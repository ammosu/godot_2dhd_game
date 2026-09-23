extends RefCounted
## A continuous, elevated ribbon: one source for collision, scenery, map and walking.
const Terrain = preload("res://scripts/gameplay/field_terrain.gd")
const NAMES := {"moss_steps": "苔階山徑", "wind_gorge": "風切峽道", "moon_highland": "月冠高地"}
const BOUNDS := Rect2(-19, -27, 38, 48)
const LINKS := {
	"moss_steps": ["mountain_to_forest", "mountain_to_gorge"],
	"wind_gorge": ["gorge_to_steps", "gorge_to_highland"],
	"moon_highland": ["highland_to_gorge", ""],
}

static func route(map_id: String) -> PackedVector3Array:
	var controls := PackedVector3Array([
		Vector3(0, 0, 18), Vector3(0, 0, 13), Vector3(-9, 0.7, 10),
		Vector3(-12, 1.3, 6), Vector3(-8, 1.9, 3), Vector3(8, 3.3, 1),
		Vector3(12, 4, -3), Vector3(8, 4.7, -7), Vector3(-6, 6, -9),
		Vector3(-8, 6.5, -13), Vector3(0, 7.2, -18), Vector3(0, 7.2, -22)])
	if map_id == "wind_gorge":
		controls = PackedVector3Array([
			Vector3(0, 0, 18), Vector3(0, 0, 13), Vector3(9, 1, 9),
			Vector3(11, 2, 4), Vector3(3, 3, 1), Vector3(-8, 4, -2),
			Vector3(-11, 5, -7), Vector3(-5, 6, -10), Vector3(7, 7, -12),
			Vector3(9, 8, -17), Vector3(0, 9, -20), Vector3(0, 9, -24)])
	elif map_id == "moon_highland":
		controls = PackedVector3Array([
			Vector3(0, 0, 18), Vector3(0, 0, 13), Vector3(-7, 0.8, 9),
			Vector3(-11, 1.6, 3), Vector3(-8, 2.2, -3), Vector3(0, 3, -6),
			Vector3(9, 3.8, -4), Vector3(12, 4.4, -9), Vector3(8, 5, -15),
			Vector3(0, 5.8, -18), Vector3(0, 5.8, -22)])
	var points := PackedVector3Array()
	for i: int in range(controls.size() - 1):
		for step: int in range(12):
			points.append(controls[i].cubic_interpolate(controls[i + 1], controls[maxi(0, i - 1)], controls[mini(controls.size() - 1, i + 2)], float(step) / 12.0))
	points.append(controls[-1])
	return points

static func spawn(map_id: String, spawn_id: String) -> Vector3:
	var points := route(map_id)
	return (points[-10] if spawn_id == "from_peak" else points[9]) + Vector3.UP * 0.15

static func side_at(points: PackedVector3Array, index: int) -> Vector3:
	var tangent := points[mini(index + 1, points.size() - 1)] - points[maxi(0, index - 1)]
	return Vector3(-tangent.z, 0, tangent.x).normalized()

