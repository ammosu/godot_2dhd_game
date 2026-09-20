extends Node3D
## Walkable, roofless domestic rooms. Near-side wall visuals cut away on orbit;
## their collision remains solid. All furniture is built in local meters.

signal interaction_requested(interaction_id: String)
const Footsteps = preload("res://scripts/gameplay/footsteps.gd")
const Dressing = preload("res://scripts/gameplay/house_dressing.gd")

var house_id: String = "house_01"
var _walls: Array[Node3D] = []
var _normals: Array[Vector3] = []


func _ready() -> void:
	var wood := _material("timber_albedo.png", Color("baa28a"))
	var plaster := _material("plaster_albedo.png", Color("ddd2b9"))
	var stone := _material("ruin_flagstone.png", Color("8c8790"))
	var linen := _material("linen_albedo.png", Color("eee0cb"))
	var blanket := _material("linen_albedo.png", Color("62969e") if int(house_id.right(2)) % 2 == 0 else Color("b77782"))
	linen.uv1_scale = Vector3(2, 2, 1)
	blanket.uv1_scale = Vector3(2, 2, 1)
	_box(self, "Foundation", Vector3(0, -0.17, 0), Vector3(8.3, 0.32, 7.3), stone, false)
	# Separate boards expose narrow dark joints while sharing one collision slab.
	var floor_body := _box(self, "FloorCollision", Vector3(0, -0.076, 0), Vector3(8, 0.20, 7), wood, true, false)
	Footsteps.register_surface(floor_body, Vector3(8, 0.20, 7), &"wood")
	var floor_wood := wood.duplicate() as StandardMaterial3D
	floor_wood.uv1_scale = Vector3(0.12, 1.0, 1.0)
	var boards := MultiMeshInstance3D.new()
	boards.name = "FloorBoards"
	boards.multimesh = MultiMesh.new()
	boards.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	var plank := BoxMesh.new()
	plank.size = Vector3(0.385, 0.024, 7)
	boards.multimesh.mesh = plank
	boards.multimesh.instance_count = 20
	for board: int in range(20):
		boards.multimesh.set_instance_transform(board, Transform3D(Basis.IDENTITY, Vector3(-3.8 + board * 0.4, 0.012, 0)))
	boards.material_override = floor_wood
	boards.set_meta("floor_detail", true)
	add_child(boards)
	for index: int in range(4):
		var normal := Vector3.FORWARD.rotated(Vector3.UP, float(index) * PI * 0.5)
		var wall := Node3D.new()
		wall.name = "Wall%d" % index
		add_child(wall)
		_walls.append(wall)
		_normals.append(normal)
		var along_x: bool = index % 2 == 0
		var size := Vector3(8.2, 2.7, 0.16) if along_x else Vector3(0.16, 2.7, 7)
		var center := normal * (3.5 if along_x else 4.0)
		# Full collision is separate from the disappearing wall visuals.
		_box(self, "Boundary%d" % index, center + Vector3.UP * 1.35, size, plaster, true, false)
		_box(wall, "Plaster", center + Vector3.UP * 1.35, size, plaster, false)
		var beam_size := Vector3(8.25, 0.12, 0.22) if along_x else Vector3(0.22, 0.12, 7.1)
		for height: float in [0.15, 2.63]:
			_box(wall, "Rail", center + Vector3.UP * height, beam_size, wood, false)
		for step: int in range(-1, 2):
			var offset := Vector3(float(step) * 3.75, 1.35, 0) if along_x else Vector3(0, 1.35, float(step) * 3.25)
			_box(wall, "Post", center + offset - normal * 0.10, Vector3(0.13, 2.6, 0.13), wood, false)
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color("7096ab")
	glass.emission_enabled = true
	glass.emission = Color("597b9c")
	glass.emission_energy_multiplier = 0.4
	for x: float in [-2.6, 0.0]:
		_box(_walls[0], "WindowPane", Vector3(x, 1.85, -3.39), Vector3(1.0, 1.05, 0.03), glass, false)
		for dx: float in [-0.55, 0.0, 0.55]:
			_box(_walls[0], "WindowFrame", Vector3(x + dx, 1.85, -3.33), Vector3(0.07, 1.18, 0.11), wood, false)
		for y: float in [1.28, 1.85, 2.42]:
			_box(_walls[0], "WindowFrame", Vector3(x, y, -3.33), Vector3(1.17, 0.07, 0.11), wood, false)
		_box(_walls[0], "WindowSill", Vector3(x, 1.25, -3.27), Vector3(1.25, 0.10, 0.32), wood, false)
	# North-facing sleeping alcove with a low divider that cannot hide the player.
	_box(self, "BedFrame", Vector3(-2.6, 0.29, -1.85), Vector3(1.65, 0.32, 2.45), wood, true)
	_box(self, "Mattress", Vector3(-2.6, 0.52, -1.85), Vector3(1.52, 0.18, 2.25), linen, false)
	_build_bedding(blanket, linen)
	_box(self, "Headboard", Vector3(-2.6, 0.75, -3.02), Vector3(1.7, 1.2, 0.14), wood, false)
	_box(self, "AlcoveDivider", Vector3(-1.4, 0.45, -2.4), Vector3(0.12, 0.9, 1.9), wood, true)
	# Clear central circulation lane connects the south exit to both room halves.
	_table(Vector3(1.4, 0, 0.1), wood)
	for z: float in [-0.95, 1.15]:
		_stool(Vector3(1.4, 0, z), wood)
	_box(self, "Rug", Vector3(-0.4, 0.027, 0.4), Vector3(1.1, 0.006, 2.6), blanket, false)
	_build_rug_edges(linen)
	# Stone hearth: dark recess, raised sill and separate piers/mantel.
	_box(self, "Hearth", Vector3(2.35, 0.11, -2.82), Vector3(2.25, 0.18, 1.05), stone, true)
	var dark := _material("ruin_flagstone.png", Color("28232a"))
	_box(self, "Firebox", Vector3(2.35, 0.68, -3.32), Vector3(1.85, 1.1, 0.14), dark, false)
	_box(self, "HearthBack", Vector3(2.35, 0.79, -3.43), Vector3(2.14, 1.4, 0.12), stone, false)
	for x: float in [1.4, 3.3]:
		_box(self, "HearthPier", Vector3(x, 0.8, -3.0), Vector3(0.27, 1.4, 0.65), stone, true)
	_box(self, "Mantel", Vector3(2.35, 1.51, -3.0), Vector3(2.35, 0.19, 0.8), wood, false)
	var fire := Node3D.new()
	fire.set_script(preload("res://scripts/gameplay/hearth_fire.gd"))
	fire.name = "HearthFire"
	fire.position = Vector3(2.35, 0.20, -2.94)
	add_child(fire)
	_light(Vector3(-1.8, 2.2, 0.5), Color("ffe1b0"), 1.7, 8.0)
	_build_shelf(wood, blanket, linen)
	Dressing.build(self, _walls[1], house_id, wood, linen, blanket)
	var crate := Node3D.new()
	crate.set_script(preload("res://scripts/gameplay/storage_chest.gd"))
	crate.name = "StorageChest"
	crate.scale.z = 0.94
	crate.rotation.y = PI
	crate.position = Vector3(3.35, 0.024, 2.55)
	add_child(crate)
	_box(self, "CrateCollision", Vector3(3.35, 0.4, 2.55), Vector3(0.85, 0.8, 0.83), wood, true, false)
	# The visible doorway is on the far side of the south wall when cut away.
	var threshold := _box(self, "DoorThreshold", Vector3(0, 0.034, 3.02), Vector3(1.5, 0.02, 0.7), stone, false)
	Footsteps.register_surface(threshold, Vector3(1.5, 0.02, 0.7), &"stone", 10)
	for x: float in [-0.75, 0.75]:
		_box(_walls[2], "DoorJamb", Vector3(x, 1.05, 3.35), Vector3(0.13, 2.1, 0.16), wood, false)
	_box(_walls[2], "DoorLintel", Vector3(0, 2.10, 3.35), Vector3(1.65, 0.14, 0.16), wood, false)
	for board: int in range(6):
		_box(_walls[2], "DoorBoard", Vector3(-0.525 + board * 0.21, 1.04, 3.37), Vector3(0.20, 1.98, 0.05), wood, false)
	_box(_walls[2], "DoorHandle", Vector3(0.42, 0.97, 3.29), Vector3(0.07, 0.12, 0.08), stone, false)
	_interaction("leave_house", "返回村莊", Vector3(0, 0.7, 2.95))
	_interaction("inspect_house_shelf", "查看" + str(preload("res://scripts/gameplay/house_catalog.gd").FURNITURE[house_id].name), Vector3(-3.0, 0.7, 1.4))
	var sign := Label3D.new()
	sign.text = "出口"
	sign.font = load("res://assets/fonts/Cubic_11.ttf") as Font
	sign.font_size = 40
	sign.pixel_size = 0.005
	sign.position = Vector3(0, 0.35, 3.12)
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(sign)


