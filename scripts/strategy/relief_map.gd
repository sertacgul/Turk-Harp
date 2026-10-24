class_name ReliefMap
extends Node3D
## Gerçek yükseklik verisinden harekât masası: kabartma ağ, ahşap masa, yer adları ve
## altıgen vurguları (hex_tex). Dünya birimi: harita world_width birim genişlikte, merkez (0, 0, 0).

const MARK_NONE := 0
const MARK_MOVE := 1
const MARK_ATTACK := 2
const MARK_SELECTED := 3
const MARK_PATH := 4

var geo: GeoMap
var grid: HexGrid
## Metreden dünya birimine yatay ölçek ve düşey (abartılı) ölçek
var s := 0.01
var v := 0.025
var world_size := Vector2.ONE
var mat: ShaderMaterial
var hex_img: Image
var hex_tex: ImageTexture
var _labels := Node3D.new()


## exaggeration: düşey abartma (gerçek ölçeğe göre kat)
func build(a_geo: GeoMap, a_grid: HexGrid, world_width := 120.0, exaggeration := 2.5, mesh_res := 320) -> void:
	geo = a_geo
	grid = a_grid
	s = world_width / geo.width_m
	v = s * exaggeration
	world_size = Vector2(geo.width_m, geo.height_m) * s
	var nx := mesh_res if geo.width_m >= geo.height_m else int(mesh_res * geo.width_m / geo.height_m)
	var nz := int(nx * geo.height_m / geo.width_m)
	var tex_res := Vector2i(nx * 2, nz * 2)
	var himg := _height_and_shore(tex_res)
	_build_mesh(himg, nx, nz)
	_build_table()
	mat.set_shader_parameter("height_tex", ImageTexture.create_from_image(himg))
	mat.set_shader_parameter("map_size_m", Vector2(geo.width_m, geo.height_m))
	mat.set_shader_parameter("world_size", world_size)
	mat.set_shader_parameter("hex_radius", grid.radius)
	mat.set_shader_parameter("hex_origin", grid.origin)
	mat.set_shader_parameter("hex_count", Vector2(grid.cols, grid.rows))
	var relief := 0.0
	for c: HexGrid.Cell in grid.cells.values():
		relief = maxf(relief, c.top)
	mat.set_shader_parameter("contour_step", 10.0 if relief < 200.0 else 20.0)
	hex_img = Image.create(grid.cols, grid.rows, false, Image.FORMAT_RGBA8)
	hex_img.fill(Color(0, 0, 1, 0))
	hex_tex = ImageTexture.create_from_image(hex_img)
	mat.set_shader_parameter("hex_tex", hex_tex)
	add_child(_labels)


## R: yükseklik, G: kıyıya uzaklık (metre). Uzaklık iki geçişli pah (chamfer) dönüşümüyle bulunur.
func _height_and_shore(res: Vector2i) -> Image:
	var hm := geo.region_image(res.x, res.y)
	var n := res.x * res.y
	var dist := PackedFloat32Array()
	dist.resize(n)
	var hv := PackedFloat32Array()
	hv.resize(n)
	for j in res.y:
		for i in res.x:
			var e := hm.get_pixel(i, j).r
			hv[j * res.x + i] = e
			dist[j * res.x + i] = 0.0 if e > 0.4 else 1e9
	var px := geo.width_m / res.x
	var diag := px * 1.4142
	for j in res.y:
		for i in res.x:
			var k := j * res.x + i
			var d := dist[k]
			if i > 0:
				d = minf(d, dist[k - 1] + px)
			if j > 0:
				d = minf(d, dist[k - res.x] + px)
				if i > 0:
					d = minf(d, dist[k - res.x - 1] + diag)
				if i < res.x - 1:
					d = minf(d, dist[k - res.x + 1] + diag)
			dist[k] = d
	for j in range(res.y - 1, -1, -1):
		for i in range(res.x - 1, -1, -1):
			var k := j * res.x + i
			var d := dist[k]
			if i < res.x - 1:
				d = minf(d, dist[k + 1] + px)
			if j < res.y - 1:
				d = minf(d, dist[k + res.x] + px)
				if i < res.x - 1:
					d = minf(d, dist[k + res.x + 1] + diag)
				if i > 0:
					d = minf(d, dist[k + res.x - 1] + diag)
			dist[k] = d
	var img := Image.create(res.x, res.y, false, Image.FORMAT_RGF)
	for j in res.y:
		for i in res.x:
			var k := j * res.x + i
			img.set_pixel(i, j, Color(hv[k], minf(dist[k], 60000.0), 0))
	return img


func _build_mesh(himg: Image, nx: int, nz: int) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hw := himg.get_width()
	var hh := himg.get_height()
	for j in nz + 1:
		for i in nx + 1:
			var u := float(i) / nx
			var t := float(j) / nz
			var e := himg.get_pixel(mini(int(u * hw), hw - 1), mini(int(t * hh), hh - 1)).r
			st.set_uv(Vector2(u, t))
			st.add_vertex(Vector3((u - 0.5) * world_size.x, _vis(e), (t - 0.5) * world_size.y))
	for j in nz:
		for i in nx:
			var a := j * (nx + 1) + i
			for k in [a, a + 1, a + nx + 1, a + 1, a + nx + 2, a + nx + 1]:
				st.add_index(k)
	st.generate_normals()
	mat = ShaderMaterial.new()
	mat.shader = load("res://shaders/relief_map.gdshader")
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = mat
	add_child(mi)


