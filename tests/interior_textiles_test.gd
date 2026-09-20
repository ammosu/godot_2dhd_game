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
	if _failures == 0:
		print("INTERIOR_TEXTILES_TEST_PASS linen drape normals cushion fringe")
	quit(0 if _failures == 0 else 1)
