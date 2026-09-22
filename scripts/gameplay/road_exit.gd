extends Interactable3D
## A full-width walking threshold. Retry after dialogue closes, never require input.
var traveler: CharacterBody3D
var game_state: Node
var _scheduled: bool = false

func _physics_process(_delta: float) -> void:
	if _scheduled or game_state.is_input_locked() or not is_instance_valid(traveler):
		return
	if _traveler_at_threshold():
		_scheduled = true
		_cross.call_deferred()

func _cross() -> void:
	_scheduled = false
	if not is_inside_tree() or game_state.is_input_locked() or not _traveler_at_threshold():
		return
	activated.emit(interaction_id)

func _traveler_at_threshold() -> bool:
	if not overlaps_body(traveler):
		return false
	# On arrival the physics overlap cache may still contain the previous map's
	# position for one tick. Check the current body position before changing maps.
	for child: Node in get_children():
		var collider := child as CollisionShape3D
		if collider == null or not collider.shape is BoxShape3D:
			continue
		var half: Vector3 = (collider.shape as BoxShape3D).size * 0.5
		var at := collider.to_local(traveler.global_position + Vector3.UP * 0.45)
		return absf(at.x) <= half.x + 0.3 and absf(at.z) <= half.z + 0.3 and absf(at.y) <= half.y + 0.55
	return false
