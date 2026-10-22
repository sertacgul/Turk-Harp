class_name PeninsulaWorld
extends Node3D
## Arıburnu (Gelibolu) prosedürel arazisi: batıda Ege ve ANZAC Koyu kumsalı,
## kumsaldan yükselen yarlar ve dereler, doğuda Conkbayırı.
## Koordinatlar: -X batı (deniz), +X doğu; -Z kuzey (Conkbayırı yönü), +Z güney.

const X_MIN := -1000.0
const X_MAX := 800.0
const Z_HALF := 750.0

const CONKBAYIRI := Vector3(330.0, 0.0, -190.0)
const CESARET_TEPE := Vector3(110.0, 0.0, -40.0)
const KIRMIZI_SIRT := Vector3(95.0, 0.0, 125.0)

static var _noise: FastNoiseLite

var environment: Environment
var sun: DirectionalLight3D


static func noise() -> FastNoiseLite:
	if _noise == null:
		_noise = FastNoiseLite.new()
		_noise.seed = 425
		_noise.frequency = 0.006
		_noise.fractal_octaves = 4
	return _noise


static func _s(t: float) -> float:
	t = clampf(t, 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


## Kıyı çizgisinin x konumu; ANZAC Koyu z=0 civarında küçük bir girinti yapar.
static func shore_x(z: float) -> float:
	return -260.0 + 22.0 * sin(z * 0.009) + 35.0 * exp(-pow(z / 90.0, 2.0)) + noise().get_noise_1d(z * 0.5) * 12.0


static func land_depth(x: float, z: float) -> float:
	return x - shore_x(z)


static func height_at(x: float, z: float) -> float:
	var d := land_depth(x, z)
	if d < 0.0:
		return maxf(d * 0.15, -25.0)
	var h := 1.5 + minf(d, 18.0) * 0.1
	h += 55.0 * _s((d - 18.0) / 70.0)
	h += 75.0 * _s((d - 160.0) / 280.0)
	var c := Vector2(x - CONKBAYIRI.x, z - CONKBAYIRI.z)
	h += 45.0 * exp(-c.length_squared() / (150.0 * 150.0))
	# Batıya inen dereler
	var gully := pow(0.5 + 0.5 * cos(z * 0.021 + noise().get_noise_2d(x, z) * 2.0), 4.0)
	h -= gully * 26.0 * _s((d - 30.0) / 60.0) * (1.0 - _s((d - 380.0) / 120.0))
	h += noise().get_noise_2d(x * 1.7, z * 1.7) * 9.0 * _s(d / 40.0)
	return h


static func is_water(x: float, z: float) -> bool:
	return land_depth(x, z) < -1.0


static func ground(p: Vector3) -> Vector3:
	return Vector3(p.x, height_at(p.x, p.z), p.z)


func build() -> void:
	var atm := Atmosphere.build(self, "dawn")
	environment = atm["environment"]
	sun = atm["sun"]
	Atmosphere.water(self, Vector3(-900.0, 0.0, 0.0), Vector2(2600.0, 3000.0), "dawn")
	_build_terrain()
	_build_scrub()
	_build_boats()


func _color(h: float, slope: float, d: float, x: float, z: float) -> Color:
	var n := noise().get_noise_2d(x * 4.0, z * 4.0) * 0.5 + 0.5
	if h < -0.3:
		return Color(0.45, 0.42, 0.33).lerp(Color(0.22, 0.24, 0.22), clampf(-h / 15.0, 0.0, 1.0))
	if d < 20.0:
		return Color(0.8, 0.73, 0.56)
	var scrub := Color(0.27, 0.31, 0.15).lerp(Color(0.4, 0.38, 0.22), n)
	var earth := Color(0.52, 0.4, 0.28)
	# Kırmızı Sırt kızıl topraklı yamaçlarıyla bilinir.
	var red := Vector2(x - KIRMIZI_SIRT.x, z - KIRMIZI_SIRT.z).length() < 130.0
	if red:
		earth = Color(0.62, 0.36, 0.24)
	return scrub.lerp(earth, clampf((slope - 0.45) * 2.2, 0.0, 1.0))


func _build_terrain() -> void:
	var step := 7.0 if GameState.high_quality() else 11.0
	var nx := int((X_MAX - X_MIN) / step) + 1
	var nz := int(Z_HALF * 2.0 / step) + 1
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for iz in nz:
		for ix in nx:
			var x := X_MIN + ix * step
			var z := -Z_HALF + iz * step
			var h := height_at(x, z)
			var slope := Vector2(height_at(x + step, z) - h, height_at(x, z + step) - h).length() / step
			st.set_color(_color(h, slope, land_depth(x, z), x, z))
			st.add_vertex(Vector3(x, h, z))
	for iz in nz - 1:
		for ix in nx - 1:
			var a := iz * nx + ix
			for i in [a, a + 1, a + nx, a + 1, a + nx + 1, a + nx]:
				st.add_index(i)
	st.generate_normals()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.97
	var tex := NoiseTexture2D.new()
	tex.seamless = true
	tex.width = 256
	tex.height = 256
	var tn := FastNoiseLite.new()
	tn.frequency = 0.08
	tex.noise = tn
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0.7, 0.7, 0.7))
	ramp.set_color(1, Color(1, 1, 1))
	tex.color_ramp = ramp
	mat.albedo_texture = tex
	mat.uv1_triplanar = true
	mat.uv1_scale = Vector3(0.12, 0.12, 0.12)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	add_child(mi)


func _build_scrub() -> void:
	var count := 5000 if GameState.high_quality() else 1600
	var bush := SphereMesh.new()
	bush.radius = 1.0
	bush.height = 1.3
	bush.radial_segments = 6
	bush.rings = 3
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.17, 0.22, 0.1)
	m.roughness = 1.0
	bush.material = m
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = bush
	var rng := RandomNumberGenerator.new()
	rng.seed = 1915
	var xf: Array[Transform3D] = []
	var tries := 0
	while xf.size() < count and tries < count * 8:
		tries += 1
		var x := rng.randf_range(X_MIN + 300.0, X_MAX)
		var z := rng.randf_range(-Z_HALF, Z_HALF)
		if land_depth(x, z) < 25.0:
			continue
		var s := rng.randf_range(0.8, 2.4)
		xf.append(Transform3D(Basis.from_scale(Vector3(s, s * 0.7, s)).rotated(Vector3.UP, rng.randf() * TAU), Vector3(x, height_at(x, z) + 0.3 * s, z)))
	mm.instance_count = xf.size()
	for i in xf.size():
		mm.set_instance_transform(i, xf[i])
	var inst := MultiMeshInstance3D.new()
	inst.multimesh = mm
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(inst)


## Kumsala çekilmiş çıkarma sandalları.
func _build_boats() -> void:
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.36, 0.28, 0.2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 25
	for i in 14:
		var z := rng.randf_range(-170.0, 170.0)
		var x := shore_x(z) + rng.randf_range(-6.0, 4.0)
		var b := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(9.0, 1.2, 2.6)
		box.material = wood
		b.mesh = box
		b.position = Vector3(x, maxf(height_at(x, z), 0.0) + 0.4, z)
		b.rotation.y = rng.randf_range(-0.4, 0.4)
		add_child(b)
