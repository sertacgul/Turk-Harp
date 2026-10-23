extends MissionBase
## 18 Mart 1915: Rumeli Mecidiye Tabyası'nın topunu yönet, diğer bataryalara hedef göster,
## Seyit Onbaşı ile cephane taşı. İtilaf filosu tarihî üç hat halinde gelir.

const GRAVITY := Vector3(0, -40.0, 0)
const BASE_MUZZLE_SPEED := 210.0
const BASE_RELOAD := 6.0
const MAX_AMMO := 6
const BASE_SEYIT := 8.0
const PLAYER_DAMAGE := 14.0
const AI_DAMAGE := 6.0
const MINE_DAMAGE := 60.0
const SINK_TARGET := 3
const PASS_LIMIT := 2
const SPAWN_X := -1350.0
const PASS_X := 620.0
const RETREAT_TIME := 360.0

const FLEET := [
	# Hat A (İngiliz): uzaktan bombardıman, sonra yaklaşır ve geri çekilir.
	{"title": "HMS Queen Elizabeth", "nation": "uk", "hp": 210, "line": "A", "lane": -70.0, "delay": 2.0, "funnels": 2, "len": 82.0},
	{"title": "HMS Agamemnon", "nation": "uk", "hp": 170, "line": "A", "lane": -25.0, "delay": 4.0, "funnels": 2, "len": 75.0},
	{"title": "HMS Lord Nelson", "nation": "uk", "hp": 170, "line": "A", "lane": 20.0, "delay": 6.0, "funnels": 2, "len": 75.0},
	{"title": "HMS Inflexible", "nation": "uk", "hp": 160, "line": "A", "lane": 65.0, "delay": 8.0, "funnels": 3, "len": 80.0},
	# Hat B (Fransız): yakından bombardıman, Erenköy Koyu üzerinden çekilir.
	{"title": "Gaulois", "nation": "fr", "hp": 130, "line": "B", "lane": -50.0, "delay": 42.0, "funnels": 2, "len": 70.0},
	{"title": "Charlemagne", "nation": "fr", "hp": 130, "line": "B", "lane": -10.0, "delay": 45.0, "funnels": 2, "len": 70.0},
	{"title": "Bouvet", "nation": "fr", "hp": 130, "line": "B", "lane": 35.0, "delay": 48.0, "funnels": 2, "len": 70.0},
	{"title": "Suffren", "nation": "fr", "hp": 130, "line": "B", "lane": 75.0, "delay": 51.0, "funnels": 2, "len": 72.0},
	# Hat C (İngiliz takviye): bir kısmı Nara'yı zorlar.
	{"title": "HMS Vengeance", "nation": "uk", "hp": 130, "line": "C", "lane": -60.0, "delay": 100.0, "funnels": 2, "len": 70.0, "push": true},
	{"title": "HMS Irresistible", "nation": "uk", "hp": 130, "line": "C", "lane": -20.0, "delay": 103.0, "funnels": 2, "len": 70.0},
	{"title": "HMS Albion", "nation": "uk", "hp": 130, "line": "C", "lane": 20.0, "delay": 106.0, "funnels": 2, "len": 70.0, "push": true},
	{"title": "HMS Ocean", "nation": "uk", "hp": 130, "line": "C", "lane": 60.0, "delay": 109.0, "funnels": 2, "len": 70.0},
	{"title": "HMS Swiftsure", "nation": "uk", "hp": 130, "line": "C", "lane": -40.0, "delay": 125.0, "funnels": 2, "len": 68.0, "push": true},
	{"title": "HMS Majestic", "nation": "uk", "hp": 130, "line": "C", "lane": 40.0, "delay": 128.0, "funnels": 2, "len": 68.0},
]

const BATTERIES := [
	{"title": "Rumeli Mecidiye", "x": 120.0, "side": -1, "player": true},
	{"title": "Namazgah", "x": 20.0, "side": -1},
	{"title": "Rumeli Hamidiye", "x": 340.0, "side": -1},
	{"title": "Dardanos", "x": -140.0, "side": 1},
	{"title": "Anadolu Hamidiye", "x": 290.0, "side": 1},
	{"title": "Çimenlik", "x": 450.0, "side": 1},
]


class Battery:
	var title := ""
	var root: Node3D
	var yaw: Node3D
	var pitch: Node3D
	var muzzle: Marker3D
	var hp := 100.0
	var max_hp := 100.0
	var reload := 0.0
	var is_player := false
	var label: Label3D
	var burning := false

	func alive() -> bool:
		return hp > 0.0

	func pos() -> Vector3:
		return root.global_position


class Ship:
	var spec: Dictionary
	var title := ""
	var root: Node3D
	var model: Node3D
	var parts: Dictionary
	var hp := 100.0
	var max_hp := 100.0
	var speed := 0.0
	var cruise := 18.0
	var heading := 0.0
	var waypoints: Array[Vector3] = []
	var hold := 0.0
	var fire_cd := 4.0
	var sinking := -1.0
	var smoking := false
	var burning := false
	var label: Label3D
	var gone := false
	var velocity := Vector3.ZERO
	var target: Battery

	func afloat() -> bool:
		return hp > 0.0 and not gone


class Shell:
	var node: Node3D
	var trail: GPUParticles3D
	var p0: Vector3
	var v0: Vector3
	var t := 0.0
	var prev: Vector3
	var by_player := false
	var from_ottoman := true
	var damage := 0.0


var batteries: Array[Battery] = []
var player: Battery
var ships: Array[Ship] = []
var shells: Array[Shell] = []
var mines: Array[Vector3] = []
var mine_markers: Array[Node3D] = []
var spawn_queue: Array = []
var focus: Ship

