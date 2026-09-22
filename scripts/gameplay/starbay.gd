extends RefCounted
## Shared authored geography for the playable world and both map views.
const Shops = preload("res://scripts/gameplay/city_shops.gd")
const Civic = preload("res://scripts/gameplay/city_civic.gd")
const NAMES := {"caravan_road": "風丘商道", "starbay": "星灣城"}
const BOUNDS := {"caravan_road": Rect2(-32, -32, 60, 64), "starbay": Rect2(-46, -43, 88, 86)}
const OUTLINE := [Vector2(-20, 38), Vector2(-28, 32), Vector2(-37, 23), Vector2(-41, 9), Vector2(-37, -6), Vector2(-29, -13), Vector2(-31, -25), Vector2(-20, -34), Vector2(-4, -38), Vector2(9, -32), Vector2(13, -23), Vector2(28, -25), Vector2(37, -15), Vector2(34, -3), Vector2(27, 4), Vector2(32, 15), Vector2(22, 24), Vector2(8, 27), Vector2(-4, 34), Vector2(-12, 38)]
const ROAD := [Vector2(-18, 26), Vector2(-18, 20), Vector2(-8, 14), Vector2(3, 10), Vector2(7, 1), Vector2(3, -10), Vector2(12, -20), Vector2(12, -27)]
const STREETS := [
	[Vector2(-16, 38), Vector2(-18, 27), Vector2(-14, 17), Vector2(-7, 10), Vector2(0, 3), Vector2(1, -8), Vector2(-6, -18), Vector2(-8, -25)],
	[Vector2(-14, 17), Vector2(-28, 13), Vector2(-29, 0), Vector2(-19, -6), Vector2(-6, -18)],
	[Vector2(0, 3), Vector2(16, 12), Vector2(23, 8), Vector2(21, -6), Vector2(12, -15), Vector2(1, -8)],
	[Vector2(-29, 0), Vector2(-13, 1), Vector2(0, 3)],
	[Vector2(-19, -6), Vector2(-24, -20), Vector2(-19, -27), Vector2(-8, -25), Vector2(2, -26), Vector2(1, -8)],
]
# Position and facing follow the local street, with small courts between clusters.
const HOMES = preload("res://scripts/gameplay/city_house_catalog.gd").POSITIONS
const PLACES := [[Vector2(-6, 11), "月帆市集"], [Vector2(-22, -19), "舊城巷"], [Vector2(22, -10), "工坊街"], [Vector2(-8, -29), "鐘樓庭"], [Vector2(-16, 35), "風丘商道 ↓"]]
const TALKS := {
	"city_sign": ["星灣城路牌", "歡迎來到星灣城。穿過南門是月帆市集；沿西側石巷可到舊城，東邊的工坊街繞著水岸延伸。返程請走南門，沿風丘商道回暮光村。"],
	"city_rest": ["月帆茶棚", "熱茶和長凳隨時為遠行的人留著。先歇一會兒吧，再沿著城牆看看這座城。\n（生命與魔力已恢復。）"],
	"city_history": ["鐘樓石誌", "星灣起初只有水邊的幾戶工匠。商隊沿山腳繞行，民居便沿著車轍生長；後來的人只把城牆接在山石之間，留下了今日彎彎曲曲的街巷。"],
}

static func spawn(map_id: String, spawn_id: String) -> Vector3:
	if map_id == "starbay":
		return Vector3(-16, 0.1, 33)
	return Vector3(12, 0.1, -23) if spawn_id == "from_city" else Vector3(-18, 0.1, 22)

static func curve(points: Array) -> PackedVector2Array:
	var line := Curve2D.new()
	line.bake_interval = 0.8
	for index: int in range(points.size()):
		var tangent: Vector2 = (points[mini(index + 1, points.size() - 1)] - points[maxi(0, index - 1)]) * 0.16
		line.add_point(points[index], -tangent if index > 0 else Vector2.ZERO, tangent if index < points.size() - 1 else Vector2.ZERO)
	return line.get_baked_points()

