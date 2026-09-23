extends Node
## Transient, collision-aware walking; persistent state stays in GameState.

const Mountains = preload("res://scripts/gameplay/mountain_maps.gd")
const CELL: float = 0.25
var player: CharacterBody3D
var path := PackedVector3Array()
var _target := Vector3.ZERO
var _last_position := Vector3.ZERO
var _stalled: float = 0.0


func _ready() -> void:
	GameState.state_changed.connect(_on_state_changed)


func _on_state_changed() -> void:
	if GameState.mode not in [GameState.Mode.EXPLORE, GameState.Mode.MAP]:
		cancel()


func is_active() -> bool:
	return not path.is_empty()


func cancel() -> void:
	var was_active := is_active()
	path.clear()
	_stalled = 0.0
	if was_active and is_instance_valid(player):
		player.velocity.x = 0.0
		player.velocity.z = 0.0


func start(target: Vector3, bounds: Rect2) -> bool:
	cancel()
	if GameState.is_input_locked():
		return false
	_target = target
	if Mountains.NAMES.has(GameState.current_map):
		path = Mountains.walking_path(GameState.current_map, player.global_position, target)
		_last_position = player.global_position
		return is_active()
	var grid := AStarGrid2D.new()
	grid.region = Rect2i(Vector2i.ZERO, Vector2i((bounds.size / CELL).ceil()) + Vector2i.ONE)
	grid.cell_size = Vector2.ONE * CELL
	grid.offset = bounds.position
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	grid.update()
	var terrain: Node = (player.get_parent().get("_map_root") as Node).get_node_or_null("OutdoorLandscape")
	var space := player.get_world_3d().direct_space_state
	var shape := CylinderShape3D.new()
	# Inflate by half a grid cell so cardinal edges cannot cut thin walls.
	shape.radius = 0.415
	shape.height = 0.9
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.collision_mask = player.collision_mask
	query.exclude = [player.get_rid()]
	var ray := PhysicsRayQueryParameters3D.new()
	ray.collision_mask = player.collision_mask
	ray.exclude = query.exclude
	var start_id := Vector2i(-1, -1)
	var start_distance: float = 1.0
	var candidates: Array[Vector2i] = []
	for y: int in range(grid.region.size.y):
		for x: int in range(grid.region.size.x):
			var id := Vector2i(x, y)
			var at := grid.get_point_position(id)
			var floor_y: float = float(terrain.soil_height(at)) if terrain != null else 0.0
			query.transform = Transform3D(Basis.IDENTITY, Vector3(at.x, floor_y + (0.8 if terrain != null else 0.65), at.y))
			var blocked := not space.intersect_shape(query, 1).is_empty()
			if not blocked:
				ray.from = Vector3(at.x, floor_y + 0.18, at.y)
				ray.to = Vector3(at.x, floor_y - 0.35, at.y)
				var hit: Dictionary = space.intersect_ray(ray)
				blocked = hit.is_empty() or Vector3(hit.normal).y < 0.75
			grid.set_point_solid(id, blocked)
			if blocked:
				continue
			var distance := at.distance_to(Vector2(player.global_position.x, player.global_position.z))
			if distance < start_distance and _clear_segment(player.global_position, Vector3(at.x, 0, at.y)):
				start_distance = distance
				start_id = id
			if at.distance_to(Vector2(target.x, target.z)) <= 1.4:
				candidates.append(id)
	if start_id.x < 0 or candidates.is_empty():
		return false
	candidates.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return grid.get_point_position(a).distance_squared_to(Vector2(target.x, target.z)) < grid.get_point_position(b).distance_squared_to(Vector2(target.x, target.z))
	)
	for candidate: Vector2i in candidates:
		var route := grid.get_point_path(start_id, candidate)
		if route.is_empty():
			continue
		for point: Vector2 in route:
			path.append(Vector3(point.x, 0, point.y))
		break
	_last_position = player.global_position
	return is_active()


func _clear_segment(from: Vector3, to: Vector3) -> bool:
	var shape := CylinderShape3D.new()
	shape.radius = 0.30
	shape.height = 0.9
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.collision_mask = player.collision_mask
	query.exclude = [player.get_rid()]
	var terrain: Node = (player.get_parent().get("_map_root") as Node).get_node_or_null("OutdoorLandscape")
	var from_y: float = float(terrain.soil_height(Vector2(from.x, from.z))) if terrain != null else 0.0
	var to_y: float = float(terrain.soil_height(Vector2(to.x, to.z))) if terrain != null else 0.0
	query.transform = Transform3D(Basis.IDENTITY, Vector3(from.x, from_y + (0.8 if terrain != null else 0.65), from.z))
	query.motion = Vector3(to.x - from.x, to_y - from_y, to.z - from.z)
	var fractions := player.get_world_3d().direct_space_state.cast_motion(query)
	return fractions[0] >= 1.0


func direction(delta: float) -> Vector3:
	var current := Vector3(player.global_position.x, 0, player.global_position.z)
	while not path.is_empty() and current.distance_to(path[0]) < 0.14:
		path.remove_at(0)
	if path.is_empty():
		cancel()
		player.velocity.x = 0.0
		player.velocity.z = 0.0
		player.call("face_world_position", _target)
		GameState.notification_requested.emit("已抵達目的地")
		return Vector3.ZERO
	# Skip only a single corner at a time; never smooth across unsupported ground.
	if not Mountains.NAMES.has(GameState.current_map) and path.size() > 1 and current.distance_to(path[1]) < 0.8 and _clear_segment(current, path[1]):
		path.remove_at(0)
	if current.distance_to(Vector3(_last_position.x, 0, _last_position.z)) < 0.003:
		_stalled += delta
	else:
		_stalled = 0.0
	_last_position = player.global_position
	if _stalled > 0.8:
		cancel()
		GameState.notification_requested.emit("前方受阻，自動移動已停止")
		return Vector3.ZERO
	var offset := path[0] - current
	# Slow down near corners, avoiding overshoot and oscillation.
	return offset.normalized() * minf(1.0, offset.length() / 0.4)
