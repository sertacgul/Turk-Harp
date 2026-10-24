class_name UnitMini
extends Node3D
## Harekât masasındaki birlik minyatürü: altıgen ahşap kaide, üzerinde askerler (sayısı birliğin
## gücünü gösterir), toplar ya da gemi; arkada milletinin dalgalanan bayrağı; üstte okunaklı ad.

const SKIN := [Color(0.86, 0.69, 0.55), Color(0.78, 0.6, 0.46), Color(0.7, 0.52, 0.4)]
const UNIFORM := {"tr": Color(0.36, 0.36, 0.22), "au": Color(0.55, 0.44, 0.26), "nz": Color(0.5, 0.42, 0.26),
	"uk": Color(0.48, 0.4, 0.25), "fr": Color(0.38, 0.47, 0.64)}
const RIM := {"tr": Color(0.7, 0.08, 0.1), "au": Color(0.1, 0.2, 0.5), "nz": Color(0.12, 0.18, 0.45),
	"uk": Color(0.12, 0.2, 0.45), "fr": Color(0.15, 0.25, 0.6)}

static var _mesh_cache := {}

var unit: Unit
var hw := 4.0
var _figs: MeshInstance3D
var _ship: Node3D
var _ring: MeshInstance3D
var _label: Label3D
var _sub: Label3D
var _fig_count := -1
var _top := 1.0


func setup(u: Unit, hex_world: float) -> void:
	unit = u
	hw = hex_world
	var nation := nation_key()
	if u.is_naval():
		_build_ship(nation)
	else:
		_build_base(nation)
		_build_flag(nation, 1.4 if u.is_fort() or u.is_hq() else 1.0)
	_ring = MeshInstance3D.new()
	var rm := TorusMesh.new()
	rm.inner_radius = hw * 0.44
	rm.outer_radius = hw * 0.5
	_ring.mesh = rm
	var rmat := StandardMaterial3D.new()
	rmat.albedo_color = Color(1.0, 0.85, 0.3)
	rmat.emission_enabled = true
	rmat.emission = Color(1.0, 0.75, 0.2)
	rmat.emission_energy_multiplier = 1.2
	rmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ring.material_override = rmat
	_ring.scale = Vector3(1, 0.25, 1)
	_ring.position.y = hw * 0.04
	_ring.visible = false
	add_child(_ring)
	_label = _make_label(40, UiTheme.font("bold"))
	_label.position.y = _top + hw * 0.1
	add_child(_label)
	_sub = _make_label(30, UiTheme.font("body"))
	_sub.position.y = _top + hw * 0.1
	_sub.offset = Vector2(0, -44)
	add_child(_sub)
	refresh()


func nation_key() -> String:
	if unit.nation == "anzac":
		return "au"
	return unit.nation if UNIFORM.has(unit.nation) else ("tr" if unit.side == Unit.OTTOMAN else "uk")


func _make_label(size: int, f: Font) -> Label3D:
	var l := Label3D.new()
	l.font = f
	l.font_size = size
	l.fixed_size = true
	l.pixel_size = 0.00042
	l.outline_size = 12
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.render_priority = 2
	l.outline_render_priority = 1
	l.modulate = Color(1, 0.97, 0.9)
	l.outline_modulate = Color(0.05, 0.03, 0.02, 0.95)
	return l


func _build_base(nation: String) -> void:
	var rim := MeshInstance3D.new()
	var rc := CylinderMesh.new()
	rc.radial_segments = 6
	rc.rings = 1
	rc.top_radius = hw * 0.4
	rc.bottom_radius = hw * 0.42
	rc.height = hw * 0.05
	rim.mesh = rc
	rim.position.y = hw * 0.025
	rim.rotation.y = PI / 6.0
	var rmat := StandardMaterial3D.new()
	rmat.albedo_color = RIM[nation]
	rmat.roughness = 0.5
	rim.material_override = rmat
	add_child(rim)
	var base := MeshInstance3D.new()
	var bc := CylinderMesh.new()
	bc.radial_segments = 6
	bc.rings = 1
	bc.top_radius = hw * 0.36
	bc.bottom_radius = hw * 0.38
	bc.height = hw * 0.05
	base.mesh = bc
	base.position.y = hw * 0.07
	base.rotation.y = PI / 6.0
	var bmat := StandardMaterial3D.new()
	bmat.albedo_color = Color(0.3, 0.33, 0.2) if not unit.is_fort() else Color(0.5, 0.44, 0.33)
	bmat.roughness = 0.9
	base.material_override = bmat
	add_child(base)
	_figs = MeshInstance3D.new()
	_figs.position.y = hw * 0.095
	var fm := StandardMaterial3D.new()
	fm.vertex_color_use_as_albedo = true
	fm.roughness = 0.75
	_figs.material_override = fm
	add_child(_figs)
	_top = hw * 0.55


