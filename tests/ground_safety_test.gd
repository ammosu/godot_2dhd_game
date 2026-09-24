extends SceneTree
var _failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var state: Node = root.get_node("GameState")
	state.call("reset_new_game", false)
	state.get("flags")["intro_seen"] = true
	var world := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(world)
	var player := world.get_node("Player") as CharacterBody3D
	player.set_physics_process(false)
	# Every map gets its own fallback; no checkpoint may leak across maps.
	for map_id: String in ["village", "ruins", "east_road", "firefly_forest", "moss_steps", "wind_gorge", "moon_highland", "caravan_road", "starbay", "house_01", "ashen_crypt"]:
		world.call("_load_map", map_id, "default")
		await create_timer(0.1).timeout
		var safe := player.global_position
		player.position = Vector3(1000, -30, 1000)
		player.velocity = Vector3(20, -50, 20)
		await create_timer(0.05).timeout
		_check(player.position.distance_to(safe) < 0.3, "Recovery must remain in map: " + map_id)
		_check(player.velocity == Vector3.ZERO, "Recovery must stop velocity")
	# Reproduce the north opening: its approach ground is only scenery.
	world.call("_load_map", "village", "default")
	await create_timer(0.1).timeout
	player.position = Vector3(0, 0.05, -19.8)
	await create_timer(0.05).timeout
	for step: int in range(25):
		await physics_frame
		player.velocity = Vector3(0, -1, -12)
		player.move_and_slide()
	await create_timer(0.05).timeout
	_check(player.position.z >= -20.0 and player.position.y > -0.2, "North exit must not allow falling onto scenery")
	# Invalid saved coordinates must recover without modifying a real save file.
	state.set("saved_position", Vector3(1000, -30, 1000))
	state.set("has_saved_position", true)
	world.call("_load_map", "ruins", "saved_position")
	await create_timer(0.1).timeout
	var spawn: Vector3 = world.call("_get_spawn_position", "ruins", "default")
	_check(player.position.distance_to(spawn) < 0.3, "Invalid saved position must recover at this map's spawn")
	world.free()
	for singleton: String in ["GameAudio", "GameMusic", "GameAmbience"]:
		root.get_node(singleton).call("stop_all")
	await create_timer(0.2).timeout
	if _failures == 0:
		print("GROUND_SAFETY_TEST_PASS maps edge_movement velocity invalid_save")
	quit(0 if _failures == 0 else 1)


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures += 1
		push_error(message)
