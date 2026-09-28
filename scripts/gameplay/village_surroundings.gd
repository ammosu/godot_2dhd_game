extends Node3D
## Wooded hills that wrap Twilight Village so its edge reads as a valley floor
## rather than a walled platform. The playable limit stays an invisible wall on
## the hill foot; the north pass and east road stay carved open to the horizon.

const Terrain = preload("res://scripts/gameplay/field_terrain.gd")
const Mountain = preload("res://scripts/gameplay/mountain_landscape.gd")
const Trees = preload("res://scripts/gameplay/tree_variants.gd")
const STEP: float = 1.0
const REACH: float = 30.0
## Hills fade into the night sky here instead of ending at a hard edge.
const FADE_START: float = 19.0
const FADE_END: float = 28.0
const SEED: int = 51903
## Road corridors kept flat through the hills: north pass and east old road.
const CORRIDORS: Array[Array] = [
	[Vector2(0.0, -18.0), Vector2(0.0, -70.0), 1.2],
	[Vector2(21.0, 4.6), Vector2(80.0, 4.6), 1.8],
]
var _outline := PackedVector2Array()


func configure(outline: PackedVector2Array) -> void:
	name = "VillageSurroundings"
	_outline = outline
	var bounds := Rect2(outline[0], Vector2.ZERO)
	for at: Vector2 in outline:
		bounds = bounds.expand(at)
	bounds = bounds.grow(REACH)
	var count := Vector2i((bounds.size / STEP).ceil()) + Vector2i.ONE
	var grid: Array[PackedVector3Array] = []
	for z: int in range(count.y):
		var row := PackedVector3Array()
		for x: int in range(count.x):
			var at := bounds.position + Vector2(x, z) * STEP
			row.append(Vector3(at.x, height_at(at), at.y))
		grid.append(row)
	var surface := Terrain._surface()
	var collision := PackedVector3Array()
	for z: int in range(count.y - 1):
		for x: int in range(count.x - 1):
			for tri: Array in [[grid[z][x], grid[z + 1][x], grid[z + 1][x + 1]], [grid[z][x], grid[z + 1][x + 1], grid[z][x + 1]]]:
				# The village floor covers everything below it; skip hidden cells.
				if tri[0].y < -0.04 and tri[1].y < -0.04 and tri[2].y < -0.04:
					continue
				_triangle(surface, tri[0], tri[1], tri[2])
				# Floor only for the slope inside the limit; road corridors past
				# the gates stay floorless so nothing can be walked onto there.
				if signed_distance(Vector2(tri[0].x, tri[0].z)) < 0.6 and road_distance(Vector2(tri[0].x, tri[0].z)) > 2.0:
					collision.append_array(PackedVector3Array([tri[0], tri[2], tri[1]]))
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/outdoor_landscape.gdshader")
	material.set_shader_parameter("grass_texture", Terrain.GRASS)
	material.set_shader_parameter("soil_texture", Terrain.SOIL)
	material.set_shader_parameter("rock_texture", Mountain.ROCK)
	material.set_shader_parameter("gravel_texture", preload("res://assets/generated/terrain/weathered_stone.png"))
	Terrain._finish(self, "HillTerrain", surface, material)
	# Only the walkable hill foot needs a floor; the boundary wall stops travel.
	var body := StaticBody3D.new()
	body.name = "HillFoot"
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(collision)
	var collider := CollisionShape3D.new()
	collider.shape = shape
	body.add_child(collider)
	add_child(body)
	_forest()


## Negative inside the village outline, positive outside.
func signed_distance(at: Vector2) -> float:
	var nearest: float = INF
	for i: int in range(_outline.size()):
		nearest = minf(nearest, at.distance_to(Geometry2D.get_closest_point_to_segment(at, _outline[i], _outline[(i + 1) % _outline.size()])))
	return -nearest if Geometry2D.is_point_in_polygon(at, _outline) else nearest


func road_distance(at: Vector2) -> float:
	var nearest: float = INF
	for corridor: Array in CORRIDORS:
		nearest = minf(nearest, at.distance_to(Geometry2D.get_closest_point_to_segment(at, corridor[0], corridor[1])) - float(corridor[2]))
	return nearest


