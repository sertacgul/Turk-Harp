class_name MapCamera
extends Node3D
## Harekât masası kamerası. Fare: sol sürükle kaydır, sağ sürükle döndür, tekerlek yakınlaş.
## Trackpad: iki parmak kaydır, kıstır yakınlaş. Dokunmatik: tek parmak kaydır, iki parmak yakınlaş/döndür.
## Klavye: WASD/oklar kaydır, Q/E döndür, +/- yakınlaş. Sürüklemeden yapılan tıklamada clicked yayılır.

signal clicked(screen_pos: Vector2)
signal hovered(screen_pos: Vector2)

var cam := Camera3D.new()
var target := Vector3.ZERO
var dist := 80.0
var yaw := 0.0
var pitch := deg_to_rad(52.0)
var min_dist := 8.0
var max_dist := 160.0
var bounds := Vector2(60, 60)
var _drag_btn := 0
var _press_pos := Vector2.ZERO
var _dragged := false
var _touches := {}
var _pinch_d := 0.0
var _pinch_a := 0.0
## Yumuşak hedef değerler
var _t_target := Vector3.ZERO
var _t_dist := 80.0
var _t_yaw := 0.0


func _ready() -> void:
	cam.fov = 40.0
	cam.near = 0.1
	cam.far = 2000.0
	add_child(cam)
	cam.current = true
	_t_target = target
	_t_dist = dist
	_t_yaw = yaw


func setup(map_size: Vector2) -> void:
	bounds = map_size * 0.5
	max_dist = maxf(map_size.x, map_size.y) * 1.25
	min_dist = maxf(map_size.x, map_size.y) * 0.06
	dist = max_dist * 0.7
	_t_dist = dist


func focus(p: Vector3, d := -1.0) -> void:
	_t_target = Vector3(p.x, 0, p.z)
	if d > 0.0:
		_t_dist = clampf(d, min_dist, max_dist)


func _process(delta: float) -> void:
	var k := 1.0 - exp(-delta * 10.0)
	var move := Vector2.ZERO
	if not _text_focus():
		if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
			move.y -= 1
		if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
			move.y += 1
		if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
			move.x -= 1
		if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
			move.x += 1
		if Input.is_key_pressed(KEY_Q):
			_t_yaw += delta * 1.4
		if Input.is_key_pressed(KEY_E):
			_t_yaw -= delta * 1.4
	if move != Vector2.ZERO:
		_pan_world(move.normalized() * _t_dist * 0.9 * delta)
	target = target.lerp(_t_target, k)
	dist = lerpf(dist, _t_dist, k)
	yaw = lerp_angle(yaw, _t_yaw, k)
	# Yakınlaştıkça kamera daha yatay bakar (masaya eğilen kurmay gibi)
	var zoom_t := inverse_lerp(min_dist, max_dist, dist)
	pitch = deg_to_rad(lerpf(38.0, 62.0, zoom_t))
	var off := Vector3(0, sin(pitch), cos(pitch)).rotated(Vector3.UP, yaw) * dist
	cam.global_position = target + off
	cam.look_at(target, Vector3.UP)


func _text_focus() -> bool:
	var f := get_viewport().gui_get_focus_owner()
	return f is LineEdit or f is TextEdit


func _pan_world(d: Vector2) -> void:
	var right := Vector3(cos(yaw), 0, -sin(yaw))
	var fwd := Vector3(sin(yaw), 0, cos(yaw))
	_t_target += right * d.x + fwd * d.y
	_t_target.x = clampf(_t_target.x, -bounds.x, bounds.x)
	_t_target.z = clampf(_t_target.z, -bounds.y, bounds.y)


func _pan_screen(rel: Vector2) -> void:
	var px := 2.0 * dist * tan(deg_to_rad(cam.fov) * 0.5) / get_viewport().get_visible_rect().size.y
	_pan_world(-rel * px * 1.1)


func zoom(f: float) -> void:
	_t_dist = clampf(_t_dist * f, min_dist, max_dist)


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventScreenTouch:
		var t := e as InputEventScreenTouch
		if t.pressed:
			_touches[t.index] = t.position
		else:
			_touches.erase(t.index)
		_pinch_d = 0.0
		return
	if e is InputEventScreenDrag:
		var d := e as InputEventScreenDrag
		_touches[d.index] = d.position
		if _touches.size() >= 2:
			var ps: Array = _touches.values()
			var a: Vector2 = ps[0]
			var b: Vector2 = ps[1]
			var nd := a.distance_to(b)
			var na := (b - a).angle()
			if _pinch_d > 0.0:
				zoom(_pinch_d / maxf(nd, 1.0))
				_t_yaw += angle_difference(_pinch_a, na)
			_pinch_d = nd
			_pinch_a = na
			_dragged = true
		return
	if e is InputEventMagnifyGesture:
		zoom(1.0 / (e as InputEventMagnifyGesture).factor)
		return
	if e is InputEventPanGesture:
		_pan_screen(-(e as InputEventPanGesture).delta * 12.0)
		return
	if e is InputEventMouseButton:
		var mb := e as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			zoom(0.88)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			zoom(1.0 / 0.88)
		elif mb.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
			if mb.pressed:
				_drag_btn = mb.button_index
				_press_pos = mb.position
				_dragged = false
			elif mb.button_index == _drag_btn:
				if not _dragged and mb.button_index == MOUSE_BUTTON_LEFT and _touches.size() < 2:
					clicked.emit(mb.position)
				_drag_btn = 0
		return
	if e is InputEventMouseMotion:
		var mm := e as InputEventMouseMotion
		if _drag_btn != 0 and _touches.size() < 2:
			if mm.position.distance_to(_press_pos) > 8.0:
				_dragged = true
			if _dragged:
				if _drag_btn == MOUSE_BUTTON_RIGHT:
					_t_yaw -= mm.relative.x * 0.006
				else:
					_pan_screen(mm.relative)
		elif _drag_btn == 0:
			hovered.emit(mm.position)
		return
	if e is InputEventKey and e.pressed:
		var k := (e as InputEventKey).keycode
		if k == KEY_EQUAL or k == KEY_PLUS or k == KEY_KP_ADD:
			zoom(0.8)
		elif k == KEY_MINUS or k == KEY_KP_SUBTRACT:
			zoom(1.25)


func ray(screen_pos: Vector2) -> Array:
	return [cam.project_ray_origin(screen_pos), cam.project_ray_normal(screen_pos)]
