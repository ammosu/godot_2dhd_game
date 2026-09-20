extends SceneTree
## Actual renderer evidence for the tablet and three points of the shard flight.


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	assert(DisplayServer.get_name() != "headless")
	var state := root.get_node("GameState")
	state.get("flags")["intro_seen"] = true
	var world := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(world)
	world.set("_test_mode", true)
	state.call("start_quest")
	state.call("defeat_guardian")
	world.call("_on_battle_finished", true)
	var shard := get_nodes_in_group("moon_shard_presentations")[0] as Node3D
	shard.set_process(false)
	for stage: String in ["start", "mid", "end"]:
		if stage != "start":
			shard.call("_process", 0.7)
		await _capture("shard-" + stage)
	var dialogue := world.get_node("DialogueUI")
	dialogue.call("advance")
	dialogue.call("advance")
	var tablet := (world.get("_map_root") as Node).find_child("MoonTabletVisual", true, false).get_parent() as Node3D
	world.get_node("Player").position = tablet.position + Vector3(0, 0.1, 2.3)
	world.get_node("CameraRig").call("snap_to_target")
	await _capture("tablet")
	world.free()
	for singleton: String in ["GameAudio", "GameMusic", "GameAmbience"]:
		root.get_node(singleton).call("stop_all")
	await create_timer(0.25).timeout
	quit()


func _capture(label: String) -> void:
	for frame: int in range(20):
		await process_frame
	await RenderingServer.frame_post_draw
	var path: String = "/tmp/wanderlight-" + label + "-" + RenderingServer.get_current_rendering_method() + ".png"
	assert(root.get_texture().get_image().save_png(path) == OK)
	print("STORY_OBJECT_CAPTURE ", path)
