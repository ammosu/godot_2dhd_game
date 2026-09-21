extends Node3D
## Small unlit geometry works in Forward+ and Compatibility without particles or DOF.
var _time: float = 0.0
var _origins: Array[Vector3] = []

func _ready() -> void:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color("b8f3af")
	var mesh := SphereMesh.new()
	mesh.radius = 0.035
	mesh.height = 0.07
	mesh.radial_segments = 6
	mesh.rings = 3
	for index: int in range(28):
		var dot := MeshInstance3D.new()
		dot.mesh = mesh
		dot.material_override = material
		dot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var origin := Vector3(sin(index * 2.4) * 10, 0.6 + float(index % 4) * 0.35, -10 + float(index % 7) * 2)
		_origins.append(origin)
		dot.position = origin
		add_child(dot)

func _process(delta: float) -> void:
	_time += delta
	for index: int in range(_origins.size()):
		var dot := get_child(index) as Node3D
		var phase := _time * 0.7 + index * 1.8
		dot.position = _origins[index] + Vector3(sin(phase) * 0.4, cos(phase * 1.3) * 0.18, cos(phase) * 0.3)
		dot.scale = Vector3.ONE * (0.65 + 0.35 * sin(phase * 2.0))
