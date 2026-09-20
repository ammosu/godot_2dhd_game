extends RefCounted
## Original domestic reading cabinet, with no gameplay state or collision.


static func build(room: Node3D, wood: Material, cloth: Material, paper: Material) -> void:
	var cabinet := Node3D.new()
	cabinet.name = "LibraryCabinet"
	cabinet.position = Vector3(-3.42, 0, 1.6)
	room.add_child(cabinet)
	for z: float in [-0.80, 0.80]:
		_box(cabinet, "Side", Vector3(0, 0.98, z), Vector3(0.60, 1.92, 0.08), wood)
	for y: float in [0.18, 0.72, 1.37, 1.93]:
		_box(cabinet, "Shelf", Vector3(0, y, 0), Vector3(0.64, 0.08, 1.68), wood)
	# Two-sided low dividers let both camera directions read the scroll cubbies.
	for z: float in [-0.27, 0.27]:
		_box(cabinet, "CubbyDivider", Vector3(0, 1.65, z), Vector3(0.56, 0.50, 0.045), wood)
	for index: int in range(9):
		var z: float = -0.65 + float(index) * 0.16
		var height: float = 0.33 + float(index % 3) * 0.04
		var book := Node3D.new()
		book.name = "ArchiveBook%d" % index
		book.position = Vector3(0, 0.22 + height * 0.5, z)
		cabinet.add_child(book)
		_box(book, "Pages", Vector3.ZERO, Vector3(0.38, height - 0.025, 0.10), paper)
		for side: float in [-1.0, 1.0]:
			_box(book, "Cover", Vector3(0, 0, side * 0.06), Vector3(0.42, height, 0.015), cloth)
		_box(book, "Spine", Vector3(0.205, 0, 0), Vector3(0.02, height, 0.12), cloth)
	for slot: int in range(3):
		for roll: int in range(3):
			var scroll := MeshInstance3D.new()
			scroll.name = "ArchiveScroll%d%d" % [slot, roll]
			var mesh := CylinderMesh.new()
			mesh.top_radius = 0.065
			mesh.bottom_radius = 0.065
			mesh.height = 0.43
			mesh.radial_segments = 12
			scroll.mesh = mesh
			scroll.material_override = paper
			scroll.rotation.z = PI * 0.5
			scroll.position = Vector3(0, 1.475, float(slot - 1) * 0.53 + float(roll - 1) * 0.14)
			cabinet.add_child(scroll)
	# Sloped open book at standing reading height, facing the room (+X).
	var lectern := Node3D.new()
	lectern.name = "ReadingStand"
	lectern.position = Vector3(0, 1.00, 0)
	lectern.rotation.z = -0.28
	cabinet.add_child(lectern)
	_box(lectern, "Desktop", Vector3.ZERO, Vector3(0.52, 0.065, 1.22), wood)
	_box(lectern, "BookCover", Vector3(0, 0.044, 0), Vector3(0.43, 0.022, 0.77), cloth)
	for side: float in [-1.0, 1.0]:
		var pages := _box(lectern, "OpenPages", Vector3(0, 0.069, side * 0.18), Vector3(0.39, 0.027, 0.34), paper)
		pages.rotation.x = side * 0.06
	_box(lectern, "BookStop", Vector3(0.235, 0.065, 0), Vector3(0.025, 0.08, 1.20), wood)
	for z: float in [-0.48, 0.48]:
		_box(cabinet, "StandSupport", Vector3(0, 0.86, z), Vector3(0.10, 0.25, 0.10), wood)


static func _box(parent: Node3D, label: String, origin: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = label
	instance.position = origin
	var mesh := BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.material_override = material
	parent.add_child(instance)
	return instance
