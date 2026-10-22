shader_type spatial;
render_mode cull_disabled;

uniform sampler2D flag_texture : source_color, filter_nearest;

void vertex() {
	// UV.x = 0 direğe bağlı kenar; uca doğru dalgalanma artar.
	float k = UV.x;
	VERTEX.z += sin(UV.x * 9.0 - TIME * 7.0) * 0.12 * k;
	VERTEX.y += sin(UV.x * 5.0 - TIME * 5.0) * 0.05 * k;
}

void fragment() {
	vec4 c = texture(flag_texture, UV);
	ALBEDO = c.rgb;
	ROUGHNESS = 0.9;
}
