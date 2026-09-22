extends SceneTree

func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var state := root.get_node("GameState")
	state.get("flags")["intro_seen"] = true
	var world := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(world)
	world.set("_test_mode", true)
	await physics_frame
	await physics_frame
	var player := world.get_node("Player") as CharacterBody3D
	var nav: Node = player.get("auto_walk")
	var map: Control = world.get("_mini_map")
	assert(map.get("destinations").size() > 5)
	# Compact map is display-only, even when an icon is clicked directly.
	var point: Dictionary = map.get("destinations")[0]
	var compact_click := InputEventMouseButton.new()
	compact_click.button_index = MOUSE_BUTTON_LEFT
	compact_click.pressed = true
	compact_click.position = map.call("_world_to_map", point.position)
	map.call("_gui_input", compact_click)
	assert(not nav.call("is_active"))
	assert(map.call("destination_at", compact_click.position).is_empty())
	assert(map.mouse_filter == Control.MOUSE_FILTER_IGNORE)
	# Walk to the elder through the live village collision geometry.
	var target := Vector3(-3, 0, 1.2)
	assert(nav.call("start", target, map.call("get_world_bounds")), "No route to elder")
	for step: int in range(1200):
		await physics_frame
		if not nav.call("is_active"):
			break
	var at := Vector2(player.position.x, player.position.z)
	assert(at.distance_to(Vector2(target.x, target.z)) < 1.5, "Did not arrive: %s" % at)
	assert(not nav.call("is_active"))
	# Manual movement, dialogue, and map changes must cancel the transient route.
	assert(nav.call("start", Vector3(0, 0, 7.5), map.call("get_world_bounds")))
	Input.action_press("move_right")
	await physics_frame
	await physics_frame
	Input.action_release("move_right")
	assert(not nav.call("is_active"))
	assert(nav.call("start", Vector3(0, 0, 7.5), map.call("get_world_bounds")))
	state.call("set_mode", 1)
	assert(not nav.call("is_active"))
	state.call("set_mode", 0)
	# Large-map click closes the modal and dispatches the same navigation request.
	var ui := world.get_node("MapUI")
	ui.call("open")
	assert(ui.get("map_view").get("interactive"))
	assert(not ui.get("map_view").call("destination_at", ui.get("map_view").call("_world_to_map", point.position)).is_empty())
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = ui.get("map_view").call("_world_to_map", point.position)
	ui.get("map_view").call("_gui_input", click)
	assert(not ui.visible)
	world.call("_load_map", "ruins", "from_village")
	assert(not nav.call("is_active"))
	await physics_frame
	await physics_frame
	assert(not nav.call("start", Vector3(1000, 0, 1000), map.call("get_world_bounds")))
	# Real obstacle detour: ruins central columns must remain solid to walking.
	player.position = Vector3(-6, 0.1, 6)
	await physics_frame
	assert(nav.call("start", Vector3(9, 0, -2), map.call("get_world_bounds")))
	for step: int in range(2400):
		await physics_frame
		if not nav.call("is_active"):
			break
	at = Vector2(player.position.x, player.position.z)
	assert(at.distance_to(Vector2(9, -2)) < 1.5, "Ruins detour stopped: %s" % at)
	for map_id: String in ["starbay", "house_01", "house_city_01"]:
		world.call("_load_map", map_id, "entry" if map_id.begins_with("house") else "from_road")
		await physics_frame
		await physics_frame
		var goal := Vector3(-6, 0, 11) if map_id == "starbay" else Vector3(0, 0, -1)
		var started := Time.get_ticks_msec()
		assert(nav.call("start", goal, map.call("get_world_bounds")), "No route in " + map_id)
		print("NAV_ROUTE ", map_id, " ms=", Time.get_ticks_msec() - started)
		for step: int in range(2400):
			await physics_frame
			if not nav.call("is_active"):
				break
		at = Vector2(player.position.x, player.position.z)
		assert(at.distance_to(Vector2(goal.x, goal.z)) < 1.5, "Stopped in %s: %s" % [map_id, at])
	world.free()
	for singleton: String in ["GameAudio", "GameMusic", "GameAmbience"]:
		root.get_node(singleton).call("stop_all")
	await create_timer(0.25).timeout
	print("MAP_NAVIGATION_TEST_PASS large_icons compact_read_only arrival obstacles manual_cancel mode_cancel map_cancel unreachable large_map")
	quit()
