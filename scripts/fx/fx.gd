class_name Fx
extends RefCounted
## Parçacık efektleri: patlama, su sütunu, namlu alevi, duman ve yangın.
## Tek seferlik efektler kendi kendini siler.

static var _soft_tex: Texture2D
static var _smoke_tex: Texture2D
static var _materials := {}


static func quality() -> float:
	return 1.0 if GameState.high_quality() else 0.5


static func soft_texture() -> Texture2D:
	if _soft_tex == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.45, Color(1, 1, 1, 0.55))
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(0.5, 0.0)
		t.width = 64
		t.height = 64
		_soft_tex = t
	return _soft_tex


## Duman bulutu: fbm gürültüsüyle bozulmuş yuvarlak, kıvrımlı kenarlı leke.
static func smoke_texture() -> Texture2D:
	if _smoke_tex == null:
		var n := 128
		var img := Image.create(n, n, true, Image.FORMAT_RGBA8)
		var noise := FastNoiseLite.new()
		noise.seed = 31
		noise.frequency = 0.045
		noise.fractal_octaves = 5
		for y in n:
			for x in n:
				var p := Vector2(x, y) / n * 2.0 - Vector2.ONE
				var r := p.length()
				var nz := noise.get_noise_2d(x, y) * 0.5 + 0.5
				var a := clampf((1.0 - r) * 1.6 - (1.0 - nz) * 0.9, 0.0, 1.0)
				var shade := 0.75 + nz * 0.25
				img.set_pixel(x, y, Color(shade, shade, shade, a * a))
		img.generate_mipmaps()
		_smoke_tex = ImageTexture.create_from_image(img)
	return _smoke_tex


static func _billboard(additive: bool, smoky := false) -> StandardMaterial3D:
	var key := "add" if additive else ("smoke" if smoky else "alpha")
	if _materials.has(key):
		return _materials[key]
	var m := StandardMaterial3D.new()
	# BILLBOARD_PARTICLES, Compatibility render modunda parçacık ölçeğini yok sayıyor.
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.billboard_keep_scale = true
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_texture = smoke_texture() if smoky else soft_texture()
	m.disable_receive_shadows = true
	if additive:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_materials[key] = m
	return m


static func _ramp(colors: Array, offsets: Array) -> GradientTexture1D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array(offsets)
	g.colors = PackedColorArray(colors)
	var t := GradientTexture1D.new()
	t.gradient = g
	return t


static func _curve(points: Array) -> CurveTexture:
	var c := Curve.new()
	c.max_value = 4.0
	for p in points:
		c.add_point(p)
	var t := CurveTexture.new()
	t.curve = c
	return t


static func _particles(amount: int, lifetime: float, additive: bool, size: float, smoky := false) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = maxi(1, int(amount * quality()))
	p.lifetime = lifetime
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	q.material = _billboard(additive, smoky)
	p.draw_pass_1 = q
	p.visibility_aabb = AABB(Vector3(-200, -50, -200), Vector3(400, 300, 400))
	return p


static func _one_shot(parent: Node, pos: Vector3, p: GPUParticles3D, pm: ParticleProcessMaterial) -> GPUParticles3D:
	p.process_material = pm
	p.one_shot = true
	p.explosiveness = 0.92
	parent.add_child(p)
	p.global_position = pos
	p.emitting = true
	parent.get_tree().create_timer(p.lifetime + 0.5).timeout.connect(p.queue_free)
	return p


static func _flash(parent: Node, pos: Vector3, color: Color, energy: float, light_range: float, dur: float) -> void:
	var l := OmniLight3D.new()
	l.light_color = color
	l.light_energy = energy
	l.omni_range = light_range
	parent.add_child(l)
	l.global_position = pos
	var tw := l.create_tween()
	tw.tween_property(l, "light_energy", 0.0, dur)
	tw.tween_callback(l.queue_free)


