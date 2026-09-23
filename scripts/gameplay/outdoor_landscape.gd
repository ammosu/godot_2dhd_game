extends Node3D
## Rolling soil banks fitted to existing roads, exits, water and encounter clearings.
const Terrain = preload("res://scripts/gameplay/field_terrain.gd")
const Mountain = preload("res://scripts/gameplay/mountain_landscape.gd")
const STEP: float = 0.75
var map_id: String
var _route := PackedVector2Array()
var _outline := PackedVector2Array()
var _origin: Vector2
var _grid: Array[PackedVector3Array] = []

func road_distance(at: Vector2) -> float:
	if map_id == "caravan_road":
		var distance: float = INF
		for i: int in range(_route.size() - 1):
			distance = minf(distance, at.distance_to(Geometry2D.get_closest_point_to_segment(at, _route[i], _route[i + 1])))
		return distance - 2.1
	var distance: float = absf(at.x) - 1.8
	if map_id == "east_road":
		distance = minf(distance, box_distance(at, Vector2(-8, 0), Vector2(3.2, 2.8)))
		distance = minf(distance, absf(at.y - 5) - 1.8)
		distance = minf(distance, box_distance(at, Vector2(4, 2), Vector2(3.5, 3.5)))
	else:
		distance = minf(distance, box_distance(at, Vector2(0, -3), Vector2(9, 0.8)))
		distance = minf(distance, box_distance(at, Vector2(7, -5), Vector2(0.8, 2.5)))
		distance = minf(distance, box_distance(at, Vector2(0, -10), Vector2(3, 2.5)))
	return distance

static func box_distance(at: Vector2, center: Vector2, extent: Vector2) -> float:
	var d := (at - center).abs() - extent
	return d.max(Vector2.ZERO).length() + minf(maxf(d.x, d.y), 0)

func height_at(at: Vector2) -> float:
	var distance: float = road_distance(at)
	# Existing bridge, pond, interaction pads and combat terraces keep their grade.
	if map_id == "east_road":
		distance = minf(distance, absf(at.y + 5) - 2.2)
		distance = minf(distance, box_distance(at, Vector2(2.5, 10), Vector2(11.5, 4.5)))
		distance = minf(distance, at.distance_to(Vector2(-6, 2)) - 1.6)
	elif map_id == "firefly_forest":
		distance = minf(distance, at.distance_to(Vector2(10, 4)) - 5.0)
	var away: float = smoothstep(0.35, 4.2, distance)
	var hills: float = 1.55 + sin(at.x * 0.27 + at.y * 0.14) * 0.9 + cos(at.y * 0.31) * 0.65 + sin(at.x * 0.52 - at.y * 0.29) * 0.35
	return 0.002 + away * maxf(0.25, hills) - smoothstep(0, 8, outside_distance(at)) * (3.9 + sin(at.x * 0.21 + at.y * 0.33) * 0.8)

func outside_distance(at: Vector2) -> float:
	if Geometry2D.is_point_in_polygon(at, _outline):
		return 0.0
	var outside: float = INF
	for i: int in range(_outline.size()):
		outside = minf(outside, at.distance_to(Geometry2D.get_closest_point_to_segment(at, _outline[i], _outline[(i + 1) % _outline.size()])))
	return outside

func soil_height(at: Vector2) -> float:
	var cell := ((at - _origin) / STEP).floor()
	var x: int = clampi(int(cell.x), 0, _grid[0].size() - 2)
	var z: int = clampi(int(cell.y), 0, _grid.size() - 2)
	var t := ((at - _origin) / STEP - Vector2(x, z)).clamp(Vector2.ZERO, Vector2.ONE)
	var a: float = _grid[z][x].y
	var c: float = _grid[z + 1][x + 1].y
	if t.y >= t.x:
		return a * (1 - t.y) + _grid[z + 1][x].y * (t.y - t.x) + c * t.x
	return a * (1 - t.x) + _grid[z][x + 1].y * (t.x - t.y) + c * t.y

