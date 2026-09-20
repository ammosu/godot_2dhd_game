shader_type spatial;
render_mode specular_disabled;
#include "res://shaders/ruin_soil_common.gdshaderinc"

varying vec3 surface_world;

void vertex() {
	surface_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	ALBEDO = sample_ruin_soil(surface_world.xz);
	ROUGHNESS = 1.0;
}
