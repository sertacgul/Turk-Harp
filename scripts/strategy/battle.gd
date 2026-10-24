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
## Kayıplar: ölü (Osmanlı için şehit), yaralı, esir
var cas := {Unit.OTTOMAN: {"dead": 0, "wounded": 0, "captured": 0}, Unit.ENTENTE: {"dead": 0, "wounded": 0, "captured": 0}}
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
## Emir verme kipi: "" ya da "attack" (hedef hücre bekleniyor)
var order_mode := ""
## Emir alayın bütün birliklerine mi verilsin
var order_group := false
var _arrows: Node3D
var _path_node: Node3D
var _enemy_moves: Array = []
var _obj_markers := {}
## Bu tur gelen birlikler ve yeni görülen düşmanlar (kurmay raporu için)
var arrivals: Array[String] = []
var _seen_enemy_ids := {}
var report: Array = []
var follow_enemy := true
## Emir puanı (komuta-kontrol): elle yönetilen her birlik ve verilen her emir puan harcar.
var cp := 0
var cp_max := 8
## İkmal noktaları: {name, cell, side, range}; ikmal ağı: taraf -> {hücre: maliyet}
var depots: Array = []
var supply_net := {Unit.OTTOMAN: {}, Unit.ENTENTE: {}}
var show_supply := false
var _roads: Node3D
## Düşman turunun özeti (kurmay raporu için)
var enemy_turn := {}
static var _soft_tex: GradientTexture2D


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
	Sfx.start_loop("battle_amb", -20.0)
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
	_arrows = Node3D.new()
	add_child(_arrows)
	_path_node = Node3D.new()
	add_child(_path_node)
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
		if vp == 0:
			map.add_place_label(p["name"], lp, 0.95, Color(0.16, 0.1, 0.06), p.get("minor", false))
	Terrain.classify(grid, hex_m)
	for p: Dictionary in scenario.get("places", []):
		if p.get("village", false):
			var vc := place_cell(p["name"])
			if grid.has(vc) and grid.cell(vc).is_land():
				grid.cell(vc).terrain = "köy"
	_roads = Node3D.new()
	add_child(_roads)
	for road: Array in scenario.get("roads", []):
		var rc := Terrain.mark_road(grid, geo, road)
		if rc.size() >= 2:
			var pts: Array[Vector3] = []
			for c in rc:
				pts.append(map.cell_world(c))
			_roads.add_child(_ribbon(pts, Color(0.42, 0.26, 0.12, 0.8), hex_m * map.s * 0.05))
	for dp: Dictionary in scenario.get("depots", []):
		var dc := grid.nearest(geo.local(dp["lat"], dp["lon"]))
		# Menzil kilometre olarak verilir; arazi maliyetine çevrilir (ortalama hücre maliyeti ~1,4).
		depots.append({"name": dp["name"], "cell": dc, "side": dp.get("side", Unit.OTTOMAN), "range": float(dp.get("range_km", 4.0)) * 1000.0 / hex_m * 1.4})
		map.add_place_label("⚑ " + String(dp["name"]), grid.cell(dc).center, 0.8,
			Color(0.1, 0.35, 0.1) if dp.get("side", Unit.OTTOMAN) == Unit.OTTOMAN else Color(0.15, 0.2, 0.45), true)
	cp_max = int(scenario.get("command_points", 8))
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
	for n: String in places:
		if places[n]["objective"]:
			_build_objective_marker(n)


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
		if u.side == player_side and (u.is_fort() or u.is_artillery()):
			u.order = "fire"
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
	var ctr := UnitMini.new()
	add_child(ctr)
	ctr.setup(u, hex_world)
	ctr.position = map.cell_world(best)
	# Birlik hedefine ya da haritanın ortasına dönük dursun.
	var look := map.cell_world(u.goal) if u.goal != Vector2i(-1, -1) else Vector3.ZERO
	ctr.face(Vector3(look.x - ctr.position.x, 0, look.z - ctr.position.z))
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


## n kişilik zayiatı ölü ve yaralı olarak ayırır (Birinci Dünya Savaşı'nda yaklaşık 1'e 2,3).
## Döndürülen: (ölü, yaralı).
func add_cas(side: String, n: int, captured := false, dead_ratio := 0.3) -> Vector2i:
	if n <= 0:
		return Vector2i.ZERO
	if captured:
		cas[side]["captured"] += n
		return Vector2i.ZERO
	var d := int(round(n * dead_ratio))
	cas[side]["dead"] += d
	cas[side]["wounded"] += n - d
	return Vector2i(d, n - d)


func losses_of(side: String) -> int:
	var c: Dictionary = cas[side]
	return int(c["dead"]) + int(c["wounded"]) + int(c["captured"])


## "12 şehit, 30 yaralı" (Osmanlı) ya da "12 ölü, 30 yaralı" (İtilaf)
static func cas_words(side: String, v: Vector2i) -> String:
	if v == Vector2i.ZERO:
		return "zayiat yok"
	return "%d %s, %d yaralı" % [v.x, "şehit" if side == Unit.OTTOMAN else "ölü", v.y]


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
			var dk := HexGrid.distance(u.cell, k)
			if dk <= 1:
				s[k] = true
				continue
			# Maki, dere ve köydeki birlikler ancak yakından ya da yukarıdan görülür.
			var tk := grid.cell(k)
			if Terrain.info(tk.terrain)["conceal"] and dk > 2 and c.top < tk.elev + 40.0:
				continue
			if los(u.cell, k, _eye(u)):
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
	var base: float = Terrain.info(cb.terrain)["move"]
	if cb.road and ca.road:
		base = 0.5
	var climb := maxf(0.0, cb.elev - ca.elev)
	var cost := base + climb / (hex_m * 0.12)
	if u.stance == "march":
		cost *= 0.8
	return cost


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
			# Yürüyüş kolundaki birlik düşmana temas eden hücreye giremez.
			if u.stance == "march" and not ignore_zoc and is_enemy_adjacent(u, n):
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
	var start := u.cell
	if not instant and (u.side == player_side or seen[player_side].has(start)):
		if u.is_naval():
			Sfx.play("horn", -16.0, 1.0)
		else:
			Sfx.play("march", -8.0)
	for c in path:
		spent += move_cost(u, prev, c)
		# Oyuncunun görmediği düşman hareketleri beklemeden yapılır.
		var hidden: bool = u.side != player_side and not seen[player_side].has(c) and not seen[player_side].has(prev)
		var mini := u.counter as UnitMini
		mini.face(map.cell_world(c) - map.cell_world(prev))
		if instant or hidden:
			u.counter.position = map.cell_world(c)
		else:
			var dur := 0.08 if fast_ai and u.side == ai_side else 0.16
			mini.march(dur)
			var tw := create_tween()
			tw.tween_property(u.counter, "position", map.cell_world(c), dur)
			await tw.finished
		prev = c
		u.cell = c
		# Mayına çarpan gemi durur (ama başka bir geminin hücresinde duramaz).
		if u.is_naval() and _check_mine(u, c) and not by_cell.has(c):
			break
		if not u.alive():
			break
	if u.alive():
		by_cell[u.cell] = u
	if u.side == ai_side and u.alive() and (seen[player_side].has(start) or seen[player_side].has(u.cell)) and start != u.cell:
		_enemy_moves.append([start, u.cell])
	u.mp = maxf(0.0, u.mp - spent)
	u.fatigue = minf(100.0, u.fatigue + spent * (2.5 if u.stance == "march" else 4.0))
	u.moved = true
	_update_control(u.cell)
	busy = false


