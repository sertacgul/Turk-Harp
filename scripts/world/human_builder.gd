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

	## Yol boyunca yuvarlak kesitli tüp (rulo battaniye, kayış). Her nokta kendi kemiğine bağlanır.
	func tube(key: String, mat: Material, pts: Array, radius: float, bones: Array, segs := 10) -> void:
		var s := st(key, mat)
		var rings: Array = []
		for i in pts.size():
			var p: Vector3 = pts[i]
			var dir: Vector3 = ((pts[mini(i + 1, pts.size() - 1)] as Vector3) - (pts[maxi(i - 1, 0)] as Vector3)).normalized()
			var side := dir.cross(Vector3.FORWARD if absf(dir.z) < 0.9 else Vector3.UP).normalized()
			var up := side.cross(dir).normalized()
			var row: Array = []
			for k in segs + 1:
				var a := TAU * float(k) / segs
				var n := side * cos(a) + up * sin(a)
				row.append([p + n * radius, n])
			rings.append(row)
		for i in pts.size() - 1:
			for k in segs:
				for q in [[i, k], [i + 1, k], [i + 1, k + 1], [i, k], [i + 1, k + 1], [i, k + 1]]:
					var pn: Array = rings[q[0]][q[1]]
					vert(s, pn[0], pn[1], Vector2(float(q[1]) / segs, float(q[0])), bones[q[0]], bones[q[0]], 0.0)

	func commit() -> ArrayMesh:
		var mesh := ArrayMesh.new()
		for key in tools:
			var s: SurfaceTool = tools[key]
			s.commit(mesh)
			mesh.surface_set_material(mesh.get_surface_count() - 1, mats[key])
		return mesh


# ------------------------------------------------------------------ gövde

const VARIANTS := 10


## Türün temel kıyafeti. Varyantlar bunun üzerine ten, yapı, yüz ve teçhizat farkları ekler.
static func _spec(kind: String) -> Dictionary:
	match kind:
		"anzac":
			return {"uniform": Color(0.6, 0.5, 0.35), "trousers": Color(0.56, 0.47, 0.33), "puttee": Color(0.5, 0.42, 0.3), "hat": Color(0.52, 0.42, 0.28),
				"leather": Color(0.42, 0.3, 0.18), "hat_kind": "slouch", "height": 1.0, "boots": false, "coat": false, "west": true}
		"british":
			return {"uniform": Color(0.58, 0.5, 0.36), "trousers": Color(0.55, 0.47, 0.34), "puttee": Color(0.48, 0.41, 0.3), "hat": Color(0.82, 0.78, 0.66),
				"leather": Color(0.36, 0.26, 0.16), "hat_kind": "helmet", "height": 1.0, "boots": false, "coat": false, "west": true}
		"officer":
			return {"uniform": Color(0.4, 0.4, 0.3), "trousers": Color(0.38, 0.37, 0.29), "puttee": Color(0.2, 0.14, 0.1), "hat": Color(0.42, 0.41, 0.31),
				"leather": Color(0.28, 0.17, 0.1), "hat_kind": "kabalak", "height": 1.02, "boots": true, "coat": false, "west": false}
		"kemal":
			return {"uniform": Color(0.43, 0.43, 0.37), "trousers": Color(0.36, 0.36, 0.31), "puttee": Color(0.12, 0.09, 0.07), "hat": Color(0.45, 0.44, 0.36),
				"leather": Color(0.2, 0.13, 0.08), "hat_kind": "kabalak", "height": 1.06, "boots": true, "coat": true, "west": false}
		_:
			return {"uniform": Color(0.47, 0.45, 0.32), "trousers": Color(0.45, 0.43, 0.31), "puttee": Color(0.4, 0.38, 0.28), "hat": Color(0.58, 0.54, 0.4),
				"leather": Color(0.4, 0.29, 0.17), "hat_kind": "kabalak", "height": 1.0, "boots": false, "coat": false, "west": false}


static func _tint(c: Color, rng: RandomNumberGenerator, amount: float) -> Color:
	var k := rng.randf_range(1.0 - amount, 1.0 + amount)
	return Color(clampf(c.r * k * rng.randf_range(0.96, 1.04), 0, 1), clampf(c.g * k * rng.randf_range(0.96, 1.04), 0, 1), clampf(c.b * k * rng.randf_range(0.94, 1.06), 0, 1))


