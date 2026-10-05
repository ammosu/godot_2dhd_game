extends Sprite3D
## A painted moon fixed in one sky direction, riding with the camera like a
## skybox so it never shows parallax. Presentation only.

@export var direction: Vector3 = Vector3(0.0, 0.45, -1.0)
## Inside the camera far plane (80 m) and the cloud ring (70 m).
@export var distance: float = 58.0
@export var diameter: float = 11.0


func _ready() -> void:
	billboard = BaseMaterial3D.BILLBOARD_ENABLED
	shaded = false
	no_depth_test = false
	texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if texture != null:
		pixel_size = diameter / float(texture.get_width())
	_follow()


func _process(_delta: float) -> void:
	_follow()


func _follow() -> void:
	var camera := get_viewport().get_camera_3d()
	if camera != null:
		global_position = camera.global_position + direction.normalized() * distance
