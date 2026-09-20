extends SceneTree
## Verify live roof batching, real relief, material and downhill orientation.

var _failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Roof transform verification requires a real renderer; omit --headless")
		quit(1)
		return
	root.get_node("GameState").get("flags")["intro_seen"] = true
	var world := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(world)
	await process_frame
	var roofs := world.find_children("SlateRoofTiles", "MultiMeshInstance3D", true, false)
	_check(roofs.size() == 8, "Village must contain eight dressed roofs")
	for node: Node in roofs:
		var batch := node as MultiMeshInstance3D
		var details := batch.get_parent()
		var house := details.get_parent() as StaticBody3D
		var gable := details.get_node("PlasterGables") as MeshInstance3D
		_check(gable.mesh.get_faces().size() == 6, "Both attic ends need triangular plaster walls")
		for deck_name: String in ["RoofDeckLeft", "RoofDeckRight"]:
			var deck := details.get_node(deck_name) as MeshInstance3D
			_check(is_equal_approx((deck.mesh as BoxMesh).size.y, 0.07), "Roof deck must remain thin")
		var collisions := house.find_children("*", "CollisionShape3D", false, false)
		_check(collisions.size() == 1, "House collision count changed")
		var collision := collisions[0] as CollisionShape3D
		_check((collision.shape as BoxShape3D).size == Vector3(4.0, 2.3, 3.2), "House gameplay footprint changed")
		var tiles := batch.multimesh
		_check(tiles.instance_count == 192, "Roof needs two slopes of eight twelve-tile courses")
		var bounds := tiles.mesh.get_aabb()
		_check(bounds.size.y > 0.08 and bounds.size.y < 0.09, "Slate needs physical lip relief")
		_check(is_equal_approx(bounds.size.x, 0.405), "Slate width changed")
		var material := batch.material_override as StandardMaterial3D
		_check(material.albedo_texture != null and material.albedo_texture.resource_path.ends_with("slate_roof_albedo.png"), "Roof lost slate texture")
		_check(material.texture_filter == BaseMaterial3D.TEXTURE_FILTER_NEAREST, "Roof needs nearest sampling")
		for index: int in range(tiles.instance_count):
			var placement := tiles.get_instance_transform(index)
			_check(placement.basis.x.y < -0.3, "Tile lip must face downhill on both slopes")
			_check(placement.basis.x.x * placement.origin.x > 0.0, "Tile lip faces ridge")
			_check(absf(placement.origin.y - (2.97 - absf(placement.origin.x) * tan(0.38))) < 0.001, "Tile detached from roof plane")
		_check(batch.find_children("*", "CollisionObject3D", true, false).is_empty(), "Roof detail must not add collision")
	world.queue_free()
	await process_frame
	if _failures == 0:
		print("ROOF_ART_TEST_PASS batching relief texture slopes")
	quit(0 if _failures == 0 else 1)
