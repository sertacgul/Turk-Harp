class_name UiTheme
extends RefCounted
## Oyunun ortak arayüz teması: koyu paneller, altın çerçeve, al düğmeler.

const GOLD := Color(0.9, 0.72, 0.28)
const RED := Color(0.62, 0.07, 0.11)
const PANEL := Color(0.05, 0.07, 0.1, 0.86)
const TEXT := Color(0.94, 0.92, 0.87)
const MUTED := Color(0.68, 0.7, 0.72)

static var _theme: Theme


static func _box(bg: Color, border: Color, width := 2, radius := 6) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(width)
	s.set_corner_radius_all(radius)
	s.content_margin_left = 18
	s.content_margin_right = 18
	s.content_margin_top = 10
	s.content_margin_bottom = 10
	s.shadow_color = Color(0, 0, 0, 0.35)
	s.shadow_size = 6
	return s


static func get_theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font_size = 20
	t.set_stylebox("panel", "PanelContainer", _box(PANEL, GOLD.darkened(0.35), 2, 10))
	t.set_stylebox("panel", "Panel", _box(PANEL, GOLD.darkened(0.35), 2, 10))
	t.set_stylebox("normal", "Button", _box(RED, GOLD.darkened(0.2)))
	t.set_stylebox("hover", "Button", _box(RED.lightened(0.15), GOLD))
	t.set_stylebox("pressed", "Button", _box(RED.darkened(0.25), GOLD))
	t.set_stylebox("disabled", "Button", _box(Color(0.2, 0.2, 0.22, 0.9), Color(0.35, 0.35, 0.35)))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", Color(0.55, 0.55, 0.55))
	t.set_font_size("font_size", "Button", 22)
	t.set_color("font_color", "Label", TEXT)
	t.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0.7))
	t.set_constant("shadow_offset_x", "Label", 1)
	t.set_constant("shadow_offset_y", "Label", 2)
	t.set_stylebox("background", "ProgressBar", _box(Color(0, 0, 0, 0.55), Color(0, 0, 0, 0), 0, 4))
	t.set_stylebox("fill", "ProgressBar", _box(GOLD, Color(0, 0, 0, 0), 0, 4))
	t.set_font_size("font_size", "ProgressBar", 1)
	_theme = t
	return t


static func label(text: String, size := 20, color := TEXT, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = align
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


static func wrap_label(text: String, size := 18, color := TEXT, width := 400.0) -> Label:
	var l := label(text, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = width
	return l


static func button(text: String, cb: Callable, min_w := 260.0) -> Button:
	var b := TouchButton.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_w, 56)
	b.pressed.connect(func() -> void:
		Sfx.play("click", -6.0)
		cb.call())
	return b


static func bar(color: Color, w := 220.0, h := 14.0) -> ProgressBar:
	var p := ProgressBar.new()
	p.custom_minimum_size = Vector2(w, h)
	p.show_percentage = false
	var fill := _box(color, Color(0, 0, 0, 0), 0, 4)
	fill.content_margin_top = 0
	fill.content_margin_bottom = 0
	p.add_theme_stylebox_override("fill", fill)
	return p
