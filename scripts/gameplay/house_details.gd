extends RefCounted
## Reusable architectural dressing; local coordinates match the 4 x 3.2 m homes.


static func build(house: Node3D, timber: Material, roof: StandardMaterial3D, plaster: StandardMaterial3D) -> void:
	var root := Node3D.new()
	root.name = "ArchitecturalDetails"
	house.add_child(root)
	_build_roof_structure(root, timber, roof, plaster)
	# Both roof slopes share one batched mesh/material, with vertex-color variation.
	var tiles := MultiMesh.new()
	tiles.transform_format = MultiMesh.TRANSFORM_3D
	tiles.use_colors = true
	tiles.mesh = _slate_tile_mesh()
	tiles.instance_count = 2 * 8 * 12
	var tile_index: int = 0
	var tile_bounds := AABB()
	for side: float in [-1.0, 1.0]:
		var slope := Basis(Vector3.FORWARD, side * 0.38)
		if side < 0.0:
			slope = slope * Basis(Vector3.UP, PI)
		for row: int in range(8):
			for column: int in range(12):
				var stagger := 0.07 if row % 2 == 0 else -0.07
				var offset := Vector3(side * (0.16 + float(row) * 0.285), 0.0, (float(column) - 5.5) * 0.32 + stagger)
				var position := Vector3(offset.x, 2.97 - absf(offset.x) * tan(0.38), offset.z)
				var transform := Transform3D(slope, position)
				tiles.set_instance_transform(tile_index, transform)
				var bounds: AABB = transform * tiles.mesh.get_aabb()
				tile_bounds = bounds if tile_index == 0 else tile_bounds.merge(bounds)
				var shade := 0.86 + float((row * 7 + column * 3) % 5) * 0.025
				tiles.set_instance_color(tile_index, Color(shade, shade, shade))
				tile_index += 1
	tiles.custom_aabb = tile_bounds
	var roof_batch := MultiMeshInstance3D.new()
	roof_batch.name = "SlateRoofTiles"
	roof_batch.multimesh = tiles
	var tile_material := roof.duplicate() as StandardMaterial3D
	tile_material.vertex_color_use_as_albedo = true
	tile_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	roof_batch.material_override = tile_material
	root.add_child(roof_batch)
	# Overlapping ridge caps hide the seam between the two roof slopes.
	for cap_index: int in range(10):
		_box(root, Vector3(0.0, 3.005, float(cap_index) * 0.40 - 1.80), Vector3(0.29, 0.13, 0.43), roof)
	_build_door(root, timber)
	# Frames are present on all four elevations so orbiting never exposes bare windows.
	for side: float in [-1.0, 1.0]:
		for x: float in ([-1.25, 1.25] if side < 0.0 else [-1.15, 1.15]):
			_box(root, Vector3(x, 1.18, side * 1.75), Vector3(0.055, 0.72, 0.07), timber)
			_box(root, Vector3(x, 1.18, side * 1.75), Vector3(0.76, 0.055, 0.07), timber)
			_box(root, Vector3(x, 0.81, side * 1.75), Vector3(0.82, 0.10, 0.20), timber)
			for edge: float in [-1.0, 1.0]:
				_box(root, Vector3(x + edge * 0.35, 1.18, side * 1.75), Vector3(0.065, 0.74, 0.07), timber)
			_box(root, Vector3(x, 1.53, side * 1.75), Vector3(0.76, 0.065, 0.07), timber)
		for z: float in [-0.72, 0.72]:
			_box(root, Vector3(side * 2.085, 1.18, z), Vector3(0.07, 0.68, 0.055), timber)
			_box(root, Vector3(side * 2.085, 1.18, z), Vector3(0.07, 0.055, 0.70), timber)
			_box(root, Vector3(side * 2.085, 0.83, z), Vector3(0.20, 0.10, 0.78), timber)
			for edge: float in [-1.0, 1.0]:
				_box(root, Vector3(side * 2.085, 1.18, z + edge * 0.33), Vector3(0.07, 0.70, 0.065), timber)
			_box(root, Vector3(side * 2.085, 1.51, z), Vector3(0.07, 0.065, 0.72), timber)
		_box(root, Vector3(side * 2.055, 1.90, 0.0), Vector3(0.14, 0.13, 3.40), timber)
		_box(root, Vector3(0.0, 1.90, side * 1.68), Vector3(4.10, 0.13, 0.14), timber)


