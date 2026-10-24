class_name Battle
extends Node3D
## Sıra tabanlı harekât: senaryo (data/scenarios/*.json) gerçek harita üzerinde oynanır.
## Her tur önce oyuncu (İttifak/Osmanlı), sonra yapay zekâ oynar; tur başında tarihî olaylar işler.

const WORLD_W := 120.0
const MONTHS := ["Ocak", "Şubat", "Mart", "Nisan", "Mayıs", "Haziran", "Temmuz", "Ağustos", "Eylül", "Ekim", "Kasım", "Aralık"]

var scenario: Dictionary
var geo: GeoMap
var grid: HexGrid
var map: ReliefMap
var mcam: MapCamera
var ui: BattleUI
var rng := RandomNumberGenerator.new()
var hex_m := 400.0
var hours := 1.0
var hex_world := 1.0
var units: Array[Unit] = []
var by_cell := {}
## ad -> {cell, vp, owner, objective}
var places := {}
var player_side := Unit.OTTOMAN
var ai_side := Unit.ENTENTE
var turn := 1
var turns := 12
var minutes := 60
var start_unix := 0
## intro, deploy, player, ai, over
var phase := "intro"
var selected: Unit
var reach := {}
var targets: Array[Vector2i] = []
var bayonet := false
var busy := false
var seen := {Unit.OTTOMAN: {}, Unit.ENTENTE: {}}
var losses := {Unit.OTTOMAN: 0, Unit.ENTENTE: 0}
var sunk: Array[String] = []
var mine_budget := 0
var mine_per_hex := 5
var mine_zone: Array[Vector2i] = []
var fast_ai := false
## Grafik yokken (test) animasyon ve beklemeler atlanır.
var instant := DisplayServer.get_name() == "headless" or OS.get_cmdline_user_args().has("instant=1")
## Bu tur süngü hücumlarına ek çarpan (ör. kamçı işareti)
var bayonet_boost := 1.0
var _los_cache := {}
var _fired := {}
var has_ships := false
var _mine_nodes := {}
var _fx: Node3D


func _ready() -> void:
	rng.randomize()
	var path := GameState.current_scenario
	for a in OS.get_cmdline_user_args():
		if a.begins_with("scenario="):
			path = a.substr(9)
	if path == "":
		path = "res://data/scenarios/ariburnu_1915.json"
	scenario = JSON.parse_string(FileAccess.open(path, FileAccess.READ).get_as_text())
	_build_world()
	_build_units()
	ui = BattleUI.new()
	var layer := CanvasLayer.new()
	add_child(layer)
	layer.add_child(ui)
	ui.setup(self)
	mcam.clicked.connect(_on_click)
	mcam.hovered.connect(_on_hover)
	update_vision(player_side)
	update_vision(ai_side)
	_refresh_map()
	Sfx.start_loop("sea", -26.0)
	ui.play_intro(scenario.get("intro", []), _after_intro)


func _exit_tree() -> void:
	Sfx.stop_all_loops()


func _build_world() -> void:
	geo = GeoMap.open(scenario.get("map", "gelibolu"))
	var r: Array = scenario["region"]
	geo.set_region(r[0], r[1], r[2], r[3])
	hex_m = float(scenario.get("hex_m", 400.0))
	grid = HexGrid.new()
	grid.setup(geo, hex_m)
	map = ReliefMap.new()
	add_child(map)
	map.build(geo, grid, WORLD_W, float(scenario.get("exaggeration", 2.5)), 300 if GameState.high_quality() else 200)
	ReliefMap.add_lighting(self, WORLD_W)
	hex_world = hex_m * map.s
	_fx = Node3D.new()
	add_child(_fx)
	minutes = int(scenario.get("minutes_per_turn", 60))
	hours = minutes / 60.0
	turns = int(scenario.get("turns", 12))
	start_unix = Time.get_unix_time_from_datetime_string(scenario.get("start", "1915-04-25T06:00:00"))
	player_side = scenario.get("player_side", Unit.OTTOMAN)
	ai_side = Unit.ENTENTE if player_side == Unit.OTTOMAN else Unit.OTTOMAN
	for p: Dictionary in scenario.get("places", []):
		var lp := geo.local(p["lat"], p["lon"])
		var c := grid.nearest(lp)
		var vp := int(p.get("vp", 0))
		places[p["name"]] = {"cell": c, "vp": vp, "owner": p.get("owner", ""), "objective": vp > 0}
		var cell := grid.cell(c)
		cell.place = p["name"]
		cell.vp = vp
		cell.owner = p.get("owner", "")
		map.add_place_label(p["name"], lp, 1.15 if vp > 0 else 0.9,
			Color(0.45, 0.05, 0.05) if vp > 0 else Color(0.16, 0.1, 0.06))
	for m: Dictionary in scenario.get("minefields", []):
		var c := grid.nearest(geo.local(m["lat"], m["lon"]))
		grid.cell(c).mines = int(m.get("mines", 5))
		grid.cell(c).mines_known = bool(m.get("known", true))
	var dep: Dictionary = scenario.get("deploy_mines", {})
	if not dep.is_empty():
		mine_budget = int(dep.get("mines", 26))
		mine_per_hex = int(dep.get("per_hex", 5))
		var z: Array = dep["zone"]
		var a := grid.nearest(geo.local(z[0], z[1]))
		var b := grid.nearest(geo.local(z[2], z[3]))
		for k: Vector2i in grid.cells:
			if k.x >= mini(a.x, b.x) and k.x <= maxi(a.x, b.x) and k.y >= mini(a.y, b.y) and k.y <= maxi(a.y, b.y) and grid.cell(k).is_sea():
				mine_zone.append(k)
	mcam = MapCamera.new()
	add_child(mcam)
	mcam.setup(map.world_size)
	var f: Array = scenario.get("focus", [])
	if f.size() >= 2:
		var fp := map.to_world(geo.local(f[0], f[1]))
		mcam.target = Vector3(fp.x, 0, fp.z)
		mcam._t_target = mcam.target
		if f.size() >= 3:
			mcam.dist = WORLD_W * float(f[2])
			mcam._t_dist = mcam.dist
	for k: Vector2i in grid.cells:
		_update_mine_marker(k)


