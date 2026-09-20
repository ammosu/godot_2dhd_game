shader_type spatial;
render_mode cull_disabled;

uniform vec4 deep_color : source_color = vec4(0.055, 0.16, 0.23, 1.0);
uniform vec4 crest_color : source_color = vec4(0.28, 0.60, 0.65, 1.0);
uniform vec2 water_size = vec2(9.0, 5.0);
uniform float glow = 0.08;

void fragment() {
	// Quantized world-scale ripples, without screen/depth textures: also runs on Web.
	vec2 p = floor(UV * water_size * 28.0) / 28.0;
	float wave = sin(p.y * 12.0 + sin(p.x * 1.7 + TIME * 0.2) * 0.8 + TIME * 0.65);
	float breakup = smoothstep(-0.2, 0.8, sin(p.x * 2.1 - p.y * 0.7 - TIME * 0.12));
	float crest = smoothstep(0.96, 1.0, wave) * breakup;
	vec2 edge_distance = min(UV, vec2(1.0) - UV) * water_size;
	float shore = 1.0 - smoothstep(0.025, 0.16, min(edge_distance.x, edge_distance.y));
	ALBEDO = mix(deep_color.rgb, crest_color.rgb, crest * 0.3 + shore * 0.25);
	ROUGHNESS = 0.28;
	METALLIC = 0.15;
	EMISSION = crest_color.rgb * (crest + shore) * glow;
}
