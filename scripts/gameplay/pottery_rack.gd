extends RefCounted
## Original drying-rack arrangement using the project's original earthenware.
## All parts fit the room's existing shelf collision; no interactions or state.


static func build(room: Node3D, wood: Material) -> void:
	var rack := Node3D.new()
	rack.name = "PotteryRack"
	rack.position = Vector3(-3.42, 0, 1.6)
	room.add_child(rack)
	for x: float in [-0.27, 0.27]:
		for z: float in [-0.77, 0.77]:
			_box(rack, "Upright", Vector3(x, 0.98, z), Vector3(0.07, 1.92, 0.07), wood)
	for level: int in range(3):
		var height: float = 0.18 + level * 0.67
		for slat: int in range(4):
			_box(rack, "DryingSlat", Vector3(-0.255 + slat * 0.17, height, 0), Vector3(0.155, 0.09, 1.7), wood)
		for side: float in [-1.0, 1.0]:
			_box(rack, "ShelfRail", Vector3(side * 0.27, height - 0.07, 0), Vector3(0.065, 0.10, 1.65), wood)
		for column: int in range(3):
			var jar := (preload("res://assets/generated/earthenware_jar.glb") as PackedScene).instantiate() as Node3D
			jar.name = "DryingPot%d%d" % [level, column]
			jar.position = Vector3(0, height + 0.045, float(column - 1) * 0.54)
			jar.scale = Vector3.ONE * (0.55 if column == 1 else 0.48)
			jar.rotation.y = float(column - 1) * 0.18
			rack.add_child(jar)
	# Open back exposes the pale wall between rows, unlike the shared bookcase.
	for z: float in [-0.77, 0.77]:
		_box(rack, "TopRail", Vector3(0, 1.91, z), Vector3(0.61, 0.08, 0.07), wood)


static func _box(parent: Node3D, label: String, origin: Vector3, size: Vector3, material: Material) -> void:
	var instance := MeshInstance3D.new()
	instance.name = label
	instance.position = origin
	var mesh := BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.material_override = material
	parent.add_child(instance)
