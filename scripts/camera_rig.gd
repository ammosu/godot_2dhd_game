class_name Hd2dCameraRig
extends Node3D

@export var target_path: NodePath
@export_range(5.0, 20.0, 0.5) var starting_distance: float = 11.0
@export_range(15.0, 70.0, 1.0) var orbit_step_degrees: float = 45.0

@onready var camera: Camera3D = $Camera3D

var _target: Node3D
var _target_yaw: float = deg_to_rad(45.0)
var _distance: float
var _indoors: bool = false
var _dungeon: bool = false
var _pre_dungeon_yaw: float = 0.0
var _pre_dungeon_fov: float = 34.0
var _outdoor_distance: float
var _outdoor_yaw: float
var _dialogue_occlusion := preload("res://scripts/gameplay/dialogue_occlusion.gd").new()
var _dialogue_partner: Node3D
var _dialogue_active: bool = false
var _dialogue_blend: float = 0.0
var _dialogue_focus: Vector3
var _dialogue_yaw: float = 0.0
var _dialogue_distance: float = 6.2
var _dialogue_elevation: float = 0.4
## Snap straight to a safe dialogue framing when a talk starts off-screen.
## Callers that position the lens themselves (scripted shots, tests) turn this off.
var snap_dialogue_framing: bool = true
var _combat_target: Node3D
var _impact_left: float = 0.0
var _impact_strength: float = 0.0
var _combat_blend: float = 0.0
var _combat_distance: float = 21.0
## Requested shots layered over exploration, dialogue and combat framing.
## Each entry: {id, priority, order, params, left, unscaled}. The highest priority
## (latest on ties) wins; switching or releasing blends instead of popping.
var _shots: Array[Dictionary] = []
var _shot_order: int = 0
var _shot_weight: float = 0.0
var _shot_focus: Vector3 = Vector3.ZERO
var _shot_distance: float = 11.0
var _shot_yaw_offset: float = 0.0
var _shot_elevation: float = 0.56
var _shot_primed: bool = false
var _shot_blend_out: float = 0.4

const SHOT_DEFAULT_BLEND_IN: float = 0.3
const SHOT_DEFAULT_BLEND_OUT: float = 0.4
## Rate (1/s) at which a running shot's targets are followed, e.g. a moving subject
## or the hand-off between two shots.
const SHOT_FOLLOW_RATE: float = 9.0


## Layer a framing over whatever the rig is doing. params (all optional):
##   subject: Node3D (followed) or focus: Vector3; defaults to the current focus
##   distance: absolute lens distance, or distance_scale: multiplier of the current one
##   yaw_offset: radians added to the current heading (manual orbit is preserved)
##   elevation: height-to-distance ratio (exploration uses 0.56)
##   blend_in / blend_out: seconds
##   follow_rate: how quickly (1/s) a running shot chases a moving focus; lower is calmer
##   relative: distance_scale multiplies the distance on screen now instead of the base
## duration <= 0 holds until release_shot(id). unscaled timers ignore Engine.time_scale,
## so a slow-motion beat still ends on time. Re-requesting an id replaces it.
func request_shot(id: StringName, params: Dictionary, priority: int = 0, duration: float = 0.0, unscaled: bool = true) -> void:
	release_shot(id, true)
	if bool(params.get("relative", false)) and params.has("distance_scale"):
		# Punch-ins scale what is on screen now (including another shot), resolved
		# once so the shot does not keep shrinking its own distance.
		params = params.duplicate()
		var current: float = lerpf(_framing_distance(), _shot_distance, smoothstep(0.0, 1.0, _shot_weight))
		params.distance = current * float(params.distance_scale)
	_shot_order += 1
	_shots.append({"id": id, "priority": priority, "order": _shot_order, "params": params, "left": duration, "timed": duration > 0.0, "unscaled": unscaled})


## immediate drops it without fading (used when the same id is re-requested).
func release_shot(id: StringName, immediate: bool = false) -> void:
	for index: int in range(_shots.size() - 1, -1, -1):
		if _shots[index].id == id:
			if not immediate:
				_shot_blend_out = float((_shots[index].params as Dictionary).get("blend_out", SHOT_DEFAULT_BLEND_OUT))
			_shots.remove_at(index)