func _build_bedding(cloth: StandardMaterial3D, linen: Material) -> void:
	var quilt := MeshInstance3D.new()
	quilt.name = "Quilt"
	# A continuous thin surface hangs beyond the mattress; no rigid slab edge.
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row: int in range(12):
		for column: int in range(12):
			for corner: Vector2i in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 0), Vector2i(1, 1), Vector2i(0, 1)]:
				var uv := Vector2(column + corner.x, row + corner.y) / 12.0
				var x := (uv.x - 0.5) * 1.78
				var z := lerpf(-2.38, -0.56, uv.y)
				var side_drop := pow(maxf(0.0, (absf(x) - 0.68) / 0.21), 2.0) * 0.22
				var end_drop := pow(maxf(0.0, (z + 0.79) / 0.23), 2.0) * 0.18
				var height := 0.665 + sin(uv.y * PI * 4.0) * 0.009 - maxf(side_drop, end_drop)
				surface.set_uv(uv)
				surface.add_vertex(Vector3(-2.6 + x, height, z))
	surface.generate_normals()
	quilt.mesh = surface.commit()
	var material := cloth.duplicate() as StandardMaterial3D
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	quilt.material_override = material
	add_child(quilt)
	var pillow := MeshInstance3D.new()
	pillow.name = "Pillow"
	var cushion := SphereMesh.new()
	cushion.radius = 1.0
	cushion.height = 2.0
	cushion.radial_segments = 24
	cushion.rings = 12
	pillow.mesh = cushion
	pillow.scale = Vector3(0.55, 0.105, 0.23)
	pillow.position = Vector3(-2.6, 0.705, -2.68)
	pillow.material_override = linen
	add_child(pillow)


