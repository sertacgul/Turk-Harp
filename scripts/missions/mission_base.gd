class_name MissionBase
extends Node3D
## Görevlerin ortak altyapısı: dünya, HUD, brifing, duraklatma, sonuç ekranı ve kamera sarsıntısı.

signal mission_started

const MENU_SCENE := "res://scenes/main_menu.tscn"

var mission_id := ""
var world: StraitWorld
var running := false
var finished := false
var elapsed := 0.0

var hud: CanvasLayer
var ui: Control
var objective_label: Label
var _messages: VBoxContainer
var _banner: Label
var _banner_sub: Label
var _banner_time := 0.0
var _pause_panel: Control
var _overlay: Control
var _shake := 0.0
var _intro_done := false
var _intro_layer: Control
var _intro_skip: Callable
var _last_message := ""
var _last_message_time := -100.0
var _rng := RandomNumberGenerator.new()


## build_strait false ise görev kendi dünyasını kurar (ör. Arıburnu).
func setup(id: String, is_night: bool, build_strait := true) -> void:
	mission_id = id
	GameState.current_mission = id
	_rng.randomize()
	if build_strait:
		world = StraitWorld.new()
		add_child(world)
		world.build(is_night)
	_build_hud()
	Sfx.start_loop("sea", -16.0)


func _exit_tree() -> void:
	Voice.stop()
	Sfx.stop_all_loops()
	get_tree().paused = false


# ------------------------------------------------------------------ HUD

