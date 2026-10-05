class_name Wanderer
extends CharacterBody3D
const Proportions = preload("res://scripts/gameplay/character_proportions.gd")

@export_range(0.5, 12.0, 0.1) var move_speed: float = 4.2
@export_range(1.0, 40.0, 0.5) var acceleration: float = 18.0
## Braking is a little firmer than starting so stops read as planted feet.
@export_range(1.0, 40.0, 0.5) var deceleration: float = 24.0

const EightWayFacing = preload("res://scripts/gameplay/eight_way_facing.gd")
var _movement_facing := preload("res://scripts/gameplay/movement_facing.gd").new()
const FACING_ANIMATIONS: Array[StringName] = EightWayFacing.ANIMATIONS
const SpriteGrounding = preload("res://scripts/gameplay/sprite_grounding.gd")
const Footsteps = preload("res://scripts/gameplay/footsteps.gd")
const EquipmentAppearance = preload("res://scripts/gameplay/equipment_appearance.gd")
const DoorActionArt = preload("res://scripts/gameplay/door_action_art.gd")
const TownAppearance = preload("res://scripts/gameplay/town_appearance.gd")
const ClassArt = preload("res://scripts/gameplay/class_art.gd")
const CONVERSATION_DISTANCE: float = 1.35
const MovementFacing = preload("res://scripts/gameplay/movement_facing.gd")
## Developer preview of Blender-rigged walking art (tools/art/build_blender_character.py):
## `-- --blender-hero` shows the raw render of the current class, `-- --blender-hero=painted`
## the repaint over it, `-- --legacy-hero` the hand-painted four-frame atlas.
## Classes without such an atlas keep their usual art. The unequipped traveler
## walks with the painted rig (stand + eight-frame cycle) by default.
const RENDERED_WALK_FLAGS: Dictionary[String, String] = {"--blender-hero": "walk", "--blender-hero=painted": "painted", "--legacy-hero": ""}
const DEFAULT_TRAVELER_WALK := "res://assets/generated/blender/wanderer/painted_frames.tres"
const RENDERED_WALK_PATH := "res://assets/generated/blender/%s/%s_frames.tres"

# Locomotion tuning. A walk cycle of N frames holds two steps starting at a
# passing pose, contacts at N/4 and 3N/4: the legacy four-frame atlases are
# [pass, contact, pass, contact]; rigged atlases put a standing pose in frame 0
# (metadata/pose "stand") ahead of an eight-frame passing/up/contact/down
# cycle. The phase (_walk_time) always counts four units per cycle, so gear
# changes between atlases keep the stride; _cycle_frame() maps it to frames.
## Distance between successive foot contacts (m). Measured once from the
## traveler's side profile (wanderer_steady_frames "left"/"right"): contact
## frames span about 0.68 m heel to toe at the 1.45 m stature, minus roughly
## 0.15 m of shoe. Tune by eye with tests/opening_cutscene_test.gd --capture-dir.
const STEP_LENGTH: float = 0.54
## Cadence floor (phase units per second) for crawls; scales with the stride.
const MIN_WALK_FPS: float = 4.0
## Cadence ceiling in steps per second, independent of the stride. A chibi's
## short rigged stride would need ten steps a second at full speed; above this
## the feet glide a little rather than scurry.
const MAX_STEPS_PER_SECOND: float = 7.0
## Shortest stride the cadence follows. The rigged chibi plants 0.40 m steps,
## which at a 1.9 m/s cutscene stroll meant almost five hurried steps a second;
## pacing by the hand-painted stride instead lets the feet glide a little.
const MIN_CADENCE_STRIDE: float = 0.54
## Time-based rate kept for direct presentation calls (tests and capture tools).
const PRESENTATION_WALK_FPS: float = 8.0
## Planar speed below which the body is considered standing.
const WALK_ANIMATION_MIN_SPEED: float = 0.25
## A new walk starts half a frame before the first contact pose.
const WALK_START_PHASE: float = 0.5
## After stopping, a mid-stride contact pose finishes to the next passing pose.
const WALK_SETTLE_FPS: float = 9.0
## Backing away with locked facing plays the cycle in reverse, a little slower.
const BACKSTEP_CADENCE_SCALE: float = 0.6
## Smallest analog tilt still produces this fraction of move_speed (no crawl-glide).
const ANALOG_MIN_SPEED_SCALE: float = 0.2
## Keep the current facing until a heading is this far from its sector centre.
const FACING_HYSTERESIS_DEGREES: float = 28.0
## Foot-anchored breathing once standing still.
const IDLE_BREATH_DELAY: float = 0.4
const IDLE_BREATH_AMPLITUDE: float = 0.006
const IDLE_BREATH_PERIOD: float = 3.2
## Scripted (cutscene, door, conversation) walks ease in and out.
const SCRIPTED_ACCELERATION: float = 4.0
const SCRIPTED_DECELERATION: float = 3.0
const SCRIPTED_START_SPEED: float = 0.3
## Final mark tolerance; small so the eased approach, not a snap, ends the walk.
const SCRIPTED_ARRIVE_RADIUS: float = 0.03
## Within this distance of an interior waypoint, steer partly toward the next leg.
const SCRIPTED_CORNER_BLEND: float = 0.45
const SCRIPTED_CORNER_RADIUS: float = 0.2
const SCRIPTED_CORNER_MAX_WEIGHT: float = 0.45
## Visual-only catch-up after the body climbs a doorstep inside one tick (m/s).
const DOORSTEP_EASE_SPEED: float = 2.5
var auto_walk := preload("res://scripts/gameplay/map_navigation.gd").new()
var ground_safety := preload("res://scripts/gameplay/ground_safety.gd").new()
var field_combat: Node
var _appearance_key: String = ""

