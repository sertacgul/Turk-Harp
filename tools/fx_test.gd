extends Node3D
## Geliştirme aracı: efektleri yakından görmek için test sahnesi.

var world: StraitWorld


func _ready() -> void:
	world = StraitWorld.new()
	add_child(world)
	world.build(false)
	var cam := Camera3D.new()
	add_child(cam)
	cam.position = Vector3(-300, 30, 0)
	cam.look_at_from_position(cam.position, Vector3(-450, 10, 10))
	var s := ShipBuilder.build_battleship("fr", 70.0, 13.0, 2)
	var r: Node3D = s["root"]
	add_child(r)
	r.position = Vector3(-470, 0, 40)
	r.rotation.y = 0.4
	for f in s["funnels"]:
		Fx.smoke_column(r, (f as Node3D).position, 0.14, 2.0, 18)
	Fx.fire(r, Vector3(-8, 8, 0), 1.3)
	Fx.smoke_column(r, Vector3(0, 10, 0), 0.08, 1.6, 26)


func boom() -> void:
	Fx.explosion(self, Vector3(-430, 4, -30), 1.2)
	Fx.water_splash(self, Vector3(-420, 0, 25), 1.0)
	Fx.muzzle_flash(self, Vector3(-360, 8, -20), Vector3(-1, 0.3, 0), 1.4)
