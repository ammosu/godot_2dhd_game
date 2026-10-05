shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never;
// Vaulted moonlight portal. Unshaded colour only (no emission or glow), so it reads
// the same in Forward+ and Compatibility.
uniform vec3 core_color : source_color = vec3(0.39, 0.87, 1.0);
uniform vec3 deep_color : source_color = vec3(0.006, 0.02, 0.06);
// 0 far away, 1 when the traveler stands at the threshold.
uniform float proximity : hint_range(0.0, 1.0) = 0.0;
// 0 idle, 1 at the instant of crossing.
uniform float surge : hint_range(0.0, 1.0) = 0.0;
uniform float arch_height = 3.55;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void fragment() {
	// Straight jambs and a semicircular crown, flush to the sill.
	float x = (UV.x - 0.5) * 2.0;
	float height = (1.0 - UV.y) * arch_height;
	float distance_to_edge = min(1.0 - abs(x), height / 1.22);
	if (height > 2.3) {
		distance_to_edge = 1.0 - length(vec2(x, (height - 2.3) / 1.22));
	}
	vec2 p = vec2(x * 1.22, height - 1.75) / 1.75;
	float r = length(p);
	float a = atan(p.y, p.x);
	float speed = 1.4 + proximity * 1.6 + surge * 7.0;
	// Spiral arms drawn inward, broken up by drifting noise.
	float twist = a + r * 3.4 - TIME * speed * 0.55;
	float arms = 0.5 + 0.5 * sin(twist * 3.0 + value_noise(p * 3.0 + TIME * 0.3) * 3.0);
	float fine = value_noise(vec2(twist * 2.2, r * 7.0 - TIME * speed));
	float swirl = pow(arms, 3.0) * 0.7 + fine * 0.35;
	float core = exp(-r * r * (6.0 - surge * 4.8)) * (0.3 + 0.6 * proximity + surge * 2.2);
	float rim = exp(-abs(distance_to_edge - 0.045) * 38.0);
	// Rune marks travel round the rim and wake as the traveler approaches.
	float rune = step(0.62, fract(a * 1.9 + TIME * 0.12)) * step(0.4, fract(height * 2.6)) * rim;
	vec3 color = mix(deep_color, core_color * 0.6, swirl * (0.42 + 0.38 * proximity + surge * 0.5));
	color += core_color * core;
	color += core_color * rim * (1.1 + proximity * 0.7 + surge * 2.0);
	color += vec3(0.85, 0.96, 1.0) * rune * (0.15 + 0.6 * proximity);
	color = mix(color, vec3(0.9, 0.97, 1.0), surge * surge * 0.7 * exp(-r * 1.4));
	ALBEDO = color;
	ALPHA = smoothstep(0.0, 0.02, distance_to_edge) * 0.97;
}