static func ribbon(points: PackedVector2Array, width: float) -> PackedVector2Array:
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	for index: int in range(points.size()):
		var tangent: Vector2 = (points[mini(index + 1, points.size() - 1)] - points[maxi(0, index - 1)]).normalized()
		var side := Vector2(-tangent.y, tangent.x) * width * (0.5 + sin(index * 0.27) * 0.025)
		left.append(points[index] + side)
		right.append(points[index] - side)
	right.reverse()
	left.append_array(right)
	return left

static func outline(map_id: String) -> PackedVector2Array:
	return PackedVector2Array(OUTLINE) if map_id == "starbay" else PackedVector2Array([Vector2(-27, 30), Vector2(-28, 20), Vector2(-20, 10), Vector2(-6, 6), Vector2(-2, 0), Vector2(-6, -11), Vector2(0, -22), Vector2(4, -30), Vector2(21, -30), Vector2(24, -19), Vector2(15, -8), Vector2(15, 3), Vector2(11, 15), Vector2(-4, 22), Vector2(-10, 30)])

static func surface(world: Node3D, label: String, polygon: PackedVector2Array, height: float, paving: bool, solid: bool = false) -> void:
	var mesh := SurfaceTool.new()
	mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
	var indices := Geometry2D.triangulate_polygon(polygon)
	for index: int in indices:
		var point: Vector2 = polygon[index]
		mesh.set_normal(Vector3.UP)
		mesh.set_uv(point / (3.2 if paving else 4.0))
		mesh.add_vertex(Vector3(point.x, height, point.y))
	var visual := MeshInstance3D.new()
	visual.name = label
	visual.mesh = mesh.commit()
	var material: ShaderMaterial = world._make_village_surface(paving)
	material.set_shader_parameter("polygon_surface", true)
	material.set_shader_parameter("planted_island", false)
	var dirt_road: bool = label == "WindingCaravanRoad"
	var worn_path: bool = label.begins_with("CivicLink") or label == "GardenWalk" or label in ["CityStreet1", "CityStreet4"]
	material.set_shader_parameter("road_kind", 2 if dirt_road else 1 if worn_path else 0)
	visual.material_override = material
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.get("_map_root").add_child(visual)
	if solid:
		visual.create_trimesh_collision()
	if paving:
		visual.add_to_group("polygon_footsteps")
		visual.set_meta("step_polygon", polygon)
		visual.set_meta("step_surface", &"dirt" if dirt_road else &"stone")

static func ellipse(center: Vector2, size: Vector2) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index: int in range(40):
		var angle: float = index * TAU / 40.0
		points.append(center + Vector2(cos(angle), sin(angle)) * size)
	return points

static func boundary(world: Node3D, polygon: PackedVector2Array, city: bool) -> void:
	for index: int in range(polygon.size() - 1):
		# The road ribbon has two open ends; the city polygon ends at the south gate.
		if not city and index == 7:
			continue
		var a: Vector2 = polygon[index]
		var b: Vector2 = polygon[index + 1]
		var center := (a + b) * 0.5
		world._add_box("CityWall" if city else "RoadBank", Vector3(center.x, 0.7 if city else 0.4, center.y), Vector3(0.65, 1.4 if city else 0.8, a.distance_to(b) + 0.12), Color("616577") if city else Color("495545"), true)
		var wall: Node3D = world.get("_map_root").get_child(-1)
		wall.rotation.y = atan2(b.x - a.x, b.y - a.y)
		if city:
			(wall.get_child(0) as MeshInstance3D).material_override = world._make_coursed_stone()
			for step: int in range(ceili(a.distance_to(b) / 1.6)):
				var at: Vector2 = a.lerp(b, float(step) / ceili(a.distance_to(b) / 1.6))
				world._add_box("WallMerlon", Vector3(at.x, 1.55, at.y), Vector3(0.9, 0.4, 0.9), Color("777882"), false)

