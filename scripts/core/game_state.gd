extends Node
## Senaryo ilerlemesi ve ayarlar. user://save.json dosyasına kaydedilir.

const SAVE_PATH := "user://save.json"
## Test için bütün senaryolar açık. Yayın öncesi false yapılacak.
const UNLOCK_ALL := true

## Senaryolar tarih sırasıyla; ayrıntılar data/scenarios/*.json dosyalarındadır.
const SCENARIOS := [
	"res://data/scenarios/18mart_1915.json",
	"res://data/scenarios/ariburnu_1915.json",
	"res://data/scenarios/conkbayiri_1915.json",
]

## Zorluk çarpanları: enemy_power düşman ateş gücü, player_power oyuncu ateş gücü.
const DIFFICULTIES := {
	"kolay": {"title": "Kolay", "enemy_power": 0.75, "player_power": 1.2},
	"normal": {"title": "Normal", "enemy_power": 1.0, "player_power": 1.0},
	"zor": {"title": "Zor", "enemy_power": 1.25, "player_power": 0.9},
}

var stars := {}
var settings := {"quality": "high", "sfx": 0.8, "difficulty": "normal"}
var current_scenario := ""
var _meta_cache := {}


func _ready() -> void:
	if is_mobile():
		settings["quality"] = "low"
	load_game()
	apply_render_settings()


func apply_render_settings() -> void:
	var root := get_tree().root
	root.scaling_3d_scale = 1.0 if high_quality() else 0.7
	root.msaa_3d = Viewport.MSAA_4X if high_quality() else Viewport.MSAA_DISABLED


func is_mobile() -> bool:
	return OS.has_feature("mobile") or OS.has_feature("web_ios") or OS.has_feature("web_android")


## Senaryonun menüde gösterilen özeti (id, title, subtitle, summary, requires).
func scenario_meta(path: String) -> Dictionary:
	if _meta_cache.has(path):
		return _meta_cache[path]
	var f := FileAccess.open(path, FileAccess.READ)
	var d: Dictionary = {}
	if f:
		var all: Dictionary = JSON.parse_string(f.get_as_text())
		for k in ["id", "title", "subtitle", "summary", "requires"]:
			if all.has(k):
				d[k] = all[k]
	d["path"] = path
	_meta_cache[path] = d
	return d


func is_unlocked(meta: Dictionary) -> bool:
	if UNLOCK_ALL:
		return true
	var req: String = meta.get("requires", "")
	return req == "" or stars.get(req, 0) > 0


func complete(id: String, earned_stars: int) -> void:
	if earned_stars > stars.get(id, 0):
		stars[id] = earned_stars
	save_game()


func difficulty() -> String:
	var d: String = settings.get("difficulty", "normal")
	return d if DIFFICULTIES.has(d) else "normal"


func difficulty_title() -> String:
	return DIFFICULTIES[difficulty()]["title"]


func diff(key: String) -> float:
	return DIFFICULTIES[difficulty()][key]


func set_difficulty(d: String) -> void:
	if DIFFICULTIES.has(d):
		settings["difficulty"] = d
		save_game()


func high_quality() -> bool:
	return settings.get("quality", "high") == "high"


func save_game() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"stars": stars, "settings": settings, "version": 2}))


func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var data = JSON.parse_string(f.get_as_text())
	if not data is Dictionary:
		return
	# Eski (3B sürüm) kayıtlarındaki yıldızlar yeni senaryolara aktarılmaz.
	if int(data.get("version", 1)) >= 2:
		stars = data.get("stars", {})
	settings.merge(data.get("settings", {}), true)


func reset_progress() -> void:
	stars = {}
	save_game()
