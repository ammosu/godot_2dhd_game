class_name Wanderer
extends CharacterBody3D
const Proportions = preload("res://scripts/gameplay/character_proportions.gd")

@export_range(0.5, 12.0, 0.1) var move_speed: float = 4.2
@export_range(1.0, 40.0, 0.5) var acceleration: float = 18.0

const EightWayFacing = preload("res://scripts/gameplay/eight_way_facing.gd")
var _movement_facing := preload("res://scripts/gameplay/movement_facing.gd").new()
const FACING_ANIMATIONS: Array[StringName] = EightWayFacing.ANIMATIONS
const SpriteGrounding = preload("res://scripts/gameplay/sprite_grounding.gd")
const Footsteps = preload("res://scripts/gameplay/footsteps.gd")
const EquipmentAppearance = preload("res://scripts/gameplay/equipment_appearance.gd")
const DoorActionArt = preload("res://scripts/gameplay/door_action_art.gd")
const TownAppearance = preload("res://scripts/gameplay/town_appearance.gd")
const CONVERSATION_DISTANCE: float = 1.35
var auto_walk := preload("res://scripts/gameplay/map_navigation.gd").new()
var ground_safety := preload("res://scripts/gameplay/ground_safety.gd").new()
var field_combat: Node
var _appearance_key: String = ""

@onready var sprite: AnimatedSprite3D = $Sprite3D
@onready var _base_pixel_size: float = sprite.pixel_size

var _gravity: float = float(ProjectSettings.get_setting("physics/3d/default_gravity", 18.0))
var _walk_time: float = 0.0
var _sprite_rest_height: float
var _facing_column: int = 0
var _interaction_area: Area3D
var _footsteps := Footsteps.new()
var _last_step_position: Vector3
var _footstep_map: String = ""
var _door_facing_locked: bool = false
var _door_facing_target: Vector3 = Vector3.ZERO
var _automatic_interaction_armed: bool = false
var _door_pose: int = -1
var _presentation_scale: float = 1.0
var _walking_offset: Vector2


func _ready() -> void:
	ground_safety.player = self
	add_child(ground_safety)
	add_child(auto_walk)
	auto_walk.player = self
	_last_step_position = global_position
	SpriteGrounding.anchor(sprite, sprite.sprite_frames.get_frame_texture(&"down", 0))
	_sprite_rest_height = sprite.position.y
	_walking_offset = sprite.offset
	SpriteGrounding.add_shadow(self, 0.32, 0.028)
	_create_interaction_detector()
	GameState.state_changed.connect(_refresh_equipment)
	_refresh_equipment()
	sprite.frame_changed.connect(_refresh_style)
	sprite.animation_changed.connect(_refresh_style)
	_refresh_style()


func _refresh_style() -> void:
	GameState.HeroStyle.apply_sprite(sprite, sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame), GameState.player_style)


func set_presentation_scale(factor: float) -> void:
	_presentation_scale = factor
	sprite.pixel_size = _base_pixel_size * factor
	# The sprite pivots around its feet; scale the ground shadow in X/Z only.
	$ContactShadow.scale = Vector3(factor, 1.0, factor)


func presentation_height() -> float:
	# Measured standing body, excluding the walking atlas's transparent margins.
	return Proportions.HEIGHT * _presentation_scale


func _refresh_equipment() -> void:
	_refresh_style()
	var loadout := GameState.get_visual_loadout()
	var town := TownAppearance.applies(GameState.current_map, loadout)
	var key := EquipmentAppearance.variant(loadout) + (":town" if town else "") + (":door" if _door_pose >= 0 else "")
	if key == _appearance_key:
		return
	_appearance_key = key
	var direction := sprite.animation
	var frame := sprite.frame
	if town:
		sprite.sprite_frames = TownAppearance.frames(loadout, _door_pose >= 0)
	else:
		sprite.sprite_frames = DoorActionArt.frames(loadout) if _door_pose >= 0 else EquipmentAppearance.walking_frames(loadout)
	sprite.animation = direction
	sprite.frame = mini(frame, sprite.sprite_frames.get_frame_count(direction) - 1)
	_refresh_style()


