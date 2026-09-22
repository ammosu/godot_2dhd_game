extends RefCounted
## Civic infill calibrated from docs/design/starbay-civic-plan-v1.png.
## Shared positions and pedestrian routes drive scenery, map symbols and tests.
const Collision = preload("res://scripts/gameplay/prop_collision.gd")
const Houses = preload("res://scripts/gameplay/city_house_catalog.gd")
const MOON := Vector2(-9, -9)
const TREE := Vector2(-18, 10)
const PAVILION := Vector2(8, 0)
const PLACES := [[Vector2(-9, -9), "月儀庭"], [Vector2(-22, 9), "樹蔭庭園"], [Vector2(8, 0), "水岸涼亭"]]
const POCKETS := [Vector2(-16, -21), Vector2(23, -13), Vector2(4, 23)]
const LINKS := [
	[Vector2(1, -8), Vector2(-3, -8.6), Vector2(-6.1, -9)],
	[Vector2(-19, -6), Vector2(-15.5, -8), Vector2(-11.9, -9)],
	[Vector2(-28, 13), Vector2(-23, 12.7), Vector2(-20, 11.2)],
	[Vector2(-15.7, 10), Vector2(-13.5, 10.5)],
	[Vector2(0, 3), Vector2(4, 2.8), Vector2(8, 2.3), Vector2(8, 0.5)],
]
const TALKS := {
	"city_moon_court": ["月儀庭", "銅環描著月亮與星辰的路徑。商隊從前在這裡對時，如今孩子們沿著花壇繞圈，等鐘樓報時。"],
	"city_tree_garden": ["樹蔭庭園", "老樹比周圍的店舖更早來到這裡。人們留下兩條穿過花園的小徑，讓趕路的人與歇腳的人都能找到位置。"],
	"city_pavilion": ["水岸涼亭", "六根木柱托起灰瓦亭頂，四周沒有牆。池邊的花隨風輕晃，從這裡能看見工坊街與月帆市集。"],
}

