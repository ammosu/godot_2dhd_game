extends SceneTree
## Imported pottery geometry, hollow opening, and live map integration.

var _failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)


func _run() -> void:
	var jar := (load("res://assets/generated/earthenware_jar.glb") as PackedScene).instantiate() as Node3D
	root.add_child(jar)
	var meshes := jar.find_children("*", "MeshInstance3D", true, false)
	_check(meshes.size() == 2, "Jar needs body and two-handle mesh")
	var bounds := AABB()
	var first := true
	var triangles: int = 0
	for node: Node in meshes:
		var instance := node as MeshInstance3D
		var box: AABB = instance.global_transform * instance.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
		for surface: int in range(instance.mesh.get_surface_count()):
			var material := instance.mesh.surface_get_material(surface) as BaseMaterial3D
			_check(material != null and material.albedo_texture != null, "Jar lost embedded clay texture")
			var arrays := instance.mesh.surface_get_arrays(surface)
			triangles += (arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3
	_check(absf(bounds.position.y) < 0.001 and is_equal_approx(bounds.size.y, 0.7), "Jar ground origin or height incorrect")
	_check(bounds.size.x > 0.8 and bounds.size.x < 0.85 and bounds.size.z > 0.6 and bounds.size.z < 0.65, "Jar handle span or body depth incorrect")
	_check(triangles > 1000 and triangles < 2000, "Unexpected jar triangle budget")
	var center_hit := _highest_hit(meshes, Vector3(0.0, 2.0, 0.0))
	var rim_hit := _highest_hit(meshes, Vector3(0.205, 2.0, 0.0))
	_check(center_hit > 0.05 and center_hit < 0.1, "Jar opening must reach inner floor, not a solid lid")
	_check(rim_hit > 0.65, "Jar needs a real raised rim")
	jar.free()
	root.get_node("GameState").get("flags")["intro_seen"] = true
	var world := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(world)
	await process_frame
	_check(get_nodes_in_group("earthenware_jar_art").size() == 1, "Village needs one jar")
	var live_jar := get_first_node_in_group("earthenware_jar_art") as Node3D
	_check(is_equal_approx(live_jar.position.y, 0.01), "Jar placement must be grounded")
	_check(Vector2(live_jar.position.x, live_jar.position.z).distance_to(Vector2(6.4, 4.2)) > 0.85, "Jar crowds Rumi's standing position")
	_check(live_jar.has_node("PropBody/Shape"), "Placed jar needs solid collision")
	for node: Node in live_jar.find_children("*", "MeshInstance3D", true, false):
		var instance := node as MeshInstance3D
		for surface: int in range(instance.mesh.get_surface_count()):
			var material := instance.mesh.surface_get_material(surface) as BaseMaterial3D
			_check(material.texture_filter == BaseMaterial3D.TEXTURE_FILTER_NEAREST, "Jar requires nearest filtering")
	world.call("_load_map", "ruins", "from_village")
	await process_frame
	_check(get_nodes_in_group("earthenware_jar_art").is_empty(), "Village jar leaked into ruins")
	world.queue_free()
	await process_frame
	if _failures == 0:
		print("JAR_ART_TEST_PASS geometry texture hollow_rim grounding clearance triangles=", triangles)
	quit(0 if _failures == 0 else 1)


func _highest_hit(meshes: Array[Node], origin: Vector3) -> float:
	var highest: float = -INF
	for node: Node in meshes:
		var instance := node as MeshInstance3D
		for surface: int in range(instance.mesh.get_surface_count()):
			var arrays := instance.mesh.surface_get_arrays(surface)
			var vertices := arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
			var indices := arrays[Mesh.ARRAY_INDEX] as PackedInt32Array
			for index: int in range(0, indices.size(), 3):
				var a: Vector3 = instance.global_transform * vertices[indices[index]]
				var b: Vector3 = instance.global_transform * vertices[indices[index + 1]]
				var c: Vector3 = instance.global_transform * vertices[indices[index + 2]]
				var hit: Variant = Geometry3D.ray_intersects_triangle(origin, Vector3.DOWN, a, b, c)
				if hit != null:
					var point: Vector3 = hit
					highest = maxf(highest, point.y)
	return highest
