class_name HumanBuilder
extends RefCounted
## Kemik iskeletli (Skeleton3D) tek parça insan gövdesi üretir. Eklemler yumuşak bükülür.
## Ölçüler metre; ayakta duruş, yüz -Z yönüne bakar, karakterin sağı +X.
##
## kind:
##   "ottoman"  Mehmetçik: kabalak, dolak, fişeklik, ekmek torbası
##   "officer"  Osmanlı subayı: subay kabalağı, Sam Browne kemer, çizme, tabanca kılıfı
##   "kemal"    Yarbay Mustafa Kemal: uzun boy, bıyık, subay kabalağı, uzun palto, çizme, dürbün
##   "anzac"    ANZAC piyadesi: geniş kenarlı şapka (sol kenar kalkık), açık haki, dolak

const BONES := [
	# ad, ebeveyn, küresel dinlenme konumu
	["hips", -1, Vector3(0, 0.98, 0)],
	["spine", 0, Vector3(0, 1.12, 0)],
	["chest", 1, Vector3(0, 1.3, 0)],
	["neck", 2, Vector3(0, 1.5, 0)],
	["head", 3, Vector3(0, 1.6, 0)],
	["r_upperarm", 2, Vector3(0.2, 1.45, 0)],
	["r_forearm", 5, Vector3(0.22, 1.17, 0)],
	["r_hand", 6, Vector3(0.23, 0.92, 0)],
	["l_upperarm", 2, Vector3(-0.2, 1.45, 0)],
	["l_forearm", 8, Vector3(-0.22, 1.17, 0)],
	["l_hand", 9, Vector3(-0.23, 0.92, 0)],
	["r_thigh", 0, Vector3(0.1, 0.93, 0)],
	["r_shin", 11, Vector3(0.1, 0.51, 0)],
	["r_foot", 12, Vector3(0.1, 0.09, 0)],
	["l_thigh", 0, Vector3(-0.1, 0.93, 0)],
	["l_shin", 14, Vector3(-0.1, 0.51, 0)],
	["l_foot", 15, Vector3(-0.1, 0.09, 0)],
]

static var _mats := {}
static var _meshes := {}
static var _skins := {}


static func bone_index(bone_name: String) -> int:
	for i in BONES.size():
		if BONES[i][0] == bone_name:
			return i
	return -1


# ------------------------------------------------------------------ malzemeler

static func _noise_normal(freq: float, strength: float, seed: int) -> NoiseTexture2D:
	var t := NoiseTexture2D.new()
	t.width = 256
	t.height = 256
	t.seamless = true
	t.as_normal_map = true
	t.bump_strength = strength
	var n := FastNoiseLite.new()
	n.seed = seed
	n.frequency = freq
	n.fractal_octaves = 3
	t.noise = n
	return t


static func material(key: String, color: Color) -> StandardMaterial3D:
	var id := "%s_%s" % [key, color.to_html()]
	if _mats.has(id):
		return _mats[id]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	match key:
		"fabric":
			m.roughness = 0.95
			m.normal_enabled = true
			m.normal_texture = _noise_normal(0.35, 6.0, 11)
			m.normal_scale = 0.6
			m.uv1_scale = Vector3(6, 6, 1)
		"skin":
			m.roughness = 0.62
			m.subsurf_scatter_enabled = true
			m.subsurf_scatter_strength = 0.12
			m.subsurf_scatter_skin_mode = true
		"leather":
			m.roughness = 0.5
			m.normal_enabled = true
			m.normal_texture = _noise_normal(0.08, 3.0, 5)
			m.normal_scale = 0.4
		"hair":
			m.roughness = 0.75
		"metal":
			m.roughness = 0.35
			m.metallic = 0.85
		"wood":
			m.roughness = 0.6
			m.normal_enabled = true
			m.normal_texture = _noise_normal(0.02, 2.0, 7)
			m.normal_scale = 0.3
		"fur":
			m.roughness = 1.0
			m.normal_enabled = true
			m.normal_texture = _noise_normal(0.6, 12.0, 3)
			m.normal_scale = 1.0
			m.uv1_scale = Vector3(4, 4, 1)
	_mats[id] = m
	return m


