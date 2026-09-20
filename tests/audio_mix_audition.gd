extends SceneTree
## Manual listening fixtures recorded from the real desktop Master mix.
## Cue timing is authored for audition, not a recorded gameplay session.

var _failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var output: String = ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="):
			output = argument.trim_prefix("--capture-dir=")
	if DisplayServer.get_name() == "headless" or not DirAccess.dir_exists_absolute(output) or "--mute-audio" in OS.get_cmdline_user_args():
		push_error("Use a real desktop audio device and an existing --capture-dir; do not mute")
		quit(1)
		return
	var audio := root.get_node("GameAudio")
	var original_volume: float = audio.get("volume")
	var original_muted: bool = audio.get("muted")
	# Runtime-only overrides: never save preferences or touch a player save.
	audio.call("set_volume", 0.8, false)
	audio.call("set_muted", false, false)
	var recorder := AudioEffectRecord.new()
	recorder.format = AudioStreamWAV.FORMAT_16_BITS
	var effect_index: int = AudioServer.get_bus_effect_count(0)
	AudioServer.add_bus_effect(0, recorder)
	var fixtures: Array[Dictionary] = [
		{"name": "village", "music": &"village", "ambience": &"village", "events": [
			[2.0, &"step_stone_1"], [2.4, &"step_stone_2"], [2.8, &"step_stone_1"],
			[4.0, &"dialogue"], [4.25, &"dialogue"], [4.5, &"dialogue"]]},
		{"name": "ruins", "music": &"ruins", "ambience": &"ruins", "events": [
			[2.0, &"step_dirt_1"], [2.4, &"step_dirt_2"], [2.8, &"step_dirt_1"], [5.0, &"dialogue"]]},
		{"name": "battle", "music": &"battle", "ambience": &"", "events": [
			[2.0, &"moon_slash"], [2.4, &"impact"], [4.0, &"spear_thrust"], [4.4, &"impact"],
			[6.0, &"frost_nova"], [6.5, &"frost_impact"], [6.5, &"frost_impact"], [6.5, &"frost_impact"],
			[9.0, &"protect"], [11.0, &"moon_heal"], [13.0, &"moon_bolt"], [15.0, &"claw_swipe"]]},
		{"name": "house", "music": &"village", "ambience": &"house", "events": [
			[2.0, &"step_wood_1"], [2.4, &"step_wood_2"], [2.8, &"step_wood_1"], [5.0, &"dialogue"]]},
	]
	for fixture: Dictionary in fixtures:
		for singleton: String in ["GameAudio", "GameMusic", "GameAmbience"]:
			root.get_node(singleton).call("stop_all")
		await create_timer(0.25).timeout
		root.get_node("GameMusic").call("set_context", fixture.music)
		root.get_node("GameAmbience").set("current_context", fixture.ambience)
		recorder.set_recording_active(true)
		var started: int = Time.get_ticks_msec()
		for event: Array in fixture.events:
			var delay: float = float(event[0]) - float(Time.get_ticks_msec() - started) / 1000.0
			if delay > 0.0:
				await create_timer(delay).timeout
			audio.call("play_cue", event[1])
		var remaining: float = 33.0 - float(Time.get_ticks_msec() - started) / 1000.0
		if remaining > 0.0:
			await create_timer(remaining).timeout
		recorder.set_recording_active(false)
		var recording := recorder.get_recording()
		var peak: float = 0.0
		var pcm: PackedByteArray = recording.data
		for index: int in range(0, pcm.size(), 2):
			peak = maxf(peak, absf(float(pcm.decode_s16(index)) / 32768.0))
		var result: Error = recording.save_to_wav(output.path_join(str(fixture.name) + ".wav"))
		if result != OK or recording.get_length() < 32.0 or peak <= 0.001 or peak >= 0.999:
			_failures += 1
			push_error("Invalid audition recording: " + str(fixture.name))
		print("AUDIO_AUDITION ", fixture.name, " seconds=", recording.get_length(), " peak=", peak, " save=", result)
	AudioServer.remove_bus_effect(0, effect_index)
	for singleton: String in ["GameAudio", "GameMusic", "GameAmbience"]:
		root.get_node(singleton).call("stop_all")
	audio.call("set_volume", original_volume, false)
	audio.call("set_muted", original_muted, false)
	await create_timer(0.25).timeout
	if _failures == 0:
		print("AUDIO_MIX_AUDITION_PASS four_desktop_fixtures manual_listening_required")
	quit(0 if _failures == 0 else 1)
