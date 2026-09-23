extends RefCounted
## Shared layout rectangles drive real collision and both map displays.
const EXIT := Vector3(-6, 0, 34.3)
const WALLS: Array[Rect2] = [
	# Central ossuary: a visitable dead-end room, with full routes on BOTH sides.
	Rect2(-3.8, 22, 0.65, 8), Rect2(3.15, 22, 0.65, 8),
	Rect2(-3.8, 22, 7.6, 0.65),
	Rect2(-3.8, 29.35, 2.5, 0.65), Rect2(1.3, 29.35, 2.5, 0.65),
	Rect2(-3.8, 17.5, 7.6, 0.65),
	# Side rooms open at z26; their doors reconnect to the shared ring corridor.
	Rect2(-9.5, 22, 0.65, 2.5), Rect2(-9.5, 27.5, 0.65, 3.5),
	Rect2(8.85, 22, 0.65, 2.5), Rect2(8.85, 27.5, 0.65, 3.5),
	Rect2(-14.5, 22, 5, 0.65), Rect2(-14.5, 30.35, 5, 0.65),
	Rect2(9.5, 22, 5, 0.65), Rect2(9.5, 30.35, 5, 0.65),
]
const LOWER_WALLS: Array[Rect2] = [
	Rect2(-3.5, 30.5, 7, 0.7),
	# Two burial islands leave west/east routes AND a middle connecting lane.
	Rect2(-8.5, 24, 5.5, 0.7), Rect2(-8.5, 24, 0.7, 4),
	Rect2(3, 24, 5.5, 0.7), Rect2(7.8, 24, 0.7, 4),
	Rect2(-2, 20, 4, 0.7), Rect2(-2, 20, 0.7, 5), Rect2(1.3, 20, 0.7, 5),
	Rect2(-0.35, 13.5, 0.7, 4),
	Rect2(-10, 17, 0.65, 3), Rect2(-10, 23, 0.65, 6),
	Rect2(9.35, 17, 0.65, 3), Rect2(9.35, 23, 0.65, 6),
	Rect2(-14.5, 17, 4.5, 0.65), Rect2(10, 17, 4.5, 0.65),
]

static func portal(world: Node3D, at: Vector3, id: String) -> void:
	var root: Node3D = world.get("_map_root")
	var veil := MeshInstance3D.new()
	veil.name = "CryptPortal"
	var plane := QuadMesh.new()
	plane.size = Vector2(2.44, 3.55)
	plane.orientation = PlaneMesh.FACE_Z
	veil.mesh = plane
	var surface := ShaderMaterial.new()
	surface.shader = preload("res://shaders/crypt_portal.gdshader")
	veil.material_override = surface
	veil.position = at + Vector3(0, 1.8, -0.16)
	root.add_child(veil)
	var light := OmniLight3D.new()
	light.position = at + Vector3(0, 1.6, 0.4)
	light.light_color = Color("63dfff")
	light.light_energy = 0.8
	light.omni_range = 5.0
	root.add_child(light)
	var exit := preload("res://scripts/gameplay/road_exit.gd").new()
	exit.name = id
	exit.interaction_id = id
	exit.prompt_text = ""
	exit.position = at
	exit.traveler = world.get_node("Player")
	exit.game_state = world.get_node("/root/GameState")
	exit.collision_layer = 8
	exit.collision_mask = 1
	exit.add_to_group("walking_exits")
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.2, 2.0, 0.65)
	collision.shape = shape
	collision.position.y = 0.8
	exit.add_child(collision)
	exit.activated.connect(world._handle_interaction)
	root.add_child(exit)

static func walls(second: bool = false) -> Array[Rect2]:
	return LOWER_WALLS if second else WALLS

