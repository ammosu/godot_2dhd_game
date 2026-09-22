extends RefCounted
## Original machiya-inspired exterior. Coordinates share the existing door/collision contract.
const ADDRESSES := ["house_city_01", "house_city_02", "house_city_06", "house_city_11", "house_city_13", "house_city_21", "house_city_22", "house_city_23"]

static func build(house: Node3D, variant: int) -> void:
	house.add_to_group("japanese_houses")
	var root := Node3D.new()
	root.name = "ArchitecturalDetails"
	house.add_child(root)
	var wood := material("timber_albedo.png", Color("685340"))
	var plaster := material("plaster_albedo.png", Color("ded4b8"))
	var stone := material("ruin_flagstone.png", Color("96928a"))
	var tile := material("slate_roof_albedo.png", Color("82919a"))
	var paper := material("linen_albedo.png", Color("efe0b6"))
	paper.emission_enabled = true
	paper.emission = Color("c49a5f")
	paper.emission_energy_multiplier = 0.22
	var cloth := material("linen_albedo.png", [Color("4d7883"), Color("9d6955"), Color("777e58")][variant % 3])
	box(root, "StoneFooting", Vector3(0, 0.17, 0), Vector3(4.18, 0.34, 3.42), stone)
	# Preserve the recessed opening for the inward-moving door and the approach animation.
	for side: float in [-1, 1]:
		box(root, "PlasterWing", Vector3(side * 1.205, 1.24, 0), Vector3(1.59, 2.08, 3.2), plaster)
	box(root, "DoorLintelWall", Vector3(0, 1.97, 0), Vector3(0.82, 0.62, 3.2), plaster)
	box(root, "DoorRecessBack", Vector3(0, 0.91, 0.41), Vector3(0.82, 1.42, 2.38), plaster)
	for x: float in [-1.98, -0.48, 0.48, 1.98]:
		for z: float in [-1.65, 1.65]:
			box(root, "TimberPost", Vector3(x, 1.23, z), Vector3(0.13, 2.13, 0.15), wood)
	for y: float in [0.38, 0.72, 1.96, 2.22]:
		for side: float in [-1, 1]:
			# Lower frontage is broken at the door instead of sealing its opening.
			if y < 1.8 and side < 0:
				for x: float in [-1.24, 1.24]:
					box(root, "FrontWainscotRail", Vector3(x, y, -1.68), Vector3(1.5, 0.10, 0.10), wood)
			else:
				box(root, "FacadeRail", Vector3(0, y, side * 1.68), Vector3(4.08, 0.10, 0.12), wood)
			box(root, "SideRail", Vector3(side * 2.02, y, 0), Vector3(0.13, 0.10, 3.4), wood)
	for side: float in [-1, 1]:
		for x: float in [-1.23, 1.23]:
			lattice(root, Vector3(x, 1.29, side * 1.73), 0, wood, paper)
		for z: float in [-0.82, 0.82]:
			lattice(root, Vector3(side * 2.06, 1.29, z), PI * 0.5, wood, paper)
		# Low boarding gives the house a dark, horizontal base.
		for board: int in range(10):
			box(root, "SideBoard", Vector3(side * 2.065, 0.52, -1.5 + board * 0.33), Vector3(0.05, 0.5, 0.30), wood)
	roof(root, tile, wood, plaster)
	preload("res://scripts/gameplay/house_details.gd")._build_door(root, wood)
	var leaf: Node3D = root.get_node("DoorHinge/DoorLeaf")
	# A lattice inset moves with the existing hinged leaf; no misleading sliding animation.
	box(leaf, "DoorPaper", Vector3(0, 1.06, -1.80), Vector3(0.59, 0.70, 0.022), paper)
	for index: int in range(5):
		box(leaf, "DoorLattice", Vector3(-0.28 + index * 0.14, 1.06, -1.82), Vector3(0.025, 0.74, 0.03), wood)
	for y: float in [0.70, 1.05, 1.42]:
		box(leaf, "DoorLattice", Vector3(0, y, -1.825), Vector3(0.62, 0.026, 0.035), wood)
	# Noren panels sit above head height, keeping the entrance readable and clear.
	box(root, "NorenRod", Vector3(0, 1.99, -1.94), Vector3(1.4, 0.04, 0.04), wood)
	for side: float in [-1, 1]:
		box(root, "NorenPanel", Vector3(side * 0.32, 1.80, -1.945), Vector3(0.60, 0.36, 0.018), cloth)
		box(root, "NorenEmblem", Vector3(side * 0.32, 1.81, -1.96), Vector3(0.09, 0.13, 0.012), paper)
	# A shallow side veranda does not introduce a step across the walk-in corridor.
	for x: float in [-1.28, 1.28]:
		box(root, "Engawa", Vector3(x, 0.18, -1.9), Vector3(1.36, 0.12, 0.45), wood)
	lantern(root, Vector3(1.77, 1.66, -1.99), wood, paper)
	box(root, "SignBoard", Vector3(-1.78, 1.35, -1.85), Vector3(0.22, 0.75, 0.07), wood)
	for y: float in [1.16, 1.35, 1.54]:
		box(root, "SignInlay", Vector3(-1.78, y, -1.89), Vector3(0.08, 0.09, 0.015), paper)

