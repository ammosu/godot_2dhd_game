extends PanelContainer
## Portrait crops reuse the party's original combat art, without new bitmap assets.
const ClassArt = preload("res://scripts/gameplay/class_art.gd")
const FACES: Dictionary = {
	"wanderer": Rect2(216, 96, 224, 224),
	"noah": Rect2(190, 76, 200, 200),
	"elder": Rect2(245, 62, 258, 258),
}
var portrait: TextureRect
var title: Label
var status: Label
var hp: ProgressBar
var mp: ProgressBar
var _hp_text: Label
var _mp_text: Label
var _style: StyleBoxFlat
var _portrait_style: StyleBoxFlat
var _art: String = ""

func _ready() -> void:
	custom_minimum_size.y = 74
	_style = StyleBoxFlat.new()
	_style.bg_color = Color(0.10, 0.14, 0.20, 0.72)
	_style.set_corner_radius_all(4)
	_style.set_content_margin_all(4)
	_style.border_width_left = 3
	add_theme_stylebox_override("panel", _style)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	add_child(row)
	var frame := PanelContainer.new()
	frame.custom_minimum_size = Vector2(66, 66)
	frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_portrait_style = StyleBoxFlat.new()
	_portrait_style.bg_color = Color("263d50")
	_portrait_style.set_border_width_all(1)
	_portrait_style.set_corner_radius_all(4)
	_portrait_style.set_content_margin_all(2)
	frame.add_theme_stylebox_override("panel", _portrait_style)
	row.add_child(frame)
	portrait = TextureRect.new()
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(portrait)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 3)
	row.add_child(info)
	var heading := HBoxContainer.new()
	info.add_child(heading)
	title = Label.new()
	title.add_theme_font_size_override("font_size", 16)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(title)
	status = Label.new()
	status.add_theme_font_size_override("font_size", 12)
	heading.add_child(status)
	hp = _bar(Color("4dad81"), 19)
	info.add_child(hp)
	_hp_text = _bar_label(hp, 13)
	mp = _bar(Color("4a84c7"), 16)
	info.add_child(mp)
	_mp_text = _bar_label(mp, 12)

func display_actor(actor: Dictionary, controlled: bool) -> void:
	var art: String = str(actor.art)
	var vocation: String = str(actor.get("hero_class", "traveler"))
	var female: bool = str(actor.get("hero_body", "male")) == "female"
	var key: String = art + ":" + vocation + (":female" if female else ":male")
	if _art != key:
		_art = key
		var face := AtlasTexture.new()
		face.atlas = load("res://assets/generated/%s_combat.png" % art) as Texture2D
		face.region = FACES[art]
		if art == "wanderer" and (vocation != "traveler" or female):
			var source := ClassArt.texture_for("female_" + vocation if female else vocation, "idle")
			var side: float = source.region.size.y * 0.52
			face.atlas = source.atlas
			face.region = Rect2(source.region.position + Vector2(float(source.get_meta("anchor_x")) - side * 0.5, 0), Vector2.ONE * side)
		face.filter_clip = true
		portrait.texture = face
	GameState.HeroStyle.apply_canvas(portrait, portrait.texture, str(actor.get("hero_style", "original")))
	hp.max_value = actor.max_hp
	hp.value = actor.hp
	mp.max_value = actor.max_mp
	mp.value = actor.mp
	_hp_text.text = "HP  %d / %d" % [actor.hp, actor.max_hp]
	_mp_text.text = "MP  %d / %d" % [actor.mp, actor.max_mp]
	var down: bool = int(actor.hp) <= 0
	var critical: bool = not down and hp.ratio <= 0.25
	var warded: bool = not down and float(actor.ward) > 0
	title.text = ("▶ " if controlled else "") + str(actor.name)
	status.text = "倒下" if down else "守護" if warded else "危急" if critical else "操作中" if controlled else "待命"
	status.modulate = Color("ff9a90") if critical or down else Color("a5eaff") if warded or controlled else Color("a8b8ca")
	title.modulate = Color("c4f3ff") if controlled else Color("e4e8ef")
	_style.bg_color = Color("1c3347") if controlled else Color(0.10, 0.14, 0.20, 0.72)
	_style.border_color = Color("a5eaff") if controlled else Color("d26961") if critical else Color("405166")
	_portrait_style.border_color = _style.border_color
	portrait.modulate = Color("69707e") if down else Color.WHITE
	(hp.get_theme_stylebox("fill") as StyleBoxFlat).bg_color = Color("c7544d") if critical else Color("4dad81")
	tooltip_text = "%s%s%s" % [actor.name, " · 目前操作角色" if controlled else "", " · 守護中，傷害減半" if warded else " · HP 偏低" if critical else ""]

func _bar(color: Color, height: float) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size.y = height
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var background := StyleBoxFlat.new()
	background.bg_color = Color("0a1421")
	background.set_corner_radius_all(2)
	bar.add_theme_stylebox_override("background", background)
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(2)
	bar.add_theme_stylebox_override("fill", fill)
	return bar

func _bar_label(bar: ProgressBar, font_size: int) -> Label:
	var label := Label.new()
	bar.add_child(label)
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_constant_override("outline_size", 3)
	label.add_theme_color_override("font_outline_color", Color("101927"))
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label
