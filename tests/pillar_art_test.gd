extends SceneTree
## Imported geometry, material, collider envelope and both map integrations.

var failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)


func _run() -> void:
	var scene := load("res://assets/generated/weathered_pillar_v2.glb") as PackedScene
	var pillar := scene.instantiate() as Node3D
	root.add_child(pillar)
	var meshes := pillar.find_children("*", "MeshInstance3D", true, false)
	_check(meshes.size() == 1, "Column should remain a single mesh")
	var bottom := INF
	var top := -INF
	var triangles: int = 0
	var crown_heights: Dictionary = {}
	for node: Node in meshes:
		var instance := node as MeshInstance3D
		for surface: int in range(instance.mesh.get_surface_count()):
			var material := instance.mesh.surface_get_material(surface) as BaseMaterial3D
			_check(material != null and material.albedo_texture != null, "Original lichen texture missing")
			var arrays := instance.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			triangles += indices.size() / 3
			for vertex: Vector3 in vertices:
				var point := instance.global_transform * vertex
				_check(point.is_finite() and Vector2(point.x, point.z).length() <= 0.49, "Pillar exceeds unchanged collision envelope")
				bottom = minf(bottom, point.y)
				top = maxf(top, point.y)
				if point.y > 1.6:
					crown_heights[snappedf(point.y, 0.02)] = true
			for index: int in range(0, indices.size(), 3):
				var a := vertices[indices[index]]
				var b := vertices[indices[index + 1]]
				var c := vertices[indices[index + 2]]
				_check((b - a).cross(c - a).length_squared() > 0.0000000001, "Degenerate column triangle")
	_check(absf(bottom) < 0.002 and top > 1.9 and top <= 2.0, "Column ground or height changed")
	_check(crown_heights.size() >= 6, "Fractured crown flattened")
	_check(triangles > 70 and triangles < 1200, "Unexpected column mesh budget")
	pillar.free()
	root.get_node("GameState").get("flags")["intro_seen"] = true
	var world := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(world)
	_check_map(4)
	world.call("_load_map", "ruins", "from_village")
	_check_map(8)
	world.free()
	_check(get_nodes_in_group("weathered_pillar_art").is_empty(), "Column nodes leaked across cleanup")
	for singleton: String in ["GameAudio", "GameMusic", "GameAmbience"]:
		root.get_node(singleton).call("stop_all")
	await create_timer(0.25).timeout
	if failures == 0:
		print("PILLAR_ART_TEST_PASS textured fractured grounded collider_envelope village ruins triangles=", triangles)
	quit(0 if failures == 0 else 1)


func _check_map(expected: int) -> void:
	var pillars := get_nodes_in_group("weathered_pillar_art")
	_check(pillars.size() == expected, "Map pillar count changed")
	var rotations: Dictionary = {}
	for pillar: Node3D in pillars:
		rotations[pillar.rotation.y] = true
		var body := pillar.get_parent() as StaticBody3D
		var shapes := body.find_children("*", "CollisionShape3D", true, false)
		_check(shapes.size() == 1, "Column gained extra collision")
		var shape := (shapes[0] as CollisionShape3D).shape as CylinderShape3D
		_check(is_equal_approx(shape.radius, 0.5) and is_equal_approx(shape.height, 2.0), "Original column collision changed")
		_check(body.has_node("ColumnFooting") and body.has_node("ColumnCutaway"), "Footing or cutaway missing")
		for node: Node in pillar.find_children("*", "MeshInstance3D", true, false):
			var instance := node as MeshInstance3D
			var material := instance.mesh.surface_get_material(0) as BaseMaterial3D
			_check(material.texture_filter == BaseMaterial3D.TEXTURE_FILTER_NEAREST, "Column filtering regressed")
	_check(rotations.size() > 1, "Columns all expose identical fracture faces")
