class_name UnitCounter
extends Node3D
## Haritadaki birlik pulu: harp oyunu pulu gibi kalın bir karo, üstünde NATO tarzı askerî sembol,
## üzerinde birlik adı ve gücü. Pul rengi milleti gösterir.

const COLORS := {
	"tr": [Color(0.6, 0.09, 0.1), Color(0.97, 0.93, 0.84)],
	"anzac": [Color(0.66, 0.57, 0.38), Color(0.14, 0.12, 0.08)],
	"uk": [Color(0.55, 0.47, 0.35), Color(0.12, 0.1, 0.08)],
	"fr": [Color(0.45, 0.56, 0.72), Color(0.08, 0.1, 0.16)],
	"uk_navy": [Color(0.5, 0.53, 0.57), Color(0.08, 0.09, 0.12)],
	"fr_navy": [Color(0.42, 0.52, 0.68), Color(0.06, 0.08, 0.14)],
}

static var _tex_cache := {}

var unit: Unit
var size_w := 1.0
var _label: Label3D
var _sub: Label3D
var _ring: MeshInstance3D
var _body: MeshInstance3D
var _top: MeshInstance3D


func setup(u: Unit, hex_world: float) -> void:
	unit = u
	size_w = hex_world * 0.62
	var thick := size_w * 0.16
	var cols: Array = COLORS[_color_key()]
	_body = MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(size_w, thick, size_w * (0.62 if u.is_naval() else 1.0))
	_body.mesh = bm
	_body.position.y = thick * 0.5
	var side := StandardMaterial3D.new()
	side.albedo_color = (cols[0] as Color).darkened(0.25)
	side.roughness = 0.6
	_body.material_override = side
	add_child(_body)
	_top = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(bm.size.x * 0.98, bm.size.z * 0.98)
	_top.mesh = q
	_top.rotation_degrees.x = -90.0
	_top.position.y = thick + 0.002
	var tm := StandardMaterial3D.new()
	tm.albedo_texture = symbol_texture(u)
	tm.roughness = 0.75
	_top.material_override = tm
	add_child(_top)
	_ring = MeshInstance3D.new()
	var rm := TorusMesh.new()
	rm.inner_radius = size_w * 0.62
	rm.outer_radius = size_w * 0.72
	_ring.mesh = rm
	var rmat := StandardMaterial3D.new()
	rmat.albedo_color = Color(1.0, 0.85, 0.3)
	rmat.emission_enabled = true
	rmat.emission = Color(1.0, 0.75, 0.2)
	rmat.emission_energy_multiplier = 0.8
	rmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ring.material_override = rmat
	_ring.scale = Vector3(1, 0.3, 1)
	_ring.position.y = thick * 0.5
	_ring.visible = false
	add_child(_ring)
	_label = Label3D.new()
	_label.pixel_size = size_w / 190.0
	_label.font_size = 64
	_label.outline_size = 14
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.position.y = thick + size_w * 0.75
	_label.modulate = Color(1, 0.97, 0.9)
	_label.outline_modulate = Color(0.06, 0.04, 0.03, 0.9)
	add_child(_label)
	_sub = Label3D.new()
	_sub.pixel_size = size_w / 220.0
	_sub.font_size = 48
	_sub.outline_size = 12
	_sub.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_sub.position.y = thick + size_w * 0.4
	_sub.outline_modulate = Color(0.06, 0.04, 0.03, 0.9)
	add_child(_sub)
	refresh()


func _color_key() -> String:
	if unit.is_naval():
		return "fr_navy" if unit.nation == "fr" else ("uk_navy" if unit.side == Unit.ENTENTE else "tr")
	return unit.nation if COLORS.has(unit.nation) else ("tr" if unit.side == Unit.OTTOMAN else "uk")


func refresh() -> void:
	_label.text = unit.short
	var st := ""
	if unit.uses_hp():
		st = "%%%d" % int(round(unit.strength() * 100.0))
	else:
		st = str(unit.men)
	if unit.entrench > 0:
		st += "  " + "▬".repeat(unit.entrench)
	if unit.suppressed > 0:
		st += "  susturuldu"
	_sub.text = st
	var m := unit.morale / 100.0
	_sub.modulate = Color(1.0, 0.45, 0.35).lerp(Color(0.75, 1.0, 0.7), clampf(m, 0.0, 1.0))


func set_selected(on: bool) -> void:
	_ring.visible = on


