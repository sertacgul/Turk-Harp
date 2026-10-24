class_name Combat
extends RefCounted
## Muharebe hesapları. Kayıp = ateş gücü x katsayı x süre x şans / siper ve arazi.
## Tüm sonuçlar sözlük olarak döner; uygulamayı Battle yapar.

## Saatte tüfek başına verilen kayıp (yakın muharebe)
const K_MELEE := 0.05
## Topçu/gemi ateşinin personel ve tahkimat/gövde katsayıları
const K_SOFT := 0.2
const K_HARD := 0.05


static func morale_f(u: Unit) -> float:
	return 0.45 + 0.55 * clampf(u.morale / 100.0, 0.0, 1.0)


## Cephanesi biten birlik yalnızca süngüyle (zayıf) çarpışır.
static func ammo_f(u: Unit, bayonet: bool) -> float:
	if u.ammo > 0.0:
		return 1.0
	return 0.55 if bayonet else 0.2


## Savunanın arazi ve siper çarpanı; yükseklik farkı ve engebe (maki, dere yatakları) korur.
static func defense_mult(b: Battle, att: Unit, def: Unit) -> float:
	var ac := b.grid.cell(att.cell)
	var dc := b.grid.cell(def.cell)
	var up := clampf((dc.elev - ac.elev) / 150.0, 0.0, 0.6)
	var m := (1.0 + 0.35 * def.entrench) * (1.0 + up) * (1.0 + clampf(dc.rough / 400.0, 0.0, 0.25))
	if def.is_fort():
		m *= 1.6
	return m


## Yakın muharebe. rnd = false ise tahmin (şanssız ortalama) döner.
static func melee(b: Battle, att: Unit, def: Unit, bayonet: bool, rnd := true) -> Dictionary:
	# Bir hücum, tur kısa da olsa yoğun bir çarpışmadır.
	var h := clampf(b.hours, 0.75, 1.5)
	var ap := att.melee_power() * morale_f(att) * ammo_f(att, bayonet) * b.power_mult(att)
	if bayonet:
		ap *= 1.35 * (b.bayonet_boost if att.side == b.player_side else 1.0)
	var dp := def.melee_power() * morale_f(def) * ammo_f(def, false) * b.power_mult(def)
	if def.is_fort():
		dp = maxf(dp, def.men * 0.8)
	var dm := defense_mult(b, att, def)
	var r1 := b.rng.randf_range(0.75, 1.25) if rnd else 1.0
	var r2 := b.rng.randf_range(0.75, 1.25) if rnd else 1.0
	var downhill := clampf((b.grid.cell(att.cell).elev - b.grid.cell(def.cell).elev) / 300.0, 0.0, 0.3)
	var cas_def := ap * K_MELEE * h * r1 / dm
	# Saldıran açıkta ilerler: savunanın ateşine daha çok maruz kalır.
	var cas_att := dp * K_MELEE * h * r2 * 1.4 / (1.0 + downhill)
	if bayonet:
		cas_att *= 1.25
	cas_def = minf(cas_def, def.men)
	cas_att = minf(cas_att, att.men)
	var odds := ap / maxf(dp * dm, 1.0)
	var def_left := def.men - cas_def
	var dmor := cas_def / maxf(def.men, 1.0) * 160.0 + (14.0 if bayonet else 0.0) + (8.0 if odds > 2.0 else 0.0)
	var amor := cas_att / maxf(att.men, 1.0) * 120.0 - (4.0 if odds > 2.0 else 0.0)
	var shock := odds * (b.rng.randf_range(0.8, 1.2) if rnd else 1.0)
	var retreat := def_left < def.men_max * 0.22 or def.morale - dmor < 25.0 or shock > 2.6
	if def.is_fort():
		retreat = def_left < def.men_max * 0.15
	return {"cas_att": int(round(cas_att)), "cas_def": int(round(cas_def)), "mor_att": amor, "mor_def": dmor,
		"odds": odds, "retreat": retreat, "bayonet": bayonet}


static func dist_m(b: Battle, a: Vector2i, c: Vector2i) -> float:
	return HexGrid.distance(a, c) * b.hex_m


## Topçu, tabya ya da gemi ateşi.
static func ranged(b: Battle, att: Unit, def: Unit, rnd := true) -> Dictionary:
	var h := b.hours
	var d := dist_m(b, att.cell, def.cell)
	var rng_m := maxf(att.max_range_m(), 1.0)
	var acc := clampf(1.15 - d / rng_m * 0.6, 0.35, 1.0)
	var r := b.rng.randf_range(0.6, 1.4) if rnd else 1.0
	var mf := morale_f(att) * (1.0 if att.ammo > 0.0 else 0.0) * b.power_mult(att)
	var res := {"dist": d, "hard": def.uses_hp(), "cas": 0, "dmg": 0.0, "mor": 0.0}
	if def.uses_hp():
		var p := att.ranged_power(true, d) * mf * acc
		var dmg := p * K_HARD * h * r
		if def.is_fort():
			# Toprak tabyalar mermiyi yutar; kalıcı hasar azdı, toplar daha çok geçici susturuldu.
			dmg *= 0.45 / (1.0 + 0.3 * def.entrench)
		res["dmg"] = dmg
		res["mor"] = dmg * 0.5
		# Tahkimat/gemi mürettebatı da kayıp verir.
		res["cas"] = int(round(minf(def.men, dmg * def.men / maxf(def.hp_max, 1.0) * 0.6)))
	else:
		var p := att.ranged_power(false, d) * mf * acc
		var cas := p * K_SOFT * h * r / (1.0 + 0.7 * def.entrench)
		# Düz atışlı gemi topları siperlere ve sırt arkalarına az etkiliydi.
		if att.is_naval():
			cas *= 0.55
		cas = minf(cas, def.men)
		res["cas"] = int(round(cas))
		res["mor"] = cas / maxf(def.men, 1.0) * 220.0 + p * 0.004
	return res
