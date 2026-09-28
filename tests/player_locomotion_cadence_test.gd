extends SceneTree
## Player locomotion core: distance-driven walk cadence, contact-frame footsteps,
## analog speed, velocity-driven stop that finishes its stride, eased scripted
## and door walks, reverse back-steps, idle facing memory across camera orbit,
## sector hysteresis and foot-anchored idle breathing. No save writes.

const MovementFacing = preload("res://scripts/gameplay/movement_facing.gd")
const EightWayFacing = preload("res://scripts/gameplay/eight_way_facing.gd")
var _failures: int = 0
var _heard: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)


func _physics(count: int) -> void:
	for frame: int in range(count):
		await physics_frame


func _planar(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


func _run() -> void:
	var state := root.get_node("GameState")
	state.call("reset_new_game", false)
	var floor := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(200, 1, 200)
	collision.shape = shape
	collision.position.y = -0.5
	floor.add_child(collision)
	root.add_child(floor)
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.position = Vector3(0, 4, 6)
	camera.look_at(Vector3.ZERO)
	camera.current = true
	var player := (load("res://scenes/player.tscn") as PackedScene).instantiate() as CharacterBody3D
	root.add_child(player)
	var sprite := player.get_node("Sprite3D") as AnimatedSprite3D
	root.get_node("GameAudio").connect("cue_played", func(cue: StringName) -> void:
		if String(cue).begins_with("step_"):
			_heard += 1)
	state.call("set_mode", 0)
	await _check_cadence(player, sprite, camera)
	await _check_analog(player)
	await _check_stop(player, sprite)
	await _check_scripted_ease(player, state)
	await _check_backstep(player)
	await _check_idle_facing(player, sprite, camera)
	_check_hysteresis()
	await _check_breath(player, sprite)
	player.queue_free()
	floor.queue_free()
	camera.queue_free()
	await process_frame
	for singleton: String in ["GameAudio", "GameMusic", "GameAmbience"]:
		root.get_node(singleton).call("stop_all")
	await create_timer(0.25).timeout
	if _failures == 0:
		print("PLAYER_LOCOMOTION_CADENCE_TEST_PASS distance_cadence contact_footsteps analog stop_settle scripted_ease backstep idle_orbit hysteresis breath")
	quit(0 if _failures == 0 else 1)


func _reset(player: CharacterBody3D, at: Vector3 = Vector3(0, 0.03, 0)) -> void:
	player.set_physics_process(false)
	player.position = at
	player.velocity = Vector3.ZERO
	player.set_physics_process(true)
	await _physics(6)


func _check_cadence(player: CharacterBody3D, sprite: AnimatedSprite3D, camera: Camera3D) -> void:
	# The atlas's own stride (STEP_LENGTH unless a rigged atlas measured one).
	var step_length: float = player.call("_step_length")
	var rates: Array[float] = []
	for speed: float in [1.6, 2.8, 4.2]:
		await _reset(player, Vector3(-60, 0.03, 0))
		player.set("move_speed", speed)
		Input.action_press(&"move_right")
		await _physics(30)
		var start_phase: float = player.get("_walk_time")
		var start := player.position
		var contacts: int = 0
		var heard_before := _heard
		var last_frame := sprite.frame
		for frame: int in range(90):
			await _physics(1)
			if sprite.frame != last_frame and sprite.frame in [1, 3]:
				contacts += 1
			last_frame = sprite.frame
		Input.action_release(&"move_right")
		var distance := _planar(player.position, start)
		var frames_per_metre := (float(player.get("_walk_time")) - start_phase) / distance
		rates.append(frames_per_metre)
		_check(absf(distance - speed * 1.5) < 0.1, "Steady walk did not reach %.1f m/s" % speed)
		_check(absf(frames_per_metre - 2.0 / step_length) < 0.1 * (2.0 / step_length), "Cadence at %.1f m/s is %.2f frames/m, expected %.2f" % [speed, frames_per_metre, 2.0 / step_length])
		_check(contacts >= 2 and _heard - heard_before == contacts, "Footsteps (%d) must match contact frames (%d) at %.1f m/s" % [_heard - heard_before, contacts, speed])
		await _physics(30)
	for rate: float in rates:
		_check(absf(rate - rates[0]) <= 0.1 * rates[0], "Frames per metre must not depend on speed: %s" % [rates])
	player.set("move_speed", 4.2)


func _check_analog(player: CharacterBody3D) -> void:
	await _reset(player, Vector3(-60, 0.03, 6))
	Input.action_press(&"move_right", 0.55)
	await _physics(40)
	var expected := Input.get_vector("move_left", "move_right", "move_forward", "move_back").length() * float(player.get("move_speed"))
	var speed := Vector2(player.velocity.x, player.velocity.z).length()
	Input.action_release(&"move_right")
	_check(expected < float(player.get("move_speed")) * 0.8, "Half tilt should request a slower walk")
	_check(absf(speed - expected) < 0.05, "Analog tilt must scale walking speed: %.2f vs %.2f" % [speed, expected])
	await _physics(30)


func _check_stop(player: CharacterBody3D, sprite: AnimatedSprite3D) -> void:
	for hold: int in range(24, 40, 3):
		await _reset(player, Vector3(-60, 0.03, 12))
		Input.action_press(&"move_right")
		await _physics(hold)
		Input.action_release(&"move_right")
		var last := sprite.frame
		for frame: int in range(24):
			await _physics(1)
			# A standing pose may only follow a passing pose or the end of a stride.
			if sprite.frame == 0 and last != 0:
				_check(last in [2, 3], "Stop snapped from contact %d to standing" % last)
			last = sprite.frame
		_check(sprite.frame == 0, "Stop did not settle to the standing pose")


func _check_scripted_ease(player: CharacterBody3D, state: Node) -> void:
	await _reset(player, Vector3(0, 0.03, 20))
	var route := PackedVector3Array([Vector3(3, 0.03, 20), Vector3(3, 0.03, 22)])
	state.call("set_mode", 7)
	player.call("play_scripted_walk", route, 1.6)
	var speeds: Array[float] = []
	for frame: int in range(360):
		await _physics(1)
		speeds.append(Vector2(player.velocity.x, player.velocity.z).length())
		if not player.call("is_scripted_walking"):
			break
	_check(not player.call("is_scripted_walking"), "Scripted walk never arrived")
	_check(_planar(player.position, route[1]) < 0.1, "Scripted walk missed its mark")
	_check(speeds[0] < 0.5, "Scripted walk started at full speed")
	_check(speeds.max() > 1.55 and speeds.max() <= 1.6001, "Scripted walk never reached its pace")
	var last_moving: float = 0.0
	for speed: float in speeds:
		if speed > 0.0:
			last_moving = speed
	_check(last_moving < 0.8, "Scripted walk stopped dead from %.2f m/s" % last_moving)
	for index: int in range(1, speeds.size()):
		if speeds[index] > 0.0:
			_check(absf(speeds[index] - speeds[index - 1]) < 0.2, "Scripted walk speed jumped at tick %d" % index)
	state.call("set_mode", 0)
	await _physics(10)


func _check_backstep(player: CharacterBody3D) -> void:
	await _reset(player, Vector3(0, 0.03, 30))
	player.call("lock_door_facing", Vector3(0, 0.03, 28))
	var phases: Array[float] = []
	var sampler := func() -> void:
		phases.append(float(player.get("_walk_time")))
	physics_frame.connect(sampler)
	var reached: bool = await player.call("walk_to_door_point", Vector3(0, 0.03, 31.5), 1.6)
	physics_frame.disconnect(sampler)
	player.call("release_door_facing")
	_check(reached, "Back-step did not reach its point")
	var lowest: float = 0.0
	for phase: float in phases:
		lowest = minf(lowest, phase)
	_check(lowest < -1.0, "Backing away while facing forward must play the stride in reverse")
	await _physics(10)


func _check_idle_facing(player: CharacterBody3D, sprite: AnimatedSprite3D, camera: Camera3D) -> void:
	await _reset(player, Vector3(0, 0.03, 40))
	camera.position = player.position + Vector3(0, 4, 6)
	camera.look_at(player.position)
	var target := player.position + Vector3(3, 0, 0)
	player.call("face_world_position", target)
	await _physics(3)
	_check(sprite.animation == &"right", "Setup should face screen-right")
	_check(player.call("is_facing_direction", target - player.position), "Setup lost its target")
	# Orbit the camera a quarter turn: the hero keeps facing the same world target.
	camera.position = player.position + Basis(Vector3.UP, deg_to_rad(90.0)) * Vector3(0, 4, 6)
	camera.look_at(player.position)
	await _physics(3)
	_check(sprite.animation != &"right", "Standing hero turned with the camera")
	_check(player.call("is_facing_direction", target - player.position), "Standing hero lost world heading after orbit")
	camera.position = Vector3(0, 4, 6)
	camera.look_at(Vector3.ZERO)


func _check_hysteresis() -> void:
	var right: int = EightWayFacing.direction_index(Vector2.RIGHT)
	var down_right: int = EightWayFacing.direction_index(Vector2(1, 1))
	_check(MovementFacing.column_with_hysteresis(Vector2.RIGHT.rotated(deg_to_rad(25.0)), right, 28.0) == right, "Boundary heading flickered away from current sector")
	_check(MovementFacing.column_with_hysteresis(Vector2.RIGHT.rotated(deg_to_rad(31.0)), right, 28.0) == down_right, "Clear turn was held back")
	_check(MovementFacing.column_with_hysteresis(Vector2.RIGHT.rotated(deg_to_rad(20.0)), down_right, 28.0) == down_right, "Returning heading flickered at the boundary")
	_check(MovementFacing.column_with_hysteresis(Vector2.LEFT, right, 28.0) == EightWayFacing.direction_index(Vector2.LEFT), "Reversal must turn immediately")


func _check_breath(player: CharacterBody3D, sprite: AnimatedSprite3D) -> void:
	await _reset(player, Vector3(0, 0.03, 50))
	await _physics(20)
	var offset := sprite.offset
	var lowest: float = 1.0
	var highest: float = 1.0
	for frame: int in range(120):
		await _physics(1)
		lowest = minf(lowest, sprite.scale.y)
		highest = maxf(highest, sprite.scale.y)
		_check(is_equal_approx(sprite.position.y, 0.012) and sprite.offset == offset, "Breathing moved the feet")
	_check(highest > 1.003 and lowest >= 0.99 and highest <= 1.0061, "Idle breath missing or too strong: %.4f..%.4f" % [lowest, highest])
	Input.action_press(&"move_right")
	await _physics(4)
	_check(is_equal_approx(sprite.scale.y, 1.0), "Walking kept the breathing scale")
	Input.action_release(&"move_right")
	await _physics(30)
