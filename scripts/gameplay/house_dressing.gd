extends RefCounted
## Original decorative arrangements. No collisions, interactions or save data.

const PRINTS: Texture2D = preload("res://assets/generated/house_prints.png")
const CROPS: Array[Rect2] = [Rect2(12, 12, 600, 580), Rect2(642, 12, 600, 580), Rect2(12, 624, 600, 610), Rect2(642, 624, 600, 610)]
const ARRANGEMENTS: Dictionary = {
	"house_01": {"theme": "woven craft", "wall": 3, "paper": 3, "books": 1, "scrolls": 0, "pots": 1},
	"house_02": {"theme": "botanical study", "wall": 0, "paper": 0, "books": 1, "scrolls": 0, "pots": 1},
	"house_03": {"theme": "moon records", "wall": 1, "paper": 3, "books": 2, "scrolls": 0, "pots": 1},
	"house_04": {"theme": "pottery patterns", "wall": 3, "paper": 0, "books": 0, "scrolls": 0, "pots": 3},
	"house_05": {"theme": "pattern collection", "wall": 3, "paper": 3, "books": 0, "scrolls": 2, "pots": 1},
	"house_06": {"theme": "travel planning", "wall": 2, "paper": 2, "books": 1, "scrolls": 2, "pots": 1},
	"house_07": {"theme": "field notes", "wall": 0, "paper": 2, "books": 2, "scrolls": 1, "pots": 1},
	"house_08": {"theme": "astronomy library", "wall": 1, "paper": 1, "books": 3, "scrolls": 2, "pots": 1},
}


static func build(room: Node3D, west_wall: Node3D, house_id: String, wood: Material, linen: Material, cloth: Material) -> void:
	var config: Dictionary = ARRANGEMENTS[house_id]
	var root := Node3D.new()
	root.name = "RoomDressing"
	root.set_meta("theme", config.theme)
	room.add_child(root)
	var frame := Node3D.new()
	frame.name = "WallPrint"
	frame.position = Vector3(-3.88, 1.73, -0.75)
	frame.rotation.y = PI * 0.5
	# Attached to its own wall so camera cutaway hides the decoration too.
	west_wall.add_child(frame)
	_print(frame, "Print", Vector3(0, 0, 0.025), Vector2.ONE, config.wall)
	for sign: float in [-1.0, 1.0]:
		_box(frame, "FrameRail", Vector3(sign * 0.535, 0, 0), Vector3(0.07, 1.14, 0.055), wood)
		_box(frame, "FrameRail", Vector3(0, sign * 0.535, 0), Vector3(1.0, 0.07, 0.055), wood)
	var paper := _print(root, "TablePaper", Vector3(1.18, 0.912, 0.27), Vector2(0.65, 0.54), config.paper)
	paper.rotation.x = -PI * 0.5
	paper.rotation.y = -0.10 if int(config.paper) % 2 == 0 else 0.08
	for index: int in range(config.books):
		_book(root, Vector3(0.85, 0.942 + float(index) * 0.064, -0.25), index, cloth, linen)
	for index: int in range(config.scrolls):
		_scroll(root, Vector3(1.39, 0.958, -0.27 + float(index) * 0.12), linen, wood, index)
	var jar_scene := load("res://assets/generated/earthenware_jar.glb") as PackedScene
	var positions: Array[Vector3] = [Vector3(1.98, 0.91, 0.38), Vector3(1.98, 0.91, -0.23), Vector3(1.70, 0.91, -0.26)]
	for index: int in range(config.pots):
		var jar := jar_scene.instantiate() as Node3D
		jar.name = "TablePot%d" % index
		jar.position = positions[index]
		jar.scale = Vector3.ONE * (0.40 - float(index) * 0.07)
		root.add_child(jar)


static func _print(parent: Node3D, label: String, position: Vector3, size: Vector2, cell: int) -> MeshInstance3D:
	var result := MeshInstance3D.new()
	result.name = label
	result.position = position
	var quad := QuadMesh.new()
	quad.size = size
	result.mesh = quad
	var material := StandardMaterial3D.new()
	material.albedo_texture = PRINTS
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	material.roughness = 0.95
	var crop: Rect2 = CROPS[cell]
	material.uv1_scale = Vector3(crop.size.x / PRINTS.get_width(), crop.size.y / PRINTS.get_height(), 1)
	material.uv1_offset = Vector3(crop.position.x / PRINTS.get_width(), crop.position.y / PRINTS.get_height(), 0)
	result.material_override = material
	result.set_meta("print_cell", cell)
	parent.add_child(result)
	return result


static func _book(parent: Node3D, position: Vector3, index: int, cover: Material, pages: Material) -> void:
	var book := Node3D.new()
	book.name = "BookStack%d" % index
	book.position = position
	book.rotation.y = float(index - 1) * 0.12
	parent.add_child(book)
	_box(book, "Pages", Vector3.ZERO, Vector3(0.39, 0.042, 0.255), pages)
	for sign: float in [-1.0, 1.0]:
		_box(book, "Cover", Vector3(0, sign * 0.026, 0), Vector3(0.43, 0.012, 0.28), cover)
	_box(book, "Spine", Vector3(-0.208, 0, 0), Vector3(0.016, 0.064, 0.28), cover)
	for z: float in [-0.085, 0.085]:
		_box(book, "Binding", Vector3(-0.220, 0, z), Vector3(0.008, 0.049, 0.016), pages)


static func _scroll(parent: Node3D, position: Vector3, paper: Material, wood: Material, index: int) -> void:
	var scroll := Node3D.new()
	scroll.name = "Scroll%d" % index
	scroll.position = position
	parent.add_child(scroll)
	for data: Vector3 in [Vector3(0, 0.040, 0.42), Vector3(-0.22, 0.048, 0.025), Vector3(0.22, 0.048, 0.025), Vector3(0, 0.044, 0.023)]:
		var mesh := MeshInstance3D.new()
		var roll := CylinderMesh.new()
		roll.top_radius = data.y
		roll.bottom_radius = data.y
		roll.height = data.z
		roll.radial_segments = 12
		mesh.mesh = roll
		mesh.position.x = data.x
		mesh.rotation.z = PI * 0.5
		mesh.material_override = paper if data.z > 0.1 else wood
		scroll.add_child(mesh)


static func _box(parent: Node3D, label: String, position: Vector3, size: Vector3, material: Material) -> void:
	var result := MeshInstance3D.new()
	result.name = label
	result.position = position
	var box := BoxMesh.new()
	box.size = size
	result.mesh = box
	result.material_override = material
	parent.add_child(result)
