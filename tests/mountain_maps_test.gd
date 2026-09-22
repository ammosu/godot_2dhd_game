extends SceneTree
const Mountains = preload("res://scripts/gameplay/mountain_maps.gd")
const SAVE := "user://mountain_maps_test.json"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var state := root.get_node("GameState")
	state.call("reset_new_game", false)
	state.get("flags")["intro_seen"] = true
	var world := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(world)
	world.set("_test_mode", true)
	var player: CharacterBody3D = world.get_node("Player")
	world.call("_load_map", "firefly_forest", "from_road")
	world.call("_handle_interaction", "forest_to_mountain")
	await process_frame
	assert(state.get("current_map") == "moss_steps")
	for map_id: String in Mountains.NAMES:
		world.call("_load_map", map_id, "from_base")
		for frame: int in range(24):
			await physics_frame
		var points := Mountains.route(map_id)
		assert(player.is_on_floor())
		# Every point of the real path must have ground at its authored elevation.
		var space: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
		for sample: int in range(points.size() - 1):
			var at := points[sample].lerp(points[sample + 1], 0.5)
			var ray := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 0.3, at - Vector3.UP * 0.3, 1, [player.get_rid()])
			assert(not space.intersect_ray(ray).is_empty(), "ground missing: " + str(at))
		var upper: Vector3 = points[-12]
		assert(player.get("auto_walk").start(upper, Mountains.BOUNDS))
		for frame: int in range(4200):
			await physics_frame
			if not player.get("auto_walk").is_active():
				break
		assert(player.global_position.distance_to(upper) < 0.5, "uphill stalled: " + map_id + str(player.global_position))
		assert(player.global_position.y > 5)
		state.call("remember_player_position", player.global_position)
		assert(state.call("save_game", SAVE, false))
		world.call("_load_map", "village", "default")
		assert(state.call("load_game", SAVE, false))
		await process_frame
		assert(state.get("current_map") == map_id)
		assert(player.global_position.distance_to(upper) < 0.5)
		if "--capture" in OS.get_cmdline_user_args():
			player.position = points[65] + Vector3.UP * 0.1
			world.get_node("CameraRig").set("_distance", 20.0)
			world.get_node("CameraRig").call("snap_to_target")
			for frame: int in range(12):
				await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("/tmp/" + map_id + ".png")
			player.position = upper + Vector3.UP * 0.1
		for frame: int in range(24):
			await physics_frame
		assert(player.get("auto_walk").start(points[9], Mountains.BOUNDS))
		for frame: int in range(4200):
			await physics_frame
			if not player.get("auto_walk").is_active():
				break
		assert(player.global_position.distance_to(points[9]) < 0.5, "downhill stalled: " + map_id)
		print("MOUNTAIN_WALK_PASS ", map_id)
	# Walk through all six thresholds, proving arrival positions do not bounce back.
	for entry: Array in [["moss_steps", "from_peak", "mountain_to_gorge", "wind_gorge"], ["wind_gorge", "from_peak", "gorge_to_highland", "moon_highland"], ["moon_highland", "from_base", "highland_to_gorge", "wind_gorge"], ["wind_gorge", "from_base", "gorge_to_steps", "moss_steps"], ["moss_steps", "from_base", "mountain_to_forest", "firefly_forest"]]:
		world.call("_load_map", entry[0], entry[1])
		for frame: int in range(5):
			await physics_frame
		var exit_node: Node3D = world.get("_map_root").get_node(entry[2])
		assert(player.get("auto_walk").start(exit_node.position, Mountains.BOUNDS))
		for frame: int in range(600):
			await physics_frame
			if state.get("current_map") == entry[3]:
				break
		assert(state.get("current_map") == entry[3], "exit failed: " + entry[2])
		for frame: int in range(20):
			await physics_frame
		assert(state.get("current_map") == entry[3], "arrival bounced: " + entry[2] + " actual " + str(state.get("current_map")) + " at " + str(player.position))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	world.free()
	for singleton: String in ["GameAudio", "GameMusic", "GameAmbience"]:
		root.get_node(singleton).call("stop_all")
	await create_timer(0.25).timeout
	print("MOUNTAIN_MAPS_TEST_PASS ground uphill downhill save walking_exits")
	quit()