func _build_units() -> void:
	for d: Dictionary in scenario.get("units", []):
		var u := Unit.from_dict(d)
		var lp := geo.local(d["lat"], d["lon"])
		u.arrive_cell = grid.nearest(lp)
		if u.goal_name != "":
			u.goal = place_cell(u.goal_name)
		for wp in d.get("waypoints", []):
			u.waypoints.append(_cell_of(wp))
		if d.has("plan"):
			u.set_meta("plan", d["plan"])
		if d.has("auto_goal"):
			u.set_meta("auto_goal", d["auto_goal"])
		units.append(u)
		if u.is_naval() and u.side != player_side:
			has_ships = true
		if u.state == "active":
			_place(u, u.arrive_cell)


## "Yer adı" ya da [enlem, boylam]
func _cell_of(v: Variant) -> Vector2i:
	if v is String:
		return place_cell(v)
	var a: Array = v
	return grid.nearest(geo.local(a[0], a[1]))


func place_cell(name_: String) -> Vector2i:
	if places.has(name_):
		return places[name_]["cell"]
	push_warning("Bilinmeyen yer: " + name_)
	return Vector2i(-1, -1)


## Birliği hücreye (doluysa en yakın uygun boş hücreye) yerleştirir ve pulunu oluşturur.
func _place(u: Unit, c: Vector2i) -> void:
	var best := c
	if not _can_stand(u, c):
		best = Vector2i(-1, -1)
		for rad in range(1, 8):
			for k in grid.within(c, rad):
				if _can_stand(u, k):
					best = k
					break
			if best != Vector2i(-1, -1):
				break
	if best == Vector2i(-1, -1):
		push_warning("Yer bulunamadı: " + u.name)
		u.state = "dead"
		return
	u.cell = best
	u.state = "active"
	by_cell[best] = u
	var ctr := UnitCounter.new()
	add_child(ctr)
	ctr.setup(u, hex_world)
	ctr.position = map.cell_world(best)
	u.counter = ctr


func _can_stand(u: Unit, c: Vector2i) -> bool:
	if not grid.has(c) or by_cell.has(c):
		return false
	var cell := grid.cell(c)
	return cell.is_sea() if u.is_naval() else cell.is_land()


func unit_at(c: Vector2i) -> Unit:
	return by_cell.get(c)


func enemy_of(side: String) -> String:
	return Unit.ENTENTE if side == Unit.OTTOMAN else Unit.OTTOMAN


## Zorluk: oyuncunun ve düşmanın ateş gücü çarpanı.
func power_mult(u: Unit) -> float:
	return GameState.diff("player_power") if u.side == player_side else GameState.diff("enemy_power")


func time_text(t := -1) -> String:
	var tt := turn if t < 0 else t
	var d := Time.get_datetime_dict_from_unix_time(start_unix + (tt - 1) * minutes * 60)
	return "%d %s %d · %02d:%02d" % [d["day"], MONTHS[int(d["month"]) - 1], d["year"], d["hour"], d["minute"]]


# --------------------------------------------------------------------- Görüş

func _eye(u: Unit) -> float:
	if u.is_fort():
		return 25.0
	if u.is_naval():
		return 22.0
	return 5.0


## İki hücre arasında görüş hattı (arazi örneklenir). Sonuç önbelleğe alınır.
func los(a: Vector2i, b: Vector2i, eye_a := 5.0, eye_b := 3.0) -> bool:
	var key := Vector4i(a.x, a.y, b.x, b.y)
	var k2 := "%s_%d" % [key, int(eye_a)]
	if _los_cache.has(k2):
		return _los_cache[k2]
	var ca := grid.cell(a)
	var cb := grid.cell(b)
	# Gözcü hücrenin en yüksek noktasında durur.
	var ha := maxf(ca.top, 0.0) + eye_a
	var hb := maxf(cb.elev, 0.0) + eye_b
	var n := HexGrid.distance(a, b) * 3
	var ok := true
	for i in range(1, n):
		var t := float(i) / n
		var p := ca.center.lerp(cb.center, t)
		if geo.height_local(p) > lerpf(ha, hb, t) + 1.0:
			ok = false
			break
	_los_cache[k2] = ok
	return ok


func update_vision(side: String) -> void:
	var s := {}
	for u in units:
		if not u.alive() or u.side != side:
			continue
		var c := grid.cell(u.cell)
		var r := u.vision + int(maxf(c.elev, 0.0) / 120.0)
		for k in grid.within(u.cell, r):
			if s.has(k):
				continue
			if HexGrid.distance(u.cell, k) <= 1 or los(u.cell, k, _eye(u)):
				s[k] = true
	seen[side] = s


func visible_to(u: Unit, side: String) -> bool:
	return u.side == side or seen[side].has(u.cell)


# --------------------------------------------------------------------- Hareket

func is_enemy_adjacent(u: Unit, c: Vector2i) -> bool:
	for n in grid.neighbors(c):
		var o := unit_at(n)
		if o and o.alive() and o.side != u.side and not o.is_naval() and not u.is_naval():
			return true
	return false


