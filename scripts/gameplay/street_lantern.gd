extends RefCounted
## Original reusable lantern geometry, shared by all village lamp instances.
## Two mesh batches (weathered metal and frosted panes), one existing light.

static var _frame_mesh: ArrayMesh
static var _pane_mesh: ArrayMesh
static var _metal: StandardMaterial3D
static var _glass: ShaderMaterial


static func build(parent: Node3D, position: Vector3) -> Node3D:
	if _frame_mesh == null:
		_build_resources()
	var root := Node3D.new()
	root.name = "Lantern"
	root.position = position
	root.add_to_group("street_lanterns")
	parent.add_child(root)
	for index: int in range(2):
		var mesh := MeshInstance3D.new()
		mesh.name = "Metalwork" if index == 0 else "FrostedGlass"
		mesh.mesh = _frame_mesh if index == 0 else _pane_mesh
		mesh.material_override = _metal if index == 0 else _glass
		root.add_child(mesh)
	var light := OmniLight3D.new()
	light.name = "RoadLight"
	light.position.y = 1.42
	light.light_color = Color("ffb968")
	light.light_energy = 3.2
	light.omni_range = 4.5
	root.add_child(light)
	return root


static func _build_resources() -> void:
	_metal = StandardMaterial3D.new()
	_metal.albedo_texture = preload("res://assets/generated/moon_lamp_aged_bronze_albedo.png")
	_metal.albedo_color = Color("6b7778")
	_metal.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_metal.metallic = 0.65
	_metal.roughness = 0.78
	_glass = ShaderMaterial.new()
	_glass.shader = preload("res://shaders/lantern_glass.gdshader")
	var metal := SurfaceTool.new()
	metal.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Stepped octagonal foot, tapered post and collars meet with no gaps.
	_cylinder(metal, Vector3(0, 0.035, 0), 0.15, 0.17, 0.07)
	_cylinder(metal, Vector3(0, 0.105, 0), 0.085, 0.13, 0.07)
	_cylinder(metal, Vector3(0, 0.67, 0), 0.045, 0.075, 1.06)
	_cylinder(metal, Vector3(0, 1.19, 0), 0.075, 0.075, 0.045)
	_box(metal, Vector3(0, 1.225, 0), Vector3(0.34, 0.05, 0.34))
	_box(metal, Vector3(0, 1.615, 0), Vector3(0.34, 0.05, 0.34))
	for x: float in [-0.145, 0.145]:
		for z: float in [-0.145, 0.145]:
			_box(metal, Vector3(x, 1.42, z), Vector3(0.025, 0.34, 0.025))
	# Slim horizontal lower rail divides the glass without covering the light.
	for side: int in range(4):
		var basis := Basis(Vector3.UP, side * PI * 0.5)
		_box(metal, basis * Vector3(0, 1.35, 0.151), Vector3(0.28, 0.016, 0.018) if side % 2 == 0 else Vector3(0.018, 0.016, 0.28))
		var a := basis * Vector3(-0.19, 1.64, 0.19)
		var b := basis * Vector3(0.19, 1.64, 0.19)
		var c := Vector3(0, 1.77, 0)
		_triangle(metal, a, c, b, Vector2(0, 1), Vector2(0.5, 0), Vector2(1, 1))
	_cylinder(metal, Vector3(0, 1.785, 0), 0.025, 0.04, 0.05)
	_frame_mesh = metal.commit()
	var glass := SurfaceTool.new()
	glass.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side: int in range(4):
		var basis := Basis(Vector3.UP, side * PI * 0.5)
		var a := basis * Vector3(-0.132, 1.25, 0.142)
		var b := basis * Vector3(0.132, 1.25, 0.142)
		var c := basis * Vector3(0.132, 1.59, 0.142)
		var d := basis * Vector3(-0.132, 1.59, 0.142)
		_triangle(glass, a, d, c, Vector2(0, 1), Vector2(0, 0), Vector2(1, 0))
		_triangle(glass, a, c, b, Vector2(0, 1), Vector2(1, 0), Vector2(1, 1))
	_pane_mesh = glass.commit()


static func _box(surface: SurfaceTool, position: Vector3, size: Vector3) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	_append(surface, mesh, position)


static func _cylinder(surface: SurfaceTool, position: Vector3, top: float, bottom: float, height: float) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = 8
	mesh.rings = 1
	_append(surface, mesh, position)


static func _append(surface: SurfaceTool, mesh: PrimitiveMesh, position: Vector3) -> void:
	# Expand primitive indices so custom roof triangles share one unindexed batch.
	var arrays: Array = mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	for index: int in indices:
		surface.set_normal(normals[index])
		surface.set_uv(uvs[index])
		surface.add_vertex(vertices[index] + position)


static func _triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, uv_a: Vector2, uv_b: Vector2, uv_c: Vector2) -> void:
	# Godot front faces use clockwise winding; normal points to the outer face.
	var normal := (c - a).cross(b - a).normalized()
	for pair: Array in [[a, uv_a], [b, uv_b], [c, uv_c]]:
		surface.set_normal(normal)
		surface.set_uv(pair[1])
		surface.add_vertex(pair[0])
