extends Sprite3D
const Proportions = preload("res://scripts/gameplay/character_proportions.gd")
## Shared eight-way presentation for household residents and street patrols.
const Facing = preload("res://scripts/gameplay/eight_way_facing.gd")
const Grounding = preload("res://scripts/gameplay/sprite_grounding.gd")
const SteppedTurn = preload("res://scripts/gameplay/stepped_turn.gd")
const BodyLife = preload("res://scripts/gameplay/body_life.gd")
const IDENTITIES: Array[String] = ["mira", "flo", "sien", "locke", "ada", "rain", "seph", "owen", "sia", "noah"]
## Fallback cadence when no walker reports a ground speed.
const WALK_FPS: float = 6.0
## Distance-driven cadence stays legible inside this frame-rate range.
const MIN_WALK_FPS: float = 4.0
const MAX_WALK_FPS: float = 9.0
## Metres travelled per drawn step, measured once from the side-profile
## contact frames (foot spread at contact minus idle, 1.45 m body). Mira's
## long dress hides her legs, so she uses a calmer nominal stride.
const STRIDE_METRES: Dictionary[String, float] = {
	"mira": 0.20, "flo": 0.14, "sien": 0.35, "locke": 0.20,
	"ada": 0.28, "rain": 0.35, "seph": 0.25, "owen": 0.16,
	"sia": 0.24, "noah": 0.32,
}
# The first drawing is idle. Walking alternates contact and passing drawings.
const WALK_SEQUENCE: Array[int] = [1, 2, 3, 2]
const CONTACT_POSES: Array[int] = [1, 3]
const GOODBYE_HOLD_SECONDS: float = 0.35
## A watched character is followed within this radius, with a lagging head turn.
const WATCH_RADIUS: float = 5.0
const WATCH_LAG_SECONDS: float = 0.4

# Keep each identity's frames resident: rebuilt maps then reuse the same frame
# textures, so per-texture caches such as foot baselines stay bounded.
static var _frames_by_identity: Dictionary[String, SpriteFrames] = {}
static var _actions_by_identity: Dictionary[String, SpriteFrames] = {}

var resident_id: String = "mira"
var world_heading: Vector3 = Vector3.BACK
var walking: bool = false
## Planar speed reported by the walker (m/s); negative uses WALK_FPS.
var ground_speed: float = -1.0
## Optional character this resident turns to follow while it passes nearby.
var watch_target: Node3D
var visible_height: float = Proportions.HEIGHT
var ground_lift: float = 0.008
var sprite_frames: SpriteFrames
var animation: StringName = &"down"
var pose_index: int = 0
## Battle pose from <id>_action.tres (0 ready, 1 windup, 2 strike, 3 recover/guard);
## -1 shows the ordinary walk. Companions only.
var action_pose: int = -1
## Screen side the action faces: &"left" or &"right".
var action_side: StringName = &"left"
var _walk_time: float = 0.0
var _conversation_partner: Node3D
var _turn := SteppedTurn.new()
var _goodbye_hold: float = 0.0
var _held_heading: Vector3 = Vector3.BACK
var _watch_heading: Vector3 = Vector3.ZERO


func _ready() -> void:
	process_priority = 10 # Resolve the view after camera motion.
	assert(resident_id in IDENTITIES, "Unknown resident identity: " + resident_id)
	if not _frames_by_identity.has(resident_id):
		_frames_by_identity[resident_id] = load("res://assets/generated/residents/" + resident_id + "_walk.tres") as SpriteFrames
	sprite_frames = _frames_by_identity[resident_id]
	texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	alpha_scissor_threshold = 0.25
	modulate = Color.WHITE
	_turn.snap(world_heading, get_viewport().get_camera_3d())
	add_child(BodyLife.new())
	_update_presentation(0.0)


func turn_to(partner: Node3D) -> void:
	_conversation_partner = partner
	_goodbye_hold = 0.0
	_turn.react()
	_update_presentation(0.0)


## Leave the conversation; hold a goodbye beat, then turn back.
func end_conversation() -> void:
	_release_partner()
	_update_presentation(0.0)


## Synchronous restore for cutscenes and presentations that capture the pose.
func snap_to_idle() -> void:
	_conversation_partner = null
	_goodbye_hold = 0.0
	_turn.snap(world_heading, get_viewport().get_camera_3d())
	_update_presentation(0.0)


## Complete the current turn now (used by tests and scripted framing).
func settle_facing() -> void:
	_turn.snap(_target_heading(0.0), get_viewport().get_camera_3d())
	_update_presentation(0.0)


