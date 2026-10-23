class_name Vegetation
extends RefCounted
## Çimen öbekleri ve maki çalıları: kodla çizilmiş yaprak dokulu çapraz kartlar (MultiMesh).

static var _cache := {}


## Çimen yaprakları dokusu (alfa kanalı yaprak biçimi).
static func _grass_texture() -> ImageTexture:
	if _cache.has("grass_tex"):
		return _cache["grass_tex"]
	var w := 128
	var h := 128
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 46:
		var x0 := rng.randf_range(8.0, w - 8.0)
		var top := rng.randf_range(h * 0.05, h * 0.6)
		var lean := rng.randf_range(-22.0, 22.0)
		var shade := rng.randf_range(0.35, 0.55)
		var steps := int(h - top)
		for s in steps:
			var t := float(s) / steps
			var y := int(h - 1 - s)
			var x := x0 + lean * t * t
			var width := lerpf(2.6, 0.4, t)
			for dx in range(int(-width), int(width) + 1):
				var px := int(x) + dx
				if px >= 0 and px < w and y >= 0:
					var c := shade * lerpf(0.7, 1.0, t)
					img.set_pixel(px, y, Color(c, c * 1.05, c * 0.6, 1.0))
	img.generate_mipmaps()
	var tex := ImageTexture.create_from_image(img)
	_cache["grass_tex"] = tex
	return tex


## Maki çalısı dokusu: yuvarlak hatlı, iç içe küçük yapraklar.
static func _bush_texture() -> ImageTexture:
	if _cache.has("bush_tex"):
		return _cache["bush_tex"]
	var n := 128
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 13
	var c := Vector2(n * 0.5, n * 0.58)
	for i in 900:
		var a := rng.randf() * TAU
		var r := sqrt(rng.randf()) * n * 0.44
		var p := c + Vector2(cos(a) * r, sin(a) * r * 0.85)
		if p.y > n - 4:
			continue
		var shade := rng.randf_range(0.3, 0.55) * (1.0 - r / (n * 0.6) * 0.4)
		var lr := rng.randf_range(1.5, 3.2)
		for dy in range(-3, 4):
			for dx in range(-4, 5):
				if Vector2(dx / lr, dy / (lr * 0.6)).length() <= 1.0:
					var px := int(p.x) + dx
					var py := int(p.y) + dy
					if px >= 0 and px < n and py >= 0 and py < n:
						img.set_pixel(px, py, Color(shade * 0.9, shade, shade * 0.55, 1.0))
	img.generate_mipmaps()
	var tex := ImageTexture.create_from_image(img)
	_cache["bush_tex"] = tex
	return tex


## Üç kartlı yıldız biçimli öbek (yaprak düzlemleri 60° arayla).
static func _cards(width: float, height: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in 3:
		var a := PI / 3.0 * k
		var d := Vector3(cos(a), 0, sin(a)) * width * 0.5
		var n := Vector3(-sin(a), 0, cos(a))
		var q := [[-d, Vector2(0, 1)], [d, Vector2(1, 1)], [d + Vector3(0, height, 0), Vector2(1, 0)], [-d + Vector3(0, height, 0), Vector2(0, 0)]]
		for idx in [0, 1, 2, 0, 2, 3]:
			st.set_normal(n)
			st.set_uv(q[idx][1])
			st.add_vertex(q[idx][0])
	return st.commit()


static func _material(tex: Texture2D, a: Color, b: Color, wind: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/foliage.gdshader")
	m.set_shader_parameter("albedo_tex", tex)
	m.set_shader_parameter("tint_a", a)
	m.set_shader_parameter("tint_b", b)
	m.set_shader_parameter("wind_strength", wind)
	return m


## area: (x0, z0, x1, z1). accept(x, z) true ise oraya bitki konur. height_fn(x, z) zemin yüksekliği.
static func scatter(parent: Node3D, kind: String, count: int, area: Vector4, height_fn: Callable, accept: Callable, seed := 1, fade_end := 260.0) -> void:
	var grass := kind == "grass"
	var mesh := _cards(1.1, 0.75) if grass else _cards(2.4, 1.9)
	mesh.surface_set_material(0, _material(_grass_texture() if grass else _bush_texture(),
		Color(0.34, 0.4, 0.16) if grass else Color(0.3, 0.4, 0.17),
		Color(0.56, 0.5, 0.26) if grass else Color(0.42, 0.44, 0.22), 0.14 if grass else 0.05))
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var xf: Array[Transform3D] = []
	var tries := 0
	while xf.size() < count and tries < count * 6:
		tries += 1
		var x := rng.randf_range(area.x, area.z)
		var z := rng.randf_range(area.y, area.w)
		if not accept.call(x, z):
			continue
		var s := rng.randf_range(0.7, 1.4) if grass else rng.randf_range(0.6, 1.5)
		var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(0.8, 1.2), s))
		xf.append(Transform3D(basis, Vector3(x, float(height_fn.call(x, z)) - 0.05, z)))
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xf.size()
	for i in xf.size():
		mm.set_instance_transform(i, xf[i])
	var inst := MultiMeshInstance3D.new()
	inst.multimesh = mm
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if grass else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	inst.visibility_range_end = fade_end
	inst.visibility_range_end_margin = 40.0
	inst.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	parent.add_child(inst)
