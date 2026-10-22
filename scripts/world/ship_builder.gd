class_name ShipBuilder
extends RefCounted
## 1915 dönemi gemilerini primitiflerden üretir. Geminin burnu yerel +X yönündedir.
## Döndürülen sözlük: root, turrets (döner kule pivotları), muzzles, funnels, searchlight, length, beam.

const HULL_GREY := Color(0.42, 0.45, 0.48)
const DARK_GREY := Color(0.26, 0.28, 0.3)
const DECK := Color(0.55, 0.45, 0.32)
const RED_HULL := Color(0.42, 0.13, 0.1)


static func flag_texture(nation: String) -> ImageTexture:
	var w := 60
	var h := 40
	var img := Image.create(w, h, false, Image.FORMAT_RGB8)
	var red := Color(0.8, 0.06, 0.12)
	var white := Color(0.97, 0.97, 0.97)
	var blue := Color(0.05, 0.15, 0.45)
	for y in h:
		for x in w:
			var c := white
			match nation:
				"tr":
					c = red
					var p := Vector2(x, y)
					var outer := p.distance_to(Vector2(23, 20)) < 11.0
					var inner := p.distance_to(Vector2(26, 20)) < 9.0
					if outer and not inner:
						c = white
					if _in_star(p, Vector2(37, 20), 5.0):
						c = white
				"fr":
					c = blue if x < w / 3 else (white if x < 2 * w / 3 else Color(0.85, 0.1, 0.15))
				_:
					# Beyaz Sancak: kırmızı haç, sol üstte Birlik bayrağı
					if abs(x - w / 2) < 3 or abs(y - h / 2) < 3:
						c = red
					if x < w / 2 and y < h / 2:
						c = blue
						var fx := float(x) / (w / 2.0)
						var fy := float(y) / (h / 2.0)
						if abs(fx - fy) < 0.12 or abs(fx - (1.0 - fy)) < 0.12:
							c = white
						if abs(x - w / 4) < 2 or abs(y - h / 4) < 2:
							c = red
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


static func _in_star(p: Vector2, center: Vector2, r: float) -> bool:
	var pts: Array[Vector2] = []
	for i in 10:
		var a := -PI / 2.0 + i * PI / 5.0 + PI / 2.0
		var rr := r if i % 2 == 0 else r * 0.42
		pts.append(center + Vector2(cos(a), sin(a)) * rr)
	return Geometry2D.is_point_in_polygon(p, PackedVector2Array(pts))


static func _mat(color: Color, rough := 0.7, metal := 0.2) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metal
	return m


static func _add_box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	b.material = mat
	mi.mesh = b
	mi.position = pos
	parent.add_child(mi)
	return mi


