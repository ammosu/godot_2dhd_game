extends CanvasLayer
## All controls edit a local draft; only starting a journey commits to GameState.
signal journey_started
const Classes = preload("res://scripts/systems/hero_classes.gd")
const Style = preload("res://scripts/gameplay/hero_style.gd")
var selected_body: String = "male"
var _bodies: Dictionary[String, Button] = {}
var selected_style: String = "original"
var _styles: Dictionary[String, Button] = {}
const Preview = preload("res://scripts/ui/hero_preview.gd")
var selected_class: String = "traveler"
var selected_action: String = "idle"
var selected_facing: int = 0
var _details: Label
var _start: Button
var _choices: Dictionary[String, Button] = {}
var _motions: Dictionary[String, Button] = {}
var _directions: Dictionary[int, Button] = {}
var _margin: MarginContainer
var _body: BoxContainer
var _settings: VBoxContainer
var _preview: Control
var _error: Label
var _pause: Button

const GOLD := Color("e8c889")
const MUTED := Color("92abc3")
var _class_title: Label
var _equipment: Label
var _skill: Label
var _stats: Array[Label] = []
var _left: VBoxContainer
var _choice_row: GridContainer
var _brand: Label
var _heading: Label
var _compass: Control
var _control_rows: BoxContainer
var _class_icon: TextureRect
var _footer: BoxContainer

