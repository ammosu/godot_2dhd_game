extends SceneTree
## Atlas and live garden checks. Does not read or write player saves.

var _failures: int = 0
const MeadowDressing = preload("res://scripts/gameplay/meadow_dressing.gd")
const Houses = preload("res://scripts/gameplay/house_catalog.gd")


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)


func _run() -> void:
	_check_grass_atlas()
	for variant: String in ["ivory", "mauve", "blue"]:
		var atlas := load("res://assets/generated/flowers_%s.tres" % variant) as AtlasTexture
		_check(atlas.get_size() == Vector2(640, 640), "Flower canvas must be 640 square")
		var image := atlas.atlas.get_image()
		_check(image.has_mipmaps(), "Flower atlas needs mipmaps for stable minification")
		_check(image.detect_alpha() != Image.ALPHA_NONE, "Flowers need transparent backgrounds")
		var region := Rect2i(atlas.region)
		_check(Rect2i(Vector2i.ZERO, image.get_size()).encloses(region), "Flower crop outside image")
		var visible: int = 0
		var bottom: int = 0
		for y: int in range(region.position.y, region.end.y):
			for x: int in range(region.position.x, region.end.x):
				if image.get_pixel(x, y).a >= 0.5:
					visible += 1
					bottom = maxi(bottom, y - region.position.y + 1)
					_check(x > region.position.x and x < region.end.x - 1 and y > region.position.y and y < region.end.y - 1, "Flower silhouette clipped")
		_check(visible > 1000, "Flower crop empty")
		_check(is_equal_approx(float(bottom) + atlas.margin.position.y, 620.0), "Flower roots must share baseline")
	var state := root.get_node("GameState")
	state.get("flags")["intro_seen"] = true
	var scene := load("res://scenes/main.tscn") as PackedScene
	var world := scene.instantiate()
	root.add_child(world)
	await process_frame
	_check_surfaces(world.get("_map_root") as Node3D)
	_check_understory(world.get("_map_root") as Node3D)
	_check_borders(world.get("_map_root") as Node3D)
	_check_groundcover(world.get("_map_root") as Node3D)
	_check_entrances(world.get("_map_root") as Node3D)
	var count: int = 0
	var variants: Dictionary = {}
	var grass_count: int = 0
	var grass_variants: Dictionary = {}
	for child: Node in (world.get("_map_root") as Node3D).get_children():
		if child is Sprite3D and (child as Sprite3D).texture.resource_path.begins_with("res://assets/generated/grass_"):
			var grass := child as Sprite3D
			grass_count += 1
			grass_variants[grass.texture.resource_path] = true
			_check(grass.shaded and grass.billboard == BaseMaterial3D.BILLBOARD_FIXED_Y, "Grass must be shaded upright billboards")
			_check(grass.texture_filter == BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS and grass.alpha_cut == SpriteBase3D.ALPHA_CUT_DISCARD, "Grass filtering or transparency regressed")
			_check(is_equal_approx(grass.position.y - 328.0 * grass.pixel_size, 0.01), "Grass roots not grounded")
			_check(grass.pixel_size >= 0.00065 - 0.00000001 and grass.pixel_size <= 0.001 + 0.00000001, "Grass scale outside art bounds")
			_check(grass.get_child_count() == 0, "Grass must remain visual-only")
		if child is Sprite3D and (child as Sprite3D).texture.resource_path.begins_with("res://assets/generated/flowers_"):
			var flower := child as Sprite3D
			count += 1
			variants[flower.texture.resource_path] = true
			_check(flower.shaded and flower.billboard == BaseMaterial3D.BILLBOARD_FIXED_Y, "Flowers must be shaded upright billboards")
			_check(flower.texture_filter == BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS and flower.alpha_cut == SpriteBase3D.ALPHA_CUT_DISCARD, "Flower filtering or transparency regressed")
			_check(is_equal_approx(flower.position.y - 300.0 * flower.pixel_size, 0.01), "Flower roots not grounded")
			_check(flower.get_child_count() == 0, "Flowers should remain visual-only sprites")
	_check(count == 12 and variants.size() == 3, "Village needs twelve clumps across three variants")
	_check(grass_count > 100 and grass_count < 305 and grass_variants.size() == 3, "Village retains three grass variants around reserved flower beds")
	world.queue_free()
	await process_frame
	for singleton: String in ["GameAudio", "GameMusic", "GameAmbience"]:
		root.get_node(singleton).call("stop_all")
	await create_timer(0.25).timeout
	if _failures == 0:
		print("GARDEN_ART_TEST_PASS atlas alpha baseline variants grounding grass")
	quit(0 if _failures == 0 else 1)


