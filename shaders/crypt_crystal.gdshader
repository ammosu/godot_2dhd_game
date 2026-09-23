shader_type spatial;
render_mode cull_disabled;
void fragment() {
	float rim = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 4.5);
	ALBEDO = mix(vec3(0.12, 0.008, 0.028), vec3(0.72, 0.08, 0.15), COLOR.r);
	METALLIC = 0.55;
	ROUGHNESS = 0.10;
	EMISSION = vec3(1.0, 0.08, 0.18) * (0.02 + rim * 0.38);
}