## Gemi mayınlı hücreye girdi mi? Girdiyse hasar uygular; true dönerse hareket durur.
func _check_mine(u: Unit, c: Vector2i) -> bool:
	var cell := grid.cell(c)
	if cell.mines <= 0 or u.side == Unit.OTTOMAN:
		return false
	cell.mines -= 1
	# Patlamadan sonra bu hücredeki mayın hattı fark edilir; diğer gemiler buradan kaçınır.
	cell.mines_known = true
	_update_mine_marker(c)
	# Kesin hasar: bir mayın eski bir zırhlıyı neredeyse batırır.
	var dmg := 85.0 * (0.8 if u.hp_max > 110.0 else 1.0)
	if u.kind == "sweeper":
		dmg = 100.0
	u.hp -= dmg
	var crew := int(u.men * clampf(dmg / maxf(u.hp_max, 1.0), 0.0, 1.0) * 0.25)
	u.men -= crew
	if u.hp > 0.0:
		add_cas(u.side, crew, false, 0.5)
	var w := map.cell_world(c)
	fx_burst(w, "mine")
	float_text(w, "MAYIN!", false)
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
	var v := add_cas(u.side, u.men, false, 0.75)
	log_line("%s battı! Mürettebatından %d denizci öldü, %d yaralı kurtarıldı." % [u.name, v.x, v.y], UiTheme.GOLD)
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
	if u.can_melee() and u.morale >= 20.0 and u.can_act_attack():
		for n in grid.neighbors(u.cell):
			var o := unit_at(n)
			if o and o.side != u.side and not o.is_naval() and visible_to(o, u.side):
				out.append(n)
	var ranged := u.ranged_items()
	if not ranged.is_empty() and u.ammo > 0.0 and not (u.is_artillery() and u.moved) and u.stance in ["normal", "defend"]:
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
	var d := unit_at(target)
	return d != null and u.can_melee() and HexGrid.distance(u.cell, target) == 1 and not d.is_naval()


## Saldırı tahmini (arayüz için).
func preview(u: Unit, target: Vector2i) -> Dictionary:
	var d := unit_at(target)
	if d == null:
		return {"odds": 0.0, "cas_att": 0, "cas_def": 0, "retreat": false, "hard": false, "dmg": 0.0, "cas": 0, "mor": 0.0, "dist": 0.0}
	if is_melee(u, target):
		return Combat.melee(self, u, d, bayonet and u.side == player_side)
	return Combat.ranged(self, u, d)


func attack(u: Unit, target: Vector2i, use_bayonet := false) -> void:
	var d := unit_at(target)
	if d == null:
		return
	busy = true
	u.attacked = true
	var aw := map.cell_world(u.cell)
	var dw := map.cell_world(target)
	(u.counter as UnitMini).face(dw - aw)
	if HexGrid.distance(u.cell, target) == 1:
		(d.counter as UnitMini).face(aw - dw)
	# Düşman hamlesini oyuncuya göster
	if u.side == ai_side and follow_enemy and not instant and seen[player_side].has(target):
		if Vector2(mcam.target.x - dw.x, mcam.target.z - dw.z).length() > WORLD_W * 0.18:
			mcam.focus(dw)
			await _pause(0.35)
	if is_melee(u, target):
		var res := Combat.melee(self, u, d, use_bayonet)
		u.mp = 0.0
		u.men -= res["cas_att"]
		d.men -= res["cas_def"]
		var ca := add_cas(u.side, res["cas_att"])
		var cd := add_cas(d.side, res["cas_def"])
		u.losses += res["cas_att"]
		d.losses += res["cas_def"]
		u.morale = clampf(u.morale - res["mor_att"], 0.0, 100.0)
		d.morale = clampf(d.morale - res["mor_def"], 0.0, 100.0)
		u.ammo = maxf(0.0, u.ammo - u.ammo_cost("bayonet" if use_bayonet else "attack"))
		d.ammo = maxf(0.0, d.ammo - d.ammo_cost("defend"))
		u.fatigue = minf(100.0, u.fatigue + 15.0)
		d.fatigue = minf(100.0, d.fatigue + 6.0)
		_note_combat(u, d, res["cas_att"], res["cas_def"])
		Sfx.play("volley", -3.0)
		if u.equipment.has("maxim_1909") or u.equipment.has("maxim_303") or d.equipment.has("maxim_1909") or d.equipment.has("maxim_303"):
			Sfx.play("mg", -6.0)
		if use_bayonet:
			Sfx.play("whistle", -6.0)
			Sfx.play("crowd", -4.0)
			if u.side == Unit.OTTOMAN:
				Voice.shout("allah_allah", 6.0)
		fx_burst(dw, "rifle")
		fx_burst(aw.lerp(dw, 0.3), "rifle")
		if instant:
			print("  T%d %s -> %s odds=%.2f cas %d/%d ret=%s mor %d/%d" % [turn, u.short, d.short, res["odds"], res["cas_att"], res["cas_def"], res["retreat"], u.morale, d.morale])
		var verb := "süngü hücumu yaptı" if use_bayonet else "saldırdı"
		log_line("%s, %s birliğine %s. %s: %s · %s: %s" % [u.name, d.name, verb, u.short, cas_words(u.side, ca), d.short, cas_words(d.side, cd)],
			UiTheme.TEXT if u.side == player_side else Color(1.0, 0.75, 0.6))
		float_text(map.cell_world(target), cas_words(d.side, cd), d.side == player_side)
		float_text(map.cell_world(u.cell), cas_words(u.side, ca), u.side == player_side, 0.35)
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
		u.ammo = maxf(0.0, u.ammo - u.ammo_cost("fire"))
		if u.is_artillery():
			u.mp = 0.0
		_note_combat(u, d, 0, res["cas"])
		Sfx.play("cannon" if u.is_naval() or u.is_fort() else "far_boom", -6.0)
		fx_burst(aw + Vector3(0, hex_world * 0.25, 0), "muzzle")
		if not instant:
			Sfx.play("shell_whistle", -12.0)
		await shell_flight(aw + Vector3(0, hex_world * 0.3, 0), dw + Vector3(0, hex_world * 0.1, 0), not u.needs_los())
		if d.is_naval():
			fx_burst(dw + Vector3(0.6, 0, -0.4) * hex_world * 0.5, "splash")
		fx_burst(dw, "shell" if not d.is_naval() else "hit")
		Sfx.play("boom", -8.0)
		if d.is_naval():
			Sfx.play("splash", -12.0)
		if res["hard"]:
			d.hp -= res["dmg"]
			d.men -= res["cas"]
			var ch := add_cas(d.side, res["cas"])
			float_text(dw, "%%%d hasar" % int(round(res["dmg"] / d.hp_max * 100.0)) + ("" if ch == Vector2i.ZERO else " · " + cas_words(d.side, ch)), d.side == player_side)
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
					add_cas(d.side, d.men, false, 0.4)
					_kill(d)
			elif d.is_naval() and d.retire_hp > 0.0 and d.hp < d.retire_hp and d.role != "retire":
				d.role = "retire"
				log_line("%s ağır hasarla savaştan çekiliyor." % d.name, UiTheme.GOLD)
		else:
			d.men -= res["cas"]
			d.losses += res["cas"]
			d.suppression = minf(0.6, d.suppression + float(res["supp"]))
			var cs := add_cas(d.side, res["cas"])
			d.morale = clampf(d.morale - res["mor"], 0.0, 100.0)
			log_line("%s, %s birliğini ateş altına aldı: %s." % [u.name, d.name, cas_words(d.side, cs)],
				UiTheme.TEXT if u.side == player_side else Color(1.0, 0.75, 0.6))
			float_text(dw, cas_words(d.side, cs), d.side == player_side)
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
		var sc := float(HexGrid.distance(n, from)) * 2.0 - (3.0 if is_enemy_adjacent(d, n) else 0.0) + grid.cell(n).elev * 0.001
		if sc > bs:
			bs = sc
			best = n
	if best == Vector2i(-1, -1) or bs < 0.0:
		log_line("%s kuşatıldı ve esir düştü (%d asker)." % [d.name, d.men], UiTheme.GOLD)
		add_cas(d.side, d.men, true)
		float_text(map.cell_world(d.cell), "%d esir" % d.men, d.side == player_side)
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
	arrivals.clear()
	for u in units:
		if u.state == "reserve" and u.arrive_turn <= turn:
			_place(u, u.arrive_cell)
			if u.alive() and u.side == player_side:
				log_line("%s harekât alanına ulaştı." % u.name, UiTheme.GOLD)
				arrivals.append(u.name)
	_compute_supply(Unit.OTTOMAN)
	_compute_supply(Unit.ENTENTE)
	_compute_command(Unit.OTTOMAN)
	_compute_command(Unit.ENTENTE)
	for u in units:
		if not u.alive():
			continue
		u.moved = false
		u.attacked = false
		u.dug = false
		u.mp = u.effective_mp() if u.can_act_move() else 0.0
		var contact := is_enemy_adjacent(u, u.cell)
		_resupply(u, contact)
		var mor := 2.0 if contact else 6.0
		if u.stance == "rest":
			mor += 6.0
		if u.in_command and u.hq_id != "":
			mor += 2.0
		if not u.in_supply and u.out_supply_turns >= 2:
			mor -= 5.0
		u.morale = clampf(u.morale + mor, 0.0, float(u.get_meta("morale_cap", 95.0)))
		if is_instance_valid(u.counter):
			u.counter.refresh()
	cp = cp_max
	for u in units:
		u.set_meta("turn_dmg", 0.0)
	bayonet_boost = 1.0
	_run_events()
	update_vision(Unit.OTTOMAN)
	update_vision(Unit.ENTENTE)
	_update_all_control()
	phase = "player"
	select(null)
	_build_report()
	_refresh_map()
	_draw_orders()
	ui.refresh()
	ui.show_report(report)
	ui.turn_banner(turn, turns, time_text())
	if not instant:
		Sfx.play("bell", -8.0)
	if fast_ai:
		debug_status()
	_check_end(false)


