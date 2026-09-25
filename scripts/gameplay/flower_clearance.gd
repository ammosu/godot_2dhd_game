extends RefCounted
## Flower art already includes leaves. Reserve its footprint across independently
## generated foliage layers so rotating billboards cannot intersect its plane.
const GAP: float = 0.025

static func footprint(sprite: Sprite3D) -> Vector3:
	var scale: Vector3 = sprite.global_basis.get_scale().abs()
	return Vector3(sprite.global_position.x, sprite.global_position.z, sprite.texture.get_width() * sprite.pixel_size * maxf(scale.x, scale.z) * 0.5)

static func overlaps(point: Vector3, radius: float, flowers: Array[Vector3]) -> bool:
	for flower: Vector3 in flowers:
		if Vector2(point.x, point.z).distance_squared_to(Vector2(flower.x, flower.y)) < pow(radius + flower.z + GAP, 2):
			return true
	return false

static func apply(map_root: Node3D) -> void:
	var flowers: Array[Vector3] = []
	var foliage: Array[Sprite3D] = []
	for node: Node in map_root.find_children("*", "Sprite3D", true, false):
		var sprite := node as Sprite3D
		if sprite.texture == null or sprite.billboard != BaseMaterial3D.BILLBOARD_FIXED_Y:
			continue
		var path: String = sprite.texture.resource_path
		if path.begins_with("res://assets/generated/flowers_"):
			flowers.append(footprint(sprite))
		elif path.begins_with("res://assets/generated/grass_") or sprite.get_parent().name == &"GardenBorders":
			foliage.append(sprite)
	for sprite: Sprite3D in foliage:
		sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
		if overlaps(sprite.global_position, footprint(sprite).z, flowers):
			sprite.free()
	# Compact the village's low grass batch as well as individual sprites.
	var cover := map_root.get_node_or_null("GardenGroundcover") as MultiMeshInstance3D
	if cover == null:
		return
	var batch: MultiMesh = cover.multimesh
	var quad := batch.mesh as QuadMesh
	(quad.material as StandardMaterial3D).texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	var kept: Array[Transform3D] = []
	# Keep CPU transforms available in headless runs (the dummy renderer does not).
	var transforms: Array[Transform3D] = cover.get_meta("foliage_transforms")
	for local: Transform3D in transforms:
		var transform: Transform3D = cover.global_transform * local
		var scale: Vector3 = transform.basis.get_scale().abs()
		if not overlaps(transform.origin, quad.size.x * maxf(scale.x, scale.z) * 0.5, flowers):
			kept.append(local)
	batch.instance_count = kept.size()
	for index: int in range(kept.size()):
		batch.set_instance_transform(index, kept[index])
	cover.set_meta("foliage_transforms", kept)
