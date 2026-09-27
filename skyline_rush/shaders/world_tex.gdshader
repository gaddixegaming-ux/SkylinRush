// Textured version of world.gdshader (for imported models such as the trees):
// same curved-world bend so scenery stays glued to the road.
shader_type spatial;
render_mode world_vertex_coords;

global uniform vec2 curve_amount;
// 1 = cheap contact shading where SSAO is off (mobile renderer / low preset):
// vertical faces darken near the ground they stand on.
global uniform float fake_ao;
varying float v_wy;
varying float v_ny;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap;
uniform vec4 tint : source_color = vec4(1.0);
uniform float roughness = 0.8;

void vertex() {
	v_wy = VERTEX.y;
	v_ny = NORMAL.y;
	float d = min(VERTEX.z, 0.0);
	VERTEX.x += curve_amount.x * d * d;
	VERTEX.y += curve_amount.y * d * d;
}

void fragment() {
	vec4 c = texture(albedo_tex, UV);
	ALBEDO = c.rgb * tint.rgb;
	ALBEDO *= mix(1.0, mix(0.5, 1.0, smoothstep(0.0, 1.6, v_wy)), (1.0 - abs(v_ny)) * fake_ao);
	ROUGHNESS = roughness;
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	EMISSION = vec3(1.0, 0.95, 0.9) * fres * 0.12;
}

#include "res://shaders/toon_light.gdshaderinc"
