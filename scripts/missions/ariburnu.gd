extends MissionBase
## 25 Nisan 1915, Arıburnu: 57. Alay'ın bir subayı olarak Conkbayırı'nı savun, bölüklere emir ver
## ve Mustafa Kemal'in taarruz emriyle Cesaret Tepe ile Kırmızı Sırt'ı geri al.

const RIFLE_RANGE := 230.0
const PLAYER_CLIP := 5
const PLAYER_RELOAD := 2.6
const PLAYER_BOLT := 1.0
const PLAYER_SPEED := 4.2
const PLAYER_RUN := 6.8
const MELEE_RANGE := 2.6
const DEFENSE_END := 180.0
const TIME_LIMIT := 600.0
const CAPTURE_RADIUS := 40.0
const CAPTURE_TIME := 8.0

const OTTOMAN := 0
const ANZAC := 1

## ANZAC dalgaları: zaman, asker sayısı, çıkış noktası, hedef mevzi.
const WAVES := [
	[22.0, 10, Vector3(160, 0, -70), "conk"],
	[50.0, 12, Vector3(120, 0, -200), "conk"],
	[85.0, 12, Vector3(150, 0, 30), "conk"],
	[120.0, 14, Vector3(90, 0, -130), "conk"],
	[155.0, 14, Vector3(130, 0, -10), "conk"],
	[215.0, 8, Vector3(-60, 0, 110), "kirmizi"],
	[255.0, 8, Vector3(-60, 0, -40), "cesaret"],
	[330.0, 10, Vector3(-80, 0, 20), "nearest"],
	[420.0, 10, Vector3(-80, 0, 80), "nearest"],
]


class Soldier:
	var side := 0
	var root: Node3D
	var model: Node3D
	var muzzle: Marker3D
	var rig: HumanRig
	var jab := 0.0
	var aim := 0.0
	var hp := 100.0
	var squad: Squad
	var goal := Vector3.ZERO
	var enemy: Soldier
	var fire_cd := 0.0
	var think_cd := 0.0
	var melee_cd := 0.0
	var dead_t := -1.0
	var speed := 3.0
	var walk := 0.0
	var no_ammo := false
	var is_player := false
	var invulnerable := false

	func alive() -> bool:
		return hp > 0.0

	func pos() -> Vector3:
		return root.position


class Squad:
	var title := ""
	var side := 0
	var soldiers: Array[Soldier] = []
	var order := "hold"
	var target := Vector3.ZERO
	var objective := ""
	var label: Label3D
	var retreating := false

	func alive_count() -> int:
		var n := 0
		for s in soldiers:
			if s.alive():
				n += 1
		return n

	func center() -> Vector3:
		var c := Vector3.ZERO
		var n := 0
		for s in soldiers:
			if s.alive():
				c += s.pos()
				n += 1
		return c / n if n > 0 else target


var land: PeninsulaWorld
var ottomans: Array[Soldier] = []
var anzacs: Array[Soldier] = []
var squads: Array[Squad] = []
var objectives := {}
var player: Soldier
var kemal: Soldier
var selected := 0
var phase := 1
var lives := 3
var kills := 0
var respawn_t := 0.0
var _events: Array = []
var _wave_i := 0
var _naval_cd := 30.0
var _ships: Array[Node3D] = []

var cam: Camera3D
var tactical_cam: Camera3D
var tactical := false
var yaw := PI / 2.0
var pitch := -0.08
var aiming := false
var clip := PLAYER_CLIP
var reload_t := 0.0
var bolt_t := 0.0
var last_hit_t := -100.0
var _touch_mode := false
var _cursor_free := false
var _look_touch := -1
var _tracers: Array[MeshInstance3D] = []
var _tracer_i := 0
var _autoplay := false

var _stick: TouchStick
var _hp_bar: ProgressBar
var _ammo_label: Label
var _squad_btns: Array[Button] = []
var _charge_btn: Button
var _map_btn: Button
var _crosshair: Control
var _rng2 := RandomNumberGenerator.new()


func _ready() -> void:
	setup("ariburnu", false, false)
	_rng2.randomize()
	_touch_mode = DisplayServer.is_touchscreen_available()
	lives = int(round(3.0 / GameState.diff("enemy_damage")))
	land = PeninsulaWorld.new()
	add_child(land)
	land.build()
	_build_objectives()
	_build_ships()
	_build_tracers()
	_spawn_player()
	_spawn_kemal()
	_build_ottoman_squads()
	_spawn_enemy_garrisons()
	_build_cameras()
	_build_controls()
	_build_events()
	Sfx.listener = cam
	set_objective("Brifing")
	show_briefing("Arıburnu: 57. Alay", "25 Nisan 1915 · Arıburnu, Conkbayırı",
		"Şafakta İtilaf Devletleri'nin ANZAC birlikleri Arıburnu'na çıktı ve sırtlara tırmanıyor. 19. Tümen Komutanı Yarbay Mustafa Kemal, 57. Alay'ı Conkbayırı'na yetiştiriyor. Sen alayın bir subayısın: önce Conkbayırı'nı tut, sonra taarruz emriyle Cesaret Tepe ve Kırmızı Sırt'ı geri al.",
		["Hareket: W/A/S/D, yön tuşları ya da sol kol · Bakış: fare ya da ekranı sürükle · Koşu: Shift",
		"Ateş: sol tık ya da ATEŞ · Nişan: sağ tık ya da NİŞAN · Doldur: R · Süngü: F (yakın dövüş)",
		"Bölük seç: 1-6 · Q: beni izle · E: nişan aldığın yerde mevzi tut · M: harita · Alt: imleci açıp düğmelere tıkla",
		"Conkbayırı düşerse görev başarısız olur. Canın: %d." % lives,
		"Taraflar: Osmanlı Devleti (İttifak Devletleri) ve ANZAC birlikleri (İtilaf Devletleri)."])
	mission_started.connect(func() -> void:
		banner("25 NİSAN 1915", "Conkbayırı'na yetiş", 3.5)
		_update_mouse())


func _exit_tree() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	super._exit_tree()


# ------------------------------------------------------------------ kurulum

