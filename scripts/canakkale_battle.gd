extends Node2D
## Çanakkale 18 Mart 1915: kıyı bataryalarını ve mayınları yöneterek Müttefik filosunu durdur.
## Fare ve dokunma aynı girdiyle çalışır.

const W := 1280.0
const H := 720.0
const MENU_SCENE := "res://scenes/main_menu.tscn"
const STRAIT_TOP := 170.0
const STRAIT_BOTTOM := 550.0
const MINE_LIMIT := 26
const MINE_DAMAGE := 55.0
const MINE_RADIUS := 28.0
const BATTERY_RANGE := 360.0
const BATTERY_MAX_AMMO := 8
const SEYIT_TIME := 2.5
const SPAWN_INTERVAL := 6.0
const RETREAT_SUNK := 4
const LOSS_LEAKED := 4

enum State { BRIEFING, PREP, BATTLE, WON, LOST }


class Battery:
	var pos: Vector2
	var title: String
	var hp := 100.0
	var ammo := 8
	var reload := 0.0
	var carry := 0.0
	func alive() -> bool:
		return hp > 0.0


class Ship:
	var pos: Vector2
	var title: String
	var hp: float
	var max_hp: float
	var speed: float
	var size: float
	var fire_cd := 3.0
	var sink := -1.0
	func afloat() -> bool:
		return hp > 0.0


class Shell:
	var from: Vector2
	var to: Vector2
	var t := 0.0
	var dur := 1.0
	var by_player := true


class Boom:
	var pos: Vector2
	var t := 0.0
	var radius := 30.0


var _state: State = State.BRIEFING
var _data: Dictionary = {}
var _batteries: Array[Battery] = []
var _ships: Array[Ship] = []
var _shells: Array[Shell] = []
var _booms: Array[Boom] = []
var _mines: Array[Vector2] = []
var _queue: Array = []
var _focus: Ship = null
var _spawn_timer := 0.0
var _sunk := 0
var _leaked := 0
var _seyit_busy := false
var _rng := RandomNumberGenerator.new()
var _button := Rect2(480, 600, 320, 70)


func _ready() -> void:
	_rng.randomize()
	var f := FileAccess.open("res://data/battles/canakkale_1915.json", FileAccess.READ)
	if f:
		var parsed = JSON.parse_string(f.get_as_text())
		if parsed is Dictionary:
			_data = parsed
	_queue = _data.get("ships", []).duplicate()
	var top := [["Rumeli Mecidiye", 300.0], ["Hamidiye", 620.0], ["Anadolu Hamidiye", 940.0]]
	var bottom := [["Dardanos", 460.0], ["Kilitbahir", 780.0], ["Çimenlik", 1100.0]]
	for b in top:
		_add_battery(b[0], Vector2(b[1], 135.0))
	for b in bottom:
		_add_battery(b[0], Vector2(b[1], 590.0))


func _add_battery(title: String, pos: Vector2) -> void:
	var b := Battery.new()
	b.title = title
	b.pos = pos
	b.ammo = BATTERY_MAX_AMMO
	_batteries.append(b)


# ---------------------------------------------------------------- girdi

func _input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var p: Vector2 = make_input_local(event).position
	match _state:
		State.BRIEFING:
			if _button.has_point(p):
				_state = State.PREP
		State.PREP:
			if _button.has_point(p):
				_state = State.BATTLE
			else:
				_toggle_mine(p)
		State.BATTLE:
			_battle_tap(p)
		State.WON, State.LOST:
			if _button.has_point(p):
				get_tree().change_scene_to_file(MENU_SCENE)
	queue_redraw()


func _toggle_mine(p: Vector2) -> void:
	for i in _mines.size():
		if _mines[i].distance_to(p) < 16.0:
			_mines.remove_at(i)
			return
	if p.y > STRAIT_TOP and p.y < STRAIT_BOTTOM and p.x > 120.0 and p.x < 1180.0 and _mines.size() < MINE_LIMIT:
		_mines.append(p)


func _battle_tap(p: Vector2) -> void:
	for b in _batteries:
		if b.alive() and b.pos.distance_to(p) < 40.0:
			if not _seyit_busy and b.ammo <= BATTERY_MAX_AMMO / 2:
				_seyit_busy = true
				b.carry = SEYIT_TIME
			return
	for s in _ships:
		if s.afloat() and s.pos.distance_to(p) < 45.0 * s.size:
			_focus = s
			return
	_focus = null