## Change a running shot's parameters in place (a framing that tracks the fight).
func update_shot(id: StringName, params: Dictionary) -> void:
	for shot: Dictionary in _shots:
		if shot.id == id:
			(shot.params as Dictionary).merge(params, true)


func has_shot(id: StringName) -> bool:
	return _shots.any(func(shot: Dictionary) -> bool: return shot.id == id)


func active_shot_id() -> StringName:
	var shot: Dictionary = _top_shot()
	return shot.id if not shot.is_empty() else &""


## 0 when no requested shot shapes the frame, 1 when one fully owns it.
func shot_weight() -> float:
	return _shot_weight


func clear_shots() -> void:
	_shots.clear()
	_shot_weight = 0.0
	_shot_primed = false


func _top_shot() -> Dictionary:
	var best: Dictionary = {}
	for shot: Dictionary in _shots:
		if best.is_empty() or int(shot.priority) > int(best.priority) or (int(shot.priority) == int(best.priority) and int(shot.order) > int(best.order)):
			best = shot
	return best


## Advance timers and blend toward the winning shot. base_* describe the frame
## the rig would show without any request.
func _advance_shots(delta: float, base_focus: Vector3, base_distance: float) -> void:
	var real_delta: float = delta / maxf(Engine.time_scale, 0.001)
	for index: int in range(_shots.size() - 1, -1, -1):
		var shot: Dictionary = _shots[index]
		if not bool(shot.timed):
			continue
		shot.left = float(shot.left) - (real_delta if bool(shot.unscaled) else delta)
		if float(shot.left) <= 0.0:
			_shot_blend_out = float((shot.params as Dictionary).get("blend_out", SHOT_DEFAULT_BLEND_OUT))
			_shots.remove_at(index)
	# A conversation's own framing always wins; requests resume afterwards.
	var top: Dictionary = {} if _dialogue_active else _top_shot()
	if top.is_empty():
		_shot_weight = move_toward(_shot_weight, 0.0, real_delta / maxf(_shot_blend_out, 0.001))
		if _shot_weight == 0.0:
			_shot_primed = false
		return
	var params: Dictionary = top.params
	var focus: Vector3 = base_focus
	var subject: Variant = params.get("subject")
	if subject is Node3D and is_instance_valid(subject):
		focus = _subject_feet(subject as Node3D)
	elif params.has("focus"):
		focus = params.focus
	var distance: float = float(params.get("distance", base_distance * float(params.get("distance_scale", 1.0))))
	var yaw_offset: float = float(params.get("yaw_offset", 0.0))
	var elevation: float = float(params.get("elevation", _base_elevation()))
	if not _shot_primed:
		# Start from where the lens already is so the blend weight alone eases the move.
		_shot_focus = focus
		_shot_distance = distance
		_shot_yaw_offset = yaw_offset
		_shot_elevation = elevation
		_shot_primed = true
	else:
		var follow: float = 1.0 - exp(-float(params.get("follow_rate", SHOT_FOLLOW_RATE)) * real_delta)
		_shot_focus = _shot_focus.lerp(focus, follow)
		_shot_distance = lerpf(_shot_distance, distance, follow)
		_shot_yaw_offset = lerpf(_shot_yaw_offset, yaw_offset, follow)
		_shot_elevation = lerpf(_shot_elevation, elevation, follow)
	_shot_weight = move_toward(_shot_weight, 1.0, real_delta / maxf(float(params.get("blend_in", SHOT_DEFAULT_BLEND_IN)), 0.001))


func _base_elevation() -> float:
	return lerpf(0.56, 0.70, smoothstep(8.0, 16.0, _target.position.z)) if _dungeon else 0.56


func begin_combat_shot(target: Node3D) -> void:
	_combat_target = target
	_combat_distance = 21.0
	_dialogue_active = false
	camera.attributes = null


func set_combat_target(target: Node3D) -> void:
	_combat_target = target


