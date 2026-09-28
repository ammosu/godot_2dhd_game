extends RefCounted
## Scenery for Twilight Village: ground, roads, walls, trees, lamps, props and
## gardens. Interactive landmarks, homes and actors are wired by the world.

const GardenFence = preload("res://scripts/gameplay/garden_fence.gd")
const SpriteGrounding = preload("res://scripts/gameplay/sprite_grounding.gd")
const STONE_DARK := Color("343246")


## Ground, plaza, pond and the three main roads, including the clipped enclosure.
static func roads(props: WorldProps) -> void:
	props.add_box("Ground", Vector3(0.0, -0.35, 0.0), Vector3(46.0, 0.7, 40.0), Color("304b48"), true)
	props.add_cobble_box("CentralPlaza", Vector3(0.0, -0.02, 0.0), Vector3(7.8, 0.12, 8.0), true)
	preload("res://scripts/gameplay/natural_water.gd").pond(props.map_root, Vector3(11.5, 0.085, -10.0), Vector2(9.0, 5.0))

	props.add_cobble_box("NorthRoad", Vector3(0.0, 0.025, -3.75), Vector3(2.35, 0.08, 32.5), false)
	props.add_cobble_box("MarketRoad", Vector3(0.0, 0.023, 4.6), Vector3(29.0, 0.075, 2.25), false)
	props.add_cobble_box("GateRoad", Vector3(0.0, 0.022, -4.8), Vector3(29.0, 0.07, 1.9), false)
	_routes(props)


## Garden promenade, organic surface blending and perimeter trees and lamps.
static func walks(props: WorldProps) -> void:
	# Outer garden promenade expands exploration without stretching the village square.
	for x_position: float in [-19.0, 19.0]:
		props.add_cobble_box("GardenWalk", Vector3(x_position, 0.022, 0), Vector3(1.8, 0.07, 34), false)
	for z_position: float in [-16.8, 16.8]:
		props.add_cobble_box("GardenWalk", Vector3(0, 0.022, z_position), Vector3(38, 0.07, 1.8), false)
	_configure_surfaces(props.map_root)
	preload("res://scripts/gameplay/village_surface_overlap.gd").configure(props.map_root)
	for x_position: float in [-20.7, 20.7]:
		for z_position: float in [-15, -7, 2, 11, 17]:
			props.add_tree(Vector3(x_position + sin(z_position * 1.7) * 0.55, 0, z_position + cos(z_position) * 0.75))
	for position: Vector3 in [Vector3(-19, 0, -12), Vector3(19, 0, -12), Vector3(-19, 0, 10), Vector3(19, 0, 10), Vector3(-6, 0, 16.8), Vector3(6, 0, 16.8)]:
		props.add_lamp(position)


## Plaza trees and lamps placed around the landmark columns.
static func plaza(props: WorldProps) -> void:
	for tree_position in [
		Vector3(-16.2, 0.0, -11.8), Vector3(-16.0, 0.0, -4.0), Vector3(-16.1, 0.0, 5.8), Vector3(-15.2, 0.0, 12.4),
		Vector3(16.1, 0.0, -5.3), Vector3(16.0, 0.0, 3.8), Vector3(15.5, 0.0, 11.9),
		Vector3(0.0, 0.0, 13.7), Vector3(14.8, 0.0, -13.0),
	]:
		props.add_tree(tree_position)
	for lamp_position in [
		Vector3(-1.75, 0.0, -8.2), Vector3(1.75, 0.0, -8.2), Vector3(-1.75, 0.0, -3.5), Vector3(1.75, 0.0, -3.5),
		Vector3(-1.75, 0.0, 3.5), Vector3(1.75, 0.0, 3.5), Vector3(-1.75, 0.0, 8.6), Vector3(1.75, 0.0, 8.6),
		Vector3(-8.0, 0.0, 4.0), Vector3(8.0, 0.0, 4.0),
	]:
		props.add_lamp(lamp_position)


