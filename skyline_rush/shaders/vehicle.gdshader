// Vehicle paint: the model's own texture with a hue rotation, saturation and
// brightness change so one model gives many colour variants. Strongly coloured
// parts are repainted; white / black / grey parts stay as they are.
shader_type spatial;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap;
uniform float hue_shift = 0.0;
uniform float sat_mult = 1.0;
uniform float val_mult = 1.0;
uniform vec4 glow_color : source_color = vec4(0.3, 0.9, 1.0, 1.0);
uniform float glow = 0.0;
uniform float alpha = 1.0;
uniform float rim = 0.25;

vec3 rgb2hsv(vec3 c) {
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	float e = 1.0e-10;
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

vec3 hsv2rgb(vec3 c) {
	vec3 p = abs(fract(c.xxx + vec3(0.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0);
	return c.z * clamp(p - 1.0, 0.0, 1.0);
}

void fragment() {
	vec3 c = texture(albedo_tex, UV).rgb;
	vec3 h = rgb2hsv(c);
	float colourful = smoothstep(0.18, 0.4, h.y);
	vec3 shifted = hsv2rgb(vec3(fract(h.x + hue_shift), clamp(h.y * sat_mult, 0.0, 1.0), clamp(h.z * val_mult, 0.0, 1.0)));
	vec3 col = mix(c, shifted, colourful);
	ALBEDO = col;
	ROUGHNESS = 0.45;
	METALLIC = 0.15;
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	EMISSION = col * colourful * glow + glow_color.rgb * fres * rim;
	ALPHA = alpha;
}
