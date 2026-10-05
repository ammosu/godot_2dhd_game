extends Node3D
## Camera-facing health display; all values come from the combat session.
var screen_offset: Vector2 = Vector2.ZERO
var _enemy: bool = false
var _fill: Sprite3D
var _fill_height: int = 8
var _pixel_size: float = 0.012

func configure(enemy: bool, species: String = "") -> void:
	_enemy = enemy
	if enemy:
		add_to_group("enemy_health_bars")
	process_priority = 30
	_pixel_size = (0.0115 if species == "guardian" else 0.009) if enemy else 0.012
	_fill_height = 8
	_make_strip(106 if enemy else 104, _fill_height + 4, Color("171b26"))
	var color := Color("d9b86c") if species == "guardian" else Color("ed887a") if enemy else Color("71d5a1")
	_fill = _make_strip(100, _fill_height, color)
	_fill.render_priority = 11
	_fill.region_enabled = true

func _process(_delta: float) -> void:
	# Story films hide gameplay UI; the next set_health call restores it.
	if GameState.mode == GameState.Mode.CUTSCENE and visible:
		visible = false
	if _enemy and not has_meta("field_layout") and get_tree().get_first_node_in_group("enemy_health_bars") == self:
		space_bars(get_tree().get_nodes_in_group("enemy_health_bars"), get_viewport().get_camera_3d())

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
	# Alpha blending honors render_priority; discard uses the opaque depth pass.
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
	sprite.no_depth_test = true
	sprite.render_priority = 10
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.shaded = false
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sprite)
	return sprite

## Recompute from the unchanged actor anchors, so separation never accumulates.
static func space_bars(bars: Array[Node], camera: Camera3D) -> Array[Rect2]:
	var occupied: Array[Rect2] = []
	if camera == null:
		return occupied
	for bar: Node3D in bars:
		bar.screen_offset = Vector2.ZERO
		for strip: Sprite3D in bar.get_children():
			strip.position = Vector3.ZERO
		if not bar.is_visible_in_tree() or camera.is_position_behind(bar.global_position):
			continue
		var anchor: Vector3 = bar.global_position
		var center: Vector2 = camera.unproject_position(anchor)
		var right: Vector2 = camera.unproject_position(anchor + camera.global_basis.x * bar._pixel_size * 106.0)
		var up: Vector2 = camera.unproject_position(anchor + camera.global_basis.y * bar._pixel_size * 12.0)
		var size := Vector2(center.distance_to(right) + 4.0, center.distance_to(up) + 4.0)
		var bounds := Rect2(center - size * 0.5, size)
		var shifted_bar: bool = false
		for attempt: int in range(occupied.size() + 1):
			var overlaps: bool = false
			for previous: Rect2 in occupied:
				if bounds.intersects(previous):
					bounds.position.y = previous.position.y - size.y - 1.0
					shifted_bar = true
					overlaps = true
					break
			if not overlaps:
				break
		occupied.append(bounds)
		if not shifted_bar:
			continue
		bar.screen_offset = bounds.get_center() - center
		if bar.screen_offset.is_zero_approx():
			continue
		var depth: float = -camera.to_local(anchor).z
		var shifted: Vector3 = camera.project_position(bounds.get_center(), depth)
		for strip: Sprite3D in bar.get_children():
			strip.global_position = shifted

	return occupied

static func reserve(bounds: Rect2, occupied: Array[Rect2]) -> Rect2:
	for attempt: int in range(occupied.size() + 1):
		var overlap: bool = false
		for previous: Rect2 in occupied:
			if bounds.intersects(previous):
				bounds.position.y = previous.position.y - bounds.size.y - 1.0
				overlap = true
				break
		if not overlap:
			break
	occupied.append(bounds)
	return bounds

static func space_label(label: Label3D, camera: Camera3D, occupied: Array[Rect2]) -> void:
	if not label.is_visible_in_tree() or label.text.is_empty() or camera.is_position_behind(label.global_position):
		return
	var anchor: Vector3 = label.global_position
	var center: Vector2 = camera.unproject_position(anchor)
	var bounds: AABB = label.get_aabb()
	var scale: Vector3 = label.global_basis.get_scale()
	var width: float = center.distance_to(camera.unproject_position(anchor + camera.global_basis.x * bounds.size.x * scale.x))
	var height: float = center.distance_to(camera.unproject_position(anchor + camera.global_basis.y * bounds.size.y * scale.y))
	var size := Vector2(maxf(width + 10.0, 28.0), maxf(height + 8.0, 28.0))
	var resolved: Rect2 = reserve(Rect2(center - size * 0.5, size), occupied)
	label.global_position = camera.project_position(resolved.get_center(), -camera.to_local(anchor).z)
	label.set_meta("layout_bounds", resolved)

## Target name is anchored to the resolved bar, never independently pushed away.
static func attach_name(label: Label3D, bar: Node3D, camera: Camera3D, occupied: Array[Rect2]) -> void:
	if not label.is_visible_in_tree() or label.text.is_empty() or not bar.is_visible_in_tree():
		return
	var anchor: Vector3 = bar.get_child(0).global_position
	if camera.is_position_behind(anchor):
		return
	var center: Vector2 = camera.unproject_position(anchor)
	var height: float = center.distance_to(camera.unproject_position(anchor + camera.global_basis.y * label.get_aabb().size.y))
	# Keep the center at most 28px from its bar at every supported zoom.
	var offset: float = clampf(height * 0.5 + 8.0, 14.0, 28.0)
	label.global_position = camera.project_position(center - Vector2(0, offset), -camera.to_local(anchor).z)
	var bounds: AABB = label.get_aabb()
	var width: float = center.distance_to(camera.unproject_position(anchor + camera.global_basis.x * bounds.size.x))
	var rect := Rect2(center - Vector2(width * 0.5 + 5.0, offset + height * 0.5 + 4.0), Vector2(width + 10.0, height + 8.0))
	label.set_meta("layout_bounds", rect)
	occupied.append(rect)
