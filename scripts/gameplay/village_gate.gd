extends RefCounted
## Roofed timber gateway where the old east road enters Twilight Village:
## a named arch, lanterns and short split-rail wings that run into the hills.

const Collision = preload("res://scripts/gameplay/prop_collision.gd")
const HALF_SPAN: float = 2.2


static func build(props: WorldProps, at: Vector3) -> void:
	var gate := Node3D.new()
	gate.name = "VillageEastGate"
	gate.position = at
	props.map_root.add_child(gate)
	var timber := props.make_material(Color("8a6a4c"), 0.93)
	timber.albedo_texture = props.art_texture("res://assets/generated/timber_albedo.png")
	timber.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	var dark := props.make_material(Color("3b2d24"), 0.95)
	var slate := props.make_material(Color("5b6479"), 0.9)
	slate.albedo_texture = props.art_texture("res://assets/generated/slate_roof_albedo.png")
	slate.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	slate.uv1_scale = Vector3(3.0, 1.0, 1.0)
	var stone := props.make_coursed_stone()
	for side: float in [-1.0, 1.0]:
		var z: float = side * HALF_SPAN
		_box(gate, Vector3(0, 0.17, z), Vector3(0.62, 0.34, 0.62), stone)
		_box(gate, Vector3(0, 1.72, z), Vector3(0.34, 3.1, 0.34), timber)
		# Knee braces make the posts read as carpentry, not two sticks.
		var brace := _box(gate, Vector3(0, 2.72, z - side * 0.36), Vector3(0.14, 0.72, 0.14), timber)
		brace.rotation.x = side * 0.62
		Collision.cylinder(gate, Vector3(0, 1.2, z), 0.3, 2.4)
		_wing(gate, side, timber, dark)
	_box(gate, Vector3(0, 2.22, 0), Vector3(0.22, 0.24, HALF_SPAN * 2 + 0.9), timber)
	_box(gate, Vector3(0, 3.33, 0), Vector3(0.4, 0.3, HALF_SPAN * 2 + 1.5), timber)
	for side: float in [-1.0, 1.0]:
		var roof := _box(gate, Vector3(side * 0.43, 3.66, 0), Vector3(1.08, 0.1, HALF_SPAN * 2 + 1.9), slate)
		roof.rotation.z = -side * 0.52
	_box(gate, Vector3(0, 3.93, 0), Vector3(0.18, 0.16, HALF_SPAN * 2 + 2.0), dark)
	# Name board framed between the beams, clear above the traveler's head.
	_box(gate, Vector3(0, 2.76, 0), Vector3(0.08, 0.56, 1.46), dark)
	_box(gate, Vector3(0, 2.76, 0), Vector3(0.1, 0.44, 1.34), timber)
	for side: float in [-1.0, 1.0]:
		var name_label := Label3D.new()
		name_label.name = "GateNameRoad" if side > 0.0 else "GateNameVillage"
		name_label.text = "暮光村"
		name_label.font = preload("res://assets/fonts/SourceHanSansTW-Regular.otf")
		name_label.font_size = 54
		name_label.pixel_size = 0.006
		name_label.outline_size = 0
		name_label.modulate = Color("f0dcae")
		name_label.position = Vector3(side * 0.06, 2.76, 0)
		name_label.rotation.y = side * PI * 0.5
		gate.add_child(name_label)
	for side: float in [-1.0, 1.0]:
		props.add_lamp(at + Vector3(-0.8, 0, side * (HALF_SPAN + 0.6)))


## Split-rail fence from each post outward; the hill slope takes over beyond it.
static func _wing(gate: Node3D, side: float, timber: Material, dark: Material) -> void:
	var length: float = 3.8
	var middle: float = side * (HALF_SPAN + length * 0.5)
	for rail_height: float in [0.42, 0.86]:
		_box(gate, Vector3(0, rail_height, middle), Vector3(0.1, 0.12, length), timber)
	for step: int in range(1, 4):
		var z: float = side * (HALF_SPAN + step * length / 3.0)
		_box(gate, Vector3(0, 0.55, z), Vector3(0.16, 1.1, 0.16), dark if step == 3 else timber)
	var body := StaticBody3D.new()
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.3, 1.2, length)
	collider.shape = shape
	body.add_child(collider)
	body.position = Vector3(0, 0.6, middle)
	gate.add_child(body)


static func _box(parent: Node3D, position: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	visual.mesh = mesh
	visual.material_override = material
	visual.position = position
	parent.add_child(visual)
	return visual
