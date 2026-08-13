class_name Hd2dCameraRig
extends Node3D

@export var target_path: NodePath
@export_range(5.0, 20.0, 0.5) var starting_distance: float = 11.0
@export_range(15.0, 70.0, 1.0) var orbit_step_degrees: float = 45.0

@onready var camera: Camera3D = $Camera3D

var _target: Node3D
var _target_yaw: float = deg_to_rad(45.0)
var _distance: float


func _ready() -> void:
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
	attributes.dof_blur_far_distance = 13.0
	attributes.dof_blur_far_transition = 6.0
	attributes.dof_blur_near_enabled = true
	attributes.dof_blur_near_distance = 5.0
	attributes.dof_blur_near_transition = 3.0
	attributes.dof_blur_amount = 0.12
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

	var follow_weight := 1.0 - exp(-delta * 7.5)
	global_position = global_position.lerp(_target.global_position, follow_weight)
	rotation.y = lerp_angle(rotation.y, _target_yaw, 1.0 - exp(-delta * 8.0))
	_update_camera_local_position()
	camera.look_at(global_position + Vector3.UP * 0.78, Vector3.UP)


func _update_camera_local_position() -> void:
	camera.position = Vector3(0.0, _distance * 0.56, _distance * 0.83)
