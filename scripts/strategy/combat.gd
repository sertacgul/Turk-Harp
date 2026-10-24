class_name Combat
extends RefCounted
## Kesin (şanssız) muharebe hesabı. Her iki tarafın ateş gücü, etkenlerle (moral, yorgunluk, talim,
## cephane, komuta, ikmal, bastırma, arazi, yükseklik, siper, duruş, süngü, kuşatma) çarpılır;
## güç oranı zayiatı ve sonucu belirler. Önizleme ile gerçek sonuç birebir aynıdır.
## Her sonuç, arayüzde gösterilmek üzere etken listelerini de içerir: [ad, çarpan].

## Güç oranı 1:1 iken saatte savunanın ve saldıranın zayiat oranı
const DEF_RATE := 0.035
const ATT_RATE := 0.05
## Topçu/gemi ateşinin personel ve tahkimat/gövde katsayıları
const K_SOFT := 0.2
const K_HARD := 0.05
## Güç oranı bu değeri aşarsa savunan çekilmek zorunda kalır
const RETREAT_ODDS := 2.0


static func morale_f(u: Unit) -> float:
	return 0.45 + 0.55 * clampf(u.morale / 100.0, 0.0, 1.0)


static func fatigue_f(u: Unit) -> float:
	return 1.0 - clampf(u.fatigue, 0.0, 100.0) / 250.0


## Birliğin kendi durumundan gelen etkenler (iki taraf için ortak).
static func _state_factors(b: Battle, u: Unit, out: Array, bayonet := false) -> void:
	out.append(["Moral %d" % int(u.morale), morale_f(u)])
	if u.fatigue >= 5.0:
		out.append(["Yorgunluk %d" % int(u.fatigue), fatigue_f(u)])
	if u.training != 1:
		out.append(["Talim: " + u.exp_title(), u.exp_mult()])
	if u.ammo <= 0.0:
		out.append(["Cephane yok" + (" (süngüyle)" if bayonet else ""), 0.55 if bayonet else 0.2])
	if not u.in_command:
		out.append(["Komuta dışı", 0.85])
	if not u.in_supply:
		out.append(["İkmal dışı", 0.9])
	if u.suppression > 0.0:
		out.append(["Topçu ateşiyle bastırılmış", 1.0 - u.suppression])
	var pm := b.power_mult(u)
	if absf(pm - 1.0) > 0.001:
		out.append(["Zorluk", pm])


static func product(f: Array) -> float:
	var m := 1.0
	for x in f:
		m *= float(x[1])
	return m


## Savunanın arazi, yükseklik, siper ve duruş etkenleri.
static func _defense_factors(b: Battle, att: Unit, def: Unit, out: Array) -> void:
	var ac := b.grid.cell(att.cell)
	var dc := b.grid.cell(def.cell)
	var t := Terrain.info(dc.terrain)
	if absf(float(t["defense"]) - 1.0) > 0.001:
		out.append(["Arazi: " + dc.terrain, float(t["defense"])])
	var up := clampf((dc.elev - ac.elev) / 150.0, 0.0, 0.6)
	if up > 0.01:
		out.append(["Yükseklik üstünlüğü (+%d m)" % int(dc.elev - ac.elev), 1.0 + up])
	if def.entrench > 0:
		out.append(["Siper %d" % def.entrench, 1.0 + 0.35 * def.entrench])
	match def.stance:
		"defend":
			out.append(["Duruş: savunma", 1.25])
		"rest":
			out.append(["Duruş: dinlenme", 0.8])
		"march":
			out.append(["Duruş: yürüyüş kolu", 0.6])
	if def.is_fort():
		out.append(["Tabya surları", 1.6])


## Saldırana komşu başka dost birlik sayısı (kuşatma)
static func flankers(b: Battle, att: Unit, def: Unit) -> int:
	var n := 0
	for k in b.grid.neighbors(def.cell):
		var o := b.unit_at(k)
		if o and o != att and o.side == att.side and o.is_land() and not o.is_hq() and o.can_melee():
			n += 1
	return mini(n, 3)