func _build_flag(nation: String, scale_: float) -> void:
	var pole_h := hw * 0.78 * scale_
	var pole := MeshInstance3D.new()
	var pc := CylinderMesh.new()
	pc.top_radius = hw * 0.012
	pc.bottom_radius = hw * 0.016
	pc.height = pole_h
	pole.mesh = pc
	var px := -hw * 0.27
	var pz := hw * 0.12
	pole.position = Vector3(px, hw * 0.1 + pole_h * 0.5, pz)
	var pm := StandardMaterial3D.new()
	pm.albedo_color = Color(0.3, 0.22, 0.14)
	pole.material_override = pm
	add_child(pole)
	var knob := MeshInstance3D.new()
	var ks := SphereMesh.new()
	ks.radius = hw * 0.025
	ks.height = hw * 0.05
	knob.mesh = ks
	knob.position = Vector3(px, hw * 0.1 + pole_h, pz)
	var km := StandardMaterial3D.new()
	km.albedo_color = Color(0.85, 0.66, 0.25)
	km.metallic = 0.8
	km.roughness = 0.3
	knob.material_override = km
	add_child(knob)
	var fw := hw * 0.38 * scale_
	var q := QuadMesh.new()
	q.size = Vector2(fw, fw * 2.0 / 3.0)
	q.subdivide_width = 10
	q.subdivide_depth = 2
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/flag.gdshader")
	m.set_shader_parameter("flag_texture", Flags.texture(nation))
	m.set_shader_parameter("amp", fw * 0.07)
	m.set_shader_parameter("phase", randf() * 6.0)
	var f := MeshInstance3D.new()
	f.mesh = q
	f.material_override = m
	f.position = Vector3(px + fw * 0.5, hw * 0.1 + pole_h - fw / 3.0, pz)
	add_child(f)
	_top = maxf(_top, hw * 0.1 + pole_h)


func _build_ship(nation: String) -> void:
	var d: Dictionary
	if unit.kind == "sweeper":
		d = ShipBuilder.build_destroyer(nation)
	else:
		d = ShipBuilder.build_battleship(nation, 75.0, 13.0, 3 if unit.hp_max >= 120.0 else 2)
	_ship = d["root"]
	var length: float = d["length"]
	var sc := hw * (0.95 if unit.kind != "sweeper" else 0.55) / length
	_ship.scale = Vector3.ONE * sc
	_ship.position.y = 0.02
	add_child(_ship)
	_top = 13.0 * 2.2 * sc


func refresh() -> void:
	_label.text = unit.short
	var st := ""
	if unit.uses_hp():
		st = "%%%d" % int(round(unit.strength() * 100.0))
	else:
		st = "%d asker" % unit.men
	if unit.entrench > 0:
		st += " · siper %d" % unit.entrench
	if unit.suppressed > 0:
		st += " · susturuldu"
	_sub.text = st
	var m := clampf(unit.morale / 100.0, 0.0, 1.0)
	_sub.modulate = Color(1.0, 0.5, 0.4).lerp(Color(0.8, 1.0, 0.75), m)
	if _figs:
		var n := _figure_count()
		if n != _fig_count:
			_fig_count = n
			_figs.mesh = _figure_mesh(n)


func _figure_count() -> int:
	if unit.kind in ["artillery", "fort", "hq", "mg"]:
		return 1
	var full := 5 if unit.size in ["tabur", "alay"] else 3
	return clampi(int(ceil(unit.strength() * full)), 1, full)


func set_selected(on: bool) -> void:
	_ring.visible = on


## Yürürken figürler hafifçe sekmeli.
func march(duration: float) -> void:
	if _figs == null:
		return
	var tw := create_tween()
	var steps := maxi(1, int(duration / 0.12))
	for i in steps:
		tw.tween_property(_figs, "position:y", hw * 0.095 + hw * 0.025, 0.06)
		tw.tween_property(_figs, "position:y", hw * 0.095, 0.06)


