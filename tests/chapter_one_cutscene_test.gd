extends SceneTree
## Real chapter interactions: natural films, early/mid-event skips, restoration and no save writes.

var failures: int = 0
var world: Node3D
var state: Node


func _initialize() -> void:
	_run.call_deferred()


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error("CHAPTER_ONE_CUTSCENE_TEST_FAIL " + message)


func _finish_dialogue() -> void:
	var dialogue: Node = world.get_node("DialogueUI")
	for step: int in range(40):
		if not bool(dialogue.call("is_open")):
			break
		dialogue.call("advance")
	check(not bool(dialogue.call("is_open")), "dialogue finishes")


func _run() -> void:
	state = root.get_node("GameState")
	state.call("reset_new_game", false)
	state.get("flags")["intro_seen"] = true
	var save_path: String = state.get("SAVE_PATH")
	var save_existed: bool = FileAccess.file_exists(save_path)
	var save_hash: String = FileAccess.get_sha256(save_path) if save_existed else ""
	var save_stamp: int = FileAccess.get_modified_time(save_path) if save_existed else 0
	world = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(world)
	world.set("_test_mode", true)
	await process_frame
	var data: GDScript = load("res://scripts/story/chapter_one_cutscenes.gd")
	for key: String in ["light_east", "shard_rise", "seal_open"]:
		var shots: Array = data.call(key)
		var duration: float = 0.0
		check(shots.size() in [2, 3, 4], key + ": shot count")
		for shot: Dictionary in shots:
			duration += float(shot.duration)
			check(not shot.has("map"), key + ": no unnecessary map reload")
			check(not shot.has("title"), key + ": the chapter card plays once, separately")
		check(duration >= 7.0 and duration <= 20.0, key + ": duration")
	var card: Array = data.call("end_card")
	check(card.size() == 1 and card[0].get("black", false) and card[0].get("title") == "第一章〈醒來的古道〉" and card[0].get("subtitle") == "完", "single chapter end card")

	Engine.time_scale = 3.0
	for ending: bool in [false, true]:
		for playback: String in ["natural", "skip_early", "skip_event"]:
			await _play_beat(ending, playback)
	Engine.time_scale = 1.0
	check(FileAccess.file_exists(save_path) == save_existed, "normal save existence unchanged")
	if save_existed:
		check(FileAccess.get_modified_time(save_path) == save_stamp and FileAccess.get_sha256(save_path) == save_hash, "normal save untouched")
	world.queue_free()
	await process_frame
	for singleton: String in ["GameAudio", "GameMusic", "GameAmbience"]:
		root.get_node(singleton).call("stop_all")
	if failures == 0:
		print("CHAPTER_ONE_CUTSCENE_TEST_PASS natural skip_early skip_event restore input_lock east glow stages no_save")
	quit(0 if failures == 0 else 1)


