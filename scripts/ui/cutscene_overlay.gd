extends CanvasLayer
## Presentation-only cutscene frame: letterbox, captions, title cards, fades and skip hint.
## CutscenePlayer drives every value; this node owns no timers or story state.

const LETTERBOX_RATIO: float = 0.11
var black: ColorRect
var caption: Label
var speaker: Label
var title: Label
var subtitle: Label
var skip_hint: Label
var _bars: Array[ColorRect] = []


func _ready() -> void:
	layer = 80
	var root := Control.new()
	root.name = "CutsceneFrame"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = GameState.ui_theme
	add_child(root)
	for top: bool in [true, false]:
		var bar := ColorRect.new()
		bar.color = Color.BLACK
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE if top else Control.PRESET_BOTTOM_WIDE)
		bar.anchor_top = 0.0 if top else 1.0 - LETTERBOX_RATIO
		bar.anchor_bottom = LETTERBOX_RATIO if top else 1.0
		bar.offset_top = 0.0
		bar.offset_bottom = 0.0
		root.add_child(bar)
		_bars.append(bar)
	black = ColorRect.new()
	black.name = "Fade"
	black.color = Color.BLACK
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(black)
	speaker = _label(root, 18, Color("9fc4d8"))
	speaker.anchor_top = 0.74
	speaker.anchor_bottom = 0.79
	caption = _label(root, 26, Color("eef1f2"))
	caption.anchor_top = 0.78
	caption.anchor_bottom = 0.89
	caption.anchor_left = 0.12
	caption.anchor_right = 0.88
	title = _label(root, 44, Color("f1dfae"))
	title.add_theme_font_override("font", GameState.title_font)
	title.anchor_top = 0.38
	title.anchor_bottom = 0.52
	subtitle = _label(root, 22, Color("b9c6d2"))
	subtitle.add_theme_font_override("font", GameState.title_font)
	subtitle.anchor_top = 0.53
	subtitle.anchor_bottom = 0.60
	skip_hint = _label(root, 16, Color("aab6c4"))
	skip_hint.anchor_top = 0.02
	skip_hint.anchor_bottom = 0.08
	skip_hint.anchor_left = 0.5
	skip_hint.anchor_right = 0.98
	skip_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	skip_hint.text = "再按一次跳過" if not MobileControls.is_mobile_device() else "再點一次跳過"
	skip_hint.modulate.a = 0.0
	set_black(1.0)
	set_caption("", "", 0.0)
	set_title("", "", 0.0)


func _label(parent: Control, size: int, color: Color) -> Label:
	var label := Label.new()
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.85))
	label.add_theme_constant_override("outline_size", 6)
	parent.add_child(label)
	return label


func set_black(alpha: float) -> void:
	black.color.a = clampf(alpha, 0.0, 1.0)


func set_caption(text: String, speaker_name: String, alpha: float) -> void:
	caption.text = text
	speaker.text = speaker_name
	caption.modulate.a = clampf(alpha, 0.0, 1.0)
	speaker.modulate.a = caption.modulate.a if not speaker_name.is_empty() else 0.0


func set_title(text: String, sub: String, alpha: float) -> void:
	title.text = text
	subtitle.text = sub
	title.modulate.a = clampf(alpha, 0.0, 1.0)
	subtitle.modulate.a = title.modulate.a


func set_letterbox(visible_bars: bool) -> void:
	for bar: ColorRect in _bars:
		bar.visible = visible_bars


func set_skip_hint(alpha: float) -> void:
	skip_hint.modulate.a = clampf(alpha, 0.0, 1.0)
