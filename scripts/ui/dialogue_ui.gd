class_name DialogueUI
extends CanvasLayer

var _root: Control
var _speaker_label: Label
var _body_label: Label
var _lines: Array = []
var _line_index: int = 0
var _finished_callback: Callable


func _ready() -> void:
	layer = 60
	_build_ui()


func show_dialogue(lines: Array, finished_callback: Callable = Callable()) -> void:
	if lines.is_empty():
		if finished_callback.is_valid():
			finished_callback.call()
		return
	_lines = lines.duplicate(true)
	_line_index = 0
	_finished_callback = finished_callback
	_root.visible = true
	GameState.set_mode(GameState.Mode.DIALOGUE)
	_show_current_line()


func advance() -> void:
	if not _root.visible:
		return
	_line_index += 1
	if _line_index >= _lines.size():
		_finish_dialogue()
	else:
		_show_current_line()


func is_open() -> bool:
	return _root.visible


func _unhandled_input(event: InputEvent) -> void:
	if not _root.visible or event.is_echo():
		return
	if event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
		advance()
		get_viewport().set_input_as_handled()


func _show_current_line() -> void:
	var line: Dictionary = _lines[_line_index]
	_speaker_label.text = str(line.get("speaker", ""))
	_body_label.text = str(line.get("text", ""))


func _finish_dialogue() -> void:
	_root.visible = false
	GameState.set_mode(GameState.Mode.EXPLORE)
	var callback := _finished_callback
	_finished_callback = Callable()
	if callback.is_valid():
		callback.call()


func _build_ui() -> void:
	_root = Control.new()
	_root.name = "DialogueRoot"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.02, 0.02, 0.05, 0.22)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(shade)

	var panel := PanelContainer.new()
	panel.anchor_left = 0.08
	panel.anchor_top = 0.68
	panel.anchor_right = 0.92
	panel.anchor_bottom = 0.94
	panel.offset_left = 0.0
	panel.offset_top = 0.0
	panel.offset_right = 0.0
	panel.offset_bottom = 0.0
	_root.add_child(panel)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.045, 0.09, 0.96)
	style.border_color = Color("d6a65e")
	style.set_border_width_all(3)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(22.0)
	panel.add_theme_stylebox_override("panel", style)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	panel.add_child(content)

	_speaker_label = Label.new()
	_speaker_label.add_theme_color_override("font_color", Color("f2b866"))
	_speaker_label.add_theme_font_size_override("font_size", 22)
	content.add_child(_speaker_label)

	_body_label = Label.new()
	_body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body_label.add_theme_color_override("font_color", Color("fff2d2"))
	_body_label.add_theme_font_size_override("font_size", 20)
	content.add_child(_body_label)

	var hint := Label.new()
	hint.text = "Space / Enter：繼續"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint.add_theme_color_override("font_color", Color("b8a9bc"))
	content.add_child(hint)
	_root.visible = false
