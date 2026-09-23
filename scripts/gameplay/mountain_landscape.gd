extends RefCounted
## Continuous mountain mass fitted underneath the authoritative walking spline.
const ROCK: Texture2D = preload("res://assets/generated/terrain/mossy_granite.png")
const Terrain = preload("res://scripts/gameplay/field_terrain.gd")

static func ground(at: Vector2, points: PackedVector3Array) -> float:
	var nearest := points[0]
	var distance: float = INF
	for index: int in range(points.size() - 1):
		var a := Vector2(points[index].x, points[index].z)
		var b := Vector2(points[index + 1].x, points[index + 1].z)
		var t: float = clampf((at - a).dot(b - a) / maxf(a.distance_squared_to(b), 0.0001), 0, 1)
		var d: float = at.distance_squared_to(a.lerp(b, t))
		if d < distance:
			distance = d
			nearest = points[index].lerp(points[index + 1], t)
	var away: float = smoothstep(2.15, 5.5, sqrt(distance))
	var grade: float = points[-1].y / 40.0
	var base: float = (18 - at.y) * grade - 0.7
	var ridges: float = sin(at.x * 0.35 + at.y * 0.16) * 1.2 + sin(at.y * 0.63 - at.x * 0.19) * 0.65
	var shoulder: float = maxf(0, sin(at.x * 0.19 + at.y * 0.11)) * 2.6
	var edge: float = smoothstep(14, 25, absf(at.x)) + smoothstep(23, 31, absf(at.y))
	return lerpf(nearest.y - 0.12, base + ridges + shoulder - edge * 12, away)

static func build(world: Node3D, points: PackedVector3Array, map_id: String) -> void:
	var parent: Node3D = world.get("_map_root")
	var rock := Terrain._surface()
	var moss := Terrain._surface()
	var slope := Terrain._surface()
	var grid: Array[PackedVector3Array] = []
	for z: int in range(77):
		var row := PackedVector3Array()
		for x: int in range(73):
			var at := Vector2(-27 + x * 0.75, -32 + z * 0.75)
			row.append(Vector3(at.x, ground(at, points), at.y))
		grid.append(row)
	for z: int in range(grid.size() - 1):
		for x: int in range(grid[z].size() - 1):
			face(slope, slope, grid[z][x], grid[z + 1][x], grid[z + 1][x + 1])
			face(slope, slope, grid[z][x], grid[z + 1][x + 1], grid[z][x + 1])
	var ground_material := ShaderMaterial.new()
	ground_material.shader = preload("res://shaders/mountain_ground.gdshader")
	ground_material.set_shader_parameter("rock_texture", ROCK)
	ground_material.set_shader_parameter("moss_texture", Terrain.GRASS)
	Terrain._finish(parent, "ContinuousMountainSlope", slope, ground_material)
	var rng := RandomNumberGenerator.new()
	rng.seed = 92418
	var gravel := Terrain._surface()
	# Broken outcrops replace the engineered appearance of bilateral parapets.
	for i: int in range(1, points.size() - 1, 2):
		var tangent := points[i + 1] - points[i - 1]
		var side := Vector3(-tangent.z, 0, tangent.x).normalized()
		if i % 4 == 1:
			for stone: int in range(3):
				var at: Vector3 = points[i] + side * rng.randf_range(-1.25, 1.25)
				at.y += 0.013
				Terrain._slab(gravel, at, Vector3(rng.randf_range(0.12, 0.3), 0.018, rng.randf_range(0.15, 0.34)), rng.randf_range(-PI, PI), Color("b9b19c"), rng)
		for sign_value: float in [-1, 1]:
			var at: Vector3 = points[i] + side * sign_value * 2.55
			at.y -= 0.22
			var uphill: bool = (side * sign_value).z < 0
			crag(rock, moss, at, Vector3(rng.randf_range(0.42, 0.68), rng.randf_range(0.8, 1.5) if uphill else rng.randf_range(0.6, 0.9), 0.65), rng)
			if i % 6 == 1:
				Terrain._grass(parent, at + Vector3.UP * 0.35, 1.25, true)
				if map_id != "wind_gorge" and i % 12 == 1:
					world._add_flower_clump(at + Vector3.UP * 0.25, "ivory")
	# Gather rocks first: no tree may share a rock's footprint, even one generated later.
	var rock_footprints: Array[Vector3] = []
	var saplings: Array[Vector3] = []
	for index: int in range(320):
		var at := Vector2(rng.randf_range(-24, 24), rng.randf_range(-28, 21))
		var distance: float = INF
		for p: Vector3 in points:
			distance = minf(distance, at.distance_to(Vector2(p.x, p.z)))
		if distance < 5.5:
			continue
		var pos := Vector3(at.x, rendered_ground(at, points), at.y)
		if index % 7 == 0:
			var size := Vector3(rng.randf_range(1, 2.6), rng.randf_range(0.8, 2.6), rng.randf_range(1, 2.2))
			crag(rock, moss, pos - Vector3.UP * 0.25, size, rng)
			rock_footprints.append(Vector3(at.x, at.y, maxf(size.x, size.z) * 1.2))
		elif map_id == "moss_steps" or (map_id == "moon_highland" and index % 4 == 0):
			saplings.append(pos)
	for pos: Vector3 in saplings:
		var at := Vector2(pos.x, pos.z)
		var clear: bool = true
		for footprint: Vector3 in rock_footprints:
			if at.distance_to(Vector2(footprint.x, footprint.y)) < footprint.z + 1.0:
				clear = false
		# Prefer soil shelves: roots on steep exposed cliff faces look unsupported.
		var slope_x: float = absf(rendered_ground(at + Vector2(0.4, 0), points) - rendered_ground(at - Vector2(0.4, 0), points))
		var slope_z: float = absf(rendered_ground(at + Vector2(0, 0.4), points) - rendered_ground(at - Vector2(0, 0.4), points))
		if not clear or maxf(slope_x, slope_z) > 0.42:
			continue
		var tree := Node3D.new()
		tree.name = "MountainConifer"
		tree.position = pos
		tree.set_meta("soil_root", pos)
		parent.add_child(tree)
		preload("res://scripts/gameplay/tree_variants.gd").decorate(tree, pos, 2)
		tree.scale *= rng.randf_range(0.85, 1.15)
		var art := tree.get_node("TreeArt") as Sprite3D
		art.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
		art.modulate = Color("c4d4d0")
	Terrain._finish(parent, "TrailEmbeddedStones", gravel, material(Terrain.STONE, Color("b6b2a7")))
	Terrain._finish(parent, "MountainBedrock", rock, material(ROCK, Color("9aa5a1") if map_id == "wind_gorge" else Color("a5ac95")))
	Terrain._finish(parent, "MountainMossShelves", moss, material(Terrain.GRASS, Color("808e70") if map_id != "wind_gorge" else Color("758987")))

