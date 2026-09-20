extends SceneTree
## Structural atlas checks plus real player animation selection; no save writes.

var _failures: int = 0
const DIRECTIONS: Array[StringName] = [&"down", &"up", &"left", &"right"]


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)


func _run() -> void:
	var scene := load("res://scenes/player.tscn") as PackedScene
	if scene == null:
		push_error("Player scene failed to load")
		quit(1)
		return
	var player := scene.instantiate() as CharacterBody3D
	if player == null:
		push_error("Player scene failed to instantiate")
		quit(1)
		return
	root.add_child(player)
	player.set_physics_process(false)
	var sprite := player.get_node("Sprite3D") as AnimatedSprite3D
	var first_frame := sprite.sprite_frames.get_frame_texture(&"down", 0) as AtlasTexture
	var atlas_image := first_frame.atlas.get_image()
	_check(atlas_image != null and atlas_image.detect_alpha() != Image.ALPHA_NONE, "Player atlas requires a transparent background")
	for row: int in range(4):
		for column: int in range(4):
			var animation: StringName = DIRECTIONS[column]
			_check(sprite.sprite_frames.get_frame_count(animation) == 4, "Each direction needs four poses")
			var frame := sprite.sprite_frames.get_frame_texture(animation, row) as AtlasTexture
			_check(frame.get_size() == Vector2(320, 320), "All poses need the same presentation canvas")
			var region := Rect2i(frame.region)
			_check(Rect2i(Vector2i.ZERO, atlas_image.get_size()).encloses(region), "Frame outside source image")
			var visible_pixels: int = 0
			var bottom: int = 0
			for y: int in range(region.position.y, region.end.y):
				for x: int in range(region.position.x, region.end.x):
					if atlas_image.get_pixel(x, y).a >= sprite.alpha_scissor_threshold:
						visible_pixels += 1
						bottom = maxi(bottom, y - region.position.y + 1)
						_check(x > region.position.x and x < region.end.x - 1 and y > region.position.y and y < region.end.y - 1, "Visible silhouette clipped by frame")
			_check(visible_pixels > 1000, "Empty or incomplete player pose")
			_check(is_equal_approx(float(bottom) + frame.margin.position.y, 300.0), "Player feet must share a baseline")
	var directions: Array[Vector2] = [Vector2.DOWN, Vector2.UP, Vector2.LEFT, Vector2.RIGHT]
	for column: int in range(4):
		player.set("_walk_time", 0.0)
		for row: int in range(4):
			player.call("_update_sprite", directions[column], Vector3.FORWARD, 0.0 if row == 0 else 0.125)
			_check(sprite.animation == DIRECTIONS[column] and sprite.frame == row, "Wrong player animation selection")
		player.call("_update_sprite", Vector2.ZERO, Vector3.ZERO, 0.1)
		_check(sprite.animation == DIRECTIONS[column] and sprite.frame == 0, "Idle must retain facing and reset pose")
	player.queue_free()
	await process_frame
	if _failures == 0:
		print("PLAYER_ART_TEST_PASS atlas alpha directions walk idle")
	quit(0 if _failures == 0 else 1)
