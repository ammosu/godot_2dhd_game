extends SceneTree

const Cutaway = preload("res://scripts/gameplay/foreground_cutaway.gd")
const Houses = preload("res://scripts/gameplay/house_catalog.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	_unit_test()
	root.get_node("GameState").get("flags")["intro_seen"] = true
	var world := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(world)
	var player := world.get_node("Player") as Node3D
	player.set_physics_process(false)
	var rig := world.get_node("CameraRig")
	assert(get_nodes_in_group("foreground_cutaways").size() == 8)
	var blocked_views: int = 0
	for home: Dictionary in Houses.HOMES:
		player.position = Houses.return_position(home.id)
		for distance: float in [7.0, 11.0, 15.0]:
			rig.set("_distance", distance)
			for angle: int in range(8):
				rig.set("_target_yaw", float(angle) * PI / 4.0)
				rig.call("snap_to_target")
				for controller: Node in get_nodes_in_group("foreground_cutaways"):
					controller.set_process(false)
					controller.call("_process", 0.3)
					assert(controller.get("active") == controller.call("obstructs_view"))
					if controller.get("active"):
						blocked_views += 1
						var house := controller.get_parent()
						var tiles := house.get_node("ArchitecturalDetails/SlateRoofTiles") as MultiMeshInstance3D
						assert(tiles.multimesh.custom_aabb.position.y > 1.9)
						assert(tiles.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY)
						assert((house.get_node("HouseEntrance") as Area3D).monitoring)
	assert(blocked_views > 0)
	world.call("_load_map", "house_02", "entry")
	assert(get_nodes_in_group("foreground_cutaways").is_empty())
	world.call("_load_map", "village", "from_house_02")
	assert(get_nodes_in_group("foreground_cutaways").size() == 8)
	world.free()
	print("FOREGROUND_CUTAWAY_TEST_PASS hysteresis shadows tiles 192_views map_cleanup")
	quit()


func _unit_test() -> void:
	var house := Node3D.new()
	root.add_child(house)
	var wall := _box(house, Vector3(0, 1.2, 0), Vector3(2, 2, 2))
	var base := _box(house, Vector3(0, 0.1, 0), Vector3(2, 0.2, 2))
	var glass := _box(house, Vector3(0, 1.2, 1.02), Vector3(0.5, 0.5, 0.05))
	glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var target := Node3D.new()
	root.add_child(target)
	target.position = Vector3(0, 0, -3)
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.position = Vector3(0, 2.5, 5)
	var controller := Cutaway.new()
	house.add_child(controller)
	controller.configure(house, target, camera)
	controller.set_process(false)
	controller._process(0.016)
	assert(controller.active)
	assert(wall.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY)
	assert(base.visible and base.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON)
	assert(not glass.visible and glass.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	target.position = Vector3(8, 0, 5)
	controller._process(0.1)
	assert(controller.active)
	# Clear intervals must not accumulate across renewed obstruction.
	for crossing: int in range(12):
		target.position = Vector3(0, 0, -3)
		controller._process(0.016)
		target.position = Vector3(8, 0, 5)
		controller._process(0.1)
		assert(controller.active, "Repeated edge crossings must restart the restore delay")
	controller._process(0.13)
	assert(not controller.active and glass.visible)
	assert(wall.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON)
	target.position = Vector3(0, 0, -3)
	controller._process(0.01)
	assert(controller.active)
	# Losing a camera during a transition must restore the original presentation.
	camera.free()
	controller._process(0.016)
	assert(not controller.active and glass.visible)
	assert(wall.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON)
	camera = Camera3D.new()
	root.add_child(camera)
	camera.position = Vector3(0, 2.5, 5)
	controller.set("_camera", camera)
	controller._process(0.016)
	assert(controller.active)
	controller.free()
	assert(wall.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON and glass.visible)
	house.free()
	target.free()
	camera.free()


func _box(parent: Node3D, position: Vector3, size: Vector3) -> MeshInstance3D:
	var result := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	result.mesh = mesh
	result.position = position
	parent.add_child(result)
	return result
