extends RefCounted
## Keep one owner at coplanar road intersections without changing collisions.
const SURFACE: Shader = preload("res://shaders/village_surface.gdshader")
const MAX_OVERLAPS: int = 32

static func configure(map_root: Node3D) -> void:
	var previous: Array[Dictionary] = []
	for root: Node in map_root.get_children():
		if not root is Node3D or root.get_child_count() == 0:
			continue
		var surface := root.get_child(0) as MeshInstance3D
		if surface == null or not surface.mesh is BoxMesh:
			continue
		var material := surface.material_override as ShaderMaterial
		if material == null or material.shader != SURFACE:
			continue
		var box := surface.mesh as BoxMesh
		var center: Vector3 = surface.global_position
		var top: float = center.y + box.size.y * 0.5
		var bounds := Rect2(Vector2(center.x, center.z) - Vector2(box.size.x, box.size.z) * 0.5, Vector2(box.size.x, box.size.z))
		var overlaps := PackedVector4Array()
		for earlier: Dictionary in previous:
			var other: Rect2 = earlier.bounds
			if absf(top - float(earlier.top)) < 0.0001 and bounds.intersects(other):
				overlaps.append(Vector4(other.position.x, other.position.y, other.end.x, other.end.y))
		assert(overlaps.size() <= MAX_OVERLAPS, "Village surface overlap uniform capacity exceeded")
		material.set_shader_parameter("overlap_count", overlaps.size())
		overlaps.resize(MAX_OVERLAPS)
		material.set_shader_parameter("overlap_rects", overlaps)
		previous.append({"bounds": bounds, "top": top})