func _build_objectives() -> void:
	var defs := {
		"conk": ["Conkbayırı", PeninsulaWorld.CONKBAYIRI, OTTOMAN],
		"cesaret": ["Cesaret Tepe", PeninsulaWorld.CESARET_TEPE, ANZAC],
		"kirmizi": ["Kırmızı Sırt", PeninsulaWorld.KIRMIZI_SIRT, ANZAC],
	}
	for key in defs:
		var d: Array = defs[key]
		var p := PeninsulaWorld.ground(d[1])
		var pole := MeshInstance3D.new()
		var c := CylinderMesh.new()
		c.top_radius = 0.08
		c.bottom_radius = 0.1
		c.height = 9.0
		pole.mesh = c
		pole.position = p + Vector3(0, 4.5, 0)
		add_child(pole)
		var flag := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(3.0, 2.0)
		q.subdivide_width = 8
		var fm := ShaderMaterial.new()
		fm.shader = load("res://shaders/flag.gdshader")
		q.material = fm
		flag.mesh = q
		flag.position = p + Vector3(1.5, 7.8, 0)
		add_child(flag)
		var label := Label3D.new()
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.fixed_size = true
		label.pixel_size = 0.0012
		label.font_size = 30
		label.outline_size = 10
		label.no_depth_test = true
		label.position = p + Vector3(0, 12, 0)
		add_child(label)
		var owner: int = d[2]
		objectives[key] = {"title": d[0], "pos": p, "owner": owner, "progress": 1.0 if owner == OTTOMAN else -1.0, "flag": fm, "label": label}
		_refresh_objective(key)


func _refresh_objective(key: String) -> void:
	var o: Dictionary = objectives[key]
	var mat: ShaderMaterial = o["flag"]
	mat.set_shader_parameter("flag_texture", ShipBuilder.flag_texture("tr" if o["owner"] == OTTOMAN else "uk"))
	var label: Label3D = o["label"]
	label.text = "%s\n%s" % [o["title"], "Bizde" if o["owner"] == OTTOMAN else "Düşmanda"]
	label.modulate = Color(0.95, 0.85, 0.45) if o["owner"] == OTTOMAN else Color(1.0, 0.5, 0.42)


func _build_ships() -> void:
	for i in 3:
		var s := ShipBuilder.build_battleship("uk", 75.0, 13.0, 2)
		var r: Node3D = s["root"]
		add_child(r)
		r.position = Vector3(-780.0, 0.0, -260.0 + i * 260.0)
		r.rotation.y = PI / 2.0
		for f in s["funnels"]:
			Fx.smoke_column(r, (f as Node3D).position, 0.14, 2.0, 14)
		_ships.append(r)


func _build_tracers() -> void:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(1.0, 0.85, 0.5, 0.7)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var box := BoxMesh.new()
	box.size = Vector3(0.05, 0.05, 1.0)
	box.material = m
	for i in 40:
		var t := MeshInstance3D.new()
		t.mesh = box
		t.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		t.visible = false
		add_child(t)
		_tracers.append(t)


func _new_soldier(kind: String, side: int, at: Vector3) -> Soldier:
	var s := Soldier.new()
	var rig := HumanBuilder.build(kind)
	s.rig = rig
	s.side = side
	s.root = rig.root
	s.model = rig.model
	s.muzzle = rig.muzzle
	add_child(s.root)
	s.root.position = PeninsulaWorld.ground(at)
	s.goal = s.root.position
	s.speed = _rng2.randf_range(2.8, 3.4)
	s.fire_cd = _rng2.randf_range(1.0, 4.0)
	s.think_cd = _rng2.randf_range(0.0, 0.5)
	if side == OTTOMAN:
		ottomans.append(s)
	else:
		anzacs.append(s)
	return s


func _spawn_player() -> void:
	player = _new_soldier("officer", OTTOMAN, PeninsulaWorld.CONKBAYIRI + Vector3(70, 0, -10))
	player.is_player = true
	player.hp = 100.0


func _spawn_kemal() -> void:
	kemal = _new_soldier("kemal", OTTOMAN, PeninsulaWorld.CONKBAYIRI + Vector3(45, 0, -25))
	kemal.invulnerable = true
	kemal.root.rotation.y = PI / 2.0
	ottomans.erase(kemal)
	var l := Label3D.new()
	l.text = "Yarbay Mustafa Kemal"
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.fixed_size = true
	l.pixel_size = 0.001
	l.font_size = 26
	l.outline_size = 8
	l.modulate = Color(0.95, 0.85, 0.5)
	l.position = Vector3(0, 2.4, 0)
	kemal.root.add_child(l)


func _make_squad(title: String, side: int, count: int, at: Vector3, kind: String) -> Squad:
	var q := Squad.new()
	q.title = title
	q.side = side
	q.target = PeninsulaWorld.ground(at)
	for i in count:
		var off := Vector3(_rng2.randf_range(-6, 6), 0, (i - count / 2.0) * 3.0)
		var s := _new_soldier(kind, side, at + off)
		s.squad = q
		q.soldiers.append(s)
	q.label = Label3D.new()
	q.label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	q.label.fixed_size = true
	q.label.pixel_size = 0.001
	q.label.font_size = 24
	q.label.outline_size = 8
	q.label.no_depth_test = true
	q.label.visible = side == OTTOMAN
	add_child(q.label)
	squads.append(q)
	return q


func _build_ottoman_squads() -> void:
	# 57. Alay doğudan, Bigalı yönünden gelir ve Conkbayırı sırtına yayılır.
	var c := PeninsulaWorld.CONKBAYIRI
	var slots := [Vector3(-35, 0, -70), Vector3(-45, 0, -25), Vector3(-45, 0, 20), Vector3(-35, 0, 65)]
	for i in 4:
		var q := _make_squad("%d. Bölük" % (i + 1), OTTOMAN, 10, c + Vector3(110, 0, -60 + i * 40), "ottoman")
		q.order = "move"
		q.target = PeninsulaWorld.ground(c + slots[i])


func _spawn_enemy_garrisons() -> void:
	for key in ["cesaret", "kirmizi"]:
		var q := _make_squad("ANZAC", ANZAC, 8, objectives[key]["pos"] + Vector3(-15, 0, 0), "anzac")
		q.order = "hold"
		q.objective = key


