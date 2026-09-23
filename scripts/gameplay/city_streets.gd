extends RefCounted
## Shared street edges and doorway approaches for the scene and map.
const Houses = preload("res://scripts/gameplay/city_house_catalog.gd")
const Terrain = preload("res://scripts/gameplay/field_terrain.gd")
const MARKET := [Vector2(-14, 7), Vector2(-11.5, 5.7), Vector2(-2, 5.7), Vector2(2, 8.5), Vector2(2, 12.8), Vector2(-2, 16.4), Vector2(-8, 16.4), Vector2(-14, 13)]

static var _approach_cache: Dictionary = {}

static func approach(index: int, streets: Array) -> PackedVector2Array:
	if _approach_cache.has(index):
		return _approach_cache[index]
	var house: Vector3 = Houses.POSITIONS[index]
	var basis := Basis(Vector3.UP, house.z)
	var door: Vector3 = Vector3(house.x, 0, house.y) + basis * Vector3(0, 0, -3.28)
	var start := Vector2(door.x, door.z)
	var best := start
	var distance: float = INF
	for street: PackedVector2Array in streets:
		for point: Vector2 in street:
			var d: float = start.distance_squared_to(point)
			if d < distance and clear_approach(start, point):
				distance = d
				best = point
	var result := PackedVector2Array([start, best])
	_approach_cache[index] = result
	return result

static func clear_approach(a: Vector2, b: Vector2) -> bool:
	# Avoid cutting across any building, including the back of the source house.
	for home: Vector3 in Houses.POSITIONS:
		var basis := Basis(Vector3.UP, -home.z)
		var local_a: Vector3 = basis * Vector3(a.x - home.x, 0, a.y - home.y)
		var local_b: Vector3 = basis * Vector3(b.x - home.x, 0, b.y - home.y)
		var rectangle := Rect2(-2.8, -2.45, 5.6, 4.9)
		for step: int in range(ceili(a.distance_to(b) / 0.3) + 1):
			var p := local_a.lerp(local_b, float(step) / maxf(1, ceili(a.distance_to(b) / 0.3)))
			if rectangle.has_point(Vector2(p.x, p.z)):
				return false
	# Keep the pond and civic centers clear.
	for obstacle: Vector3 in [Vector3(12, 4, 3.5), Vector3(-18, 10, 1.8), Vector3(-9, -9, 2.2), Vector3(-3, 17, 1.8), Vector3(-1.5, 16, 1.9), Vector3(2, 16, 1.9), Vector3(-1, 17, 0.9)]:
		if Geometry2D.get_closest_point_to_segment(Vector2(obstacle.x, obstacle.y), a, b).distance_to(Vector2(obstacle.x, obstacle.y)) < obstacle.z:
			return false
	return true

static func border(world: Node3D, polygon: PackedVector2Array) -> void:
	var surface := Terrain._surface()
	for expanded: PackedVector2Array in Geometry2D.offset_polygon(polygon, 0.25, Geometry2D.JOIN_ROUND):
		var indices := Geometry2D.triangulate_polygon(expanded)
		for i: int in range(0, indices.size(), 3):
			var a: Vector2 = expanded[indices[i]]
			var b: Vector2 = expanded[indices[i + 1]]
			var c: Vector2 = expanded[indices[i + 2]]
			Terrain._triangle(surface, Vector3(a.x, 0.011, a.y), Vector3(b.x, 0.011, b.y), Vector3(c.x, 0.011, c.y), Vector3.UP)
	Terrain._finish(world.get("_map_root"), "StreetStoneShoulder", surface, Terrain._material(Terrain.STONE, Color("727d7b")))