static func build(world: Node3D, map_id: String) -> void:
	var city := map_id == "starbay"
	var perimeter := outline(map_id)
	surface(world, "StarbayGround", perimeter, 0.0, false, true)
	boundary(world, perimeter, city)
	if not city:
		build_road(world)
		return
	for index: int in range(STREETS.size()):
		surface(world, "CityStreet%d" % index, ribbon(curve(STREETS[index]), 4.2 if index == 0 else 2.8), 0.018 + index * 0.001, true)
	surface(world, "MarketCourt", ellipse(Vector2(-6, 11), Vector2(9, 6)), 0.026, true)
	surface(world, "BelfryCourt", ellipse(Vector2(-8, -27), Vector2(6.5, 5)), 0.026, true)
	for index: int in range(HOMES.size()):
		var home: Vector3 = HOMES[index]
		var catalog: Dictionary = preload("res://scripts/gameplay/house_catalog.gd").HOMES[index % 8]
		var address: String = preload("res://scripts/gameplay/city_house_catalog.gd").address(index)
		var japanese: bool = address in preload("res://scripts/gameplay/japanese_house.gd").ADDRESSES
		world._add_house(Vector3(home.x, 0, home.y), catalog.wall, catalog.roof, home.z, catalog.id, index if japanese else -1, address if Shops.SHOPS.has(address) else "")
		var building: Node3D = world.get("_map_root").get_child(-1)
		building.name = "CityHouse%d" % index
		var id: String = preload("res://scripts/gameplay/city_house_catalog.gd").address(index)
		building.set_meta("house_id", id)
		var entrance: Interactable3D = building.get_node("HouseEntrance")
		entrance.interaction_id = "enter_" + id
		entrance.prompt_text = "進入" + str(preload("res://scripts/gameplay/city_house_catalog.gd").home(id).name)
		building.add_to_group("city_houses")
	for at: Vector2 in [Vector2(-20, 33), Vector2(-12, 33), Vector2(-20, 18), Vector2(-24, 12), Vector2(-31, -4), Vector2(-9, -23), Vector2(-3, -27), Vector2(4, -16), Vector2(24, -8), Vector2(19, 10), Vector2(3, 10), Vector2(-1, 17)]:
		world._add_lamp(Vector3(at.x, 0, at.y))
	for at: Vector2 in [Vector2(-31, 27), Vector2(-36, 17), Vector2(-35, -8), Vector2(-24, -28), Vector2(-11, -36), Vector2(5, -30.5), Vector2(32, -16), Vector2(30, 13), Vector2(20, 22), Vector2(-5, 28)]:
		world._add_tree(Vector3(at.x, 0, at.y))
		world._add_flower_clump(Vector3(at.x + 1.3, 0.02, at.y), "ivory")
	preload("res://scripts/gameplay/natural_water.gd").pond(world.get("_map_root"), Vector3(12, 0.035, 4), Vector2(6, 4))
	build_market(world)
	build_belfry(world)
	dress_materials(world)
	Civic.build(world)
	add_residents(world)
	var exits := preload("res://scripts/gameplay/outskirts.gd")
	exits.add_interaction(world, "travel_city_home", "返回風丘商道", Vector3(-16, 0, 36.8), true)
	exits.add_interaction(world, "city_sign", "查看星灣城路牌", Vector3(-12, 0, 30))
	exits.add_interaction(world, "city_rest", "在月帆茶棚休息", Vector3(-3, 0, 15))
	exits.add_interaction(world, "city_history", "閱讀鐘樓石誌", Vector3(-8, 0, -25))
	world._add_box("CitySignPost", Vector3(-12, 0.7, 30), Vector3(0.18, 1.4, 0.18), Color("665347"), false)
	world._add_box("CitySignBoard", Vector3(-12, 1.3, 30), Vector3(1.5, 0.6, 0.15), Color("a79162"), false)
	for x: float in [-20, -12]:
		world._add_column(Vector3(x, 0, 37))