static func _build_roof_structure(root: Node3D, timber: Material, roof: Material, plaster: StandardMaterial3D) -> void:
	# Deck top is parallel to the tile plane, not a thick independent box.
	for side: float in [-1.0, 1.0]:
		var deck := MeshInstance3D.new()
		deck.name = "RoofDeckLeft" if side < 0.0 else "RoofDeckRight"
		var slab := BoxMesh.new()
		slab.size = Vector3(2.5, 0.07, 3.80)
		deck.mesh = slab
		deck.material_override = roof
		deck.rotation.z = -side * 0.38
		deck.position = Vector3(side * 1.13, 2.97 - 1.13 * tan(0.38) - 0.06, 0.0)
		root.add_child(deck)
		_box(root, Vector3(side * 2.28, 2.00, 0.0), Vector3(0.09, 0.13, 3.86), timber)
	# Close the formerly open attic at both ends. Timber follows the roof pitch.
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side: float in [-1.0, 1.0]:
		var vertices: Array[Vector3] = [Vector3(-2.0, 2.02, side * 1.605), Vector3(2.0, 2.02, side * 1.605), Vector3(0.0, 2.86, side * 1.605)]
		for index: int in ([0, 1, 2] if side < 0.0 else [2, 1, 0]):
			var vertex := vertices[index]
			surface.set_normal(Vector3(0.0, 0.0, side))
			surface.set_uv(Vector2((vertex.x + 2.0) / 4.0, (vertex.y - 2.02) / 0.84))
			surface.add_vertex(vertex)
		_box(root, Vector3(0.0, 2.05, side * 1.67), Vector3(4.05, 0.12, 0.12), timber)
		_box(root, Vector3(0.0, 2.46, side * 1.67), Vector3(0.10, 0.79, 0.12), timber)
		for slope_side: float in [-1.0, 1.0]:
			var rafter := MeshInstance3D.new()
			rafter.name = "GableRafter"
			var beam := BoxMesh.new()
			beam.size = Vector3(2.46, 0.11, 0.12)
			rafter.mesh = beam
			rafter.material_override = timber
			rafter.rotation.z = -slope_side * 0.38
			rafter.position = Vector3(slope_side * 1.11, 2.97 - 1.11 * tan(0.38) - 0.11, side * 1.88)
			root.add_child(rafter)
	var gable := MeshInstance3D.new()
	gable.name = "PlasterGables"
	gable.mesh = surface.commit()
	gable.material_override = plaster
	root.add_child(gable)


static func _slate_tile_mesh() -> ArrayMesh:
	# A thicker chipped lower lip overlaps the next course. This is actual
	# silhouette relief, not a checkerboard painted across a flat roof plane.
	var outline: Array[Vector2] = [
		Vector2(-0.20, -0.151), Vector2(0.16, -0.151), Vector2(0.205, -0.12),
		Vector2(0.205, 0.10), Vector2(0.17, 0.151), Vector2(-0.20, 0.151),
	]
	var top: Array[Vector3] = []
	var bottom: Array[Vector3] = []
	for point: Vector2 in outline:
		top.append(Vector3(point.x, 0.018 + (point.x + 0.20) / 0.405 * 0.055, point.y))
		bottom.append(Vector3(point.x, -0.012, point.y))
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index: int in range(1, outline.size() - 1):
		_tile_triangle(surface, top[0], top[index + 1], top[index])
		_tile_triangle(surface, bottom[0], bottom[index], bottom[index + 1])
	for index: int in range(outline.size()):
		var next := (index + 1) % outline.size()
		_tile_triangle(surface, bottom[index], top[index], top[next])
		_tile_triangle(surface, bottom[index], top[next], bottom[next])
	return surface.commit()


static func _tile_triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	var normal := (b - a).cross(c - a).normalized()
	for vertex: Vector3 in [a, b, c]:
		surface.set_normal(normal)
		# Sample a smaller stone area per tile so mineral flakes stay readable.
		surface.set_uv(Vector2((vertex.x + 0.20) / 0.405, (vertex.z + 0.151) / 0.302) * 0.25)
		surface.add_vertex(vertex)


static func _build_door(root: Node3D, timber: Material) -> void:
	var wood := StandardMaterial3D.new()
	wood.albedo_texture = load("res://assets/generated/timber_albedo.png") as Texture2D
	wood.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	wood.roughness = 0.9
	wood.uv1_scale = Vector3(0.14, 1.0, 1.0)
	var doorway := StandardMaterial3D.new()
	doorway.albedo_color = Color("100d12")
	doorway.roughness = 1.0
	_box(root, Vector3(0.0, 0.91, -0.80), Vector3(0.78, 1.42, 0.025), doorway)
	var hinge := Node3D.new()
	hinge.name = "DoorHinge"
	hinge.position = Vector3(-0.39, 0.88, -1.66)
	root.add_child(hinge)
	var leaf := Node3D.new()
	leaf.name = "DoorLeaf"
	leaf.position = -hinge.position
	hinge.add_child(leaf)
	_box(leaf, Vector3(0.0, 0.88, -1.66), Vector3(0.78, 1.42, 0.14), timber)
	# Boards, straps and handle all move with the door leaf.
	for board_index: int in range(5):
		_box(leaf, Vector3(float(board_index - 2) * 0.143, 0.91, -1.746), Vector3(0.135, 1.24, 0.035), wood)
	for side: float in [-1.0, 1.0]:
		_box(root, Vector3(side * 0.43, 0.91, -1.76), Vector3(0.12, 1.48, 0.15), timber)
	_box(root, Vector3(0.0, 1.63, -1.76), Vector3(0.98, 0.14, 0.15), timber)
	var iron := StandardMaterial3D.new()
	iron.albedo_color = Color("353b46")
	iron.metallic = 0.65
	iron.roughness = 0.6
	for height: float in [0.53, 1.26]:
		_box(leaf, Vector3(-0.10, height, -1.776), Vector3(0.49, 0.055, 0.025), iron)
	var handle := MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 0.029
	ring.outer_radius = 0.052
	ring.rings = 12
	ring.ring_segments = 6
	handle.mesh = ring
	handle.material_override = iron
	handle.rotation.x = PI / 2.0
	handle.position = Vector3(0.23, 0.92, -1.80)
	leaf.add_child(handle)
	var stone := StandardMaterial3D.new()
	stone.albedo_texture = load("res://assets/generated/ruin_flagstone.png") as Texture2D
	stone.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	stone.roughness = 0.95
	_box(root, Vector3(0.0, 0.255, -1.99), Vector3(1.20, 0.075, 0.65), stone)


static func _box(parent: Node3D, position: Vector3, size: Vector3, material: Material) -> void:
	var instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.position = position
	instance.material_override = material
	parent.add_child(instance)
