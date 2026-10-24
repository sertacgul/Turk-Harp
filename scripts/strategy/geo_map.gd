class_name GeoMap
extends RefCounted
## Gerçek yükseklik verisi (assets/maps/<ad>_height.png, Terrarium kodlu) ve coğrafi dönüşümler.
## Senaryo bölgesi (enlem/boylam kutusu) yerel metre koordinatlarına çevrilir:
## x doğuya, y güneye doğru artar; (0, 0) bölgenin kuzeybatı köşesidir.

var meta: Dictionary
var heights := PackedFloat32Array()
var w := 0
var h := 0
## Senaryo bölgesi
var lat0 := 0.0
var lon0 := 0.0
var lat1 := 0.0
var lon1 := 0.0
var m_per_lon := 1.0
var m_per_lat := 110540.0
var width_m := 1.0
var height_m := 1.0

static var _cache := {}


static func open(map_name: String) -> GeoMap:
	var g := GeoMap.new()
	var f := FileAccess.open("res://data/maps/%s.json" % map_name, FileAccess.READ)
	g.meta = JSON.parse_string(f.get_as_text())
	if _cache.has(map_name):
		var c: Array = _cache[map_name]
		g.heights = c[0]
		g.w = c[1]
		g.h = c[2]
	else:
		var img := (load("res://assets/maps/%s_height.png" % map_name) as Texture2D).get_image()
		if img.is_compressed():
			img.decompress()
		img.convert(Image.FORMAT_RGB8)
		g.w = img.get_width()
		g.h = img.get_height()
		var data := img.get_data()
		g.heights.resize(g.w * g.h)
		for i in g.w * g.h:
			g.heights[i] = data[i * 3] * 256.0 + data[i * 3 + 1] + data[i * 3 + 2] / 256.0 - 32768.0
		_cache[map_name] = [g.heights, g.w, g.h]
	g.set_region(g.meta["lat0"], g.meta["lon0"], g.meta["lat1"], g.meta["lon1"])
	return g


func set_region(a_lat0: float, a_lon0: float, a_lat1: float, a_lon1: float) -> void:
	lat0 = a_lat0
	lon0 = a_lon0
	lat1 = a_lat1
	lon1 = a_lon1
	m_per_lon = 111320.0 * cos(deg_to_rad((lat0 + lat1) * 0.5))
	width_m = (lon1 - lon0) * m_per_lon
	height_m = (lat1 - lat0) * m_per_lat


## Enlem/boylam -> yerel metre (x doğu, y güney).
func local(lat: float, lon: float) -> Vector2:
	return Vector2((lon - lon0) * m_per_lon, (lat1 - lat) * m_per_lat)


func latlon(p: Vector2) -> Vector2:
	return Vector2(lat1 - p.y / m_per_lat, lon0 + p.x / m_per_lon)


## Yerel noktadaki yükseklik (metre), çift doğrusal örnekleme.
func height_local(p: Vector2) -> float:
	var ll := latlon(p)
	return height_ll(ll.x, ll.y)


func height_ll(lat: float, lon: float) -> float:
	var fx := (lon - float(meta["lon0"])) / (float(meta["lon1"]) - float(meta["lon0"])) * w - 0.5
	var fy := (float(meta["lat1"]) - lat) / (float(meta["lat1"]) - float(meta["lat0"])) * h - 0.5
	fx = clampf(fx, 0.0, w - 1.001)
	fy = clampf(fy, 0.0, h - 1.001)
	var ix := int(fx)
	var iy := int(fy)
	var tx := fx - ix
	var ty := fy - iy
	var i := iy * w + ix
	var a := lerpf(heights[i], heights[i + 1], tx)
	var b := lerpf(heights[i + w], heights[i + w + 1], tx)
	return lerpf(a, b, ty)


## Bölgenin yükseklik görüntüsü (FORMAT_RF, metre); kabartma haritanın gölgelendiricisinde kullanılır.
func region_image(res_x: int, res_y: int) -> Image:
	var img := Image.create(res_x, res_y, false, Image.FORMAT_RF)
	for j in res_y:
		for i in res_x:
			var p := Vector2((i + 0.5) / res_x * width_m, (j + 0.5) / res_y * height_m)
			img.set_pixel(i, j, Color(height_local(p), 0, 0))
	return img