# ------------------------------------------------------------------ geometri

## Bir malzeme grubu için SurfaceTool kümesi.
class Builder:
	var tools := {}
	var mats := {}

	func st(key: String, mat: Material) -> SurfaceTool:
		if not tools.has(key):
			var s := SurfaceTool.new()
			s.set_skin_weight_count(SurfaceTool.SKIN_4_WEIGHTS)
			s.begin(Mesh.PRIMITIVE_TRIANGLES)
			tools[key] = s
			mats[key] = mat
		return tools[key]

	func vert(s: SurfaceTool, p: Vector3, n: Vector3, uv: Vector2, b0: int, b1: int, w1: float) -> void:
		s.set_normal(n.normalized())
		s.set_uv(uv)
		s.set_bones(PackedInt32Array([b0, b1, 0, 0]))
		s.set_weights(PackedFloat32Array([1.0 - w1, w1, 0.0, 0.0]))
		s.add_vertex(p)

	## Dikey eksende eliptik kesitli tüp. ring: [y, cx, cz, rx, rz, b0, b1, w1]
	func loft(key: String, mat: Material, rings: Array, segs := 14, cap_top := false, cap_bottom := false) -> void:
		var s := st(key, mat)
		var pts: Array = []
		for r in rings:
			var row: Array = []
			for i in segs + 1:
				var a := TAU * float(i) / segs
				var c := cos(a)
				var sn := sin(a)
				row.append([Vector3(r[1] + c * r[3], r[0], r[2] + sn * r[4]), Vector3(c / r[3], 0.0, sn / r[4])])
			pts.append(row)
		var vlen := 0.0
		for j in rings.size() - 1:
			var a: Array = rings[j]
			var b: Array = rings[j + 1]
			var v0 := vlen
			vlen += absf(b[0] - a[0]) * 3.0
			for i in segs:
				var quad := [[j, i, v0], [j + 1, i, vlen], [j + 1, i + 1, vlen], [j, i, v0], [j + 1, i + 1, vlen], [j, i + 1, v0]]
				for q in quad:
					var ring: Array = rings[q[0]]
					var pn: Array = pts[q[0]][q[1]]
					vert(s, pn[0], pn[1], Vector2(float(q[1]) / segs * 2.0, q[2]), ring[5], ring[6], ring[7])
		if cap_top:
			_cap(s, rings[rings.size() - 1], pts[pts.size() - 1], segs, Vector3.UP)
		if cap_bottom:
			_cap(s, rings[0], pts[0], segs, Vector3.DOWN)

	func _cap(s: SurfaceTool, ring: Array, row: Array, segs: int, n: Vector3) -> void:
		var c := Vector3(ring[1], ring[0], ring[2])
		for i in segs:
			var a: Vector3 = row[i][0]
			var b: Vector3 = row[i + 1][0]
			var tri := [c, a, b] if n.y < 0.0 else [c, b, a]
			for p in tri:
				vert(s, p, n, Vector2.ZERO, ring[5], ring[6], ring[7])

	## Elipsoid (baş, el, postal, torba). squash_front: ön tarafı düzleştirir.
	func ellipsoid(key: String, mat: Material, c: Vector3, r: Vector3, bone: int, segs := 12, rings := 8, b1 := -1, w1 := 0.0) -> void:
		var s := st(key, mat)
		var bb := bone if b1 < 0 else b1
		for j in rings:
			var t0 := PI * float(j) / rings
			var t1 := PI * float(j + 1) / rings
			for i in segs:
				var p0 := TAU * float(i) / segs
				var p1 := TAU * float(i + 1) / segs
				var quad := [[t0, p0], [t1, p0], [t1, p1], [t0, p0], [t1, p1], [t0, p1]]
				for q in quad:
					var u := Vector3(sin(q[0]) * cos(q[1]), cos(q[0]), sin(q[0]) * sin(q[1]))
					vert(s, c + u * r, u / r, Vector2(q[1] / TAU * 2.0, q[0] / PI), bone, bb, w1)

	## Eksenleri hizalı kutu.
	func box(key: String, mat: Material, c: Vector3, size: Vector3, bone: int, basis := Basis()) -> void:
		var s := st(key, mat)
		var h := size * 0.5
		var faces := [
			[Vector3(1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1)], [Vector3(-1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, -1)],
			[Vector3(0, 1, 0), Vector3(0, 0, 1), Vector3(1, 0, 0)], [Vector3(0, -1, 0), Vector3(0, 0, -1), Vector3(1, 0, 0)],
			[Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 1, 0)], [Vector3(0, 0, -1), Vector3(-1, 0, 0), Vector3(0, 1, 0)]]
		for f in faces:
			var n: Vector3 = f[0]
			var u: Vector3 = f[1]
			var v: Vector3 = f[2]
			var corners := []
			for k in [[-1, -1], [1, -1], [1, 1], [-1, 1]]:
				corners.append(c + basis * ((n + u * k[0] + v * k[1]) * h))
			for idx in [0, 2, 1, 0, 3, 2]:
				vert(s, corners[idx], basis * n, Vector2(idx % 2, idx / 2), bone, bone, 0.0)

	## Düz disk (şapka kenarı); lift: x<0 tarafını yukarı kaldırır (ANZAC şapkası).
	func brim(key: String, mat: Material, c: Vector3, r_in: float, r_out: float, bone: int, lift := 0.0, segs := 20) -> void:
		var s := st(key, mat)
		for i in segs:
			var a0 := TAU * float(i) / segs
			var a1 := TAU * float(i + 1) / segs
			var pts := []
			for a in [a0, a1]:
				var up := lift * clampf(-cos(a), 0.0, 1.0)
				pts.append([c + Vector3(cos(a) * r_in, 0.0, sin(a) * r_in), c + Vector3(cos(a) * r_out, up, sin(a) * r_out * 0.92)])
			for side in [1.0, -1.0]:
				var n := Vector3(0, side, 0)
				var tri := [pts[0][0], pts[1][0], pts[1][1], pts[0][0], pts[1][1], pts[0][1]]
				if side < 0.0:
					tri.reverse()
				for p in tri:
					vert(s, p + n * 0.004, n, Vector2.ZERO, bone, bone, 0.0)

	## Gövde üzerinde sürekli şerit (kayış). pts: yol noktaları, out: yüzey normali yönü.
	func ribbon(key: String, mat: Material, pts: Array, width: float, bones: Array) -> void:
		var s := st(key, mat)
		for i in pts.size() - 1:
			var a: Vector3 = pts[i]
			var b: Vector3 = pts[i + 1]
			var dir := (b - a).normalized()
			var n := Vector3(a.x, 0, a.z).normalized() if Vector2(a.x, a.z).length() > 0.01 else Vector3.FORWARD
			var side := dir.cross(n).normalized() * width * 0.5
			var ba: int = bones[i]
			var bb: int = bones[i + 1]
			var quad := [[a - side, ba], [b - side, bb], [b + side, bb], [a - side, ba], [b + side, bb], [a + side, ba]]
			for q in quad:
				vert(s, q[0] + n * 0.006, n, Vector2.ZERO, q[1], q[1], 0.0)

	func commit() -> ArrayMesh:
		var mesh := ArrayMesh.new()
		for key in tools:
			var s: SurfaceTool = tools[key]
			s.commit(mesh)
			mesh.surface_set_material(mesh.get_surface_count() - 1, mats[key])
		return mesh


