class_name BattleUI
extends Control
## Harekât arayüzü. Solda HEDEFLER ve KURMAY RAPORU, sağda birlik kartı (bayrak, teçhizat, EMİRLER),
## üstte saat ve tur, altta günlük ve turu bitirme. Giriş, brifing, rehber ve sonuç pencereleri.

const W_LEFT := 310.0
const W_RIGHT := 320.0

var b: Battle
var _top_time: Label
var _top_deadline: Label
var _top_cp: Label
var _obj_box: VBoxContainer
var _cas_label: Label
var _report_box: VBoxContainer
var _report_panel: PanelContainer
var _card: PanelContainer
var _card_box: VBoxContainer
var _card_scroll: ScrollContainer
var _report_scroll: ScrollContainer
var _log: RichTextLabel
var _tip: PanelContainer
var _tip_label: Label
var _hint: Label
var _end_btn: Button
var _overlay: Control
var _banner: Label
var _deploy: PanelContainer
var _deploy_label: Label
var _popups: Array = []


func setup(battle: Battle) -> void:
	b = battle
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = UiTheme.get_theme()
	_build_vignette()
	_build_top()
	_build_left()
	_build_card()
	_build_log()
	_build_buttons()
	_hint = UiTheme.label("", 20, UiTheme.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	_hint.add_theme_font_override("font", UiTheme.font("bold"))
	_hint.add_theme_constant_override("outline_size", 8)
	_hint.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_hint.offset_left = -360
	_hint.offset_right = 360
	_hint.offset_top = 70
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hint)
	_tip = PanelContainer.new()
	_tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tip_label = UiTheme.label("", 16)
	_tip.add_child(_tip_label)
	_tip.visible = false
	add_child(_tip)
	_banner = UiTheme.title("", 46, UiTheme.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	_banner.add_theme_constant_override("outline_size", 10)
	_banner.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_banner.offset_left = -500
	_banner.offset_right = 500
	_banner.offset_top = -160
	_banner.offset_bottom = -90
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.modulate.a = 0.0
	add_child(_banner)


## Ekran kenarlarını hafifçe karartan vinyet (eski fotoğraf/harita havası).
func _build_vignette() -> void:
	var v := ColorRect.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = """shader_type canvas_item;
void fragment() {
	vec2 p = (UV - 0.5) * vec2(1.25, 1.0);
	float v = smoothstep(0.38, 0.9, length(p));
	COLOR = vec4(0.03, 0.02, 0.01, v * 0.6);
}"""
	var m := ShaderMaterial.new()
	m.shader = sh
	v.material = m
	add_child(v)


func _panel_box(p: PanelContainer, sep := 4) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	p.add_child(v)
	return v


func _build_top() -> void:
	var p := PanelContainer.new()
	p.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	p.offset_left = 8
	p.offset_right = -8
	p.offset_top = 6
	p.offset_bottom = 58
	add_child(p)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 18)
	p.add_child(h)
	h.add_child(UiTheme.title(String(b.scenario.get("title", "")).split(":")[0], 22, UiTheme.GOLD))
	_top_time = UiTheme.label("", 19, UiTheme.TEXT)
	_top_time.add_theme_font_override("font", UiTheme.font("bold"))
	h.add_child(_top_time)
	_top_deadline = UiTheme.label("", 17, UiTheme.MUTED)
	h.add_child(_top_deadline)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(sp)
	_top_cp = UiTheme.label("", 18, UiTheme.GOLD)
	_top_cp.add_theme_font_override("font", UiTheme.font("bold"))
	_top_cp.tooltip_text = "Emir puanı: elle yönetilen her birlik, verilen her emir ve duruş değişikliği 1 puan harcar\n(karargâh menzili dışındaki birlik için 2). Emirli birlikler tur sonunda puan harcamadan uygular."
	_top_cp.mouse_filter = Control.MOUSE_FILTER_PASS
	h.add_child(_top_cp)
	var sup := UiTheme.button("İkmal", b.toggle_supply, 90)
	sup.custom_minimum_size.y = 40
	sup.add_theme_font_size_override("font_size", 16)
	sup.tooltip_text = "İkmal haritası: yeşil hücrelere cephane ulaşır, kırmızı hücreler ikmal dışıdır."
	h.add_child(sup)
	var oob := UiTheme.button("Muharebe Düzeni", show_oob, 170)
	oob.custom_minimum_size.y = 40
	oob.add_theme_font_size_override("font_size", 16)
	h.add_child(oob)
	var help := UiTheme.button("?", show_tutorial, 44)
	help.custom_minimum_size = Vector2(44, 40)
	help.tooltip_text = "Nasıl oynanır"
	h.add_child(help)
	var menu := UiTheme.button("☰", _show_menu, 52)
	menu.custom_minimum_size = Vector2(52, 40)
	h.add_child(menu)


