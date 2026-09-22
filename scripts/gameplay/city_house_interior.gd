extends "res://scripts/gameplay/house_interior.gd"
## City interiors share door/cutaway primitives, but have six authored floor plans.
const City = preload("res://scripts/gameplay/city_house_catalog.gd")
var plan: Dictionary
var _wood: StandardMaterial3D
var _cloth: StandardMaterial3D
var _linen: StandardMaterial3D

func _ready() -> void:
	var home := City.home(house_id)
	plan = City.THEMES[home.kind]
	set_meta("room_kind", home.kind)
	_wood = _material("timber_albedo.png", Color("bda68d"))
	_linen = _material("linen_albedo.png", Color("ecdfc8"))
	_cloth = _material("linen_albedo.png", (plan.color as Color).lightened(float(int(home.index) % 3) * 0.07))
	var plaster := _material("plaster_albedo.png", Color("d5d0bc"))
	var stone := _material("ruin_flagstone.png", Color("a6a0a0"))
	_build_shell(plaster, stone)
	match str(home.kind):
		"inn":
			_bed(Vector3(-1.65, 0, -4.55), 0)
			_bed(Vector3(2.8, 0, -4.55), 0)
			_partition(Vector3(-2.3, 0.65, -2.65), Vector3(2.8, 1.3, 0.15))
			_partition(Vector3(3.2, 0.65, -2.65), Vector3(3.0, 1.3, 0.15))
			_dining(Vector3(-2.7, 0, 0.25))
			_counter(Vector3(3.1, 0, 0), Vector3(2.6, 0.95, 1.0))
			_feature("library", Vector3(4.6, 0, -4.3), 0)
		"home":
			_bed(Vector3(-2.7, 0, -3.25), 0)
			_bed(Vector3(2.6, 0, -3.25), 0)
			_partition(Vector3(-1.45, 0.7, -3.45), Vector3(0.15, 1.4, 2.8))
			_partition(Vector3(1.35, 0.7, -3.45), Vector3(0.15, 1.4, 2.8))
			_dining(Vector3(2.4, 0, 0.7))
			_feature("linen", Vector3(-3.7, 0, 0.3), 0)
		"shop":
			_counter(Vector3(2.6, 0, -0.4), Vector3(3.6, 0.95, 1.1))
			_counter(Vector3(-3.4, 0, 0), Vector3(1.2, 0.8, 2.6))
			_partition(Vector3(2.8, 0.75, -2.5), Vector3(4.4, 1.5, 0.16))
			_feature("library", Vector3(4.3, 0, -4.2), 0)
			for x: float in [-1.4, 0.3, 2.0]:
				_chest(Vector3(x, 0, -4.9))
		"library":
			for z: float in [-4.9, -2.5, 0]:
				_feature("library", Vector3(-3.8, 0, z), 0)
			_feature("library", Vector3(3.8, 0, -4.7), PI)
			_dining(Vector3(2.1, 0, -1.1))
			_table(Vector3(0, 0, -5.6), _wood)
			_books(Vector3(0, 0.94, -5.6))
		"workshop":
			_counter(Vector3(-3.5, 0, -0.7), Vector3(1.6, 0.85, 3.0))
			_counter(Vector3(2.8, 0, -2.8), Vector3(3.5, 0.85, 1.5))
			_feature("pottery", Vector3(4.8, 0, 0.7), PI)
			_feature("weaving", Vector3(-2.8, 0, -3.8), PI * 0.5)
			_chest(Vector3(3.7, 0, 2.3))
		"herbalist":
			_feature("plants", Vector3(-3.9, 0, -3.8), 0)
			_feature("herbs", Vector3(4.1, 0, -3.8), PI)
			_counter(Vector3(2.6, 0, -0.9), Vector3(2.8, 0.9, 1.2))
			_bed(Vector3(-3, 0, -0.6), 0)
			_partition(Vector3(-1.7, 0.6, -0.65), Vector3(0.12, 1.2, 2.4))
	# Entry, owner and inspect points share an intentionally clear central aisle.
	_box(self, "Runner", Vector3(0, 0.038, 0.6), Vector3(1.25, 0.01, 3.1), _cloth, false)
	_light(Vector3(0, 2.5, -1.0), Color("ffe0b1"), 1.55, 10)
	_light(Vector3(0, 2.4, -float(plan.depth) + 1.4), Color("b7cddd"), 0.8, 7)
	_chest(Vector3(float(plan.width) - 0.8, 0, 2.5))
	_build_exit(stone)
	_interaction("inspect_house_shelf", "查看" + str(plan.furniture), Vector3(0, 0.7, -2.15))
	# A small lectern marks the inspect point without occupying the walkway.
	_counter(Vector3(1.0, 0, -2.1), Vector3(0.48, 0.72, 0.46), false)
	_books(Vector3(1.0, 0.78, -2.1))

