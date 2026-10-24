class_name BattleUI
extends Control
## Harekât arayüzü: üst bilgi çubuğu, birlik kartı, günlük, ipucu, olay pencereleri, giriş ve sonuç.

var b: Battle
var _top_time: Label
var _top_obj: HBoxContainer
var _top_loss: Label
var _card: PanelContainer
var _card_box: VBoxContainer
var _log: RichTextLabel
var _tip: PanelContainer
var _tip_label: Label
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
	_build_top()
	_build_card()
	_build_log()
	_build_buttons()
	_tip = PanelContainer.new()
	_tip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tip_label = UiTheme.label("", 15)
	_tip.add_child(_tip_label)
	_tip.visible = false
	add_child(_tip)
	_banner = UiTheme.label("", 40, UiTheme.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	_banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_banner.position = Vector2(-400, 120)
	_banner.size = Vector2(800, 60)
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.modulate.a = 0.0
	add_child(_banner)


func _panel_box(p: PanelContainer) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	p.add_child(v)
	return v


func _build_top() -> void:
	var p := PanelContainer.new()
	p.set_anchors_preset(Control.PRESET_TOP_WIDE)
	p.offset_left = 8
	p.offset_right = -8
	p.offset_top = 6
	add_child(p)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 18)
	p.add_child(h)
	_top_time = UiTheme.label("", 18, UiTheme.GOLD)
	h.add_child(_top_time)
	_top_obj = HBoxContainer.new()
	_top_obj.add_theme_constant_override("separation", 10)
	h.add_child(_top_obj)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(sp)
	_top_loss = UiTheme.label("", 16, UiTheme.MUTED)
	h.add_child(_top_loss)
	var menu := UiTheme.button("☰", _show_menu, 52)
	menu.custom_minimum_size = Vector2(52, 40)
	h.add_child(menu)


func _build_card() -> void:
	_card = PanelContainer.new()
	_card.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_card.offset_left = -330
	_card.offset_right = -8
	_card.offset_top = 62
	_card.custom_minimum_size = Vector2(322, 0)
	add_child(_card)
	_card_box = _panel_box(_card)
	_card.visible = false


func _build_log() -> void:
	var p := PanelContainer.new()
	p.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	p.offset_left = 8
	p.offset_right = 560
	p.offset_top = -168
	p.offset_bottom = -8
	p.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(p)
	_log = RichTextLabel.new()
	_log.bbcode_enabled = true
	_log.scroll_following = true
	_log.add_theme_font_size_override("normal_font_size", 14)
	_log.custom_minimum_size = Vector2(530, 140)
	p.add_child(_log)


func _build_buttons() -> void:
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	v.offset_left = -250
	v.offset_right = -8
	v.offset_top = -132
	v.offset_bottom = -8
	v.add_theme_constant_override("separation", 6)
	add_child(v)
	var nb := UiTheme.button("Sıradaki Birlik (Tab)", b.next_unit, 240)
	nb.custom_minimum_size.y = 44
	nb.add_theme_font_size_override("font_size", 17)
	v.add_child(nb)
	_end_btn = UiTheme.button("Turu Bitir (Enter)", b.end_turn, 240)
	_end_btn.custom_minimum_size.y = 64
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
		if _overlay == null:
			_show_menu()


func refresh() -> void:
	_top_time.text = "%s · Tur %d/%d" % [b.time_text(), b.turn, b.turns]
	for c in _top_obj.get_children():
		c.queue_free()
	for name_: String in b.places:
		var p: Dictionary = b.places[name_]
		if not p["objective"]:
			continue
		var col := Color(0.95, 0.4, 0.35) if p["owner"] == Unit.OTTOMAN else (Color(0.55, 0.7, 1.0) if p["owner"] == Unit.ENTENTE else UiTheme.MUTED)
		_top_obj.add_child(UiTheme.label("● " + name_, 15, col))
	_top_loss.text = "Kayıp  Osm. %s · İtl. %s" % [_num(b.losses[Unit.OTTOMAN]), _num(b.losses[Unit.ENTENTE])]
	if b.has_ships and (not b.sunk.is_empty() or _top_obj.get_child_count() == 0):
		_top_loss.text += "  ·  Batan gemi: %d" % b.sunk.size()
	_end_btn.disabled = b.phase != "player"
	_end_btn.text = "Turu Bitir (Enter)" if b.phase == "player" else ("Düşman hamlesi..." if b.phase == "ai" else "—")
	if _deploy:
		_deploy_label.text = "Kalan mayın: %d" % b.mine_budget
	show_unit(b.selected)