func end_turn() -> void:
	if phase != "player" or busy:
		return
	select(null)
	order_mode = ""
	_clear_path()
	phase = "orders"
	ui.refresh()
	await _execute_orders()
	if phase == "over":
		return
	_end_side(player_side)
	phase = "ai"
	_enemy_moves.clear()
	enemy_turn = {"attacks": 0, "our": 0, "their": 0, "places": []}
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
			# Bastırma, birliğin kendi turunun sonunda kalkar.
			u.suppression = 0.0
			# Yerinden kımıldamayan ve saldırmayan birlik siper kazar; savunma duruşunda daha hızlı.
			var still := not u.moved and not u.attacked
			if still and u.is_land() and not u.is_fort() and grid.cell(u.cell).terrain != "kumsal":
				u.entrench = mini(u.entrench + (2 if u.stance == "defend" else 1), 3 if u.stance == "defend" else 2)
			# Yorgunluk toparlanması
			var rec := 3.0
			if u.stance == "rest":
				rec = 35.0
			elif still:
				rec = 15.0 if u.stance == "defend" else 12.0
			if not u.in_supply:
				rec *= 0.5
			u.fatigue = maxf(0.0, u.fatigue - rec)
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


## Hedefin şu anki durumu: ok (sağlanıyor), risk (tehlikede), text (ilerleme), fail_now (anında yenilgi).
func obj_eval(o: Dictionary) -> Dictionary:
	var t: String = o.get("type", "hold")
	var out := {"ok": false, "risk": false, "text": "", "fail_now": false}
	match t:
		"hold", "capture":
			var all_ok := true
			var risk := false
			var parts: Array[String] = []
			for n in o.get("places", []):
				if not places.has(n):
					continue
				var mine: bool = places[n]["owner"] == player_side
				all_ok = all_ok and mine
				var c: Vector2i = places[n]["cell"]
				for k in grid.within(c, 1):
					var e := unit_at(k)
					if e and e.side == ai_side and e.is_land() and visible_to(e, player_side):
						risk = true
				parts.append("%s %s" % [n, "elimizde" if mine else ("düşmanda" if places[n]["owner"] == ai_side else "boş")])
			out["ok"] = all_ok
			out["risk"] = risk or not all_ok
			out["text"] = ", ".join(parts)
		"losses":
			var n_ := losses_of(ai_side)
			out["ok"] = n_ >= int(o["count"])
			out["text"] = "%s / %s" % [BattleUI.num(n_), BattleUI.num(int(o["count"]))]
		"own_losses_below":
			var m_ := losses_of(player_side)
			out["ok"] = m_ < int(o["count"])
			out["risk"] = m_ > int(o["count"]) * 0.7
			out["text"] = "%s / %s" % [BattleUI.num(m_), BattleUI.num(int(o["count"]))]
		"sink":
			out["ok"] = sunk.size() >= int(o["count"])
			out["text"] = "%d / %d" % [sunk.size(), int(o["count"])]
		"alive":
			var ok := true
			var risk2 := false
			for id_ in o.get("units", []):
				var u := find_unit(id_)
				if u == null or not u.alive():
					ok = false
				elif u.uses_hp() and u.hp < u.hp_max * 0.5:
					risk2 = true
			out["ok"] = ok
			out["risk"] = risk2
			out["text"] = "ayakta" if ok else "kaybedildi"
			out["fail_now"] = not ok
		"deny":
			var ok2 := true
			var near := false
			for n in o.get("places", []):
				var c2 := place_cell(n)
				for k in grid.within(c2, int(o.get("radius", 1)) + 3):
					var e2 := unit_at(k)
					if e2 and e2.side == ai_side:
						if HexGrid.distance(k, c2) <= int(o.get("radius", 1)):
							ok2 = false
						else:
							near = true
			out["ok"] = ok2
			out["risk"] = near
			out["text"] = "geçit kapalı" if ok2 else "düşman geçti!"
			out["fail_now"] = not ok2
	return out


