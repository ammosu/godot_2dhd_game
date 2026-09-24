class_name DialogueUI
extends CanvasLayer

signal page_shown(index: int)

const Cinematic = preload("res://scripts/ui/dialogue_cinematic.gd")

var _cinematic: Control
var _panel: PanelContainer
var _root: Control
var _speaker_label: Label
var _body_label: Label
var _hint_label: Label
var _illustration: TextureRect
var _lines: Array = []
var _line_index: int = 0
var _finished_callback: Callable
var _motion: String = ""
var _motion_elapsed: float = 0.0


func _process(delta: float) -> void:
	if _motion == "awakening" and _illustration.material != null:
		_motion_elapsed += delta
		var opened: float = smoothstep(0.25, 1.45, _motion_elapsed)
		(_illustration.material as ShaderMaterial).set_shader_parameter("openness", opened)


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


func _input(event: InputEvent) -> void:
	if not is_open() or not event is InputEventScreenTouch:
		return
	# Dialogue is modal: panel/HUD hit testing must not swallow taps. Consume
	# before advancing, since the last page can immediately change game mode.
	get_viewport().set_input_as_handled()
	if event.pressed and not event.canceled:
		advance()


func _unhandled_input(event: InputEvent) -> void:
	if not _root.visible or event.is_echo():
		return
	if (
		event.is_action_pressed("interact")
		or event.is_action_pressed("ui_accept")
	):
		advance()
		get_viewport().set_input_as_handled()


func _show_current_line() -> void:
	_stop_cinematic()
	GameAudio.play_cue(&"dialogue")
	var line: Dictionary = _lines[_line_index]
	_illustration.texture = line.get("illustration") as Texture2D
	_illustration.visible = _illustration.texture != null
	var next_motion: String = str(line.get("motion", "")) if _illustration.visible else ""
	if next_motion != _motion:
		_motion = next_motion
		_motion_elapsed = 0.0
		_illustration.material = null
		if _motion == "awakening":
			var material := ShaderMaterial.new()
			material.shader = preload("res://shaders/fog_awakening.gdshader")
			material.set_shader_parameter("closed_texture", load("res://assets/generated/fog_awakening_closed.png"))
			material.set_shader_parameter("openness", 0.0)
			_illustration.material = material
	_speaker_label.text = str(line.get("speaker", ""))
	_body_label.text = str(line.get("text", ""))
	if str(line.get("cinematic", "")) == "moon_memory" and _illustration.texture != null:
		layer = 100 # Keep arrival notices behind the cinematic insert.
		_panel.hide()
		_cinematic.play(_illustration.texture)
	_hint_label.text = "%02d / %02d   ·   %s" % [_line_index + 1, _lines.size(), "點一下繼續" if MobileControls.is_mobile_device() else "Space / Enter  繼續"]
	page_shown.emit(_line_index)


func _finish_dialogue() -> void:
	_root.visible = false
	clear_illustration()
	GameState.set_mode(GameState.Mode.EXPLORE)
	var callback := _finished_callback
	_finished_callback = Callable()
	if callback.is_valid():
		callback.call()


func _stop_cinematic() -> void:
	layer = 60
	_cinematic.stop()
	_panel.show()


func clear_illustration() -> void:
	_stop_cinematic()
	_motion = ""
	_motion_elapsed = 0.0
	_illustration.material = null
	_illustration.texture = null
	_illustration.hide()
	# Do not retain pictures in a completed or abandoned dialogue.
	for line: Dictionary in _lines:
		line.erase("illustration")


func _build_ui() -> void:
	_root = Control.new()
	_root.name = "DialogueRoot"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = GameState.ui_theme
	add_child(_root)

	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.02, 0.02, 0.05, 0.22)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(shade)

	_illustration = TextureRect.new()
	_illustration.name = "MemoryIllustration"
	_illustration.anchor_left = 0.20
	_illustration.anchor_top = 0.16
	_illustration.anchor_right = 0.80
	_illustration.anchor_bottom = 0.65
	_illustration.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_illustration.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_illustration.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_illustration.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_illustration.hide()
	_root.add_child(_illustration)

	var panel := PanelContainer.new()
	_panel = panel
	panel.anchor_left = 0.06
	panel.anchor_top = 1.0
	panel.anchor_right = 0.94
	panel.anchor_bottom = 1.0
	panel.offset_left = 0.0
	panel.offset_top = -214.0
	panel.offset_right = 0.0
	panel.offset_bottom = -24.0
	panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_root.add_child(panel)

	var style := preload("res://scripts/ui/presentation_theme.gd").panel(22)
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
	_body_label.add_theme_constant_override("line_spacing", 5)
	content.add_child(_body_label)

	_hint_label = Label.new()
	_hint_label.text = "點一下：繼續" if MobileControls.is_mobile_device() else "Space / Enter：繼續"
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hint_label.add_theme_color_override("font_color", Color("b8a9bc"))
	content.add_child(_hint_label)
	_cinematic = Cinematic.new()
	_cinematic.name = "CinematicInsert"
	_root.add_child(_cinematic)
	_cinematic.finished.connect(_stop_cinematic)
	_root.visible = false
