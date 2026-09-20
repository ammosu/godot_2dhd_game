extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var map := preload("res://scripts/ui/mini_map.gd").new()
	map.size = Vector2(226, 226)
	for map_id: String in ["village", "ruins", "house_01"]:
		map.set_map(map_id)
		for step: int in range(32):
			var yaw := step * TAU / 32.0
			map.set_camera_yaw(yaw)
			var center: Vector2 = map._world_to_map(Vector3.ZERO)
			var north: Vector2 = map._world_to_map(Vector3(0, 0, -1)) - center
			assert(north.normalized().is_equal_approx(Vector2.UP.rotated(yaw)))
			assert(map._get_map_rect().has_point(map._world_to_map(Vector3(999, 0, 999))))
	map.free()
	root.get_node("GameState").get("flags")["intro_seen"] = true
	var world := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(world)
	await process_frame
	var terrain: Node3D = world.get("_map_root")
	var ground := terrain.get_node("Ground").get_child(0) as MeshInstance3D
	assert((ground.mesh as BoxMesh).size == Vector3(46, .7, 40))
	var minimap: Control = world.get("_mini_map")
	var camera := world.get_node("CameraRig/Camera3D") as Camera3D
	for yaw: float in [0.0, PI / 4, PI, -PI / 2]:
		world.get_node("CameraRig").rotation.y = yaw
		minimap.call("_process", 0.0)
		assert(is_equal_approx(float(minimap.get("_camera_yaw")), wrapf(atan2(-camera.global_basis.x.z, camera.global_basis.x.x), -PI, PI)))
	# Ground is continuous across the old boundary, and the new border is solid.
	var space := root.world_3d.direct_space_state
	for point: Vector3 in [Vector3(19, 2, 0), Vector3(-19, 2, 0), Vector3(0, 2, 16.8), Vector3(0, 2, -16.8)]:
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(point, point - Vector3.UP * 4, 1))
		assert(not hit.is_empty() and hit.collider.name == &"Ground")
	world.free()
	for singleton: String in ["GameAudio", "GameMusic", "GameAmbience"]:
		root.get_node(singleton).call("stop_all")
	await create_timer(0.25).timeout
	print("MINI_MAP_ROTATION_TEST_PASS 96_orientations north bounds")
	quit()
