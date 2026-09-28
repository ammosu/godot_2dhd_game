shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled;

// Overlay pass for a Y-locked Sprite3D: paints the sprite silhouette a solid
// colour. Sprite3D generates atlas-aware UVs, so sample the underlying atlas.
uniform sampler2D character_texture : source_color, filter_nearest;
uniform vec4 flash_color : source_color = vec4(1.0);
uniform float flash = 0.0;
uniform float alpha_threshold = 0.3;

void vertex() {
	// Same fixed-Y billboard (with kept scale) as the sprite's own material.
	vec3 up = vec3(0.0, 1.0, 0.0);
	vec3 right = normalize(cross(up, INV_VIEW_MATRIX[2].xyz));
	vec3 facing = cross(right, up);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(vec4(right * length(MODEL_MATRIX[0].xyz), 0.0), vec4(up * length(MODEL_MATRIX[1].xyz), 0.0), vec4(facing * length(MODEL_MATRIX[2].xyz), 0.0), MODEL_MATRIX[3]);
	// Nudge toward the camera so the overlay never z-fights its own sprite.
	MODELVIEW_MATRIX[3].z += 0.01;
}

void fragment() {
	float mask = texture(character_texture, UV).a;
	if (mask < alpha_threshold) {
		discard;
	}
	ALBEDO = flash_color.rgb;
	ALPHA = clamp(flash, 0.0, 1.0) * flash_color.a;
}
