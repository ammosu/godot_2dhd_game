extends RefCounted
## Original wall-mounted dressing, kept outside the central entrance corridor.

const THEMES: Dictionary = {"house_01": "weaving", "house_02": "garden", "house_03": "moon", "house_04": "pottery", "house_05": "quilt", "house_06": "compass", "house_07": "herbs", "house_08": "book"}


static func build(house: Node3D, house_id: String, wood: Material) -> void:
	if not THEMES.has(house_id):
		return
	var root := Node3D.new()
	root.name = "ExteriorDressing"
	root.set_meta("theme", THEMES[house_id])
	house.add_child(root)
	preload("res://scripts/gameplay/facade_planters.gd").build(root, house_id, wood)
	if house_id not in ["house_02", "house_04"]:
		var kind: String = THEMES[house_id]
		preload("res://scripts/gameplay/house_emblem.gd").build(root, kind, wood)
		return
	for x: float in [-1.25, 1.25]:
		# Top at 0.76 m, below the existing sill. Supports touch the wall.
		_box(root, Vector3(x, 0.72, -1.88), Vector3(0.85, 0.08, 0.40), wood)
		for side: float in [-1.0, 1.0]:
			_box(root, Vector3(x + side * 0.30, 0.59, -1.78), Vector3(0.07, 0.20, 0.23), wood)
		if house_id == "house_02":
			_planter(root, x, wood)
		else:
			for index: int in range(3):
				var jar := (preload("res://assets/generated/earthenware_jar.glb") as PackedScene).instantiate() as Node3D
				jar.name = "DisplayPot%s%d" % ["Left" if x < 0.0 else "Right", index]
				jar.scale = Vector3.ONE * (0.25 if index == 1 else 0.19)
				jar.position = Vector3(x + float(index - 1) * 0.25, 0.76, -1.91)
				root.add_child(jar)


static func build_collision(house: StaticBody3D, house_id: String) -> void:
	# Visual roots have already received the exterior's non-uniform scale.
	# Bake that scale into box dimensions; keep physics on the unscaled house.
	var root := house.get_node("ExteriorDressing") as Node3D
	var planters := root.get_node("FacadePlanters") as Node3D
	for node: Node in planters.get_children():
		var planter := node as Node3D
		_add_collision(house, planter, Vector3(0, 0.71, 0.207), Vector3(0.88, 0.42, 0.433), Vector3.BACK)
	if house_id in ["house_02", "house_04"]:
		for x: float in [-1.25, 1.25]:
			var height: float = 0.44 if house_id == "house_02" else 0.27
			_add_collision(house, root, Vector3(x, 0.49 + height * 0.5, -1.875), Vector3(0.85, height, 0.415), Vector3.FORWARD)


static func _add_collision(house: StaticBody3D, mount: Node3D, center: Vector3, size: Vector3, outward: Vector3) -> void:
	var local: Transform3D = house.global_transform.affine_inverse() * mount.global_transform
	var shape := BoxShape3D.new()
	shape.size = size * local.basis.get_scale().abs()
	var collider := CollisionShape3D.new()
	collider.name = "FacadeCollision"
	collider.shape = shape
	collider.transform = Transform3D(local.basis.orthonormalized(), local * center)
	collider.set_meta("outward", outward)
	collider.add_to_group("house_facade_collisions")
	house.add_child(collider)


static func _planter(root: Node3D, x: float, wood: Material) -> void:
	_box(root, Vector3(x, 0.83, -2.06), Vector3(0.85, 0.20, 0.045), wood)
	for side: float in [-1.0, 1.0]:
		_box(root, Vector3(x + side * 0.405, 0.83, -1.88), Vector3(0.04, 0.20, 0.37), wood)
	var soil := StandardMaterial3D.new()
	soil.albedo_color = Color("302822")
	soil.roughness = 1.0
	_box(root, Vector3(x, 0.87, -1.88), Vector3(0.76, 0.04, 0.32), soil)
	for index: int in range(3):
		var flowers := Sprite3D.new()
		flowers.name = "WindowFlowers"
		flowers.texture = preload("res://assets/generated/flowers_mauve.tres")
		flowers.pixel_size = 0.00085
		flowers.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
		flowers.shaded = true
		flowers.double_sided = true
		flowers.position = Vector3(x + float(index - 1) * 0.17, 0.89 + 300.0 * flowers.pixel_size, -1.97)
		root.add_child(flowers)


static func _box(parent: Node3D, position: Vector3, size: Vector3, material: Material) -> void:
	var instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.position = position
	instance.material_override = material
	parent.add_child(instance)
