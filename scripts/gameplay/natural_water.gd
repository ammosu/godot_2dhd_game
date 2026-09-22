extends Node3D
## A shallow shelf and a blocked deep channel share the same sampled shoreline.

var _sections: Array[Vector3] = [] # x, z, half width; strips run along X.
var _ford: bool = false
var _material: ShaderMaterial
var _last_step: Vector3 = Vector3.INF
var _ripple_age: float = 2.0


static func pond(parent: Node3D, center: Vector3, size: Vector2) -> Node3D:
	var water := new()
	water.name = "NaturalPond"
	water.position = center
	for index: int in range(33):
		var t: float = -1.0 + index / 16.0
		var width: float = sqrt(maxf(0.0, 1.0 - t * t)) * size.y * 0.5
		water._sections.append(Vector3(t * size.x * 0.5, sin(t * 5.0) * 0.16, width))
	parent.add_child(water)
	water._build()
	return water


static func creek(parent: Node3D, center: Vector3) -> Node3D:
	var water := new()
	water.name = "WadingCreek"
	water.position = center
	water._ford = true
	for index: int in range(31):
		var x: float = index - 15.0
		water._sections.append(Vector3(x, sin(x * 0.32) * 0.65, 1.3 + cos(x * 0.45) * 0.18))
	parent.add_child(water)
	water._build()
	return water


func _deep_width(section: Vector3) -> float:
	return 0.0 if _ford and absf(section.x) <= 2.0 else maxf(0.0, section.z - 0.85)


func _build() -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var body := StaticBody3D.new()
	body.name = "DeepWaterBarrier"
	add_child(body)
	for index: int in range(_sections.size() - 1):
		var a: Vector3 = _sections[index]
		var b: Vector3 = _sections[index + 1]
		var da: float = _deep_width(a)
		var db: float = _deep_width(b)
		var rows_a: Array[float] = [-a.z, -da, da, a.z]
		var rows_b: Array[float] = [-b.z, -db, db, b.z]
		for band: int in range(3):
			var points: Array[Vector3] = [Vector3(a.x, 0, a.y + rows_a[band]), Vector3(b.x, 0, b.y + rows_b[band]), Vector3(b.x, 0, b.y + rows_b[band + 1]), Vector3(a.x, 0, a.y + rows_a[band + 1])]
			for vertex: int in [0, 2, 1, 0, 3, 2]:
				var edge: bool = (band == 0 and vertex in [0, 1]) or (band == 2 and vertex in [2, 3])
				var depth: float = 0.0 if edge else (1.0 if (da if vertex in [0, 3] else db) > 0.0 else 0.18)
				surface.set_color(Color(depth, 0, 0, 1))
				surface.set_uv(Vector2(points[vertex].x, points[vertex].z))
				surface.set_normal(Vector3.UP)
				surface.add_vertex(points[vertex])
		if da + db > 0.01:
			var hull := PackedVector3Array()
			for y: float in [-0.4, 2.0]:
				for point: Vector3 in [Vector3(a.x, y, a.y - da), Vector3(a.x, y, a.y + da), Vector3(b.x, y, b.y - db), Vector3(b.x, y, b.y + db)]:
					hull.append(point)
			var shape := ConvexPolygonShape3D.new()
			shape.points = hull
			var collider := CollisionShape3D.new()
			collider.shape = shape
			body.add_child(collider)
	var mesh := MeshInstance3D.new()
	mesh.name = "WaterSurface"
	mesh.mesh = surface.commit()
	_material = ShaderMaterial.new()
	_material.shader = preload("res://shaders/natural_water.gdshader")
	_material.set_shader_parameter("flow_speed", 0.65 if _ford else 0.12)
	mesh.material_override = _material
	add_child(mesh)


func depth_at(local_point: Vector3) -> float:
	for index: int in range(_sections.size() - 1):
		var a: Vector3 = _sections[index]
		var b: Vector3 = _sections[index + 1]
		if local_point.x < a.x or local_point.x > b.x:
			continue
		var t: float = inverse_lerp(a.x, b.x, local_point.x)
		var width: float = lerpf(a.z, b.z, t)
		var offset: float = absf(local_point.z - lerpf(a.y, b.y, t))
		if offset > width:
			return -1.0
		var deep: float = lerpf(_deep_width(a), _deep_width(b), t)
		return 1.0 if deep > 0.0 and offset < deep else 0.2
	return -1.0


func _process(delta: float) -> void:
	_ripple_age += delta
	var scene: Node = get_tree().current_scene
	var player: Node3D = scene.get_node_or_null("Player") as Node3D if scene != null else null
	if player != null:
		var point: Vector3 = to_local(player.global_position)
		if absf(point.y) < 0.18 and depth_at(point) >= 0.0 and point.distance_to(_last_step) > 0.45:
			_last_step = point
			_ripple_age = 0.0
			_material.set_shader_parameter("step_position", Vector2(point.x, point.z))
	_material.set_shader_parameter("ripple_age", _ripple_age)
