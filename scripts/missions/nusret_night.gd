extends MissionBase
## 7-8 Mart 1915 gecesi: Nusret ışıklarını söndürüp Erenköy Koyu'na mayın döşer.
## Düşman ışıldaklarına yakalanmadan mayınları bırak ve Çanakkale'ye dön.

const MAX_SPEED := 15.0
const TURN_RATE := 0.55
const MINE_COUNT := 26
const MIN_MINES := 15
const ZONE_RADIUS := 175.0
const MINE_SPACING := 9.0
const DROP_COOLDOWN := 0.9
const DOCK := Vector3(330.0, 0.0, 110.0)

var boat: Node3D
var boat_model: Node3D
var boat_parts: Dictionary
var heading := PI
var speed := 0.0
var throttle := 0.0
var cam: Camera3D
var zone_center: Vector3
var laid: Array[Vector3] = []
var drop_cd := 0.0
var detection := 0.0
var max_detection := 0.0
var patrols: Array = []
var _cam_yaw_offset := 0.0

var _joy: VirtualJoystick
var _drop_btn: Button
var _det_bar: ProgressBar
var _map: MiniMap
var _vignette: ColorRect
var _alarm_cd := 0.0
var _autoplay := false


func _ready() -> void:
	setup("nusret", true)
	zone_center = StraitWorld.bay_zone_center()
	_build_boat()
	_build_zone()
	_build_patrols()
	_build_controls()
	cam = Camera3D.new()
	cam.fov = 65.0
	cam.far = 5000.0
	add_child(cam)
	cam.current = true
	_update_camera(1.0)
	Sfx.listener = cam
	set_objective("Brifing")
	show_briefing("Nusret'in Gecesi", "7-8 Mart 1915 · Erenköy Koyu",
		"Müttefik gemileri her gece boğazı ışıldaklarla tarıyor. Nusret mayın gemisi tüm ışıklarını söndürerek Erenköy Koyu'na süzülecek ve kıyıya paralel %d mayın döşeyecek. Bu mayınlar 18 Mart'ta düşman zırhlılarının kaderini belirleyecek." % MINE_COUNT,
		["W/S ya da sol kol: hız · A/D: dümen · Boşluk ya da MAYIN: mayın bırak",
		"Işıldak huzmesine yakalanırsan tespit çubuğu dolar; dolarsa görev başarısız olur.",
		"Altın çember içindeki koya en az %d mayın bırak, sonra Çanakkale'ye (yeşil çember) dön." % MIN_MINES,
		"Bu görevde bıraktığın mayınlar 18 Mart görevinde aynı yerde olacak.",
		"Komutan: Tophaneli Hakkı Bey. Mayın uzmanı: Nazmi Bey."])
	mission_started.connect(func() -> void:
		Sfx.start_loop("engine", -14.0)
		banner("IŞIKLAR SÖNDÜRÜLDÜ", "Nusret Erenköy Koyu'na doğru", 3.5))


func _build_boat() -> void:
	boat_parts = ShipBuilder.build_nusret()
	boat = Node3D.new()
	add_child(boat)
	boat_model = boat_parts["root"]
	boat.add_child(boat_model)
	boat.global_position = DOCK
	boat.rotation.y = heading
	Fx.wake(boat_model, Vector3(-boat_parts["length"] * 0.5, 0.3, 0), 0.8)
	Fx.smoke_column(boat_model, (boat_parts["funnels"][0] as Node3D).position, 0.06, 0.6, 10)


func _build_zone() -> void:
	var ring := MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = ZONE_RADIUS - 2.0
	t.outer_radius = ZONE_RADIUS + 2.0
	t.rings = 64
	ring.mesh = t
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(0.9, 0.72, 0.28, 0.35)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring.material_override = m
	ring.position = zone_center + Vector3(0, 0.6, 0)
	add_child(ring)
	var dock := MeshInstance3D.new()
	var dt := TorusMesh.new()
	dt.inner_radius = 48.0
	dt.outer_radius = 52.0
	dock.mesh = dt
	var dm := m.duplicate() as StandardMaterial3D
	dm.albedo_color = Color(0.4, 0.95, 0.5, 0.35)
	dock.material_override = dm
	dock.position = DOCK + Vector3(0, 0.6, 0)
	add_child(dock)