## Çok kullanılan sembolleri bir kez çizer.
static func symbol_texture(u: Unit) -> ImageTexture:
	var nation := u.nation
	var key := "%s_%s_%s_%s" % [nation, u.kind, u.size, u.side]
	if _tex_cache.has(key):
		return _tex_cache[key]
	var col_key := nation
	if u.is_naval():
		col_key = "fr_navy" if nation == "fr" else ("uk_navy" if u.side == Unit.ENTENTE else "tr")
	var cols: Array = COLORS.get(col_key, COLORS["uk"])
	var bg: Color = cols[0]
	var fg: Color = cols[1]
	var n := 128
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	img.fill(bg)
	# Kenar çizgisi
	_rect(img, Rect2i(3, 3, n - 6, n - 6), bg.darkened(0.35), 3)
	var naval := u.is_naval()
	var fr := Rect2i(26, 40, 76, 50) if not naval else Rect2i(20, 44, 88, 40)
	match u.kind:
		"infantry", "mg":
			_rect(img, fr, fg, 4)
			_line(img, Vector2(fr.position), Vector2(fr.end), fg, 3.5)
			_line(img, Vector2(fr.position.x, fr.end.y), Vector2(fr.end.x, fr.position.y), fg, 3.5)
			if u.kind == "mg":
				_line(img, Vector2(fr.position.x + 8, fr.get_center().y), Vector2(fr.end.x - 8, fr.get_center().y), fg, 3.0)
		"hq":
			# Karargâh: çerçeve ve sol alttan inen bayrak direği
			_rect(img, fr, fg, 4)
			img.fill_rect(Rect2i(fr.position.x, fr.end.y, 4, 22), fg)
			_disc(img, Vector2(fr.get_center()), 6.0, fg)
		"artillery":
			_rect(img, fr, fg, 4)
			_disc(img, Vector2(fr.get_center()), 10.0, fg)
		"fort":
			# Tabya: burçlu sur
			var base := Rect2i(24, 58, 80, 34)
			img.fill_rect(base, fg)
			for i in 5:
				img.fill_rect(Rect2i(24 + i * 17, 46, 10, 14), fg)
			img.fill_rect(Rect2i(56, 72, 16, 20), bg)
		"ship":
			# Zırhlı silueti: gövde, üst yapı, bacalar ve taretler
			var pts := PackedVector2Array([Vector2(14, 70), Vector2(114, 70), Vector2(104, 86), Vector2(26, 86)])
			_poly(img, pts, fg)
			img.fill_rect(Rect2i(46, 56, 36, 14), fg)
			img.fill_rect(Rect2i(54, 42, 7, 14), fg)
			img.fill_rect(Rect2i(67, 42, 7, 14), fg)
			img.fill_rect(Rect2i(24, 62, 14, 8), fg)
			img.fill_rect(Rect2i(90, 62, 14, 8), fg)
		"sweeper":
			var pts2 := PackedVector2Array([Vector2(34, 66), Vector2(94, 66), Vector2(86, 80), Vector2(40, 80)])
			_poly(img, pts2, fg)
			img.fill_rect(Rect2i(56, 52, 12, 14), fg)
			for i in 4:
				_line(img, Vector2(20 + i * 22, 94), Vector2(31 + i * 22, 102), fg, 2.0)
				_line(img, Vector2(31 + i * 22, 102), Vector2(42 + i * 22, 94), fg, 2.0)
	# Birlik büyüklüğü işaretleri (çerçevenin üstünde)
	var marks := {"bölük": 1, "batarya": 1, "tabur": 2, "alay": 3}.get(u.size, 0) as int
	for i in marks:
		var x := 64 - (marks - 1) * 6 + i * 12
		img.fill_rect(Rect2i(x - 2, 22, 4, 13), fg)
	if u.size == "tümen":
		_line(img, Vector2(52, 22), Vector2(64, 35), fg, 2.5)
		_line(img, Vector2(52, 35), Vector2(64, 22), fg, 2.5)
		_line(img, Vector2(66, 22), Vector2(78, 35), fg, 2.5)
		_line(img, Vector2(66, 35), Vector2(78, 22), fg, 2.5)
	# Osmanlı pullarında köşede ay-yıldız
	if u.side == Unit.OTTOMAN:
		_disc(img, Vector2(108, 108), 9.0, fg)
		_disc(img, Vector2(111, 108), 7.5, bg)
		_disc(img, Vector2(117, 108), 2.2, fg)
	elif nation == "anzac":
		img.fill_rect(Rect2i(8, 108, 30, 8), Color(0.15, 0.35, 0.18))
	elif nation == "fr" and not naval:
		img.fill_rect(Rect2i(8, 108, 10, 8), Color(0.1, 0.2, 0.55))
		img.fill_rect(Rect2i(18, 108, 10, 8), Color(0.95, 0.95, 0.95))
		img.fill_rect(Rect2i(28, 108, 10, 8), Color(0.75, 0.1, 0.12))
	img.generate_mipmaps()
	var t := ImageTexture.create_from_image(img)
	_tex_cache[key] = t
	return t


static func _rect(img: Image, r: Rect2i, c: Color, w: int) -> void:
	img.fill_rect(Rect2i(r.position.x, r.position.y, r.size.x, w), c)
	img.fill_rect(Rect2i(r.position.x, r.end.y - w, r.size.x, w), c)
	img.fill_rect(Rect2i(r.position.x, r.position.y, w, r.size.y), c)
	img.fill_rect(Rect2i(r.end.x - w, r.position.y, w, r.size.y), c)


static func _disc(img: Image, c: Vector2, r: float, col: Color) -> void:
	for y in range(int(c.y - r - 1), int(c.y + r + 2)):
		for x in range(int(c.x - r - 1), int(c.x + r + 2)):
			if x < 0 or y < 0 or x >= img.get_width() or y >= img.get_height():
				continue
			var d := Vector2(x + 0.5, y + 0.5).distance_to(c)
			if d <= r:
				img.set_pixel(x, y, col)


static func _line(img: Image, a: Vector2, b: Vector2, col: Color, w: float) -> void:
	var steps := int(a.distance_to(b))
	for i in steps + 1:
		_disc(img, a.lerp(b, float(i) / maxf(steps, 1)), w * 0.5, col)


static func _poly(img: Image, pts: PackedVector2Array, col: Color) -> void:
	var r := Rect2(pts[0], Vector2.ZERO)
	for p in pts:
		r = r.expand(p)
	for y in range(int(r.position.y), int(r.end.y) + 1):
		for x in range(int(r.position.x), int(r.end.x) + 1):
			if Geometry2D.is_point_in_polygon(Vector2(x + 0.5, y + 0.5), pts):
				img.set_pixel(x, y, col)
