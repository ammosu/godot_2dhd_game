extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var state: Node = root.get_node("GameState")
	state.reset_new_game(false)
	state.flags.intro_seen = true
	var world: Node3D = load("res://scenes/main.tscn").instantiate()
	root.add_child(world)
	world.set("_test_mode", true)
	var player: Node3D = world.get_node("Player")
	player.set_physics_process(false)
	var rig: Node3D = world.get_node("CameraRig")
	rig.set_process(false)
	for fps: int in [30, 60, 120]:
		rig.call("snap_to_target")
		# Simulate a second of walking, then release movement and rotate.
		for frame: int in range(fps):
			player.position.x += 3.0 / fps
			rig.call("_process", 1.0 / fps)
		rig.set("_target_yaw", float(rig.get("_target_yaw")) + PI / 4.0)
		for frame: int in range(fps * 2):
			rig.call("_process", 1.0 / fps)
		if rig.global_position != player.global_position or not is_equal_approx(rig.rotation.y, float(rig.get("_target_yaw"))):
			push_error("Camera must reach an exact resting transform at %d FPS" % fps)
			quit(1)
			return
		var resting: Transform3D = rig.global_transform
		for frame: int in range(fps):
			rig.call("_process", 1.0 / fps)
		if rig.global_transform != resting:
			push_error("Resting camera must not drift")
			quit(1)
			return
	world.free()
	for singleton: String in ["GameAudio", "GameMusic", "GameAmbience"]:
		root.get_node(singleton).call("stop_all")
	await create_timer(0.25).timeout
	print("CAMERA_SETTLE_TEST_PASS walking rotation rest 30_60_120fps")
	quit()
