extends Control
## Full-bleed moonlit stage behind the character draft, tinted by the chosen
## vocation. Narrow screens scroll, so the sky moves into the framed preview.
const GOLD := Color(0.76, 0.62, 0.40, 0.65)
const INK := Color("071423")
const SKY := preload("res://assets/generated/class_selection_moonlit.png")
var accent: Color = Color("e6c58b"):
	set(value):
		accent = value
		queue_redraw()
var epithet: String = "":
	set(value):
		epithet = value
		queue_redraw()
var narrow: bool = false:
	set(value):
		narrow = value
		queue_redraw()

func _ready() -> void:
	resized.connect(queue_redraw)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), INK)
	if narrow:
		draw_rect(Rect2(Vector2.ZERO, size), Color(accent, 0.05))
		return
	var cover: float = maxf(size.x / SKY.get_width(), size.y / SKY.get_height())
	var drawn: Vector2 = SKY.get_size() * cover
	draw_texture_rect(SKY, Rect2((size - drawn) * 0.5, drawn), false, Color(0.78, 0.84, 0.92))
	draw_rect(Rect2(Vector2.ZERO, size), Color(accent, 0.08))
	# The info column reads over a dark gradient instead of a boxed panel.
	var fade_start: float = size.x * 0.40
	var fade_end: float = size.x * 0.60
	var shade := Color(INK, 0.86)
	_gradient(Rect2(fade_start, 0, fade_end - fade_start, size.y), Color(INK, 0.0), shade, true)
	draw_rect(Rect2(fade_end, 0, size.x - fade_end, size.y), shade)
	_gradient(Rect2(0, 0, size.x, 110), Color(INK, 0.7), Color(INK, 0.0), false)
	_gradient(Rect2(0, size.y - 200, size.x, 200), Color(INK, 0.0), Color(INK, 0.92), false)
	var band := PackedVector2Array([Vector2(fade_end - 40, size.y * 0.17), Vector2(size.x, size.y * 0.09), Vector2(size.x, size.y * 0.21), Vector2(fade_end - 40, size.y * 0.29)])
	draw_colored_polygon(band, Color(accent, 0.07))
	if not epithet.is_empty():
		draw_string(GameState.title_font, Vector2(fade_start + 20, size.y * 0.80), epithet, HORIZONTAL_ALIGNMENT_RIGHT, size.x - fade_start - 40, int(size.y * 0.2), Color(accent, 0.05))
	for corner: Vector2 in [Vector2(12, 12), Vector2(size.x - 12, 12), Vector2(12, size.y - 12), size - Vector2(12, 12)]:
		var inward := Vector2(1.0 if corner.x < size.x * 0.5 else -1.0, 1.0 if corner.y < size.y * 0.5 else -1.0)
		draw_line(corner, corner + Vector2(inward.x * 32, 0), GOLD, 1.0, true)
		draw_line(corner, corner + Vector2(0, inward.y * 32), GOLD, 1.0, true)
		var jewel: Vector2 = corner + inward * 6.0
		draw_polyline(PackedVector2Array([jewel + Vector2(0, -4), jewel + Vector2(4, 0), jewel + Vector2(0, 4), jewel + Vector2(-4, 0), jewel + Vector2(0, -4)]), GOLD, 1.0, true)

func _gradient(rect: Rect2, from: Color, to: Color, horizontal: bool) -> void:
	var points := PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)])
	var colors := PackedColorArray([from, to, to, from] if horizontal else [from, from, to, to])
	draw_polygon(points, colors)
