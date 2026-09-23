shader_type spatial;
render_mode cull_disabled;
uniform sampler2D atlas : source_color, filter_nearest_mipmap, repeat_disable;
uniform vec2 quadrant = vec2(0.0);
uniform float scale_uv = 0.32;
uniform vec4 tint : source_color = vec4(1.0);
uniform bool panel = false;
uniform vec2 panel_tiles = vec2(1.0);
varying vec3 local_position;
varying vec3 local_normal;
void vertex() { local_position = VERTEX; local_normal = NORMAL; }
void fragment() {
	vec3 weights = abs(local_normal);
	vec2 projected = weights.y > weights.x && weights.y > weights.z ? local_position.xz : (weights.x > weights.z ? local_position.zy : local_position.xy);
	vec2 mapped = (quadrant + mix(vec2(0.004), vec2(0.996), fract(projected * scale_uv))) * 0.5;
	vec3 stone = texture(atlas, mapped, 0.4).rgb;
	if (panel) { stone = texture(atlas, (quadrant + mix(vec2(0.003), vec2(0.997), fract(UV * panel_tiles))) * 0.5).rgb; }
	ALBEDO = stone * tint.rgb * COLOR.rgb;
	ROUGHNESS = 0.88;
	SPECULAR = 0.22;
}