var cam: Camera3D
var tactical_cam: Camera3D
var tactical := false
var aim_yaw := 0.0
var aim_pitch := deg_to_rad(8.0)
var zoomed := false
var ammo := MAX_AMMO
var reload := 0.0
var seyit_time := 0.0
var seyit_node: Node3D
var preview: MeshInstance3D
var preview_mesh: ImmediateMesh
var impact_ring: MeshInstance3D
var sunk := 0
var passed := 0
var sunk_names: Array[String] = []
var _retreat_ordered := false
var player_kills := 0

var _fire_btn: Button
var _seyit_btn: Button
var _reload_bar: ProgressBar
var _hp_bar: ProgressBar
var _ammo_label: Label
var _speed_btn: Button
var _map_btn: Button
var _dragging := false
var _autoplay := false


func _ready() -> void:
	setup("18mart", false)
	mines = GameState.mines_for_battle().duplicate()
	for b in BATTERIES:
		_add_battery(b)
	_build_player_view()
	_build_mines()
	_build_controls()
	spawn_queue = FLEET.duplicate()
	Sfx.listener = cam
	set_objective("Brifing")
	show_briefing("18 Mart: Boğaz Savunması", "18 Mart 1915 · Çanakkale Boğazı",
		"İtilaf donanması boğazı geçip İstanbul'a ulaşmak için saldırıyor. Rumeli Mecidiye Tabyası'ndaki topu sen yönetiyorsun. Erenköy Koyu'ndaki mayınlar (%d adet) Nusret'in döşediği yerde bekliyor." % mines.size(),
		["Sürükle ya da W/A/S/D: nişan al · Boşluk ya da ATEŞ: atış · Z ya da DÜRBÜN: dürbün · Fare tekerleği ya da +/-: yakınlaştır",
		"HARİTA: taktik görünüm. Bir gemiye dokunarak diğer bataryaların ateşini yoğunlaştır.",
		"Cephane azalınca SEYİT düğmesi: Seyit Onbaşı 215 kg'lık mermiyi sırtında taşır.",
		"Hedef: en az %d gemi batsın, %d gemi Nara'yı geçmesin. Yıldızlar: kendi topunla 2 gemi batır, tabyanı sağlam tut." % [SINK_TARGET, PASS_LIMIT],
		"Komutanlar: Cevat Paşa (Osmanlı Devleti, İttifak Devletleri; Çanakkale Müstahkem Mevki), Amiral de Robeck ve Amiral Guépratte (İtilaf Devletleri)."])
	mission_started.connect(func() -> void:
		banner("ÇANAKKALE GEÇİLMEZ", "İtilaf donanması boğaza giriyor", 4.0)
		Voice.shout("canakkale_gecilmez"))


func _exit_tree() -> void:
	Engine.time_scale = 1.0
	super._exit_tree()


func intro_cards() -> Array:
	return [
		["18 Mart 1915", "Dünyanın en güçlü donanmalarından biri, on altı zırhlıyla Çanakkale Boğazı'na giriyor. Amaç, tabyaları susturup İstanbul'a ulaşmak."],
		["Tabyalardaki Mehmetçik", "Rumeli Mecidiye, Anadolu Hamidiye, Kilitbahir... Eski toplar ve az cephaneyle kıyıdaki topçular saatlerce düşman ateşi altında görev yapacak."],
		["Seyit Onbaşı", "Rumeli Mecidiye Tabyası'nda topun mermi kaldıran vinci bozulunca, Seyit Onbaşı 215 kiloluk mermiyi sırtlanıp topa taşıdı."],
		["Çanakkale Geçilmez", "Günün sonunda üç zırhlı battı, üçü ağır yaralandı. İtilaf Devletleri Boğaz'ı denizden geçemeyeceğini anladı. 18 Mart bugün Şehitleri Anma Günü ve Çanakkale Deniz Zaferi olarak anılmaktadır."],
	]


# ------------------------------------------------------------------ kurulum

func _shore_point(x: float, side: int, inland: float) -> Vector3:
	var z := (-StraitWorld.north_half_width(x) - inland) if side < 0 else (StraitWorld.south_half_width(x) + inland)
	return Vector3(x, StraitWorld.height_at(x, z), z)


