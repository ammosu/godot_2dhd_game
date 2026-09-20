extends SceneTree

const Details = preload("res://scripts/gameplay/house_details.gd")


func _initialize() -> void:
	var house := Node3D.new()
	root.add_child(house)
	var material := StandardMaterial3D.new()
	Details.build(house, material, material, material)
	var details := house.get_node("ArchitecturalDetails")
	# Each glass center must have exactly one matching vertical and horizontal bar.
	for side: float in [-1.0, 1.0]:
		for x: float in ([-1.25, 1.25] if side < 0.0 else [-1.15, 1.15]):
			_check_cross(details, Vector3(x, 1.18, side * 1.75))
			for edge: float in [-1.0, 1.0]:
				assert(_count_at(details, Vector3(x + edge * 0.35, 1.18, side * 1.75)) == 1)
			assert(_count_at(details, Vector3(x, 1.53, side * 1.75)) == 1)
		for z: float in [-0.72, 0.72]:
			_check_cross(details, Vector3(side * 2.085, 1.18, z))
			for edge: float in [-1.0, 1.0]:
				assert(_count_at(details, Vector3(side * 2.085, 1.18, z + edge * 0.33)) == 1)
			assert(_count_at(details, Vector3(side * 2.085, 1.51, z)) == 1)
	house.free()
	print("HOUSE_WINDOW_TEST_PASS aligned_crossbars eight_outer_frames")
	quit()


func _check_cross(parent: Node, position: Vector3) -> void:
	assert(_count_at(parent, position) == 2)


func _count_at(parent: Node, position: Vector3) -> int:
	var count: int = 0
	for child: Node in parent.get_children():
		if child is MeshInstance3D and (child as MeshInstance3D).position.is_equal_approx(position):
			count += 1
	return count
