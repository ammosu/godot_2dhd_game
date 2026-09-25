extends SceneTree
## Opening film: natural playback, two-step skip, final exploration state and no save writes.
## Add `-- --capture-dir=/absolute/dir` (without --headless) to save one frame per shot.

var _failures: int = 0
var _capture_dir: String = ""


func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="):
			_capture_dir = argument.trim_prefix("--capture-dir=")
	call_deferred("_run")


func _run() -> void:
	var state: Node = root.get_node("GameState")
	state.get("flags")["intro_seen"] = true
	var save_path := str(state.get("SAVE_PATH"))
	var save_existed := FileAccess.file_exists(save_path)
	var save_stamp := FileAccess.get_modified_time(save_path) if save_existed else 0
	var world := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(world)
	await process_frame
	var player := world.get_node("Player") as Node3D
	var rig_camera := world.get_node("CameraRig/Camera3D") as Camera3D
	var shot_count: int = (load("res://scripts/story/opening_cutscene.gd").shots() as Array).size()

	# Natural playback, sped up; captures use real time so frames are stable.
	Engine.time_scale = 1.0 if not _capture_dir.is_empty() else 6.0
	world.set("_test_mode", true)
	var film: Node = world.call("_play_opening")
	if film == null:
		push_error("OPENING_CUTSCENE_TEST_FAIL film did not start")
		quit(1)
		return
	_check(state.call("is_input_locked"), "Cutscene must lock exploration input")
	_check(not (world.get_node("HUD") as CanvasLayer).visible, "HUD must hide during the film")
	_check(root.get_viewport().get_camera_3d() == film.get("camera"), "Film camera must be current")
	var seen_maps: Dictionary = {}
	var road_start_x: float = INF
	var road_end_x: float = INF
	var captured: Dictionary = {}
	while is_instance_valid(film) and not bool(film.call("is_concluded")):
		var index := int(film.get("shot_index"))
		seen_maps[str(state.get("current_map"))] = true
		if index == 2:
			if road_start_x == INF:
				road_start_x = player.global_position.x
			road_end_x = player.global_position.x
		_check(state.call("is_input_locked"), "Input must stay locked during shot %d" % index)
		var progress := float(film.get("shot_time")) / float(film.call("current_shot").duration)
		for moment: float in [0.25, 0.55, 0.85]:
			var key := "%d_%d" % [index, int(moment * 100.0)]
			if not _capture_dir.is_empty() and not captured.has(key) and progress > moment:
				captured[key] = true
				await RenderingServer.frame_post_draw
				root.get_viewport().get_texture().get_image().save_png("%s/opening_shot_%s.png" % [_capture_dir, key])
		await process_frame
	_check(seen_maps.has("east_road") and seen_maps.has("village"), "Film must visit the east road and village")
	_check(road_start_x - road_end_x > 8.0, "Traveler must walk west along the east road (%.2f -> %.2f)" % [road_start_x, road_end_x])
	await _wait_for_film(film)
	_check_final_state(world, state, player, rig_camera, "natural")

	# A single press only arms skipping; it expires if not confirmed.
	Engine.time_scale = 1.0
	film = world.call("_play_opening")
	await process_frame
	film.call("request_skip")
	await create_timer(2.8).timeout
	film.call("request_skip")
	await process_frame
	_check(not bool(film.call("is_concluded")), "Expired first press must not skip")
	film.call("request_skip")
	await process_frame
	_check(bool(film.call("is_concluded")), "Second press within the window must skip")
	_check(bool(film.get("skipped")), "Skip must be reported")
	await _wait_for_film(film)
	_check_final_state(world, state, player, rig_camera, "skip")

	# Skipping mid-walk must stop the scripted route cleanly.
	film = world.call("_play_opening")
	while int(film.get("shot_index")) < 2 or float(film.get("shot_time")) < 1.5:
		film.call("_process", 0.25)
		await physics_frame
	_check(bool(player.call("is_scripted_walking")), "Traveler must be walking in the road shot")
	film.call("request_skip")
	film.call("request_skip")
	await _wait_for_film(film)
	_check(not bool(player.call("is_scripted_walking")), "Skip must stop the scripted route")
	_check_final_state(world, state, player, rig_camera, "skip_mid_walk")

	var save_now_exists := FileAccess.file_exists(save_path)
	_check(save_now_exists == save_existed and (not save_existed or FileAccess.get_modified_time(save_path) == save_stamp), "Film must not write the normal save")
	Engine.time_scale = 1.0
	world.queue_free()
	await process_frame
	if _failures == 0:
		print("OPENING_CUTSCENE_TEST_PASS natural skip_confirm skip_mid_walk final_state no_save shots=%d" % shot_count)
	quit(1 if _failures > 0 else 0)


func _wait_for_film(film: Node) -> void:
	var limit := 600
	while is_instance_valid(film) and limit > 0:
		limit -= 1
		await process_frame
	_check(limit > 0, "Film must finish and free itself")


func _check_final_state(world: Node, state: Node, player: Node3D, rig_camera: Camera3D, label: String) -> void:
	_check(str(state.get("current_map")) == "village", "%s: must end in the village" % label)
	_check(player.global_position.distance_to(Vector3(0.0, 0.1, 7.5)) < 0.6, "%s: must end at the village spawn (%s)" % [label, player.global_position])
	_check(root.get_viewport().get_camera_3d() == rig_camera, "%s: exploration camera must be restored" % label)
	_check((world.get_node("HUD") as CanvasLayer).visible, "%s: HUD must be restored" % label)
	_check(world.get_node_or_null("CutscenePlayer") == null, "%s: film node must be freed" % label)
	# The film hands over to the existing intro narration, which then returns to exploration.
	var dialogue := world.get_node("DialogueUI")
	_check(bool(dialogue.call("is_open")), "%s: intro narration must follow the film" % label)
	dialogue.call("_finish_dialogue")
	_check(int(state.get("mode")) == 0, "%s: closing the intro must restore exploration" % label)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error("OPENING_CUTSCENE_TEST_FAIL " + message)
