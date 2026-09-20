extends SceneTree

var _failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)


func _run() -> void:
	var test_path := "user://audio_preferences_test_%d_%d.cfg" % [OS.get_process_id(), Time.get_ticks_usec()]
	var audio: Node = load("res://scripts/systems/game_audio.gd").new()
	audio.set("settings_path", test_path)
	root.add_child(audio)
	_check(audio.call("set_volume", 0.35) == OK, "Preference write failed")
	_check(audio.call("set_muted", true) == OK, "Mute preference write failed")
	_check(AudioServer.is_bus_mute(0), "Master did not mute")
	audio.call("set_volume", 0.9, false)
	audio.call("set_muted", false, false)
	_check(audio.call("load_preferences") == OK, "Preference reload failed")
	_check(is_equal_approx(float(audio.get("volume")), 0.35) and bool(audio.get("muted")), "Preferences did not round-trip")
	audio.call("set_muted", false, false)
	audio.call("set_volume", 0.0, false)
	_check(AudioServer.is_bus_mute(0), "Zero volume must be silent")
	audio.call("set_volume", 2.0, false)
	_check(is_equal_approx(float(audio.get("volume")), 1.0), "Volume must clamp")
	_check(audio.call("set_volume", NAN, false) == ERR_INVALID_PARAMETER, "Non-finite volume accepted")
	var config := ConfigFile.new()
	config.set_value("audio", "version", 1)
	config.set_value("audio", "volume", "invalid")
	config.set_value("audio", "muted", true)
	config.save(test_path)
	_check(audio.call("load_preferences") == ERR_INVALID_DATA, "Invalid preference accepted")
	_check(is_equal_approx(float(audio.get("volume")), 1.0) and not bool(audio.get("muted")), "Invalid load partially changed preferences")
	for action: StringName in [&"audio_mute", &"audio_down", &"audio_up"]:
		_check(InputMap.has_action(action), "Audio binding missing")
	var event := InputEventAction.new()
	event.action = &"audio_mute"
	event.pressed = true
	var battle: Node = load("res://scripts/ui/battle_ui.gd").new()
	root.add_child(battle)
	battle.call("start_battle", {"name": "settings test"})
	await create_timer(0.5).timeout
	root.push_input(event)
	_check(bool(audio.get("muted")), "Mute input did not toggle")
	event.action = &"audio_down"
	root.push_input(event)
	_check(is_equal_approx(float(audio.get("volume")), 0.9), "Battle consumed volume shortcut")
	battle.queue_free()
	await process_frame
	audio.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(test_path))
	_check(not FileAccess.file_exists(test_path), "Temporary settings cleanup failed")
	root.get_node("GameAudio").call("_apply_preferences")
	if _failures == 0:
		print("AUDIO_PREFERENCES_TEST_PASS persistence mute clamp validation input isolated_save")
	quit(0 if _failures == 0 else 1)
