extends RefCounted
## Connected optional exploration maps; persistent event mutations live in GameState.

const NAMES := {"east_road": "東行舊道", "firefly_forest": "螢光森林"}
const EXITS := {
	"travel_east": ["village", "east_road", "from_village"],
	"travel_home": ["east_road", "village", "from_east_road"],
	"travel_forest": ["east_road", "firefly_forest", "from_road"],
	"travel_road": ["firefly_forest", "east_road", "from_forest"],
}
const EVENTS := {
	"road_sign": ["east_road", Vector3(-6, 0, 2), "扶正倒下的路標"],
	"road_traveler": ["east_road", Vector3(5, 0, 2), "與驛路旅人交談"],
	"forest_parcel": ["firefly_forest", Vector3(-7, 0, -3), "查看遺落的包裹"],
	"forest_herb": ["firefly_forest", Vector3(7, 0, -7), "採集月露草"],
	"forest_rest": ["firefly_forest", Vector3(0, 0, -11), "在螢光樹下休息"],
}

static func spawn(map_id: String, spawn_id: String) -> Vector3:
	if map_id == "east_road":
		return Vector3(0, 0.1, -10) if spawn_id == "from_forest" else Vector3(-12, 0.1, 5)
	return Vector3(0, 0.1, 11)


static func add_interaction(world: Node3D, id: String, prompt: String, at: Vector3, exit: bool = false) -> void:
	var area := Interactable3D.new()
	area.name = id
	area.interaction_id = id
	area.prompt_text = prompt
	area.position = at
	area.collision_layer = 8
	area.collision_mask = 0
	var collider := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.8
	collider.shape = shape
	collider.position.y = 0.6
	area.add_child(collider)
	area.activated.connect(world._handle_interaction)
	world.get("_map_root").add_child(area)
	var label := Label3D.new()
	label.text = prompt if exit else "!"
	label.font_size = 32
	label.pixel_size = 0.012
	label.position.y = 2.3 if exit else 1.8
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = Color("ffe29a") if exit else Color("64e6ff")
	area.add_child(label)
	if not exit:
		world.get("_quest_markers")[id] = label


static func build(world: Node3D, map_id: String) -> void:
	var forest := map_id == "firefly_forest"
	world._add_box("Ground", Vector3(0, -0.35, 0), Vector3(34, 0.7, 30), Color("304b48"), true)
	# Low banks seal the playable area; trees give the banks a natural silhouette.
	for x: float in [-16.5, 16.5]:
		world._add_box("WoodlandBank", Vector3(x, 0.4, 0), Vector3(1, 1.5, 30), Color("354840"), true)
	for z: float in [-14.5, 14.5]:
		world._add_box("WoodlandBank", Vector3(0, 0.4, z), Vector3(34, 1.5, 1), Color("354840"), true)
	world._add_cobble_box("WoodlandTrail", Vector3(0, 0.025, 0), Vector3(2.5, 0.07, 26), false)
	if not forest:
		world._add_cobble_box("CaravanRoad", Vector3(-4, 0.026, 5), Vector3(22, 0.07, 3), false)
		world._add_cobble_box("RestStop", Vector3(4, 0.025, 2), Vector3(7, 0.07, 7), false)
	else:
		world._add_cobble_box("ForagerTrail", Vector3(0, 0.026, -3), Vector3(18, 0.07, 1.6), false)
		world._add_cobble_box("HerbTrail", Vector3(7, 0.025, -5), Vector3(1.6, 0.07, 5), false)
		world._add_cobble_box("MoonClearing", Vector3(0, 0.024, -10), Vector3(6, 0.07, 5), false)
	for x: float in [-14, -10, -5, 5, 10, 14]:
		for z: float in [-12, -8, 0, 9, 12]:
			if not forest and absf(x) < 12 and z == 0:
				continue
			world._add_tree(Vector3(x, 0, z))
			var trunk := StaticBody3D.new()
			trunk.position = Vector3(x, 0.4, z)
			var trunk_shape := CollisionShape3D.new()
			var cylinder := CylinderShape3D.new()
			cylinder.radius = 0.22
			cylinder.height = 0.8
			trunk_shape.shape = cylinder
			trunk.add_child(trunk_shape)
			world.get("_map_root").add_child(trunk)
			if forest:
				world._add_grass_clump(Vector3(x + 0.7, 0.02, z + 0.8), "seed", 0.001)
	for at: Vector3 in [Vector3(-2, 0, 7), Vector3(2, 0, -4), Vector3(-2, 0, -10)]:
		world._add_lamp(at)
	if forest:
		world.get("_map_root").add_child(preload("res://scripts/gameplay/forest_fireflies.gd").new())
		world._add_supply_crate(Vector3(-7, 0, -3), 0.2)
		world._add_flower_clump(Vector3(7, 0, -7), "ivory")
		world._add_tree(Vector3(0, 0, -13))
		for at: Vector3 in [Vector3(-3, 0, -10), Vector3(3, 0, -10), Vector3(7.8, 0, -7.4)]:
			world._add_crystal(at, 0.45)
		add_interaction(world, "travel_road", "南行・返回東行舊道", Vector3(0, 0, 13), true)
	else:
		world._add_supply_crate(Vector3(7, 0, 3), 0.1)
		world._add_actor_interactable("road_traveler", "與驛路旅人交談", Vector3(5, 0, 2), "res://assets/generated/noah.tres", 1.6 / 724.0, Color("d3c5ac"), false, &"side")
		world._add_box("FallenSignPost", Vector3(-6, 0.4, 2), Vector3(0.18, 0.8, 0.18), Color("806247"), false)
		world._add_box("RoadSign", Vector3(-6, 0.9, 2), Vector3(1.5, 0.4, 0.15), Color("a88b60"), false)
		add_interaction(world, "travel_home", "西行・返回暮光村", Vector3(-14, 0, 5), true)
		add_interaction(world, "travel_forest", "北行・螢光森林", Vector3(0, 0, -12), true)
	for id: String in EVENTS:
		var event: Array = EVENTS[id]
		if event[0] == map_id and id != "road_traveler":
			add_interaction(world, id, event[2], event[1])

	configure_surfaces(world)


static func configure_surfaces(world: Node3D) -> void:
	var map: Node3D = world.get("_map_root")
	var paths: Array[Node3D] = []
	for node: Node in map.get_children():
		if node.name in ["WoodlandTrail", "CaravanRoad", "RestStop", "ForagerTrail", "HerbTrail", "MoonClearing"]:
			paths.append(node as Node3D)
	var uniforms: Array[String] = ["plaza_rect", "north_rect", "market_rect", "gate_rect"]
	for node: Node in map.get_children():
		if node.name != "Ground" and node not in paths:
			continue
		var mesh := node.get_child(0) as MeshInstance3D
		var material := mesh.material_override as ShaderMaterial
		material.set_shader_parameter("planted_island", false)
		for index: int in range(uniforms.size()):
			var path := paths[mini(index, paths.size() - 1)]
			var box := (path.get_child(0) as MeshInstance3D).mesh as BoxMesh
			material.set_shader_parameter(uniforms[index], Vector4(path.position.x, path.position.z, box.size.x * 0.5, box.size.z * 0.5))
