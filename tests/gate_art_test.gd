extends SceneTree

const Interactable = preload("res://scripts/gameplay/interactable_3d.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var state := root.get_node("GameState")
	state.get("flags")["intro_seen"] = true
	var world := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(world)
	var portal := world.get("_village_gate_portal") as Area3D
	assert(portal.get_node("MoonSeal").position.z > 0.0)
	assert(portal.get_node("MoonSealCore").position.z > 0.0)
	var shape := portal.get_child(0) as CollisionShape3D
	assert((shape.shape as BoxShape3D).size == Vector3(2.2, 1.6, 0.6))
	assert(shape.position.z < -0.5)
	assert(portal.has_node("WingWallWest") and portal.has_node("WingWallEast"))
	assert(portal.monitoring and portal.collision_layer == 8 and portal.collision_mask == 1)
	for label: String in ["LeftDoorHinge", "RightDoorHinge"]:
		var hinge := portal.get_node(label) as Node3D
		assert(hinge.has_node("Joinery"))
		var leaf := hinge.get_child(0) as MeshInstance3D
		var material := leaf.material_override as StandardMaterial3D
		assert(material.albedo_texture.resource_path.ends_with("timber_albedo.png"))
		assert(is_zero_approx(hinge.rotation.y))
	var wall_count: int = 0
	for child: Node in (world.get("_map_root") as Node).get_children():
		if child is StaticBody3D and child.get_child_count() == 2 and child.get_child(0) is MeshInstance3D and (child.get_child(0) as MeshInstance3D).material_override is ShaderMaterial:
			var candidate := (child.get_child(0) as MeshInstance3D).material_override as ShaderMaterial
			if not candidate.shader.resource_path.ends_with("coursed_stone.gdshader"):
				continue
			wall_count += 1
			var visual := child.get_child(0) as MeshInstance3D
			assert((visual.material_override as ShaderMaterial).shader.resource_path.ends_with("coursed_stone.gdshader"))
			assert((visual.mesh as BoxMesh).size == ((child.get_child(1) as CollisionShape3D).shape as BoxShape3D).size)
	assert(wall_count == 6)
	# The locked gate and adjoining wall both block passage before the quest.
	var traveler := world.get_node("Player") as CharacterBody3D
	traveler.position = Vector3(0, 0.1, -18.05)
	assert(traveler.move_and_collide(Vector3(0, 0, -2.0)) != null)
	assert(traveler.position.z > -19.3)
	traveler.position = Vector3(5, 0.1, -18.05)
	assert(traveler.move_and_collide(Vector3(0, 0, -2.0)) != null)
	traveler.position = Vector3(0, 0.1, -17.0)
	await _capture(world, "closed")
	state.set("quest_state", 1)
	world.call("_update_village_gate_state")
	await create_timer(0.85).timeout
	assert(is_equal_approx((portal.get_node("LeftDoorHinge") as Node3D).rotation.y, -1.22))
	assert(is_equal_approx((portal.get_node("MoonSeal") as MeshInstance3D).transparency, 1.0))
	await _capture(world, "open")
	assert(not (portal.get_node("MoonSeal") as MeshInstance3D).visible)
	world.call("_load_map", "ruins", "from_village")
	var player := world.get_node("Player") as CharacterBody3D
	assert(is_zero_approx(player.position.x))
	assert(is_equal_approx(player.position.z, 13.85))
	await create_timer(0.3).timeout
	assert(state.get("current_map") == "ruins")
	var found: bool = false
	for child: Node in (world.get("_map_root") as Node).get_children():
		if child is Interactable and child.interaction_id == "portal_to_village":
			assert(child.get_node("MoonSeal").position.z < 0.0)
			found = true
	assert(found)
	await _capture(world, "arrival")
	world.call("_load_map", "village", "from_ruins")
	assert(is_zero_approx(player.position.x))
	assert(is_equal_approx(player.position.z, -18.05))
	await create_timer(0.3).timeout
	assert(state.get("current_map") == "village")
	# Exercise real threshold overlap in both directions, rather than emitting signals.
	player.set_physics_process(false)
	for destination: String in ["ruins", "village"]:
		var step := Vector3(0.0, 0.0, -0.06 if destination == "ruins" else 0.06)
		for frame: int in range(70):
			player.move_and_collide(step)
			await physics_frame
			await process_frame
			if state.get("current_map") == destination:
				break
		assert(state.get("current_map") == destination)
		await create_timer(0.25).timeout
		assert(state.get("current_map") == destination)
	# The separate eastern opening is walkable; its visible road-end fence is solid.
	player.position = Vector3(20.0, 0.1, 4.6)
	for frame: int in range(100):
		player.move_and_collide(Vector3(0.09, 0, 0))
		await physics_frame
	assert(player.position.x > 25.5 and player.position.x < 27.0)
	assert(state.get("current_map") == "village")
	await _capture(world, "east_road")
	world.free()
	for singleton: String in ["GameAudio", "GameMusic", "GameAmbience"]:
		root.get_node(singleton).call("stop_all")
	await create_timer(0.25).timeout
	print("GATE_ART_TEST_PASS masonry timber two_sided approach seal_open collision_preserved")
	quit()


func _capture(world: Node, label: String) -> void:
	if not "--gate-capture" in OS.get_cmdline_user_args() or DisplayServer.get_name() == "headless":
		return
	var player := world.get_node("Player") as CharacterBody3D
	if label in ["closed", "open"]:
		player.position = Vector3(0.0, 0.1, -17.0)
	world.get_node("CameraRig").call("snap_to_target")
	await create_timer(0.35).timeout
	await RenderingServer.frame_post_draw
	var path := "/tmp/wanderlight-gate-%s-%s.png" % [RenderingServer.get_current_rendering_method(), label]
	assert(root.get_texture().get_image().save_png(path) == OK)
	print("GATE_CAPTURE ", path)