func _build_rug_edges(linen: Material) -> void:
	for side: float in [-1.0, 1.0]:
		_box(self, "RugBinding", Vector3(-0.4 + side * 0.515, 0.033, 0.4), Vector3(0.05, 0.005, 2.6), linen, false)
		_box(self, "RugBinding", Vector3(-0.4, 0.033, 0.4 + side * 1.22), Vector3(1.05, 0.005, 0.06), linen, false)
	var fringe := MultiMeshInstance3D.new()
	fringe.name = "RugFringe"
	fringe.multimesh = MultiMesh.new()
	fringe.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	var thread := BoxMesh.new()
	thread.size = Vector3(0.018, 0.009, 0.14)
	fringe.multimesh.mesh = thread
	fringe.multimesh.instance_count = 28
	for index: int in range(28):
		var side := -1.0 if index < 14 else 1.0
		var origin := Vector3(-0.9 + float(index % 14) / 13.0, 0.033, 0.4 + side * 1.34)
		fringe.multimesh.set_instance_transform(index, Transform3D(Basis.IDENTITY, origin))
	fringe.material_override = linen
	add_child(fringe)


func configure_furniture_cutaway(target: Node3D, camera: Camera3D) -> void:
	for label: String in ["WeavingFrame", "PottingBench", "MoonRecordStand", "PotteryRack", "LinenCupboard", "TravelGearStand", "HerbDryingStand", "LibraryCabinet"]:
		var furniture := get_node_or_null(label) as Node3D
		if furniture == null:
			continue
		var cutaway := preload("res://scripts/gameplay/foreground_cutaway.gd").new()
		cutaway.name = "FurnitureCutaway"
		add_child(cutaway)
		cutaway.configure(furniture, target, camera)


func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return
	var view := camera.global_position - global_position
	for index: int in range(_walls.size()):
		_walls[index].visible = view.dot(_normals[index]) < 0.5


func _interaction(id: String, prompt: String, origin: Vector3) -> void:
	var area := Interactable3D.new()
	area.name = id
	area.interaction_id = id
	area.prompt_text = prompt
	area.position = origin
	area.collision_layer = 8
	area.collision_mask = 0
	var collider := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.5
	collider.shape = shape
	area.add_child(collider)
	area.activated.connect(func(value: String) -> void: interaction_requested.emit(value))
	add_child(area)


func _table(origin: Vector3, wood: Material) -> void:
	_box(self, "TableTop", origin + Vector3(0, 0.85, 0), Vector3(1.75, 0.12, 1.15), wood, true)
	for x: float in [-0.7, 0.7]:
		for z: float in [-0.42, 0.42]:
			_box(self, "TableLeg", origin + Vector3(x, 0.42, z), Vector3(0.12, 0.8, 0.12), wood, false)
	_box(self, "TableCollision", origin + Vector3(0, 0.43, 0), Vector3(1.75, 0.85, 1.15), wood, true, false)


