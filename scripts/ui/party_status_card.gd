extends PanelContainer
## Portrait crops reuse the party's original combat art, without new bitmap assets.
const Faces = preload("res://scripts/ui/portrait_faces.gd")
var portrait: TextureRect
var compact: bool = false
var title: Label
var status: Label
var hp: ProgressBar
var mp: ProgressBar
var _hp_text: Label
var _mp_text: Label
var _style: StyleBoxFlat
var _portrait_style: StyleBoxFlat
var _art: String = ""
## Pale bar that lingers at the previous HP and drains after a hit.
var _hp_trail: ColorRect
var _trail_ratio: float = -1.0
var _trail_tween: Tween

func _ready() -> void:
	custom_minimum_size.y = 54 if compact else 74
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
	frame.custom_minimum_size = Vector2(40, 40) if compact else Vector2(66, 66)
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
	info.add_theme_constant_override("separation", 1 if compact else 3)
	row.add_child(info)
	var heading := HBoxContainer.new()
	info.add_child(heading)
	title = Label.new()
	title.add_theme_font_size_override("font_size", 12 if compact else 16)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(title)
	status = Label.new()
	status.visible = not compact
	status.add_theme_font_size_override("font_size", 12)
	heading.add_child(status)
	hp = _bar(Color("4dad81"), 14 if compact else 19)
	info.add_child(hp)
	_hp_trail = ColorRect.new()
	_hp_trail.color = Color("b8513c")
	_hp_trail.show_behind_parent = true
	_hp_trail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp.add_child(_hp_trail)
	hp.move_child(_hp_trail, 1)
	hp.resized.connect(_place_trail)
	_hp_text = _bar_label(hp, 11 if compact else 13)
	mp = _bar(Color("4a84c7"), 12 if compact else 16)
	info.add_child(mp)
	_mp_text = _bar_label(mp, 10 if compact else 12)

func display_actor(actor: Dictionary, controlled: bool) -> void:
	var art: String = str(actor.art)
	var vocation: String = str(actor.get("hero_class", "traveler"))
	var female: bool = str(actor.get("hero_body", "male")) == "female"
	var key: String = art + ":" + vocation + (":female" if female else ":male")
	if _art != key:
		_art = key
		portrait.texture = Faces.combat_face(art, vocation, female)
	GameState.HeroStyle.apply_canvas(portrait, portrait.texture, str(actor.get("hero_style", "original")))
	hp.max_value = actor.max_hp
	hp.value = actor.hp
	_follow_trail(hp.ratio)
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
	var hp_fill := hp.get_theme_stylebox("fill") as StyleBoxFlat
	hp_fill.bg_color = Color("c7544d") if critical else Color("4dad81")
	hp_fill.border_color = hp_fill.bg_color.lightened(0.35)
	tooltip_text = "%s%s%s" % [actor.name, " · 目前操作角色" if controlled else "", " · 守護中，傷害減半" if warded else " · HP 偏低" if critical else ""]

func _follow_trail(ratio: float) -> void:
	if _trail_ratio < 0.0 or ratio >= _trail_ratio:
		# First display or healing: no lingering damage to show.
		if _trail_tween != null:
			_trail_tween.kill()
		_trail_ratio = ratio
		_place_trail()
		return
	if _trail_tween != null:
		_trail_tween.kill()
	_trail_tween = create_tween()
	_trail_tween.tween_interval(0.35)
	_trail_tween.tween_method(func(value: float) -> void:
		_trail_ratio = value
		_place_trail(), _trail_ratio, ratio, 0.45).set_ease(Tween.EASE_IN)


func _place_trail() -> void:
	_hp_trail.position = Vector2.ZERO
	_hp_trail.size = Vector2(hp.size.x * maxf(_trail_ratio, 0.0), hp.size.y)


func _bar(color: Color, height: float) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size.y = height
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# The track is a child drawn behind the bar so other behind-parent layers
	# (the HP damage trail) can sit between the track and the fill.
	bar.add_theme_stylebox_override("background", StyleBoxEmpty.new())
	var track := Panel.new()
	track.show_behind_parent = true
	track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var background := StyleBoxFlat.new()
	background.bg_color = Color("0a1421")
	background.set_corner_radius_all(2)
	track.add_theme_stylebox_override("panel", background)
	bar.add_child(track)
	track.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(2)
	# A lighter top edge reads as a glassy highlight on a flat fill.
	fill.border_width_top = 2 if height >= 16 else 1
	fill.border_color = color.lightened(0.35)
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
