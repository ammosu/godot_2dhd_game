extends RefCounted
## Neighbor footprints prevent false erosion seams where raised courts overlap.

static func configure(map: Node3D) -> void:
	var materials: Array[ShaderMaterial] = []
	var rects: Array[Vector4] = []
	for label: String in ["RuinCourt", "WestRuinCourt", "EastRuinCourt"]:
		var root := map.get_node(label) as Node3D
		var visual := root.get_child(0) as MeshInstance3D
		var size: Vector3 = (visual.mesh as BoxMesh).size
		rects.append(Vector4(root.position.x, root.position.z, size.x / 2.0, size.z / 2.0))
		materials.append(visual.material_override as ShaderMaterial)
	for index: int in range(materials.size()):
		materials[index].set_shader_parameter("neighbor_a", rects[(index + 1) % 3])
		materials[index].set_shader_parameter("neighbor_b", rects[(index + 2) % 3])