static func ring(center: Vector2, radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index: int in range(65):
		var angle: float = index * TAU / 64.0
		points.append(center + Vector2(cos(angle), sin(angle)) * radius)
	return points

static func build(world: Node3D) -> void:
	var geography: GDScript = load("res://scripts/gameplay/starbay.gd")
	for index: int in range(LINKS.size()):
		geography.surface(world, "CivicLink%d" % index, geography.ribbon(geography.curve(LINKS[index]), 1.5), 0.031, true)
	for court: Array in [[MOON, 2.9, 1.45], [TREE, 2.3, 1.35]]:
		# Closed annuli use separate quads, avoiding a self-intersecting ribbon seam.
		var points := ring(court[0], court[1])
		for index: int in range(points.size() - 1):
			var a: Vector2 = points[index] - court[0]
			var b: Vector2 = points[index + 1] - court[0]
			var half_width: float = float(court[2]) * 0.5
			var polygon := PackedVector2Array([court[0] + a + a.normalized() * half_width, court[0] + b + b.normalized() * half_width, court[0] + b - b.normalized() * half_width, court[0] + a - a.normalized() * half_width])
			geography.surface(world, "GardenWalk", polygon, 0.032, true)
	moon_court(world)
	tree_garden(world)
	pavilion(world)
	planting(world, geography)
	var exits: GDScript = load("res://scripts/gameplay/outskirts.gd")
	exits.add_interaction(world, "city_moon_court", "查看月儀", Vector3(MOON.x - 2.9, 0, MOON.y))
	exits.add_interaction(world, "city_tree_garden", "閱讀老樹銘牌", Vector3(TREE.x + 2.3, 0, TREE.y))
	exits.add_interaction(world, "city_pavilion", "在亭中聽風", Vector3(PAVILION.x, 0, PAVILION.y + 0.4))

static func material(file: String, tint: Color) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_color = tint
	result.albedo_texture = load("res://assets/generated/" + file) as Texture2D
	result.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	result.roughness = 0.9
	return result

static func root_at(world: Node3D, label: String, at: Vector2) -> Node3D:
	var root := Node3D.new()
	root.name = label
	root.position = Vector3(at.x, 0, at.y)
	world.get("_map_root").add_child(root)
	root.add_to_group("civic_landmarks")
	return root

static func mesh_at(parent: Node3D, label: String, mesh: Mesh, at: Vector3, mat: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = label
	node.mesh = mesh
	node.position = at
	node.material_override = mat
	parent.add_child(node)
	return node

static func box(parent: Node3D, label: String, at: Vector3, size: Vector3, mat: Material, solid: bool = false) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var visual := mesh_at(parent, label, mesh, at, mat)
	if solid:
		Collision.box(parent, at, size)
	return visual

static func cylinder(parent: Node3D, label: String, at: Vector3, radius: float, height: float, mat: Material) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 32
	return mesh_at(parent, label, mesh, at, mat)

static func moon_court(world: Node3D) -> void:
	var root := root_at(world, "MoonArmillaryCourt", MOON)
	var stone := material("ruin_flagstone.png", Color("b7b9bd"))
	var bronze := StandardMaterial3D.new()
	bronze.albedo_color = Color("bb9762")
	bronze.metallic = 0.7
	bronze.roughness = 0.46
	cylinder(root, "Plinth", Vector3(0, 0.12, 0), 1.5, 0.24, stone)
	cylinder(root, "UpperStep", Vector3(0, 0.29, 0), 1.23, 0.12, stone)
	cylinder(root, "Pedestal", Vector3(0, 0.75, 0), 0.65, 0.86, stone)
	cylinder(root, "DialTable", Vector3(0, 1.21, 0), 1.08, 0.16, bronze)
	Collision.cylinder(root, Vector3(0, 0.7, 0), 1.50, 1.4)
	for index: int in range(3):
		var ring_mesh := TorusMesh.new()
		ring_mesh.inner_radius = 0.98 - index * 0.1
		ring_mesh.outer_radius = 1.05 - index * 0.1
		ring_mesh.rings = 48
		ring_mesh.ring_segments = 8
		var visual := mesh_at(root, "AstronomicalRing", ring_mesh, Vector3(0, 2.0, 0), bronze)
		visual.rotation = [Vector3(0.30, 0, 0.1), Vector3(PI * 0.5, 0, 0.4), Vector3(0, 0, 1.05)][index]
	for index: int in range(12):
		var angle: float = index * TAU / 12.0
		var tick := box(root, "HourMarker", Vector3(cos(angle), 1.31, sin(angle)), Vector3(0.035, 0.035, 0.15), stone)
		tick.rotation.y = -angle + PI * 0.5
	world._add_crystal(Vector3(MOON.x, 1.6, MOON.y), 0.38)
	# Two planted crescents inside the promenade, with east/west access gaps.
	for side: float in [-1, 1]:
		for index: int in range(7):
			var angle: float = 0.35 + index * (PI - 0.7) / 6.0
			var at := Vector3(MOON.x + cos(angle) * 1.93, 0.025, MOON.y + side * sin(angle) * 1.93)
			world._add_flower_clump(at, "ivory" if side > 0 else "blue")
	world._add_lamp(Vector3(MOON.x + 4.1, 0, MOON.y + 2.5))

static func tree_garden(world: Node3D) -> void:
	var root := root_at(world, "CommunityTreeGarden", TREE)
	var tree := Node3D.new()
	tree.name = "CommunityOak"
	tree.position = Vector3(TREE.x, 0, TREE.y)
	tree.add_to_group("village_trees")
	world.get("_map_root").add_child(tree)
	preload("res://scripts/gameplay/tree_variants.gd").decorate(tree, tree.position, 0)
	var art: Sprite3D = tree.get_node("TreeArt")
	art.scale *= 1.28
	art.position *= 1.28
	Collision.cylinder(tree, Vector3(0, 1, 0), 0.5, 2.0)
	var stone := material("ruin_flagstone.png", Color("9a9990"))
	cylinder(root, "TreeWell", Vector3(0, 0.09, 0), 1.05, 0.18, stone)
	Collision.cylinder(root, Vector3(0, 0.2, 0), 1.05, 0.4)
	bench(root, Vector3(0, 0, -3.5), 0)
	bench(root, Vector3(0.3, 0, 3.5), PI)
	for index: int in range(12):
		var angle: float = index * TAU / 12.0
		world._add_flower_clump(Vector3(TREE.x + cos(angle) * 1.25, 0.02, TREE.y + sin(angle) * 1.25), "mauve" if index % 2 == 0 else "ivory")

static func bench(parent: Node3D, at: Vector3, yaw: float) -> void:
	var root := Node3D.new()
	root.name = "GardenBench"
	root.position = at
	root.rotation.y = yaw
	parent.add_child(root)
	var wood := material("timber_albedo.png", Color("bba388"))
	for side: float in [-1, 1]:
		box(root, "Leg", Vector3(side * 0.72, 0.23, 0), Vector3(0.13, 0.46, 0.48), wood)
	for strip: int in range(3):
		box(root, "SeatSlat", Vector3(0, 0.48, -0.2 + strip * 0.2), Vector3(1.9, 0.09, 0.18), wood)
	box(root, "BackRest", Vector3(0, 0.88, -0.28), Vector3(1.9, 0.23, 0.09), wood)
	Collision.box(root, Vector3(0, 0.46, 0), Vector3(1.9, 0.92, 0.6))

static func pavilion(world: Node3D) -> void:
	var root := root_at(world, "PondPavilion", PAVILION)
	var wood := material("timber_albedo.png", Color("a18b71"))
	var stone := material("ruin_flagstone.png", Color("bab7a5"))
	var tile := material("slate_roof_albedo.png", Color("89969b"))
	var platform := CylinderMesh.new()
	platform.radial_segments = 6
	platform.top_radius = 2.1
	platform.bottom_radius = 2.1
	platform.height = 0.035
	mesh_at(root, "PavilionFloor", platform, Vector3(0, 0.023, 0), stone)
	for index: int in range(6):
		var angle: float = index * TAU / 6.0
		var at := Vector3(cos(angle) * 1.55, 1.32, sin(angle) * 1.55)
		cylinder(root, "PavilionPost", at, 0.105, 2.64, wood)
		Collision.cylinder(root, at, 0.14, 2.64)
		var next := Vector3(cos(angle + TAU / 6.0) * 1.55, 2.58, sin(angle + TAU / 6.0) * 1.55)
		var beam := box(root, "RoofBeam", (Vector3(at.x, 2.58, at.z) + next) * 0.5, Vector3(0.15, 0.16, 1.55), wood)
		beam.rotation.y = atan2(next.x - at.x, next.z - at.z)
	var roof := SurfaceTool.new()
	roof.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side: int in range(6):
		var a: float = side * TAU / 6.0
		var b: float = (side + 1) * TAU / 6.0
		for band: int in range(8):
			var r0: float = band / 8.0 * 2.35
			var r1: float = (band + 1) / 8.0 * 2.35
			var vertices: Array[Vector3] = []
			for corner: Vector2 in [Vector2(a, r0), Vector2(b, r0), Vector2(b, r1), Vector2(a, r1)]:
				var t: float = corner.y / 2.35
				vertices.append(Vector3(cos(corner.x) * corner.y, 3.7 - t * 1.3 + 0.27 * pow(t, 4), sin(corner.x) * corner.y))
			for corner: int in [0, 1, 2, 0, 2, 3]:
				roof.set_uv(Vector2(vertices[corner].x, vertices[corner].z) * 0.45)
				roof.add_vertex(vertices[corner])
	roof.generate_normals()
	tile.cull_mode = BaseMaterial3D.CULL_DISABLED
	mesh_at(root, "HexagonalRoof", roof.commit(), Vector3.ZERO, tile)
	cylinder(root, "Finial", Vector3(0, 3.84, 0), 0.10, 0.34, wood)
	bench(root, Vector3(0, 0, -1.0), 0)
	# Shore planting sits outside the existing pond's deep-water collision.
	for at: Vector2 in [Vector2(9.5, 5.5), Vector2(11, 6.5), Vector2(14, 5.8), Vector2(15.2, 3.7), Vector2(13.5, 1.8)]:
		world._add_grass_clump(Vector3(at.x, 0.02, at.y), "fan", 0.00125)
		world._add_flower_clump(Vector3(at.x + 0.3, 0.02, at.y), "blue")

static func planting(world: Node3D, geography: GDScript) -> void:
	var paths: Array[PackedVector2Array] = []
	for street: Array in geography.STREETS:
		paths.append(geography.curve(street))
	for link: Array in LINKS:
		paths.append(geography.curve(link))
	paths.append(ring(MOON, 2.9))
	paths.append(ring(TREE, 2.3))
	for center: Vector2 in POCKETS:
		world._add_tree(Vector3(center.x, 0, center.y))
	for center: Vector2 in [MOON, TREE, Vector2(12, 4), POCKETS[0], POCKETS[1], POCKETS[2]]:
		for index: int in range(24):
			var angle: float = index * 2.399963
			var radius: float = 1.5 + float(index % 5) * 0.58
			var at := center + Vector2(cos(angle), sin(angle)) * radius
			if not clear_for_plant(at, paths):
				continue
			world._add_grass_clump(Vector3(at.x, 0.025, at.y), "low", 0.00085)
			if index % 3 == 0:
				world._add_flower_clump(Vector3(at.x, 0.03, at.y), "ivory" if index % 2 == 0 else "mauve")

static func clear_for_plant(at: Vector2, paths: Array[PackedVector2Array]) -> bool:
	for index: int in range(paths.size()):
		var path: PackedVector2Array = paths[index]
		var clearance: float = 2.55 if index == 0 else (1.9 if index < 5 else 1.0)
		for segment: int in range(path.size() - 1):
			if at.distance_to(Geometry2D.get_closest_point_to_segment(at, path[segment], path[segment + 1])) < clearance:
				return false
	for home: Vector3 in Houses.POSITIONS:
		var local := (at - Vector2(home.x, home.y)).rotated(home.z)
		if absf(local.x) < 2.9 and local.y > -4.4 and local.y < 2.8:
			return false
	if ((at - Vector2(12, 4)) / Vector2(3.4, 2.5)).length() < 1.0:
		return false
	if at.distance_to(PAVILION) < 2.4 or at.distance_to(MOON) < 1.65:
		return false
	return true
