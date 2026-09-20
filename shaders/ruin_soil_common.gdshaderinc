uniform sampler2D mineral_texture : source_color, filter_nearest, repeat_enable;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float field(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(cell), hash(cell + vec2(1.0, 0.0)), f.x),
		mix(hash(cell + vec2(0.0, 1.0)), hash(cell + vec2(1.0)), f.x), f.y);
}

vec3 sample_ruin_soil(vec2 position) {
	// Fixed world-space pixels: no scrolling noise or dependence on box UVs.
	vec2 p = floor(position * 64.0) / 64.0;
	float drift = field(p * 0.38 + vec2(5.1, 2.8));
	float grit = field(p * 13.0);
	vec3 mineral_sample = texture(mineral_texture, p / 2.7).rgb;
	if (OUTPUT_IS_SRGB) {
		mineral_sample = mix(mineral_sample / 12.92, pow((mineral_sample + 0.055) / 1.055, vec3(2.4)), step(vec3(0.04045), mineral_sample));
	}
	float mineral = dot(mineral_sample, vec3(0.299, 0.587, 0.114));
	vec3 earth = mix(vec3(0.040, 0.038, 0.035), vec3(0.095, 0.085, 0.070), drift);
	earth *= 0.78 + grit * 0.30 + mineral * 0.22;
	// Scattered angular chips, jittered inside cells to avoid regular dot rows.
	vec2 cell = floor(p * 5.0);
	vec2 jitter = vec2(hash(cell + vec2(3.7, 0.2)), hash(cell + vec2(0.4, 8.1)));
	vec2 d = fract(p * 5.0) - jitter;
	float chip_distance = abs(d.x + d.y * 0.35) + abs(d.y) * 1.4;
	float radius = 0.08 + hash(cell + vec2(12.7)) * 0.13;
	float cluster = smoothstep(0.42, 0.66, field(p * 0.95));
	float chip = (1.0 - smoothstep(radius * 0.65, radius, chip_distance)) * step(0.65, hash(cell)) * cluster;
	vec3 stone = vec3(0.115, 0.108, 0.092) * (0.85 + hash(cell + vec2(9.0)) * 0.25);
	vec3 result = mix(earth, stone, chip * 0.65);
	if (OUTPUT_IS_SRGB) {
		result = mix(result * 12.92, 1.055 * pow(result, vec3(1.0 / 2.4)) - 0.055, step(vec3(0.0031308), result));
	}
	return result;
}
