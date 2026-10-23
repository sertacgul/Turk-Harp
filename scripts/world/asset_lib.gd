class_name AssetLib
extends RefCounted
## İsteğe bağlı fotogerçekçi (CC0) varlıklar: tools/fetch_assets.py ile indirilen HDRI gökyüzleri,
## PBR arazi dokuları ve glTF kaya/çalı modelleri. Dosya yoksa her çağrı null/false döner ve
## oyun prosedürel grafiklere geri döner.

const HDRI_DIR := "res://assets/hdri/"
const TEX_DIR := "res://assets/textures/"
const MODEL_DIR := "res://assets/models/"
const TERRAIN_LAYERS := ["grass", "dirt", "rock", "sand"]

const CELL := 120.0
const SCATTER_GROUP := "asset_scatter"

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


## prefix_0.gltf, prefix_1.gltf ... dosyalarındaki ağlar. Bir dosyada birden çok parça varsa
## (ör. kaya seti) her parça ayrı bir çeşit olur; parçalar ortalanır ve tabanı y=0'a oturtulur.
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
		var parts: Array[MeshInstance3D] = []
		_collect_meshes(node, parts)
		for mi in parts:
			var mesh := _bake(mi, _global_basis(mi), 3000 if prefix == "bush" else 1600)
			if mesh:
				out.append(mesh)
		node.free()
	_mesh_cache[prefix] = out
	return out


static func _collect_meshes(n: Node, out: Array[MeshInstance3D]) -> void:
	if n is MeshInstance3D and (n as MeshInstance3D).mesh and not String(n.name).to_lower().contains("proxy"):
		out.append(n)
	for c in n.get_children():
		_collect_meshes(c, out)


## Ağaçta değil (sahneye eklenmemiş) düğümün dönüş/ölçeği; öteleme parçayı ortalarken atılır.
static func _global_basis(n: Node) -> Basis:
	var b := Basis.IDENTITY
	var cur := n
	while cur is Node3D:
		b = (cur as Node3D).transform.basis * b
		cur = cur.get_parent()
	return b


static func _bake(mi: MeshInstance3D, basis: Basis, max_tris: int) -> Mesh:
	var src := mi.mesh
	var aabb: AABB = Transform3D(basis, Vector3.ZERO) * src.get_aabb()
	var center: Vector3 = aabb.get_center()
	var shift := Transform3D(basis, Vector3(-center.x, -aabb.position.y, -center.z))
	var nb := basis.inverse().transposed()
	var out := ArrayMesh.new()
	for s in src.get_surface_count():
		var arrays := src.surface_get_arrays(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		for i in verts.size():
			verts[i] = shift * verts[i]
		arrays[Mesh.ARRAY_VERTEX] = verts
		if arrays[Mesh.ARRAY_NORMAL] is PackedVector3Array:
			var norms: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			for i in norms.size():
				norms[i] = (nb * norms[i]).normalized()
			arrays[Mesh.ARRAY_NORMAL] = norms
		if arrays[Mesh.ARRAY_TANGENT] is PackedFloat32Array:
			var tans: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT]
			for i in range(0, tans.size(), 4):
				var t := (basis * Vector3(tans[i], tans[i + 1], tans[i + 2])).normalized()
				tans[i] = t.x
				tans[i + 1] = t.y
				tans[i + 2] = t.z
			arrays[Mesh.ARRAY_TANGENT] = tans
		if arrays[Mesh.ARRAY_INDEX] is PackedInt32Array:
			arrays[Mesh.ARRAY_INDEX] = _lod_indices(src, s, arrays[Mesh.ARRAY_INDEX], max_tris)
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var m := mi.get_active_material(s)
		if m:
			out.surface_set_material(out.get_surface_count() - 1, m)
	return out if out.get_surface_count() > 0 else null


## Taranmış modeller 50-150 bin üçgenlidir; binlerce kopya için içe aktarıcının ürettiği
## LOD'lardan max_tris'e en yakın (onu aşmayan en ayrıntılı) olanı seçilir.
static func _lod_indices(src: Mesh, surface: int, base: PackedInt32Array, max_tris: int) -> PackedInt32Array:
	if base.size() / 3 <= max_tris:
		return base
	var d: Dictionary = RenderingServer.mesh_get_surface(src.get_rid(), surface)
	var base_bytes: int = (d.get("index_data", PackedByteArray()) as PackedByteArray).size()
	if base_bytes == 0:
		return base
	var stride := base_bytes / base.size()
	var best := PackedByteArray()
	for l in d.get("lods", []):
		var data: PackedByteArray = l["index_data"]
		if data.size() / stride / 3 <= max_tris:
			best = data
			break
	if best.is_empty():
		var lods: Array = d.get("lods", [])
		if lods.is_empty():
			return base
		best = lods[-1]["index_data"]
	var count := best.size() / stride
	var out := PackedInt32Array()
	out.resize(count)
	for i in count:
		out[i] = best.decode_u16(i * 2) if stride == 2 else best.decode_u32(i * 4)
	return out


## Modelleri MultiMesh ile saçar. Model yoksa false döner (çağıran prosedürel yedeğe geçer).
static func scatter_models(parent: Node3D, prefix: String, count: int, area: Vector4, height_fn: Callable,
		accept: Callable, scale_range := Vector2(0.6, 1.6), seed := 1, fade_end := 400.0, sink := 0.15) -> bool:
	var list := meshes(prefix)
	if list.is_empty():
		return false
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	# Kopyalar (çeşit, hücre) gruplarına ayrılır: her grup ayrı çizilir, böylece kamera dışındaki
	# ve uzaktaki hücreler hiç çizilmez (tek dev MultiMesh her zaman tamamen çizilirdi).
	var groups := {}
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
		var key := Vector3i(rng.randi() % list.size(), floori(x / CELL), floori(z / CELL))
		if not groups.has(key):
			groups[key] = [] as Array[Transform3D]
		(groups[key] as Array[Transform3D]).append(Transform3D(basis, Vector3(x, y, z)))
		placed += 1
	for key: Vector3i in groups:
		var xf: Array[Transform3D] = groups[key]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = list[key.x]
		mm.instance_count = xf.size()
		for j in xf.size():
			mm.set_instance_transform(j, xf[j])
		var inst := MultiMeshInstance3D.new()
		inst.multimesh = mm
		inst.visibility_range_end = fade_end
		inst.visibility_range_end_margin = 40.0
		inst.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		inst.add_to_group(SCATTER_GROUP)
		parent.add_child(inst)
	return true


## Tabya, bayrak direği gibi oyun yapılarının çevresindeki saçılmış modelleri kaldırır (sıfır ölçek).
static func clear_around(node: Node, center: Vector3, radius: float) -> void:
	if not node.is_inside_tree():
		return
	for inst: MultiMeshInstance3D in node.get_tree().get_nodes_in_group(SCATTER_GROUP):
		var mm := inst.multimesh
		for i in mm.instance_count:
			var t := mm.get_instance_transform(i)
			var d := Vector2(t.origin.x - center.x, t.origin.z - center.z).length()
			if d < radius + t.basis.get_scale().x * 1.5:
				mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ZERO), t.origin))
