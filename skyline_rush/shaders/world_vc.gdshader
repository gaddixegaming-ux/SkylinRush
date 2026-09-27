// Merged scenery (one mesh per building / prop group). Per-vertex data:
// COLOR.rgb = colour (linear), COLOR.a = glow / 8, UV2 = roughness, metallic,
// UV.x = beat pulse, UV.y = rim strength (negative = red hazard rim). Same curved-world bend as world.gdshader.
shader_type spatial;
render_mode world_vertex_coords;

global uniform vec2 curve_amount;
// 1 = cheap contact shading where SSAO is off (mobile renderer / low preset):
// vertical faces darken near the ground they stand on.
global uniform float fake_ao;
varying float v_wy;
varying float v_ny;
global uniform float beat;

void vertex() {
	v_wy = VERTEX.y;
	v_ny = NORMAL.y;
	float d = min(VERTEX.z, 0.0);
	VERTEX.x += curve_amount.x * d * d;
	VERTEX.y += curve_amount.y * d * d;
}

void fragment() {
	ALBEDO = COLOR.rgb;
	ALBEDO *= mix(1.0, mix(0.5, 1.0, smoothstep(0.0, 1.6, v_wy)), (1.0 - abs(v_ny)) * fake_ao);
	ROUGHNESS = UV2.x;
	METALLIC = UV2.y;
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	vec3 rim_c = UV.y < 0.0 ? vec3(1.0, 0.22, 0.12) : vec3(1.0, 0.92, 1.0);
	EMISSION = COLOR.rgb * COLOR.a * 8.0 * (1.0 + beat * UV.x) + rim_c * fres * max(abs(UV.y), 0.1);
}

#include "res://shaders/toon_light.gdshaderinc"
