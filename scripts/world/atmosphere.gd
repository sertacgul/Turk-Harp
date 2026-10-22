class_name Atmosphere
extends RefCounted
## Dünyalar arasında paylaşılan gökyüzü, ışık, sis ve deniz yüzeyi.
## mode: "day", "night" ya da "dawn" (şafak; güneş doğudan, alçak ve sıcak renkli).


## WorldEnvironment ve güneşi parent'a ekler; {"environment", "sun"} döndürür.
static func build(parent: Node, mode: String) -> Dictionary:
	var hq := GameState.high_quality()
	var sky_mat := ProceduralSkyMaterial.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 6.0
	env.glow_enabled = true
	env.glow_intensity = 1.0 if mode == "night" else 0.35
	env.glow_hdr_threshold = 0.9 if mode == "night" else 1.3
	env.glow_bloom = 0.0
	env.fog_enabled = true
	env.ssao_enabled = hq and RenderingServer.get_rendering_device() != null
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	var sun := DirectionalLight3D.new()
	sun.shadow_enabled = hq
	sun.directional_shadow_max_distance = 700.0
	match mode:
		"night":
			sky_mat.sky_top_color = Color(0.01, 0.015, 0.04)
			sky_mat.sky_horizon_color = Color(0.05, 0.07, 0.13)
			sky_mat.ground_horizon_color = Color(0.03, 0.04, 0.07)
			sky_mat.ground_bottom_color = Color(0.0, 0.0, 0.0)
			sky_mat.sun_angle_max = 2.0
			sky_mat.sky_energy_multiplier = 0.6
			env.fog_light_color = Color(0.04, 0.06, 0.1)
			env.fog_density = 0.0011
			env.ambient_light_energy = 0.6
			env.tonemap_exposure = 1.5
			sun.light_color = Color(0.6, 0.7, 1.0)
			sun.light_energy = 0.55
			sun.rotation_degrees = Vector3(-35.0, -130.0, 0.0)
		"dawn":
			sky_mat.sky_top_color = Color(0.25, 0.38, 0.62)
			sky_mat.sky_horizon_color = Color(0.95, 0.72, 0.52)
			sky_mat.ground_horizon_color = Color(0.6, 0.5, 0.45)
			sky_mat.ground_bottom_color = Color(0.15, 0.15, 0.18)
			env.fog_light_color = Color(0.85, 0.72, 0.6)
			env.fog_density = 0.0009
			env.fog_sky_affect = 0.35
			env.ambient_light_energy = 0.5
			env.tonemap_exposure = 1.0
			sun.light_color = Color(1.0, 0.78, 0.55)
			sun.light_energy = 1.15
			# Güneş doğudan (+X) doğar; ışık batıya, denize doğru düşer.
			sun.rotation_degrees = Vector3(-16.0, 95.0, 0.0)
		_:
			sky_mat.sky_top_color = Color(0.22, 0.42, 0.72)
			sky_mat.sky_horizon_color = Color(0.72, 0.76, 0.8)
			sky_mat.ground_horizon_color = Color(0.55, 0.6, 0.65)
			sky_mat.ground_bottom_color = Color(0.15, 0.2, 0.25)
			env.fog_light_color = Color(0.62, 0.68, 0.76)
			env.fog_density = 0.00016
			env.fog_sky_affect = 0.3
			env.ambient_light_energy = 0.45
			env.tonemap_exposure = 0.95
			sun.light_color = Color(1.0, 0.94, 0.84)
			sun.light_energy = 1.05
			sun.rotation_degrees = Vector3(-38.0, 150.0, 0.0)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.sky = sky
	var we := WorldEnvironment.new()
	we.environment = env
	parent.add_child(we)
	parent.add_child(sun)
	return {"environment": env, "sun": sun}


static func water(parent: Node, center: Vector3, size: Vector2, mode: String) -> MeshInstance3D:
	var plane := PlaneMesh.new()
	plane.size = size
	var sub := 220 if GameState.high_quality() else 120
	plane.subdivide_width = sub
	plane.subdivide_depth = sub
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/water.gdshader")
	if mode == "night":
		mat.set_shader_parameter("deep_color", Color(0.02, 0.05, 0.09))
		mat.set_shader_parameter("shallow_color", Color(0.05, 0.12, 0.18))
	elif mode == "dawn":
		mat.set_shader_parameter("deep_color", Color(0.02, 0.07, 0.11))
		mat.set_shader_parameter("shallow_color", Color(0.06, 0.16, 0.2))
	plane.material = mat
	var w := MeshInstance3D.new()
	w.mesh = plane
	w.position = center
	w.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(w)
	return w
