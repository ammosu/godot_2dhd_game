extends Node3D
## Data-driven story cutscene. Presentation only: GameState owns mode and progress, and the
## host world owns map construction plus the final exploration state.
##
## Host contract:
##   cutscene_load_map(map_id: String, spawn_id: String) -> void
##   cutscene_ground(point: Vector3) -> Vector3   # snaps a route point onto walkable ground
##   cutscene_event(event_id: String) -> void     # one-shot scenery beats (lights, seals)
##   cutscene_conclude() -> void                  # final map/spawn, loaded under black
##
## Shot keys (all optional except duration):
##   duration, map, spawn, music, black, letterbox, fade_in, fade_out,
##   caption, speaker, title, subtitle,
##   camera: {from, to, look_from, look_to, track, look_actor}
##     track: position and look are offsets from the actor; look_actor: fixed lens pans with the actor
##   fov, actor_at, actor_face, actor_path, actor_speed, actor_delay,
##   events: [{at, id}]

signal finished(skipped: bool)

const Overlay = preload("res://scripts/ui/cutscene_overlay.gd")
const SKIP_CONFIRM_SECONDS: float = 2.5
const TEXT_FADE_SECONDS: float = 0.6
const END_FADE_SECONDS: float = 0.8

var host: Node
var actor: Node3D
var hidden_layers: Array[CanvasLayer] = []
## Captures and automated runs keep playing when the window is in the background.
var pause_on_focus_loss: bool = true
var shots: Array[Dictionary] = []
var shot_index: int = -1
var shot_time: float = 0.0
var skipped: bool = false
var overlay: Overlay
var camera: Camera3D
var _previous_camera: Camera3D
var _layer_visibility: Array[bool] = []
var _concluded: bool = false
var _paused: bool = false
var _skip_armed_left: float = 0.0
var _fired_events: Dictionary = {}
var _walk_started: bool = false


func _ready() -> void:
	name = "CutscenePlayer"
	process_mode = Node.PROCESS_MODE_ALWAYS
	camera = Camera3D.new()
	camera.name = "CutsceneCamera"
	add_child(camera)
	overlay = Overlay.new()
	add_child(overlay)


func play(shot_list: Array[Dictionary]) -> void:
	shots = shot_list
	_previous_camera = get_viewport().get_camera_3d()
	if is_instance_valid(_previous_camera):
		camera.attributes = _previous_camera.attributes
		camera.far = _previous_camera.far
	camera.make_current()
	_layer_visibility.clear()
	for layer: CanvasLayer in hidden_layers:
		_layer_visibility.append(layer.visible)
		layer.visible = false
	GameState.set_mode(GameState.Mode.CUTSCENE)
	if shots.is_empty():
		_conclude()
		return
	_start_shot(0)


func current_shot() -> Dictionary:
	return shots[shot_index] if shot_index >= 0 and shot_index < shots.size() else {}


func is_concluded() -> bool:
	return _concluded


func skip() -> void:
	if _concluded:
		return
	skipped = true
	_conclude()


func _start_shot(index: int) -> void:
	shot_index = index
	shot_time = 0.0
	_fired_events.clear()
	_walk_started = false
	var shot := current_shot()
	if shot.has("map"):
		host.cutscene_load_map(str(shot.map), str(shot.get("spawn", "default")))
		# Map loading resets the exploration rig; keep presenting through our own camera.
		camera.make_current()
	if shot.has("music"):
		GameMusic.set_context(StringName(shot.music))
	if actor is Wanderer:
		(actor as Wanderer).stop_scripted_walk()
	if shot.has("actor_at"):
		actor.global_position = host.cutscene_ground(shot.actor_at)
		(actor as CharacterBody3D).velocity = Vector3.ZERO
	if shot.has("fov"):
		camera.fov = float(shot.fov)
	overlay.set_letterbox(bool(shot.get("letterbox", true)))
	_update_camera(0.0)
	if shot.has("actor_face") and actor.has_method("face_world_position"):
		actor.call("face_world_position", shot.actor_face)
		# Field maps swap in a combat silhouette that reads its facing from this meta.
		var heading: Vector3 = (shot.actor_face as Vector3) - actor.global_position
		heading.y = 0.0
		actor.set_meta("cutscene_facing", heading.normalized())
	elif actor.has_meta("cutscene_facing"):
		actor.remove_meta("cutscene_facing")
	_update_presentation()


func _process(delta: float) -> void:
	if _concluded or shot_index < 0:
		return
	_skip_armed_left = maxf(0.0, _skip_armed_left - delta)
	overlay.set_skip_hint(minf(1.0, _skip_armed_left / 0.4))
	if _paused:
		return
	shot_time += delta
	var shot := current_shot()
	if not _walk_started and shot.has("actor_path") and shot_time >= float(shot.get("actor_delay", 0.0)):
		_walk_started = true
		var route := PackedVector3Array()
		for point: Vector3 in shot.actor_path:
			route.append(host.cutscene_ground(point))
		(actor as Wanderer).play_scripted_walk(route, float(shot.get("actor_speed", 2.4)))
	for beat: Dictionary in shot.get("events", []):
		var id := str(beat.id)
		if not _fired_events.has(id) and shot_time >= float(beat.at):
			_fired_events[id] = true
			host.cutscene_event(id)
	var duration := float(shot.duration)
	_update_camera(clampf(shot_time / duration, 0.0, 1.0))
	_update_presentation()
	if shot_time >= duration:
		if shot_index + 1 < shots.size():
			_start_shot(shot_index + 1)
		else:
			_conclude()


