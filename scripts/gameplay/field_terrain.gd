extends RefCounted
## Natural cliff dressing over the proven platform + smooth stair collision.
## Steps are shallow visual treads; height deviation from the walk plane is < 7 cm.
const HEIGHT: float = 1.8
const CLIFF: Texture2D = preload("res://assets/generated/terrain/stratified_moss_cliff.png")
const STONE: Texture2D = preload("res://assets/generated/terrain/worn_sandstone.png")
const GRASS: Texture2D = preload("res://assets/generated/meadow_albedo.png")
const SOIL: Texture2D = preload("res://assets/generated/terrain/trampled_gravel.png")
const SEED: int = 92261

static func build(parent: Node3D) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	_collision(parent)
	_cliff(parent, rng)
	_stairs(parent, rng)
	_dressing(parent, rng)
	_naturalize_bank(parent)

static func _collision(parent: Node3D) -> void:
	var platform := StaticBody3D.new()
	platform.name = "OldRoadTerrace"
	platform.position = Vector3(9, HEIGHT * 0.5, 10.5)
	parent.add_child(platform)
	var shape := BoxShape3D.new()
	shape.size = Vector3(6, HEIGHT, 5)
	var collider := CollisionShape3D.new()
	collider.shape = shape
	platform.add_child(collider)
	var ramp := StaticBody3D.new()
	ramp.name = "TerraceRamp"
	parent.add_child(ramp)
	var wedge := ConvexPolygonShape3D.new()
	wedge.points = PackedVector3Array([Vector3(1, 0, 9), Vector3(1, 0, 12), Vector3(6, 0, 9), Vector3(6, 0, 12), Vector3(6, HEIGHT, 9), Vector3(6, HEIGHT, 12)])
	var ramp_shape := CollisionShape3D.new()
	ramp_shape.shape = wedge
	ramp.add_child(ramp_shape)

static func _material(texture: Texture2D, tint: Color = Color.WHITE) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_texture = texture
	material.albedo_color = tint
	material.vertex_color_use_as_albedo = true
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	material.roughness = 1.0
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material

static func _surface() -> SurfaceTool:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	return surface

static func _finish(parent: Node3D, title: String, surface: SurfaceTool, material: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = title
	node.mesh = surface.commit()
	node.material_override = material
	parent.add_child(node)
	return node

static func _triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, normal: Vector3, tint: Color = Color.WHITE) -> void:
	# Keep Godot clockwise winding consistent with the outward shading normal.
	# Otherwise double-sided materials reverse lighting on half the cliff faces.
	var points: Array[Vector3] = [a, b, c]
	if (c-a).cross(b-a).dot(normal) < 0:
		points.reverse()
	for vertex: Vector3 in points:
		surface.set_normal(normal)
		surface.set_color(tint)
		var uv: Vector2 = Vector2(vertex.x, vertex.z) * 0.7
		if absf(normal.y) < 0.5:
			uv = Vector2(vertex.z if absf(normal.x) > 0.5 else vertex.x, -vertex.y) * Vector2(0.30, 0.46)
		surface.set_uv(uv)
		surface.add_vertex(vertex)