static func build_approaches(world: Node3D, geography: GDScript) -> void:
	var streets: Array = []
	for street: Array in geography.STREETS:
		streets.append(geography.curve(street))
	for index: int in range(Houses.POSITIONS.size()):
		var points := approach(index, streets)
		if points[0].distance_to(points[1]) < 0.1:
			continue
		var polygon: PackedVector2Array = geography.ribbon(points, 1.55)
		border(world, polygon)
		geography.surface(world, "DoorLane%d" % index, polygon, 0.027, true)
		var home: Vector3 = Houses.POSITIONS[index]
		var basis := Basis(Vector3.UP, home.z)
		var apron := PackedVector2Array()
		for local: Vector2 in [Vector2(-2.65, -2.05), Vector2(2.65, -2.05), Vector2(2.65, -3.8), Vector2(-2.65, -3.8)]:
			var point: Vector3 = Vector3(home.x, 0, home.y) + basis * Vector3(local.x, 0, local.y)
			apron.append(Vector2(point.x, point.z))
		border(world, apron)
		geography.surface(world, "DoorApron%d" % index, apron, 0.028, true)
		# Planted corners frame the door without blocking the threshold.
		for side: float in [-1, 1]:
			var at: Vector3 = Vector3(home.x, 0.035, home.y) + basis * Vector3(side * 2.85, 0, -1.65)
			world._add_flower_clump(at, "ivory" if index % 3 == 0 else "blue")
			Terrain._grass(world.get("_map_root"), at, 1.8, true)
		# Long, low planted beds tie each facade into its plot.
		for side: float in [-1, 1]:
			for step: int in range(4):
				var at: Vector3 = Vector3(home.x, 0.035, home.y) + basis * Vector3(side * 2.85, 0, -0.9 + step * 0.75)
				Terrain._grass(world.get("_map_root"), at, 2.0, true)
				if step % 2 == 0:
					world._add_flower_clump(at, "ivory" if index % 2 == 0 else "blue")

static func landscape(world: Node3D, geography: GDScript) -> void:
	var parent: Node3D = world.get("_map_root")
	var perimeter: PackedVector2Array = geography.outline("starbay")
	var rock := Terrain._surface()
	var moss := Terrain._surface()
	var terrain: GDScript = preload("res://scripts/gameplay/mountain_landscape.gd")
	var rng := RandomNumberGenerator.new()
	rng.seed = 92371
	for i: int in range(perimeter.size()):
		var a: Vector2 = perimeter[i]
		var b: Vector2 = perimeter[(i + 1) % perimeter.size()]
		var outward := Vector2((b - a).y, -(b - a).x).normalized()
		# Polygon winding is clockwise in the map's x/z coordinates.
		if Geometry2D.is_point_in_polygon((a + b) * 0.5 + outward, perimeter):
			outward = -outward
		var count: int = ceili(a.distance_to(b) / 1.7)
		for step: int in range(count):
			var p: Vector2 = a.lerp(b, float(step) / count)
			var q: Vector2 = a.lerp(b, float(step + 1) / count)
			for layer: int in range(3):
				var upper: float = -layer * 2.0
				var lower: float = -(layer + 1) * 2.0
				# A shared radial expansion keeps corners watertight.
				var center := Vector2(-3, 0)
				var pa := (p - center).normalized()
				var qa := (q - center).normalized()
				var u := pa * layer * 0.9
				var v := pa * (layer + 1) * 0.9
				var uq := qa * layer * 0.9
				var vq := qa * (layer + 1) * 0.9
				terrain.face(rock, moss, Vector3(p.x + u.x, upper, p.y + u.y), Vector3(p.x + v.x, lower, p.y + v.y), Vector3(q.x + vq.x, lower, q.y + vq.y))
				terrain.face(rock, moss, Vector3(p.x + u.x, upper, p.y + u.y), Vector3(q.x + vq.x, lower, q.y + vq.y), Vector3(q.x + uq.x, upper, q.y + uq.y))
			if step % 2 == 1:
				var at := Vector3(p.x + outward.x * 2, -3, p.y + outward.y * 2)
				terrain.crag(rock, moss, at - Vector3.UP * 1.4, Vector3(rng.randf_range(1.6, 3.0), rng.randf_range(2.6, 4.0), 2.3), rng)
				# Gate throat stays visually open; trees dress the lower outer shelf.
				if p.y < 31 or p.x < -24 or p.x > -8:
					world._add_tree(at - Vector3.UP * 0.8)
					var tree: Node3D = parent.get_child(-1)
					tree.scale *= 1.4
					(tree.get_node("TreeArt") as Sprite3D).texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	Terrain._finish(parent, "StarbayCliffFooting", rock, terrain.material(terrain.ROCK, Color("7c8b88")))
	Terrain._finish(parent, "StarbayMossFooting", moss, terrain.material(Terrain.GRASS, Color("7d8c71")))
	var streets: Array = []
	for street: Array in geography.STREETS:
		streets.append(geography.curve(street))
	for link: Array in geography.Civic.LINKS:
		streets.append(geography.curve(link))
	for index: int in range(Houses.POSITIONS.size()):
		streets.append(approach(index, streets.slice(0, geography.STREETS.size())))
	for index: int in range(760):
		var at := Vector2(rng.randf_range(-35, 31), rng.randf_range(-33, 30))
		if not Geometry2D.is_point_in_polygon(at, perimeter) or not garden_space(at, streets, geography):
			continue
		for clump: int in range(3):
			var pos := Vector3(at.x + rng.randf_range(-0.5, 0.5), 0.04, at.y + rng.randf_range(-0.5, 0.5))
			Terrain._grass(parent, pos, rng.randf_range(1.6, 2.2), true)
			if clump == 0:
				world._add_flower_clump(pos, "ivory" if index % 3 == 0 else "blue")
		if index % 4 == 0 and spacious_plot(at, streets):
			garden_bed(world, at, index)
		if index % 13 == 0:
			world._add_tree(Vector3(at.x, 0, at.y))

