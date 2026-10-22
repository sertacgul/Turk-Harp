extends Node
## Kampanya ilerlemesi, yükseltmeler ve ayarlar. user://save.json dosyasına kaydedilir.

const SAVE_PATH := "user://save.json"

const MISSIONS := [
	{
		"id": "nusret",
		"title": "Nusret'in Gecesi",
		"date": "7-8 Mart 1915",
		"scene": "res://scenes/missions/nusret_night.tscn",
		"requires": "",
		"summary": "İtilaf ışıldakları boğazı tararken küçük mayın gemisi Nusret, Erenköy Koyu'na kıyıya paralel 26 mayın döşer. Bu mayınlar 18 Mart'ın kaderini belirleyecektir.",
	},
	{
		"id": "18mart",
		"title": "18 Mart: Boğaz Savunması",
		"date": "18 Mart 1915",
		"scene": "res://scenes/missions/strait_defense.tscn",
		"requires": "nusret",
		"summary": "İtilaf donanması üç hat halinde boğaza girer. Rumeli Mecidiye Tabyası'nın topunu sen yönet, diğer bataryalara hedef göster. Cephane bittiğinde Seyit Onbaşı mermiyi sırtında taşır.",
	},
	{
		"id": "ariburnu",
		"title": "Arıburnu: 57. Alay",
		"date": "25 Nisan 1915",
		"scene": "",
		"requires": "18mart",
		"summary": "Mustafa Kemal komutasındaki 19. Tümen, Arıburnu'na çıkan ANZAC birliklerini durdurur. (Yapım aşamasında)",
	},
	{
		"id": "conkbayiri",
		"title": "Conkbayırı",
		"date": "8-10 Ağustos 1915",
		"scene": "",
		"requires": "ariburnu",
		"summary": "Anafartalar Grubu Komutanı Mustafa Kemal'in Conkbayırı taarruzu. (Yapım aşamasında)",
	},
]

const UPGRADES := {
	"range": {"title": "Barut Hakkı", "desc": "Mermi hızı ve menzil +%8", "costs": [2, 4, 7]},
	"reload": {"title": "Talimli Top Mürettebatı", "desc": "Dolum süresi -%12", "costs": [2, 4, 7]},
	"armor": {"title": "Tabya Tahkimatı", "desc": "Tabya dayanıklılığı +%15", "costs": [2, 4, 7]},
	"seyit": {"title": "Seyit'in Gücü", "desc": "Cephane taşıma süresi -%20", "costs": [1, 3, 5]},
}

## Varsayılan (tarihî) mayın hattı: Erenköy Koyu'nda kıyıya paralel 26 mayın.
var default_mines: Array[Vector3] = []

var stars := {}
var honor := 0
var upgrades := {"range": 0, "reload": 0, "armor": 0, "seyit": 0}
var laid_mines: Array[Vector3] = []
var settings := {"quality": "high", "sfx": 0.8}
var current_mission := ""


func _ready() -> void:
	default_mines = StraitWorld.default_mine_line()
	load_game()


func mission(id: String) -> Dictionary:
	for m in MISSIONS:
		if m["id"] == id:
			return m
	return {}


func is_unlocked(id: String) -> bool:
	var req: String = mission(id).get("requires", "")
	return req == "" or stars.get(req, 0) > 0


func complete(id: String, earned_stars: int, honor_gain: int) -> void:
	if earned_stars > stars.get(id, 0):
		stars[id] = earned_stars
	honor += honor_gain
	save_game()


func upgrade_level(key: String) -> int:
	return upgrades.get(key, 0)


func upgrade_cost(key: String) -> int:
	var costs: Array = UPGRADES[key]["costs"]
	var lvl := upgrade_level(key)
	return -1 if lvl >= costs.size() else costs[lvl]


func buy_upgrade(key: String) -> bool:
	var cost := upgrade_cost(key)
	if cost < 0 or honor < cost:
		return false
	honor -= cost
	upgrades[key] = upgrade_level(key) + 1
	save_game()
	return true


func mines_for_battle() -> Array[Vector3]:
	return laid_mines if laid_mines.size() > 0 else default_mines


func high_quality() -> bool:
	return settings.get("quality", "high") == "high"


func save_game() -> void:
	var mines := []
	for m in laid_mines:
		mines.append([m.x, m.z])
	var data := {"stars": stars, "honor": honor, "upgrades": upgrades, "mines": mines, "settings": settings}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(data))


func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var data = JSON.parse_string(f.get_as_text())
	if not data is Dictionary:
		return
	stars = data.get("stars", {})
	honor = int(data.get("honor", 0))
	for k in upgrades:
		upgrades[k] = int(data.get("upgrades", {}).get(k, 0))
	settings.merge(data.get("settings", {}), true)
	laid_mines.clear()
	for m in data.get("mines", []):
		laid_mines.append(Vector3(m[0], 0.0, m[1]))


func reset_progress() -> void:
	stars = {}
	honor = 0
	for k in upgrades:
		upgrades[k] = 0
	laid_mines.clear()
	save_game()
