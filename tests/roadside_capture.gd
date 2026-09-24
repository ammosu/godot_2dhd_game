extends SceneTree
## Visual capture plus quest-state regression for the roadside dressing.
func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var state := root.get_node("GameState")
	state.reset_new_game(false)
	state.flags.intro_seen = true
	var world := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(world)
	world.set("_test_mode", true)
	world.call("_load_map", "east_road", "from_village")
	var map: Node3D = world.get("_map_root")
	var sign: Node3D = map.get_node("RoadSign")
	assert(is_equal_approx(sign.rotation.z, -0.45))
	var details := map.get_node("OutdoorLandscape/RoadsideDetails")
	assert(details.get_node("PebbleClusters").multimesh.instance_count > 20)
	assert(details.find_children("FallenWood*", "MeshInstance3D", false, false).size() >= 3)
	var player: Node3D = world.get_node("Player")
	player.set_physics_process(false)
	player.position = Vector3(-4.7, 0.2, 3.4)
	var camera := world.get_node("CameraRig")
	camera.set("_distance", 9.0)
	camera.set("_target_yaw", deg_to_rad(-15))
	camera.call("snap_to_target")
	await create_timer(2.5).timeout
	for frame: int in range(30):
		await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/roadside-" + RenderingServer.get_current_rendering_method() + ".png")
	state.flags.road_sign = true
	world.call("_load_map", "east_road", "from_village")
	sign = world.get("_map_root").get_node("RoadSign")
	assert(is_zero_approx(sign.rotation.z))
	world.free()
	for singleton: String in ["GameAudio", "GameMusic", "GameAmbience"]:
		root.get_node(singleton).call("stop_all")
	await create_timer(0.25).timeout
	print("ROADSIDE_CAPTURE_PASS decoration tilted repaired")
	quit()
