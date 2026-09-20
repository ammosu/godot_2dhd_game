extends RefCounted
## Original solid-mesh wayfinding ornaments, attached to the front gable.


static func build(parent: Node3D, kind: String, wood: Material) -> Node3D:
	var root := Node3D.new()
	root.name = "GableEmblem"
	root.position = Vector3(0, 2.43, -1.78)
	root.set_meta("kind", kind)
	parent.add_child(root)
	var gold := _material(Color("b69552"))
	if kind == "book":
		_box(root, "Backing", Vector3.ZERO, Vector3(0.72, 0.51, 0.075), wood)
		var paper := _material(Color("d6c59b"))
		var cover := _material(Color("354d5a"))
		var ink := _material(Color("807457"))
		for side: float in [-1.0, 1.0]:
			var leaf := Node3D.new()
			leaf.name = "LeftLeaf" if side < 0.0 else "RightLeaf"
			leaf.position = Vector3(side * 0.145, 0, -0.069)
			leaf.rotation.y = -side * 0.20
			root.add_child(leaf)
			_box(leaf, "Cover", Vector3.ZERO, Vector3(0.28, 0.40, 0.025), cover)
			_box(leaf, "Pages", Vector3(0, 0.008, -0.026), Vector3(0.25, 0.35, 0.035), paper)
			for line: int in range(4):
				_box(leaf, "TextLine%d" % line, Vector3(0, 0.09 - line * 0.05, -0.045), Vector3(0.15, 0.009, 0.005), ink)
		_box(root, "Spine", Vector3(0, 0, -0.125), Vector3(0.023, 0.39, 0.018), gold)
		_box(root, "Bookmark", Vector3(0.065, -0.145, -0.134), Vector3(0.03, 0.18, 0.012), _material(Color("8c4148")))
	elif kind == "compass":
		var disc := MeshInstance3D.new()
		disc.name = "OctagonalBacking"
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = 0.32
		cylinder.bottom_radius = 0.32
		cylinder.height = 0.075
		cylinder.radial_segments = 8
		disc.mesh = cylinder
		disc.rotation.x = PI * 0.5
		disc.material_override = wood
		root.add_child(disc)
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		for point: int in range(8):
			var basis := Basis(Vector3.BACK, float(point) * TAU / 8.0)
			var tip := basis * Vector3(0, 0.25 if point % 2 == 0 else 0.15, -0.052)
			var left := basis * Vector3(-0.038, 0, -0.052)
			var right := basis * Vector3(0.038, 0, -0.052)
			var center := Vector3(0, 0, -0.082)
			_triangle(surface, tip, left, center, Color("c1a366"))
			_triangle(surface, tip, center, right, Color("776345"))
		var rose := MeshInstance3D.new()
		rose.name = "CompassRose"
		rose.mesh = surface.commit()
		var colors := _material(Color.WHITE)
		colors.vertex_color_use_as_albedo = true
		rose.material_override = colors
		root.add_child(rose)
	else:
		# Runtime load avoids a cyclic preload with the shared mesh helpers.
		load("res://scripts/gameplay/craft_emblems.gd").build(root, kind, wood)
	return root


static func _triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
	for vertex: Vector3 in [a, b, c]:
		surface.set_normal((c - a).cross(b - a).normalized())
		surface.set_color(color)
		surface.add_vertex(vertex)


static func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.85
	return material


static func _box(parent: Node3D, label: String, position: Vector3, size: Vector3, material: Material) -> void:
	var instance := MeshInstance3D.new()
	instance.name = label
	var box := BoxMesh.new()
	box.size = size
	instance.mesh = box
	instance.position = position
	instance.material_override = material
	parent.add_child(instance)
