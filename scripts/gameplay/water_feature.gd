extends RefCounted
## Shared pond and spring presentation, independent of interaction/save state.


static func build(parent: Node3D, center: Vector3, size: Vector2, luminous: bool = false) -> void:
	var water := MeshInstance3D.new()
	water.name = "MoonWaterSurface"
	water.position = center
	var plane := PlaneMesh.new()
	plane.size = size
	water.mesh = plane
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/moon_water.gdshader")
	material.set_shader_parameter("water_size", size)
	material.set_shader_parameter("glow", 0.45 if luminous else 0.08)
	water.material_override = material
	parent.add_child(water)
	var stone := StandardMaterial3D.new()
	stone.albedo_texture = preload("res://assets/generated/moon_lamp_cut_limestone_albedo.png")
	stone.albedo_color = Color("9396a4")
	stone.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	stone.roughness = 0.95
	var transforms: Array[Transform3D] = []
	for side: float in [-1.0, 1.0]:
		_course(transforms, center + Vector3(0.0, 0.025, side * size.y * 0.5), size.x + 0.30, false)
		# Side courses stop before the end caps, avoiding overlapping corner faces.
		_course(transforms, center + Vector3(side * size.x * 0.5, 0.025, 0.0), size.y - 0.23, true)
	# The raised spring needs walls beneath its coping, down to local ground.
	var support_height: float = maxf(0.0, center.y - 0.05) if luminous else 0.0
	if support_height > 0.0:
		var cap_count: int = transforms.size()
		for index: int in range(cap_count):
			var cap: Transform3D = transforms[index]
			var dimensions: Vector3 = cap.basis.get_scale()
			dimensions.y = support_height
			var position: Vector3 = cap.origin
			position.y = support_height * 0.5
			transforms.append(Transform3D(Basis.IDENTITY.scaled(dimensions), position))
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.mesh = mesh
	batch.instance_count = transforms.size()
	var bounds := AABB()
	for index: int in range(transforms.size()):
		batch.set_instance_transform(index, transforms[index])
		var block: AABB = transforms[index] * mesh.get_aabb()
		bounds = block if index == 0 else bounds.merge(block)
	batch.custom_aabb = bounds
	var coping := MultiMeshInstance3D.new()
	coping.name = "WaterStoneCoping"
	coping.multimesh = batch
	coping.material_override = stone
	coping.set_meta("blocks", transforms)
	parent.add_child(coping)


static func _course(blocks: Array[Transform3D], center: Vector3, length: float, along_z: bool) -> void:
	var count: int = maxi(1, ceili(length / 0.55))
	var spacing: float = length / count
	for index: int in range(count):
		var offset: float = -length * 0.5 + (index + 0.5) * spacing
		var position := center + (Vector3(0, 0, offset) if along_z else Vector3(offset, 0, 0))
		var size := Vector3(0.23, 0.15, spacing - 0.018) if along_z else Vector3(spacing - 0.018, 0.15, 0.23)
		blocks.append(Transform3D(Basis.IDENTITY.scaled(size), position))
