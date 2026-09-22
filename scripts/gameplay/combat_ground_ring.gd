extends MeshInstance3D
## A depth-tested ground mark shared by attacks, selection and trial boundary.
func configure(radius: float, color: Color, width: float = 0.055) -> void:
	var ring := ImmediateMesh.new()
	ring.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for index: int in range(64):
		var a: float = TAU * float(index) / 64.0
		var b: float = TAU * float(index + 1) / 64.0
		var inner_a := Vector3(cos(a), 0, sin(a)) * maxf(0.0, radius - width)
		var outer_a := Vector3(cos(a), 0, sin(a)) * radius
		var inner_b := Vector3(cos(b), 0, sin(b)) * maxf(0.0, radius - width)
		var outer_b := Vector3(cos(b), 0, sin(b)) * radius
		for vertex: Vector3 in [inner_a, outer_a, outer_b, inner_a, outer_b, inner_b]:
			ring.surface_add_vertex(vertex)
	ring.surface_end()
	mesh = ring
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = color
	material.no_depth_test = false
	material_override = material
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