func end_combat_shot() -> void:
	_impact_left = 0.0
	_impact_strength = 0.0
	camera.h_offset = 0.0
	camera.v_offset = 0.0
	_combat_target = null
	_configure_camera_attributes()



func begin_dialogue_shot(partner: Node3D) -> void:
	if not is_instance_valid(partner) or _target == null:
		return
	var partner_at: Vector3 = _subject_feet(partner)
	var separation: Vector3 = partner_at - _target.global_position
	separation.y = 0.0
	_dialogue_focus = _target.global_position.lerp(partner_at, 0.5)
	# Frame both characters above the dialogue panel, from the nearest side.
	_dialogue_focus.y -= 0.25
	var side_yaw: float = atan2(separation.z, -separation.x)
	if absf(wrapf(side_yaw - rotation.y, -PI, PI)) > PI * 0.5:
		side_yaw += PI
	_dialogue_yaw = side_yaw if separation.length() > 0.1 else rotation.y
	_dialogue_distance = clampf(separation.length() * 1.6 + 3.5, 6.2, 10.0)
	_dialogue_partner = partner
	_choose_dialogue_angle()
	_dialogue_active = true
	# Do not show the first dialogue page over an off-screen speaker while the
	# exploration camera catches up. Safe starts can retain their smooth blend.
	if snap_dialogue_framing and not _dialogue_subjects_in_safe_area():
		_preview_dialogue_camera()
		_dialogue_occlusion.update([_target, _dialogue_partner], 0.18)


func _subject_feet(subject: Node3D) -> Vector3:
	return (subject.get_parent() as Node3D).global_position if subject is SpriteBase3D else subject.global_position


## Test nearby angles before blending, avoiding a camera that hunts every frame.
func _choose_dialogue_angle() -> void:
	var saved: Transform3D = camera.global_transform
	var saved_size: float = camera.size
	var base_yaw: float = _dialogue_yaw
	_dialogue_elevation = 0.4
	camera.set_meta("dialogue_subjects", [_target, _dialogue_partner])
	var found: bool = false
	for offset: float in [0.0, -0.18, 0.18, -0.36, 0.36]:
		_dialogue_yaw = base_yaw + offset
		_fit_dialogue_safe_area()
		if _dialogue_subjects_clear():
			found = true
			break
	if not found:
		_dialogue_yaw = base_yaw
		_dialogue_distance = maxf(12.0, _dialogue_distance * 1.4)
		_dialogue_elevation = 0.70
	_fit_dialogue_safe_area()
	camera.global_transform = saved
	camera.size = saved_size


func _preview_dialogue_camera() -> void:
	camera.global_position = _dialogue_focus + Vector3(0, _dialogue_distance * _dialogue_elevation, _dialogue_distance * 0.83).rotated(Vector3.UP, _dialogue_yaw)
	camera.look_at(_dialogue_focus + Vector3.UP * 0.78)
	if _indoors:
		camera.size = _dialogue_distance * 0.64

## Fit the actual projection, including wide separations and narrow viewports.
func _fit_dialogue_safe_area() -> void:
	for attempt: int in range(48):
		_preview_dialogue_camera()
		if _dialogue_subjects_in_safe_area():
			return
		_dialogue_distance *= 1.1


func _dialogue_subjects_in_safe_area() -> bool:
	var viewport: Vector2 = camera.get_viewport().get_visible_rect().size
	for subject: Node3D in [_target, _dialogue_partner]:
		for height: float in [0.0, 1.7]:
			var at: Vector3 = _subject_feet(subject) + Vector3.UP * height
			var point: Vector2 = camera.unproject_position(at) / viewport
			if camera.is_position_behind(at) or point.x < 0.27 or point.x > 0.73 or point.y < 0.05 or point.y > 0.68:
				return false
	return true


func _dialogue_subjects_clear() -> bool:
	if not _dialogue_subjects_in_safe_area():
		return false
	for subject: Node3D in [_target, _dialogue_partner]:
		if _dialogue_occlusion.blocks_subject(subject):
			return false
	return true


