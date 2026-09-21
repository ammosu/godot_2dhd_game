shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, depth_test_disabled, cull_disabled, fog_disabled;

uniform sampler2D character_texture : source_color, filter_nearest;
uniform sampler2D scene_depth : hint_depth_texture, repeat_disable, filter_nearest;
uniform vec4 silhouette_color : source_color = vec4(0.65, 0.85, 0.95, 0.28);
varying float character_depth;

void vertex() {
	// Match the upright, Y-locked player card. Tilting the card with the camera
	// sends the head behind the feet and into scenery behind the player.
	vec3 up = vec3(0.0, 1.0, 0.0);
	vec3 right = normalize(cross(up, INV_VIEW_MATRIX[2].xyz));
	vec3 facing = cross(right, up);
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(vec4(right, 0.0), vec4(up, 0.0), vec4(facing, 0.0), MODEL_MATRIX[3]);
	character_depth = -(MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).z;
}

void fragment() {
	float mask = texture(character_texture, UV).a;
	if (mask < 0.25) {
		discard;
	}
	float depth = texture(scene_depth, SCREEN_UV).r;
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	vec3 ndc = vec3(SCREEN_UV, depth) * 2.0 - 1.0;
#else
	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, depth);
#endif
	vec4 scene_position = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	float obstruction = character_depth - (-scene_position.z / scene_position.w);
	// Visible player pixels (including the player's own depth) receive no tint.
	if (obstruction <= 0.025) {
		discard;
	}
	ALBEDO = silhouette_color.rgb;
	ALPHA = silhouette_color.a * smoothstep(0.025, 0.12, obstruction);
}
