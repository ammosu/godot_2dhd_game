extends RefCounted
## Presentation-only cadence. Surface rectangles derive from the visible map
## geometry, including non-colliding road overlays. No save or quest state.

const STRIDE: float = 1.05
const GROUP: StringName = &"footstep_surfaces"
var _distance: float = 0.0
var _variant: int = 0


func advance(distance: float, grounded: bool, moving: bool, locked: bool) -> bool:
	# Suppress walls, airborne motion, map teleports and catch-up sound bursts.
	if locked or not grounded or not moving or distance < 0.002 or distance > 2.0:
		_distance = 0.0
		return false
	_distance += distance
	if _distance < STRIDE:
		return false
	_distance = fmod(_distance, STRIDE)
	return true


func next_cue(surface: StringName) -> StringName:
	_variant = (_variant % 2) + 1
	return StringName("step_%s_%d" % [surface, _variant])


static func register_surface(node: Node3D, size: Vector3, surface: StringName, priority: int = 0) -> void:
	node.set_meta("step_size", size)
	node.set_meta("step_surface", surface)
	node.set_meta("step_priority", priority)
	node.add_to_group(GROUP)


static func surface_at(tree: SceneTree, position: Vector3) -> StringName:
	for candidate: Node in tree.get_nodes_in_group("polygon_footsteps"):
		var node := candidate as Node3D
		if node != null and absf(position.y - node.position.y) < 0.4 and Geometry2D.is_point_in_polygon(Vector2(position.x, position.z), node.get_meta("step_polygon")):
			return node.get_meta("step_surface", &"stone")
	var surface: StringName = &"dirt"
	var priority: int = -1
	for candidate: Node in tree.get_nodes_in_group(GROUP):
		var node := candidate as Node3D
		if node == null or node.is_queued_for_deletion():
			continue
		var local: Vector3 = node.to_local(position)
		var size: Vector3 = node.get_meta("step_size")
		if absf(local.x) > size.x * 0.5 or absf(local.z) > size.z * 0.5 or absf(local.y - size.y * 0.5) > 0.4:
			continue
		var candidate_priority: int = node.get_meta("step_priority", 0)
		if candidate_priority > priority:
			priority = candidate_priority
			surface = node.get_meta("step_surface")
	return surface
