extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.get_node("GameState").get("flags")["intro_seen"] = true
	var world := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(world)
	world.call("_load_map", "ruins", "from_village")
	var map := world.get("_map_root") as Node3D
	var ground := map.get_node("RuinGround") as StaticBody3D
	assert(ground.position.is_equal_approx(Vector3(0, -0.35, 0)))
	var visual := ground.get_child(0) as MeshInstance3D
	assert((visual.mesh as BoxMesh).size.is_equal_approx(Vector3(34, 0.7, 32)))
	var soil := visual.material_override as ShaderMaterial
	assert(soil != null and soil.shader.resource_path == "res://shaders/ruin_soil.gdshader")
	var mineral := soil.get_shader_parameter("mineral_texture") as Texture2D
	assert(mineral != null and mineral.resource_path == "res://assets/generated/moon_lamp_cut_limestone_albedo.png")
	var collision := ground.get_child(1) as CollisionShape3D
	assert(not collision.disabled)
	assert((collision.shape as BoxShape3D).size.is_equal_approx(Vector3(34, 0.7, 32)))
	for name: String in ["RuinCourt", "WestRuinCourt", "EastRuinCourt"]:
		var court_root := map.get_node(name) as StaticBody3D
		var court := court_root.get_child(0) as MeshInstance3D
		var material := court.material_override as ShaderMaterial
		assert(material.shader.resource_path == "res://shaders/ruin_court.gdshader")
		assert((material.get_shader_parameter("stone_texture") as Texture2D).resource_path == "res://assets/generated/ruin_flagstone.png")
		var size: Vector3 = (court.mesh as BoxMesh).size
		assert(size.is_equal_approx(Vector3(14, 0.12, 17) if name == "RuinCourt" else Vector3(5.5, 0.1, 5.5)))
		assert((court_root.get_child(1) as CollisionShape3D).shape is BoxShape3D)
		assert(((court_root.get_child(1) as CollisionShape3D).shape as BoxShape3D).size.is_equal_approx(size))
		assert(material.get_shader_parameter("court_rect") == Vector4(court_root.position.x, court_root.position.z, size.x / 2.0, size.z / 2.0))
		assert(material.get_shader_parameter("stone_scale") == Vector2(size.x / 4.0, size.z / 4.0))
		assert(court.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
		for parameter: String in ["neighbor_a", "neighbor_b"]:
			var neighbor: Vector4 = material.get_shader_parameter(parameter)
			assert(neighbor.z > 0.0 and neighbor.w > 0.0)
			assert(neighbor != material.get_shader_parameter("court_rect"))
	if DisplayServer.get_name() != "headless":
		var player := world.get_node("Player") as Node3D
		player.set_physics_process(false)
		player.position = Vector3(-7, 0.1, 6.5)
		world.get_node("CameraRig").call("snap_to_target")
		for frame: int in range(45):
			await process_frame
		await RenderingServer.frame_post_draw
		var camera := world.get_node("CameraRig/Camera3D") as Camera3D
		var point := camera.unproject_position(Vector3(-10.5, 0.001, 7.5))
		var pixels := root.get_texture().get_image()
		assert(point.x > 5 and point.y > 5 and point.x < pixels.get_width() - 5 and point.y < pixels.get_height() - 5)
		var brightness: float = 0.0
		for x: int in range(-4, 5):
			for y: int in range(-4, 5):
				brightness += pixels.get_pixel(int(point.x) + x, int(point.y) + y).get_luminance()
		brightness /= 81.0
		print("RUIN_SOIL_RENDER_SAMPLE ", RenderingServer.get_current_rendering_method(), " luminance=", brightness)
		assert(brightness > 0.10 and brightness < 0.45, "Soil must not become near-black or overbright")
	world.call("_load_map", "village", "from_ruins")
	map = world.get("_map_root") as Node3D
	var meadow := (map.get_node("Ground").get_child(0) as MeshInstance3D).material_override as ShaderMaterial
	assert(meadow.shader.resource_path == "res://shaders/village_surface.gdshader")
	world.free()
	await process_frame
	await process_frame
	for singleton: String in ["GameAudio", "GameMusic", "GameAmbience"]:
		root.get_node(singleton).call("stop_all")
	await create_timer(0.25).timeout
	print("RUIN_SOIL_TEST_PASS material collision courts village_unchanged")
	quit()
