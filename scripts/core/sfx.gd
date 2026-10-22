extends Node
## Ses efektleri çalışma anında sentezlenir; harici ses dosyası gerekmez.
## Konumlu sesler mesafeye göre kısılır ve ses hızına göre gecikir.

const RATE := 22050
const POOL_SIZE := 14
const SPEED_OF_SOUND := 343.0

var _streams := {}
var _pool: Array[AudioStreamPlayer] = []
var _loops := {}
var _rng := RandomNumberGenerator.new()
var listener: Node3D


func _ready() -> void:
	_rng.seed = 18
	_streams["cannon"] = _make(1.6, 0.16, 6.0, 55.0, 9.0, 0.9)
	_streams["boom"] = _make(2.6, 0.06, 2.0, 38.0, 4.0, 1.0)
	_streams["far_boom"] = _make(2.2, 0.025, 2.2, 32.0, 3.0, 0.7)
	_streams["splash"] = _make(1.6, 0.55, 3.0, 0.0, 0.0, 0.7, 0.04)
	_streams["click"] = _tone(0.06, 1300.0, 40.0)
	_streams["alarm"] = _sweep(1.2, 500.0, 1100.0)
	_streams["sea"] = _make(6.0, 0.03, 0.0, 0.0, 0.0, 0.5, 0.0, true)
	_streams["engine"] = _engine(2.0)
	_streams["mine_drop"] = _make(0.9, 0.35, 5.0, 90.0, 10.0, 0.6, 0.02)
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool.append(p)


func _write(data: PackedFloat32Array, loop := false) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(data.size() * 2)
	for i in data.size():
		bytes.encode_s16(i * 2, int(clampf(data[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.data = bytes
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_end = data.size()
	return w


## Gürültü + alçak geçiren filtre + düşük frekanslı gümbürtü.
func _make(dur: float, lp: float, decay: float, thump_hz: float, thump_decay: float, gain: float, attack := 0.004, loop := false) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var y := 0.0
	var y2 := 0.0
	for i in n:
		var t := float(i) / RATE
		y += lp * (_rng.randf_range(-1.0, 1.0) - y)
		y2 += lp * (y - y2)
		var env := minf(t / attack, 1.0) * exp(-t * decay) if not loop else 0.6 + 0.4 * sin(TAU * t / dur * 2.0)
		var thump := 0.0
		if thump_hz > 0.0:
			thump = sin(TAU * thump_hz * t * (1.0 - t * 0.3)) * exp(-t * thump_decay)
		out[i] = (y2 * 6.0 * env + thump * 0.8) * gain
	return _write(out, loop)


func _tone(dur: float, hz: float, decay: float) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	for i in n:
		var t := float(i) / RATE
		out[i] = sin(TAU * hz * t) * exp(-t * decay) * 0.5
	return _write(out)


func _sweep(dur: float, a: float, b: float) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	for i in n:
		var t := float(i) / RATE
		phase += TAU * lerpf(a, b, absf(sin(t * PI * 2.0))) / RATE
		out[i] = sign(sin(phase)) * 0.25 * minf(1.0, (dur - t) * 8.0)
	return _write(out)


func _engine(dur: float) -> AudioStreamWAV:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var y := 0.0
	for i in n:
		var t := float(i) / RATE
		y += 0.05 * (_rng.randf_range(-1.0, 1.0) - y)
		var pulse := pow(0.5 + 0.5 * sin(TAU * 6.0 * t), 3.0)
		out[i] = (y * 4.0 * pulse + sin(TAU * 42.0 * t) * 0.15 * pulse) * 0.6
	return _write(out, true)


func _volume_db(base_db: float) -> float:
	return base_db + linear_to_db(maxf(GameState.settings.get("sfx", 0.8), 0.001))


func play(name: String, volume_db := 0.0, pitch := 1.0) -> void:
	if not _streams.has(name):
		return
	for p in _pool:
		if not p.playing:
			p.stream = _streams[name]
			p.volume_db = _volume_db(volume_db)
			p.pitch_scale = pitch * _rng.randf_range(0.93, 1.07)
			p.play()
			return


## Dinleyiciye uzaklığa göre kısılmış ve gecikmeli ses.
func play_at(name: String, pos: Vector3, volume_db := 0.0) -> void:
	if listener == null or not is_instance_valid(listener) or not listener.is_inside_tree():
		play(name, volume_db)
		return
	var dist := listener.global_position.distance_to(pos)
	var vol := volume_db - dist / 45.0
	if vol < -40.0:
		return
	var actual := name
	if name == "boom" and dist > 600.0:
		actual = "far_boom"
	var delay := dist / SPEED_OF_SOUND
	if delay < 0.05:
		play(actual, vol)
	else:
		get_tree().create_timer(delay).timeout.connect(play.bind(actual, vol, 1.0))


func start_loop(name: String, volume_db := -10.0) -> void:
	if _loops.has(name) or not _streams.has(name):
		return
	var p := AudioStreamPlayer.new()
	p.stream = _streams[name]
	p.volume_db = _volume_db(volume_db)
	add_child(p)
	p.play()
	_loops[name] = p


func set_loop_volume(name: String, volume_db: float) -> void:
	if _loops.has(name):
		_loops[name].volume_db = _volume_db(volume_db)


func stop_all_loops() -> void:
	for k in _loops:
		_loops[k].queue_free()
	_loops.clear()