func _mat(c: Color, rough := 0.85, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	return m


func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	b.material = mat
	mi.mesh = b
	mi.position = pos
	parent.add_child(mi)
	return mi


func _add_battery(spec: Dictionary) -> void:
	var b := Battery.new()
	b.title = spec["title"]
	b.is_player = spec.get("player", false)
	var p := _shore_point(spec["x"], spec["side"], 24.0)
	b.root = Node3D.new()
	add_child(b.root)
	b.root.global_position = p
	var earth := _mat(Color(0.55, 0.48, 0.36))
	var stone := _mat(Color(0.68, 0.63, 0.53))
	_box(b.root, Vector3(30, 12, 24), Vector3(0, -4.5, 0), earth)
	var toward_water := Vector3(0, 0, 1) * (-float(spec["side"]))
	for i in 5:
		var wall := _box(b.root, Vector3(4.5, 3.0, 2.0), Vector3(-12.0 + i * 6.0, 2.0, 0) + toward_water * 10.0, stone)
		wall.rotation.y = 0.0
	b.yaw = Node3D.new()
	b.yaw.position = Vector3(0, 2.2, 0)
	b.root.add_child(b.yaw)
	var steel := _mat(Color(0.18, 0.19, 0.2), 0.45, 0.7)
	_box(b.yaw, Vector3(3.2, 1.6, 4.5), Vector3(0, 0, 0), _mat(Color(0.3, 0.26, 0.2)))
	for side in [-1.8, 1.8]:
		var wheel := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 1.3
		cyl.bottom_radius = 1.3
		cyl.height = 0.4
		cyl.material = _mat(Color(0.25, 0.2, 0.15))
		wheel.mesh = cyl
		wheel.rotation.z = PI / 2.0
		wheel.position = Vector3(side, -0.2, 0.5)
		b.yaw.add_child(wheel)
	b.pitch = Node3D.new()
	b.pitch.position = Vector3(0, 1.0, 0)
	b.yaw.add_child(b.pitch)
	var barrel := MeshInstance3D.new()
	var bc := CylinderMesh.new()
	bc.top_radius = 0.45
	bc.bottom_radius = 0.75
	bc.height = 9.0
	bc.material = steel
	barrel.mesh = bc
	barrel.rotation.x = -PI / 2.0
	barrel.position = Vector3(0, 0, -3.0)
	b.pitch.add_child(barrel)
	b.muzzle = Marker3D.new()
	b.muzzle.position = Vector3(0, 0, -7.6)
	b.pitch.add_child(b.muzzle)
	var face := toward_water * 0.5 + Vector3(-1.0, 0, 0)
	b.yaw.rotation.y = atan2(-face.x, -face.z)
	b.pitch.rotation.x = deg_to_rad(8.0)
	# Sancak
	var pole := MeshInstance3D.new()
	var pc := CylinderMesh.new()
	pc.top_radius = 0.12
	pc.bottom_radius = 0.12
	pc.height = 12.0
	pc.material = _mat(Color(0.4, 0.35, 0.3))
	pole.mesh = pc
	pole.position = Vector3(12, 6, -8 * float(spec["side"]))
	b.root.add_child(pole)
	var flag := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(4.5, 3.0)
	q.subdivide_width = 8
	var fm := ShaderMaterial.new()
	fm.shader = load("res://shaders/flag.gdshader")
	fm.set_shader_parameter("flag_texture", ShipBuilder.flag_texture("tr"))
	q.material = fm
	flag.mesh = q
	flag.position = pole.position + Vector3(2.3, 4.2, 0)
	b.root.add_child(flag)
	# Cephane sandıkları
	for i in 3:
		_box(b.root, Vector3(1.6, 1.0, 1.0), Vector3(-9.0 + i * 1.9, 1.5, -6.0 * float(spec["side"])), _mat(Color(0.42, 0.32, 0.2)))
	b.max_hp = 150.0 * (1.0 + 0.15 * GameState.upgrade_level("armor")) if b.is_player else 140.0
	b.hp = b.max_hp
	b.reload = randf_range(3.0, 9.0)
	b.label = Label3D.new()
	b.label.text = b.title
	b.label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	b.label.font_size = 28
	b.label.fixed_size = true
	b.label.pixel_size = 0.0012
	b.label.outline_size = 12
	b.label.position = Vector3(0, 18, 0)
	b.label.modulate = Color(0.95, 0.85, 0.5)
	b.label.no_depth_test = true
	b.label.visible = false
	b.root.add_child(b.label)
	batteries.append(b)
	if b.is_player:
		player = b
		aim_yaw = b.yaw.rotation.y


func _build_player_view() -> void:
	cam = Camera3D.new()
	cam.fov = 62.0
	cam.far = 6000.0
	cam.position = Vector3(2.5, 6.5, 16.0)
	cam.rotation.x = deg_to_rad(-6.0)
	player.yaw.add_child(cam)
	cam.current = true
	tactical_cam = Camera3D.new()
	tactical_cam.fov = 55.0
	tactical_cam.far = 6000.0
	add_child(tactical_cam)
	tactical_cam.global_position = Vector3(-420.0, 1250.0, 760.0)
	tactical_cam.look_at(Vector3(-380.0, 0.0, 40.0))

	preview_mesh = ImmediateMesh.new()
	preview = MeshInstance3D.new()
	preview.mesh = preview_mesh
	preview.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var pm := StandardMaterial3D.new()
	pm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pm.albedo_color = Color(1.0, 0.75, 0.25, 0.65)
	pm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pm.no_depth_test = true
	preview.material_override = pm
	add_child(preview)
	impact_ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 9.0
	torus.outer_radius = 11.0
	impact_ring.mesh = torus
	impact_ring.material_override = pm
	add_child(impact_ring)

	seyit_node = Node3D.new()
	var body := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.45
	cap.height = 1.8
	cap.material = _mat(Color(0.45, 0.4, 0.28))
	body.mesh = cap
	body.position.y = 0.9
	seyit_node.add_child(body)
	var shell_mesh := MeshInstance3D.new()
	var sc := CylinderMesh.new()
	sc.top_radius = 0.1
	sc.bottom_radius = 0.28
	sc.height = 1.3
	sc.material = _mat(Color(0.65, 0.5, 0.25), 0.4, 0.6)
	shell_mesh.mesh = sc
	shell_mesh.position = Vector3(0, 1.4, 0.4)
	shell_mesh.rotation.x = 0.4
	seyit_node.add_child(shell_mesh)
	seyit_node.visible = false
	player.root.add_child(seyit_node)


func _build_mines() -> void:
	var mm := _mat(Color(0.9, 0.2, 0.15))
	mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for m in mines:
		var marker := MeshInstance3D.new()
		var s := SphereMesh.new()
		s.radius = 4.0
		s.height = 8.0
		s.material = mm
		marker.mesh = s
		marker.position = m + Vector3(0, 1.0, 0)
		marker.visible = false
		add_child(marker)
		mine_markers.append(marker)


func _build_controls() -> void:
	var right := VBoxContainer.new()
	right.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	right.position = Vector2(-300, -330)
	right.custom_minimum_size = Vector2(280, 0)
	right.add_theme_constant_override("separation", 10)
	ui.add_child(right)
	_ammo_label = UiTheme.label("", 22, UiTheme.TEXT, HORIZONTAL_ALIGNMENT_RIGHT)
	right.add_child(_ammo_label)
	_reload_bar = UiTheme.bar(UiTheme.GOLD, 280, 12)
	right.add_child(_reload_bar)
	_seyit_btn = UiTheme.button("SEYİT ONBAŞI", _call_seyit, 280)
	right.add_child(_seyit_btn)
	_fire_btn = UiTheme.button("ATEŞ", fire_player, 280)
	_fire_btn.custom_minimum_size.y = 110
	_fire_btn.add_theme_font_size_override("font_size", 40)
	right.add_child(_fire_btn)

	var left := VBoxContainer.new()
	left.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	left.position = Vector2(20, -280)
	left.add_theme_constant_override("separation", 10)
	ui.add_child(left)
	left.add_child(UiTheme.label("Rumeli Mecidiye Tabyası", 18, UiTheme.MUTED))
	_hp_bar = UiTheme.bar(Color(0.3, 0.8, 0.4), 260, 14)
	left.add_child(_hp_bar)
	_map_btn = UiTheme.button("HARİTA", toggle_tactical, 200)
	left.add_child(_map_btn)
	left.add_child(UiTheme.button("DÜRBÜN", toggle_zoom, 200))
	_speed_btn = UiTheme.button("HIZ x1", _toggle_speed, 200)
	left.add_child(_speed_btn)


# ------------------------------------------------------------------ girdi

func _unhandled_input(event: InputEvent) -> void:
	if not running:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_SPACE, KEY_F:
				fire_player()
			KEY_Z:
				toggle_zoom()
			KEY_TAB, KEY_M:
				toggle_tactical()
			KEY_R:
				_call_seyit()
			KEY_EQUAL, KEY_PLUS, KEY_KP_ADD:
				zoom(1.0)
			KEY_MINUS, KEY_KP_SUBTRACT:
				zoom(-1.0)
	if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		zoom(1.0 if event.button_index == MOUSE_BUTTON_WHEEL_UP else -1.0)
		return
	# Dokunmatikte her parmak ayrı işlenir; dokunuştan üretilen sahte fare olayları yok sayılır.
	if event is InputEventScreenTouch and event.pressed and tactical:
		_tactical_pick(event.position)
	elif event is InputEventScreenDrag and not tactical:
		_aim_by(event.relative)
	if event is InputEventMouse and event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_dragging = true
			if tactical:
				_tactical_pick(event.position)
		else:
			_dragging = false
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		toggle_zoom()
	if event is InputEventMouseMotion and _dragging and not tactical:
		_aim_by(event.relative)


func _aim_by(rel: Vector2) -> void:
	var sens := 0.0025 * (0.35 if zoomed else 1.0)
	aim_yaw -= rel.x * sens
	aim_pitch = clampf(aim_pitch - rel.y * sens * 0.6, deg_to_rad(0.0), deg_to_rad(32.0))


func _tactical_pick(screen: Vector2) -> void:
	var from := tactical_cam.project_ray_origin(screen)
	var dir := tactical_cam.project_ray_normal(screen)
	if absf(dir.y) < 0.001:
		return
	var hit := from + dir * (-from.y / dir.y)
	var best: Ship = null
	var best_d := 70.0
	for s in ships:
		if s.afloat():
			var d := Vector2(s.root.global_position.x - hit.x, s.root.global_position.z - hit.z).length()
			if d < best_d:
				best_d = d
				best = s
	focus = best
	if focus:
		message("Bataryalar %s üzerine ateş ediyor" % focus.title, UiTheme.GOLD)


func toggle_tactical() -> void:
	tactical = not tactical
	tactical_cam.current = tactical
	cam.current = not tactical
	world.environment.fog_enabled = not tactical
	_map_btn.text = "TOP BAŞI" if tactical else "HARİTA"
	for m in mine_markers:
		m.visible = tactical
	for b in batteries:
		b.label.visible = tactical
	Sfx.listener = tactical_cam if tactical else cam


## Kademesiz yakınlaştırma: top başında dürbün açısı, haritada kamera yüksekliği.
func zoom(step: float) -> void:
	if tactical:
		var next := tactical_cam.global_position + (-tactical_cam.global_basis.z) * step * 80.0
		if next.y > 150.0 and next.y < 1800.0:
			tactical_cam.global_position = next
		return
	cam.fov = clampf(cam.fov - step * 6.0, 14.0, 70.0)
	zoomed = cam.fov < 45.0


func toggle_zoom() -> void:
	zoomed = not zoomed
	var tw := create_tween()
	tw.tween_property(cam, "fov", 20.0 if zoomed else 62.0, 0.25)


func _toggle_speed() -> void:
	Engine.time_scale = 2.0 if Engine.time_scale < 1.5 else 1.0
	_speed_btn.text = "HIZ x%d" % int(Engine.time_scale)


# ------------------------------------------------------------------ oyuncu topu

func muzzle_speed() -> float:
	return BASE_MUZZLE_SPEED * (1.0 + 0.08 * GameState.upgrade_level("range"))


func reload_time() -> float:
	return BASE_RELOAD * (1.0 - 0.12 * GameState.upgrade_level("reload"))


func fire_player() -> void:
	if not running or not player.alive() or reload > 0.0 or ammo <= 0 or seyit_time > 0.0:
		if ammo <= 0 and running:
			message("Cephane bitti! Seyit Onbaşı'yı çağır.", Color(1, 0.6, 0.4))
		return
	ammo -= 1
	reload = reload_time()
	var dir := -player.pitch.global_basis.z
	_spawn_shell(player.muzzle.global_position, dir * muzzle_speed(), true, true, PLAYER_DAMAGE * GameState.diff("player_damage"))
	Fx.muzzle_flash(self, player.muzzle.global_position, dir, 1.4)
	Sfx.play("cannon", 0.0)
	shake(1.2)
	var tw := create_tween()
	tw.tween_property(player.pitch, "position:z", 1.2, 0.06)
	tw.tween_property(player.pitch, "position:z", 0.0, 0.6)


func _call_seyit() -> void:
	if not running or seyit_time > 0.0 or ammo >= MAX_AMMO or not player.alive():
		return
	seyit_time = BASE_SEYIT * (1.0 - 0.2 * GameState.upgrade_level("seyit"))
	seyit_node.visible = true
	banner("SEYİT ONBAŞI", "215 kiloluk mermiyi sırtına aldı", 2.5)
	Voice.shout("seyit")


func _update_player(delta: float) -> void:
	var keys := move_axis()
	aim_yaw -= keys.x * delta * 0.5 * (0.35 if zoomed else 1.0)
	aim_pitch = clampf(aim_pitch + keys.y * delta * 0.25, 0.0, deg_to_rad(32.0))
	player.yaw.rotation.y = aim_yaw
	player.pitch.rotation.x = aim_pitch
	cam.rotation.x = deg_to_rad(-6.0) + (aim_pitch * 0.6 if zoomed else aim_pitch * 0.15)
	reload = maxf(reload - delta, 0.0)
	if seyit_time > 0.0:
		seyit_time -= delta
		var k := 1.0 - absf(fmod(seyit_time, 4.0) / 2.0 - 1.0)
		seyit_node.position = Vector3(-9.0, 1.5, 7.0).lerp(Vector3(-2.5, 1.5, 1.0), k)
		seyit_node.position.y += absf(sin(elapsed * 9.0)) * 0.25
		if seyit_time <= 0.0:
			ammo = MAX_AMMO
			seyit_node.visible = false
			message("Seyit Onbaşı mermileri yetiştirdi!", UiTheme.GOLD)
	_draw_preview()


func _draw_preview() -> void:
	preview_mesh.clear_surfaces()
	if tactical or not player.alive():
		impact_ring.visible = false
		return
	var p0 := player.muzzle.global_position
	var v0 := -player.pitch.global_basis.z * muzzle_speed()
	preview_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	var t := 0.0
	var p := p0
	var landed := false
	while t < 12.0:
		p = p0 + v0 * t + 0.5 * GRAVITY * t * t
		preview_mesh.surface_add_vertex(p)
		if t > 0.2 and p.y <= maxf(StraitWorld.height_at(p.x, p.z), 0.0):
			landed = true
			break
		t += 0.06
	preview_mesh.surface_end()
	impact_ring.visible = landed
	impact_ring.global_position = Vector3(p.x, maxf(StraitWorld.height_at(p.x, p.z), 0.0) + 0.8, p.z)


## Geliştirme ve test için: oyuncu topu en yakın gemiye kendiliğinden nişan alır.
func debug_autoplay() -> void:
	_autoplay = true


func debug_status() -> void:
	print("t=%d pk=%d sunk=%d passed=%d ships=%d mines=%d hp=%d ammo=%d finished=%s names=%s" % [elapsed, player_kills, sunk, passed, ships.size(), mines.size(), player.hp, ammo, finished, sunk_names])


func _autoplay_step() -> void:
	var best: Ship = null
	var best_d := 1100.0
	for s in ships:
		if s.afloat() and s.sinking < 0.0:
			var d := s.root.global_position.distance_to(player.pos())
			if d < best_d:
				best_d = d
				best = s
	if best == null:
		return
	var to := best.root.global_position + best.velocity * (best_d / muzzle_speed()) - player.muzzle.global_position
	aim_yaw = atan2(-to.x, -to.z)
	var flat := Vector2(to.x, to.z).length()
	var v := muzzle_speed()
	var g := -GRAVITY.y
	var disc := v * v * v * v - g * (g * flat * flat + 2.0 * to.y * v * v)
	if disc > 0.0:
		aim_pitch = atan((v * v - sqrt(disc)) / (g * flat))
	if ammo == 0:
		_call_seyit()
	fire_player()


# ------------------------------------------------------------------ mermiler

func _spawn_shell(pos: Vector3, vel: Vector3, by_player: bool, ottoman: bool, damage: float) -> void:
	var s := Shell.new()
	s.node = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.7
	sm.height = 1.4
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1.0, 0.75, 0.4)
	m.emission_enabled = true
	m.emission = Color(1.0, 0.6, 0.2)
	m.emission_energy_multiplier = 4.0
	sm.material = m
	(s.node as MeshInstance3D).mesh = sm
	add_child(s.node)
	s.node.global_position = pos
	s.trail = Fx.trail(s.node, 1.2 if by_player else 1.0)
	s.p0 = pos
	s.v0 = vel
	s.prev = pos
	s.by_player = by_player
	s.from_ottoman = ottoman
	s.damage = damage
	shells.append(s)