func move_cost(u: Unit, a: Vector2i, b: Vector2i) -> float:
	var cb := grid.cell(b)
	if u.is_naval():
		if not cb.is_sea():
			return INF
		if u.side == Unit.ENTENTE and cb.mines > 0 and cb.mines_known:
			return INF
		return 1.0
	if cb.is_sea():
		return INF
	var ca := grid.cell(a)
	var climb := maxf(0.0, cb.elev - ca.elev)
	return 1.0 + climb / (hex_m * 0.12) + cb.rough / (hex_m * 0.35)


## Dijkstra: hücre -> [maliyet, önceki]. Düşmana komşu hücreye girilir ama oradan devam edilmez.
func compute_reach(u: Unit, budget := -1.0, ignore_zoc := false) -> Dictionary:
	var mp := u.mp if budget < 0.0 else budget
	var out := {u.cell: [0.0, u.cell]}
	var open: Array = [[0.0, u.cell]]
	while not open.is_empty():
		var bi := 0
		for i in open.size():
			if open[i][0] < open[bi][0]:
				bi = i
		var cur: Array = open.pop_at(bi)
		var cc: Vector2i = cur[1]
		var cost: float = cur[0]
		if cost > out[cc][0]:
			continue
		if cc != u.cell and not ignore_zoc and is_enemy_adjacent(u, cc):
			continue
		for n in grid.neighbors(cc):
			var o := unit_at(n)
			if o and o.side != u.side:
				continue
			var mc := move_cost(u, cc, n)
			if mc == INF:
				continue
			var nc := cost + mc
			# İlk adım her zaman atılabilir (yavaş ilerleme)
			if nc > mp and not (cc == u.cell and mp >= 1.0 and nc <= mp + 1.5):
				continue
			if not out.has(n) or nc < out[n][0]:
				out[n] = [nc, cc]
				open.append([nc, n])
	return out


func path_from(r: Dictionary, to: Vector2i) -> Array[Vector2i]:
	var p: Array[Vector2i] = []
	var c := to
	while r.has(c) and r[c][1] != c:
		p.push_front(c)
		c = r[c][1]
	return p


func move_unit(u: Unit, path: Array[Vector2i]) -> void:
	if path.is_empty():
		return
	busy = true
	by_cell.erase(u.cell)
	var spent := 0.0
	var prev := u.cell
	for c in path:
		spent += move_cost(u, prev, c)
		# Oyuncunun görmediği düşman hareketleri beklemeden yapılır.
		var hidden: bool = u.side != player_side and not seen[player_side].has(c) and not seen[player_side].has(prev)
		if instant or hidden:
			u.counter.position = map.cell_world(c)
		else:
			var tw := create_tween()
			tw.tween_property(u.counter, "position", map.cell_world(c), 0.05 if fast_ai and u.side == ai_side else 0.09)
			await tw.finished
		prev = c
		u.cell = c
		if u.is_naval() and _check_mine(u, c):
			break
		if not u.alive():
			break
	if u.alive():
		by_cell[u.cell] = u
	u.mp = maxf(0.0, u.mp - spent)
	u.moved = true
	_update_control(u.cell)
	busy = false


## Gemi mayınlı hücreye girdi mi? Girdiyse hasar uygular; true dönerse hareket durur.
func _check_mine(u: Unit, c: Vector2i) -> bool:
	var cell := grid.cell(c)
	if cell.mines <= 0 or u.side == Unit.OTTOMAN:
		return false
	if rng.randf() > 0.45:
		return false
	cell.mines -= 1
	_update_mine_marker(c)
	var dmg := rng.randf_range(60.0, 115.0) * (0.75 if u.hp_max > 110.0 else 1.0)
	if u.kind == "sweeper":
		dmg = 100.0
	u.hp -= dmg
	var w := map.cell_world(c)
	fx_burst(w, "mine")
	Sfx.play("boom", -2.0)
	mcam.focus(w)
	log_line("%s mayına çarptı! (%s)" % [u.name, cell.place if cell.place != "" else "Boğaz"], Color(1.0, 0.6, 0.3))
	if instant:
		print("  T%d MINE %s dmg=%.0f hp=%.0f" % [turn, u.short, dmg, u.hp])
	if u.hp <= 0.0:
		_sink(u)
	else:
		u.morale -= 30.0
		u.counter.refresh()
	return true


func _sink(u: Unit) -> void:
	sunk.append(u.name)
	losses[u.side] += u.men
	log_line("%s battı! Mürettebatından %d kişi kayıp." % [u.name, u.men], UiTheme.GOLD)
	_kill(u)
	ui.popup("%s battı" % u.name, u.note if u.note != "" else "İtilaf donanması bir zırhlısını daha kaybetti.", "")


func _kill(u: Unit) -> void:
	if u.is_hq() and u.alive():
		log_line("%s vuruldu! Birlikler sarsıldı." % u.name, Color(1.0, 0.5, 0.4))
		for o in units:
			if o.alive() and o.side == u.side:
				o.morale = maxf(0.0, o.morale - 20.0)
	u.state = "dead"
	u.men = 0
	by_cell.erase(u.cell)
	if is_instance_valid(u.counter):
		var tw := create_tween()
		tw.tween_property(u.counter, "scale", Vector3(0.01, 0.01, 0.01), 0.5)
		tw.tween_callback(u.counter.queue_free)
	if selected == u:
		select(null)
	_run_triggers()


# --------------------------------------------------------------------- Muharebe