## Tur ve saat sınırı metni (ör. "19:00'a kadar · 8 tur kaldı")
func deadline_text() -> String:
	var d := Time.get_datetime_dict_from_unix_time(start_unix + (turns - 1) * minutes * 60)
	return "Son tur %02d:%02d · %d tur kaldı" % [d["hour"], d["minute"], maxi(0, turns - turn + 1)]


## Bitiş denetimi. final: son tur bitti mi?
func _check_end(final: bool) -> bool:
	if phase == "over":
		return true
	var reason := ""
	for o: Dictionary in scenario.get("objectives", []):
		if not o.get("required", false):
			continue
		var ev := obj_eval(o)
		if ev["fail_now"] or (final and not ev["ok"]):
			reason = "Zorunlu hedef sağlanamadı: %s" % o["text"]
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
	for o: Dictionary in scenario.get("objectives", []):
		var ok: bool = obj_eval(o)["ok"]
		lines.append(("✔ " if ok else "✘ ") + String(o["text"]) + ("" if o.get("required", false) else "  (yıldız)"))
		if won and ok and not o.get("required", false):
			stars += 1
	if won:
		stars = mini(stars + 1, 3)
		GameState.complete(scenario["id"], stars)
	_clear_arrows()
	ui.show_result(won, stars, reason, lines, scenario.get("history", ""))
	return true


# --------------------------------------------------------------------- Seçim ve tıklama

func select(u: Unit) -> void:
	if selected and is_instance_valid(selected.counter):
		selected.counter.set_selected(false)
	selected = u
	reach = {}
	targets = []
	if u and not instant and phase in ["player", "deploy"]:
		Sfx.play("select" if u.side == player_side else "paper", -6.0)
	if u:
		if is_instance_valid(u.counter):
			u.counter.set_selected(true)
		if u.side == player_side and phase == "player":
			if u.can_act_move() and u.mp > 0.0 and not u.attacked:
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
	if order_mode == "attack" and selected:
		_apply_order(selected, "attack", c)
		return
	_clear_path()
	var u := unit_at(c)
	if selected and selected.side == player_side and targets.has(c):
		if not spend_cp(selected):
			return
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
		if not spend_cp(selected):
			return
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
		_clear_path()
		return
	ui.hover(grid.cell(c), unit_at(c) if unit_at(c) and visible_to(unit_at(c), player_side) else null)
	if phase != "player" or selected == null or selected.side != player_side:
		return
	if order_mode == "attack":
		_show_path([selected.cell, c] as Array[Vector2i], Color(0.8, 0.1, 0.06, 0.6))
	elif targets.has(c):
		_show_path([selected.cell, c] as Array[Vector2i], Color(0.95, 0.15, 0.1, 0.8))
	elif reach.has(c) and c != selected.cell and not by_cell.has(c):
		var p: Array[Vector2i] = [selected.cell]
		p.append_array(path_from(reach, c))
		_show_path(p, Color(1.0, 0.82, 0.3, 0.85))
	else:
		_clear_path()


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
		if not spend_cp(selected):
			return
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
	if show_supply:
		var net: Dictionary = supply_net[player_side]
		for k: Vector2i in grid.cells:
			if grid.cell(k).is_land():
				map.mark(k, ReliefMap.MARK_SUPPLY if net.has(k) else ReliefMap.MARK_NOSUPPLY)
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
	_refresh_objectives()


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


## Patlama, duman, su sütunu ve tüfek ateşi efektleri (parçacıklarla).
func fx_burst(at: Vector3, kind: String) -> void:
	if instant:
		return
	var w := hex_world
	match kind:
		"rifle":
			# Bir hat boyunca çakan namlu ışıkları ve barut dumanı
			for i in 5:
				var o := Vector3(rng.randf_range(-0.3, 0.3), 0.15, rng.randf_range(-0.3, 0.3)) * w
				_particles(at + o, Color(1.0, 0.8, 0.4, 0.9), 2, w * 0.06, 0.15, 30.0, w * 0.1, true)
			_particles(at + Vector3(0, w * 0.1, 0), Color(0.86, 0.84, 0.78, 0.55), 10, w * 0.22, 1.6, 50.0, w * 0.25)
		"shell":
			_particles(at + Vector3(0, w * 0.05, 0), Color(1.0, 0.6, 0.2, 1.0), 8, w * 0.25, 0.35, 70.0, w * 0.6, true)
			_particles(at + Vector3(0, w * 0.1, 0), Color(0.36, 0.3, 0.24, 0.8), 16, w * 0.35, 2.4, 40.0, w * 0.8)
		"hit":
			_particles(at + Vector3(0, w * 0.15, 0), Color(1.0, 0.55, 0.15, 1.0), 10, w * 0.25, 0.4, 60.0, w * 0.5, true)
			_particles(at + Vector3(0, w * 0.2, 0), Color(0.12, 0.11, 0.1, 0.8), 18, w * 0.35, 3.0, 25.0, w * 0.9)
		"splash":
			_particles(at, Color(0.95, 0.97, 1.0, 0.9), 14, w * 0.14, 1.0, 12.0, w * 1.6)
		"mine":
			_particles(at, Color(0.95, 0.97, 1.0, 0.95), 30, w * 0.25, 1.6, 15.0, w * 2.6)
			_particles(at + Vector3(0, w * 0.2, 0), Color(1.0, 0.5, 0.15, 1.0), 12, w * 0.4, 0.5, 70.0, w * 0.8, true)
			_particles(at + Vector3(0, w * 0.3, 0), Color(0.15, 0.14, 0.13, 0.85), 24, w * 0.5, 4.0, 30.0, w * 1.2)
		"muzzle":
			_particles(at, Color(1.0, 0.8, 0.45, 1.0), 4, w * 0.18, 0.18, 25.0, w * 0.3, true)
			_particles(at, Color(0.82, 0.8, 0.76, 0.6), 8, w * 0.28, 1.8, 35.0, w * 0.4)


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
	print("STATUS turn=%d phase=%s losses=%s units own=%d enemy=%d sunk=%s places=%s" % [turn, phase, {"tr": losses_of(Unit.OTTOMAN), "en": losses_of(Unit.ENTENTE)}, own, en, sunk, ", ".join(ps)])


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


# --------------------------------------------------------------------- Emirler

## Arayüzden: "attack" hedef seçme kipini açar; diğerleri hemen uygulanır.
func give_order(kind: String) -> void:
	if selected == null or selected.side != player_side:
		return
	if kind == "attack":
		order_mode = "attack"
		ui.set_hint("Taarruz hedefini seç: haritada bir hücreye tıkla (Esc: vazgeç)")
		return
	_apply_order(selected, kind, Vector2i(-1, -1))


