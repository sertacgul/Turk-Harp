extends Node
## Geliştirme aracı: bir sahneyi yükler, zamanlanmış komutları çalıştırır ve ekran görüntüsü alır.
## Kullanım: godot --path . res://tools/shot.tscn -- scene=res://... cmds=1:start_mission,5:shot,8:quit out=/tmp/x
## Komutlar: shot (PNG kaydet), quit, press_<TUŞ>/release_<TUŞ>, ya da sahne kökünde çağrılacak bir metot adı.
## "speed=4" ile oyun hızlandırılabilir.

var _target: Node
var _cmds: Array = []
var _t := 0.0
var _out := "user://shot"
var _n := 0


func _ready() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		if kv.size() == 2:
			args[kv[0]] = kv[1]
	_out = args.get("out", _out)
	Engine.time_scale = float(args.get("speed", "1"))
	for c in String(args.get("cmds", "3:shot,4:quit")).split(","):
		var p := c.split(":")
		_cmds.append([float(p[0]), p[1]])
	_target = load(args.get("scene", "res://scenes/main_menu.tscn")).instantiate()
	add_child(_target)


func _process(delta: float) -> void:
	_t += delta / maxf(Engine.time_scale, 0.001)
	while not _cmds.is_empty() and _t >= _cmds[0][0]:
		var cmd: String = _cmds.pop_front()[1]
		match cmd:
			"shot":
				var path := "%s_%02d.png" % [_out, _n]
				_n += 1
				get_viewport().get_texture().get_image().save_png(path)
				print("SHOT ", path)
			"quit":
				get_tree().quit()
			_ when cmd.begins_with("press_") or cmd.begins_with("release_"):
				# ör. press_UP, release_W: klavye olayı gönderir
				var ev := InputEventKey.new()
				var name := cmd.split("_", true, 1)[1]
				ev.keycode = OS.find_keycode_from_string(name)
				ev.physical_keycode = ev.keycode
				ev.pressed = cmd.begins_with("press_")
				Input.parse_input_event(ev)
			_:
				if _target.has_method(cmd):
					_target.call(cmd)
				else:
					print("unknown cmd ", cmd)
