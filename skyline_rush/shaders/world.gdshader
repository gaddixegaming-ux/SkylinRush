// Stylised lit material + "curved world" bend. Every world object uses it.
shader_type spatial;
render_mode world_vertex_coords;

global uniform vec2 curve_amount;
global uniform float beat;

uniform vec4 albedo : source_color = vec4(1.0);
uniform vec4 emission_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float emission_energy = 0.0;
uniform float beat_pulse = 0.0;
uniform float roughness : hint_range(0.0, 1.0) = 0.7;
uniform float metallic : hint_range(0.0, 1.0) = 0.0;
uniform float rim_strength = 0.2;
uniform vec4 rim_color : source_color = vec4(1.0, 0.85, 1.0, 1.0);

void vertex() {
	float d = min(VERTEX.z, 0.0);
	VERTEX.x += curve_amount.x * d * d;
	VERTEX.y += curve_amount.y * d * d;
}

void fragment() {
	ALBEDO = albedo.rgb;
	ROUGHNESS = roughness;
	METALLIC = metallic;
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	EMISSION = emission_color.rgb * emission_energy * (1.0 + beat * beat_pulse)
		+ rim_color.rgb * fres * rim_strength;
}

#include "res://shaders/toon_light.gdshaderinc"