func _apply_order(u: Unit, kind: String, c: Vector2i) -> void:
	var group: Array[Unit] = [u]
	if order_group and u.regiment() != "":
		group = []
		for o in units:
			if o.alive() and o.side == player_side and o.regiment() == u.regiment() and not o.is_artillery():
				group.append(o)
	if kind != "":
		var cost := 0
		if group.size() > 1:
			cost = 1
			for o in group:
				if not o.in_command:
					cost += 1
		else:
			cost = cp_cost(u)
		if cp < cost:
			ui.set_hint("Emir puanı yetersiz (%d gerekli, %d var)." % [cost, cp])
			order_mode = ""
			return
		cp -= cost
	for o in group:
		o.order = kind
		o.order_cell = c
		o.order_name = ""
		if c != Vector2i(-1, -1):
			var cell := grid.cell(c)
			o.order_name = cell.place if cell.place != "" else "%.1f km ileri" % (Combat.dist_m(self, o.cell, c) / 1000.0)
	order_mode = ""
	ui.set_hint("")
	Sfx.play("paper", -6.0)
	Sfx.play("stamp", -4.0)
	if kind == "attack":
		Sfx.play("bugle", -14.0)
	log_line("%s: %s" % [u.regiment() + " (bütün birlikler)" if group.size() > 1 else u.name, u.order_title()], UiTheme.GOLD)
	_draw_orders()
	select(u)


## Tur sonunda, bu tur elle yönetilmemiş birlikler emirlerini uygular.
func _execute_orders() -> void:
	var list: Array[Unit] = []
	for u in units:
		if u.alive() and u.side == player_side and u.order != "" and not u.attacked:
			list.append(u)
	# Önce topçu ateşi, sonra piyade
	list.sort_custom(func(a: Unit, b: Unit) -> bool: return a.order == "fire" and b.order != "fire")
	for u in list:
		if not u.alive() or phase == "over":
			continue
		match u.order:
			"fire":
				if u.stance != "normal" and not u.moved:
					u.stance = "normal"
				if not (u.is_artillery() and u.moved):
					await BattleAI._fire_best(self, u)
			"reserve":
				if not u.moved and u.stance != "rest":
					u.stance = "rest"
					u.mp = 0.0
			"attack":
				# Astın inisiyatifi: düşmandan uzaktaysa yürüyüş kolunda hızlı ilerler, yaklaşınca açılır.
				if not u.moved:
					var want := "normal" if _enemy_near(u, 3) else "march"
					if u.stance != want:
						u.stance = want
						u.mp = u.effective_mp()
				if u.cell == u.order_cell or (by_cell.has(u.order_cell) and by_cell[u.order_cell].side == player_side and HexGrid.distance(u.cell, u.order_cell) <= 1):
					u.order = "defend"
					log_line("%s hedefine ulaştı; mevziyi savunuyor." % u.name, UiTheme.GOLD)
					continue
				var keep_role := u.role
				var keep_goal := u.goal
				u.role = "attack"
				u.goal = u.order_cell
				if u.moved:
					var t := BattleAI._melee_choice(self, u, 0.9)
					if t != Vector2i(-1, -1):
						await attack(u, t)
				else:
					await BattleAI._land(self, u)
				u.role = keep_role
				u.goal = keep_goal
			"defend":
				if not u.moved and u.stance != "defend":
					u.stance = "defend"
					u.mp = 0.0
	update_vision(player_side)
	_draw_orders()


# --------------------------------------------------------------------- Oklar

func _clear_arrows() -> void:
	for c in _arrows.get_children():
		c.queue_free()


func _clear_path() -> void:
	for c in _path_node.get_children():
		c.queue_free()


## Oyuncu emirleri (kırmızı taarruz okları) ve düşmanın son hareketleri (mavi oklar).
func _draw_orders() -> void:
	if _arrows == null:
		return
	_clear_arrows()
	for u in units:
		if u.alive() and u.side == player_side and u.order == "attack" and u.order_cell != Vector2i(-1, -1):
			_arrows.add_child(_arrow([map.cell_world(u.cell), map.cell_world(u.order_cell)], Color(0.75, 0.07, 0.05, 0.72), hex_world * 0.085, true))
	for mv in _enemy_moves:
		_arrows.add_child(_arrow([map.cell_world(mv[0]), map.cell_world(mv[1])], Color(0.12, 0.25, 0.65, 0.7), hex_world * 0.07, true))


## Yol önizlemesi (altın) ya da saldırı çizgisi (kırmızı)
func _show_path(cells: Array[Vector2i], col: Color) -> void:
	_clear_path()
	if cells.size() < 2:
		return
	var pts: Array[Vector3] = []
	for c in cells:
		pts.append(map.cell_world(c))
	_path_node.add_child(_arrow(pts, col, hex_world * 0.07, cells.size() == 2))


## Arazinin üstünden geçen şerit ok. curve: iki nokta arası kavisli (harekât oku) çizilsin mi.
func _arrow(pts: Array[Vector3], col: Color, w: float, curve: bool) -> MeshInstance3D:
	var samples: Array[Vector3] = []
	if curve and pts.size() == 2:
		var a := pts[0]
		var b := pts[1]
		var mid := (a + b) * 0.5
		var side := Vector3(-(b - a).z, 0, (b - a).x).normalized() * a.distance_to(b) * 0.12
		var ctrl := mid + side
		for i in 25:
			var t := i / 24.0
			samples.append(a.lerp(ctrl, t).lerp(ctrl.lerp(b, t), t))
	else:
		for i in pts.size() - 1:
			for j in 6:
				samples.append(pts[i].lerp(pts[i + 1], j / 6.0))
		samples.append(pts[-1])
	# Arazi yüksekliğine otur
	for i in samples.size():
		var lp := map.world_to_local(samples[i])
		samples[i] = map.to_world(lp, hex_world * 0.12)
	# Başlangıç ve uçta pulun altında kalmasın diye kısalt
	var total := 0.0
	for i in samples.size() - 1:
		total += samples[i].distance_to(samples[i + 1])
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var head := minf(w * 3.5, total * 0.4)
	var acc := 0.0
	var left: Array[Vector3] = []
	var right: Array[Vector3] = []
	var cut := samples.size() - 1
	for i in samples.size():
		var dir := (samples[mini(i + 1, samples.size() - 1)] - samples[maxi(i - 1, 0)])
		dir.y = 0.0
		dir = dir.normalized()
		var n := Vector3(-dir.z, 0, dir.x)
		var wi := w * (0.55 + 0.45 * clampf(acc / maxf(total * 0.3, 0.01), 0.0, 1.0))
		left.append(samples[i] + n * wi * 0.5)
		right.append(samples[i] - n * wi * 0.5)
		if i < samples.size() - 1:
			acc += samples[i].distance_to(samples[i + 1])
			if acc > total - head and cut == samples.size() - 1:
				cut = i + 1
	for i in cut:
		st.add_vertex(left[i])
		st.add_vertex(right[i])
		st.add_vertex(left[i + 1])
		st.add_vertex(right[i])
		st.add_vertex(right[i + 1])
		st.add_vertex(left[i + 1])
	# Ok ucu
	var tip := samples[-1]
	var base := samples[cut]
	var d2 := (tip - base)
	d2.y = 0.0
	var n2 := Vector3(-d2.normalized().z, 0, d2.normalized().x)
	st.add_vertex(base + n2 * w * 1.6)
	st.add_vertex(base - n2 * w * 1.6)
	st.add_vertex(tip)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = col
	m.render_priority = 1
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


# --------------------------------------------------------------------- Hedef işaretleri

