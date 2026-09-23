extends SceneTree
const Bounds := Rect2(-32, -32, 60, 64)
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var state := root.get_node("GameState")
	state.call("reset_new_game", false)
	state.get("flags")["intro_seen"] = true
	var world := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(world)
	world.set("_test_mode", true)
	var player: CharacterBody3D = world.get_node("Player")
	for id: String in ["east_road", "firefly_forest", "caravan_road"]:
		world.call("_load_map", id, "default")
		for frame: int in range(5):
			await physics_frame
		var terrain: Node = world.get("_map_root").get_node("OutdoorLandscape")
		var space: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
		var raised: int = 0
		for x: int in range(-14, 15, 2):
			for z: int in range(-12, 13, 2):
				var at := Vector2(x, z)
				var height: float = terrain.soil_height(at)
				if height < 0.35:
					continue
				var ray := PhysicsRayQueryParameters3D.create(Vector3(x, height + 0.08, z), Vector3(x, height - 0.08, z), 1, [player.get_rid()])
				assert(not space.intersect_ray(ray).is_empty(), "raised soil lacks matching collision " + id)
				raised += 1
		assert(raised > 8, "outdoor landscape should contain real relief " + id)
	# A real walk onto the grassy bank exercises height-aware map navigation.
	world.call("_load_map", "caravan_road", "from_road")
	for frame: int in range(10):
		await physics_frame
	var terrain: Node = world.get("_map_root").get_node("OutdoorLandscape")
	var target := Vector3.ZERO
	var found: bool = false
	var space: PhysicsDirectSpaceState3D = world.get_world_3d().direct_space_state
	var shape := CylinderShape3D.new()
	shape.radius = 0.44
	shape.height = 0.9
	for x: int in range(-46, -23):
		for z: int in range(30, 44):
			var point := Vector2(x, z) * 0.5
			var h: float = terrain.soil_height(point)
			if h < 0.2 or h > 1.2:
				continue
			var query := PhysicsShapeQueryParameters3D.new()
			query.shape = shape
			query.transform.origin = Vector3(point.x, h + 0.8, point.y)
			query.collision_mask = 1
			query.exclude = [player.get_rid()]
			if space.intersect_shape(query, 1).is_empty():
				target = Vector3(point.x, h, point.y)
				found = true
				break
		if found:
			break
	assert(found, "missing accessible grassy bank")
	assert(player.get("auto_walk").start(target, Bounds))
	for frame: int in range(1200):
		await physics_frame
		if not player.get("auto_walk").is_active():
			break
	assert(player.position.distance_to(target) < 0.5, "bank walk stalled " + str(player.position) + " target " + str(target))
	# An older flat-ground save is lifted above the new soil without schema changes.
	state.set("saved_position", Vector3(target.x, 0.1, target.z))
	state.set("has_saved_position", true)
	world.call("_load_map", "caravan_road", "saved_position")
	assert(player.position.y >= target.y, "saved player buried under new hill")
	world.free()
	for singleton: String in ["GameAudio", "GameMusic", "GameAmbience"]:
		root.get_node(singleton).call("stop_all")
	await create_timer(0.25).timeout
	print("OUTDOOR_LANDSCAPE_TEST_PASS relief collision bank_walk old_save_height")
	quit()
