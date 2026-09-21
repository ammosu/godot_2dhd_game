extends RefCounted
## Simple solid footprints for scenery, independent of imported art resources.


static func box(parent: Node3D, center: Vector3, size: Vector3) -> void:
	var shape := BoxShape3D.new()
	shape.size = size
	_attach(parent, center, shape)


static func cylinder(parent: Node3D, center: Vector3, radius: float, height: float) -> void:
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = height
	_attach(parent, center, shape)


static func from_meshes(parent: Node3D, round_footprint: bool = false) -> void:
	var bounds := AABB()
	var first: bool = true
	for node: Node in parent.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		var local: Transform3D = parent.global_transform.affine_inverse() * mesh.global_transform
		var mesh_bounds: AABB = local * mesh.get_aabb()
		bounds = mesh_bounds if first else bounds.merge(mesh_bounds)
		first = false
	assert(not first, "Solid prop requires mesh bounds")
	if round_footprint:
		cylinder(parent, bounds.get_center(), maxf(bounds.size.x, bounds.size.z) * 0.5, bounds.size.y)
	else:
		box(parent, bounds.get_center(), bounds.size)


static func _attach(parent: Node3D, center: Vector3, shape: Shape3D) -> void:
	var body := StaticBody3D.new()
	body.name = "PropBody"
	body.collision_layer = 1
	body.collision_mask = 1
	body.add_to_group("solid_scenery")
	var collider := CollisionShape3D.new()
	collider.name = "Shape"
	collider.position = center
	collider.shape = shape
	body.add_child(collider)
	parent.add_child(body)
