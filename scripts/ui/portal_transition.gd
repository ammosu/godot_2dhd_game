extends CanvasLayer
## Full-screen crossing effect: ripple the world into moonlight, hold while the
## map changes underneath, then open a clear disc back out. Hidden (and free of
## the screen copy) whenever no crossing is running.

const RIPPLE: Shader = preload("res://shaders/portal_ripple.gdshader")

var _rect: ColorRect
var _material: ShaderMaterial
var _tween: Tween


func _ready() -> void:
	name = "PortalTransition"
	layer = 80
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rect = ColorRect.new()
	_rect.name = "Ripple"
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_material = ShaderMaterial.new()
	_material.shader = RIPPLE
	_rect.material = _material
	add_child(_rect)
	_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_reset()


func is_running() -> bool:
	return _rect.visible


func amount() -> Vector2:
	return Vector2(float(_material.get_shader_parameter("cover")), float(_material.get_shader_parameter("open")))


## Ripple in from `screen_center` (0..1 viewport coordinates) until fully lit.
func cover(seconds: float, screen_center: Vector2 = Vector2(0.5, 0.5), tint: Color = Color("dcf2ff")) -> void:
	_kill()
	_rect.show()
	_material.set_shader_parameter("center", screen_center)
	_material.set_shader_parameter("light_color", tint)
	_material.set_shader_parameter("cover", 0.0)
	_material.set_shader_parameter("open", 0.0)
	_tween = create_tween()
	_tween.tween_method(_set_cover, 0.0, 1.0, seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await _tween.finished


## Open from the screen center back to the new map, then hide.
func reveal(seconds: float) -> void:
	_kill()
	_material.set_shader_parameter("center", Vector2(0.5, 0.5))
	_material.set_shader_parameter("cover", 1.0)
	_tween = create_tween()
	_tween.tween_method(_set_open, 0.0, 1.0, seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await _tween.finished
	_reset()


## Drop the effect at once (map reset, test cleanup).
func cancel() -> void:
	_kill()
	_reset()


func _set_cover(value: float) -> void:
	_material.set_shader_parameter("cover", value)


func _set_open(value: float) -> void:
	_material.set_shader_parameter("open", value)


func _kill() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()


func _reset() -> void:
	_material.set_shader_parameter("cover", 0.0)
	_material.set_shader_parameter("open", 0.0)
	_rect.hide()
