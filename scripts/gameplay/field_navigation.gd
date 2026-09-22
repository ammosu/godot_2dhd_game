extends RefCounted
## Height-sampled navigation: no links across ledges or through scenery.
const STEP: float = 0.5
const ORIGIN := Vector2(-8, 6.5)
const SIZE := Vector2i(43, 15)
var graph := AStar3D.new()
var cells: Dictionary[Vector2i, int] = {}
var space: PhysicsDirectSpaceState3D
var ignored: Array[RID] = []

func build(world: World3D, player: CharacterBody3D) -> void:
	space = world.direct_space_state
	ignored = [player.get_rid()]
	graph.clear()
	cells.clear()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.29
	capsule.height = 0.9
	for x: int in range(SIZE.x):
		for z: int in range(SIZE.y):
			var point := Vector3(ORIGIN.x + x * STEP, 4, ORIGIN.y + z * STEP)
			var ray := PhysicsRayQueryParameters3D.create(point, point + Vector3.DOWN * 5, 1, ignored)
			var hit: Dictionary = space.intersect_ray(ray)
			if hit.is_empty() or Vector3(hit.normal).y < 0.8:
				continue
			point = hit.position
			var query := PhysicsShapeQueryParameters3D.new()
			query.shape = capsule
			query.transform.origin = point + Vector3.UP * 0.68
			query.collision_mask = 1
			query.exclude = ignored
			if not space.intersect_shape(query, 1).is_empty():
				continue
			var id: int = graph.get_available_point_id()
			graph.add_point(id, point)
			cells[Vector2i(x, z)] = id
	for cell: Vector2i in cells:
		for offset: Vector2i in [Vector2i.RIGHT, Vector2i.DOWN]:
			var neighbor := cell + offset
			if not cells.has(neighbor):
				continue
			var a: Vector3 = graph.get_point_position(cells[cell])
			var b: Vector3 = graph.get_point_position(cells[neighbor])
			if absf(a.y - b.y) > 0.25:
				continue
			var ray := PhysicsRayQueryParameters3D.create(a + Vector3.UP * 0.4, b + Vector3.UP * 0.4, 1, ignored)
			if space.intersect_ray(ray).is_empty():
				graph.connect_points(cells[cell], cells[neighbor])

func path(from: Vector3, to: Vector3) -> PackedVector3Array:
	if graph.get_point_count() == 0:
		return PackedVector3Array()
	return graph.get_point_path(graph.get_closest_point(from), graph.get_closest_point(to))

static func contains(point: Vector3) -> bool:
	return Rect2(ORIGIN, Vector2(SIZE - Vector2i.ONE) * STEP).has_point(Vector2(point.x, point.z))
