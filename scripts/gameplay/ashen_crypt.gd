extends RefCounted
## Original modular dungeon: real floor/wall collision, open sightlines, existing field combat.
const Layout = preload("res://scripts/gameplay/crypt_layout.gd")
const Maze = preload("res://scripts/gameplay/crypt_maze.gd")
const MATERIAL_PATH: String = "res://assets/generated/dungeon/crypt_materials.png"

static func material(quadrant: Vector2, density: float = 0.32, panel: bool = false) -> ShaderMaterial:
	var result := ShaderMaterial.new()
	result.shader = preload("res://shaders/crypt_stone.gdshader")
	result.set_shader_parameter("atlas", load(MATERIAL_PATH))
	result.set_shader_parameter("quadrant", quadrant)
	result.set_shader_parameter("scale_uv", density)
	result.set_shader_parameter("panel", panel)
	result.set_shader_parameter("panel_tiles", Vector2(3, 2) if panel else Vector2.ONE)
	return result

static func box(parent: Node3D, at: Vector3, size: Vector3, surface: Material, solid: bool = false, label: String = "Masonry") -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = label
	node.position = at
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.material_override = surface
	parent.add_child(node)
	if solid:
		var body := StaticBody3D.new()
		node.add_child(body)
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		collision.shape = shape
		body.add_child(collision)
	return node

static func arch(parent: Node3D, at: Vector3, width: float, surface: Material, yaw: float = 0.0) -> void:
	var root := Node3D.new()
	root.name = "VoussoirArch"
	root.position = at
	root.rotation.y = yaw
	parent.add_child(root)
	for side: float in [-1, 1]:
		box(root, Vector3(side * (width * 0.5 + 0.28), 1.15, 0), Vector3(0.56, 2.3, 0.78), surface, true)
		box(root, Vector3(side * (width * 0.5 + 0.28), 0.12, 0), Vector3(0.82, 0.24, 1.0), surface)
		box(root, Vector3(side * (width * 0.5 + 0.28), 2.24, 0), Vector3(0.86, 0.24, 1.0), surface)
	# Trapezoidal voussoirs, actual open arch rather than a rectangular lintel.
	for segment: int in range(13):
		var mesh := ImmediateMesh.new()
		mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
		var a: float = float(segment) * PI / 13.0 + 0.006
		var b: float = float(segment + 1) * PI / 13.0 - 0.006
		var corners: Array[Vector3] = []
		for z: float in [-0.39, 0.39]:
			for pair: Vector2 in [Vector2(a, width * 0.5), Vector2(b, width * 0.5), Vector2(b, width * 0.5 + 0.56), Vector2(a, width * 0.5 + 0.56)]:
				corners.append(Vector3(cos(pair.x) * pair.y, 2.3 + sin(pair.x) * pair.y, z))
		for face: Array in [[0, 3, 2, 1], [4, 5, 6, 7], [0, 4, 7, 3], [1, 2, 6, 5], [0, 1, 5, 4], [3, 7, 6, 2]]:
			var normal: Vector3 = (corners[face[1]] - corners[face[0]]).cross(corners[face[2]] - corners[face[0]]).normalized()
			for index: int in [0, 1, 2, 0, 2, 3]:
				mesh.surface_set_normal(normal)
				mesh.surface_add_vertex(corners[face[index]])
		mesh.surface_end()
		var stone := MeshInstance3D.new()
		stone.mesh = mesh
		stone.material_override = surface
		root.add_child(stone)

static func brazier(parent: Node3D, at: Vector3, stone: Material, detail: Material) -> void:
	box(parent, at + Vector3.UP * 0.12, Vector3(1.0, 0.24, 1.0), stone, true, "BrazierFoot")
	box(parent, at + Vector3.UP * 0.55, Vector3(0.72, 0.7, 0.72), detail, true, "CarvedBrazier")
	box(parent, at + Vector3.UP * 0.96, Vector3(1.0, 0.16, 1.0), stone)
	var fire := preload("res://scripts/gameplay/hearth_fire.gd").new()
	fire.position = at + Vector3.UP * 1.05
	fire.scale = Vector3.ONE * 0.62
	parent.add_child(fire)
	var firelight: OmniLight3D = fire.get_node("Firelight")
	firelight.omni_range = 8.0
	var iron := StandardMaterial3D.new()
	iron.albedo_color = Color("211d1c")
	iron.metallic = 0.7
	iron.roughness = 0.6
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.33
	torus.outer_radius = 0.40
	ring.mesh = torus
	ring.material_override = iron
	ring.position = at + Vector3.UP * 1.24
	parent.add_child(ring)
	for i: int in range(8):
		var angle: float = i * TAU / 8.0
		box(parent, at + Vector3(cos(angle) * 0.36, 1.19, sin(angle) * 0.36), Vector3(0.04, 0.3, 0.04), iron)

