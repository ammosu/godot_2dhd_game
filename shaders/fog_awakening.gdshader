shader_type canvas_item;
uniform sampler2D closed_texture : source_color, filter_nearest;
uniform float openness : hint_range(0.0, 1.0) = 0.0;
varying vec4 tint;

void vertex() {
	tint = COLOR;
}

void fragment() {
	vec4 opened = texture(TEXTURE, UV);
	vec4 closed = texture(closed_texture, UV);
	// Only the tiny eye neighborhood changes. The original forest never drifts.
	vec2 center = vec2(0.506, 0.3815);
	float neighborhood = 1.0 - smoothstep(0.75, 1.0, length((UV - center) / vec2(0.018, 0.012)));
	float aperture = 1.0 - smoothstep(openness * 0.008, openness * 0.008 + 0.001, abs(UV.y - center.y));
	aperture *= smoothstep(0.0, 0.15, openness);
	COLOR = tint * mix(opened, closed, neighborhood * (1.0 - aperture));
}