## Hedefe verilen uçuş süresinde düşen balistik hız.
func _ballistic(from: Vector3, to: Vector3, flight: float) -> Vector3:
	return (to - from - 0.5 * GRAVITY * flight * flight) / flight


func _update_shells(delta: float) -> void:
	for s in shells:
		s.t += delta
		var p := s.p0 + s.v0 * s.t + 0.5 * GRAVITY * s.t * s.t
		s.node.global_position = p
		if s.from_ottoman:
			for k in 3:
				var q := s.prev.lerp(p, float(k + 1) / 3.0)
				var hit := _ship_at(q)
				if hit:
					_hit_ship(hit, q, s.damage, s.by_player)
					_kill_shell(s)
					break
		if s.node == null:
			continue
		var ground := StraitWorld.height_at(p.x, p.z)
		if p.y <= ground and ground > 0.0:
			_land_impact(p, s)
			_kill_shell(s)
		elif p.y <= 0.0:
			Fx.water_splash(self, Vector3(p.x, 0.0, p.z), 1.6)
			Sfx.play_at("splash", p, -4.0)
			_kill_shell(s)
		else:
			s.prev = p
	shells.assign(shells.filter(func(x: Shell) -> bool: return x.node != null))


func _kill_shell(s: Shell) -> void:
	if s.node == null:
		return
	var tr := s.trail
	var at := tr.global_position
	s.node.remove_child(tr)
	add_child(tr)
	tr.global_position = at
	tr.emitting = false
	get_tree().create_timer(1.2).timeout.connect(tr.queue_free)
	s.node.queue_free()
	s.node = null


