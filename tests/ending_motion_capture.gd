extends SceneTree
## Real-renderer stage capture; isolated from normal saves.


func _initialize() -> void:
	call_deferred("_run")


func _capture(label: String) -> void:
	for frame: int in range(3):
		await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("/tmp/wanderlight-ending-" + label + "-" + RenderingServer.get_current_rendering_method() + ".png") == OK)


func _run() -> void:
	var state := root.get_node("GameState")
	state.get("flags")["intro_seen"] = true
	var world := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(world)
	world.set("_test_mode", true)
	var player := world.get_node("Player") as Node3D
	player.position = Vector3(-3.0, 0.1, 3.0)
	world.get_node("CameraRig").call("snap_to_target")
	state.call("start_quest")
	state.call("defeat_guardian")
	world.call("_complete_main_quest")
	var dialogue := world.get_node("DialogueUI")
	var motion := get_nodes_in_group("moon_seal_presentations")[0]
	motion.set_process(false)
	dialogue.call("advance")
	dialogue.call("advance")
	await _capture("seal-low")
	motion.call("_process", 0.25)
	await _capture("seal-mid")
	motion.call("_process", 0.25)
	await _capture("seal-held")
	dialogue.call("advance")
	dialogue.call("advance")
	dialogue.set_process(false)
	await _capture("eyes-closed")
	dialogue.call("_process", 0.85)
	await _capture("eyes-opening")
	dialogue.call("_process", 0.75)
	await _capture("eyes-open")
	world.free()
	for singleton: String in ["GameAudio", "GameMusic", "GameAmbience"]:
		root.get_node(singleton).call("stop_all")
	await create_timer(0.25).timeout
	print("ENDING_MOTION_CAPTURE_PASS six_stages")
	quit()
