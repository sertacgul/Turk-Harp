class_name StarRow
extends Control
## Görev yıldızlarını çizer (yazı tipine bağımlı değildir).

var filled := 0
var total := 3
var star_size := 26.0


func _init(f := 0, s := 26.0) -> void:
	filled = f
	star_size = s
	custom_minimum_size = Vector2(total * (s + 6.0), s)


func _draw() -> void:
	for i in total:
		var c := Vector2(i * (star_size + 6.0) + star_size * 0.5, star_size * 0.5)
		var pts := PackedVector2Array()
		for k in 10:
			var a := -PI / 2.0 + k * PI / 5.0
			var r := star_size * 0.5 if k % 2 == 0 else star_size * 0.21
			pts.append(c + Vector2(cos(a), sin(a)) * r)
		var col := UiTheme.GOLD if i < filled else Color(0.25, 0.25, 0.27)
		draw_colored_polygon(pts, col)
