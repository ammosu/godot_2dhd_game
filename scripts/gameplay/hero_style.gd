extends RefCounted
## Cosmetic palette presets; no gameplay stats or image pixels are modified.
const ORDER: Array[String] = ["original", "frost", "ember"]
const DATA: Dictionary = {
	"original": {"name": "原色銀髮", "description": "銀髮與職業原色", "hair": Color("d8d4d2"), "cloth": Color("7babb8")},
	"frost": {"name": "霜銀青衣", "description": "冰銀髮色與青藍服裝", "hair": Color("d4edf9"), "cloth": Color("49a7b5")},
	"ember": {"name": "栗髮赤衣", "description": "栗棕髮色與赤銅服裝", "hair": Color("936348"), "cloth": Color("b76243")},
}
const CANVAS = preload("res://shaders/hero_style_canvas.gdshader")
const SPATIAL = preload("res://shaders/hero_style_spatial.gdshader")

static func _configure(material: ShaderMaterial, texture: Texture2D, id: String) -> void:
	var atlas := texture as AtlasTexture
	var source: Texture2D = atlas.atlas if atlas != null else texture
	var rect: Rect2 = atlas.region if atlas != null else Rect2(Vector2.ZERO, texture.get_size())
	material.set_shader_parameter("frame_rect", Vector4(rect.position.x / source.get_width(), rect.position.y / source.get_height(), rect.size.x / source.get_width(), rect.size.y / source.get_height()))
	material.set_shader_parameter("hair_color", DATA[id].hair)
	material.set_shader_parameter("cloth_color", DATA[id].cloth)
	if material.shader == SPATIAL:
		material.set_shader_parameter("character_texture", source)

static func apply_canvas(item: CanvasItem, texture: Texture2D, id: String) -> void:
	if id == "original" or not DATA.has(id):
		if item.has_meta("hero_style"):
			item.material = null
			item.remove_meta("hero_style")
		return
	if texture == null:
		return
	if not item.has_meta("hero_style"):
		var material := ShaderMaterial.new()
		material.shader = CANVAS
		item.material = material
		item.set_meta("hero_style", true)
	_configure(item.material as ShaderMaterial, texture, id)

static func apply_sprite(sprite: SpriteBase3D, texture: Texture2D, id: String) -> void:
	if id == "original" or not DATA.has(id):
		if sprite.has_meta("hero_style"):
			sprite.material_override = null
			sprite.remove_meta("hero_style")
		return
	if texture == null:
		return
	if not sprite.has_meta("hero_style"):
		var material := ShaderMaterial.new()
		material.shader = SPATIAL
		sprite.material_override = material
		sprite.set_meta("hero_style", true)
	var material := sprite.material_override as ShaderMaterial
	_configure(material, texture, id)
	material.set_shader_parameter("upright", sprite.billboard == BaseMaterial3D.BILLBOARD_FIXED_Y)
	material.set_shader_parameter("sprite_tint", sprite.modulate)
	material.set_shader_parameter("alpha_threshold", sprite.alpha_scissor_threshold)
