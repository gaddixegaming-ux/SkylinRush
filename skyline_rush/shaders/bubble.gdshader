// Fresnel energy bubble (shield / overdrive aura).
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_back;

uniform vec4 color : source_color = vec4(0.35, 0.9, 1.0, 1.0);
uniform float intensity = 1.6;

void fragment() {
	float f = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.2);
	float bands = 0.5 + 0.5 * sin(TIME * 6.0 + UV.y * 50.0);
	ALBEDO = color.rgb * intensity;
	ALPHA = clamp(f * (0.75 + 0.25 * bands) + 0.04, 0.0, 1.0);
}
