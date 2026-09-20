extends SceneTree
## Two-pose idle art, real playback and map lifecycle; no save writes.

var _failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)


func _run() -> void:
	var frames := load("res://assets/generated/pig_idle.tres") as SpriteFrames
	_check(frames.get_frame_count(&"idle") == 2 and frames.get_animation_loop(&"idle"), "Pig needs a two-pose looping idle")
	_check(is_equal_approx(frames.get_animation_speed(&"idle"), 2.0), "Pig idle rate changed")
	_check(is_equal_approx(frames.get_frame_duration(&"idle", 0), 3.0) and is_equal_approx(frames.get_frame_duration(&"idle", 1), 1.0), "Pig idle should favor standing over sniffing")
	for index: int in range(2):
		var atlas := frames.get_frame_texture(&"idle", index) as AtlasTexture
		_check(atlas.get_size() == Vector2(800, 640), "Pig poses need the same canvas")
		var image := atlas.atlas.get_image()
		_check(image.detect_alpha() != Image.ALPHA_NONE, "Pig background must be transparent")
		var region := Rect2i(atlas.region)
		_check(Rect2i(Vector2i.ZERO, image.get_size()).encloses(region), "Pig crop outside image")
		var bottom: int = 0
		var visible: int = 0
		for y: int in range(region.position.y, region.end.y):
			for x: int in range(region.position.x, region.end.x):
				if image.get_pixel(x, y).a >= 0.5:
					visible += 1
					bottom = maxi(bottom, y - region.position.y + 1)
					_check(x > region.position.x and x < region.end.x - 1 and y > region.position.y and y < region.end.y - 1, "Pig pose clipped")
		_check(visible > 10000, "Pig pose is empty")
		_check(is_equal_approx(bottom + atlas.margin.position.y, 620.0), "Pig hooves must share a baseline")
	root.get_node("GameState").get("flags")["intro_seen"] = true
	var world := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(world)
	await process_frame
	_check(get_nodes_in_group("village_pig_art").size() == 1, "Village needs exactly one pig")
	var pig := get_first_node_in_group("village_pig_art") as AnimatedSprite3D
	_check(pig.is_playing() and pig.animation == &"idle", "Pig idle must start automatically")
	_check(not pig.shaded and pig.modulate.is_equal_approx(Color("c8b9c5")) and pig.billboard == BaseMaterial3D.BILLBOARD_FIXED_Y, "Pig character tint or upright billboard regressed")
	_check(pig.texture_filter == BaseMaterial3D.TEXTURE_FILTER_NEAREST and pig.alpha_cut == SpriteBase3D.ALPHA_CUT_DISCARD, "Pig filtering or alpha regressed")
	_check(is_equal_approx(pig.position.y - 300.0 * pig.pixel_size, 0.015), "Pig hooves are not grounded")
	_check(pig.get_child_count() == 0, "Pig must remain a visual-only actor")
	var seen: Dictionary[int, bool] = {}
	var deadline := Time.get_ticks_msec() + 2300
	while Time.get_ticks_msec() < deadline:
		seen[pig.frame] = true
		await process_frame
	_check(seen.size() == 2, "Real idle playback never reached both pig poses")
	world.call("_load_map", "ruins", "from_village")
	await process_frame
	_check(get_nodes_in_group("village_pig_art").is_empty(), "Pig leaked into ruins")
	world.call("_load_map", "village", "from_ruins")
	await process_frame
	_check(get_nodes_in_group("village_pig_art").size() == 1, "Returning to village must recreate one pig")
	world.queue_free()
	await process_frame
	if _failures == 0:
		print("PIG_ART_TEST_PASS atlas alpha baseline playback map_lifecycle")
	quit(0 if _failures == 0 else 1)
