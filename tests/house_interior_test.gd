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
		var chest := room.get_node("StorageChest") as Node3D
		_check(room.get_node("inspect_house_shelf").get("prompt_text") == "查看" + str(Houses.FURNITURE[home.id].name), "Furniture inspection prompt does not match art")
		var new_themes: Dictionary = {"house_03": "MoonRecordStand", "house_05": "LinenCupboard", "house_06": "TravelGearStand", "house_07": "HerbDryingStand"}
		for map_id: String in new_themes:
			var furnishing := room.get_node_or_null(new_themes[map_id]) as Node3D
			_check((furnishing != null) == (home.id == map_id), "Wrong themed furnishing: " + map_id)
			if furnishing == null:
				continue
			_check(furnishing.find_children("*", "CollisionObject3D", true, false).is_empty(), "Themed furnishing added collision")
			for part: Node in furnishing.find_children("*", "MeshInstance3D", true, false):
				var visual := part as MeshInstance3D
				var bounds: AABB = visual.global_transform * visual.get_aabb()
				_check(bounds.position.x >= -3.76 and bounds.end.x <= -3.04 and bounds.position.z >= 0.725 and bounds.end.z <= 2.475, "Themed furnishing exceeds original footprint: " + map_id)
			match map_id:
				"house_03":
					_check(furnishing.find_children("RecordRoll*", "MeshInstance3D", false, false).size() == 5, "Moon records missing")
				"house_05":
					_check(furnishing.find_children("FoldedLinen*", "MeshInstance3D", false, false).size() == 12, "Folded linen missing")
					_check(furnishing.find_children("ClothBolt*", "MeshInstance3D", false, false).size() == 4, "Cloth bolts missing")
				"house_06":
					_check(furnishing.has_node("TravelPack") and furnishing.has_node("Bedroll") and furnishing.has_node("WalkingStaff"), "Travel equipment missing")
				"house_07":
					_check(furnishing.find_children("HerbBundle*", "Node3D", false, false).size() == 4, "Herb bundles missing")
					_check(furnishing.find_children("HerbPot*", "Node3D", false, false).size() == 3, "Herb pots missing")
		var rack := room.get_node_or_null("PotteryRack") as Node3D
		var bench := room.get_node_or_null("PottingBench") as Node3D
		var library := room.get_node_or_null("LibraryCabinet") as Node3D
		var loom := room.get_node_or_null("WeavingFrame") as Node3D
		_check((loom != null) == (home.id == "house_01"), "Weaving frame appeared in wrong home")
		if loom != null:
			_check(loom.find_children("Warp*", "MeshInstance3D", false, false).size() == 25, "Loom warp threads missing")
			_check(loom.has_node("WovenCloth") and loom.has_node("Shuttle"), "Loom cloth or shuttle missing")
			_check(loom.find_children("*", "CollisionObject3D", true, false).is_empty(), "Loom added collision")
			for part: Node in loom.find_children("*", "MeshInstance3D", true, false):
				var visual := part as MeshInstance3D
				var bounds: AABB = visual.global_transform * visual.get_aabb()
				_check(bounds.position.x >= -3.76 and bounds.end.x <= -3.04 and bounds.position.z >= 0.725 and bounds.end.z <= 2.475, "Loom extends into circulation lane")
		_check((library != null) == (home.id == "house_08"), "Library cabinet appeared in wrong home")
		if library != null:
			_check(library.find_children("ArchiveBook*", "Node3D", false, false).size() == 9, "Archive books missing")
			_check(library.find_children("ArchiveScroll*", "MeshInstance3D", false, false).size() == 9, "Archive scrolls missing")
			_check(library.has_node("ReadingStand/BookCover"), "Open reading book missing")
			_check(library.find_children("*", "CollisionObject3D", true, false).is_empty(), "Library cabinet added collision")
			for part: Node in library.find_children("*", "MeshInstance3D", true, false):
				var visual := part as MeshInstance3D
				var bounds: AABB = visual.global_transform * visual.get_aabb()
				_check(bounds.position.x >= -3.76 and bounds.end.x <= -3.04 and bounds.position.z >= 0.725 and bounds.end.z <= 2.475, "Library art extends into circulation lane")
		_check((bench != null) == (home.id == "house_02"), "Potting bench appeared in wrong home")
		if bench != null:
			_check(bench.find_children("Seedling*", "Node3D", false, false).size() == 3, "Expected three nursery pots")
			_check(bench.find_children("*", "CollisionObject3D", true, false).is_empty(), "Potting bench added collision")
			for part: Node in bench.find_children("*", "MeshInstance3D", true, false):
				var visual := part as MeshInstance3D
				var bounds: AABB = visual.global_transform * visual.get_aabb()
				_check(bounds.position.x >= -3.76 and bounds.end.x <= -3.04 and bounds.position.z >= 0.725 and bounds.end.z <= 2.475, "Nursery art extends into circulation lane")
			for index: int in range(3):
				var seedling := bench.get_node("Seedling%d" % index) as Node3D
				_check(is_equal_approx(seedling.position.y, 0.96), "Nursery pot floats above bench")
				_check(seedling.find_children("Leaf*", "MeshInstance3D", false, false).size() == 6, "Seedling leaves missing")
		_check((rack != null) == (home.id == "house_04"), "Pottery rack appeared in wrong home")
		if rack != null:
			_check(rack.find_children("DryingPot*", "Node3D", false, false).size() == 9, "Drying rack needs nine pots")
			_check(rack.find_children("*", "CollisionObject3D", true, false).is_empty(), "Drying rack added collision")
			for level: int in range(3):
				for column: int in range(3):
					var pot := rack.get_node("DryingPot%d%d" % [level, column]) as Node3D
					_check(is_equal_approx(pot.position.y, 0.225 + level * 0.67), "Pot is not supported on shelf")
		_check(chest.get_node_or_null("Latch") != null and chest.get_node_or_null("LidSeam") != null, "Chest lid and latch missing")
		var chest_bounds := AABB(Vector3(2.925, 0, 2.135), Vector3(0.85, 0.8, 0.83)).grow(0.001)
		for part: Node in chest.get_children():
			var mesh := part as MeshInstance3D
			_check(chest_bounds.encloses(mesh.global_transform * mesh.get_aabb()), "Chest art exceeds existing collision bounds")
		for required: String in ["FloorCollision", "BedFrame", "TableTop", "Hearth", "ShelfBack", "leave_house"]:
			_check(room.get_node_or_null(required) != null, "Missing furnishing or exit: " + required)
		_check(not (world.get_node("Moonlight") as DirectionalLight3D).visible, "Outdoor moonlight leaked inside")
		_check(world.get("_environment").background_mode == Environment.BG_CANVAS and world.get("_interior_backdrop").visible, "Interior backdrop missing")
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
		_check(world.get("_environment").background_mode == Environment.BG_COLOR and not world.get("_interior_backdrop").visible, "Interior backdrop leaked outside")
		_check(not bool(world.get_node("CameraRig").get("_indoors")), "Outdoor camera not restored")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	world.queue_free()
	await process_frame
	if _failures == 0:
		print("HOUSE_INTERIOR_TEST_PASS eight_entrances furniture collision return_spawns save_load camera minimap")
	quit(0 if _failures == 0 else 1)
