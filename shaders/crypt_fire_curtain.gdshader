shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;
uniform sampler2D flames : source_color, filter_linear_mipmap, repeat_disable;
uniform float age = 0.0;
uniform float opacity = 1.0;
varying vec3 world_at;
void vertex() { world_at = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	float around = UV.x * 24.0;
	float tile = floor(around);
	float drift = sin(tile * 7.31 + age * 6.0) * 0.07;
	vec2 uv = vec2(fract(around) * 0.72 + 0.14, clamp(UV.y + drift * (1.0 - UV.y), 0.0, 1.0));
	vec4 a = textureLod(flames, vec2(0.5 + uv.x * 0.5, uv.y * 0.5), 1.5);
	vec4 b = textureLod(flames, vec2(uv.x * 0.5, 0.5 + uv.y * 0.5), 1.5);
	vec4 fire = mix(a, b, 0.5 + 0.5 * sin(age * 9.0 + tile * 2.73));
	ALBEDO = fire.rgb;
	EMISSION = fire.rgb * 1.25;
	ALPHA = smoothstep(0.08, 0.72, fire.a) * opacity * smoothstep(0.0, 0.08, UV.y) * (1.0 - smoothstep(0.94, 1.0, UV.y));
	if (abs(world_at.x) > 9.0 || world_at.z < -12.0 || world_at.z > 10.0) { ALPHA = 0.0; }
}
