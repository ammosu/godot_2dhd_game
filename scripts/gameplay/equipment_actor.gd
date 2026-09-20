extends Sprite3D
## Village actors share the same authoritative loadout as their battle versions.
const Appearance = preload("res://scripts/gameplay/equipment_appearance.gd")
const Grounding = preload("res://scripts/gameplay/sprite_grounding.gd")
var actor_id: String = ""
var source_texture: Texture2D
var _variant: String = "unset"


func _ready() -> void:
	source_texture = texture
	GameState.state_changed.connect(_refresh_equipment)
	call_deferred("_refresh_equipment")


func _refresh_equipment() -> void:
	var loadout := GameState.get_loadout(actor_id)
	var selected := Appearance.variant(loadout, actor_id)
	if selected == _variant:
		return
	_variant = selected
	texture = Appearance.texture_for(source_texture, "npc", loadout, actor_id)
	var baseline: float = float(texture.get_meta("ground_y")) if texture.has_meta("ground_y") else Grounding.foot_baseline(texture, alpha_scissor_threshold)
	Grounding.anchor(self, texture, baseline)
	position.y += 0.008
