extends SceneTree
## Visual inspection utility; uses transient preview state only.
func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var state := root.get_node("GameState")
	state.get("flags")["intro_seen"] = true
	var world := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(world)
	world.set("_test_mode", true)
	world.call("_load_map", "starbay", "default")
	world.get_node("CameraRig").set_process(false)
	var camera := root.get_camera_3d()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 9.5
	for index: int in [0, 5, 12]:
		var house: Node3D = world.get("_map_root").get_node("CityHouse%d" % index)
		world.get_node("Player").position = house.to_global(Vector3(0, 0.1, -3.3))
		camera.global_position = house.to_global(Vector3(6, 5, -8))
		camera.look_at(house.to_global(Vector3(0, 1.3, 0)))
		for frame: int in range(15):
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/japanese-house-%d-%s.png" % [index, RenderingServer.get_current_rendering_method()])
	world.free()
	for singleton: String in ["GameAudio", "GameMusic", "GameAmbience"]:
		root.get_node(singleton).call("stop_all")
	await create_timer(0.25).timeout
	print("JAPANESE_HOUSE_CAPTURE_PASS")
	quit()
