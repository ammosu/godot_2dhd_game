extends RefCounted
## Shared anticipation → hand contact → door travel → release choreography.
const OPEN_ANGLE: float = -PI * 0.48


static func animate(player: Wanderer, hinge: Node3D, closing: bool = false) -> void:
	await player.reach_for_door()
	var movement := hinge.create_tween()
	movement.tween_property(hinge, "rotation:y", 0.0 if closing else OPEN_ANGLE, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await movement.finished
	await player.withdraw_door_hand()