func _build_patrols() -> void:
	var routes := [
		[Vector3(-1250, 0, -120), Vector3(-700, 0, -80)],
		[Vector3(-1000, 0, 140), Vector3(-560, 0, 40)],
		[Vector3(-850, 0, -40), Vector3(-1350, 0, 60)],
	]
	for i in routes.size():
		var parts := ShipBuilder.build_destroyer("uk" if i != 1 else "fr")
		var root := Node3D.new()
		add_child(root)
		root.add_child(parts["root"])
		root.global_position = routes[i][0]
		var sl: Node3D = parts["searchlight"]
		var light := SpotLight3D.new()
		light.spot_range = 950.0
		light.spot_angle = 7.0
		light.spot_attenuation = 0.6
		light.light_energy = 14.0
		light.light_color = Color(0.92, 0.95, 1.0)
		light.shadow_enabled = false
		sl.add_child(light)
		var beam := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.6
		cyl.bottom_radius = tan(deg_to_rad(4.5)) * 600.0
		cyl.height = 600.0
		cyl.radial_segments = 20
		cyl.cap_top = false
		cyl.cap_bottom = false
		var bm := ShaderMaterial.new()
		bm.shader = load("res://shaders/searchlight_beam.gdshader")
		cyl.material = bm
		beam.mesh = cyl
		beam.rotation.x = -PI / 2.0
		beam.position = Vector3(0, 0, -300.0)
		beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		sl.add_child(beam)
		Fx.smoke_column(parts["root"], (parts["funnels"][0] as Node3D).position, 0.05, 0.6, 8)
		patrols.append({"root": root, "parts": parts, "light": sl, "route": routes[i], "leg": 1, "phase": i * 2.1, "speed": 9.0 + i})


func _build_controls() -> void:
	_joy = VirtualJoystick.new()
	_joy.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_joy.position = Vector2(30, -250)
	ui.add_child(_joy)
	var right := VBoxContainer.new()
	right.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	right.position = Vector2(-300, -200)
	right.add_theme_constant_override("separation", 10)
	ui.add_child(right)
	right.add_child(UiTheme.label("Tespit", 18, UiTheme.MUTED, HORIZONTAL_ALIGNMENT_RIGHT))
	_det_bar = UiTheme.bar(Color(0.9, 0.3, 0.25), 280, 14)
	right.add_child(_det_bar)
	_drop_btn = UiTheme.button("MAYIN BIRAK", drop_mine, 280)
	_drop_btn.custom_minimum_size.y = 100
	_drop_btn.add_theme_font_size_override("font_size", 30)
	right.add_child(_drop_btn)
	_map = MiniMap.new()
	_map.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_map.position = Vector2(20, 60)
	_map.zone_center = zone_center
	_map.zone_radius = ZONE_RADIUS
	_map.dock_center = DOCK
	ui.add_child(_map)
	_vignette = ColorRect.new()
	_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vignette.color = Color(0.8, 0.05, 0.05, 0.0)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(_vignette)
	ui.move_child(_vignette, 0)


func _unhandled_input(event: InputEvent) -> void:
	if not running:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE:
		drop_mine()
	if event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_RIGHT:
		_cam_yaw_offset -= event.relative.x * 0.004