func _on_state_changed() -> void:
	if GameState.mode != GameState.Mode.DIALOGUE:
		_dialogue_active = false


func set_dungeon(enabled: bool) -> void:
	if enabled == _dungeon:
		return
	_dungeon = enabled
	if enabled:
		_pre_dungeon_yaw = _target_yaw
		_pre_dungeon_fov = camera.fov
		camera.fov = 38.0
		_target_yaw = 0.0
		_distance = 20.0
	else:
		_target_yaw = _pre_dungeon_yaw
		camera.fov = _pre_dungeon_fov
	_configure_camera_attributes()


func _exploration_focus() -> Vector3:
	if _indoors:
		return Vector3.ZERO
	return _target.global_position + (Vector3(0, 0, lerpf(-3.0, -4.5, smoothstep(8.0, 16.0, _target.position.z))).rotated(Vector3.UP, _target_yaw) if _dungeon else Vector3.ZERO)


func set_interior(enabled: bool) -> void:
	if enabled == _indoors:
		return
	if enabled:
		_outdoor_distance = _distance
		_outdoor_yaw = _target_yaw
		_distance = 13.5
		_target_yaw = deg_to_rad(35.0)
	else:
		_distance = _outdoor_distance
		_target_yaw = _outdoor_yaw
	_indoors = enabled
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL if enabled else Camera3D.PROJECTION_PERSPECTIVE
	if enabled:
		camera.attributes = null
	else:
		_configure_camera_attributes()


func snap_to_target() -> void:
	# Map loads and resets start from plain exploration framing.
	clear_shots()
	_dialogue_occlusion.restore()
	_dialogue_partner = null
	_dialogue_active = false
	_dialogue_blend = 0.0
	if _target == null:
		return
	global_position = _exploration_focus()
	rotation.y = _target_yaw
	_update_camera_local_position()
	camera.look_at(global_position + Vector3.UP * 0.78, Vector3.UP)


func _ready() -> void:
	add_child(_dialogue_occlusion)
	GameState.state_changed.connect(_on_state_changed)
	_target = get_node_or_null(target_path) as Node3D
	_distance = starting_distance
	rotation.y = _target_yaw
	_configure_camera_attributes()
	camera.current = true
	_update_camera_local_position()


func _configure_camera_attributes() -> void:
	if _dungeon or _indoors or RenderingServer.get_current_rendering_method() == "gl_compatibility":
		camera.attributes = null
		return

	var attributes := CameraAttributesPractical.new()
	attributes.dof_blur_far_enabled = true
	attributes.dof_blur_far_distance = 16.0
	attributes.dof_blur_far_transition = 8.0
	attributes.dof_blur_near_enabled = true
	attributes.dof_blur_near_distance = 3.0
	attributes.dof_blur_near_transition = 2.0
	attributes.dof_blur_amount = 0.055
	camera.attributes = attributes


