extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var state := root.get_node("GameState")
	state.get("flags")["intro_seen"] = true
	var world := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(world)
	world.set("_test_mode", true)
	world.call("_load_map", "ruins", "from_village")
	var dialogue := world.get_node("DialogueUI")
	var cinematic: Control = dialogue.get_node("DialogueRoot/CinematicInsert")
	var picture := dialogue.get_node("DialogueRoot/MemoryIllustration") as TextureRect
	for injured: bool in [true, false]:
		if injured:
			state.set("player_hp", 12)
			state.set("player_mp", 0)
		world.call("_rest_at_moon_spring")
		assert(picture.visible and picture.texture != null)
		assert(cinematic.visible and not dialogue.get("_panel").visible)
		# Natural completion must keep the page and dialogue lock until input.
		if not injured:
			cinematic.call("_process", 14.1)
			assert(not cinematic.visible and dialogue.get("_panel").visible)
			assert(dialogue.get("_line_index") == 0 and dialogue.call("is_open"))
		assert(state.get("player_hp") == state.get("player_max_hp"))
		assert(state.get("player_mp") == state.get("player_max_mp"))
		if injured and "--memory-capture" in OS.get_cmdline_user_args():
			cinematic.set_process(false)
			for moment: float in [1.5, 5.0, 9.0, 12.0]:
				cinematic.set("elapsed", moment)
				cinematic.call("_process", 0.0)
				await process_frame
				await RenderingServer.frame_post_draw
				assert(root.get_texture().get_image().save_png("/tmp/wanderlight-memory-" + RenderingServer.get_current_rendering_method() + "-" + str(int(moment)) + ".png") == OK)
			cinematic.set_process(true)
		dialogue.call("advance")
		assert(not picture.visible and picture.texture == null)
		assert(not cinematic.visible and cinematic.get("picture") == null)
		for page: int in range(4):
			if dialogue.call("is_open"):
				dialogue.call("advance")
		assert(not dialogue.call("is_open"))
	world.call("_rest_at_moon_spring")
	world.call("_load_map", "village", "default")
	assert(not cinematic.visible and cinematic.get("picture") == null)
	assert(not picture.visible and picture.texture == null)
	for page: int in range(4):
		if dialogue.call("is_open"):
			dialogue.call("advance")
	world.free()
	for singleton: String in ["GameAudio", "GameMusic", "GameAmbience"]:
		root.get_node(singleton).call("stop_all")
	await create_timer(0.25).timeout
	print("SPRING_MEMORY_TEST_PASS injured full_health page_cleanup map_cleanup")
	quit()