func configure(world: Node3D, id: String) -> void:
	map_id = id
	var geography: GDScript = load("res://scripts/gameplay/starbay.gd")
	_outline = geography.outline(id) if id == "caravan_road" else PackedVector2Array([Vector2(-17, -15), Vector2(17, -15), Vector2(17, 15), Vector2(-17, 15)])
	if id == "caravan_road":
		_route = geography.curve(geography.ROAD)
	var bounds := Rect2(_outline[0], Vector2.ZERO)
	for at: Vector2 in _outline:
		bounds = bounds.expand(at)
	bounds = bounds.grow(8)
	_origin = bounds.position
	var count := Vector2i((bounds.size / STEP).ceil()) + Vector2i.ONE
	for z: int in range(count.y):
		var row := PackedVector3Array()
		for x: int in range(count.x):
			var at := _origin + Vector2(x, z) * STEP
			row.append(Vector3(at.x, height_at(at), at.y))
		_grid.append(row)
	var surface := Terrain._surface()
	for z: int in range(count.y - 1):
		for x: int in range(count.x - 1):
			_triangle(surface, _grid[z][x], _grid[z + 1][x], _grid[z + 1][x + 1])
			_triangle(surface, _grid[z][x], _grid[z + 1][x + 1], _grid[z][x + 1])
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/outdoor_landscape.gdshader")
	mat.set_shader_parameter("grass_texture", Terrain.GRASS)
	mat.set_shader_parameter("soil_texture", Terrain.SOIL)
	mat.set_shader_parameter("rock_texture", Mountain.ROCK)
	mat.set_shader_parameter("gravel_texture", preload("res://assets/generated/terrain/weathered_stone.png"))
	var visual := Terrain._finish(self, "RollingRoadTerrain", surface, mat)
	visual.create_trimesh_collision()
	((visual.get_child(0).get_child(0) as CollisionShape3D).shape as ConcavePolygonShape3D).backface_collision = true
	var parent: Node3D = world.get("_map_root")
	for node: Node in parent.get_children():
		if node == self or not node is Node3D:
			continue
		var authored_name := str(node.get_meta("authored_name", node.name))
		if authored_name in ["Ground", "StarbayGround", "WoodlandTrail", "CaravanRoad", "RestStop", "ForagerTrail", "HerbTrail", "MoonClearing", "WindingCaravanRoad"]:
			if node is MeshInstance3D:
				node.visible = false
			elif node.get_child_count() > 0:
				(node.get_child(0) as MeshInstance3D).visible = false
		elif authored_name in ["WoodlandBank", "RoadBank"]:
			(node.get_child(0) as MeshInstance3D).visible = false
			for shape: Node in node.get_children():
				if shape is CollisionShape3D and shape.shape is BoxShape3D:
					shape.shape = shape.shape.duplicate()
					shape.shape.size.y = 8.0
					shape.position.y = 2.0
		elif node is Node3D and str(node.name) != "FieldCombat":
			var at := Vector2(node.position.x, node.position.z)
			if node.has_node("TreeArt"):
				# Place root on the rendered earth; never on decorative crag tops.
				node.position.y = soil_height(at)
				(node.get_node("TreeArt") as Sprite3D).texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
			else:
				node.position.y += soil_height(at)
	_dress(world, bounds)
	_backdrop(bounds.grow(24))

func _triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	var normal := (b - a).cross(c - a).normalized()
	for point: Vector3 in [a, c, b]:
		var at := Vector2(point.x, point.z)
		var breakup: float = sin(at.x * 3.1 + at.y * 1.9) * 0.13
		var road: float = 1.0 - smoothstep(-0.35, 0.55, road_distance(at) + breakup)
		surface.set_normal(normal)
		surface.set_color(Color(road, smoothstep(2.5, 7.5, outside_distance(at)), 0))
		surface.add_vertex(point)