func _build_left() -> void:
	var col := VBoxContainer.new()
	col.position = Vector2(8, 66)
	col.custom_minimum_size.x = W_LEFT
	col.add_theme_constant_override("separation", 6)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(col)
	var op := PanelContainer.new()
	col.add_child(op)
	var ov := _panel_box(op, 5)
	ov.add_child(UiTheme.title("HEDEFLER", 20, UiTheme.GOLD))
	_obj_box = VBoxContainer.new()
	_obj_box.add_theme_constant_override("separation", 5)
	ov.add_child(_obj_box)
	_cas_label = UiTheme.wrap_label("", 13, UiTheme.MUTED, W_LEFT - 40)
	ov.add_child(_cas_label)
	_report_panel = PanelContainer.new()
	col.add_child(_report_panel)
	var rv := _panel_box(_report_panel, 4)
	var rh := HBoxContainer.new()
	rh.add_child(UiTheme.title("KURMAY RAPORU", 18, UiTheme.GOLD))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rh.add_child(sp)
	var hide := Button.new()
	hide.text = "–"
	hide.flat = true
	hide.tooltip_text = "Raporu küçült / aç"
	hide.pressed.connect(func() -> void: _report_scroll.visible = not _report_scroll.visible)
	rh.add_child(hide)
	rv.add_child(rh)
	_report_scroll = ScrollContainer.new()
	_report_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_report_scroll.custom_minimum_size = Vector2(W_LEFT - 30, 150)
	rv.add_child(_report_scroll)
	_report_box = VBoxContainer.new()
	_report_box.add_theme_constant_override("separation", 6)
	_report_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_report_scroll.add_child(_report_box)


func _build_card() -> void:
	_card = PanelContainer.new()
	_card.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_card.offset_left = -W_RIGHT - 8
	_card.offset_right = -8
	_card.offset_top = 66
	_card.custom_minimum_size = Vector2(W_RIGHT, 0)
	add_child(_card)
	_card_scroll = ScrollContainer.new()
	_card_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_card.add_child(_card_scroll)
	_card_box = VBoxContainer.new()
	_card_box.add_theme_constant_override("separation", 4)
	_card_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_card_scroll.add_child(_card_box)
	_card.visible = false


func _build_log() -> void:
	var p := PanelContainer.new()
	p.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	p.offset_left = W_LEFT + 16
	p.offset_right = -272
	p.offset_top = -104
	p.offset_bottom = -8
	add_child(p)
	_log = RichTextLabel.new()
	_log.bbcode_enabled = true
	_log.scroll_following = true
	_log.add_theme_font_size_override("normal_font_size", 15)
	_log.custom_minimum_size = Vector2(300, 82)
	p.add_child(_log)


func _build_buttons() -> void:
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	v.offset_left = -264
	v.offset_right = -8
	v.offset_top = -158
	v.offset_bottom = -8
	v.add_theme_constant_override("separation", 6)
	add_child(v)
	var nb := UiTheme.button("Sıradaki Birlik (Tab)", b.next_unit, 256)
	nb.custom_minimum_size.y = 42
	nb.add_theme_font_size_override("font_size", 16)
	v.add_child(nb)
	_end_btn = UiTheme.button("Turu Bitir", b.end_turn, 256)
	_end_btn.custom_minimum_size.y = 98
	_end_btn.add_theme_font_size_override("font_size", 20)
	_end_btn.tooltip_text = "Emirler uygulanır, sonra düşman hamlesini yapar. (Enter)"
	v.add_child(_end_btn)


func _unhandled_key_input(e: InputEvent) -> void:
	var k := e as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	if k.keycode == KEY_ENTER or k.keycode == KEY_KP_ENTER:
		if _popups.is_empty() and _overlay == null:
			b.end_turn()
	elif k.keycode == KEY_TAB:
		b.next_unit()
	elif k.keycode == KEY_B:
		_toggle_bayonet()
	elif k.keycode == KEY_ESCAPE:
		if b.order_mode != "":
			b.order_mode = ""
			set_hint("")
		elif _overlay == null:
			_show_menu()


static func num(n: int) -> String:
	var s := str(n)
	var out := ""
	while s.length() > 3:
		out = "." + s.right(3) + out
		s = s.left(s.length() - 3)
	return s + out


func set_hint(text: String) -> void:
	_hint.text = text


func refresh() -> void:
	_top_time.text = "%s   Tur %d/%d" % [b.time_text(), mini(b.turn, b.turns), b.turns]
	_top_deadline.text = b.deadline_text() if b.phase != "deploy" else "Hazırlık"
	_top_cp.text = "Emir puanı %d/%d" % [b.cp, b.cp_max]
	for c in _obj_box.get_children():
		c.queue_free()
	for o: Dictionary in b.scenario.get("objectives", []):
		_obj_box.add_child(_objective_row(o))
	var tr: Dictionary = b.cas[Unit.OTTOMAN]
	var en: Dictionary = b.cas[Unit.ENTENTE]
	_cas_label.text = "Osmanlı: %s şehit, %s yaralı%s\nİtilaf: %s ölü, %s yaralı, %s esir%s" % [num(tr["dead"]), num(tr["wounded"]),
		(", %s esir" % num(tr["captured"])) if int(tr["captured"]) > 0 else "", num(en["dead"]), num(en["wounded"]), num(en["captured"]),
		("\nBatan gemi: %s" % ", ".join(b.sunk)) if not b.sunk.is_empty() else ""]
	_end_btn.disabled = b.phase != "player"
	match b.phase:
		"player":
			_end_btn.text = "Turu Bitir\nemirler uygulanır"
		"orders":
			_end_btn.text = "Emirler uygulanıyor..."
		"ai":
			_end_btn.text = "Düşman hamlesi..."
		_:
			_end_btn.text = "—"
	if _deploy:
		_deploy_label.text = "Kalan mayın: %d" % b.mine_budget
	show_unit(b.selected)


