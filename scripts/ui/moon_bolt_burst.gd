extends "res://scripts/ui/magic_burst.gd"
## One projectile cell and three impact cells; timing stays shared with magic.
const MOON_ATLAS: Texture2D = preload("res://assets/generated/moon_bolt.png")


static func projectile_texture() -> AtlasTexture:
	var texture := AtlasTexture.new()
	texture.atlas = MOON_ATLAS
	texture.region = Rect2(Vector2.ZERO, MOON_ATLAS.get_size() * 0.5)
	texture.filter_clip = true
	return texture


func _draw() -> void:
	var frame: int = mini(2, int(_elapsed / FRAME_SECONDS)) + 1
	var cell := MOON_ATLAS.get_size() * 0.5
	var region := Rect2(Vector2(frame % 2, frame / 2) * cell, cell)
	var extent := Vector2.ONE * radius
	# Hold the final fragment frame, fading through the fourth time slot.
	var alpha := clampf((FRAME_SECONDS * 4.0 - _elapsed) / FRAME_SECONDS, 0.0, 1.0)
	draw_texture_rect_region(MOON_ATLAS, Rect2(-extent, extent * 2.0), region, Color(1, 1, 1, alpha))
