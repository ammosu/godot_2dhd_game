extends Sprite3D
const Proportions = preload("res://scripts/gameplay/character_proportions.gd")
## Village actors share the same authoritative loadout as their battle versions.
const Appearance = preload("res://scripts/gameplay/equipment_appearance.gd")
const Grounding = preload("res://scripts/gameplay/sprite_grounding.gd")
const Facing = preload("res://scripts/gameplay/eight_way_facing.gd")
const TURNAROUNDS: Dictionary[String, SpriteFrames] = {
	"elder": preload("res://assets/generated/elder_facings.tres"),
	"noah": preload("res://assets/generated/noah_facings.tres"),
	"rumi": preload("res://assets/generated/rumi_facings.tres"),
}
const SteppedTurn = preload("res://scripts/gameplay/stepped_turn.gd")
const BodyLife = preload("res://scripts/gameplay/body_life.gd")
## A short goodbye beat before the NPC turns back to its post.
const GOODBYE_HOLD_SECONDS: float = 0.35
var actor_id: String = ""
var source_texture: Texture2D
@export var idle_world_direction: Vector3 = Vector3.BACK
var _conversation_partner: Node3D
var _facing_key: String = ""
var _turn: SteppedTurn
var _goodbye_hold: float = 0.0
var _held_heading: Vector3 = Vector3.BACK


func _ready() -> void:
	process_priority = 10 # Resolve directional art after the camera rig.
	source_texture = texture
	_turn = SteppedTurn.new(idle_world_direction)
	add_child(BodyLife.new())
	GameState.state_changed.connect(_refresh_equipment)
	_refresh_equipment()


func _refresh_equipment() -> void:
	if GameState.mode == GameState.Mode.CUTSCENE:
		snap_to_idle()
		return
	if is_instance_valid(_conversation_partner) and GameState.mode != GameState.Mode.DIALOGUE:
		_release_partner()
	_present(0.0)


func turn_to(partner: Node3D) -> void:
	_conversation_partner = partner
	_goodbye_hold = 0.0
	_turn.react()
	_present(0.0)


## Leave the conversation; the NPC holds a goodbye beat, then turns home.
func end_conversation() -> void:
	_release_partner()
	_facing_key = ""
	_present(0.0)


## Synchronous restore for cutscenes and presentations that capture the pose.
func snap_to_idle() -> void:
	_conversation_partner = null
	_goodbye_hold = 0.0
	_show_index(_turn.snap(idle_world_direction, get_viewport().get_camera_3d()))


## Complete the current turn now (used by tests and scripted framing).
func settle_facing() -> void:
	_show_index(_turn.snap(_target_heading(), get_viewport().get_camera_3d()))


func _process(delta: float) -> void:
	if is_instance_valid(_conversation_partner) and GameState.mode != GameState.Mode.DIALOGUE:
		_release_partner()
	_goodbye_hold = maxf(0.0, _goodbye_hold - delta)
	_present(delta)


func _release_partner() -> void:
	if is_instance_valid(_conversation_partner):
		_goodbye_hold = GOODBYE_HOLD_SECONDS
		_held_heading = _turn.heading
	_conversation_partner = null


func _target_heading() -> Vector3:
	if is_instance_valid(_conversation_partner) and GameState.mode == GameState.Mode.DIALOGUE:
		return _conversation_partner.global_position - get_parent_node_3d().global_position
	if _goodbye_hold > 0.0:
		return _held_heading
	return idle_world_direction


func _present(delta: float) -> void:
	if is_instance_valid(_conversation_partner):
		_conversation_partner.call("face_world_position", get_parent_node_3d().global_position)
	_show_index(_turn.update(_target_heading(), get_viewport().get_camera_3d(), delta))


func _show_index(index: int) -> void:
	var animation := Facing.ANIMATIONS[index]
	var variant := Appearance.variant(GameState.get_loadout(actor_id), actor_id) if actor_id != "rumi" else ""
	var row := 3 if variant.ends_with("_both") else 2 if variant.ends_with("_armor") else 1 if variant.ends_with("_weapon") else 0
	var key := "%s:%s" % [animation, row]
	if key != _facing_key:
		_facing_key = key
		_show_facing(animation, variant)


func _show_facing(animation: StringName, variant: String) -> void:
	# Idle and conversation share one character design and physical height.
	var row := 3 if variant.ends_with("_both") else 2 if variant.ends_with("_armor") else 1 if variant.ends_with("_weapon") else 0
	texture = TURNAROUNDS[actor_id].get_frame_texture(animation, row)
	Proportions.apply(self, texture, float(texture.get_meta("visible_height")))
	Grounding.anchor(self, texture, float(texture.get_meta("ground_y")))
	position.y += 0.008
