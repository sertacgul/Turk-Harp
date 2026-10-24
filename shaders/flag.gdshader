shader_type spatial;
render_mode cull_disabled;
// Dalgalanan bayrak: UV.x = 0 direğe bağlı kenar; uca doğru dalga genliği artar.

uniform sampler2D flag_texture : source_color, filter_linear_mipmap;
uniform float amp = 0.1;
uniform float speed = 1.0;
uniform float phase = 0.0;

void vertex() {
	float k = UV.x;
	float t = TIME * speed + phase;
	VERTEX.z += sin(UV.x * 9.0 - t * 6.0) * amp * k;
	VERTEX.y += sin(UV.x * 5.0 - t * 4.0) * amp * 0.4 * k;
}

void fragment() {
	vec4 c = texture(flag_texture, UV);
	// Kumaş kıvrımlarında hafif gölge
	float fold = 0.88 + 0.12 * sin(UV.x * 9.0 - (TIME * speed + phase) * 6.0);
	ALBEDO = c.rgb * fold;
	ROUGHNESS = 0.85;
}
