extends SceneTree
## Isolated facade inspection, not a gameplay screenshot or automatic approval.

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
	(world.get_node("Player") as Node3D).position = Vector3(100, 0, 100)
	world.get_node("Player").set_physics_process(false)
	world.get_node("CameraRig").set_process(false)
	var camera := world.get_node("CameraRig/Camera3D") as Camera3D
	camera.attributes = null
	var map_root := world.get("_map_root") as Node3D
	# This is deliberately a diagnostic isolated view. Normal screenshots and
	# the foreground cutaway regression remain separate acceptance evidence.
	for controller: Node in get_nodes_in_group("foreground_cutaways"):
		controller.set_process(false)
		controller.call("_set_active", false)
	for child: Node in map_root.get_children():
		if child is Node3D and child.name != &"Ground":
			(child as Node3D).hide()
	for id: String in ["house_02", "house_04", "house_06"]:
		var home := Houses.find_home(id)
		var selected: Node3D
		for child: Node in map_root.get_children():
			if child is StaticBody3D and child.has_node("ExteriorDressing") and (child as Node3D).position.is_equal_approx(home.position):
				selected = child as Node3D
		assert(selected != null)
		selected.show()
		for side: int in [-1, 1]:
			camera.global_position = (home.position as Vector3) + Basis(Vector3.UP, float(home.yaw)) * Vector3(6.0 * side, 3.4, 6.0 * side)
			camera.look_at((home.position as Vector3) + Vector3.UP * 1.45)
			for frame: int in range(8):
				await process_frame
			await RenderingServer.frame_post_draw
			var path := output.path_join("%s-%s-%s.png" % [RenderingServer.get_current_rendering_method(), id, "front" if side < 0 else "rear"])
			var error := root.get_texture().get_image().save_png(path)
			assert(error == OK)
			print("HOUSE_FACADE_CAPTURE ", path)
		selected.hide()
	world.free()
	for singleton: String in ["GameAudio", "GameMusic", "GameAmbience"]:
		root.get_node(singleton).call("stop_all")
	await create_timer(0.25).timeout
	print("HOUSE_FACADE_CAPTURE_PASS three_archetypes two_sides isolated_inspection")
	quit()
