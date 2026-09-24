extends Node
## Map-local recovery for unsupported movement and old out-of-map saves.
## Physics support follows slopes and irregular maps instead of a UI rectangle.
var player: CharacterBody3D
var _safe_position := Vector3.ZERO
var _sync_frames: int = 0
var _configured: bool = false


func _ready() -> void:
	# Check after ordinary player movement, including locked-input movement.
	process_physics_priority = 10


func reset(spawn: Vector3) -> void:
	_safe_position = spawn
	_configured = true
	# Newly built collision bodies must reach the physics server first.
	_sync_frames = 2


func _physics_process(_delta: float) -> void:
	if not _configured or not is_instance_valid(player):
		return
	if _sync_frames > 0:
		_sync_frames -= 1
		return
	var at := player.global_position
	if at.is_finite():
		# Sample within the capsule footprint: a single center ray can miss a
		# triangle seam on a curved mountain trail even while the body is grounded.
		for offset: Vector3 in [Vector3.ZERO, Vector3(0.18, 0, 0), Vector3(-0.18, 0, 0), Vector3(0, 0, 0.18), Vector3(0, 0, -0.18)]:
			var ray := PhysicsRayQueryParameters3D.create(at + offset + Vector3.UP * 0.4, at + offset + Vector3.DOWN * 0.8, player.collision_mask, [player.get_rid()])
			var hit: Dictionary = player.get_world_3d().direct_space_state.intersect_ray(ray)
			if not hit.is_empty() and Vector3(hit.normal).y >= cos(player.floor_max_angle):
				_safe_position = Vector3(at.x, Vector3(hit.position).y + 0.04, at.z)
				return
	player.global_position = _safe_position
	player.velocity = Vector3.ZERO
	player.get("auto_walk").cancel()
