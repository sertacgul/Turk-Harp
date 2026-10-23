shader_type spatial;
render_mode specular_schlick_ggx, cull_back;
// Deniz: üç Gerstner dalgası, iki katmanlı kayan gürültü normali, arazi yükseklik haritasından
// kıyı sığlığı ve köpük. Yansımalar gökyüzünden ve (Forward+'ta) ekran uzayı yansımasından gelir.

uniform vec4 deep_color : source_color = vec4(0.015, 0.09, 0.14, 1.0);
uniform vec4 shallow_color : source_color = vec4(0.07, 0.32, 0.34, 1.0);
uniform vec4 foam_color : source_color = vec4(0.92, 0.94, 0.95, 1.0);
uniform float wave_height = 1.0;
uniform sampler2D normal_a : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_b : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D height_map : filter_linear, repeat_disable;
uniform vec4 height_bounds = vec4(-1000.0, -1000.0, 2000.0, 2000.0);
uniform bool use_height_map = false;

varying vec3 world_pos;
varying vec3 gerstner_n;
varying float crest;

vec3 gerstner(vec2 p, vec2 dir, float steep, float wavelength, float t, inout vec3 tangent, inout vec3 binormal) {
	float k = TAU / wavelength;
	float c = sqrt(9.8 / k);
	vec2 d = normalize(dir);
	float f = k * (dot(d, p) - c * t);
	float a = steep / k;
	tangent += vec3(-d.x * d.x * steep * sin(f), d.x * steep * cos(f), -d.x * d.y * steep * sin(f));
	binormal += vec3(-d.x * d.y * steep * sin(f), d.y * steep * cos(f), -d.y * d.y * steep * sin(f));
	return vec3(d.x * a * cos(f), a * sin(f), d.y * a * cos(f));
}

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 t = vec3(1.0, 0.0, 0.0);
	vec3 b = vec3(0.0, 0.0, 1.0);
	vec3 off = vec3(0.0);
	// Dalga boyları su ağının aralığından (≈17 m) en az dört kat uzun olmalı; ince ayrıntıyı normal haritaları verir.
	off += gerstner(w.xz, vec2(1.0, 0.3), 0.1, 140.0, TIME, t, b);
	off += gerstner(w.xz, vec2(-0.3, 1.0), 0.08, 95.0, TIME, t, b);
	off += gerstner(w.xz, vec2(0.6, -0.8), 0.06, 70.0, TIME, t, b);
	VERTEX += off * wave_height;
	world_pos = w + off * wave_height;
	gerstner_n = normalize(cross(b, t));
	crest = off.y * wave_height;
}

void fragment() {
	vec2 uv = world_pos.xz;
	vec3 na = texture(normal_a, uv / 26.0 + vec2(TIME * 0.012, TIME * 0.007)).rgb * 2.0 - 1.0;
	vec3 nb = texture(normal_b, uv / 9.0 - vec2(TIME * 0.009, -TIME * 0.015)).rgb * 2.0 - 1.0;
	vec3 n = normalize(gerstner_n + vec3(na.x + nb.x * 0.6, 0.0, na.y + nb.y * 0.6) * 0.45);
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);

	float depth = 30.0;
	if (use_height_map) {
		vec2 huv = (world_pos.xz - height_bounds.xy) / height_bounds.zw;
		depth = -texture(height_map, huv).r;
	}
	float shallow = 1.0 - smoothstep(0.0, 14.0, depth);
	vec3 col = mix(deep_color.rgb, shallow_color.rgb, shallow * 0.85);
	// Kıyı köpüğü dalga gibi atar; dalga tepelerinde ince köpük
	float shore = 1.0 - smoothstep(0.0, 2.2, depth + sin(TIME * 1.3 + world_pos.x * 0.05) * 0.4);
	float breakup = clamp((nb.x + na.y) * 0.5 + 0.55, 0.0, 1.0);
	float foam = clamp(shore * breakup * 1.4, 0.0, 1.0);
	ALBEDO = mix(col, foam_color.rgb, foam);
	ROUGHNESS = mix(0.04, 0.5, foam);
	METALLIC = 0.0;
	SPECULAR = 0.5;
}
