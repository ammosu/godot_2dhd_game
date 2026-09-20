extends TextureRect
## One replacement texture: the old equipment is absent, not covered by a decal.
const Appearance = preload("res://scripts/gameplay/equipment_appearance.gd")


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func dress(base: Texture2D, pose: String, loadout: Dictionary, actor: String = "wanderer") -> void:
	texture = Appearance.texture_for(base, pose, loadout, actor)
