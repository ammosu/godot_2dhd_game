extends Control
## Original line icon; drawn as geometry so it stays crisp at every canvas scale.
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(26, 28)

func _draw() -> void:
	var ink := Color("f3eee1")
	draw_polyline(PackedVector2Array([Vector2(1, 5), Vector2(9, 1), Vector2(17, 5), Vector2(25, 1), Vector2(25, 23), Vector2(17, 27), Vector2(9, 23), Vector2(1, 27), Vector2(1, 5)]), ink, 1.6, true)
	draw_line(Vector2(9, 1), Vector2(9, 23), ink, 1.6, true)
	draw_line(Vector2(17, 5), Vector2(17, 27), ink, 1.6, true)
