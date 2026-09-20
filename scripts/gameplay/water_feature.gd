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
	stone.albedo_texture = preload("res://assets/generated/ruin_flagstone.png")
	stone.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	stone.roughness = 0.95
	for side: float in [-1.0, 1.0]:
		_edge(parent, center + Vector3(0.0, 0.025, side * size.y * 0.5), Vector3(size.x + 0.3, 0.15, 0.23), stone)
		_edge(parent, center + Vector3(side * size.x * 0.5, 0.025, 0.0), Vector3(0.23, 0.15, size.y), stone)


static func _edge(parent: Node3D, position: Vector3, size: Vector3, material: Material) -> void:
	var instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.position = position
	instance.material_override = material
	parent.add_child(instance)
