shader_type spatial;
render_mode specular_disabled, cull_disabled;
uniform sampler2D rock_texture : source_color, filter_nearest_mipmap, repeat_enable;
uniform sampler2D moss_texture : source_color, filter_nearest_mipmap, repeat_enable;
uniform vec4 tint : source_color = vec4(0.75, 0.81, 0.78, 1.0);
varying vec3 world_position;
varying vec3 terrain_normal;
void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	terrain_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}
void fragment() {
	vec3 n = abs(normalize(terrain_normal));
	vec3 weights = pow(n, vec3(4.0));
	weights /= max(dot(weights, vec3(1.0)), 0.001);
	vec3 p = world_position / 4.0;
	vec3 rock = texture(rock_texture, p.zy).rgb * weights.x + texture(rock_texture, p.xz).rgb * weights.y + texture(rock_texture, p.xy).rgb * weights.z;
	vec3 moss = texture(moss_texture, world_position.xz / 5.0).rgb * vec3(0.49, 0.63, 0.42);
	float patch = sin(world_position.x * 1.4 + sin(world_position.z * 0.8)) * 0.06;
	float shelf = smoothstep(0.52, 0.88, n.y + patch);
	ALBEDO = mix(rock, moss, shelf * 0.87) * tint.rgb;
	ROUGHNESS = 1.0;
}