func _land_impact(p: Vector3, s: Shell) -> void:
	Fx.explosion(self, p, 0.8)
	Sfx.play_at("boom", p, -2.0)
	if s.from_ottoman:
		return
	for b in batteries:
		if b.alive() and b.pos().distance_to(p) < 20.0:
			_damage_battery(b, s.damage * (1.0 - b.pos().distance_to(p) / 25.0))
	if player.pos().distance_to(p) < 160.0 and not tactical:
		shake(clampf(1.6 - player.pos().distance_to(p) / 120.0, 0.2, 1.4))


func _damage_battery(b: Battery, amount: float) -> void:
	b.hp -= amount
	if b.is_player:
		message("Tabyamız isabet aldı!", Color(1, 0.5, 0.4))
		shake(1.6)
	if b.hp < b.max_hp * 0.4 and not b.burning:
		b.burning = true
		Fx.smoke_column(b.root, Vector3(4, 3, 0), 0.12, 1.2, 20)
	if not b.alive():
		Fx.explosion(self, b.pos() + Vector3(0, 3, 0), 2.0)
		Sfx.play_at("boom", b.pos(), 4.0)
		message("%s tabyası sustu!" % b.title, Color(1, 0.45, 0.35))


func _ship_at(p: Vector3) -> Ship:
	for s in ships:
		if not s.afloat():
			continue
		var l := s.root.global_transform.affine_inverse() * p
		var half_len: float = s.parts["length"] * 0.5
		var beam: float = s.parts["beam"]
		if absf(l.x) < half_len and absf(l.z) < beam * 0.6 + 1.0 and l.y > -2.0 and l.y < beam * 1.4:
			return s
	return null