func attack_targets(u: Unit) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if u.attacked or u.suppressed > 0 or not u.alive():
		return out
	if u.can_melee() and u.morale >= 20.0:
		for n in grid.neighbors(u.cell):
			var o := unit_at(n)
			if o and o.side != u.side and not o.is_naval() and visible_to(o, u.side):
				out.append(n)
	var ranged := u.ranged_items()
	if not ranged.is_empty() and u.ammo > 0.0 and not (u.is_artillery() and u.moved):
		var rmax := u.max_range_m()
		for o in units:
			if not o.alive() or o.side == u.side or not visible_to(o, u.side) or out.has(o.cell):
				continue
			var d := Combat.dist_m(self, u.cell, o.cell)
			if d > rmax or d < 1.0:
				continue
			if u.ranged_power(o.uses_hp(), d) <= 0.0:
				continue
			if u.needs_los() and not los(u.cell, o.cell, _eye(u), _eye(o)):
				continue
			out.append(o.cell)
	return out


func is_melee(u: Unit, target: Vector2i) -> bool:
	return u.can_melee() and HexGrid.distance(u.cell, target) == 1 and not unit_at(target).is_naval()


## Saldırı tahmini (arayüz için).
func preview(u: Unit, target: Vector2i) -> Dictionary:
	var d := unit_at(target)
	if is_melee(u, target):
		return Combat.melee(self, u, d, bayonet and u.side == player_side, false)
	return Combat.ranged(self, u, d, false)


func attack(u: Unit, target: Vector2i, use_bayonet := false) -> void:
	var d := unit_at(target)
	if d == null:
		return
	busy = true
	u.attacked = true
	var aw := map.cell_world(u.cell)
	var dw := map.cell_world(target)
	if is_melee(u, target):
		var res := Combat.melee(self, u, d, use_bayonet)
		u.mp = 0.0
		u.men -= res["cas_att"]
		d.men -= res["cas_def"]
		losses[u.side] += res["cas_att"]
		losses[d.side] += res["cas_def"]
		u.losses += res["cas_att"]
		d.losses += res["cas_def"]
		u.morale = clampf(u.morale - res["mor_att"], 0.0, 100.0)
		d.morale = clampf(d.morale - res["mor_def"], 0.0, 100.0)
		u.ammo = maxf(0.0, u.ammo - (6.0 if use_bayonet else 16.0))
		d.ammo = maxf(0.0, d.ammo - 10.0)
		Sfx.play("rifle", -4.0)
		if use_bayonet:
			Sfx.play("bugle", -8.0)
			if u.side == Unit.OTTOMAN:
				Voice.shout("allah_allah", 6.0)
		fx_burst(dw, "rifle")
		fx_burst(aw.lerp(dw, 0.3), "rifle")
		if instant:
			print("  T%d %s -> %s odds=%.2f cas %d/%d ret=%s mor %d/%d" % [turn, u.short, d.short, res["odds"], res["cas_att"], res["cas_def"], res["retreat"], u.morale, d.morale])
		var verb := "süngü hücumu yaptı" if use_bayonet else "saldırdı"
		log_line("%s, %s birliğine %s: düşman kaybı %d, kendi kaybı %d." % [u.name, d.name, verb, res["cas_def"], res["cas_att"]],
			UiTheme.TEXT if u.side == player_side else Color(1.0, 0.75, 0.6))
		await _pause(0.2 if fast_ai and u.side == ai_side else 0.4)
		if d.men <= 0:
			log_line("%s dağıldı." % d.name, UiTheme.MUTED)
			_kill(d)
			await _advance(u, target)
		elif res["retreat"]:
			var ok := await _retreat(d, u.cell)
			if ok:
				await _advance(u, target)
	else:
		var res := Combat.ranged(self, u, d)
		if instant:
			print("  T%d %s => %s dist=%.1fkm dmg=%.1f cas=%d" % [turn, u.short, d.short, res["dist"] / 1000.0, res["dmg"], res["cas"]])
		u.ammo = maxf(0.0, u.ammo - 8.0)
		if u.is_artillery():
			u.mp = 0.0
		Sfx.play("cannon" if u.is_naval() or u.is_fort() else "far_boom", -6.0)
		await _pause(0.15)
		if d.is_naval() and rng.randf() < 0.3:
			fx_burst(dw + Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)) * hex_world * 0.5, "splash")
		fx_burst(dw, "shell" if not d.is_naval() else "hit")
		Sfx.play("boom", -10.0)
		if res["hard"]:
			d.hp -= res["dmg"]
			d.men -= res["cas"]
			losses[d.side] += res["cas"]
			d.morale = clampf(d.morale - res["mor"], 0.0, 100.0)
			var td := float(d.get_meta("turn_dmg", 0.0)) + float(res["dmg"])
			d.set_meta("turn_dmg", td)
			if d.is_fort() and td >= 6.0:
				d.suppressed = 1
			log_line("%s, %s hedefini dövdü: %%%d hasar%s." % [u.name, d.name, int(round(res["dmg"] / d.hp_max * 100.0)),
				" (tabya susturuldu)" if d.suppressed > 0 and d.is_fort() else ""],
				UiTheme.TEXT if u.side == player_side else Color(1.0, 0.75, 0.6))
			if d.hp <= 0.0:
				if d.is_naval():
					_sink(d)
				else:
					log_line("%s tahrip edildi." % d.name, UiTheme.GOLD)
					losses[d.side] += d.men
					_kill(d)
			elif d.is_naval() and d.retire_hp > 0.0 and d.hp < d.retire_hp and d.role != "retire":
				d.role = "retire"
				log_line("%s ağır hasarla savaştan çekiliyor." % d.name, UiTheme.GOLD)
		else:
			d.men -= res["cas"]
			d.losses += res["cas"]
			losses[d.side] += res["cas"]
			d.morale = clampf(d.morale - res["mor"], 0.0, 100.0)
			log_line("%s, %s birliğini ateş altına aldı: %d kayıp." % [u.name, d.name, res["cas"]],
				UiTheme.TEXT if u.side == player_side else Color(1.0, 0.75, 0.6))
			if d.men <= 0:
				_kill(d)
			elif d.morale < 15.0 and d.can_move():
				await _retreat(d, u.cell)
		await _pause(0.12 if fast_ai and u.side == ai_side else 0.3)
	for x in [u, d]:
		if x.alive() and is_instance_valid(x.counter):
			x.counter.refresh()
	update_vision(Unit.OTTOMAN)
	update_vision(Unit.ENTENTE)
	_run_triggers()
	busy = false
	if u.side == player_side:
		_refresh_map()
		ui.refresh()