func _check_grass_atlas() -> void:
	for variant: String in ["low", "seed", "fan"]:
		var atlas := load("res://assets/generated/grass_%s.tres" % variant) as AtlasTexture
		_check(atlas.get_size() == Vector2(704, 704), "Grass canvas must be 704 square")
		var image := atlas.atlas.get_image()
		_check(image.has_mipmaps(), "Grass needs mipmaps for stable minification")
		_check(image.detect_alpha() != Image.ALPHA_NONE, "Grass needs transparent background")
		var region := Rect2i(atlas.region)
		_check(Rect2i(Vector2i.ZERO, image.get_size()).encloses(region), "Grass crop outside image")
		var visible: int = 0
		var bottom: int = 0
		for y: int in range(region.position.y, region.end.y):
			for x: int in range(region.position.x, region.end.x):
				if image.get_pixel(x, y).a >= 0.5:
					visible += 1
					bottom = maxi(bottom, y - region.position.y + 1)
					_check(x > region.position.x and x < region.end.x - 1 and y > region.position.y and y < region.end.y - 1, "Grass silhouette clipped")
		_check(visible > 1000, "Grass crop empty")
		_check(is_equal_approx(float(bottom) + atlas.margin.position.y, 680.0), "Grass roots must share baseline")


func _check_entrance_point(point: Vector3, radius: float) -> void:
	# Independent local-space check, not the implementation's blocked rectangles.
	for home: Dictionary in Houses.HOMES:
		var local: Vector3 = Basis(Vector3.UP, -float(home.yaw)) * (point - (home.position as Vector3))
		var far_z: float = -2.85 * Houses.EXTERIOR_SCALE.z - 0.65
		var near_z: float = -Houses.EXTERIOR_COLLISION.z * 0.5
		var overlaps: bool = absf(local.x) < 0.7 + radius and local.z > far_z - radius and local.z < near_z + radius
		_check(not overlaps, "Foliage silhouette blocks doorstep/return spawn: " + str(home.id))


func _check_entrances(map_root: Node3D) -> void:
	for node: Node in map_root.find_children("*", "Sprite3D", true, false):
		var sprite := node as Sprite3D
		# Only ground foliage: window planters and other sprites are intentional.
		if sprite.get_parent() == map_root:
			if not sprite.texture.resource_path.begins_with("res://assets/generated/grass_") and not sprite.texture.resource_path.begins_with("res://assets/generated/flowers_"):
				continue
		elif sprite.get_parent().name not in [&"GardenBorders", &"MeadowUnderstory"]:
			continue
		_check_entrance_point(sprite.position, sprite.texture.get_width() * sprite.pixel_size * 0.5)
	if DisplayServer.get_name() != "headless":
		var batch := (map_root.get_node("GardenGroundcover") as MultiMeshInstance3D).multimesh
		for index: int in range(batch.instance_count):
			var transform := batch.get_instance_transform(index)
			_check_entrance_point(transform.origin, 0.36 * transform.basis.get_scale().x)
		for node: Node in map_root.get_children():
			if not str(node.name).begins_with("GardenFence"):
				continue
			for child: Node in node.get_children():
				var instance := child as MultiMeshInstance3D
				if instance == null:
					continue
				for index: int in range(instance.multimesh.instance_count):
					var transform: Transform3D = instance.global_transform * instance.multimesh.get_instance_transform(index)
					for home: Dictionary in Houses.HOMES:
						var local := Transform3D(Basis(Vector3.UP, float(home.yaw)), home.position).affine_inverse() * transform
						var bounds: AABB = local * instance.multimesh.mesh.get_aabb()
						var footprint := Rect2(Vector2(bounds.position.x, bounds.position.z), Vector2(bounds.size.x, bounds.size.z))
						var far_z: float = -2.85 * Houses.EXTERIOR_SCALE.z - 0.65
						var apron := Rect2(-0.7, far_z, 1.4, -Houses.EXTERIOR_COLLISION.z * 0.5 - far_z)
						_check(not footprint.intersects(apron), "Fence blocks door apron: " + str(home.id))
	print("GARDEN_ENTRANCES_CHECKED 8 independent local-space envelopes")


