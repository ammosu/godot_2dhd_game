extends SceneTree
## test-requires: gpu
## Pixel checks catch opaque-pass sorting regressions that properties cannot.
var failures: int = 0

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(400, 200)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.0
	camera.position = Vector3(0, 0, 5)
	viewport.add_child(camera)
	var bar: Node3D = load("res://scripts/gameplay/world_health_bar.gd").new()
	viewport.add_child(bar)
	bar.configure(true, "wolf")
	var full_width: int = 0
	for hp: int in [100, 50, 10]:
		bar.set_health(hp, 100)
		for frame: int in range(3):
			await process_frame
		await RenderingServer.frame_post_draw
		var pixels: Image = viewport.get_texture().get_image()
		var bright: int = 0
		var dark: int = 0
		for x: int in range(400):
			var color: Color = pixels.get_pixel(x, 100)
			if color.r > 0.6 and color.g > 0.25:
				bright += 1
			elif color.r > 0.04 and color.r < 0.2:
				dark += 1
		if hp == 100:
			full_width = bright
		var expected: float = full_width * float(hp) / 100.0
		if full_width < 20 or absf(bright - expected) > 3.0 or dark < 2:
			failures += 1
			push_error("Visible health fill mismatch at %d HP: bright=%d dark=%d" % [hp, bright, dark])
		pixels.save_png("/tmp/health-bar-%s-%d.png" % [RenderingServer.get_current_rendering_method(), hp])
	viewport.queue_free()
	await process_frame
	if failures == 0:
		print("HEALTH_BAR_RENDER_TEST_PASS full half low visible_fill")
	quit(0 if failures == 0 else 1)