static func explosion(parent: Node, pos: Vector3, s := 1.0) -> void:
	# Ateş topu
	var fire := _particles(28, 0.9, true, 1.0)
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 2.0 * s
	pm.direction = Vector3.UP
	pm.spread = 180.0
	pm.initial_velocity_min = 4.0 * s
	pm.initial_velocity_max = 14.0 * s
	pm.damping_min = 8.0
	pm.damping_max = 14.0
	pm.gravity = Vector3(0, 4, 0)
	pm.scale_min = 8.0 * s
	pm.scale_max = 15.0 * s
	pm.scale_curve = _curve([Vector2(0, 0.4), Vector2(0.3, 1.0), Vector2(1, 1.3)])
	pm.color_ramp = _ramp([Color(1, 0.75, 0.35, 0.75), Color(0.95, 0.42, 0.08, 0.6), Color(0.5, 0.12, 0.03, 0.35), Color(0.1, 0.05, 0.03, 0)], [0.0, 0.25, 0.6, 1.0])
	_one_shot(parent, pos, fire, pm)
	# Duman
	var smoke := _particles(22, 5.0, false, 1.0, true)
	var sm := ParticleProcessMaterial.new()
	sm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	sm.emission_sphere_radius = 3.0 * s
	sm.direction = Vector3.UP
	sm.spread = 40.0
	sm.initial_velocity_min = 3.0 * s
	sm.initial_velocity_max = 9.0 * s
	sm.gravity = Vector3(1.5, 2.5, 0)
	sm.damping_min = 1.0
	sm.damping_max = 2.0
	sm.scale_min = 8.0 * s
	sm.scale_max = 16.0 * s
	sm.scale_curve = _curve([Vector2(0, 0.3), Vector2(1, 1.6)])
	sm.color_ramp = _ramp([Color(0.15, 0.13, 0.12, 0.0), Color(0.18, 0.16, 0.15, 0.75), Color(0.4, 0.38, 0.36, 0.0)], [0.0, 0.1, 1.0])
	var smoke_node := _one_shot(parent, pos, smoke, sm)
	smoke_node.explosiveness = 0.7
	# Kıvılcım ve enkaz
	var sparks := _particles(36, 1.2, true, 0.5)
	var sp := ParticleProcessMaterial.new()
	sp.direction = Vector3.UP
	sp.spread = 75.0
	sp.initial_velocity_min = 20.0 * s
	sp.initial_velocity_max = 45.0 * s
	sp.gravity = Vector3(0, -30, 0)
	sp.scale_min = 0.6 * s
	sp.scale_max = 1.4 * s
	sp.color_ramp = _ramp([Color(1, 0.85, 0.4, 1), Color(1, 0.4, 0.1, 0)], [0.0, 1.0])
	_one_shot(parent, pos, sparks, sp)
	_flash(parent, pos + Vector3(0, 3, 0), Color(1.0, 0.6, 0.25), 6.0, 70.0 * s, 0.6)


static func water_splash(parent: Node, pos: Vector3, s := 1.0) -> void:
	var col := _particles(40, 2.2, false, 1.0)
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 1.5 * s
	pm.direction = Vector3.UP
	pm.spread = 9.0
	pm.initial_velocity_min = 18.0 * s
	pm.initial_velocity_max = 38.0 * s
	pm.gravity = Vector3(0, -32, 0)
	pm.scale_min = 2.5 * s
	pm.scale_max = 6.0 * s
	pm.scale_curve = _curve([Vector2(0, 0.5), Vector2(1, 1.8)])
	pm.color_ramp = _ramp([Color(0.95, 0.97, 1.0, 0.9), Color(0.85, 0.9, 0.95, 0.6), Color(0.85, 0.9, 0.95, 0.0)], [0.0, 0.5, 1.0])
	_one_shot(parent, pos, col, pm)
	var mist := _particles(18, 3.0, false, 1.0)
	var mm := ParticleProcessMaterial.new()
	mm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	mm.emission_ring_axis = Vector3.UP
	mm.emission_ring_radius = 3.0 * s
	mm.emission_ring_inner_radius = 1.0 * s
	mm.emission_ring_height = 0.5
	mm.direction = Vector3(1, 0.3, 0)
	mm.spread = 180.0
	mm.flatness = 0.8
	mm.initial_velocity_min = 4.0 * s
	mm.initial_velocity_max = 9.0 * s
	mm.damping_min = 2.0
	mm.damping_max = 3.0
	mm.scale_min = 6.0 * s
	mm.scale_max = 10.0 * s
	mm.scale_curve = _curve([Vector2(0, 0.5), Vector2(1, 1.5)])
	mm.color_ramp = _ramp([Color(1, 1, 1, 0.55), Color(1, 1, 1, 0.0)], [0.0, 1.0])
	_one_shot(parent, pos, mist, mm)


static func muzzle_flash(parent: Node, pos: Vector3, dir: Vector3, s := 1.0) -> void:
	var fire := _particles(16, 0.3, true, 1.0)
	var pm := ParticleProcessMaterial.new()
	pm.direction = dir.normalized()
	pm.spread = 14.0
	pm.initial_velocity_min = 20.0 * s
	pm.initial_velocity_max = 40.0 * s
	pm.damping_min = 30.0
	pm.damping_max = 50.0
	pm.scale_min = 2.0 * s
	pm.scale_max = 4.5 * s
	pm.color_ramp = _ramp([Color(1, 0.95, 0.75, 1), Color(1, 0.5, 0.1, 0)], [0.0, 1.0])
	_one_shot(parent, pos, fire, pm)
	var smoke := _particles(14, 3.5, false, 1.0, true)
	var sm := ParticleProcessMaterial.new()
	sm.direction = dir.normalized()
	sm.spread = 25.0
	sm.initial_velocity_min = 8.0 * s
	sm.initial_velocity_max = 18.0 * s
	sm.damping_min = 5.0
	sm.damping_max = 8.0
	sm.gravity = Vector3(0.5, 1.2, 0)
	sm.scale_min = 3.0 * s
	sm.scale_max = 6.0 * s
	sm.scale_curve = _curve([Vector2(0, 0.4), Vector2(1, 2.0)])
	sm.color_ramp = _ramp([Color(0.85, 0.83, 0.8, 0.7), Color(0.8, 0.8, 0.8, 0.0)], [0.0, 1.0])
	_one_shot(parent, pos, smoke, sm)
	_flash(parent, pos, Color(1.0, 0.75, 0.4), 6.0, 40.0 * s, 0.25)


