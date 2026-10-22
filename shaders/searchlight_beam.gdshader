shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;

uniform vec4 beam_color : source_color = vec4(0.9, 0.95, 1.0, 1.0);
uniform float intensity = 0.18;

void fragment() {
	// UV.y: 0 = lamba, 1 = huzmenin ucu
	float fade = pow(1.0 - UV.y, 1.6);
	float edge = pow(clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0), 1.5);
	ALBEDO = beam_color.rgb * intensity * fade * edge;
}
