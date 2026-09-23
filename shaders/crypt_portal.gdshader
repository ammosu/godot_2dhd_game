shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never;
void fragment() {
	// Vaulted opening: straight jambs and a semicircular crown, flush to the sill.
	float x = (UV.x - 0.5) * 2.0;
	float height = (1.0 - UV.y) * 3.55;
	float distance_to_edge = min(1.0 - abs(x), height / 1.22);
	if (height > 2.3) {
		distance_to_edge = 1.0 - length(vec2(x, (height - 2.3) / 1.22));
	}
	vec2 p = vec2(x, (height - 1.75) / 1.75);
	float r = length(p);
	float angle = atan(p.y, p.x);
	float edge = exp(-abs(distance_to_edge - 0.045) * 42.0);
	float swirl = pow(0.5 + 0.5 * sin(angle * 4.0 - r * 24.0 + TIME * 2.0), 3.0);
	ALBEDO = vec3(0.006, 0.02, 0.055) + swirl * vec3(0.02, 0.24, 0.36);
	EMISSION = edge * vec3(0.20, 0.85, 1.0) * 1.8 + swirl * vec3(0.01, 0.13, 0.25);
	ALPHA = smoothstep(0.0, 0.02, distance_to_edge) * 0.99;
}