func _objective_row(o: Dictionary) -> Control:
	var ev := b.obj_eval(o)
	var req: bool = o.get("required", false)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var icon := UiTheme.label("✔" if ev["ok"] else ("!" if ev["risk"] else "○"), 20,
		Color(0.5, 0.9, 0.5) if ev["ok"] and not ev["risk"] else (Color(1.0, 0.5, 0.4) if ev["risk"] else UiTheme.MUTED))
	icon.custom_minimum_size.x = 22
	row.add_child(icon)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	var t := UiTheme.wrap_label(("ZORUNLU · " if req else "★ ") + String(o["text"]), 15, UiTheme.TEXT if req else Color(0.95, 0.88, 0.65), W_LEFT - 70)
	t.add_theme_font_override("font", UiTheme.font("bold"))
	v.add_child(t)
	if ev["text"] != "":
		v.add_child(UiTheme.wrap_label(ev["text"], 13, Color(1.0, 0.6, 0.5) if ev["risk"] else UiTheme.MUTED, W_LEFT - 70))
	row.add_child(v)
	# Hedefe tıklayınca kamera oraya gider
	var places: Array = o.get("places", [])
	if not places.is_empty():
		row.mouse_filter = Control.MOUSE_FILTER_STOP
		row.tooltip_text = "Haritada göster"
		row.gui_input.connect(func(e: InputEvent) -> void:
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
				b.mcam.focus(b.map.cell_world(b.place_cell(places[0])), Battle.WORLD_W * 0.4))
	return row


func show_report(items: Array) -> void:
	for c in _report_box.get_children():
		c.queue_free()
	_report_panel.visible = not items.is_empty()
	for it: Array in items:
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 0)
		var h := UiTheme.label(String(it[0]).to_upper(), 13, it[2])
		h.add_theme_font_override("font", UiTheme.font("bold"))
		v.add_child(h)
		v.add_child(UiTheme.wrap_label(it[1], 14, UiTheme.TEXT, W_LEFT - 50))
		_report_box.add_child(v)
	_report_scroll.visible = true


func add_log(text: String, color := UiTheme.TEXT) -> void:
	_log.push_color(color)
	_log.add_text(text + "\n")
	_log.pop()


# ------------------------------------------------------------- Birlik kartı

func show_unit(u: Unit) -> void:
	for c in _card_box.get_children():
		c.queue_free()
	_card.visible = u != null
	if u == null:
		return
	var mine := u.side == b.player_side
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	var flag := TextureRect.new()
	var nation := (u.counter as UnitMini).nation_key() if is_instance_valid(u.counter) else u.nation
	flag.texture = Flags.texture(nation)
	flag.custom_minimum_size = Vector2(54, 36)
	flag.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	flag.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	head.add_child(flag)
	var hv := VBoxContainer.new()
	hv.add_theme_constant_override("separation", 0)
	hv.add_child(UiTheme.wrap_label(u.name, 19, UiTheme.GOLD, W_RIGHT - 130))
	var kt := u.kind_title()
	hv.add_child(UiTheme.label("%s · %s%s" % [Flags.title(nation), kt, "" if u.size.to_lower() == kt.to_lower() else " " + u.size], 14, UiTheme.MUTED))
	head.add_child(hv)
	var close := Button.new()
	close.text = "✕"
	close.flat = true
	close.tooltip_text = "Kartı kapat"
	close.pressed.connect(func() -> void: b.select(null))
	head.add_child(close)
	_card_box.add_child(head)
	if u.commander != "":
		_card_box.add_child(UiTheme.wrap_label("Komutan: " + u.commander, 15, UiTheme.TEXT, W_RIGHT - 40))
	if not mine:
		_card_box.add_child(UiTheme.label("Güç: " + b.enemy_strength_text(u), 15))
		_card_box.add_child(UiTheme.label("Duruş: %s · Siper %d" % [u.stance_title(), u.entrench], 14, UiTheme.MUTED))
		_card_box.add_child(UiTheme.label("Talim: %s" % u.exp_title(), 14, UiTheme.MUTED))
	else:
		if u.uses_hp():
			_card_box.add_child(_bar_row("Dayanıklılık", u.strength(), Color(0.85, 0.5, 0.3)))
			_card_box.add_child(UiTheme.label("Mürettebat: %s" % num(u.men), 15))
		else:
			_card_box.add_child(UiTheme.label("Mevcut: %s / %s asker · %s" % [num(u.men), num(u.men_max), u.exp_title()], 15))
			_card_box.add_child(_bar_row("Güç", u.strength(), Color(0.85, 0.5, 0.3)))
		_card_box.add_child(_bar_row("Moral", u.morale / 100.0, Color(0.4, 0.75, 0.4)))
		_card_box.add_child(_bar_row("Dinçlik", 1.0 - u.fatigue / 100.0, Color(0.45, 0.65, 0.9)))
		_card_box.add_child(_bar_row("Cephane", u.ammo / 100.0, UiTheme.GOLD))
		_card_box.add_child(UiTheme.label(u.ammo_text(), 13, UiTheme.MUTED))
		var lines: Array[String] = []
		lines.append("Duruş: " + u.stance_title())
		if u.entrench > 0:
			lines.append("Siper %d" % u.entrench)
		if u.suppression > 0.0:
			lines.append("Bastırılmış %%%d" % int(u.suppression * 100.0))
		if u.suppressed > 0:
			lines.append("Susturuldu")
		var cell := b.grid.cell(u.cell)
		lines.append("Arazi: %s%s, %d m" % [cell.terrain, " (yol)" if cell.road else "", int(cell.elev)])
		if not u.is_naval() and not u.is_fort():
			lines.append("İkmal: " + ("hatta" if u.in_supply else "KESİK (%d tur)" % u.out_supply_turns))
		if u.hq_id != "":
			var hq := b.find_unit(u.hq_id)
			var hn := hq.short if hq else "?"
			lines.append("Komuta: %s %s" % [hn, "(menzilde)" if u.in_command else "(MENZİL DIŞI)"])
		elif u.is_hq():
			lines.append("Komuta menzili: %d hücre (%.1f km)" % [u.command_range, u.command_range * b.hex_m / 1000.0])
		if u.can_move():
			lines.append("Hareket puanı %.1f" % u.mp)
		if u.attacked:
			lines.append("Bu tur eylemini tamamladı")
		elif u.moved:
			lines.append("Hareket etti")
		_card_box.add_child(UiTheme.wrap_label(" · ".join(lines), 14, UiTheme.MUTED, W_RIGHT - 40))
	var eq := UiTheme.label("Teçhizat", 15, UiTheme.GOLD)
	eq.add_theme_font_override("font", UiTheme.font("bold"))
	_card_box.add_child(eq)
	for id_: String in u.equipment:
		var e := Equipment.info(id_)
		var l := UiTheme.wrap_label("%d × %s (%s)" % [int(u.equipment[id_]), e["name"], e["caliber"]], 14, UiTheme.TEXT, W_RIGHT - 40)
		l.tooltip_text = "%s\n%s" % [e["kind"], e["note"]]
		l.mouse_filter = Control.MOUSE_FILTER_PASS
		_card_box.add_child(l)
	if u.note != "":
		_card_box.add_child(UiTheme.wrap_label(u.note, 13, UiTheme.MUTED, W_RIGHT - 40))
	if mine and b.phase == "player":
		_card_box.add_child(_orders_section(u))
	_fit_card()


