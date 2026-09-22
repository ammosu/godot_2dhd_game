extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var world := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	world.set("_test_mode", true)
	root.add_child(world)
	current_scene = world
	world.call("_load_map", "east_road", "default")
	var player := world.get_node("Player") as CharacterBody3D
	player.set_physics_process(false)
	await physics_frame
	await physics_frame
	for direction: float in [-1, 1]:
		player.position = Vector3(0, 0.1, -5 - direction * 4.1)
		var maximum_height: float = 0.0
		for frame: int in range(160):
			await physics_frame
			player.velocity = Vector3(0, -2.5, direction * 4.2)
			player.move_and_slide()
			maximum_height = maxf(maximum_height, player.position.y)
			if direction * (player.position.z + 5) > 3.9:
				break
		assert(direction * (player.position.z + 5) > 3.9, "Player must cross the bridge in both directions")
		assert(maximum_height > 0.39 and maximum_height < 0.48, "Player must walk on the raised deck")
	player.position = Vector3(0, 0.43, -5)
	assert(player.test_move(player.global_transform, Vector3(2, 0, 0)), "Rail must stop sideways movement")
	assert(preload("res://scripts/gameplay/footsteps.gd").surface_at(self, player.position) == &"wood")
	if DisplayServer.get_name() != "headless":
		world.get_node("CameraRig").call("snap_to_target")
		for frame: int in range(20):
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/creek-bridge.png")
	world.free()
	print("CREEK_BRIDGE_TEST_PASS bidirectional_crossing raised_deck rails wood_steps")
	quit()