func _check_surfaces(map_root: Node3D) -> void:
	var roads: Dictionary[String, String] = {
		"CentralPlaza": "plaza_rect", "NorthRoad": "north_rect",
		"MarketRoad": "market_rect", "GateRoad": "gate_rect",
	}
	for surface_name: String in ["Ground", "CentralPlaza", "NorthRoad", "MarketRoad", "GateRoad"]:
		var surface_root := map_root.get_node(surface_name) as Node3D
		var surface := surface_root.get_child(0) as MeshInstance3D
		var material := surface.material_override as ShaderMaterial
		_check(material != null, "Village surface shader missing")
		if material == null:
			continue
		_check(material.get_shader_parameter("road_surface") == (surface_name != "Ground"), "Incorrect surface material mode")
		for road_name: String in roads:
			var road := map_root.get_node(road_name) as Node3D
			var box := (road.get_child(0) as MeshInstance3D).mesh as BoxMesh
			var expected := Vector4(road.position.x, road.position.z, box.size.x * 0.5, box.size.z * 0.5)
			_check(material.get_shader_parameter(roads[road_name]) == expected, "Shader road bounds disagree with geometry")
		if surface_name != "Ground":
			var box := surface.mesh as BoxMesh
			_check(is_equal_approx(surface_root.position.y + surface.position.y + box.size.y * 0.5, 0.006), "Visual paving must sit above ground without a raised curb")
			_check(surface.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "Paving must not cast a straight curb shadow")
	var plaza := map_root.get_node("CentralPlaza") as StaticBody3D
	var collision := plaza.get_child(1) as CollisionShape3D
	_check(is_equal_approx((collision.shape as BoxShape3D).size.y, 0.12), "Plaza collision must remain unchanged")
	var plaza_size: Vector3 = ((plaza.get_child(0) as MeshInstance3D).mesh as BoxMesh).size
	for road_name: String in ["MarketRoad", "GateRoad"]:
		var road := map_root.get_node(road_name) as Node3D
		var road_size: Vector3 = ((road.get_child(0) as MeshInstance3D).mesh as BoxMesh).size
		_check(absf(road.position.z - plaza.position.z) < (plaza_size.z + road_size.z) * 0.5, "Plaza leaves a thin grass seam before " + road_name)


func _check_understory(map_root: Node3D) -> void:
	var blocked := MeadowDressing.exclusions(map_root)
	var points := MeadowDressing.sample(blocked)
	_check(points == MeadowDressing.sample(blocked), "Understory must be deterministic")
	_check(points.size() > 100 and points.size() < 500, "Understory density outside expected budget")
	var dressing := map_root.get_node("MeadowUnderstory") as Node3D
	_check(dressing.get_child_count() > 50 and dressing.get_child_count() <= points.size(), "Understory retains spaced foliage")
	for index: int in range(dressing.get_child_count()):
		var planted := dressing.get_child(index) as Sprite3D
		var point := Vector3(planted.position.x, 0.01, planted.position.z)
		_check(points.has(point), "Understory must retain deterministic sample positions")
		for rectangle: Rect2 in blocked:
			_check(not rectangle.has_point(Vector2(point.x, point.z)), "Understory intrudes into map clearance")
		var sprite := dressing.get_child(index) as Sprite3D
		_check(sprite != null and sprite.get_child_count() == 0, "Understory must remain visual-only")
		_check(sprite.shaded and sprite.billboard == BaseMaterial3D.BILLBOARD_FIXED_Y, "Understory lighting or billboard regressed")
		_check(sprite.texture_filter == BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS, "Understory requires nearest filtering")
		_check(is_equal_approx(sprite.position.y - 328.0 * sprite.pixel_size, 0.01), "Understory is not grounded")
		_check(is_equal_approx(sprite.position.x, point.x) and is_equal_approx(sprite.position.z, point.z), "Understory position changed")
	print("UNDERSTORY_INSTANCES ", dressing.get_child_count())