## Kart ekrana sığmazsa kaydırılabilir olsun (alt düğmelerin üstünde kalır).
func _fit_card() -> void:
	await get_tree().process_frame
	if not is_instance_valid(_card_box):
		return
	var max_h := get_viewport_rect().size.y - 66.0 - 190.0
	_card_scroll.custom_minimum_size = Vector2(W_RIGHT - 30, minf(_card_box.get_combined_minimum_size().y, max_h))
	_card.reset_size()


func _small_btn(text: String, cb: Callable, w: float, tip: String, active := false) -> Button:
	var bt := UiTheme.button(text, cb, w)
	bt.custom_minimum_size.y = 38
	bt.add_theme_font_size_override("font_size", 15)
	bt.tooltip_text = tip
	if active:
		var sel := UiTheme._box(UiTheme.GOLD.darkened(0.25), UiTheme.GOLD, 2)
		bt.add_theme_stylebox_override("normal", sel)
		bt.add_theme_color_override("font_color", Color(0.08, 0.06, 0.03))
	return bt


func _orders_section(u: Unit) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 5)
	var t := UiTheme.label("EMİR: " + u.order_title(), 16, UiTheme.GOLD)
	t.add_theme_font_override("font", UiTheme.font("bold"))
	v.add_child(t)
	var g1 := GridContainer.new()
	g1.columns = 2
	g1.add_theme_constant_override("h_separation", 6)
	g1.add_theme_constant_override("v_separation", 6)
	v.add_child(g1)
	var w := (W_RIGHT - 46) * 0.5
	if u.can_melee():
		g1.add_child(_small_btn("Taarruz...", func() -> void: b.give_order("attack"), w,
			"Haritada hedef seç: birlik her tur kendiliğinden o yöne ilerler ve yolundaki düşmana saldırır. Kırmızı ok planı gösterir.", u.order == "attack"))
		g1.add_child(_small_btn("Savun", func() -> void: b.give_order("defend"), w,
			"Savunma duruşuna geçer, yerini tutar ve her tur siperini derinleştirir (savunma +%25).", u.order == "defend"))
		g1.add_child(_small_btn("Yedekte bekle", func() -> void: b.give_order("reserve"), w,
			"Dinlenme duruşuna geçer: yorgunluk hızla azalır, moral toparlanır.", u.order == "reserve"))
	if not u.ranged_items().is_empty():
		g1.add_child(_small_btn("Serbest ateş", func() -> void: b.give_order("fire"), w,
			"Her tur menzildeki ve görülen en iyi hedefe kendiliğinden ateş eder.", u.order == "fire"))
	if u.order != "":
		g1.add_child(_small_btn("Emri kaldır", func() -> void: b.give_order(""), w, "Birlik yalnızca senin elle verdiğin komutlarla hareket eder."))
	if u.regiment() != "":
		var cb := CheckBox.new()
		cb.text = "Emri bütün %s'na ver" % u.regiment()
		cb.button_pressed = b.order_group
		cb.toggled.connect(func(on: bool) -> void: b.order_group = on)
		cb.add_theme_font_size_override("font_size", 15)
		v.add_child(cb)
	if u.can_move() and not u.is_hq():
		var ts := UiTheme.label("DURUŞ: " + u.stance_title(), 15, UiTheme.GOLD)
		ts.add_theme_font_override("font", UiTheme.font("bold"))
		v.add_child(ts)
		var g3 := GridContainer.new()
		g3.columns = 2
		g3.add_theme_constant_override("h_separation", 6)
		g3.add_theme_constant_override("v_separation", 6)
		v.add_child(g3)
		g3.add_child(_small_btn("Muharebe", func() -> void: b.set_stance(u, "normal"), w,
			"Muharebe düzeni: hareket eder ve saldırır.", u.stance == "normal"))
		g3.add_child(_small_btn("İntikal", func() -> void: b.set_stance(u, "march"), w,
			"Yürüyüş kolu: hareket puanı x1,5 ve yolda çok hızlı, daha az yorulur.\nAma saldıramaz, düşmana temas eden hücreye giremez ve savunması x0,6.", u.stance == "march"))
		g3.add_child(_small_btn("Savunma", func() -> void: b.set_stance(u, "defend"), w,
			"Savunma: hareket etmez, saldırmaz; savunma x1,25, siper iki kat hızlı (en çok 3).", u.stance == "defend"))
		g3.add_child(_small_btn("Dinlenme", func() -> void: b.set_stance(u, "rest"), w,
			"Dinlenme: yorgunluk tur başına 35 azalır, moral toparlanır; savunma x0,8.", u.stance == "rest"))
	var t2 := UiTheme.label("ŞİMDİ (bu tur, elle · %d emir puanı)" % b.cp_cost(u), 15, UiTheme.GOLD)
	t2.add_theme_font_override("font", UiTheme.font("bold"))
	v.add_child(t2)
	v.add_child(UiTheme.wrap_label("Sarı hücre: git · kırmızı hücre: saldır. Fareyi hedefin üstünde tut: bütün etkenleriyle kesin sonuç görünür.", 13, UiTheme.MUTED, W_RIGHT - 40))
	var g2 := HBoxContainer.new()
	g2.add_theme_constant_override("separation", 6)
	v.add_child(g2)
	if u.can_melee() and not u.attacked:
		g2.add_child(_small_btn("Süngü: " + ("AÇIK" if b.bayonet else "kapalı") + " (B)", _toggle_bayonet, w,
			"Süngü hücumu: saldırı gücü +%35, düşman morali ağır sarsılır; kendi şehit ve yaralı sayın artar.\nCephanesi bitmiş birlik de süngüyle saldırabilir.", b.bayonet))
	if u.is_land() and not u.is_fort() and not u.moved and not u.attacked and u.entrench < 2:
		g2.add_child(_small_btn("Siper Kaz", b.dig_in, w, "Bu tur hareket etmez ve saldırmaz; siper seviyesi artar (her seviye savunma +%35)."))
	return v


