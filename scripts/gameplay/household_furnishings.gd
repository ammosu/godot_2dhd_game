extends RefCounted
## Original decorative furniture for the remaining domestic themes.
## Coordinates are relative to the shared wall-furniture footprint.

const THEMES: Dictionary[String, String] = {
	"house_03": "MoonRecordStand", "house_05": "LinenCupboard",
	"house_06": "TravelGearStand", "house_07": "HerbDryingStand",
}


static func build(room: Node3D, house_id: String, wood: Material, cloth: Material, linen: Material) -> void:
	var furniture := Node3D.new()
	furniture.name = THEMES[house_id]
	furniture.position = Vector3(-3.42, 0, 1.6)
	room.add_child(furniture)
	match house_id:
		"house_03": _moon_records(furniture, wood, linen)
		"house_05": _linen_cupboard(furniture, wood, cloth, linen)
		"house_06": _travel_gear(furniture, wood, cloth, linen)
		"house_07": _herb_stand(furniture, wood, linen)


static func _frame(parent: Node3D, wood: Material, height: float) -> void:
	for z: float in [-0.74, 0.74]:
		_box(parent, "Foot", Vector3(0, 0.07, z), Vector3(0.63, 0.09, 0.12), wood)
		_box(parent, "Post", Vector3(0, height * 0.5 + 0.025, z), Vector3(0.09, height, 0.09), wood)
	_box(parent, "TopRail", Vector3(0, height, 0), Vector3(0.10, 0.09, 1.56), wood)


static func _moon_records(parent: Node3D, wood: Material, linen: Material) -> void:
	_frame(parent, wood, 1.88)
	_box(parent, "ChartPanel", Vector3(0, 1.19, 0), Vector3(0.055, 1.10, 1.34), wood)
	var print_material := StandardMaterial3D.new()
	print_material.albedo_texture = preload("res://assets/generated/house_prints.png")
	print_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	print_material.roughness = 0.95
	var texture_size := Vector2(print_material.albedo_texture.get_size())
	print_material.uv1_scale = Vector3(600.0 / texture_size.x, 580.0 / texture_size.y, 1)
	print_material.uv1_offset = Vector3(642.0 / texture_size.x, 12.0 / texture_size.y, 0)
	for side: float in [-1.0, 1.0]:
		var quad := QuadMesh.new()
		quad.size = Vector2(1.22, 0.98)
		var chart := _mesh(parent, "MoonChart", Vector3(side * 0.032, 1.19, 0), quad, print_material)
		chart.rotation.y = side * PI * 0.5
	_box(parent, "RecordShelf", Vector3(0, 0.35, 0), Vector3(0.60, 0.08, 1.55), wood)
	for index: int in range(5):
		var roll := _cylinder(parent, "RecordRoll%d" % index, Vector3(0, 0.465, -0.52 + index * 0.26), 0.075, 0.075, 0.40, linen)
		roll.rotation.z = PI * 0.5


static func _linen_cupboard(parent: Node3D, wood: Material, cloth: Material, linen: Material) -> void:
	for z: float in [-0.79, 0.79]:
		_box(parent, "EndPanel", Vector3(0, 0.82, z), Vector3(0.61, 1.59, 0.08), wood)
	for y: float in [0.18, 0.82, 1.62]:
		_box(parent, "Shelf", Vector3(0, y, 0), Vector3(0.65, 0.08, 1.65), wood)
	for pile: int in range(3):
		for layer: int in range(4):
			var folded := _box(parent, "FoldedLinen%d%d" % [pile, layer], Vector3(0, 0.263 + layer * 0.087, float(pile - 1) * 0.50), Vector3(0.48, 0.08, 0.42), linen if layer % 2 == 0 else cloth)
			folded.rotation.y = float((pile + layer) % 3 - 1) * 0.035
	for index: int in range(4):
		var bolt := _cylinder(parent, "ClothBolt%d" % index, Vector3(0, 1.035, -0.57 + index * 0.38), 0.17, 0.17, 0.46, cloth if index % 2 == 0 else linen)
		bolt.rotation.z = PI * 0.5
		var core := _cylinder(parent, "BoltCore", Vector3(0, 1.035, -0.57 + index * 0.38), 0.04, 0.04, 0.52, wood)
		core.rotation.z = PI * 0.5


