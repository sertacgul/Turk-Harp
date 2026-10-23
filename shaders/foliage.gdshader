shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;
// Çimen ve çalı kartları: alfa kesmeli doku, rüzgârda salınım (tepeler daha çok), konuma göre renk çeşitliliği.

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap;
uniform vec3 tint_a : source_color = vec3(0.32, 0.38, 0.16);
uniform vec3 tint_b : source_color = vec3(0.52, 0.48, 0.24);
uniform float wind_strength = 0.12;
uniform float alpha_cut = 0.45;

varying float variation;

float h2(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 o = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	variation = h2(floor(o.xz * 0.37));
	float sway = sin(TIME * 1.7 + o.x * 0.21 + o.z * 0.17) * 0.6 + sin(TIME * 3.1 + o.x * 0.7) * 0.25;
	float k = (1.0 - UV.y) * (1.0 - UV.y);
	VERTEX.x += sway * wind_strength * k;
	VERTEX.z += sway * wind_strength * 0.5 * k;
	// Yumuşak ışık için normaller yukarı bakar
	NORMAL = normalize(mix(NORMAL, vec3(0.0, 1.0, 0.0), 0.7));
}

void fragment() {
	vec4 t = texture(albedo_tex, UV);
	if (t.a < alpha_cut) {
		discard;
	}
	vec3 tint = mix(tint_a, tint_b, variation);
	ALBEDO = t.rgb * tint * 2.2 * mix(0.55, 1.0, 1.0 - UV.y);
	ROUGHNESS = 0.9;
	SPECULAR = 0.2;
	BACKLIGHT = vec3(0.45, 0.5, 0.25);
}
