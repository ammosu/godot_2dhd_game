shader_type spatial;
render_mode specular_disabled, cull_disabled, depth_prepass_alpha;
uniform sampler2D grass_texture : source_color, filter_nearest_mipmap, repeat_enable;
uniform sampler2D soil_texture : source_color, filter_nearest_mipmap, repeat_enable;
uniform sampler2D gravel_texture : source_color, filter_nearest_mipmap, repeat_enable;
uniform sampler2D rock_texture : source_color, filter_nearest_mipmap, repeat_enable;
varying vec3 world_position;
varying vec3 ground_normal;
void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	ground_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}
void fragment() {
	vec2 p = world_position.xz;
	vec3 meadow = texture(grass_texture, p / 5.0).rgb;
	float dry = smoothstep(-0.55, 0.75, sin(p.x * 0.73 + sin(p.y * 0.51)) * cos(p.y * 0.63 + p.x * 0.17));
	vec3 grass = meadow * mix(vec3(0.37, 0.55, 0.35), vec3(0.75, 0.70, 0.39), dry);
	vec3 soil = texture(soil_texture, p / 5.5).rgb * vec3(0.90, 0.84, 0.73);
	float patches = smoothstep(-0.3, 0.7, sin(p.x * 1.1 + sin(p.y * 0.8)) * cos(p.y * 0.7));
	soil = mix(soil, texture(gravel_texture, p / 6.0).rgb * vec3(0.86, 0.83, 0.76), patches * 0.55);
	vec3 n = abs(normalize(ground_normal));
	vec3 weights = pow(n, vec3(4.0));
	weights /= max(dot(weights, vec3(1.0)), 0.001);
	vec3 rock = texture(rock_texture, world_position.zy / 4.0).rgb * weights.x + texture(rock_texture, p / 4.0).rgb * weights.y + texture(rock_texture, world_position.xy / 4.0).rgb * weights.z;
	float slope = 1.0 - smoothstep(0.60, 0.86, n.y);
	vec3 bank = mix(grass, rock * vec3(0.72, 0.81, 0.77), slope);
	ALBEDO = mix(bank, soil, COLOR.r);
	ALPHA = 1.0 - COLOR.g;
	ROUGHNESS = 1.0;
}