static func candles(parent: Node3D, at: Vector3) -> void:
	var wax := StandardMaterial3D.new()
	wax.albedo_color = Color("c8b590")
	var ember := StandardMaterial3D.new()
	ember.albedo_color = Color("ffce7b")
	ember.emission_enabled = true
	ember.emission = Color("ff9e38")
	ember.emission_energy_multiplier = 2.0
	for i: int in range(3):
		var height: float = 0.20 + i * 0.105
		var offset := Vector3((i - 1) * 0.16, 0, 0.06 if i == 1 else 0)
		box(parent, at + offset + Vector3.UP * height / 2, Vector3(0.07, height, 0.07), wax)
		var flame := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radius = 0.035
		mesh.height = 0.15
		flame.mesh = mesh
		flame.material_override = ember
		flame.position = at + offset + Vector3.UP * (height + 0.07)
		parent.add_child(flame)

static func interaction(world: Node3D, id: String, prompt: String, at: Vector3) -> void:
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

static func build_entrance(world: Node3D) -> void:
	var root: Node3D = world.get("_map_root")
	var stone := material(Vector2(1, 0), 0.5)
	var detail := material(Vector2(0, 1), 1, true)
	arch(root, Vector3(-8, 0, -1.8), 2.5, stone)
	Maze.portal(world, Vector3(-8, 0, -1.8), "enter_crypt")
	for side: float in [-1, 1]:
		brazier(root, Vector3(-8 + side * 2.25, 0, -0.8), stone, detail)


