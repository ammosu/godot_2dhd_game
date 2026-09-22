shader_type spatial;
render_mode diffuse_burley;

uniform sampler2D timber : source_color, filter_nearest, repeat_enable;
uniform vec4 wood_color : source_color = vec4(0.39, 0.25, 0.15, 1.0);
uniform vec3 dimensions = vec3(1.0);
varying vec3 local_point;
varying vec3 local_normal;

void vertex() {
	local_point = VERTEX;
	local_normal = NORMAL;
}

void fragment() {
	vec3 n = abs(local_normal);
	vec2 p = local_point.xz;
	vec2 extent = dimensions.xz;
	if (n.z > n.y && n.z > n.x) {
		p = local_point.xy;
		extent = dimensions.xy;
	} else if (n.x > n.y) {
		p = local_point.zy;
		extent = dimensions.zy;
	}
	// Long grain follows each board's longest direction at a stable physical scale.
	if (extent.y > extent.x) {
		p = p.yx;
		extent = extent.yx;
	}
	vec2 sample_point = floor(p * 120.0) / 120.0;
	vec3 grain = texture(timber, sample_point * vec2(0.32, 1.6)).rgb;
	float value = dot(grain, vec3(0.299, 0.587, 0.114));
	float edge_distance = min(extent.x * 0.5 - abs(p.x), extent.y * 0.5 - abs(p.y));
	float worn_edge = 1.0 - smoothstep(0.002, 0.018, edge_distance);
	// Restrained grain contrast keeps furniture distinct from weathered structural beams.
	ALBEDO = wood_color.rgb * (0.62 + sqrt(value) * 0.95) + vec3(0.035, 0.024, 0.013) * worn_edge;
	ROUGHNESS = mix(0.86, 0.72, worn_edge);
	SPECULAR = 0.2;
}