func height_at(at: Vector2) -> float:
	var edge: float = signed_distance(at)
	if edge < -1.6:
		return -0.06
	# Starting the rise just inside the wall makes the limit a slope, not a line.
	var rise: float = smoothstep(-1.6, 8.0, edge)
	var hills: float = 2.7 + sin(at.x * 0.23 + at.y * 0.11) * 1.1 + cos(at.y * 0.29 - at.x * 0.07) * 0.8 + sin(at.x * 0.51 - at.y * 0.37) * 0.35
	# The camera looks north: keep the southern rim low so it never hides the hero.
	hills *= lerpf(1.0, 0.5, smoothstep(12.0, 22.0, at.y))
	hills += smoothstep(10.0, REACH, edge) * 2.5
	var open_road: float = smoothstep(0.3, 4.0, road_distance(at))
	return -0.012 + rise * open_road * hills


func _triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	var normal := (b - a).cross(c - a).normalized()
	for point: Vector3 in [a, c, b]:
		var at := Vector2(point.x, point.z)
		var road: float = 1.0 - smoothstep(-0.35, 0.6, road_distance(at) + sin(at.x * 3.1 + at.y * 1.9) * 0.13)
		surface.set_normal(normal)
		surface.set_color(Color(road, smoothstep(FADE_START, FADE_END, signed_distance(at)), 0))
		surface.add_vertex(point)


func _forest() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var placed: Array[Vector2] = []
	var extent := Rect2(_outline[0], Vector2.ZERO)
	for at: Vector2 in _outline:
		extent = extent.expand(at)
	extent = extent.grow(FADE_END)
	for i: int in range(2400):
		var at := Vector2(rng.randf_range(extent.position.x, extent.end.x), rng.randf_range(extent.position.y, extent.end.y))
		var edge: float = signed_distance(at)
		if edge < 0.8 or edge > FADE_END - 1.0 or road_distance(at) < 2.6:
			continue
		# Denser woods further out; the near rim stays open enough to read the slope.
		if rng.randf() > lerpf(0.35, 0.95, smoothstep(1.0, 9.0, edge)):
			continue
		var crowded: bool = false
		for other: Vector2 in placed:
			if other.distance_squared_to(at) < 5.3:
				crowded = true
				break
		if crowded:
			continue
		placed.append(at)
		var tree := Node3D.new()
		tree.name = "HillTree"
		tree.position = Vector3(at.x, height_at(at) - 0.05, at.y)
		add_child(tree)
		# Two species only: village oaks on the rim, spruce taking over the woods.
		var spruce: bool = rng.randf() < smoothstep(2.0, 12.0, edge) * 0.8
		Trees.decorate(tree, tree.position, 2 if spruce else 0)
		tree.scale *= rng.randf_range(0.85, 1.25)
		var art := tree.get_node("TreeArt") as Sprite3D
		art.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
		var depth: float = smoothstep(3.0, 22.0, edge)
		art.modulate = art.modulate * Color.WHITE.lerp(Color("5f7474"), depth)
		art.modulate.a = 1.0 - smoothstep(FADE_START, FADE_END, edge)
		if art.modulate.a < 0.99:
			art.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
		if edge > 6.0:
			art.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		elif edge < 3.0 and i % 2 == 0:
			Terrain._grass(self, Vector3(at.x + 0.9, height_at(at + Vector2(0.9, 0)), at.y + 0.4), rng.randf_range(1.0, 1.6), true)
	# Shrubs and low grass walk the whole outline, hiding where floor meets slope.
	for i: int in range(_outline.size()):
		var start: Vector2 = _outline[i]
		var finish: Vector2 = _outline[(i + 1) % _outline.size()]
		var normal := (finish - start).orthogonal().normalized()
		for step: int in range(int(start.distance_to(finish) / 0.55)):
			var at: Vector2 = start.lerp(finish, (step + rng.randf()) * 0.55 / start.distance_to(finish))
			at += normal * rng.randf_range(-1.2, 1.2)
			if road_distance(at) < 1.0:
				continue
			Terrain._grass(self, Vector3(at.x, maxf(height_at(at), 0.0), at.y), rng.randf_range(0.8, 1.7), step % 3 == 0)


## Seat authored village trees and props beyond the floor on the hill surface.
func ground_outer_props(map_root: Node3D) -> void:
	for node: Node in map_root.get_children():
		if node == self or not node is Node3D or not node.is_in_group("village_trees"):
			continue
		var at := Vector2((node as Node3D).position.x, (node as Node3D).position.z)
		(node as Node3D).position.y = maxf(0.0, height_at(at) - 0.05)
