extends Node
## Presentation-only score routing; GameState remains authoritative for map/mode.

signal music_changed(context: StringName)

const TRACKS: Dictionary = {
	&"village": preload("res://assets/generated/audio/music_village.wav"),
	&"ruins": preload("res://assets/generated/audio/music_ruins.wav"),
	&"battle": preload("res://assets/generated/audio/music_battle.wav"),
}
const LEVEL: float = 0.126 # Approximately -18 dB, under the gameplay cues.
var current_context: StringName = &""
var _players: Array[AudioStreamPlayer] = []
var _targets: Array[float] = [0.0, 0.0]
var _active: int = 0
var _battle_resolved: bool = false
var _streams: Dictionary = {}


func _ready() -> void:
	if AudioServer.get_bus_index("Music") < 0:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, "Music")
		AudioServer.set_bus_send(AudioServer.bus_count - 1, "Master")
	for key: StringName in TRACKS:
		var stream := (TRACKS[key] as AudioStreamWAV).duplicate() as AudioStreamWAV
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = roundi(stream.get_length() * stream.mix_rate)
		_streams[key] = stream
	for index: int in range(2):
		var player := AudioStreamPlayer.new()
		player.name = "MusicCrossfade%d" % index
		player.bus = "Music"
		player.volume_linear = 0.0
		add_child(player)
		_players.append(player)
	GameState.state_changed.connect(sync_to_state)
	sync_to_state()


func sync_to_state() -> void:
	if GameState.mode == GameState.Mode.BATTLE:
		set_context(&"" if _battle_resolved else &"battle")
	else:
		_battle_resolved = false
		set_context(&"ruins" if GameState.current_map == "ruins" else &"village")


func resolve_battle() -> void:
	_battle_resolved = true
	sync_to_state()


func set_context(context: StringName) -> void:
	if context == current_context or (context != &"" and not TRACKS.has(context)):
		return
	current_context = context
	_targets[0] = 0.0
	_targets[1] = 0.0
	if context != &"":
		_active = 1 - _active
		var player := _players[_active]
		player.stop()
		player.stream = _streams[context] as AudioStream
		player.volume_linear = 0.0
		_targets[_active] = LEVEL
		if DisplayServer.get_name() != "headless":
			player.play()
	music_changed.emit(context)


func _process(delta: float) -> void:
	for index: int in range(_players.size()):
		var player := _players[index]
		player.volume_linear = move_toward(player.volume_linear, _targets[index], delta * LEVEL / 0.75)
		if _targets[index] == 0.0 and player.volume_linear <= 0.0001:
			player.stop()
			player.stream = null


func stop_all() -> void:
	_targets = [0.0, 0.0]
	current_context = &""
	for player: AudioStreamPlayer in _players:
		player.stop()
		player.stream = null
		player.volume_linear = 0.0


func _exit_tree() -> void:
	stop_all()
	_players.clear()
	_streams.clear()
