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
var _variant: String = "unset"
var _conversation_partner: Node3D
var _source_pixel_size: float
var _source_height: float
var _facing_key: String = ""


func _ready() -> void:
	source_texture = texture
	_source_pixel_size = pixel_size
	_source_height = float(source_texture.get_image().get_used_rect().size.y)
	GameState.state_changed.connect(_refresh_equipment)
	call_deferred("_refresh_equipment")


func _refresh_equipment() -> void:
	if is_instance_valid(_conversation_partner):
		if GameState.mode == GameState.Mode.DIALOGUE:
			_update_conversation_facing()
		else:
			end_conversation()
		return
	var loadout := GameState.get_loadout(actor_id) if actor_id != "rumi" else {}
	var selected := Appearance.variant(loadout, actor_id) if actor_id != "rumi" else ""
	if selected == _variant:
		return
	_variant = selected
	texture = Appearance.texture_for(source_texture, "npc", loadout, actor_id)
	var baseline: float = float(texture.get_meta("ground_y")) if texture.has_meta("ground_y") else Grounding.foot_baseline(texture, alpha_scissor_threshold)
	Grounding.anchor(self, texture, baseline)
	position.y += 0.008


func turn_to(partner: Node3D) -> void:
	_conversation_partner = partner
	_update_conversation_facing()


func end_conversation() -> void:
	_conversation_partner = null
	_facing_key = ""
	_variant = "unset"
	pixel_size = _source_pixel_size
	_refresh_equipment()


func _process(_delta: float) -> void:
	if _facing_key.is_empty():
		return
	if not is_instance_valid(_conversation_partner) or GameState.mode != GameState.Mode.DIALOGUE:
		end_conversation()
		return
	_update_conversation_facing()


func _update_conversation_facing() -> void:
	var direction := Facing.screen_direction(_conversation_partner.global_position - get_parent_node_3d().global_position, get_viewport().get_camera_3d())
	if direction.is_zero_approx():
		return
	var animation := Facing.ANIMATIONS[Facing.direction_index(direction)]
	var variant := Appearance.variant(GameState.get_loadout(actor_id), actor_id) if actor_id != "rumi" else ""
	var row := 3 if variant.ends_with("_both") else 2 if variant.ends_with("_armor") else 1 if variant.ends_with("_weapon") else 0
	var key := "%s:%s" % [animation, row]
	if key != _facing_key:
		_facing_key = key
		texture = TURNAROUNDS[actor_id].get_frame_texture(animation, row)
		pixel_size = _source_pixel_size * _source_height / float(texture.get_meta("visible_height"))
		Grounding.anchor(self, texture, float(texture.get_meta("ground_y")))
		position.y += 0.008
	_conversation_partner.call("face_world_position", get_parent_node_3d().global_position)
