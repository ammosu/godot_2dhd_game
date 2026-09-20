class_name MiniMap
extends Control

const HouseCatalog = preload("res://scripts/gameplay/house_catalog.gd")
const INTERIOR_BOUNDS := Rect2(-4.3, -3.8, 8.6, 7.6)

const PANEL_COLOR := Color(0.035, 0.03, 0.065, 0.94)
const PANEL_BORDER_COLOR := Color("d6a65e")
const MAP_BACKGROUND_COLOR := Color(0.075, 0.075, 0.12, 0.96)
const MAP_GROUND_COLOR := Color("35434b")
const MAP_PATH_COLOR := Color("8c765f")
const MAP_WATER_COLOR := Color("31556d")
const MAP_RUIN_COLOR := Color("514a63")
const PLAYER_COLOR := Color("8affec")
const EXIT_COLOR := Color("ffe29a")
const MAIN_TARGET_COLOR := Color("ffd45c")
const OPTIONAL_TARGET_COLOR := Color("64e6ff")

const VILLAGE_BOUNDS := Rect2(-23.0, -20.0, 46.0, 40.0)
const RUINS_BOUNDS := Rect2(-17.0, -16.0, 34.0, 32.0)
const VILLAGE_EXIT := Vector3(0.0, 0.0, -13.1)
const RUINS_EXIT := Vector3(0.0, 0.0, 12.5)

var _map_id: String = "village"
var _player_world_position: Vector3 = Vector3.ZERO
var _player_heading: Vector2 = Vector2.UP
var _main_target_world_position: Vector3 = Vector3.ZERO
var _optional_target_world_position: Vector3 = Vector3.ZERO
var _main_target_visible: bool = false
var _optional_target_visible: bool = false
var _panel_style: StyleBoxFlat
var _camera_yaw: float = 0.0


func _ready() -> void:
	process_priority = 30 # Follow the camera rig's actual interpolated pose.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(226.0, 226.0)
	_panel_style = StyleBoxFlat.new()
	_panel_style.bg_color = PANEL_COLOR
	_panel_style.border_color = PANEL_BORDER_COLOR
	_panel_style.set_border_width_all(2)
	_panel_style.set_corner_radius_all(8)
	queue_redraw()


func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera != null:
		var right := camera.global_basis.x
		set_camera_yaw(atan2(-right.z, right.x))


func set_camera_yaw(yaw: float) -> void:
	if not is_finite(yaw):
		return
	var wrapped := wrapf(yaw, -PI, PI)
	if not is_equal_approx(_camera_yaw, wrapped):
		_camera_yaw = wrapped
		queue_redraw()


func set_map(map_id: String) -> void:
	if map_id == _map_id:
		return
	_map_id = map_id
	queue_redraw()


func set_player_state(world_position: Vector3, movement: Vector3) -> void:
	var state_changed := not _player_world_position.is_equal_approx(world_position)
	_player_world_position = world_position
	var planar_movement := Vector2(movement.x, movement.z)
	if planar_movement.length_squared() > 0.01:
		var next_heading := planar_movement.normalized()
		state_changed = state_changed or not _player_heading.is_equal_approx(next_heading)
		_player_heading = next_heading
	if state_changed:
		queue_redraw()


func set_main_target(world_position: Vector3, target_visible: bool) -> void:
	if _main_target_world_position.is_equal_approx(world_position) and _main_target_visible == target_visible:
		return
	_main_target_world_position = world_position
	_main_target_visible = target_visible
	queue_redraw()


func set_optional_target(world_position: Vector3, target_visible: bool) -> void:
	if _optional_target_world_position.is_equal_approx(world_position) and _optional_target_visible == target_visible:
		return
	_optional_target_world_position = world_position
	_optional_target_visible = target_visible
	queue_redraw()


func get_map_id() -> String:
	return _map_id


func has_main_target() -> bool:
	return _main_target_visible