func _stool(origin: Vector3, wood: Material) -> void:
	_box(self, "StoolSeat", origin + Vector3(0, 0.46, 0), Vector3(0.58, 0.10, 0.55), wood, false)
	for x: float in [-0.21, 0.21]:
		for z: float in [-0.20, 0.20]:
			_box(self, "StoolLeg", origin + Vector3(x, 0.23, z), Vector3(0.08, 0.45, 0.08), wood, false)
	_box(self, "StoolCollision", origin + Vector3(0, 0.25, 0), Vector3(0.58, 0.5, 0.55), wood, true, false)


func _build_shelf(wood: Material, cloth: Material, linen: Material) -> void:
	if preload("res://scripts/gameplay/household_furnishings.gd").THEMES.has(house_id):
		preload("res://scripts/gameplay/household_furnishings.gd").build(self, house_id, wood, cloth, linen)
		_box(self, "ShelfBack", Vector3(-3.68, 1.0, 1.6), Vector3(0.15, 1.9, 1.65), wood, true, false)
		_box(self, "ShelfCollision", Vector3(-3.4, 0.9, 1.6), Vector3(0.72, 1.8, 1.75), wood, true, false)
		return
	if house_id == "house_01":
		preload("res://scripts/gameplay/weaving_frame.gd").build(self, wood, cloth, linen)
		_box(self, "ShelfBack", Vector3(-3.68, 1.0, 1.6), Vector3(0.15, 1.9, 1.65), wood, true, false)
		_box(self, "ShelfCollision", Vector3(-3.4, 0.9, 1.6), Vector3(0.72, 1.8, 1.75), wood, true, false)
		return
	if house_id == "house_08":
		preload("res://scripts/gameplay/library_cabinet.gd").build(self, wood, cloth, linen)
		_box(self, "ShelfBack", Vector3(-3.68, 1.0, 1.6), Vector3(0.15, 1.9, 1.65), wood, true, false)
		_box(self, "ShelfCollision", Vector3(-3.4, 0.9, 1.6), Vector3(0.72, 1.8, 1.75), wood, true, false)
		return
	if house_id == "house_02":
		preload("res://scripts/gameplay/potting_bench.gd").build(self, wood)
		_box(self, "ShelfBack", Vector3(-3.68, 1.0, 1.6), Vector3(0.15, 1.9, 1.65), wood, true, false)
		_box(self, "ShelfCollision", Vector3(-3.4, 0.9, 1.6), Vector3(0.72, 1.8, 1.75), wood, true, false)
		return
	if house_id == "house_04":
		preload("res://scripts/gameplay/pottery_rack.gd").build(self, wood)
		_box(self, "ShelfBack", Vector3(-3.68, 1.0, 1.6), Vector3(0.15, 1.9, 1.65), wood, true, false)
		_box(self, "ShelfCollision", Vector3(-3.4, 0.9, 1.6), Vector3(0.72, 1.8, 1.75), wood, true, false)
		return
	_box(self, "ShelfBack", Vector3(-3.68, 1.0, 1.6), Vector3(0.15, 1.9, 1.65), wood, true)
	for y: float in [0.18, 0.85, 1.52, 1.95]:
		_box(self, "ShelfBoard", Vector3(-3.42, y, 1.6), Vector3(0.68, 0.09, 1.7), wood, false)
	for index: int in range(7):
		_box(self, "Book", Vector3(-3.4, 1.13, 1.0 + float(index) * 0.19), Vector3(0.35, 0.44 + float(index % 3) * 0.04, 0.13), cloth if index % 2 == 0 else linen, false)
	_box(self, "ShelfCollision", Vector3(-3.4, 0.9, 1.6), Vector3(0.72, 1.8, 1.75), wood, true, false)


func _light(origin: Vector3, color: Color, energy: float, radius: float) -> void:
	var light := OmniLight3D.new()
	light.position = origin
	light.light_color = color
	light.light_energy = energy
	light.omni_range = radius
	add_child(light)


func _material(file: String, color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_texture = load("res://assets/generated/" + file) as Texture2D
	material.albedo_color = color
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	material.roughness = 0.94
	return material


func _box(parent: Node3D, label: String, origin: Vector3, size: Vector3, material: Material, collision: bool, visible_mesh: bool = true) -> Node3D:
	var body: Node3D = StaticBody3D.new() if collision else Node3D.new()
	body.name = label
	body.position = origin
	parent.add_child(body)
	if visible_mesh:
		var mesh := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = size
		mesh.mesh = box
		mesh.material_override = material
		body.add_child(mesh)
	if collision:
		var collider := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		collider.shape = shape
		body.add_child(collider)
	return body
