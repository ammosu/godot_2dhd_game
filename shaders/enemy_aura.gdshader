shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
uniform float energy : hint_range(0.0, 1.0) = 0.45;
void fragment() {
	float radius = length((UV - vec2(0.5)) * 2.0);
	float ring = 1.0 - smoothstep(0.012, 0.035, abs(radius - 0.62));
	float halo = exp(-pow((radius - 0.57) * 3.0, 2.0)) * (1.0 - smoothstep(0.8, 1.0, radius));
	ALBEDO = vec3(0.52, 0.20, 0.85);
	ALPHA = (ring * 0.65 + halo * 0.30) * energy;
}
