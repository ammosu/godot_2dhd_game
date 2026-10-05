class_name DialogueUI
extends CanvasLayer

signal page_shown(index: int)
## A speaker's line starts (true) or stops (false) typing, for world body language.
signal line_revealing(speaker: String, active: bool)
## A line asked its speaker to act ("act": beat, "emote": bubble; see actor_acting.gd).
signal line_acted(speaker: String, beat: StringName, emote: StringName)

const Cinematic = preload("res://scripts/ui/dialogue_cinematic.gd")
const Presentation = preload("res://scripts/ui/presentation_theme.gd")
const Faces = preload("res://scripts/ui/portrait_faces.gd")
## Typewriter pace for body text; a press while revealing shows the full page.
const REVEAL_CHARS_PER_SECOND: float = 42.0
const FADE_IN_SECONDS: float = 0.16
## The box fades out after closing; game mode and callbacks stay synchronous.
const FADE_OUT_SECONDS: float = 0.12

var _cinematic: Control
var _panel: PanelContainer
var _root: Control
var _speaker_label: Label
var _body_label: Label
var _hint_label: Label
var _story_shade: ColorRect
var _illustration: TextureRect
var _lines: Array = []
var _line_index: int = 0
var _finished_callback: Callable
var _motion: String = ""
var _motion_elapsed: float = 0.0
var _reveal: Tween
var _continue_arrow: TextureRect
var _nameplate: PanelContainer
var _portrait_frame: PanelContainer
var _portrait: TextureRect
var _arrow_time: float = 0.0
var _open: bool = false
var _fade: Tween
var _revealing_speaker: String = ""


func _process(delta: float) -> void:
	if _open and _continue_arrow.visible:
		_arrow_time += delta
		_continue_arrow.position.y = sin(_arrow_time * 5.0) * 3.0
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
	if _fade != null:
		_fade.kill()
		_fade = null
	if not _root.visible:
		_root.modulate.a = 0.0
		_fade = create_tween()
		_fade.tween_property(_root, "modulate:a", 1.0, FADE_IN_SECONDS)
	else:
		# Reopened while the previous box was fading out: stay solid.
		_root.modulate.a = 1.0
	_root.visible = true
	_open = true
	_notify_hud("set_dialogue_open", true)
	GameState.set_mode(GameState.Mode.DIALOGUE)
	_show_current_line()


func advance() -> void:
	if not _open:
		return
	_line_index += 1
	if _line_index >= _lines.size():
		_finish_dialogue()
	else:
		_show_current_line()


func is_open() -> bool:
	return _open


## Speaker whose line is currently typing, or "" when none is.
func revealing_speaker() -> String:
	return _revealing_speaker


func is_revealing() -> bool:
	return _reveal != null and _reveal.is_running()


## Player input: first completes a page that is still typing, then advances.
## Scripted callers use `advance()` directly and never wait for the reveal.
func _press() -> void:
	if is_revealing():
		_complete_reveal()
	else:
		advance()


func _input(event: InputEvent) -> void:
	if not is_open() or not event is InputEventScreenTouch:
		return
	# Dialogue is modal: panel/HUD hit testing must not swallow taps. Consume
	# before advancing, since the last page can immediately change game mode.
	get_viewport().set_input_as_handled()
	if event.pressed and not event.canceled:
		_press()


func _unhandled_input(event: InputEvent) -> void:
	if not _open or event.is_echo():
		return
	if (
		event.is_action_pressed("interact")
		or event.is_action_pressed("ui_accept")
	):
		_press()
		get_viewport().set_input_as_handled()


func _show_current_line() -> void:
	_stop_cinematic()
	GameAudio.play_cue(&"dialogue")
	var line: Dictionary = _lines[_line_index]
	_illustration.texture = line.get("illustration") as Texture2D
	_illustration.visible = _illustration.texture != null
	_story_shade.visible = _illustration.visible
	_notify_hud("set_story_focus", _illustration.visible)
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
	_nameplate.visible = not _speaker_label.text.is_empty()
	_show_portrait(Faces.speaker_face_id(_speaker_label.text))
	_nameplate.reset_size()
	_place_nameplate()
	_body_label.text = str(line.get("text", ""))
	_start_reveal()
	if str(line.get("cinematic", "")) == "moon_memory" and _illustration.texture != null:
		layer = 100 # Keep arrival notices behind the cinematic insert.
		_panel.hide()
		_cinematic.play(_illustration.texture)
	_hint_label.text = "%02d / %02d   ·   %s" % [_line_index + 1, _lines.size(), "點一下繼續" if MobileControls.is_mobile_device() else "Space / Enter  繼續"]
	page_shown.emit(_line_index)
	if line.has("act") or line.has("emote"):
		line_acted.emit(_speaker_label.text, StringName(line.get("act", "")), StringName(line.get("emote", "")))


func _show_portrait(face_id: String) -> void:
	_portrait_frame.visible = not face_id.is_empty()
	if face_id.is_empty():
		_portrait.texture = null
		return
	var hero: bool = face_id == "hero"
	_portrait.texture = Faces.hero_face(GameState.player_class, GameState.player_body == "female") if hero else Faces.npc_face(face_id)
	GameState.HeroStyle.apply_canvas(_portrait, _portrait.texture, GameState.player_style if hero else "original")


func _place_nameplate() -> void:
	_nameplate.global_position = _panel.global_position + Vector2(18.0, -_nameplate.size.y * 0.5)


