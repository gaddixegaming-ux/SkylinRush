// Soft "cartoon-realistic" lighting: a smooth two-tone light ramp (light side /
// shade side with a soft terminator) and a small glossy highlight.
void light() {
	float ndl = dot(NORMAL, LIGHT);
	float ramp = smoothstep(-0.12, 0.28, ndl) * 0.78 + clamp(ndl, 0.0, 1.0) * 0.22;
	DIFFUSE_LIGHT += ramp * ATTENUATION * LIGHT_COLOR / PI;
	vec3 h = normalize(VIEW + LIGHT);
	float gloss = pow(max(dot(NORMAL, h), 0.0), mix(12.0, 90.0, 1.0 - ROUGHNESS));
	SPECULAR_LIGHT += smoothstep(0.35, 0.6, gloss) * (1.0 - ROUGHNESS) * 0.35 * ATTENUATION * LIGHT_COLOR / PI;
}