func _pause(t: float) -> void:
	if instant:
		await get_tree().process_frame
	else:
		await get_tree().create_timer(t).timeout


## Savunan bir hücre geri çekilir; kaçacak yer yoksa esir düşer.
func _retreat(d: Unit, from: Vector2i) -> bool:
	if not d.can_move():
		return false
	var best := Vector2i(-1, -1)
	var bs := -INF
	for n in grid.neighbors(d.cell):
		if by_cell.has(n) or move_cost(d, d.cell, n) == INF:
			continue
		var sc := float(HexGrid.distance(n, from)) * 2.0 - (3.0 if is_enemy_adjacent(d, n) else 0.0) + rng.randf() * 0.3
		if sc > bs:
			bs = sc
			best = n
	if best == Vector2i(-1, -1) or bs < 0.0:
		log_line("%s kuşatıldı ve esir düştü (%d asker)." % [d.name, d.men], UiTheme.GOLD)
		losses[d.side] += d.men
		_kill(d)
		return true
	log_line("%s geri çekildi." % d.name, UiTheme.MUTED)
	d.entrench = 0
	var mp := d.mp
	d.mp = 9.0
	await move_unit(d, [best] as Array[Vector2i])
	d.mp = mp
	d.moved = true
	busy = true
	return true


## Boşalan hücreye saldıran ilerler.
func _advance(u: Unit, target: Vector2i) -> void:
	if not u.alive() or by_cell.has(target) or not u.can_move() or u.is_artillery():
		return
	if move_cost(u, u.cell, target) == INF:
		return
	var mp := u.mp
	u.mp = 9.0
	await move_unit(u, [target] as Array[Vector2i])
	u.mp = mp
	u.entrench = 0
	busy = true


# --------------------------------------------------------------------- Tur akışı

func _after_intro() -> void:
	if not mine_zone.is_empty() and mine_budget > 0:
		phase = "deploy"
		ui.show_briefing(scenario, func() -> void:
			ui.show_deploy(scenario.get("deploy_mines", {}))
			_refresh_map())
	else:
		ui.show_briefing(scenario, _start)


func finish_deploy() -> void:
	# Yerleştirilmeyen mayınlar tarihî hatta (önerilen hücrelere) dökülür.
	var hist: Array = (scenario.get("deploy_mines", {}) as Dictionary).get("historic", [])
	for h in hist:
		if mine_budget <= 0:
			break
		var c := _cell_of(h)
		if grid.has(c) and grid.cell(c).mines == 0:
			var n := mini(mine_per_hex, mine_budget)
			grid.cell(c).mines = n
			grid.cell(c).mines_known = false
			mine_budget -= n
			_update_mine_marker(c)
	_start()


func toggle_mine(c: Vector2i) -> void:
	if not mine_zone.has(c):
		return
	var cell := grid.cell(c)
	if cell.mines > 0:
		mine_budget += cell.mines
		cell.mines = 0
	elif mine_budget > 0:
		var n := mini(mine_per_hex, mine_budget)
		cell.mines = n
		cell.mines_known = false
		mine_budget -= n
		Sfx.play("mine_drop", -6.0)
	_update_mine_marker(c)
	ui.refresh()
	_refresh_map()


func _start() -> void:
	phase = "player"
	turn = 1
	_begin_turn()


func _begin_turn() -> void:
	for u in units:
		if u.state == "reserve" and u.arrive_turn <= turn:
			_place(u, u.arrive_cell)
			if u.alive() and u.side == player_side:
				log_line("%s harekât alanına ulaştı." % u.name, UiTheme.GOLD)
	for u in units:
		if not u.alive():
			continue
		u.mp = u.mp_max
		u.moved = false
		u.attacked = false
		u.dug = false
		var contact := is_enemy_adjacent(u, u.cell)
		if u.uses_hp():
			if u.is_fort():
				u.hp = minf(u.hp_max, u.hp + 2.0)
			u.ammo = minf(100.0, u.ammo + 6.0)
		else:
			u.ammo = minf(100.0, u.ammo + (4.0 if contact else 12.0) * hours)
		u.morale = minf(float(u.get_meta("morale_cap", 95.0)), u.morale + (2.0 if contact else 6.0))
		if is_instance_valid(u.counter):
			u.counter.refresh()
	# Karargâh yakınındaki birliklerin morali yükselir.
	for h in units:
		if h.alive() and h.is_hq():
			for o in units:
				if o.alive() and o.side == h.side and o != h and HexGrid.distance(o.cell, h.cell) <= 2:
					o.morale = minf(100.0, o.morale + 8.0)
	for u in units:
		u.set_meta("turn_dmg", 0.0)
	bayonet_boost = 1.0
	_run_events()
	update_vision(Unit.OTTOMAN)
	update_vision(Unit.ENTENTE)
	_update_all_control()
	phase = "player"
	select(null)
	_refresh_map()
	ui.refresh()
	ui.turn_banner(turn, turns, time_text())
	if fast_ai:
		debug_status()
	_check_end(false)


