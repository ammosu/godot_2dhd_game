shader_type spatial;
render_mode cull_disabled;
uniform float flow_speed = 0.2;
uniform vec2 step_position = vec2(1000.0);
uniform float ripple_age = 2.0;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void fragment() {
	vec2 p = floor(UV * 32.0) / 32.0;
	float depth = smoothstep(0.0, 0.85, COLOR.r);
	float stones = hash(floor(p * 9.0));
	vec3 sand = mix(vec3(0.24, 0.35, 0.28), vec3(0.42, 0.49, 0.34), stones);
	vec3 body = mix(sand, vec3(0.035, 0.19, 0.25), depth);
	float wave = sin(p.y * 22.0 + sin(p.x * 4.0 - TIME * flow_speed) * 1.8 + TIME * 1.4);
	float flecks = step(0.7, hash(floor((p - vec2(TIME * flow_speed, 0.0)) * 5.0)));
	float crest = smoothstep(0.93, 1.0, wave) * flecks;
	float shore = 1.0 - smoothstep(0.0, 0.12, COLOR.r);
	float ring = (1.0 - smoothstep(0.025, 0.075, abs(length(p - step_position) - ripple_age * 1.2))) * max(0.0, 1.0 - ripple_age / 1.3);
	ALBEDO = body + vec3(0.25, 0.47, 0.43) * (crest * 0.45 + shore * 0.3 + ring * 0.9);
	ROUGHNESS = 0.3;
	METALLIC = 0.12;
	EMISSION = vec3(0.12, 0.25, 0.24) * (crest * 0.12 + ring * 0.25);
}
