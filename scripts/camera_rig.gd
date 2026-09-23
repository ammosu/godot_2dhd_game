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
var _combat_target: Node3D
var _impact_left: float = 0.0
var _impact_strength: float = 0.0
var _combat_blend: float = 0.0
var _combat_distance: float = 21.0


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
	var separation: Vector3 = partner.global_position - _target.global_position
	separation.y = 0.0
	_dialogue_focus = (_target.global_position + partner.global_position) * 0.5
	# Frame both characters above the dialogue panel, from the nearest side.
	_dialogue_focus.y -= 0.55
	var side_yaw: float = atan2(separation.z, -separation.x)
	if absf(wrapf(side_yaw - rotation.y, -PI, PI)) > PI * 0.5:
		side_yaw += PI
	_dialogue_yaw = side_yaw if separation.length() > 0.1 else rotation.y
	_dialogue_distance = clampf(separation.length() * 1.6 + 3.5, 6.2, 10.0)
	_dialogue_partner = partner
	_dialogue_active = true


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
		_distance = 17.0
	else:
		_target_yaw = _pre_dungeon_yaw
		camera.fov = _pre_dungeon_fov
	_configure_camera_attributes()


func _exploration_focus() -> Vector3:
	if _indoors:
		return Vector3.ZERO
	return _target.global_position + (Vector3(0, 0, -3.0).rotated(Vector3.UP, _target_yaw) if _dungeon else Vector3.ZERO)


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
	global_position = global_position.lerp(exploration_focus.lerp(_dialogue_focus, shot_weight), follow_weight)
	var desired_yaw: float = lerp_angle(_target_yaw, _dialogue_yaw, shot_weight)
	rotation.y = lerp_angle(rotation.y, desired_yaw, 1.0 - exp(-delta * 8.0))
	_update_camera_local_position()
	camera.look_at(global_position + Vector3.UP * 0.78, Vector3.UP)
	var subjects: Array[Node3D] = []
	if _dialogue_blend > 0.0 and is_instance_valid(_dialogue_partner):
		subjects.assign([_target, _dialogue_partner])
	_dialogue_occlusion.update(subjects, delta)


func _update_camera_local_position() -> void:
	var shot_weight: float = smoothstep(0.0, 1.0, _dialogue_blend)
	var exploration_distance: float = lerpf(_distance, _combat_distance, smoothstep(0.0, 1.0, _combat_blend))
	var shot_distance: float = lerpf(exploration_distance, _dialogue_distance, shot_weight)
	if _indoors:
		# Preserve zoom and dialogue framing without shrinking distant people.
		camera.size = shot_distance * 0.64
	var elevation: float = lerpf(0.56, 0.40, shot_weight)
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
