extends CanvasLayer
## All controls edit a local draft; only starting a journey commits to GameState.
## Two steps share one stage: choose a vocation, then tune the look and set out.
signal journey_started
const Classes = preload("res://scripts/systems/hero_classes.gd")
const Style = preload("res://scripts/gameplay/hero_style.gd")
const Preview = preload("res://scripts/ui/hero_preview.gd")
const Stage = preload("res://scripts/ui/class_selection_ornament.gd")
const GOLD := Color("e8c889")
const MUTED := Color("92abc3")
const TEXT := Color("ecedf1")
const ICONS: Dictionary = {"traveler": "sword", "archer": "bow", "mage": "staff", "thief": "dagger"}
const EPITHETS: Dictionary = {"traveler": "WARRIOR", "archer": "ARCHER", "mage": "MAGE", "thief": "THIEF"}
const TAGS: Dictionary = {"traveler": "近戰 · 均衡 · 新手推薦", "archer": "遠程 · 貫穿 · 保持距離", "mage": "遠程 · 範圍 · 緩速控場", "thief": "近戰 · 高速連擊 · 背刺"}
const DIFFICULTY: Dictionary = {"traveler": 1, "archer": 2, "mage": 3, "thief": 2}
const STAT_NAMES: Array[String] = ["HP", "MP", "攻擊", "防禦"]
## Carousel order while the player has not picked a motion by hand.
const CYCLE: Array[String] = ["idle", "walk", "attack", "cast", "dodge"]
var selected_body: String = "male"
var selected_style: String = "original"
var selected_class: String = "traveler"
var selected_action: String = "idle"
var selected_facing: int = 0
var auto_cycle: bool = true
var _cycle_index: int = 0
var _cycle_left: float = 2.0
var _cycle: Button
var _choices: Dictionary[String, Button] = {}
var _bodies: Dictionary[String, Button] = {}
var _styles: Dictionary[String, Button] = {}
var _motions: Dictionary[String, Button] = {}
var _directions: Dictionary[int, Button] = {}
var _steps: Array[Button] = []
var _step: int = 0
var _stage: Control
var _margin: MarginContainer
var _body: BoxContainer
var _preview: Control
var _info_slide: MarginContainer
var _class_info: VBoxContainer
var _look_info: VBoxContainer
var _class_index: Label
var _class_title: Label
var _epithet: Label
var _tags: Label
var _details: Label
var _equipment: Label
var _skill: Label
var _style_note: Label
var _bars: Array[ProgressBar] = []
var _values: Array[Label] = []
var _stat_max: Array[int] = [1, 1, 1, 1]
var _brand: Label
var _roster: HBoxContainer
var _stage_column: VBoxContainer
var _control_rows: BoxContainer
var _footer: BoxContainer
var _hints: Label
var _start: Button
var _resume: Button
var _pause: Button
var _error: Label
var _fade: Tween
var _entrance: Tween

func _ready() -> void:
	layer = 100
	GameState.set_mode(GameState.Mode.CLASS_SELECTION)
	var backdrop := ColorRect.new()
	backdrop.color = Stage.INK
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.add_to_group("camera_touch_blocker")
	backdrop.theme = GameState.ui_theme
	add_child(backdrop)
	_stage = Stage.new()
	_stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.add_child(_stage)
	for id: String in Classes.ORDER:
		var values := _stat_values(id)
		for index: int in range(values.size()):
			_stat_max[index] = maxi(_stat_max[index], values[index])
	_margin = MarginContainer.new()
	_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.add_child(_margin)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_margin.add_child(scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 8)
	scroll.add_child(column)
	_build_header(column)
	_body = BoxContainer.new()
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 24)
	column.add_child(_body)
	_build_stage_column()
	_info_slide = MarginContainer.new()
	_info_slide.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_info_slide.custom_minimum_size.x = 340
	_body.add_child(_info_slide)
	var info := VBoxContainer.new()
	_info_slide.add_child(info)
	_build_class_info(info)
	_build_look_info(info)
	_build_footer(column)
	_error = _label("", 16, Color("ffb6a0"))
	_error.visible = false
	column.add_child(_error)
	get_viewport().size_changed.connect(_layout)
	_layout()
	select_class(selected_class)
	set_step(0)
	_choices[selected_class].grab_focus()

