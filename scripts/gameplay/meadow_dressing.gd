extends RefCounted
## Deterministic low foliage islands. Visual-only, with map-derived clearances.

const SEED: int = 91027
const PATCHES: Array[Vector4] = [
	Vector4(-4.7, 7.6, 3.0, 2.4), Vector4(5.1, 7.9, 3.2, 2.1),
	Vector4(-8.0, 2.3, 2.4, 1.3), Vector4(8.0, 2.3, 2.4, 1.3),
	Vector4(-7.5, -6.6, 2.8, 1.6), Vector4(7.3, -6.5, 2.7, 1.5),
]
const TEXTURES: Array[Texture2D] = [
	preload("res://assets/generated/grass_low.tres"),
	preload("res://assets/generated/grass_fan.tres"),
]


static func exclusions(map_root: Node3D) -> Array[Rect2]:
	var blocked: Array[Rect2] = []
	for road_name: String in ["CentralPlaza", "NorthRoad", "MarketRoad", "GateRoad"]:
		var road := map_root.get_node(road_name) as Node3D
		var size := ((road.get_child(0) as MeshInstance3D).mesh as BoxMesh).size
		blocked.append(Rect2(Vector2(road.position.x, road.position.z) - Vector2(size.x, size.z) * 0.5, Vector2(size.x, size.z)).grow(0.18))
	for node: Node in map_root.find_children("*", "CollisionShape3D", true, false):
		var collision := node as CollisionShape3D
		if collision.get_parent().name == &"Ground":
			continue
		var size := Vector3.ZERO
		if collision.shape is BoxShape3D:
			size = (collision.shape as BoxShape3D).size
		elif collision.shape is CylinderShape3D:
			var radius := (collision.shape as CylinderShape3D).radius
			size = Vector3(radius * 2.0, 1.0, radius * 2.0)
		elif collision.shape is SphereShape3D:
			var radius := (collision.shape as SphereShape3D).radius
			size = Vector3.ONE * radius * 2.0
		elif collision.shape is CapsuleShape3D:
			var radius := (collision.shape as CapsuleShape3D).radius
			size = Vector3(radius * 2.0, 1.0, radius * 2.0)
		if size == Vector3.ZERO:
			continue
		var bounds: AABB = collision.global_transform * AABB(-size * 0.5, size)
		blocked.append(Rect2(Vector2(bounds.position.x, bounds.position.z), Vector2(bounds.size.x, bounds.size.z)).grow(0.45))
	# Keep the animal pen's center and its existing animated pig legible.
	blocked.append(Rect2(7.7, 7.6, 1.6, 1.6))
	return blocked


static func sample(blocked: Array[Rect2]) -> Array[Vector3]:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var points: Array[Vector3] = []
	for patch: Vector4 in PATCHES:
		for _attempt: int in range(180):
			var angle := rng.randf() * TAU
			var radius := sqrt(rng.randf())
			var position := Vector2(patch.x, patch.y) + Vector2(cos(angle) * patch.z, sin(angle) * patch.w) * radius
			# Ragged islands and internal gaps, not rectangular stripes or a grid.
			var density := 0.68 + 0.20 * sin(position.x * 2.6 + sin(position.y * 1.8))
			if rng.randf() > density * (1.0 - radius * 0.38):
				continue
			var occupied := false
			for rectangle: Rect2 in blocked:
				if rectangle.has_point(position):
					occupied = true
					break
			if occupied:
				continue
			for existing: Vector3 in points:
				if Vector2(existing.x, existing.z).distance_squared_to(position) < 0.13 * 0.13:
					occupied = true
					break
			if not occupied:
				points.append(Vector3(position.x, 0.01, position.y))
	return points


static func build(map_root: Node3D) -> void:
	var dressing := Node3D.new()
	dressing.name = "MeadowUnderstory"
	map_root.add_child(dressing)
	var points := sample(exclusions(map_root))
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED + 1
	for index: int in range(points.size()):
		var sprite := Sprite3D.new()
		sprite.texture = TEXTURES[index % TEXTURES.size()]
		sprite.pixel_size = rng.randf_range(0.00055, 0.00085)
		sprite.position = points[index] + Vector3.UP * 328.0 * sprite.pixel_size
		sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		sprite.shaded = true
		sprite.double_sided = true
		sprite.flip_h = index % 2 == 0
		dressing.add_child(sprite)