func _start_reveal() -> void:
	if _reveal != null:
		_reveal.kill()
	_set_revealing(_speaker_label.text)
	_continue_arrow.hide()
	var count: int = _body_label.get_total_character_count()
	_body_label.visible_ratio = 0.0
	_reveal = create_tween()
	_reveal.tween_property(_body_label, "visible_ratio", 1.0, maxf(0.05, count / REVEAL_CHARS_PER_SECOND))
	_reveal.finished.connect(_complete_reveal)


func _complete_reveal() -> void:
	if _reveal != null:
		_reveal.kill()
		_reveal = null
	_set_revealing("")
	_body_label.visible_ratio = 1.0
	_arrow_time = 0.0
	_continue_arrow.show()


func _set_revealing(speaker: String) -> void:
	if not _revealing_speaker.is_empty():
		var previous := _revealing_speaker
		_revealing_speaker = ""
		line_revealing.emit(previous, false)
	if not speaker.is_empty():
		_revealing_speaker = speaker
		line_revealing.emit(speaker, true)


func _finish_dialogue() -> void:
	if _reveal != null:
		_reveal.kill()
		_reveal = null
	_set_revealing("")
	_open = false
	_continue_arrow.hide()
	if _fade != null:
		_fade.kill()
		_fade = null
	if _panel.visible:
		_fade = create_tween()
		_fade.tween_property(_root, "modulate:a", 0.0, FADE_OUT_SECONDS)
		_fade.tween_callback(_hide_closed_root)
	else:
		_hide_closed_root() # A full-screen cinematic insert cuts straight out.
	clear_illustration()
	_notify_hud("set_dialogue_open", false)
	GameState.set_mode(GameState.Mode.EXPLORE)
	var callback := _finished_callback
	_finished_callback = Callable()
	if callback.is_valid():
		callback.call()


func _hide_closed_root() -> void:
	_fade = null
	if not _open:
		_root.visible = false
		_root.modulate.a = 1.0


func _stop_cinematic() -> void:
	layer = 60
	_cinematic.stop()
	_panel.show()


func clear_illustration() -> void:
	_story_shade.hide()
	_notify_hud("set_story_focus", false)
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

	_story_shade = ColorRect.new()
	_story_shade.name = "StoryShade"
	_root.add_child(_story_shade)
	_story_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_story_shade.color = Color(0, 0, 0, 0.76)
	_story_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_story_shade.hide()
	_illustration = TextureRect.new()
	_illustration.name = "MemoryIllustration"
	_illustration.anchor_left = 0.15
	_illustration.anchor_top = 0.025
	_illustration.anchor_right = 0.85
	_illustration.anchor_bottom = 0.70
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

	var style := Presentation.ornate_panel(16)
	style.content_margin_top = 34.0 # Room under the speaker tab.
	style.content_margin_right = 50.0 # Keep the arrow clear of the corner filigree.
	panel.add_theme_stylebox_override("panel", style)

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 18)
	panel.add_child(columns)
	_portrait_frame = PanelContainer.new()
	_portrait_frame.name = "Portrait"
	_portrait_frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_portrait_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var portrait_style := Presentation.panel(3)
	portrait_style.bg_color = Color("1c2f40")
	portrait_style.set_corner_radius_all(6)
	portrait_style.shadow_size = 0
	_portrait_frame.add_theme_stylebox_override("panel", portrait_style)
	columns.add_child(_portrait_frame)
	_portrait = TextureRect.new()
	var side: float = 84.0 if MobileControls.is_mobile_device() else 112.0
	_portrait.custom_minimum_size = Vector2(side, side)
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_portrait_frame.add_child(_portrait)
	_portrait_frame.hide()
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 10)
	columns.add_child(content)

	# The speaker tab straddles the frame's top edge; top_level keeps the
	# panel container from laying it out while it still inherits visibility.
	_nameplate = PanelContainer.new()
	_nameplate.name = "Nameplate"
	_nameplate.top_level = true
	_nameplate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_nameplate.add_theme_stylebox_override("panel", Presentation.nameplate())
	panel.add_child(_nameplate)
	panel.item_rect_changed.connect(_place_nameplate)
	_speaker_label = Label.new()
	_speaker_label.add_theme_color_override("font_color", Color("f2c46e"))
	_speaker_label.add_theme_font_size_override("font_size", 21)
	_nameplate.add_child(_speaker_label)

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
	_hint_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 10)
	content.add_child(footer)
	footer.add_child(_hint_label)
	# A plain Control slot keeps the bobbing arrow from reflowing the footer.
	var arrow_slot := Control.new()
	arrow_slot.custom_minimum_size = Vector2(18, 24)
	arrow_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	footer.add_child(arrow_slot)
	_continue_arrow = TextureRect.new()
	_continue_arrow.name = "ContinueArrow"
	_continue_arrow.texture = preload("res://assets/generated/ui/continue_arrow.png")
	_continue_arrow.size = Vector2(22, 22)
	_continue_arrow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_continue_arrow.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_continue_arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_continue_arrow.hide()
	arrow_slot.add_child(_continue_arrow)
	_cinematic = Cinematic.new()
	_cinematic.name = "CinematicInsert"
	_root.add_child(_cinematic)
	_cinematic.finished.connect(_stop_cinematic)
	_root.visible = false


func _notify_hud(method: StringName, value: bool) -> void:
	var hud := get_tree().get_first_node_in_group("world_hud")
	if hud != null:
		hud.call(method, value)

func _exit_tree() -> void:
	_notify_hud("set_story_focus", false)
	_notify_hud("set_dialogue_open", false)
