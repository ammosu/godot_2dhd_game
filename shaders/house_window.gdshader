shader_type spatial;
render_mode specular_disabled;

varying vec2 pane_uv;

void vertex() {
	// Local coordinates work on every BoxMesh face without its atlas UV seams.
	float horizontal = abs(NORMAL.x) > 0.5 ? VERTEX.z : VERTEX.x;
	pane_uv = vec2(horizontal / 0.66 + 0.5, VERTEX.y / 0.62 + 0.5);
}

void fragment() {
	vec2 p = clamp(pane_uv, vec2(0.0), vec2(1.0));
	float edge = min(min(p.x, 1.0 - p.x), min(p.y, 1.0 - p.y));
	float inset = smoothstep(0.0, 0.12, edge);
	float warm_center = max(0.0, 1.0 - length((p - vec2(0.5, 0.42)) * vec2(1.4, 1.0)));
	float grain = fract(sin(dot(floor(p * 32.0), vec2(12.9898, 78.233))) * 43758.5453);
	ALBEDO = mix(vec3(0.12, 0.065, 0.028), vec3(0.65, 0.38, 0.16), inset) * (0.94 + grain * 0.06);
	// Windows are luminous interiors, not brown surfaces lit by street lamps.
	// Keep the inset dark while lifting the pane above the glow threshold.
	EMISSION = vec3(1.0, 0.48, 0.13) * inset * (0.85 + 2.0 * warm_center);
	ROUGHNESS = 0.9;
}