func _ready() -> void:
	layer = 100
	GameState.set_mode(GameState.Mode.CLASS_SELECTION)
	var backdrop := ColorRect.new()
	backdrop.color = Color("071423")
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.add_to_group("camera_touch_blocker")
	backdrop.theme = GameState.ui_theme
	add_child(backdrop)
	var ornament := Control.new()
	ornament.set_script(preload("res://scripts/ui/class_selection_ornament.gd"))
	ornament.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ornament.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.add_child(ornament)
	_margin = MarginContainer.new()
	_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.add_child(_margin)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_margin.add_child(scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 10)
	scroll.add_child(column)
	var header := HBoxContainer.new()
	header.custom_minimum_size.y = 58
	column.add_child(header)
	var brand := _label("月 光 碎 片\nWANDERLIGHT", 24, GOLD)
	_brand = brand
	brand.custom_minimum_size.x = 210
	header.add_child(brand)
	var heading := VBoxContainer.new()
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(heading)
	var title := _label("──  選 擇 你 的 旅 途  ──", 36, GOLD)
	_heading = title
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_child(title)
	var subtitle := _label("在月光指引下，踏上屬於你的旅程。", 16, MUTED)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_child(subtitle)
	var compass := Control.new()
	_compass = compass
	compass.custom_minimum_size.x = 70
	header.add_child(compass)
	_choice_row = GridContainer.new()
	_choice_row.columns = 4
	_choice_row.add_theme_constant_override("h_separation", 10)
	_choice_row.add_theme_constant_override("v_separation", 8)
	column.add_child(_choice_row)
	var subtitles: Array[String] = ["均衡的近戰冒險者", "遠距離的精準射手", "掌控元素的施法者", "靈活迅捷的潛行者"]
	var icons: Array[String] = ["sword", "bow", "staff", "dagger"]
	for index: int in range(Classes.ORDER.size()):
		var id: String = Classes.ORDER[index]
		var button := _button(str(Classes.profile(id).name) + "\n" + subtitles[index], _choice_row, select_class.bind(id))
		button.custom_minimum_size = Vector2(0, 70)
		button.add_theme_font_size_override("font_size", 17)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.icon = load("res://assets/ui/class_selection/%s.svg" % icons[index])
		button.expand_icon = true
		button.add_theme_constant_override("icon_max_width", 46)
		button.add_theme_constant_override("h_separation", 18)
		button.toggle_mode = true
		_choices[id] = button
	_body = BoxContainer.new()
	_body.add_theme_constant_override("separation", 14)
	column.add_child(_body)
	_left = VBoxContainer.new()
	_left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_left.size_flags_stretch_ratio = 1.2
	_left.add_theme_constant_override("separation", 8)
	_body.add_child(_left)
	_preview = Preview.new()
	_preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_left.add_child(_preview)
	var controls := _panel(_left, 12)
	var control_column := VBoxContainer.new()
	controls.add_child(control_column)
	_control_rows = BoxContainer.new()
	_control_rows.add_theme_constant_override("separation", 14)
	control_column.add_child(_control_rows)
	var motion_column := VBoxContainer.new()
	motion_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	motion_column.size_flags_stretch_ratio = 1.6
	_control_rows.add_child(motion_column)
	var motion_row := HFlowContainer.new()
	motion_row.add_theme_constant_override("h_separation", 6)
	motion_column.add_child(_label("動作預覽", 13, MUTED))
	motion_column.add_child(motion_row)
	var names := {"idle": "待機", "walk": "走路", "attack": "攻擊", "cast": "施法", "dodge": "閃避"}
	for action: String in names:
		var button := _button(str(names[action]), motion_row, select_action.bind(action))
		button.add_theme_font_size_override("font_size", 13)
		button.toggle_mode = true
		_motions[action] = button
	_pause = _button("暫停預覽", motion_row, _toggle_pause)
	_pause.add_theme_font_size_override("font_size", 13)
	var direction_column := VBoxContainer.new()
	direction_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_control_rows.add_child(direction_column)
	direction_column.add_child(_label("視角", 13, MUTED))
	var direction_row := HFlowContainer.new()
	direction_row.add_theme_constant_override("h_separation", 6)
	direction_column.add_child(direction_row)
	for direction: int in range(4):
		var button := _button(["正面", "右側", "背面", "左側"][direction], direction_row, select_facing.bind(direction))
		button.add_theme_font_size_override("font_size", 13)
		button.toggle_mode = true
		_directions[direction] = button
	control_column.add_child(_label("預覽不消耗 MP，也不會改動現有旅程。", 12, MUTED))
	var settings_panel := _panel(_body, 16)
	settings_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_settings = VBoxContainer.new()
	_settings.add_theme_constant_override("separation", 8)
	settings_panel.add_child(_settings)
	var class_heading := HBoxContainer.new()
	class_heading.add_theme_constant_override("separation", 14)
	_settings.add_child(class_heading)
	_class_icon = TextureRect.new()
	_class_icon.custom_minimum_size = Vector2(44, 44)
	_class_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_class_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	class_heading.add_child(_class_icon)
	_class_title = _label("", 34, GOLD)
	_class_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	class_heading.add_child(_class_title)
	_details = _label("", 16, Color("ecedf1"))
	_settings.add_child(_details)
	_equipment = _label("", 16, MUTED)
	_settings.add_child(_equipment)
	var stat_row := HBoxContainer.new()
	stat_row.add_theme_constant_override("separation", 8)
	_settings.add_child(stat_row)
	for stat: String in ["HP", "MP", "攻擊", "防禦"]:
		var card := _panel(stat_row, 8)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var label := _label(stat, 17, Color("eef1f5"))
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card.add_child(label)
		_stats.append(label)
	var skill_panel := _panel(_settings, 10)
	var skill_row := HBoxContainer.new()
	skill_panel.add_child(skill_row)
	var moon := TextureRect.new()
	moon.texture = load("res://assets/ui/class_selection/moon.svg")
	moon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	moon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	moon.custom_minimum_size = Vector2(54, 54)
	skill_row.add_child(moon)
	_skill = _label("", 17, GOLD)
	_skill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	skill_row.add_child(_skill)
	_build_body_controls()
	_build_style_controls()
	_footer = BoxContainer.new()
	_footer.add_theme_constant_override("separation", 20)
	column.add_child(_footer)
	var resume := _button("繼續存檔  ·  回到先前的旅程", _footer, continue_journey)
	resume.custom_minimum_size.y = 54
	resume.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	resume.disabled = not GameState.has_save_file()
	resume.icon = load("res://assets/ui/class_selection/book.svg")
	resume.expand_icon = true
	resume.add_theme_constant_override("icon_max_width", 30)
	_start = _button("", _footer, start_journey)
	_start.custom_minimum_size = Vector2(350, 54)
	_start.add_theme_font_size_override("font_size", 24)
	_start.add_theme_color_override("font_color", Color("152131"))
	_start.add_theme_color_override("font_hover_color", Color("152131"))
	for state: String in ["normal", "hover", "pressed"]:
		var style := _box(GOLD.lightened(0.12) if state == "hover" else GOLD, Color("fff0be"), 12)
		style.set_border_width_all(2)
		_start.add_theme_stylebox_override(state, style)
	_error = _label("", 16, Color("ffb6a0"))
	_error.visible = false
	column.add_child(_error)
	get_viewport().size_changed.connect(_layout)
	_layout()
	select_class(selected_class)
	_choices[selected_class].grab_focus()

func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", GameState.title_font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label

func _box(fill: Color, border: Color, padding: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	style.set_content_margin_all(padding)
	return style

func _panel(parent: Node, padding: int) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _box(Color("0a1a2b"), Color("8c7959"), padding))
	parent.add_child(panel)
	return panel

func _build_body_controls() -> void:
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 8)
	_settings.add_child(row)
	for id: String in GameState.HERO_BODIES:
		var button := _button("男性" if id == "male" else "女性", row, select_body.bind(id))
		button.custom_minimum_size = Vector2(108, 38)
		button.toggle_mode = true
		_bodies[id] = button

func select_body(id: String) -> void:
	if id not in GameState.HERO_BODIES:
		return
	selected_body = id
	_refresh_preview()

func _build_style_controls() -> void:
	var label := Label.new()
	label.text = "角色樣式 · 髮色與服裝配色"
	label.add_theme_font_override("font", GameState.title_font)
	label.add_theme_color_override("font_color", Color("e6c58b"))
	_settings.add_child(label)
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 8)
	_settings.add_child(row)
	for id: String in Style.ORDER:
		var button := _button(str(Style.DATA[id].name), row, select_style.bind(id))
		button.toggle_mode = true
		button.custom_minimum_size.y = 44
		button.icon = load("res://assets/ui/class_selection/%s.svg" % id)
		button.add_theme_constant_override("h_separation", 8)
		button.tooltip_text = str(Style.DATA[id].description)
		_styles[id] = button

