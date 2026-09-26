// Textured version of world.gdshader (for imported models such as the trees):
// same curved-world bend so scenery stays glued to the road.
shader_type spatial;
render_mode world_vertex_coords;

global uniform vec2 curve_amount;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap;
uniform vec4 tint : source_color = vec4(1.0);
uniform float roughness = 0.8;

void vertex() {
	float d = min(VERTEX.z, 0.0);
	VERTEX.x += curve_amount.x * d * d;
	VERTEX.y += curve_amount.y * d * d;
}

void fragment() {
	vec4 c = texture(albedo_tex, UV);
	ALBEDO = c.rgb * tint.rgb;
	ROUGHNESS = roughness;
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	EMISSION = vec3(1.0, 0.95, 0.9) * fres * 0.12;
}
