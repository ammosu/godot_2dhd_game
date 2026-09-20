extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var state := root.get_node("GameState")
	state.get("flags")["intro_seen"] = true
	var world := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(world)
	world.set("_test_mode", true)
	var road := world.get("_map_root").get_node("AwakenedRoad") as MeshInstance3D
	assert(not road.visible)
	state.call("start_quest")
	state.call("defeat_guardian")
	assert(not road.visible)
	state.call("complete_quest")
	assert(road.visible)
	assert(road.mesh.get_aabb().position.z > -13.1)
	assert(road.find_children("*", "CollisionObject3D").is_empty())
	var old: WeakRef = weakref(road)
	world.call("_load_map", "ruins", "from_village")
	assert(old.get_ref() == null)
	world.call("_load_map", "village", "from_ruins")
	assert(world.get("_map_root").get_node("AwakenedRoad").visible)
	if "--road-capture" in OS.get_cmdline_user_args():
		world.get_node("Player").position = Vector3(0, 0.1, 3.5)
		world.get_node("CameraRig").call("snap_to_target")
		for frame: int in range(45):
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/wanderlight-road-" + RenderingServer.get_current_rendering_method() + ".png")
	world.free()
	for singleton: String in ["GameAudio", "GameMusic", "GameAmbience"]:
		root.get_node(singleton).call("stop_all")
	await create_timer(0.25).timeout
	print("AWAKENED_ROAD_TEST_PASS quest_visibility map_cleanup restore")
	quit()
