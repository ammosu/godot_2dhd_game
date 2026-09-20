extends SceneTree
## Atlas and live garden checks. Does not read or write player saves.

var _failures: int = 0
const MeadowDressing = preload("res://scripts/gameplay/meadow_dressing.gd")


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
			_check(grass.texture_filter == BaseMaterial3D.TEXTURE_FILTER_NEAREST and grass.alpha_cut == SpriteBase3D.ALPHA_CUT_DISCARD, "Grass filtering or transparency regressed")
			_check(is_equal_approx(grass.position.y - 328.0 * grass.pixel_size, 0.01), "Grass roots not grounded")
			_check(grass.pixel_size >= 0.00065 - 0.00000001 and grass.pixel_size <= 0.001 + 0.00000001, "Grass scale outside art bounds")
			_check(grass.get_child_count() == 0, "Grass must remain visual-only")
		if child is Sprite3D and (child as Sprite3D).texture.resource_path.begins_with("res://assets/generated/flowers_"):
			var flower := child as Sprite3D
			count += 1
			variants[flower.texture.resource_path] = true
			_check(flower.shaded and flower.billboard == BaseMaterial3D.BILLBOARD_FIXED_Y, "Flowers must be shaded upright billboards")
			_check(flower.texture_filter == BaseMaterial3D.TEXTURE_FILTER_NEAREST and flower.alpha_cut == SpriteBase3D.ALPHA_CUT_DISCARD, "Flower filtering or transparency regressed")
			_check(is_equal_approx(flower.position.y - 300.0 * flower.pixel_size, 0.01), "Flower roots not grounded")
			_check(flower.get_child_count() == 0, "Flowers should remain visual-only sprites")
	_check(count == 12 and variants.size() == 3, "Village needs twelve clumps across three variants")
	_check(grass_count == 305 and grass_variants.size() == 3, "Village needs 305 grass clumps across three variants")
	world.queue_free()
	await process_frame
	if _failures == 0:
		print("GARDEN_ART_TEST_PASS atlas alpha baseline variants grounding grass")
	quit(0 if _failures == 0 else 1)


func _check_grass_atlas() -> void:
	for variant: String in ["low", "seed", "fan"]:
		var atlas := load("res://assets/generated/grass_%s.tres" % variant) as AtlasTexture
		_check(atlas.get_size() == Vector2(704, 704), "Grass canvas must be 704 square")
		var image := atlas.atlas.get_image()
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


func _check_understory(map_root: Node3D) -> void:
	var blocked := MeadowDressing.exclusions(map_root)
	var points := MeadowDressing.sample(blocked)
	_check(points == MeadowDressing.sample(blocked), "Understory must be deterministic")
	_check(points.size() > 100 and points.size() < 500, "Understory density outside expected budget")
	var dressing := map_root.get_node("MeadowUnderstory") as Node3D
	_check(dressing.get_child_count() == points.size(), "Understory instances disagree with layout")
	for index: int in range(points.size()):
		var point := points[index]
		for rectangle: Rect2 in blocked:
			_check(not rectangle.has_point(Vector2(point.x, point.z)), "Understory intrudes into map clearance")
		var sprite := dressing.get_child(index) as Sprite3D
		_check(sprite != null and sprite.get_child_count() == 0, "Understory must remain visual-only")
		_check(sprite.shaded and sprite.billboard == BaseMaterial3D.BILLBOARD_FIXED_Y, "Understory lighting or billboard regressed")
		_check(sprite.texture_filter == BaseMaterial3D.TEXTURE_FILTER_NEAREST, "Understory requires nearest filtering")
		_check(is_equal_approx(sprite.position.y - 328.0 * sprite.pixel_size, 0.01), "Understory is not grounded")
		_check(is_equal_approx(sprite.position.x, point.x) and is_equal_approx(sprite.position.z, point.z), "Understory position changed")
	print("UNDERSTORY_INSTANCES ", points.size())