@onready var sprite: AnimatedSprite3D = $Sprite3D
@onready var _base_pixel_size: float = sprite.pixel_size

var _gravity: float = float(ProjectSettings.get_setting("physics/3d/default_gravity", 18.0))
var _walk_time: float = 0.0
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
## Cutscene-owned route; only followed while GameState is in CUTSCENE mode.
var scripted_path := PackedVector3Array()
var scripted_speed: float = 2.4
var scripted_hold: bool = false
var _scripted_current_speed: float = 0.0
var _walk_animating: bool = false
var _walk_direction_sign: float = 1.0
var _idle_time: float = 0.0
## True while idle breathing owns sprite.scale.y. The flag lets the hero's
## BodyLife nod write scale.y without being reset every physics tick.
var _breathing: bool = false
## World heading of the last deliberate facing; standing re-derives the screen
## sector from it so a camera orbit does not turn the hero with the camera.
var _idle_world_heading: Vector3 = Vector3.ZERO
var _doorstep_offset: float = 0.0


func _ready() -> void:
	ground_safety.player = self
	add_child(ground_safety)
	add_child(auto_walk)
	auto_walk.player = self
	_last_step_position = global_position
	SpriteGrounding.anchor(sprite, sprite.sprite_frames.get_frame_texture(&"down", 0))
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


static func _rendered_walk_path(loadout: Dictionary) -> String:
	for flag: String in OS.get_cmdline_user_args():
		if RENDERED_WALK_FLAGS.has(flag):
			if str(RENDERED_WALK_FLAGS[flag]).is_empty():
				return ""
			var vocation := ClassArt.vocation(loadout)
			var path := RENDERED_WALK_PATH % ["wanderer" if vocation.is_empty() else vocation, RENDERED_WALK_FLAGS[flag]]
			return path if ResourceLoader.exists(path) else ""
	if ClassArt.vocation(loadout).is_empty() and EquipmentAppearance.variant(loadout).is_empty():
		return DEFAULT_TRAVELER_WALK
	return ""


func _refresh_equipment() -> void:
	_refresh_style()
	var loadout := GameState.get_visual_loadout()
	var town := TownAppearance.applies(GameState.current_map, loadout)
	var rendered := _rendered_walk_path(loadout) if _door_pose < 0 else ""
	var key := EquipmentAppearance.variant(loadout) + (":town" if town else "") + (":door" if _door_pose >= 0 else "") + rendered
	if key == _appearance_key:
		return
	_appearance_key = key
	var direction := sprite.animation
	var frame := sprite.frame
	var striding: bool = _walk_animating or not is_zero_approx(_walk_time)
	if not rendered.is_empty():
		sprite.sprite_frames = load(rendered) as SpriteFrames
	elif town:
		sprite.sprite_frames = TownAppearance.frames(loadout, _door_pose >= 0)
	else:
		sprite.sprite_frames = DoorActionArt.frames(loadout) if _door_pose >= 0 else EquipmentAppearance.walking_frames(loadout)
	sprite.animation = direction
	# Atlases differ in cycle length; the shared phase picks the matching pose.
	if _door_pose >= 0:
		sprite.frame = mini(frame, sprite.sprite_frames.get_frame_count(direction) - 1)
	else:
		sprite.frame = _cycle_first_frame() + posmod(_cycle_frame(), _cycle_length()) if striding else 0
	_refresh_style()


