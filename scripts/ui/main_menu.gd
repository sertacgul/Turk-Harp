extends Node3D
## Ana menü: arka planda yavaşça dönen Gelibolu Yarımadası kabartma haritası; senaryolar ve ayarlar.

var map: ReliefMap
var cam: Camera3D
var ui: Control
var _screen: Control
var _t := 0.0


func _ready() -> void:
	var geo := GeoMap.open("gelibolu")
	var grid := HexGrid.new()
	grid.setup(geo, 3000.0)
	map = ReliefMap.new()
	add_child(map)
	map.build(geo, grid, 120.0, 3.2, 180)
	map.mat.set_shader_parameter("grid_alpha", 0.0)
	for p in [["Conkbayırı", 40.2520, 26.3086], ["Arıburnu", 40.2400, 26.2680], ["Seddülbahir", 40.0447, 26.1889],
			["Kilitbahir", 40.1478, 26.3793], ["Çanakkale", 40.1463, 26.4029], ["Alçıtepe", 40.0949, 26.2273]]:
		map.add_place_label(p[0], geo.local(p[1], p[2]), 1.3)
	ReliefMap.add_lighting(self, 120.0)
	cam = Camera3D.new()
	cam.fov = 40.0
	cam.far = 1000.0
	add_child(cam)
	cam.current = true
	var layer := CanvasLayer.new()
	add_child(layer)
	ui = Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.theme = UiTheme.get_theme()
	layer.add_child(ui)
	Sfx.start_loop("sea", -24.0)
	Sfx.start_loop("wind", -20.0)
	show_main()


func _exit_tree() -> void:
	Sfx.stop_all_loops()


func _process(delta: float) -> void:
	_t += delta * 0.04
	var r := 115.0
	cam.global_position = Vector3(sin(_t) * r, 62.0, cos(_t) * r)
	cam.look_at(Vector3(0, -4, 0))


func _clear() -> VBoxContainer:
	if _screen:
		_screen.queue_free()
	_screen = Control.new()
	_screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(_screen)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.35)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screen.add_child(shade)
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_screen.add_child(cc)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 10)
	cc.add_child(box)
	return box


