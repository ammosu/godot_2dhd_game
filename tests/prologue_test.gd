extends SceneTree
## Prologue "霧中醒來": waking film, east-road exploration (clues, fog turn-back, early west
## exit), whisper and moonbeam (skipped, still restored), the village film and dream, waking
## in the lodge, the coat gate on the door, and no save writes throughout.
## Add `-- --capture-dir=/absolute/dir` (without --headless) to save one frame per film shot.

var _failures: int = 0
var _capture_dir: String = ""
var _world: Node3D
var _state: Node


func _initialize() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="):
			_capture_dir = argument.trim_prefix("--capture-dir=")
	call_deferred("_run")


func _run() -> void:
	_state = root.get_node("GameState")
	_state.get("flags")["intro_seen"] = true
	var save_path := str(_state.get("SAVE_PATH"))
	var save_existed := FileAccess.file_exists(save_path)
	var save_stamp := FileAccess.get_modified_time(save_path) if save_existed else 0
	_world = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(_world)
	await process_frame
	_world.set("_test_mode", true)
	_state.call("reset_new_game", false)
	var Prologue: GDScript = load("res://scripts/story/prologue.gd")
	var player := _world.get_node("Player") as CharacterBody3D
	var rig_camera := _world.get_node("CameraRig/Camera3D") as Camera3D
	var dialogue: Node = _world.get_node("DialogueUI")
	Engine.time_scale = 1.0 if not _capture_dir.is_empty() else 6.0

	# Waking film: input locked, HUD hidden, ends on the foggy road with the controls hint.
	var film: Node = _world.call("_play_opening")
	_check(film != null and bool(_state.call("is_input_locked")), "waking film locks input")
	_check(not (_world.get_node("HUD") as CanvasLayer).visible, "HUD hides during the film")
	await _play_through(film, "waking")
	_check(str(_state.get("current_map")) == "east_road", "wakes on the east road")
	_check(player.global_position.distance_to(Prologue.WAKE) < 0.8, "wakes at the prologue spot (%s)" % player.global_position)
	_check(root.get_viewport().get_camera_3d() == rig_camera and (_world.get_node("HUD") as CanvasLayer).visible, "exploration camera and HUD return")
	_check(bool(dialogue.call("is_open")) and str(dialogue.get("_lines")[0].speaker) == "系統", "controls hint follows the film")
	_close(dialogue)
	await _snap("explore_wake")
	_check(str(_state.call("get_quest_text")) == "序幕：看看四周", "road objective")
	var map: Node3D = _world.get("_map_root")
	_check(map.get_node_or_null("FieldCombat") == null and map.get_node_or_null("FieldTerrain") != null, "no beasts, terrain kept")
	_check(map.get_node_or_null("Road Traveler") == null and map.get_node_or_null("travel_caravan") == null and map.get_node_or_null("travel_home") != null, "only the way home remains")
	for id: String in Prologue.CLUES:
		_check(map.get_node_or_null(id) != null, "clue %s placed" % id)
	var lit_lamps := 0
	for lantern: Node in get_nodes_in_group("street_lanterns"):
		if map.is_ancestor_of(lantern) and (lantern.get_node("RoadLight") as OmniLight3D).visible:
			lit_lamps += 1
	_check(lit_lamps == 0, "every road lamp starts cold (%d lit)" % lit_lamps)
	var mini_map: Node = _world.get("_mini_map")
	for point: Dictionary in mini_map.get("destinations"):
		_check(not str(point.title).contains("暮光村"), "the village is not offered before the sign is read")

	# Saving is refused during the prologue.
	var save := InputEventAction.new()
	save.action = &"save_game"
	save.pressed = true
	_world.call("_unhandled_input", save)

	# Walking east into the fog returns the traveler to where they woke.
	player.global_position = Vector3(13.2, player.global_position.y, 5.0)
	await _until(func() -> bool: return bool(dialogue.call("is_open")), 240)
	_check(player.global_position.distance_to(Prologue.WAKE) < 0.8, "fog turns the traveler back (%s)" % player.global_position)
	_check(str(dialogue.get("_lines")[0].text).contains("往東走了幾步"), "fog turn-back line")
	_close(dialogue)

	# The village mouth holds the traveler back until the way is found.
	_world.call("_handle_interaction", "travel_home")
	_check(str(_state.call("get_quest_text")) == "序幕：看看四周" and player.global_position.distance_to(Prologue.WEST_HOLD) < 0.8, "west exit holds back before the whisper")
	_close(dialogue)

	# One clue is not enough; the second brings the whisper.
	_world.call("_handle_interaction", "prologue_sign")
	_close(dialogue)
	_check(_world.get_node_or_null("CutscenePlayer") == null, "one clue does not start the whisper")
	_check(not ((_world.get("_quest_markers") as Dictionary)["prologue_sign"] as Label3D).visible, "read clue clears its marker")
	_world.call("_handle_interaction", "prologue_lamp")
	_close(dialogue)
	film = _world.get_node_or_null("CutscenePlayer")
	_check(film != null, "second clue starts the whisper film")
	await _play_through(film, "whisper")
	_check(str(_state.call("get_quest_text")) == "序幕：看看四周", "whisper alone does not advance")
	_check(bool(dialogue.call("is_open")) and str(dialogue.get("_lines")[0].text) == "誰？", "traveler answers the whisper")
	var whisper_at := player.global_position
	_close(dialogue)
	# Skipping the moonbeam must still light the way.
	film = _world.get_node_or_null("CutscenePlayer")
	_check(film != null, "moonbeam film follows")
	film.call("request_skip")
	film.call("request_skip")
	await _wait_freed(film)
	_check(str(_state.call("get_quest_text")) == "序幕：跟著月光往西走", "follow objective")
	_check(player.global_position.distance_to(whisper_at) < 0.3 and str(_state.get("current_map")) == "east_road", "moonbeam keeps the traveler in place")
	var road: Node = map.get_node_or_null("PrologueRoad")
	_check(road != null and bool(road.get("lit")) and map.get_node_or_null("PrologueRoad/Moonbeam") != null, "moonlight lights the way after a skip")
	lit_lamps = 0
	for lantern: Node in get_nodes_in_group("street_lanterns"):
		if map.is_ancestor_of(lantern) and (lantern.get_node("RoadLight") as OmniLight3D).visible:
			lit_lamps += 1
	_check(lit_lamps == 2, "the village-mouth lamps answer (%d lit)" % lit_lamps)
	player.global_position = Vector3(-6.0, player.global_position.y, 5.0)
	player.call("face_world_position", Vector3(-14.0, 0, 5.0))
	(_world.get_node("CameraRig") as Node).call("snap_to_target")
	await _snap("explore_follow")

	# Arrival film and dream, then waking in the lodge.
	_world.call("_handle_interaction", "travel_home")
	film = _world.get_node_or_null("CutscenePlayer")
	_check(film != null, "village mouth starts the arrival film")
	var seen_village := false
	var dream_lines := 0
	for shot: Dictionary in load("res://scripts/story/prologue_cutscenes.gd").arrival():
		dream_lines += 1 if str(shot.get("speaker", "")) == "記憶" else 0
	while is_instance_valid(film) and not bool(film.call("is_concluded")):
		seen_village = seen_village or str(_state.get("current_map")) == "village"
		await _capture(film, "arrival")
		await process_frame
	await _wait_freed(film)
	_check(seen_village, "arrival film shows the village")
	_check(dream_lines == 5, "all five memory fragments are in the arrival film")
	_check(str(_state.get("current_map")) == Prologue.LODGE, "wakes in the travelers' lodge")
	_check(player.global_position.distance_to(Prologue.BED_SIDE) < 0.6, "wakes beside the bed (%s)" % player.global_position)
	_check(bool(dialogue.call("is_open")) and str(dialogue.get("_lines")[0].speaker) == "村童・露米", "Rumi greets the traveler")
	var rumi := (_world.get("_map_root") as Node3D).get_node_or_null("Rumi") as Node3D
	_check(rumi != null, "Rumi stands in the lodge")
	await _snap("lodge_wake")
	var pages := 0
	while bool(dialogue.call("is_open")) and pages < 20:
		dialogue.call("advance")
		pages += 1
		await create_timer(0.2).timeout
	await process_frame
	_check(not is_instance_valid(rumi) or rumi.is_queued_for_deletion(), "Rumi leaves after the wake scene")
	_check(str(_state.call("get_quest_text")) == "序幕：換上外衣，到廣場找長老", "lodge objective")

	# The door waits for the coat; the window and rack add optional lines.
	_world.call("_handle_interaction", "leave_house")
	_check(str(_state.get("current_map")) == Prologue.LODGE and str(dialogue.get("_lines")[0].text).contains("外衣"), "door waits for the coat")
	_close(dialogue)
	_world.call("_handle_interaction", "prologue_window")
	_check(bool(dialogue.call("is_open")), "window line")
	_close(dialogue)
	_world.call("_handle_interaction", "inspect_house_shelf")
	var rack: Array = dialogue.get("_lines")
	_check(str(rack[rack.size() - 1].text).contains("燈排成一列"), "rack echoes the dream")
	_close(dialogue)
	_world.call("_handle_interaction", "prologue_coat")
	_close(dialogue)
	_check(not (_state.get("flags") as Dictionary).has("prologue"), "taking the coat ends the prologue")
	_check(str(_state.call("get_quest_text")).begins_with("主線："), "main story objective resumes")
	_world.call("_handle_interaction", "leave_house")
	await _until(func() -> bool: return str(_state.get("current_map")) == "village" and int(_state.get("mode")) == 0, 600)
	_check(str(_state.get("current_map")) == "village", "the lodge door opens onto the village")
	_world.call("_handle_interaction", "rumi")
	var rumi_lines: Array = dialogue.get("_lines")
	_check(rumi_lines.size() == 3 and not str(rumi_lines[2].text).contains("外衣"), "Rumi no longer repeats the coat news")
	_close(dialogue)

	var save_now_exists := FileAccess.file_exists(save_path)
	_check(save_now_exists == save_existed and (not save_existed or FileAccess.get_modified_time(save_path) == save_stamp), "prologue never writes the normal save")
	Engine.time_scale = 1.0
	_world.queue_free()
	await process_frame
	for singleton: String in ["GameAudio", "GameMusic", "GameAmbience"]:
		root.get_node(singleton).call("stop_all")
	if _failures == 0:
		print("PROLOGUE_TEST_PASS waking clues fog_turn_back west_hold whisper moonbeam_skip arrival dream lodge coat_gate no_save")
	quit(1 if _failures > 0 else 0)


