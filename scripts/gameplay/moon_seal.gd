extends Node3D
## Original keeper's seal, presented during the ending. No gameplay state.

var last_reveal_page: int = 3


func show_for_page(index: int) -> void:
	visible = index >= 2 and index <= last_reveal_page

static func ring_mesh(radius: float, width: float, depth: float) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index: int in range(56):
		var a: float = deg_to_rad(40.0 + index * 5.0) - 0.30
		var b: float = deg_to_rad(45.0 + index * 5.0) - 0.30
		var inner_a := Vector2(cos(a), sin(a)) * (radius - width * 0.5)
		var outer_a := Vector2(cos(a), sin(a)) * (radius + width * 0.5)
		var inner_b := Vector2(cos(b), sin(b)) * (radius - width * 0.5)
		var outer_b := Vector2(cos(b), sin(b)) * (radius + width * 0.5)
		var points: Array[Vector3] = []
		for z: float in [-depth * 0.5, depth * 0.5]:
			for point: Vector2 in [inner_a, outer_a, outer_b, inner_b]:
				points.append(Vector3(point.x, point.y, z))
		for face: Array in [[0, 3, 2, 1], [4, 5, 6, 7], [0, 4, 7, 3], [1, 2, 6, 5]]:
			_quad(surface, points, face)
		if index == 0:
			_quad(surface, points, [0, 1, 5, 4])
		if index == 55:
			_quad(surface, points, [3, 7, 6, 2])
	return surface.commit()


static func _quad(surface: SurfaceTool, points: Array[Vector3], indices: Array) -> void:
	var normal := (points[indices[1]] - points[indices[0]]).cross(points[indices[2]] - points[indices[0]]).normalized()
	for index: int in [indices[0], indices[2], indices[1], indices[0], indices[3], indices[2]]:
		surface.set_normal(normal)
		surface.add_vertex(points[index])


func _ready() -> void:
	name = "KeeperMoonSeal"
	hide()
	add_to_group("moon_seal_presentations")
	var bronze := StandardMaterial3D.new()
	bronze.albedo_color = Color("716653")
	bronze.albedo_texture = preload("res://assets/generated/aged_bronze_albedo.png")
	bronze.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	bronze.metallic = 0.55
	bronze.roughness = 0.6
	var body := MeshInstance3D.new()
	body.name = "KeeperToken"
	var disc := CylinderMesh.new()
	disc.top_radius = 0.31
	disc.bottom_radius = 0.31
	disc.height = 0.065
	disc.radial_segments = 16
	body.mesh = disc
	body.rotation.x = PI * 0.5
	body.material_override = bronze
	add_child(body)
	var scar := MeshInstance3D.new()
	scar.name = "BurnedOpenRing"
	scar.mesh = ring_mesh(0.215, 0.037, 0.01)
	scar.position.z = 0.039
	var charred := StandardMaterial3D.new()
	charred.albedo_color = Color("211c28")
	charred.roughness = 1.0
	scar.material_override = charred
	add_child(scar)
	var ember := MeshInstance3D.new()
	ember.name = "ResidualMoonlight"
	ember.mesh = ring_mesh(0.215, 0.009, 0.012)
	ember.position.z = 0.041
	var silver := StandardMaterial3D.new()
	silver.albedo_color = Color("b7e2df")
	silver.emission_enabled = true
	silver.emission = Color("8cb9c5")
	silver.emission_energy_multiplier = 0.7
	ember.material_override = silver
	add_child(ember)
