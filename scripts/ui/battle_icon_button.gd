extends Button
## Original vector glyphs stay crisp at every control size; no font-icon dependency.
var glyph: String = "attack"
var caption: String = "普攻"
var hotkey: String = "J"
var accent := Color("e9c47f")
var cooldown: float = 0.0
var cooldown_fraction: float = 0.0
var show_caption: bool = true
var badge: String = ""

func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)
	button_down.connect(queue_redraw)
	button_up.connect(queue_redraw)

func _has_point(point: Vector2) -> bool:
	return point.distance_squared_to(size * 0.5) <= pow(minf(size.x, size.y) * 0.5, 2.0)

func contains_screen_point(point: Vector2) -> bool:
	return _has_point(get_global_transform_with_canvas().affine_inverse() * point)

func _draw() -> void:
	var center: Vector2 = size * 0.5
	var radius: float = minf(size.x, size.y) * 0.5 - 2.0
	var ink: Color = accent.darkened(0.4) if disabled else accent
	draw_circle(center + Vector2(0, 3), radius, Color(0, 0, 0, 0.35))
	draw_circle(center, radius, Color("263e51") if is_pressed() else Color(0.025, 0.045, 0.08, 0.94))
	draw_arc(center, radius, 0, TAU, 72, ink, 2.0, true)
	draw_arc(center, radius - 5.0, 0, TAU, 72, Color(ink, 0.22), 1.0, true)
	if is_hovered() and not disabled:
		draw_arc(center, radius, 0, TAU, 72, Color("f1f6ff"), 3.0, true)
	var icon_scale: float = radius / 44.0
	var icon_center: Vector2 = center - Vector2(0, 6 if show_caption else 0)
	draw_set_transform(icon_center, 0, Vector2.ONE * icon_scale)
	_draw_glyph(ink)
	draw_set_transform(Vector2.ZERO)
	if cooldown > 0.0:
		draw_circle(center, radius - 3, Color(0.02, 0.035, 0.065, 0.65))
		draw_arc(center, radius - 2.0, -PI * 0.5, -PI * 0.5 + TAU * cooldown_fraction, 64, accent, 3.5, true)
		_text("%.1f" % cooldown, center.y + 7, 22, Color.WHITE)
	elif show_caption:
		_text(caption, center.y + radius * 0.64, 13 if size.x < 95 else 16, Color("e7edf3"))
	if not badge.is_empty():
		_text(badge, 14, 12, Color("d8e6f0"))
	elif not MobileControls.is_mobile_device():
		_text(hotkey, 14, 11, Color("afc1ce"))

func _text(value: String, baseline: float, font_size: int, color: Color) -> void:
	var font: Font = get_theme_font("font")
	var width: float = font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(font, Vector2((size.x - width) * 0.5, baseline), value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func _line(points: Array, color: Color, width: float = 3.0) -> void:
	draw_polyline(PackedVector2Array(points), color, width, true)

func _draw_glyph(ink: Color) -> void:
	match glyph:
		"attack":
			draw_colored_polygon(PackedVector2Array([Vector2(-9, 8), Vector2(9, -17), Vector2(20, -23), Vector2(17, -11), Vector2(-3, 13)]), ink)
			_line([Vector2(-16, 2), Vector2(3, 19)], ink, 4)
			_line([Vector2(-9, 12), Vector2(-18, 23)], ink, 5)
		"moon":
			draw_arc(Vector2(1, -1), 21, -1.3, 1.7, 32, ink, 7, true)
			_line([Vector2(-20, 17), Vector2(20, -20)], Color("f0fbff"), 3)
			draw_circle(Vector2(-12, -13), 3, ink)
		"ward":
			_line([Vector2(0, -23), Vector2(20, -15), Vector2(17, 7), Vector2(0, 23), Vector2(-17, 7), Vector2(-20, -15), Vector2(0, -23)], ink)
			_line([Vector2(0, -13), Vector2(0, 11)], ink)
			_line([Vector2(-10, -2), Vector2(10, -2)], ink)
		"frost":
			for index: int in range(6):
				var arm: Vector2 = Vector2.from_angle(PI / 3.0 * index)
				var side := Vector2(-arm.y, arm.x)
				_line([Vector2.ZERO, arm * 23], ink)
				_line([arm * 11 + side * 7, arm * 17, arm * 11 - side * 7], ink, 2)
		"dodge":
			for x: float in [-13.0, 2.0]:
				_line([Vector2(x - 6, -17), Vector2(x + 10, 0), Vector2(x - 6, 17)], ink, 5)
			_line([Vector2(-25, -6), Vector2(-17, -6)], ink, 2)
			_line([Vector2(-25, 6), Vector2(-17, 6)], ink, 2)
		"switch":
			draw_circle(Vector2(-8, -7), 6, ink)
			draw_arc(Vector2(-8, 12), 11, PI, TAU, 20, ink, 3, true)
			_line([Vector2(5, -15), Vector2(21, -15), Vector2(16, -21)], ink)
			_line([Vector2(21, 14), Vector2(5, 14), Vector2(10, 20)], ink)
		"potion":
			_line([Vector2(-7, -20), Vector2(-7, -8), Vector2(-16, 6), Vector2(-13, 19), Vector2(13, 19), Vector2(16, 6), Vector2(7, -8), Vector2(7, -20), Vector2(-7, -20)], ink)
			_line([Vector2(-10, -23), Vector2(10, -23)], ink, 4)
			_line([Vector2(-10, 6), Vector2(10, 6)], ink, 3)
			_line([Vector2(0, 2), Vector2(0, 14)], ink, 3)
