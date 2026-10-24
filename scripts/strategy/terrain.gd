class_name Terrain
extends RefCounted
## Arazi türleri. Gerçek yükseklik verisinden sırt, dere yatağı, sarp yamaç ve kumsal çıkarılır;
## maki örtüsü yarımadanın genel bitki örtüsünü yansıtan sabit bir desenle, köy ve yollar senaryodan gelir.
## move: hareket maliyeti, defense: savunma çarpanı, conceal: birlikleri gizler mi.

const TABLE := {
	"açık": {"move": 1.0, "defense": 1.0, "conceal": false, "note": "Açık arazi: hızlı geçilir, savunana koruma vermez."},
	"maki": {"move": 1.4, "defense": 1.2, "conceal": true, "note": "Sık maki ve çalılık: ağır ilerlenir, birlikleri gizler."},
	"sırt": {"move": 1.2, "defense": 1.3, "conceal": false, "note": "Sırt: geniş görüş, savunana üstünlük."},
	"dere": {"move": 1.3, "defense": 1.15, "conceal": true, "note": "Dere yatağı: gizli yaklaşma yolu, ama yukarıdan görülür."},
	"sarp": {"move": 2.0, "defense": 1.45, "conceal": false, "note": "Sarp yamaç: tırmanması zor, savunması kolay."},
	"kumsal": {"move": 1.2, "defense": 0.8, "conceal": false, "note": "Kumsal: siper kazmak güç, açıkta kalınır."},
	"köy": {"move": 1.0, "defense": 1.35, "conceal": true, "note": "Köy: taş evler ve duvarlar korur."},
	"deniz": {"move": 1.0, "defense": 1.0, "conceal": false, "note": "Deniz."},
}


static func info(t: String) -> Dictionary:
	return TABLE.get(t, TABLE["açık"])


## Bütün hücrelerin arazi türünü belirler.
static func classify(grid: HexGrid, hex_m: float) -> void:
	for k: Vector2i in grid.cells:
		var c := grid.cell(k)
		if c.is_sea():
			c.terrain = "deniz"
			continue
		var sum := 0.0
		var n := 0
		var coast := false
		for nb in grid.neighbors(k):
			var o := grid.cell(nb)
			if o.is_sea():
				coast = true
			sum += maxf(o.elev, 0.0)
			n += 1
		var avg := sum / maxf(n, 1)
		var rel := c.elev - avg
		if coast and c.low < 4.0 and c.elev < 15.0:
			c.terrain = "kumsal"
		elif c.rough > hex_m * 0.3:
			c.terrain = "sarp"
		elif rel > hex_m * 0.045 and c.elev > 40.0:
			c.terrain = "sırt"
		elif rel < -hex_m * 0.045:
			c.terrain = "dere"
		elif _veg(c.center) > 0.42:
			c.terrain = "maki"
		else:
			c.terrain = "açık"


## Sabit (rastgele olmayan) bitki örtüsü deseni.
static func _veg(p: Vector2) -> float:
	var v := sin(p.x * 0.0021 + 1.3) * cos(p.y * 0.0017 - 0.4) * 0.5 + sin((p.x + p.y) * 0.0009) * 0.3
	return v * 0.5 + 0.5


## Senaryodaki yolu (enlem/boylam noktaları) geçtiği hücrelere işler.
static func mark_road(grid: HexGrid, geo: GeoMap, pts: Array) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for i in pts.size() - 1:
		var a := geo.local(pts[i][0], pts[i][1])
		var b := geo.local(pts[i + 1][0], pts[i + 1][1])
		var steps := int(a.distance_to(b) / (grid.radius * 0.4)) + 1
		for j in steps + 1:
			var c := grid.at(a.lerp(b, float(j) / steps))
			if grid.has(c) and grid.cell(c).is_land():
				grid.cell(c).road = true
				if cells.is_empty() or cells[-1] != c:
					cells.append(c)
	return cells