# ---------------------------------------------------------------- mantık

func _process(delta: float) -> void:
	if _state == State.BATTLE:
		_update_battle(delta)
	for bm in _booms:
		bm.t += delta
	_booms.assign(_booms.filter(func(x: Boom) -> bool: return x.t < 0.8))
	queue_redraw()


func _update_battle(delta: float) -> void:
	_spawn_timer -= delta
	if _spawn_timer <= 0.0 and not _queue.is_empty():
		_spawn_timer = SPAWN_INTERVAL
		_spawn_ship(_queue.pop_front())

	for s in _ships:
		_update_ship(s, delta)
	for b in _batteries:
		_update_battery(b, delta)
	_update_shells(delta)
	_check_mines()
	_ships.assign(_ships.filter(func(s: Ship) -> bool: return s.afloat() or (s.sink >= 0.0 and s.sink < 2.0)))
	if _focus != null and not _focus.afloat():
		_focus = null
	_check_end()


func _spawn_ship(d: Dictionary) -> void:
	var s := Ship.new()
	s.title = d["title"]
	s.hp = d["hp"]
	s.max_hp = d["hp"]
	s.speed = d["speed"]
	s.size = d["size"]
	s.pos = Vector2(-60.0, _rng.randf_range(STRAIT_TOP + 50.0, STRAIT_BOTTOM - 50.0))
	s.fire_cd = _rng.randf_range(2.0, 4.0)
	_ships.append(s)


func _update_ship(s: Ship, delta: float) -> void:
	if not s.afloat():
		s.sink += delta
		return
	s.pos.x += s.speed * delta
	if s.pos.x > W + 40.0:
		s.hp = 0.0
		s.sink = 99.0
		_leaked += 1
		return
	s.fire_cd -= delta
	if s.fire_cd <= 0.0:
		var target: Battery = null
		var best := 380.0
		for b in _batteries:
			if b.alive() and b.pos.distance_to(s.pos) < best:
				best = b.pos.distance_to(s.pos)
				target = b
		if target != null:
			s.fire_cd = _rng.randf_range(3.0, 5.0)
			_fire(s.pos, target.pos, false)


func _update_battery(b: Battery, delta: float) -> void:
	if not b.alive():
		return
	if b.carry > 0.0:
		b.carry -= delta
		if b.carry <= 0.0:
			b.ammo = BATTERY_MAX_AMMO
			_seyit_busy = false
	b.reload -= delta
	if b.reload > 0.0 or b.ammo <= 0:
		return
	var target: Ship = null
	if _focus != null and _focus.afloat() and _focus.pos.distance_to(b.pos) < BATTERY_RANGE:
		target = _focus
	else:
		var best := BATTERY_RANGE
		for s in _ships:
			if s.afloat() and s.pos.distance_to(b.pos) < best:
				best = s.pos.distance_to(b.pos)
				target = s
	if target != null:
		b.ammo -= 1
		b.reload = 2.5
		var dist := b.pos.distance_to(target.pos)
		var lead := target.pos + Vector2(target.speed * dist / 520.0, 0.0)
		var scatter := lerpf(8.0, 42.0, dist / BATTERY_RANGE)
		_fire(b.pos, lead + Vector2(_rng.randf_range(-scatter, scatter), _rng.randf_range(-scatter, scatter)), true)


func _fire(from: Vector2, to: Vector2, by_player: bool) -> void:
	var sh := Shell.new()
	sh.from = from
	sh.to = to
	sh.dur = maxf(0.4, from.distance_to(to) / 520.0)
	sh.by_player = by_player
	_shells.append(sh)


func _update_shells(delta: float) -> void:
	for sh in _shells:
		sh.t += delta
		if sh.t >= sh.dur:
			_land(sh)
	_shells.assign(_shells.filter(func(x: Shell) -> bool: return x.t < x.dur))


func _land(sh: Shell) -> void:
	_boom(sh.to, 24.0)
	if sh.by_player:
		for s in _ships:
			if s.afloat() and s.pos.distance_to(sh.to) < 34.0 * s.size:
				_damage_ship(s, 16.0)
	else:
		for b in _batteries:
			if b.alive() and b.pos.distance_to(sh.to) < 32.0:
				b.hp -= 10.0
				if not b.alive() and b.carry > 0.0:
					b.carry = 0.0
					_seyit_busy = false


