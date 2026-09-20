extends RefCounted
## Original upright hand loom; geometry only, supported by room collision.


static func build(room: Node3D, wood: Material, cloth: Material, thread: Material) -> void:
	var loom := Node3D.new()
	loom.name = "WeavingFrame"
	loom.position = Vector3(-3.42, 0, 1.6)
	room.add_child(loom)
	for z: float in [-0.73, 0.73]:
		_box(loom, "Foot", Vector3(0, 0.07, z), Vector3(0.64, 0.09, 0.12), wood)
		_box(loom, "Upright", Vector3(0, 0.97, z), Vector3(0.09, 1.85, 0.10), wood)
	for y: float in [0.36, 1.70]:
		var roller := MeshInstance3D.new()
		roller.name = "ClothRoller"
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.075
		mesh.bottom_radius = 0.075
		mesh.height = 1.65
		mesh.radial_segments = 12
		roller.mesh = mesh
		roller.material_override = wood
		roller.position.y = y
		roller.rotation.x = PI * 0.5
		loom.add_child(roller)
	for index: int in range(25):
		_box(loom, "Warp%d" % index, Vector3(0.01, 1.04, -0.60 + index * 0.05), Vector3(0.012, 1.27, 0.009), thread)
	_box(loom, "WovenCloth", Vector3(0.01, 0.69, 0), Vector3(0.04, 0.58, 1.22), cloth)
	# Woven bands on both sides remain readable after camera orbit.
	for side: float in [-1.0, 1.0]:
		for y: float in [0.49, 0.54, 0.81, 0.86]:
			_box(loom, "WovenBand", Vector3(0.01 + side * 0.023, y, 0), Vector3(0.006, 0.016, 1.18), thread)
		for z: float in [-0.50, -0.25, 0.0, 0.25, 0.50]:
			var motif := _box(loom, "Diamond", Vector3(0.01 + side * 0.024, 0.675, z), Vector3(0.007, 0.075, 0.075), thread)
			motif.rotation.x = PI * 0.25
	_box(loom, "Heddle", Vector3(0.075, 1.12, 0), Vector3(0.065, 0.05, 1.32), wood)
	var shuttle := _box(loom, "Shuttle", Vector3(0.11, 0.99, 0.20), Vector3(0.10, 0.055, 0.34), wood)
	shuttle.rotation.x = 0.16
	_box(loom, "ShuttleThread", Vector3(0.165, 0.99, 0.20), Vector3(0.015, 0.035, 0.15), cloth)


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
