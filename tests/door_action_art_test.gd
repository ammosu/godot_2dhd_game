extends SceneTree
## Real actor rendering plus source/grounding/equipment and contact-order checks.
const Art = preload("res://scripts/gameplay/door_action_art.gd")
var _failures: int = 0
var _capture: String = ""


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="):
			_capture = argument.trim_prefix("--capture-dir=")
	var state := root.get_node("GameState")
	state.get("flags")["intro_seen"] = true
	for armor: String in ["", "moonward_cloak"]:
		for weapon: String in ["", "moonsteel_saber"]:
			var frames := Art.frames({"armor": armor, "weapon": weapon})
			_check(frames.get_animation_names().size() == 8, "All eight directions need hand action art")
			for direction: StringName in frames.get_animation_names():
				for pose: int in range(2):
					var texture := frames.get_frame_texture(direction, pose)
					_check(float(texture.get_meta("body_height")) > 240, "Grounded full-body pose must not be clipped")
					_check(float(texture.get_meta("ground_y")) < texture.get_height(), "Boots need transparent lower gutter")
	var world := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(world)
	world.call("_load_map", "village", "from_house_01")
	await physics_frame
	await physics_frame
	var player := world.get_node("Player") as CharacterBody3D
	var camera := root.get_camera_3d()
	var rig := world.get_node("CameraRig")
	var normal_camera := camera.global_transform
	if not _capture.is_empty():
		rig.set_process(false)
		camera.attributes = null

	var house: Node3D
	for node: Node in world.get("_map_root").get_children():
		if node.get_meta("house_id", "") == "house_01":
			house = node as Node3D
	if not _capture.is_empty():
		camera.global_position = house.to_global(Vector3(3.4, 2.8, -6.8))
		camera.look_at(house.to_global(Vector3(0, 0.9, -2.2)))
	var hinge := house.get_node("ArchitecturalDetails/DoorHinge") as Node3D
	world.call("_handle_interaction", "enter_house_01")
	await _wait_for_pose(player, 0)
	_check(is_zero_approx(hinge.rotation.y), "Door must stay closed during raised elbow pose")
	await _snapshot("01-reach")
	await _wait_for_pose(player, 1)
	_check(is_zero_approx(hinge.rotation.y), "Door must wait for hand contact")
	var sprite := player.get_node("Sprite3D") as AnimatedSprite3D
	_check(sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame).get_meta("door_pose") == "contact", "Runtime must display contact texture, not skew walking art")
	_check(sprite.scale.is_equal_approx(Vector3.ONE), "Articulated arm must not stretch whole body")
	_check(player.global_position.y > 0.25, "Actor must stand on doorstep instead of sinking into it")
	await _snapshot("02-contact")
	if not _capture.is_empty():
		var close_camera := camera.global_transform
		camera.global_transform = normal_camera
		await _snapshot("02-normal-view")
		camera.global_transform = close_camera
	await create_timer(0.23).timeout
	await _snapshot("03-push")
	while state.call("is_input_locked"):
		await process_frame
	_check(player.get("_door_pose") == -1, "Door action must restore walking frames")
	world.free()
	for name: String in ["GameAudio", "GameMusic", "GameAmbience"]:
		root.get_node(name).call("stop_all")
	await process_frame
	if _failures == 0:
		print("DOOR_ACTION_ART_TEST_PASS eight_directions four_loadouts grounded contact_before_swing restore")
	quit(0 if _failures == 0 else 1)


func _wait_for_pose(player: Node, pose: int) -> void:
	var deadline := Time.get_ticks_msec() + 10000
	while player.get("_door_pose") != pose and Time.get_ticks_msec() < deadline:
		await process_frame
	_check(player.get("_door_pose") == pose, "Reach pose timed out")


func _snapshot(label: String) -> void:
	if _capture.is_empty() or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(_capture.path_join(label + ".png"))


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)