func _hit_ship(s: Ship, p: Vector3, damage: float, by_player: bool) -> void:
	var crit := randf() < 0.06
	var dmg := damage * (2.5 if crit else 1.0)
	Fx.explosion(self, p, 1.1 if not crit else 2.2)
	Sfx.play_at("boom", p, 0.0 if by_player else -3.0)
	if by_player:
		message(("%s cephaneliğine isabet!" if crit else "%s isabet aldı") % s.title, UiTheme.GOLD if crit else UiTheme.TEXT)
	_damage_ship(s, dmg, by_player)


func _damage_ship(s: Ship, dmg: float, by_player := false) -> void:
	if not s.afloat():
		return
	s.hp -= dmg
	if s.hp <= 0.0 and by_player:
		player_kills += 1
	s.label.modulate = Color(1, 1, 1).lerp(Color(1, 0.3, 0.2), 1.0 - s.hp / s.max_hp)
	if s.hp < s.max_hp * 0.65 and not s.smoking:
		s.smoking = true
		Fx.smoke_column(s.model, Vector3(0, s.parts["beam"] * 0.8, 0), 0.08, 1.6, 26)
	if s.hp < s.max_hp * 0.35 and not s.burning:
		s.burning = true
		Fx.fire(s.model, Vector3(-s.parts["length"] * 0.1, s.parts["beam"] * 0.6, 0), 1.3)
	if s.hp <= 0.0:
		s.sinking = 0.0
		sunk += 1
		sunk_names.append(s.title)
		banner("%s BATIYOR!" % s.title.to_upper(), "Batırılan gemi: %d" % sunk, 3.5)
		Fx.explosion(self, s.root.global_position + Vector3(0, 6, 0), 3.0)
		Sfx.play_at("boom", s.root.global_position, 6.0)
		if focus == s:
			focus = null


# ------------------------------------------------------------------ İtilaf filosu

func _spawn_ship(spec: Dictionary) -> void:
	var s := Ship.new()
	s.spec = spec
	s.title = spec["title"]
	s.max_hp = spec["hp"]
	s.hp = s.max_hp
	s.parts = ShipBuilder.build_battleship(spec["nation"], spec["len"], 13.0, spec["funnels"])
	s.root = Node3D.new()
	add_child(s.root)
	s.model = s.parts["root"]
	s.root.add_child(s.model)
	var lane: float = spec["lane"]
	s.root.global_position = Vector3(SPAWN_X, 0.0, lane)
	for f in s.parts["funnels"]:
		Fx.smoke_column(s.model, (f as Node3D).position, 0.14, 2.0, 18)
	Fx.wake(s.model, Vector3(-s.parts["length"] * 0.5, 0.3, 0), 1.4)
	s.label = Label3D.new()
	s.label.text = s.title
	s.label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	s.label.font_size = 26
	s.label.fixed_size = true
	s.label.pixel_size = 0.0012
	s.label.outline_size = 10
	s.label.no_depth_test = true
	s.label.visible = false
	s.label.position = Vector3(0, 34, 0)
	s.root.add_child(s.label)
	s.cruise = randf_range(17.0, 20.0)
	s.speed = s.cruise
	s.fire_cd = randf_range(4.0, 8.0)
	match spec["line"]:
		"A":
			s.waypoints = [Vector3(-560, 0, lane), Vector3(-420, 0, lane * 0.8), Vector3(-1500, 0, lane)]
			s.hold = 55.0
		"B":
			s.waypoints = [Vector3(-220 + lane * 0.6, 0, lane), Vector3(-440 + lane, 0, 385), Vector3(-900, 0, 220), Vector3(-1500, 0, 60)]
			s.hold = 60.0
		_:
			if spec.get("push", false):
				s.waypoints = [Vector3(-100 + lane, 0, lane), Vector3(250, 0, lane * 0.4), Vector3(PASS_X + 100.0, 0, 0)]
			else:
				s.waypoints = [Vector3(-150 + lane, 0, lane), Vector3(-470 + lane, 0, 380), Vector3(-1000, 0, 200), Vector3(-1500, 0, 0)]
			s.hold = 45.0
	ships.append(s)
	message("%s boğaza girdi" % s.title, UiTheme.MUTED)