static func garden_space(at: Vector2, streets: Array, geography: GDScript) -> bool:
	for home: Vector3 in Houses.POSITIONS:
		if at.distance_to(Vector2(home.x, home.y)) < 3.25:
			return false
	for street: PackedVector2Array in streets:
		for i: int in range(street.size() - 1):
			if Geometry2D.get_closest_point_to_segment(at, street[i], street[i + 1]).distance_to(at) < 2.3:
				return false
	if Rect2(-15, 4.2, 19, 15.3).has_point(at):
		return false
	for obstacle: Vector3 in [Vector3(-8, -27, 7.5), Vector3(12, 4, 7), Vector3(-18, 10, 5), Vector3(-9, -9, 5), Vector3(8, 0, 3)]:
		if at.distance_to(Vector2(obstacle.x, obstacle.y)) < obstacle.z:
			return false
	for pocket: Vector2 in geography.Civic.POCKETS:
		if at.distance_to(pocket) < 3:
			return false
	return true

static func garden_bed(world: Node3D, at: Vector2, index: int) -> void:
	var civic: GDScript = preload("res://scripts/gameplay/city_civic.gd")
	var parent: Node3D = world.get("_map_root")
	var wood: StandardMaterial3D = civic.material("timber_albedo.png", Color("9e8a6e"))
	var soil := Terrain._material(Terrain.SOIL, Color("60594a"))
	soil.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	var center := Vector3(at.x, 0.10, at.y)
	civic.box(parent, "CourtyardSoil", center, Vector3(2.1, 0.16, 1.35), soil)
	for side: float in [-1, 1]:
		civic.box(parent, "GardenTimberEdge", center + Vector3(side * 1.1, 0.03, 0), Vector3(0.12, 0.22, 1.55), wood)
		civic.box(parent, "GardenTimberEdge", center + Vector3(0, 0.03, side * 0.74), Vector3(2.3, 0.22, 0.12), wood)
	for i: int in range(6):
		var pos := center + Vector3(-0.75 + (i % 3) * 0.75, 0.10, -0.35 + floorf(float(i) / 3.0) * 0.7)
		Terrain._grass(parent, pos, 1.8, true)
		if i % 2 == 0:
			world._add_flower_clump(pos, "ivory" if index % 2 == 0 else "mauve")

static func spacious_plot(at: Vector2, streets: Array) -> bool:
	for home: Vector3 in Houses.POSITIONS:
		if at.distance_to(Vector2(home.x, home.y)) < 4.6:
			return false
	for street: PackedVector2Array in streets:
		for i: int in range(street.size() - 1):
			if Geometry2D.get_closest_point_to_segment(at, street[i], street[i + 1]).distance_to(at) < 3.0:
				return false
	return true
