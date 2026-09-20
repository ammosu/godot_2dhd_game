shader_type spatial;
render_mode specular_disabled;

uniform sampler2D meadow_texture : source_color, filter_nearest, repeat_enable;
uniform sampler2D cobble_texture : source_color, filter_nearest, repeat_enable;
uniform bool road_surface = false;
// Filled from the actual BoxMesh footprints, never a second map definition.
uniform vec4 plaza_rect;
uniform vec4 north_rect;
uniform vec4 market_rect;
uniform vec4 gate_rect;
uniform vec4 meadow_base : source_color = vec4(0.24, 0.32, 0.26, 1.0);
uniform vec4 soil_color : source_color = vec4(0.30, 0.29, 0.23, 1.0);
varying vec3 surface_world;

float rectangle_distance(vec2 point, vec2 center, vec2 half_size) {
	vec2 d = abs(point - center) - half_size;
	return length(max(d, vec2(0.0))) + min(max(d.x, d.y), 0.0);
}

void vertex() {
	surface_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// One world-space sampling grid keeps separate road meshes and ground aligned.
	vec2 p = floor(surface_world.xz * 72.0) / 72.0;
	vec3 meadow = texture(meadow_texture, p / 4.0).rgb;
	float patches = sin(p.x * 0.83 + sin(p.y * 0.61)) * sin(p.y * 0.74 - p.x * 0.28);
	vec3 grass = mix(meadow_base.rgb, meadow, 0.22) * (0.94 + patches * 0.10);
	// Union of the actual plaza and three roads: no false borders at crossings.
	float edge = rectangle_distance(p, plaza_rect.xy, plaza_rect.zw);
	edge = min(edge, rectangle_distance(p, north_rect.xy, north_rect.zw));
	edge = min(edge, rectangle_distance(p, market_rect.xy, market_rect.zw));
	edge = min(edge, rectangle_distance(p, gate_rect.xy, gate_rect.zw));
	float breakup = sin(p.x * 14.0 + sin(p.y * 9.0)) * sin(p.y * 17.0 + p.x * 3.0);
	float wear = 1.0 - smoothstep(0.0, 0.40, max(edge, 0.0));
	grass = mix(grass, soil_color.rgb, wear * 0.13);
	if (road_surface) {
		vec3 cobble = texture(cobble_texture, p / 5.0).rgb * vec3(0.68, 0.62, 0.65);
		float paving = smoothstep(0.04, 0.32, -edge + breakup * 0.10);
		ALBEDO = mix(grass, cobble, paving);
	} else {
		ALBEDO = grass;
	}
	ROUGHNESS = 1.0;
}
