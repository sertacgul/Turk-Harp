class_name TouchButton
extends Button
## Dokunmatik ekranda her parmağı ayrı ayrı tanıyan düğme.
## Godot yalnızca ilk parmağı fare tıklamasına çevirir; sanal kolu tutarken ikinci parmakla
## basılan sıradan bir Button tepki vermez. Bu düğme dokunuşu doğrudan işler ve basıldığı
## anda tetiklenir; dokunuştan üretilen sahte fare olaylarını yutar ki iki kez tetiklenmesin.

var _touches := 0


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		accept_event()
		if disabled:
			return
		if event.pressed:
			_touches += 1
			if _touches == 1:
				add_theme_stylebox_override("normal", get_theme_stylebox("pressed"))
			pressed.emit()
		else:
			_touches = maxi(_touches - 1, 0)
			if _touches == 0:
				remove_theme_stylebox_override("normal")
	elif event is InputEventMouse and event.device == InputEvent.DEVICE_ID_EMULATION:
		accept_event()