## Crystals, crates, jar, grass, the pig and the fenced gardens.
static func dressing(props: WorldProps) -> void:
	props.add_crystal(Vector3(-7.0, 0.0, -3.2), 1.1)
	props.add_crystal(Vector3(7.2, 0.0, 1.2), 0.85)
	props.add_crystal(Vector3(14.0, 0.0, 9.0), 0.72)
	props.add_supply_crate(Vector3(-6.5, 0.01, 4.0), 0.12)
	props.add_supply_crate(Vector3(-5.5, 0.01, 4.6), -0.10)
	props.add_earthenware_jar(Vector3(6.2, 0.01, 3.3))
	for grass_position: Vector3 in [Vector3(-14.0, 0.01, 3.0), Vector3(-13.5, 0.01, 2.6), Vector3(14.5, 0.01, -2.1), Vector3(14.0, 0.01, -2.45), Vector3(5.4, 0.01, 8.8)]:
		props.add_grass_clump(grass_position, "seed", 0.001)
	props.add_village_pig(Vector3(8.5, 0.015, 8.4))
	_gardens(props)


## Low flower crescent framing the moon lamp, open to the south approach.
static func moon_garden(map_root: Node3D) -> void:
	var planting := Node3D.new()
	planting.name = "MoonGarden"
	map_root.add_child(planting)
	for index: int in range(20):
		var angle := PI + index * PI / 19.0
		var flower := Sprite3D.new()
		flower.texture = preload("res://assets/generated/flowers_ivory.tres")
		flower.pixel_size = 0.00065
		flower.position = Vector3(cos(angle) * 1.16, 0.015, sin(angle) * 1.16)
		flower.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		flower.shaded = true
		flower.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
		flower.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		flower.modulate = Color("bc95da") if index % 3 != 0 else Color.WHITE
		planting.add_child(flower)
		SpriteGrounding.anchor(flower, flower.texture, SpriteGrounding.foot_baseline(flower.texture, flower.alpha_scissor_threshold))
		flower.remove_from_group("grounded_character_art")


static func _routes(props: WorldProps) -> void:
	# Visible terrain beyond the checkpoint makes the opening read as a road.
	props.add_box("NorthApproachGround", Vector3(0, -0.35, -22.5), Vector3(12, 0.7, 7), Color("292b3e"), false)
	props.add_cobble_box("NorthApproachRoad", Vector3(0, 0.025, -22.0), Vector3(2.35, 0.08, 5.5), false)
	for side: float in [-1.0, 1.0]:
		props.add_tree(Vector3(side * 4.0, 0, -22.0))
	# Clipped, uneven corners soften the enclosure; preserve both portal gaps.
	var boundary: Array[Vector2] = [
		Vector2(1.75, -19.3), Vector2(17.8, -19.3), Vector2(21.5, -16.7),
		Vector2(22.3, -9.0), Vector2(22.3, 2.1),
		Vector2(22.3, 7.1), Vector2(21.9, 15.7), Vector2(18.2, 19.0),
		Vector2(6.0, 19.3), Vector2(-16.8, 19.0), Vector2(-22.0, 15.4),
		Vector2(-22.3, 4.0), Vector2(-21.8, -15.8), Vector2(-17.8, -19.3), Vector2(-1.75, -19.3),
	]
	for index: int in range(boundary.size() - 1):
		if index == 4:
			continue # East road opening.
		var start: Vector2 = boundary[index]
		var finish: Vector2 = boundary[index + 1]
		var middle: Vector2 = (start + finish) * 0.5
		props.add_box("BoundaryWall", Vector3(middle.x, 0.75, middle.y), Vector3(0.7, 1.8, start.distance_to(finish) + 0.2), STONE_DARK, true)
		(props.map_root.get_child(props.map_root.get_child_count() - 1) as Node3D).rotation.y = atan2(finish.x - start.x, finish.y - start.y)
	props.add_box("OutskirtsGround", Vector3(29.0, -0.38, 4.6), Vector3(16.0, 0.7, 19.0), Color("304b48"), false)
	props.add_cobble_box("EastRoad", Vector3(30.5, 0.022, 4.6), Vector3(8.0, 0.075, 3.6), false)
	for tree_position: Vector3 in [Vector3(29, 0, 0), Vector3(32, 0, 1), Vector3(29, 0, 10), Vector3(33, 0, 9)]:
		props.add_tree(tree_position)
	props.add_box("EastRoadGround", Vector3(24.5, -0.35, 4.6), Vector3(6.0, 0.7, 5.0), Color("304b48"), true)
	props.add_cobble_box("EastRoad", Vector3(20.75, 0.025, 4.6), Vector3(12.5, 0.08, 3.6), false)
	# A safety backstop sits beyond the automatic walking threshold.
	props.add_box("EastTrailEdge", Vector3(27.25, 0.5, 4.6), Vector3(0.35, 1.0, 5), Color("405b49"), true)
	for z: float in [2.25, 6.95]:
		props.add_box("EastTrailEdge", Vector3(25, 0.5, z), Vector3(4.5, 1.0, 0.3), Color("405b49"), true)
	for at: Vector3 in [Vector3(18.2, 0, 2.35), Vector3(18.2, 0, 6.85), Vector3(22.3, 0, 1.95), Vector3(22.3, 0, 7.25)]:
		props.add_lamp(at)


