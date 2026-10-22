class_name SoldierBuilder
extends RefCounted
## 1915 piyadesi: primitiflerden basit asker figürü. İleri yön -Z, boy yaklaşık 1.8 m.
## kind: "ottoman" (kabalaklı Mehmetçik), "officer" (kalpaklı subay), "kemal", "anzac" (geniş kenarlı şapka).
## Döndürülen sözlük: root, model (eğilip düşen gövde), legs [sol, sağ], arms, muzzle.

static var _meshes := {}
static var _mats := {}


static func _mat(key: String, c: Color) -> StandardMaterial3D:
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = 0.9
		_mats[key] = m
	return _mats[key]


static func _box_mesh(size: Vector3) -> BoxMesh:
	var key := "box%s" % size
	if not _meshes.has(key):
		var b := BoxMesh.new()
		b.size = size
		_meshes[key] = b
	return _meshes[key]


static func _part(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3, scale := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.scale = scale
	parent.add_child(mi)
	return mi


static func _sphere() -> SphereMesh:
	if not _meshes.has("sphere"):
		var s := SphereMesh.new()
		s.radius = 0.5
		s.height = 1.0
		s.radial_segments = 10
		s.rings = 6
		_meshes["sphere"] = s
	return _meshes["sphere"]


static func _cyl() -> CylinderMesh:
	if not _meshes.has("cyl"):
		var c := CylinderMesh.new()
		c.top_radius = 0.5
		c.bottom_radius = 0.5
		c.height = 1.0
		c.radial_segments = 10
		_meshes["cyl"] = c
	return _meshes["cyl"]


static func build(kind: String) -> Dictionary:
	var uniform := Color(0.47, 0.45, 0.33)
	var hat := Color(0.5, 0.47, 0.34)
	match kind:
		"anzac":
			uniform = Color(0.62, 0.53, 0.37)
			hat = Color(0.55, 0.45, 0.3)
		"officer":
			uniform = Color(0.42, 0.41, 0.32)
			hat = Color(0.18, 0.15, 0.12)
		"kemal":
			uniform = Color(0.4, 0.4, 0.36)
			hat = Color(0.15, 0.13, 0.11)
	var u := _mat("u" + kind, uniform)
	var dark := _mat("boots", Color(0.18, 0.14, 0.1))
	var skin := _mat("skin", Color(0.78, 0.6, 0.47))
	var h := _mat("h" + kind, hat)
	var wood := _mat("wood", Color(0.35, 0.24, 0.14))
	var steel := _mat("steel", Color(0.3, 0.31, 0.33))

	var root := Node3D.new()
	var model := Node3D.new()
	root.add_child(model)
	var legs: Array[Node3D] = []
	for side in [-0.11, 0.11]:
		var pivot := Node3D.new()
		pivot.position = Vector3(side, 0.9, 0)
		model.add_child(pivot)
		_part(pivot, _box_mesh(Vector3(0.17, 0.7, 0.2)), u, Vector3(0, -0.35, 0))
		_part(pivot, _box_mesh(Vector3(0.18, 0.2, 0.28)), dark, Vector3(0, -0.8, -0.04))
		legs.append(pivot)
	_part(model, _box_mesh(Vector3(0.48, 0.66, 0.28)), u, Vector3(0, 1.22, 0))
	_part(model, _box_mesh(Vector3(0.5, 0.08, 0.3)), dark, Vector3(0, 0.95, 0))
	_part(model, _sphere(), skin, Vector3(0, 1.67, 0), Vector3(0.24, 0.27, 0.25))
	match kind:
		"anzac":
			_part(model, _cyl(), h, Vector3(0, 1.79, 0), Vector3(0.58, 0.025, 0.58))
			_part(model, _cyl(), h, Vector3(0, 1.85, 0), Vector3(0.26, 0.13, 0.26))
		"officer", "kemal":
			_part(model, _cyl(), h, Vector3(0, 1.83, 0), Vector3(0.27, 0.2, 0.27))
		_:
			# Kabalak: başa sarılı yuvarlak kumaş başlık
			_part(model, _sphere(), h, Vector3(0, 1.75, 0.01), Vector3(0.3, 0.2, 0.32))
	var arms := Node3D.new()
	arms.position = Vector3(0, 1.45, 0)
	model.add_child(arms)
	for side in [-0.29, 0.29]:
		var arm := _part(arms, _box_mesh(Vector3(0.13, 0.55, 0.14)), u, Vector3(side, -0.2, -0.12))
		arm.rotation.x = -0.9
	var muzzle := Marker3D.new()
	if kind == "kemal":
		# Dürbün
		_part(arms, _box_mesh(Vector3(0.22, 0.09, 0.14)), dark, Vector3(0, 0.2, -0.32))
		muzzle.position = Vector3(0, 0.2, -0.4)
	else:
		_part(arms, _box_mesh(Vector3(0.05, 0.07, 1.15)), wood, Vector3(0.1, -0.22, -0.48))
		_part(arms, _box_mesh(Vector3(0.025, 0.025, 0.4)), steel, Vector3(0.1, -0.2, -1.22))
		muzzle.position = Vector3(0.1, -0.2, -1.05)
	arms.add_child(muzzle)
	return {"root": root, "model": model, "legs": legs, "arms": arms, "muzzle": muzzle}
