class_name Unit
extends RefCounted
## Harekât haritasındaki bir birlik: tabur, batarya, tabya ya da gemi.

const OTTOMAN := "ottoman"
const ENTENTE := "entente"

var id := ""
var name := ""
## Pul üzerindeki kısa ad (ör. "57/1")
var short := ""
var side := OTTOMAN
## tr, anzac, uk, fr
var nation := "tr"
## infantry, mg, artillery, fort, ship, sweeper
var kind := "infantry"
## bölük, tabur, alay, batarya, tabya, gemi
var size := "tabur"
var commander := ""
var note := ""
var men := 0
var men_max := 0
## Gemi ve tabyalar için gövde/tahkimat dayanıklılığı (0 ise kara birliği)
var hp := 0.0
var hp_max := 0.0
var equipment := {}
var morale := 80.0
var ammo := 100.0
var entrench := 0
var mp_max := 4.0
var mp := 4.0
var vision := 2
var cell := Vector2i.ZERO
var moved := false
var attacked := false
var dug := false
## Ağır ateş altında kalan tabya/batarya bir tur ateş edemez.
var suppressed := 0
## reserve (henüz gelmedi), active, dead, retired (çekildi)
var state := "active"
var arrive_turn := 0
var arrive_cell := Vector2i.ZERO
## YZ: attack, hold, bombard, naval, sweep, retreat
var role := "hold"
var goal := Vector2i(-1, -1)
var goal_name := ""
var waypoints: Array[Vector2i] = []
var retire_hp := 0.0
var losses := 0
## Oyuncu emri: "" (yok), attack (hedefe taarruz), defend (savun), reserve (yedek), fire (otomatik ateş)
var order := ""
var order_cell := Vector2i(-1, -1)
var order_name := ""
## Duruş: normal (muharebe düzeni), march (intikal/yürüyüş kolu), defend (savunma), rest (dinlenme)
var stance := "normal"
## 0..100: yürüyüş ve çarpışmayla artar, dinlenmeyle azalır
var fatigue := 0.0
## Talim/tecrübe: 0 acemi, 1 talimli, 2 tecrübeli, 3 seçkin
var training := 1
## Bağlı olduğu karargâhın kimliği ve komuta durumu
var hq_id := ""
var in_command := true
## Karargâhlar için komuta menzili (hücre)
var command_range := 0
## İkmal durumu
var in_supply := true
var out_supply_turns := 0
## Topçu ateşiyle bastırılma (0..0.6): muharebe değerini düşürür
var suppression := 0.0
## Silah başına mermi (topçu, tabya, gemi); 0 ise türüne göre varsayılan
var shells_per_gun := 0
var counter: Node3D

const EXP_TITLES := ["Acemi", "Talimli", "Tecrübeli", "Seçkin"]
const EXP_MULT := [0.85, 1.0, 1.12, 1.25]
const STANCE_TITLES := {"normal": "Muharebe düzeni", "march": "İntikal (yürüyüş kolu)", "defend": "Savunma", "rest": "Dinlenme"}


func is_naval() -> bool:
	return kind == "ship" or kind == "sweeper"


func is_fort() -> bool:
	return kind == "fort"


func is_hq() -> bool:
	return kind == "hq"


func is_land() -> bool:
	return not is_naval()


func uses_hp() -> bool:
	return hp_max > 0.0


func alive() -> bool:
	return state == "active"


## 0..1 kalan güç
func strength() -> float:
	if uses_hp():
		return clampf(hp / hp_max, 0.0, 1.0)
	return clampf(float(men) / maxf(men_max, 1.0), 0.0, 1.0)


func can_move() -> bool:
	return not is_fort() and mp_max > 0.0


func can_melee() -> bool:
	if is_naval() or is_fort() or men <= 0:
		return false
	for id_ in equipment:
		if not Equipment.is_ranged(id_) and Equipment.info(id_)["soft"] > 0.0:
			return true
	return false


func ranged_items() -> Array[String]:
	var out: Array[String] = []
	for id_: String in equipment:
		if Equipment.is_ranged(id_) and int(equipment[id_]) > 0:
			out.append(id_)
	return out


func max_range_m() -> float:
	var r := 0.0
	for id_ in ranged_items():
		r = maxf(r, float(Equipment.info(id_)["range_m"]))
	return r


## Topçu: hareket ettiği tur ateş edemez (gemiler hariç).
func is_artillery() -> bool:
	return not ranged_items().is_empty() and not can_melee() and not is_naval()


## Yakın muharebe ateş gücü (tüfek + makineli tüfek), kalan güce göre.
func melee_power() -> float:
	var p := 0.0
	for id_: String in equipment:
		var e := Equipment.info(id_)
		if not Equipment.is_ranged(id_):
			p += float(equipment[id_]) * float(e["soft"])
	return p * strength()


func ranged_power(target_hard: bool, dist_m: float) -> float:
	var p := 0.0
	for id_ in ranged_items():
		var e := Equipment.info(id_)
		if dist_m <= float(e["range_m"]):
			p += float(equipment[id_]) * float(e["hard"] if target_hard else e["soft"])
	return p * strength()


func needs_los() -> bool:
	for id_ in ranged_items():
		if bool(Equipment.info(id_)["indirect"]):
			return false
	return true


