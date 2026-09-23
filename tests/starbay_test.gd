extends SceneTree
var City: GDScript
var save_path: String = "user://starbay_test_%d.json" % OS.get_process_id()
var world: Node3D
var state: Node

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool, message: String) -> void:
	if not condition:
		push_error("STARBAY_TEST_FAIL " + message)
		quit(1)

func settle() -> void:
	for frame: int in range(4):
		await physics_frame
		await process_frame

func cross(id: String, expected: String) -> void:
	var exit: Area3D = world.get("_map_root").get_node(id)
	world.get_node("Player").position = exit.position + Vector3(0, 0.1, 0)
	await settle()
	check(state.get("current_map") == expected, "walking exit " + id)
	await settle()
	check(state.get("current_map") == expected, "no bounce at " + id)

func sweep(points: PackedVector2Array, label: String) -> void:
	var shape := CapsuleShape3D.new()
	shape.radius = 0.28
	shape.height = 1.1
	for index: int in range(points.size() - 1):
		var a := Vector3(points[index].x, 0.7, points[index].y)
		var b := Vector3(points[index + 1].x, 0.7, points[index + 1].y)
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = shape
		query.transform.origin = a
		query.motion = b - a
		query.collision_mask = 1
		query.exclude = [(world.get_node("Player") as CollisionObject3D).get_rid()]
		var result := world.get_world_3d().direct_space_state.cast_motion(query)
		check(result[0] > 0.99, "%s blocked at %s" % [label, a])
		var floor_query := PhysicsRayQueryParameters3D.create(a, a - Vector3(0, 2, 0), 1)
		floor_query.exclude = query.exclude
		check(not world.get_world_3d().direct_space_state.intersect_ray(floor_query).is_empty(), "missing floor " + str(a))

func _run() -> void:
	City = load("res://scripts/gameplay/starbay.gd")
	state = root.get_node("GameState")
	state.call("reset_new_game", false)
	state.get("flags")["intro_seen"] = true
	world = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(world)
	world.set("_test_mode", true)
	await settle()
	await cross("travel_east", "east_road")
	await cross("travel_caravan", "caravan_road")
	sweep(City.curve(City.ROAD).slice(3, -3), "caravan")
	await cross("travel_city", "starbay")
	check(get_nodes_in_group("city_houses").size() == 26, "city houses")
	check(world.get("_mini_map").get_map_id() == "starbay", "minimap")
	check(not world.get("_mini_map").has_main_target(), "no unrelated quest marker")
	for index: int in range(City.STREETS.size()):
		sweep(City.curve(City.STREETS[index]).slice(2, -2), "street%d" % index)
	var streets: Array = []
	for street: Array in City.STREETS:
		streets.append(City.curve(street))
	for index: int in range(City.HOMES.size()):
		var approach: PackedVector2Array = City.Streets.approach(index, streets)
		check(approach[0].distance_to(approach[1]) > 0.1, "door lane missing %d" % index)
		sweep(approach, "door lane%d" % index)
	check(get_nodes_in_group("civic_landmarks").size() == 3, "three civic landmarks")
	for index: int in range(City.Civic.LINKS.size()):
		sweep(City.curve(City.Civic.LINKS[index]), "civic link%d" % index)
	sweep(City.Civic.ring(City.Civic.MOON, 2.9), "moon promenade")
	sweep(City.Civic.ring(City.Civic.TREE, 2.3), "tree promenade")
	for id: String in City.Civic.TALKS:
		world.call("_handle_interaction", id)
		check(world.get_node("DialogueUI").call("is_open"), "civic dialogue " + id)
		while world.get_node("DialogueUI").call("is_open"):
			world.get_node("DialogueUI").call("advance")
	check(world.get_node("Player").position.y > -0.1, "player grounded")
	var footsteps := preload("res://scripts/gameplay/footsteps.gd")
	check(footsteps.surface_at(self, Vector3(-6, 0.05, 11)) == &"stone", "polygon stone footsteps")
	check(footsteps.surface_at(self, Vector3(-35, 0.05, 20)) == &"dirt", "outside street footsteps")
	world.call("_talk_to_wandering_villager", world.get("_map_root").get_node("CityResident0"))
	check(world.get_node("DialogueUI").call("is_open"), "resident conversation")
	while world.get_node("DialogueUI").call("is_open"):
		world.get_node("DialogueUI").call("advance")
	state.set("player_hp", 1)
	state.set("player_mp", 0)
	world.call("_handle_interaction", "city_rest")
	check(state.get("player_hp") == state.get("player_max_hp"), "rest hp")
	check(state.get("player_mp") == state.get("player_max_mp"), "rest mp")
	while world.get_node("DialogueUI").call("is_open"):
		world.get_node("DialogueUI").call("advance")
	state.call("remember_player_position", Vector3(-6, 0.1, 11))
	check(state.call("save_game", save_path, false), "save")
	state.call("reset_new_game", false)
	check(state.call("load_game", save_path, false), "load")
	await settle()
	check(state.get("current_map") == "starbay", "saved city")
	check(world.get_node("Player").position.distance_to(Vector3(-6, 0.1, 11)) < 0.5, "saved position")
	if "--capture" in OS.get_cmdline_user_args():
		for shot: Array in [["starbay_moon", Vector3(-6, 0.1, -9)], ["starbay_tree", Vector3(-15.7, 0.1, 10)], ["starbay_pavilion", Vector3(8, 0.1, 1)], ["starbay_market", Vector3(-6, 0.1, 12)], ["starbay_belfry", Vector3(-8, 0.1, -22)]]:
			world.get_node("Player").position = shot[1]
			world.get_node("CameraRig").call("snap_to_target")
			for frame: int in range(12):
				await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("/tmp/" + shot[0] + ".png")
		world.get_node("MapUI").call("open")
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/starbay_map.png")
		world.get_node("MapUI").call("close")
	await cross("travel_city_home", "caravan_road")
	if "--capture" in OS.get_cmdline_user_args():
		world.get_node("Player").position = Vector3(3, 0.1, 10)
		world.get_node("CameraRig").call("snap_to_target")
		for frame: int in range(12):
			await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/starbay_road.png")
	await cross("travel_caravan_back", "east_road")
	await cross("travel_home", "village")
	check(state.get("quest_state") == 0, "main quest unchanged")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	world.free()
	for singleton: String in ["GameAudio", "GameMusic", "GameAmbience"]:
		root.get_node(singleton).call("stop_all")
	await create_timer(0.25).timeout
	print("STARBAY_TEST_PASS walking_roundtrip streets floor rest save minimap")
	quit()
