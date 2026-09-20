extends RefCounted
## Original low broken masonry, batched once across all ruin columns.


static func build(parent: Node3D, columns: Array[Vector3]) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var outline: Array[Vector2] = [Vector2(-0.18, -0.10), Vector2(-0.12, -0.15), Vector2(0.14, -0.12), Vector2(0.19, 0.045), Vector2(0.10, 0.14), Vector2(-0.16, 0.11)]
	var top: Array[Vector3] = []
	var bottom: Array[Vector3] = []
	for index: int in range(outline.size()):
		var p: Vector2 = outline[index]
		bottom.append(Vector3(p.x, 0, p.y))
		top.append(Vector3(p.x * 0.83, 0.10 + float(index % 3) * 0.018, p.y * 0.83))
	for index: int in range(1, 5):
		_triangle(surface, top[0], top[index], top[index + 1])
		_triangle(surface, bottom[0], bottom[index + 1], bottom[index])
	for index: int in range(6):
		var next: int = (index + 1) % 6
		_triangle(surface, bottom[index], top[next], top[index])
		_triangle(surface, bottom[index], bottom[next], top[next])
	var mesh: ArrayMesh = surface.commit()
	var placements: Array[Transform3D] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 82173
	for column: Vector3 in columns:
		for index: int in range(7):
			var angle: float = index * TAU / 7.0 + rng.randf_range(-0.18, 0.18)
			var position := column + Vector3(cos(angle), 0, sin(angle)) * rng.randf_range(0.85, 1.25)
			if Vector2(position.x + 9, position.z - 4).length() < 1.2 or Vector2(position.x - 9, position.z + 1.5).length() < 1.2:
				continue
			var height := _support_height(parent, position)
			if height < 0:
				continue
			position.y = height + 0.001
			var scale := Vector3(rng.randf_range(0.7, 1.15), rng.randf_range(0.6, 1.0), rng.randf_range(0.7, 1.15))
			placements.append(Transform3D(Basis(Vector3.UP, rng.randf_range(-PI, PI)).scaled(scale), position))
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.mesh = mesh
	batch.instance_count = placements.size()
	var bounds := AABB()
	for index: int in range(placements.size()):
		batch.set_instance_transform(index, placements[index])
		var piece: AABB = placements[index] * mesh.get_aabb()
		bounds = piece if index == 0 else bounds.merge(piece)
	batch.custom_aabb = bounds
	var result := MultiMeshInstance3D.new()
	result.name = "RuinRubble"
	result.multimesh = batch
	result.set_meta("placements", placements)
	var material := StandardMaterial3D.new()
	material.albedo_texture = preload("res://assets/generated/moon_lamp_cut_limestone_albedo.png")
	material.albedo_color = Color("8b8b9e")
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	material.roughness = 1.0
	result.material_override = material
	parent.add_child(result)


static func _support_height(parent: Node3D, position: Vector3) -> float:
	var height: float = 0.0
	for label: String in ["RuinCourt", "WestRuinCourt", "EastRuinCourt"]:
		var court := parent.get_node(label) as Node3D
		var size: Vector3 = ((court.get_child(0) as MeshInstance3D).mesh as BoxMesh).size
		var delta := Vector2(absf(position.x - court.position.x), absf(position.z - court.position.z))
		var half := Vector2(size.x, size.z) * 0.5
		# Keep the entire stone away from the thin height discontinuity.
		if (absf(delta.x - half.x) < 0.30 and delta.y < half.y + 0.30) or (absf(delta.y - half.y) < 0.30 and delta.x < half.x + 0.30):
			return -1.0
		if delta.x < half.x and delta.y < half.y:
			height = maxf(height, court.position.y + size.y * 0.5)
	return height


static func _triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	var normal := (c - a).cross(b - a).normalized()
	for vertex: Vector3 in [a, b, c]:
		surface.set_normal(normal)
		surface.set_uv(Vector2(vertex.x, vertex.z) * 1.8 + Vector2(0.5, 0.5))
		surface.add_vertex(vertex)