func _build_hud() -> void:
	hud = CanvasLayer.new()
	hud.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(hud)
	ui = Control.new()
	ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.theme = UiTheme.get_theme()
	hud.add_child(ui)

	objective_label = UiTheme.label("", 20, UiTheme.TEXT)
	objective_label.position = Vector2(24, 18)
	ui.add_child(objective_label)

	_messages = VBoxContainer.new()
	_messages.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_messages.position = Vector2(-520, 70)
	_messages.custom_minimum_size = Vector2(500, 0)
	_messages.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(_messages)

	var center := VBoxContainer.new()
	center.set_anchors_preset(Control.PRESET_CENTER_TOP)
	center.position = Vector2(-500, 150)
	center.custom_minimum_size = Vector2(1000, 0)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(center)
	_banner = UiTheme.label("", 52, UiTheme.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	_banner_sub = UiTheme.label("", 24, UiTheme.TEXT, HORIZONTAL_ALIGNMENT_CENTER)
	center.add_child(_banner)
	center.add_child(_banner_sub)

	var pause_btn := UiTheme.button("II", toggle_pause, 56)
	pause_btn.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	pause_btn.position = Vector2(-76, 12)
	ui.add_child(pause_btn)


func message(text: String, color := UiTheme.TEXT) -> void:
	# Aynı mesajı kısa sürede tekrar gösterme.
	if text == _last_message and elapsed - _last_message_time < 4.0:
		return
	_last_message = text
	_last_message_time = elapsed
	var l := UiTheme.label(text, 19, color, HORIZONTAL_ALIGNMENT_RIGHT)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 500
	_messages.add_child(l)
	if _messages.get_child_count() > 6:
		_messages.get_child(0).queue_free()
	var tw := l.create_tween()
	tw.tween_interval(6.0)
	tw.tween_property(l, "modulate:a", 0.0, 1.0)
	tw.tween_callback(l.queue_free)


func banner(text: String, sub := "", duration := 3.0) -> void:
	_banner.text = text
	_banner_sub.text = sub
	_banner.modulate.a = 1.0
	_banner_sub.modulate.a = 1.0
	_banner_time = duration


func set_objective(text: String) -> void:
	objective_label.text = text


func _overlay_panel() -> VBoxContainer:
	if _overlay:
		_overlay.queue_free()
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.add_child(dim)
	_overlay = dim
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.add_child(cc)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(760, 0)
	cc.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	panel.add_child(box)
	return box


## Görevin tarihî önemini anlatan intro kartları: [[başlık, metin], ...]. Alt sınıflar doldurur.
func intro_cards() -> Array:
	return []


## Intro bittiğinde (ya da geçildiğinde) brifing gösterilir.
func show_briefing(title: String, date: String, body: String, notes: Array) -> void:
	if not _intro_done and not intro_cards().is_empty():
		_intro_done = true
		_play_intro(intro_cards(), show_briefing.bind(title, date, body, notes))
		return
	_show_briefing_panel(title, date, body, notes)


func _show_briefing_panel(title: String, date: String, body: String, notes: Array) -> void:
	var box := _overlay_panel()
	box.add_child(UiTheme.label("%s  ·  Zorluk: %s" % [date, GameState.difficulty_title()], 18, UiTheme.MUTED, HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(UiTheme.label(title, 40, UiTheme.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(UiTheme.wrap_label(body, 19, UiTheme.TEXT, 720))
	for n in notes:
		box.add_child(UiTheme.wrap_label("•  " + str(n), 17, UiTheme.MUTED, 720))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	row.add_child(UiTheme.button("Menü", _to_menu, 180))
	row.add_child(UiTheme.button("Göreve Başla", start_mission, 260))
	box.add_child(row)


func start_mission() -> void:
	if _intro_layer:
		Voice.stop()
		_intro_layer.queue_free()
		_intro_layer = null
		_restore_hud()
	if _overlay:
		_overlay.queue_free()
		_overlay = null
	running = true
	mission_started.emit()


func finish(success: bool, earned_stars: int, honor_gain: int, lines: Array) -> void:
	if finished:
		return
	finished = true
	running = false
	honor_gain = int(round(honor_gain * GameState.diff("honor")))
	if success:
		GameState.complete(mission_id, earned_stars, honor_gain)
	var box := _overlay_panel()
	box.add_child(UiTheme.label("ZAFER" if success else "BAŞARISIZ", 46, UiTheme.GOLD if success else Color(0.9, 0.35, 0.3), HORIZONTAL_ALIGNMENT_CENTER))
	if success:
		var cc := CenterContainer.new()
		cc.add_child(StarRow.new(earned_stars, 44.0))
		box.add_child(cc)
		box.add_child(UiTheme.label("+%d Şeref  ·  Zorluk: %s" % [honor_gain, GameState.difficulty_title()], 24, UiTheme.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	for l in lines:
		box.add_child(UiTheme.wrap_label(str(l), 19, UiTheme.TEXT, 720))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	row.add_child(UiTheme.button("Tekrar", _restart, 200))
	row.add_child(UiTheme.button("Görevler", _to_menu, 240))
	box.add_child(row)


func toggle_pause() -> void:
	if finished or not running:
		return
	var p := not get_tree().paused
	get_tree().paused = p
	if p:
		_pause_panel = Control.new()
		_pause_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
		ui.add_child(_pause_panel)
		var dim := ColorRect.new()
		dim.color = Color(0, 0, 0, 0.5)
		dim.set_anchors_preset(Control.PRESET_FULL_RECT)
		_pause_panel.add_child(dim)
		var cc := CenterContainer.new()
		cc.set_anchors_preset(Control.PRESET_FULL_RECT)
		_pause_panel.add_child(cc)
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 14)
		cc.add_child(box)
		box.add_child(UiTheme.label("DURAKLATILDI", 40, UiTheme.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
		box.add_child(UiTheme.button("Devam", toggle_pause))
		box.add_child(UiTheme.button("Yeniden Başla", _restart))
		box.add_child(UiTheme.button("Görevlere Dön", _to_menu))
	elif _pause_panel:
		_pause_panel.queue_free()


func _restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _to_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(MENU_SCENE)


func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if _intro_layer and k.pressed and k.keycode in [KEY_SPACE, KEY_ENTER, KEY_ESCAPE]:
		_end_intro()
		return
	if event.is_pressed() and k.keycode == KEY_ESCAPE:
		toggle_pause()


# ------------------------------------------------------------------ efektler

func shake(amount: float) -> void:
	_shake = maxf(_shake, amount)


func _process(delta: float) -> void:
	if running:
		elapsed += delta
	if _banner_time > 0.0:
		_banner_time -= delta
		if _banner_time < 1.0:
			_banner.modulate.a = maxf(_banner_time, 0.0)
			_banner_sub.modulate.a = maxf(_banner_time, 0.0)
	var cam := get_viewport().get_camera_3d()
	if cam:
		_shake = move_toward(_shake, 0.0, delta * 2.5)
		cam.h_offset = _rng.randf_range(-1.0, 1.0) * _shake * 0.6
		cam.v_offset = _rng.randf_range(-1.0, 1.0) * _shake * 0.6
	mission_process(delta)


# ------------------------------------------------------------------ intro

## Sinematik intro: sinema şeritleri, kart kart tarih ve metin, ağır müzik, isteğe bağlı seslendirme.
func _play_intro(cards: Array, then: Callable) -> void:
	_intro_skip = then
	_intro_layer = Control.new()
	_intro_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.add_child(_intro_layer)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.55)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_intro_layer.add_child(shade)
	# Intro sırasında oyun arayüzü gizli; yalnızca sahne ve intro görünür.
	for c in ui.get_children():
		if c != _intro_layer and c is CanvasItem:
			c.set_meta("intro_hidden", (c as CanvasItem).visible)
			(c as CanvasItem).visible = false
	for top in [true, false]:
		var bar := ColorRect.new()
		bar.color = Color.BLACK
		bar.anchor_right = 1.0
		bar.anchor_top = 0.0 if top else 1.0
		bar.anchor_bottom = 0.0 if top else 1.0
		bar.offset_top = 0.0 if top else -90.0
		bar.offset_bottom = 90.0 if top else 0.0
		_intro_layer.add_child(bar)
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	_intro_layer.add_child(cc)
	var box := VBoxContainer.new()
	box.custom_minimum_size.x = 860
	box.add_theme_constant_override("separation", 18)
	cc.add_child(box)
	var kicker := UiTheme.label("", 20, UiTheme.MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	var title := UiTheme.label("", 50, UiTheme.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	var line := ColorRect.new()
	line.color = UiTheme.GOLD.darkened(0.2)
	line.custom_minimum_size = Vector2(120, 2)
	line.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var body := UiTheme.wrap_label("", 24, UiTheme.TEXT, 860)
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.visible_ratio = 0.0
	for n in [kicker, title, line, body]:
		box.add_child(n)
	var skip := UiTheme.button("Geç  ›", _end_intro, 140)
	skip.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	skip.position = Vector2(-170, -72)
	_intro_layer.add_child(skip)
	Sfx.play("intro", -6.0)
	var tw := _intro_layer.create_tween()
	for i in cards.size():
		var card: Array = cards[i]
		tw.tween_callback(func() -> void:
			kicker.text = "%d / %d" % [i + 1, cards.size()]
			title.text = card[0]
			body.text = card[1]
			body.visible_ratio = 0.0
			box.modulate.a = 0.0
			Voice.speak(card[1], "kemal"))
		tw.tween_property(box, "modulate:a", 1.0, 0.8)
		tw.parallel().tween_property(body, "visible_ratio", 1.0, 2.6)
		tw.tween_interval(maxf(4.0, String(card[1]).length() * 0.045))
		tw.tween_property(box, "modulate:a", 0.0, 0.7)
	tw.tween_callback(_end_intro)


func _end_intro() -> void:
	if _intro_layer == null:
		return
	Voice.stop()
	var layer := _intro_layer
	_intro_layer = null
	_restore_hud()
	var tw := layer.create_tween()
	tw.tween_property(layer, "modulate:a", 0.0, 0.5)
	tw.tween_callback(layer.queue_free)
	_intro_skip.call()


func _restore_hud() -> void:
	for c in ui.get_children():
		if c.has_meta("intro_hidden"):
			(c as CanvasItem).visible = c.get_meta("intro_hidden")
			c.remove_meta("intro_hidden")


## Konuşma: mesaj akışında gösterir ve sesli okur.
func say(who: String, text: String, color := UiTheme.TEXT) -> void:
	message("%s: \"%s\"" % [who, text], color)
	Voice.speak(text, "kemal" if who.contains("Kemal") else "asker")


## Tuş basılı mı? Hem tuşun üzerindeki harfe hem de klavyedeki yerine bakar;
## böylece W/A/S/D Türkçe F klavyede de aynı yerden çalışır.
func key(code: Key) -> bool:
	return Input.is_key_pressed(code) or Input.is_physical_key_pressed(code)


## İleri/geri ve sol/sağ: W/A/S/D ya da yön tuşları. x: sağ +, y: ileri +.
func move_axis() -> Vector2:
	var v := Vector2.ZERO
	if key(KEY_W) or key(KEY_UP):
		v.y += 1.0
	if key(KEY_S) or key(KEY_DOWN):
		v.y -= 1.0
	if key(KEY_D) or key(KEY_RIGHT):
		v.x += 1.0
	if key(KEY_A) or key(KEY_LEFT):
		v.x -= 1.0
	return v


## Alt sınıflar bunu uygular.
func mission_process(_delta: float) -> void:
	pass