func _physics_process(delta: float) -> void:
	if GameState.mode == GameState.Mode.MAP:
		_movement_facing.update(Vector2.ZERO, delta)
		velocity = Vector3.ZERO
		_last_step_position = global_position
		_update_sprite(Vector2.ZERO, Vector3.ZERO, delta)
		return
	if _footstep_map != GameState.current_map or global_position.distance_to(_last_step_position) > 2.0:
		_footsteps.advance(0.0, false, false, true)
		_footstep_map = GameState.current_map
	if GameState.is_input_locked():
		_movement_facing.update(Vector2.ZERO, delta)
		_footsteps.advance(0.0, false, false, true)
		velocity.x = move_toward(velocity.x, 0.0, acceleration * delta)
		velocity.z = move_toward(velocity.z, 0.0, acceleration * delta)
		if not is_on_floor():
			velocity.y -= _gravity * delta
		move_and_slide()
		_last_step_position = global_position
		_update_sprite(Vector2.ZERO, Vector3.ZERO, delta)
		return
	var input_vector := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var facing_input := _movement_facing.update(input_vector, delta)
	var move_direction := _camera_relative_direction(input_vector)
	if not input_vector.is_zero_approx():
		auto_walk.cancel()
	elif auto_walk.is_active():
		move_direction = auto_walk.direction(delta)
		input_vector = EightWayFacing.screen_direction(move_direction, get_viewport().get_camera_3d())
		facing_input = input_vector
	var target_velocity := move_direction * move_speed
	if is_instance_valid(field_combat):
		target_velocity = field_combat.movement_velocity(target_velocity, delta, _camera_relative_direction(facing_input))
		move_direction = target_velocity.normalized()
		input_vector = EightWayFacing.screen_direction(move_direction, get_viewport().get_camera_3d())
		facing_input = EightWayFacing.screen_direction(field_combat.get("facing"), get_viewport().get_camera_3d())

	velocity.x = move_toward(velocity.x, target_velocity.x, acceleration * delta)
	velocity.z = move_toward(velocity.z, target_velocity.z, acceleration * delta)
	if is_instance_valid(field_combat) and float(field_combat.get("dodge_time")) > 0.0:
		velocity.x = target_velocity.x
		velocity.z = target_velocity.z
	if not is_on_floor():
		velocity.y -= _gravity * delta
	else:
		velocity.y = -0.1

	var before_move := global_position
	move_and_slide()
	var traveled := Vector2(global_position.x - before_move.x, global_position.z - before_move.z).length()
	if _footsteps.advance(traveled, is_on_floor(), not input_vector.is_zero_approx(), GameState.is_input_locked()):
		GameAudio.play_cue(_footsteps.next_cue(Footsteps.surface_at(get_tree(), global_position)))
	_last_step_position = global_position
	_update_sprite(facing_input, move_direction, delta)
	if not auto_walk.is_active():
		_update_automatic_interaction()


func reset_automatic_interaction() -> void:
	# Arriving or loading beside a door requires leaving its near zone first.
	_automatic_interaction_armed = false


func _update_automatic_interaction() -> void:
	if GameState.is_input_locked():
		return
	var nearest: Interactable3D
	var nearest_distance: float = INF
	var inside_release_zone: bool = false
	for node: Node in get_tree().get_nodes_in_group("proximity_interactables"):
		var area := node as Interactable3D
		var offset := area.global_position - global_position
		var distance := Vector2(offset.x, offset.z).length()
		if absf(offset.y) > 1.5:
			continue
		if distance <= area.automatic_distance + 0.2:
			inside_release_zone = true
		if distance > area.automatic_distance or distance >= nearest_distance:
			continue
		if not area.facing_direction.is_zero_approx() and not is_facing_direction(area.global_basis * area.facing_direction):
			continue
		nearest = area
		nearest_distance = distance
	if not inside_release_zone:
		_automatic_interaction_armed = true
	if _automatic_interaction_armed and nearest != null:
		_automatic_interaction_armed = false
		nearest.interact()


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
			if not area.facing_direction.is_zero_approx():
				if not is_facing_direction(area.global_basis * area.facing_direction):
					continue
			var distance := global_position.distance_squared_to(area.global_position)
			if distance < nearest_distance:
				nearest = area
				nearest_distance = distance
	return nearest