func select_style(id: String) -> void:
	if not Style.DATA.has(id):
		return
	selected_style = id
	_refresh_preview()

func _button(text: String, parent: Node, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_font_override("font", GameState.title_font)
	button.custom_minimum_size = Vector2(52, 32)
	button.add_theme_font_size_override("font_size", 15)
	for state: String in ["normal", "hover", "pressed", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color.TRANSPARENT if state == "focus" else Color("303a3e") if state in ["pressed", "hover"] else Color("0b1d2f")
		style.border_color = Color("e6c58b") if state == "pressed" else Color("f7dea3") if state == "focus" else Color("476074")
		style.set_border_width_all(2 if state in ["focus", "pressed"] else 1)
		style.set_content_margin_all(8)
		style.set_corner_radius_all(4)
		if state == "pressed":
			style.shadow_color = Color(0.94, 0.77, 0.43, 0.22)
			style.shadow_size = 5
		button.add_theme_stylebox_override(state, style)
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _layout() -> void:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var narrow: bool = viewport_size.x < 900
	var inset: int = 18 if narrow else maxi(30, int(viewport_size.x * 0.04))
	for side: String in ["left", "right"]:
		_margin.add_theme_constant_override("margin_" + side, inset)
	_margin.add_theme_constant_override("margin_top", 14)
	_margin.add_theme_constant_override("margin_bottom", 14)
	_brand.visible = not narrow
	_compass.visible = not narrow
	_heading.text = "選 擇 你 的 旅 途" if narrow else "──  選 擇 你 的 旅 途  ──"
	_heading.add_theme_font_size_override("font_size", 28 if narrow else 36)
	_control_rows.vertical = viewport_size.x < 1250
	_body.vertical = narrow
	_footer.vertical = narrow
	_choice_row.columns = 2 if narrow else 4
	_preview.custom_minimum_size = Vector2(280, 310 if narrow else maxf(260, viewport_size.y - 408))

func select_class(id: String) -> void:
	if not Classes.DATA.has(id):
		return
	selected_class = id
	for choice: String in _choices:
		_choices[choice].set_pressed_no_signal(choice == id)
	var profile := Classes.profile(id)
	var defaults: Dictionary = GameState.ClassEquipment.defaults(id)
	var weapon: Dictionary = GameState.EQUIPMENT_CATALOG[defaults.weapon]
	var armor: Dictionary = GameState.EQUIPMENT_CATALOG[defaults.armor]
	_class_title.text = str(profile.name)
	_class_icon.texture = load("res://assets/ui/class_selection/%s.svg" % ["sword", "bow", "staff", "dagger"][Classes.ORDER.find(id)])
	_details.text = str(profile.description)
	_equipment.text = "%s ／ %s" % [weapon.name, armor.name]
	var values: Array[int] = [int(profile.hp), int(profile.mp), int(profile.attack) + int(weapon.attack), int(profile.defense) + int(armor.defense)]
	for index: int in range(_stats.size()):
		_stats[index].text = "%s\n%d" % [["HP", "MP", "攻擊", "防禦"][index], values[index]]
	_skill.text = "%s\n%d MP · 冷卻 %.1f 秒" % [profile.skill, profile.cost, profile.cooldown]
	_start.text = "以%s開始旅程  ›" % profile.name
	_refresh_preview()

func select_action(action: String) -> void:
	if not Preview.SEQUENCES.has(action):
		return
	selected_action = action
	_refresh_preview()

func select_facing(direction: int) -> void:
	selected_facing = clampi(direction, 0, 3)
	_refresh_preview()

func _refresh_preview() -> void:
	_preview.body_id = selected_body
	for body: String in _bodies:
		_bodies[body].set_pressed_no_signal(body == selected_body)
	_preview.style_id = selected_style
	_preview.configure(selected_class, selected_action, selected_facing)
	for style: String in _styles:
		_styles[style].set_pressed_no_signal(style == selected_style)
	for action: String in _motions:
		_motions[action].set_pressed_no_signal(action == selected_action)
	for direction: int in _directions:
		_directions[direction].set_pressed_no_signal(direction == selected_facing)

func _toggle_pause() -> void:
	_preview.playing = not _preview.playing
	_pause.text = "播放預覽" if not _preview.playing else "暫停預覽"

func start_journey() -> void:
	GameState.reset_new_game(false, selected_class, selected_style, selected_body)
	GameState.flags["intro_seen"] = true
	visible = false
	journey_started.emit()
	queue_free()

func continue_journey() -> void:
	if GameState.load_game():
		visible = false
		queue_free()
	else:
		_error.visible = true
		_error.text = "無法讀取存檔。可選擇職業開始新旅程。"