func _physics_process(delta: float) -> void:
	if GameState.mode == GameState.Mode.MAP:
		_movement_facing.update(Vector2.ZERO, delta)
		velocity = Vector3.ZERO
		_last_step_position = global_position
		_update_sprite(Vector2.ZERO, Vector3.ZERO, delta, 0.0)
		return
	if _footstep_map != GameState.current_map or global_position.distance_to(_last_step_position) > 2.0:
		_footsteps.advance(0.0, false, false, true)
		_footstep_map = GameState.current_map
	if GameState.mode == GameState.Mode.CUTSCENE:
		_follow_scripted_path(delta)
		return
	if GameState.is_input_locked():
		_movement_facing.update(Vector2.ZERO, delta)
		_footsteps.advance(0.0, false, false, true)
		velocity.x = move_toward(velocity.x, 0.0, deceleration * delta)
		velocity.z = move_toward(velocity.z, 0.0, deceleration * delta)
		if not is_on_floor():
			velocity.y -= _gravity * delta
		var before_locked := global_position
		move_and_slide()
		_last_step_position = global_position
		# Momentum carried into a dialogue still finishes its last half step.
		var coasting := Vector3(velocity.x, 0.0, velocity.z)
		_update_sprite(Vector2.ZERO, coasting if coasting.length() > WALK_ANIMATION_MIN_SPEED else Vector3.ZERO, delta,
			Vector2(global_position.x - before_locked.x, global_position.z - before_locked.z).length())
		return
	var input_vector := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var facing_input := _movement_facing.update(input_vector, delta)
	var move_direction := _camera_relative_direction(input_vector)
	# Keyboard vectors are unit length; a partly tilted stick or touch joystick
	# walks proportionally slower (Input.get_vector already removed the deadzone).
	var speed_scale: float = 1.0
	if not input_vector.is_zero_approx():
		speed_scale = clampf(input_vector.length(), ANALOG_MIN_SPEED_SCALE, 1.0)
		auto_walk.cancel()
	elif auto_walk.is_active():
		move_direction = auto_walk.direction(delta)
		input_vector = EightWayFacing.screen_direction(move_direction, get_viewport().get_camera_3d())
		facing_input = input_vector
	var target_velocity := move_direction * move_speed * speed_scale
	if is_instance_valid(field_combat):
		target_velocity = field_combat.movement_velocity(target_velocity, delta, _camera_relative_direction(facing_input))
		move_direction = target_velocity.normalized()
		input_vector = EightWayFacing.screen_direction(move_direction, get_viewport().get_camera_3d())
		facing_input = EightWayFacing.screen_direction(field_combat.get("facing"), get_viewport().get_camera_3d())

	var planar_speed := Vector2(velocity.x, velocity.z).length()
	var rate: float = deceleration if Vector2(target_velocity.x, target_velocity.z).length() < planar_speed - 0.001 else acceleration
	velocity.x = move_toward(velocity.x, target_velocity.x, rate * delta)
	velocity.z = move_toward(velocity.z, target_velocity.z, rate * delta)
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
	_last_step_position = global_position
	# Walk or stand by what the body actually does, not by the held input:
	# braking shows the last half step, pushing into a wall stands still.
	var motion := Vector3(velocity.x, 0.0, velocity.z)
	_update_sprite(facing_input, motion if motion.length() > WALK_ANIMATION_MIN_SPEED else Vector3.ZERO, delta, traveled)
	if not auto_walk.is_active():
		_update_automatic_interaction()


func play_scripted_walk(points: PackedVector3Array, speed: float) -> void:
	scripted_path = points.duplicate()
	scripted_speed = speed
	scripted_hold = false
	_scripted_current_speed = minf(Vector2(velocity.x, velocity.z).length(), speed)


func stop_scripted_walk() -> void:
	scripted_path.clear()
	scripted_hold = false
	_scripted_current_speed = 0.0
	velocity = Vector3.ZERO


func is_scripted_walking() -> bool:
	return not scripted_path.is_empty()


