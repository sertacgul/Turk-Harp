class_name StraitWorld
extends Node3D
## Çanakkale Boğazı'nın prosedürel 3D modeli: kara, su, gökyüzü, ışık, köyler ve kaleler.
## Koordinatlar: +X Marmara'ya (Nara) doğru, -X Ege'ye; -Z Rumeli (Gelibolu), +Z Anadolu yakası.

const X_MIN := -1800.0
const X_MAX := 1400.0
const Z_HALF := 1400.0
const NARROWS_X := 300.0

static var _noise: FastNoiseLite

var night := false
var environment: Environment
var sun: DirectionalLight3D


static func noise() -> FastNoiseLite:
	if _noise == null:
		_noise = FastNoiseLite.new()
		_noise.seed = 1915
		_noise.frequency = 0.0035
		_noise.fractal_octaves = 4
	return _noise


static func _smooth01(t: float) -> float:
	t = clampf(t, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


## Rumeli kıyısının boğaz merkezine uzaklığı.
static func north_half_width(x: float) -> float:
	return 160.0 + 230.0 * _smooth01((NARROWS_X - x) / 1700.0) + 70.0 * _smooth01((x - NARROWS_X) / 600.0)


## Anadolu kıyısının uzaklığı; Erenköy Koyu bir girinti yapar.
static func south_half_width(x: float) -> float:
	var bay := 170.0 * exp(-pow((x + 450.0) / 270.0, 2.0))
	return 160.0 + 230.0 * _smooth01((NARROWS_X - x) / 1700.0) + 90.0 * _smooth01((x - NARROWS_X) / 600.0) + bay


## Kıyıdan karaya doğru mesafe (denizde negatif).
static func land_depth(x: float, z: float) -> float:
	if z < 0.0:
		return -z - north_half_width(x)
	return z - south_half_width(x)


static func height_at(x: float, z: float) -> float:
	var d := land_depth(x, z)
	if d < 0.0:
		return maxf(d * 0.12, -30.0)
	var n := noise().get_noise_2d(x, z) * 0.5 + 0.5
	var hills := _smooth01(d / 160.0) * (25.0 + n * 85.0)
	var ridge := _smooth01((d - 250.0) / 400.0) * 60.0
	return 1.5 + minf(d * 0.25, 4.0) + hills + ridge


static func is_water(x: float, z: float) -> bool:
	return land_depth(x, z) < -2.0


## Tarihî mayın hattı: Erenköy Koyu'nda kıyıya paralel 26 mayın.
static func default_mine_line() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for i in 26:
		var x := -620.0 + i * 13.0
		out.append(Vector3(x, 0.0, south_half_width(x) - 95.0))
	return out


## Erenköy Koyu'ndaki mayın döşeme bölgesi.
static func bay_zone_center() -> Vector3:
	return Vector3(-460.0, 0.0, south_half_width(-460.0) - 110.0)


func build(is_night: bool) -> void:
	night = is_night
	_build_environment()
	_build_water()
	_build_terrain()
	_build_trees()
	_build_settlements()


func _build_environment() -> void:
	var atm := Atmosphere.build(self, "night" if night else "day")
	environment = atm["environment"]
	sun = atm["sun"]


func _build_water() -> void:
	var bounds := Vector4(X_MIN, -Z_HALF, X_MAX - X_MIN, Z_HALF * 2.0)
	var heights := Atmosphere.bake_heights(func(x: float, z: float) -> float: return height_at(x, z), bounds)
	Atmosphere.water(self, Vector3((X_MIN + X_MAX) * 0.5, 0.0, 0.0),
		Vector2(X_MAX - X_MIN + 2000.0, Z_HALF * 2.0 + 2000.0), "night" if night else "day", heights, bounds)


func _terrain_color(h: float, slope: float, x: float, z: float) -> Color:
	var n := noise().get_noise_2d(x * 3.0, z * 3.0) * 0.5 + 0.5
	if h < -0.5:
		return Color(0.42, 0.38, 0.28).lerp(Color(0.2, 0.22, 0.2), clampf(-h / 20.0, 0.0, 1.0))
	if h < 4.5:
		return Color(0.78, 0.7, 0.52)
	var grass := Color(0.36, 0.42, 0.2).lerp(Color(0.5, 0.48, 0.28), n)
	var rock := Color(0.48, 0.43, 0.36)
	return grass.lerp(rock, clampf((slope - 0.35) * 2.5 + (h - 90.0) / 80.0, 0.0, 1.0))


func _build_terrain() -> void:
	var step := 18.0 if GameState.high_quality() else 28.0
	var nx := int((X_MAX - X_MIN) / step) + 1
	var nz := int(Z_HALF * 2.0 / step) + 1
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for iz in nz:
		for ix in nx:
			var x := X_MIN + ix * step
			var z := -Z_HALF + iz * step
			var h := height_at(x, z)
			var hx := height_at(x + step, z) - h
			var hz := height_at(x, z + step) - h
			var slope := Vector2(hx, hz).length() / step
			st.set_color(_terrain_color(h, slope, x, z))
			st.set_uv(Vector2(x, z) * 0.02)
			st.add_vertex(Vector3(x, h, z))
	for iz in nz - 1:
		for ix in nx - 1:
			var a := iz * nx + ix
			st.add_index(a)
			st.add_index(a + 1)
			st.add_index(a + nx)
			st.add_index(a + 1)
			st.add_index(a + nx + 1)
			st.add_index(a + nx)
	st.generate_normals()
	var mesh := st.commit()
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/terrain.gdshader")
	mat.set_shader_parameter("rock_color", Color(0.5, 0.46, 0.4))
	AssetLib.apply_terrain_textures(mat)
	mat.set_shader_parameter("octaves", 5 if GameState.high_quality() else 3)
	var terrain := MeshInstance3D.new()
	terrain.mesh = mesh
	terrain.material_override = mat
	add_child(terrain)


func _build_trees() -> void:
	var count := 2200 if GameState.high_quality() else 700
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 4.0
	cone.height = 12.0
	cone.radial_segments = 6
	cone.rings = 1
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.16, 0.24, 0.12) if not night else Color(0.05, 0.08, 0.05)
	mat.roughness = 1.0
	cone.material = mat
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = cone
	var rng := RandomNumberGenerator.new()
	rng.seed = 57
	var placed: Array[Transform3D] = []
	var tries := 0
	while placed.size() < count and tries < count * 12:
		tries += 1
		var x := rng.randf_range(X_MIN, X_MAX)
		var z := rng.randf_range(-Z_HALF, Z_HALF)
		var d := land_depth(x, z)
		if d < 40.0:
			continue
		if noise().get_noise_2d(x * 2.0 + 300.0, z * 2.0) < 0.05:
			continue
		var h := height_at(x, z)
		var s := rng.randf_range(0.7, 1.6)
		var b := Basis.from_scale(Vector3(s, s * rng.randf_range(0.8, 1.3), s))
		placed.append(Transform3D(b, Vector3(x, h + 5.0 * s, z)))
	mm.instance_count = placed.size()
	for i in placed.size():
		mm.set_instance_transform(i, placed[i])
	var inst := MultiMeshInstance3D.new()
	inst.multimesh = mm
	add_child(inst)
	# Kıyı kayalıkları (yalnızca indirilmiş modeller varsa).
	var shore := func(x: float, z: float) -> bool:
		var d := land_depth(x, z)
		return d > -2.0 and d < 45.0 and noise().get_noise_2d(x * 3.0, z * 3.0 + 50.0) > 0.0
	AssetLib.scatter_models(self, "rock", 1600 if GameState.high_quality() else 500, Vector4(X_MIN, -Z_HALF, X_MAX, Z_HALF),
		func(x: float, z: float) -> float: return height_at(x, z), shore, Vector2(1.5, 5.0), 21, 900.0)


