// Swirling energy disc inside portal rings.
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, world_vertex_coords;

global uniform vec2 curve_amount;
uniform vec4 color : source_color = vec4(0.4, 0.9, 1.0, 1.0);
uniform float strength = 1.0;

void vertex() {
	float d = min(VERTEX.z, 0.0);
	VERTEX.x += curve_amount.x * d * d;
	VERTEX.y += curve_amount.y * d * d;
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float a = atan(p.y, p.x);
	float swirl = 0.5 + 0.5 * sin(a * 5.0 + r * 14.0 - TIME * 5.0);
	float mask = smoothstep(1.0, 0.75, r);
	ALBEDO = color.rgb * (0.5 + swirl) * 1.6;
	ALPHA = mask * (0.12 + 0.3 * swirl * r) * strength;
}
