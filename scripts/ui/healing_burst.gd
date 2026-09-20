extends "res://scripts/ui/magic_burst.gd"
## Shares the one-impact lifetime with offensive magic, but uses restorative art.
const HEAL_ATLAS: Texture2D = preload("res://assets/generated/moon_heal.png")


func _draw() -> void:
	var frame: int = mini(3, int(_elapsed / FRAME_SECONDS))
	var cell := HEAL_ATLAS.get_size() * 0.5
	var region := Rect2(Vector2(frame % 2, frame / 2) * cell, cell)
	var size := Vector2.ONE * radius * 2.0
	# The generated ground ellipse is consistently 80% down each cell.
	# Anchor it to the target's feet rather than centering the sprite there.
	draw_texture_rect_region(HEAL_ATLAS, Rect2(-size * Vector2(0.5, 0.8), size), region)
