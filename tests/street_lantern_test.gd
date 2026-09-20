extends SceneTree

const Lantern = preload("res://scripts/gameplay/street_lantern.gd")


func _initialize() -> void:
	var parent := Node3D.new()
	root.add_child(parent)
	var first: Node3D = Lantern.build(parent, Vector3.ZERO)
	var second: Node3D = Lantern.build(parent, Vector3(2, 0, 0))
	assert(first.get_child_count() == 3)
	var frame := first.get_node("Metalwork") as MeshInstance3D
	var panes := first.get_node("FrostedGlass") as MeshInstance3D
	assert(frame.mesh == (second.get_node("Metalwork") as MeshInstance3D).mesh)
	assert(panes.mesh == (second.get_node("FrostedGlass") as MeshInstance3D).mesh)
	assert(is_equal_approx(frame.mesh.get_aabb().position.y, 0.0))
	assert(is_equal_approx(frame.mesh.get_aabb().end.y, 1.81))
	var arrays: Array = panes.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	assert(vertices.size() == 24)
	for index: int in range(vertices.size()):
		assert(vertices[index].is_finite())
		assert(normals[index].dot(Vector3(vertices[index].x, 0, vertices[index].z)) > 0.0)
	var light := first.get_node("RoadLight") as OmniLight3D
	assert(is_equal_approx(light.position.y, 1.42))
	assert(is_equal_approx(light.light_energy, 5.5))
	assert(is_equal_approx(light.omni_range, 5.0))
	assert(is_equal_approx(light.omni_attenuation, 1.25))
	assert(light.light_color == Color("ffb968"))
	parent.free()
	print("STREET_LANTERN_TEST_PASS shared_meshes grounded outward_panes localized_light")
	quit()
