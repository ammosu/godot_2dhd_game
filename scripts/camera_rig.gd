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
var _outdoor_distance: float
var _outdoor_yaw: float
var _dialogue_active: bool = false
var _dialogue_blend: float = 0.0
var _dialogue_focus: Vector3
var _dialogue_yaw: float = 0.0
var _dialogue_distance: float = 6.2


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
	_dialogue_active = true


func _on_state_changed() -> void:
	if GameState.mode != GameState.Mode.DIALOGUE:
		_dialogue_active = false


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
	_dialogue_active = false
	_dialogue_blend = 0.0
	if _target == null:
		return
	global_position = Vector3.ZERO if _indoors else _target.global_position
	rotation.y = _target_yaw
	_update_camera_local_position()
	camera.look_at(global_position + Vector3.UP * 0.78, Vector3.UP)


func _ready() -> void:
	GameState.state_changed.connect(_on_state_changed)
	_target = get_node_or_null(target_path) as Node3D
	_distance = starting_distance
	rotation.y = _target_yaw
	_configure_camera_attributes()
	camera.current = true
	_update_camera_local_position()


func _configure_camera_attributes() -> void:
	if RenderingServer.get_current_rendering_method() == "gl_compatibility":
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

	if not GameState.is_input_locked():
		if Input.is_action_just_pressed("camera_rotate_left"):
			_target_yaw += deg_to_rad(orbit_step_degrees)
		if Input.is_action_just_pressed("camera_rotate_right"):
			_target_yaw -= deg_to_rad(orbit_step_degrees)
		if Input.is_action_just_pressed("camera_zoom_in"):
			_distance = maxf(7.0, _distance - 1.25)
		if Input.is_action_just_pressed("camera_zoom_out"):
			_distance = minf(15.0, _distance + 1.25)

	_dialogue_blend = move_toward(_dialogue_blend, 1.0 if _dialogue_active else 0.0, delta / 0.85)
	var shot_weight: float = smoothstep(0.0, 1.0, _dialogue_blend)
	var exploration_focus: Vector3 = Vector3.ZERO if _indoors else _target.global_position
	var follow_weight := 1.0 - exp(-delta * 7.5)
	global_position = global_position.lerp(exploration_focus.lerp(_dialogue_focus, shot_weight), follow_weight)
	var desired_yaw: float = lerp_angle(_target_yaw, _dialogue_yaw, shot_weight)
	rotation.y = lerp_angle(rotation.y, desired_yaw, 1.0 - exp(-delta * 8.0))
	_update_camera_local_position()
	camera.look_at(global_position + Vector3.UP * 0.78, Vector3.UP)


func _update_camera_local_position() -> void:
	var shot_weight: float = smoothstep(0.0, 1.0, _dialogue_blend)
	var shot_distance: float = lerpf(_distance, _dialogue_distance, shot_weight)
	if _indoors:
		# Preserve zoom without shrinking distant residents.
		camera.size = shot_distance * 0.64
	var elevation: float = lerpf(0.56, 0.40, shot_weight)
	camera.position = Vector3(0.0, shot_distance * elevation, shot_distance * 0.83)