static func build_road(world: Node3D) -> void:
	var route := curve(ROAD)
	surface(world, "WindingCaravanRoad", ribbon(route, 4.2), 0.022, true)
	for index: int in range(5, route.size() - 5, 7):
		var p: Vector2 = route[index]
		var tangent: Vector2 = (route[index + 1] - route[index - 1]).normalized()
		var side := Vector2(-tangent.y, tangent.x)
		for direction: float in [-1, 1]:
			var at: Vector2 = p + side * (5.5 + sin(index) * 0.8) * direction
			world._add_tree(Vector3(at.x, 0, at.y))
			world._add_grass_clump(Vector3(at.x - 0.7, 0.02, at.y), "seed", 0.001)
		if index % 3 == 0:
			var at: Vector2 = p + side * 2.9
			world._add_lamp(Vector3(at.x, 0, at.y))
	world._add_supply_crate(Vector3(-10, 0, 18), 0.2)
	world._add_supply_crate(Vector3(-8.5, 0, 19), -0.3)
	var exits := preload("res://scripts/gameplay/outskirts.gd")
	exits.add_interaction(world, "travel_caravan_back", "返回東行舊道", Vector3(-18, 0, 25), true)
	exits.add_interaction(world, "travel_city", "前往星灣城", Vector3(12, 0, -26), true)

static func build_market(world: Node3D) -> void:
	for index: int in range(5):
		var at := Vector3(-12 + index * 3.5, 0, 6 if index < 3 else 16)
		var color: Color = [Color("a35c66"), Color("54858a"), Color("bc995e")][index % 3]
		world._add_box("MarketCounter", at + Vector3(0, 0.48, 0), Vector3(2.3, 0.96, 1.1), Color("795d48"), true)
		world.get("_map_root").get_child(-1).set_meta("city_material_kind", "MarketCounter")
		for side: float in [-1, 1]:
			world._add_box("CanopyPost", at + Vector3(side * 1.2, 1.1, 0.3), Vector3(0.12, 2.2, 0.12), Color("5e5148"), false)
			world.get("_map_root").get_child(-1).set_meta("city_material_kind", "CanopyPost")
		for stripe: int in range(6):
			add_canopy_strip(world, at + Vector3(-1.35 + stripe * 0.45, 0, 0), color if stripe % 2 == 0 else Color("d9c9a1"))
		world._add_earthenware_jar(at + Vector3(0.9, 0, -1.6))
		world._add_box("MarketTabletop", at + Vector3(0, 0.99, 0), Vector3(2.5, 0.12, 1.25), Color("ab9270"), false)
		world.get("_map_root").get_child(-1).set_meta("city_material_kind", "MarketTabletop")
		for item: int in range(3):
			world._add_box("MarketGoods", at + Vector3(-0.7 + item * 0.65, 1.13, 0), Vector3(0.5, 0.18, 0.8), color.lightened(item * 0.12), false)
	world._add_box("TeaBench", Vector3(-3, 0.45, 17), Vector3(2.2, 0.18, 0.65), Color("8a6c4f"), true)
	world.get("_map_root").get_child(-1).set_meta("city_material_kind", "TeaBench")

static func build_belfry(world: Node3D) -> void:
	world._add_box("BelfryBase", Vector3(-8, 0.2, -30.5), Vector3(3.8, 0.4, 3.8), Color("aaa29a"), true)
	world.get("_map_root").get_child(-1).set_meta("city_material_kind", "BelfryBase")
	world._add_box("BelfryTower", Vector3(-8, 3.4, -30.5), Vector3(2.3, 6.4, 2.3), Color("a59c8e"), true)
	world.get("_map_root").get_child(-1).set_meta("city_material_kind", "BelfryTower")
	for y: float in [1.0, 3.7, 6.3]:
		world._add_box("BelfryCornice", Vector3(-8, y, -30.5), Vector3(2.7, 0.22, 2.7), Color("736f7b"), false)
		world.get("_map_root").get_child(-1).set_meta("city_material_kind", "BelfryCornice")
	for x: float in [-8.85, -7.15]:
		world._add_box("BellSupport", Vector3(x, 7.1, -30.5), Vector3(0.2, 1.5, 1.8), Color("69584d"), false)
		world.get("_map_root").get_child(-1).set_meta("city_material_kind", "BellSupport")
	world._add_box("BellRoof", Vector3(-8, 8, -30.5), Vector3(3.4, 0.32, 3.4), Color("4d6878"), false)
	var bell := MeshInstance3D.new()
	var shape := CylinderMesh.new()
	shape.top_radius = 0.25
	shape.bottom_radius = 0.65
	shape.height = 0.9
	bell.mesh = shape
	bell.material_override = world._make_material(Color("bc9a51"), 0.5, 0.55)
	bell.position = Vector3(-8, 7.1, -30.5)
	world.get("_map_root").add_child(bell)