func _build_cameras() -> void:
	cam = Camera3D.new()
	cam.fov = 70.0
	cam.far = 4000.0
	add_child(cam)
	cam.current = true
	tactical_cam = Camera3D.new()
	tactical_cam.fov = 50.0
	tactical_cam.far = 4000.0
	add_child(tactical_cam)
	tactical_cam.position = Vector3(260, 620, 260)
	tactical_cam.look_at(Vector3(160, 60, -30))
	_update_camera()


func _build_controls() -> void:
	_crosshair = Control.new()
	_crosshair.set_anchors_preset(Control.PRESET_CENTER)
	_crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_crosshair.draw.connect(func() -> void:
		var g := 4.0 if aiming else 9.0
		var col := Color(1, 1, 1, 0.85)
		for d in [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]:
			_crosshair.draw_line(d * g, d * (g + 9.0), col, 2.0))
	ui.add_child(_crosshair)

	var left := VBoxContainer.new()
	left.set_anchors_preset(Control.PRESET_TOP_LEFT)
	left.position = Vector2(20, 60)
	left.add_theme_constant_override("separation", 6)
	ui.add_child(left)
	left.add_child(UiTheme.label("Teğmen (sen)", 17, UiTheme.MUTED))
	_hp_bar = UiTheme.bar(Color(0.3, 0.8, 0.4), 220, 12)
	left.add_child(_hp_bar)
	_ammo_label = UiTheme.label("", 20)
	left.add_child(_ammo_label)

	var squad_row := HBoxContainer.new()
	squad_row.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	squad_row.position = Vector2(-330, -70)
	squad_row.add_theme_constant_override("separation", 8)
	ui.add_child(squad_row)
	for i in 6:
		var b := UiTheme.button("%d" % (i + 1), _select_squad.bind(i), 56)
		b.custom_minimum_size.y = 50
		b.visible = i < 4
		squad_row.add_child(b)
		_squad_btns.append(b)
	squad_row.add_child(UiTheme.button("İZLE (Q)", _order_follow, 110))
	squad_row.add_child(UiTheme.button("MEVZİ (E)", _order_hold_here, 120))
	_map_btn = UiTheme.button("HARİTA (M)", toggle_tactical, 140)
	squad_row.add_child(_map_btn)
	for b in squad_row.get_children():
		(b as Button).custom_minimum_size.y = 50
		(b as Button).add_theme_font_size_override("font_size", 18)

	_charge_btn = UiTheme.button("SÜNGÜ HÜCUMU! (H)", order_charge, 300)
	if not _touch_mode:
		var hint := UiTheme.label("Alt: imleci aç/kapat (düğmelere tıklamak için)  ·  Esc: duraklat", 16, UiTheme.MUTED, HORIZONTAL_ALIGNMENT_RIGHT)
		hint.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		hint.position = Vector2(-640, -32)
		hint.custom_minimum_size.x = 620
		ui.add_child(hint)
	_charge_btn.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_charge_btn.position = Vector2(-130, 60)
	_charge_btn.visible = false
	ui.add_child(_charge_btn)

	if _touch_mode:
		_stick = TouchStick.new()
		_stick.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
		_stick.position = Vector2(20, -250)
		ui.add_child(_stick)
		var right := VBoxContainer.new()
		right.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		right.position = Vector2(-230, -330)
		right.add_theme_constant_override("separation", 8)
		ui.add_child(right)
		var fire := UiTheme.button("ATEŞ", fire_player, 210)
		fire.custom_minimum_size.y = 90
		right.add_child(UiTheme.button("NİŞAN", func() -> void: aiming = not aiming, 210))
		right.add_child(UiTheme.button("DOLDUR", _reload, 210))
		right.add_child(UiTheme.button("SÜNGÜ", _melee_player, 210))
		right.add_child(fire)
	_select_squad(0)


func _build_events() -> void:
	var k := "Mustafa Kemal"
	var gold := UiTheme.GOLD
	_events = [
		[4.0, func() -> void: message("%s: \"57. Alay, Conkbayırı'na!\"" % k, gold)],
		[6.0, _spawn_retreaters],
		[10.0, func() -> void: message("%s: \"Niçin kaçıyorsunuz?\"" % k, gold)],
		[11.5, func() -> void: message("Asker: \"Efendim, düşman!\"")],
		[13.0, func() -> void: message("%s: \"Nerede?\"" % k, gold)],
		[14.5, func() -> void: message("Asker: \"İşte!\" (Cesaret Tepe'yi gösterir)")],
		[16.0, func() -> void: message("%s: \"Düşmandan kaçılmaz!\"" % k, gold)],
		[17.5, func() -> void: message("Asker: \"Cephanemiz kalmadı!\"")],
		[19.0, func() -> void: message("%s: \"Cephaneniz yoksa süngünüz var!\"" % k, gold)],
		[20.5, _fix_bayonets],
		[DEFENSE_END, _start_counterattack],
		[DEFENSE_END + 12.0, _reinforce_27],
	]


# ------------------------------------------------------------------ olaylar

func _spawn_retreaters() -> void:
	var q := squads[0]
	for i in 6:
		var s := _new_soldier("ottoman", OTTOMAN, PeninsulaWorld.CESARET_TEPE + Vector3(70, 0, -20 + i * 4))
		s.no_ammo = true
		s.speed = 5.0
		s.goal = PeninsulaWorld.ground(kemal.pos() + Vector3(-8, 0, -6 + i * 2.5))
		s.squad = q
		q.soldiers.append(s)


func _fix_bayonets() -> void:
	banner("SÜNGÜ TAK! YERE YAT!", "Askerler süngü takıp yere yattı; düşman da yere yattı. Kazanılan zaman, 57. Alay'ın yetişmesini sağladı.", 4.5)
	Sfx.play("bugle", -6.0)


func _start_counterattack() -> void:
	phase = 2
	banner("\"Ben size taarruzu emretmiyorum, ölmeyi emrediyorum!\"",
		"\"Biz ölünceye kadar geçecek zaman zarfında yerimize başka kuvvetler ve kumandanlar gelebilir.\" (Mustafa Kemal)", 7.0)
	message("Yeni hedef: Cesaret Tepe ve Kırmızı Sırt'ı geri al. Conkbayırı'nı elde tut (1. ve 2. Bölük sırtta kalır).", UiTheme.GOLD)
	_charge_btn.visible = true
	Sfx.play("bugle", -4.0)


