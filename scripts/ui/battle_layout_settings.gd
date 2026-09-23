extends ConfirmationDialog
signal layout_saved(layout: Dictionary)
const Layout = preload("res://scripts/systems/battle_control_layout.gd")
const Dock = preload("res://scripts/ui/battle_radial_dock.gd")
var preferences: RefCounted
var draft: Dictionary = {}
var preview_dock: Control
var sliders: Dictionary = {}
var value_labels: Dictionary = {}
var slots: Array[OptionButton] = []
var labels_toggle: CheckButton
var message: Label

func _ready() -> void:
	title = "戰鬥操作配置"
	borderless = true
	exclusive = true
	unresizable = true
	dialog_hide_on_ok = false
	ok_button_text = "儲存配置"
	cancel_button_text = "取消"
	theme = theme.duplicate()
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color("111d2b")
	panel.border_color = Color("7896a8")
	panel.set_border_width_all(1)
	panel.set_corner_radius_all(12)
	panel.set_content_margin_all(20)
	theme.set_stylebox("panel", "AcceptDialog", panel)
	for button: Button in [get_ok_button(), get_cancel_button()]:
		button.custom_minimum_size = Vector2(160, 46)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	add_child(content)
	var heading := Label.new()
	heading.text = "戰鬥操作配置"
	heading.add_theme_font_size_override("font_size", 26)
	content.add_child(heading)
	var note := Label.new()
	note.text = "普攻位於右下角；其他操作沿圓弧排列。調整後按儲存套用。"
	note.add_theme_font_size_override("font_size", 16)
	content.add_child(note)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 24)
	content.add_child(columns)
	var form := VBoxContainer.new()
	form.custom_minimum_size.x = 400
	form.add_theme_constant_override("separation", 8)
	columns.add_child(form)
	for key: String in ["size", "radius", "inset_x", "inset_y"]:
		var row := HBoxContainer.new()
		row.custom_minimum_size.y = 44
		form.add_child(row)
		var label := Label.new()
		label.text = {"size": "按鈕大小", "radius": "圓弧間距", "inset_x": "向左移動", "inset_y": "向上移動"}[key]
		label.custom_minimum_size.x = 90
		row.add_child(label)
		var slider := HSlider.new()
		slider.custom_minimum_size = Vector2(210, 40)
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.min_value = Layout.LIMITS[key].x
		slider.max_value = Layout.LIMITS[key].y
		slider.step = 0.05 if key == "size" else 2.0
		row.add_child(slider)
		sliders[key] = slider
		var value := Label.new()
		value.custom_minimum_size.x = 56
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(value)
		value_labels[key] = value
		slider.value_changed.connect(func(number: float) -> void:
			draft[key] = number
			_update_preview()
		)
	var order_heading := Label.new()
	order_heading.text = "圓弧順序（由左至上）"
	form.add_child(order_heading)
	var order_grid := GridContainer.new()
	order_grid.columns = 2
	order_grid.add_theme_constant_override("h_separation", 8)
	order_grid.add_theme_constant_override("v_separation", 8)
	form.add_child(order_grid)
	for index: int in range(4):
		var option := OptionButton.new()
		option.custom_minimum_size = Vector2(196, 44)
		for action: String in Layout.DEFAULTS.order:
			option.add_item("%d  %s" % [index + 1, Dock.CAPTIONS[action]])
		option.item_selected.connect(func(item: int) -> void: _swap_slot(index, item))
		order_grid.add_child(option)
		slots.append(option)
	labels_toggle = CheckButton.new()
	labels_toggle.text = "顯示按鈕名稱"
	labels_toggle.custom_minimum_size.y = 42
	labels_toggle.toggled.connect(func(enabled: bool) -> void:
		draft.labels = enabled
		_update_preview()
	)
	form.add_child(labels_toggle)
	var reset := Button.new()
	reset.text = "恢復預設配置"
	reset.custom_minimum_size.y = 42
	reset.pressed.connect(reset_draft)
	form.add_child(reset)
	var preview_column := VBoxContainer.new()
	columns.add_child(preview_column)
	var preview_label := Label.new()
	preview_label.text = "即時預覽"
	preview_label.add_theme_color_override("font_color", Color("9feaff"))
	preview_column.add_child(preview_label)
	preview_dock = Dock.new()
	preview_dock.preview = true
	preview_dock.custom_minimum_size = Vector2(408, 408)
	preview_column.add_child(preview_dock)
	var preview_note := Label.new()
	preview_note.text = "技能圖示會隨操作角色切換。"
	preview_note.add_theme_font_size_override("font_size", 14)
	preview_column.add_child(preview_note)
	message = Label.new()
	message.add_theme_font_size_override("font_size", 14)
	message.text = "配置會保留至下次開啟遊戲；取消不會修改目前配置。"
	content.add_child(message)
	confirmed.connect(save_draft)

func open_layout(store: RefCounted, controlled: int) -> void:
	preferences = store
	draft = preferences.values.duplicate(true)
	preview_dock.buttons.skill.glyph = ["moon", "ward", "frost"][controlled]
	preview_dock.buttons.skill.caption = ["月影斬", "守護", "霜星爆"][controlled]
	for index: int in range(slots.size()):
		slots[index].set_item_text(2, "%d  %s" % [index + 1, preview_dock.buttons.skill.caption])
	message.text = "配置會保留至下次開啟遊戲；取消不會修改目前配置。"
	_sync_form()
	popup_centered()
	get_cancel_button().grab_focus()

func _swap_slot(index: int, selected: int) -> void:
	var action: String = Layout.DEFAULTS.order[selected]
	var previous: int = draft.order.find(action)
	var displaced: String = draft.order[index]
	draft.order[index] = action
	draft.order[previous] = displaced
	_sync_form()

func reset_draft() -> void:
	draft = Layout.DEFAULTS.duplicate(true)
	_sync_form()

func _sync_form() -> void:
	for key: String in sliders:
		sliders[key].set_value_no_signal(draft[key])
	for index: int in range(4):
		slots[index].select(Layout.DEFAULTS.order.find(draft.order[index]))
	labels_toggle.set_pressed_no_signal(bool(draft.labels))
	_update_preview()

func _update_preview() -> void:
	for key: String in value_labels:
		value_labels[key].text = "%d%%" % roundi(float(draft[key]) * 100.0) if key == "size" else "%d" % roundi(draft[key])
	preview_dock.apply_layout(draft)

func save_draft() -> void:
	if preferences.save_preferences(draft) != OK:
		message.text = "無法儲存配置，請確認儲存空間後再試一次。"
		return
	layout_saved.emit(preferences.values.duplicate(true))
	hide()