func _toggle_bayonet() -> void:
	b.bayonet = not b.bayonet
	show_unit(b.selected)


func _bar_row(title: String, v: float, col: Color) -> Control:
	var h := HBoxContainer.new()
	var l := UiTheme.label(title, 14, UiTheme.MUTED)
	l.custom_minimum_size.x = 100
	h.add_child(l)
	var bar := UiTheme.bar(col, 140, 12)
	bar.value = clampf(v, 0.0, 1.0) * 100.0
	h.add_child(bar)
	h.add_child(UiTheme.label(" %d%%" % int(round(v * 100.0)), 13, UiTheme.MUTED))
	return h


func show_cell(_c: HexGrid.Cell) -> void:
	_card.visible = false


## Fare altındaki hücre; seçili birliğin saldırısı için bütün etkenleriyle kesin sonuç.
func hover(c: HexGrid.Cell, u: Unit) -> void:
	if c == null:
		_tip.visible = false
		return
	var lines: Array[String] = []
	if c.place != "":
		lines.append(c.place + ("  ★ hedef" if c.vp > 0 else ""))
	if c.is_sea():
		lines.append("Deniz" + (" · %d mayın" % c.mines if c.mines > 0 and (b.player_side == Unit.OTTOMAN or c.mines_known) else ""))
	else:
		var ti := Terrain.info(c.terrain)
		lines.append("%s%s · %d m · hareket %.1f · savunma x%.2f" % [c.terrain.capitalize(), " + yol" if c.road else "", int(round(c.elev)), float(ti["move"]), float(ti["defense"])])
	if u:
		lines.append("%s · %s · %s" % [u.name, b.enemy_strength_text(u), u.stance_title()])
		var s := b.selected
		if s and s.side == b.player_side and b.targets.has(c.coord):
			lines.append("")
			lines.append_array(_combat_lines(b.preview(s, c.coord), s, u))
	elif b.selected and b.reach.has(c.coord) and b.selected.side == b.player_side:
		var cost: float = b.reach[c.coord][0]
		lines.append("Hareket maliyeti %.1f / kalan %.1f · yorgunluk +%d" % [cost, b.selected.mp, int(cost * (2.5 if b.selected.stance == "march" else 4.0))])
	if b.order_mode == "attack":
		lines.append("Tıkla: taarruz hedefi")
	_tip_label.text = "\n".join(lines)
	_tip.visible = true
	_tip.reset_size()
	var mp := get_viewport().get_mouse_position()
	_tip.position = (mp + Vector2(20, 20)).min(get_viewport_rect().size - _tip.size - Vector2(4, 4))


## Muharebe hesabının satır satır dökümü.
func _combat_lines(pr: Dictionary, att: Unit, def: Unit) -> Array[String]:
	var out: Array[String] = []
	if pr.get("melee", false):
		var odds: float = pr["odds"]
		out.append("KESİN SONUÇ · güç oranı 1 : %.2f → %s" % [odds, pr["outcome"]])
		out.append("Saldıran %s: ateş gücü %d" % [att.short, int(pr["att_base"])])
		for f in pr["att_f"]:
			out.append("   x%.2f  %s" % [f[1], f[0]])
		out.append("   = %d" % int(pr["A"]))
		out.append("Savunan %s: ateş gücü %d" % [def.short, int(pr["def_base"])])
		for f in pr["def_f"]:
			out.append("   x%.2f  %s" % [f[1], f[0]])
		out.append("   = %d" % int(pr["D"]))
		var dv := _split(int(pr["cas_def"]))
		var av := _split(int(pr["cas_att"]))
		out.append("Düşman: %s · Birliğimiz: %s" % [Battle.cas_words(def.side, dv), Battle.cas_words(att.side, av)])
		out.append("Cephane: -%d%% · yorgunluk +15" % int(att.ammo_cost("bayonet" if pr["bayonet"] else "attack")))
		if odds < 1.0:
			out.append("İpucu: topçuyla önce bastır, yanına birlik getirip kuşat ya da süngüyü aç.")
	else:
		out.append("KESİN SONUÇ · %s" % pr.get("outcome", ""))
		out.append("Atış gücü %d" % int(pr.get("att_base", 0)))
		for f in pr["att_f"]:
			out.append("   x%.2f  %s" % [f[1], f[0]])
		for f in pr["def_f"]:
			out.append("   x%.2f  %s" % [f[1], f[0]])
		out.append("Mermi: -%d%% (%s)" % [int(att.ammo_cost("fire")), att.ammo_text()])
	return out


