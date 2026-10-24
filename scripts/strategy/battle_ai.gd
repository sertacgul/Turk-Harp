class_name BattleAI
extends RefCounted
## Yapay zekâ. Roller: attack (hedefe ilerle ve saldır), hold (yerini tut, siper kaz),
## naval (ara noktalar boyunca ilerle ve ateş et), sweep (bilinen mayınları tara), retire (çekil).


static func play(b: Battle, side: String) -> void:
	var order: Array[Unit] = []
	# Önce topçu ve gemiler ateş etsin, sonra piyade ilerlesin.
	for u in b.units:
		if u.alive() and u.side == side and (u.is_artillery() or u.is_fort() or u.is_naval()):
			order.append(u)
	for u in b.units:
		if u.alive() and u.side == side and not order.has(u):
			order.append(u)
	for u in order:
		if not u.alive() or b.phase == "over":
			continue
		if u.is_naval():
			await _naval(b, u)
		elif u.is_artillery() or u.is_fort():
			if u.stance != "normal" and u.stance != "defend":
				u.stance = "normal"
			await _fire_best(b, u)
		else:
			await _land(b, u)
	b.update_vision(Unit.OTTOMAN)
	b.update_vision(Unit.ENTENTE)
	b._refresh_map()


static func _best_target(b: Battle, u: Unit) -> Vector2i:
	var best := Vector2i(-1, -1)
	var bs := 0.0
	for t in b.attack_targets(u):
		var d := b.unit_at(t)
		if d == null or b.is_melee(u, t):
			continue
		var pr := b.preview(u, t)
		var sc := float(pr["dmg"]) * 3.0 + float(pr["cas"]) if pr["hard"] else float(pr["cas"]) + float(pr["mor"]) * 0.5
		# Tabya topları önce gemileri hedef alsın
		if d.is_naval():
			sc *= 1.5
		if sc > bs:
			bs = sc
			best = t
	return best


static func _fire_best(b: Battle, u: Unit) -> void:
	var t := _best_target(b, u)
	if t != Vector2i(-1, -1):
		await b.attack(u, t)


static func _melee_choice(b: Battle, u: Unit, min_odds: float) -> Vector2i:
	var best := Vector2i(-1, -1)
	var bo := min_odds
	for t in b.attack_targets(u):
		if not b.is_melee(u, t):
			continue
		var pr := b.preview(u, t)
		var o := float(pr["odds"])
		# Hedefe giden yoldaki düşmana öncelik
		if b.unit_at(t) and u.goal != Vector2i(-1, -1):
			o += 0.15 * maxf(0.0, HexGrid.distance(u.cell, u.goal) - HexGrid.distance(t, u.goal))
		if o > bo:
			bo = o
			best = t
	return best


static func _land(b: Battle, u: Unit) -> void:
	if u.side == b.ai_side:
		if u.is_hq():
			return
		_ai_stance(b, u)
	if u.stance in ["defend", "rest"]:
		return
	if u.morale < 22.0:
		await _fall_back(b, u)
		return
	var aggressive := u.role == "attack"
	var t := _melee_choice(b, u, 0.75 if aggressive else 1.8)
	if t != Vector2i(-1, -1):
		await b.attack(u, t)
		return
	if aggressive and u.goal != Vector2i(-1, -1) and u.can_move():
		var dest := _step_toward(b, u, u.goal)
		if dest != u.cell:
			var r := b.compute_reach(u)
			await b.move_unit(u, b.path_from(r, dest))
			b.update_vision(u.side)
			t = _melee_choice(b, u, 0.7)
			if t != Vector2i(-1, -1):
				await b.attack(u, t)
				return
	# Menzilli silahı varsa ateş et
	if not u.attacked and not u.ranged_items().is_empty():
		await _fire_best(b, u)


## Hedefe en kısa yol (hareket puanı sınırı olmadan) üzerinde bu tur ulaşılabilecek en ileri hücre.
static func _step_toward(b: Battle, u: Unit, goal: Vector2i) -> Vector2i:
	var r := b.compute_reach(u)
	var full := b.compute_reach(u, 999.0, true)
	var target := goal
	if not full.has(goal):
		# Hedef kapalı (düşman tutuyor): hedefe en yakın ulaşılabilir hücre
		var bd := 9999
		for k: Vector2i in full:
			var d := HexGrid.distance(k, goal)
			if d < bd:
				bd = d
				target = k
	var path := b.path_from(full, target)
	var best := u.cell
	for c in path:
		if r.has(c) and not b.by_cell.has(c):
			best = c
	return best


static func _fall_back(b: Battle, u: Unit) -> void:
	if not u.can_move():
		return
	var r := b.compute_reach(u)
	var best := u.cell
	var bs := _danger(b, u, u.cell)
	for k: Vector2i in r:
		if b.by_cell.has(k):
			continue
		var s := _danger(b, u, k)
		if s < bs:
			bs = s
			best = k
	if best != u.cell:
		await b.move_unit(u, b.path_from(r, best))


static func _danger(b: Battle, u: Unit, c: Vector2i) -> float:
	var s := 0.0
	for o in b.units:
		if o.alive() and o.side != u.side and o.is_land():
			s += 1.0 / maxf(1.0, float(HexGrid.distance(c, o.cell)))
	return s


