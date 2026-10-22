class_name VirtualJoystick
extends Control
## Dokunmatik ekranlar için sanal kol. output: -1..1 aralığında vektör.

var output := Vector2.ZERO
var _touch := -1
var _center := Vector2.ZERO
var radius := 80.0


func _ready() -> void:
	custom_minimum_size = Vector2(radius * 2.6, radius * 2.6)
	mouse_filter = Control.MOUSE_FILTER_STOP


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and _touch < 0:
			_touch = event.index
			_update(event.position)
		elif not event.pressed and event.index == _touch:
			_touch = -1
			output = Vector2.ZERO
		accept_event()
	elif event is InputEventScreenDrag and event.index == _touch:
		_update(event.position)
		accept_event()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not DisplayServer.is_touchscreen_available():
		if event.pressed:
			_touch = 0
			_update(event.position)
		else:
			_touch = -1
			output = Vector2.ZERO
	elif event is InputEventMouseMotion and _touch == 0 and not DisplayServer.is_touchscreen_available():
		_update(event.position)
	queue_redraw()


func _update(p: Vector2) -> void:
	_center = size * 0.5
	output = ((p - _center) / radius).limit_length(1.0)


func _draw() -> void:
	var c := size * 0.5
	draw_circle(c, radius, Color(0, 0, 0, 0.3))
	draw_arc(c, radius, 0.0, TAU, 48, Color(1, 1, 1, 0.35), 2.0)
	draw_circle(c + output * radius, radius * 0.38, Color(UiTheme.GOLD, 0.75))
