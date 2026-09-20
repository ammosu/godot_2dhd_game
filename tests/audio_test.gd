extends SceneTree

var _failures: int = 0
var _heard: Array[StringName] = []


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)


func _run() -> void:
	var audio := root.get_node("GameAudio")
	# Web sample routing requires stable buses before any autoload starts playback.
	var layout := load("res://default_bus_layout.tres") as AudioBusLayout
	_check(layout != null, "Missing startup audio bus layout")
	for index: int in range(4):
		var expected: String = ["Master", "SFX", "Music", "Ambience"][index]
		_check(str(layout.get("bus/%d/name" % index)) == expected, "Startup bus order changed")
		_check(AudioServer.get_bus_index(expected) == index, "Runtime bus order differs from layout")
		if index > 0:
			_check(str(layout.get("bus/%d/send" % index)) == "Master", "Child bus must send to Master")
	audio.connect("cue_played", func(cue: StringName) -> void: _heard.append(cue))
	var cues: Dictionary = audio.get("CUES")
	_check(cues.size() == 23, "Expected twenty-three original cues including footsteps")
	for cue: StringName in cues:
		var stream := cues[cue] as AudioStreamWAV
		_check(stream != null and stream.get_length() > 0.1 and stream.get_length() <= 1.6, "Invalid cue duration")
		_check(not stream.stereo and stream.mix_rate == 48000 and stream.loop_mode == AudioStreamWAV.LOOP_DISABLED, "Invalid cue import format")
		_check(stream.data.size() > 0, "Cue PCM missing")
	var dialogue: Node = load("res://scripts/ui/dialogue_ui.gd").new()
	root.add_child(dialogue)
	dialogue.call("show_dialogue", [{"speaker": "test", "text": "one"}, {"speaker": "test", "text": "two"}])
	dialogue.call("advance")
	dialogue.call("advance")
	_check(_heard.count(&"dialogue") == 2, "Dialogue must cue once per displayed line")
	dialogue.free()
	var state := root.get_node("GameState")
	state.call("reset_new_game", false)
	var battle: Node = load("res://scripts/ui/battle_ui.gd").new()
	root.add_child(battle)
	battle.call("start_battle", {"name": "audio test", "max_hp": 1000, "attack": 10, "defense": 0})
	await _wait_turn(battle)
	for action: String in ["guard", "attack", "skill", "potion"]:
		battle.call("choose_action", action)
		await _wait_turn(battle)
	for cue: StringName in [&"guard", &"slash", &"impact", &"skill", &"heal"]:
		_check(_heard.has(cue), "Missing live combat cue: " + String(cue))
	battle.call("_end_battle", true)
	_check(_heard.back() == &"victory", "Victory cue missing")
	battle.call("_end_battle", false)
	_check(_heard.back() == &"defeat", "Defeat cue missing")
	var before: int = _heard.size()
	audio.call("play_cue", &"unknown")
	_check(_heard.size() == before, "Unknown cue must be ignored")
	for index: int in range(32):
		audio.call("play_cue", &"impact")
	_check(audio.get_child_count() == 8, "Audio voice pool must remain bounded")
	if DisplayServer.get_name() != "headless":
		for voice: Node in audio.get_children():
			_check((voice as AudioStreamPlayer).playing, "Desktop voice did not start playback")
	audio.call("stop_all")
	root.get_node("GameMusic").call("stop_all")
	root.get_node("GameAmbience").call("stop_all")
	await create_timer(0.25).timeout
	battle.queue_free()
	await process_frame
	if _failures == 0:
		print("AUDIO_TEST_PASS imports dialogue combat outcomes voice_limit")
	quit(0 if _failures == 0 else 1)


func _wait_turn(battle: Node) -> void:
	var deadline := Time.get_ticks_msec() + 10000
	while not bool(battle.call("can_accept_action")) and Time.get_ticks_msec() < deadline:
		await process_frame
	_check(bool(battle.call("can_accept_action")), "Combat animation timed out")
