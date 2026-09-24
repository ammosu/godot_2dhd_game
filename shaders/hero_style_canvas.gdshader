shader_type canvas_item;
#include "res://shaders/hero_palette.gdshaderinc"
varying vec4 vertex_tint;
void vertex() { vertex_tint = COLOR; }
void fragment() {
	vec4 sample_color = texture(TEXTURE, UV);
	COLOR = vertex_tint * vec4(style_pixel(sample_color.rgb, UV), sample_color.a);
}
