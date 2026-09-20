extends SceneTree

var _failures: int = 0
var _changes: Array[StringName] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)


func _run() -> void:
	var music := root.get_node("GameMusic")
	var state := root.get_node("GameState")
	music.connect("music_changed", func(context: StringName) -> void: _changes.append(context))
	var streams: Dictionary = music.get("_streams")
	_check(streams.size() == 3, "Expected three music contexts")
	for key: StringName in streams:
		var stream := streams[key] as AudioStreamWAV
		_check(stream.stereo and stream.mix_rate == 32000, "Music format changed")
		_check(stream.loop_mode == AudioStreamWAV.LOOP_FORWARD and stream.loop_end > 500000, "Music loop disabled or truncated")
		_check(stream.get_length() > 17.0 and stream.get_length() <= 30.1, "Music duration invalid")
	state.call("reset_new_game", false)
	_check(music.get("current_context") == &"village", "Village music missing")
	var before: int = _changes.size()
	state.emit_signal("state_changed")
	state.emit_signal("state_changed")
	_check(_changes.size() == before, "Unrelated state update restarted score")
	state.call("request_map", "house_02", "entry")
	_check(music.get("current_context") == &"village", "House should retain village theme")
	state.call("request_map", "ruins", "from_village")
	_check(music.get("current_context") == &"ruins", "Ruins music missing")
	state.call("set_mode", 2)
	_check(music.get("current_context") == &"battle", "Battle music missing")
	await create_timer(0.85).timeout
	var players: Array = music.get("_players")
	var audible: int = 0
	for player: AudioStreamPlayer in players:
		if player.volume_linear > 0.001:
			audible += 1
			_check(player.stream != null, "Crossfade target has no stream")
			if DisplayServer.get_name() != "headless":
				_check(player.playing, "Desktop music did not start")
	_check(audible == 1, "Crossfade did not retire previous track")
	music.call("resolve_battle")
	_check(music.get("current_context") == &"", "Outcome must release room for fanfare")
	state.emit_signal("state_changed")
	_check(music.get("current_context") == &"", "Resolved battle restarted score")
	state.call("set_mode", 0)
	_check(music.get("current_context") == &"ruins", "Exploration score did not resume")
	for index: int in range(12):
		music.call("set_context", &"village" if index % 2 == 0 else &"ruins")
	_check(music.get_child_count() == 2, "Music crossfade must remain two bounded players")
	music.call("stop_all")
	root.get_node("GameAmbience").call("stop_all")
	await create_timer(0.3).timeout
	for player: AudioStreamPlayer in players:
		_check(not player.playing and player.stream == null, "Music cleanup failed")
	if _failures == 0:
		print("MUSIC_TEST_PASS imports loops routing no_restart crossfade outcome cleanup")
	quit(0 if _failures == 0 else 1)
