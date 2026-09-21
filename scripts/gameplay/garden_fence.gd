extends RefCounted
## Solid split-rail fence. Wood grain follows each beam's long axis.


static func build(parent: Node3D, origin: Vector3, width: float) -> Node3D:
	assert(width > 0.4, "Garden fence requires a positive usable span")
	var root := Node3D.new()
	root.name = "GardenFence"
	root.position = origin
	parent.add_child(root)
	preload("res://scripts/gameplay/prop_collision.gd").box(root, Vector3(0, 0.48, 0), Vector3(width, 0.96, 0.18))
	var wood := StandardMaterial3D.new()
	wood.albedo_texture = load("res://assets/generated/timber_albedo.png") as Texture2D
	wood.albedo_color = Color("b1a18c")
	wood.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	wood.roughness = 0.94
	wood.uv1_scale = Vector3(0.14, 1.0, 1.0)
	wood.vertex_color_use_as_albedo = true
	var beam_mesh := BoxMesh.new()
	beam_mesh.size = Vector3.ONE
	var beams := _batch(root, "TimberBeams", beam_mesh, wood, 7)
	for post_index: int in range(3):
		var x := float(post_index - 1) * (width * 0.5 - 0.08)
		beams.set_instance_transform(post_index, Transform3D(Basis.from_scale(Vector3(0.16, 0.96, 0.16)), Vector3(x, 0.48, 0.0)))
		beams.set_instance_color(post_index, Color(0.9, 0.9, 0.9))
	# Two separate rail spans meet at the middle post. Rotating local Y to X
	# also rotates the vertical grain, avoiding vertical grain on horizontal rails.
	var span := width * 0.5 - 0.08
	for bay: int in range(2):
		for row: int in range(2):
			var index := 3 + bay * 2 + row
			var center := Vector3((float(bay) - 0.5) * span, 0.34 + float(row) * 0.36, -0.015)
			var basis := Basis(Vector3.BACK, PI * 0.5).scaled_local(Vector3(0.12, span, 0.10))
			beams.set_instance_transform(index, Transform3D(basis, center))
			var shade := 0.92 + float((bay + row) % 2) * 0.08
			beams.set_instance_color(index, Color(shade, shade, shade))
	var cap_mesh := CylinderMesh.new()
	cap_mesh.top_radius = 0.0
	cap_mesh.bottom_radius = 0.12
	cap_mesh.height = 0.10
	cap_mesh.radial_segments = 4
	var caps := _batch(root, "PostCaps", cap_mesh, wood, 3)
	for post_index: int in range(3):
		var x := float(post_index - 1) * (width * 0.5 - 0.08)
		caps.set_instance_transform(post_index, Transform3D(Basis(Vector3.UP, PI * 0.25), Vector3(x, 1.01, 0.0)))
		caps.set_instance_color(post_index, Color.WHITE)
	var iron := StandardMaterial3D.new()
	iron.albedo_color = Color("363743")
	iron.roughness = 0.65
	iron.metallic = 0.5
	var nail_mesh := BoxMesh.new()
	nail_mesh.size = Vector3(0.038, 0.038, 0.015)
	var nails := _batch(root, "Fasteners", nail_mesh, iron, 12)
	for post_index: int in range(3):
		for row: int in range(2):
			for face: int in range(2):
				var index := post_index * 4 + row * 2 + face
				var position := Vector3(float(post_index - 1) * (width * 0.5 - 0.08), 0.34 + float(row) * 0.36, (float(face) * 2.0 - 1.0) * 0.085)
				nails.set_instance_transform(index, Transform3D(Basis.IDENTITY, position))
	return root


static func _batch(parent: Node3D, label: String, mesh: Mesh, material: Material, count: int) -> MultiMesh:
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.use_colors = true
	batch.mesh = mesh
	batch.instance_count = count
	var instance := MultiMeshInstance3D.new()
	instance.name = label
	instance.multimesh = batch
	instance.material_override = material
	parent.add_child(instance)
	return batch
