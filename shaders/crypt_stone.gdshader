shader_type spatial;
render_mode cull_disabled;
uniform sampler2D atlas : source_color, filter_nearest_mipmap, repeat_disable;
uniform vec2 quadrant = vec2(0.0);
uniform float scale_uv = 0.32;
uniform vec4 tint : source_color = vec4(1.0);
uniform bool panel = false;
uniform vec2 panel_tiles = vec2(1.0);
uniform float dampness = 0.0;
varying vec3 world_position;
varying vec3 local_position;
varying vec3 local_normal;
void vertex() { world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; local_position = VERTEX; local_normal = NORMAL; }
void fragment() {
	vec3 weights = abs(local_normal);
	vec2 projected = weights.y > weights.x && weights.y > weights.z ? local_position.xz : (weights.x > weights.z ? local_position.zy : local_position.xy);
	vec2 mapped = (quadrant + mix(vec2(0.004), vec2(0.996), fract(projected * scale_uv))) * 0.5;
	vec3 stone = texture(atlas, mapped, 0.4).rgb;
	if (panel) { stone = texture(atlas, (quadrant + mix(vec2(0.003), vec2(0.997), fract(UV * panel_tiles))) * 0.5).rgb; }
	ALBEDO = stone * tint.rgb * COLOR.rgb;
	// Narrow descending stains and a mottled rising-damp band retain the stone texture.
	float stripe = sin(world_position.x * 7.3 + world_position.z * 5.8) * 0.5 + 0.5;
	float broken = sin(world_position.x * 2.7 - world_position.z * 3.4 + sin(world_position.z * 8.0)) * 0.5 + 0.5;
	float low_wall = (1.0 - smoothstep(0.10, 1.5 + stripe * 0.5, world_position.y)) * (0.35 + pow(stripe, 5.0) * 0.65);
	float damp_floor = smoothstep(0.42, 0.86, broken) * 0.52;
	float wet = dampness * mix(low_wall, damp_floor, step(0.8, weights.y));
	ALBEDO *= mix(vec3(1.0), vec3(0.48, 0.56, 0.55), wet);
	ROUGHNESS = mix(0.88, 0.24, wet);
	SPECULAR = mix(0.22, 0.65, wet);
}
