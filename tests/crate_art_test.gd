extends SceneTree
## Validate imported art and both map integrations without save writes.

var _failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)


func _run() -> void:
	var packed := load("res://assets/generated/supply_crate.glb") as PackedScene
	_check(packed != null, "Supply crate GLB must load")
	if packed == null:
		quit(1)
		return
	var crate := packed.instantiate() as Node3D
	root.add_child(crate)
	var meshes := crate.find_children("*", "MeshInstance3D", true, false)
	_check(meshes.size() == 2, "Crate should have two meshes: wood and hardware")
	var bounds := AABB()
	var first := true
	var textured: bool = false
	var triangles: int = 0
	for node: Node in meshes:
		var instance := node as MeshInstance3D
		var box: AABB = instance.global_transform * instance.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
		for surface: int in range(instance.mesh.get_surface_count()):
			var material := instance.mesh.surface_get_material(surface) as BaseMaterial3D
			textured = textured or (material != null and material.albedo_texture != null)
			var arrays := instance.mesh.surface_get_arrays(surface)
			triangles += (arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
	_check(textured, "Crate must retain embedded original wood texture")
	_check(bounds.size.x > 0.8 and bounds.size.x < 0.9 and bounds.size.z > 0.8 and bounds.size.z < 0.9, "Crate footprint incorrect")
	_check(absf(bounds.position.y) < 0.005 and bounds.size.y > 0.70 and bounds.size.y < 0.78, "Crate must have ground-centered origin and correct height")
	_check(triangles > 720 and triangles < 6000, "Crate bevel geometry missing or unexpectedly heavy")
	_check(crate.find_children("*", "CollisionObject3D", true, false).is_empty(), "Crate must remain visual-only")
	crate.free()
	root.get_node("GameState").get("flags")["intro_seen"] = true
	var world := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(world)
	await process_frame
	_check_map_crates(2)
	_check_village_clearance(world.get("_map_root") as Node3D)
	world.call("_load_map", "ruins", "from_village")
	await process_frame
	_check_map_crates(5)
	world.queue_free()
	await process_frame
	if _failures == 0:
		print("CRATE_ART_TEST_PASS geometry texture grounding village ruins triangles=", triangles)
	quit(0 if _failures == 0 else 1)


func _check_map_crates(expected: int) -> void:
	var crates := get_nodes_in_group("supply_crate_art")
	_check(crates.size() == expected, "Wrong crate count in current map")
	for node: Node in crates:
		var crate := node as Node3D
		_check(is_equal_approx(crate.position.y, 0.01), "Crate placement must be grounded")
		_check(crate.find_children("*", "CollisionObject3D", true, false).is_empty(), "Crate unexpectedly blocks gameplay")
		for child: Node in crate.find_children("*", "MeshInstance3D", true, false):
			var instance := child as MeshInstance3D
			for surface: int in range(instance.mesh.get_surface_count()):
				var material := instance.mesh.surface_get_material(surface) as BaseMaterial3D
				_check(material != null and material.texture_filter == BaseMaterial3D.TEXTURE_FILTER_NEAREST, "Crate must retain nearest texture filtering")


func _check_village_clearance(map_root: Node3D) -> void:
	var boxes: Array[AABB] = []
	for crate: Node in get_nodes_in_group("supply_crate_art"):
		var bounds := AABB()
		var first := true
		for node: Node in crate.find_children("*", "MeshInstance3D", true, false):
			var mesh := node as MeshInstance3D
			var box: AABB = mesh.global_transform * mesh.get_aabb()
			bounds = box if first else bounds.merge(box)
			first = false
		for previous: AABB in boxes:
			_check(not bounds.intersects(previous), "Village crates overlap")
		boxes.append(bounds)
		for node: Node in map_root.find_children("*", "CollisionShape3D", true, false):
			var shape := node as CollisionShape3D
			if shape.shape is CylinderShape3D:
				var center := Vector2(shape.global_position.x, shape.global_position.z)
				var nearest := Vector2(clampf(center.x, bounds.position.x, bounds.end.x), clampf(center.y, bounds.position.z, bounds.end.z))
				_check(nearest.distance_to(center) > (shape.shape as CylinderShape3D).radius, "Crate intersects a village pillar")
