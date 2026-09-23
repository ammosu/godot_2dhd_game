extends Control
## Presentation-only insert. No quest state, timers, camera or audio bus ownership.
signal finished

const DURATION: float = 14.0
var elapsed: float = 0.0
var picture: Texture2D
var _caption: Label
var _hint: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	clip_contents = true
	_caption = Label.new()
	_caption.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_caption.anchor_top = 0.81
	_caption.anchor_bottom = 0.94
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_caption.add_theme_font_size_override("font_size", 24)
	_caption.add_theme_color_override("font_color", Color("e4ebee"))
	_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_caption)
	_hint = Label.new()
	_hint.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_hint.offset_top = 18
	_hint.offset_right = -24
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hint.add_theme_font_size_override("font_size", 16)
	_hint.add_theme_color_override("font_color", Color("96a4b6"))
	_hint.text = "點一下：跳過回憶" if MobileControls.is_mobile_device() else "Space / Enter：跳過回憶"
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_hint)
	hide()


func play(texture: Texture2D) -> void:
	picture = texture
	elapsed = 0.0
	show()
	_update_caption()
	queue_redraw()


func stop() -> void:
	hide()
	picture = null
	elapsed = 0.0


func _process(delta: float) -> void:
	if not visible:
		return
	elapsed += delta
	if elapsed >= DURATION:
		stop()
		finished.emit()
		return
	_update_caption()
	queue_redraw()


func _update_caption() -> void:
	if elapsed < 3.2:
		_caption.text = "月泉深處，浮起一輪不屬於今夜的月亮。"
	elif elapsed < 7.6:
		_caption.text = "曾經，他們沿著月光，走向有人點燈的地方。"
	elif elapsed < 11.2:
		_caption.text = "後來，牆築起了。光留在牆內。"
	else:
		_caption.text = "而牆外的人……再也沒有抵達。"
	modulate.a = smoothstep(0.0, 0.7, elapsed) * (1.0 - smoothstep(13.0, DURATION, elapsed))


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("050912"))
	var frame := Rect2(0.0, size.y * 0.12, size.x, size.y * 0.68)
	if elapsed >= 3.2 and elapsed < 11.2 and picture != null:
		var wall: bool = elapsed >= 7.6
		var t: float = clampf((elapsed - (7.6 if wall else 3.2)) / (3.6 if wall else 4.4), 0.0, 1.0)
		var source_size: Vector2 = picture.get_size()
		var zoom: float = lerpf(1.48, 1.64, t) if wall else lerpf(1.12, 1.24, t)
		var crop := Vector2(source_size.x / zoom, source_size.x / zoom * frame.size.y / frame.size.x)
		crop.y = minf(crop.y, source_size.y)
		var focus := Vector2(0.64, 0.42) if wall else Vector2(0.40, 0.62)
		var origin := focus * source_size - crop * 0.5
		origin = origin.clamp(Vector2.ZERO, source_size - crop)
		var fade: float = smoothstep(0.0, 0.13, t)
		draw_texture_rect_region(picture, frame, Rect2(origin, crop), Color(0.83, 0.9, 1.0, fade))
	else:
		_draw_moon(frame, elapsed >= 11.2)
	# Fine drifting silver motes tie the painted memory to the water imagery.
	for index: int in range(24):
		var x: float = fposmod(float(index) * 0.137 + elapsed * 0.006, 1.0) * size.x
		var y: float = frame.position.y + fposmod(float(index) * 0.213 - elapsed * 0.011, 1.0) * frame.size.y
		draw_rect(Rect2(x, y, 2, 2), Color(0.64, 0.8, 0.94, 0.22))


func _draw_moon(frame: Rect2, broken: bool) -> void:
	var center := Vector2(size.x * 0.5, size.y * 0.36)
	var radius: float = minf(size.x, size.y) * 0.105
	draw_rect(frame, Color("0c182b"))
	for band: int in range(40):
		var y: float = -radius + float(band) * radius / 20.0
		var half_width: float = sqrt(maxf(0.0, radius * radius - y * y))
		var drift: float = sin(float(band) * 0.8 + elapsed * 1.6) * (13.0 if broken else 2.5)
		if broken:
			drift *= 1.0 + (elapsed - 11.2) * 1.5
		draw_rect(Rect2(center.x - half_width + drift, center.y + y, half_width * 2.0, radius / 22.0), Color("b5d7e8"))
	for ripple: int in range(16):
		var t: float = float(ripple) / 16.0
		var width: float = radius * (0.25 + t * 2.0) * (0.65 + 0.35 * sin(float(ripple) * 2.4 + elapsed))
		var y: float = center.y + radius * 1.2 + t * frame.size.y * 0.36
		draw_rect(Rect2(center.x - width, y, width * 2.0, 2.0), Color(0.48, 0.72, 0.87, (1.0 - t) * 0.32))
