class_name Flags
extends RefCounted
## Dönemin bayrakları, kodla çizilir (çözünürlükten bağımsız oranlarla).
## tr: Osmanlı Devleti, uk: Britanya (Union Jack), au: Avustralya (mavi sancak),
## nz: Yeni Zelanda (mavi sancak), fr: Fransa.

const W := 240
const H := 160
const RED_TR := Color(0.85, 0.05, 0.1)
const UK_BLUE := Color(0.0, 0.14, 0.42)
const UK_RED := Color(0.78, 0.06, 0.18)

static var _cache := {}


static func title(nation: String) -> String:
	return {"tr": "Osmanlı Devleti", "uk": "Britanya İmparatorluğu", "au": "Avustralya", "nz": "Yeni Zelanda",
		"fr": "Fransa", "anzac": "ANZAC"}.get(nation, nation)


static func texture(nation: String) -> ImageTexture:
	var key := nation if nation != "anzac" else "au"
	if _cache.has(key):
		return _cache[key]
	var img := Image.create(W, H, false, Image.FORMAT_RGBA8)
	match key:
		"tr":
			img.fill(RED_TR)
			_crescent(img, Vector2(W * 0.42, H * 0.5), H * 0.25, Vector2(W * 0.48, H * 0.5), H * 0.2, Color.WHITE)
			_star(img, Vector2(W * 0.6, H * 0.5), H * 0.115, 5, 0.38, PI, Color.WHITE)
		"uk":
			_union_jack(img, Rect2i(0, 0, W, H))
		"au":
			img.fill(UK_BLUE)
			_union_jack(img, Rect2i(0, 0, W / 2, H / 2))
			_star(img, Vector2(W * 0.25, H * 0.75), H * 0.15, 7, 0.45, -PI / 2.0, Color.WHITE)
			for p in [Vector2(0.75, 0.82), Vector2(0.62, 0.45), Vector2(0.75, 0.2), Vector2(0.87, 0.4)]:
				_star(img, Vector2(W * p.x, H * p.y), H * 0.07, 7, 0.45, -PI / 2.0, Color.WHITE)
			_star(img, Vector2(W * 0.81, H * 0.56), H * 0.04, 5, 0.42, -PI / 2.0, Color.WHITE)
		"nz":
			img.fill(UK_BLUE)
			_union_jack(img, Rect2i(0, 0, W / 2, H / 2))
			for p in [Vector2(0.75, 0.82), Vector2(0.64, 0.45), Vector2(0.75, 0.2), Vector2(0.86, 0.38)]:
				_star(img, Vector2(W * p.x, H * p.y), H * 0.085, 5, 0.42, -PI / 2.0, Color.WHITE)
				_star(img, Vector2(W * p.x, H * p.y), H * 0.06, 5, 0.42, -PI / 2.0, UK_RED)
		"fr":
			img.fill_rect(Rect2i(0, 0, W / 3, H), Color(0.0, 0.14, 0.58))
			img.fill_rect(Rect2i(W / 3, 0, W / 3 + 1, H), Color.WHITE)
			img.fill_rect(Rect2i(W * 2 / 3, 0, W / 3 + 1, H), Color(0.94, 0.25, 0.21))
		_:
			img.fill(Color(0.8, 0.8, 0.8))
	img.generate_mipmaps()
	var t := ImageTexture.create_from_image(img)
	_cache[key] = t
	return t


## Union Jack: mavi zemin, beyaz ve kırmızı çapraz haçlar, beyaz ve kırmızı düz haç.
static func _union_jack(img: Image, r: Rect2i) -> void:
	var w := float(r.size.x)
	var h := float(r.size.y)
	var diag := Vector2(w, h).normalized()
	for y in r.size.y:
		for x in r.size.x:
			var p := Vector2(x + 0.5, y + 0.5)
			var c := UK_BLUE
			# Çapraz haçlar (Aziz Andreas ve Aziz Patrick)
			var d1 := absf(p.x * diag.y - p.y * diag.x)
			var d2 := absf((w - p.x) * diag.y - p.y * diag.x)
			var sw := h * 0.1
			if d1 < sw or d2 < sw:
				c = Color.WHITE
			# Kırmızı çaprazlar (sadeleştirilmiş)
			if d1 < sw * 0.4 or d2 < sw * 0.4:
				c = UK_RED
			# Düz haç (Aziz George), beyaz kenarlı
			var cx := absf(p.x - w * 0.5)
			var cy := absf(p.y - h * 0.5)
			if cx < h * 0.17 or cy < h * 0.17:
				c = Color.WHITE
			if cx < h * 0.1 or cy < h * 0.1:
				c = UK_RED
			img.set_pixel(r.position.x + x, r.position.y + y, c)


static func _crescent(img: Image, c1: Vector2, r1: float, c2: Vector2, r2: float, col: Color) -> void:
	for y in range(int(c1.y - r1 - 1), int(c1.y + r1 + 2)):
		for x in range(int(c1.x - r1 - 1), int(c1.x + r1 + 2)):
			var p := Vector2(x + 0.5, y + 0.5)
			if p.distance_to(c1) <= r1 and p.distance_to(c2) > r2:
				img.set_pixel(x, y, col)


## points köşeli yıldız; inner: iç yarıçap oranı.
static func _star(img: Image, c: Vector2, r: float, points: int, inner: float, rot: float, col: Color) -> void:
	var poly := PackedVector2Array()
	for i in points * 2:
		var a := rot + PI * i / points
		var rr := r if i % 2 == 0 else r * inner
		poly.append(c + Vector2(cos(a), sin(a)) * rr)
	for y in range(int(c.y - r - 1), int(c.y + r + 2)):
		for x in range(int(c.x - r - 1), int(c.x + r + 2)):
			if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
				if Geometry2D.is_point_in_polygon(Vector2(x + 0.5, y + 0.5), poly):
					img.set_pixel(x, y, col)
