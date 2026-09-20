extends Node3D
## Original closed household chest, ground origin; collision belongs to room.


func _ready() -> void:
	var wood := StandardMaterial3D.new()
	wood.albedo_texture = preload("res://assets/generated/timber_albedo.png")
	wood.albedo_color = Color("947957")
	wood.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	wood.roughness = 0.9
	var iron := StandardMaterial3D.new()
	iron.albedo_color = Color("353943")
	iron.metallic = 0.65
	iron.roughness = 0.65
	var brass := StandardMaterial3D.new()
	brass.albedo_color = Color("b29660")
	brass.metallic = 0.55
	brass.roughness = 0.6
	# Recessed core keeps the narrow plank gaps dark rather than see-through.
	_box("Core", Vector3(0, 0.34, 0), Vector3(0.77, 0.60, 0.75), iron)
	for row: int in range(3):
		var y: float = 0.14 + row * 0.18
		for side: float in [-1.0, 1.0]:
			_box("FrontBackPlank", Vector3(0, y, side * 0.38), Vector3(0.79, 0.17, 0.05), wood)
			_box("SidePlank", Vector3(side * 0.39, y, 0), Vector3(0.05, 0.17, 0.73), wood)
	_box("LidSeam", Vector3(0, 0.626, 0), Vector3(0.80, 0.016, 0.79), iron)
	for plank: int in range(4):
		_box("LidPlank", Vector3(-0.306 + plank * 0.204, 0.687, 0), Vector3(0.198, 0.106, 0.81), wood)
	for x: float in [-0.30, 0.30]:
		_box("LidStrap", Vector3(x, 0.747, 0), Vector3(0.055, 0.014, 0.816), iron)
		for side: float in [-1.0, 1.0]:
			_box("StrapEnd", Vector3(x, 0.645, side * 0.412), Vector3(0.055, 0.19, 0.016), iron)
			_box("Rivet", Vector3(x, 0.595, side * 0.423), Vector3(0.024, 0.024, 0.01), brass)
	for x: float in [-0.402, 0.402]:
		for z: float in [-0.392, 0.392]:
			_box("Corner", Vector3(x, 0.32, z), Vector3(0.045, 0.60, 0.045), iron)
	_box("Latch", Vector3(0, 0.60, 0.417), Vector3(0.115, 0.20, 0.02), brass)
	_box("Keyhole", Vector3(0, 0.565, 0.431), Vector3(0.025, 0.045, 0.012), iron)


func _box(label: String, origin: Vector3, size: Vector3, material: Material) -> void:
	var instance := MeshInstance3D.new()
	instance.name = label
	instance.position = origin
	var mesh := BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.material_override = material
	add_child(instance)