static func build(world: Node3D, map_id: String) -> void:
	var parent: Node3D = world.get("_map_root")
	var points := route(map_id)
	preload("res://scripts/gameplay/mountain_landscape.gd").build(world, points, map_id)
	var turf := Terrain._surface()
	var trail := Terrain._surface()
	var rim := Terrain._surface()
	var width: float = 2.4
	for i: int in range(points.size() - 1):
		var a: Vector3 = points[i]
		var b: Vector3 = points[i + 1]
		var sa := side_at(points, i)
		var sb := side_at(points, i + 1)
		_quad(turf, a - sa * width, a - sa * 1.35, b - sb * 1.35, b - sb * width)
		_quad(turf, a + sa * 1.35, a + sa * width, b + sb * width, b + sb * 1.35)
		_quad(trail, a - sa * 1.35, a + sa * 1.35, b + sb * 1.35, b - sb * 1.35)
		for sign_value: float in [-1, 1]:
			var edge_a := a + sa * (width + 0.12 * sin(i * 1.7)) * sign_value
			var edge_b := b + sb * (width + 0.12 * sin((i + 1) * 1.7)) * sign_value
			# Solid weathered parapet prevents falls; cap follows the walking slope.
			var inner_a := edge_a - sa * sign_value * 0.20
			var inner_b := edge_b - sb * sign_value * 0.20
			var lift := Vector3.UP * (0.58 + 0.05 * sin(i * 0.5))
			_quad(rim, inner_a, inner_a + lift, inner_b + lift, inner_b)
			_quad(rim, edge_a + lift, inner_a + lift, inner_b + lift, edge_b + lift)
			_quad(rim, edge_a, edge_b, edge_b + lift, edge_a + lift)
		if i % 8 == 3:
			var at := a + sa * 1.85
			Terrain._grass(parent, at, 0.95, i % 3 == 0)
			if map_id == "moon_highland":
				world._add_crystal(a - sa * 1.95, 0.30)
		elif i % 24 == 12:
			world._add_lamp(a - sa * 1.9)
	_collision_mesh(parent, "MountainWalkSurface", turf, preload("res://scripts/gameplay/mountain_landscape.gd").material(Terrain.GRASS, Color("9fa780") if map_id != "wind_gorge" else Color("87999a")))
	_collision_mesh(parent, "MountainGravelTrail", trail, preload("res://scripts/gameplay/mountain_landscape.gd").material(Terrain.SOIL, Color("d2c2a2")))
	# Collision follows the original safe edge, now enclosed by natural outcrops.
	_collision_mesh(parent, "WeatheredCliffRim", rim, preload("res://scripts/gameplay/mountain_landscape.gd").material(Terrain.CLIFF, Color("818776")))
	var outskirts: GDScript = load("res://scripts/gameplay/outskirts.gd")
	outskirts.add_interaction(world, LINKS[map_id][0], "下山", points[0], true)
	if not str(LINKS[map_id][1]).is_empty():
		outskirts.add_interaction(world, LINKS[map_id][1], "繼續登山", points[-1], true)
	else:
		var end := points[-1]
		world._add_tree(end + Vector3(1.6, 0, 0.5))
		# Close the summit end with a stone wall, keeping the overlook walkable.
		world._add_box("SummitEnd", end + Vector3(0, 0.45, -0.5), Vector3(width * 2, 0.9, 0.6), Color("727d83"), true)
		world._add_crystal(end + Vector3(-1.5, 0, 0), 0.7)
		outskirts.add_interaction(world, "highland_view", "眺望月冠群山", points[-9])

static func _quad(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	var normal := (b - a).cross(c - a).normalized()
	if absf(normal.y) > 0.5 and normal.y < 0:
		normal = -normal
	Terrain._triangle(surface, a, b, c, normal)
	Terrain._triangle(surface, a, c, d, normal)

static func _collision_mesh(parent: Node3D, title: String, surface: SurfaceTool, material: Material) -> void:
	var mesh := Terrain._finish(parent, title, surface, material)
	mesh.create_trimesh_collision()
	var shape := (mesh.get_child(0).get_child(0) as CollisionShape3D).shape as ConcavePolygonShape3D
	shape.backface_collision = true

static func walking_path(map_id: String, from: Vector3, target: Vector3) -> PackedVector3Array:
	var points := route(map_id)
	var start: int = 0
	var finish: int = 0
	for i: int in range(points.size()):
		if points[i].distance_squared_to(from) < points[start].distance_squared_to(from):
			start = i
		if points[i].distance_squared_to(target) < points[finish].distance_squared_to(target):
			finish = i
	var result := PackedVector3Array()
	var step: int = 1 if finish >= start else -1
	for i: int in range(start, finish + step, step):
		result.append(Vector3(points[i].x, 0, points[i].z))
	result.append(Vector3(target.x, 0, target.z))
	return result
