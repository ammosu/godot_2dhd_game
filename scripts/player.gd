class_name Wanderer
extends CharacterBody3D

@export_range(0.5, 12.0, 0.1) var move_speed: float = 4.2
@export_range(1.0, 40.0, 0.5) var acceleration: float = 18.0

@onready var sprite: Sprite3D = $Sprite3D

var _gravity: float = float(ProjectSettings.get_setting("physics/3d/default_gravity", 18.0))
var _walk_time: float = 0.0
var _sprite_rest_height: float
var _facing_column: int = 0
var _interaction_area: Area3D


func _ready() -> void:
	_sprite_rest_height = sprite.position.y
	_create_contact_shadow()
	_create_interaction_detector()


func _physics_process(delta: float) -> void:
	if GameState.is_input_locked():
		velocity.x = move_toward(velocity.x, 0.0, acceleration * delta)
		velocity.z = move_toward(velocity.z, 0.0, acceleration * delta)
		if not is_on_floor():
			velocity.y -= _gravity * delta
		move_and_slide()
		_update_sprite(Vector2.ZERO, Vector3.ZERO, delta)
		return
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


func _unhandled_input(event: InputEvent) -> void:
	if GameState.is_input_locked() or event.is_echo():
		return
	if event.is_action_pressed("interact"):
		var target := get_nearest_interactable()
		if target != null:
			target.interact()
			get_viewport().set_input_as_handled()


func get_nearest_interactable() -> Interactable3D:
	if _interaction_area == null:
		return null
	var nearest: Interactable3D
	var nearest_distance := INF
	for area in _interaction_area.get_overlapping_areas():
		if area is Interactable3D:
			var distance := global_position.distance_squared_to(area.global_position)
			if distance < nearest_distance:
				nearest = area
				nearest_distance = distance
	return nearest


func get_interaction_prompt() -> String:
	var target := get_nearest_interactable()
	return target.prompt_text if target != null else ""


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


func _create_interaction_detector() -> void:
	_interaction_area = Area3D.new()
	_interaction_area.name = "InteractionDetector"
	_interaction_area.collision_layer = 0
	_interaction_area.collision_mask = 8
	_interaction_area.monitoring = true
	var shape_node := CollisionShape3D.new()
	shape_node.position.y = 0.65
	var shape := SphereShape3D.new()
	shape.radius = 1.65
	shape_node.shape = shape
	_interaction_area.add_child(shape_node)
	add_child(_interaction_area)
