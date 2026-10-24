class_name HexGrid
extends RefCounted
## Sivri tepeli altıgen ızgara. Hücreler ofset (sütun, satır; tek satırlar yarım hücre sağda)
## koordinatıyla Vector2i olarak tutulur. Konumlar bölgenin yerel metre koordinatlarındadır.

const SQ3 := 1.7320508

## Merkezden köşeye yarıçap (metre)
var radius := 100.0
var origin := Vector2.ZERO
var cols := 0
var rows := 0
var cells := {}


class Cell:
	var coord := Vector2i.ZERO
	var center := Vector2.ZERO
	## Ortalama, en yüksek ve en alçak yükseklik (metre)
	var elev := 0.0
	var top := 0.0
	var low := 0.0
	## Karada kalan örneklerin oranı (0 deniz, 1 tamamen kara)
	var land := 1.0
	var sea_depth := 0.0
	## Engebe: örnekler arasındaki yükseklik farkı (metre)
	var rough := 0.0
	var place := ""
	## Hedef puanı (0: hedef değil) ve kontrol eden taraf
	var vp := 0
	var owner := ""
	var mines := 0
	var mines_known := false
	## Arazi türü (Terrain.TABLE anahtarı) ve yol
	var terrain := "açık"
	var road := false

	func is_sea() -> bool:
		return land < 0.35

	func is_land() -> bool:
		return land >= 0.35


## center_dist: komşu hücre merkezleri arası uzaklık (metre).
func setup(geo: GeoMap, center_dist: float) -> void:
	radius = center_dist / SQ3
	origin = Vector2(SQ3 * radius * 0.5, radius)
	cols = int(geo.width_m / (SQ3 * radius))
	rows = int((geo.height_m - radius) / (1.5 * radius)) + 1
	for row in rows:
		for col in cols:
			var c := Cell.new()
			c.coord = Vector2i(col, row)
			c.center = center(c.coord)
			_sample(geo, c)
			cells[c.coord] = c


func _sample(geo: GeoMap, c: Cell) -> void:
	var sum := 0.0
	var n := 0
	var land := 0
	c.top = -9999.0
	c.low = 9999.0
	for i in 19:
		var off := Vector2.ZERO
		if i > 0 and i <= 6:
			off = Vector2.from_angle(TAU * i / 6.0 + PI / 6.0) * radius * 0.45
		elif i > 6:
			off = Vector2.from_angle(TAU * (i - 7) / 12.0) * radius * 0.82
		var e := geo.height_local(c.center + off)
		sum += e
		n += 1
		c.top = maxf(c.top, e)
		c.low = minf(c.low, e)
		if e > 0.5:
			land += 1
	c.elev = sum / n
	c.land = float(land) / n
	c.rough = c.top - c.low
	c.sea_depth = maxf(0.0, -c.elev)


func center(o: Vector2i) -> Vector2:
	return origin + Vector2(SQ3 * radius * (o.x + 0.5 * (o.y & 1)), 1.5 * radius * o.y)


func has(o: Vector2i) -> bool:
	return cells.has(o)


func cell(o: Vector2i) -> Cell:
	return cells.get(o)


static func to_axial(o: Vector2i) -> Vector2i:
	return Vector2i(o.x - (o.y - (o.y & 1)) / 2, o.y)


static func from_axial(a: Vector2i) -> Vector2i:
	return Vector2i(a.x + (a.y - (a.y & 1)) / 2, a.y)


const DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1)]


func neighbors(o: Vector2i) -> Array[Vector2i]:
	var a := to_axial(o)
	var out: Array[Vector2i] = []
	for d in DIRS:
		var n := from_axial(a + d)
		if cells.has(n):
			out.append(n)
	return out


static func distance(a: Vector2i, b: Vector2i) -> int:
	var p := to_axial(a)
	var q := to_axial(b)
	var dq := p.x - q.x
	var dr := p.y - q.y
	return (absi(dq) + absi(dr) + absi(dq + dr)) / 2


## Yerel noktanın bulunduğu hücre (ızgara dışındaysa da hesaplanır; has() ile denetleyin).
func at(p: Vector2) -> Vector2i:
	var l := p - origin
	var q := (SQ3 / 3.0 * l.x - l.y / 3.0) / radius
	var r := (2.0 / 3.0 * l.y) / radius
	var s := -q - r
	var rq := roundf(q)
	var rr := roundf(r)
	var rs := roundf(s)
	var dq := absf(rq - q)
	var dr := absf(rr - r)
	var ds := absf(rs - s)
	if dq > dr and dq > ds:
		rq = -rr - rs
	elif dr > ds:
		rr = -rq - rs
	return from_axial(Vector2i(int(rq), int(rr)))


func within(o: Vector2i, n: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var a := to_axial(o)
	for dq in range(-n, n + 1):
		for dr in range(maxi(-n, -dq - n), mini(n, -dq + n) + 1):
			var c := from_axial(a + Vector2i(dq, dr))
			if cells.has(c):
				out.append(c)
	return out


## Ofset koordinatı -> Vector2(sütun, satır) yerine dünya adı için yer etiketi aranırken kullanılır.
func nearest(p: Vector2) -> Vector2i:
	var c := at(p)
	if cells.has(c):
		return c
	var best := Vector2i(-1, -1)
	var bd := INF
	for k: Vector2i in cells:
		var d := (cells[k] as Cell).center.distance_squared_to(p)
		if d < bd:
			bd = d
			best = k
	return best
