extends RefCounted
## Deterministic low foliage islands. Visual-only, with map-derived clearances.

const SEED: int = 91027
const Houses = preload("res://scripts/gameplay/house_catalog.gd")
const PATCHES: Array[Vector4] = [
	Vector4(-4.7, 7.6, 3.0, 2.4), Vector4(5.1, 7.9, 3.2, 2.1),
	Vector4(-8.0, 2.3, 2.4, 1.3), Vector4(8.0, 2.3, 2.4, 1.3),
	Vector4(-7.5, -6.6, 2.8, 1.6), Vector4(7.3, -6.5, 2.7, 1.5),
]
const TEXTURES: Array[Texture2D] = [
	preload("res://assets/generated/grass_low.tres"),
	preload("res://assets/generated/grass_fan.tres"),
]


static func exclusions(map_root: Node3D, margin: float = 0.45) -> Array[Rect2]:
	var blocked: Array[Rect2] = []
	# Door aprons are walkable, not collision volumes. Reserve them explicitly
	# so every foliage layer leaves the doorstep and return spawn readable.
	for home: Dictionary in Houses.HOMES:
		var near_z: float = -Houses.EXTERIOR_COLLISION.z * 0.5
		var far_z: float = -2.85 * Houses.EXTERIOR_SCALE.z - 0.65
		var apron := AABB(Vector3(-0.7, 0.0, far_z), Vector3(1.4, 0.1, near_z - far_z))
		var bounds: AABB = Transform3D(Basis(Vector3.UP, float(home.yaw)), home.position) * apron
		blocked.append(Rect2(Vector2(bounds.position.x, bounds.position.z), Vector2(bounds.size.x, bounds.size.z)).grow(margin))
	for road_name: String in ["CentralPlaza", "NorthRoad", "MarketRoad", "GateRoad"]:
		var road := map_root.get_node(road_name) as Node3D
		var size := ((road.get_child(0) as MeshInstance3D).mesh as BoxMesh).size
		blocked.append(Rect2(Vector2(road.position.x, road.position.z) - Vector2(size.x, size.z) * 0.5, Vector2(size.x, size.z)).grow(minf(0.18, margin)))
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
		blocked.append(Rect2(Vector2(bounds.position.x, bounds.position.z), Vector2(bounds.size.x, bounds.size.z)).grow(margin))
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
		var dryness: float = sin(sprite.position.x * 0.29 + sin(sprite.position.z * 0.37)) * 0.5 + 0.5
		sprite.modulate *= Color.WHITE.lerp(Color("c4ba8b"), dryness * 0.32)
		dressing.add_child(sprite)
	_build_borders(map_root)
	_build_groundcover(map_root)


static func _build_groundcover(map_root: Node3D) -> void:
	var texture := preload("res://assets/generated/grass_low.tres") as AtlasTexture
	var source_size := texture.atlas.get_size()
	var material := StandardMaterial3D.new()
	material.albedo_texture = texture.atlas
	material.uv1_scale = Vector3(texture.region.size.x / source_size.x, texture.region.size.y / source_size.y, 1.0)
	material.uv1_offset = Vector3(texture.region.position.x / source_size.x, texture.region.position.y / source_size.y, 0.0)
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	material.alpha_scissor_threshold = 0.5
	material.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	material.billboard_keep_scale = true
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.roughness = 1.0
	var quad := QuadMesh.new()
	quad.size = Vector2(0.72, 0.72 * 349.0 / 629.0)
	# The source crop has four transparent pixels below the measured roots.
	quad.center_offset.y = quad.size.y * (0.5 - 4.0 / 349.0)
	quad.material = material
	var blocked := exclusions(map_root, 0.04)
	var transforms: Array[Transform3D] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED + 3
	for row: int in range(70):
		for column: int in range(70):
			var point := Vector3(-12.0 + column * 0.35 + rng.randf_range(-0.12, 0.12), 0.01, -10.0 + row * 0.35 + rng.randf_range(-0.12, 0.12))
			var scale_factor := rng.randf_range(0.75, 1.15)
			var clear := true
			for rectangle: Rect2 in blocked:
				if rectangle.grow(0.36 * scale_factor).has_point(Vector2(point.x, point.z)):
					clear = false
					break
			if clear:
				transforms.append(Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * scale_factor), point))
	var batch := MultiMesh.new()
	batch.transform_format = MultiMesh.TRANSFORM_3D
	batch.mesh = quad
	batch.instance_count = transforms.size()
	for index: int in range(transforms.size()):
		batch.set_instance_transform(index, transforms[index])
	var instance := MultiMeshInstance3D.new()
	instance.name = "GardenGroundcover"
	instance.multimesh = batch
	instance.custom_aabb = AABB(Vector3(-13, -0.1, -11), Vector3(27, 1.2, 27))
	map_root.add_child(instance)