# ------------------------------------------------------------------ gövde

static func _spec(kind: String) -> Dictionary:
	match kind:
		"anzac":
			return {"uniform": Color(0.6, 0.5, 0.35), "trousers": Color(0.56, 0.47, 0.33), "puttee": Color(0.5, 0.42, 0.3), "hat": Color(0.52, 0.42, 0.28),
				"skin": Color(0.84, 0.63, 0.5), "leather": Color(0.42, 0.3, 0.18), "hat_kind": "slouch", "mustache": false, "height": 1.0, "boots": false, "coat": false}
		"officer":
			return {"uniform": Color(0.4, 0.4, 0.3), "trousers": Color(0.38, 0.37, 0.29), "puttee": Color(0.2, 0.14, 0.1), "hat": Color(0.42, 0.41, 0.31),
				"skin": Color(0.78, 0.58, 0.44), "leather": Color(0.28, 0.17, 0.1), "hat_kind": "kabalak", "mustache": true, "height": 1.02, "boots": true, "coat": false}
		"kemal":
			return {"uniform": Color(0.43, 0.43, 0.37), "trousers": Color(0.36, 0.36, 0.31), "puttee": Color(0.12, 0.09, 0.07), "hat": Color(0.45, 0.44, 0.36),
				"skin": Color(0.86, 0.68, 0.56), "leather": Color(0.2, 0.13, 0.08), "hat_kind": "kabalak", "mustache": true, "height": 1.06, "boots": true, "coat": true}
		_:
			return {"uniform": Color(0.47, 0.45, 0.32), "trousers": Color(0.45, 0.43, 0.31), "puttee": Color(0.4, 0.38, 0.28), "hat": Color(0.58, 0.54, 0.4),
				"skin": Color(0.72, 0.55, 0.42), "leather": Color(0.4, 0.29, 0.17), "hat_kind": "kabalak", "mustache": true, "height": 1.0, "boots": false, "coat": false}


