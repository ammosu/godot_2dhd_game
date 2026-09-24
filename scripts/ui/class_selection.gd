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

func _ready() -> void:
	layer = 100
	GameState.set_mode(GameState.Mode.CLASS_SELECTION)
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.04, 0.08, 0.14, 0.96)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.add_to_group("camera_touch_blocker")
	backdrop.theme = GameState.ui_theme
	add_child(backdrop)
	_margin = MarginContainer.new()
	_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		_margin.add_theme_constant_override("margin_" + side, 20)
	backdrop.add_child(_margin)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_margin.add_child(scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 8)
	scroll.add_child(column)
	var title := Label.new()
	title.text = "月光碎片 · 你的旅人"
	title.theme_type_variation = "TitleLabel"
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color("e6c58b"))
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(title)
	var choices := HFlowContainer.new()
	choices.add_theme_constant_override("h_separation", 10)
	column.add_child(choices)
	for id: String in Classes.ORDER:
		var button := _button(str(Classes.profile(id).name), choices, select_class.bind(id))
		button.custom_minimum_size = Vector2(140, 48)
		button.toggle_mode = true
		_choices[id] = button
	_body = BoxContainer.new()
	_body.add_theme_constant_override("separation", 24)
	column.add_child(_body)
	_preview = Preview.new()
	_preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_child(_preview)
	_settings = VBoxContainer.new()
	_settings.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_settings.add_theme_constant_override("separation", 10)
	_body.add_child(_settings)
	_details = Label.new()
	_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_details.add_theme_font_size_override("font_size", 18)
	_details.add_theme_constant_override("line_spacing", 3)
	_settings.add_child(_details)
	_build_body_controls()
	_build_style_controls()
	var motion_row := HFlowContainer.new()
	motion_row.add_theme_constant_override("h_separation", 8)
	column.add_child(motion_row)
	var names := {"idle": "待機", "walk": "走路", "attack": "攻擊", "cast": "施法", "dodge": "閃避"}
	for action: String in names:
		var button := _button(str(names[action]), motion_row, select_action.bind(action))
		button.toggle_mode = true
		_motions[action] = button
	_pause = _button("暫停預覽", motion_row, _toggle_pause)
	var directions := HFlowContainer.new()
	directions.add_theme_constant_override("h_separation", 8)
	column.add_child(directions)
	for direction: int in range(4):
		var button := _button(["正面", "右側", "背面", "左側"][direction], directions, select_facing.bind(direction))
		button.toggle_mode = true
		_directions[direction] = button
	var note := Label.new()
	note.text = "預覽不消耗 MP，也不會改動現有旅程。"
	note.add_theme_color_override("font_color", Color("9eafba"))
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(note)
	_start = _button("", column, start_journey)
	_start.custom_minimum_size.y = 50
	var resume := _button("繼續存檔", column, continue_journey)
	resume.disabled = not GameState.has_save_file()
	_error = Label.new()
	_error.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_error.add_theme_color_override("font_color", Color("ffb6a0"))
	_error.visible = false
	column.add_child(_error)
	get_viewport().size_changed.connect(_layout)
	_layout()
	select_class(selected_class)
	_choices[selected_class].grab_focus()

func _build_body_controls() -> void:
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 8)
	_settings.add_child(row)
	for id: String in GameState.HERO_BODIES:
		var button := _button("男性" if id == "male" else "女性", row, select_body.bind(id))
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
	label.add_theme_color_override("font_color", Color("e6c58b"))
	_settings.add_child(label)
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 8)
	_settings.add_child(row)
	for id: String in Style.ORDER:
		var button := _button(str(Style.DATA[id].name), row, select_style.bind(id))
		button.toggle_mode = true
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
	button.custom_minimum_size = Vector2(80, 40)
	button.add_theme_font_size_override("font_size", 18)
	for state: String in ["normal", "hover", "pressed", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color.TRANSPARENT if state == "focus" else Color("304e59") if state in ["pressed", "hover"] else Color("182737")
		style.border_color = Color("e6c58b") if state == "pressed" else Color("a1e6dd") if state == "focus" else Color("476074")
		style.set_border_width_all(2 if state in ["focus", "pressed"] else 1)
		style.set_content_margin_all(8)
		style.set_corner_radius_all(4)
		button.add_theme_stylebox_override(state, style)
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _layout() -> void:
	var width: float = get_viewport().get_visible_rect().size.x
	var inset: int = maxi(20, int((width - 1060.0) * 0.5))
	_margin.add_theme_constant_override("margin_left", inset)
	_margin.add_theme_constant_override("margin_right", inset)
	_body.vertical = width < 760

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
	_details.text = "%s\n%s\n%s ／ %s\nHP %d    MP %d    攻擊 %d    防禦 %d\n%s · %d MP · 冷卻 %.1f 秒" % [profile.name, profile.description, weapon.name, armor.name, profile.hp, profile.mp, int(profile.attack) + int(weapon.attack), int(profile.defense) + int(armor.defense), profile.skill, profile.cost, profile.cooldown]
	_start.text = "以%s開始旅程" % profile.name
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
