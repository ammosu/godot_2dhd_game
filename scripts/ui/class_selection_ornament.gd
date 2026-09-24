extends Control
## Quiet framing stays behind the interactive character draft.
const GOLD := Color(0.76, 0.62, 0.40, 0.65)
const SKY := preload("res://assets/generated/class_selection_moonlit.png")

func _ready() -> void:
	resized.connect(queue_redraw)

func _draw() -> void:
	if size.x < 900.0:
		return
	var art_size := Vector2(size.x * 0.48, size.y * 0.50)
	draw_texture_rect(SKY, Rect2(size - art_size, art_size), false, Color(0.42, 0.52, 0.64, 0.15))
	for corner: Vector2 in [Vector2(12, 12), Vector2(size.x - 12, 12), Vector2(12, size.y - 12), size - Vector2(12, 12)]:
		var inward := Vector2(1.0 if corner.x < size.x * 0.5 else -1.0, 1.0 if corner.y < size.y * 0.5 else -1.0)
		draw_line(corner, corner + Vector2(inward.x * 32, 0), GOLD, 1.0, true)
		draw_line(corner, corner + Vector2(0, inward.y * 32), GOLD, 1.0, true)
		var jewel: Vector2 = corner + inward * 6.0
		draw_polyline(PackedVector2Array([jewel + Vector2(0, -4), jewel + Vector2(4, 0), jewel + Vector2(0, 4), jewel + Vector2(-4, 0), jewel + Vector2(0, -4)]), GOLD, 1.0, true)
	var compass := Vector2(size.x - maxf(30.0, size.x * 0.04) - 28.0, 56.0)
	draw_arc(compass, 17, 0, TAU, 48, GOLD, 1.0, true)
	for index: int in range(4):
		var angle: float = index * PI * 0.5
		var axis := Vector2(cos(angle), sin(angle))
		var perpendicular := Vector2(-axis.y, axis.x)
		draw_polyline(PackedVector2Array([compass, compass + axis * 8 + perpendicular * 5, compass + axis * 32, compass + axis * 8 - perpendicular * 5, compass]), GOLD, 1.0, true)
