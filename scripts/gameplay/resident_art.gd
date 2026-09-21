extends Sprite3D
## Shared eight-way presentation for household residents and street patrols.
const Facing = preload("res://scripts/gameplay/eight_way_facing.gd")
const Grounding = preload("res://scripts/gameplay/sprite_grounding.gd")
const IDENTITIES: Array[String] = ["mira", "flo", "sien", "locke", "ada", "rain", "seph", "owen"]
const WALK_FPS: float = 6.0
# The first drawing is idle. Walking alternates contact and passing drawings.
const WALK_SEQUENCE: Array[int] = [1, 2, 3, 2]

var resident_id: String = "mira"
var world_heading: Vector3 = Vector3.BACK
var walking: bool = false
var visible_height: float = 1.4
var ground_lift: float = 0.008
var sprite_frames: SpriteFrames
var animation: StringName = &"down"
var pose_index: int = 0
var _walk_time: float = 0.0
var _conversation_partner: Node3D


func _ready() -> void:
	process_priority = 10 # Resolve the view after camera motion.
	assert(resident_id in IDENTITIES, "Unknown resident identity: " + resident_id)
	sprite_frames = load("res://assets/generated/residents/" + resident_id + "_walk.tres") as SpriteFrames
	texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	alpha_scissor_threshold = 0.25
	modulate = Color.WHITE
	_update_presentation(0.0)


func turn_to(partner: Node3D) -> void:
	_conversation_partner = partner
	_update_presentation(0.0)


func end_conversation() -> void:
	_conversation_partner = null
	_update_presentation(0.0)


func _process(delta: float) -> void:
	_update_presentation(delta)


func _update_presentation(delta: float) -> void:
	if sprite_frames == null:
		return
	var heading: Vector3 = world_heading
	if is_instance_valid(_conversation_partner):
		if GameState.mode == GameState.Mode.DIALOGUE:
			heading = _conversation_partner.global_position - get_parent_node_3d().global_position
			_conversation_partner.call("face_world_position", get_parent_node_3d().global_position)
		else:
			_conversation_partner = null
	var screen_heading := Facing.screen_direction(heading, get_viewport().get_camera_3d())
	if not screen_heading.is_zero_approx():
		animation = Facing.ANIMATIONS[Facing.direction_index(screen_heading)]
	if walking and not GameState.is_input_locked():
		_walk_time = fmod(_walk_time + delta, float(WALK_SEQUENCE.size()) / WALK_FPS)
		pose_index = WALK_SEQUENCE[int(_walk_time * WALK_FPS) % WALK_SEQUENCE.size()]
	else:
		_walk_time = 0.0
		pose_index = 0
	var next_texture := sprite_frames.get_frame_texture(animation, pose_index)
	if texture == next_texture:
		return
	texture = next_texture
	# One scale per direction avoids pumping between animation frames. Measured
	# foot metadata keeps every direction planted without modifying source art.
	pixel_size = visible_height / float(texture.get_meta("reference_height"))
	Grounding.anchor(self, texture, float(texture.get_meta("ground_y")))
	position.y += ground_lift