static func _cliff(parent: Node3D, rng: RandomNumberGenerator) -> void:
	var outline: Array[Vector3] = []
	for side: int in range(4):
		var count: int = 12 if side % 2 == 0 else 10
		for index: int in range(count):
			var t: float = float(index) / count
			match side:
				0: outline.append(Vector3(6 + t*6, 0, 8))
				1: outline.append(Vector3(12, 0, 8 + t*5))
				2: outline.append(Vector3(12 - t*6, 0, 13))
				3: outline.append(Vector3(6, 0, 13 - t*5))
	var walls := _surface()
	var cap := _surface()
	var previous: Array[Vector3] = []
	for layer: int in range(6):
		var y: float = [0.0, 0.38, 0.79, 1.13, 1.53, HEIGHT][layer]
		var ring: Array[Vector3] = []
		for index: int in range(outline.size()):
			var point: Vector3 = outline[index]
			var outward := ((point - Vector3(9, 0, 10.5)) * Vector3(1, 0, 1)).normalized()
			var amount: float = rng.randf_range(0.015, 0.16) if layer < 5 else rng.randf_range(0.0, 0.08)
			# The west stair landing remains flush with the traversable plane.
			if point.x == 6 and point.z > 8.7 and point.z < 12.3:
				amount = 0.0
			point += outward * amount
			point.y = y + (rng.randf_range(-0.07, 0.07) if layer in [1, 2, 3, 4] else 0.0)
			ring.append(point)
		if not previous.is_empty():
			for index: int in range(outline.size()):
				var next: int = (index + 1) % outline.size()
				var tangent := ring[next] - ring[index]
				var normal := Vector3(tangent.z, 0, -tangent.x).normalized()
				var tint := Color("8c785f") if layer == 5 else Color.WHITE.lerp(Color("b5a28b"), rng.randf_range(0.0, 0.25))
				_triangle(walls, previous[index], ring[index], ring[next], normal, tint)
				_triangle(walls, previous[index], ring[next], previous[next], normal, tint)
		previous = ring
	for index: int in range(previous.size()):
		_triangle(cap, Vector3(9, HEIGHT, 10.5), previous[index], previous[(index + 1) % previous.size()], Vector3.UP)
	_finish(parent, "LayeredMossCliff", walls, _material(CLIFF))
	var turf := ShaderMaterial.new()
	turf.shader = preload("res://shaders/field_turf.gdshader")
	turf.set_shader_parameter("grass_texture", GRASS)
	turf.set_shader_parameter("soil_texture", SOIL)
	_finish(parent, "BrokenTurfEdge", cap, turf)

static func _slab(surface: SurfaceTool, at: Vector3, size: Vector3, yaw: float, tint: Color, rng: RandomNumberGenerator, corner_wear: float = 1.0) -> void:
	var outline: Array[Vector2] = [Vector2(-0.38,-0.5), Vector2(0.34,-0.5), Vector2(0.5,-0.32), Vector2(0.5,0.33), Vector2(0.33,0.5), Vector2(-0.35,0.5), Vector2(-0.5,0.31), Vector2(-0.5,-0.30)]
	var top: Array[Vector3] = []
	var bottom: Array[Vector3] = []
	for point: Vector2 in outline:
		point = Vector2(signf(point.x), signf(point.y)) * 0.5 * (1.0 - corner_wear) + point * corner_wear
		var vertex := Vector3(point.x * size.x, 0, point.y * size.z).rotated(Vector3.UP, yaw)
		top.append(at + vertex + Vector3.UP * (size.y + rng.randf_range(-0.009, 0.009)))
		bottom.append(at + vertex * 1.025)
	for index: int in range(outline.size()):
		var next: int = (index + 1) % outline.size()
		_triangle(surface, at + Vector3.UP * size.y, top[index], top[next], Vector3.UP, tint)
		var normal := ((top[index] + top[next]) * 0.5 - at) * Vector3(1, 0, 1)
		normal = normal.normalized()
		_triangle(surface, bottom[index], top[index], top[next], normal, tint.darkened(0.12))
		_triangle(surface, bottom[index], top[next], bottom[next], normal, tint.darkened(0.12))