func is_facing_direction(world_direction: Vector3) -> bool:
	var direction := EightWayFacing.screen_direction(world_direction, get_viewport().get_camera_3d())
	if direction.is_zero_approx():
		return false
	# Match the visible eight-way facing, including after the camera orbits.
	var sector: int = EightWayFacing.SECTORS.find(_facing_column)
	var facing := Vector2.from_angle(float(sector) * PI / 4.0)
	return facing.dot(direction.normalized()) >= cos(PI / 4.0) - 0.0001


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
	if _door_facing_locked:
		input_vector = EightWayFacing.screen_direction(_door_facing_target - global_position, get_viewport().get_camera_3d())
		_update_facing_column(input_vector)
	_refresh_equipment()
	if _door_pose >= 0:
		sprite.animation = FACING_ANIMATIONS[_facing_column]
		sprite.frame = _door_pose
		var texture := sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
		sprite.pixel_size = presentation_height() / float(texture.get_meta("body_height"))
		sprite.scale.x = float(texture.get_meta("width_scale", sprite.scale.x))
		sprite.offset = Vector2(texture.get_width() * 0.5 - float(texture.get_meta("foot_center")), float(texture.get_meta("ground_y")) - texture.get_height() * 0.5)
		sprite.flip_h = bool(texture.get_meta("flip_h", false))
		if sprite.flip_h:
			sprite.offset.x *= -1.0
		return
	sprite.pixel_size = _base_pixel_size * _presentation_scale
	sprite.offset = _walking_offset
	sprite.flip_h = false
	if not move_direction.is_zero_approx():
		_walk_time += delta * 8.0
		if not _door_facing_locked:
			_update_facing_column(input_vector)
		sprite.animation = FACING_ANIMATIONS[_facing_column]
		sprite.frame = int(floor(_walk_time)) % 4
		sprite.position.y = _sprite_rest_height
		sprite.rotation.z = 0.0
	else:
		_walk_time = 0.0
		sprite.animation = FACING_ANIMATIONS[_facing_column]
		sprite.frame = 0
		sprite.position.y = move_toward(sprite.position.y, _sprite_rest_height, delta * 0.5)
		sprite.rotation.z = move_toward(sprite.rotation.z, 0.0, delta * 0.5)
	_refresh_equipment()
	var standing := sprite.sprite_frames.get_frame_texture(sprite.animation, 0)
	var texture := sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
	if texture.has_meta("width_scale"):
		sprite.pixel_size = presentation_height() / float(texture.get_meta("body_height"))
		sprite.scale.x = float(texture.get_meta("width_scale"))
	else:
		Proportions.apply(sprite, standing, float(standing.get_meta("body_height", 290.0)), presentation_height())
	SpriteGrounding.anchor(sprite, texture, float(texture.get_meta("ground_y", 316.0)))
	if texture.has_meta("anchor_x"):
		sprite.offset.x = texture.get_width() * 0.5 - float(texture.get_meta("anchor_x"))


func reach_for_door() -> void:
	# The door remains still until the visibly articulated hand reaches contact.
	_door_pose = 0
	_update_sprite(Vector2.ZERO, Vector3.ZERO, 0.0)
	await get_tree().create_timer(0.16).timeout
	_door_pose = 1
	_update_sprite(Vector2.ZERO, Vector3.ZERO, 0.0)
	await get_tree().create_timer(0.10).timeout


func withdraw_door_hand() -> void:
	_door_pose = 0
	_update_sprite(Vector2.ZERO, Vector3.ZERO, 0.0)
	await get_tree().create_timer(0.16).timeout
	_door_pose = -1
	_update_sprite(Vector2.ZERO, Vector3.ZERO, 0.0)


func _update_facing_column(input_vector: Vector2) -> void:
	# Eight equal 45-degree sectors support keyboard and analog input alike.
	# Facing stays screen-relative while the camera orbits; idle keeps its sector.
	if input_vector.is_zero_approx():
		return
	_facing_column = EightWayFacing.direction_index(input_vector)