## Türün n. varyantı: yapı, ten, saç, yüz, sakal/bıyık, solmuş kıyafet ve teçhizat.
static func _variant(kind: String, v: int) -> Dictionary:
	var sp := _spec(kind)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(kind) + v * 7919
	var west: bool = sp["west"]
	var fixed := kind == "kemal" or kind == "officer"
	sp["height"] = float(sp["height"]) if fixed else rng.randf_range(0.93, 1.07)
	sp["shoulders"] = 1.0 if fixed else rng.randf_range(0.92, 1.1)
	sp["waist"] = 0.96 if kind == "kemal" else rng.randf_range(0.9, 1.15)
	if west:
		sp["skin"] = Color(0.93, 0.74, 0.62).lerp(Color(0.78, 0.53, 0.38), rng.randf())
		sp["hair"] = [Color(0.25, 0.16, 0.09), Color(0.55, 0.42, 0.24), Color(0.12, 0.08, 0.05), Color(0.45, 0.2, 0.1)][rng.randi() % 4]
	else:
		sp["skin"] = Color(0.84, 0.66, 0.52).lerp(Color(0.54, 0.37, 0.26), rng.randf() * (0.3 if kind == "kemal" else 1.0))
		sp["hair"] = Color(0.06, 0.05, 0.04).lerp(Color(0.2, 0.13, 0.08), rng.randf())
	if kind == "kemal":
		sp["skin"] = Color(0.88, 0.71, 0.6)
		sp["hair"] = Color(0.42, 0.33, 0.22)
	# Yüz biçimi
	sp["head_w"] = rng.randf_range(0.93, 1.07)
	sp["head_l"] = rng.randf_range(0.95, 1.06)
	sp["jaw"] = rng.randf_range(0.88, 1.15)
	sp["nose"] = rng.randf_range(0.85, 1.3)
	sp["brow"] = rng.randf_range(0.7, 1.4)
	if kind == "kemal":
		sp["head_w"] = 0.96
		sp["head_l"] = 1.04
		sp["jaw"] = 0.95
		sp["nose"] = 1.05
		sp["brow"] = 1.1
	# Sakal ve bıyık: none, thin, thick, handlebar; sakal ve kirli sakal
	var r := rng.randf()
	if kind == "kemal" or kind == "officer":
		sp["mustache"] = "thin"
		sp["beard"] = false
		sp["stubble"] = false
	elif west:
		sp["mustache"] = "none" if r < 0.6 else ("thin" if r < 0.85 else "thick")
		sp["beard"] = false
		sp["stubble"] = rng.randf() < 0.35
	else:
		sp["mustache"] = "thick" if r < 0.45 else ("thin" if r < 0.75 else ("handlebar" if r < 0.9 else "none"))
		sp["beard"] = rng.randf() < 0.25
		sp["stubble"] = rng.randf() < 0.45
	# Solmuş, yıpranmış kıyafetler
	for key in ["uniform", "trousers", "puttee", "hat"]:
		sp[key] = _tint(sp[key], rng, 0.0 if fixed else 0.1)
	sp["blanket"] = not west and not fixed and rng.randf() < 0.55
	sp["canteen"] = not fixed and rng.randf() < 0.75
	sp["bandolier"] = not west and not fixed and rng.randf() < 0.4
	sp["pack"] = west and rng.randf() < 0.55
	sp["shirt"] = kind == "anzac" and rng.randf() < 0.3
	sp["rolled"] = (kind == "anzac" and rng.randf() < 0.55) or (kind == "british" and rng.randf() < 0.3) or sp["shirt"]
	if sp["shirt"]:
		sp["uniform"] = [Color(0.66, 0.6, 0.48), Color(0.55, 0.58, 0.62), Color(0.62, 0.55, 0.42)][rng.randi() % 3]
	if west and rng.randf() < 0.3:
		sp["hat_kind"] = "cap"
	return sp


