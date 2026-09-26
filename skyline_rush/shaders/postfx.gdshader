// Screen post-process: radial speed blur, chromatic aberration, vignette, tint, flash.
shader_type canvas_item;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float aberration = 0.0;
uniform float radial_blur = 0.0;
uniform float vignette = 0.45;
uniform vec4 tint : source_color = vec4(0.6, 0.8, 1.0, 1.0);
uniform float tint_amount = 0.0;
uniform vec4 flash_color : source_color = vec4(1.0);
uniform float flash = 0.0;

vec3 grab(vec2 uv, vec2 off) {
	return vec3(texture(screen_tex, uv + off).r, texture(screen_tex, uv).g, texture(screen_tex, uv - off).b);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 dir = uv - vec2(0.5, 0.52);
	float dist = length(dir);
	vec2 off = dir * aberration * (0.4 + dist);
	vec3 col = grab(uv, off);
	if (radial_blur > 0.001) {
		float amt = radial_blur * smoothstep(0.12, 0.7, dist);
		vec3 acc = col;
		for (int i = 1; i <= 6; i++) {
			float k = float(i) / 6.0;
			acc += grab(uv - dir * amt * k, off);
		}
		col = acc / 7.0;
	}
	float l = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(col, vec3(l) * tint.rgb * 1.25, tint_amount);
	col *= 1.0 - vignette * smoothstep(0.35, 0.95, dist);
	col = mix(col, flash_color.rgb, clamp(flash, 0.0, 1.0));
	COLOR = vec4(col, 1.0);
}