static func _gardens(props: WorldProps) -> void:
	# Local seed keeps dressing stable without changing gameplay randomness.
	var garden_rng := RandomNumberGenerator.new()
	garden_rng.seed = 704
	var grass_variants: Array[String] = ["low", "seed", "fan"]
	for side: float in [-1.0, 1.0]:
		for index: int in range(90):
			var z := garden_rng.randf_range(6.1, 12.0)
			var x := side * garden_rng.randf_range(1.4, 3.5)
			props.add_grass_clump(Vector3(x, 0.01, z), grass_variants[index % 3], garden_rng.randf_range(0.00065, 0.00095))
		for index: int in range(60):
			var x := side * garden_rng.randf_range(5.7, 10.0)
			var z := garden_rng.randf_range(2.5, 3.2)
			props.add_grass_clump(Vector3(x, 0.01, z), grass_variants[index % 3], garden_rng.randf_range(0.00065, 0.00095))
	for fence_data: Array in [
		# Keep the garden-house doorway apron open; the fence borders its south bed.
		[Vector3(-8.4, 0.35, 2.3), Vector3(4.0, 0.7, 0.16)],
		[Vector3(8.2, 0.35, 1.8), Vector3(3.5, 0.7, 0.16)],
		[Vector3(-8.5, 0.35, 7.3), Vector3(3.8, 0.7, 0.16)],
		[Vector3(8.6, 0.35, 7.3), Vector3(3.2, 0.7, 0.16)],
	]:
		var fence_position: Vector3 = fence_data[0]
		var fence_size: Vector3 = fence_data[1]
		GardenFence.build(props.map_root, Vector3(fence_position.x, 0.0, fence_position.z), fence_size.x)
	var flower_variants: Array[String] = ["ivory", "mauve", "blue"]
	var flower_positions: Array[Vector3] = [
		Vector3(-7.4, 0.01, 2.35), Vector3(-8.2, 0.01, 2.55), Vector3(-9.1, 0.01, 2.3),
		Vector3(7.2, 0.01, 2.35), Vector3(8.1, 0.01, 2.55), Vector3(9.0, 0.01, 2.3),
		Vector3(-7.2, 0.01, 7.85), Vector3(-8.1, 0.01, 8.05), Vector3(7.5, 0.01, 7.8),
		Vector3(9.4, 0.01, 7.9), Vector3(-5.2, 0.01, -2.1), Vector3(5.3, 0.01, -1.9),
	]
	for flower_index: int in range(flower_positions.size()):
		props.add_flower_clump(flower_positions[flower_index], flower_variants[flower_index % flower_variants.size()])


static func _configure_surfaces(map_root: Node3D) -> void:
	var roads: Dictionary[String, String] = {
		"CentralPlaza": "plaza_rect", "NorthRoad": "north_rect",
		"MarketRoad": "market_rect", "GateRoad": "gate_rect",
	}
	var surfaces: Array[Node] = []
	for child: Node in map_root.get_children():
		if str(child.name) in ["Ground", "CentralPlaza", "NorthRoad", "MarketRoad", "GateRoad"] or child.is_in_group("village_garden_walks"):
			surfaces.append(child)
	for surface_root: Node in surfaces:
		var surface := surface_root.get_child(0) as MeshInstance3D
		var material := surface.material_override as ShaderMaterial
		material.set_shader_parameter("organic_village", true)
		for road_name: String in roads:
			var road := map_root.get_node(road_name) as Node3D
			var mesh := (road.get_child(0) as MeshInstance3D).mesh as BoxMesh
			material.set_shader_parameter(roads[road_name], Vector4(road.position.x, road.position.z, mesh.size.x * 0.5, mesh.size.z * 0.5))