## Ten üzerine göz çukuru, kaş kemiği, elmacık, burun, dudak ve çene ile biçimlendirilmiş baş.
static func _head(b: Builder, sp: Dictionary, skin: Material, stubble_mat: Material, HD: int) -> void:
	var c := Vector3(0, 1.705, 0.005)
	var rad := Vector3(0.081 * float(sp["head_w"]), 0.11 * float(sp["head_l"]), 0.097)
	var jaw: float = sp["jaw"]
	var nose: float = sp["nose"]
	var brow: float = sp["brow"]
	var segs := 28
	var rings := 22
	var grid: Array = []
	for j in rings + 1:
		var th := PI * float(j) / rings
		var row: Array = []
		for i in segs + 1:
			var ph := TAU * float(i) / segs
			var u := Vector3(sin(th) * cos(ph), cos(th), sin(th) * sin(ph))
			var front := clampf(-u.z, 0.0, 1.0)
			var p := u * rad
			# Alt yüz daralır; çene genişliği varyanta göre
			var lower := clampf(-u.y, 0.0, 1.0)
			p.x *= lerpf(1.0, 0.78 * jaw, lower * lower)
			p.z *= lerpf(1.0, 0.92, lower)
			var d := 0.0
			d += 0.006 * brow * exp(-pow((u.y - 0.3) / 0.07, 2.0)) * smoothstep(0.55, 0.9, front)
			d -= 0.007 * exp(-pow((u.y - 0.14) / 0.08, 2.0)) * exp(-pow((absf(u.x) - 0.33) / 0.12, 2.0)) * smoothstep(0.5, 0.85, front)
			d += 0.005 * exp(-pow(u.y / 0.1, 2.0)) * exp(-pow((absf(u.x) - 0.58) / 0.14, 2.0)) * smoothstep(0.3, 0.7, front)
			var bridge := smoothstep(0.24, 0.0, u.y) * smoothstep(-0.2, -0.05, u.y)
			d += 0.026 * nose * bridge * (0.4 + 0.6 * smoothstep(0.2, -0.12, u.y)) * exp(-pow(u.x / (0.09 * nose), 2.0)) * smoothstep(0.8, 0.98, front)
			d -= 0.004 * exp(-pow((u.y + 0.33) / 0.04, 2.0)) * exp(-pow(u.x / 0.2, 2.0)) * smoothstep(0.8, 0.97, front)
			d += 0.003 * exp(-pow((u.y + 0.28) / 0.05, 2.0)) * exp(-pow(u.x / 0.18, 2.0)) * smoothstep(0.8, 0.97, front)
			d += 0.008 * jaw * exp(-pow((u.y + 0.62) / 0.12, 2.0)) * exp(-pow(u.x / 0.3, 2.0)) * smoothstep(0.6, 0.95, front)
			row.append(c + p + u * d)
		grid.append(row)
	var st := b.st("skin", skin)
	var lowface := b.st("stubble", stubble_mat) if sp["stubble"] else st
	for j in rings:
		for i in segs:
			var q := [[j, i], [j + 1, i], [j + 1, i + 1], [j, i], [j + 1, i + 1], [j, i + 1]]
			var center: Vector3 = grid[j][i]
			var u_y := (center.y - c.y) / rad.y
			var u_front := (c.z - center.z) / rad.z
			var target := lowface if u_y < -0.25 and u_front > -0.2 else st
			for k in q:
				var jj: int = k[0]
				var ii: int = k[1]
				var p: Vector3 = grid[jj][ii]
				var pu: Vector3 = grid[maxi(jj - 1, 0)][ii]
				var pd: Vector3 = grid[mini(jj + 1, rings)][ii]
				var pl: Vector3 = grid[jj][(ii - 1 + segs) % segs]
				var pr: Vector3 = grid[jj][(ii + 1) % segs]
				var n := (pr - pl).cross(pd - pu)
				if n.dot(p - c) < 0.0:
					n = -n
				if n.length() < 0.000001:
					n = p - c
				b.vert(target, p, n, Vector2(float(ii) / segs, float(jj) / rings), HD, HD, 0.0)