static func build(world: Node3D, stone: Material, floor_stone: Material, detail: Material, second: bool = false) -> void:
	# Runtime load avoids cyclic preloads between the hall and its modular extension.
	var crypt: GDScript = load("res://scripts/gameplay/ashen_crypt.gd")
	var root: Node3D = world.get("_map_root")
	crypt.box(root, Vector3(0, -0.2, 23.5), Vector3(29, 0.4, 25), floor_stone, true, "MazeFloor")
	crypt.flagstones(root, floor_stone, 11.25, 20, 14.5)
	var cap: ShaderMaterial = stone.duplicate() as ShaderMaterial
	cap.set_shader_parameter("tint", Color(0.65, 0.72, 0.82))
	for side: float in [-1, 1]:
		crypt.box(root, Vector3(side * 14.5, 0.95, 23.5), Vector3(0.5, 1.9, 25), stone, true, "MazeBoundary")
		crypt.box(root, Vector3(side * 8.4, 0.65, 35.7), Vector3(12.6, 1.3, 0.6), stone, true, "PortalEnclosure")
	crypt.box(root, Vector3(0, 0.65, 35.7), Vector3(4.2, 1.3, 0.6), stone, true, "SouthBoundary")
	var sign: float = -1.0 if second else 1.0
	var exit_at := Vector3(EXIT.x * sign, 0, EXIT.z)
	crypt.arch(root, exit_at, 2.5, stone)
	portal(world, exit_at, "crypt_ascend" if second else "leave_crypt")
	for x: float in [-8.1, -3.9]:
		crypt.brazier(root, Vector3(x * sign, 0, 34.3), stone, detail)
	for rect: Rect2 in walls(second):
		var center := rect.get_center()
		crypt.box(root, Vector3(center.x, 0.65, center.y), Vector3(rect.size.x, 1.3, rect.size.y), stone, true, "MazePartition")
		crypt.box(root, Vector3(center.x, 1.38, center.y), Vector3(rect.size.x + 0.22, 0.24, rect.size.y + 0.22), cap)
		if rect.size.x > 3:
			for x: float in [center.x]:
				for side: float in [-1, 1]:
					for flank: float in [-1, 1]:
						crypt.box(root, Vector3(x + flank * 1.1, 0.73, center.y + side * 0.44), Vector3(0.32, 1.46, 0.46), stone)
					crypt.box(root, Vector3(x, 0.72, center.y + side * 0.415), Vector3(1.7, 1.05, 0.035), detail)
			for x: float in [rect.position.x + 0.35, rect.end.x - 0.35]:
				crypt.box(root, Vector3(x, 0.78, center.y), Vector3(0.95, 1.56, 1.05), detail, true, "MazeEndPier")
				crypt.candles(root, Vector3(x, 1.56, center.y))
			var votive := OmniLight3D.new()
			votive.position = Vector3(center.x, 1.8, center.y + 1.0)
			votive.light_color = Color("ffc17b")
			votive.light_energy = 0.7
			votive.omni_range = 4.5
			root.add_child(votive)
	for at: Vector3 in [Vector3(-7, 0, 32), Vector3(7, 0, 32), Vector3(-7, 0, 18.8), Vector3(7, 0, 18.8), Vector3(-12.5, 0, 28.8), Vector3(12.5, 0, 28.8)]:
		crypt.brazier(root, Vector3(at.x * sign, at.y, at.z), stone, detail)
	for at: Vector3 in [Vector3(0, 0, 24), Vector3(-12.5, 0, 23.8), Vector3(11, 0, 23.8)]:
		at.x *= sign
		crypt.box(root, at + Vector3.UP * 0.3, Vector3(1.4, 0.6, 1.1), detail, true, "BurialNiche")
		crypt.box(root, at + Vector3.UP * 0.65, Vector3(1.6, 0.12, 1.3), cap)
		crypt.candles(root, at + Vector3.UP * 0.72)
		crypt.urn(root, at + Vector3(1.4, 0, 0), stone)
	# Discrete moonstone inlays identify the safe bends without drawing an arrow trail.
	var rune := StandardMaterial3D.new()
	rune.albedo_color = Color("5bafb6")
	rune.emission_enabled = true
	rune.emission = Color("3aa1af")
	rune.emission_energy_multiplier = 1.5
	for at: Vector3 in [Vector3(-6, 0.065, 29), Vector3(6, 0.065, 29), Vector3(-6, 0.065, 20), Vector3(6, 0.065, 20), Vector3(0, 0.065, 13)]:
		at.x *= sign
		for i: int in range(4):
			var angle: float = PI / 4 + i * PI / 2
			var offset := Vector3(cos(angle), 0, sin(angle)) * 0.22
			var mark: MeshInstance3D = crypt.box(root, at + offset, Vector3(0.44, 0.025, 0.06), rune)
			mark.rotation.y = -angle + PI / 2
		crypt.box(root, at, Vector3(0.09, 0.025, 0.09), rune)

	# A separate northern stair threshold is the only route to the next level.
	crypt.box(root, Vector3(0, 1.0, 10.7), Vector3(29, 2.0, 0.6), stone, true, "StairBackWall")
	crypt.arch(root, Vector3(0, 0, 11.8), 2.5, stone)
	portal(world, Vector3(0, 0, 11.8), "crypt_boss_door" if second else "crypt_descend")
	var label := Label3D.new()
	label.font = world.get_node("/root/GameState").ui_theme.default_font
	label.text = "燼冠王座 ↓" if second else "B2・沉灰牢廊 ↓"
	label.position = Vector3(0, 3.9, 11.8)
	label.font_size = 40
	label.pixel_size = 0.012
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	root.add_child(label)

	# Discoverable landmarks give the branches different purposes.
	crypt.interaction(world, "crypt_cache_2" if second else "crypt_spring_1", "開啟・守衛補給箱" if second else "飲用・月露泉（一次恢復）", Vector3(12, 0, 26) if second else Vector3(-12, 0, 26))
	crypt.interaction(world, "crypt_lore_2" if second else "crypt_lore_1", "閱讀・墓窟銘文", Vector3(-12, 0, 21) if second else Vector3(12, 0, 26))
	var landmark := Vector3(12, 0, 26) if second else Vector3(-12, 0, 26)
	crypt.box(root, landmark + Vector3.UP * 0.28, Vector3(1.2, 0.56, 0.9), detail, true, "SupplyChest" if second else "Moonwell")
	if not second:
		var water := StandardMaterial3D.new()
		water.albedo_color = Color("49aebb")
		water.emission_enabled = true
		water.emission = Color("246d87")
		crypt.box(root, landmark + Vector3.UP * 0.57, Vector3(0.95, 0.035, 0.65), water)
	var names: Array = ["西・封印書庫", "中央・囚魂井", "東・守衛庫房"] if second else ["西・月露泉", "中央・先祖墓室", "東・銘文室"]
	for i: int in range(3):
		var place := Label3D.new()
		place.font = world.get_node("/root/GameState").ui_theme.default_font
		place.text = names[i]
		place.position = Vector3((i - 1) * 11.5, 2.4, 27)
		place.font_size = 30
		place.pixel_size = 0.009
		place.modulate = Color("cdbb9a")
		place.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		root.add_child(place)

	if second:
		var soul := MeshInstance3D.new()
		soul.name = "PrisonSoulCrystal"
		soul.mesh = crypt.faceted_crystal()
		var glow := StandardMaterial3D.new()
		glow.albedo_color = Color("62bed0")
		glow.emission_enabled = true
		glow.emission = Color("237d96")
		glow.emission_energy_multiplier = 1.8
		soul.material_override = glow
		soul.position = Vector3(0, 1.35, 24)
		root.add_child(soul)
		for x: float in [-13.2, -12, -10.8]:
			crypt.box(root, Vector3(x, 0.75, 18.5), Vector3(0.75, 1.5, 0.35), detail, true, "SealedArchiveTablet")
