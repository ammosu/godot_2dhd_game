extends SceneTree
## Evidence capture only: successful export does not imply visual acceptance.

const Houses = preload("res://scripts/gameplay/house_catalog.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var output: String = ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="):
			output = argument.trim_prefix("--capture-dir=")
	if DisplayServer.get_name() == "headless" or not DirAccess.dir_exists_absolute(output):
		push_error("Requires actual renderer and existing --capture-dir directory")
		quit(1)
		return
	root.get_node("GameState").get("flags")["intro_seen"] = true
	var world := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(world)
	var player := world.get_node("Player") as CharacterBody3D
	player.set_physics_process(false)
	var camera := world.get_node("CameraRig")
	var renderer: String = RenderingServer.get_current_rendering_method()
	for home: Dictionary in Houses.HOMES:
		world.call("_load_map", str(home.id), "default")
		var inspection: bool = "--inspect-furniture" in OS.get_cmdline_user_args()
		if inspection:
			player.position = Vector3(-2.5, 0.024, 1.2)
		var angles: Array[int] = [45, 225]
		if inspection:
			angles.assign([135, 315])
		for yaw: int in angles:
			camera.set("_target_yaw", deg_to_rad(float(yaw)))
			for frame: int in range(60):
				await process_frame
			await RenderingServer.frame_post_draw
			var path: String = output.path_join("%s-%s-%d.png" % [renderer, home.id, yaw])
			var error: Error = root.get_texture().get_image().save_png(path)
			if error != OK:
				push_error("Capture failed: " + error_string(error))
				quit(1)
				return
			print("HOUSE_VISUAL_CAPTURE ", path)
	world.free()
	for singleton: String in ["GameAudio", "GameMusic", "GameAmbience"]:
		root.get_node(singleton).call("stop_all")
	await create_timer(0.25).timeout
	print("HOUSE_VISUAL_CAPTURE_PASS eight_homes two_angles screenshots_only")
	quit()