## Hedef tepeye dikilen direk: sahibinin bayrağı, büyük ad ve tehlike halkası.
func _build_objective_marker(n: String) -> void:
	var root := Node3D.new()
	add_child(root)
	var c: Vector2i = places[n]["cell"]
	root.position = map.cell_world(c)
	var h := hex_world * 1.1
	var pole := MeshInstance3D.new()
	var pc := CylinderMesh.new()
	pc.top_radius = hex_world * 0.018
	pc.bottom_radius = hex_world * 0.025
	pc.height = h
	pole.mesh = pc
	pole.position = Vector3(hex_world * 0.3, h * 0.5, -hex_world * 0.2)
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.85, 0.66, 0.25)
	gm.metallic = 0.7
	gm.roughness = 0.35
	pole.material_override = gm
	root.add_child(pole)
	var fw := hex_world * 0.42
	var q := QuadMesh.new()
	q.size = Vector2(fw, fw * 2.0 / 3.0)
	q.subdivide_width = 10
	var fm := ShaderMaterial.new()
	fm.shader = load("res://shaders/flag.gdshader")
	fm.set_shader_parameter("amp", fw * 0.07)
	var flag := MeshInstance3D.new()
	flag.mesh = q
	flag.material_override = fm
	flag.position = pole.position + Vector3(fw * 0.5, h * 0.5 - fw / 3.0, 0)
	root.add_child(flag)
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = hex_world * 0.5
	tm.outer_radius = hex_world * 0.58
	ring.mesh = tm
	ring.scale = Vector3(1, 0.2, 1)
	var rm := StandardMaterial3D.new()
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rm.albedo_color = Color(1.0, 0.2, 0.15)
	rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring.material_override = rm
	ring.position.y = hex_world * 0.05
	ring.visible = false
	root.add_child(ring)
	var l := Label3D.new()
	l.text = "★ " + n
	l.font = UiTheme.font("map_bold")
	l.font_size = 50
	l.fixed_size = true
	l.pixel_size = 0.00045
	l.outline_size = 16
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.render_priority = 3
	l.outline_modulate = Color(0.98, 0.94, 0.84, 0.97)
	l.position = pole.position + Vector3(0, h * 0.62, 0)
	root.add_child(l)
	_obj_markers[n] = {"root": root, "flag": fm, "ring": ring, "label": l}


func _refresh_objectives() -> void:
	for n: String in _obj_markers:
		var mk: Dictionary = _obj_markers[n]
		var owner: String = places[n]["owner"]
		var nation := "tr" if owner == Unit.OTTOMAN else "uk"
		var occ := unit_at(places[n]["cell"])
		if owner == Unit.ENTENTE and occ and occ.side == Unit.ENTENTE:
			nation = (occ.counter as UnitMini).nation_key() if is_instance_valid(occ.counter) else "uk"
		(mk["flag"] as ShaderMaterial).set_shader_parameter("flag_texture", Flags.texture(nation) if owner != "" else Flags.texture("none"))
		var lbl: Label3D = mk["label"]
		lbl.modulate = Color(0.6, 0.04, 0.05) if owner == Unit.OTTOMAN else (Color(0.1, 0.18, 0.5) if owner == Unit.ENTENTE else Color(0.25, 0.22, 0.18))
		var threat := false
		for k in grid.within(places[n]["cell"], 1):
			var e := unit_at(k)
			if e and e.side != owner and owner != "" and e.is_land() and visible_to(e, player_side):
				threat = true
		(mk["ring"] as MeshInstance3D).visible = threat


func _process(_delta: float) -> void:
	# Tehlikedeki hedeflerin halkası nabız gibi atar.
	var a := 0.35 + 0.35 * sin(Time.get_ticks_msec() / 220.0)
	for n: String in _obj_markers:
		var ring: MeshInstance3D = _obj_markers[n]["ring"]
		if ring.visible:
			(ring.material_override as StandardMaterial3D).albedo_color.a = a
	if map and mcam:
		map.update_labels(mcam.dist)


# --------------------------------------------------------------------- Kurmay raporu

func _build_report() -> void:
	report = []
	var hints: Dictionary = scenario.get("hints", {})
	if hints.has(str(turn)):
		report.append(["Kurmay önerisi", String(hints[str(turn)]), UiTheme.GOLD])
	if not arrivals.is_empty():
		report.append(["Takviye", ", ".join(arrivals) + " cepheye ulaştı.", Color(0.7, 0.95, 0.7)])
	var new_enemy := 0
	for u in units:
		if u.alive() and u.side == ai_side and visible_to(u, player_side) and not _seen_enemy_ids.has(u.id):
			_seen_enemy_ids[u.id] = true
			new_enemy += 1
	if new_enemy > 0:
		report.append(["İstihbarat", "%d yeni düşman birliği görüldü. Mavi oklar düşmanın son hareketlerini gösterir." % new_enemy if turn > 1 else "%d düşman birliği görülüyor." % new_enemy, Color(0.65, 0.78, 1.0)])
	for o: Dictionary in scenario.get("objectives", []):
		var ev := obj_eval(o)
		if ev["risk"] and o.get("type", "") in ["hold", "capture", "deny", "alive"] and (o.get("required", false) or ev["ok"]):
			report.append(["Tehlike", "%s: %s" % [o["text"], ev["text"]], Color(1.0, 0.55, 0.45)])
	if int(enemy_turn.get("attacks", 0)) > 0:
		report.append(["Düşman hamlesi", "Düşman %d kez saldırdı. Birliklerimiz %s; düşman %s verdi." % [enemy_turn["attacks"],
			"%d zayiat" % int(enemy_turn["our"]), "%d zayiat" % int(enemy_turn["their"])], Color(1.0, 0.7, 0.55)])
	var no_sup: Array[String] = []
	var no_cmd: Array[String] = []
	var tired: Array[String] = []
	for u in units:
		if u.alive() and u.side == player_side:
			if not u.in_supply:
				no_sup.append(u.short)
			if not u.in_command:
				no_cmd.append(u.short)
			if u.fatigue >= 60.0:
				tired.append(u.short)
	if not no_sup.is_empty():
		report.append(["İkmal", "İkmal hattı dışında: %s. Cephane gelmez, moral düşer. İkmal haritasını aç (yeşil alan) ve hattı aç." % ", ".join(no_sup), Color(1.0, 0.6, 0.4)])
	if not no_cmd.is_empty():
		report.append(["Komuta", "Karargâh menzili dışında: %s. Güçleri %%15 düşük ve emirleri 2 puan. Karargâhı yaklaştır." % ", ".join(no_cmd), Color(1.0, 0.75, 0.5)])
	if not tired.is_empty():
		report.append(["Yorgunluk", "Çok yorgun: %s. Dinlenme duruşu ya da yedek emri ile toparla." % ", ".join(tired), Color(0.95, 0.85, 0.6)])
	var idle := 0
	var low_ammo: Array[String] = []
	for u in units:
		if u.alive() and u.side == player_side:
			if u.order == "" and u.can_move() and not u.is_hq():
				idle += 1
			if u.ammo < 25.0 and not u.uses_hp():
				low_ammo.append(u.short)
	if idle > 0:
		report.append(["Emir bekleyen", "%d birliğin emri yok. Bu tur %d emir puanın var: elle yönetilen her birlik ve verilen her emir 1 puan (karargâh menzili dışındaysa 2). Emirli birlikler tur sonunda puan harcamadan uygular." % [idle, cp], UiTheme.MUTED])
	if not low_ammo.is_empty():
		report.append(["Cephane", "Cephanesi azalan: %s. Geri çek ya da süngüyle saldır." % ", ".join(low_ammo), Color(1.0, 0.8, 0.45)])


