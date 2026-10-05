extends RefCounted
## Impact tuning shared by action combat adapters: hit stop, camera shake,
## white flash, sprite tremor and impact cues. Presentation only; never
## touches GameState.

const FlashShader = preload("res://shaders/hit_flash.gdshader")
## Brief partial-white overlay; retain the actor palette through contact.
const FLASH_TIME: float = 0.035
const FLASH_BLEND: float = 0.65
const TREMOR_AMPLITUDE: float = 0.045

## Freeze length for one landed hit. Heavier hits and finishers hold longer.
static func stop_time(damage: int, max_hp: int, skill: bool, lethal: bool) -> float:
	var weight: float = clampf(float(damage) / maxf(1.0, float(max_hp)), 0.0, 1.0)
	var time: float = 0.045 + weight * 0.05 + (0.025 if skill else 0.0)
	return minf(0.12, maxf(time, 0.10 if lethal else 0.0))

static func shake_strength(damage: int, max_hp: int, skill: bool, lethal: bool) -> float:
	var weight: float = clampf(float(damage) / maxf(1.0, float(max_hp)), 0.0, 1.0)
	var strength: float = 0.035 + weight * 0.04 + (0.02 if skill else 0.0)
	return minf(0.11, maxf(strength, 0.085 if lethal else 0.0))

static func impact_cue(player_class: String) -> StringName:
	return &"frost_impact" if player_class == "mage" else &"impact"

## Slight pitch spread so repeated hits do not sound machine-gunned.
static func impact_pitch() -> float:
	return randf_range(0.92, 1.08)

## Time left to simulate after a freeze. Large steps still advance once the
## freeze is spent, so hit stop never swallows real time.
static func after_stop(stop: float, delta: float) -> float:
	return maxf(0.0, delta - maxf(stop, 0.0))

## Horizontal screen-space shiver while a target is held in hit stop.
static func tremor(stop_left: float, camera: Camera3D) -> Vector3:
	if stop_left <= 0.0 or camera == null:
		return Vector3.ZERO
	var right: Vector3 = camera.global_basis.x * Vector3(1, 0, 1)
	if right.is_zero_approx():
		return Vector3.ZERO
	var side: float = 1.0 if int(stop_left * 60.0) % 2 == 0 else -1.0
	return right.normalized() * side * TREMOR_AMPLITUDE

## Partial-white overlay; only attached during the brief contact flash.
static func apply_flash(sprite: Sprite3D, amount: float) -> void:
	if amount <= 0.0 or sprite.texture == null:
		if sprite.material_overlay != null:
			sprite.material_overlay = null
		return
	if not sprite.has_meta("hit_flash_material"):
		var created := ShaderMaterial.new()
		created.shader = FlashShader
		sprite.set_meta("hit_flash_material", created)
	var material := sprite.get_meta("hit_flash_material") as ShaderMaterial
	var atlas := sprite.texture as AtlasTexture
	material.set_shader_parameter("character_texture", atlas.atlas if atlas != null else sprite.texture)
	material.set_shader_parameter("alpha_threshold", sprite.alpha_scissor_threshold)
	material.set_shader_parameter("flash", clampf(amount, 0.0, 1.0) * FLASH_BLEND)
	sprite.material_overlay = material

## A separate depth-free edge pass, so normal hit flashes keep depth testing.
const OUTLINE_SHADER: String = """
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, depth_test_disabled, cull_disabled, fog_disabled, shadows_disabled;
uniform sampler2D character_texture : source_color, filter_nearest;
void vertex() {
	vec3 up = vec3(0.0, 1.0, 0.0);
	vec3 right = normalize(cross(up, INV_VIEW_MATRIX[2].xyz));
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(vec4(right * length(MODEL_MATRIX[0].xyz), 0.0), vec4(up * length(MODEL_MATRIX[1].xyz), 0.0), vec4(cross(right, up) * length(MODEL_MATRIX[2].xyz), 0.0), MODEL_MATRIX[3]);
}
void fragment() {
	vec2 step_uv = 2.0 / vec2(textureSize(character_texture, 0));
	float center = texture(character_texture, UV).a;
	float edge = 0.0;
	for (int x = -1; x <= 1; x++) {
		for (int y = -1; y <= 1; y++) {
			edge = max(edge, texture(character_texture, UV + vec2(float(x), float(y)) * step_uv).a);
		}
	}
	ALBEDO = vec3(0.65, 0.95, 1.0);
	ALPHA = max(0.0, edge - center) * 0.75;
}
"""