static func build(world: Node3D) -> void:
	var root: Node3D = world.get("_map_root")
	var stone := material(Vector2(1, 0), 0.22)
	stone.set_shader_parameter("dampness", 0.8)
	var floor_stone := material(Vector2.ZERO, 0.25)
	floor_stone.set_shader_parameter("dampness", 0.65)
	floor_stone.set_shader_parameter("tint", Color(0.87, 0.94, 1.12))
	var detail := material(Vector2(0, 1), 1, true)
	var cloth := material(Vector2(1, 1), 1, true)
	cloth.set_shader_parameter("panel_tiles", Vector2.ONE)
	box(root, Vector3(0, -0.2, -1), Vector3(19, 0.4, 24), floor_stone, true, "CryptFloor")
	flagstones(root, floor_stone)
	box(root, Vector3(0, 2.3, -12.7), Vector3(19, 4.6, 0.7), stone, true, "ApseWall")
	for side: float in [-1, 1]:
		box(root, Vector3(side * 9.25, 1.2, -1), Vector3(0.5, 2.4, 24), stone, true, "SideWall")
		var foreground := material(Vector2(1, 0), 0.22)
		foreground.set_shader_parameter("tint", Color(0.42, 0.45, 0.50))
		box(root, Vector3(side * 7.2, 1.1, 5.0), Vector3(4.0, 2.2, 1.0), foreground, true, "CutawayButtress")
		box(root, Vector3(side * 7.2, 2.26, 5.0), Vector3(4.2, 0.14, 1.15), foreground)
		box(root, Vector3(side * 5.65, 0.45, 10.7), Vector3(7, 0.9, 0.6), stone, true, "CutawayWall")
		for bay_z: float in [-6.7, -1.7]:
			arch(root, Vector3(side * 7.25, 0, bay_z), 3.8, stone, PI / 2)
			box(root, Vector3(side * 7.6, 1.55, bay_z), Vector3(0.4, 3.1, 4.7), foreground, true, "RecessBackWall")
			for end: float in [-2.2, 2.2]:
				box(root, Vector3(side * 6.7, 1.45, bay_z + end), Vector3(2.2, 2.9, 0.45), stone, true, "VaultReturnWall")
				for ledge: float in [0.15, 2.95]:
					box(root, Vector3(side * 6.7, ledge, bay_z + end), Vector3(2.38, 0.2, 0.65), stone)
				box(root, Vector3(side * 6.7, 1.5, bay_z + end + 0.24), Vector3(1.25, 1.95, 0.03), detail)
		for z: float in [-8.5, -3.5, 1.5]:
			# Cut the nearest arcade away as one architectural bay, revealing tombs.
			if z < 1.5:
				arch(root, Vector3(side * 4.65, 0, z), 4.4, stone, PI / 2)
				box(root, Vector3(side * 4.65, 1.6, z + 2.5), Vector3(1.05, 3.2, 1.05), stone, true, "NavePier")
				for height: float in [0.16, 0.4, 3.0, 3.3]:
					box(root, Vector3(side * 4.65, height, z + 2.5), Vector3(1.34, 0.16, 1.34), stone)
				banner(root, Vector3(side * 4.65, 2.85, z + 3.15), cloth)
			var tomb: Vector3 = Vector3(side * 5.95, 0, z + 1.8)
			box(root, tomb + Vector3.UP * 0.38, Vector3(1.45, 0.76, 2.8), detail, true, "Sarcophagus")
			box(root, tomb + Vector3.UP * 0.83, Vector3(1.64, 0.16, 3.0), stone)
			box(root, tomb + Vector3.UP * 0.94, Vector3(0.85, 0.12, 2.0), detail)
			candles(root, tomb + Vector3(0.48, 0.93, 1.1))
			effigy(root, tomb + Vector3.UP * 1.02, stone)
		urn(root, Vector3(side * 4.85, 0.05, 2.5), stone)
		for z: float in [-8, 0.7]:
			brazier(root, Vector3(side * 3.75, 0, z), stone, detail)
	# Low altar retains a flat, accessible battle floor; decorated dais edges are visual only.
	box(root, Vector3(0, 0.10, -10.6), Vector3(5.6, 0.20, 2.3), stone)
	box(root, Vector3(0, 0.6, -11), Vector3(3.6, 1.0, 1.15), detail, true, "BloodAltar")
	box(root, Vector3(0, 1.16, -11), Vector3(4, 0.16, 1.5), stone)
	for x: float in [-1.35, 1.35]:
		candles(root, Vector3(x, 1.25, -10.7))
	arch(root, Vector3(0, 0, -12.3), 4, stone)
	banner(root, Vector3(0, 4.0, -12.23), cloth)
	var crystal := MeshInstance3D.new()
	crystal.name = "BloodCrystal"
	crystal.mesh = faceted_crystal()
	var red := ShaderMaterial.new()
	red.shader = preload("res://shaders/crypt_crystal.gdshader")
	crystal.material_override = red
	crystal.position = Vector3(0, 1.85, -11)
	root.add_child(crystal)
	for i: int in range(3):
		var shard: MeshInstance3D = crystal.duplicate() as MeshInstance3D
		shard.scale = Vector3.ONE * (0.33 + i * 0.08)
		shard.position = Vector3(-0.6 + i * 0.6, 1.5, -10.8)
		shard.rotation = Vector3(0.1, i * 0.9, -0.2 + i * 0.2)
		root.add_child(shard)
	var glow := OmniLight3D.new()
	glow.position = Vector3(0, 2.4, -10)
	glow.light_color = Color("f2493f")
	glow.light_energy = 1.5
	glow.omni_range = 6
	root.add_child(glow)
	var glint := OmniLight3D.new()
	glint.position = Vector3(-0.8, 3.1, -10.3)
	glint.light_color = Color("ffe1e4")
	glint.light_energy = 1.5
	glint.omni_range = 2.5
	root.add_child(glint)
	for radius: float in [2.5, 2.85]:
		var ring := preload("res://scripts/gameplay/combat_ground_ring.gd").new()
		ring.configure(radius, Color("983b36"), 0.035)
		ring.position = Vector3(0, 0.035, -9.4)
		root.add_child(ring)
	var rng := RandomNumberGenerator.new()
	rng.seed = 92326
	for i: int in range(100):
		var at := Vector3(rng.randf_range(-8.8, 8.8), 0.04, rng.randf_range(-12, 10))
		if absf(at.x) < 3.8:
			continue
		var fragment := box(root, at, Vector3(rng.randf_range(0.08, 0.27), 0.08, rng.randf_range(0.1, 0.34)), stone, false, "FallenMasonry")
		fragment.rotation.y = rng.randf_range(0, TAU)
	Maze.portal(world, Vector3(0, 0, 10), "crypt_boss_return")
	interaction(world, "crypt_reliquary", "調查・血晶祭壇", Vector3(0, 0, -9.25))
	# The southern entry has cut-away piers so its arch cannot cover gameplay.
	for x: float in [-2.15, 2.15]:
		box(root, Vector3(x, 0.6, 10.7), Vector3(0.8, 1.2, 0.9), stone, true, "ExitPier")

	var field := preload("res://scripts/gameplay/crypt_boss_combat.gd").new()
	field.name = "FieldCombat"
	field.player = world.get_node("Player")
	field.spawn_list = [{"id": Layout.BOSS_ID, "at": Vector3(0, 0.05, -5), "caster": false, "art": "guardian"}]
	field.build_terrain = false
	field.compact_hud = true
	field.camera_distance = 20.0
	field.area_title = "灰燼墓窟"
	field.recovery_map = "east_road"
	field.recovery_spawn = "from_crypt"
	field.navigation.origin = Vector2(-8.5, -12)
	field.navigation.grid_size = Vector2i(35, 46)
	root.add_child(field)
	preload("res://scripts/gameplay/crypt_dampness.gd").build(world, world.get_node("/root/GameState").current_map)