static func _stairs(parent: Node3D, rng: RandomNumberGenerator) -> void:
	var slabs := _surface()
	var foundation := _surface()
	var moss := _surface()
	# Continuous packed earth fills the old open joints. The central surface
	# follows the original collision wedge, recessed below the worn stone noses.
	var previous: Array[Vector3] = []
	for row: int in range(21):
		var x: float = 1.0 + row * 0.25
		var h: float = (x - 1.0) * HEIGHT / 5.0
		var edge: float = sin(x * 2.7) * 0.045
		var ring: Array[Vector3] = [
			Vector3(x, 0.005, 8.91 + edge),
			Vector3(x, maxf(0.008, h - 0.12), 9.02 + edge),
			Vector3(x, maxf(0.008, h - 0.018), 9.43 + edge),
			Vector3(x, maxf(0.008, h - 0.035), 10.5),
			Vector3(x, maxf(0.008, h - 0.018), 11.59 + edge),
			Vector3(x, maxf(0.008, h - 0.12), 11.98 + edge),
			Vector3(x, 0.005, 12.09 + edge),
		]
		if not previous.is_empty():
			for band: int in range(ring.size() - 1):
				var normal := (previous[band + 1] - previous[band]).cross(ring[band] - previous[band]).normalized()
				var surface: SurfaceTool = moss if band in [1, 4] else foundation
				_triangle(surface, previous[band], ring[band], ring[band + 1], normal)
				_triangle(surface, previous[band], ring[band + 1], previous[band + 1], normal)
		previous = ring
	_finish(parent, "StairEarthFoundation", foundation, _material(SOIL, Color("a79a7f")))
	_finish(parent, "StairMossShoulders", moss, _material(GRASS, Color("89916b")))
	# Unequal stone lengths and offset seams break the former three-column grid.
	# Keep the rise shallow so visible feet stay close to the smooth walk plane.
	for step: int in range(16):
		var x: float = 1.0 + (step + 0.5) * 5.0 / 16.0
		var height: float = (step + 0.5) * HEIGHT / 16.0
		var half_width: float = 1.08 + sin(step * 1.71) * 0.10
		var center: float = 10.5 + sin(step * 0.8) * 0.09
		var cursor: float = center - half_width
		var count: int = 2 if step % 3 != 1 else 3
		for column: int in range(count):
			var remaining: float = center + half_width - cursor
			var width: float = remaining if column == count - 1 else remaining / (count - column) * rng.randf_range(0.72, 1.22)
			var depth: float = rng.randf_range(0.29, 0.33)
			var top: float = height + rng.randf_range(-0.006, 0.006)
			_slab(slabs, Vector3(x, top - 0.11, cursor + width * 0.5), Vector3(depth, 0.11, width - 0.018), rng.randf_range(-0.022, 0.022), Color.WHITE.lerp(Color("c2bba7"), rng.randf_range(0.05, 0.26)), rng, 0.3)
			cursor += width
		# Partly buried fragments and grass dissolve the stair edges into the bank.
		for side: float in [-1.0, 1.0]:
			var z: float = center + side * (half_width + 0.13)
			if step % 3 != 0:
				_slab(slabs, Vector3(x, height - 0.07, z), Vector3(0.24, 0.055, rng.randf_range(0.16, 0.27)), rng.randf_range(-0.3, 0.3), Color("92977f"), rng)
			if rng.randf() < 0.6:
				_grass(parent, Vector3(x, maxf(0.01, height - 0.025), z), rng.randf_range(0.26, 0.46), step % 4 == 0)
	# Uneven rock outcrops interrupt the soil cut, without extending walkable tops.
	for side: float in [-1.0, 1.0]:
		for i: int in range(13):
			var x: float = 1.4 + i * 0.35 + rng.randf_range(-0.09, 0.09)
			var h: float = (x - 1.0) * HEIGHT / 5.0
			var z: float = 10.5 + side * rng.randf_range(1.44, 1.55)
			var y: float = h * rng.randf_range(0.1, 0.6)
			_slab(slabs, Vector3(x, y, z), Vector3(rng.randf_range(0.32, 0.65), rng.randf_range(0.13, 0.28), 0.20), rng.randf_range(-0.4, 0.4), Color("a09b85"), rng)
			if i % 3 == 0:
				_grass(parent, Vector3(x, 0.015, z + side * 0.1), rng.randf_range(0.34, 0.55), true)
	# Treads become scattered, buried stepping stones at the foot and landing.
	for index: int in range(14):
		var high: bool = index >= 7
		var x: float = 6.17 + (index - 7) * 0.31 if high else -0.9 + index * 0.27
		var z: float = 10.5 + rng.randf_range(-0.55, 0.55)
		_slab(slabs, Vector3(x, HEIGHT - 0.012 if high else 0.002, z), Vector3(rng.randf_range(0.28, 0.49), 0.028, rng.randf_range(0.32, 0.66)), rng.randf_range(-0.35, 0.35), Color("bdb49b"), rng)
	_finish(parent, "WornStoneTreads", slabs, _material(STONE, Color("b8ac94")))

