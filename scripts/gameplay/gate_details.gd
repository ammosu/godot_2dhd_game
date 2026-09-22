extends RefCounted
## Identical masonry and joinery on both sides of the village/ruins threshold.


static func build(gate: Node3D, left: Node3D, right: Node3D, stone: Material, iron: Material, joints: Material) -> void:
	for side: float in [-1.0, 1.0]:
		# Short wing walls anchor the doorway to the ground rather than a floating frame.
		var wall := _box(gate, Vector3(side * 2.65, 0.68, 0.0), Vector3(1.9, 1.36, 0.65), stone)
		wall.name = "WingWallWest" if side < 0.0 else "WingWallEast"
		_solid(wall, Vector3(1.9, 1.36, 0.65))
		_box(gate, Vector3(side * 2.65, 1.39, 0.0), Vector3(2.0, 0.12, 0.78), stone)
		var jamb := _box(gate, Vector3(side * 1.48, 0.2, 0.0), Vector3(0.7, 0.4, 0.82), stone)
		_solid(jamb, Vector3(0.52, 5.4, 0.62))
	# A shared apron joins both roads through the same low, walkable sill.
	_box(gate, Vector3(0.0, 0.025, 0.0), Vector3(2.35, 0.05, 3.8), stone)
	for hinge: Node3D in [left, right]:
		var direction: float = 1.0 if hinge == left else -1.0
		var details := Node3D.new()
		details.name = "Joinery"
		hinge.add_child(details)
		for face: float in [-1.0, 1.0]:
			for plank: int in range(1, 6):
				_box(details, Vector3(direction * plank * 0.195, 0.0, face * 0.095), Vector3(0.016, 2.42, 0.014), joints)
			for height: float in [-0.72, 0.72]:
				for nail_x: float in [0.15, 0.53, 1.0]:
					_box(details, Vector3(direction * nail_x, height, face * 0.18), Vector3(0.055, 0.055, 0.035), iron)
			# A solid handle and hinge straps remain visible from either approach.
			_box(details, Vector3(direction * 0.98, -0.08, face * 0.18), Vector3(0.07, 0.28, 0.12), iron)
		for height: float in [-0.85, 0.85]:
			_box(details, Vector3(0.0, height, 0.0), Vector3(0.14, 0.3, 0.3), iron)


static func _box(parent: Node3D, position: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	visual.mesh = mesh
	visual.material_override = material
	visual.position = position
	parent.add_child(visual)
	return visual


static func _solid(parent: Node3D, size: Vector3) -> void:
	var body := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collider.shape = shape
	body.add_child(collider)
	parent.add_child(body)


static func build_road_end(root: Node3D, timber: Material) -> void:
	var road_end := Node3D.new()
	road_end.name = "FutureRoadBarrier"
	root.add_child(road_end)
	# Guard the short playable spur with visible rails, including its far end.
	for side: float in [-1.0, 1.0]:
		var rail := _box(road_end, Vector3(24.75, 0.7, 4.6 + side * 2.35), Vector3(5.3, 0.16, 0.16), timber)
		_solid(rail, Vector3(5.3, 1.6, 0.2))
		for x: float in [22.4, 24.7, 27.0]:
			_box(road_end, Vector3(x, 0.5, 4.6 + side * 2.35), Vector3(0.18, 1.0, 0.18), timber)
	var barrier := _box(road_end, Vector3(27.0, 0.65, 4.6), Vector3(0.18, 0.18, 4.8), timber)
	_solid(barrier, Vector3(0.22, 1.8, 4.8))
	_box(road_end, Vector3(27.0, 0.3, 4.6), Vector3(0.18, 0.16, 4.8), timber)
	_box(road_end, Vector3(26.9, 1.05, 6.1), Vector3(0.16, 0.62, 1.55), timber)
	for side: float in [-1.0, 1.0]:
		var text := Label3D.new()
		text.text = "東行舊道\n前路修復中"
		text.font = preload("res://assets/fonts/SourceHanSansTW-Regular.otf")
		text.font_size = 40
		text.pixel_size = 0.006
		text.outline_size = 3
		text.modulate = Color("ead8ad")
		text.position = Vector3(26.9 + side * 0.09, 1.05, 6.1)
		text.rotation.y = side * PI * 0.5
		road_end.add_child(text)
