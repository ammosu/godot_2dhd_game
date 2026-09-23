shader_type spatial;
render_mode cull_disabled, depth_draw_never;
uniform sampler2D atlas : source_color, filter_nearest_mipmap, repeat_disable;
uniform vec2 extent = vec2(3.0, 2.0);
uniform vec3 reflected_light = vec3(0.0, 1.5, 0.0);
uniform vec4 light_tint : source_color = vec4(1.0, 0.48, 0.13, 1.0);
uniform float seed = 0.0;
uniform vec2 step_uv = vec2(-10.0);
uniform float step_age = 5.0;
varying vec3 world_at;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1)), f.x), f.y);
}
void vertex() { world_at = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float border = 1.0 - length(p) + (noise(p * 3.8 + seed) - 0.5) * 0.32;
	float cover = smoothstep(0.02, 0.18, border);
	float wave = sin(world_at.x * 9.0 + TIME * 1.3) * sin(world_at.z * 7.0 - TIME * 0.8);
	float distance_step = length((UV - step_uv) * extent);
	float ripple = sin(distance_step * 30.0 - step_age * 12.0) * exp(-pow((distance_step - step_age * 1.4) * 5.0, 2.0)) * max(0.0, 1.0 - step_age / 1.6);
	float drop_age = mod(TIME * 0.55 + seed, 2.5);
	float drop_dist = length((UV - vec2(0.43, 0.56)) * extent);
	float drops = sin(drop_dist * 38.0 - drop_age * 10.0) * exp(-pow((drop_dist - drop_age * 0.55) * 9.0, 2.0)) * max(0.0, 1.0 - drop_age);
	vec3 n = normalize(vec3(wave * 0.025 + ripple * 0.05, 1.0, cos(world_at.z * 8.0 + TIME) * 0.025 + drops * 0.04));
	NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
	vec3 reflected_at = vec3(reflected_light.x, -reflected_light.y, reflected_light.z);
	vec3 eye = normalize(INV_VIEW_MATRIX[3].xyz - world_at);
	vec3 reflection = normalize(world_at - reflected_at);
	float alignment = max(0.0, dot(eye, reflection));
	float streak = pow(alignment, 180.0) * (0.65 + wave * 0.18 + noise(world_at.xz * 13.0 + TIME * 0.3) * 0.22);
	vec3 stone = texture(atlas, mix(vec2(0.004), vec2(0.496), fract(world_at.xz * 0.25))).rgb;
	ALBEDO = mix(stone * vec3(0.26, 0.34, 0.40), vec3(0.06, 0.09, 0.11), 0.4);
	EMISSION = light_tint.rgb * streak * 0.18 * pow(0.5 + 0.5 * sin(world_at.x * 28.0 + wave), 6.0) + vec3(0.16, 0.24, 0.29) * (max(ripple, 0.0) + max(drops, 0.0)) * 0.18;
	ROUGHNESS = 0.38;
	SPECULAR = 0.0;
	METALLIC = 0.15;
	ALPHA = cover * 0.82;
}