func end_turn() -> void:
	if phase != "player" or busy:
		return
	select(null)
	_end_side(player_side)
	phase = "ai"
	ui.refresh()
	await BattleAI.play(self, ai_side)
	_end_side(ai_side)
	if phase == "over":
		return
	if _check_end(false):
		return
	turn += 1
	if turn > turns:
		_check_end(true)
		return
	_begin_turn()


func _end_side(side: String) -> void:
	for u in units:
		if u.alive() and u.side == side:
			if u.suppressed > 0:
				u.suppressed -= 1
			# Yerinden kımıldamayan ve saldırmayan birlik siper kazar.
			if not u.moved and not u.attacked and u.is_land() and not u.is_fort() and u.entrench < 2:
				u.entrench += 1
			if is_instance_valid(u.counter):
				u.counter.refresh()


func _run_events() -> void:
	for e: Dictionary in scenario.get("events", []):
		if int(e.get("turn", -1)) == turn:
			_do_event(e)


func _run_triggers() -> void:
	var evs: Array = scenario.get("triggers", [])
	for i in evs.size():
		if _fired.has(i):
			continue
		var e: Dictionary = evs[i]
		var w: Dictionary = e.get("when", {})
		var ok := false
		if w.has("dead"):
			var u := find_unit(w["dead"])
			ok = u != null and u.state == "dead"
		elif w.has("hp_below"):
			var u2 := find_unit(w["hp_below"][0])
			ok = u2 != null and u2.alive() and u2.hp < float(w["hp_below"][1])
		elif w.has("owner"):
			ok = places.has(w["owner"][0]) and places[w["owner"][0]]["owner"] == w["owner"][1]
		elif w.has("turn_at_least"):
			ok = turn >= int(w["turn_at_least"])
		if ok:
			_fired[i] = true
			for a: Dictionary in e.get("do", []):
				_do_event(a)


func find_unit(id_: String) -> Unit:
	for u in units:
		if u.id == id_:
			return u
	return null


func _do_event(e: Dictionary) -> void:
	match e.get("type", "message"):
		"message":
			var who: String = e.get("who", "")
			log_line(("%s: %s" % [who, e["text"]]) if who != "" else String(e["text"]), UiTheme.GOLD if who != "" else UiTheme.TEXT)
			if e.get("popup", false):
				ui.popup(e.get("title", who), e["text"], who)
			if e.get("voice", false):
				Voice.speak(e["text"], "kemal" if who.contains("Mustafa Kemal") else "")
		"role":
			var ids: Array = e["units"] if e.has("units") else [e["unit"]]
			for id_ in ids:
				var u := find_unit(id_)
				if u:
					u.role = e.get("role", u.role)
					if e.has("goal"):
						u.goal_name = e["goal"]
						u.goal = place_cell(e["goal"])
		"morale":
			for u in units:
				if (e.has("side") and u.side == e["side"]) or (e.has("unit") and u.id == e["unit"]):
					u.morale = clampf(u.morale + float(e.get("add", 0.0)), 0.0, 100.0)
					if e.has("cap"):
						u.set_meta("morale_cap", float(e["cap"]))
		"ammo":
			var u3 := find_unit(e["unit"])
			if u3:
				u3.ammo = float(e.get("set", 100.0))
		"repair":
			var u4 := find_unit(e["unit"])
			if u4 and u4.alive():
				u4.hp = minf(u4.hp_max, u4.hp + float(e.get("hp", 20.0)))
				u4.suppressed = 0
				u4.ammo = 100.0
				if is_instance_valid(u4.counter):
					u4.counter.refresh()
		"sound":
			Sfx.play(e.get("sound", "bugle"), -6.0)
		"bayonet_bonus":
			bayonet_boost = float(e.get("mult", 1.3))
		"shout":
			Voice.shout(e.get("key", "allah_allah"), 1.0)


func _update_control(c: Vector2i) -> void:
	var cell := grid.cell(c)
	var u := unit_at(c)
	if u and u.is_land() and cell.place != "" and places.has(cell.place):
		if places[cell.place]["owner"] != u.side:
			places[cell.place]["owner"] = u.side
			cell.owner = u.side
			if places[cell.place]["objective"]:
				log_line("%s artık %s elinde." % [cell.place, "Osmanlı" if u.side == Unit.OTTOMAN else "İtilaf"],
					UiTheme.GOLD if u.side == player_side else Color(1.0, 0.5, 0.4))


func _update_all_control() -> void:
	for k: Vector2i in by_cell:
		_update_control(k)


## Bitiş denetimi. final: son tur bitti mi?
func _check_end(final: bool) -> bool:
	if phase == "over":
		return true
	var v: Dictionary = scenario.get("victory", {})
	var reason := ""
	for name_ in v.get("lose_if_enemy_reaches", []):
		var c := place_cell(name_)
		for k in grid.within(c, int(v.get("reach_radius", 0))):
			var u := unit_at(k)
			if u and u.side == ai_side:
				reason = "%s %s'na ulaştı." % [u.name, name_]
	if reason == "" and final:
		for name_ in v.get("lose_if_lost", []):
			if places.has(name_) and places[name_]["owner"] == ai_side:
				reason = "%s düşman eline geçti." % name_
	var alive_player := false
	for u in units:
		if u.side == player_side and (u.alive() or u.state == "reserve"):
			alive_player = true
	if not alive_player:
		reason = "Birliklerimiz dağıldı."
	if reason == "" and not final:
		return false
	phase = "over"
	var won := reason == ""
	var stars := 0
	var lines: Array[String] = []
	if won:
		stars = 1
		for st: Dictionary in v.get("stars", []):
			var ok := _star_ok(st)
			lines.append(("✔ " if ok else "✘ ") + String(st["text"]))
			if ok:
				stars += 1
		stars = mini(stars, 3)
		GameState.complete(scenario["id"], stars)
	ui.show_result(won, stars, reason, lines, scenario.get("history", ""))
	return true


