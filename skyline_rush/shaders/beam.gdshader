// Soft additive light beam / hologram, with world bend.
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, world_vertex_coords;

global uniform vec2 curve_amount;
global uniform float beat;
uniform vec4 color : source_color = vec4(1.0, 0.4, 0.8, 1.0);
uniform float strength = 0.35;

void vertex() {
	float d = min(VERTEX.z, 0.0);
	VERTEX.x += curve_amount.x * d * d;
	VERTEX.y += curve_amount.y * d * d;
}

void fragment() {
	float fres = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float fade = smoothstep(0.0, 0.25, UV.y) * smoothstep(1.0, 0.55, UV.y);
	float scan = 0.75 + 0.25 * sin(UV.y * 60.0 - TIME * 4.0);
	ALBEDO = color.rgb * 1.5;
	ALPHA = fres * fade * scan * strength * (1.0 + beat * 0.6);
}