func _check_mines() -> void:
	for i in range(_mines.size() - 1, -1, -1):
		for s in _ships:
			if s.afloat() and s.pos.distance_to(_mines[i]) < MINE_RADIUS * s.size:
				_boom(_mines[i], 55.0)
				_damage_ship(s, MINE_DAMAGE)
				_mines.remove_at(i)
				break


func _damage_ship(s: Ship, amount: float) -> void:
	s.hp -= amount
	if s.hp <= 0.0:
		s.sink = 0.0
		_sunk += 1


func _boom(pos: Vector2, radius: float) -> void:
	var bm := Boom.new()
	bm.pos = pos
	bm.radius = radius
	_booms.append(bm)


func _check_end() -> void:
	var alive_batteries := _batteries.filter(func(b: Battery) -> bool: return b.alive())
	if alive_batteries.is_empty() or _leaked >= LOSS_LEAKED:
		_state = State.LOST
	elif _sunk >= RETREAT_SUNK:
		_state = State.WON
	elif _queue.is_empty():
		var any_afloat := false
		for s in _ships:
			if s.afloat():
				any_afloat = true
		if not any_afloat:
			_state = State.WON


# ---------------------------------------------------------------- çizim

func _draw() -> void:
	var font := ThemeDB.fallback_font
	_draw_map()
	if _state == State.BRIEFING:
		_draw_briefing(font)
		return
	for m in _mines:
		var shown := _state == State.PREP
		draw_circle(m, 9.0, Color("3d3d3d") if shown else Color(0.2, 0.2, 0.2, 0.25))
		if shown:
			draw_arc(m, 9.0, 0.0, TAU, 12, Color("e8b923"), 2.0)
	for b in _batteries:
		_draw_battery(b, font)
	for s in _ships:
		_draw_ship(s, font)
	for sh in _shells:
		var k := sh.t / sh.dur
		draw_circle(sh.from.lerp(sh.to, k) + Vector2(0, -sin(k * PI) * 40.0), 4.0, Color("ffd24a") if sh.by_player else Color("ff6a4a"))
	for bm in _booms:
		var k := bm.t / 0.8
		draw_circle(bm.pos, bm.radius * (0.4 + k), Color(1.0, 0.6, 0.1, 1.0 - k))
	_draw_hud(font)


func _draw_map() -> void:
	draw_rect(Rect2(0, 0, W, H), Color("1f5f8b"))
	draw_rect(Rect2(0, 0, W, STRAIT_TOP - 30.0), Color("6b7d4a"))
	draw_rect(Rect2(0, STRAIT_BOTTOM + 30.0, W, H - STRAIT_BOTTOM - 30.0), Color("7b8a52"))
	draw_rect(Rect2(0, STRAIT_TOP - 30.0, W, 30.0), Color("c9b98a"))
	draw_rect(Rect2(0, STRAIT_BOTTOM, W, 30.0), Color("c9b98a"))


func _draw_battery(b: Battery, font: Font) -> void:
	var col := Color("4b5563") if b.alive() else Color("2a2a2a")
	draw_rect(Rect2(b.pos - Vector2(22, 16), Vector2(44, 32)), col)
	if b.alive():
		var aim := Vector2(0, 1) if b.pos.y < H / 2.0 else Vector2(0, -1)
		draw_line(b.pos, b.pos + aim.rotated(0.9) * 30.0, Color("111111"), 6.0)
		draw_rect(Rect2(b.pos + Vector2(-22, -26), Vector2(44.0 * b.hp / 100.0, 5)), Color("2ecc71"))
		draw_string(font, b.pos + Vector2(-30, 38), "%s  %d" % [b.title, b.ammo], HORIZONTAL_ALIGNMENT_LEFT, 120, 13, Color.WHITE)
		if b.carry > 0.0:
			draw_string(font, b.pos + Vector2(-30, -34), "Seyit Onbaşı taşıyor...", HORIZONTAL_ALIGNMENT_LEFT, 160, 14, Color("e8b923"))
	if _state == State.BATTLE and _focus != null and b.alive() and b.pos.distance_to(_focus.pos) < BATTERY_RANGE:
		draw_line(b.pos, _focus.pos, Color(1, 1, 1, 0.12), 1.0)


