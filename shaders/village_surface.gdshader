shader_type spatial;
render_mode specular_disabled, cull_disabled;

uniform sampler2D meadow_texture : source_color, filter_nearest, repeat_enable;
uniform sampler2D cobble_texture : source_color, filter_nearest, repeat_enable;
uniform sampler2D dirt_texture : source_color, filter_nearest, repeat_enable;
uniform sampler2D broken_texture : source_color, filter_nearest, repeat_enable;
uniform sampler2D dry_grass_texture : source_color, filter_nearest, repeat_enable;
// 0: maintained paving, 1: weathered stone, 2: compacted earth/gravel.
uniform int road_kind = 0;
uniform bool polygon_surface = false;
uniform bool road_surface = false;
uniform bool organic_village = false;
uniform float road_brightness = 1.0;
uniform bool planted_island = true;
// Filled from the actual BoxMesh footprints, never a second map definition.
uniform vec4 plaza_rect;
uniform vec4 north_rect;
uniform vec4 market_rect;
uniform vec4 gate_rect;
uniform vec4 meadow_base : source_color = vec4(0.24, 0.32, 0.26, 1.0);
uniform vec4 soil_color : source_color = vec4(0.30, 0.29, 0.23, 1.0);
varying vec3 surface_world;

float terrain_hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float terrain_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(terrain_hash(i), terrain_hash(i + vec2(1.0, 0.0)), f.x),
		mix(terrain_hash(i + vec2(0.0, 1.0)), terrain_hash(i + vec2(1.0)), f.x), f.y);
}

float rectangle_distance(vec2 point, vec2 center, vec2 half_size) {
	vec2 d = abs(point - center) - half_size;
	return length(max(d, vec2(0.0))) + min(max(d.x, d.y), 0.0);
}

// Continuous world-space paths: the ground and shallow overlays share this mask.
float village_distance(vec2 p) {
	vec2 plaza = p - vec2(0.2, 0.1);
	float edge = (length(plaza / vec2(4.25, 4.1)) - 1.0) * 4.1;
	edge += sin(p.x * 1.3 + p.y * 0.8) * 0.12;
	vec2 north = p;
	north.x -= sin(p.y * 0.30) * 0.48;
	edge = min(edge, rectangle_distance(north, north_rect.xy, north_rect.zw));
	vec2 market = p;
	market.y -= sin(p.x * 0.28) * 0.65;
	edge = min(edge, rectangle_distance(market, market_rect.xy, market_rect.zw));
	vec2 gate = p;
	gate.y -= sin(p.x * 0.32 + 0.4) * 0.50;
	edge = min(edge, rectangle_distance(gate, gate_rect.xy, gate_rect.zw));
	// Share the east-road junction with the garden overlays to avoid grass seams.
	edge = min(edge, rectangle_distance(p, vec2(20.75, 4.6), vec2(6.25, 1.8)));
	// A softened, gently uneven perimeter instead of four ruler-straight sides.
	vec2 garden = p + vec2(sin(p.y * 0.32) * 0.38, sin(p.x * 0.25) * 0.40);
	float ring = rectangle_distance(garden, vec2(0.0), vec2(15.7, 13.5)) - 3.3;
	return min(edge, abs(ring) - 0.90);
}

void vertex() {
	surface_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// One world-space sampling grid keeps separate road meshes and ground aligned.
	vec2 p = floor(surface_world.xz * 72.0) / 72.0;
	vec3 meadow = texture(meadow_texture, p / 4.0).rgb;
	float patches = terrain_noise(p * 0.24) * 0.65 + terrain_noise(p * 0.73 + vec2(17.0)) * 0.35;
	float dry_patch = smoothstep(0.48, 0.76, patches);
	vec3 dry_grass = texture(dry_grass_texture, p / 3.7).rgb;
	vec3 dirt = texture(dirt_texture, p / 3.1).rgb;
	vec3 grass = mix(meadow_base.rgb, meadow, 0.30);
	grass = mix(grass, mix(meadow_base.rgb * vec3(1.15, 0.98, 0.77), dry_grass, 0.42), dry_patch * 0.68);
	grass *= 0.88 + patches * 0.22;
	float bare_patch = smoothstep(0.77, 0.92, terrain_noise(p * 0.62 + vec2(43.0)));
	grass = mix(grass, dirt * vec3(0.70, 0.76, 0.67), bare_patch * 0.30);
	// Union of the actual plaza and three roads: no false borders at crossings.
	float edge = rectangle_distance(p, plaza_rect.xy, plaza_rect.zw);
	edge = min(edge, rectangle_distance(p, north_rect.xy, north_rect.zw));
	edge = min(edge, rectangle_distance(p, market_rect.xy, market_rect.zw));
	edge = min(edge, rectangle_distance(p, gate_rect.xy, gate_rect.zw));
	if (organic_village) {
		edge = village_distance(p);
	}
	float breakup = sin(p.x * 14.0 + sin(p.y * 9.0)) * sin(p.y * 17.0 + p.x * 3.0);
	float wear = 1.0 - smoothstep(0.0, 0.40, max(edge, 0.0));
	grass = mix(grass, soil_color.rgb, wear * 0.13);
	if (road_surface || organic_village) {
		vec3 cobble = texture(cobble_texture, p / 3.2).rgb * vec3(0.96, 0.88, 0.78) * road_brightness;
		vec3 broken = texture(broken_texture, p / 3.4).rgb * vec3(0.94, 0.91, 0.85);
		float weathering = smoothstep(0.36, 0.74, terrain_noise(p * 0.47 + vec2(8.0)));
		float roughness_amount = road_kind == 0 ? 0.10 : 0.85;
		if (organic_village) {
			// Main village streets stay stone; peripheral garden paths become rougher.
			roughness_amount = mix(0.16, 0.88, smoothstep(11.0, 16.0, max(abs(p.x), abs(p.y))));
		}
		vec3 road = mix(cobble, broken, roughness_amount);
		road = mix(road, dirt, weathering * roughness_amount * 0.46);
		if (road_kind == 2) {
			road = mix(dirt, broken, weathering * 0.20);
		}
		// Soil gathers along the edges rather than uniformly dirtying every stone.
		float shoulder = 1.0 - smoothstep(0.05, 0.65, -edge);
		if (!polygon_surface) {
			road = mix(road, dirt, shoulder * roughness_amount * 0.50);
		}
		float paving = smoothstep(0.04, 0.32, -edge + breakup * 0.10);
		if (polygon_surface) {
			paving = 1.0;
		}
		// The central planted island breaks up the uninterrupted stone square.
		if (planted_island && !polygon_surface) {
			paving *= smoothstep(1.04, 1.40, length(p) + breakup * 0.045);
		}
		ALBEDO = mix(grass, road, paving);
	} else {
		ALBEDO = grass;
	}
	ROUGHNESS = 1.0;
}