func _star_ok(st: Dictionary) -> bool:
	if st.has("hold"):
		for n in st["hold"]:
			if not places.has(n) or places[n]["owner"] != player_side:
				return false
		return true
	if st.has("enemy_losses"):
		return losses[ai_side] >= int(st["enemy_losses"])
	if st.has("own_losses_below"):
		return losses[player_side] < int(st["own_losses_below"])
	if st.has("sunk"):
		return sunk.size() >= int(st["sunk"])
	if st.has("alive"):
		for id_ in st["alive"]:
			var u := find_unit(id_)
			if u == null or not u.alive():
				return false
		return true
	return false


# --------------------------------------------------------------------- Seçim ve tıklama

func select(u: Unit) -> void:
	if selected and is_instance_valid(selected.counter):
		selected.counter.set_selected(false)
	selected = u
	reach = {}
	targets = []
	if u:
		if is_instance_valid(u.counter):
			u.counter.set_selected(true)
		if u.side == player_side and phase == "player":
			if u.can_move() and u.mp > 0.0 and not u.attacked:
				reach = compute_reach(u)
			targets = attack_targets(u)
	_refresh_map()
	ui.show_unit(u)


func _pick(screen_pos: Vector2) -> Vector2i:
	var r := mcam.ray(screen_pos)
	return map.pick(r[0], r[1])


func _on_click(screen_pos: Vector2) -> void:
	if busy:
		return
	var c := _pick(screen_pos)
	if not grid.has(c):
		select(null)
		return
	if phase == "deploy":
		toggle_mine(c)
		return
	if phase != "player":
		return
	var u := unit_at(c)
	if selected and selected.side == player_side and targets.has(c):
		var me := selected
		await attack(me, c, bayonet and is_melee(me, c))
		bayonet = false
		if me.alive():
			select(me)
		else:
			select(null)
		_check_end(false)
		return
	if selected and selected.side == player_side and reach.has(c) and c != selected.cell and not by_cell.has(c):
		var me2 := selected
		await move_unit(me2, path_from(reach, c))
		update_vision(player_side)
		_refresh_map()
		select(me2)
		_check_end(false)
		return
	if u and (u.side == player_side or visible_to(u, player_side)):
		select(u)
	else:
		select(null)
		ui.show_cell(grid.cell(c))


func _on_hover(screen_pos: Vector2) -> void:
	if busy or phase == "intro":
		return
	var c := _pick(screen_pos)
	if not grid.has(c):
		ui.hover(null, null)
		return
	ui.hover(grid.cell(c), unit_at(c) if unit_at(c) and visible_to(unit_at(c), player_side) else null)


## Birliği seçip sıradaki hareket edebilecek birliğe geçer.
func next_unit() -> void:
	var mine: Array[Unit] = []
	for u in units:
		if u.alive() and u.side == player_side and not u.attacked and (u.mp > 0.0 or not attack_targets(u).is_empty()):
			if (u.can_move() and not u.moved) or not attack_targets(u).is_empty():
				mine.append(u)
	if mine.is_empty():
		return
	var i := mine.find(selected)
	var n := mine[(i + 1) % mine.size()]
	select(n)
	mcam.focus(map.cell_world(n.cell))


## Seçili birliğe bu tur siper kazdırır (hareket ve saldırı yapmaz).
func dig_in() -> void:
	if selected and selected.side == player_side and not selected.moved and not selected.attacked:
		selected.mp = 0.0
		selected.attacked = true
		selected.dug = true
		log_line("%s siper kazıyor." % selected.name, UiTheme.MUTED)
		select(selected)


# --------------------------------------------------------------------- Görsel

func _refresh_map() -> void:
	if map == null:
		return
	map.clear_marks()
	var ps: Dictionary = seen[player_side]
	for k: Vector2i in grid.cells:
		map.set_seen(k, ps.has(k) or phase == "deploy")
		var cell := grid.cell(k)
		if cell.vp > 0:
			map.set_control(k, 1 if cell.owner == Unit.OTTOMAN else (2 if cell.owner == Unit.ENTENTE else 0), true)
	if phase == "deploy":
		for k in mine_zone:
			map.mark(k, ReliefMap.MARK_MOVE if grid.cell(k).mines == 0 else ReliefMap.MARK_PATH)
	for k: Vector2i in reach:
		if k != (selected.cell if selected else Vector2i(-99, -99)) and not by_cell.has(k):
			map.mark(k, ReliefMap.MARK_MOVE)
	for k in targets:
		map.mark(k, ReliefMap.MARK_ATTACK)
	if selected:
		map.mark(selected.cell, ReliefMap.MARK_SELECTED)
	map.commit()
	for u in units:
		if u.alive() and is_instance_valid(u.counter):
			u.counter.visible = visible_to(u, player_side)