func make_conversation_space(partner: Node3D) -> void:
	# Stop approach momentum before framing the shot. Keep the NPC at its post.
	velocity.x = 0.0
	velocity.z = 0.0
	var away: Vector3 = global_position - partner.global_position
	away.y = 0.0
	if away.length() >= CONVERSATION_DISTANCE:
		return
	if away.is_zero_approx():
		away = _camera_relative_direction(Vector2.RIGHT)
	away = away.normalized()
	# Saves or scripted placement can start inside the speaker. Let the retreat
	# leave that body, while still sweeping against walls and other characters.
	var ignored_bodies: Array[PhysicsBody3D] = []
	for node: Node in partner.find_children("*", "PhysicsBody3D", true, false):
		var body := node as PhysicsBody3D
		if not get_collision_exceptions().has(body):
			add_collision_exception_with(body)
			ignored_bodies.append(body)
	# Try the shortest retreat first, then nearby sides when scenery blocks it.
	# Sweep the whole body rather than teleporting through a wall to a clear point.
	for degrees: float in [0.0, 30.0, -30.0, 60.0, -60.0, 90.0, -90.0, 120.0, -120.0, 150.0, -150.0, 180.0]:
		var destination: Vector3 = partner.global_position + away.rotated(Vector3.UP, deg_to_rad(degrees)) * CONVERSATION_DISTANCE
		destination.y = global_position.y
		var motion: Vector3 = destination - global_position
		if not test_move(global_transform, motion):
			move_and_collide(motion)
			break
	for body: PhysicsBody3D in ignored_bodies:
		remove_collision_exception_with(body)


func walk_to_door_point(target: Vector3, speed: float = 2.8) -> bool:
	# Keep scripted steps collision-aware and animate them like ordinary walking.
	var was_processing := is_physics_processing()
	set_physics_process(false)
	var reached: bool = false
	for step: int in range(240):
		await get_tree().physics_frame
		var offset := Vector3(target.x - global_position.x, 0, target.z - global_position.z)
		if offset.length() < 0.035:
			reached = true
			break
		var delta := get_physics_process_delta_time()
		var direction := offset.normalized()
		velocity = direction * minf(speed, offset.length() / delta)
		velocity.y = -2.0
		var before := global_position
		# Climb the real low doorstep using sweeps, never teleport through walls.
		var horizontal := direction * minf(speed * delta, offset.length())
		var raised := global_transform
		raised.origin.y += 0.34
		var climb := test_move(global_transform, horizontal) and not test_move(global_transform, Vector3.UP * 0.34) and not test_move(raised, horizontal)
		if climb:
			move_and_collide(Vector3.UP * 0.34)
		move_and_slide()
		if climb:
			move_and_collide(Vector3.DOWN * 0.36)
		var traveled := Vector2(global_position.x - before.x, global_position.z - before.z).length()
		if _footsteps.advance(traveled, is_on_floor(), true, false):
			GameAudio.play_cue(_footsteps.next_cue(Footsteps.surface_at(get_tree(), global_position)))
		_update_sprite(EightWayFacing.screen_direction(direction, get_viewport().get_camera_3d()), direction, delta)
		if Vector2(global_position.x - before.x, global_position.z - before.z).length() < 0.001:
			break
	velocity = Vector3.ZERO
	_update_sprite(Vector2.ZERO, Vector3.ZERO, 0.0)
	_last_step_position = global_position
	set_physics_process(was_processing)
	return reached


func lock_door_facing(target: Vector3) -> void:
	_door_facing_target = target
	_door_facing_locked = true
	face_world_position(target)


func release_door_facing() -> void:
	_door_facing_locked = false
	_door_pose = -1
	_update_sprite(Vector2.ZERO, Vector3.ZERO, 0.0)


func face_world_position(target: Vector3) -> void:
	var direction := EightWayFacing.screen_direction(target - global_position, get_viewport().get_camera_3d())
	_update_facing_column(direction)
	_update_sprite(Vector2.ZERO, Vector3.ZERO, 0.0)


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