## Sürekli duman (baca ya da yanan gemi). Döndürülen düğüm hedefe eklenir.
static func smoke_column(target: Node3D, offset: Vector3, dark := 0.15, s := 1.0, amount := 30) -> GPUParticles3D:
	var p := _particles(amount, 7.0, false, 1.0, true)
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3.UP
	pm.spread = 8.0
	pm.initial_velocity_min = 3.0 * s
	pm.initial_velocity_max = 5.0 * s
	pm.gravity = Vector3(2.5, 0.8, 0.6)
	pm.scale_min = 3.0 * s
	pm.scale_max = 5.0 * s
	pm.scale_curve = _curve([Vector2(0, 0.6), Vector2(1, 3.5)])
	pm.color_ramp = _ramp([Color(dark, dark, dark, 0.0), Color(dark, dark, dark, 0.8), Color(dark + 0.3, dark + 0.3, dark + 0.3, 0.0)], [0.0, 0.06, 1.0])
	pm.angle_min = -180.0
	pm.angle_max = 180.0
	p.process_material = pm
	p.local_coords = false
	p.position = offset
	target.add_child(p)
	p.emitting = true
	return p


static func fire(target: Node3D, offset: Vector3, s := 1.0) -> GPUParticles3D:
	var p := _particles(24, 0.8, true, 1.0)
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(4, 0.5, 2) * s
	pm.direction = Vector3.UP
	pm.spread = 15.0
	pm.initial_velocity_min = 3.0 * s
	pm.initial_velocity_max = 7.0 * s
	pm.scale_min = 2.0 * s
	pm.scale_max = 4.0 * s
	pm.scale_curve = _curve([Vector2(0, 1.0), Vector2(1, 0.2)])
	pm.color_ramp = _ramp([Color(1, 0.8, 0.3, 1), Color(1, 0.35, 0.05, 0.8), Color(0.3, 0.1, 0.05, 0)], [0.0, 0.5, 1.0])
	p.process_material = pm
	p.local_coords = false
	p.position = offset
	target.add_child(p)
	p.emitting = true
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.55, 0.2)
	l.light_energy = 3.0
	l.omni_range = 30.0 * s
	l.position = offset + Vector3(0, 3, 0)
	target.add_child(l)
	return p


static func wake(target: Node3D, offset: Vector3, s := 1.0) -> GPUParticles3D:
	var p := _particles(40, 4.0, false, 1.0)
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(1, 0.1, 2.5) * s
	pm.direction = Vector3(0, 0.2, 1)
	pm.spread = 180.0
	pm.flatness = 0.9
	pm.initial_velocity_min = 0.5
	pm.initial_velocity_max = 2.0
	pm.gravity = Vector3.ZERO
	pm.scale_min = 3.0 * s
	pm.scale_max = 5.0 * s
	pm.scale_curve = _curve([Vector2(0, 0.6), Vector2(1, 2.2)])
	pm.color_ramp = _ramp([Color(1, 1, 1, 0.55), Color(1, 1, 1, 0.0)], [0.0, 1.0])
	p.process_material = pm
	p.local_coords = false
	p.position = offset
	target.add_child(p)
	p.emitting = true
	return p


## Mermi izi: hedef düğümü takip eden ince duman.
static func trail(target: Node3D, s := 1.0) -> GPUParticles3D:
	var p := _particles(30, 0.8, false, 1.0)
	var pm := ParticleProcessMaterial.new()
	pm.initial_velocity_min = 0.0
	pm.initial_velocity_max = 0.5
	pm.gravity = Vector3.ZERO
	pm.scale_min = 1.2 * s
	pm.scale_max = 1.8 * s
	pm.scale_curve = _curve([Vector2(0, 0.6), Vector2(1, 2.0)])
	pm.color_ramp = _ramp([Color(0.9, 0.85, 0.75, 0.5), Color(0.9, 0.9, 0.9, 0.0)], [0.0, 1.0])
	p.process_material = pm
	p.local_coords = false
	target.add_child(p)
	p.emitting = true
	return p


## Kurşunun toprağa çarptığı yerde küçük toz bulutu.
static func dust(parent: Node, pos: Vector3, s := 1.0) -> void:
	var p := _particles(8, 1.2, false, 1.0)
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3.UP
	pm.spread = 35.0
	pm.initial_velocity_min = 1.5 * s
	pm.initial_velocity_max = 4.0 * s
	pm.gravity = Vector3(0, -4, 0)
	pm.damping_min = 2.0
	pm.damping_max = 3.0
	pm.scale_min = 0.6 * s
	pm.scale_max = 1.4 * s
	pm.scale_curve = _curve([Vector2(0, 0.5), Vector2(1, 1.8)])
	pm.color_ramp = _ramp([Color(0.6, 0.5, 0.38, 0.8), Color(0.6, 0.52, 0.4, 0.0)], [0.0, 1.0])
	_one_shot(parent, pos, p, pm)
