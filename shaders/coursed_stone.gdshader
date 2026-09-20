shader_type spatial;

uniform sampler2D stone_texture : source_color, filter_nearest, repeat_enable;
uniform vec4 stone_tint : source_color = vec4(0.48, 0.49, 0.55, 1.0);
varying vec3 world_position;
varying vec3 world_normal;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 n = abs(world_normal);
	vec2 face = n.y > 0.5 ? world_position.xz : (n.x > n.z ? world_position.zy : world_position.xy);
	vec2 p = floor(face * 64.0) / 64.0;
	vec2 courses = p / vec2(0.58, 0.29);
	courses.x += mod(floor(courses.y), 2.0) * 0.5;
	vec2 cell = floor(courses);
	vec2 edge = min(fract(courses), 1.0 - fract(courses)) * vec2(0.58, 0.29);
	float joint = smoothstep(0.008, 0.026, min(edge.x, edge.y));
	float variation = fract(sin(dot(cell, vec2(127.1, 311.7))) * 43758.5453);
	vec3 stone = texture(stone_texture, p / 0.8).rgb * stone_tint.rgb;
	stone *= mix(0.88, 1.08, variation);
	ALBEDO = stone * mix(0.48, 1.0, joint);
	ROUGHNESS = 0.96;
}
