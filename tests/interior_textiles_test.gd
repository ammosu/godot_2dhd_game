extends SceneTree

var _failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)


func _run() -> void:
	var room: Node3D = load("res://scripts/gameplay/house_interior.gd").new()
	root.add_child(room)
	var boards := room.get_node("FloorBoards") as MultiMeshInstance3D
	_check(boards.multimesh.instance_count == 20, "Floor board batch incomplete")
	_check((boards.multimesh.mesh as BoxMesh).size.is_equal_approx(Vector3(0.385, 0.024, 7)), "Floor board dimensions changed")
	# Dummy rendering does not store MultiMesh transforms; check these on GPU.
	if DisplayServer.get_name() != "headless":
		for index: int in range(20):
			var transform := boards.multimesh.get_instance_transform(index)
			_check(transform.origin.is_equal_approx(Vector3(-3.8 + index * 0.4, 0.012, 0)), "Floor board position changed")
			_check(transform.basis.is_equal_approx(Basis.IDENTITY), "Floor board orientation changed")
	var floor_material := boards.material_override as StandardMaterial3D
	_check(floor_material.uv1_scale.is_equal_approx(Vector3(0.12, 1, 1)), "Floor wood grain scale changed")
	_check(floor_material.texture_filter == BaseMaterial3D.TEXTURE_FILTER_NEAREST, "Floor lost nearest sampling")
	_check(boards.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON, "Floor shadows changed")
	_check(boards.find_children("*", "CollisionObject3D", true, false).is_empty(), "Floor visuals added collision")
	var floor_shape := room.get_node("FloorCollision").get_child(0) as CollisionShape3D
	_check((floor_shape.shape as BoxShape3D).size.is_equal_approx(Vector3(8, 0.20, 7)), "Floor collision changed")
	var quilt := room.get_node("Quilt") as MeshInstance3D
	_check(quilt.mesh is ArrayMesh, "Quilt must have a draped surface")
	var bounds := quilt.mesh.get_aabb()
	_check(bounds.size.y > 0.2 and bounds.size.y < 0.3, "Quilt drape depth incorrect")
	_check(bounds.position.y > 0.4, "Quilt fell through bed frame")
	var material := quilt.material_override as StandardMaterial3D
	_check(material.albedo_texture.resource_path.ends_with("linen_albedo.png"), "Quilt still uses placeholder texture")
	_check(material.texture_filter == BaseMaterial3D.TEXTURE_FILTER_NEAREST, "Cloth lost nearest sampling")
	var arrays := quilt.mesh.surface_get_arrays(0)
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var up_count: int = 0
	for normal: Vector3 in normals:
		up_count += 1 if normal.y > 0.0 else 0
	_check(up_count == normals.size(), "Quilt normals point into mattress")
	var pillow := room.get_node("Pillow") as MeshInstance3D
	_check(pillow.mesh is SphereMesh and pillow.scale.y < pillow.scale.z, "Pillow must be a flattened cushion")
	var fringe := room.get_node("RugFringe") as MultiMeshInstance3D
	_check(fringe.multimesh.instance_count == 28, "Rug fringe batch incomplete")
	_check(quilt.find_children("*", "CollisionObject3D", true, false).is_empty(), "Cloth must not alter furniture collision")
	room.queue_free()
	await process_frame
	for singleton: String in ["GameAudio", "GameMusic", "GameAmbience"]:
		root.get_node(singleton).call("stop_all")
	await create_timer(0.25).timeout
	if _failures == 0:
		print("INTERIOR_TEXTILES_TEST_PASS linen drape normals cushion fringe")
	quit(0 if _failures == 0 else 1)