func _reinforce_27() -> void:
	for i in 2:
		var q := _make_squad("27. Alay %d. Bölük" % (i + 1), OTTOMAN, 10, PeninsulaWorld.CONKBAYIRI + Vector3(160, 0, 120 + i * 40), "ottoman")
		q.order = "move"
		q.target = PeninsulaWorld.ground(PeninsulaWorld.CONKBAYIRI + Vector3(-60, 0, 90 + i * 30))
		_squad_btns[4 + i].visible = true
	message("27. Alay yetişti! (Yarbay Mehmet Şefik)", UiTheme.GOLD)


func _spawn_wave(w: Array) -> void:
	var count := int(round(float(w[1]) * (0.85 if GameState.difficulty() == "kolay" else (1.15 if GameState.difficulty() == "zor" else 1.0))))
	var at: Vector3 = w[2]
	var q := _make_squad("ANZAC", ANZAC, count, at, "anzac")
	var key: String = w[3]
	if key == "nearest":
		key = _nearest_ottoman_objective(at)
	q.objective = key
	q.order = "attack"
	q.target = objectives[key]["pos"]


func _nearest_ottoman_objective(from: Vector3) -> String:
	var best := "conk"
	var bd := INF
	for key in objectives:
		if objectives[key]["owner"] == OTTOMAN:
			var d := from.distance_to(objectives[key]["pos"])
			if d < bd:
				bd = d
				best = key
	return best


# ------------------------------------------------------------------ emirler

func _select_squad(i: int) -> void:
	selected = i
	for j in _squad_btns.size():
		_squad_btns[j].modulate = Color(1.4, 1.2, 0.6) if j == i else Color.WHITE


func _ottoman_squads() -> Array[Squad]:
	var out: Array[Squad] = []
	for q in squads:
		if q.side == OTTOMAN:
			out.append(q)
	return out


func _selected_squad() -> Squad:
	var list := _ottoman_squads()
	return list[selected] if selected < list.size() else null


func _order_follow() -> void:
	var q := _selected_squad()
	if q:
		q.order = "follow"
		message("%s seni izliyor" % q.title, UiTheme.MUTED)


func _order_hold_here() -> void:
	var q := _selected_squad()
	if q == null:
		return
	var p := _aim_point()
	q.order = "move"
	q.target = p
	message("%s mevziye ilerliyor" % q.title, UiTheme.MUTED)


func _order_to(q: Squad, p: Vector3, attack: bool) -> void:
	q.order = "attack" if attack else "move"
	q.target = PeninsulaWorld.ground(p)


func order_charge() -> void:
	if phase < 2:
		return
	var targets: Array[String] = []
	for key in ["cesaret", "kirmizi"]:
		if objectives[key]["owner"] != OTTOMAN:
			targets.append(key)
	if targets.is_empty():
		return
	var list := _ottoman_squads()
	for i in list.size():
		if i < 2:
			continue  # 1. ve 2. Bölük Conkbayırı'nda kalır
		var key: String = targets[i % targets.size()]
		_order_to(list[i], objectives[key]["pos"], true)
	banner("SÜNGÜ HÜCUMU!", "Allah Allah!", 2.5)
	Sfx.play("bugle", -2.0)


func toggle_tactical() -> void:
	tactical = not tactical
	tactical_cam.current = tactical
	cam.current = not tactical
	_map_btn.text = "GERİ (M)" if tactical else "HARİTA (M)"
	land.environment.fog_enabled = not tactical
	for q in squads:
		q.label.visible = tactical and q.side == OTTOMAN
	Sfx.listener = tactical_cam if tactical else cam
	_update_mouse()


func toggle_pause() -> void:
	super.toggle_pause()
	_update_mouse()


func _update_mouse() -> void:
	var capture := running and not finished and not tactical and not get_tree().paused and not _touch_mode and not _cursor_free
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if capture else Input.MOUSE_MODE_VISIBLE


# ------------------------------------------------------------------ girdi

func _unhandled_input(event: InputEvent) -> void:
	if not running:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_R:
				_reload()
			KEY_F:
				_melee_player()
			KEY_Q:
				_order_follow()
			KEY_E:
				_order_hold_here()
			KEY_M, KEY_TAB:
				toggle_tactical()
			KEY_H:
				order_charge()
			KEY_ALT:
				# İmleci serbest bırak: alttaki düğmelere tıklanabilir; boş yere tıklayınca bakışa dönülür.
				_cursor_free = not _cursor_free
				_update_mouse()
			_:
				if event.keycode >= KEY_1 and event.keycode <= KEY_6:
					_select_squad(event.keycode - KEY_1)
	if tactical:
		if event is InputEventMouseButton and event.pressed:
			var q := _selected_squad()
			var hit := _map_point(event.position)
			if q and hit != Vector3.INF:
				_order_to(q, hit, event.button_index == MOUSE_BUTTON_RIGHT or phase == 2)
				message("%s: %s" % [q.title, "hücum" if q.order == "attack" else "ilerle"], UiTheme.MUTED)
		return
	if _touch_mode:
		if event is InputEventScreenTouch:
			if event.pressed and _look_touch < 0 and event.position.x > get_viewport().get_visible_rect().size.x * 0.35:
				_look_touch = event.index
			elif not event.pressed and event.index == _look_touch:
				_look_touch = -1
		elif event is InputEventScreenDrag and event.index == _look_touch:
			_look(event.relative * 1.6)
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_look(event.relative)
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
				_cursor_free = false
				_update_mouse()
			else:
				fire_player()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			aiming = event.pressed


func _look(rel: Vector2) -> void:
	var sens := 0.0022 * (0.45 if aiming else 1.0)
	yaw -= rel.x * sens
	pitch = clampf(pitch - rel.y * sens, -1.1, 0.9)


func _map_point(screen: Vector2) -> Vector3:
	var from := tactical_cam.project_ray_origin(screen)
	var dir := tactical_cam.project_ray_normal(screen)
	var p := from
	for i in 400:
		p += dir * 4.0
		if p.y <= PeninsulaWorld.height_at(p.x, p.z):
			return p
	return Vector3.INF


# ------------------------------------------------------------------ oyuncu

func _aim_dir() -> Vector3:
	return -cam.global_basis.z


