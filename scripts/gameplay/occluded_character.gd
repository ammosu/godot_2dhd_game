extends Sprite3D
## One shared, depth-masked silhouette per player, regardless of blocker count.

var _source: AnimatedSprite3D
var _material: ShaderMaterial
var _controllers: Array[WeakRef] = []


func configure(source: AnimatedSprite3D) -> void:
	_source = source
	process_priority = 30
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_material = ShaderMaterial.new()
	_material.shader = preload("res://shaders/occluded_character.gdshader")
	material_override = _material
	visible = false


func register(controller: Node) -> void:
	_controllers.append(weakref(controller))


func _process(_delta: float) -> void:
	if not is_instance_valid(_source):
		hide()
		return
	var blocked: bool = false
	for index: int in range(_controllers.size() - 1, -1, -1):
		var controller: Node = _controllers[index].get_ref()
		if controller == null:
			_controllers.remove_at(index)
		elif controller.active:
			blocked = true
	visible = blocked and _source.is_visible_in_tree()
	if not visible:
		return
	transform = _source.transform
	billboard = _source.billboard
	layers = _source.layers
	pixel_size = _source.pixel_size
	offset = _source.offset
	centered = _source.centered
	flip_h = _source.flip_h
	flip_v = _source.flip_v
	texture = _source.sprite_frames.get_frame_texture(_source.animation, _source.frame)
	# Sprite3D generates atlas-aware UVs; sample the underlying atlas with them.
	var atlas := texture as AtlasTexture
	_material.set_shader_parameter("character_texture", atlas.atlas if atlas != null else texture)