func _build_header(column: VBoxContainer) -> void:
	var header := HBoxContainer.new()
	header.custom_minimum_size.y = 44
	header.add_theme_constant_override("separation", 12)
	column.add_child(header)
	_brand = _label("月光碎片 · WANDERLIGHT", 18, GOLD)
	_brand.autowrap_mode = TextServer.AUTOWRAP_OFF
	_brand.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_brand)
	var steps := HBoxContainer.new()
	steps.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	steps.alignment = BoxContainer.ALIGNMENT_CENTER
	steps.add_theme_constant_override("separation", 4)
	header.add_child(steps)
	for index: int in range(2):
		if index > 0:
			var line := _label("──", 14, Color(GOLD, 0.45))
			line.autowrap_mode = TextServer.AUTOWRAP_OFF
			steps.add_child(line)
		var tab := Button.new()
		tab.text = ["①  職業", "②  外觀"][index]
		tab.toggle_mode = true
		tab.focus_mode = Control.FOCUS_NONE
		tab.add_theme_font_override("font", GameState.title_font)
		tab.add_theme_font_size_override("font_size", 17)
		tab.add_theme_color_override("font_color", MUTED)
		for state: String in ["font_pressed_color", "font_hover_color", "font_hover_pressed_color"]:
			tab.add_theme_color_override(state, GOLD)
		for state: String in ["normal", "hover", "pressed", "hover_pressed", "focus"]:
			var style := StyleBoxFlat.new()
			style.bg_color = Color.TRANSPARENT
			style.border_color = GOLD
			style.border_width_bottom = 2 if state in ["pressed", "hover_pressed"] else 0
			style.set_content_margin_all(6)
			tab.add_theme_stylebox_override(state, style)
		tab.pressed.connect(set_step.bind(index))
		steps.add_child(tab)
		_steps.append(tab)
	var right := HBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.alignment = BoxContainer.ALIGNMENT_END
	header.add_child(right)
	_resume = _chip("繼續存檔", right, continue_journey)
	_resume.icon = load("res://assets/ui/class_selection/book.svg")
	_resume.add_theme_constant_override("icon_max_width", 20)
	_resume.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_resume.visible = GameState.has_save_file()

func _build_stage_column() -> void:
	var left := VBoxContainer.new()
	_stage_column = left
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 1.3
	left.add_theme_constant_override("separation", 6)
	_body.add_child(left)
	_preview = Preview.new()
	_preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left.add_child(_preview)
	_control_rows = BoxContainer.new()
	_control_rows.alignment = BoxContainer.ALIGNMENT_CENTER
	_control_rows.add_theme_constant_override("separation", 16)
	left.add_child(_control_rows)
	var controls := _chip_row()
	var names := {"idle": "待機", "walk": "走路", "attack": "攻擊", "cast": "施法", "dodge": "閃避"}
	for action: String in names:
		var button := _chip(str(names[action]), controls, select_action.bind(action))
		button.toggle_mode = true
		_motions[action] = button
	_cycle = _chip("輪播", controls, _toggle_cycle)
	_cycle.toggle_mode = true
	_cycle.set_pressed_no_signal(auto_cycle)
	_cycle.tooltip_text = "自動輪播各種動作"
	_pause = _chip("暫停", controls, _toggle_pause)
	controls = _chip_row()
	for direction: int in range(4):
		var button := _chip(["正", "右", "背", "左"][direction], controls, select_facing.bind(direction))
		button.toggle_mode = true
		button.tooltip_text = ["正面", "右側", "背面", "左側"][direction] + "（Q／E 旋轉）"
		_directions[direction] = button

func _chip_row() -> HFlowContainer:
	var row := HFlowContainer.new()
	row.alignment = FlowContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("h_separation", 4)
	row.add_theme_constant_override("v_separation", 4)
	# Side by side, the motion row needs roughly twice the facing row's width.
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.size_flags_stretch_ratio = 1.0 if _control_rows.get_child_count() > 0 else 2.0
	_control_rows.add_child(row)
	return row