# --------------------------------------------------------------------- Uçan yazılar ve efektler

func float_text(at: Vector3, text: String, own: bool, delay := 0.0) -> void:
	if instant or text == "" or text == "zayiat yok":
		return
	var l := Label3D.new()
	l.text = text
	l.font = UiTheme.font("bold")
	l.font_size = 34
	l.fixed_size = true
	l.pixel_size = 0.00045
	l.outline_size = 12
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.render_priority = 4
	l.modulate = Color(1.0, 0.42, 0.36) if own else Color(1.0, 0.93, 0.75)
	l.outline_modulate = Color(0.05, 0.03, 0.02, 0.95)
	l.position = at + Vector3(0, hex_world * 0.8, 0)
	l.modulate.a = 0.0
	_fx.add_child(l)
	var tw := create_tween()
	tw.tween_interval(delay)
	tw.tween_property(l, "modulate:a", 1.0, 0.15)
	tw.parallel().tween_property(l, "position:y", l.position.y + hex_world * 0.7, 1.8)
	tw.tween_property(l, "modulate:a", 0.0, 0.5)
	tw.tween_callback(l.queue_free)


static func soft_texture() -> GradientTexture2D:
	if _soft_tex:
		return _soft_tex
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	_soft_tex = GradientTexture2D.new()
	_soft_tex.gradient = g
	_soft_tex.fill = GradientTexture2D.FILL_RADIAL
	_soft_tex.fill_from = Vector2(0.5, 0.5)
	_soft_tex.fill_to = Vector2(1.0, 0.5)
	_soft_tex.width = 64
	_soft_tex.height = 64
	return _soft_tex


## Duman ve alev parçacıkları
func _particles(at: Vector3, col: Color, amount: int, size: float, life: float, spread: float, rise: float, additive := false) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.amount = amount
	p.lifetime = life
	p.explosiveness = 0.85
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.billboard_keep_scale = true
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = soft_texture()
	if additive:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	q.material = m
	p.mesh = q
	p.direction = Vector3.UP
	p.spread = spread
	p.initial_velocity_min = rise * 0.5
	p.initial_velocity_max = rise
	p.gravity = Vector3(0.0, -rise * 0.4, 0.0)
	p.damping_min = rise * 0.6
	p.damping_max = rise
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.4
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.4))
	curve.add_point(Vector2(1, 1.6))
	p.scale_amount_curve = curve
	var ramp := Gradient.new()
	ramp.set_color(0, col)
	ramp.set_color(1, Color(col.r, col.g, col.b, 0.0))
	p.color_ramp = ramp
	p.position = at
	_fx.add_child(p)
	p.emitting = true
	get_tree().create_timer(life + 0.5).timeout.connect(p.queue_free)


## Topçu mermisi: atan birlikten hedefe kavisli uçuş (iz bırakan parlak nokta).
func shell_flight(from: Vector3, to: Vector3, high: bool) -> void:
	if instant:
		return
	var s := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = hex_world * 0.04
	sm.height = sm.radius * 2.0
	s.mesh = sm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(1.0, 0.85, 0.5)
	s.material_override = m
	_fx.add_child(s)
	var peak := from.distance_to(to) * (0.35 if high else 0.12)
	var dur := clampf(from.distance_to(to) / (hex_world * 12.0), 0.25, 0.7)
	var tw := create_tween()
	tw.tween_method(func(t: float) -> void:
		var p := from.lerp(to, t)
		p.y += sin(t * PI) * peak
		s.position = p, 0.0, 1.0, dur)
	await tw.finished
	s.queue_free()


func debug_orders_demo() -> void:
	ui._popups.clear()
	if ui._overlay:
		ui._overlay.queue_free()
		ui._overlay = null
	var u := find_unit("t1_57")
	order_group = true
	select(u)
	_apply_order(u, "attack", place_cell("Cesaret Tepe"))
	order_group = false
	var h := find_unit("hq19")
	_apply_order(h, "attack", place_cell("Kocaçimen"))
	select(u)
	mcam.focus(map.cell_world(place_cell("Conkbayırı")) + Vector3(8, 0, 4), WORLD_W * 0.5)


func debug_closeup() -> void:
	var u := find_unit("t1_27") if find_unit("t1_27") and find_unit("t1_27").alive() else find_unit("mecidiye")
	select(u)
	mcam.focus(map.cell_world(u.cell), WORLD_W * 0.16)


func debug_ships() -> void:
	ui._popups.clear()
	if ui._overlay:
		ui._overlay.queue_free()
		ui._overlay = null
	var u := find_unit("bouvet") if find_unit("bouvet").alive() else find_unit("qe")
	if not u.alive():
		for o in units:
			if o.alive() and o.is_naval():
				u = o
	select(u)
	mcam.focus(map.cell_world(u.cell), WORLD_W * 0.22)


func debug_tutorial() -> void:
	Voice.stop()
	for c in ui.get_children():
		if c is ColorRect and c != ui.get_child(0):
			c.queue_free()
	ui._overlay = null
	ui.show_tutorial(_start)



# --------------------------------------------------------------------- Komuta, ikmal, emir puanı

## İkmal ağı: depolardan arazi üzerinden, düşman birliklerinin tuttuğu hücreler kapalı.
func _compute_supply(side: String) -> void:
	var net := {}
	var mine: Array = []
	for d: Dictionary in depots:
		if d["side"] == side:
			mine.append(d)
	if mine.is_empty():
		supply_net[side] = {}
		for u in units:
			if u.alive() and u.side == side:
				u.in_supply = true
				u.out_supply_turns = 0
		return
	for d: Dictionary in mine:
		var start: Vector2i = d["cell"]
		var occ := unit_at(start)
		if occ and occ.side != side:
			continue
		var best := {start: 0.0}
		var open: Array = [[0.0, start]]
		while not open.is_empty():
			var bi := 0
			for i in open.size():
				if open[i][0] < open[bi][0]:
					bi = i
			var cur: Array = open.pop_at(bi)
			var cc: Vector2i = cur[1]
			var cost: float = cur[0]
			if cost > best[cc]:
				continue
			for n in grid.neighbors(cc):
				var cn := grid.cell(n)
				if cn.is_sea():
					continue
				var o := unit_at(n)
				if o and o.side != side and o.is_land():
					continue
				var base: float = Terrain.info(cn.terrain)["move"]
				if cn.road and grid.cell(cc).road:
					base = 0.5
				var step := base + maxf(0.0, cn.elev - grid.cell(cc).elev) / (hex_m * 0.12)
				# Düşman ateşi altındaki hücreden ikmal güç geçer.
				for nb in grid.neighbors(n):
					var e := unit_at(nb)
					if e and e.side != side and e.is_land():
						step += 1.5
						break
				var nc := cost + step
				if nc > float(d["range"]):
					continue
				if not best.has(n) or nc < best[n]:
					best[n] = nc
					open.append([nc, n])
		for k: Vector2i in best:
			if not net.has(k) or best[k] < net[k]:
				net[k] = best[k]
	supply_net[side] = net
	for u in units:
		if not u.alive() or u.side != side:
			continue
		var ok: bool = u.is_naval() or u.is_fort() or net.has(u.cell)
		if not ok:
			for nb in grid.neighbors(u.cell):
				if net.has(nb):
					ok = true
					break
		u.in_supply = ok
		u.out_supply_turns = 0 if ok else u.out_supply_turns + 1