static func _num(n: int) -> String:
	var s := str(n)
	var out := ""
	while s.length() > 3:
		out = "." + s.right(3) + out
		s = s.left(s.length() - 3)
	return s + out


func add_log(text: String, color := UiTheme.TEXT) -> void:
	_log.push_color(color)
	_log.add_text(text + "\n")
	_log.pop()


func show_unit(u: Unit) -> void:
	for c in _card_box.get_children():
		c.queue_free()
	_card.visible = u != null
	if u == null:
		return
	var mine := u.side == b.player_side
	_card_box.add_child(UiTheme.label(u.name, 21, UiTheme.GOLD))
	var kt := u.kind_title()
	_card_box.add_child(UiTheme.label("%s · %s%s" % [u.nation_title(), kt, "" if u.size.to_lower() == kt.to_lower() else " " + u.size], 14, UiTheme.MUTED))
	if u.commander != "":
		_card_box.add_child(UiTheme.wrap_label("Komutan: " + u.commander, 15, UiTheme.TEXT, 290))
	if u.uses_hp():
		_card_box.add_child(_bar_row("Dayanıklılık", u.strength(), Color(0.85, 0.5, 0.3)))
		_card_box.add_child(UiTheme.label("Mürettebat: %s" % _num(u.men), 15))
	else:
		_card_box.add_child(UiTheme.label("Mevcut: %s / %s asker" % [_num(u.men), _num(u.men_max)], 15))
		_card_box.add_child(_bar_row("Güç", u.strength(), Color(0.85, 0.5, 0.3)))
	_card_box.add_child(_bar_row("Moral", u.morale / 100.0, Color(0.4, 0.75, 0.4)))
	_card_box.add_child(_bar_row("Cephane", u.ammo / 100.0, UiTheme.GOLD))
	var st: Array[String] = []
	if u.entrench > 0:
		st.append("Siperde (%d)" % u.entrench)
	if u.suppressed > 0:
		st.append("Susturuldu")
	if mine:
		if u.attacked:
			st.append("Bu tur hareketini tamamladı")
		elif u.moved:
			st.append("Hareket etti")
		if u.can_move():
			st.append("Hareket: %.1f/%.0f" % [u.mp, u.mp_max])
	if not st.is_empty():
		_card_box.add_child(UiTheme.wrap_label(" · ".join(st), 14, UiTheme.MUTED, 290))
	_card_box.add_child(UiTheme.label("Teçhizat", 16, UiTheme.GOLD))
	for id_: String in u.equipment:
		var e := Equipment.info(id_)
		var l := UiTheme.wrap_label("%d × %s (%s)" % [int(u.equipment[id_]), e["name"], e["caliber"]], 14, UiTheme.TEXT, 290)
		l.tooltip_text = "%s\n%s" % [e["kind"], e["note"]]
		l.mouse_filter = Control.MOUSE_FILTER_PASS
		_card_box.add_child(l)
	if u.note != "":
		_card_box.add_child(UiTheme.wrap_label(u.note, 13, UiTheme.MUTED, 290))
	if mine and b.phase == "player":
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		_card_box.add_child(row)
		if u.can_melee() and not u.attacked:
			var bb := UiTheme.button("Süngü: " + ("AÇIK" if b.bayonet else "kapalı") + " (B)", _toggle_bayonet, 150)
			bb.custom_minimum_size.y = 40
			bb.add_theme_font_size_override("font_size", 15)
			bb.tooltip_text = "Süngü hücumu: saldırı gücü +%35, düşman morali ağır sarsılır; kendi kaybın artar.\nCephanesi bitmiş birlik de süngüyle saldırabilir."
			row.add_child(bb)
		if u.is_land() and not u.is_fort() and not u.moved and not u.attacked and u.entrench < 2:
			var db := UiTheme.button("Siper Kaz", b.dig_in, 130)
			db.custom_minimum_size.y = 40
			db.add_theme_font_size_override("font_size", 15)
			db.tooltip_text = "Bu tur hareket etmez ve saldırmaz; siper seviyesi artar (savunma +%35)."
			row.add_child(db)


