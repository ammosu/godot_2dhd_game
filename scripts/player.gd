class_name Wanderer
extends CharacterBody3D

@export_range(0.5, 12.0, 0.1) var move_speed: float = 4.2
@export_range(1.0, 40.0, 0.5) var acceleration: float = 18.0

@onready var sprite: Sprite3D = $Sprite3D

var _gravity: float = float(ProjectSettings.get_setting("physics/3d/default_gravity", 18.0))
var _walk_time: float = 0.0
var _sprite_rest_height: float
var _facing_column: int = 0


func _ready() -> void:
	_sprite_rest_height = sprite.position.y
	_create_contact_shadow()


func _physics_process(delta: float) -> void:
	var input_vector := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var move_direction := _camera_relative_direction(input_vector)
	var target_velocity := move_direction * move_speed

	velocity.x = move_toward(velocity.x, target_velocity.x, acceleration * delta)
	velocity.z = move_toward(velocity.z, target_velocity.z, acceleration * delta)
	if not is_on_floor():
		velocity.y -= _gravity * delta
	else:
		velocity.y = -0.1

	move_and_slide()
	_update_sprite(input_vector, move_direction, delta)


func _camera_relative_direction(input_vector: Vector2) -> Vector3:
	if input_vector.is_zero_approx():
		return Vector3.ZERO

	var active_camera := get_viewport().get_camera_3d()
	if active_camera == null:
		return Vector3(input_vector.x, 0.0, input_vector.y).normalized()

	var camera_right := active_camera.global_basis.x
	var camera_forward := -active_camera.global_basis.z
	camera_right.y = 0.0
	camera_forward.y = 0.0
	camera_right = camera_right.normalized()
	camera_forward = camera_forward.normalized()
	return (camera_right * input_vector.x + camera_forward * -input_vector.y).normalized()


func _update_sprite(input_vector: Vector2, move_direction: Vector3, delta: float) -> void:
	if not move_direction.is_zero_approx():
		_walk_time += delta * 8.0
		_update_facing_column(input_vector)
		sprite.frame_coords = Vector2i(_facing_column, int(floor(_walk_time)) % 4)
		sprite.position.y = _sprite_rest_height + abs(sin(_walk_time * PI * 0.5)) * 0.025
		sprite.rotation.z = sin(_walk_time * PI * 0.5) * 0.018
	else:
		_walk_time = 0.0
		sprite.frame_coords = Vector2i(_facing_column, 0)
		sprite.position.y = move_toward(sprite.position.y, _sprite_rest_height, delta * 0.5)
		sprite.rotation.z = move_toward(sprite.rotation.z, 0.0, delta * 0.5)


func _update_facing_column(input_vector: Vector2) -> void:
	# Atlas columns: down, up, left, right. Movement remains screen-relative
	# even when the 3D camera orbits around the player.
	if absf(input_vector.x) > absf(input_vector.y):
		_facing_column = 3 if input_vector.x > 0.0 else 2
	elif absf(input_vector.y) > 0.05:
		_facing_column = 0 if input_vector.y > 0.0 else 1


func _create_contact_shadow() -> void:
	var shadow := MeshInstance3D.new()
	shadow.name = "ContactShadow"
	shadow.position.y = 0.025
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.32
	mesh.bottom_radius = 0.32
	mesh.height = 0.012
	mesh.radial_segments = 20
	shadow.mesh = mesh

	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.04, 0.035, 0.06, 0.34)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shadow.material_override = material
	add_child(shadow)
