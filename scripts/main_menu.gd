extends Node2D

const W := 1280.0
const H := 720.0
const BATTLE_SCENE := "res://scenes/canakkale_battle.tscn"

var _battle: Dictionary = {}
var _start_rect := Rect2(440, 560, 400, 80)


func _ready() -> void:
	var f := FileAccess.open("res://data/battles/canakkale_1915.json", FileAccess.READ)
	if f:
		var parsed = JSON.parse_string(f.get_as_text())
		if parsed is Dictionary:
			_battle = parsed


func _draw() -> void:
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(0, 0, W, H), Color("14202e"))
	draw_string(font, Vector2(0, 110), "TÜRK HARP", HORIZONTAL_ALIGNMENT_CENTER, W, 80, Color("e8b923"))
	draw_string(font, Vector2(0, 160), "Türk tarihinin gerçek savaşları · Ücretsiz · Açık kaynak", HORIZONTAL_ALIGNMENT_CENTER, W, 24, Color("c9d3dd"))
	if not _battle.is_empty():
		draw_string(font, Vector2(0, 250), "%s (%s)" % [_battle["title"], _battle["date"]], HORIZONTAL_ALIGNMENT_CENTER, W, 34, Color.WHITE)
		draw_multiline_string(font, Vector2(180, 300), _battle["summary"], HORIZONTAL_ALIGNMENT_CENTER, 920, 22, 6, Color("dfe7ee"))
		var leaders: Array = _battle["leaders_ottoman"]
		var y := 440.0
		for l in leaders:
			draw_string(font, Vector2(0, y), "%s: %s" % [l["name"], l["role"]], HORIZONTAL_ALIGNMENT_CENTER, W, 20, Color("a9b8c6"))
			y += 28.0
	draw_rect(_start_rect, Color("c8102e"))
	draw_string(font, Vector2(_start_rect.position.x, _start_rect.position.y + 52), "Boğaz Savunması", HORIZONTAL_ALIGNMENT_CENTER, _start_rect.size.x, 34, Color.WHITE)
	draw_string(font, Vector2(0, 690), "GPL-3.0 · github.com/sertacgul/Turk-Harp", HORIZONTAL_ALIGNMENT_CENTER, W, 16, Color("6f8193"))


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var p: Vector2 = make_input_local(event).position
		if _start_rect.has_point(p):
			get_tree().change_scene_to_file(BATTLE_SCENE)