static func _body_mesh(kind: String) -> ArrayMesh:
	if _meshes.has(kind):
		return _meshes[kind]
	var sp := _spec(kind)
	var b := Builder.new()
	var cloth := material("fabric", sp["uniform"])
	var trou := material("fabric", sp["trousers"])
	var put := material("fabric", sp["puttee"])
	var skin := material("skin", sp["skin"])
	var lea := material("leather", sp["leather"])
	var hair := material("hair", Color(0.08, 0.06, 0.05))
	var metal := material("metal", Color(0.55, 0.5, 0.35))
	var hatm := material("fabric", sp["hat"])
	var H := bone_index("hips")
	var SP := bone_index("spine")
	var CH := bone_index("chest")
	var NK := bone_index("neck")
	var HD := bone_index("head")

	# Ceket: kalçadan omuza; subay paltosu dize kadar iner.
	var hem := 0.52 if sp["coat"] else 0.8
	b.loft("cloth", cloth, [
		[hem, 0, 0.01, 0.2 if sp["coat"] else 0.19, 0.155, H, H, 0.0],
		[0.9, 0, 0.0, 0.18, 0.13, H, H, 0.0],
		[1.0, 0, 0.0, 0.16, 0.115, H, SP, 0.3],
		[1.12, 0, 0.0, 0.165, 0.115, SP, SP, 0.0],
		[1.27, 0, -0.005, 0.185, 0.13, SP, CH, 0.7],
		[1.4, 0, 0.0, 0.2, 0.125, CH, CH, 0.0],
		[1.47, 0, 0.005, 0.16, 0.1, CH, CH, 0.0],
		[1.51, 0, 0.01, 0.075, 0.07, CH, NK, 0.5],
	], 16)
	# Yaka ve düğmeler
	b.loft("cloth", cloth, [[1.49, 0, 0.005, 0.08, 0.075, NK, NK, 0.0], [1.55, 0, 0.005, 0.072, 0.068, NK, NK, 0.0]], 12)
	for i in 5:
		b.ellipsoid("metal", metal, Vector3(0, 1.43 - i * 0.09, -0.128 + i * 0.003), Vector3(0.009, 0.009, 0.006), CH if i < 2 else SP, 6, 4)
	# Kemer, fişeklikler, kayış
	b.loft("leather", lea, [[0.96, 0, 0.0, 0.172, 0.123, H, H, 0.0], [1.02, 0, 0.0, 0.17, 0.122, H, H, 0.0]], 16)
	b.box("metal", metal, Vector3(0, 0.99, -0.125), Vector3(0.06, 0.05, 0.012), H)
	if kind == "officer" or kind == "kemal":
		# Sam Browne omuz kayışı (sol omuzdan sağ kalçaya) ve tabanca kılıfı
		b.ribbon("leather", lea, [Vector3(-0.12, 1.46, 0.06), Vector3(-0.13, 1.44, -0.12), Vector3(-0.04, 1.3, -0.14), Vector3(0.06, 1.14, -0.125), Vector3(0.13, 1.0, -0.12)], 0.035, [CH, CH, CH, SP, H])
		b.ribbon("leather", lea, [Vector3(-0.12, 1.46, 0.06), Vector3(-0.08, 1.3, 0.13), Vector3(0.05, 1.14, 0.125), Vector3(0.13, 1.0, 0.12)], 0.035, [CH, CH, SP, H])
		b.box("leather", lea, Vector3(0.19, 0.9, -0.02), Vector3(0.05, 0.14, 0.09), H)
	else:
		for side in [-1.0, 1.0]:
			for k in 2:
				b.box("leather", lea, Vector3(side * (0.06 + k * 0.065), 0.98, -0.13), Vector3(0.055, 0.07, 0.05), H)
		# Ekmek torbası (sol kalça) ve göğüste çapraz kayış
		b.box("cloth", hatm, Vector3(-0.17, 0.86, 0.06), Vector3(0.06, 0.16, 0.18), H)
		b.ribbon("leather", lea, [Vector3(0.13, 1.46, 0.05), Vector3(0.14, 1.44, -0.12), Vector3(0.04, 1.3, -0.14), Vector3(-0.07, 1.13, -0.125), Vector3(-0.15, 0.96, -0.11)], 0.04, [CH, CH, CH, SP, H])
	if kind == "kemal":
		b.box("leather", lea, Vector3(0.05, 1.33, -0.14), Vector3(0.13, 0.07, 0.06), CH)  # dürbün göğüste
		for x in [-0.03, 0.03]:
			b.loft("metal", hair, [[1.3, x + 0.05, -0.16, 0.022, 0.022, CH, CH, 0.0], [1.37, x + 0.05, -0.16, 0.022, 0.022, CH, CH, 0.0]], 8)

	# Boyun ve baş
	b.loft("skin", skin, [[1.5, 0, 0.01, 0.055, 0.055, NK, NK, 0.0], [1.62, 0, 0.012, 0.05, 0.052, NK, HD, 1.0]], 12)
	b.ellipsoid("skin", skin, Vector3(0, 1.705, 0.005), Vector3(0.082, 0.112, 0.098), HD, 16, 12)
	b.ellipsoid("skin", skin, Vector3(0, 1.63, -0.04), Vector3(0.065, 0.045, 0.07), HD, 12, 8)  # çene
	b.ellipsoid("skin", skin, Vector3(0, 1.692, -0.096), Vector3(0.011, 0.024, 0.016), HD, 8, 6)  # burun
	for side in [-1.0, 1.0]:
		b.ellipsoid("skin", skin, Vector3(side * 0.086, 1.69, 0.005), Vector3(0.01, 0.024, 0.016), HD, 8, 6)  # kulak
		b.ellipsoid("hair", hair, Vector3(side * 0.033, 1.712, -0.088), Vector3(0.009, 0.0055, 0.005), HD, 6, 4)  # göz
		b.box("hair", hair, Vector3(side * 0.035, 1.733, -0.088), Vector3(0.03, 0.006, 0.008), HD, Basis(Vector3.BACK, side * -0.1))  # kaş
	b.ellipsoid("hair", hair, Vector3(0, 1.73, 0.03), Vector3(0.085, 0.07, 0.085), HD, 12, 8)  # şapka altından görünen saç
	if sp["mustache"]:
		for side in [-1.0, 1.0]:
			b.ellipsoid("hair", hair, Vector3(side * 0.019, 1.663, -0.094), Vector3(0.02, 0.0055, 0.008), HD, 8, 4)

	# Şapkalar
	match sp["hat_kind"]:
		"slouch":
			b.brim("hat", hatm, Vector3(0, 1.79, 0), 0.08, 0.26, HD, 0.08)
			b.loft("hat", hatm, [[1.78, 0, 0, 0.1, 0.11, HD, HD, 0.0], [1.86, 0, 0, 0.092, 0.1, HD, HD, 0.0], [1.9, 0, 0, 0.06, 0.08, HD, HD, 0.0]], 14, true)
			b.loft("leather", lea, [[1.79, 0, 0, 0.102, 0.112, HD, HD, 0.0], [1.81, 0, 0, 0.102, 0.112, HD, HD, 0.0]], 14)
		_:
			# Kabalak (Enveriye): başa sarılmış kumaş; üst üste sarım katları
			b.ellipsoid("hat", hatm, Vector3(0, 1.79, 0.005), Vector3(0.105, 0.085, 0.12), HD, 16, 10)
			for k in 3:
				var y := 1.755 + k * 0.03
				b.loft("hat", hatm, [[y, 0, 0.005, 0.113 - k * 0.012, 0.128 - k * 0.012, HD, HD, 0.0], [y + 0.022, 0, 0.005, 0.11 - k * 0.012, 0.125 - k * 0.012, HD, HD, 0.0]], 16)
			# Arkaya inen ense örtüsü
			b.box("hat", hatm, Vector3(0, 1.72, 0.09), Vector3(0.15, 0.08, 0.02), HD, Basis(Vector3.RIGHT, -0.25))

	# Kollar
	for side in [1.0, -1.0]:
		var pre := "r_" if side > 0.0 else "l_"
		var UA := bone_index(pre + "upperarm")
		var FA := bone_index(pre + "forearm")
		var HA := bone_index(pre + "hand")
		var x: float = side
		b.loft("cloth", cloth, [
			[0.95, x * 0.23, 0.0, 0.05, 0.05, FA, HA, 0.1],
			[1.12, x * 0.222, 0.0, 0.052, 0.05, FA, FA, 0.0],
			[1.17, x * 0.22, 0.0, 0.054, 0.052, UA, FA, 0.5],
			[1.3, x * 0.21, 0.0, 0.06, 0.058, UA, UA, 0.0],
			[1.42, x * 0.2, 0.0, 0.066, 0.066, UA, UA, 0.0],
			[1.47, x * 0.18, 0.0, 0.05, 0.06, UA, CH, 0.5],
		], 12)
		b.ellipsoid("skin", skin, Vector3(x * 0.232, 0.875, -0.005), Vector3(0.03, 0.05, 0.026), HA, 10, 6)  # el
		# Bacaklar
		var TH := bone_index(pre + "thigh")
		var SH := bone_index(pre + "shin")
		var FT := bone_index(pre + "foot")
		var lx: float = side * 0.1
		b.loft("trousers", trou, [
			[0.42, lx, 0.0, 0.058, 0.058, SH, SH, 0.0],
			[0.51, lx, 0.0, 0.065, 0.07, TH, SH, 0.5],
			[0.72, lx, 0.0, 0.08, 0.085, TH, TH, 0.0],
			[0.95, lx, 0.0, 0.1, 0.1, TH, H, 0.3],
		], 12)
		if sp["boots"]:
			b.loft("leather", lea, [[0.06, lx, 0.0, 0.05, 0.06, FT, FT, 0.0], [0.12, lx, 0.0, 0.052, 0.058, SH, SH, 0.0], [0.46, lx, 0.0, 0.06, 0.062, SH, SH, 0.0]], 12)
		else:
			# Dolak (sargı) ve postal
			var rings := []
			for k in 6:
				var y := 0.1 + k * 0.065
				rings.append([y, lx, 0.0, 0.047 + k * 0.003, 0.05 + k * 0.003, SH, SH, 0.0])
			b.loft("puttee", put, rings, 12)
		b.ellipsoid("leather", lea, Vector3(lx, 0.05, -0.04), Vector3(0.05, 0.05, 0.12), FT, 10, 6)  # ayakkabı

	var mesh := b.commit()
	_meshes[kind] = mesh
	return mesh


