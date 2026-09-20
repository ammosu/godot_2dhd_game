extends Node
## Bounded, non-spatial gameplay cues. Does not own quest or save state.
## default_bus_layout.tres establishes buses before startup for Web sample routing.

signal cue_played(cue: StringName)

const CUES: Dictionary = {
	&"dialogue": preload("res://assets/generated/audio/dialogue.wav"),
	&"slash": preload("res://assets/generated/audio/slash.wav"),
	&"impact": preload("res://assets/generated/audio/impact.wav"),
	&"guard": preload("res://assets/generated/audio/guard.wav"),
	&"heal": preload("res://assets/generated/audio/heal.wav"),
	&"skill": preload("res://assets/generated/audio/skill.wav"),
	&"victory": preload("res://assets/generated/audio/victory.wav"),
	&"defeat": preload("res://assets/generated/audio/defeat.wav"),
}
const VOICE_COUNT: int = 8
const SETTINGS_VERSION: int = 1
var settings_path: String = "user://audio_preferences.cfg"
var volume: float = 0.8
var muted: bool = false
var _forced_mute: bool = false
var _voices: Array[AudioStreamPlayer] = []
var _next_voice: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_forced_mute = "--mute-audio" in OS.get_cmdline_user_args()
	load_preferences()
	if AudioServer.get_bus_index("SFX") < 0:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, "SFX")
		AudioServer.set_bus_send(AudioServer.bus_count - 1, "Master")
	for index: int in range(VOICE_COUNT):
		var voice := AudioStreamPlayer.new()
		voice.name = "CueVoice%d" % index
		voice.bus = "SFX"
		voice.volume_db = -14.0
		add_child(voice)
		_voices.append(voice)
	_apply_preferences()


func _input(event: InputEvent) -> void:
	if event.is_echo():
		return
	var result: Error = OK
	if event.is_action_pressed("audio_mute"):
		result = set_muted(not muted)
	elif event.is_action_pressed("audio_down"):
		result = set_volume(volume - 0.1)
	elif event.is_action_pressed("audio_up"):
		result = set_volume(volume + 0.1)
	else:
		return
	var message := "聲音：靜音" if muted or _forced_mute else "聲音：%d%%" % roundi(volume * 100.0)
	if result != OK:
		message += "（設定暫時無法儲存）"
	get_node("/root/GameState").emit_signal("notification_requested", message)
	get_viewport().set_input_as_handled()


func set_volume(value: float, persist: bool = true) -> Error:
	if not is_finite(value):
		return ERR_INVALID_PARAMETER
	volume = clampf(value, 0.0, 1.0)
	_apply_preferences()
	return save_preferences() if persist else OK


func set_muted(value: bool, persist: bool = true) -> Error:
	muted = value
	_apply_preferences()
	return save_preferences() if persist else OK


func _apply_preferences() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(volume, 0.0001)))
	AudioServer.set_bus_mute(0, muted or _forced_mute or volume <= 0.0)


func save_preferences() -> Error:
	var settings := ConfigFile.new()
	settings.set_value("audio", "version", SETTINGS_VERSION)
	settings.set_value("audio", "volume", volume)
	settings.set_value("audio", "muted", muted)
	return settings.save(settings_path)


func load_preferences() -> Error:
	var settings := ConfigFile.new()
	var result := settings.load(settings_path)
	if result != OK:
		return result
	if settings.get_value("audio", "version", 0) != SETTINGS_VERSION:
		return ERR_INVALID_DATA
	var stored_volume: Variant = settings.get_value("audio", "volume", 0.8)
	var stored_mute: Variant = settings.get_value("audio", "muted", false)
	if typeof(stored_volume) not in [TYPE_FLOAT, TYPE_INT] or typeof(stored_mute) != TYPE_BOOL:
		return ERR_INVALID_DATA
	if not is_finite(float(stored_volume)):
		return ERR_INVALID_DATA
	volume = clampf(float(stored_volume), 0.0, 1.0)
	muted = bool(stored_mute)
	_apply_preferences()
	return OK


func play_cue(cue: StringName) -> void:
	if not CUES.has(cue):
		return
	# Headless runs validate cue routing without enqueueing inaudible playback
	# into the dummy audio mixer, which may exit before draining its queue.
	if DisplayServer.get_name() == "headless":
		cue_played.emit(cue)
		return
	var voice := _voices[_next_voice]
	# Prefer idle voices; steal in round-robin order only when saturated.
	for offset: int in range(VOICE_COUNT):
		var candidate := (_next_voice + offset) % VOICE_COUNT
		if not _voices[candidate].playing:
			_next_voice = candidate
			voice = _voices[candidate]
			break
	voice.stop()
	voice.stream = CUES[cue] as AudioStream
	voice.play()
	_next_voice = (_next_voice + 1) % VOICE_COUNT
	cue_played.emit(cue)


func stop_all() -> void:
	for voice: AudioStreamPlayer in _voices:
		voice.stop()
		voice.stream = null


func _exit_tree() -> void:
	stop_all()
	_voices.clear()
