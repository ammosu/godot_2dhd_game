shader_type canvas_item;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.34;
uniform float warmth : hint_range(0.0, 0.2) = 0.035;

void fragment() {
	vec4 scene = texture(screen_texture, SCREEN_UV);
	vec2 centered_uv = UV * 2.0 - 1.0;
	float edge = smoothstep(0.48, 1.35, length(centered_uv * vec2(0.78, 1.0)));
	vec3 warm_tint = vec3(1.0 + warmth, 1.0, 1.0 - warmth * 0.8);
	vec3 graded = scene.rgb * warm_tint;
	graded *= 1.0 - edge * vignette_strength;
	COLOR = vec4(graded, scene.a);
}