func _follow_scripted_path(delta: float) -> void:
	var flat := Vector3(global_position.x, 0.0, global_position.z)
	# Interior corners are rounded, so accept them from a little further away.
	while not scripted_path.is_empty():
		var radius: float = SCRIPTED_ARRIVE_RADIUS if scripted_path.size() == 1 else SCRIPTED_CORNER_RADIUS
		if flat.distance_to(Vector3(scripted_path[0].x, 0.0, scripted_path[0].z)) >= radius:
			break
		scripted_path.remove_at(0)
	var move_direction := Vector3.ZERO
	if not scripted_hold and not scripted_path.is_empty():
		move_direction = _scripted_heading(flat)
	if move_direction.is_zero_approx():
		_scripted_current_speed = 0.0
	else:
		# Ease in from a standstill and brake into the final mark.
		var cap := sqrt(2.0 * SCRIPTED_DECELERATION * _remaining_scripted_length(flat))
		_scripted_current_speed = minf(move_toward(maxf(_scripted_current_speed, SCRIPTED_START_SPEED), scripted_speed, SCRIPTED_ACCELERATION * delta), cap)
	velocity.x = move_direction.x * _scripted_current_speed
	velocity.z = move_direction.z * _scripted_current_speed
	if not is_on_floor():
		velocity.y -= _gravity * delta
	else:
		velocity.y = -0.1
	var before_move := global_position
	move_and_slide()
	var traveled := Vector2(global_position.x - before_move.x, global_position.z - before_move.z).length()
	_last_step_position = global_position
	var moving := not move_direction.is_zero_approx() and _scripted_current_speed > WALK_ANIMATION_MIN_SPEED
	var screen := EightWayFacing.screen_direction(move_direction, get_viewport().get_camera_3d()) if moving else Vector2.ZERO
	_update_sprite(screen, move_direction if moving else Vector3.ZERO, delta, traveled)


func _scripted_heading(flat: Vector3) -> Vector3:
	var target := Vector3(scripted_path[0].x, 0.0, scripted_path[0].z)
	var heading := (target - flat).normalized()
	if scripted_path.size() < 2:
		return heading
	var distance := flat.distance_to(target)
	if distance >= SCRIPTED_CORNER_BLEND:
		return heading
	var next_leg := (Vector3(scripted_path[1].x, 0.0, scripted_path[1].z) - target).normalized()
	# The weight stays below one half, so the walker always keeps closing on the
	# corner and cannot orbit it, even on a hairpin.
	var weight: float = (1.0 - distance / SCRIPTED_CORNER_BLEND) * SCRIPTED_CORNER_MAX_WEIGHT
	var blended := heading.lerp(next_leg, weight)
	return heading if blended.is_zero_approx() else blended.normalized()


func _remaining_scripted_length(flat: Vector3) -> float:
	var remaining: float = flat.distance_to(Vector3(scripted_path[0].x, 0.0, scripted_path[0].z))
	for index: int in range(1, scripted_path.size()):
		var a := scripted_path[index - 1]
		var b := scripted_path[index]
		remaining += Vector2(b.x - a.x, b.z - a.z).length()
	return remaining


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
	var fallback: Interactable3D
	var fallback_distance := INF
	for area in _interaction_area.get_overlapping_areas():
		if area is Interactable3D:
			if not area.facing_direction.is_zero_approx():
				if not is_facing_direction(area.global_basis * area.facing_direction):
					continue
			var distance := global_position.distance_squared_to(area.global_position)
			if area.low_priority:
				if distance < fallback_distance:
					fallback = area
					fallback_distance = distance
			elif distance < nearest_distance:
				nearest = area
				nearest_distance = distance
	return nearest if nearest != null else fallback


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


