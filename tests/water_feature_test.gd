extends SceneTree


func _initialize() -> void:
	var feature := preload("res://scripts/gameplay/water_feature.gd")
	for size: Vector2 in [Vector2(9, 5), Vector2(1.6, 1.6)]:
		var container := Node3D.new()
		var center := Vector3(3, 0.2, -5)
		feature.build(container, center, size, size.x < 2)
		var water := container.get_node("MoonWaterSurface") as MeshInstance3D
		assert(water.position == center)
		assert((water.mesh as PlaneMesh).size == size)
		var coping := container.get_node("WaterStoneCoping") as MultiMeshInstance3D
		var blocks: Array = coping.get_meta("blocks")
		assert(blocks.size() == 52 if size.x == 9 else blocks.size() == 28)
		assert(coping.multimesh.instance_count == blocks.size())
		assert(container.get_child_count() == 2, "Only water and one decorative batch; no new collision")
		var boxes: Array[AABB] = []
		for index: int in range(blocks.size()):
			var transform: Transform3D = blocks[index]
			var bounds: AABB = transform * coping.multimesh.mesh.get_aabb()
			var is_support: bool = size.x < 2 and index >= 14
			assert(is_equal_approx(bounds.position.y, 0.0 if is_support else center.y - 0.05))
			assert(is_equal_approx(bounds.end.y, center.y - 0.05 if is_support else center.y + 0.10))
			assert(coping.multimesh.custom_aabb.grow(0.001).encloses(bounds))
			for previous: AABB in boxes:
				assert(not previous.grow(-0.0001).intersects(bounds), "Coping blocks must not overlap")
			boxes.append(bounds)
		container.free()
	print("WATER_FEATURE_TEST_PASS pond spring joints bounds original_surface no_collision")
	quit()
