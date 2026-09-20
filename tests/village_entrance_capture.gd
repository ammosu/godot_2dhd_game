extends SceneTree
## Real village at each return spawn; leaves cutaways, scenery and HUD active.

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
	var rig := world.get_node("CameraRig") as Node3D
	player.set_physics_process(false)
	var count: int = 0
	for home: Dictionary in Houses.HOMES:
		player.position = Houses.return_position(home.id)
		for angle: int in [45, 225]:
			rig.set("_target_yaw", deg_to_rad(float(angle)))
			rig.call("snap_to_target")
			# Allow cutaway hysteresis and real scene presentation to settle.
			await create_timer(0.35).timeout
			await RenderingServer.frame_post_draw
			var path := output.path_join("%s-%s-%d.png" % [RenderingServer.get_current_rendering_method(), home.id, angle])
			var error := root.get_texture().get_image().save_png(path)
			if error != OK:
				push_error("Capture failed: %s (%d)" % [path, error])
				quit(1)
				return
			count += 1
			print("VILLAGE_ENTRANCE_CAPTURE ", path)
	world.free()
	for singleton: String in ["GameAudio", "GameMusic", "GameAmbience"]:
		root.get_node(singleton).call("stop_all")
	await create_timer(0.25).timeout
	print("VILLAGE_ENTRANCE_CAPTURE_PASS ", count, " views; manual review required")
	quit()
