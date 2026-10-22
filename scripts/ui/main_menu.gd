extends Node3D
## Ana menü: arka planda yavaşça dönen kamera ile boğaz; kampanya, yükseltmeler ve ayarlar.

var world: StraitWorld
var cam: Camera3D
var ui: Control
var _screen: Control
var _t := 0.0


func _ready() -> void:
	world = StraitWorld.new()
	add_child(world)
	world.build(false)
	cam = Camera3D.new()
	cam.far = 6000.0
	cam.fov = 55.0
	add_child(cam)
	cam.current = true
	_add_scenery_ships()
	var layer := CanvasLayer.new()
	add_child(layer)
	ui = Control.new()
	ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.theme = UiTheme.get_theme()
	layer.add_child(ui)
	Sfx.start_loop("sea", -18.0)
	show_main()


func _exit_tree() -> void:
	Sfx.stop_all_loops()


func _add_scenery_ships() -> void:
	var tr := ShipBuilder.build_nusret()
	var n: Node3D = tr["root"]
	add_child(n)
	n.position = Vector3(170, 0, 40)
	n.rotation.y = 2.6
	Fx.smoke_column(n, (tr["funnels"][0] as Node3D).position, 0.1, 0.6, 10)
	for i in 3:
		var s := ShipBuilder.build_battleship("uk" if i != 1 else "fr", 75.0, 13.0, 2)
		var r: Node3D = s["root"]
		add_child(r)
		r.position = Vector3(-700.0 - i * 160.0, 0, -60.0 + i * 70.0)
		for f in s["funnels"]:
			Fx.smoke_column(r, (f as Node3D).position, 0.14, 2.0, 18)


func _process(delta: float) -> void:
	_t += delta * 0.03
	# Kamera boğazın üzerinde süzülür ve Ege'ye doğru bakar.
	cam.global_position = Vector3(60.0 + sin(_t) * 160.0, 70.0 + sin(_t * 1.3) * 15.0, sin(_t * 0.8) * 70.0)
	cam.look_at(Vector3(-650.0, 0.0, 30.0 + sin(_t * 0.6) * 120.0))


func _clear() -> VBoxContainer:
	if _screen:
		_screen.queue_free()
	_screen = Control.new()
	_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	ui.add_child(_screen)
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.25)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screen.add_child(shade)
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	_screen.add_child(cc)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 14)
	cc.add_child(box)
	return box


func show_main() -> void:
	var box := _clear()
	box.add_child(UiTheme.label("TÜRK HARP", 96, UiTheme.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(UiTheme.label("Çanakkale 1915", 30, UiTheme.TEXT, HORIZONTAL_ALIGNMENT_CENTER))
	var spacer := Control.new()
	spacer.custom_minimum_size.y = 20
	box.add_child(spacer)
	for item in [["Kampanya", show_campaign], ["Ayarlar", show_settings], ["Hakkında", show_about]]:
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
	head.add_child(UiTheme.label("Çanakkale Seferi", 42, UiTheme.GOLD))
	head.add_child(UiTheme.label("Şeref: %d" % GameState.honor, 28, UiTheme.TEXT))
	box.add_child(head)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	box.add_child(row)
	for m in GameState.MISSIONS:
		row.add_child(_mission_card(m))
	box.add_child(UiTheme.label("Yükseltmeler", 28, UiTheme.GOLD))
	var ups := HBoxContainer.new()
	ups.add_theme_constant_override("separation", 12)
	box.add_child(ups)
	for key in GameState.UPGRADES:
		ups.add_child(_upgrade_card(key))
	var cc := CenterContainer.new()
	cc.add_child(UiTheme.button("Geri", show_main, 220))
	box.add_child(cc)


func _mission_card(m: Dictionary) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(290, 330)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	panel.add_child(v)
	var unlocked := GameState.is_unlocked(m["id"])
	var ready_scene: bool = m["scene"] != ""
	v.add_child(UiTheme.label(m["date"], 16, UiTheme.MUTED))
	var title := UiTheme.wrap_label(m["title"], 24, UiTheme.GOLD if unlocked else UiTheme.MUTED, 250)
	v.add_child(title)
	v.add_child(StarRow.new(GameState.stars.get(m["id"], 0), 24.0))
	var summary := UiTheme.wrap_label(m["summary"], 15, UiTheme.TEXT if unlocked else UiTheme.MUTED, 250)
	summary.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(summary)
	var label := "Başla"
	if not ready_scene:
		label = "Yakında"
	elif not unlocked:
		label = "Kilitli"
	var b := UiTheme.button(label, func() -> void: get_tree().change_scene_to_file(m["scene"]), 250)
	b.disabled = not (unlocked and ready_scene)
	v.add_child(b)
	return panel


func _upgrade_card(key: String) -> Control:
	var info: Dictionary = GameState.UPGRADES[key]
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(220, 0)
	var v := VBoxContainer.new()
	panel.add_child(v)
	var lvl := GameState.upgrade_level(key)
	var costs: Array = info["costs"]
	v.add_child(UiTheme.label("%s  %d/%d" % [info["title"], lvl, costs.size()], 17, UiTheme.GOLD))
	v.add_child(UiTheme.wrap_label(info["desc"], 14, UiTheme.MUTED, 190))
	var cost := GameState.upgrade_cost(key)
	var b := UiTheme.button("Tamam" if cost < 0 else "Al (%d)" % cost, func() -> void:
		if GameState.buy_upgrade(key):
			show_campaign(), 190)
	b.custom_minimum_size.y = 42
	b.add_theme_font_size_override("font_size", 17)
	b.disabled = cost < 0 or GameState.honor < cost
	v.add_child(b)
	return panel


func show_settings() -> void:
	var box := _clear()
	box.add_child(UiTheme.label("Ayarlar", 42, UiTheme.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	var q := UiTheme.button("Grafik: " + ("Yüksek" if GameState.high_quality() else "Düşük"), func() -> void:
		GameState.settings["quality"] = "low" if GameState.high_quality() else "high"
		GameState.save_game()
		get_tree().reload_current_scene(), 380)
	box.add_child(q)
	box.add_child(UiTheme.label("Ses", 20, UiTheme.TEXT))
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.05
	slider.value = GameState.settings.get("sfx", 0.8)
	slider.custom_minimum_size = Vector2(380, 30)
	slider.value_changed.connect(func(v: float) -> void:
		GameState.settings["sfx"] = v
		GameState.save_game())
	box.add_child(slider)
	box.add_child(UiTheme.button("İlerlemeyi Sıfırla", func() -> void:
		GameState.reset_progress()
		show_main(), 380))
	box.add_child(UiTheme.button("Geri", show_main, 380))


func show_about() -> void:
	var box := _clear()
	box.add_child(UiTheme.label("Türk Harp", 42, UiTheme.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(UiTheme.wrap_label("Türk tarihinin gerçek savaşlarını konu alan ücretsiz ve açık kaynak bir oyun. Kod GPL-3.0, tarihî içerik CC BY-SA 4.0 lisanslıdır.\n\nKaynaklar: Genelkurmay Başkanlığı, Birinci Dünya Harbi'nde Türk Harbi, Çanakkale Cephesi Harekâtı; Edward J. Erickson, Gallipoli: The Ottoman Campaign.\n\ngithub.com/sertacgul/Turk-Harp", 19, UiTheme.TEXT, 700))
	var cc := CenterContainer.new()
	cc.add_child(UiTheme.button("Geri", show_main, 220))
	box.add_child(cc)
