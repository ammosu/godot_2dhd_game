shader_type spatial;
render_mode specular_disabled;

// Opaque frosted glass: the light source is diffused, not a white solid cube.
// Pixel-scale variation and the dark gasket stay readable at game distance.
void fragment() {
	vec2 p = floor(UV * vec2(20.0, 28.0));
	float grain = fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
	float edge = min(min(UV.x, 1.0 - UV.x), min(UV.y, 1.0 - UV.y));
	float pane = smoothstep(0.015, 0.095, edge);
	float core = pow(max(0.0, 1.0 - length((UV - vec2(0.5, 0.48)) * vec2(1.8, 1.3))), 2.0);
	vec3 amber = mix(vec3(0.28, 0.105, 0.025), vec3(0.82, 0.47, 0.13), core);
	ALBEDO = mix(vec3(0.045, 0.034, 0.022), amber * (0.90 + grain * 0.12), pane);
	EMISSION = vec3(1.0, 0.48, 0.12) * pane * (0.28 + core * 0.90) * (0.94 + grain * 0.06);
	ROUGHNESS = 0.85;
}