func has_optional_target() -> bool:
	return _optional_target_visible


func _draw() -> void:
	_draw_panel()
	_draw_map_geometry()
	_draw_exit_marker()
	if _optional_target_visible:
		_draw_optional_target(_world_to_map(_optional_target_world_position))
	if _main_target_visible:
		_draw_main_target(_world_to_map(_main_target_world_position))
	_draw_player_marker(_world_to_map(_player_world_position))


func _draw_panel() -> void:
	draw_style_box(_panel_style, Rect2(Vector2.ZERO, size))

	var font := ThemeDB.fallback_font
	var title := "暮光村" if _map_id == "village" else "北境遺跡"
	if HouseCatalog.is_interior(_map_id):
		title = str(HouseCatalog.find_home(_map_id).name)
	draw_string(font, Vector2(12.0, 22.0), title, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 16, Color("fff2d2"))
	draw_string(font, Vector2(size.x - 48.0, 22.0), "N", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14, Color("f3c77f"))
	var north := Vector2.UP.rotated(_camera_yaw)
	var origin := Vector2(size.x - 19.0, 17.0)
	var tip := origin + north * 7.0
	draw_line(origin - north * 5.0, tip, EXIT_COLOR, 1.5, true)
	draw_line(tip, tip - north.rotated(0.6) * 4.0, EXIT_COLOR, 1.5, true)
	draw_line(tip, tip - north.rotated(-0.6) * 4.0, EXIT_COLOR, 1.5, true)


func _draw_map_geometry() -> void:
	var map_rect := _get_map_rect()
	draw_rect(map_rect, MAP_BACKGROUND_COLOR, true)
	if _map_id == "village":
		_draw_world_rect(VILLAGE_BOUNDS, MAP_GROUND_COLOR.darkened(0.12))
		_draw_world_rect(Rect2(-3.9, -4.0, 7.8, 8.0), Color("686176"))
		_draw_world_rect(Rect2(-1.175, -12.5, 2.35, 25.0), MAP_PATH_COLOR)
		_draw_world_rect(Rect2(-14.5, 3.475, 29.0, 2.25), MAP_PATH_COLOR)
		_draw_world_rect(Rect2(-14.5, -5.75, 29.0, 1.9), MAP_PATH_COLOR.darkened(0.08))
		for x: float in [-19.0, 19.0]:
			_draw_world_rect(Rect2(x - 0.9, -17, 1.8, 34), MAP_PATH_COLOR)
		for z: float in [-16.8, 16.8]:
			_draw_world_rect(Rect2(-19, z - 0.9, 38, 1.8), MAP_PATH_COLOR)
		_draw_world_rect(Rect2(7.0, -12.5, 9.0, 5.0), MAP_WATER_COLOR)
		for home: Dictionary in HouseCatalog.HOMES:
			var basis := Basis(Vector3.UP, float(home.yaw))
			var extent: Vector3 = basis.x.abs() * HouseCatalog.EXTERIOR_COLLISION.x + basis.z.abs() * HouseCatalog.EXTERIOR_COLLISION.z
			var size := Vector2(extent.x, extent.z)
			var center := Vector2(home.position.x, home.position.z)
			_draw_world_rect(Rect2(center - size * 0.5, size), Color("594e5e"))
	elif HouseCatalog.is_interior(_map_id):
		_draw_world_rect(Rect2(-4, -3.5, 8, 7), Color("86694f"))
		_draw_world_rect(Rect2(-3.425, -3.075, 1.65, 2.45), Color("497c82"))
		_draw_world_rect(Rect2(0.525, -0.475, 1.75, 1.15), Color("b5986d"))
		_draw_world_rect(Rect2(1.225, -3.345, 2.25, 1.05), Color("554953"))
		_draw_world_rect(Rect2(-3.76, 0.725, 0.72, 1.75), Color("624a38"))
	else:
		_draw_world_rect(RUINS_BOUNDS, Color("292b3e"))
		_draw_world_rect(Rect2(-7.0, -10.5, 14.0, 17.0), MAP_RUIN_COLOR)
		_draw_world_rect(Rect2(-11.75, 1.25, 5.5, 5.5), MAP_RUIN_COLOR.darkened(0.08))
		_draw_world_rect(Rect2(6.25, -4.25, 5.5, 5.5), MAP_RUIN_COLOR.darkened(0.08))
		_draw_world_rect(Rect2(-0.75, -12.0, 1.5, 25.0), Color("786c8d"))
		_draw_world_rect(Rect2(-9.5, 3.2, 19.0, 1.2), Color("6c617f"))
	draw_rect(map_rect, Color("9d91ae"), false, 1.5)


