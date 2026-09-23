shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform int pattern = 0;
uniform vec2 center = vec2(0.0);
uniform float radius = 2.5;
uniform float progress = 0.0;
uniform float burst = 0.0;
uniform float phase = 0.0;
uniform float wave_radius = 0.0;
varying vec2 world_xz;
vec2 hash2(vec2 p) { return fract(sin(vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)))) * 43758.5453); }
float fissure(vec2 p) {
	vec2 cell = floor(p); vec2 f = fract(p);
	float first = 9.0; float second = 9.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 offset = vec2(float(x), float(y));
			vec2 r = offset + hash2(cell + offset) - f;
			float d = dot(r, r);
			second = max(first, min(second, d)); first = min(first, d);
		}
	}
	return second - first;
}
float sigil(vec2 uv) {
	vec2 p = abs(uv - vec2(0.5));
	float spine = (1.0 - step(0.055, p.x)) * (1.0 - step(0.37, p.y));
	float wings = (1.0 - step(0.045, abs(p.x + p.y - 0.30))) * (1.0 - step(0.25, p.y));
	return max(spine, wings);
}
void vertex() { world_xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz; }
void fragment() {
	vec2 p = world_xz - center;
	float d = length(p);
	float r = pattern == 1 ? (burst > 0.0 ? wave_radius : 1.3) : radius;
	float jitter = sin(atan(p.y, p.x) * 37.0 + phase * 5.0) * 0.035 + sin(atan(p.y, p.x) * 73.0) * 0.025;
	float dist = abs(d - r + jitter);
	float band = 1.0 - smoothstep(0.4, 0.65, dist);
	float inside = 1.0 - step(r, d);
	float danger = pattern == 1 ? band : inside;
	float edge = 1.0 - smoothstep(0.02, 0.055, dist);
	float echo = 1.0 - smoothstep(0.025, 0.07, abs(d - r + 0.32 + jitter));
	float cracks = fissure(world_xz * 1.5 + vec2(sin(world_xz.y * 4.0), cos(world_xz.x * 4.0)) * 0.12);
	float core = 1.0 - smoothstep(0.008, 0.025, cracks);
	float halo = exp(-dist * 2.5);
	float fine = 1.0 - smoothstep(0.003, 0.018, fissure(world_xz * 3.7));
	float branches = max(core, fine * 0.45) * (1.0 - smoothstep(0.45, 1.15, dist));
	float reflection = pow(max(0.0, sin(world_xz.x * 19.0 + sin(world_xz.y * 5.0))), 8.0) * exp(-dist * 1.4) * 0.14;
	float hot = 0.60 + 0.4 * sin(atan(p.y, p.x) * 11.0 + phase * 3.0);
	float front = smoothstep(0.0, 1.0, p.y);
	float mirror_dist = abs(length(p - vec2(0.0, 0.8)) - r);
	float streaks = smoothstep(0.62, 0.95, hash2(vec2(floor(world_xz.x * 13.0), floor(world_xz.y * 1.8))).x) * (0.3 + 0.7 * hash2(floor(world_xz * 12.0)).y);
	float mirrored = exp(-mirror_dist * 2.7) * streaks * front * 0.22;
	branches *= 0.35 + 0.65 * hot;
	float power = progress * 0.2 + burst;
	ALBEDO = mix(vec3(0.85, 0.10, 0.005), vec3(1.0, 0.85, 0.32), edge);
	EMISSION = vec3(1.0, 0.20, 0.012) * (branches * 2.2 + halo * 0.7 + reflection * 2.0 + mirrored * 6.0) * power + edge * vec3(3.5, 2.3, 0.7) * hot + echo * vec3(2.0, 0.7, 0.1);
	ALPHA = clamp(danger * 0.04 + (branches * 0.85 + halo * 0.22 + reflection + mirrored) * power + edge + echo * 0.7, 0.0, 0.97);
}