static func _naval(b: Battle, u: Unit) -> void:
	if u.kind == "sweeper":
		await _sweep(b, u)
		return
	var goal := Vector2i(-1, -1)
	if u.role == "retire":
		goal = u.waypoints[-1] if not u.waypoints.is_empty() else u.arrive_cell
	elif not u.waypoints.is_empty():
		var idx := int(u.get_meta("wp", 0))
		# Plan: [ara nokta, tur] çiftleri senaryoda "plan" ile verilir; yoksa sırayla ilerler.
		var plan: Array = u.get_meta("plan", [])
		if not plan.is_empty():
			idx = 0
			for i in plan.size():
				if b.turn >= int(plan[i]):
					idx = i
		goal = u.waypoints[mini(idx, u.waypoints.size() - 1)]
	if goal != Vector2i(-1, -1) and u.cell != goal:
		var r := b.compute_reach(u)
		var full := b.compute_reach(u, 999.0, true)
		var path := b.path_from(full, goal)
		var dest := u.cell
		for c in path:
			if r.has(c) and not b.by_cell.has(c):
				dest = c
		if dest != u.cell:
			await b.move_unit(u, b.path_from(r, dest))
	if not u.alive():
		return
	var plan2: Array = u.get_meta("plan", [])
	var leaving := u.role == "retire" or (not plan2.is_empty() and b.turn >= int(plan2[-1]) and plan2.size() == u.waypoints.size())
	if leaving and not u.waypoints.is_empty() and HexGrid.distance(u.cell, u.waypoints[-1]) <= 1:
		u.state = "retired"
		b.by_cell.erase(u.cell)
		if is_instance_valid(u.counter):
			u.counter.queue_free()
		b.log_line("%s Boğaz'dan çıktı." % u.name, UiTheme.MUTED)
		return
	if u.role != "retire":
		await _fire_best(b, u)


## Mayın tarayıcı: bilinen mayınlı hücreye gider; ateş altında değilse tarar, ateş altındaysa geri döner.
static func _sweep(b: Battle, u: Unit) -> void:
	var under_fire := _threatened(b, u, u.cell)
	if under_fire and u.hp < u.hp_max * 0.8:
		var back := u.waypoints[0] if not u.waypoints.is_empty() else u.arrive_cell
		var r := b.compute_reach(u)
		var full := b.compute_reach(u, 999.0, true)
		var dest := u.cell
		for c in b.path_from(full, back):
			if r.has(c) and not b.by_cell.has(c):
				dest = c
		if dest != u.cell:
			b.log_line("%s ateş altında geri döndü." % u.name, UiTheme.MUTED)
			await b.move_unit(u, b.path_from(r, dest))
		return
	var cell := b.grid.cell(u.cell)
	for n in [u.cell] + b.grid.neighbors(u.cell):
		var nc := b.grid.cell(n)
		if nc.mines > 0 and nc.mines_known:
			if not under_fire:
				nc.mines = maxi(0, nc.mines - 2)
				b._update_mine_marker(n)
				b.log_line("%s %s mayın hattının bir kısmını taradı." % [u.name, nc.place if nc.place != "" else "Kepez"], Color(1.0, 0.7, 0.5))
			return
	# En yakın bilinen mayın hattına yanaş
	var best := Vector2i(-1, -1)
	var bd := 9999
	for k: Vector2i in b.grid.cells:
		var c := b.grid.cell(k)
		if c.mines > 0 and c.mines_known:
			var d := HexGrid.distance(u.cell, k)
			if d < bd:
				bd = d
				best = k
	if best == Vector2i(-1, -1) or cell == null:
		return
	var r2 := b.compute_reach(u)
	var dest2 := u.cell
	var bd2 := bd
	for k: Vector2i in r2:
		if b.by_cell.has(k):
			continue
		var d := HexGrid.distance(k, best)
		if d < bd2 and d >= 1:
			bd2 = d
			dest2 = k
	if dest2 != u.cell:
		await b.move_unit(u, b.path_from(r2, dest2))


static func _threatened(b: Battle, u: Unit, c: Vector2i) -> bool:
	for o in b.units:
		if not o.alive() or o.side == u.side or o.ranged_items().is_empty():
			continue
		var d := Combat.dist_m(b, o.cell, c)
		if d <= o.max_range_m() * 0.8 and b.seen[o.side].has(c):
			return true
	return false



## Yapay zekâ duruş seçimi: tutan birlik savunmada; çok yorgun ve temassız birlik dinlenir;
## düşmandan uzak taarruz birliği yürüyüş kolunda ilerler.
static func _ai_stance(b: Battle, u: Unit) -> void:
	if u.moved or u.attacked or u.is_hq():
		return
	var want := "normal"
	var near := b._enemy_near(u, 1)
	if u.role == "hold":
		want = "defend" if not near or u.morale < 60.0 else "normal"
	elif u.fatigue > 75.0 and not near:
		want = "rest"
	elif u.role == "attack" and not b._enemy_near(u, 3):
		want = "march"
	if want != u.stance:
		u.stance = want
		u.mp = u.effective_mp() if u.can_act_move() else 0.0
