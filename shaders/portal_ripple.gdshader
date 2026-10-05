shader_type canvas_item;
// Full-screen portal crossing. `cover` grows a rippling disc of moonlight from
// `center` until the whole screen is lit (the map changes under it), and `open`
// grows a clear disc back out from the center on arrival.
uniform sampler2D screen_texture : hint_screen_texture, filter_linear;
uniform float cover : hint_range(0.0, 1.0) = 0.0;
uniform float open : hint_range(0.0, 1.0) = 1.0;
uniform vec2 center = vec2(0.5, 0.5);
uniform vec4 light_color : source_color = vec4(0.86, 0.95, 1.0, 1.0);
uniform vec4 deep_color : source_color = vec4(0.22, 0.48, 0.78, 1.0);

void fragment() {
	vec2 aspect = vec2(SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x, 1.0);
	vec2 d = (SCREEN_UV - center) * aspect;
	float r = length(d);
	// The screen is lit wherever the cover disc has reached and the open disc has not.
	// Both fronts start just behind the center (nothing at 0) and pass the farthest
	// corner (about 1.75 away when the center sits near an edge) at 1.
	float reach = cover * 2.2 - 0.2;
	float lit = smoothstep(r - 0.18, r + 0.02, reach);
	float clear = smoothstep(r - 0.18, r + 0.02, open * 2.2 - 0.2);
	float amount = lit * (1.0 - clear);
	// Ripples run ahead of the light front and pull the world toward the center.
	float front = (1.0 - abs(reach - r) * 4.0) * (1.0 - clear);
	float energy = max(cover * (1.0 - open), 0.0);
	float wave = sin(r * 52.0 - TIME * 16.0) * 0.010 * energy * (1.0 - smoothstep(0.0, 1.3, r));
	vec2 pull = -d * energy * energy * 0.08;
	vec2 offset = (r > 0.0001 ? d / r : vec2(0.0)) * wave + pull;
	vec3 world = texture(screen_texture, SCREEN_UV + offset / aspect).rgb;
	// Moonlight with slow concentric bands, deepening toward the edges.
	float bands = 0.95 + 0.05 * sin(r * 18.0 - TIME * 4.0);
	vec3 light = mix(light_color.rgb, deep_color.rgb, smoothstep(0.0, 1.4, r) * 0.6) * bands;
	vec3 color = mix(world, light, amount);
	color += light_color.rgb * clamp(front, 0.0, 1.0) * 0.35 * energy;
	COLOR = vec4(color, 1.0);
}
