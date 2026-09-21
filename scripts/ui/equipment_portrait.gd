extends TextureRect
## Production atlas portrait with opt-in live layers for supported party poses.
const Appearance = preload("res://scripts/gameplay/equipment_appearance.gd")
const LayeredActor = preload("res://scripts/gameplay/layered_combat_actor.gd")
var _layered: Node2D
var _layer_origin := Vector2.ZERO
var _layer_canvases: Dictionary[String, Texture2D] = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	resized.connect(_layout_layers)


func dress(base: Texture2D, pose: String, loadout: Dictionary, actor: String = "wanderer") -> void:
	if "--layered-equipment" in OS.get_cmdline_user_args() and actor in ["wanderer", "noah", "elder"] and pose in LayeredActor.POSES:
		_dress_layered(base, pose, loadout, actor)
		return
	if is_instance_valid(_layered):
		_layered.hide()
	texture = Appearance.texture_for(base, pose, loadout, actor)


func _dress_layered(base: Texture2D, pose: String, loadout: Dictionary, actor: String) -> void:
	if not is_instance_valid(_layered):
		_layered = LayeredActor.new()
		add_child(_layered)
	var atlas := base as AtlasTexture
	var canvas := base.get_size() + Appearance.PAD * 2
	var key := actor + ":" + pose
	if not _layer_canvases.has(key):
		var blank := Image.create(int(canvas.x), int(canvas.y), false, Image.FORMAT_RGBA8)
		var placeholder := ImageTexture.create_from_image(blank)
		placeholder.set_meta("canvas_padding", Appearance.PAD)
		placeholder.set_meta("ground_y", LayeredActor.foot_y(pose, actor) + atlas.margin.position.y - atlas.region.position.y + Appearance.PAD.y)
		placeholder.set_meta("display_height", float(base.get_meta("display_height", 175.0)) * canvas.y / base.get_height())
		placeholder.set_meta("layered", true)
		_layer_canvases[key] = placeholder
	texture = _layer_canvases[key]
	texture.set_meta("pose", pose)
	texture.set_meta("variant", Appearance.variant(loadout, actor))
	_layer_origin = LayeredActor.ORIGINS[LayeredActor.POSES.find(pose)] + atlas.margin.position - atlas.region.position + Appearance.PAD
	var armors: Dictionary[String, String] = {"wanderer":"moonward_cloak", "noah":"dawn_plate", "elder":"astral_robe"}
	var weapons: Dictionary[String, String] = {"wanderer":"moonsteel_saber", "noah":"dawn_partisan", "elder":"astral_staff"}
	_layered.configure(pose, "moonward" if loadout.get("armor") == armors[actor] else "coat", "saber" if loadout.get("weapon") == weapons[actor] else "blade", false, true, actor)
	_layered.show()
	_layout_layers()


func _layout_layers() -> void:
	if not is_instance_valid(_layered) or not _layered.visible or texture == null:
		return
	var factor := minf(size.x / texture.get_width(), size.y / texture.get_height())
	_layered.scale = Vector2.ONE * factor
	_layered.position = (size - texture.get_size() * factor) * 0.5 + _layer_origin * factor