func _toggle_bayonet() -> void:
	b.bayonet = not b.bayonet
	show_unit(b.selected)


func _bar_row(title: String, v: float, col: Color) -> Control:
	var h := HBoxContainer.new()
	h.add_child(UiTheme.label(title, 14, UiTheme.MUTED))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(sp)
	var bar := UiTheme.bar(col, 160, 12)
	bar.value = clampf(v, 0.0, 1.0) * 100.0
	h.add_child(bar)
	return h


func show_cell(c: HexGrid.Cell) -> void:
	_card.visible = false


## Fare altındaki hücre ve (varsa) seçili birliğin saldırı tahmini.
func hover(c: HexGrid.Cell, u: Unit) -> void:
	if c == null:
		_tip.visible = false
		return
	var lines: Array[String] = []
	if c.place != "":
		lines.append(c.place)
	if c.is_sea():
		lines.append("Deniz" + (" · %d mayın" % c.mines if c.mines > 0 and (b.player_side == Unit.OTTOMAN or c.mines_known) else ""))
	else:
		lines.append("Yükseklik %d m · engebe %d m" % [int(round(c.elev)), int(round(c.rough))])
	if u:
		lines.append("%s (%s)" % [u.name, str(u.men) + " asker" if not u.uses_hp() else "%%%d" % int(u.strength() * 100)])
		var s := b.selected
		if s and s.side == b.player_side and b.targets.has(c.coord):
			var pr := b.preview(s, c.coord)
			if pr.has("odds"):
				lines.append("Tahmini: düşman kaybı ~%d, kendi kaybın ~%d" % [pr["cas_def"], pr["cas_att"]])
				lines.append("Güç oranı 1 : %.1f%s" % [pr["odds"], "  (düşman çekilebilir)" if pr["retreat"] else ""])
			elif pr["hard"]:
				lines.append("Tahmini hasar ~%%%d · mesafe %.1f km" % [int(pr["dmg"] / maxf(u.hp_max, 1.0) * 100.0), pr["dist"] / 1000.0])
			else:
				lines.append("Tahmini kayıp ~%d · mesafe %.1f km" % [pr["cas"], pr["dist"] / 1000.0])
	elif b.selected and b.reach.has(c.coord):
		lines.append("Hareket maliyeti %.1f" % b.reach[c.coord][0])
	_tip_label.text = "\n".join(lines)
	_tip.visible = true
	_tip.reset_size()
	var mp := get_viewport().get_mouse_position()
	_tip.position = (mp + Vector2(18, 18)).min(get_viewport_rect().size - _tip.size - Vector2(4, 4))


func turn_banner(t: int, total: int, time: String) -> void:
	_banner.text = "TUR %d / %d  ·  %s" % [t, total, time]
	var tw := create_tween()
	tw.tween_property(_banner, "modulate:a", 1.0, 0.3)
	tw.tween_interval(1.4)
	tw.tween_property(_banner, "modulate:a", 0.0, 0.6)


# ------------------------------------------------------------- Pencereler

func _modal(width := 720.0) -> VBoxContainer:
	var shade := ColorRect.new()
	shade.color = Color(0, 0, 0, 0.55)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.add_child(cc)
	var p := PanelContainer.new()
	p.custom_minimum_size.x = width
	cc.add_child(p)
	var v := _panel_box(p)
	v.add_theme_constant_override("separation", 12)
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
	var v := _modal(640)
	if who != "":
		v.add_child(UiTheme.label(who, 18, UiTheme.MUTED))
	v.add_child(UiTheme.wrap_label(title, 28, UiTheme.GOLD, 600))
	v.add_child(UiTheme.wrap_label(text, 19, UiTheme.TEXT, 600))
	var cc := CenterContainer.new()
	cc.add_child(UiTheme.button("Tamam", _close_modal, 200))
	v.add_child(cc)