func show_main() -> void:
	var box := _clear()
	box.add_child(UiTheme.title("TÜRK HARP", 110, UiTheme.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(UiTheme.label("Çanakkale 1915 · Harekât Haritası", 28, UiTheme.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 20
	box.add_child(spacer)
	for item in [["Oyuna Başla", show_campaign], ["Ayarlar", show_settings], ["Hakkında", show_about]]:
		var cc := CenterContainer.new()
		cc.add_child(UiTheme.button(item[0], item[1], 320))
		box.add_child(cc)
	if not OS.has_feature("mobile") and not OS.has_feature("web"):
		var cc := CenterContainer.new()
		cc.add_child(UiTheme.button("Çıkış", get_tree().quit, 320))
		box.add_child(cc)


func show_campaign() -> void:
	var box := _clear()
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 30)
	head.add_child(UiTheme.title("Çanakkale Seferi · 1915", 44, UiTheme.GOLD))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(spacer)
	var back := UiTheme.button("Geri", show_main, 160)
	back.custom_minimum_size.y = 46
	head.add_child(back)
	box.add_child(head)
	box.add_child(_difficulty_row())
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	box.add_child(row)
	for path: String in GameState.SCENARIOS:
		if FileAccess.file_exists(path):
			row.add_child(_scenario_card(GameState.scenario_meta(path)))


func _difficulty_row() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.add_child(UiTheme.label("Zorluk:", 22, UiTheme.TEXT))
	for key in GameState.DIFFICULTIES:
		var b := UiTheme.button(GameState.DIFFICULTIES[key]["title"], func() -> void:
			GameState.set_difficulty(key)
			show_campaign(), 150)
		b.custom_minimum_size.y = 44
		if key == GameState.difficulty():
			var sel := UiTheme._box(UiTheme.GOLD.darkened(0.25), UiTheme.GOLD, 3)
			b.add_theme_stylebox_override("normal", sel)
			b.add_theme_stylebox_override("hover", sel)
			b.add_theme_color_override("font_color", Color(0.08, 0.06, 0.03))
			b.add_theme_color_override("font_hover_color", Color(0.08, 0.06, 0.03))
		row.add_child(b)
	var hint := {"kolay": "Düşman ateşi zayıf, birliklerin güçlü", "normal": "Tarihî denge", "zor": "Düşman ateşi daha etkili"}
	row.add_child(UiTheme.label("  " + hint[GameState.difficulty()], 17, UiTheme.MUTED))
	return row


func _scenario_card(m: Dictionary) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(330, 340)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)
	var unlocked := GameState.is_unlocked(m)
	v.add_child(UiTheme.wrap_label(m.get("subtitle", ""), 14, UiTheme.MUTED, 290))
	v.add_child(UiTheme.wrap_label(m.get("title", ""), 24, UiTheme.GOLD if unlocked else UiTheme.MUTED, 290))
	v.add_child(StarRow.new(GameState.stars.get(m.get("id", ""), 0), 24.0))
	var summary := UiTheme.wrap_label(m.get("summary", ""), 15, UiTheme.TEXT if unlocked else UiTheme.MUTED, 290)
	summary.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(summary)
	var b := UiTheme.button("Başla" if unlocked else "Kilitli", func() -> void:
		GameState.current_scenario = m["path"]
		get_tree().change_scene_to_file("res://scenes/battle.tscn"), 290)
	b.disabled = not unlocked
	v.add_child(b)
	return panel


func show_settings() -> void:
	var box := _clear()
	box.add_child(UiTheme.title("Ayarlar", 46, UiTheme.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(UiTheme.button("Grafik: " + ("Yüksek" if GameState.high_quality() else "Düşük"), func() -> void:
		GameState.settings["quality"] = "low" if GameState.high_quality() else "high"
		GameState.save_game()
		GameState.apply_render_settings()
		show_settings(), 380))
	box.add_child(UiTheme.button("Zorluk: " + GameState.difficulty_title(), func() -> void:
		var keys := GameState.DIFFICULTIES.keys()
		GameState.set_difficulty(keys[(keys.find(GameState.difficulty()) + 1) % keys.size()])
		show_settings(), 380))
	box.add_child(UiTheme.label("Ses", 20, UiTheme.TEXT))
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = GameState.settings.get("sfx", 0.8)
	slider.custom_minimum_size = Vector2(380, 30)
	slider.value_changed.connect(func(val: float) -> void:
		GameState.settings["sfx"] = val
		GameState.save_game())
	box.add_child(slider)
	box.add_child(UiTheme.button("İlerlemeyi Sıfırla", func() -> void:
		GameState.reset_progress()
		show_main(), 380))
	box.add_child(UiTheme.button("Geri", show_main, 380))


func show_about() -> void:
	var box := _clear()
	box.add_child(UiTheme.title("Türk Harp", 46, UiTheme.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(UiTheme.wrap_label("Türk tarihinin gerçek savaşlarını gerçek haritalar üzerinde canlandıran, ücretsiz ve açık kaynak bir sıra tabanlı strateji oyunu. Kod GPL-3.0, tarihî içerik CC BY-SA 4.0 lisanslıdır.\n\nHarita: SRTM tabanlı yükseklik verisi (AWS Terrain Tiles / Mapzen). Yer adları: OpenStreetMap katkıcıları.\n\nKaynaklar: Genelkurmay Başkanlığı, Birinci Dünya Harbi'nde Türk Harbi, Çanakkale Cephesi Harekâtı; Edward J. Erickson, Gallipoli: The Ottoman Campaign; C. E. W. Bean, Official History of Australia in the War of 1914-1918, Cilt I.\n\ngithub.com/sertacgul/Turk-Harp", 18, UiTheme.TEXT, 760))
	var cc := CenterContainer.new()
	cc.add_child(UiTheme.button("Geri", show_main, 220))
	box.add_child(cc)
