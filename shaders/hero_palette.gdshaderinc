uniform vec4 hair_color : source_color = vec4(1.0);
uniform vec4 cloth_color : source_color = vec4(1.0);
uniform vec4 frame_rect = vec4(0.0, 0.0, 1.0, 1.0);

vec3 style_with_palette(vec3 color, vec2 uv, vec3 hair_tint, vec3 cloth_tint) {
	float high = max(color.r, max(color.g, color.b));
	float low = min(color.r, min(color.g, color.b));
	float chroma = high - low;
	float saturation = chroma / max(high, 0.001);
	vec2 local_uv = (uv - frame_rect.xy) / max(frame_rect.zw, vec2(0.0001));
	// Neutral highlights in the head region are silver hair. Skin and warm
	// leather are deliberately excluded from the cool garment color mask.
	float hair = (1.0 - smoothstep(0.18, 0.30, saturation)) * step(0.20, high)
		* (1.0 - smoothstep(0.30, 0.40, local_uv.y));
	float cool = smoothstep(0.01, 0.05, max(color.b - color.r, color.g - color.r));
	float purple = step(color.g + 0.02, color.b) * step(color.r * 0.65, color.b);
	float cloth = max(cool, purple) * smoothstep(0.14, 0.28, saturation) * (1.0 - hair);
	vec3 result = mix(color, cloth_tint * (high * 1.25 + 0.035), cloth * 0.92);
	return mix(result, hair_tint * (high * 1.12 + 0.025), hair * 0.95);
}

vec3 style_pixel(vec3 color, vec2 uv) {
	return style_with_palette(color, uv, hair_color.rgb, cloth_color.rgb);
}
