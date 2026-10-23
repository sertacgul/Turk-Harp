class_name HumanRig
extends RefCounted
## HumanBuilder'ın ürettiği karakterin iskeletine yürüyüş, nişan, süngü ve dürbün pozları verir.

var kind := ""
var root: Node3D
var model: Node3D
var skeleton: Skeleton3D
var rifle: MeshInstance3D
var muzzle: Marker3D
var binoculars: Node3D
var walk := 0.0
## 0: tüfek hazır (göğüs önünde), 1: omuzda nişan.
var aiming_amount := 0.0
var _idx := {}


func _b(name: String) -> int:
	if not _idx.has(name):
		_idx[name] = skeleton.find_bone(name)
	return _idx[name]


func _rot(name: String, euler: Vector3) -> void:
	skeleton.set_bone_pose_rotation(_b(name), Quaternion.from_euler(euler))


## speed: yürüme hızı (m/s), aim: üst gövdenin yukarı/aşağı eğimi (radyan), jab: 0..1 süngü hamlesi.
## binocular: 0..1 dürbünü göze kaldırma (yalnızca Mustafa Kemal).
func apply_pose(speed: float, aim: float, jab: float, binocular := 0.0) -> void:
	var moving := speed > 0.3
	var amp := clampf(speed / 3.5, 0.0, 1.3)
	var s := sin(walk)
	var c := cos(walk)
	# Bacaklar: kalça salınımı, dizin yalnızca geriye bükülmesi, ayak bileği dengesi
	var swing := s * 0.55 * amp if moving else 0.0
	_rot("r_thigh", Vector3(swing, 0, 0))
	_rot("l_thigh", Vector3(-swing, 0, 0))
	var knee_r := maxf(0.0, -c) * 0.9 * amp if moving else 0.0
	var knee_l := maxf(0.0, c) * 0.9 * amp if moving else 0.0
	_rot("r_shin", Vector3(-knee_r - 0.05, 0, 0))
	_rot("l_shin", Vector3(-knee_l - 0.05, 0, 0))
	_rot("r_foot", Vector3(knee_r * 0.4, 0, 0))
	_rot("l_foot", Vector3(knee_l * 0.4, 0, 0))
	var bob := absf(c) * 0.03 * amp if moving else 0.0
	skeleton.set_bone_pose_position(_b("hips"), skeleton.get_bone_rest(_b("hips")).origin + Vector3(0, bob, 0))
	_rot("hips", Vector3(0, s * 0.08 * amp, 0))
	# Gövde: koşarken hafif öne eğik; nişan eğimi göğüse ve başa dağıtılır
	var lean := 0.12 * amp if moving else 0.0
	_rot("spine", Vector3(-lean + aim * 0.35, -s * 0.06 * amp, 0))
	_rot("chest", Vector3(aim * 0.45, 0, 0))
	_rot("head", Vector3(aim * 0.2, 0, 0))
	if kind == "kemal":
		_pose_kemal(binocular)
		return
	_pose_rifle(jab)


const UPPER_ARM := 0.28
const FOREARM := 0.25


## İki kemikli IK: omuzdan hedefe; dirsek pole yönüne doğru bükülür. Hepsi model uzayında.
func _reach(side: String, target: Vector3, pole: Vector3) -> void:
	var ua := _b(side + "upperarm")
	var fa := _b(side + "forearm")
	var sh := skeleton.get_bone_global_pose(ua).origin
	var to := target - sh
	var d := clampf(to.length(), 0.05, UPPER_ARM + FOREARM - 0.002)
	var u := to.normalized()
	var a := (UPPER_ARM * UPPER_ARM - FOREARM * FOREARM + d * d) / (2.0 * d)
	var h := sqrt(maxf(UPPER_ARM * UPPER_ARM - a * a, 0.0))
	var p := (pole - u * pole.dot(u)).normalized()
	var elbow := sh + u * a + p * h
	var hand := sh + u * d
	_aim_bone(ua, (elbow - sh).normalized())
	_aim_bone(fa, (hand - elbow).normalized())
	skeleton.set_bone_pose_rotation(_b(side + "hand"), Quaternion.IDENTITY)


## Kemiğin dinlenme yönü (aşağı, -Y) model uzayında dir'e baksın.
func _aim_bone(bone: int, dir: Vector3) -> void:
	var parent := skeleton.get_bone_parent(bone)
	var pg := skeleton.get_bone_global_pose(parent).basis
	var want := Basis(Quaternion(Vector3.DOWN, dir))
	skeleton.set_bone_pose_rotation(bone, (pg.inverse() * want).get_rotation_quaternion())


func _pose_rifle(jab: float) -> void:
	var chest := skeleton.get_bone_global_pose(_b("chest"))
	var up := aiming_amount
	# Göğüs uzayında tüfek: "hazır"da göğüs önünde çapraz, "nişan"da sağ omuzda ileri.
	var grip_local := Vector3(0.11, -0.2, -0.22).lerp(Vector3(0.12, 0.08, -0.2), up) + Vector3(0, 0, -0.35 * jab)
	var dir_local := Vector3(-0.3, 0.22, -1.0).normalized().slerp(Vector3(0.0, 0.0, -1.0), up)
	var grip := chest * grip_local
	var dir := (chest.basis * dir_local).normalized()
	var basis := Basis.looking_at(dir, Vector3.UP)
	if rifle:
		rifle.transform = Transform3D(basis, grip - basis * Vector3(0, 0, 0.17))
	var forend := grip + dir * 0.42 + basis * Vector3(0, -0.02, 0)
	_reach("r_", grip + basis * Vector3(0.0, -0.03, 0.0), Vector3(0.5, -1.0, 0.3))
	_reach("l_", forend, Vector3(-0.6, -1.0, 0.0))


func _pose_kemal(binocular: float) -> void:
	# Sağ el belde; dürbün kaldırılınca iki el göz hizasında.
	var head := skeleton.get_bone_global_pose(_b("head"))
	var hips := skeleton.get_bone_global_pose(_b("hips"))
	var eyes := head * Vector3(0, 0.11, -0.2)
	var rest_r := hips * Vector3(0.2, 0.0, -0.06)
	var rest_l := hips * Vector3(-0.24, -0.08, 0.02)
	_reach("r_", rest_r.lerp(eyes + Vector3(0.04, -0.02, 0), binocular), Vector3(1.0, -0.3, 0.4).lerp(Vector3(0.25, -1.0, 0.1), binocular))
	_reach("l_", rest_l.lerp(eyes + Vector3(-0.04, -0.02, 0), binocular), Vector3(-1.0, -0.3, 0.4).lerp(Vector3(-0.25, -1.0, 0.1), binocular))
	if binoculars:
		binoculars.visible = binocular > 0.6


## Ölüm: gövde arkaya düşer (0..1).
func fall(k: float) -> void:
	model.rotation.x = lerpf(0.0, PI / 2.0 * 0.95, k)
	model.position.y = lerpf(0.0, 0.2, k)


func reset_fall() -> void:
	model.rotation = Vector3.ZERO
	model.position = Vector3.ZERO
