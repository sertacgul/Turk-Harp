extends Node3D
## Geliştirme aracı: karakterleri yakın planda görmek için test sahnesi.

var rigs: Array[HumanRig] = []
var t := 0.0
var cam: Camera3D


func _ready() -> void:
	var atm := Atmosphere.build(self, "day")
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(40, 40)
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.36, 0.38, 0.22)
	pm.material = gm
	ground.mesh = pm
	add_child(ground)
	var kinds := ["ottoman", "officer", "kemal", "anzac", "ottoman"]
	for i in kinds.size():
		var r := HumanBuilder.build(kinds[i])
		add_child(r.root)
		r.root.position = Vector3(-2.4 + i * 1.2, 0, 0)
		r.root.rotation.y = PI + 0.35
		rigs.append(r)
	cam = Camera3D.new()
	add_child(cam)
	cam.position = Vector3(0, 1.5, 4.2)
	cam.look_at(Vector3(0, 1.0, 0))


func _process(delta: float) -> void:
	t += delta
	for i in rigs.size():
		var r := rigs[i]
		if i == 4:
			r.walk += delta * 7.0
			r.apply_pose(3.5, 0.0, 0.0)
		elif r.kind == "kemal":
			r.apply_pose(0.0, 0.0, 0.0, 1.0 if fmod(t, 6.0) > 3.0 else 0.0)
		elif i == 3:
			r.aiming_amount = 1.0
			r.apply_pose(0.0, 0.0, 0.0)
		else:
			r.apply_pose(0.0, 0.1, 0.0)


func side() -> void:
	cam.position = Vector3(4.5, 1.4, 0.5)
	cam.look_at(Vector3(0, 1.0, 0))


func close() -> void:
	cam.position = Vector3(0.0, 1.65, 1.6)
	cam.look_at(Vector3(0, 1.55, 0))
