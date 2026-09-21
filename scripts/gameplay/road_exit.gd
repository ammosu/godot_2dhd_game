extends Interactable3D
## A full-width walking threshold. Retry after dialogue closes, never require input.
var traveler: CharacterBody3D
var game_state: Node
var _scheduled: bool = false

func _physics_process(_delta: float) -> void:
	if _scheduled or game_state.is_input_locked() or not is_instance_valid(traveler):
		return
	if overlaps_body(traveler):
		_scheduled = true
		_cross.call_deferred()

func _cross() -> void:
	_scheduled = false
	if not is_inside_tree() or game_state.is_input_locked() or not overlaps_body(traveler):
		return
	activated.emit(interaction_id)