## Komuta: birlik bağlı olduğu karargâhın menzilindeyse komuta altındadır.
func _compute_command(side: String) -> void:
	for u in units:
		if not u.alive() or u.side != side:
			continue
		if u.hq_id == "" or u.is_hq():
			u.in_command = true
			continue
		var h := find_unit(u.hq_id)
		u.in_command = h != null and h.alive() and HexGrid.distance(h.cell, u.cell) <= h.command_range


## Tur başı ikmal: cephane yalnızca ikmal ağındaki birliklere gelir; tabyaların mermisi sınırlıdır.
func _resupply(u: Unit, contact: bool) -> void:
	if u.is_fort():
		u.hp = minf(u.hp_max, u.hp + 2.0)
		return
	if u.is_naval():
		u.ammo = minf(100.0, u.ammo + 4.0)
		return
	if not u.in_supply:
		return
	var depot_near := false
	for d: Dictionary in depots:
		if d["side"] == u.side and HexGrid.distance(d["cell"], u.cell) <= 1:
			depot_near = true
	var gain := 30.0 if depot_near else (6.0 if contact else 15.0)
	if u.is_artillery():
		gain *= 0.6
	u.ammo = minf(100.0, u.ammo + gain * hours)


func cp_cost(u: Unit) -> int:
	return 1 if u.in_command else 2


## Bu tur elle yönetilen birlik için emir puanı harcar (aynı birlik aynı tur bir kez öder).
func spend_cp(u: Unit) -> bool:
	if u.side != player_side or int(u.get_meta("cp_turn", -1)) == turn:
		return true
	var c := cp_cost(u)
	if cp < c:
		ui.set_hint("Emir puanı yetersiz (%d gerekli). Emirli birlikler tur sonunda puan harcamadan hareket eder." % c)
		Sfx.play("paper", -4.0)
		return false
	cp -= c
	u.set_meta("cp_turn", turn)
	ui.refresh()
	return true


## Duruş değişikliği (emir puanı harcar).
func set_stance(u: Unit, st: String) -> void:
	if u == null or u.side != player_side or u.stance == st or phase != "player":
		return
	if st in ["defend", "rest"] and (u.moved or u.attacked):
		ui.set_hint("Bu tur hareket eden ya da saldıran birlik savunma ya da dinlenme duruşuna geçemez.")
		return
	if not spend_cp(u):
		return
	var was := u.stance
	u.stance = st
	if st == "march" and was != "march" and not u.moved:
		u.mp = u.effective_mp()
	elif st in ["defend", "rest"]:
		u.mp = 0.0
	elif st == "normal" and was == "march":
		u.mp = minf(u.mp, u.effective_mp())
	log_line("%s: %s" % [u.name, u.stance_title()], UiTheme.GOLD)
	Sfx.play("stamp", -6.0)
	if is_instance_valid(u.counter):
		u.counter.refresh()
	select(u)


func _note_combat(att: Unit, def: Unit, ca: int, cd: int) -> void:
	if phase != "ai" or att.side != ai_side:
		return
	enemy_turn["attacks"] = int(enemy_turn.get("attacks", 0)) + 1
	enemy_turn["our"] = int(enemy_turn.get("our", 0)) + cd
	enemy_turn["their"] = int(enemy_turn.get("their", 0)) + ca


## Arazi üstünde düz şerit (yollar için).
func _ribbon(pts: Array[Vector3], col: Color, w: float) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var samples: Array[Vector3] = []
	for i in pts.size() - 1:
		for j in 4:
			samples.append(pts[i].lerp(pts[i + 1], j / 4.0))
	samples.append(pts[-1])
	for i in samples.size():
		samples[i] = map.to_world(map.world_to_local(samples[i]), hex_world * 0.04)
	for i in samples.size() - 1:
		var dir := samples[i + 1] - samples[i]
		dir.y = 0.0
		var n := Vector3(-dir.normalized().z, 0, dir.normalized().x) * w * 0.5
		# Kesik çizgi (patika)
		if i % 2 == 1:
			continue
		st.add_vertex(samples[i] + n)
		st.add_vertex(samples[i] - n)
		st.add_vertex(samples[i + 1] + n)
		st.add_vertex(samples[i] - n)
		st.add_vertex(samples[i + 1] - n)
		st.add_vertex(samples[i + 1] + n)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = col
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## Düşmanın gücü: yakındaysa kesin, uzaktaysa yuvarlanmış tahmin (gizli bilgi, şans değil).
func enemy_strength_text(u: Unit) -> String:
	if u.uses_hp():
		return "%%%d sağlam" % int(round(u.strength() * 100.0))
	var near := false
	for o in units:
		if o.alive() and o.side == player_side and HexGrid.distance(o.cell, u.cell) <= 1:
			near = true
			break
	if near or u.side == player_side:
		return "%d asker" % u.men
	return "~%d asker (tahmini)" % (int(round(u.men / 100.0)) * 100)



func _enemy_near(u: Unit, r: int) -> bool:
	for o in units:
		if o.alive() and o.side != u.side and o.is_land() and HexGrid.distance(o.cell, u.cell) <= r and visible_to(o, u.side):
			return true
	return false



func toggle_supply() -> void:
	show_supply = not show_supply
	_refresh_map()


func debug_preview() -> void:
	ui._popups.clear()
	if ui._overlay:
		ui._overlay.queue_free()
		ui._overlay = null
	for u in units:
		if u.alive() and u.side == player_side and u.can_melee() and not u.is_hq():
			select(u)
			for t in targets:
				if is_melee(u, t):
					mcam.focus(map.cell_world(u.cell), WORLD_W * 0.3)
					Input.warp_mouse(Vector2(560, 300))
					ui.hover(grid.cell(t), unit_at(t))
					return


func debug_oob() -> void:
	ui._popups.clear()
	if ui._overlay:
		ui._overlay.queue_free()
		ui._overlay = null
	ui.show_oob()


func debug_preview_auto() -> void:
	await debug_auto_turns()
	debug_preview()


func debug_print_preview() -> void:
	await debug_auto_turns()
	for u in units:
		if u.alive() and u.side == player_side and u.can_melee() and not u.is_hq():
			select(u)
			for t in targets:
				if is_melee(u, t):
					print("\n".join(ui._combat_lines(preview(u, t), u, unit_at(t))))
					var r := Combat.ranged(self, find_unit("dag_57"), unit_at(t)) if find_unit("dag_57") and find_unit("dag_57").alive() else {}
					if not r.is_empty():
						print("\n".join(ui._combat_lines(r, find_unit("dag_57"), unit_at(t))))
					get_tree().quit()
					return
	get_tree().quit()


func debug_supply_view() -> void:
	ui._popups.clear()
	if ui._overlay:
		ui._overlay.queue_free()
		ui._overlay = null
	show_supply = true
	_refresh_map()
	mcam.focus(Vector3(10, 0, 0), WORLD_W * 0.85)
