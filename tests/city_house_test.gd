extends SceneTree
const Houses = preload("res://scripts/gameplay/house_catalog.gd")
const City = preload("res://scripts/gameplay/city_house_catalog.gd")
var failures: int = 0

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error("CITY_HOUSE_TEST_FAIL " + message)

func settle() -> void:
	for frame: int in range(4):
		await physics_frame
		await process_frame

func _run() -> void:
	var state := root.get_node("GameState")
	state.call("reset_new_game", false)
	state.get("flags")["intro_seen"] = true
	var world := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(world)
	world.set("_test_mode", true)
	world.call("_load_map", "starbay", "default")
	var player := world.get_node("Player") as CharacterBody3D
	player.set_physics_process(false)
	await settle()
	check(get_nodes_in_group("house_entrances").size() == 26, "26 usable doors")
	var tested_kinds: Dictionary = {}
	var save_path := "user://city_house_test_%d.json" % OS.get_process_id()
	for index: int in range(City.POSITIONS.size()):
		var id := City.address(index)
		var kind: String = City.home(id).kind
		player.position = Houses.return_position(id)
		await settle()
		var entrance: Node3D = world.get("_map_root").get_node("CityHouse%d/HouseEntrance" % index)
		player.call("release_door_facing")
		player.call("face_world_position", entrance.global_position)
		var target: Node = player.call("get_nearest_interactable")
		check(target != null and target.get("interaction_id") == "enter_" + id, "door reachable " + id)
		if target == null or target.get("interaction_id") != "enter_" + id:
			continue
		target.call("interact")
		await create_timer(2.6).timeout
		await settle()
		check(state.get("current_map") == id, "animated entry " + id)
		if state.get("current_map") != id:
			continue
		check(not state.call("is_input_locked"), "entry unlock " + id)
		var room: Node3D = world.get("_map_root").get_node("HouseInterior")
		check(room.get_meta("room_kind") == kind, "layout type " + id)
		check(world.get("_mini_map").get_map_id() == id, "interior map " + id)
		var shape := CapsuleShape3D.new()
		shape.radius = 0.3
		shape.height = 1.2
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = shape
		query.transform.origin = Vector3(0, 0.7, 2.6)
		query.motion = Vector3(0, 0, -4.65)
		query.collision_mask = 1
		query.exclude = [player.get_rid()]
		var sweep: PackedFloat32Array = world.get_world_3d().direct_space_state.cast_motion(query)
		check(sweep[0] > 0.99, "entry to inspection aisle " + id)
		var floor_query := PhysicsRayQueryParameters3D.create(Vector3(0, 1, 1.9), Vector3(0, -1, 1.9), 1)
		floor_query.exclude = [player.get_rid()]
		check(not world.get_world_3d().direct_space_state.intersect_ray(floor_query).is_empty(), "floor " + id)
		if not tested_kinds.has(kind):
			world.call("_handle_interaction", "house_resident")
			check(world.get_node("DialogueUI").call("is_open"), "owner dialogue " + kind)
			while world.get_node("DialogueUI").call("is_open"):
				world.get_node("DialogueUI").call("advance")
			world.call("_handle_interaction", "inspect_house_shelf")
			check(world.get_node("DialogueUI").call("is_open"), "inspect " + kind)
			while world.get_node("DialogueUI").call("is_open"):
				world.get_node("DialogueUI").call("advance")
			state.call("remember_player_position", Vector3(0, 0.1, 1.9))
			check(state.call("save_game", save_path, false), "save " + kind)
			check(state.call("load_game", save_path, false), "load " + kind)
			await settle()
			check(state.get("current_map") == id and player.position.distance_to(Vector3(0, 0.1, 1.9)) < 0.1, "saved interior position")
			if "--capture" in OS.get_cmdline_user_args():
				var rig := world.get_node("CameraRig") as Node3D
				rig.set_process(false)
				var camera := root.get_camera_3d()
				camera.size = 17.5
				camera.global_position = Vector3(9, 15, 12)
				camera.look_at(Vector3(0, 0, -1.5))
				for frame: int in range(10):
					await process_frame
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("/tmp/city-house-" + kind + ".png")
				rig.set_process(true)
			tested_kinds[kind] = true
		world.call("_handle_interaction", "leave_house")
		await create_timer(0.85).timeout
		await settle()
		check(state.get("current_map") == "starbay", "return city " + id)
		check(player.position.distance_to(Houses.return_position(id)) < 0.15, "return same doorstep " + id)
		check(not state.call("is_input_locked"), "exit unlock " + id)
		print("CITY_HOUSE_OK ", id, " ", kind)
	check(tested_kinds.size() == 6, "six room types")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	world.free()
	for singleton: String in ["GameAudio", "GameMusic", "GameAmbience"]:
		root.get_node(singleton).call("stop_all")
	await create_timer(0.25).timeout
	if failures == 0:
		print("CITY_HOUSE_TEST_PASS 26_doors six_layouts collisions dialogue save return")
	quit(0 if failures == 0 else 1)