## Giriş kartları: savaşın Türk tarihindeki yeri.
func play_intro(cards: Array, done: Callable) -> void:
	if cards.is_empty():
		done.call()
		return
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.015, 0.01, 0.92)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	_overlay = shade
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.add_child(cc)
	var v := VBoxContainer.new()
	v.custom_minimum_size.x = 820
	v.add_theme_constant_override("separation", 18)
	cc.add_child(v)
	var title := UiTheme.wrap_label("", 40, UiTheme.GOLD, 820)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var body := UiTheme.wrap_label("", 23, UiTheme.TEXT, 820)
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
	var v := _modal(860)
	v.add_child(UiTheme.label(sc.get("title", ""), 34, UiTheme.GOLD))
	v.add_child(UiTheme.label(sc.get("subtitle", ""), 18, UiTheme.MUTED))
	v.add_child(UiTheme.wrap_label(sc.get("briefing", ""), 18, UiTheme.TEXT, 820))
	var goals: Array = sc.get("goals", [])
	if not goals.is_empty():
		v.add_child(UiTheme.label("Hedefler", 20, UiTheme.GOLD))
		for g in goals:
			v.add_child(UiTheme.wrap_label("• " + String(g), 16, UiTheme.TEXT, 820))
	v.add_child(UiTheme.wrap_label("Kontroller: birliğe tıkla, sarı hücreye tıklayarak ilerlet, kırmızı hücreye tıklayarak saldır. Haritayı sürükleyerek kaydır, tekerlek ya da iki parmakla yakınlaş, sağ tuşla ya da Q/E ile döndür. Hücre üzerinde bekleyince bilgi ve saldırı tahmini görünür.", 14, UiTheme.MUTED, 820))
	var cc := CenterContainer.new()
	cc.add_child(UiTheme.button("Harekâta Başla", func() -> void:
		_close_modal()
		done.call(), 280))
	v.add_child(cc)


func show_deploy(d: Dictionary) -> void:
	_deploy = PanelContainer.new()
	_deploy.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_deploy.offset_left = -330
	_deploy.offset_right = 330
	_deploy.offset_top = 62
	add_child(_deploy)
	var v := _panel_box(_deploy)
	v.add_child(UiTheme.label(d.get("title", "Mayın döşeme"), 22, UiTheme.GOLD))
	v.add_child(UiTheme.wrap_label(d.get("text", ""), 15, UiTheme.TEXT, 640))
	_deploy_label = UiTheme.label("", 18, UiTheme.GOLD)
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
	var v := _modal(820)
	v.add_child(UiTheme.label("ZAFER" if won else "YENİLGİ", 44, UiTheme.GOLD if won else Color(0.9, 0.4, 0.35), HORIZONTAL_ALIGNMENT_CENTER))
	if won:
		var sr := StarRow.new(stars, 40.0)
		var c0 := CenterContainer.new()
		c0.add_child(sr)
		v.add_child(c0)
	if reason != "":
		v.add_child(UiTheme.wrap_label(reason, 19, UiTheme.TEXT, 780))
	for l in lines:
		v.add_child(UiTheme.label(l, 17, UiTheme.TEXT))
	v.add_child(UiTheme.label("Kayıplar: Osmanlı %s · İtilaf %s%s" % [_num(b.losses[Unit.OTTOMAN]), _num(b.losses[Unit.ENTENTE]),
		("  ·  Batan: " + ", ".join(b.sunk)) if not b.sunk.is_empty() else ""], 16, UiTheme.MUTED))
	if history != "":
		v.add_child(UiTheme.label("Tarihte ne oldu?", 20, UiTheme.GOLD))
		v.add_child(UiTheme.wrap_label(history, 16, UiTheme.TEXT, 780))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 14)
	row.add_child(UiTheme.button("Yeniden Oyna", func() -> void: get_tree().reload_current_scene(), 240))
	row.add_child(UiTheme.button("Ana Menü", func() -> void: get_tree().change_scene_to_file("res://scenes/main_menu.tscn"), 240))
	v.add_child(row)
	if won:
		Sfx.play("bugle", -4.0)


func _show_menu() -> void:
	if _overlay:
		return
	var v := _modal(420)
	v.add_child(UiTheme.label("Duraklatıldı", 30, UiTheme.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UiTheme.button("Devam", _close_modal, 380))
	v.add_child(UiTheme.button("Düşman hamleleri: " + ("Hızlı" if b.fast_ai else "Normal"), func() -> void:
		b.fast_ai = not b.fast_ai
		_close_modal()
		_show_menu(), 380))
	v.add_child(UiTheme.button("Yeniden Başla", func() -> void: get_tree().reload_current_scene(), 380))
	v.add_child(UiTheme.button("Ana Menü", func() -> void: get_tree().change_scene_to_file("res://scenes/main_menu.tscn"), 380))
