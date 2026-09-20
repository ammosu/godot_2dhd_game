extends Node2D
## Presentation only. Caller resolves damage when impact is emitted.
signal impact
signal finished

const ATLAS: Texture2D = preload("res://assets/generated/frost_nova.png")
const FRAME_SECONDS: float = 0.16
var radius: float = 120.0
var _elapsed: float = 0.0
var _impacted: bool = false


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = 12
	queue_redraw()


func _process(delta: float) -> void:
	_elapsed += delta
	if not _impacted and _elapsed >= FRAME_SECONDS:
		_impacted = true
		impact.emit()
	if _elapsed >= FRAME_SECONDS * 4.0:
		set_process(false)
		finished.emit()
		queue_free()
	queue_redraw()


func _draw() -> void:
	var frame: int = mini(3, int(_elapsed / FRAME_SECONDS))
	var cell := ATLAS.get_size() * 0.5
	var region := Rect2(Vector2(frame % 2, frame / 2) * cell, cell)
	var extent := Vector2.ONE * radius
	if frame == 0:
		draw_circle(Vector2.ZERO, radius, Color(0.4, 0.85, 1.0, 0.10))
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 64, Color(0.5, 0.9, 1.0, 0.65), 2.0)
	draw_texture_rect_region(ATLAS, Rect2(-extent, extent * 2.0), region)
