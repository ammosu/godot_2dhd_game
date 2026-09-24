shader_type spatial;
render_mode unshaded, cull_disabled;
#include "res://shaders/hero_palette.gdshaderinc"
uniform sampler2D character_texture : source_color, filter_nearest;
uniform bool upright = false;
uniform vec4 sprite_tint : source_color = vec4(1.0);
uniform float alpha_threshold = 0.3;
void vertex() {
	vec3 up = upright ? vec3(0.0, 1.0, 0.0) : INV_VIEW_MATRIX[1].xyz;
	vec3 right = upright ? normalize(cross(up, INV_VIEW_MATRIX[2].xyz)) : INV_VIEW_MATRIX[0].xyz;
	vec3 facing = cross(right, up);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(vec4(right * length(MODEL_MATRIX[0].xyz), 0.0), vec4(up * length(MODEL_MATRIX[1].xyz), 0.0), vec4(facing, 0.0), MODEL_MATRIX[3]);
}
vec3 to_srgb(vec3 c) {
	return mix(c * 12.92, 1.055 * pow(max(c, vec3(0.0)), vec3(1.0 / 2.4)) - 0.055, step(vec3(0.0031308), c));
}
vec3 to_linear(vec3 c) {
	return mix(c / 12.92, pow(max((c + 0.055) / 1.055, vec3(0.0)), vec3(2.4)), step(vec3(0.04045), c));
}
void fragment() {
	vec4 sample_color = texture(character_texture, UV);
	if (sample_color.a < alpha_threshold) { discard; }
	vec3 styled;
	if (OUTPUT_IS_SRGB) {
		styled = style_pixel(sample_color.rgb, UV);
	} else {
		styled = to_linear(style_with_palette(to_srgb(sample_color.rgb), UV, to_srgb(hair_color.rgb), to_srgb(cloth_color.rgb)));
	}
	ALBEDO = styled * sprite_tint.rgb;
	ALPHA = sample_color.a * sprite_tint.a;
	ALPHA_SCISSOR_THRESHOLD = alpha_threshold;
}