## Görsel yükseklik: deniz düz, kara abartılı.
func _vis(e: float) -> float:
	return maxf(e, 0.0) * v - (0.04 if e <= 0.4 else 0.0)


## Haritanın oturduğu kaide ve ahşap masa.
func _build_table() -> void:
	var base := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(world_size.x + 0.6, 1.2, world_size.y + 0.6)
	base.mesh = bm
	base.position.y = -0.7
	var plaster := StandardMaterial3D.new()
	plaster.albedo_color = Color(0.32, 0.24, 0.17)
	plaster.roughness = 0.7
	base.material_override = plaster
	add_child(base)
	var table := MeshInstance3D.new()
	var tm := BoxMesh.new()
	tm.size = Vector3(world_size.x * 1.7, 0.6, world_size.y * 1.7)
	table.mesh = tm
	table.position.y = -1.5
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.2, 0.12, 0.07)
	wood.roughness = 0.55
	var nt := NoiseTexture2D.new()
	var fn := FastNoiseLite.new()
	fn.frequency = 0.004
	fn.fractal_octaves = 3
	nt.noise = fn
	nt.width = 512
	nt.height = 512
	nt.seamless = true
	wood.albedo_texture = nt
	wood.uv1_scale = Vector3(1.0, 8.0, 1.0)
	table.material_override = wood
	add_child(table)


## Yerel metre -> dünya (yüzeyin hemen üstü).
func to_world(p: Vector2, lift := 0.0) -> Vector3:
	return Vector3(p.x * s - world_size.x * 0.5, _vis(geo.height_local(p)) + lift, p.y * s - world_size.y * 0.5)


func cell_world(c: Vector2i, lift := 0.0) -> Vector3:
	var cell := grid.cell(c)
	var p := to_world(cell.center, lift)
	# Pul, hücrenin ortalama yüksekliğinde dursun (tepe noktasında havada kalmasın).
	p.y = maxf(_vis(cell.elev), _vis(geo.height_local(cell.center))) + lift
	return p


func world_to_local(w: Vector3) -> Vector2:
	return Vector2((w.x + world_size.x * 0.5) / s, (w.z + world_size.y * 0.5) / s)


## Kamera ışınının harita yüzeyine değdiği hücre (ışın yürütme); yoksa Vector2i(-1, -1).
func pick(from: Vector3, dir: Vector3) -> Vector2i:
	var t := 0.0
	var step := world_size.x / 600.0
	var prev := from
	for i in 3000:
		var p := from + dir * t
		if p.y < -2.0:
			break
		var lp := world_to_local(p)
		if lp.x >= 0.0 and lp.y >= 0.0 and lp.x <= geo.width_m and lp.y <= geo.height_m:
			if p.y <= _vis(geo.height_local(lp)):
				var c := grid.at(world_to_local(prev.lerp(p, 0.5)))
				return c if grid.has(c) else Vector2i(-1, -1)
		prev = p
		t += step * maxf(1.0, p.y * 0.5)
	return Vector2i(-1, -1)


func clear_marks() -> void:
	for k: Vector2i in grid.cells:
		var c := hex_img.get_pixelv(k)
		c.r = 0.0
		hex_img.set_pixelv(k, c)


func mark(c: Vector2i, kind: int) -> void:
	var px := hex_img.get_pixelv(c)
	px.r = kind / 255.0
	hex_img.set_pixelv(c, px)


## owner: 0 yok, 1 Osmanlı, 2 İtilaf; objective: hedef halkası çizilsin mi
func set_control(c: Vector2i, owner: int, objective: bool) -> void:
	var px := hex_img.get_pixelv(c)
	px.g = owner / 255.0
	px.a = 1.0 if objective else 0.0
	hex_img.set_pixelv(c, px)


func set_seen(c: Vector2i, seen: bool) -> void:
	var px := hex_img.get_pixelv(c)
	px.b = 1.0 if seen else 0.0
	hex_img.set_pixelv(c, px)


func commit() -> void:
	hex_tex.update(hex_img)


## Haritaya yer adı yazar (yere yakın, kameraya dönük).
func add_place_label(text: String, p: Vector2, size := 1.0, color := Color(0.16, 0.1, 0.06)) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = int(54 * size)
	l.pixel_size = world_size.x / 7500.0
	l.modulate = color
	l.outline_modulate = Color(0.96, 0.92, 0.8, 0.85)
	l.outline_size = 10
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = false
	l.position = to_world(p, world_size.x * 0.012)
	_labels.add_child(l)
	return l


## Harekât odası ışığı: kuzeybatıdan (haritacılık geleneği) gelen ışık, sıcak ortam ve koyu arka plan.
static func add_lighting(parent: Node, map_width: float) -> DirectionalLight3D:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.05, 0.045, 0.04)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.6, 0.6, 0.62)
	env.ambient_light_energy = 0.38
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.05
	env.glow_enabled = false
	env.fog_enabled = false
	env.fog_light_color = Color(0.05, 0.045, 0.04)
	env.fog_density = 0.0
	env.fog_depth_begin = map_width * 1.1
	env.fog_depth_end = map_width * 2.6
	env.fog_mode = Environment.FOG_MODE_DEPTH
	var we := WorldEnvironment.new()
	we.environment = env
	parent.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42.0, -135.0 + 180.0, 0.0)
	sun.light_energy = 1.45
	sun.light_color = Color(1.0, 0.97, 0.92)
	sun.shadow_enabled = true
	sun.shadow_blur = 1.5
	sun.directional_shadow_max_distance = map_width * 2.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	parent.add_child(sun)
	return sun