func _check_borders(map_root: Node3D) -> void:
	var borders := map_root.get_node("GardenBorders")
	_check(borders.get_child_count() > 150 and borders.get_child_count() < 1100, "Border planting budget")
	var blocked := MeadowDressing.exclusions(map_root, 0.04)
	var variants: Dictionary = {}
	for child: Node in borders.get_children():
		var sprite := child as Sprite3D
		_check(sprite != null and sprite.get_child_count() == 0, "Borders must remain visual only")
		var texture := sprite.texture as AtlasTexture
		var baseline: float = sprite.get_meta("root_baseline")
		if not variants.has(texture.region):
			var image := texture.atlas.get_image()
			var region := Rect2i(texture.region)
			var bottom: int = 0
			var visible: int = 0
			for y: int in range(region.position.y, region.end.y):
				for x: int in range(region.position.x, region.end.x):
					if image.get_pixel(x, y).a >= 0.5:
						bottom = maxi(bottom, y + 1)
						visible += 1
						_check(x > region.position.x and x < region.end.x - 1, "Border crop clips leaves")
			var canvas_bottom: float = float(bottom) - texture.region.position.y + texture.margin.position.y
			_check(visible > 10000 and is_equal_approx(canvas_bottom, baseline), "Border alpha baseline or silhouette changed")
			variants[texture.region] = true
		_check(is_equal_approx(sprite.position.y - (baseline - texture.get_height() * 0.5) * sprite.pixel_size, 0.01), "Border roots drifted")
		_check(sprite.shaded and sprite.billboard == BaseMaterial3D.BILLBOARD_FIXED_Y, "Border shading and upright view")
		var expected_filter: int = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
		_check(sprite.alpha_cut == SpriteBase3D.ALPHA_CUT_DISCARD and sprite.texture_filter == expected_filter, "Border alpha and filtering")
		for rectangle: Rect2 in blocked:
			_check(not rectangle.grow(texture.get_width() * sprite.pixel_size * 0.5 - 0.00001).has_point(Vector2(sprite.position.x, sprite.position.z)), "Border silhouette enters clearance")
	_check(variants.size() == 5, "Three border shrubs plus upright grass and ivory flowers required")
	print("GARDEN_BORDER_INSTANCES ", borders.get_child_count())


func _check_groundcover(map_root: Node3D) -> void:
	var instance := map_root.get_node("GardenGroundcover") as MultiMeshInstance3D
	var batch := instance.multimesh
	_check(batch.instance_count > 400 and batch.instance_count < 4000, "Groundcover density budget")
	var quad := batch.mesh as QuadMesh
	var material := quad.material as StandardMaterial3D
	_check(material.billboard_mode == BaseMaterial3D.BILLBOARD_FIXED_Y and material.billboard_keep_scale, "Batched grass must stay upright and preserve scale")
	_check(material.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR and material.texture_filter == BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS, "Groundcover alpha/filtering")
	_check(is_equal_approx(quad.center_offset.y - quad.size.y * 0.5 + quad.size.y * 4.0 / 349.0, 0.0), "Groundcover alpha baseline")
	if DisplayServer.get_name() != "headless":
		var blocked := MeadowDressing.exclusions(map_root, 0.04)
		for index: int in range(batch.instance_count):
			var transform := batch.get_instance_transform(index)
			_check(is_equal_approx(transform.origin.y, 0.01), "Groundcover roots drifted")
			var radius := 0.36 * transform.basis.get_scale().x
			for rectangle: Rect2 in blocked:
				_check(not rectangle.grow(radius - 0.00001).has_point(Vector2(transform.origin.x, transform.origin.z)), "Groundcover intrudes on paths")
	print("GARDEN_GROUNDCOVER_INSTANCES ", batch.instance_count)