static func _rifle() -> ArrayMesh:
	if _meshes.has("rifle"):
		return _meshes["rifle"]
	var b := Builder.new()
	var wood := material("wood", Color(0.38, 0.24, 0.13))
	var steel := material("metal", Color(0.2, 0.21, 0.23))
	# Uzunluk ekseni -Z (namlu ileri). Kök: kundak dipçiği z=+0.45
	b.box("wood", wood, Vector3(0, -0.03, 0.36), Vector3(0.045, 0.12, 0.2), 0)  # dipçik
	b.box("wood", wood, Vector3(0, 0.0, 0.17), Vector3(0.04, 0.06, 0.22), 0, Basis(Vector3.RIGHT, 0.12))  # kabza
	b.box("wood", wood, Vector3(0, 0.01, -0.25), Vector3(0.045, 0.05, 0.64), 0)  # el kundağı
	b.box("metal", steel, Vector3(0, 0.045, -0.4), Vector3(0.018, 0.018, 0.92), 0)  # namlu
	b.box("metal", steel, Vector3(0, 0.04, 0.04), Vector3(0.035, 0.04, 0.16), 0)  # mekanizma
	b.box("metal", steel, Vector3(0.035, 0.05, 0.08), Vector3(0.05, 0.012, 0.012), 0)  # kurma kolu
	b.box("metal", steel, Vector3(0, 0.045, -0.98), Vector3(0.012, 0.022, 0.36), 0)  # süngü
	var mesh := b.commit()
	_meshes["rifle"] = mesh
	return mesh


