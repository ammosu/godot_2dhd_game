shader_type spatial;
render_mode specular_disabled;
#include "res://shaders/ruin_soil_common.gdshaderinc"

uniform sampler2D stone_texture : source_color, filter_nearest, repeat_enable;
uniform vec4 stone_tint : source_color = vec4(0.72157, 0.71765, 0.81569, 1.0);
// World-space center / half-size, supplied by the real court mesh dimensions.
uniform vec4 court_rect;
uniform vec4 neighbor_a;
uniform vec4 neighbor_b;
uniform vec2 stone_scale;
varying vec3 surface_world;

void vertex() {
	surface_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float inside_distance(vec2 p, vec4 rect) {
	vec2 to_edge = rect.zw - abs(p - rect.xy);
	return min(to_edge.x, to_edge.y);
}

void fragment() {
	vec2 p = floor(surface_world.xz * 64.0) / 64.0;
	float inset = max(inside_distance(p, court_rect), max(inside_distance(p, neighbor_a), inside_distance(p, neighbor_b)));
	float erosion = field(p * 3.6) * 0.22 + field(p * 11.0) * 0.055;
	float exposed = smoothstep(0.035, 0.38, inset - erosion);
	vec3 stone = texture(stone_texture, UV * stone_scale).rgb * stone_tint.rgb;
	ALBEDO = mix(sample_ruin_soil(p), stone, exposed);
	// Treat the tiny soil-covered box lip as ground, not a dark vertical wall.
	NORMAL = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
	ROUGHNESS = 1.0;
}
