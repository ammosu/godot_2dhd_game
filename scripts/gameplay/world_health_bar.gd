extends Node3D
## Camera-facing health display; all values come from the combat session.
var _fill: Sprite3D

func configure(enemy: bool) -> void:
	_make_strip(104, 12, Color("111a27"))
	_fill = _make_strip(100, 8, Color("ed786b") if enemy else Color("71d5a1"))
	_fill.render_priority = 1
	_fill.region_enabled = true

func set_health(current: int, maximum: int) -> void:
	visible = current > 0
	var width: float = 100.0 * clampf(float(current) / maxi(maximum, 1), 0.0, 1.0)
	_fill.region_rect = Rect2(0, 0, width, 8)
	_fill.offset.x = (width - 100.0) * 0.5

func _make_strip(width: int, height: int, color: Color) -> Sprite3D:
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color.WHITE, Color.WHITE])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = width
	texture.height = height
	var sprite := Sprite3D.new()
	sprite.texture = texture
	sprite.modulate = color
	sprite.pixel_size = 0.012
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.shaded = false
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sprite)
	return sprite
