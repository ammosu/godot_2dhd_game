shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform float opacity : hint_range(0.0, 1.0) = 0.43;

void fragment() {
	float distance_from_center = length((UV - vec2(0.5)) * 2.0);
	ALBEDO = vec3(0.025, 0.022, 0.035);
	ALPHA = (1.0 - smoothstep(0.12, 1.0, distance_from_center)) * opacity;
}