static func face(rock: SurfaceTool, moss: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	var normal := (c - a).cross(b - a).normalized()
	if normal.y < 0:
		normal = -normal
	Terrain._triangle(moss if normal.y > 0.68 else rock, a, b, c, normal)

static func crag(rock: SurfaceTool, moss: SurfaceTool, at: Vector3, size: Vector3, rng: RandomNumberGenerator) -> void:
	var rings: Array[PackedVector3Array] = []
	var phase: float = rng.randf_range(0, TAU)
	for layer: int in range(4):
		var ring := PackedVector3Array()
		for corner: int in range(7):
			var angle: float = phase + corner * TAU / 7.0
			var radius: float = [1.0, 1.06, 0.82, 0.56][layer] * rng.randf_range(0.85, 1.12)
			ring.append(at + Vector3(cos(angle) * size.x * radius, size.y * (layer / 3.0 + rng.randf_range(-0.06, 0.06)), sin(angle) * size.z * radius))
		rings.append(ring)
	for layer: int in range(3):
		for corner: int in range(7):
			var next: int = (corner + 1) % 7
			face(rock, moss, rings[layer][corner], rings[layer + 1][corner], rings[layer + 1][next])
			face(rock, moss, rings[layer][corner], rings[layer + 1][next], rings[layer][next])
	for corner: int in range(7):
		face(rock, moss, rings[3][corner], at + Vector3.UP * size.y, rings[3][(corner + 1) % 7])

static func material(texture: Texture2D, tint: Color = Color.WHITE) -> StandardMaterial3D:
	var result := Terrain._material(texture, tint)
	result.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	return result

static func rendered_ground(at: Vector2, points: PackedVector3Array) -> float:
	# Match the actual two triangles in the 0.75 m terrain grid, not a nearby
	# analytical sample that can put a trunk above/below the rendered slope.
	var cell := ((at - Vector2(-27, -32)) / 0.75).floor()
	var origin := Vector2(-27, -32) + cell * 0.75
	var t := (at - origin) / 0.75
	var a: float = ground(origin, points)
	var c: float = ground(origin + Vector2.ONE * 0.75, points)
	if t.y >= t.x:
		var b: float = ground(origin + Vector2(0, 0.75), points)
		return a * (1 - t.y) + b * (t.y - t.x) + c * t.x
	var d: float = ground(origin + Vector2(0.75, 0), points)
	return a * (1 - t.x) + d * (t.x - t.y) + c * t.y
