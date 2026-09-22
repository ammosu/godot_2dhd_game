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

static func _slab(surface: SurfaceTool, at: Vector3, size: Vector3, yaw: float, tint: Color, rng: RandomNumberGenerator) -> void:
	var outline: Array[Vector2] = [Vector2(-0.38,-0.5), Vector2(0.34,-0.5), Vector2(0.5,-0.32), Vector2(0.5,0.33), Vector2(0.33,0.5), Vector2(-0.35,0.5), Vector2(-0.5,0.31), Vector2(-0.5,-0.30)]
	var top: Array[Vector3] = []
	var bottom: Array[Vector3] = []
	for point: Vector2 in outline:
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
	# Solid earth underneath the separate worn treads; no dark rectangular paving ramp.
	for z: float in [9, 12]:
		var normal := Vector3(0, 0, -1 if z == 9 else 1)
		_triangle(foundation, Vector3(1, 0.01, z), Vector3(6, HEIGHT-0.13, z), Vector3(6, 0.01, z), normal)
	_finish(parent, "StairEarthFoundation", foundation, _material(CLIFF, Color("b5a085")))
	for step: int in range(16):
		var x: float = 1.0 + (step + 0.5) * 5.0 / 16.0
		var height: float = (step + 0.5) * HEIGHT / 16.0
		for column: int in range(3):
			var z: float = 9.5 + column + rng.randf_range(-0.03, 0.03)
			_slab(slabs, Vector3(x, height - 0.17, z), Vector3(0.34, 0.17, rng.randf_range(0.95, 1.04)), rng.randf_range(-0.018, 0.018), Color.WHITE.lerp(Color("b6ac94"), rng.randf_range(0.0, 0.30)), rng)
	# Sparse broken slabs continue the route into grass at both ends.
	for index: int in range(8):
		var high: bool = index >= 4
		var x: float = 6.25 + (index-4)*0.65 if high else -0.6 + index*0.43
		var z: float = 10.5 + rng.randf_range(-0.38, 0.38)
		_slab(slabs, Vector3(x, HEIGHT-0.008 if high else 0.002, z), Vector3(rng.randf_range(0.34,0.55), 0.025, rng.randf_range(0.45,0.85)), rng.randf_range(-0.4,0.4), Color("c1baa6"), rng)
	_finish(parent, "WornStoneTreads", slabs, _material(STONE, Color("b0a38a")))

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
	# Low tufts on the stair shoulders; never cover the central treads.
	for index: int in range(16):
		var x: float = 1.1 + index * 0.3
		for z: float in [9.08, 11.93]:
			if rng.randf() < 0.62:
				_grass(parent, Vector3(x, (x-1)*HEIGHT/5, z), rng.randf_range(0.23,0.42))
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
