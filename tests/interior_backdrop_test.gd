extends SceneTree
var failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func _sample(world: Node) -> void:
	for frame: int in range(8):
		await process_frame
	await RenderingServer.frame_post_draw
	var picture := root.get_texture().get_image()
	for uv: Vector2 in [Vector2(0.008, 0.48), Vector2(0.992, 0.48), Vector2(0.5, 0.012)]:
		var pixel := picture.get_pixel(int(uv.x * picture.get_width()), int(uv.y * picture.get_height()))
		_check(pixel.r > 0.025 and pixel.r < 0.15 and pixel.g < 0.15 and pixel.b < 0.17, "Interior backdrop is washed out or black: " + str(pixel))
		print("BACKDROP_PIXEL ", RenderingServer.get_current_rendering_method(), " size=", picture.get_size(), " rgb=", pixel)
	if "--backdrop-capture" in OS.get_cmdline_user_args():
		picture.save_png("res://.dream-loop/interior-backdrop-%s-%d.png" % [RenderingServer.get_current_rendering_method(), picture.get_width()])
	_check(bool(world.get("_environment").glow_enabled), "Fix disabled scene glow")

func _run() -> void:
	var state := root.get_node("GameState")
	state.call("reset_new_game", false)
	state.get("flags")["intro_seen"] = true
	var world := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(world)
	var env: Environment = world.get("_environment")
	var backdrop := world.get("_interior_backdrop") as ColorRect
	_check(not backdrop.visible and env.background_mode == Environment.BG_COLOR, "Backdrop leaked into village")
	for id: String in ["house_02", "house_08"]:
		world.call("_load_map", id, "entry")
		_check(backdrop.visible and env.background_mode == Environment.BG_CANVAS, "Interior canvas background missing")
		_check(env.background_canvas_max_layer == -10 and (backdrop.get_parent() as CanvasLayer).layer == -10, "Backdrop captures HUD layers")
		_check(backdrop.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Backdrop intercepts input")
		if DisplayServer.get_name() != "headless":
			for size: Vector2i in [Vector2i(1280, 720), Vector2i(960, 640)]:
				root.size = size
				await _sample(world)
		world.call("_load_map", "ruins", "from_village")
		_check(not backdrop.visible and env.background_mode == Environment.BG_COLOR, "Backdrop leaked into ruins")
	world.free()
	for singleton: String in ["GameAudio", "GameMusic", "GameAmbience"]:
		root.get_node(singleton).call("stop_all")
	await create_timer(0.25).timeout
	if failures == 0:
		print("INTERIOR_BACKDROP_TEST_PASS transitions canvas_order input glow_preserved" + (" rendered_pixels resize" if DisplayServer.get_name() != "headless" else " structural_only"))
	quit(0 if failures == 0 else 1)