static func effigy(parent: Node3D, at: Vector3, stone: Material) -> void:
	# One batched carved effigy per lid; small rounded ribs and articulated limbs.
	var bone: ShaderMaterial = stone.duplicate() as ShaderMaterial
	bone.set_shader_parameter("tint", Color(1.9, 1.7, 1.4))
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var skull := SphereMesh.new()
	skull.radius = 0.21
	skull.height = 0.36
	skull.radial_segments = 10
	skull.rings = 5
	tool.append_from(skull, 0, Transform3D(Basis.IDENTITY, Vector3(0, 0.15, -0.67)))
	var jaw := BoxMesh.new()
	jaw.size = Vector3(0.25, 0.10, 0.18)
	tool.append_from(jaw, 0, Transform3D(Basis.IDENTITY, Vector3(0, 0.10, -0.46)))
	append_bone(tool, Vector3(0, 0.09, -0.44), Vector3(0, 0.09, 0.35), 0.06)
	for side: float in [-1, 1]:
		append_bone(tool, Vector3(0, 0.12, -0.30), Vector3(side * 0.34, 0.1, -0.30), 0.045)
		append_bone(tool, Vector3(side * 0.34, 0.1, -0.30), Vector3(side * 0.36, 0.09, 0.1), 0.047)
		append_bone(tool, Vector3(side * 0.36, 0.09, 0.1), Vector3(side * 0.19, 0.14, 0.35), 0.04)
		append_bone(tool, Vector3(0, 0.09, 0.3), Vector3(side * 0.15, 0.08, 0.4), 0.08)
		append_bone(tool, Vector3(side * 0.15, 0.08, 0.4), Vector3(side * 0.16, 0.09, 0.74), 0.058)
		append_bone(tool, Vector3(side * 0.16, 0.09, 0.76), Vector3(side * 0.14, 0.06, 1.06), 0.038)
		for rib: int in range(5):
			var z: float = -0.32 + rib * 0.12
			var points: Array[Vector3] = [Vector3(0, 0.10, z), Vector3(side * 0.17, 0.19, z + 0.02), Vector3(side * 0.25, 0.13, z + 0.07), Vector3(side * 0.16, 0.08, z + 0.13)]
			for i: int in range(3):
				append_bone(tool, points[i], points[i + 1], 0.027)
	var figure := MeshInstance3D.new()
	figure.mesh = tool.commit()
	figure.material_override = bone
	figure.position = at
	parent.add_child(figure)
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color("171819")
	for x: float in [-0.08, 0.08]:
		var socket := box(parent, at + Vector3(x, 0.32, -0.62), Vector3(0.08, 0.025, 0.095), dark)
		socket.rotation.y = x * 2.0

