extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _key(code: Key) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	Input.parse_input_event(event)
	await process_frame

func _run() -> void:
	var state := root.get_node("GameState")
	state.get("flags")["intro_seen"] = true
	var world := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	# Enable test save isolation after ready, without starting the built-in playthrough.
	root.add_child(world)
	world.set("_test_mode", true)
	await process_frame
	var ui := world.get_node("MapUI")
	var player := world.get_node("Player") as CharacterBody3D
	for map_id: String in ["village", "ruins", "east_road", "firefly_forest", "house_01"]:
		world.call("_load_map", map_id, "default")
		await process_frame
		await _key(KEY_G)
		assert(ui.visible and state.is_input_locked())
		assert(ui.map_view.get_map_id() == map_id)
		assert(ui.map_view.has_main_target() == ui.source_map.has_main_target())
		assert(ui.map_view.has_optional_target() == ui.source_map.has_optional_target())
		var at := player.position
		Input.action_press("move_forward")
		await create_timer(0.12).timeout
		Input.action_release("move_forward")
		assert(player.position.is_equal_approx(at), "Player moved while map open")
		var center: Vector2 = ui.map_view._world_to_map(Vector3.ZERO)
		assert(ui.map_view._world_to_map(Vector3(0, 0, -1)).y < center.y)
		await _key(KEY_ESCAPE)
		assert(not ui.visible and not state.is_input_locked())
	# G toggles, and UI button opens the same modal.
	await _key(KEY_G)
	await _key(KEY_G)
	assert(not ui.visible)
	ui.open_button.pressed.emit()
	assert(ui.visible)
	ui.close()
	for mode: int in [1, 2, 3, 4]:
		state.set_mode(mode)
		await _key(KEY_G)
		assert(not ui.visible and state.mode == mode)
	state.set_mode(0)
	world.call("_load_map", "village", "default")
	await process_frame
	ui.open()
	if DisplayServer.get_name() != "headless":
		await create_timer(0.4).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/wanderlight-large-map.png")
	ui.close()
	world.free()
	for singleton: String in ["GameAudio", "GameMusic", "GameAmbience"]:
		root.get_node(singleton).call("stop_all")
	await create_timer(0.25).timeout
	print("MAP_UI_TEST_PASS five_regions input_lock modal_guards keyboard button north_up targets")
	quit()
