extends RefCounted
## Original solid timber props and terrain-fitted verge details. No gameplay state.

const Bridge = preload("res://scripts/gameplay/creek_bridge.gd")
const GRASSES: Array[Texture2D] = [preload("res://assets/generated/grass_low.tres"), preload("res://assets/generated/grass_fan.tres"), preload("res://assets/generated/grass_seed.tres")]

static func wood(tint: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = preload("res://assets/generated/timber_albedo.png")
	mat.albedo_color = tint
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.roughness = 0.96
	mat.uv1_scale = Vector3(0.3, 1.0, 1.0)
	return mat

static func plain(tint: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = tint
	mat.roughness = 0.92
	return mat

static func segment(parent: Node3D, a: Vector3, b: Vector3, radius: float, tip: float, mat: Material) -> MeshInstance3D:
	var shape := CylinderMesh.new()
	shape.bottom_radius = radius
	shape.top_radius = tip
	shape.height = a.distance_to(b)
	shape.radial_segments = 7
	var visual := MeshInstance3D.new()
	visual.mesh = shape
	visual.material_override = mat
	visual.position = (a + b) * 0.5
	visual.quaternion = Quaternion(Vector3.UP, (b - a).normalized())
	parent.add_child(visual)
	return visual

static func signpost(parent: Node3D, at: Vector3) -> Node3D:
	var sign := Node3D.new()
	sign.name = "RoadSign"
	sign.position = at
	parent.add_child(sign)
	var timber := wood(Color("b5a28a"))
	var bark := wood(Color("706052"))
	var iron := plain(Color("414849"))
	iron.metallic = 0.65
	segment(sign, Vector3(0, 0.03, 0), Vector3(0, 1.62, 0), 0.105, 0.075, bark)
	# Solid chipped arrow silhouettes; both faces carry the same route label.
	for row: int in range(2):
		var board := Node3D.new()
		board.name = "ArrowBoard%d" % row
		board.position = Vector3(0.06 if row == 0 else -0.1, 1.31 - row * 0.43, 0)
		board.rotation.z = 0.035 if row == 0 else -0.045
		sign.add_child(board)
		var outline := PackedVector2Array([Vector2(-0.73, -0.14), Vector2(-0.76, 0.10), Vector2(-0.46, 0.14), Vector2(0.51, 0.14), Vector2(0.77, 0), Vector2(0.49, -0.15), Vector2(-0.24, -0.13)])
		if row == 1:
			for i: int in range(outline.size()):
				outline[i].x *= -1
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		var indices := Geometry2D.triangulate_polygon(outline)
		for side: float in [-1.0, 1.0]:
			for index: int in indices:
				var p := outline[index]
				surface.set_normal(Vector3(0, 0, side))
				surface.set_uv(Vector2(p.y * 0.8 + 0.5, p.x * 0.7 + 0.5))
				surface.add_vertex(Vector3(p.x, p.y, side * 0.075))
		for i: int in range(outline.size()):
			var a := outline[i]
			var b := outline[(i + 1) % outline.size()]
			for p: Vector3 in [Vector3(a.x, a.y, -0.075), Vector3(b.x, b.y, -0.075), Vector3(b.x, b.y, 0.075), Vector3(a.x, a.y, -0.075), Vector3(b.x, b.y, 0.075), Vector3(a.x, a.y, 0.075)]:
				surface.set_normal(Vector3(b.y - a.y, a.x - b.x, 0).normalized())
				surface.set_uv(Vector2(p.y + 0.5, p.x + 0.5))
				surface.add_vertex(p)
		var plank := MeshInstance3D.new()
		plank.mesh = surface.commit()
		timber.cull_mode = BaseMaterial3D.CULL_DISABLED
		plank.material_override = timber
		board.add_child(plank)
		for side: float in [-1.0, 1.0]:
			var label := Label3D.new()
			label.text = "星灣城" if row == 0 else "暮光村"
			label.font = preload("res://assets/fonts/Cubic_11.ttf")
			label.font_size = 48
			label.pixel_size = 0.0035
			label.outline_size = 0
			label.modulate = Color("e8d8ac")
			label.shaded = true
			label.position = Vector3(-0.1 if row == 0 else 0.1, 0, side * 0.079)
			label.rotation.y = PI if side < 0 else 0.0
			board.add_child(label)
			for x: float in [-0.54, 0.43]:
				Bridge._box(board, Vector3(x, 0, side * 0.08), Vector3(0.035, 0.035, 0.018), iron)
	var rope := plain(Color("ba9e72"))
	for i: int in range(4):
		var loop := TorusMesh.new()
		loop.inner_radius = 0.083
		loop.outer_radius = 0.109
		loop.rings = 8
		loop.ring_segments = 6
		var ring := MeshInstance3D.new()
		ring.mesh = loop
		ring.material_override = rope
		ring.position.y = 0.48 + i * 0.033
		sign.add_child(ring)
	return sign

static func branch(variant: int, bark: Material, heart: Material) -> Node3D:
	var root := Node3D.new()
	var points: Array[Vector3] = [Vector3(-0.55, 0.10, -0.10), Vector3(-0.10, 0.11, 0.05), Vector3(0.34, 0.09, -0.02), Vector3(0.65, 0.065, 0.12)]
	var thickness: float = 0.07 if variant != 2 else 0.15
	for i: int in range(3):
		segment(root, points[i], points[i + 1], thickness * (1.0 - i * 0.22), thickness * (0.8 - i * 0.22), bark)
	if variant != 2:
		segment(root, points[1], Vector3(0.02, 0.065, -0.43), 0.042, 0.008, bark)
		if variant == 1:
			segment(root, points[2], Vector3(0.46, 0.05, 0.45), 0.035, 0.006, bark)
			segment(root, Vector3(0.02, 0.065, -0.43), Vector3(0.24, 0.04, -0.53), 0.012, 0.002, bark)
	else:
		segment(root, points[1], Vector3(-0.02, 0.25, -0.17), 0.07, 0.034, bark)
	# Pale exposed break at the thicker end, with a smaller dark heart ring.
	var direction := (points[0] - points[1]).normalized()
	segment(root, points[0], points[0] + direction * 0.006, thickness * 0.88, thickness * 0.88, heart)
	segment(root, points[0] + direction * 0.007, points[0] + direction * 0.009, thickness * 0.35, thickness * 0.35, bark)
	return root

static func dress(terrain: Node3D, bounds: Rect2) -> void:
	var layer := Node3D.new()
	layer.name = "RoadsideDetails"
	terrain.add_child(layer)
	var rng := RandomNumberGenerator.new()
	rng.seed = 92724
	var bark := wood(Color("8f8271"))
	var heart := plain(Color("c4ac83"))
	var stone := plain(Color("9c9d91"))
	stone.albedo_texture = preload("res://assets/generated/terrain/weathered_stone.png")
	stone.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	# Bake each branch prototype once, then instance the shared surface meshes.
	var prototypes: Array[ArrayMesh] = []
	for variant: int in range(3):
		var source := branch(variant, bark, heart)
		var mesh := ArrayMesh.new()
		for mat: Material in [bark, heart]:
			var surface := SurfaceTool.new()
			surface.begin(Mesh.PRIMITIVE_TRIANGLES)
			for child: Node in source.get_children():
				var visual := child as MeshInstance3D
				if visual.material_override == mat:
					surface.append_from(visual.mesh, 0, visual.transform)
			surface.set_material(mat)
			surface.commit(mesh)
		prototypes.append(mesh)
		source.free()
	var pebble := SphereMesh.new()
	pebble.radius = 1.0
	pebble.height = 2.0
	pebble.radial_segments = 7
	pebble.rings = 3
	var stones: Array[Transform3D] = []
	var occupied: Array[Vector2] = []
	for i: int in range(1500):
		var at := Vector2(rng.randf_range(bounds.position.x + 2, bounds.end.x - 2), rng.randf_range(bounds.position.y + 2, bounds.end.y - 2))
		var distance: float = terrain.road_distance(at)
		if distance < 0.45 or distance > 2.6 or terrain.outside_distance(at) > 0:
			continue
		if terrain.map_id == "east_road" and (absf(at.y + 5) < 2.4 or at.distance_to(Vector2(-6, 2)) < 1.2 or Rect2(-2, 6.5, 13, 8).has_point(at)):
			continue
		if terrain.map_id == "firefly_forest" and at.distance_to(Vector2(10, 4)) < 5.2:
			continue
		var close := false
		for previous: Vector2 in occupied:
			if previous.distance_to(at) < 1.1:
				close = true
		if close:
			continue
		var h: float = terrain.soil_height(at)
		if absf(terrain.soil_height(at + Vector2(0.65, 0)) - h) > 0.20 or absf(terrain.soil_height(at + Vector2(0, 0.65)) - h) > 0.20:
			continue
		occupied.append(at)
		var kind: int = occupied.size() % 3
		if kind == 0:
			var visual := MeshInstance3D.new()
			visual.name = "FallenWood%d" % occupied.size()
			visual.mesh = prototypes[(occupied.size() / 3) % 3]
			visual.position = Vector3(at.x, h + 0.012, at.y)
			var normal := Vector3(terrain.soil_height(at - Vector2(0.3, 0)) - terrain.soil_height(at + Vector2(0.3, 0)), 0.6, terrain.soil_height(at - Vector2(0, 0.3)) - terrain.soil_height(at + Vector2(0, 0.3))).normalized()
			visual.basis = Basis(Quaternion(Vector3.UP, normal)) * Basis(Vector3.UP, rng.randf() * TAU)
			layer.add_child(visual)
		elif kind == 1:
			for j: int in range(7):
				var p := at + Vector2(rng.randf_range(-0.36, 0.36), rng.randf_range(-0.3, 0.3))
				var size := rng.randf_range(0.035, 0.13)
				stones.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled_local(Vector3(size, size * 0.5, size * rng.randf_range(0.7, 1.5))), Vector3(p.x, terrain.soil_height(p) + size * 0.22, p.y)))
		else:
			var sprite := Sprite3D.new()
			var variant: int = (occupied.size() / 3) % 3
			sprite.name = "VergeGrass%d" % occupied.size()
			sprite.texture = GRASSES[variant]
			sprite.pixel_size = rng.randf_range(0.55, 0.85) / sprite.texture.get_width()
			sprite.position = Vector3(at.x, h + sprite.texture.get_height() * sprite.pixel_size * 0.46, at.y)
			sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
			sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
			sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
			sprite.shaded = true
			sprite.modulate = Color("adb58a") if variant == 2 else Color("a3b59c")
			layer.add_child(sprite)
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.mesh = pebble
	batch.instance_count = stones.size()
	for i: int in range(stones.size()):
		batch.set_instance_transform(i, stones[i])
	var gravel := MultiMeshInstance3D.new()
	gravel.name = "PebbleClusters"
	gravel.multimesh = batch
	gravel.material_override = stone
	layer.add_child(gravel)