func _build_shell(plaster: Material, stone: Material) -> void:
	var outline := City.footprint(house_id)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index: int in Geometry2D.triangulate_polygon(outline):
		var p: Vector2 = outline[index]
		surface.set_normal(Vector3.UP)
		surface.set_uv(p / 2.0)
		surface.add_vertex(Vector3(p.x, 0.024, p.y))
	var floor_mesh := MeshInstance3D.new()
	floor_mesh.name = "CityFloor"
	floor_mesh.mesh = surface.commit()
	var floor_material := _wood.duplicate() as StandardMaterial3D
	floor_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	floor_mesh.material_override = floor_material
	add_child(floor_mesh)
	floor_mesh.create_trimesh_collision()
	Footsteps.register_surface(floor_mesh, Vector3(float(plan.width) * 2, 0.04, float(plan.depth) * 2 + 7), &"wood")
	for index: int in range(outline.size()):
		var a: Vector2 = outline[index]
		var b: Vector2 = outline[(index + 1) % outline.size()]
		var delta := b - a
		var center := (a + b) * 0.5
		var wall := Node3D.new()
		wall.name = "CityWall%d" % index
		add_child(wall)
		_walls.append(wall)
		_normals.append(Vector3(delta.y, 0, -delta.x).normalized())
		var south := is_equal_approx(a.y, 3.5) and is_equal_approx(b.y, 3.5)
		if south:
			for side: float in [-1, 1]:
				_box(wall, "DoorWall", Vector3(side * (float(plan.width) + 0.75) * 0.5, 1.35, 3.5), Vector3(float(plan.width) - 0.75, 2.7, 0.16), plaster, false)
			_box(wall, "DoorLintel", Vector3(0, 2.45, 3.5), Vector3(1.5, 0.5, 0.18), plaster, false)
			_build_door(wall, stone)
		else:
			var panel := _box(wall, "Plaster", Vector3(center.x, 1.35, center.y), Vector3(delta.length(), 2.7, 0.16), plaster, false)
			panel.rotation.y = -atan2(delta.y, delta.x)
			for height: float in [0.15, 2.62]:
				var rail := _box(wall, "TimberRail", Vector3(center.x, height, center.y), Vector3(delta.length(), 0.13, 0.23), _wood, false)
				rail.rotation.y = panel.rotation.y
		var boundary := _box(self, "Boundary", Vector3(center.x, 1.35, center.y), Vector3(delta.length(), 2.7, 0.16), plaster, true, false)
		boundary.rotation.y = -atan2(delta.y, delta.x)
		if delta.length() > 4 and not south:
			var window := _box(wall, "Window", Vector3(center.x, 1.7, center.y) - _normals[-1] * 0.10, Vector3(1.4, 1.15, 0.06), _material("linen_albedo.png", Color("718d9d")), false)
			window.rotation.y = -atan2(delta.y, delta.x)
			for x: float in [-0.73, 0, 0.73]:
				_box(window, "WindowBar", Vector3(x, 0, 0), Vector3(0.07, 1.25, 0.12), _wood, false)
			for y: float in [-0.6, 0.6]:
				_box(window, "WindowRail", Vector3(0, y, 0), Vector3(1.55, 0.07, 0.12), _wood, false)

func _build_door(wall: Node3D, stone: Material) -> void:
	for x: float in [-0.75, 0.75]:
		_box(wall, "DoorJamb", Vector3(x, 1.05, 3.35), Vector3(0.13, 2.1, 0.16), _wood, false)
	_door_hinge = Node3D.new()
	_door_hinge.name = "DoorHinge"
	_door_hinge.position = Vector3(-0.63, 0, 3.37)
	wall.add_child(_door_hinge)
	for board: int in range(6):
		_box(_door_hinge, "DoorBoard", Vector3(0.105 + board * 0.21, 1.04, 0), Vector3(0.2, 1.98, 0.05), _wood, false)
	_box(_door_hinge, "Handle", Vector3(1.05, 0.97, -0.08), Vector3(0.07, 0.12, 0.08), stone, false)

func _build_exit(stone: Material) -> void:
	var threshold := _box(self, "DoorThreshold", Vector3(0, 0.034, 3.02), Vector3(1.5, 0.02, 0.7), stone, false)
	Footsteps.register_surface(threshold, Vector3(1.5, 0.02, 0.7), &"stone", 10)
	_build_exit_glow()
	_interaction("leave_house", "返回星灣城", Vector3(0, 0.7, 2.95))