func _aim_point() -> Vector3:
	var o := cam.global_position
	var d := _aim_dir()
	var p := o
	for i in 200:
		p += d * 3.0
		if p.y <= PeninsulaWorld.height_at(p.x, p.z):
			return PeninsulaWorld.ground(p)
	return PeninsulaWorld.ground(o + d * 120.0)


func _reload() -> void:
	if reload_t > 0.0 or clip >= PLAYER_CLIP or not player.alive():
		return
	reload_t = PLAYER_RELOAD


func fire_player() -> void:
	if not running or not player.alive() or tactical:
		return
	if reload_t > 0.0 or bolt_t > 0.0:
		return
	if clip <= 0:
		_reload()
		return
	clip -= 1
	bolt_t = PLAYER_BOLT
	var spread := 0.004 if aiming else 0.02
	var dir := (_aim_dir() + Vector3(_rng2.randf_range(-spread, spread), _rng2.randf_range(-spread, spread), _rng2.randf_range(-spread, spread))).normalized()
	var origin := cam.global_position
	var hit := _ray_soldier(origin, dir, anzacs)
	var from := player.muzzle.global_position
	Sfx.play("rifle", -2.0)
	Fx.muzzle_flash(self, from, dir, 0.15)
	shake(0.25)
	if hit.is_empty():
		var end := _ray_ground(origin, dir)
		_tracer(from, end)
		Fx.dust(self, end, 0.8)
	else:
		var target: Soldier = hit["soldier"]
		_tracer(from, hit["point"])
		_damage(target, 120.0 if hit["head"] else 70.0, player)
	if clip == 0:
		_reload()


func _melee_player() -> void:
	if not running or not player.alive() or player.melee_cd > 0.0:
		return
	player.melee_cd = 0.9
	var best: Soldier = null
	var bd := MELEE_RANGE + 0.8
	for e in anzacs:
		if e.alive():
			var d := e.pos().distance_to(player.pos())
			if d < bd:
				bd = d
				best = e
	player.jab = 1.0
	if best:
		_damage(best, 100.0, player)


func _ray_soldier(o: Vector3, d: Vector3, list: Array[Soldier]) -> Dictionary:
	var best := {}
	var bt := RIFLE_RANGE * 1.5
	for s in list:
		if not s.alive():
			continue
		for part in [[Vector3(0, 1.67, 0), 0.2, true], [Vector3(0, 1.2, 0), 0.38, false], [Vector3(0, 0.55, 0), 0.25, false]]:
			var c: Vector3 = s.pos() + (part[0] as Vector3)
			var t := (c - o).dot(d)
			if t < 0.0 or t > bt:
				continue
			if (o + d * t).distance_to(c) < float(part[1]):
				if _ground_blocks(o, d, t):
					continue
				bt = t
				best = {"soldier": s, "point": o + d * t, "head": part[2]}
	return best


func _ground_blocks(o: Vector3, d: Vector3, dist: float) -> bool:
	var t := 2.0
	while t < dist - 1.0:
		var p := o + d * t
		if p.y < PeninsulaWorld.height_at(p.x, p.z) - 0.2:
			return true
		t += 2.5
	return false


func _ray_ground(o: Vector3, d: Vector3) -> Vector3:
	var t := 1.0
	while t < RIFLE_RANGE * 1.5:
		var p := o + d * t
		if p.y <= PeninsulaWorld.height_at(p.x, p.z):
			return p
		t += 2.0
	return o + d * RIFLE_RANGE


func _tracer(a: Vector3, b: Vector3) -> void:
	var t := _tracers[_tracer_i]
	_tracer_i = (_tracer_i + 1) % _tracers.size()
	var len := a.distance_to(b)
	if len < 0.5:
		return
	t.visible = true
	t.global_transform = Transform3D(Basis.looking_at((b - a).normalized(), Vector3.UP if absf((b - a).normalized().y) < 0.99 else Vector3.RIGHT), (a + b) * 0.5)
	t.scale = Vector3(1, 1, len)
	get_tree().create_timer(0.07).timeout.connect(func() -> void: t.visible = false)


func _update_player(delta: float) -> void:
	if not player.alive():
		respawn_t -= delta
		if respawn_t <= 0.0 and lives > 0:
			_respawn()
		return
	if reload_t > 0.0:
		reload_t -= delta
		if reload_t <= 0.0:
			reload_t = 0.0
			clip = PLAYER_CLIP
	bolt_t = maxf(bolt_t - delta, 0.0)
	player.melee_cd = maxf(player.melee_cd - delta, 0.0)
	if elapsed - last_hit_t > 5.0:
		player.hp = minf(player.hp + delta * 5.0, 100.0)
	var input := Vector2.ZERO
	if _stick:
		input = _stick.output
	var keys := move_axis()
	input += Vector2(keys.x, -keys.y)
	input = input.limit_length(1.0)
	var fwd := Vector3(-sin(yaw), 0, -cos(yaw))
	var right := Vector3(cos(yaw), 0, -sin(yaw))
	var spd := PLAYER_RUN if key(KEY_SHIFT) and not aiming else PLAYER_SPEED
	if aiming:
		spd *= 0.5
	var move := (fwd * -input.y + right * input.x) * spd * delta
	var next := player.pos() + move
	if not PeninsulaWorld.is_water(next.x, next.z):
		player.root.position = PeninsulaWorld.ground(next)
	player.root.rotation.y = yaw
	player.aim = clampf(pitch, -0.6, 0.6)
	player.rig.aiming_amount = move_toward(player.rig.aiming_amount, 1.0 if aiming else 0.0, delta * 5.0)
	_animate(player, move.length() / maxf(delta, 0.001), delta)


func _respawn() -> void:
	player.hp = 100.0
	player.dead_t = -1.0
	player.root.position = PeninsulaWorld.ground(PeninsulaWorld.CONKBAYIRI + Vector3(70, 0, -10))
	player.rig.reset_fall()
	clip = PLAYER_CLIP
	message("Yeniden saflardasın. Kalan can: %d" % lives, UiTheme.MUTED)


