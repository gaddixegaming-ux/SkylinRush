// Merged scenery (one mesh per building / prop group). Per-vertex data:
// COLOR.rgb = colour (linear), COLOR.a = glow / 8, UV2 = roughness, metallic,
// UV.x = beat pulse. Same curved-world bend as world.gdshader.
shader_type spatial;
render_mode world_vertex_coords;

global uniform vec2 curve_amount;
global uniform float beat;

void vertex() {
	float d = min(VERTEX.z, 0.0);
	VERTEX.x += curve_amount.x * d * d;
	VERTEX.y += curve_amount.y * d * d;
}

void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = UV2.x;
	METALLIC = UV2.y;
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	EMISSION = COLOR.rgb * COLOR.a * 8.0 * (1.0 + beat * UV.x) + vec3(1.0, 0.92, 1.0) * fres * 0.12;
}

#include "res://shaders/toon_light.gdshaderinc"