func _update_ship(s: Ship, delta: float) -> void:
	if s.sinking >= 0.0:
		s.sinking += delta
		var k := clampf(s.sinking / 22.0, 0.0, 1.0)
		s.model.rotation.x = lerpf(0.0, deg_to_rad(28.0), k)
		s.model.rotation.z = lerpf(0.0, deg_to_rad(-12.0), k)
		s.model.position.y = -k * 22.0
		s.speed = move_toward(s.speed, 0.0, delta * 4.0)
		s.root.global_position += Vector3(cos(s.heading), 0, -sin(s.heading)) * s.speed * delta
		if s.sinking > 24.0:
			s.gone = true
			s.root.queue_free()
		return
	var pos := s.root.global_position
	if s.waypoints.is_empty():
		return
	var wp: Vector3 = s.waypoints[0]
	var to := Vector2(wp.x - pos.x, wp.z - pos.z)
	if to.length() < 45.0:
		if s.hold > 0.0 and s.waypoints.size() > 1 and _is_hold_point(s):
			s.speed = move_toward(s.speed, 0.0, delta * 3.0)
			s.hold -= delta
		else:
			s.waypoints.pop_front()
			if s.waypoints.is_empty():
				_ship_exits(s)
				return
	else:
		s.speed = move_toward(s.speed, s.cruise, delta * 2.0)
		var want := atan2(-to.y, to.x)
		s.heading = lerp_angle(s.heading, want, delta * 0.6)
		# Hedef arkada kalırsa yavaşlayarak dön, çember çizme.
		if absf(angle_difference(s.heading, want)) > 1.2:
			s.speed = move_toward(s.speed, s.cruise * 0.4, delta * 4.0)
	s.velocity = Vector3(cos(s.heading), 0, -sin(s.heading)) * s.speed
	s.root.global_position = pos + s.velocity * delta
	s.root.rotation.y = s.heading
	s.model.position.y = sin(elapsed * 0.8 + pos.x * 0.01) * 0.35
	s.model.rotation.z = sin(elapsed * 0.6 + pos.z * 0.01) * 0.02
	if s.root.global_position.x > PASS_X:
		passed += 1
		banner("%s NARA'YI GEÇTİ" % s.title.to_upper(), "Geçen gemi: %d/%d" % [passed, PASS_LIMIT], 3.0)
		_ship_exits(s)
		return
	_check_mines(s)
	_ship_fire(s, delta)


## Tarihte de Robeck öğleden sonra kayıplar üzerine genel geri çekilme emri verdi.
func _order_retreat() -> void:
	_retreat_ordered = true
	spawn_queue.clear()
	for s in ships:
		if s.afloat() and s.sinking < 0.0 and s.root.global_position.x < 150.0:
			s.waypoints = [Vector3(-1500.0, 0.0, s.root.global_position.z * 0.5)]
			s.hold = 0.0
	banner("FİLO GERİ ÇEKİLİYOR", "Amiral de Robeck geri çekilme emri verdi", 4.0)


## Gemi ilk ara noktasında (bombardıman mevkii) bir süre bekler.
func _is_hold_point(s: Ship) -> bool:
	var line: String = s.spec["line"]
	var total := 3 if line == "A" else (3 if s.spec.get("push", false) else 4)
	return s.waypoints.size() == total


func _ship_exits(s: Ship) -> void:
	s.gone = true
	s.root.queue_free()
	if focus == s:
		focus = null


func _check_mines(s: Ship) -> void:
	var p := s.root.global_position
	for i in range(mines.size() - 1, -1, -1):
		if Vector2(mines[i].x - p.x, mines[i].z - p.z).length() < s.parts["beam"] * 0.5 + 7.0:
			var at := Vector3(mines[i].x, 0.0, mines[i].z)
			Fx.water_splash(self, at, 2.5)
			Fx.explosion(self, at + Vector3(0, 2, 0), 2.0)
			Sfx.play_at("boom", at, 6.0)
			mine_markers[i].queue_free()
			mine_markers.remove_at(i)
			mines.remove_at(i)
			message("%s mayına çarptı!" % s.title, UiTheme.GOLD)
			_damage_ship(s, MINE_DAMAGE)
			return


func _ship_fire(s: Ship, delta: float) -> void:
	s.fire_cd -= delta
	if s.target == null or not s.target.alive() or s.fire_cd <= 0.0:
		s.target = _pick_battery(s.root.global_position)
	var target := s.target
	if target == null:
		return
	for t in s.parts["turrets"]:
		var tn := t as Node3D
		var local := s.model.to_local(target.pos())
		var want := atan2(-local.z, local.x)
		tn.rotation.y = lerp_angle(tn.rotation.y, want, delta * 0.8)
	if s.fire_cd > 0.0:
		return
	s.fire_cd = randf_range(9.0, 15.0)
	var muzzles: Array = s.parts["muzzles"]
	var m: Marker3D = muzzles[randi() % muzzles.size()]
	var from := m.global_position
	var scatter := (50.0 - minf(elapsed * 0.05, 15.0)) * GameState.diff("enemy_scatter")
	var aim := target.pos() + Vector3(randf_range(-scatter, scatter), 0, randf_range(-scatter, scatter))
	aim.y = StraitWorld.height_at(aim.x, aim.z)
	var flight := clampf(from.distance_to(aim) / 160.0, 2.0, 7.0)
	_spawn_shell(from, _ballistic(from, aim, flight), false, false, randf_range(7.0, 11.0) * GameState.diff("enemy_damage"))
	Fx.muzzle_flash(self, from, (aim - from).normalized(), 1.6)
	Sfx.play_at("cannon", from, -2.0)