func _update_camera() -> void:
	var pivot := player.pos() + Vector3(0, 1.6, 0)
	var basis := Basis.from_euler(Vector3(pitch, yaw, 0))
	var off := Vector3(0.85, 0.3, 1.9) if aiming else Vector3(0.75, 0.35, 3.4)
	var p := pivot + basis * off
	p.y = maxf(p.y, PeninsulaWorld.height_at(p.x, p.z) + 0.4)
	cam.global_transform = Transform3D(basis, p)
	cam.fov = lerpf(cam.fov, 38.0 if aiming else 70.0, 0.2)
	if _crosshair:
		_crosshair.queue_redraw()


# ------------------------------------------------------------------ yapay zekâ

func _animate(s: Soldier, spd: float, delta: float) -> void:
	s.jab = move_toward(s.jab, 0.0, delta * 3.0)
	if spd > 0.3:
		s.rig.walk += delta * spd * 2.4
	# Uzaktaki askerlerin pozu her karede değil, üç karede bir güncellenir.
	if not s.is_player and cam and s.pos().distance_to(cam.global_position) > 90.0 and (Engine.get_process_frames() + s.root.get_instance_id()) % 3 != 0:
		return
	s.rig.apply_pose(spd, s.aim, ease(s.jab, 0.5))


func _update_squads() -> void:
	for q in squads:
		var alive := q.alive_count()
		q.label.position = q.center() + Vector3(0, 6, 0)
		q.label.text = "%s (%d)" % [q.title, alive]
		if q.side == ANZAC and not q.retreating and alive > 0 and (alive <= int(q.soldiers.size() * 0.4) or _charge_pressure(q) >= alive):
			q.retreating = true
			q.order = "retreat"
			var c := q.center()
			q.target = PeninsulaWorld.ground(Vector3(PeninsulaWorld.shore_x(c.z) + 15.0, 0, c.z))
		if q.side == OTTOMAN and q.order == "attack" and q.center().distance_to(q.target) < 15.0:
			q.order = "hold"
		if q.order == "follow":
			q.target = player.pos() - Vector3(-sin(yaw), 0, -cos(yaw)) * 8.0
		var idx := 0
		var face := Vector3(-1, 0, 0)
		var side_dir := Vector3(face.z, 0, -face.x)
		for s in q.soldiers:
			if not s.alive() or s.no_ammo and q.side == OTTOMAN and elapsed < 22.0:
				continue
			var row := idx % 8
			var line := idx / 8
			s.goal = PeninsulaWorld.ground(q.target + side_dir * (row - 3.5) * 3.2 - face * line * 4.0)
			idx += 1


## Bir ANZAC mangasının 45 m yakınında süngü hücumundaki Osmanlı asker sayısı.
func _charge_pressure(q: Squad) -> int:
	var c := q.center()
	var n := 0
	for s in ottomans:
		if s.alive() and (s.is_player or (s.squad and s.squad.order == "attack")) and s.pos().distance_to(c) < 45.0:
			n += 1
	return n


func _update_soldier(s: Soldier, delta: float) -> void:
	if not s.alive():
		_update_dead(s, delta)
		return
	s.fire_cd -= delta
	s.think_cd -= delta
	s.melee_cd -= delta
	var foes := anzacs if s.side == OTTOMAN else ottomans
	if s.enemy != null and (not is_instance_valid(s.enemy.root) or not s.enemy.alive()):
		s.enemy = null
	if s.think_cd <= 0.0:
		s.think_cd = _rng2.randf_range(0.4, 0.7)
		s.enemy = _pick_target(s, foes)
	var order := s.squad.order if s.squad else "hold"
	var move_goal := s.goal
	var spd := s.speed
	var enemy_d := s.enemy.pos().distance_to(s.pos()) if s.enemy else INF
	if order == "attack" or order == "retreat":
		spd *= 1.35
	# İlerleyen ANZAC birlikleri düşmanı görünce yer yer durup ateş eder; Osmanlı bölükleri emre uyar.
	var halt := s.side == ANZAC and s.enemy != null and order != "retreat" and enemy_d > 25.0 and (order != "attack" or fmod(elapsed + s.speed * 10.0, 9.0) < 4.0)
	if order == "attack" and s.enemy and enemy_d < 30.0:
		move_goal = s.enemy.pos()
		halt = false
	var to := move_goal - s.pos()
	to.y = 0.0
	var moving := not halt and to.length() > 1.2
	if moving:
		var step := to.normalized() * minf(spd * delta, to.length())
		var next := s.pos() + step
		if not PeninsulaWorld.is_water(next.x, next.z) or s.side == ANZAC:
			s.root.position = PeninsulaWorld.ground(next)
		s.root.rotation.y = atan2(-to.x, -to.z)
	elif s.enemy:
		var te := s.enemy.pos() - s.pos()
		s.root.rotation.y = atan2(-te.x, -te.z)
	# Durup ateş ederken tüfek omuza kalkar ve namlu düşmana eğilir.
	var target_aim := 1.0 if s.enemy != null and not moving and not s.no_ammo else 0.0
	s.rig.aiming_amount = move_toward(s.rig.aiming_amount, target_aim, delta * 3.0)
	if s.enemy:
		var te3 := s.enemy.pos() - s.pos()
		s.aim = clampf(atan2(te3.y, Vector2(te3.x, te3.z).length()), -0.5, 0.5)
	_animate(s, spd if moving else 0.0, delta)
	if s.enemy == null:
		return
	if enemy_d < MELEE_RANGE and s.melee_cd <= 0.0:
		s.melee_cd = _rng2.randf_range(0.9, 1.4)
		s.jab = 1.0
		if _rng2.randf() < 0.45:
			_damage(s.enemy, 80.0, s)
		return
	if s.no_ammo or s.fire_cd > 0.0 or order == "retreat":
		return
	s.fire_cd = _rng2.randf_range(2.6, 4.6) * (1.6 if moving else 1.0)
	var chance := 0.2 * pow(1.0 - enemy_d / RIFLE_RANGE, 1.2) * (0.6 if moving else 1.0)
	# Mevzisinde yatan asker hem daha iyi nişan alır hem de daha zor vurulur.
	if not moving and s.side == OTTOMAN:
		chance *= 1.3
	if s.side == ANZAC and not s.enemy.is_player and s.enemy.squad:
		if s.enemy.squad.order in ["hold", "move"] and s.enemy.pos().distance_to(s.enemy.goal) < 3.0:
			chance *= 0.55
		elif s.enemy.squad.order == "attack":
			chance *= 0.6
	chance *= GameState.diff("enemy_damage") if s.side == ANZAC else GameState.diff("player_damage")
	var from := s.muzzle.global_position
	var aim := s.enemy.pos() + Vector3(0, 1.2, 0)
	if _rng2.randf() < 0.35:
		Sfx.play_at("rifle", from, -10.0)
	if _rng2.randf() < 0.5:
		_tracer(from, aim + Vector3(_rng2.randf_range(-1, 1), _rng2.randf_range(-0.5, 0.5), _rng2.randf_range(-1, 1)) * (0.0 if chance > 0.5 else 1.5))
	if _rng2.randf() < chance:
		_damage(s.enemy, 60.0 if s.enemy.is_player else 100.0, s)
	elif s.enemy.is_player and enemy_d < 80.0:
		Fx.dust(self, s.enemy.pos() + Vector3(_rng2.randf_range(-2, 2), 0.2, _rng2.randf_range(-2, 2)), 0.7)


