extends Sprite3D
## Village actors share the same authoritative loadout as their battle versions.
const Appearance = preload("res://scripts/gameplay/equipment_appearance.gd")
const Grounding = preload("res://scripts/gameplay/sprite_grounding.gd")
const Facing = preload("res://scripts/gameplay/eight_way_facing.gd")
const TURNAROUNDS: Dictionary[String, SpriteFrames] = {
	"elder": preload("res://assets/generated/elder_facings.tres"),
	"noah": preload("res://assets/generated/noah_facings.tres"),
	"rumi": preload("res://assets/generated/rumi_facings.tres"),
}
var actor_id: String = ""
var source_texture: Texture2D
@export var idle_world_direction: Vector3 = Vector3.BACK
var _conversation_partner: Node3D
var _source_pixel_size: float
var _source_height: float
var _facing_key: String = ""


func _ready() -> void:
	process_priority = 10 # Resolve directional art after the camera rig.
	source_texture = texture
	_source_pixel_size = pixel_size
	_source_height = float(source_texture.get_image().get_used_rect().size.y)
	GameState.state_changed.connect(_refresh_equipment)
	_refresh_equipment()


func _refresh_equipment() -> void:
	if is_instance_valid(_conversation_partner):
		if GameState.mode == GameState.Mode.DIALOGUE:
			_update_conversation_facing()
		else:
			end_conversation()
		return
	_update_idle_facing()


func turn_to(partner: Node3D) -> void:
	_conversation_partner = partner
	_update_conversation_facing()


func end_conversation() -> void:
	_conversation_partner = null
	_facing_key = ""
	_refresh_equipment()


func _process(_delta: float) -> void:
	if is_instance_valid(_conversation_partner) and GameState.mode == GameState.Mode.DIALOGUE:
		_update_conversation_facing()
	else:
		_conversation_partner = null
		_update_idle_facing()


func _update_idle_facing() -> void:
	_update_world_facing(idle_world_direction)


func _update_conversation_facing() -> void:
	_update_world_facing(_conversation_partner.global_position - get_parent_node_3d().global_position)
	_conversation_partner.call("face_world_position", get_parent_node_3d().global_position)


func _update_world_facing(world_direction: Vector3) -> void:
	var direction := Facing.screen_direction(world_direction, get_viewport().get_camera_3d())
	if direction.is_zero_approx():
		return
	var animation := Facing.ANIMATIONS[Facing.direction_index(direction)]
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
	pixel_size = _source_pixel_size * _source_height / float(texture.get_meta("visible_height"))
	Grounding.anchor(self, texture, float(texture.get_meta("ground_y")))
	position.y += 0.008
