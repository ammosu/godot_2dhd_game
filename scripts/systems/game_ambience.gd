extends Node
## One bounded environmental voice; fades out before replacing its stream.

const TRACKS: Dictionary = {
	&"village": preload("res://assets/generated/audio/ambience_village.wav"),
	&"ruins": preload("res://assets/generated/audio/ambience_ruins.wav"),
	&"house": preload("res://assets/generated/audio/ambience_house.wav"),
}
const LEVEL: float = 0.07
var current_context: StringName = &""
var _playing_context: StringName = &""
var _player: AudioStreamPlayer
var _streams: Dictionary = {}


func _ready() -> void:
	if AudioServer.get_bus_index("Ambience") < 0:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, "Ambience")
		AudioServer.set_bus_send(AudioServer.bus_count - 1, "Master")
	_player = AudioStreamPlayer.new()
	# Compare continuous mixing without changing the normal Web backend.
	if OS.has_feature("web") and "--stream-loop-audio" in OS.get_cmdline_user_args():
		_player.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
	_player.bus = "Ambience"
	_player.volume_linear = 0.0
	add_child(_player)
	for key: StringName in TRACKS:
		var stream := (TRACKS[key] as AudioStreamWAV).duplicate() as AudioStreamWAV
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_end = roundi(stream.get_length() * stream.mix_rate)
		_streams[key] = stream
	GameState.state_changed.connect(sync_to_state)
	sync_to_state()


func sync_to_state() -> void:
	if GameState.mode == GameState.Mode.BATTLE:
		current_context = &""
	elif GameState.current_map.begins_with("house_"):
		current_context = &"house"
	else:
		current_context = &"ruins" if GameState.current_map == "ruins" else &"village"


func _process(delta: float) -> void:
	var changing: bool = current_context != _playing_context
	var target: float = 0.0 if changing or current_context == &"" else LEVEL
	_player.volume_linear = move_toward(_player.volume_linear, target, delta * LEVEL / 0.6)
	if changing and _player.volume_linear <= 0.0001:
		_player.stop()
		_player.stream = null
		_playing_context = current_context
		if current_context != &"":
			_player.stream = _streams[current_context] as AudioStream
			if DisplayServer.get_name() != "headless":
				_player.play()


func stop_all() -> void:
	current_context = &""
	_playing_context = &""
	_player.stop()
	_player.stream = null
	_player.volume_linear = 0.0


func _exit_tree() -> void:
	stop_all()
	_streams.clear()