## Yakın muharebe (hücum). Sonuç kesindir.
static func melee(b: Battle, att: Unit, def: Unit, bayonet: bool) -> Dictionary:
	var h := clampf(b.hours, 0.75, 1.5)
	var af: Array = []
	_state_factors(b, att, af, bayonet)
	if bayonet:
		af.append(["Süngü hücumu", 1.35 * (b.bayonet_boost if att.side == b.player_side else 1.0)])
	var fl := flankers(b, att, def)
	if fl > 0:
		af.append(["Kuşatma (%d birlik)" % fl, 1.0 + 0.12 * fl])
	var df: Array = []
	_state_factors(b, def, df)
	_defense_factors(b, att, def, df)
	var a_base := att.melee_power()
	var d_base := def.melee_power()
	if def.is_fort():
		d_base = maxf(d_base, def.men * 0.8)
	var A := a_base * product(af)
	var D := maxf(d_base * product(df), 1.0)
	var odds := A / D
	var def_frac := clampf(DEF_RATE * odds * h, 0.005, 0.4)
	var att_frac := clampf(ATT_RATE * h / maxf(odds, 0.05) * (1.25 if bayonet else 1.0), 0.005, 0.35)
	var cas_def := mini(int(round(def.men * def_frac)), def.men)
	var cas_att := mini(int(round(att.men * att_frac)), att.men)
	var dmor := def_frac * 180.0 + (12.0 if bayonet else 0.0) + (8.0 if odds >= RETREAT_ODDS else 0.0)
	var amor := att_frac * 120.0 + (8.0 if odds < 0.7 else 0.0) - (4.0 if odds >= RETREAT_ODDS else 0.0)
	var left := def.men - cas_def
	var retreat := odds >= RETREAT_ODDS or def.morale - dmor < 25.0 or left < def.men_max * 0.25
	if def.is_fort():
		retreat = left < def.men_max * 0.15
	var outcome := "Düşman geri çekilir" if retreat else ("Hücum püskürtülür" if odds < 0.7 else "Düşman mevzide tutunur")
	return {"cas_att": cas_att, "cas_def": cas_def, "mor_att": amor, "mor_def": dmor, "odds": odds,
		"retreat": retreat, "bayonet": bayonet, "att_base": a_base, "def_base": d_base, "att_f": af, "def_f": df,
		"A": A, "D": D, "outcome": outcome, "melee": true}


static func dist_m(b: Battle, a: Vector2i, c: Vector2i) -> float:
	return HexGrid.distance(a, c) * b.hex_m


## Topçu, tabya ya da gemi ateşi. Personel hedefinde zayiat ve bastırma, tahkimat/gemide hasar.
static func ranged(b: Battle, att: Unit, def: Unit) -> Dictionary:
	var h := b.hours
	var d := dist_m(b, att.cell, def.cell)
	var rng_m := maxf(att.max_range_m(), 1.0)
	var acc := clampf(1.15 - d / rng_m * 0.6, 0.35, 1.0)
	var af: Array = []
	af.append(["Menzil isabeti (%.1f km)" % (d / 1000.0), acc])
	af.append(["Moral %d" % int(att.morale), morale_f(att)])
	if att.training != 1:
		af.append(["Talim: " + att.exp_title(), att.exp_mult()])
	if att.ammo <= 0.0:
		af.append(["Mermi yok", 0.0])
	if not att.in_command and not att.is_naval():
		af.append(["Komuta dışı", 0.85])
	var pm := b.power_mult(att)
	if absf(pm - 1.0) > 0.001:
		af.append(["Zorluk", pm])
	var res := {"dist": d, "hard": def.uses_hp(), "cas": 0, "dmg": 0.0, "mor": 0.0, "supp": 0.0, "att_f": af, "def_f": [], "melee": false}
	if def.uses_hp():
		var base := att.ranged_power(true, d)
		var df: Array = []
		if def.is_fort():
			df.append(["Toprak tabya mermiyi yutar", 0.45])
			if def.entrench > 0:
				df.append(["Tahkimat %d" % def.entrench, 1.0 / (1.0 + 0.3 * def.entrench)])
		var dmg := base * product(af) * product(df) * K_HARD * h
		res["att_base"] = base
		res["def_f"] = df
		res["dmg"] = dmg
		res["mor"] = dmg * 0.5
		res["cas"] = int(round(minf(def.men, dmg * def.men / maxf(def.hp_max, 1.0) * 0.6)))
		res["outcome"] = "%%%d hasar" % int(round(dmg / maxf(def.hp_max, 1.0) * 100.0))
	else:
		var base2 := att.ranged_power(false, d)
		var df2: Array = []
		if def.entrench > 0:
			df2.append(["Siper %d" % def.entrench, 1.0 / (1.0 + 0.7 * def.entrench)])
		var dc := b.grid.cell(def.cell)
		if Terrain.info(dc.terrain)["conceal"]:
			df2.append(["Gizleyen arazi: " + dc.terrain, 0.8])
		if att.is_naval():
			df2.append(["Gemi topu düz atışlı", 0.55])
		var p := base2 * product(af) * product(df2)
		var cas := minf(p * K_SOFT * h, def.men)
		res["att_base"] = base2
		res["def_f"] = df2
		res["cas"] = int(round(cas))
		res["mor"] = cas / maxf(def.men, 1.0) * 220.0 + p * 0.004
		# Bastırma: birlik siperde başını kaldıramaz; bir sonraki kendi turunun sonuna kadar sürer.
		var supp := clampf(p / (def.men * 0.06 + 20.0) / (1.0 + 0.5 * def.entrench), 0.0, 0.5)
		res["supp"] = supp
		res["outcome"] = "%d zayiat, %%%d bastırma" % [int(round(cas)), int(round(supp * 100.0))]
	return res