static func _travel_gear(parent: Node3D, wood: Material, cloth: Material, linen: Material) -> void:
	_frame(parent, wood, 1.84)
	_box(parent, "GearBench", Vector3(0, 0.38, 0), Vector3(0.64, 0.09, 1.60), wood)
	var leather := StandardMaterial3D.new()
	leather.albedo_color = Color("6e4b34")
	leather.roughness = 0.95
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color("b49b66")
	metal.metallic = 0.4
	metal.roughness = 0.6
	_box(parent, "TravelPack", Vector3(0, 0.72, -0.30), Vector3(0.40, 0.59, 0.48), cloth)
	_box(parent, "PackFlap", Vector3(0.015, 1.025, -0.30), Vector3(0.43, 0.055, 0.51), leather)
	for side: float in [-1.0, 1.0]:
		_box(parent, "PackStrap", Vector3(side * 0.212, 0.73, -0.30), Vector3(0.024, 0.57, 0.065), leather)
		_box(parent, "PackBuckle", Vector3(side * 0.229, 0.78, -0.30), Vector3(0.014, 0.065, 0.09), metal)
	var bedroll := _cylinder(parent, "Bedroll", Vector3(0, 1.145, -0.30), 0.09, 0.09, 0.52, linen)
	bedroll.rotation.x = PI * 0.5
	_cylinder(parent, "WalkingStaff", Vector3(0, 1.09, 0.44), 0.027, 0.032, 1.32, wood)
	_box(parent, "StaffGrip", Vector3(0, 1.63, 0.44), Vector3(0.08, 0.19, 0.07), leather)
	_box(parent, "StaffSupport", Vector3(0, 1.38, 0.59), Vector3(0.10, 0.08, 0.38), wood)


static func _herb_stand(parent: Node3D, wood: Material, linen: Material) -> void:
	_frame(parent, wood, 1.88)
	_box(parent, "DryingTray", Vector3(0, 0.26, 0), Vector3(0.61, 0.08, 1.59), wood)
	var herbs := StandardMaterial3D.new()
	herbs.albedo_color = Color("718050")
	herbs.roughness = 1.0
	for bunch: int in range(4):
		var bundle := Node3D.new()
		bundle.name = "HerbBundle%d" % bunch
		bundle.position = Vector3(0, 0, -0.57 + bunch * 0.38)
		parent.add_child(bundle)
		_cylinder(bundle, "Tie", Vector3(0, 1.77, 0), 0.012, 0.012, 0.19, linen)
		for sprig: int in range(5):
			var angle: float = sprig * TAU / 5.0
			var stem := _cylinder(bundle, "Sprig", Vector3(sin(angle) * 0.035, 1.40, cos(angle) * 0.035), 0.007, 0.011, 0.56, herbs)
			stem.rotation.z = sin(angle) * 0.13
			for leaf: int in range(3):
				var blade := SphereMesh.new()
				blade.radius = 1.0
				blade.height = 2.0
				blade.radial_segments = 6
				blade.rings = 3
				var visual := _mesh(bundle, "DriedLeaf", Vector3(sin(angle) * 0.07, 1.18 + leaf * 0.13, cos(angle) * 0.07), blade, herbs)
				visual.scale = Vector3(0.028, 0.095, 0.035)
				visual.rotation.z = sin(angle) * 0.5
	for index: int in range(3):
		var jar := (preload("res://assets/generated/earthenware_jar.glb") as PackedScene).instantiate() as Node3D
		jar.name = "HerbPot%d" % index
		jar.scale = Vector3.ONE * 0.45
		jar.position = Vector3(0, 0.30, float(index - 1) * 0.51)
		parent.add_child(jar)


static func _box(parent: Node3D, label: String, origin: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _mesh(parent, label, origin, mesh, material)


static func _cylinder(parent: Node3D, label: String, origin: Vector3, top: float, bottom: float, height: float, material: Material) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = 12
	return _mesh(parent, label, origin, mesh, material)


static func _mesh(parent: Node3D, label: String, origin: Vector3, mesh: Mesh, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = label
	instance.position = origin
	instance.mesh = mesh
	instance.material_override = material
	parent.add_child(instance)
	return instance
