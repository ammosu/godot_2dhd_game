extends SceneTree

var _failures: int = 0


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)


func _initialize() -> void:
	for enemy: String in ["moss_wolf", "eclipse_mage"]:
		for pose: String in ["front", "idle", "attack", "hurt"]:
			var texture := load("res://assets/generated/%s_%s.tres" % [enemy, pose]) as AtlasTexture
			_check(texture != null, "Missing enemy pose")
			if texture == null:
				continue
			_check(texture.get_size() == Vector2(800, 640), "Pose canvas differs")
			_check(is_equal_approx(texture.margin.position.y + texture.region.size.y, 620), "Pose baseline differs")
			var image := texture.atlas.get_image()
			_check(image.detect_alpha() != Image.ALPHA_NONE, "Atlas background is opaque")
			var bounds := Rect2i(texture.region)
			_check(Rect2i(Vector2i.ZERO, image.get_size()).encloses(bounds), "Crop extends outside atlas")
			var edge_alpha: float = 0.0
			for x: int in range(bounds.position.x, bounds.end.x):
				edge_alpha = maxf(edge_alpha, image.get_pixel(x, bounds.position.y).a)
				edge_alpha = maxf(edge_alpha, image.get_pixel(x, bounds.end.y - 1).a)
			for y: int in range(bounds.position.y, bounds.end.y):
				edge_alpha = maxf(edge_alpha, image.get_pixel(bounds.position.x, y).a)
				edge_alpha = maxf(edge_alpha, image.get_pixel(bounds.end.x - 1, y).a)
			_check(edge_alpha < 0.5, "Crop cuts into visible sprite: " + enemy + " " + pose)
	if _failures == 0:
		print("ENEMY_ROSTER_ART_TEST_PASS two_enemies eight_poses alpha crops baseline")
	quit(0 if _failures == 0 else 1)