static func append_bone(tool: SurfaceTool, a: Vector3, b: Vector3, radius: float) -> void:
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = radius * 0.82
	cylinder.bottom_radius = radius
	cylinder.height = a.distance_to(b)
	cylinder.radial_segments = 6
	cylinder.rings = 1
	var basis := Basis(Quaternion(Vector3.UP, (b - a).normalized()))
	tool.append_from(cylinder, 0, Transform3D(basis, (a + b) * 0.5))


static func banner(parent: Node3D, at: Vector3, cloth: Material) -> void:
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var columns: int = 12
	for i: int in range(columns):
		var u: float = float(i) / columns
		var v: float = float(i + 1) / columns
		var points: Array[Vector3] = []
		for uv: Vector2 in [Vector2(u, 0), Vector2(v, 0), Vector2(v, 1), Vector2(u, 1)]:
			var bottom: float = 0.18 * sin(uv.x * 31) + 0.11 * cos(uv.x * 47)
			points.append(Vector3((uv.x - 0.5) * 0.94, -uv.y * (2.35 + bottom), sin(uv.x * TAU * 3) * 0.065))
		var uvs: Array[Vector2] = [Vector2(u, 0), Vector2(v, 0), Vector2(v, 1), Vector2(u, 1)]
		for j: int in [0, 1, 2, 0, 2, 3]:
			mesh.surface_set_normal(Vector3.BACK)
			mesh.surface_set_uv(uvs[j])
			mesh.surface_add_vertex(points[j])
	mesh.surface_end()
	var flag := MeshInstance3D.new()
	flag.mesh = mesh
	flag.material_override = cloth
	flag.position = at
	parent.add_child(flag)
	var gold := StandardMaterial3D.new()
	gold.albedo_color = Color("b88c57")
	gold.metallic = 0.45
	gold.roughness = 0.75
	for quadrant: int in range(4):
		var angle: float = quadrant * PI / 2.0
		var offset := Vector3(sin(angle) * 0.14, cos(angle) * 0.14 - 1.2, 0.09)
		var stitch := box(parent, at + offset, Vector3(0.028, 0.24, 0.022), gold, false, "BannerSigil")
		stitch.rotation.z = -angle + PI / 4.0

static func flagstones(parent: Node3D, surface: Material, start_z: float = -12.5, rows: int = 19, half_width: float = 9.0) -> void:
	# One batched mesh: bevelled chipped slabs with deliberate broad tonal variation.
	var rng := RandomNumberGenerator.new()
	rng.seed = 73092
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row: int in range(rows):
		var z: float = start_z + row * 1.25
		var x: float = -half_width
		while x < half_width - 0.05:
			var width: float = minf(rng.randf_range(1.2, 2.2), half_width - x)
			if width < 0.1:
				break
			var height: float = rng.randf_range(0.025, 0.05)
			var chip: float = rng.randf_range(0.08, 0.18)
			var polygon: Array[Vector2] = [Vector2(x + chip, z + 0.025), Vector2(x + width - 0.04, z + 0.025), Vector2(x + width - 0.025, z + 1.1), Vector2(x + width - chip, z + 1.22), Vector2(x + 0.025, z + 1.2), Vector2(x + 0.025, z + chip)]
			var center := Vector2(x + width * 0.5, z + 0.625)
			var color := Color.from_hsv(0.60, rng.randf_range(0.02, 0.10), rng.randf_range(0.76, 1.10))
			for i: int in range(polygon.size()):
				var next: int = (i + 1) % polygon.size()
				tool.set_color(color)
				tool.set_normal(Vector3.UP)
				for point: Vector2 in [center, polygon[i], polygon[next]]:
					tool.add_vertex(Vector3(point.x, height, point.y))
				var edge: Vector2 = (polygon[next] - polygon[i]).normalized()
				tool.set_normal(Vector3(edge.y, 0.7, -edge.x).normalized())
				for index: int in [0, 1, 2, 0, 2, 3]:
					var end: Vector2 = polygon[i] if index in [0, 3] else polygon[next]
					var rim: Vector2 = end + (end - center).normalized() * (0.02 if index >= 2 else 0)
					tool.add_vertex(Vector3(rim.x, height if index < 2 else 0.005, rim.y))
			x += width
	var slabs := MeshInstance3D.new()
	slabs.name = "ChippedFlagstones"
	slabs.mesh = tool.commit()
	slabs.material_override = surface
	parent.add_child(slabs)


