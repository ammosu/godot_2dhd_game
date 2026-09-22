extends SceneTree

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var state := root.get_node("GameState")
	state.reset_new_game(false)
	state.flags.intro_seen = true
	var world: Node3D = load("res://scenes/main.tscn").instantiate()
	root.add_child(world)
	world.set("_test_mode", true)
	world.call("_load_map", "east_road", "from_village")
	var field: Node3D = world.get("_map_root").get_node("FieldCombat")
	while not field.ready_for_combat:
		await physics_frame
	field.set_physics_process(false)
	for title: String in ["LayeredMossCliff", "WornStoneTreads", "BrokenTurfEdge"]:
		var mesh: ArrayMesh = field.get_node(title).mesh
		assert(mesh.get_surface_count() == 1, "Terrain surface missing: " + title)
		assert(mesh.surface_get_array_len(0) > 100, "Terrain geometry missing: " + title)
	var player: Node3D = world.get_node("Player")
	player.set_physics_process(false)
	player.position = Vector3(3.5, 0.9, 10.5)
	world.get_node("CameraRig").set("_distance", 15.0)
	world.get_node("CameraRig").set("_target_yaw", deg_to_rad(-35.0))
	world.get_node("CameraRig").call("snap_to_target")
	for enemy: Dictionary in field.enemies:
		field._advance_enemy(enemy, 0.0)
	field._update_hud()
	for frame: int in range(40):
		await process_frame
	await RenderingServer.frame_post_draw
	var method: String = RenderingServer.get_current_rendering_method()
	root.get_texture().get_image().save_png("/tmp/field-" + method + ".png")
	world.queue_free()
	await process_frame
	await process_frame
	print("FIELD_RENDER_TEST_PASS ", method)
	quit()
