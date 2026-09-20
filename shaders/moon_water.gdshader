shader_type spatial;
render_mode cull_disabled;

uniform vec4 deep_color : source_color = vec4(0.055, 0.16, 0.23, 1.0);
uniform vec4 crest_color : source_color = vec4(0.28, 0.60, 0.65, 1.0);
uniform vec2 water_size = vec2(9.0, 5.0);
uniform float glow = 0.08;

float water_hash(vec2 cell) {
	return fract(sin(dot(cell, vec2(127.1, 311.7))) * 43758.5453);
}

float water_field(vec2 p) {
	vec2 cell = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(water_hash(cell), water_hash(cell + vec2(1.0, 0.0)), f.x),
		mix(water_hash(cell + vec2(0.0, 1.0)), water_hash(cell + vec2(1.0)), f.x), f.y);
}

void fragment() {
	// Quantized world-scale ripples, without screen/depth textures: also runs on Web.
	vec2 p = floor(UV * water_size * 28.0) / 28.0;
	float drift = water_field(p * 0.75 + vec2(TIME * 0.035, -TIME * 0.025));
	float patches = water_field(p * vec2(2.2, 1.4) + vec2(-TIME * 0.09, TIME * 0.045));
	// Interfering directions and drifting patches break up long ruler-like bands.
	float wave = sin(p.y * 10.0 + sin(p.x * 2.4 + TIME * 0.18) * 1.9 + drift * 3.5 + TIME * 0.65);
	float cross_wave = sin(dot(p, vec2(6.5, -8.0)) + drift * 2.0 - TIME * 0.48);
	float crest = smoothstep(0.90, 1.0, wave) * smoothstep(0.42, 0.68, patches);
	crest += smoothstep(0.97, 1.0, cross_wave) * smoothstep(0.65, 0.85, patches) * 0.35;
	vec2 edge_distance = min(UV, vec2(1.0) - UV) * water_size;
	float shore = 1.0 - smoothstep(0.025, 0.16, min(edge_distance.x, edge_distance.y));
	vec3 water_body = deep_color.rgb * mix(0.87, 1.12, drift);
	ALBEDO = mix(water_body, crest_color.rgb, crest * 0.3 + shore * 0.25);
	ROUGHNESS = 0.28;
	METALLIC = 0.15;
	EMISSION = crest_color.rgb * (crest + shore) * glow;
}