static func _binoculars() -> ArrayMesh:
	if _meshes.has("binoculars"):
		return _meshes["binoculars"]
	var b := Builder.new()
	var m := material("hair", Color(0.08, 0.06, 0.05))
	for x in [-0.03, 0.03]:
		b.loft("m", m, [[0.0, x, 0.0, 0.022, 0.022, 0, 0, 0.0], [0.1, x, 0.0, 0.02, 0.02, 0, 0, 0.0]], 10, true, true)
	var mesh := b.commit()
	_meshes["binoculars"] = mesh
	return mesh


static func _skin_for(skel_rest: Array) -> Skin:
	if _skins.has("default"):
		return _skins["default"]
	var skin := Skin.new()
	skin.set_bind_count(BONES.size())
	for i in BONES.size():
		skin.set_bind_bone(i, i)
		skin.set_bind_pose(i, Transform3D(Basis(), -(BONES[i][2] as Vector3)))
	_skins["default"] = skin
	return skin


## Yeni bir insan üretir: HumanRig döner (kök düğüm, iskelet, namlu ucu, poz fonksiyonları).
static func build(kind: String) -> HumanRig:
	var rig := HumanRig.new()
	var sp := _spec(kind)
	rig.kind = kind
	rig.root = Node3D.new()
	rig.model = Node3D.new()
	rig.model.scale = Vector3.ONE * float(sp["height"])
	rig.root.add_child(rig.model)
	var skel := Skeleton3D.new()
	skel.name = "Skeleton"
	for i in BONES.size():
		skel.add_bone(BONES[i][0])
	for i in BONES.size():
		var parent: int = BONES[i][1]
		skel.set_bone_parent(i, parent)
		var g: Vector3 = BONES[i][2]
		var pg: Vector3 = BONES[parent][2] if parent >= 0 else Vector3.ZERO
		skel.set_bone_rest(i, Transform3D(Basis(), g - pg))
	skel.reset_bone_poses()
	rig.model.add_child(skel)
	var mi := MeshInstance3D.new()
	mi.mesh = _body_mesh(kind)
	mi.skin = _skin_for([])
	skel.add_child(mi)
	mi.skeleton = NodePath("..")
	rig.skeleton = skel
	if kind == "kemal":
		var att := BoneAttachment3D.new()
		att.bone_name = "head"
		skel.add_child(att)
		var bino := MeshInstance3D.new()
		bino.mesh = _binoculars()
		bino.position = Vector3(0, 0.11, -0.13)
		bino.rotation = Vector3(-PI / 2.0, 0, 0)
		att.add_child(bino)
		rig.binoculars = bino
		rig.muzzle = Marker3D.new()
		att.add_child(rig.muzzle)
	else:
		# Tüfek her karede iki elin arasına yerleştirilir (HumanRig._place_rifle).
		var rifle := MeshInstance3D.new()
		rifle.mesh = _rifle()
		skel.add_child(rifle)
		rig.rifle = rifle
		rig.muzzle = Marker3D.new()
		rifle.add_child(rig.muzzle)
		rig.muzzle.position = Vector3(0, 0.045, -0.88)
	rig.apply_pose(0.0, 0.0, 0.0)
	return rig
