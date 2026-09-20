extends SceneTree
const Footsteps = preload("res://scripts/gameplay/footsteps.gd")
var failures: int = 0
var heard: Array[StringName] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)


func _frames(count: int) -> void:
	for frame: int in range(count):
		await physics_frame
		await process_frame


func _run() -> void:
	var cadence := Footsteps.new()
	_check(not cadence.advance(1.0, true, true, false), "Step before stride")
	_check(cadence.advance(0.1, true, true, false), "Stride failed to emit")
	_check(cadence.next_cue(&"dirt") == &"step_dirt_1" and cadence.next_cue(&"dirt") == &"step_dirt_2", "Variants do not alternate")
	for blocked: Array in [[0.0, true, true, false], [0.5, false, true, false], [0.5, true, false, false], [0.5, true, true, true], [20.0, true, true, false]]:
		_check(not cadence.advance(blocked[0], blocked[1], blocked[2], blocked[3]), "Blocked movement emitted footstep")
		_check(not cadence.advance(0.1, true, true, false), "Blocked cadence did not reset")
	var state := root.get_node("GameState")
	state.call("reset_new_game", false)
	state.get("flags")["intro_seen"] = true
	var world := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(world)
	var player := world.get_node("Player") as CharacterBody3D
	player.set_physics_process(false)
	await _frames(3)
	_check(Footsteps.surface_at(self, Vector3(0, 0.01, 7.5)) == &"stone", "Non-colliding north road not stone")
	_check(Footsteps.surface_at(self, Vector3(9, 0.01, 4.6)) == &"stone", "Market road not stone")
	_check(Footsteps.surface_at(self, Vector3(8, 0.01, 8)) == &"dirt", "Meadow not dirt")
	_check(Footsteps.surface_at(self, Vector3(2, 0.01, 1)) == &"stone", "Plaza not stone")
	world.call("_load_map", "ruins", "from_village")
	await _frames(3)
	_check(Footsteps.surface_at(self, Vector3(0, 0.01, 10)) == &"stone", "Ruin path not stone")
	_check(Footsteps.surface_at(self, Vector3(5, 0.04, -5)) == &"stone", "Ruin court not stone")
	_check(Footsteps.surface_at(self, Vector3(13, 0.01, 8)) == &"dirt", "Ruin soil not dirt")
	world.call("_load_map", "house_02", "entry")
	await _frames(3)
	_check(Footsteps.surface_at(self, Vector3(0, 0.024, 0)) == &"wood", "Indoor floor not wood or stale plaza overrides it")
	_check(Footsteps.surface_at(self, Vector3(0, 0.024, 3)) == &"stone", "Stone threshold not stone")
	# Real physics input: central clear lane, then walk into the north wall.
	root.get_node("GameAudio").connect("cue_played", func(cue: StringName) -> void:
		if String(cue).begins_with("step_"):
			heard.append(cue)
			if DisplayServer.get_name() != "headless":
				var audio := root.get_node("GameAudio")
				_check(audio.get_children().any(func(voice: Node) -> bool: return (voice as AudioStreamPlayer).playing and (voice as AudioStreamPlayer).stream == audio.get("CUES")[cue]), "Footstep voice did not start"))
	player.position = Vector3(0, 0.15, 1.8)
	player.velocity = Vector3.ZERO
	# Remove camera orbit from this collision/cadence test's input coordinates.
	world.get_node("CameraRig/Camera3D").set("current", false)
	player.set_physics_process(true)
	await _frames(8)
	_check(heard.is_empty(), "Stationary player emitted steps")
	Input.action_press("move_forward")
	await _frames(35)
	_check(heard.size() >= 1 and heard.size() <= 3, "Walking cadence missing or flooding")
	_check(heard.all(func(cue: StringName) -> bool: return String(cue).begins_with("step_wood_")), "Indoor live movement selected wrong material")
	var before_teleport := heard.size()
	player.position = Vector3(0, 0.1, 2.5)
	await _frames(3)
	_check(heard.size() == before_teleport, "Teleport retained partial stride")
	state.call("set_mode", 1)
	var count := heard.size()
	await _frames(25)
	_check(heard.size() == count, "Dialogue-locked movement emitted steps")
	state.call("set_mode", 0)
	await _frames(110)
	count = heard.size()
	await _frames(30)
	_check(heard.size() == count, "Pushing against wall emitted steps")
	Input.action_release("move_forward")
	await _frames(10)
	_check(heard.size() == count, "Stopping emitted steps")
	world.free()
	_check(get_nodes_in_group(Footsteps.GROUP).is_empty(), "Surface registrations leaked after map cleanup")
	for singleton: String in ["GameAudio", "GameMusic", "GameAmbience"]:
		root.get_node(singleton).call("stop_all")
	await create_timer(0.25).timeout
	if failures == 0:
		print("FOOTSTEPS_TEST_PASS materials overlays maps cadence variants walking idle wall dialogue teleport cleanup")
	quit(0 if failures == 0 else 1)