static func _split(n: int) -> Vector2i:
	var d := int(round(n * 0.3))
	return Vector2i(d, n - d)


func turn_banner(t: int, total: int, time: String) -> void:
	_banner.text = "TUR %d / %d  ·  %s" % [t, total, time]
	var tw := create_tween()
	tw.tween_property(_banner, "modulate:a", 1.0, 0.3)
	tw.tween_interval(1.3)
	tw.tween_property(_banner, "modulate:a", 0.0, 0.6)


# ------------------------------------------------------------- Pencereler

func _modal(width := 720.0) -> VBoxContainer:
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.6)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.add_child(cc)
	var p := PanelContainer.new()
	p.custom_minimum_size.x = width
	cc.add_child(p)
	var v := _panel_box(p, 12)
	_overlay = shade
	return v


func _close_modal() -> void:
	if _overlay:
		_overlay.queue_free()
		_overlay = null
	if not _popups.is_empty():
		var nxt: Array = _popups.pop_front()
		popup(nxt[0], nxt[1], nxt[2])


## Tarihî olay penceresi (sıraya alınır).
func popup(title: String, text: String, who: String) -> void:
	if _overlay != null:
		_popups.append([title, text, who])
		return
	var v := _modal(680)
	if who != "":
		v.add_child(UiTheme.label(who, 17, UiTheme.MUTED))
	v.add_child(UiTheme.title(title, 30, UiTheme.GOLD))
	v.add_child(UiTheme.wrap_label(text, 20, UiTheme.TEXT, 640))
	var cc := CenterContainer.new()
	cc.add_child(UiTheme.button("Tamam", _close_modal, 200))
	v.add_child(cc)


