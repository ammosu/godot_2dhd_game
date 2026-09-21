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
	# The tilted character card reaches behind its vertical body at head height.
	# The neighboring pottery facade used to draw a triangle across its face.
	player.position = Houses.return_position("house_07")
	rig.set("_target_yaw", PI / 4.0)
	rig.call("snap_to_target")
	var neighbor_checked: bool = false
	for controller: Node in get_nodes_in_group("foreground_cutaways"):
		if (controller.get_parent() as Node3D).position.is_equal_approx(Houses.find_home("house_04").position):
			assert(controller.call("obstructs_view"), "Tilted billboard face intersects neighboring facade")
			neighbor_checked = true
	assert(neighbor_checked)
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
						assert(tiles.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON)
						assert((house.get_node("HouseEntrance") as Area3D).monitoring)
	assert(blocked_views > 0)
	var outdoor_controllers: Array[WeakRef] = []
	for controller: Node in get_nodes_in_group("foreground_cutaways"):
		outdoor_controllers.append(weakref(controller))
	world.call("_load_map", "house_02", "entry")
	for reference: WeakRef in outdoor_controllers:
		assert(reference.get_ref() == null, "Outdoor cutaway survived entering a house")
	var indoors := get_nodes_in_group("foreground_cutaways")
	assert(indoors.size() == 1, "House must have exactly one furniture cutaway")
	assert(indoors[0].name == &"FurnitureCutaway")
	var indoor_controller: WeakRef = weakref(indoors[0])
	world.call("_load_map", "village", "from_house_02")
	assert(indoor_controller.get_ref() == null, "Furniture cutaway survived returning to village")
	assert(get_nodes_in_group("foreground_cutaways").size() == 8)
	_test_columns(world)
	world.free()
	print("FOREGROUND_CUTAWAY_TEST_PASS hysteresis shadows tiles 192_views map_cleanup")
	quit()


func _test_columns(world: Node) -> void:
	world.call("_load_map", "ruins", "default")
	var camera := root.get_camera_3d()
	var player := world.get_node("Player") as Node3D
	var columns := get_nodes_in_group("column_cutaways")
	assert(not columns.is_empty(), "Ruins columns have no cutaway")
	for controller: Node in columns:
		var column := controller.get_parent() as Node3D
		player.global_position = column.global_position + Vector3(0, 0, -2)
		camera.global_position = column.global_position + Vector3(0, 1.5, 4)
		camera.look_at(player.global_position + Vector3.UP * 0.8)
		controller.call("_process", 0.01)
		assert(controller.get("active"), "Foreground column did not cut away")
		var footing := column.get_node("ColumnFooting") as MeshInstance3D
		assert(footing.visible and footing.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON, "Column cutaway hid collision footprint")
		var footing_mesh := footing.mesh as CylinderMesh
		assert(footing_mesh.bottom_radius <= 0.5 and footing_mesh.top_radius <= 0.5, "Footing extends beyond collider")
		assert(is_equal_approx(footing.position.y - footing_mesh.height * 0.5, 0.0), "Footing floats above ground")
		for part: Dictionary in controller.get("_parts"):
			assert(part.visual.visible and part.visual.cast_shadow == part.shadow)
		var shapes := column.find_children("*", "CollisionShape3D", true, false)
		assert(shapes.size() == 1 and not (shapes[0] as CollisionShape3D).disabled)
		camera.global_position = column.global_position + Vector3(4, 3, -2)
		camera.look_at(player.global_position + Vector3.UP * 0.8)
		controller.call("_process", 0.23)
		assert(not controller.get("active"), "Column did not restore at clear view")
	world.call("_load_map", "house_02", "entry")
	assert(get_nodes_in_group("column_cutaways").is_empty(), "Column cutaways survived leaving ruins")


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
	assert(wall.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON)
	assert(base.visible and base.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON)
	assert(glass.visible and glass.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
	# A blocker behind the player must not request a silhouette.
	target.position = Vector3(0, 0, 3)
	controller._process(0.23)
	assert(not controller.active and wall.visible and glass.visible)
	target.position = Vector3(0, 0, -3)
	controller._process(0.016)
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
