class_name Atmosphere
extends RefCounted
## Dünyalar arasında paylaşılan gökyüzü, ışık, sis ve deniz yüzeyi.
## mode: "day", "night" ya da "dawn" (şafak; güneş doğudan, alçak ve sıcak renkli).


## WorldEnvironment ve güneşi parent'a ekler; {"environment", "sun"} döndürür.
static func build(parent: Node, mode: String) -> Dictionary:
	var hq := GameState.high_quality()
	# Forward+ ya da Mobile render (RenderingDevice) gelişmiş efektleri destekler.
	var rd := RenderingServer.get_rendering_device() != null
	var sky_mat := ShaderMaterial.new()
	sky_mat.shader = load("res://shaders/sky.gdshader")
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.glow_enabled = true
	env.glow_intensity = 0.6 if mode == "night" else 0.3
	env.glow_hdr_threshold = 0.9 if mode == "night" else 1.2
	env.glow_bloom = 0.02
	env.fog_enabled = true
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.06
	env.adjustment_saturation = 1.04
	if rd and hq:
		env.ssao_enabled = true
		env.ssao_radius = 1.5
		env.ssao_intensity = 1.6
		env.ssil_enabled = true
		env.ssr_enabled = true
		env.ssr_max_steps = 48
		env.volumetric_fog_enabled = true
		env.volumetric_fog_length = 400.0
		env.volumetric_fog_anisotropy = 0.6
	var sun := DirectionalLight3D.new()
	sun.shadow_enabled = hq
	sun.directional_shadow_max_distance = 600.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.shadow_blur = 1.2
	sun.light_angular_distance = 0.5
	match mode:
		"night":
			sky_mat.set_shader_parameter("zenith_color", Color(0.004, 0.008, 0.025))
			sky_mat.set_shader_parameter("horizon_color", Color(0.03, 0.05, 0.1))
			sky_mat.set_shader_parameter("ground_color", Color(0.01, 0.01, 0.02))
			sky_mat.set_shader_parameter("cloud_color", Color(0.25, 0.28, 0.35))
			sky_mat.set_shader_parameter("cloud_shade", Color(0.05, 0.06, 0.09))
			sky_mat.set_shader_parameter("cloud_cover", 0.35)
			sky_mat.set_shader_parameter("star_amount", 1.0)
			sky_mat.set_shader_parameter("sun_size", 0.012)
			env.fog_light_color = Color(0.03, 0.05, 0.09)
			env.fog_density = 0.0009
			env.volumetric_fog_density = 0.004
			env.volumetric_fog_albedo = Color(0.6, 0.65, 0.75)
			# Gece gökyüzü çok karanlık; ortam ışığı sabit, mavimsi ay ışığı olsun.
			env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
			env.ambient_light_color = Color(0.16, 0.2, 0.32)
			env.ambient_light_energy = 0.9
			env.tonemap_exposure = 1.6
			sun.light_color = Color(0.6, 0.7, 1.0)
			sun.light_energy = 0.45
			sun.rotation_degrees = Vector3(-35.0, -130.0, 0.0)
		"dawn":
			sky_mat.set_shader_parameter("zenith_color", Color(0.2, 0.34, 0.6))
			sky_mat.set_shader_parameter("horizon_color", Color(0.92, 0.72, 0.56))
			sky_mat.set_shader_parameter("ground_color", Color(0.35, 0.32, 0.3))
			sky_mat.set_shader_parameter("cloud_color", Color(1.0, 0.86, 0.74))
			sky_mat.set_shader_parameter("cloud_shade", Color(0.5, 0.5, 0.58))
			sky_mat.set_shader_parameter("cloud_cover", 0.38)
			env.fog_light_color = Color(0.78, 0.72, 0.66)
			env.fog_density = 0.00035
			env.fog_sky_affect = 0.15
			env.volumetric_fog_density = 0.001
			env.volumetric_fog_albedo = Color(0.9, 0.86, 0.8)
			env.ambient_light_energy = 0.6
			env.tonemap_exposure = 1.1
			sun.light_color = Color(1.0, 0.86, 0.7)
			sun.light_energy = 1.6
			# Sabah güneşi doğudan (+X) gelir; ışık batıya, denize doğru düşer.
			sun.rotation_degrees = Vector3(-32.0, 100.0, 0.0)
		_:
			env.fog_light_color = Color(0.62, 0.7, 0.8)
			env.fog_density = 0.00018
			env.fog_sky_affect = 0.25
			env.volumetric_fog_density = 0.0015
			env.ambient_light_energy = 0.5
			env.tonemap_exposure = 1.0
			sun.light_color = Color(1.0, 0.95, 0.86)
			sun.light_energy = 1.4
			sun.rotation_degrees = Vector3(-38.0, 150.0, 0.0)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	sky.process_mode = Sky.PROCESS_MODE_REALTIME
	sky.radiance_size = Sky.RADIANCE_SIZE_64
	env.sky = sky
	var we := WorldEnvironment.new()
	we.environment = env
	parent.add_child(we)
	parent.add_child(sun)
	return {"environment": env, "sun": sun}


## Deniz yüzeyi. height_tex: arazi yüksekliği (R kanalı, metre), bounds: (x0, z0, genişlik, derinlik).
static func water(parent: Node, center: Vector3, size: Vector2, mode: String, height_tex: Texture2D = null, bounds := Vector4.ZERO) -> MeshInstance3D:
	var plane := PlaneMesh.new()
	plane.size = size
	var sub := 260 if GameState.high_quality() else 120
	plane.subdivide_width = sub
	plane.subdivide_depth = sub
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/water.gdshader")
	mat.set_shader_parameter("normal_a", _wave_normal(0.008, 11))
	mat.set_shader_parameter("normal_b", _wave_normal(0.02, 23))
	if height_tex:
		mat.set_shader_parameter("height_map", height_tex)
		mat.set_shader_parameter("height_bounds", bounds)
		mat.set_shader_parameter("use_height_map", true)
	if mode == "night":
		mat.set_shader_parameter("deep_color", Color(0.035, 0.07, 0.12))
		mat.set_shader_parameter("shallow_color", Color(0.06, 0.13, 0.17))
		mat.set_shader_parameter("foam_color", Color(0.35, 0.38, 0.45))
	elif mode == "dawn":
		mat.set_shader_parameter("deep_color", Color(0.02, 0.07, 0.11))
		mat.set_shader_parameter("shallow_color", Color(0.06, 0.22, 0.24))
	plane.material = mat
	var w := MeshInstance3D.new()
	w.mesh = plane
	w.position = center
	w.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(w)
	return w


static func _wave_normal(freq: float, seed: int) -> NoiseTexture2D:
	var t := NoiseTexture2D.new()
	t.width = 512
	t.height = 512
	t.seamless = true
	t.as_normal_map = true
	t.bump_strength = 6.0
	var n := FastNoiseLite.new()
	n.seed = seed
	n.frequency = freq
	n.fractal_octaves = 4
	t.noise = n
	return t


## Arazi yükseklik fonksiyonunu suya verilecek bir dokuya örnekler.
static func bake_heights(height_fn: Callable, bounds: Vector4, res := 256) -> ImageTexture:
	var img := Image.create(res, res, false, Image.FORMAT_RF)
	for y in res:
		for x in res:
			var wx := bounds.x + (float(x) + 0.5) / res * bounds.z
			var wz := bounds.y + (float(y) + 0.5) / res * bounds.w
			img.set_pixel(x, y, Color(height_fn.call(wx, wz), 0, 0))
	return ImageTexture.create_from_image(img)