static func _grass(parent: Node3D, at: Vector3, size: float, fan: bool = false) -> void:
	var sprite := Sprite3D.new()
	sprite.name = "CliffGrass"
	sprite.texture = preload("res://assets/generated/grass_fan.tres") if fan else preload("res://assets/generated/grass_low.tres")
	sprite.pixel_size = size / 704.0
	sprite.position = at + Vector3.UP * 328.0 * sprite.pixel_size
	sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.shaded = true
	sprite.modulate = Color("b2bc8c")
	sprite.flip_h = sin(at.x * 7.1 + at.z) > 0
	parent.add_child(sprite)

static func _dressing(parent: Node3D, rng: RandomNumberGenerator) -> void:
	var rubble := _surface()
	# Collapsed fragments hug the cliff foot, away from the ramp and combat lanes.
	for index: int in range(50):
		var side: int = index % 3
		var at := Vector3(rng.randf_range(6.3, 11.7), 0.015, 7.78 if side == 0 else 13.22)
		if side == 2:
			at = Vector3(12.22, 0.015, rng.randf_range(8.2, 12.8))
		var size: float = rng.randf_range(0.10, 0.37)
		_slab(rubble, at, Vector3(size, size * 0.55, size * 0.8), rng.randf_range(-PI, PI), Color("b4ab90"), rng)
		if index % 4 == 0:
			_grass(parent, at + Vector3(0.04,0,0.06), rng.randf_range(0.45,0.7), true)
	# Broken grass lip on the upper perimeter; avoid the central battle area.
	for index: int in range(30):
		var side: int = index % 3
		var at := Vector3(rng.randf_range(6.2,11.7), HEIGHT, 8.12 if side == 0 else 12.82)
		if side == 2:
			at = Vector3(11.78, HEIGHT, rng.randf_range(8.3,12.6))
		_grass(parent, at, rng.randf_range(0.45,0.80), index % 4 == 0)
	for index: int in range(12):
		var at := Vector3(rng.randf_range(6.3,11.7), HEIGHT + 0.002, 8.25 if index % 2 == 0 else 12.65)
		_slab(rubble, at, Vector3(0.24,0.08,0.19), rng.randf_range(-PI,PI), Color("b5b699"), rng)
	_finish(parent, "CliffFootRubble", rubble, _material(STONE))

static func _naturalize_bank(parent: Node3D) -> void:
	# The existing south boundary was a featureless blue box in front of the steps.
	# Reuse its exact collision and add the same rock/turf vocabulary to its surface.
	if parent.get_parent() == null:
		return
	for child: Node in parent.get_parent().get_children():
		if not child is StaticBody3D or child.get_child_count() == 0:
			continue
		if child.position.z < 14.0:
			continue
		var mesh := child.get_child(0) as MeshInstance3D
		if mesh == null or not mesh.mesh is BoxMesh or (mesh.mesh as BoxMesh).size != Vector3(34, 1.5, 1):
			continue
		mesh.hide()
		var bank := _surface()
		var turf := _surface()
		for part: int in range(68):
			var x0: float = -17.0 + part * 0.5
			var x1: float = x0 + 0.5
			var a := Vector3(x0, 1.15, 14.03 + sin(x0 * 4.1) * 0.06)
			var b := Vector3(x1, 1.15, 14.03 + sin(x1 * 4.1) * 0.06)
			_triangle(bank, Vector3(x0, 0, 14), a, b, Vector3.FORWARD)
			_triangle(bank, Vector3(x0, 0, 14), b, Vector3(x1, 0, 14), Vector3.FORWARD)
			_triangle(turf, a, Vector3(x0, 1.15, 15), b, Vector3.UP)
			_triangle(turf, b, Vector3(x0, 1.15, 15), Vector3(x1, 1.15, 15), Vector3.UP)
		_finish(parent, "SouthBankCliff", bank, _material(CLIFF, Color("bcb29a")))
		_finish(parent, "SouthBankTurf", turf, _material(GRASS, Color("949b75")))
		for index: int in range(24):
			_grass(parent, Vector3(-7.0 + index * 0.85, 1.16, 14.18), 0.8, index % 3 == 0)