func _play_beat(ending: bool, playback: String) -> void:
	var chapter: Dictionary = state.get_script().get_script_constant_map().Chapter
	var initial: int = chapter.CAMPFIRE if ending else chapter.NONE
	state.set("quest_state", 3)
	state.set("chapter_stage", initial)
	state.call("set_mode", 0)
	var map_id: String = "moon_highland" if ending else "village"
	world.call("_load_map", map_id, "default")
	var player := world.get_node("Player") as CharacterBody3D
	if ending:
		var mountains: GDScript = load("res://scripts/gameplay/mountain_maps.gd")
		var points: PackedVector3Array = mountains.route(map_id)
		player.global_position = points[-9] + Vector3(0.3, 0.15, 0.2)
	else:
		player.global_position = Vector3(2.7, 0.1, 3.3)
	player.velocity = Vector3.ZERO
	for frame: int in range(20):
		await physics_frame
	var origin: Vector3 = player.global_position
	var old_root: Node = world.get("_map_root")
	world.call("_handle_interaction", "highland_view" if ending else "moon_lamp")
	var dialogue: Node = world.get_node("DialogueUI")
	check(not bool(dialogue.call("is_open")), "film precedes dialogue")
	var film: Node = world.get_node_or_null("CutscenePlayer")
	check(film != null, "interaction starts film")
	if film == null:
		return
	check(state.call("is_input_locked"), "film locks input")
	check(not bool(film.get("pause_on_focus_loss")), "test playback ignores focus loss")
	check(not (world.get_node("HUD") as CanvasLayer).visible, "film hides HUD")
	check(world.get("_map_root") == old_root, "film starts on existing map")
	check(int(state.get("chapter_stage")) == initial, "stage waits for film/dialogue")
	# The film may stage the actor on its mark; input must not move it from there.
	await physics_frame
	var staged: Vector3 = player.global_position
	Input.action_press("move_right")
	await physics_frame
	await physics_frame
	Input.action_release("move_right")
	check(Vector2(player.global_position.x - staged.x, player.global_position.z - staged.z).length() < 0.01, "movement input ignored during film")
	var saw_event: bool = false
	var saw_east: bool = false
	var saw_glow: bool = false
	var deadline: int = Time.get_ticks_msec() + 30000
	if playback == "skip_early":
		film.call("skip")
	while is_instance_valid(film) and not bool(film.call("is_concluded")) and Time.get_ticks_msec() < deadline:
		check(int(state.get("chapter_stage")) == initial, "no early chapter advancement")
		var map_root: Node = world.get("_map_root")
		if ending:
			var glow := map_root.get_node_or_null("ShardGlow") as OmniLight3D
			if glow != null:
				saw_event = true
				check(glow.global_position.distance_to(player.global_position + Vector3.UP * 1.6) < 0.01, "shard light placement")
				saw_glow = saw_glow or glow.light_energy > 0.2
		else:
			var road := map_root.find_child("AwakenedRoad", true, false) as Node3D
			if road != null:
				saw_event = saw_event or (road.rotation.y < -0.01 and road.rotation.y > -PI / 2.0 + 0.01)
				saw_east = saw_east or is_equal_approx(road.rotation.y, -PI / 2.0)
		if playback == "skip_event" and saw_event:
			film.call("skip")
		await process_frame
	check(is_instance_valid(film) and bool(film.call("is_concluded")), "film concludes within timeout")
	if not is_instance_valid(film):
		return
	check(str(state.get("current_map")) == map_id, "conclude restores map")
	check(player.global_position.distance_to(origin) < 0.01, "conclude restores exact position")
	check(world.get("_map_root").get_node_or_null("ShardGlow") == null, "reload removes temporary glow")
	if not ending:
		var road := (world.get("_map_root") as Node).find_child("AwakenedRoad", true, false) as Node3D
		check(road != null and is_equal_approx(road.rotation.y, -PI / 2.0), "road already faces east before fade reveals map")
	if playback == "natural":
		check(saw_event, "natural playback fires event")
		check(saw_glow if ending else saw_east, "natural playback completes visual beat")
	elif playback == "skip_event":
		check(saw_event, "skip interrupts an active event")
	await film.finished
	await process_frame
	check(str(state.get("current_map")) == map_id, "finished callback preserves map")
	check(player.global_position.distance_to(origin) < 0.15, "finished callback preserves position")
	check(root.get_viewport().get_camera_3d() == world.get_node("CameraRig/Camera3D"), "exploration camera restored")
	check((world.get_node("HUD") as CanvasLayer).visible, "HUD restored")
	check(bool(dialogue.call("is_open")) and int(state.get("chapter_stage")) == initial, "dialogue follows film before advancement")
	if ending:
		check((dialogue.get("_lines") as Array)[0].has("illustration"), "lantern bearer pages illustrated")
		_finish_dialogue()
		var lamp: Node = world.get_node_or_null("CutscenePlayer")
		check(lamp != null, "blue lamp film follows the bearer")
		if lamp != null:
			lamp.call("skip")
			await lamp.finished
			await process_frame
		check(bool(dialogue.call("is_open")), "the traveler decides after the blue lamp")
		_finish_dialogue()
		var home: Node = world.get_node_or_null("CutscenePlayer")
		check(home != null, "homecoming film follows the lantern bearer")
		if home != null:
			home.call("skip")
			await home.finished
			await process_frame
		check(str(state.get("current_map")) == "village", "homecoming ends in the village")
		check(bool(dialogue.call("is_open")) and str((dialogue.get("_lines") as Array)[0].text).contains("露米"), "the reply reaches Rumi")
		_finish_dialogue()
		var card: Node = world.get_node_or_null("CutscenePlayer")
		check(card != null, "chapter card closes the epilogue")
		if card != null:
			card.call("skip")
			await card.finished
			await process_frame
	else:
		_finish_dialogue()
		var road := (world.get("_map_root") as Node).find_child("AwakenedRoad", true, false) as Node3D
		check(road != null and is_equal_approx(road.rotation.y, -PI / 2.0), "light points east after dialogue")
	check(int(state.get("chapter_stage")) == (chapter.COMPLETE if ending else chapter.LIGHT_EAST), "correct final stage")
	check(not bool(state.call("is_input_locked")), "exploration unlocked")
	# Reload proves the presentation is derived from the persisted chapter stage.
	world.call("_load_map", "village", "default")
	var restored := (world.get("_map_root") as Node).find_child("AwakenedRoad", true, false) as Node3D
	check(restored != null and is_equal_approx(restored.rotation.y, -PI / 2.0), "reload keeps road east")