## Menzildeki tabyalardan birini, yakın olanlara daha çok ağırlık vererek seçer.
func _pick_battery(from: Vector3) -> Battery:
	var total := 0.0
	var weights: Array[float] = []
	for b in batteries:
		var d := b.pos().distance_to(from)
		var w := 0.0 if not b.alive() or d > 1250.0 else 1.0 / maxf(d, 100.0)
		weights.append(w)
		total += w
	if total <= 0.0:
		return null
	var r := randf() * total
	for i in batteries.size():
		r -= weights[i]
		if r <= 0.0 and weights[i] > 0.0:
			return batteries[i]
	return null


func _update_ai_batteries(delta: float) -> void:
	for b in batteries:
		if b.is_player or not b.alive():
			continue
		b.reload -= delta
		var target: Ship = null
		if focus != null and focus.afloat() and focus.root.global_position.distance_to(b.pos()) < 1100.0:
			target = focus
		else:
			var best := 1000.0
			for s in ships:
				if s.afloat() and s.sinking < 0.0:
					var d := s.root.global_position.distance_to(b.pos())
					if d < best:
						best = d
						target = s
		if target == null:
			continue
		var to := target.root.global_position - b.pos()
		b.yaw.rotation.y = lerp_angle(b.yaw.rotation.y, atan2(-to.x, -to.z), delta * 1.5)
		if b.reload > 0.0:
			continue
		b.reload = randf_range(12.0, 18.0)
		var from := b.muzzle.global_position
		var flight := clampf(from.distance_to(target.root.global_position) / 150.0, 1.5, 7.0)
		var lead := target.root.global_position + target.velocity * flight
		var scatter := 30.0
		lead += Vector3(randf_range(-scatter, scatter), randf_range(2.0, 8.0), randf_range(-scatter, scatter) * 0.5)
		_spawn_shell(from, _ballistic(from, lead, flight), false, true, AI_DAMAGE)
		Fx.muzzle_flash(self, from, (lead - from).normalized(), 1.3)
		Sfx.play_at("cannon", from, -3.0)


# ------------------------------------------------------------------ döngü

func mission_process(delta: float) -> void:
	if not running:
		_update_hud()
		return
	while not spawn_queue.is_empty() and elapsed >= float(spawn_queue[0]["delay"]):
		_spawn_ship(spawn_queue.pop_front())
	if not _retreat_ordered and elapsed > RETREAT_TIME:
		_order_retreat()
	if _autoplay:
		_autoplay_step()
	_update_player(delta)
	_update_ai_batteries(delta)
	for s in ships:
		if not s.gone:
			_update_ship(s, delta)
	ships.assign(ships.filter(func(x: Ship) -> bool: return not x.gone))
	for s in ships:
		s.label.visible = s.sinking < 0.0 and (tactical or (s == focus and not zoomed))
	_update_shells(delta)
	_update_hud()
	_check_end()


func _update_hud() -> void:
	set_objective("Batırılan: %d/%d   ·   Nara'yı geçen: %d/%d   ·   Boğazdaki gemi: %d   ·   Mayın: %d" % [sunk, SINK_TARGET, passed, PASS_LIMIT, ships.size(), mines.size()])
	_ammo_label.text = "Mermi  %d / %d" % [ammo, MAX_AMMO]
	_reload_bar.value = 100.0 * (1.0 - reload / reload_time())
	_hp_bar.value = 100.0 * maxf(player.hp, 0.0) / player.max_hp
	_fire_btn.disabled = reload > 0.0 or ammo <= 0 or seyit_time > 0.0 or not player.alive()
	_seyit_btn.disabled = seyit_time > 0.0 or ammo >= MAX_AMMO
	_seyit_btn.text = "SEYİT TAŞIYOR..." if seyit_time > 0.0 else "SEYİT ONBAŞI"


func _check_end() -> void:
	if finished:
		return
	if not player.alive():
		finish(false, 0, 0, ["Rumeli Mecidiye Tabyası sustu.", "Tekrar dene: Seyit Onbaşı'yı zamanında çağır, tabyayı tahkim et."])
	elif passed >= PASS_LIMIT:
		finish(false, 0, 0, ["%d gemi Nara'yı geçti." % passed, "Tarihte hiçbir gemi geçemedi. Nara'ya yaklaşan gemilere ateşi yoğunlaştır."])
	elif spawn_queue.is_empty() and ships.is_empty():
		if sunk >= SINK_TARGET:
			var st := 1 + (1 if player_kills >= 2 else 0) + (1 if player.hp >= player.max_hp * 0.6 else 0)
			finish(true, st, 3 + sunk + player_kills * 2 + st * 2, [
				"Batırılan gemiler: %s" % ", ".join(sunk_names),
				"Senin topunun batırdığı: %d" % player_kills,
				"Tarihte 18 Mart 1915'te Bouvet, Irresistible ve Ocean battı; Inflexible, Suffren ve Gaulois ağır yaralandı.",
				"Boğaz denizden geçilemedi. İtilaf Devletleri 25 Nisan'da Gelibolu'ya çıkarma kararı aldı."])
		else:
			finish(false, 0, 0, ["Filo geri çekildi ama yalnızca %d gemi batırıldı (hedef %d)." % [sunk, SINK_TARGET]])
