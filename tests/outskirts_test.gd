extends SceneTree

const Outskirts = preload("res://scripts/gameplay/outskirts.gd")
const SAVE := "user://outskirts_test.json"

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var state := root.get_node("GameState")
	state.call("reset_new_game", false)
	state.get("flags")["intro_seen"] = true
	var world := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(world)
	world.set("_test_mode", true)
	world.call("_handle_interaction", "travel_east")
	await process_frame
	assert(state.get("current_map") == "east_road")
	assert(world.get("_map_label").text.contains("東行舊道"))
	assert(world.get("_map_root").get_node("RoadSign").rotation.z < 0)
	world.call("_handle_interaction", "road_traveler")
	assert(state.get("flags").parcel_requested)
	assert(not state.get("flags").has("road_traveler"))
	var dialogue := world.get_node("DialogueUI")
	for page: int in range(4):
		if dialogue.call("is_open"):
			dialogue.call("advance")
	# Clear the request to exercise pickup before accepting a quest as well.
	state.get("flags").erase("parcel_requested")
	var initial: int = state.get("inventory").potion
	state.call("resolve_outskirts_event", "forest_herb")
	assert(state.get("inventory").potion == initial)
	state.call("resolve_outskirts_event", "road_sign")
	state.call("resolve_outskirts_event", "road_sign")
	assert(state.get("inventory").potion == initial + 1)
	assert(is_zero_approx(world.get("_map_root").get_node("RoadSign").rotation.z))
	assert(not world.get("_quest_markers")["road_sign"].visible)
	world.call("_handle_interaction", "travel_forest")
	await process_frame
	assert(state.get("current_map") == "firefly_forest")
	state.call("resolve_outskirts_event", "forest_parcel")
	assert(state.get("inventory").lost_parcel == 1)
	state.call("resolve_outskirts_event", "forest_herb")
	state.call("resolve_outskirts_event", "forest_herb")
	assert(state.get("inventory").potion == initial + 2)
	state.set("player_hp", 1)
	state.set("player_mp", 0)
	state.call("resolve_outskirts_event", "forest_rest")
	assert(state.get("player_hp") == state.get("player_max_hp"))
	assert(state.get("player_mp") == state.get("player_max_mp"))
	state.call("remember_player_position", Vector3(0, 0.1, -9))
	assert(state.call("save_game", SAVE, false))
	state.call("reset_new_game", false)
	assert(state.call("load_game", SAVE, false))
	await process_frame
	assert(state.get("current_map") == "firefly_forest")
	assert(state.get("flags").forest_herb)
	assert(state.get("inventory").lost_parcel == 1)
	for frame: int in range(3):
		await physics_frame
	# A physical sweep along each marked trail must not hit scenery.
	for segment: Array in [[Vector3(0, 0.8, 11), Vector3(0, 0.8, -10)], [Vector3(-7, 0.8, -3), Vector3(7, 0.8, -3)], [Vector3(7, 0.8, -3), Vector3(7, 0.8, -7)]]:
		var query := PhysicsRayQueryParameters3D.create(segment[0], segment[1], 1)
		query.exclude = [(world.get_node("Player") as CollisionObject3D).get_rid()]
		assert(world.get_world_3d().direct_space_state.intersect_ray(query).is_empty())
	if "--capture" in OS.get_cmdline_user_args():
		for map_id: String in ["firefly_forest", "east_road"]:
			world.call("_load_map", map_id, "default")
			world.get_node("Player").position = Vector3(0, 0.1, 3)
			world.get_node("CameraRig").call("snap_to_target")
			for frame: int in range(15):
				await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("/tmp/" + map_id + ".png")
		world.call("_load_map", "firefly_forest", "default")
	world.call("_handle_interaction", "travel_road")
	await process_frame
	assert(state.get("current_map") == "east_road")
	state.call("resolve_outskirts_event", "road_traveler")
	state.call("resolve_outskirts_event", "road_traveler")
	assert(state.get("inventory").potion == initial + 4)
	assert(not state.get("inventory").has("lost_parcel"))
	world.call("_handle_interaction", "travel_home")
	await process_frame
	assert(state.get("current_map") == "village")
	assert(world.get_node("Player").position.distance_to(Vector3(24, 0.1, 4.6)) < 0.5)
	world.call("_handle_interaction", "travel_east")
	await process_frame
	world.call("_handle_interaction", "travel_forest")
	await process_frame
	state.call("resolve_outskirts_event", "forest_parcel")
	assert(not state.get("inventory").has("lost_parcel"))
	assert(state.get("quest_state") == 0)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	world.free()
	for singleton: String in ["GameAudio", "GameMusic", "GameAmbience"]:
		root.get_node(singleton).call("stop_all")
	await create_timer(0.25).timeout
	print("OUTSKIRTS_TEST_PASS routes events early_pickup rewards save trails main_quest")
	quit()
