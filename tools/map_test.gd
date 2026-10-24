extends Node3D
## Harita testi: godot --path . res://tools/map_test.tscn -- region=lat0,lon0,lat1,lon1 hex=400 out=/tmp/x

func _ready() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=", true, 1)
		if kv.size() == 2:
			args[kv[0]] = kv[1]
	var geo := GeoMap.open("gelibolu")
	var r: PackedStringArray = String(args.get("region", "40.20,26.25,40.29,26.37")).split(",")
	geo.set_region(float(r[0]), float(r[1]), float(r[2]), float(r[3]))
	var grid := HexGrid.new()
	var t0 := Time.get_ticks_msec()
	grid.setup(geo, float(args.get("hex", "400")))
	var t1 := Time.get_ticks_msec()
	var map := ReliefMap.new()
	add_child(map)
	map.build(geo, grid, 120.0, float(args.get("exag", "2.5")))
	print("grid ", grid.cols, "x", grid.rows, " ", t1 - t0, "ms  map ", Time.get_ticks_msec() - t1, "ms")
	ReliefMap.add_lighting(self, 120.0)
	for n in [["Conkbayırı", 40.2520, 26.3086], ["Kocaçimen", 40.2593, 26.3199], ["Arıburnu", 40.2390, 26.2771], ["Kabatepe", 40.2067, 26.2680], ["Bigalı", 40.2357, 26.3597]]:
		var p := geo.local(n[1], n[2])
		map.add_place_label(n[0], p)
		var c := grid.at(p)
		if grid.has(c):
			map.set_control(c, 1, true)
	var c0 := grid.at(geo.local(40.2390, 26.2771))
	for c in grid.within(c0, 2):
		map.mark(c, ReliefMap.MARK_MOVE)
	map.mark(c0, ReliefMap.MARK_SELECTED)
	map.commit()
	var mc := MapCamera.new()
	add_child(mc)
	mc.setup(map.world_size)
	mc.yaw = float(args.get("yaw", "0"))
	mc._t_yaw = mc.yaw
	if args.has("dist"):
		mc.dist = float(args["dist"])
		mc._t_dist = mc.dist
	await get_tree().create_timer(1.5).timeout
	get_viewport().get_texture().get_image().save_png(String(args.get("out", "/tmp/map")) + ".png")
	get_tree().quit()
