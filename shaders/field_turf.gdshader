shader_type spatial;
render_mode cull_disabled, specular_disabled;
uniform sampler2D grass_texture : source_color, filter_nearest, repeat_enable;
uniform sampler2D soil_texture : source_color, filter_nearest, repeat_enable;
varying vec3 world_point;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f*f*(3.0-2.0*f);
	return mix(mix(hash(i), hash(i+vec2(1,0)), f.x), mix(hash(i+vec2(0,1)), hash(i+vec2(1)), f.x), f.y);
}
void vertex() { world_point = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 p = world_point.xz;
	float edge = min(min(p.x-6.0, 12.0-p.x), min(p.y-8.0, 13.0-p.y));
	float variation = noise(p * 4.2);
	float turf = smoothstep(0.02, 0.44, edge + (variation-0.5)*0.30);
	float trail_center = 10.5 + sin((p.x-6.0)*0.65)*0.27;
	float trail = 1.0-smoothstep(0.28, 0.72, abs(p.y-trail_center)+(variation-0.5)*0.20);
	trail *= 1.0-smoothstep(10.3, 11.4, p.x);
	vec3 grass = texture(grass_texture, p * 0.46).rgb * vec3(0.88, 0.91, 0.73);
	vec3 soil = texture(soil_texture, p * 0.53).rgb * vec3(0.80, 0.72, 0.59);
	ALBEDO = mix(soil, grass, turf*(1.0-trail*0.90));
	ROUGHNESS = 1.0;
}