func side_title() -> String:
	return "İttifak (Osmanlı)" if side == OTTOMAN else "İtilaf"


func nation_title() -> String:
	return {"tr": "Osmanlı Devleti", "anzac": "ANZAC", "au": "Avustralya (ANZAC)", "nz": "Yeni Zelanda (ANZAC)", "uk": "Britanya", "fr": "Fransa"}.get(nation, nation)


## "57. Alay 1. Tabur" -> "57. Alay" (aynı alaya toplu emir için)
func regiment() -> String:
	var i := name.find(" Alay")
	return name.substr(0, i + 5) if i > 0 else ""


func order_title() -> String:
	match order:
		"attack":
			return "Taarruz: " + order_name
		"defend":
			return "Savunma"
		"reserve":
			return "Yedekte"
		"fire":
			return "Serbest ateş"
	return "Emir yok"



func exp_title() -> String:
	return EXP_TITLES[clampi(training, 0, 3)]


func exp_mult() -> float:
	return EXP_MULT[clampi(training, 0, 3)]


func stance_title() -> String:
	return STANCE_TITLES.get(stance, stance)


## Yorgunluk hareket puanını düşürür; intikal duruşu artırır.
func effective_mp() -> float:
	var m := mp_max * (1.0 - fatigue / 300.0)
	if stance == "march":
		m *= 1.5
	return m


func can_act_move() -> bool:
	return can_move() and stance in ["normal", "march"]


func can_act_attack() -> bool:
	return stance == "normal"


## Silah başına tam mermi (topçu ve tabyalar için sınırlı stok)
func shells_full() -> int:
	if shells_per_gun > 0:
		return shells_per_gun
	if is_naval():
		return 80
	if is_fort():
		return 40
	for id_ in ranged_items():
		if String(id_).contains("obus"):
			return 60
	return 120


func gun_count() -> int:
	var n := 0
	for id_ in ranged_items():
		n += int(equipment[id_])
	return n


func rifle_count() -> int:
	var n := 0
	for id_: String in equipment:
		if not Equipment.is_ranged(id_) and Equipment.info(id_)["kind"] == "tüfek":
			n += int(equipment[id_])
	return n


## Cephane gerçek sayılarla: piyadede fişek (tüfek başına 150), topçuda mermi.
func ammo_text() -> String:
	var f := ammo / 100.0
	if not ranged_items().is_empty() and (is_artillery() or is_fort() or is_naval()):
		var total := gun_count() * shells_full()
		return "%d / %d mermi" % [int(round(total * f)), total]
	var rounds := int(round(maxi(rifle_count(), 1) * 150 * strength() * f))
	return "%s fişek (~%d hücumluk)" % [str(rounds), int(floor(ammo / 25.0))]


## Bir eylemin cephane bedeli (yüzde)
func ammo_cost(action: String) -> float:
	match action:
		"attack":
			return 25.0
		"bayonet":
			return 8.0
		"defend":
			return 8.0
		"fire":
			if is_naval():
				return 5.0
			# Bir ateş görevi: tabyada silah başına 4, sahra ve dağ topunda 12 mermi
			return (4.0 if is_fort() else 12.0) * 100.0 / float(shells_full())
	return 0.0


func kind_title() -> String:
	return {"infantry": "Piyade", "mg": "Makineli tüfek", "artillery": "Topçu", "fort": "Tabya", "ship": "Zırhlı", "sweeper": "Mayın tarayıcı", "hq": "Karargâh"}.get(kind, kind)


static func from_dict(d: Dictionary) -> Unit:
	var u := Unit.new()
	u.id = d.get("id", "")
	u.name = d.get("name", u.id)
	u.short = d.get("short", u.name.left(6))
	u.side = d.get("side", OTTOMAN)
	u.nation = d.get("nation", "tr" if u.side == OTTOMAN else "uk")
	u.kind = d.get("kind", "infantry")
	u.size = d.get("size", "tabur")
	u.commander = d.get("commander", "")
	u.note = d.get("note", "")
	u.men = int(d.get("men", 0))
	u.men_max = int(d.get("men_max", u.men))
	u.hp_max = float(d.get("hp", 0.0))
	u.hp = u.hp_max
	u.equipment = (d.get("equipment", {}) as Dictionary).duplicate()
	u.morale = float(d.get("morale", 80.0))
	u.ammo = float(d.get("ammo", 100.0))
	u.entrench = int(d.get("entrench", 0))
	u.mp_max = float(d.get("mp", 0.0 if u.kind == "fort" else 4.0))
	u.mp = u.mp_max
	u.vision = int(d.get("vision", 6 if u.kind in ["ship", "fort"] else 2))
	u.arrive_turn = int(d.get("arrive", 0))
	u.state = "reserve" if u.arrive_turn > 0 else "active"
	u.role = d.get("role", "hold")
	u.goal_name = d.get("goal", "")
	u.retire_hp = float(d.get("retire_hp", 0.0))
	u.training = int(d.get("exp", 1))
	u.hq_id = d.get("hq", "")
	u.command_range = int(d.get("command_range", 0))
	u.shells_per_gun = int(d.get("shells", 0))
	u.stance = d.get("stance", "normal")
	u.fatigue = float(d.get("fatigue", 0.0))
	return u
