extends RefCounted
## Wall-mounted planting; HouseExterior adds collision after visual scaling.
## Reuses original timber and flower art; each wooden box is one mesh batch.

const FLOWERS: Array[Texture2D] = [
	preload("res://assets/generated/flowers_ivory.tres"),
	preload("res://assets/generated/flowers_mauve.tres"),
	preload("res://assets/generated/flowers_blue.tres"),
]
const BOARDS: Array[Vector4] = [
	Vector4(0.0, 0.70, 0.20, 0.0),
	Vector4(0.0, 0.81, 0.40, 1.0),
	Vector4(-0.42, 0.81, 0.20, 2.0),
	Vector4(0.42, 0.81, 0.20, 2.0),
	Vector4(-0.30, 0.60, 0.13, 3.0),
	Vector4(0.30, 0.60, 0.13, 3.0),
]
const SIZES: Array[Vector3] = [Vector3(0.88, 0.06, 0.42), Vector3(0.88, 0.22, 0.045), Vector3(0.04, 0.22, 0.40), Vector3(0.075, 0.20, 0.26)]


static func build(parent: Node3D, house_id: String, wood: Material) -> void:
	var root := Node3D.new()
	root.name = "FacadePlanters"
	parent.add_child(root)
	var variant: int = int(house_id.trim_prefix("house_")) % FLOWERS.size()
	# All mounts align with actual window centers. The two front showcases
	# retain their authored flower boxes / pottery shelves without duplicates.
	_add(root, "RearLeft", Vector3(-1.15, 0, 1.67), 0.0, wood, variant)
	_add(root, "RearRight", Vector3(1.15, 0, 1.67), 0.0, wood, (variant + 1) % FLOWERS.size())
	_add(root, "SideLeft", Vector3(-2.01, 0, 0.72), -PI * 0.5, wood, variant)
	_add(root, "SideRight", Vector3(2.01, 0, 0.72), PI * 0.5, wood, (variant + 1) % FLOWERS.size())
	_add(root, "SideLeftFront", Vector3(-2.01, 0, -0.72), -PI * 0.5, wood, (variant + 1) % FLOWERS.size())
	_add(root, "SideRightFront", Vector3(2.01, 0, -0.72), PI * 0.5, wood, variant)
	if house_id not in ["house_02", "house_04"]:
		_add(root, "FrontLeft", Vector3(-1.25, 0, -1.67), PI, wood, variant)
		_add(root, "FrontRight", Vector3(1.25, 0, -1.67), PI, wood, (variant + 1) % FLOWERS.size())


static func _add(parent: Node3D, label: String, position: Vector3, yaw: float, wood: Material, variant: int) -> void:
	var planter := Node3D.new()
	planter.name = label
	planter.position = position
	planter.rotation.y = yaw
	parent.add_child(planter)
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.mesh = BoxMesh.new()
	(batch.mesh as BoxMesh).size = Vector3.ONE
	batch.instance_count = BOARDS.size()
	for index: int in range(BOARDS.size()):
		var board := BOARDS[index]
		batch.set_instance_transform(index, Transform3D(Basis.IDENTITY.scaled(SIZES[int(board.w)]), Vector3(board.x, board.y, board.z)))
	var boards := MultiMeshInstance3D.new()
	boards.name = "TimberBoards"
	boards.multimesh = batch
	boards.material_override = wood
	boards.custom_aabb = AABB(Vector3(-0.44, 0.50, -0.01), Vector3(0.88, 0.42, 0.433))
	batch.custom_aabb = boards.custom_aabb
	planter.add_child(boards)
	var soil := MeshInstance3D.new()
	soil.name = "Soil"
	var surface := BoxMesh.new()
	surface.size = Vector3(0.79, 0.04, 0.35)
	soil.mesh = surface
	soil.position = Vector3(0, 0.85, 0.20)
	var earth := StandardMaterial3D.new()
	earth.albedo_texture = preload("res://assets/generated/meadow_albedo.png")
	earth.albedo_color = Color("393529")
	earth.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	earth.roughness = 1.0
	soil.material_override = earth
	planter.add_child(soil)
	for index: int in range(3):
		var flowers := Sprite3D.new()
		flowers.name = "Flowers%d" % index
		flowers.texture = FLOWERS[variant]
		flowers.pixel_size = 0.00085
		# Atlas canvas 640 high, measured root at 620 -> offset 300 pixels.
		flowers.position = Vector3((index - 1) * 0.17, 0.87 + 300.0 * flowers.pixel_size, 0.21)
		flowers.rotation.y = deg_to_rad(float(index - 1) * 12.0)
		flowers.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
		flowers.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		flowers.shaded = true
		flowers.double_sided = true
		planter.add_child(flowers)
