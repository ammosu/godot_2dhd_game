extends SceneTree

var _failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)


func _run() -> void:
	var ambience := root.get_node("GameAmbience")
	var state := root.get_node("GameState")
	var player := ambience.get("_player") as AudioStreamPlayer
	var streams: Dictionary = ambience.get("_streams")
	_check(streams.size() == 3, "Expected three ambience loops")
	for stream: AudioStreamWAV in streams.values():
		_check(not stream.stereo and stream.mix_rate == 32000, "Ambience format mismatch")
		_check(is_equal_approx(stream.get_length(), 11.5), "Ambience duration mismatch")
		_check(stream.loop_mode == AudioStreamWAV.LOOP_FORWARD and stream.loop_end == 368000, "Loop bounds mismatch")
	state.call("set_mode", 0)
	for map_id: String in ["village", "ruins", "house_02"]:
		state.set("current_map", map_id)
		state.emit_signal("state_changed")
		await create_timer(1.35).timeout
		var expected: StringName = &"house" if map_id.begins_with("house_") else StringName(map_id)
		_check(ambience.get("current_context") == expected and player.stream == streams[expected], "Wrong map ambience")
		_check(player.volume_linear > 0.06, "Ambience did not fade in")
		if DisplayServer.get_name() != "headless":
			_check(player.playing, "Desktop ambience did not play")
		var before: AudioStream = player.stream
		state.emit_signal("state_changed")
		await process_frame
		_check(player.stream == before and player.volume_linear > 0.06, "Unrelated update reset ambience")
	state.call("set_mode", 2)
	await create_timer(0.75).timeout
	_check(player.stream == null and not player.playing, "Battle ambience did not retire")
	state.call("set_mode", 0)
	for index: int in range(20):
		state.set("current_map", "village" if index % 2 == 0 else "ruins")
		ambience.call("sync_to_state")
	await create_timer(1.35).timeout
	_check(ambience.get_child_count() == 1 and player.stream == streams[&"ruins"], "Rapid routing leaked players or retained stale context")
	for singleton: String in ["GameAmbience", "GameMusic", "GameAudio"]:
		root.get_node(singleton).call("stop_all")
	await create_timer(0.3).timeout
	_check(player.stream == null and not player.playing, "Ambience cleanup failed")
	if _failures == 0:
		print("AMBIENCE_TEST_PASS imports loops maps battle rapid_switch cleanup")
	quit(0 if _failures == 0 else 1)
