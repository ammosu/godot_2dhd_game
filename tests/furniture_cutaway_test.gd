extends SceneTree

const Houses = preload("res://scripts/gameplay/house_catalog.gd")
var _failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)


func _run() -> void:
	root.get_node("GameState").get("flags")["intro_seen"] = true
	var world := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(world)
	var player := world.get_node("Player") as CharacterBody3D
	player.set_physics_process(false)
	world.get_node("CameraRig").set_process(false)
	var camera := root.get_camera_3d()
	for home: Dictionary in Houses.HOMES:
		world.call("_load_map", str(home.id), "default")
		var room := (world.get("_map_root") as Node).get_node("HouseInterior")
		var cutaway := room.get_node("FurnitureCutaway")
		cutaway.set_process(false)
		player.position = Vector3(-2.5, 0.024, 1.2)
		camera.global_position = Vector3(-6.0, 2.2, 1.6)
		camera.look_at(player.position + Vector3.UP * 0.8)
		cutaway.call("_process", 0.01)
		_check(bool(cutaway.get("active")), "Foreground furnishing failed to cut away: " + str(home.id))
		var parts: Array = cutaway.get("_parts")
		_check(not parts.is_empty(), "Furniture cutaway has no parts")
		for part: Dictionary in parts:
			var visual := part.visual as GeometryInstance3D
			_check(visual.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY or not visual.visible, "Occluding furniture still drawn")
		_check(room.get_node("ShelfCollision").get_child(0) is CollisionShape3D, "Cutaway removed collision")
		_check(room.has_node("inspect_house_shelf"), "Cutaway removed interaction")
		camera.global_position = Vector3(3.0, 3.0, 1.6)
		camera.look_at(player.position + Vector3.UP * 0.8)
		cutaway.call("_process", 0.10)
		_check(bool(cutaway.get("active")), "Cutaway restored before hysteresis")
		cutaway.call("_process", 0.13)
		_check(not bool(cutaway.get("active")), "Furniture did not restore")
		for part: Dictionary in parts:
			_check((part.visual as GeometryInstance3D).cast_shadow == part.shadow, "Original shadow mode not restored")
	world.call("_load_map", "village", "default")
	_check(get_nodes_in_group("foreground_cutaways").size() == 8, "Interior cutaway leaked into village")
	world.free()
	for singleton: String in ["GameAudio", "GameMusic", "GameAmbience"]:
		root.get_node(singleton).call("stop_all")
	await create_timer(0.25).timeout
	if _failures == 0:
		print("FURNITURE_CUTAWAY_TEST_PASS eight_homes obstruction restore collision interaction cleanup")
	quit(0 if _failures == 0 else 1)