## Birliği hedefe döndürür (kaide altıgeni sabit kalır, figürler döner).
func face(world_dir: Vector3) -> void:
	if world_dir.length() < 0.01:
		return
	var a := atan2(world_dir.x, world_dir.z)
	if _figs:
		_figs.rotation.y = a
	elif _ship:
		_ship.rotation.y = a - PI / 2.0


# ------------------------------------------------------------------ Figür ağları

func _figure_mesh(n: int) -> ArrayMesh:
	var nation := nation_key()
	var key := "%s_%s_%d" % [nation, unit.kind, n]
	if _mesh_cache.has(key):
		return _mesh_cache[key]
	var b := MiniMesh.new()
	var s := hw * 0.31
	var spots := [Vector2(0, 0.05), Vector2(-0.16, -0.09), Vector2(0.16, -0.09), Vector2(-0.12, 0.17), Vector2(0.12, 0.17)]
	match unit.kind:
		"artillery":
			var how := false
			for id_ in unit.equipment:
				if String(id_).contains("obus"):
					how = true
			_gun(b, Vector3(0, 0, 0.02 * hw), s, how)
			_soldier(b, nation, Vector3(-0.17 * hw, 0, -0.08 * hw), s * 0.95, 0.4, 0)
			_soldier(b, nation, Vector3(0.17 * hw, 0, -0.1 * hw), s * 0.95, -0.4, 1)
		"mg":
			_mg(b, Vector3(0, 0, 0.06 * hw), s)
			_soldier(b, nation, Vector3(-0.14 * hw, 0, -0.06 * hw), s, 0.3, 0)
			_soldier(b, nation, Vector3(0.14 * hw, 0, -0.08 * hw), s, -0.2, 1)
		"fort":
			_fort(b, s)
			_soldier(b, nation, Vector3(0.05 * hw, s * 0.18, -0.12 * hw), s * 0.9, 0.0, 0)
		"hq":
			_tent(b, Vector3(0.1 * hw, 0, -0.08 * hw), s)
			_soldier(b, nation, Vector3(-0.05 * hw, 0, 0.1 * hw), s * 1.05, 0.0, 0, true)
			_soldier(b, nation, Vector3(0.15 * hw, 0, 0.14 * hw), s * 0.95, 0.3, 1)
		_:
			for i in n:
				var sp: Vector2 = spots[i]
				_soldier(b, nation, Vector3(sp.x * hw, 0, sp.y * hw), s * (1.0 - 0.04 * (i % 2)), (i - 2) * 0.12, i)
	var m := b.commit()
	_mesh_cache[key] = m
	return m