static func _build_borders(map_root: Node3D) -> void:
	var layer := Node3D.new()
	layer.name = "GardenBorders"
	map_root.add_child(layer)
	var atlas := preload("res://assets/generated/garden_borders_v1.png")
	var regions: Array[Rect2] = [Rect2(0, 0, 504, 1024), Rect2(504, 0, 516, 1024), Rect2(1024, 0, 512, 1024)]
	var baselines: Array[float] = [696.0, 714.0, 697.0]
	var textures: Array[AtlasTexture] = []
	for region: Rect2 in regions:
		var texture := AtlasTexture.new()
		texture.atlas = atlas
		texture.region = region
		textures.append(texture)
	var blocked := exclusions(map_root, 0.04)
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED + 2
	var border_points: Array[Vector3] = []
	# Connected beds follow actual free ground, rather than six isolated islands.
	# Jittered overlapping crowns hide the sampling grid without blocking paths.
	for row: int in range(38):
		for column: int in range(38):
			border_points.append(Vector3(-12.0 + column * 0.65 + rng.randf_range(-0.16, 0.16), 0.01, -10.0 + row * 0.65 + rng.randf_range(-0.16, 0.16)))
	var mix_rng := RandomNumberGenerator.new()
	mix_rng.seed = SEED + 4
	for index: int in range(border_points.size()):
		var point := border_points[index]
		var pixel_size := rng.randf_range(0.0018, 0.0025)
		var radius := 258.0 * pixel_size
		var clear := true
		for rectangle: Rect2 in blocked:
			if rectangle.grow(radius).has_point(Vector2(point.x, point.z)):
				clear = false
				break
		if not clear:
			# Low edge flowers fill narrow beds where a full shrub would overhang.
			pixel_size = 0.0009
			radius = 258.0 * pixel_size
			clear = true
			for rectangle: Rect2 in blocked:
				if rectangle.grow(radius).has_point(Vector2(point.x, point.z)):
					clear = false
					break
			if not clear:
				continue
		var variant: int = index % 3
		var sprite := Sprite3D.new()
		sprite.texture = textures[variant]
		var baseline: float = baselines[variant]
		var kind: int = mix_rng.randi_range(0, 4)
		# Reuse the same clearance envelope, replacing some broad crowns with
		# upright silhouettes instead of adding another overlapping foliage layer.
		if kind == 2 or kind == 3:
			sprite.texture = preload("res://assets/generated/grass_seed.tres")
			baseline = 680.0
			pixel_size = radius * 2.0 / sprite.texture.get_width()
		elif kind == 4:
			sprite.texture = preload("res://assets/generated/flowers_ivory.tres")
			baseline = 620.0
			pixel_size = radius * 1.4 / sprite.texture.get_width()
		sprite.pixel_size = pixel_size
		sprite.position = point + Vector3.UP * (baseline - sprite.texture.get_height() * 0.5) * pixel_size
		sprite.set_meta("root_baseline", baseline)
		sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS if kind == 4 else BaseMaterial3D.TEXTURE_FILTER_NEAREST
		sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		sprite.shaded = true
		sprite.modulate = Color(0.68, 0.76, 0.80) if kind < 2 else Color(0.85, 0.88, 0.9)
		sprite.double_sided = true
		sprite.flip_h = index % 2 == 0
		var dryness: float = sin(sprite.position.x * 0.29 + sin(sprite.position.z * 0.37)) * 0.5 + 0.5
		sprite.modulate *= Color.WHITE.lerp(Color("c4ba8b"), dryness * 0.32)
		layer.add_child(sprite)
