extends SceneTree

const Houses = preload("res://scripts/gameplay/house_catalog.gd")
var _failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)


func _settle() -> void:
	for frame: int in range(3):
		await physics_frame
		await process_frame


func _run() -> void:
	var state := root.get_node("GameState")
	state.get("flags")["intro_seen"] = true
	var world := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(world)
	var player := world.get_node("Player") as CharacterBody3D
	player.set_physics_process(false)
	await _settle()
	_check(get_nodes_in_group("house_entrances").size() == 8, "Village needs eight entrances")
	var save_path := "user://house_visit_test_%d.json" % OS.get_process_id()
	for home: Dictionary in Houses.HOMES:
		player.position = Houses.return_position(home.id)
		await _settle()
		var target: Node = player.call("get_nearest_interactable")
		_check(target != null and target.get("interaction_id") == "enter_" + str(home.id), "House entrance not reachable: " + str(home.id))
		if target == null:
			continue
		target.call("interact")
		await _settle()
		_check(state.get("current_map") == home.id, "Wrong interior entered")
		var map_root := world.get("_map_root") as Node3D
		var room := map_root.get_node_or_null("HouseInterior") as Node3D
		_check(room != null, "Interior not built")
		if room == null:
			continue
		for required: String in ["FloorCollision", "BedFrame", "TableTop", "Hearth", "ShelfBack", "leave_house"]:
			_check(room.get_node_or_null(required) != null, "Missing furnishing or exit: " + required)
		_check(not (world.get_node("Moonlight") as DirectionalLight3D).visible, "Outdoor moonlight leaked inside")
		_check(bool(world.get_node("CameraRig").get("_indoors")), "Interior camera not enabled")
		var walls: Array = room.get("_walls")
		room.call("_process", 0.0)
		var visible_walls: int = 0
		for wall: Node3D in walls:
			visible_walls += 1 if wall.visible else 0
		_check(visible_walls == 2, "Near walls must cut away for interior camera")
		for boundary: int in range(4):
			_check(room.get_node("Boundary%d" % boundary) is StaticBody3D, "Hidden wall lost collision")
		var mini_map := world.get("_mini_map") as Control
		_check(mini_map.call("get_map_id") == home.id and not bool(mini_map.call("has_optional_target")), "Interior minimap contains village markers")
		player.position = Vector3(0, 0.1, 0.1)
		await _settle()
		_check(player.test_move(player.global_transform, Vector3(1.5, 0, 0)), "Table collision missing")
		_check(not player.test_move(player.global_transform, Vector3(0, 0, 1.8)), "Exit circulation lane blocked")
		state.call("remember_player_position", player.position)
		_check(bool(state.call("save_game", save_path, false)), "Interior save failed")
		world.call("_load_map", "village", "default")
		_check(bool(state.call("load_game", save_path, false)), "Interior load failed")
		await _settle()
		_check(state.get("current_map") == home.id and player.position.is_equal_approx(Vector3(0, 0.1, 0.1)), "Interior save position did not round-trip")
		player.position = Vector3(0, 0.1, 2.0)
		await _settle()
		target = player.call("get_nearest_interactable")
		_check(target != null and target.get("interaction_id") == "leave_house", "Exit not reachable")
		if target != null:
			target.call("interact")
		await _settle()
		_check(state.get("current_map") == "village", "Did not return to village")
		_check(player.position.is_equal_approx(Houses.return_position(home.id)), "Returned at wrong house")
		_check((world.get_node("Moonlight") as DirectionalLight3D).visible, "Outdoor lighting not restored")
		_check(not bool(world.get_node("CameraRig").get("_indoors")), "Outdoor camera not restored")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	world.queue_free()
	await process_frame
	if _failures == 0:
		print("HOUSE_INTERIOR_TEST_PASS eight_entrances furniture collision return_spawns save_load camera minimap")
	quit(0 if _failures == 0 else 1)