func _build_class_info(parent: VBoxContainer) -> void:
	_class_info = VBoxContainer.new()
	_class_info.add_theme_constant_override("separation", 6)
	parent.add_child(_class_info)
	_class_index = _label("", 13, MUTED)
	_class_info.add_child(_class_index)
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 14)
	_class_info.add_child(title_row)
	_class_title = _label("", 52, GOLD)
	_class_title.autowrap_mode = TextServer.AUTOWRAP_OFF
	title_row.add_child(_class_title)
	_epithet = _label("", 18, MUTED)
	_epithet.size_flags_vertical = Control.SIZE_SHRINK_END
	_epithet.autowrap_mode = TextServer.AUTOWRAP_OFF
	title_row.add_child(_epithet)
	_tags = _label("", 15, TEXT)
	_class_info.add_child(_tags)
	_details = _label("", 16, TEXT)
	_class_info.add_child(_details)
	_equipment = _label("", 14, MUTED)
	_class_info.add_child(_equipment)
	var stats := GridContainer.new()
	stats.columns = 3
	stats.add_theme_constant_override("h_separation", 12)
	stats.add_theme_constant_override("v_separation", 6)
	_class_info.add_child(stats)
	for stat: String in STAT_NAMES:
		var caption := _label(stat, 15, MUTED)
		caption.custom_minimum_size.x = 40
		stats.add_child(caption)
		var bar := ProgressBar.new()
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(0, 10)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var groove := StyleBoxFlat.new()
		groove.bg_color = Color(1, 1, 1, 0.08)
		groove.set_corner_radius_all(3)
		bar.add_theme_stylebox_override("background", groove)
		stats.add_child(bar)
		_bars.append(bar)
		var value := _label("", 17, TEXT)
		value.custom_minimum_size.x = 38
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		stats.add_child(value)
		_values.append(value)
	var skill_row := HBoxContainer.new()
	skill_row.add_theme_constant_override("separation", 10)
	_class_info.add_child(skill_row)
	var moon := TextureRect.new()
	moon.texture = load("res://assets/ui/class_selection/moon.svg")
	moon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	moon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	moon.custom_minimum_size = Vector2(40, 40)
	skill_row.add_child(moon)
	_skill = _label("", 16, GOLD)
	_skill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	skill_row.add_child(_skill)

func _build_look_info(parent: VBoxContainer) -> void:
	_look_info = VBoxContainer.new()
	_look_info.add_theme_constant_override("separation", 10)
	parent.add_child(_look_info)
	_look_info.add_child(_label("STEP 2 / 2", 13, MUTED))
	_look_info.add_child(_label("外觀", 52, GOLD))
	_look_info.add_child(_label("性別與配色只改變外觀，不影響能力。", 15, TEXT))
	_look_info.add_child(_label("體型", 15, MUTED))
	var bodies := HBoxContainer.new()
	bodies.add_theme_constant_override("separation", 8)
	_look_info.add_child(bodies)
	for id: String in GameState.HERO_BODIES:
		var button := _chip("男性" if id == "male" else "女性", bodies, select_body.bind(id))
		button.custom_minimum_size = Vector2(108, 44)
		button.toggle_mode = true
		_bodies[id] = button
	_look_info.add_child(_label("髮色與服裝配色", 15, MUTED))
	var styles := HFlowContainer.new()
	styles.add_theme_constant_override("h_separation", 8)
	styles.add_theme_constant_override("v_separation", 8)
	_look_info.add_child(styles)
	for id: String in Style.ORDER:
		var button := _chip(str(Style.DATA[id].name), styles, select_style.bind(id))
		button.toggle_mode = true
		button.custom_minimum_size.y = 48
		button.icon = load("res://assets/ui/class_selection/%s.svg" % id)
		button.tooltip_text = str(Style.DATA[id].description)
		_styles[id] = button
	_style_note = _label("", 14, MUTED)
	_look_info.add_child(_style_note)