func _process(delta: float) -> void:
	if _target == null:
		return

	var fighting: bool = is_instance_valid(_combat_target) and GameState.mode == GameState.Mode.BATTLE
	var combat_paused: bool = fighting and GameState.battle_session != null and bool(GameState.battle_session.paused)
	if not GameState.is_input_locked() or (fighting and not combat_paused):
		if Input.is_action_just_pressed("camera_rotate_left"):
			_target_yaw += deg_to_rad(orbit_step_degrees)
		if Input.is_action_just_pressed("camera_rotate_right"):
			_target_yaw -= deg_to_rad(orbit_step_degrees)
		if Input.is_action_just_pressed("camera_zoom_in"):
			if fighting:
				_combat_distance = maxf(17.0, _combat_distance - 1.25)
			else:
				_distance = maxf(7.0, _distance - 1.25)
		if Input.is_action_just_pressed("camera_zoom_out"):
			if fighting:
				_combat_distance = minf(26.0, _combat_distance + 1.25)
			else:
				_distance = minf(20.0 if _dungeon else 15.0, _distance + 1.25)

	_dialogue_blend = move_toward(_dialogue_blend, 1.0 if _dialogue_active else 0.0, delta / 0.85)
	var shot_weight: float = smoothstep(0.0, 1.0, _dialogue_blend)
	_combat_blend = move_toward(_combat_blend, 1.0 if fighting else 0.0, delta / 0.65)
	var exploration_focus: Vector3 = _exploration_focus()
	if fighting:
		exploration_focus = exploration_focus.lerp(_combat_target.global_position, _combat_blend)
	var follow_weight := 1.0 - exp(-delta * 7.5)
	var desired_focus: Vector3 = exploration_focus.lerp(_dialogue_focus, shot_weight)
	_advance_shots(delta, desired_focus, _framing_distance())
	var request_weight: float = smoothstep(0.0, 1.0, _shot_weight)
	desired_focus = desired_focus.lerp(_shot_focus, request_weight)
	global_position = global_position.lerp(desired_focus, follow_weight)
	# End the subpixel tail of exponential following once it is imperceptible.
	if global_position.distance_squared_to(desired_focus) < 0.002 * 0.002:
		global_position = desired_focus
	var desired_yaw: float = lerp_angle(_target_yaw, _dialogue_yaw, shot_weight) + _shot_yaw_offset * request_weight
	rotation.y = lerp_angle(rotation.y, desired_yaw, 1.0 - exp(-delta * 8.0))
	if absf(angle_difference(rotation.y, desired_yaw)) < 0.0001:
		rotation.y = desired_yaw
	_update_camera_local_position()
	camera.look_at(global_position + Vector3.UP * 0.78, Vector3.UP)
	if _dialogue_active and is_instance_valid(_dialogue_partner) and not _dialogue_subjects_in_safe_area():
		_preview_dialogue_camera()
	var subjects: Array[Node3D] = []
	if _dialogue_blend > 0.0 and is_instance_valid(_dialogue_partner):
		subjects.assign([_target, _dialogue_partner])
	_dialogue_occlusion.update(subjects, delta)


## Lens distance from exploration, combat and dialogue, before requested shots.
func _framing_distance() -> float:
	var exploration_distance: float = lerpf(_distance, _combat_distance, smoothstep(0.0, 1.0, _combat_blend))
	return lerpf(exploration_distance, _dialogue_distance, smoothstep(0.0, 1.0, _dialogue_blend))


func _update_camera_local_position() -> void:
	var shot_weight: float = smoothstep(0.0, 1.0, _dialogue_blend)
	var request_weight: float = smoothstep(0.0, 1.0, _shot_weight)
	var shot_distance: float = lerpf(_framing_distance(), _shot_distance, request_weight)
	if _indoors:
		# Preserve zoom and dialogue framing without shrinking distant people.
		camera.size = shot_distance * 0.64
	var elevation: float = lerpf(lerpf(_base_elevation(), _dialogue_elevation, shot_weight), _shot_elevation, request_weight)
	camera.position = Vector3(0.0, shot_distance * elevation, shot_distance * 0.83)


func configure_dialogue_scenery(scenery: Node3D) -> void:
	_dialogue_occlusion.configure(scenery, camera)


func add_combat_impact(strength: float) -> void:
	_impact_left = 0.16
	_impact_strength = maxf(_impact_strength, strength)

func advance_combat_feedback(delta: float) -> void:
	_impact_left = maxf(0.0, _impact_left - delta)
	var envelope: float = _impact_left / 0.16
	camera.h_offset = sin(_impact_left * 95.0) * _impact_strength * envelope
	camera.v_offset = cos(_impact_left * 75.0) * _impact_strength * envelope * 0.45
	if _impact_left == 0.0:
		_impact_strength = 0.0


func rotate_from_touch(radians: float) -> void:
	var fighting: bool = is_instance_valid(_combat_target) and GameState.mode == GameState.Mode.BATTLE
	var allowed: bool = not GameState.is_input_locked() or (fighting and GameState.battle_session != null and not bool(GameState.battle_session.paused))
	if allowed and is_finite(radians):
		_target_yaw = wrapf(_target_yaw + radians, -PI, PI)