func _update_camera(progress: float) -> void:
	var shot := current_shot()
	if not shot.has("camera"):
		return
	var rig: Dictionary = shot.camera
	var eased := smoothstep(0.0, 1.0, progress)
	var from_position: Vector3 = rig.get("from", Vector3(0, 6, 10))
	var to_position: Vector3 = rig.get("to", from_position)
	var look_from: Vector3 = rig.get("look_from", Vector3.ZERO)
	var look_to: Vector3 = rig.get("look_to", look_from)
	var position := from_position.lerp(to_position, eased)
	var look := look_from.lerp(look_to, eased)
	var tracking := bool(rig.get("track", false)) and is_instance_valid(actor)
	if tracking:
		position += actor.global_position
	if (tracking or bool(rig.get("look_actor", false))) and is_instance_valid(actor):
		look += actor.global_position
	# Close tracking shots orbit the actor, so keep scenery from slicing through the lens.
	camera.global_position = _unobstructed(look, position) if tracking else position
	if not position.is_equal_approx(look):
		camera.look_at(look, Vector3.UP)


## Keeps the lens in front of solid scenery between the subject and the planned position.
func _unobstructed(look: Vector3, position: Vector3) -> Vector3:
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(look, position)
	if actor is CollisionObject3D:
		query.exclude = [(actor as CollisionObject3D).get_rid()]
	var hit := space.intersect_ray(query)
	if hit.is_empty():
		return position
	return (hit.position as Vector3) + (look - position).normalized() * 0.3


func _update_presentation() -> void:
	var shot := current_shot()
	var duration := float(shot.duration)
	var fade_in := float(shot.get("fade_in", 0.0))
	var fade_out := float(shot.get("fade_out", 0.0))
	var darkness := 0.0
	if bool(shot.get("black", false)):
		darkness = 1.0
	elif fade_in > 0.0 and shot_time < fade_in:
		darkness = 1.0 - shot_time / fade_in
	elif fade_out > 0.0 and shot_time > duration - fade_out:
		darkness = (shot_time - (duration - fade_out)) / fade_out
	overlay.set_black(darkness)
	var text_alpha := minf(smoothstep(0.0, TEXT_FADE_SECONDS, shot_time - fade_in * 0.5), smoothstep(0.0, TEXT_FADE_SECONDS, duration - fade_out * 0.5 - shot_time))
	overlay.set_caption(str(shot.get("caption", "")), str(shot.get("speaker", "")), text_alpha)
	overlay.set_title(str(shot.get("title", "")), str(shot.get("subtitle", "")), text_alpha)


func _conclude() -> void:
	if _concluded:
		return
	_concluded = true
	if actor is Wanderer:
		(actor as Wanderer).stop_scripted_walk()
	if is_instance_valid(actor) and actor.has_meta("cutscene_facing"):
		actor.remove_meta("cutscene_facing")
	overlay.set_black(1.0)
	overlay.set_caption("", "", 0.0)
	overlay.set_title("", "", 0.0)
	overlay.set_skip_hint(0.0)
	if is_instance_valid(_previous_camera):
		_previous_camera.make_current()
	host.cutscene_conclude()
	for index: int in range(hidden_layers.size()):
		if is_instance_valid(hidden_layers[index]):
			hidden_layers[index].visible = _layer_visibility[index]
	overlay.set_letterbox(false)
	var fade := create_tween()
	fade.tween_method(overlay.set_black, 1.0, 0.0, END_FADE_SECONDS)
	await fade.finished
	if GameState.mode == GameState.Mode.CUTSCENE:
		GameState.set_mode(GameState.Mode.EXPLORE)
	finished.emit(skipped)
	queue_free()


func _input(event: InputEvent) -> void:
	if _concluded or shot_index < 0 or event.is_echo():
		return
	var pressed: bool = (event is InputEventKey and event.pressed) \
		or (event is InputEventMouseButton and event.pressed) \
		or (event is InputEventScreenTouch and event.pressed)
	if not pressed or event.is_action("audio_mute") or event.is_action("audio_down") or event.is_action("audio_up"):
		return
	get_viewport().set_input_as_handled()
	request_skip()


## First press arms the skip; a second press within the window confirms it.
func request_skip() -> void:
	if _skip_armed_left > 0.0:
		skip()
	else:
		_skip_armed_left = SKIP_CONFIRM_SECONDS


func _notification(what: int) -> void:
	if not pause_on_focus_loss:
		return
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_set_paused(true)
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_set_paused(false)


func _set_paused(value: bool) -> void:
	_paused = value
	if actor is Wanderer:
		(actor as Wanderer).scripted_hold = value
