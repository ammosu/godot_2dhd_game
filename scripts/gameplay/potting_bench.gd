extends RefCounted
## Original nursery furniture. Decorative only; room owns the collision.


static func build(room: Node3D, wood: Material) -> void:
	var bench := Node3D.new()
	bench.name = "PottingBench"
	bench.position = Vector3(-3.42, 0, 1.6)
	room.add_child(bench)
	var clay := _material(Color("b97f5b"))
	var soil := _material(Color("393028"))
	var green := _material(Color("668951"))
	var young := _material(Color("9cac68"))
	for x: float in [-0.27, 0.27]:
		for z: float in [-0.75, 0.75]:
			_box(bench, "Leg", Vector3(x, 0.47, z), Vector3(0.08, 0.90, 0.08), wood)
	for y: float in [0.23, 0.92]:
		for slat: int in range(4):
			_box(bench, "Board", Vector3(-0.255 + slat * 0.17, y, 0), Vector3(0.155, 0.08, 1.7), wood)
	# Shallow seed tray on the lower shelf, with a visible recessed soil bed.
	_box(bench, "SeedSoil", Vector3(0, 0.30, 0), Vector3(0.43, 0.07, 1.25), soil)
	for side: float in [-1.0, 1.0]:
		_box(bench, "TraySide", Vector3(side * 0.235, 0.32, 0), Vector3(0.04, 0.12, 1.33), wood)
		_box(bench, "TrayEnd", Vector3(0, 0.32, side * 0.645), Vector3(0.43, 0.12, 0.04), wood)
	for index: int in range(3):
		var plant := Node3D.new()
		plant.name = "Seedling%d" % index
		plant.position = Vector3(0, 0.96, float(index - 1) * 0.53)
		bench.add_child(plant)
		_cylinder(plant, "Pot", Vector3(0, 0.115, 0), 0.15, 0.11, 0.23, clay)
		_cylinder(plant, "Rim", Vector3(0, 0.22, 0), 0.165, 0.165, 0.04, clay)
		_cylinder(plant, "Soil", Vector3(0, 0.242, 0), 0.145, 0.145, 0.006, soil)
		var height: float = 0.34 + index * 0.055
		_cylinder(plant, "Stem", Vector3(0, 0.245 + height * 0.5, 0), 0.008, 0.013, height, green)
		for leaf: int in range(6):
			var angle: float = float(leaf) * 2.4 + index
			var mesh := SphereMesh.new()
			mesh.radius = 1.0
			mesh.height = 2.0
			mesh.radial_segments = 8
			mesh.rings = 4
			var blade := MeshInstance3D.new()
			blade.name = "Leaf%d" % leaf
			blade.mesh = mesh
			blade.material_override = green if leaf < 4 else young
			blade.position = Vector3(sin(angle) * 0.085, 0.29 + height * float(leaf + 1) / 7.0, cos(angle) * 0.085)
			blade.rotation = Vector3(-0.25, angle, 0)
			blade.scale = Vector3(0.06, 0.018, 0.12)
			plant.add_child(blade)


static func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.95
	return material


static func _box(parent: Node3D, label: String, origin: Vector3, size: Vector3, material: Material) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	_add(parent, label, origin, mesh, material)


static func _cylinder(parent: Node3D, label: String, origin: Vector3, top: float, bottom: float, height: float, material: Material) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = 12
	_add(parent, label, origin, mesh, material)


static func _add(parent: Node3D, label: String, origin: Vector3, mesh: Mesh, material: Material) -> void:
	var instance := MeshInstance3D.new()
	instance.name = label
	instance.position = origin
	instance.mesh = mesh
	instance.material_override = material
	parent.add_child(instance)