func _partition(at: Vector3, size: Vector3) -> void:
	_box(self, "LowPartition", at, size, _wood, true)
	_box(self, "PartitionCap", at + Vector3.UP * size.y * 0.5, Vector3(size.x + 0.1, 0.08, size.z + 0.1), _wood, false)

func _bed(at: Vector3, yaw: float) -> void:
	var bed := Node3D.new()
	bed.name = "CityBed"
	add_child(bed)
	_box(bed, "Frame", Vector3(0, 0.29, 0), Vector3(1.65, 0.32, 2.45), _wood, true)
	_box(bed, "Mattress", Vector3(0, 0.52, 0), Vector3(1.52, 0.18, 2.25), _linen, false)
	_box(bed, "Headboard", Vector3(0, 0.75, -1.17), Vector3(1.7, 1.2, 0.14), _wood, false)
	var before := get_child_count()
	_build_bedding(_cloth, _linen)
	var bedding: Array[Node] = get_children().slice(before)
	for piece: Node3D in bedding:
		piece.reparent(bed, false)
		piece.position -= Vector3(-2.6, 0, -1.85)
	bed.position = at
	bed.rotation.y = yaw

func _dining(at: Vector3) -> void:
	_table(at, _wood)
	_stool(at + Vector3(0, 0, -1.05), _wood)
	_stool(at + Vector3(0, 0, 1.05), _wood)
	_box(self, "TableRunner", at + Vector3(0, 0.917, 0), Vector3(0.6, 0.016, 1.1), _cloth, false)
	_books(at + Vector3(0.35, 0.95, 0))

func _counter(at: Vector3, size: Vector3, goods: bool = true) -> void:
	_box(self, "Counter", at + Vector3.UP * size.y * 0.5, size, _wood, true)
	_box(self, "CounterLid", at + Vector3.UP * size.y, Vector3(size.x + 0.08, 0.08, size.z + 0.08), _wood, false)
	if goods:
		for index: int in range(3):
			_box(self, "FoldedGoods", at + Vector3((index - 1) * size.x * 0.25, size.y + 0.14, 0), Vector3(size.x * 0.2, 0.2, size.z * 0.5), _cloth if index % 2 == 0 else _linen, false)

func _books(at: Vector3) -> void:
	for index: int in range(3):
		_box(self, "BookCover", at + Vector3(0, index * 0.08, 0), Vector3(0.38, 0.025, 0.29), _cloth, false)
		_box(self, "BookPages", at + Vector3(0, index * 0.08 + 0.028, 0), Vector3(0.35, 0.04, 0.27), _linen, false)

func _chest(at: Vector3) -> void:
	var chest := preload("res://scripts/gameplay/storage_chest.gd").new()
	chest.position = at
	add_child(chest)
	_box(self, "ChestCollision", at + Vector3.UP * 0.4, Vector3(0.85, 0.8, 0.85), _wood, true, false)

func _feature(kind: String, at: Vector3, yaw: float) -> void:
	var holder := Node3D.new()
	holder.name = "CityFeature"
	add_child(holder)
	match kind:
		"library": preload("res://scripts/gameplay/library_cabinet.gd").build(holder, _wood, _cloth, _linen)
		"pottery": preload("res://scripts/gameplay/pottery_rack.gd").build(holder, _wood)
		"weaving": preload("res://scripts/gameplay/weaving_frame.gd").build(holder, _wood, _cloth, _linen)
		"plants": preload("res://scripts/gameplay/potting_bench.gd").build(holder, _wood)
		_: preload("res://scripts/gameplay/household_furnishings.gd").build(holder, "house_07" if kind == "herbs" else "house_05", _wood, _cloth, _linen)
	for child: Node3D in holder.get_children():
		child.position -= Vector3(-3.42, 0, 1.6)
	_box(holder, "FeatureCollision", Vector3(0, 0.9, 0), Vector3(0.75, 1.8, 1.8), _wood, true, false)
	holder.position = at
	holder.rotation.y = yaw
	holder.add_to_group("city_furniture")

func configure_furniture_cutaway(target: Node3D, camera: Camera3D) -> void:
	for furniture: Node in get_children():
		if not furniture.is_in_group("city_furniture"):
			continue
		var cutaway := preload("res://scripts/gameplay/foreground_cutaway.gd").new()
		add_child(cutaway)
		cutaway.configure(furniture, target, camera)
