shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform float strength = 0.18;

void fragment() {
	vec2 p = abs(UV * 2.0 - 1.0);
	float rounded_box = pow(pow(p.x, 4.0) + pow(p.y, 4.0), 0.25);
	ALBEDO = vec3(0.045, 0.032, 0.026);
	ALPHA = (1.0 - smoothstep(0.25, 1.0, rounded_box)) * strength;
}