## Menzildeki en yakın üç düşmandan görüş hattı açık olan ilkini seçer.
func _pick_target(s: Soldier, foes: Array[Soldier]) -> Soldier:
	var cands: Array = []
	var me := s.pos()
	for e in foes:
		if e.alive():
			var d := e.pos().distance_to(me)
			if d < RIFLE_RANGE:
				cands.append([d, e])
	if s.side == ANZAC and player.alive():
		var dp := player.pos().distance_to(me)
		if dp < RIFLE_RANGE:
			cands.append([dp * 0.8, player])
	cands.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var eye := me + Vector3(0, 1.5, 0)
	for i in mini(cands.size(), 3):
		var e: Soldier = cands[i][1]
		var aim := e.pos() + Vector3(0, 1.2, 0)
		if float(cands[i][0]) < MELEE_RANGE * 2.0 or not _ground_blocks(eye, (aim - eye).normalized(), eye.distance_to(aim)):
			return e
	return null


func _damage(s: Soldier, amount: float, by: Soldier) -> void:
	if not s.alive() or s.invulnerable:
		return
	if s.is_player:
		amount *= 0.55 * GameState.diff("enemy_damage")
		last_hit_t = elapsed
		shake(0.6)
	s.hp -= amount
	if s.alive():
		return
	s.dead_t = 0.0
	if by != null and by.is_player:
		kills += 1
	if s.is_player:
		lives -= 1
		respawn_t = 5.0
		banner("YARALANDIN", "Kalan can: %d" % lives, 3.0)


func _update_dead(s: Soldier, delta: float) -> void:
	if s.dead_t < 0.0:
		return
	s.dead_t += delta
	var k := clampf(s.dead_t / 0.6, 0.0, 1.0)
	s.rig.fall(k)


func _naval_fire(delta: float) -> void:
	_naval_cd -= delta
	if _naval_cd > 0.0 or _ships.is_empty():
		return
	_naval_cd = _rng2.randf_range(12.0, 18.0) / GameState.diff("enemy_damage")
	var ship := _ships[_rng2.randi() % _ships.size()]
	var list := _ottoman_squads()
	if list.is_empty():
		return
	var target := list[_rng2.randi() % list.size()].center()
	target += Vector3(_rng2.randf_range(-30, 30), 0, _rng2.randf_range(-30, 30))
	target = PeninsulaWorld.ground(target)
	var from := ship.global_position + Vector3(0, 12, 0)
	Fx.muzzle_flash(self, from, (target - from).normalized(), 2.0)
	Sfx.play_at("cannon", from, 0.0)
	get_tree().create_timer(4.0).timeout.connect(func() -> void:
		if not is_inside_tree():
			return
		Fx.explosion(self, target + Vector3(0, 1, 0), 1.0)
		Sfx.play_at("boom", target, 4.0)
		if player.pos().distance_to(target) < 60.0:
			shake(1.2)
		for s in ottomans:
			if not s.alive():
				continue
			var d := s.pos().distance_to(target)
			if d < 5.0 and _rng2.randf() < 0.5 or d < 11.0 and _rng2.randf() < 0.15:
				_damage(s, 100.0, null))


func _update_objectives(delta: float) -> void:
	for key in objectives:
		var o: Dictionary = objectives[key]
		var ot := 0
		var an := 0
		for s in ottomans:
			if s.alive() and s.pos().distance_to(o["pos"]) < CAPTURE_RADIUS:
				ot += 1
		for s in anzacs:
			if s.alive() and s.pos().distance_to(o["pos"]) < CAPTURE_RADIUS:
				an += 1
		var dirn := 0.0
		if ot > 0 and an == 0:
			dirn = 1.0
		elif an > 0 and ot == 0:
			dirn = -1.0
		elif an > ot * 2:
			dirn = -0.4
		o["progress"] = clampf(o["progress"] + dirn * delta * 2.0 / CAPTURE_TIME, -1.0, 1.0)
		var owner: int = o["owner"]
		if o["progress"] >= 1.0 and owner != OTTOMAN:
			o["owner"] = OTTOMAN
			_refresh_objective(key)
			banner("%s ALINDI!" % String(o["title"]).to_upper(), "Sancak dalgalanıyor", 3.0)
		elif o["progress"] <= -1.0 and owner != ANZAC:
			o["owner"] = ANZAC
			_refresh_objective(key)
			message("%s düşmana geçti!" % o["title"], Color(1, 0.5, 0.4))


# ------------------------------------------------------------------ döngü

## Geliştirme ve test için: oyuncu en yakın düşmana nişan alıp ateş eder, taarruz anında hücum emri verir.
func debug_autoplay() -> void:
	_autoplay = true


## Geliştirme: oyuncuyu Mustafa Kemal'in önüne getirip ona baktırır.
func debug_look_kemal() -> void:
	_autoplay = false
	player.root.position = PeninsulaWorld.ground(kemal.pos() + Vector3(-3.2, 0, 1.0))
	var to := kemal.pos() + Vector3(0, 1.5, 0) - (player.pos() + Vector3(0, 1.6, 0))
	yaw = atan2(-to.x, -to.z) + 0.25
	pitch = 0.0