static func _body_mesh(kind: String, v: int) -> ArrayMesh:
	var cache_key := "%s_%d" % [kind, v]
	if _meshes.has(cache_key):
		return _meshes[cache_key]
	var sp := _variant(kind, v)
	var b := Builder.new()
	var cloth := material("fabric", sp["uniform"])
	var trou := material("fabric", sp["trousers"])
	var put := material("fabric", sp["puttee"])
	var skin := material("skin", sp["skin"])
	var hairc: Color = sp["hair"]
	var stubble := material("skin", (sp["skin"] as Color).lerp(hairc, 0.3))
	var lea := material("leather", sp["leather"])
	var hair := material("hair", hairc)
	var dark := material("hair", Color(0.05, 0.04, 0.03))
	var eye_white := material("skin", Color(0.86, 0.84, 0.8))
	var metal := material("metal", Color(0.55, 0.5, 0.35))
	var hatm := material("fabric", sp["hat"])
	var wool := material("fabric", Color(0.5, 0.45, 0.38))
	var H := bone_index("hips")
	var SP := bone_index("spine")
	var CH := bone_index("chest")
	var NK := bone_index("neck")
	var HD := bone_index("head")
	var sw: float = sp["shoulders"]
	var ww: float = sp["waist"]

	# Ceket (ya da gömlek): kalçadan omuza; subay paltosu dize kadar iner.
	var shirt: bool = sp["shirt"]
	var hem := 0.52 if sp["coat"] else (0.93 if shirt else 0.8)
	b.loft("cloth", cloth, [
		[hem, 0, 0.01, (0.2 if sp["coat"] else (0.165 if shirt else 0.19)) * ww, 0.155 * ww, H, H, 0.0],
		[0.9, 0, 0.0, 0.18 * ww, 0.13 * ww, H, H, 0.0],
		[1.0, 0, -0.01 * (ww - 1.0) * 4.0, 0.16 * ww, 0.115 * ww, H, SP, 0.3],
		[1.12, 0, -0.012 * (ww - 1.0) * 4.0, 0.165 * lerpf(1.0, ww, 0.7), 0.115 * lerpf(1.0, ww, 0.8), SP, SP, 0.0],
		[1.27, 0, -0.005, 0.185 * sw, 0.13, SP, CH, 0.7],
		[1.4, 0, 0.0, 0.2 * sw, 0.125, CH, CH, 0.0],
		[1.47, 0, 0.005, 0.16 * sw, 0.1, CH, CH, 0.0],
		[1.51, 0, 0.01, 0.075, 0.07, CH, NK, 0.5],
	], 18)
	# Yaka ve düğmeler
	b.loft("cloth", cloth, [[1.49, 0, 0.005, 0.082, 0.077, NK, NK, 0.0], [1.575, 0, 0.008, 0.07, 0.068, NK, NK, 0.0]], 12)
	for i in 5:
		b.ellipsoid("metal", metal, Vector3(0, 1.43 - i * 0.09, -0.128 * lerpf(1.0, ww, 0.5) + i * 0.003), Vector3(0.009, 0.009, 0.006), CH if i < 2 else SP, 6, 4)
	if not shirt:
		for side in [-1.0, 1.0]:
			b.box("cloth", cloth, Vector3(side * 0.09 * sw, 1.36, -0.13), Vector3(0.07, 0.06, 0.012), CH)  # göğüs cepleri
	# Kemer
	b.loft("leather", lea, [[0.96, 0, 0.0, 0.172 * ww, 0.123 * ww, H, H, 0.0], [1.02, 0, 0.0, 0.17 * ww, 0.122 * ww, H, H, 0.0]], 16)
	b.box("metal", metal, Vector3(0, 0.99, -0.125 * ww), Vector3(0.06, 0.05, 0.012), H)
	if shirt:
		# Pantolon askıları
		for side in [-1.0, 1.0]:
			b.ribbon("leather", lea, [Vector3(side * 0.09, 1.0, -0.12 * ww), Vector3(side * 0.1, 1.25, -0.135), Vector3(side * 0.11, 1.45, -0.09), Vector3(side * 0.1, 1.47, 0.06), Vector3(side * 0.06, 1.25, 0.13), Vector3(side * 0.05, 1.0, 0.12 * ww)], 0.022, [H, SP, CH, CH, SP, H])
	if kind == "officer" or kind == "kemal":
		# Sam Browne omuz kayışı (sol omuzdan sağ kalçaya) ve tabanca kılıfı
		b.ribbon("leather", lea, [Vector3(-0.12, 1.46, 0.06), Vector3(-0.13, 1.44, -0.12), Vector3(-0.04, 1.3, -0.14), Vector3(0.06, 1.14, -0.125), Vector3(0.13, 1.0, -0.12)], 0.035, [CH, CH, CH, SP, H])
		b.ribbon("leather", lea, [Vector3(-0.12, 1.46, 0.06), Vector3(-0.08, 1.3, 0.13), Vector3(0.05, 1.14, 0.125), Vector3(0.13, 1.0, 0.12)], 0.035, [CH, CH, SP, H])
		b.box("leather", lea, Vector3(0.19, 0.9, -0.02), Vector3(0.05, 0.14, 0.09), H)
	else:
		for side in [-1.0, 1.0]:
			for k in 2:
				b.box("leather", lea, Vector3(side * (0.06 + k * 0.065) * ww, 0.98, -0.13 * ww), Vector3(0.055, 0.07, 0.05), H)
		b.box("cloth", hatm, Vector3(-0.17 * ww, 0.86, 0.06), Vector3(0.06, 0.16, 0.18), H)  # ekmek torbası
		b.ribbon("leather", lea, [Vector3(0.13, 1.46, 0.05), Vector3(0.14, 1.44, -0.12), Vector3(0.04, 1.3, -0.14), Vector3(-0.07, 1.13, -0.125), Vector3(-0.15, 0.96, -0.11)], 0.04, [CH, CH, CH, SP, H])
	if sp["bandolier"]:
		# Göğüste çapraz fişeklik: sağ omuzdan sol kalçaya fişek cepleri
		for k in 7:
			var t := float(k) / 6.0
			var pt := Vector3(lerpf(0.14, -0.14, t), lerpf(1.42, 1.0, t), -0.14 + sin(t * PI) * -0.01)
			b.box("leather", lea, pt, Vector3(0.05, 0.055, 0.03), CH if t < 0.4 else (SP if t < 0.8 else H), Basis(Vector3.BACK, -0.6))
	if sp["blanket"]:
		# Sol omuzdan sağ kalçaya, göğüs ve sırttan dolanan rulo battaniye
		for zside in [-1.0, 1.0]:
			var pts := []
			var bones := []
			for k in 9:
				var t := float(k) / 8.0
				pts.append(Vector3(lerpf(-0.12, 0.16, t) * sw, lerpf(1.48, 0.97, t), zside * lerpf(0.11, 0.15, sin(t * PI))))
				bones.append(CH if t < 0.45 else (SP if t < 0.8 else H))
			b.tube("wool", wool, pts, 0.042, bones)
	if sp["canteen"]:
		b.ellipsoid("metal", material("fabric", Color(0.36, 0.33, 0.25)), Vector3(0.17 * ww, 0.88, 0.07), Vector3(0.035, 0.08, 0.07), H, 10, 6)
	if sp["pack"]:
		b.box("cloth", hatm, Vector3(0, 1.3, 0.15), Vector3(0.24 * sw, 0.26, 0.09), CH)
		b.box("wool", wool, Vector3(0, 1.47, 0.14), Vector3(0.26 * sw, 0.06, 0.07), CH)
	if kind == "kemal":
		b.box("leather", lea, Vector3(0.05, 1.33, -0.14), Vector3(0.13, 0.07, 0.06), CH)  # dürbün kutusu
	# Boyun ve baş
	b.loft("skin", skin, [[1.5, 0, 0.012, 0.062, 0.06, NK, NK, 0.0], [1.63, 0, 0.012, 0.056, 0.056, NK, HD, 1.0]], 12)
	_head(b, sp, skin, stubble, HD)
	var hw: float = sp["head_w"]
	for side in [-1.0, 1.0]:
		b.ellipsoid("skin", skin, Vector3(side * 0.083 * hw, 1.69, 0.008), Vector3(0.008, 0.027, 0.017), HD, 8, 6)  # kulak
		var ex: float = side * 0.032 * hw
		b.ellipsoid("eye", eye_white, Vector3(ex, 1.716, -0.08), Vector3(0.0095, 0.0048, 0.005), HD, 8, 5)  # göz akı
		b.ellipsoid("hair", dark, Vector3(ex, 1.716, -0.0843), Vector3(0.0042, 0.0042, 0.0018), HD, 6, 4)  # iris
		b.box("hair", hair, Vector3(side * 0.034 * hw, 1.736, -0.09), Vector3(0.032, 0.005 * float(sp["brow"]) + 0.003, 0.008), HD, Basis(Vector3.BACK, side * -0.1))  # kaş
	b.ellipsoid("hair", hair, Vector3(0, 1.73, 0.03), Vector3(0.085 * hw, 0.07, 0.085), HD, 12, 8)  # şapka altından görünen saç
	b.ellipsoid("lips", material("skin", (sp["skin"] as Color).lerp(Color(0.55, 0.25, 0.22), 0.45)), Vector3(0, 1.648, -0.091), Vector3(0.018, 0.0045, 0.006), HD, 8, 4)  # dudak
	match sp["mustache"]:
		"thin":
			for side in [-1.0, 1.0]:
				b.ellipsoid("hair", hair, Vector3(side * 0.018, 1.665, -0.095), Vector3(0.018, 0.004, 0.006), HD, 8, 4)
		"thick":
			for side in [-1.0, 1.0]:
				b.ellipsoid("hair", hair, Vector3(side * 0.02, 1.662, -0.094), Vector3(0.023, 0.007, 0.009), HD, 8, 4)
		"handlebar":
			for side in [-1.0, 1.0]:
				b.ellipsoid("hair", hair, Vector3(side * 0.02, 1.663, -0.094), Vector3(0.022, 0.0055, 0.008), HD, 8, 4)
				b.ellipsoid("hair", hair, Vector3(side * 0.043, 1.672, -0.085), Vector3(0.006, 0.009, 0.005), HD, 6, 4)
	if sp["beard"]:
		b.ellipsoid("hair", hair, Vector3(0, 1.625, -0.05), Vector3(0.062 * float(sp["jaw"]), 0.048, 0.06), HD, 14, 8)
		for side in [-1.0, 1.0]:
			b.ellipsoid("hair", hair, Vector3(side * 0.06, 1.66, -0.03), Vector3(0.018, 0.04, 0.035), HD, 8, 5)

	# Şapkalar
	match sp["hat_kind"]:
		"helmet":
			# Wolseley sıcak iklim miğferi: yüksek kubbe, siper, puggaree sargısı
			b.ellipsoid("hat", hatm, Vector3(0, 1.8, 0.005), Vector3(0.115, 0.1, 0.13), HD, 16, 10)
			b.brim("hat", hatm, Vector3(0, 1.76, 0.0), 0.1, 0.17, HD, 0.0)
			b.loft("hat", material("fabric", Color(0.72, 0.66, 0.52)), [[1.765, 0, 0.005, 0.118, 0.133, HD, HD, 0.0], [1.8, 0, 0.005, 0.113, 0.128, HD, HD, 0.0]], 16)
		"cap":
			# Siperli hizmet kasketi
			b.loft("hat", hatm, [[1.77, 0, 0.005, 0.095, 0.105, HD, HD, 0.0], [1.81, 0, 0.0, 0.105, 0.118, HD, HD, 0.0], [1.83, 0, 0.0, 0.1, 0.11, HD, HD, 0.0]], 16, true)
			b.box("leather", lea, Vector3(0, 1.768, -0.11), Vector3(0.15, 0.008, 0.06), HD, Basis(Vector3.RIGHT, 0.25))
		"slouch":
			b.brim("hat", hatm, Vector3(0, 1.79, 0), 0.08, 0.26, HD, 0.08)
			b.loft("hat", hatm, [[1.78, 0, 0, 0.1, 0.11, HD, HD, 0.0], [1.86, 0, 0, 0.092, 0.1, HD, HD, 0.0], [1.9, 0, 0, 0.06, 0.08, HD, HD, 0.0]], 14, true)
			b.loft("leather", lea, [[1.79, 0, 0, 0.102, 0.112, HD, HD, 0.0], [1.81, 0, 0, 0.102, 0.112, HD, HD, 0.0]], 14)
		_:
			# Kabalak (Enveriye): başa sarılmış kumaş; üst üste sarım katları
			b.ellipsoid("hat", hatm, Vector3(0, 1.79, 0.005), Vector3(0.105 * hw, 0.085, 0.12), HD, 16, 10)
			for k in 3:
				var y := 1.755 + k * 0.03
				b.loft("hat", hatm, [[y, 0, 0.005, (0.113 - k * 0.012) * hw, 0.128 - k * 0.012, HD, HD, 0.0], [y + 0.022, 0, 0.005, (0.11 - k * 0.012) * hw, 0.125 - k * 0.012, HD, HD, 0.0]], 16)
			b.box("hat", hatm, Vector3(0, 1.72, 0.09), Vector3(0.15, 0.08, 0.02), HD, Basis(Vector3.RIGHT, -0.25))

	# Kollar ve bacaklar
	for side in [1.0, -1.0]:
		var pre := "r_" if side > 0.0 else "l_"
		var UA := bone_index(pre + "upperarm")
		var FA := bone_index(pre + "forearm")
		var HA := bone_index(pre + "hand")
		var x: float = side
		if sp["rolled"]:
			# Sıvanmış kollar: önkol çıplak, dirsek üstünde kıvrım
			b.loft("skin", skin, [[0.95, x * 0.23, 0.0, 0.036, 0.034, FA, HA, 0.1], [1.12, x * 0.222, 0.0, 0.043, 0.04, FA, FA, 0.0], [1.2, x * 0.22, 0.0, 0.046, 0.044, UA, FA, 0.5]], 12)
			b.loft("cloth", cloth, [
				[1.18, x * 0.22, 0.0, 0.06, 0.058, UA, FA, 0.4],
				[1.23, x * 0.218, 0.0, 0.058, 0.056, UA, UA, 0.0],
				[1.3, x * 0.21, 0.0, 0.058, 0.056, UA, UA, 0.0],
				[1.42, x * 0.2 * sw, 0.0, 0.066, 0.066, UA, UA, 0.0],
				[1.47, x * 0.18 * sw, 0.0, 0.05, 0.06, UA, CH, 0.5],
			], 12)
		else:
			b.loft("cloth", cloth, [
				[0.95, x * 0.23, 0.0, 0.05, 0.05, FA, HA, 0.1],
				[1.12, x * 0.222, 0.0, 0.052, 0.05, FA, FA, 0.0],
				[1.17, x * 0.22, 0.0, 0.054, 0.052, UA, FA, 0.5],
				[1.3, x * 0.21, 0.0, 0.06, 0.058, UA, UA, 0.0],
				[1.42, x * 0.2 * sw, 0.0, 0.066, 0.066, UA, UA, 0.0],
				[1.47, x * 0.18 * sw, 0.0, 0.05, 0.06, UA, CH, 0.5],
			], 12)
		# El: avuç ve başparmak
		b.ellipsoid("skin", skin, Vector3(x * 0.232, 0.88, -0.004), Vector3(0.026, 0.045, 0.022), HA, 10, 6)
		b.ellipsoid("skin", skin, Vector3(x * 0.222, 0.895, -0.024), Vector3(0.01, 0.025, 0.01), HA, 6, 4)
		var TH := bone_index(pre + "thigh")
		var SH := bone_index(pre + "shin")
		var FT := bone_index(pre + "foot")
		var lx: float = side * 0.1
		b.loft("trousers", trou, [
			[0.42, lx, 0.0, 0.058, 0.058, SH, SH, 0.0],
			[0.51, lx, 0.0, 0.065, 0.07, TH, SH, 0.5],
			[0.72, lx, 0.0, 0.08, 0.085, TH, TH, 0.0],
			[0.95, lx, 0.0, 0.1 * ww, 0.1 * ww, TH, H, 0.3],
		], 12)
		if sp["boots"]:
			b.loft("leather", lea, [[0.06, lx, 0.0, 0.05, 0.06, FT, FT, 0.0], [0.12, lx, 0.0, 0.052, 0.058, SH, SH, 0.0], [0.46, lx, 0.0, 0.06, 0.062, SH, SH, 0.0]], 12)
		else:
			# Dolak (sargı): spiral sargıyı andıran halkalar
			var rings := []
			for k in 9:
				var y := 0.1 + k * 0.043
				var bump := 0.004 if k % 2 == 0 else 0.0
				rings.append([y, lx, 0.0, 0.047 + k * 0.002 + bump, 0.05 + k * 0.002 + bump, SH, SH, 0.0])
			b.loft("puttee", put, rings, 12)
		b.ellipsoid("leather", lea, Vector3(lx, 0.05, -0.04), Vector3(0.05, 0.05, 0.12), FT, 10, 6)  # postal
		b.box("leather", lea, Vector3(lx, 0.012, -0.03), Vector3(0.1, 0.02, 0.25), FT)  # taban

	var mesh := b.commit()
	_meshes[cache_key] = mesh
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
static func build(kind: String, variant := -1) -> HumanRig:
	var rig := HumanRig.new()
	if variant < 0:
		variant = 0 if kind == "kemal" or kind == "officer" else randi() % VARIANTS
	var sp := _variant(kind, variant)
	rig.kind = kind
	rig.seed = variant * 31 + randi() % 1000
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
	mi.mesh = _body_mesh(kind, variant)
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
