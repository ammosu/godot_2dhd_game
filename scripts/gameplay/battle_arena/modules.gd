extends RefCounted
## Reusable geometric arena modules. All origins sit on the walkable floor.

static func material(tint: Color, texture_path: String = "", repeats: float = 1.0) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = tint
	result.roughness = 0.94
	result.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	if not texture_path.is_empty():
		result.albedo_texture = load(texture_path) as Texture2D
		result.uv1_scale = Vector3(repeats, repeats, 1.0)
	return result


static func box(parent: Node3D, at: Vector3, size: Vector3, surface: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return mesh_instance(parent, mesh, at, surface)


static func mesh_instance(parent: Node3D, mesh: Mesh, at: Vector3, surface: Material) -> MeshInstance3D:
	var visual := MeshInstance3D.new()
	visual.mesh = mesh
	visual.material_override = surface
	visual.position = at
	parent.add_child(visual)
	return visual


static func cylinder(parent: Node3D, at: Vector3, radius: float, height: float, surface: Material, top: float = -1.0) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = radius
	mesh.top_radius = radius if top < 0.0 else top
	mesh.height = height
	mesh.radial_segments = 9
	return mesh_instance(parent, mesh, at, surface)


static func imported(parent: Node3D, path: String, height: float, max_radius: float = 0.0) -> Node3D:
	var model := (load(path) as PackedScene).instantiate() as Node3D
	parent.add_child(model)
	var bounds := AABB()
	var first: bool = true
	for child: Node in model.find_children("*", "MeshInstance3D", true, false):
		var visual := child as MeshInstance3D
		var local_bounds: AABB = (model.global_transform.affine_inverse() * visual.global_transform) * visual.get_aabb()
		bounds = local_bounds if first else bounds.merge(local_bounds)
		first = false
		for index: int in range(visual.mesh.get_surface_count()):
			var original := visual.mesh.surface_get_material(index) as BaseMaterial3D
			if original != null:
				var surface := original.duplicate() as BaseMaterial3D
				surface.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
				visual.set_surface_override_material(index, surface)
	if not first and bounds.size.y > 0.001:
		var factor: float = height / bounds.size.y
		if max_radius > 0.0:
			factor = minf(factor, max_radius / maxf(Vector2(bounds.size.x, bounds.size.z).length() * 0.5, 0.001))
		model.scale = Vector3.ONE * factor
		model.position = Vector3(-bounds.get_center().x, -bounds.position.y, -bounds.get_center().z) * factor
	return model


static func pine(parent: Node3D, height: float, wood: Material, foliage: Material) -> void:
	cylinder(parent, Vector3(0, height * 0.39, 0), 0.19, height * 0.78, wood, 0.10)
	for index: int in range(3):
		var radius: float = height * (0.24 - float(index) * 0.045)
		var cone := cylinder(parent, Vector3(0, height * (0.42 + float(index) * 0.20), 0), radius, height * 0.48, foliage, 0.025)
		cone.rotation.y = float(index) * 0.45


static func house(parent: Node3D, plaster: Material, wood: Material, roof: Material, window: Material) -> void:
	box(parent, Vector3(0, 1.45, 0), Vector3(3.7, 2.9, 2.8), plaster)
	for x: float in [-1.78, 0.0, 1.78]:
		box(parent, Vector3(x, 1.45, 1.43), Vector3(0.14, 2.9, 0.12), wood)
	for y: float in [0.20, 2.65]:
		box(parent, Vector3(0, y, 1.45), Vector3(3.75, 0.16, 0.13), wood)
	for x: float in [-0.95, 0.95]:
		box(parent, Vector3(x, 1.6, 1.48), Vector3(0.70, 0.95, 0.06), wood)
		box(parent, Vector3(x, 1.6, 1.52), Vector3(0.52, 0.75, 0.03), window)
		box(parent, Vector3(x, 1.6, 1.55), Vector3(0.065, 0.8, 0.035), wood)
		box(parent, Vector3(x, 1.6, 1.55), Vector3(0.56, 0.06, 0.035), wood)
	for side: float in [-1.0, 1.0]:
		var slope := box(parent, Vector3(0, 3.18, side * 0.89), Vector3(4.1, 0.19, 2.05), roof)
		slope.rotation.x = side * 0.46
	box(parent, Vector3(1.1, 3.6, -0.65), Vector3(0.45, 1.35, 0.5), plaster)


static func arch_stone(parent: Node3D, center: Vector3, start: float, end: float, surface: Material) -> void:
	var points: Array[Vector3] = []
	for depth: float in [-0.45, 0.45]:
		for angle: float in [start, end]:
			points.append(Vector3(cos(angle) * 3.92, sin(angle) * 1.08, depth))
			points.append(Vector3(cos(angle) * 3.08, sin(angle) * 0.59, depth))
	var builder := SurfaceTool.new()
	builder.begin(Mesh.PRIMITIVE_TRIANGLES)
	var indices: Array[int] = [0, 2, 1, 1, 2, 3, 4, 5, 6, 5, 7, 6, 0, 4, 2, 2, 4, 6, 1, 3, 5, 3, 7, 5, 0, 1, 4, 1, 5, 4, 2, 6, 3, 3, 6, 7]
	for index: int in indices:
		builder.set_uv(Vector2(points[index].x * 0.4, points[index].y * 0.5))
		builder.add_vertex(points[index])
	builder.generate_normals()
	mesh_instance(parent, builder.commit(), center, surface)
