shader_type spatial;
render_mode specular_disabled, cull_disabled;
// Nearest texels preserve pixel art; mip levels prevent distant texture sparkle.
uniform sampler2D paving : source_color, filter_nearest_mipmap, repeat_enable;
uniform sampler2D meadow : source_color, filter_nearest_mipmap, repeat_enable;
uniform sampler2D weathered : source_color, filter_nearest_mipmap, repeat_enable;
uniform bool road = false;
uniform bool lane = false;
varying vec3 world_position;
void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	vec2 p = world_position.xz;
	vec3 grass = texture(meadow, p / 5.5).rgb;
	grass = mix(vec3(0.035, 0.075, 0.038), grass * 0.45, 0.3);
	float patches = sin(p.x * 0.31 + sin(p.y * 0.37)) * sin(p.y * 0.26);
	grass *= 0.96 + patches * 0.12;
	vec3 stone = texture(paving, p / 6.0).rgb * vec3(0.93, 0.89, 0.82);
	if (lane) {
		stone = mix(stone, texture(weathered, p / 5.0).rgb, 0.3);
	}
	ALBEDO = road ? stone : grass;
	ROUGHNESS = 1.0;
}