## `traveled` is the planar distance the body really moved this tick. Live
## movement passes it (>= 0): the walk phase then follows ground distance,
## stops finish their stride, footsteps land on contact frames and standing
## keeps its world heading. Direct presentation requests (tests, capture tools,
## door gestures) omit it and get the deterministic time-based pose instead.
func _update_sprite(input_vector: Vector2, move_direction: Vector3, delta: float, traveled: float = -1.0) -> void:
	var live: bool = traveled >= 0.0
	var walking: bool = not move_direction.is_zero_approx()
	if _door_facing_locked:
		input_vector = EightWayFacing.screen_direction(_door_facing_target - global_position, get_viewport().get_camera_3d())
		_update_facing_column(input_vector, live)
	elif live and not walking and _door_pose < 0 and not _idle_world_heading.is_zero_approx():
		# Standing keeps its world heading while the camera orbits around it.
		_update_facing_column(EightWayFacing.screen_direction(_idle_world_heading, get_viewport().get_camera_3d()), true, false)
	_refresh_equipment()
	if _breathing:
		sprite.scale.y = 1.0
		_breathing = false
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
	sprite.rotation.z = 0.0
	var previous_frame: int = sprite.frame
	if walking:
		if not _door_facing_locked:
			_update_facing_column(input_vector, live)
		if live:
			_advance_walk_phase(move_direction, delta, traveled)
		else:
			_walk_time += delta * PRESENTATION_WALK_FPS
		_idle_time = 0.0
	elif live:
		_settle_walk_phase(delta)
		_idle_time = _idle_time + delta if not _walk_animating else 0.0
	else:
		_walk_time = 0.0
		_walk_animating = false
		_idle_time = 0.0
	sprite.animation = FACING_ANIMATIONS[_facing_column]
	var first: int = _cycle_first_frame()
	var length: int = _cycle_length()
	var standing_still: bool = first > 0 and not walking and not _walk_animating
	sprite.frame = 0 if standing_still else first + posmod(_cycle_frame(), length)
	if live:
		var audible := _footsteps.advance(traveled, is_on_floor(), walking, false)
		var contact: int = sprite.frame - first
		if audible and sprite.frame != previous_frame and not standing_still and (contact == length / 4 or contact == length * 3 / 4):
			GameAudio.play_cue(_footsteps.next_cue(Footsteps.surface_at(get_tree(), global_position)))
		if not walking and not _walk_animating and _idle_time > IDLE_BREATH_DELAY:
			# Scales about the sprite origin, which SpriteGrounding puts at the feet.
			_breathing = true
			sprite.scale.y = 1.0 + IDLE_BREATH_AMPLITUDE * sin((_idle_time - IDLE_BREATH_DELAY) * TAU / IDLE_BREATH_PERIOD)
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
	if not is_zero_approx(_doorstep_offset):
		_doorstep_offset = move_toward(_doorstep_offset, 0.0, DOORSTEP_EASE_SPEED * delta)
		sprite.position.y += _doorstep_offset


func _advance_walk_phase(move_direction: Vector3, delta: float, traveled: float) -> void:
	if not _walk_animating:
		# Resume a stride still settling; otherwise lift the first foot at once.
		if posmod(_cycle_frame(), _cycle_length() / 2) == 0:
			_walk_time = WALK_START_PHASE
		_walk_animating = true
	# Backing away while facing a locked target plays the stride in reverse.
	_walk_direction_sign = 1.0
	if _door_facing_locked and move_direction.dot(_door_facing_target - global_position) < 0.0:
		_walk_direction_sign = -1.0
	if traveled < 0.0005 or delta <= 0.0:
		return
	# One phase unit per half step of ground covered. Atlases measured from a
	# rig carry their own stride, paced no shorter than MIN_CADENCE_STRIDE.
	var step: float = _cadence_stride()
	var fps_scale: float = STEP_LENGTH / step
	var frames: float = clampf(traveled / (step * 0.5), MIN_WALK_FPS * fps_scale * delta, MAX_STEPS_PER_SECOND * 2.0 * delta)
	if _walk_direction_sign < 0.0:
		frames *= BACKSTEP_CADENCE_SCALE
	_walk_time += frames * _walk_direction_sign


func _step_length() -> float:
	var texture := sprite.sprite_frames.get_frame_texture(sprite.animation, 0)
	return float(texture.get_meta("step_length", STEP_LENGTH)) if texture != null else STEP_LENGTH


func _cadence_stride() -> float:
	return maxf(_step_length(), MIN_CADENCE_STRIDE)


func _settle_walk_phase(delta: float) -> void:
	# Finish the stride to the following passing pose, then stand. A dedicated
	# standing pose follows the up pose directly too (the feet are already
	# close); only the wide contact and down poses walk on to passing.
	var half: int = _cycle_length() / 2
	var frame: int = _cycle_frame()
	var into_step: int = posmod(frame, half)
	var near_standing: bool = _cycle_first_frame() > 0 and into_step * 4 <= half
	if _walk_animating and into_step != 0 and not near_standing:
		if delta > 0.0:
			var boundary: float = float(frame + half - into_step) / _cycle_scale() if _walk_direction_sign > 0.0 else float(frame - into_step + 1) / _cycle_scale() - 0.0001
			# Show the passing pose for one tick before the standing pose.
			_walk_time = move_toward(_walk_time, boundary, WALK_SETTLE_FPS * delta)
		return
	_walk_time = 0.0
	_walk_animating = false