## Ayakta asker; officer: subay (koyu palto, dürbün, Osmanlı'da kalpak).
func _soldier(b: MiniMesh, nation: String, at: Vector3, h: float, turn: float, idx: int, officer := false) -> void:
	var uni: Color = UNIFORM[nation]
	if officer:
		uni = Color(0.3, 0.31, 0.26) if nation == "tr" else uni.darkened(0.2)
	uni = uni.lightened(0.04 * (idx % 3) - 0.03)
	var skin: Color = SKIN[idx % SKIN.size()]
	var boot := Color(0.2, 0.13, 0.08)
	var putt := uni.darkened(0.15)
	var t := Transform3D(Basis(Vector3.UP, turn), at)
	# Bacaklar (dolaklı) ve postal
	for sx in [-0.06, 0.06]:
		b.box(t, Vector3(sx, 0.2, 0) * h, Vector3(0.085, 0.36, 0.1) * h, putt)
		b.box(t, Vector3(sx, 0.03, 0.02) * h, Vector3(0.09, 0.06, 0.14) * h, boot)
	# Gövde, kemer, palaska
	b.box(t, Vector3(0, 0.56, 0) * h, Vector3(0.25, 0.34, 0.15) * h, uni)
	b.box(t, Vector3(0, 0.44, 0) * h, Vector3(0.26, 0.04, 0.16) * h, Color(0.3, 0.2, 0.12))
	if officer:
		b.box(t, Vector3(0, 0.36, 0) * h, Vector3(0.27, 0.2, 0.17) * h, uni)
	# Kollar
	for sx in [-0.16, 0.16]:
		b.box(t, Vector3(sx, 0.56, 0.03) * h, Vector3(0.07, 0.3, 0.08) * h, uni)
	# Baş
	b.sphere(t, Vector3(0, 0.82, 0) * h, 0.085 * h, skin)
	# Başlık
	match nation:
		"tr":
			if officer:
				b.cyl(t, Vector3(0, 0.93, 0) * h, 0.085 * h, 0.1 * h, Color(0.12, 0.1, 0.09))
			else:
				# Kabalak: başa sarılı bez
				b.sphere(t, Vector3(0, 0.9, 0) * h, 0.1 * h, Color(0.6, 0.55, 0.4), Vector3(1.0, 0.6, 1.0))
		"au":
			# Geniş kenarlı keçe şapka
			b.cyl(t, Vector3(0, 0.89, 0) * h, 0.17 * h, 0.012 * h, uni.darkened(0.25))
			b.cyl(t, Vector3(0, 0.93, 0) * h, 0.085 * h, 0.08 * h, uni.darkened(0.25))
		"nz":
			# "Limon sıkacağı" sivri şapka
			b.cyl(t, Vector3(0, 0.89, 0) * h, 0.16 * h, 0.012 * h, uni.darkened(0.25))
			b.cone(t, Vector3(0, 0.9, 0) * h, 0.085 * h, 0.13 * h, uni.darkened(0.25))
		_:
			b.cyl(t, Vector3(0, 0.9, 0) * h, 0.09 * h, 0.06 * h, uni.darkened(0.15))
			b.box(t, Vector3(0, 0.88, 0.08) * h, Vector3(0.12, 0.012, 0.07) * h, Color(0.15, 0.12, 0.1))
	if officer:
		# Dürbün
		b.box(t, Vector3(0, 0.8, 0.1) * h, Vector3(0.11, 0.05, 0.07) * h, Color(0.08, 0.08, 0.08))
		return
	# Tüfek (süngülü), göğüs önünde çapraz
	var rt := t * Transform3D(Basis(Vector3(0, 0, 1), 0.6), Vector3(0.0, 0.58, 0.11) * h)
	b.box(rt, Vector3(0, 0, 0), Vector3(0.035, 0.68, 0.035) * h, Color(0.38, 0.24, 0.12))
	b.box(rt, Vector3(0, 0.36, 0) * h, Vector3(0.018, 0.16, 0.018) * h, Color(0.75, 0.75, 0.78))


func _gun(b: MiniMesh, at: Vector3, s: float, howitzer: bool) -> void:
	var t := Transform3D(Basis.IDENTITY, at)
	var steel := Color(0.2, 0.22, 0.2)
	var wood := Color(0.36, 0.26, 0.16)
	# Tekerlekler
	for sx in [-0.22, 0.22]:
		var wt := t * Transform3D(Basis(Vector3(0, 0, 1), PI / 2.0), Vector3(sx, 0.2, 0) * s)
		b.cyl(wt, Vector3.ZERO, 0.2 * s, 0.05 * s, wood)
		b.cyl(wt, Vector3.ZERO, 0.05 * s, 0.07 * s, steel)
	b.box(t, Vector3(0, 0.2, -0.1) * s, Vector3(0.36, 0.08, 0.5) * s, steel)
	b.box(t, Vector3(0, 0.06, -0.55) * s, Vector3(0.08, 0.06, 0.6) * s, wood)
	b.box(t, Vector3(0, 0.38, 0.1) * s, Vector3(0.44, 0.3, 0.03) * s, steel.lightened(0.1))
	var elev := 0.55 if howitzer else 0.15
	var bt := t * Transform3D(Basis(Vector3(1, 0, 0), -PI / 2.0 + elev), Vector3(0, 0.3, 0.05) * s)
	var r := 0.085 if howitzer else 0.05
	var l := 0.55 if howitzer else 0.85
	b.cyl(bt, Vector3(0, l * 0.5, 0) * s, r * s, l * s, steel)


func _mg(b: MiniMesh, at: Vector3, s: float) -> void:
	var t := Transform3D(Basis.IDENTITY, at)
	var steel := Color(0.15, 0.16, 0.15)
	for a in [0.0, 2.1, 4.2]:
		var lt := t * Transform3D(Basis(Vector3.UP, a) * Basis(Vector3(1, 0, 0), 0.5), Vector3(0, 0.12, 0) * s)
		b.cyl(lt, Vector3(0, -0.08, 0) * s, 0.015 * s, 0.26 * s, steel)
	b.box(t, Vector3(0, 0.26, 0.02) * s, Vector3(0.1, 0.12, 0.3) * s, steel)
	b.cyl(t * Transform3D(Basis(Vector3(1, 0, 0), PI / 2.0), Vector3(0, 0.27, 0.32) * s), Vector3.ZERO, 0.03 * s, 0.35 * s, steel)
	b.box(t, Vector3(0, 0.3, -0.02) * s, Vector3(0.22, 0.16, 0.02) * s, steel.lightened(0.1))