func _update_mine_marker(c: Vector2i) -> void:
	var cell := grid.cell(c)
	if _mine_nodes.has(c):
		(_mine_nodes[c] as Node3D).queue_free()
		_mine_nodes.erase(c)
	if cell.mines <= 0:
		return
	var root := Node3D.new()
	add_child(root)
	root.position = map.cell_world(c)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.08, 0.08, 0.08)
	mat.metallic = 0.6
	mat.roughness = 0.4
	for i in mini(cell.mines, 6):
		var m := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = hex_world * 0.07
		sm.height = sm.radius * 2.0
		m.mesh = sm
		m.material_override = mat
		m.position = Vector3((i - mini(cell.mines, 6) * 0.5 + 0.5) * hex_world * 0.17, sm.radius * 0.5, 0)
		root.add_child(m)
	root.rotation.y = 0.6
	_mine_nodes[c] = root


## Basit patlama/duman efekti.
func fx_burst(at: Vector3, kind: String) -> void:
	var m := MeshInstance3D.new()
	var sm := SphereMesh.new()
	var r: float = hex_world * {"rifle": 0.12, "shell": 0.28, "hit": 0.22, "splash": 0.18, "mine": 0.6}.get(kind, 0.2)
	sm.radius = r
	sm.height = r * 2.0
	m.mesh = sm
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var col: Color = {"rifle": Color(0.9, 0.88, 0.8, 0.7), "shell": Color(0.45, 0.36, 0.26, 0.85), "hit": Color(1.0, 0.6, 0.2, 0.9),
		"splash": Color(0.92, 0.96, 1.0, 0.85), "mine": Color(1.0, 0.55, 0.15, 0.95)}.get(kind, Color.WHITE)
	mat.albedo_color = col
	m.material_override = mat
	_fx.add_child(m)
	m.position = at + Vector3(0, r * 0.6, 0)
	m.scale = Vector3.ONE * 0.2
	if kind == "splash":
		m.scale = Vector3(0.3, 0.3, 0.3)
	var tw := create_tween().set_parallel(true)
	var grow := Vector3(1, 2.6, 1) if kind in ["splash", "mine"] else Vector3.ONE * 1.4
	tw.tween_property(m, "scale", grow, 0.45).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.9).set_delay(0.2)
	tw.chain().tween_callback(m.queue_free)


func log_line(text: String, color := UiTheme.TEXT) -> void:
	if ui:
		ui.add_log("[%s] %s" % [time_text().split(" · ")[1], text], color)


# --------------------------------------------------------------------- Test yardımcıları (tools/shot.gd)

func debug_skip_intro() -> void:
	Voice.stop()
	for c in ui.get_children():
		if c is ColorRect:
			c.queue_free()
	ui._overlay = null
	ui._popups.clear()
	if phase == "intro":
		if not mine_zone.is_empty():
			finish_deploy()
		else:
			_start()


## Oyuncu tarafını da yapay zekâ oynatır (denge testi).
func debug_autoplay() -> void:
	fast_ai = true
	while phase != "over":
		ui._popups.clear()
		if ui._overlay and phase != "over":
			ui._overlay.queue_free()
			ui._overlay = null
		if phase == "player":
			for u in units:
				if u.alive() and u.side == player_side and u.has_meta("auto_goal"):
					u.role = "attack"
					u.goal = place_cell(u.get_meta("auto_goal"))
			await BattleAI.play(self, player_side)
			await end_turn()
		else:
			await get_tree().process_frame
	debug_status()
	if instant:
		get_tree().quit()


func debug_status() -> void:
	var own := 0
	var en := 0
	for u in units:
		if u.alive():
			if u.side == player_side:
				own += 1
			else:
				en += 1
	var ps := []
	for n: String in places:
		if places[n]["objective"]:
			ps.append("%s=%s" % [n, places[n]["owner"]])
	print("STATUS turn=%d phase=%s losses=%s units own=%d enemy=%d sunk=%s places=%s" % [turn, phase, losses, own, en, sunk, ", ".join(ps)])


func debug_focus(name_: String) -> void:
	mcam.focus(map.cell_world(place_cell(name_)), WORLD_W * 0.35)


func debug_select_57() -> void:
	var u := find_unit("t1_57")
	select(u)
	mcam.focus(map.cell_world(u.cell), WORLD_W * 0.45)


func debug_view_front() -> void:
	ui._overlay = null
	for c in ui.get_children():
		if c is ColorRect:
			c.queue_free()
	mcam.focus(map.cell_world(place_cell("Cesaret Tepe")), WORLD_W * 0.42)


func debug_show_deploy() -> void:
	for c in ui.get_children():
		if c is ColorRect:
			c.queue_free()
	ui._overlay = null
	phase = "deploy"
	ui.show_deploy(scenario.get("deploy_mines", {}))
	mcam.focus(map.cell_world(mine_zone[mine_zone.size() / 2]), WORLD_W * 0.5)
	_refresh_map()


## Birkaç turu otomatik oynatır, sonra oyuncuya bırakır (ekran görüntüsü için).
func debug_auto_turns() -> void:
	fast_ai = true
	if phase == "deploy":
		ui._finish_deploy()
	for i in 4:
		ui._popups.clear()
		if ui._overlay:
			ui._overlay.queue_free()
			ui._overlay = null
		if phase != "player":
			break
		for u in units:
			if u.alive() and u.side == player_side and u.has_meta("auto_goal"):
				u.role = "attack"
				u.goal = place_cell(u.get_meta("auto_goal"))
		await BattleAI.play(self, player_side)
		await end_turn()
	ui._popups.clear()
	if ui._overlay:
		ui._overlay.queue_free()
		ui._overlay = null
	var first: Unit = null
	for u in units:
		if u.alive() and u.side == player_side and (u.is_fort() or u.kind == "infantry"):
			first = u
			break
	select(first)
	mcam.focus(map.cell_world(first.cell), WORLD_W * 0.5)