func debug_status() -> void:
	var own := []
	for key in objectives:
		own.append("%s=%s" % [key, "TR" if objectives[key]["owner"] == OTTOMAN else "AN"])
	var alive_o := 0
	for s in ottomans:
		if s.alive():
			alive_o += 1
	var alive_a := 0
	for s in anzacs:
		if s.alive():
			alive_a += 1
	print("player_pos=", player.pos().round())
	print("t=%d phase=%d ottoman=%d anzac=%d kills=%d lives=%d hp=%d %s finished=%s" % [elapsed, phase, alive_o, alive_a, kills, lives, player.hp, " ".join(own), finished])


func _autoplay_step() -> void:
	var post := PeninsulaWorld.ground(PeninsulaWorld.CONKBAYIRI + Vector3(-30, 0, -15))
	if player.alive() and player.pos().distance_to(post) > 3.0:
		player.root.position = PeninsulaWorld.ground(player.pos().move_toward(post, PLAYER_SPEED * get_process_delta_time()))
	var best: Soldier = null
	var bd := RIFLE_RANGE
	for e in anzacs:
		if e.alive():
			var d := e.pos().distance_to(player.pos())
			if d < bd and not _ground_blocks(cam.global_position, (e.pos() + Vector3(0, 1.2, 0) - cam.global_position).normalized(), d):
				bd = d
				best = e
	if best:
		aiming = true
		# Nişangâh kamera ışınıdır; omuz kamerasının kaymasını iki adımda düzelt.
		for i in 3:
			_update_camera()
			var to := best.pos() + Vector3(0, 1.2, 0) - cam.global_position
			yaw = atan2(-to.x, -to.z)
			pitch = atan2(to.y, Vector2(to.x, to.z).length())
		_update_camera()
		fire_player()
	if phase == 2 and elapsed > DEFENSE_END + 20.0 and fmod(elapsed, 45.0) < get_process_delta_time():
		order_charge()


func mission_process(delta: float) -> void:
	if running:
		while not _events.is_empty() and elapsed >= float(_events[0][0]):
			(_events.pop_front()[1] as Callable).call()
		while _wave_i < WAVES.size() and elapsed >= float(WAVES[_wave_i][0]):
			_spawn_wave(WAVES[_wave_i])
			_wave_i += 1
		if _autoplay:
			_autoplay_step()
		_update_player(delta)
		_update_squads()
		for s in ottomans:
			if not s.is_player:
				_update_soldier(s, delta)
			elif not s.alive():
				_update_dead(s, delta)
		for s in anzacs:
			_update_soldier(s, delta)
		if elapsed > 30.0:
			_naval_fire(delta)
		_update_objectives(delta)
		_cleanup()
		_check_end()
	if kemal:
		# Mustafa Kemal arada bir dürbünle cepheyi gözetler.
		var cycle := fmod(elapsed + 3.0, 14.0)
		kemal.rig.apply_pose(0.0, -0.05, 0.0, clampf(minf(cycle - 4.0, 12.0 - cycle), 0.0, 1.0))
	if not tactical:
		_update_camera()
	_update_hud()


func _cleanup() -> void:
	for list in [ottomans, anzacs]:
		for i in range(list.size() - 1, -1, -1):
			var s: Soldier = list[i]
			if not s.is_player and s.dead_t > 25.0:
				s.root.queue_free()
				list.remove_at(i)
				if s.squad:
					s.squad.soldiers.erase(s)
	for i in range(squads.size() - 1, -1, -1):
		var q := squads[i]
		if q.side == ANZAC and q.soldiers.is_empty():
			q.label.queue_free()
			squads.remove_at(i)
		elif q.side == ANZAC and q.retreating and q.center().distance_to(q.target) < 12.0:
			for s in q.soldiers:
				anzacs.erase(s)
				s.hp = 0.0
				s.root.queue_free()
			q.label.queue_free()
			squads.remove_at(i)


func _update_hud() -> void:
	var obj := "Conkbayırı'nı tut" if phase == 1 else "Cesaret Tepe ve Kırmızı Sırt'ı al"
	var remain := maxf(DEFENSE_END - elapsed, 0.0) if phase == 1 else maxf(TIME_LIMIT - elapsed, 0.0)
	set_objective("%s  ·  %d:%02d  ·  Vurulan düşman: %d  ·  Can: %d" % [obj, int(remain) / 60, int(remain) % 60, kills, lives])
	_hp_bar.value = maxf(player.hp, 0.0)
	_ammo_label.text = "DOLDURULUYOR..." if reload_t > 0.0 else "Fişek  %d / %d" % [clip, PLAYER_CLIP]
	_crosshair.visible = not tactical and player.alive()
	var list := _ottoman_squads()
	for i in _squad_btns.size():
		if i < list.size():
			_squad_btns[i].text = "%d (%d)" % [i + 1, list[i].alive_count()]


func _check_end() -> void:
	if finished:
		return
	if objectives["conk"]["owner"] == ANZAC:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		finish(false, 0, 0, ["Conkbayırı düştü.", "Tarihte 57. Alay sırtları tuttu ve ANZAC ilerleyişi durduruldu. Bölükleri sırtta tut ve gemi ateşinden dağınık dur."])
		return
	if lives <= 0 and not player.alive():
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		finish(false, 0, 0, ["Teğmen şehit düştü.", "Siper arkasından ateş et, Shift ile koşarak açıkta kalma süreni kısalt."])
		return
	var taken := 0
	for key in ["cesaret", "kirmizi"]:
		if objectives[key]["owner"] == OTTOMAN:
			taken += 1
	if phase == 2 and (taken == 2 or elapsed >= TIME_LIMIT):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		if taken == 0:
			finish(false, 0, 0, ["Gün battı; Cesaret Tepe ve Kırmızı Sırt düşmanda kaldı."])
			return
		var st := 1 + (1 if taken == 2 else 0) + (1 if kills >= 10 else 0)
		finish(true, st, 4 + kills / 2 + taken * 2 + st * 2, [
			"Geri alınan mevzi: %d/2 · Vurduğun düşman: %d" % [taken, kills],
			"Tarihte 57. Alay'ın 25 Nisan karşı taarruzu ANZAC'ın Conkbayırı ve Kocaçimen'e ulaşmasını engelledi; alay o gün ağır kayıp verdi.",
			"57. Alay'ın anısına bu alay numarası Türk ordusunda bir daha kullanılmadı."])