func _fort(b: MiniMesh, s: float) -> void:
	var earth := Color(0.58, 0.5, 0.36)
	var stone := Color(0.66, 0.62, 0.54)
	# Altıgen toprak tabya duvarı
	for i in 6:
		var a := TAU * i / 6.0
		var t := Transform3D(Basis(Vector3.UP, a), Vector3(sin(a), 0, cos(a)) * 0.95 * s)
		b.box(t, Vector3(0, 0.12, 0) * s, Vector3(1.05, 0.24, 0.2) * s, earth.darkened(0.05 * (i % 2)))
	b.box(Transform3D.IDENTITY, Vector3(0, 0.05, 0), Vector3(1.6, 0.1, 1.6) * s, earth.darkened(0.1))
	# İki ağır kıyı topu
	for sx in [-0.35, 0.35]:
		var t2 := Transform3D(Basis.IDENTITY, Vector3(sx, 0.1, 0.1) * s)
		b.cyl(t2, Vector3(0, 0.08, 0) * s, 0.22 * s, 0.16 * s, stone)
		var bt := t2 * Transform3D(Basis(Vector3(1, 0, 0), -PI / 2.0 + 0.12), Vector3(0, 0.25, 0) * s)
		b.cyl(bt, Vector3(0, 0.55, 0) * s, 0.075 * s, 1.1 * s, Color(0.18, 0.19, 0.18))
		b.box(t2, Vector3(0, 0.26, -0.05) * s, Vector3(0.3, 0.22, 0.34) * s, Color(0.22, 0.23, 0.22))


func _tent(b: MiniMesh, at: Vector3, s: float) -> void:
	var canvas := Color(0.55, 0.5, 0.36)
	var t := Transform3D(Basis.IDENTITY, at)
	for side in [-1.0, 1.0]:
		var pt := t * Transform3D(Basis(Vector3(0, 0, 1), side * 0.75), Vector3(side * 0.16, 0.2, 0) * s)
		b.box(pt, Vector3.ZERO, Vector3(0.04, 0.5, 0.6) * s, canvas.darkened(0.08 if side > 0 else 0.0))


## Birleştirilmiş, köşe renkli minyatür ağı.
class MiniMesh:
	var st := SurfaceTool.new()

	func _init() -> void:
		st.begin(Mesh.PRIMITIVE_TRIANGLES)

	func _add(m: Mesh, xf: Transform3D, col: Color) -> void:
		var arr := m.surface_get_arrays(0)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var nrm: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
		var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
		var nb := xf.basis.inverse().transposed()
		for i in idx:
			st.set_color(col)
			st.set_normal((nb * nrm[i]).normalized())
			st.add_vertex(xf * v[i])

	func box(t: Transform3D, pos: Vector3, size: Vector3, col: Color) -> void:
		var m := BoxMesh.new()
		m.size = size
		_add(m, t * Transform3D(Basis.IDENTITY, pos), col)

	func cyl(t: Transform3D, pos: Vector3, r: float, h: float, col: Color) -> void:
		var m := CylinderMesh.new()
		m.top_radius = r
		m.bottom_radius = r
		m.height = h
		m.radial_segments = 10
		m.rings = 1
		_add(m, t * Transform3D(Basis.IDENTITY, pos), col)

	func cone(t: Transform3D, pos: Vector3, r: float, h: float, col: Color) -> void:
		var m := CylinderMesh.new()
		m.top_radius = 0.0
		m.bottom_radius = r
		m.height = h
		m.radial_segments = 10
		m.rings = 1
		_add(m, t * Transform3D(Basis.IDENTITY, pos + Vector3(0, h * 0.5, 0)), col)

	func sphere(t: Transform3D, pos: Vector3, r: float, col: Color, sc := Vector3.ONE) -> void:
		var m := SphereMesh.new()
		m.radius = r
		m.height = r * 2.0
		m.radial_segments = 10
		m.rings = 6
		_add(m, t * Transform3D(Basis.from_scale(sc), pos), col)

	func commit() -> ArrayMesh:
		return st.commit()