func _build_settlements() -> void:
	# Kilitbahir (Rumeli) ve Çanakkale/Çimenlik (Anadolu) Nara'nın iki yakasında.
	_castle(Vector3(250.0, 0.0, -north_half_width(250.0) - 30.0), true)
	_castle(Vector3(360.0, 0.0, south_half_width(360.0) + 30.0), false)
	_village(Vector3(270.0, 0.0, -north_half_width(270.0) - 90.0), 26, 51)
	_village(Vector3(420.0, 0.0, south_half_width(420.0) + 90.0), 60, 52)
	_village(Vector3(-460.0, 0.0, south_half_width(-460.0) + 120.0), 14, 53)
	_lighthouse(Vector3(-1500.0, 0.0, -north_half_width(-1500.0) - 15.0))
	_lighthouse(Vector3(-1450.0, 0.0, south_half_width(-1450.0) + 15.0))


func _stone_mat() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.72, 0.66, 0.55)
	m.roughness = 0.9
	return m


func _box(size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	b.material = mat
	mi.mesh = b
	mi.position = pos
	add_child(mi)
	return mi


func _cyl(r: float, h: float, pos: Vector3, mat: Material, top := -1.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = r if top < 0.0 else top
	c.bottom_radius = r
	c.height = h
	c.material = mat
	mi.mesh = c
	mi.position = pos
	add_child(mi)
	return mi


func _castle(at: Vector3, heart_shaped: bool) -> void:
	var stone := _stone_mat()
	var g := height_at(at.x, at.z)
	_box(Vector3(70, 14, 50), Vector3(at.x, g + 5.0, at.z), stone)
	for c in [Vector3(-35, 0, -25), Vector3(35, 0, -25), Vector3(-35, 0, 25), Vector3(35, 0, 25)]:
		_cyl(7.0, 20.0, Vector3(at.x + c.x, g + 8.0, at.z + c.z), stone)
	if heart_shaped:
		_cyl(16.0, 34.0, Vector3(at.x, g + 15.0, at.z), stone)
	else:
		_box(Vector3(26, 32, 26), Vector3(at.x, g + 14.0, at.z), stone)


func _village(center: Vector3, count: int, seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var wall := StandardMaterial3D.new()
	wall.albedo_color = Color(0.86, 0.82, 0.74)
	var roof := StandardMaterial3D.new()
	roof.albedo_color = Color(0.62, 0.27, 0.18)
	var lit := StandardMaterial3D.new()
	lit.albedo_color = Color(1.0, 0.75, 0.35)
	lit.emission_enabled = true
	lit.emission = Color(1.0, 0.7, 0.3)
	lit.emission_energy_multiplier = 3.0
	for i in count:
		var p := center + Vector3(rng.randf_range(-90, 90), 0.0, rng.randf_range(-60, 60))
		if land_depth(p.x, p.z) < 12.0:
			continue
		var h := height_at(p.x, p.z)
		var w := rng.randf_range(7, 12)
		var d := rng.randf_range(6, 9)
		var house := _box(Vector3(w, 6, d), Vector3(p.x, h + 2.5, p.z), wall)
		house.rotation.y = rng.randf_range(0.0, PI)
		var r := MeshInstance3D.new()
		var prism := PrismMesh.new()
		prism.size = Vector3(w + 1.0, 3.5, d + 1.0)
		prism.material = roof
		r.mesh = prism
		r.position = Vector3(0, 4.75, 0)
		house.add_child(r)
		if night and rng.randf() < 0.35:
			var win := MeshInstance3D.new()
			var q := BoxMesh.new()
			q.size = Vector3(1.4, 1.4, 0.2)
			q.material = lit
			win.mesh = q
			win.position = Vector3(0, 0.5, d * 0.5 + 0.05)
			house.add_child(win)


func _lighthouse(at: Vector3) -> void:
	var g := height_at(at.x, at.z)
	var white := StandardMaterial3D.new()
	white.albedo_color = Color(0.92, 0.9, 0.86)
	_cyl(4.5, 26.0, Vector3(at.x, g + 13.0, at.z), white, 3.2)
	var lamp := StandardMaterial3D.new()
	lamp.albedo_color = Color(1.0, 0.9, 0.6)
	lamp.emission_enabled = true
	lamp.emission = Color(1.0, 0.85, 0.5)
	lamp.emission_energy_multiplier = 6.0 if night else 1.0
	_cyl(3.0, 3.0, Vector3(at.x, g + 27.5, at.z), lamp)
	if night:
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.85, 0.55)
		l.omni_range = 120.0
		l.light_energy = 2.0
		l.position = Vector3(at.x, g + 30.0, at.z)
		add_child(l)
