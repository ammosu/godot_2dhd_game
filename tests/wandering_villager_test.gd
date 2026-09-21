extends SceneTree
var failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _run() -> void:
	var state := root.get_node("GameState")
	state.call("reset_new_game", false)
	state.get("flags")["intro_seen"] = true
	var world := load("res://scenes/main.tscn").instantiate() as Node3D
	root.add_child(world)
	world.set("_test_mode", true)
	var player := world.get_node("Player") as Node3D
	player.set_physics_process(false)
	player.position = Vector3(18, 0.1, 16)
	await physics_frame
	var villagers: Array[Node] = get_nodes_in_group("wandering_villagers")
	check(villagers.size() == 3, "Expected three village walkers")
	var starts: Array[Vector3] = []
	for npc: Node3D in villagers:
		starts.append(npc.position)
	for frame: int in range(180):
		await physics_frame
	for index: int in range(villagers.size()):
		var npc := villagers[index] as Node3D
		check(npc.position.distance_to(starts[index]) > 0.5, "Villager failed to walk")
	var first := villagers[0] as Node3D
	state.set("mode", 1)
	await physics_frame
	var stopped: Vector3 = first.position
	for frame: int in range(30):
		await physics_frame
	check(first.position.is_equal_approx(stopped), "Dialogue must freeze patrols")
	state.set("mode", 0)
	player.position = first.position + Vector3(0.7, 0, 0)
	for frame: int in range(30):
		await physics_frame
	check(Vector2(first.position.x, first.position.z).distance_to(Vector2(stopped.x, stopped.z)) < 0.05, "Villager must yield to nearby player")
	player.position = Vector3(18, 0.1, 16)
	var changed_target: bool = false
	var initial_target: int = first.get("_target")
	for frame: int in range(720):
		await physics_frame
		changed_target = changed_target or first.get("_target") != initial_target
	check(changed_target, "Patrol must reach its endpoint and turn back")
	world.call("_load_map", "ruins", "from_village")
	await process_frame
	check(get_nodes_in_group("wandering_villagers").is_empty(), "Walkers must be removed outside village")
	world.call("_load_map", "village", "default")
	await process_frame
	check(get_nodes_in_group("wandering_villagers").size() == 3, "Returning must recreate exactly three walkers")
	world.queue_free()
	await process_frame
	for singleton: String in ["GameAudio", "GameMusic", "GameAmbience"]:
		root.get_node(singleton).call("stop_all")
	if failures == 0:
		print("WANDERING_VILLAGER_TEST_PASS movement pause proximity patrol maps")
	quit(1 if failures else 0)
