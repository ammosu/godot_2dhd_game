extends Node3D
## Original quest relic presentation. No inventory, collision or pickup logic.

var _time: float = 0.0
var _relic: Node3D
const FLIGHT_DURATION: float = 1.4
var _flight_elapsed: float = FLIGHT_DURATION
var _flight_start: Vector3
var _flight_end: Vector3


func fly_to(destination: Vector3) -> void:
	_flight_start = position
	_flight_end = destination
	_flight_elapsed = 0.0


func _ready() -> void:
	add_to_group("moon_shard_presentations")
	_relic = Node3D.new()
	_relic.name = "Relic"
	add_child(_relic)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var outline: Array[Vector2] = [Vector2(-0.03, 0.38), Vector2(0.19, 0.12), Vector2(0.12, -0.18), Vector2(-0.055, -0.31), Vector2(-0.18, -0.08), Vector2(-0.12, 0.16)]
	var colors: Array[Color] = [Color("d8e5f0"), Color("aebedc"), Color("8997c3"), Color("bdcceb"), Color("e4e7f2"), Color("94acd4")]
	for index: int in range(outline.size()):
		var next: int = (index + 1) % outline.size()
		var a := Vector3(outline[index].x, outline[index].y, -0.025)
		var b := Vector3(outline[next].x, outline[next].y, -0.025)
		var c := Vector3(b.x, b.y, 0.025)
		var d := Vector3(a.x, a.y, 0.025)
		_triangle(surface, Vector3(0.02, 0.02, -0.105), b, a, colors[index])
		_triangle(surface, Vector3(0, 0.01, 0.09), d, c, colors[index].darkened(0.18))
		_triangle(surface, a, b, c, colors[index].darkened(0.3))
		_triangle(surface, a, c, d, colors[index].darkened(0.3))
	var crystal := MeshInstance3D.new()
	crystal.name = "FacetedShard"
	crystal.mesh = surface.commit()
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.32
	material.metallic = 0.18
	material.emission_enabled = true
	material.emission = Color("8fadd4")
	material.emission_energy_multiplier = 0.28
	crystal.material_override = material
	_relic.add_child(crystal)
	# A broken metal ring gives the relic a silhouette distinct from scenery ore.
	var ring := SurfaceTool.new()
	ring.begin(Mesh.PRIMITIVE_TRIANGLES)
	for segment: int in range(28):
		var a: float = deg_to_rad(40.0 + segment * 10.0)
		var b: float = deg_to_rad(50.0 + segment * 10.0)
		for side: int in range(6):
			var u: float = float(side) * TAU / 6.0
			var v: float = float(side + 1) * TAU / 6.0
			_triangle(ring, _ring_point(a, u), _ring_point(b, v), _ring_point(b, u), Color.WHITE)
			_triangle(ring, _ring_point(a, u), _ring_point(a, v), _ring_point(b, v), Color.WHITE)
	for side: int in range(6):
		var u: float = float(side) * TAU / 6.0
		var v: float = float(side + 1) * TAU / 6.0
		var start := deg_to_rad(40.0)
		var end := deg_to_rad(320.0)
		_triangle(ring, Vector3(cos(start) * 0.255, sin(start) * 0.255, -0.02), _ring_point(start, v), _ring_point(start, u), Color.WHITE)
		_triangle(ring, Vector3(cos(end) * 0.255, sin(end) * 0.255, -0.02), _ring_point(end, u), _ring_point(end, v), Color.WHITE)
	var rim := MeshInstance3D.new()
	rim.name = "BrokenRing"
	rim.mesh = ring.commit()
	rim.rotation.z = -0.30
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color("c0ad82")
	metal.metallic = 0.65
	metal.roughness = 0.48
	rim.material_override = metal
	_relic.add_child(rim)


func _process(delta: float) -> void:
	_time += delta
	if _flight_elapsed < FLIGHT_DURATION:
		_flight_elapsed = minf(_flight_elapsed + delta, FLIGHT_DURATION)
		var progress: float = _flight_elapsed / FLIGHT_DURATION
		var eased: float = smoothstep(0.0, 1.0, progress)
		position = _flight_start.lerp(_flight_end, eased)
		position.y += sin(progress * PI) * 0.35
	_relic.position.y = sin(_time * 2.0) * 0.045
	_relic.rotation.y = sin(_time * 0.85) * 0.45
	_relic.rotation.z = sin(_time * 1.3) * 0.035


static func _ring_point(angle: float, cross_angle: float) -> Vector3:
	var radius: float = 0.255 + cos(cross_angle) * 0.016
	return Vector3(cos(angle) * radius, sin(angle) * radius, sin(cross_angle) * 0.016 - 0.02)


static func _triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
	for vertex: Vector3 in [a, b, c]:
		surface.set_normal((c - a).cross(b - a).normalized())
		surface.set_color(color)
		surface.add_vertex(vertex)