func _build_footer(column: VBoxContainer) -> void:
	_footer = BoxContainer.new()
	_footer.add_theme_constant_override("separation", 16)
	column.add_child(_footer)
	_roster = HBoxContainer.new()
	_roster.add_theme_constant_override("separation", 8)
	_roster.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_footer.add_child(_roster)
	for id: String in Classes.ORDER:
		var button := Button.new()
		button.text = str(Classes.profile(id).name)
		button.toggle_mode = true
		button.icon = load("res://assets/ui/class_selection/%s.svg" % ICONS[id])
		button.expand_icon = true
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		button.add_theme_constant_override("icon_max_width", 34)
		button.add_theme_font_override("font", GameState.title_font)
		button.add_theme_font_size_override("font_size", 15)
		button.add_theme_color_override("font_color", MUTED)
		for state: String in ["font_pressed_color", "font_hover_color", "font_hover_pressed_color", "font_focus_color"]:
			button.add_theme_color_override(state, GOLD)
		_style_button(button, true)
		button.pressed.connect(select_class.bind(id))
		button.focus_entered.connect(select_class.bind(id))
		# Keyboard confirm on the roster advances; a mouse click only selects.
		button.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventKey and event.is_action_pressed("ui_accept"):
				button.accept_event()
				_advance())
		_roster.add_child(button)
		_choices[id] = button
	_start = _button("", _footer, _advance)
	_start.custom_minimum_size = Vector2(320, 56)
	_start.add_theme_font_size_override("font_size", 22)
	_start.add_theme_color_override("font_color", Color("152131"))
	_start.add_theme_color_override("font_hover_color", Color("152131"))
	_start.add_theme_color_override("font_focus_color", Color("152131"))
	_start.add_theme_color_override("font_pressed_color", Color("152131"))
	for state: String in ["normal", "hover", "pressed", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = GOLD.lightened(0.12) if state in ["hover", "focus"] else GOLD
		style.border_color = Color("fff0be")
		style.set_border_width_all(2)
		style.set_corner_radius_all(6)
		style.set_content_margin_all(10)
		if state == "focus":
			style.shadow_color = Color(GOLD, 0.45)
			style.shadow_size = 8
		_start.add_theme_stylebox_override(state, style)
	_hints = _label("←→ 切換職業　Q／E 旋轉角色　Enter 確認　Esc 返回", 13, Color(MUTED, 0.8))
	_hints.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	column.add_child(_hints)

func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", GameState.title_font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label

func _style_button(button: Button, roster: bool) -> void:
	for state: String in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		var active: bool = state in ["pressed", "hover_pressed"]
		var style := StyleBoxFlat.new()
		style.bg_color = Color.TRANSPARENT if state == "focus" else Color(GOLD, 0.16) if active else Color(1, 1, 1, 0.08) if state == "hover" else Color(0.03, 0.08, 0.13, 0.62)
		style.border_color = Color("f7dea3") if state == "focus" else GOLD if active else Color(1, 1, 1, 0.14)
		style.set_border_width_all(2 if state == "focus" else 1)
		if roster and active:
			style.border_width_bottom = 3
		style.set_corner_radius_all(6 if roster else 16)
		style.content_margin_left = 12 if roster else 9
		style.content_margin_right = 12 if roster else 9
		style.content_margin_top = 8 if roster else 5
		style.content_margin_bottom = 6 if roster else 5
		button.add_theme_stylebox_override(state, style)

func _chip(text: String, parent: Node, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_font_override("font", GameState.title_font)
	button.add_theme_font_size_override("font_size", 14)
	button.add_theme_color_override("font_color", TEXT)
	button.add_theme_color_override("font_pressed_color", GOLD)
	button.add_theme_color_override("font_hover_pressed_color", GOLD)
	button.custom_minimum_size = Vector2(44, 36)
	_style_button(button, false)
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _button(text: String, parent: Node, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.add_theme_font_override("font", GameState.title_font)
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _layout() -> void:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	var narrow: bool = viewport_size.x < 900
	var inset: int = 16 if narrow else maxi(30, int(viewport_size.x * 0.04))
	for side: String in ["left", "right"]:
		_margin.add_theme_constant_override("margin_" + side, inset)
	_margin.add_theme_constant_override("margin_top", 12)
	_margin.add_theme_constant_override("margin_bottom", 12)
	_stage.narrow = narrow
	_preview.framed = narrow
	_brand.visible = not narrow
	_hints.visible = not narrow
	_body.vertical = narrow
	_footer.vertical = narrow
	_control_rows.vertical = viewport_size.x < 1100
	# Phones scroll, so the roster moves up to sit under the hero it changes.
	var roster_parent: Node = _stage_column if narrow else _footer
	if _roster.get_parent() != roster_parent:
		_roster.reparent(roster_parent, false)
		if not narrow:
			_footer.move_child(_roster, 0)
	_start.custom_minimum_size.x = 0 if narrow else 320
	_preview.custom_minimum_size = Vector2(260, 300 if narrow else maxf(240, viewport_size.y - 290))
	for id: String in _choices:
		_choices[id].custom_minimum_size = Vector2(0, 68) if narrow else Vector2(104, 72)
		_choices[id].size_flags_horizontal = Control.SIZE_EXPAND_FILL if narrow else Control.SIZE_FILL

func set_step(step: int) -> void:
	_step = clampi(step, 0, 1)
	for index: int in range(_steps.size()):
		_steps[index].set_pressed_no_signal(index == _step)
	_class_info.visible = _step == 0
	_look_info.visible = _step == 1
	_refresh_start()
	_fade_in(_class_info if _step == 0 else _look_info)

func _advance() -> void:
	if _step == 0:
		set_step(1)
		_start.grab_focus()
	else:
		start_journey()

func _refresh_start() -> void:
	var profile := Classes.profile(selected_class)
	_start.text = "下一步 · 外觀  ›" if _step == 0 else "以%s開始旅程  ›" % profile.name

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and _step == 1:
		set_step(0)
		_choices[selected_class].grab_focus()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_Q, KEY_E]:
		select_facing(posmod(selected_facing + (1 if event.keycode == KEY_E else -1), 4))
		get_viewport().set_input_as_handled()

func _stat_values(id: String) -> Array[int]:
	var profile := Classes.profile(id)
	var defaults: Dictionary = GameState.ClassEquipment.defaults(id)
	var weapon: Dictionary = GameState.EQUIPMENT_CATALOG[defaults.weapon]
	var armor: Dictionary = GameState.EQUIPMENT_CATALOG[defaults.armor]
	return [int(profile.hp), int(profile.mp), int(profile.attack) + int(weapon.attack), int(profile.defense) + int(armor.defense)]

func select_class(id: String) -> void:
	if not Classes.DATA.has(id):
		return
	var changed: bool = id != selected_class
	var side: float = signf(Classes.ORDER.find(id) - Classes.ORDER.find(selected_class))
	selected_class = id
	for choice: String in _choices:
		_choices[choice].set_pressed_no_signal(choice == id)
	var profile := Classes.profile(id)
	var accent: Color = profile.color
	var defaults: Dictionary = GameState.ClassEquipment.defaults(id)
	_class_index.text = "CLASS %02d / %02d" % [Classes.ORDER.find(id) + 1, Classes.ORDER.size()]
	_class_title.text = str(profile.name)
	_epithet.text = EPITHETS[id]
	_tags.text = "%s　　難度 %s" % [TAGS[id], "★".repeat(DIFFICULTY[id]) + "☆".repeat(3 - DIFFICULTY[id])]
	_details.text = str(profile.description)
	_equipment.text = "初始裝備　%s ／ %s" % [GameState.EQUIPMENT_CATALOG[defaults.weapon].name, GameState.EQUIPMENT_CATALOG[defaults.armor].name]
	var values := _stat_values(id)
	var tween: Tween = create_tween().set_parallel().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	for index: int in range(_bars.size()):
		_values[index].text = str(values[index])
		var fill := StyleBoxFlat.new()
		fill.bg_color = accent
		fill.set_corner_radius_all(3)
		_bars[index].add_theme_stylebox_override("fill", fill)
		_bars[index].max_value = _stat_max[index]
		tween.tween_property(_bars[index], "value", float(values[index]), 0.3)
	_skill.text = "%s\n%d MP · 冷卻 %.1f 秒" % [profile.skill, profile.cost, profile.cooldown]
	tween.tween_property(_stage, "accent", accent, 0.35)
	tween.tween_property(_preview, "accent", accent, 0.35)
	_stage.epithet = EPITHETS[id]
	_refresh_start()
	if changed:
		_play_entrance(side)
		if _step == 0:
			_fade_in(_class_info)
		if auto_cycle:
			var signature: String = "cast" if id == "mage" else "attack"
			_cycle_index = CYCLE.find(signature)
			_play_cycle(signature)
			return
	_refresh_preview()

func _play_entrance(side: float) -> void:
	if _entrance != null:
		_entrance.kill()
	_preview.entrance_side = side
	_preview.entrance = 0.0
	_entrance = create_tween().set_parallel().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_entrance.tween_property(_preview, "entrance", 1.0, 0.4)
	_entrance.tween_method(_slide_info, 32.0 * side, 0.0, 0.3)

func _slide_info(offset: float) -> void:
	# Only inset margins, so the column never slides past the screen edge.
	_info_slide.add_theme_constant_override("margin_left", maxi(0, int(offset)))
	_info_slide.add_theme_constant_override("margin_right", maxi(0, -int(offset)))

func _fade_in(panel: Control) -> void:
	if _fade != null:
		_fade.kill()
	panel.modulate.a = 0.0
	_fade = create_tween()
	_fade.tween_property(panel, "modulate:a", 1.0, 0.18)

func select_body(id: String) -> void:
	if id not in GameState.HERO_BODIES:
		return
	selected_body = id
	_refresh_preview()

func select_style(id: String) -> void:
	if not Style.DATA.has(id):
		return
	selected_style = id
	_refresh_preview()

func select_action(action: String) -> void:
	if not Preview.SEQUENCES.has(action):
		return
	_set_auto_cycle(false)
	selected_action = action
	_refresh_preview()

func _process(delta: float) -> void:
	if not auto_cycle or not _preview.playing:
		return
	_cycle_left -= delta
	if _cycle_left <= 0.0:
		_cycle_index = (_cycle_index + 1) % CYCLE.size()
		_play_cycle(CYCLE[_cycle_index])

func _play_cycle(action: String) -> void:
	selected_action = action
	# Hold each motion for at least two seconds or two full loops.
	_cycle_left = maxf(2.0, Preview.SEQUENCES[action].size() / 6.0 * 2.0)
	_refresh_preview()

func _set_auto_cycle(enabled: bool) -> void:
	auto_cycle = enabled
	_cycle.set_pressed_no_signal(enabled)

func _toggle_cycle() -> void:
	_set_auto_cycle(not auto_cycle)
	if auto_cycle:
		if not _preview.playing:
			_toggle_pause()
		_cycle_index = 0
		_play_cycle(CYCLE[0])

func select_facing(direction: int) -> void:
	selected_facing = clampi(direction, 0, 3)
	_refresh_preview()

func _refresh_preview() -> void:
	_preview.body_id = selected_body
	_preview.style_id = selected_style
	_preview.configure(selected_class, selected_action, selected_facing)
	_style_note.text = str(Style.DATA[selected_style].description)
	for body: String in _bodies:
		_bodies[body].set_pressed_no_signal(body == selected_body)
	for style: String in _styles:
		_styles[style].set_pressed_no_signal(style == selected_style)
	for action: String in _motions:
		_motions[action].set_pressed_no_signal(action == selected_action)
	for direction: int in _directions:
		_directions[direction].set_pressed_no_signal(direction == selected_facing)

func _toggle_pause() -> void:
	_preview.playing = not _preview.playing
	_pause.text = "播放" if not _preview.playing else "暫停"

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
