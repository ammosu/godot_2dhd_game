extends SceneTree
## Requested camera shots: blend in, priority, hand-off, timed expiry (also under
## slow motion), yaw offsets, map-reset clearing and an exact return to rest.

const FPS: int = 60

var _failed: bool = false


func _initialize() -> void:
	_run.call_deferred()


func _check(condition: bool, message: String) -> void:
	if not condition and not _failed:
		_failed = true
		push_error(message)


func _step(rig: Node3D, seconds: float, time_scale: float = 1.0) -> void:
	for frame: int in range(roundi(seconds * FPS)):
		rig.call("_process", time_scale / FPS)


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
	var camera: Camera3D = rig.get_node("Camera3D")
	rig.call("snap_to_target")
	_step(rig, 2.0)
	var rest_rig: Transform3D = rig.global_transform
	var rest_camera: Transform3D = camera.global_transform
	var rest_distance: float = camera.position.length()

	# Blend in toward a fixed focus and a closer lens.
	var focus: Vector3 = player.global_position + Vector3(3.0, 0.0, 0.0)
	rig.call("request_shot", &"close", {"focus": focus, "distance": 6.0, "blend_in": 0.3}, 0, 0.0)
	_step(rig, 0.1)
	var partial: float = float(rig.call("shot_weight"))
	_check(partial > 0.0 and partial < 1.0, "Shot must blend in, not pop (weight %f)" % partial)
	_step(rig, 1.5)
	_check(is_equal_approx(float(rig.call("shot_weight")), 1.0), "Shot must reach full weight")
	_check(rig.global_position.distance_to(focus) < 0.05, "Shot must frame its focus")
	_check(absf(camera.position.length() - 6.0 * Vector2(0.56, 0.83).length()) < 0.05, "Shot must use its distance")

	# A higher priority shot wins; releasing it hands back to the lower one.
	rig.call("request_shot", &"boss", {"subject": player, "distance_scale": 1.5}, 5, 0.0)
	rig.call("request_shot", &"low", {"focus": focus}, 1, 0.0)
	_check(rig.call("active_shot_id") == &"boss", "Highest priority shot must win")
	_step(rig, 1.0)
	_check(rig.global_position.distance_to(player.global_position) < 0.05, "Subject shot must follow its subject")
	rig.call("release_shot", &"boss")
	_check(rig.call("active_shot_id") == &"low", "Release must hand off to the next shot")
	_check(is_equal_approx(float(rig.call("shot_weight")), 1.0), "Hand-off between shots must not dip to the base frame")
	rig.call("release_shot", &"low")
	rig.call("release_shot", &"close")
	_step(rig, 2.0)
	_check(is_zero_approx(float(rig.call("shot_weight"))), "Released shots must fade out")
	_check(rig.global_transform.is_equal_approx(rest_rig) and camera.global_transform.is_equal_approx(rest_camera), "Rig must return exactly to rest")

	# Timed shots expire on real time even in slow motion.
	Engine.time_scale = 0.25
	rig.call("request_shot", &"kill", {"distance_scale": 0.7, "blend_in": 0.1, "blend_out": 0.2}, 0, 0.5)
	_step(rig, 0.45, 0.25)
	_check(rig.call("has_shot", &"kill"), "Unscaled shot must still run before its duration")
	_step(rig, 0.1, 0.25)
	_check(not rig.call("has_shot", &"kill"), "Unscaled shot must expire on real time")
	rig.call("request_shot", &"scaled", {"distance_scale": 0.7}, 0, 0.5, false)
	_step(rig, 0.6, 0.25)
	_check(rig.call("has_shot", &"scaled"), "Scaled shot must follow game time")
	Engine.time_scale = 1.0
	_step(rig, 0.6)
	_check(not rig.call("has_shot", &"scaled"), "Scaled shot must expire on game time")
	_step(rig, 2.0)
	_check(rig.global_transform.is_equal_approx(rest_rig), "Rig must rest after timed shots")

	# Yaw offsets add to the player's chosen heading and give it back afterwards.
	var yaw: float = float(rig.get("_target_yaw"))
	rig.call("request_shot", &"lean", {"yaw_offset": 0.4}, 0, 0.0)
	_step(rig, 2.0)
	_check(absf(angle_difference(rig.rotation.y, yaw + 0.4)) < 0.001, "Yaw offset must rotate relative to the heading")
	rig.call("release_shot", &"lean")
	_step(rig, 2.0)
	_check(absf(angle_difference(rig.rotation.y, yaw)) < 0.0001, "Yaw must return to the heading")

	# Map resets drop every request at once.
	rig.call("request_shot", &"stale", {"distance": 4.0}, 0, 0.0)
	_step(rig, 1.0)
	rig.call("snap_to_target")
	_check(not rig.call("has_shot", &"stale") and is_zero_approx(float(rig.call("shot_weight"))), "snap_to_target must clear shots")
	_check(absf(camera.position.length() - rest_distance) < 0.001, "Snap must restore the exploration distance")

	world.free()
	for singleton: String in ["GameAudio", "GameMusic", "GameAmbience"]:
		root.get_node(singleton).call("stop_all")
	await create_timer(0.25).timeout
	if _failed:
		quit(1)
		return
	print("CAMERA_SHOT_REQUEST_TEST_PASS blend priority handoff rest unscaled yaw snap")
	quit()
