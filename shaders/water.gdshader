shader_type spatial;
render_mode specular_schlick_ggx, cull_back;

uniform vec4 deep_color : source_color = vec4(0.02, 0.13, 0.2, 1.0);
uniform vec4 shallow_color : source_color = vec4(0.07, 0.3, 0.36, 1.0);
uniform vec4 foam_color : source_color = vec4(0.9, 0.93, 0.95, 1.0);
uniform float wave_height = 0.9;

varying vec3 world_pos;
varying float crest;

// Dört yönlü sinüs dalgası; yükseklik ve analitik eğim döndürür.
vec3 waves(vec2 p, float t) {
	vec2 dirs[4] = vec2[](vec2(1.0, 0.25), vec2(-0.35, 1.0), vec2(0.7, -0.7), vec2(0.2, 0.95));
	float freqs[4] = float[](0.045, 0.08, 0.15, 0.31);
	float amps[4] = float[](0.6, 0.3, 0.14, 0.06);
	float speeds[4] = float[](0.9, 1.4, 2.1, 3.2);
	float h = 0.0;
	vec2 grad = vec2(0.0);
	for (int i = 0; i < 4; i++) {
		vec2 d = normalize(dirs[i]);
		float ph = dot(p, d) * freqs[i] + t * speeds[i];
		h += sin(ph) * amps[i];
		grad += d * cos(ph) * amps[i] * freqs[i];
	}
	return vec3(h, grad);
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 w = waves(world_pos.xz, TIME);
	VERTEX.y += w.x * wave_height;
	crest = w.x;
}

void fragment() {
	vec3 w = waves(world_pos.xz, TIME);
	vec2 g = w.yz * wave_height;
	// İnce dalgacıklar
	float r1 = sin(world_pos.x * 0.9 + TIME * 2.7) * cos(world_pos.z * 1.1 - TIME * 2.1);
	float r2 = sin(world_pos.x * 1.7 - world_pos.z * 1.3 + TIME * 3.9);
	g += vec2(r1, r2) * 0.035;
	vec3 n_world = normalize(vec3(-g.x, 1.0, -g.y));
	NORMAL = normalize((VIEW_MATRIX * vec4(n_world, 0.0)).xyz);

	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);
	vec3 col = mix(deep_color.rgb, shallow_color.rgb, clamp(crest * 0.5 + 0.5, 0.0, 1.0) * 0.6);
	float foam = smoothstep(0.62, 0.95, crest) * (0.5 + 0.5 * r2);
	col = mix(col, foam_color.rgb, foam * 0.5);
	ALBEDO = col;
	ROUGHNESS = mix(0.06, 0.25, foam);
	METALLIC = 0.0;
	SPECULAR = 0.6 + fresnel * 0.4;
}
