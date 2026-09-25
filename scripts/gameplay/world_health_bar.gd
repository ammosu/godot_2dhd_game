extends Node3D
## Camera-facing health display; all values come from the combat session.
var _fill: Sprite3D
var _fill_height: int = 8
var _pixel_size: float = 0.012

func configure(enemy: bool, species: String = "") -> void:
	_pixel_size = (0.0115 if species == "guardian" else 0.009) if enemy else 0.012
	_fill_height = 8
	_make_strip(106 if enemy else 104, _fill_height + 4, Color("171b26"))
	var color := Color("d9b86c") if species == "guardian" else Color("ed887a") if enemy else Color("71d5a1")
	_fill = _make_strip(100, _fill_height, color)
	_fill.render_priority = 1
	_fill.region_enabled = true

func _process(_delta: float) -> void:
	# Story films hide gameplay UI; the next set_health call restores it.
	if GameState.mode == GameState.Mode.CUTSCENE and visible:
		visible = false

func set_health(current: int, maximum: int) -> void:
	visible = current > 0
	var width: float = 100.0 * clampf(float(current) / maxi(maximum, 1), 0.0, 1.0)
	_fill.region_rect = Rect2(0, 0, width, _fill_height)
	_fill.offset.x = (width - 100.0) * 0.5

func _make_strip(width: int, height: int, color: Color) -> Sprite3D:
	# Small code-native rounded UI strip, not a filtered/scaled art texture.
	var pixels := Image.create(width, height, false, Image.FORMAT_RGBA8)
	var radius: float = 3.0
	for y: int in range(height):
		for x: int in range(width):
			var point := Vector2(float(x) + 0.5, float(y) + 0.5)
			var nearest := Vector2(clampf(point.x, radius, float(width) - radius), clampf(point.y, radius, float(height) - radius))
			if point.distance_to(nearest) <= radius:
				pixels.set_pixel(x, y, Color.WHITE)
	var texture := ImageTexture.create_from_image(pixels)
	var sprite := Sprite3D.new()
	sprite.texture = texture
	sprite.modulate = color
	sprite.pixel_size = _pixel_size
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.shaded = false
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sprite)
	return sprite
