extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.get_node("GameState").get("flags")["intro_seen"] = true
	var world := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(world)
	world.call("_load_map", "ruins", "from_village")
	var map := world.get("_map_root") as Node3D
	var rubble := map.get_node("RuinRubble") as MultiMeshInstance3D
	var placements: Array = rubble.get_meta("placements")
	assert(placements.size() >= 24 and placements.size() <= 56)
	assert(rubble.multimesh.instance_count == placements.size())
	assert(rubble.get_child_count() == 0, "Decorative rubble adds no colliders")
	var vertices: PackedVector3Array = rubble.multimesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = rubble.multimesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL]
	assert(vertices.size() == 60)
	for index: int in range(0, vertices.size(), 3):
		var center := (vertices[index] + vertices[index + 1] + vertices[index + 2]) / 3.0
		assert(normals[index].dot(center - Vector3(0, 0.06, 0)) > 0.0)
	for transform: Transform3D in placements:
		assert(transform.origin.is_finite())
		var bottom: float = INF
		for vertex: Vector3 in vertices:
			bottom = minf(bottom, (transform * vertex).y)
		assert(is_equal_approx(bottom, transform.origin.y))
		assert(bottom >= 0.001 and bottom <= 0.042)
		assert(Vector2(transform.origin.x + 9, transform.origin.z - 4).length() >= 1.2)
		assert(Vector2(transform.origin.x - 9, transform.origin.z + 1.5).length() >= 1.2)
		assert(rubble.multimesh.custom_aabb.grow(0.001).encloses(transform * rubble.multimesh.mesh.get_aabb()))
	world.call("_load_map", "ruins", "from_village")
	map = world.get("_map_root") as Node3D
	assert(map.get_node("RuinRubble").get_meta("placements") == placements, "Layout must be deterministic")
	world.call("_load_map", "village", "from_ruins")
	assert((world.get("_map_root") as Node3D).get_node_or_null("RuinRubble") == null)
	world.free()
	for singleton: String in ["GameAudio", "GameMusic", "GameAmbience"]:
		root.get_node(singleton).call("stop_all")
	await create_timer(0.25).timeout
	print("RUIN_RUBBLE_TEST_PASS grounded normals deterministic one_batch count=", placements.size())
	quit()
