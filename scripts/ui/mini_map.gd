class_name MiniMap
extends Control
## Boğazın üstten görünüşü: kıyılar, oyuncu, hedef bölge ve düşman ışıldakları.

var x_range := Vector2(-1500.0, 700.0)
var z_range := Vector2(-600.0, 600.0)
var player_pos := Vector3.ZERO
var player_heading := 0.0
var zone_center := Vector3.ZERO
var zone_radius := 0.0
var dock_center := Vector3.ZERO
var enemies: Array = []  # [{pos, dir}]
var mines: Array[Vector3] = []


func _ready() -> void:
	custom_minimum_size = Vector2(330, 180)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func to_map(p: Vector3) -> Vector2:
	return Vector2(
		inverse_lerp(x_range.x, x_range.y, p.x) * size.x,
		inverse_lerp(z_range.x, z_range.y, p.z) * size.y)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.36, 0.33, 0.24, 0.85))
	var water := PackedVector2Array()
	var steps := 40
	for i in steps + 1:
		var x := lerpf(x_range.x, x_range.y, float(i) / steps)
		water.append(to_map(Vector3(x, 0, -StraitWorld.north_half_width(x))))
	for i in range(steps, -1, -1):
		var x := lerpf(x_range.x, x_range.y, float(i) / steps)
		water.append(to_map(Vector3(x, 0, StraitWorld.south_half_width(x))))
	draw_colored_polygon(water, Color(0.08, 0.2, 0.3, 0.95))
	var scale := size.x / (x_range.y - x_range.x)
	if zone_radius > 0.0:
		draw_arc(to_map(zone_center), zone_radius * scale, 0.0, TAU, 32, UiTheme.GOLD, 2.0)
	draw_arc(to_map(dock_center), 50.0 * scale, 0.0, TAU, 24, Color(0.4, 0.9, 0.5), 2.0)
	for m in mines:
		draw_circle(to_map(m), 2.0, Color(1, 0.3, 0.25))
	for e in enemies:
		var p := to_map(e["pos"])
		var d: Vector3 = e["dir"]
		draw_line(p, p + Vector2(d.x, d.z).normalized() * 40.0, Color(1, 1, 0.8, 0.5), 3.0)
		draw_circle(p, 4.0, Color(0.9, 0.3, 0.3))
	var pp := to_map(player_pos)
	var fwd := Vector2(cos(player_heading), -sin(player_heading))
	draw_colored_polygon(PackedVector2Array([pp + fwd * 9.0, pp + fwd.rotated(2.5) * 6.0, pp + fwd.rotated(-2.5) * 6.0]), Color.WHITE)
	draw_rect(Rect2(Vector2.ZERO, size), UiTheme.GOLD.darkened(0.3), false, 2.0)