static func add_residents(world: Node3D) -> void:
	var routes: Array = [
		[Vector3(-11, 0, 12), Vector3(-5, 0, 11), Vector3(-1, 0, 9)],
		[Vector3(-29, 0, 3), Vector3(-28, 0, 11), Vector3(-23, 0, 13)],
		[Vector3(21, 0, -5), Vector3(23, 0, 2), Vector3(23, 0, 8)],
		[Vector3(-18, 0, -27), Vector3(-12, 0, -27), Vector3(-11, 0, -23)],
	]
	var names := ["商販・莉亞", "石匠・梅森", "工匠・琳", "守鐘人・索恩"]
	var lines := ["從暮光村來的？沿風丘商道的彎路走，就會到我們南門。市集東南角的茶棚可以休息。", "這些巷子比城牆還老。房子順著山腳蓋，路就跟著屋子轉彎。", "工坊的貨沿水岸運到市集。別急著離開，繞過池邊還有一整條街呢。", "每次商隊回城，鐘聲就會響起。想知道城的來歷，可以讀讀塔前的石誌。"]
	for index: int in range(routes.size()):
		var resident := preload("res://scripts/gameplay/wandering_villager.gd").new()
		resident.name = "CityResident%d" % index
		resident.route = PackedVector3Array(routes[index])
		resident.position = resident.route[0]
		resident.player = world.get_node("Player")
		resident.resident_id = ["rain", "locke", "mira", "owen"][index]
		resident.display_name = names[index]
		resident.dialogue_text = lines[index]
		resident.speed = 0.65
		resident.conversation_requested.connect(world._talk_to_wandering_villager)
		world.get("_map_root").add_child(resident)


static func add_canopy_strip(world: Node3D, at: Vector3, color: Color) -> void:
	var surface_tool := SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index: int in range(8):
		var z0: float = -1.05 + index * 0.27
		var z1: float = z0 + 0.27
		var y0: float = 2.35 - sin(float(index) / 8.0 * PI) * 0.16 + z0 * 0.12
		var y1: float = 2.35 - sin(float(index + 1) / 8.0 * PI) * 0.16 + z1 * 0.12
		var vertices: Array[Vector3] = [Vector3(0, y0, z0), Vector3(0.45, y0, z0), Vector3(0.45, y1, z1), Vector3(0, y1, z1)]
		for corner: int in [0, 1, 2, 0, 2, 3]:
			surface_tool.set_uv(Vector2(vertices[corner].x, vertices[corner].z + 1.05))
			surface_tool.add_vertex(vertices[corner])
	surface_tool.generate_normals()
	var canopy := MeshInstance3D.new()
	canopy.name = "CanvasAwning"
	canopy.position = at
	surface_tool.generate_tangents()
	canopy.mesh = surface_tool.commit()
	var material: StandardMaterial3D = preload("res://scripts/gameplay/cloth_material.gd").make(color)
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	canopy.material_override = material
	world.get("_map_root").add_child(canopy)


static func dress_materials(world: Node3D) -> void:
	var timber: StandardMaterial3D = world._make_material(Color("c2ad93"), 0.95)
	timber.albedo_texture = preload("res://assets/generated/timber_albedo.png")
	timber.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	var stone: ShaderMaterial = world._make_coursed_stone()
	for node: Node in world.get("_map_root").get_children():
		var name: String = str(node.get_meta("city_material_kind", ""))
		if name.begins_with("MarketCounter") or name.begins_with("MarketTabletop") or name.begins_with("CanopyPost") or name.begins_with("TeaBench") or name.begins_with("BellSupport"):
			(node.get_child(0) as MeshInstance3D).material_override = timber
		elif name.begins_with("Belfry"):
			(node.get_child(0) as MeshInstance3D).material_override = stone
