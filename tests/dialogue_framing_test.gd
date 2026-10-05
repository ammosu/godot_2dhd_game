extends SceneTree
## Speaker framing and character separation after the dialogue camera blend.
var failures: int = 0

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _run() -> void:
	var state: Node = root.get_node("GameState")
	state.reset_new_game(false)
	state.flags.intro_seen = true
	var world: Node3D = load("res://scenes/main.tscn").instantiate()
	root.add_child(world)
	world.set("_test_mode", true)
	var rig: Node3D = world.get_node("CameraRig")
	var player: Node3D = world.get_node("Player")
	rig.set_process(false)
	rig._dialogue_occlusion._parts.clear()
	for group: StringName in [&"foreground_cutaways", &"gate_cutaways"]:
		for controller: Node in get_nodes_in_group(group):
			controller.remove_from_group(group)
	player.set_physics_process(false)
	var actor := Node3D.new()
	world.add_child(actor)
	var art := Sprite3D.new()
	actor.add_child(art)
	art.position.y = 0.8
	var camera: Camera3D = rig.camera
	state.mode = state.Mode.DIALOGUE
	for projection: int in [Camera3D.PROJECTION_PERSPECTIVE, Camera3D.PROJECTION_ORTHOGONAL]:
		rig._indoors = projection == Camera3D.PROJECTION_ORTHOGONAL
		camera.projection = projection
		for separation: float in [1.2, 3.0, 6.0, 12.0]:
			player.global_position = Vector3.ZERO
			actor.global_position = Vector3(0, 0, -separation)
			rig.begin_dialogue_shot(art)
			check(rig._dialogue_subjects_in_safe_area(), "dialogue starts with both subjects in safe area")
			for frame: int in range(180):
				rig._process(1.0 / 60.0)
			var viewport: Vector2 = camera.get_viewport().get_visible_rect().size
			for height: float in [0.0, 1.7]:
				var point: Vector2 = camera.unproject_position(actor.global_position + Vector3.UP * height) / viewport
				check(point.x >= 0.25 and point.x <= 0.75 and point.y > 0.05 and point.y < 0.70, "entire speaker stays above dialogue panel")
			var hero_point: Vector2 = camera.unproject_position(player.global_position + Vector3.UP * 0.8) / viewport
			check(hero_point.x >= 0.25 and hero_point.x <= 0.75, "hero also remains inside horizontal safe area")
			var hero_screen: Vector2 = camera.unproject_position(player.global_position + Vector3.UP * 0.8)
			var actor_screen: Vector2 = camera.unproject_position(actor.global_position + Vector3.UP * 0.8)
			check(absf(hero_screen.x - actor_screen.x) > 45.0, "traveler does not obscure dialogue subject")
	# If a companion remains directly in front of the speaker, only that
	# companion fades; moving clear or ending dialogue restores the art.
	var companion: Node3D = load("res://scripts/gameplay/party_follower.gd").new()
	companion.leader = player
	world.add_child(companion)
	companion.set_physics_process(false)
	companion.global_position = actor.global_position + camera.global_basis.z * 1.0
	companion._process(0.3)
	check(companion._sprite.transparency > 0.8, "foreground companion cannot hide speaker")
	companion.global_position += camera.global_basis.x * 3.0
	companion._process(0.3)
	check(is_zero_approx(companion._sprite.transparency), "unobstructing companion remains opaque")
	rig.begin_dialogue_shot(companion._sprite)
	companion._process(0.3)
	check(is_zero_approx(companion._sprite.transparency), "speaking companion never fades")
	# Isolate candidate selection high above map collisions.
	player.global_position = Vector3(0, 100, 0)
	actor.global_position = Vector3(0, 100, -3)
	rig._indoors = false
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	rig.begin_dialogue_shot(art)
	var base_yaw: float = rig._dialogue_yaw
	rig._preview_dialogue_camera()
	var obstruction := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.35, 1.8, 0.35)
	obstruction.mesh = box
	world.add_child(obstruction)
	obstruction.global_position = camera.global_position.lerp(actor.global_position + Vector3.UP * 1.4, 0.5)
	rig._dialogue_occlusion._parts.append(obstruction)
	check(not rig._dialogue_subjects_clear(), "Speaker obstruction rejects original angle")
	rig._choose_dialogue_angle()
	check(not is_equal_approx(rig._dialogue_yaw, base_yaw) and rig._dialogue_elevation == 0.4, "Nearby clear candidate is selected before fallback")
	rig._preview_dialogue_camera()
	check(rig._dialogue_subjects_clear(), "Chosen candidate clears both head/chest rays and panel")
	box.size = Vector3(100, 100, 100)
	obstruction.global_position = actor.global_position
	rig._choose_dialogue_angle()
	check(rig._dialogue_distance >= 12.0 and rig._dialogue_elevation == 0.7, "All blocked angles use distant elevated fixed shot")
	obstruction.free()
	state.mode = state.Mode.EXPLORE
	companion._process(0.3)
	check(is_zero_approx(companion._sprite.transparency), "dialogue end restores companion")
	world.queue_free()
	await process_frame
	if failures == 0:
		print("DIALOGUE_FRAMING_TEST_PASS speaker_feet_head perspective orthographic separation")
	quit(0 if failures == 0 else 1)
