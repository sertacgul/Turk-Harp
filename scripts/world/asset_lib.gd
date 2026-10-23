class_name AssetLib
extends RefCounted
## İsteğe bağlı fotogerçekçi (CC0) varlıklar: tools/fetch_assets.py ile indirilen HDRI gökyüzleri,
## PBR arazi dokuları ve glTF kaya/çalı modelleri. Dosya yoksa her çağrı null/false döner ve
## oyun prosedürel grafiklere geri döner.

const HDRI_DIR := "res://assets/hdri/"
const TEX_DIR := "res://assets/textures/"
const MODEL_DIR := "res://assets/models/"
const TERRAIN_LAYERS := ["grass", "dirt", "rock", "sand"]

static var _mesh_cache := {}


static func _load(path: String) -> Resource:
	return load(path) if ResourceLoader.exists(path) else null


## mode ("day", "dawn", "night") için HDRI panoraması.
static func hdri(mode: String) -> Texture2D:
	for ext in ["hdr", "exr"]:
		var t := _load(HDRI_DIR + mode + "." + ext) as Texture2D
		if t:
			return t
	return null


## Dört katmanın da albedo dokusu varsa arazi malzemesine PBR dokularını bağlar.
static func apply_terrain_textures(mat: ShaderMaterial) -> bool:
	for layer in TERRAIN_LAYERS:
		if not ResourceLoader.exists(TEX_DIR + layer + "_albedo.jpg"):
			return false
	for layer in TERRAIN_LAYERS:
		mat.set_shader_parameter(layer + "_albedo", _load(TEX_DIR + layer + "_albedo.jpg"))
		var n := _load(TEX_DIR + layer + "_normal.jpg")
		if n:
			mat.set_shader_parameter(layer + "_normal", n)
	mat.set_shader_parameter("textured", true)
	return true


## prefix_0.gltf, prefix_1.gltf ... dosyalarındaki ilk ağlar (malzemeleri gömülü).
static func meshes(prefix: String) -> Array[Mesh]:
	if _mesh_cache.has(prefix):
		return _mesh_cache[prefix]
	var out: Array[Mesh] = []
	for i in 8:
		var scene := _load(MODEL_DIR + "%s_%d.gltf" % [prefix, i]) as PackedScene
		if scene == null:
			scene = _load(MODEL_DIR + "%s_%d.glb" % [prefix, i]) as PackedScene
		if scene == null:
			break
		var node := scene.instantiate()
		var mi := _first_mesh(node)
		if mi and mi.mesh:
			var mesh := mi.mesh.duplicate() as Mesh
			# Model ölçeği/yönelimi ağa işlenir (Poly Haven modelleri metre ölçeklidir).
			for s in mesh.get_surface_count():
				var m := mi.get_active_material(s)
				if m:
					mesh.surface_set_material(s, m)
			out.append(mesh)
		node.free()
	_mesh_cache[prefix] = out
	return out


static func _first_mesh(n: Node) -> MeshInstance3D:
	if n is MeshInstance3D:
		return n
	for c in n.get_children():
		var r := _first_mesh(c)
		if r:
			return r
	return null


## Modelleri MultiMesh ile saçar. Model yoksa false döner (çağıran prosedürel yedeğe geçer).
static func scatter_models(parent: Node3D, prefix: String, count: int, area: Vector4, height_fn: Callable,
		accept: Callable, scale_range := Vector2(0.6, 1.6), seed := 1, fade_end := 400.0, sink := 0.15) -> bool:
	var list := meshes(prefix)
	if list.is_empty():
		return false
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var per: Array = []
	for i in list.size():
		per.append([] as Array[Transform3D])
	var placed := 0
	var tries := 0
	while placed < count and tries < count * 8:
		tries += 1
		var x := rng.randf_range(area.x, area.z)
		var z := rng.randf_range(area.y, area.w)
		if not accept.call(x, z):
			continue
		var s := rng.randf_range(scale_range.x, scale_range.y)
		var tilt := Basis(Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)).normalized(), rng.randf_range(0.0, 0.25))
		var basis := (tilt * Basis(Vector3.UP, rng.randf() * TAU)).scaled(Vector3(s, s * rng.randf_range(0.7, 1.2), s))
		var y := float(height_fn.call(x, z)) - sink * s
		(per[rng.randi() % list.size()] as Array[Transform3D]).append(Transform3D(basis, Vector3(x, y, z)))
		placed += 1
	for i in list.size():
		var xf: Array[Transform3D] = per[i]
		if xf.is_empty():
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = list[i]
		mm.instance_count = xf.size()
		for j in xf.size():
			mm.set_instance_transform(j, xf[j])
		var inst := MultiMeshInstance3D.new()
		inst.multimesh = mm
		inst.visibility_range_end = fade_end
		inst.visibility_range_end_margin = 40.0
		inst.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		parent.add_child(inst)
	return true