## Giriş kartları: savaşın Türk tarihindeki yeri.
func play_intro(cards: Array, done: Callable) -> void:
	if cards.is_empty():
		done.call()
		return
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.015, 0.01, 0.9)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	_overlay = shade
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.add_child(cc)
	var v := VBoxContainer.new()
	v.custom_minimum_size.x = 860
	v.add_theme_constant_override("separation", 20)
	cc.add_child(v)
	var title := UiTheme.title("", 52, UiTheme.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.custom_minimum_size.x = 860
	var body := UiTheme.wrap_label("", 25, UiTheme.TEXT, 860)
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	v.add_child(body)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	v.add_child(row)
	var idx := [0]
	var finish := func() -> void:
		Voice.stop()
		shade.queue_free()
		_overlay = null
		done.call()
	var show := func() -> void:
		var c: Array = cards[idx[0]]
		title.text = c[0]
		body.text = c[1]
		v.modulate.a = 0.0
		create_tween().tween_property(v, "modulate:a", 1.0, 0.6)
		Voice.speak(c[1])
	var next := func() -> void:
		idx[0] += 1
		if idx[0] >= cards.size():
			finish.call()
		else:
			show.call()
	row.add_child(UiTheme.button("Devam", next, 200))
	row.add_child(UiTheme.button("Geç", finish, 140))
	Sfx.play("intro", -10.0)
	show.call()


func show_briefing(sc: Dictionary, done: Callable) -> void:
	var v := _modal(900)
	v.add_child(UiTheme.title(sc.get("title", ""), 38, UiTheme.GOLD))
	v.add_child(UiTheme.label(sc.get("subtitle", ""), 18, UiTheme.MUTED))
	v.add_child(UiTheme.wrap_label(sc.get("briefing", ""), 18, UiTheme.TEXT, 860))
	v.add_child(UiTheme.title("GÖREVİN", 22, UiTheme.GOLD))
	for o: Dictionary in sc.get("objectives", []):
		var req: bool = o.get("required", false)
		var l := UiTheme.wrap_label(("ZORUNLU · " if req else "★ YILDIZ · ") + String(o["text"]), 18, UiTheme.TEXT if req else Color(0.95, 0.88, 0.65), 860)
		l.add_theme_font_override("font", UiTheme.font("bold"))
		v.add_child(l)
	v.add_child(UiTheme.wrap_label("Zorunlu hedef sağlanamazsa harekât başarısız olur. Her yıldız hedefi bir yıldız daha kazandırır.", 15, UiTheme.MUTED, 860))
	var cc := CenterContainer.new()
	cc.add_child(UiTheme.button("Harekâta Başla", func() -> void:
		_close_modal()
		if not GameState.settings.get("tutorial_seen", false):
			show_tutorial(done)
		else:
			done.call(), 300))
	v.add_child(cc)


const TUTORIAL := [
	["1 · Amacın", "Sol üstteki HEDEFLER panelinde görevin yazar. 'ZORUNLU' hedef sağlanamazsa harekât başarısız olur; ★ hedefler yıldız kazandırır. Hedef tepeler altın direkli bayraklarla işaretlidir; bayrak tepeyi kimin tuttuğunu gösterir, kırmızı halka tehlikeyi. Üst çubukta kaç tur kaldığı görünür."],
	["2 · Şans yok", "Bu oyunda zar yoktur: her çarpışmanın sonucu kesindir. Kendi birliğini seçip fareyi düşmanın üstünde tut: iki tarafın ateş gücü, her etken (moral, yorgunluk, talim, cephane, arazi, yükseklik, siper, duruş, kuşatma, topçu bastırması) ve kesin zayiat tablosu görünür. Belirsizlik yalnızca göremediğin düşmandadır: uzaktaki düşmanın gücü tahminidir, maki ve derelerdeki birlikler gizlenir."],
	["3 · Komuta: emir puanı", "Her tur sınırlı emir puanın vardır (üst çubuk). Bir birliği elle yönetmek, emir vermek ya da duruşunu değiştirmek 1 puan; karargâh menzili dışındaki birlik için 2 puandır. Taarruz, Savun, Yedek ve Serbest ateş emirleri tur sonunda puan harcamadan uygulanır: iyi bir komutan planını emirlerle kurar, elle müdahaleyi kritik anlara saklar. Karargâhı birliklerinin yakınında tut."],
	["4 · İkmal, yorgunluk, duruş", "Cephane yalnızca ikmal hattındaki birliklere gelir (İkmal düğmesi: yeşil alan). Tabyaların mermisi sınırlıdır: ne zaman ateş edeceğini sen seç. Yürüyüş ve çarpışma yorar; yorgun birlik zayıflar. Duruşlar: İntikal (hızlı, ama saldıramaz), Muharebe, Savunma (+%25, hızlı siper), Dinlenme (toparlanır)."],
	["5 · Birleşik harekât", "Önce topçuyla düşmanı bastır (bastırılan birliğin gücü düşer), sonra komşu birliklerle kuşatıp (her ek birlik +%12) süngüyle saldır. Güç oranı 2'yi aşarsa düşman çekilmek zorundadır; kaçacak yeri yoksa esir düşer. Yüksek yer ve siper savunana büyük üstünlük verir."],
	["6 · Tur", "Turu bitirince emirlerin uygulanır, sonra düşman oynar; mavi oklar düşmanın görülen hareketleridir. Her tur başında KURMAY RAPORU düşman hamlesini, ikmal ve komuta sorunlarını, yorgun birlikleri ve tarihten bir öneriyi söyler. Muharebe Düzeni düğmesi bütün birliklerinin durumunu tek tabloda gösterir."],
]


func show_tutorial(done: Callable = Callable()) -> void:
	if _overlay:
		if not done.is_valid():
			return
		_overlay.queue_free()
		_overlay = null
	var v := _modal(780)
	var title := UiTheme.title("", 30, UiTheme.GOLD)
	var body := UiTheme.wrap_label("", 19, UiTheme.TEXT, 740)
	v.add_child(UiTheme.label("NASIL OYNANIR", 15, UiTheme.MUTED))
	v.add_child(title)
	v.add_child(body)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	v.add_child(row)
	var idx := [0]
	var shade := _overlay
	var finish := func() -> void:
		GameState.settings["tutorial_seen"] = true
		GameState.save_game()
		if is_instance_valid(shade):
			shade.queue_free()
		_overlay = null
		if done.is_valid():
			done.call()
	var show := func() -> void:
		title.text = TUTORIAL[idx[0]][0]
		body.text = TUTORIAL[idx[0]][1]
	var next_btn := UiTheme.button("İleri", func() -> void: pass, 180)
	next_btn.pressed.connect(func() -> void:
		idx[0] += 1
		if idx[0] >= TUTORIAL.size():
			finish.call()
		else:
			show.call()
			if idx[0] == TUTORIAL.size() - 1:
				next_btn.text = "Başla")
	row.add_child(UiTheme.button("Geç", finish, 140))
	row.add_child(next_btn)
	show.call()


func show_deploy(d: Dictionary) -> void:
	_deploy = PanelContainer.new()
	_deploy.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_deploy.offset_left = -340
	_deploy.offset_right = 340
	_deploy.offset_top = 66
	add_child(_deploy)
	var v := _panel_box(_deploy)
	v.add_child(UiTheme.title(d.get("title", "Mayın döşeme"), 24, UiTheme.GOLD))
	v.add_child(UiTheme.wrap_label(d.get("text", ""), 16, UiTheme.TEXT, 660))
	_deploy_label = UiTheme.label("", 19, UiTheme.GOLD)
	v.add_child(_deploy_label)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	v.add_child(row)
	row.add_child(UiTheme.button("Tarihî hattı kullan", func() -> void:
		for k in b.mine_zone:
			if b.grid.cell(k).mines > 0:
				b.toggle_mine(k)
		_finish_deploy(), 260))
	row.add_child(UiTheme.button("Tamam, harekâta başla", _finish_deploy, 300))
	refresh()


func _finish_deploy() -> void:
	if _deploy:
		_deploy.queue_free()
		_deploy = null
	b.finish_deploy()


func show_result(won: bool, stars: int, reason: String, lines: Array[String], history: String) -> void:
	_popups.clear()
	if _overlay:
		_overlay.queue_free()
		_overlay = null
	var v := _modal(860)
	v.add_child(UiTheme.title("ZAFER" if won else "YENİLGİ", 56, UiTheme.GOLD if won else Color(0.9, 0.4, 0.35), HORIZONTAL_ALIGNMENT_CENTER))
	if won:
		var sr := StarRow.new(stars, 40.0)
		var c0 := CenterContainer.new()
		c0.add_child(sr)
		v.add_child(c0)
	if reason != "":
		v.add_child(UiTheme.wrap_label(reason, 19, UiTheme.TEXT, 820))
	for l in lines:
		v.add_child(UiTheme.wrap_label(l, 17, UiTheme.TEXT, 820))
	v.add_child(UiTheme.wrap_label(_cas_label.text.replace("\n", "   ·   "), 16, UiTheme.MUTED, 820))
	if history != "":
		v.add_child(UiTheme.title("Tarihte ne oldu?", 24, UiTheme.GOLD))
		v.add_child(UiTheme.wrap_label(history, 16, UiTheme.TEXT, 820))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	row.add_child(UiTheme.button("Yeniden Oyna", func() -> void: get_tree().reload_current_scene(), 240))
	row.add_child(UiTheme.button("Ana Menü", func() -> void: get_tree().change_scene_to_file("res://scenes/main_menu.tscn"), 240))
	v.add_child(row)
	if won:
		Sfx.play("bugle", -4.0)
		Sfx.play("crowd", -8.0)
	else:
		Sfx.play("defeat", -4.0)


func _show_menu() -> void:
	if _overlay:
		return
	var v := _modal(440)
	v.add_child(UiTheme.title("Duraklatıldı", 32, UiTheme.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UiTheme.button("Devam", _close_modal, 400))
	v.add_child(UiTheme.button("Düşman hamleleri: " + ("Hızlı" if b.fast_ai else "Normal"), func() -> void:
		b.fast_ai = not b.fast_ai
		_close_modal()
		_show_menu(), 400))
	v.add_child(UiTheme.button("Kamera düşmanı izlesin: " + ("Açık" if b.follow_enemy else "Kapalı"), func() -> void:
		b.follow_enemy = not b.follow_enemy
		_close_modal()
		_show_menu(), 400))
	v.add_child(UiTheme.button("Nasıl Oynanır", func() -> void:
		_close_modal()
		show_tutorial(), 400))
	v.add_child(UiTheme.button("Yeniden Başla", func() -> void: get_tree().reload_current_scene(), 400))
	v.add_child(UiTheme.button("Ana Menü", func() -> void: get_tree().change_scene_to_file("res://scenes/main_menu.tscn"), 400))



## Muharebe düzeni: karargâhlara göre bütün birlikler ve durumları.
func show_oob() -> void:
	if _overlay:
		return
	var v := _modal(980)
	v.add_child(UiTheme.title("MUHAREBE DÜZENİ", 30, UiTheme.GOLD))
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(940, minf(520.0, get_viewport_rect().size.y - 200.0))
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(sc)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 3)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(list)
	var groups := {}
	for u in b.units:
		if u.side != b.player_side or u.state == "dead" or u.state == "retired":
			continue
		var key := u.hq_id if u.hq_id != "" else ("_" + u.id if u.is_hq() else "_bağımsız")
		if u.is_hq():
			key = u.id
		if not groups.has(key):
			groups[key] = []
		(groups[key] as Array).append(u)
	var hdr := HBoxContainer.new()
	for t in [["Birlik", 250], ["Asker", 80], ["Moral", 70], ["Dinçlik", 75], ["Cephane", 80], ["Duruş", 140], ["İkmal", 70], ["Komuta", 75], ["Emir", 150]]:
		var l := UiTheme.label(t[0], 14, UiTheme.GOLD)
		l.custom_minimum_size.x = t[1]
		hdr.add_child(l)
	list.add_child(hdr)
	for key: String in groups:
		var hq := b.find_unit(key)
		var title := ("Karargâh: " + hq.name + (" · " + hq.commander if hq.commander != "" else "")) if hq else "Bağımsız birlikler"
		var gl := UiTheme.label(title, 16, Color(0.95, 0.85, 0.6))
		gl.add_theme_font_override("font", UiTheme.font("bold"))
		list.add_child(gl)
		for u: Unit in groups[key]:
			list.add_child(_oob_row(u))
	var cc := CenterContainer.new()
	cc.add_child(UiTheme.button("Kapat", _close_modal, 200))
	v.add_child(cc)


func _oob_row(u: Unit) -> Control:
	var row := HBoxContainer.new()
	var reserve := u.state == "reserve"
	var vals := [
		[("   " if not u.is_hq() else "") + u.name, 250],
		[str(u.men) if not u.uses_hp() else "%%%d" % int(u.strength() * 100), 80],
		["%d" % int(u.morale), 70],
		["%d" % int(100 - u.fatigue), 75],
		["%d%%" % int(u.ammo), 80],
		["(Tur %d'de gelir)" % u.arrive_turn if reserve else u.stance_title(), 140],
		["—" if reserve else ("✔" if u.in_supply else "✘"), 70],
		["—" if reserve else ("✔" if u.in_command else "✘"), 75],
		[u.order_title(), 150],
	]
	for vv in vals:
		var l := UiTheme.label(String(vv[0]), 14, UiTheme.MUTED if reserve else UiTheme.TEXT)
		l.custom_minimum_size.x = vv[1]
		l.clip_text = true
		row.add_child(l)
	if not reserve:
		row.mouse_filter = Control.MOUSE_FILTER_STOP
		row.tooltip_text = "Seç ve haritada göster"
		row.gui_input.connect(func(e: InputEvent) -> void:
			if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
				_close_modal()
				b.select(u)
				b.mcam.focus(b.map.cell_world(u.cell), Battle.WORLD_W * 0.35))
	return row