static func _add_cyl(parent: Node3D, r: float, h: float, pos: Vector3, mat: Material, top := -1.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = r if top < 0.0 else top
	c.bottom_radius = r
	c.height = h
	c.radial_segments = 12
	c.material = mat
	mi.mesh = c
	mi.position = pos
	parent.add_child(mi)
	return mi


static func _hull_mesh(length: float, beam: float, freeboard: float, draft: float, hull_color: Color) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sections := 28
	var rings: Array = []
	for i in sections + 1:
		var t := float(i) / sections
		var x := (t - 0.5) * length
		var w := beam * 0.5
		if t > 0.72:
			var k := (t - 0.72) / 0.28
			w *= sqrt(maxf(1.0 - k * k, 0.0))
		elif t < 0.12:
			w *= 0.72 + 0.28 * (t / 0.12)
		w = maxf(w, 0.05)
		var fb := freeboard + (maxf(t - 0.8, 0.0) * 5.0) * freeboard * 0.5
		var ring := [
			Vector3(x, fb, -w), Vector3(x, 0.0, -w * 0.98), Vector3(x, -draft * 0.7, -w * 0.72),
			Vector3(x, -draft, 0.0),
			Vector3(x, -draft * 0.7, w * 0.72), Vector3(x, 0.0, w * 0.98), Vector3(x, fb, w)]
		rings.append(ring)
	var col := func(v: Vector3) -> Color: return hull_color if v.y >= -0.2 else RED_HULL
	for i in sections:
		var a: Array = rings[i]
		var b: Array = rings[i + 1]
		for j in a.size() - 1:
			for v in [a[j], b[j], b[j + 1], a[j], b[j + 1], a[j + 1]]:
				st.set_color(col.call(v))
				st.add_vertex(v)
	# Güverte
	for i in sections:
		var a: Array = rings[i]
		var b: Array = rings[i + 1]
		for v in [a[0], a[6], b[6], a[0], b[6], b[0]]:
			st.set_color(DECK)
			st.add_vertex(v - Vector3(0, 0.15, 0))
	# Kıç aynası
	var s: Array = rings[0]
	for j in range(1, s.size() - 1):
		for v in [s[0], s[j + 1], s[j]]:
			st.set_color(col.call(v))
			st.add_vertex(v)
	st.generate_normals()
	return st.commit()


static func _flag(parent: Node3D, nation: String, pos: Vector3, size: float) -> void:
	var q := QuadMesh.new()
	q.size = Vector2(size * 1.5, size)
	q.subdivide_width = 8
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/flag.gdshader")
	m.set_shader_parameter("flag_texture", flag_texture(nation))
	q.material = m
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.position = pos + Vector3(-size * 0.75, 0, 0)
	mi.rotation.y = PI
	parent.add_child(mi)


static func _turret(parent: Node3D, pos: Vector3, beam: float, facing: float, barrel_len: float, mat: Material, out: Dictionary) -> void:
	_add_cyl(parent, beam * 0.2, 1.2, pos + Vector3(0, -0.4, 0), mat)
	var pivot := Node3D.new()
	pivot.position = pos + Vector3(0, 0.6, 0)
	pivot.rotation.y = facing
	parent.add_child(pivot)
	_add_box(pivot, Vector3(beam * 0.34, beam * 0.16, beam * 0.3), Vector3.ZERO, mat)
	for side in [-1.0, 1.0]:
		var barrel := _add_cyl(pivot, beam * 0.025, barrel_len, Vector3(beam * 0.17 + barrel_len * 0.5, 0.1, side * beam * 0.07), mat)
		barrel.rotation.z = PI / 2.0
	var muzzle := Marker3D.new()
	muzzle.position = Vector3(beam * 0.17 + barrel_len, 0.1, 0)
	pivot.add_child(muzzle)
	out["turrets"].append(pivot)
	out["muzzles"].append(muzzle)


static func build_battleship(nation: String, length := 75.0, beam := 13.0, funnels := 2) -> Dictionary:
	var root := Node3D.new()
	var out := {"root": root, "turrets": [], "muzzles": [], "funnels": [], "length": length, "beam": beam}
	var hull_color := HULL_GREY if nation == "uk" else Color(0.36, 0.38, 0.36)
	var freeboard := beam * 0.42
	var hull := MeshInstance3D.new()
	hull.mesh = _hull_mesh(length, beam, freeboard, beam * 0.45, hull_color)
	var hm := StandardMaterial3D.new()
	hm.vertex_color_use_as_albedo = true
	hm.roughness = 0.75
	hm.metallic = 0.25
	hm.cull_mode = BaseMaterial3D.CULL_DISABLED
	hull.material_override = hm
	root.add_child(hull)

	var steel := _mat(hull_color.lightened(0.08))
	var dark := _mat(DARK_GREY)
	var black := _mat(Color(0.08, 0.08, 0.08))
	var y0 := freeboard
	# Üst yapı
	_add_box(root, Vector3(length * 0.32, beam * 0.32, beam * 0.62), Vector3(-length * 0.02, y0 + beam * 0.16, 0), steel)
	_add_box(root, Vector3(length * 0.08, beam * 0.5, beam * 0.42), Vector3(length * 0.17, y0 + beam * 0.3, 0), steel)
	_add_box(root, Vector3(length * 0.05, beam * 0.12, beam * 0.75), Vector3(length * 0.17, y0 + beam * 0.58, 0), dark)
	# Bacalar
	for i in funnels:
		var fx := lerpf(-length * 0.1, length * 0.08, 0.5 if funnels == 1 else float(i) / (funnels - 1))
		var f := _add_cyl(root, beam * 0.1, beam * 0.95, Vector3(fx, y0 + beam * 0.78, 0), _mat(Color(0.3, 0.3, 0.3) if nation == "uk" else Color(0.45, 0.42, 0.38)))
		f.scale = Vector3(1.0, 1.0, 1.25)
		_add_cyl(root, beam * 0.105, beam * 0.15, Vector3(fx, y0 + beam * 1.2, 0), black)
		var top := Marker3D.new()
		top.position = Vector3(fx, y0 + beam * 1.3, 0)
		root.add_child(top)
		out["funnels"].append(top)
	# Direkler
	for mx in [length * 0.24, -length * 0.22]:
		_add_cyl(root, beam * 0.035, beam * 2.3, Vector3(mx, y0 + beam * 1.15, 0), dark, beam * 0.02)
		_add_cyl(root, beam * 0.11, beam * 0.12, Vector3(mx, y0 + beam * 1.5, 0), dark)
		var yard := _add_box(root, Vector3(0.3, 0.3, beam * 0.8), Vector3(mx, y0 + beam * 1.8, 0), dark)
		yard.name = "Yard"
	# Ana toplar
	_turret(root, Vector3(length * 0.31, y0, 0), beam, 0.0, beam * 0.75, steel, out)
	_turret(root, Vector3(-length * 0.31, y0, 0), beam, PI, beam * 0.75, steel, out)
	# Yan toplar
	for sx in [-0.12, 0.0, 0.12]:
		for side in [-1.0, 1.0]:
			var g := _add_cyl(root, beam * 0.02, beam * 0.3, Vector3(length * sx, y0 - beam * 0.08, side * beam * 0.52), dark)
			g.rotation.x = PI / 2.0
	_add_cyl(root, 0.15, beam * 0.6, Vector3(-length * 0.49, y0 + beam * 0.3, 0), dark)
	_flag(root, nation, Vector3(-length * 0.49, y0 + beam * 0.5, 0), beam * 0.22)
	return out


static func build_destroyer(nation: String) -> Dictionary:
	var length := 46.0
	var beam := 6.0
	var root := Node3D.new()
	var out := {"root": root, "turrets": [], "muzzles": [], "funnels": [], "length": length, "beam": beam}
	var hull := MeshInstance3D.new()
	hull.mesh = _hull_mesh(length, beam, beam * 0.45, beam * 0.4, Color(0.25, 0.27, 0.29))
	var hm := StandardMaterial3D.new()
	hm.vertex_color_use_as_albedo = true
	hm.cull_mode = BaseMaterial3D.CULL_DISABLED
	hull.material_override = hm
	root.add_child(hull)
	var steel := _mat(Color(0.3, 0.32, 0.34))
	var y0 := beam * 0.45
	_add_box(root, Vector3(5, 3, 3.2), Vector3(length * 0.25, y0 + 1.5, 0), steel)
	for i in 3:
		var fx := -2.0 + i * 5.0
		_add_cyl(root, 0.7, 4.5, Vector3(fx - 6.0, y0 + 2.2, 0), _mat(Color(0.18, 0.18, 0.18)))
		var top := Marker3D.new()
		top.position = Vector3(fx - 6.0, y0 + 4.6, 0)
		root.add_child(top)
		out["funnels"].append(top)
	_add_cyl(root, 0.18, 12.0, Vector3(length * 0.18, y0 + 6.0, 0), steel)
	_turret(root, Vector3(length * 0.38, y0, 0), beam, 0.0, 3.0, steel, out)
	# Işıldak: köprü üstünde yönlendirilebilir pivot
	var sl := Node3D.new()
	sl.position = Vector3(length * 0.25, y0 + 3.6, 0)
	root.add_child(sl)
	_add_cyl(sl, 0.6, 0.8, Vector3.ZERO, _mat(Color(0.2, 0.2, 0.2)))
	out["searchlight"] = sl
	_flag(root, nation, Vector3(-length * 0.49, y0 + 2.0, 0), 1.6)
	return out


static func build_nusret() -> Dictionary:
	var length := 36.0
	var beam := 7.5
	var root := Node3D.new()
	var out := {"root": root, "turrets": [], "muzzles": [], "funnels": [], "length": length, "beam": beam}
	var hull := MeshInstance3D.new()
	hull.mesh = _hull_mesh(length, beam, beam * 0.4, beam * 0.35, Color(0.2, 0.21, 0.22))
	var hm := StandardMaterial3D.new()
	hm.vertex_color_use_as_albedo = true
	hm.cull_mode = BaseMaterial3D.CULL_DISABLED
	hull.material_override = hm
	root.add_child(hull)
	var y0 := beam * 0.4
	var paint := _mat(Color(0.32, 0.33, 0.33))
	_add_box(root, Vector3(7, 3, 4.5), Vector3(4.0, y0 + 1.5, 0), paint)
	_add_box(root, Vector3(4, 1.6, 5.5), Vector3(5.5, y0 + 3.6, 0), _mat(Color(0.45, 0.38, 0.28)))
	_add_cyl(root, 0.9, 5.0, Vector3(-1.5, y0 + 2.8, 0), _mat(Color(0.15, 0.15, 0.15)))
	var top := Marker3D.new()
	top.position = Vector3(-1.5, y0 + 5.4, 0)
	root.add_child(top)
	out["funnels"].append(top)
	_add_cyl(root, 0.15, 11.0, Vector3(9.0, y0 + 5.5, 0), paint)
	# Kıçtaki mayın rayları ve mayınlar
	var mine_mat := _mat(Color(0.1, 0.1, 0.1), 0.5, 0.6)
	for side in [-1.4, 1.4]:
		_add_box(root, Vector3(14, 0.2, 0.3), Vector3(-9.0, y0 + 0.1, side), paint)
		for i in 4:
			var m := MeshInstance3D.new()
			var s := SphereMesh.new()
			s.radius = 0.55
			s.height = 1.1
			s.material = mine_mat
			m.mesh = s
			m.position = Vector3(-15.0 + i * 2.2, y0 + 0.65, side)
			root.add_child(m)
	_add_cyl(root, 0.1, 4.0, Vector3(-length * 0.49, y0 + 2.0, 0), paint)
	_flag(root, "tr", Vector3(-length * 0.49, y0 + 3.4, 0), 1.6)
	var stern := Marker3D.new()
	stern.position = Vector3(-length * 0.5, 0.0, 0)
	root.add_child(stern)
	out["stern"] = stern
	return out


static func build_mine() -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.9
	s.height = 1.8
	s.material = _mat(Color(0.08, 0.08, 0.08), 0.4, 0.7)
	m.mesh = s
	for d in [Vector3.UP, Vector3.LEFT, Vector3.RIGHT, Vector3.FORWARD, Vector3.BACK, Vector3(0.7, 0.7, 0), Vector3(-0.7, 0.7, 0)]:
		var horn := MeshInstance3D.new()
		var c := CylinderMesh.new()
		c.top_radius = 0.08
		c.bottom_radius = 0.14
		c.height = 0.5
		c.material = s.material
		horn.mesh = c
		horn.position = d.normalized() * 0.95
		if d != Vector3.UP:
			horn.basis = Basis(Quaternion(Vector3.UP, d.normalized()))
		m.add_child(horn)
	return m