func _process(delta: float) -> void:
	_update_presentation(delta)


func _release_partner() -> void:
	if is_instance_valid(_conversation_partner):
		_goodbye_hold = GOODBYE_HOLD_SECONDS
		_held_heading = _turn.heading
	_conversation_partner = null


func _target_heading(delta: float) -> Vector3:
	if is_instance_valid(_conversation_partner):
		if GameState.mode == GameState.Mode.DIALOGUE:
			var toward: Vector3 = _conversation_partner.global_position - get_parent_node_3d().global_position
			_conversation_partner.call("face_world_position", get_parent_node_3d().global_position)
			return toward
		_release_partner()
	if GameState.mode == GameState.Mode.CUTSCENE and _goodbye_hold > 0.0:
		_goodbye_hold = 0.0
		_turn.snap(world_heading, get_viewport().get_camera_3d())
	if _goodbye_hold > 0.0:
		_goodbye_hold = maxf(0.0, _goodbye_hold - delta)
		return _held_heading
	return _watched_heading(delta)


func _watched_heading(delta: float) -> Vector3:
	var heading: Vector3 = world_heading
	if is_instance_valid(watch_target) and not walking:
		var toward: Vector3 = watch_target.global_position - get_parent_node_3d().global_position
		toward.y = 0.0
		if toward.length() < WATCH_RADIUS and not toward.is_zero_approx():
			heading = toward
	if _watch_heading.is_zero_approx() or delta <= 0.0:
		_watch_heading = heading
	else:
		var angle: float = lerp_angle(atan2(_watch_heading.x, _watch_heading.z), atan2(heading.x, heading.z), 1.0 - exp(-delta / WATCH_LAG_SECONDS))
		_watch_heading = Vector3(sin(angle), 0.0, cos(angle))
	return _watch_heading


func _update_presentation(delta: float) -> void:
	if sprite_frames == null:
		return
	if action_pose >= 0 and _action_frames() != null:
		_present_action()
		return
	var index: int = _turn.update(_target_heading(delta), get_viewport().get_camera_3d(), delta)
	animation = Facing.ANIMATIONS[index]
	var moving_mode: bool = GameState.mode in [GameState.Mode.EXPLORE, GameState.Mode.CUTSCENE]
	if walking and moving_mode:
		_walk_time = fmod(_walk_time + delta * _walk_fps(), float(WALK_SEQUENCE.size()))
		pose_index = WALK_SEQUENCE[int(_walk_time) % WALK_SEQUENCE.size()]
	elif moving_mode and pose_index in CONTACT_POSES and delta > 0.0:
		# Finish the step: bring the trailing foot through before standing.
		_walk_time += delta * MAX_WALK_FPS
		if WALK_SEQUENCE[int(_walk_time) % WALK_SEQUENCE.size()] != pose_index:
			_walk_time = 0.0
			pose_index = 0
	else:
		_walk_time = 0.0
		pose_index = 0
	var next_texture := sprite_frames.get_frame_texture(animation, pose_index)
	if texture == next_texture:
		return
	texture = next_texture
	# One scale per direction avoids pumping between animation frames. Measured
	# foot metadata keeps every direction planted without modifying source art.
	Proportions.apply(self, sprite_frames.get_frame_texture(animation, 0), float(texture.get_meta("reference_height")), visible_height)
	Grounding.anchor(self, texture, float(texture.get_meta("ground_y")))
	position.y += ground_lift


func _action_frames() -> SpriteFrames:
	if not _actions_by_identity.has(resident_id):
		var path := "res://assets/generated/residents/" + resident_id + "_action.tres"
		_actions_by_identity[resident_id] = load(path) as SpriteFrames if ResourceLoader.exists(path) else null
	return _actions_by_identity[resident_id]


func _present_action() -> void:
	var frames := _action_frames()
	var next_texture := frames.get_frame_texture(action_side, clampi(action_pose, 0, 3))
	if texture == next_texture:
		return
	texture = next_texture
	Proportions.apply(self, frames.get_frame_texture(action_side, 0), float(texture.get_meta("reference_height")), visible_height)
	Grounding.anchor(self, texture, float(texture.get_meta("ground_y")))
	position.y += ground_lift


func _walk_fps() -> float:
	if ground_speed < 0.0:
		return WALK_FPS
	# Two drawings (contact, passing) per step: frames/s = 2 * speed / stride.
	return clampf(2.0 * ground_speed / STRIDE_METRES.get(resident_id, 0.25), MIN_WALK_FPS, MAX_WALK_FPS)