func _draw_world_rect(world_rect: Rect2, color: Color) -> void:
	var points := PackedVector2Array()
	for corner: Vector2 in [world_rect.position, Vector2(world_rect.end.x, world_rect.position.y), world_rect.end, Vector2(world_rect.position.x, world_rect.end.y)]:
		points.append(_world_to_map(Vector3(corner.x, 0, corner.y)))
	draw_colored_polygon(points, color)


func _draw_exit_marker() -> void:
	var exit_position := VILLAGE_EXIT if _map_id == "village" else RUINS_EXIT
	if HouseCatalog.is_interior(_map_id):
		exit_position = Vector3(0, 0, 2.95)
	var center := _world_to_map(exit_position)
	var points := PackedVector2Array([
		center + Vector2(0.0, -6.0), center + Vector2(6.0, 0.0),
		center + Vector2(0.0, 6.0), center + Vector2(-6.0, 0.0),
		center + Vector2(0.0, -6.0),
	])
	draw_polyline(points, EXIT_COLOR, 2.0, true)


func _draw_main_target(center: Vector2) -> void:
	draw_circle(center, 10.0, Color(MAIN_TARGET_COLOR, 0.32), false, 2.0, true)
	draw_circle(center, 7.0, MAIN_TARGET_COLOR)
	_draw_exclamation(center, Color("31230b"))


func _draw_optional_target(center: Vector2) -> void:
	draw_circle(center, 6.5, OPTIONAL_TARGET_COLOR)
	_draw_exclamation(center, Color("092d35"))


func _draw_exclamation(center: Vector2, color: Color) -> void:
	var font := ThemeDB.fallback_font
	draw_string(font, center + Vector2(-3.5, 4.5), "!", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14, color)


func _draw_player_marker(center: Vector2) -> void:
	var forward := _player_heading.normalized().rotated(_camera_yaw)
	var right := Vector2(-forward.y, forward.x)
	var points := PackedVector2Array([
		center + forward * 8.0,
		center - forward * 5.0 + right * 4.5,
		center - forward * 5.0 - right * 4.5,
	])
	draw_circle(center, 9.5, Color(0.02, 0.035, 0.06, 0.78))
	draw_colored_polygon(points, PLAYER_COLOR)


func _world_to_map(world_position: Vector3) -> Vector2:
	var bounds := VILLAGE_BOUNDS if _map_id == "village" else RUINS_BOUNDS
	if HouseCatalog.is_interior(_map_id):
		bounds = INTERIOR_BOUNDS
	var map_rect := _get_map_rect()
	# Fixed isotropic scale fits every rotation without zoom pulsing, skewing
	# buildings, or clipping corner markers. Clamp only out-of-map positions.
	var point := Vector2(world_position.x, world_position.z).clamp(bounds.position, bounds.end)
	var scale_factor := (minf(map_rect.size.x, map_rect.size.y) - 20.0) / bounds.size.length()
	return map_rect.get_center() + (point - bounds.get_center()).rotated(_camera_yaw) * scale_factor


func _get_map_rect() -> Rect2:
	return Rect2(Vector2(10.0, 30.0), Vector2(size.x - 20.0, size.y - 40.0))