func _dress(world: Node3D, bounds: Rect2) -> void:
	var rock := Terrain._surface()
	var moss := Terrain._surface()
	var rng := RandomNumberGenerator.new()
	rng.seed = 92614
	var roots: Array[Vector2] = []
	var rocks: Array[Vector2] = []
	for tree: Node in get_parent().find_children("TreeArt", "Sprite3D", true, false):
		roots.append(Vector2(tree.get_parent().position.x, tree.get_parent().position.z))
	for i: int in range(620):
		var at := Vector2(rng.randf_range(bounds.position.x + 2, bounds.end.x - 2), rng.randf_range(bounds.position.y + 2, bounds.end.y - 2))
		var distance: float = road_distance(at)
		if distance < 0.9:
			continue
		# Only decorate actual soil hills; leave water and interaction clearings alone.
		var y: float = soil_height(at)
		if y < 0.08 and distance > 2.0 and Geometry2D.is_point_in_polygon(at, _outline):
			continue
		if map_id == "east_road" and absf(at.y + 5) < 1.6:
			continue
		if map_id == "firefly_forest" and at.distance_to(Vector2(10, 4)) < 4.4:
			continue
		var pos := Vector3(at.x, y, at.y)
		var near_root: bool = false
		for root: Vector2 in roots:
			if root.distance_to(at) < 2.7:
				near_root = true
		if i % 3 == 0 and not Geometry2D.is_point_in_polygon(at, _outline):
			var on_rock: bool = false
			for stone: Vector2 in rocks:
				if at.distance_to(stone) < 2.0:
					on_rock = true
			var slope: float = maxf(absf(soil_height(at + Vector2(0.4, 0)) - soil_height(at - Vector2(0.4, 0))), absf(soil_height(at + Vector2(0, 0.4)) - soil_height(at - Vector2(0, 0.4))))
			if not on_rock and not near_root and slope < 0.5:
				var tree := Node3D.new()
				tree.name = "ValleyTree"
				tree.position = pos
				add_child(tree)
				preload("res://scripts/gameplay/tree_variants.gd").decorate(tree, pos, 2 if i % 4 != 0 else 0)
				tree.scale *= rng.randf_range(0.8, 1.3)
				var art := tree.get_node("TreeArt") as Sprite3D
				art.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
				art.modulate = Color("819b9e")
				art.modulate.a = 1.0 - smoothstep(3, 7.5, outside_distance(at))
				art.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
				roots.append(at)
		elif i % 5 == 0 and not near_root and outside_distance(at) < 1.5:
			rocks.append(at)
			Mountain.crag(rock, moss, pos - Vector3.UP * 0.20, Vector3(0.7, rng.randf_range(0.6, 1.3), 0.7), rng)
		elif distance < 5.5 and outside_distance(at) < 1.5:
			Terrain._grass(self, pos, rng.randf_range(1.1, 1.8), true)
			if i % 3 == 0:
				world._add_flower_clump(pos, "ivory")
	# Small, collision-free verge detail follows the worn road edge, not the center.
	for i: int in range(2200):
		var at := Vector2(rng.randf_range(bounds.position.x, bounds.end.x), rng.randf_range(bounds.position.y, bounds.end.y))
		var distance: float = road_distance(at)
		if distance < 0.1 or distance > 2.0 or outside_distance(at) > 0:
			continue
		if map_id == "east_road" and absf(at.y + 5) < 2.2:
			continue
		if map_id == "firefly_forest" and at.distance_to(Vector2(10, 4)) < 5:
			continue
		var pos := Vector3(at.x, soil_height(at), at.y)
		Terrain._grass(self, pos, rng.randf_range(0.25, 0.65), false)
		if i % 4 == 0:
			world._add_flower_clump(pos, "ivory")
		if i % 2 == 0:
			Mountain.crag(rock, moss, pos - Vector3.UP * 0.035, Vector3(0.13, 0.12, 0.16), rng)
	Terrain._finish(self, "RoadsideGranite", rock, Mountain.material(Mountain.ROCK))
	Terrain._finish(self, "RoadsideMoss", moss, Mountain.material(Terrain.GRASS, Color("788b67")))

func _backdrop(bounds: Rect2) -> void:
	# A lower forest basin gives every camera orbit a grounded distant landscape.
	var ground := Terrain._surface()
	var count := Vector2i((bounds.size / 3.0).ceil())
	for z: int in range(count.y):
		for x: int in range(count.x):
			var quad: Array[Vector3] = []
			for offset: Vector2 in [Vector2.ZERO, Vector2(0, 3), Vector2(3, 3), Vector2(3, 0)]:
				var at := bounds.position + Vector2(x, z) * 3.0 + offset
				quad.append(Vector3(at.x, _basin_height(at), at.y))
			for tri: Vector3i in [Vector3i(0, 2, 1), Vector3i(0, 3, 2)]:
				for vertex: int in [tri.x, tri.y, tri.z]:
					var point := Vector2(quad[vertex].x, quad[vertex].z)
					ground.set_normal(Vector3(_basin_height(point - Vector2(0.1, 0)) - _basin_height(point + Vector2(0.1, 0)), 0.2, _basin_height(point - Vector2(0, 0.1)) - _basin_height(point + Vector2(0, 0.1))).normalized())
					ground.set_uv(Vector2(quad[vertex].x, quad[vertex].z) / 7.0)
					ground.add_vertex(quad[vertex])
	var material := Mountain.material(Terrain.GRASS, Color("324d4e"))
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	Terrain._finish(self, "DistantForestFloor", ground, material)
	var rng := RandomNumberGenerator.new()
	rng.seed = 192623
	for i: int in range(1050):
		var at := Vector2(rng.randf_range(bounds.position.x, bounds.end.x), rng.randf_range(bounds.position.y, bounds.end.y))
		var distance: float = outside_distance(at)
		if distance < 5.0:
			continue
		var tree := Node3D.new()
		tree.position = Vector3(at.x, _basin_height(at), at.y)
		add_child(tree)
		preload("res://scripts/gameplay/tree_variants.gd").decorate(tree, tree.position, 2 if i % 5 != 0 else 0)
		tree.scale *= rng.randf_range(0.65, 1.2)
		var art := tree.get_node("TreeArt") as Sprite3D
		art.name = "DistantTreeArt"
		art.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
		art.shaded = false
		art.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		art.modulate = Color("263f40").lerp(Color("354e50"), smoothstep(6, 28, distance))

func _basin_height(at: Vector2) -> float:
	return -10.0 + sin(at.x * 0.09 + sin(at.y * 0.08)) * 2.5 + cos(at.y * 0.13) * 1.8
