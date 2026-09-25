extends SceneTree
var failures: int = 0
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var state: Node = root.get_node("GameState")
	state.reset_new_game(false)
	state.flags.intro_seen = true
	var world: Node3D = load("res://scenes/main.tscn").instantiate()
	root.add_child(world)
	world.set("_test_mode", true)
	for map_id: String in ["village", "east_road", "firefly_forest", "caravan_road", "starbay", "village"]:
		world.call("_load_map", map_id, "default")
		var map: Node3D = world.get("_map_root")
		var flowers: Array[Sprite3D] = []
		var grasses: Array[Sprite3D] = []
		for node: Node in map.find_children("*", "Sprite3D", true, false):
			var sprite := node as Sprite3D
			if sprite.texture == null or sprite.billboard != BaseMaterial3D.BILLBOARD_FIXED_Y:
				continue
			if sprite.texture.resource_path.contains("/flowers_"):
				flowers.append(sprite)
			elif sprite.texture.resource_path.contains("/grass_") or sprite.get_parent().name == &"GardenBorders":
				grasses.append(sprite)
		var near: int = 0
		var exact: int = 0
		for flower: Sprite3D in flowers:
			for grass: Sprite3D in grasses:
				var d: float = Vector2(flower.global_position.x, flower.global_position.z).distance_to(Vector2(grass.global_position.x, grass.global_position.z))
				if d < 0.001:
					exact += 1
				if d + 0.00001 < (flower.texture.get_width() * flower.pixel_size + grass.texture.get_width() * grass.pixel_size) * 0.5 + 0.025:
					near += 1
		if near > 0 or flowers.is_empty() or grasses.is_empty():
			failures += 1
			push_error("Flower/foliage footprints intersect in " + map_id)
		var cover := map.get_node_or_null("GardenGroundcover") as MultiMeshInstance3D
		if cover != null:
			var transforms: Array[Transform3D] = cover.get_meta("foliage_transforms")
			for transform: Transform3D in transforms:
				for flower: Sprite3D in flowers:
					var radius: float = 0.36 * transform.basis.get_scale().x + flower.texture.get_width() * flower.pixel_size * 0.5 + 0.025
					if Vector2(transform.origin.x, transform.origin.z).distance_to(Vector2(flower.global_position.x, flower.global_position.z)) + 0.00001 < radius:
						failures += 1
						push_error("Groundcover overlaps flowers")
		if DisplayServer.get_name() != "headless" and map_id in ["village", "east_road"]:
			var player: Node3D = world.get_node("Player")
			player.set_physics_process(false)
			player.position = Vector3(-7.5, 0.1, 7.8) if map_id == "village" else Vector3(-4.7, 0.2, 3.4)
			var rig: Node3D = world.get_node("CameraRig")
			for angle: int in [0, 45, 90]:
				rig.set("_target_yaw", deg_to_rad(angle))
				rig.call("snap_to_target")
				await create_timer(0.15).timeout
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("/tmp/flower-clearance-%s-%s-%d.png" % [RenderingServer.get_current_rendering_method(), map_id, angle])
		print("FOLIAGE_AUDIT ", map_id, " flowers=", flowers.size(), " grass=", grasses.size(), " overlapping_pairs=", near, " same_origin_pairs=", exact)
	world.free()
	for singleton: String in ["GameAudio", "GameMusic", "GameAmbience"]:
		root.get_node(singleton).call("stop_all")
	await create_timer(0.25).timeout
	if failures == 0:
		print("FLOWER_CLEARANCE_TEST_PASS village roads forest city reload")
	quit(0 if failures == 0 else 1)
