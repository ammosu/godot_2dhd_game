extends SceneTree
## Actual GPU regression: run without --headless on both desktop renderers.


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for singleton: String in ["GameAudio", "GameMusic", "GameAmbience"]:
		root.get_node(singleton).call("stop_all")
	await create_timer(0.25).timeout
	if DisplayServer.get_name() == "headless":
		push_error("Water render test requires a real renderer, not --headless")
		quit(1)
		return
	var viewport := SubViewport.new()
	viewport.size = Vector2i(320, 240)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.own_world_3d = true
	root.add_child(viewport)
	var scene := Node3D.new()
	viewport.add_child(scene)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color.BLACK
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = 0.8
	scene.add_child(environment)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 10.0
	camera.position = Vector3(0, 8, 0)
	camera.rotation_degrees.x = -90
	scene.add_child(camera)
	preload("res://scripts/gameplay/water_feature.gd").build(scene, Vector3.ZERO, Vector2(9, 5))
	await create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	var first: Image = viewport.get_texture().get_image()
	await create_timer(1.5).timeout
	await RenderingServer.frame_post_draw
	var second: Image = viewport.get_texture().get_image()
	var changed: int = 0
	var visible: int = 0
	var minimum: float = 1.0
	var maximum: float = 0.0
	# Central region lies wholly inside the water, excluding coping/background.
	for y: int in range(85, 155, 2):
		for x: int in range(65, 255, 2):
			var a: Color = first.get_pixel(x, y)
			var b: Color = second.get_pixel(x, y)
			if absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b) > 0.012:
				changed += 1
			if a.b > a.r and a.get_luminance() > 0.01:
				visible += 1
			minimum = minf(minimum, a.get_luminance())
			maximum = maxf(maximum, a.get_luminance())
	if changed < 30 or visible < 2500 or maximum - minimum < 0.015:
		push_error("Water failed visible/animated/contrast checks: %s %s %s" % [changed, visible, maximum - minimum])
		viewport.free()
		quit(1)
		return
	viewport.free()
	print("WATER_RENDER_TEST_PASS animated_pixels=", changed, " visible_pixels=", visible, " contrast=", maximum - minimum)
	quit()