func _play_through(film: Node, label: String) -> void:
	while is_instance_valid(film) and not bool(film.call("is_concluded")):
		_check(bool(_state.call("is_input_locked")), "%s: input stays locked" % label)
		await _capture(film, label)
		await process_frame
	await _wait_freed(film)


func _capture(film: Node, label: String) -> void:
	if _capture_dir.is_empty() or not is_instance_valid(film):
		return
	var key := "%s_%d" % [label, int(film.get("shot_index"))]
	var progress := float(film.get("shot_time")) / float(film.call("current_shot").duration)
	if progress > 0.6 and not film.has_meta(key):
		film.set_meta(key, true)
		await RenderingServer.frame_post_draw
		root.get_viewport().get_texture().get_image().save_png("%s/prologue_%s.png" % [_capture_dir, key])


func _snap(label: String) -> void:
	if _capture_dir.is_empty():
		return
	for frame: int in range(20):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png("%s/prologue_%s.png" % [_capture_dir, label])


func _wait_freed(film: Node) -> void:
	var limit := 900
	while is_instance_valid(film) and limit > 0:
		limit -= 1
		await process_frame
	_check(limit > 0, "film must finish and free itself")


func _until(condition: Callable, frames: int) -> void:
	while not bool(condition.call()) and frames > 0:
		frames -= 1
		await physics_frame


func _close(dialogue: Node) -> void:
	var safety := 0
	while bool(dialogue.call("is_open")) and safety < 30:
		dialogue.call("advance")
		safety += 1


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error("PROLOGUE_TEST_FAIL " + message)