func drop_mine() -> void:
	if not running or drop_cd > 0.0 or laid.size() >= MINE_COUNT:
		return
	var p := boat_model.to_global(Vector3(-boat_parts["length"] * 0.5 - 2.0, 0, 0))
	p.y = 0.0
	if Vector2(p.x - zone_center.x, p.z - zone_center.z).length() > ZONE_RADIUS:
		message("Mayınlar yalnızca Erenköy Koyu'na bırakılmalı.", Color(1, 0.7, 0.4))
		return
	for m in laid:
		if m.distance_to(p) < MINE_SPACING:
			message("Mayınlar arasında aralık bırak; ilerle.", UiTheme.MUTED)
			return
	drop_cd = DROP_COOLDOWN
	laid.append(p)
	var mine := ShipBuilder.build_mine()
	add_child(mine)
	mine.global_position = p + Vector3(0, 1.5, 0)
	var tw := mine.create_tween()
	tw.tween_property(mine, "global_position:y", -1.2, 1.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	Fx.water_splash(self, p, 0.25)
	Sfx.play("mine_drop", -4.0)
	_map.mines = laid
	if laid.size() == MIN_MINES:
		banner("%d MAYIN DÖŞENDİ" % MIN_MINES, "Devam edebilir ya da Çanakkale'ye dönebilirsin", 3.5)
	elif laid.size() == MINE_COUNT:
		banner("26 MAYIN TAMAM", "Şimdi sessizce Çanakkale'ye dön", 3.5)


func mission_process(delta: float) -> void:
	_update_patrols(delta)
	if running:
		_update_boat(delta)
		_update_detection(delta)
		drop_cd = maxf(drop_cd - delta, 0.0)
		_check_end()
	_update_camera(delta)
	_update_hud()


## Geliştirme ve test için otomatik pilot.
func debug_autoplay() -> void:
	_autoplay = true


func debug_status() -> void:
	print("t=%d mines=%d det=%d maxdet=%d pos=%s finished=%s" % [elapsed, laid.size(), detection, max_detection, boat.global_position.round(), finished])


func _autopilot() -> Vector2:
	var goal := DOCK
	if laid.size() >= MINE_COUNT and boat.global_position.x < -100.0:
		goal = Vector3(-60.0, 0.0, 60.0)
	if laid.size() < MINE_COUNT:
		var k := float(laid.size()) / MINE_COUNT
		goal = zone_center + Vector3(lerpf(-140.0, 140.0, 1.0 - k), 0, 10.0)
		if laid.is_empty() and boat.global_position.x > -150.0:
			goal = Vector3(-200.0, 0.0, 90.0)
		if Vector2(boat.global_position.x - zone_center.x, boat.global_position.z - zone_center.z).length() < ZONE_RADIUS - 10.0:
			drop_mine()
	var to := goal - boat.global_position
	var want := atan2(-to.z, to.x)
	var turn := clampf(angle_difference(heading, want) * 2.0, -1.0, 1.0)
	return Vector2(-turn, -1.0 if to.length() > 30.0 else -0.3)


func _update_boat(delta: float) -> void:
	var t := _joy.output.y * -1.0
	var r := -_joy.output.x
	if _autoplay:
		var a := _autopilot()
		r = -a.x
		t = -a.y
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		t = 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		t = -0.4
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		r = 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		r = -1.0
	throttle = move_toward(throttle, clampf(t, -0.4, 1.0), delta * 0.8)
	speed = move_toward(speed, throttle * MAX_SPEED, delta * 3.0)
	heading += r * TURN_RATE * delta * clampf(absf(speed) / 6.0, 0.15, 1.0) * signf(speed if absf(speed) > 0.1 else 1.0)
	var fwd := Vector3(cos(heading), 0, -sin(heading))
	var next := boat.global_position + fwd * speed * delta
	var probe := next + fwd * 20.0 * signf(speed)
	if StraitWorld.is_water(probe.x, probe.z):
		boat.global_position = next
	else:
		speed *= 0.5
	boat.rotation.y = heading
	boat_model.position.y = sin(elapsed * 1.1) * 0.25
	boat_model.rotation.z = sin(elapsed * 0.9) * 0.03 - r * 0.04 * absf(speed) / MAX_SPEED
	Sfx.set_loop_volume("engine", -20.0 + absf(throttle) * 8.0)


func _update_patrols(delta: float) -> void:
	var enemies := []
	for p in patrols:
		var root: Node3D = p["root"]
		var route: Array = p["route"]
		var target: Vector3 = route[p["leg"]]
		var to := target - root.global_position
		if to.length() < 20.0:
			p["leg"] = 1 - int(p["leg"])
		var want := atan2(-to.z, to.x)
		root.rotation.y = lerp_angle(root.rotation.y, want, delta * 0.3)
		root.global_position += Vector3(cos(root.rotation.y), 0, -sin(root.rotation.y)) * float(p["speed"]) * delta
		var sl: Node3D = p["light"]
		p["phase"] = float(p["phase"]) + delta * 0.35
		# Işıldak geminin kıyı tarafını ve önünü tarar.
		sl.rotation.y = -PI / 2.0 + sin(float(p["phase"])) * 1.4
		sl.rotation.x = deg_to_rad(-3.5)
		enemies.append({"pos": root.global_position, "dir": -sl.global_basis.z})
	if _map:
		_map.enemies = enemies


func _update_detection(delta: float) -> void:
	var lit := false
	var target := boat.global_position + Vector3(0, 3, 0)
	for p in patrols:
		var sl: Node3D = p["light"]
		var to := target - sl.global_position
		var d := to.length()
		if d > 900.0:
			continue
		var ang := rad_to_deg((-sl.global_basis.z).angle_to(to))
		if ang < 9.0:
			lit = true
			detection += delta * (55.0 * (1.0 - d / 900.0) + 18.0)
	if not lit:
		detection = maxf(detection - delta * 8.0, 0.0)
	detection = minf(detection, 100.0)
	max_detection = maxf(max_detection, detection)
	_vignette.color.a = 0.25 * detection / 100.0 if lit else move_toward(_vignette.color.a, 0.0, delta)
	_alarm_cd -= delta
	if lit and _alarm_cd <= 0.0:
		_alarm_cd = 1.4
		Sfx.play("alarm", -10.0)
		message("Işıldak huzmesindesin!", Color(1, 0.5, 0.4))


func _update_camera(delta: float) -> void:
	var back := Vector3(-cos(heading + _cam_yaw_offset), 0, sin(heading + _cam_yaw_offset))
	var want := boat.global_position + back * 55.0 + Vector3(0, 20.0, 0)
	cam.global_position = cam.global_position.lerp(want, clampf(delta * 3.0, 0.0, 1.0))
	cam.look_at(boat.global_position + Vector3(0, 6, 0) - back * 30.0)


func _update_hud() -> void:
	var in_zone := Vector2(boat.global_position.x - zone_center.x, boat.global_position.z - zone_center.z).length() < ZONE_RADIUS
	var goal := "Erenköy Koyu'na git (altın çember)"
	if in_zone:
		goal = "Mayın bırak"
	if laid.size() >= MIN_MINES:
		goal = "Çanakkale'ye dön (yeşil çember)" if laid.size() >= MINE_COUNT or not in_zone else "Mayın bırak ya da Çanakkale'ye dön"
	set_objective("Mayın: %d/%d   ·   %s" % [laid.size(), MINE_COUNT, goal])
	_det_bar.value = detection
	_drop_btn.disabled = not in_zone or laid.size() >= MINE_COUNT or drop_cd > 0.0
	_map.player_pos = boat.global_position
	_map.player_heading = heading
	_map.queue_redraw()


func _check_end() -> void:
	if detection >= 100.0:
		finish(false, 0, 0, ["Nusret düşman ışıldaklarına yakalandı.", "Huzmelerin döngüsünü izle; karanlık aralıklarda ilerle ve kıyıya yakın dur."])
		return
	if laid.size() >= MIN_MINES and boat.global_position.distance_to(DOCK) < 50.0:
		GameState.laid_mines = laid.duplicate()
		var st := 1 + (1 if laid.size() >= 22 else 0) + (1 if max_detection < 50.0 else 0)
		finish(true, st, 3 + laid.size() / 5 + st * 2, [
			"%d mayın Erenköy Koyu'na döşendi." % laid.size(),
			"Tarihte Nusret 26 mayın döşedi ve fark edilmeden döndü. Müttefikler bu hattı keşfedemedi.",
			"Bu mayınlar 18 Mart görevinde senin bıraktığın yerlerde olacak."])
