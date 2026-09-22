extends RefCounted
## Continuous ramp collision beneath individual timber planks; no stair snagging.

static func build(parent: Node3D, center: Vector3) -> Node3D:
	var bridge := Node3D.new()
	bridge.name = "CreekBridge"
	bridge.position = center
	parent.add_child(bridge)
	var wood := StandardMaterial3D.new()
	wood.albedo_texture = preload("res://assets/generated/timber_albedo.png")
	wood.albedo_color = Color("b99870")
	wood.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	wood.roughness = 0.95
	var dark: StandardMaterial3D = wood.duplicate()
	dark.albedo_color = Color("69513c")
	var iron := StandardMaterial3D.new()
	iron.albedo_color = Color("3b4246")
	iron.metallic = 0.65
	iron.roughness = 0.65
	for index: int in range(30):
		var z: float = -3.6 + (index + 0.5) * 0.24
		var height: float = 0.42 - maxf(0.0, absf(z) - 2.4) * 0.3
		var plank: MeshInstance3D = _box(bridge, Vector3(0, height - 0.055, z), Vector3(3.2, 0.11, 0.231), wood)
		if absf(z) > 2.4:
			plank.rotation.x = atan(0.3) * signf(z)
	var hull := PackedVector3Array()
	for x: float in [-1.6, 1.6]:
		for point: Vector2 in [Vector2(-3.6, 0.06), Vector2(-2.4, 0.42), Vector2(2.4, 0.42), Vector2(3.6, 0.06), Vector2(3.6, -0.1), Vector2(-3.6, -0.1)]:
			hull.append(Vector3(x, point.y, point.x))
	var deck := StaticBody3D.new()
	deck.name = "WalkableDeck"
	var shape := ConvexPolygonShape3D.new()
	shape.points = hull
	var collision := CollisionShape3D.new()
	collision.shape = shape
	deck.add_child(collision)
	bridge.add_child(deck)
	preload("res://scripts/gameplay/footsteps.gd").register_surface(bridge, Vector3(3.2, 0.5, 7.2), &"wood", 20)
	for side: float in [-1, 1]:
		_box(bridge, Vector3(side * 1.25, 0.21, 0), Vector3(0.2, 0.3, 4.8), dark)
		for z: float in [-2.4, -1.2, 0, 1.2, 2.4]:
			_box(bridge, Vector3(side * 1.53, 0.7, z), Vector3(0.18, 1.35, 0.18), dark)
			_box(bridge, Vector3(side * 1.53, 1.18, z), Vector3(0.195, 0.12, 0.195), iron)
		for y: float in [0.77, 1.28]:
			_box(bridge, Vector3(side * 1.53, y, 0), Vector3(0.12, 0.12, 5.0), wood)
		var rail := StaticBody3D.new()
		rail.name = "SafetyRail"
		rail.position = Vector3(side * 1.53, 0.8, 0)
		var rail_collision := CollisionShape3D.new()
		var rail_shape := BoxShape3D.new()
		rail_shape.size = Vector3(0.18, 1.6, 5.0)
		rail_collision.shape = rail_shape
		rail.add_child(rail_collision)
		bridge.add_child(rail)
	return bridge


static func _box(parent: Node3D, position: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.position = position
	mesh.material_override = material
	parent.add_child(mesh)
	return mesh