static func material(texture: String, tint: Color) -> StandardMaterial3D:
	var result := StandardMaterial3D.new()
	result.albedo_texture = load("res://assets/generated/" + texture) as Texture2D
	result.albedo_color = tint
	result.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	result.roughness = 0.93
	return result

static func box(parent: Node3D, label: String, at: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var visual := MeshInstance3D.new()
	visual.name = label
	var mesh := BoxMesh.new()
	mesh.size = size
	visual.mesh = mesh
	visual.position = at
	visual.material_override = material
	parent.add_child(visual)
	return visual

static func lattice(parent: Node3D, at: Vector3, yaw: float, wood: Material, paper: Material) -> void:
	var window := Node3D.new()
	window.name = "KoshiWindow"
	window.position = at
	window.rotation.y = yaw
	parent.add_child(window)
	box(window, "PaperPane", Vector3.ZERO, Vector3(1.04, 1.0, 0.04), paper)
	for column: int in range(9):
		box(window, "LatticeUpright", Vector3(-0.52 + column * 0.13, 0, 0), Vector3(0.028, 1.05, 0.10), wood)
	for y: float in [-0.51, -0.16, 0.18, 0.51]:
		box(window, "LatticeRail", Vector3(0, y, 0), Vector3(1.1, 0.045, 0.10), wood)

static func roof_height(t: float) -> float:
	return 3.30 - 1.25 * t + 0.25 * pow(t, 4)

static func roof(parent: Node3D, tile: Material, wood: Material, plaster: Material) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Broad ridge parallel to the street; gently lifted eaves, rather than temple-scale tips.
	for side: float in [-1, 1]:
		for column: int in range(26):
			for row: int in range(18):
				for corner: Vector2 in [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 0), Vector2(1, 1), Vector2(0, 1)]:
					var u: float = (column + corner.x) / 26.0
					var t: float = (row + corner.y) / 18.0
					surface.set_uv(Vector2(u * 2.0, t))
					surface.add_vertex(Vector3(lerpf(-2.48, 2.48, u), roof_height(t), side * t * 2.12))
	surface.generate_normals()
	var visual := MeshInstance3D.new()
	visual.name = "KawaraRoof"
	visual.mesh = surface.commit()
	var roof_material := tile.duplicate() as StandardMaterial3D
	roof_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	visual.material_override = roof_material
	parent.add_child(visual)
	# Barrel tile ribs follow the curved roof, batched into one mesh.
	var ribs := SurfaceTool.new()
	ribs.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side: float in [-1, 1]:
		for column: int in range(25):
			for row: int in range(12):
				for arc: int in range(4):
					for corner: Vector2 in [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 0), Vector2(1, 1), Vector2(0, 1)]:
						var angle: float = (arc + corner.x) * PI / 4.0
						var t: float = (row + corner.y * 0.93) / 12.0
						ribs.set_uv(Vector2(column / 12.0, t))
						ribs.add_vertex(Vector3(-2.35 + column * 0.196 + cos(angle) * 0.045, roof_height(t) + sin(angle) * 0.045 + 0.008, side * t * 2.12))
	ribs.generate_normals()
	var ribs_mesh := MeshInstance3D.new()
	ribs_mesh.name = "BarrelTileRows"
	ribs_mesh.mesh = ribs.commit()
	ribs_mesh.material_override = roof_material
	parent.add_child(ribs_mesh)
	for y: float in [3.30, 3.39]:
		box(parent, "RidgeCap", Vector3(0, y, 0), Vector3(5.04, 0.10, 0.18 if y > 3.35 else 0.32), tile)
	for side: float in [-1, 1]:
		box(parent, "EaveFascia", Vector3(0, 2.26, side * 2.10), Vector3(5.02, 0.12, 0.13), wood)
		for x: float in [-1.9, -1.5, -1.1, -0.7, -0.3, 0.3, 0.7, 1.1, 1.5, 1.9]:
			box(parent, "EaveRafter", Vector3(x, 2.22, side * 1.90), Vector3(0.09, 0.10, 0.55), wood)
		var gable := SurfaceTool.new()
		gable.begin(Mesh.PRIMITIVE_TRIANGLES)
		for i: int in range(12):
			var z0: float = -1.6 + i * 3.2 / 12.0
			var z1: float = z0 + 3.2 / 12.0
			for point: Vector2 in [Vector2(z0, 2.2), Vector2(z0, roof_height(absf(z0) / 2.12) - 0.035), Vector2(z1, roof_height(absf(z1) / 2.12) - 0.035), Vector2(z0, 2.2), Vector2(z1, roof_height(absf(z1) / 2.12) - 0.035), Vector2(z1, 2.2)]:
				gable.set_uv(Vector2(point.x, point.y))
				gable.add_vertex(Vector3(side * 2, point.y, point.x))
		gable.generate_normals()
		var gable_mesh := MeshInstance3D.new()
		gable_mesh.name = "GableWall"
		gable_mesh.mesh = gable.commit()
		var gable_material := plaster.duplicate() as StandardMaterial3D
		gable_material.cull_mode = BaseMaterial3D.CULL_DISABLED
		gable_mesh.material_override = gable_material
		parent.add_child(gable_mesh)
		box(parent, "GablePost", Vector3(side * 2.04, 2.72, 0), Vector3(0.10, 0.95, 0.12), wood)

static func lantern(parent: Node3D, at: Vector3, wood: Material, paper: Material) -> void:
	var body := MeshInstance3D.new()
	body.name = "PaperLantern"
	var globe := SphereMesh.new()
	globe.radius = 0.18
	globe.height = 0.48
	globe.radial_segments = 16
	globe.rings = 12
	body.mesh = globe
	body.position = at
	body.material_override = paper
	parent.add_child(body)
	for step: int in range(7):
		var y: float = -0.19 + step * 0.0633
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		var radius: float = sqrt(maxf(0.0, 1.0 - pow(y / 0.24, 2))) * 0.18
		torus.inner_radius = maxf(radius - 0.007, 0.01)
		torus.outer_radius = radius + 0.004
		torus.rings = 16
		torus.ring_segments = 4
		ring.mesh = torus
		ring.material_override = wood
		ring.position = at + Vector3.UP * y
		parent.add_child(ring)
	box(parent, "LanternHanger", at + Vector3(0, 0.36, 0.05), Vector3(0.04, 0.28, 0.04), wood)