func _draw_ship(s: Ship, font: Font) -> void:
	var k := s.size
	var sinking := not s.afloat()
	var alpha := 1.0 - clampf(s.sink / 2.0, 0.0, 1.0) if sinking else 1.0
	var pts := PackedVector2Array([
		s.pos + Vector2(-34, -10) * k, s.pos + Vector2(26, -10) * k, s.pos + Vector2(40, 0) * k,
		s.pos + Vector2(26, 10) * k, s.pos + Vector2(-34, 10) * k])
	draw_colored_polygon(pts, Color(0.62, 0.66, 0.7, alpha))
	draw_rect(Rect2(s.pos + Vector2(-8, -6) * k, Vector2(14, 12) * k), Color(0.3, 0.33, 0.36, alpha))
	if not sinking:
		draw_rect(Rect2(s.pos + Vector2(-30, -22) * k, Vector2(60.0 * s.hp / s.max_hp, 4) * k), Color("e74c3c"))
		draw_string(font, s.pos + Vector2(-34, 28) * k, s.title, HORIZONTAL_ALIGNMENT_LEFT, 140, 12, Color.WHITE)
		if s == _focus:
			draw_arc(s.pos, 48.0 * k, 0.0, TAU, 24, Color("e8b923"), 2.5)


func _draw_hud(font: Font) -> void:
	var text := "Batan gemi: %d/%d   Geçen gemi: %d/%d   Mayın: %d" % [_sunk, RETREAT_SUNK, _leaked, LOSS_LEAKED, _mines.size()]
	if _state == State.PREP:
		text = "Mayınları yerleştir (%d/%d). Tekrar dokun: kaldır." % [_mines.size(), MINE_LIMIT]
	draw_string(font, Vector2(0, 28), "Nusret'in 26 mayını · " + text, HORIZONTAL_ALIGNMENT_CENTER, W, 20, Color.WHITE)
	if _state == State.BATTLE:
		draw_string(font, Vector2(0, 700), "Gemiye dokun: ateşi yoğunlaştır · Cephanesi azalan bataryaya dokun: Seyit Onbaşı mermi taşısın", HORIZONTAL_ALIGNMENT_CENTER, W, 16, Color("e0e8ef"))
	if _state == State.PREP:
		_draw_button(font, "Savaşı Başlat")
	elif _state == State.WON or _state == State.LOST:
		draw_rect(Rect2(0, 220, W, 300), Color(0, 0, 0, 0.72))
		var head := "BOĞAZ GEÇİLEMEZ!" if _state == State.WON else "Savunma çöktü"
		var body := "Müttefik donanması geri çekildi. Tarihte de 18 Mart 1915'te Bouvet, Irresistible ve Ocean battı." if _state == State.WON else "Gemiler Boğaz'ı geçti ya da bataryalar sustu. Tarihte Boğaz geçilemedi; tekrar dene."
		draw_string(font, Vector2(0, 330), head, HORIZONTAL_ALIGNMENT_CENTER, W, 56, Color("e8b923"))
		draw_string(font, Vector2(0, 400), body, HORIZONTAL_ALIGNMENT_CENTER, W, 22, Color.WHITE)
		_draw_button(font, "Menüye Dön")


func _draw_briefing(font: Font) -> void:
	draw_rect(Rect2(0, 0, W, H), Color(0, 0, 0, 0.8))
	draw_string(font, Vector2(0, 110), "18 Mart 1915 · Çanakkale Boğazı", HORIZONTAL_ALIGNMENT_CENTER, W, 44, Color("e8b923"))
	draw_multiline_string(font, Vector2(200, 170), String(_data.get("summary", "")), HORIZONTAL_ALIGNMENT_CENTER, 880, 22, 8, Color.WHITE)
	var steps := "1) Hazırlık: Nusret'in mayınlarını boğaza yerleştir.\n2) Savaş: Gemilere dokunarak bataryaları yönlendir.\n3) Cephane azalınca Seyit Onbaşı'yı bataryaya gönder.\n4) 4 gemiyi batır, 4 geminin geçmesine izin verme."
	draw_multiline_string(font, Vector2(260, 360), steps, HORIZONTAL_ALIGNMENT_LEFT, 780, 22, 8, Color("c9d3dd"))
	_draw_button(font, "Hazırlığa Başla")


func _draw_button(font: Font, label: String) -> void:
	draw_rect(_button, Color("c8102e"))
	draw_string(font, _button.position + Vector2(0, 46), label, HORIZONTAL_ALIGNMENT_CENTER, _button.size.x, 30, Color.WHITE)