static func faceted_crystal() -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var profile: Array[Vector2] = [Vector2(-0.65, 0), Vector2(-0.28, 0.32), Vector2(0.38, 0.26), Vector2(0.80, 0)]
	for ring: int in range(profile.size() - 1):
		for i: int in range(6):
			var a: float = i * TAU / 6.0 + 0.18
			var b: float = (i + 1) * TAU / 6.0 + 0.18
			var points: Array[Vector3] = []
			for value: Vector2 in [profile[ring], profile[ring + 1]]:
				for angle: float in [a, b]:
					points.append(Vector3(cos(angle) * value.y, value.x, sin(angle) * value.y))
			var shades: Array[float] = [0.95, 0.40, 0.75, 0.30, 0.90, 0.55]
			tool.set_color(Color(shades[i], shades[i], shades[i]))
			for index: int in [0, 2, 1, 1, 2, 3]:
				tool.add_vertex(points[index])
	tool.generate_normals()
	return tool.commit()


static func urn(parent: Node3D, at: Vector3, stone: Material) -> void:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var profile: Array[Vector2] = [Vector2(0, 0.20), Vector2(0.10, 0.25), Vector2(0.46, 0.33), Vector2(0.70, 0.20), Vector2(0.80, 0.17), Vector2(0.85, 0.21)]
	for ring: int in range(profile.size() - 1):
		for segment: int in range(12):
			var a: float = segment * TAU / 12.0
			var b: float = (segment + 1) * TAU / 12.0
			var points: Array[Vector3] = []
			for value: Vector2 in [profile[ring], profile[ring + 1]]:
				for angle: float in [a, b]:
					points.append(Vector3(cos(angle) * value.y, value.x, sin(angle) * value.y))
			for index: int in [0, 2, 1, 1, 2, 3]:
				tool.add_vertex(points[index])
	tool.generate_normals()
	var visual := MeshInstance3D.new()
	visual.name = "FuneraryUrn"
	visual.mesh = tool.commit()
	visual.material_override = stone
	visual.position = at
	parent.add_child(visual)
	var body := StaticBody3D.new()
	visual.add_child(body)
	var collider := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.31
	shape.height = 0.85
	collider.shape = shape
	collider.position.y = 0.425
	body.add_child(collider)


static func build_floor(world: Node3D, id: String) -> void:
	var root: Node3D = world.get("_map_root")
	var second: bool = id == "ashen_crypt_2"
	var stone := material(Vector2(1, 0), 0.22)
	stone.set_shader_parameter("dampness", 0.8)
	var floor_stone := material(Vector2.ZERO, 0.25)
	floor_stone.set_shader_parameter("dampness", 0.65)
	stone.set_shader_parameter("tint", Color(0.76, 0.83, 1.05) if second else Color.WHITE)
	floor_stone.set_shader_parameter("tint", Color(0.78, 0.87, 1.15) if second else Color(0.87, 0.94, 1.12))
	Maze.build(world, stone, floor_stone, material(Vector2(0, 1), 1, true), second)
	var field := preload("res://scripts/gameplay/field_combat.gd").new()
	field.name = "FieldCombat"
	field.player = world.get_node("Player")
	field.spawn_list.assign(Layout.FLOOR_SPAWNS[id].duplicate(true))
	field.build_terrain = false
	field.compact_hud = true
	field.camera_distance = 20.0
	field.area_title = Layout.NAMES[id]
	field.recovery_map = "east_road"
	field.recovery_spawn = "from_crypt"
	field.navigation.origin = Vector2(-14, 11.5)
	field.navigation.grid_size = Vector2i(57, 48)
	root.add_child(field)
	preload("res://scripts/gameplay/crypt_dampness.gd").build(world, world.get_node("/root/GameState").current_map)