## Rigged atlases put a dedicated standing pose ahead of the walk cycle.
func _cycle_first_frame() -> int:
	var texture := sprite.sprite_frames.get_frame_texture(sprite.animation, 0) if sprite.sprite_frames != null else null
	return 1 if texture != null and str(texture.get_meta("pose", "")) == "stand" else 0


func _cycle_length() -> int:
	if sprite.sprite_frames == null or not sprite.sprite_frames.has_animation(sprite.animation):
		return 4
	return maxi(4, sprite.sprite_frames.get_frame_count(sprite.animation) - _cycle_first_frame())


## Cycle frames per four-unit phase step.
func _cycle_scale() -> float:
	return float(_cycle_length()) / 4.0


## Unwrapped cycle frame of the current phase.
func _cycle_frame() -> int:
	return int(floor(_walk_time * _cycle_scale() + 0.00001))


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


func _update_facing_column(input_vector: Vector2, hysteresis: bool = false, remember: bool = true) -> void:
	# Eight equal 45-degree sectors support keyboard and analog input alike.
	# Live motion adds a small hysteresis so boundary headings do not flicker.
	if input_vector.is_zero_approx():
		return
	if hysteresis:
		_facing_column = MovementFacing.column_with_hysteresis(input_vector, _facing_column, FACING_HYSTERESIS_DEGREES)
	else:
		_facing_column = EightWayFacing.direction_index(input_vector)
	if remember:
		_idle_world_heading = _camera_relative_direction(input_vector)


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
	# Carry any momentum along the new heading, then ease in and brake to the mark.
	var initial := Vector3(target.x - global_position.x, 0, target.z - global_position.z)
	var current_speed: float = clampf(Vector3(velocity.x, 0.0, velocity.z).dot(initial.normalized()), 0.0, speed)
	var delta: float = get_physics_process_delta_time()
	for step: int in range(240):
		await get_tree().physics_frame
		var offset := Vector3(target.x - global_position.x, 0, target.z - global_position.z)
		if offset.length() < 0.035:
			reached = true
			break
		delta = get_physics_process_delta_time()
		var direction := offset.normalized()
		current_speed = minf(move_toward(maxf(current_speed, SCRIPTED_START_SPEED), speed, SCRIPTED_ACCELERATION * delta), sqrt(2.0 * SCRIPTED_DECELERATION * offset.length()))
		velocity = direction * minf(current_speed, offset.length() / delta)
		velocity.y = -2.0
		var before := global_position
		# Climb the real low doorstep using sweeps, never teleport through walls.
		var horizontal := direction * minf(current_speed * delta, offset.length())
		var raised := global_transform
		raised.origin.y += 0.34
		var climb := test_move(global_transform, horizontal) and not test_move(global_transform, Vector3.UP * 0.34) and not test_move(raised, horizontal)
		if climb:
			move_and_collide(Vector3.UP * 0.34)
		move_and_slide()
		if climb:
			move_and_collide(Vector3.DOWN * 0.36)
			# The body mounts the step inside one tick; let the art follow over ~0.1 s.
			_doorstep_offset -= global_position.y - before.y
		var traveled := Vector2(global_position.x - before.x, global_position.z - before.z).length()
		_update_sprite(EightWayFacing.screen_direction(direction, get_viewport().get_camera_3d()), direction, delta, traveled)
		if traveled < 0.001:
			break
	velocity = Vector3.ZERO
	# Finish a mid-stride contact pose (at most a few ticks) instead of snapping.
	for settle: int in range(8):
		if not _walk_animating and is_zero_approx(_doorstep_offset):
			break
		await get_tree().physics_frame
		_update_sprite(Vector2.ZERO, Vector3.ZERO, delta, 0.0)
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
	var previous_column: int = _facing_column
	var direction := EightWayFacing.screen_direction(target - global_position, get_viewport().get_camera_3d())
	_update_facing_column(direction)
	var heading := Vector3(target.x - global_position.x, 0.0, target.z - global_position.z)
	if not heading.is_zero_approx():
		_idle_world_heading = heading.normalized()
	# Conversation partners re-aim the hero every frame. A live stride (such as
	# the conversation back-step) renders itself each tick, and a live idle
	# re-derives the column from the heading; the static redraw below would
	# reset the walk phase and the breathing clock, so skip it in those cases.
	if _walk_animating:
		return
	if is_physics_processing() and previous_column == _facing_column and _door_pose < 0:
		return
	_update_sprite(Vector2.ZERO, Vector3.ZERO, 0.0)


## World heading of the last deliberate facing (zero before the first one).
func idle_world_heading() -> Vector3:
	return _idle_world_heading


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
