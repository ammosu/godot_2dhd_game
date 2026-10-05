extends Node3D
## A travelling companion that walks the traveler's own footsteps.
## Presentation only: no collision, no combat; who travels is GameState's call.
const ResidentArt = preload("res://scripts/gameplay/resident_art.gd")
const Grounding = preload("res://scripts/gameplay/sprite_grounding.gd")

## Distance kept behind the traveler, measured along the walked trail.
const SLOT_SPACING: float = 1.25
const SAMPLE_DISTANCE: float = 0.12
const MAX_SAMPLES: int = 160
## Catch up quickly when left behind, settle gently when close.
const CATCH_UP_GAIN: float = 3.2
const MAX_SPEED: float = 6.5
const ACCELERATION: float = 9.0
const TURN_RATE: float = 9.0
## Beyond this gap (blocked, map edge) the companion simply reappears behind.
const TELEPORT_DISTANCE: float = 9.0

var leader: Node3D
var resident_id: String = "noah"
var slot: int = 1
## Field fights may send the companion somewhere other than the trail (INF = trail).
var combat_goal: Vector3 = Vector3.INF
## Current battle pose (-1 = walking) and the screen side it faces.
var action_pose: int = -1
var action_side: StringName = &"left"
var _trail: PackedVector3Array = PackedVector3Array()
var _speed: float = 0.0
var _heading: Vector3 = Vector3.BACK
var _sprite: ResidentArt


func _ready() -> void:
	add_to_group("party_followers")
	_sprite = ResidentArt.new()
	_sprite.name = "CharacterArt"
	_sprite.resident_id = resident_id
	_sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	add_child(_sprite)
	Grounding.add_shadow(self, 0.28, 0.025)
	var talk_area := Interactable3D.new()
	talk_area.name = "TalkArea"
	talk_area.interaction_id = "party_talk"
	talk_area.prompt_text = "與同伴交談"
	talk_area.low_priority = true
	talk_area.collision_layer = 8
	talk_area.collision_mask = 0
	talk_area.monitoring = false
	var talk_shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.6
	talk_shape.shape = sphere
	talk_shape.position.y = 0.75
	talk_area.add_child(talk_shape)
	add_child(talk_area)
	snap_behind_leader()


func set_action(pose: int, side: StringName) -> void:
	action_pose = pose
	action_side = side
	if is_instance_valid(_sprite):
		_sprite.action_pose = pose
		_sprite.action_side = side


## Restart the trail directly behind the traveler (map load, teleport).
func snap_behind_leader() -> void:
	if not is_instance_valid(leader):
		return
	var back: Vector3 = leader.global_basis.z
	back.y = 0.0
	back = back.normalized() if not back.is_zero_approx() else Vector3.BACK
	global_position = leader.global_position + back * SLOT_SPACING * slot
	_trail = PackedVector3Array([global_position, leader.global_position])
	_heading = -back
	_speed = 0.0
	if is_instance_valid(_sprite):
		_sprite.world_heading = _heading
		_sprite.walking = false


func trail_target() -> Vector3:
	var remaining: float = SLOT_SPACING * slot
	var cursor: Vector3 = leader.global_position
	for index: int in range(_trail.size() - 1, -1, -1):
		var point: Vector3 = _trail[index]
		var step: float = cursor.distance_to(point)
		if step >= remaining:
			return cursor.lerp(point, remaining / step) if step > 0.0 else point
		remaining -= step
		cursor = point
	return cursor


func _physics_process(delta: float) -> void:
	if not is_instance_valid(leader):
		return
	if _trail.is_empty() or leader.global_position.distance_to(_trail[_trail.size() - 1]) >= SAMPLE_DISTANCE:
		_trail.append(leader.global_position)
		if _trail.size() > MAX_SAMPLES:
			_trail.remove_at(0)
	var paused: bool = GameState.mode not in [GameState.Mode.EXPLORE, GameState.Mode.CUTSCENE]
	var fighting: bool = combat_goal.is_finite()
	var target: Vector3 = combat_goal if fighting else trail_target()
	var offset: Vector3 = target - global_position
	if global_position.distance_to(leader.global_position) > TELEPORT_DISTANCE * (1.5 if fighting else 1.0):
		set_action(-1, action_side)
		combat_goal = Vector3.INF
		snap_behind_leader()
		return
	var planar := Vector3(offset.x, 0.0, offset.z)
	var desired_speed: float = 0.0 if paused or (action_pose >= 0 and not fighting) else minf(MAX_SPEED, planar.length() * CATCH_UP_GAIN)
	if planar.length() < 0.05:
		desired_speed = 0.0
	_speed = move_toward(_speed, desired_speed, ACCELERATION * delta)
	var before: Vector3 = global_position
	if _speed > 0.0 and not planar.is_zero_approx():
		var direction: Vector3 = planar.normalized()
		var angle: float = lerp_angle(atan2(_heading.x, _heading.z), atan2(direction.x, direction.z), 1.0 - exp(-TURN_RATE * delta))
		_heading = Vector3(sin(angle), 0.0, cos(angle))
		global_position += direction * minf(_speed * delta, planar.length())
	# The trail already lies on walkable ground; follow its height (the leader's
	# while fighting off the trail, since enemies stand on the same ground).
	var ground_y: float = leader.global_position.y if fighting else target.y
	global_position.y = lerpf(global_position.y, ground_y, 1.0 - exp(-12.0 * delta))
	var travelled: float = Vector2(global_position.x - before.x, global_position.z - before.z).length()
	_sprite.world_heading = _heading
	_sprite.walking = travelled > 0.2 * delta
	_sprite.ground_speed = travelled / delta if delta > 0.0 else 0.0


## Keep the speaking actor legible if a companion still overlaps the safe shot.
func _process(delta: float) -> void:
	if not is_instance_valid(_sprite):
		return
	var desired: float = 0.0
	var camera := get_viewport().get_camera_3d()
	var rig := camera.get_parent() as Hd2dCameraRig if camera != null else null
	if rig != null and rig._dialogue_active and GameState.mode == GameState.Mode.DIALOGUE:
		var partner: Node3D = rig._dialogue_partner
		if is_instance_valid(partner) and partner != self and not is_ancestor_of(partner):
			var subject: Vector3 = rig._subject_feet(partner) + Vector3.UP * 0.8
			var center: Vector3 = global_position + Vector3.UP * 0.8
			var screen: Vector2 = camera.unproject_position(center)
			var other: Vector2 = camera.unproject_position(subject)
			var width: float = screen.distance_to(camera.unproject_position(center + camera.global_basis.x * 0.85))
			var height: float = screen.distance_to(camera.unproject_position(center + camera.global_basis.y * 1.6))
			if camera.to_local(center).z > camera.to_local(subject).z and absf(screen.x - other.x) < width and absf(screen.y - other.y) < height:
				desired = 0.88
	_sprite.transparency = move_toward(_sprite.transparency, desired, delta / 0.18)
