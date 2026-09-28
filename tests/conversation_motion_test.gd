extends SceneTree
## Conversation body language and ambient walkers: stepped turns, the eased
## back-step and its cancellation, speaking nods, breathing, dialogue fade-out,
## villager ramps and hysteresis, cutscene ambience and the road traveler's look.
const Facing = preload("res://scripts/gameplay/eight_way_facing.gd")
const SealMotion = preload("res://scripts/gameplay/keeper_seal_motion.gd")
var failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error("CONVERSATION_MOTION_TEST_FAIL " + message)


func _sector(index: int) -> int:
	return Facing.SECTORS.find(index)


func _run() -> void:
	_check_facing_math()
	check(SealMotion.scheduled_pose(0.29) == 0 and SealMotion.scheduled_pose(0.31) == 1 and SealMotion.scheduled_pose(0.47) == 1 and SealMotion.scheduled_pose(0.49) == 2, "Seal pose schedule")
	var state := root.get_node("GameState")
	state.call("reset_new_game", false)
	state.get("flags")["intro_seen"] = true
	state.set("quest_state", 1)
	var world := (load("res://scenes/main.tscn") as PackedScene).instantiate() as Node3D
	root.add_child(world)
	world.set("_test_mode", true)
	await process_frame
	var player := world.get_node("Player") as CharacterBody3D
	player.set_physics_process(false)
	var dialogue := world.get_node("DialogueUI")
	var map_root := world.get("_map_root") as Node3D
	var rumi := map_root.get_node("Rumi") as Node3D
	var rumi_art := rumi.get_node("CharacterArt") as Sprite3D
	var rumi_life := rumi_art.get_node("BodyLife")
	var hero_life := (player.get("sprite") as Node).get_node("BodyLife")
	check(rumi_life != null and hero_life != null, "Body language components attached")

	# Breathing moves only scale.y; the feet stay anchored.
	var foot_y: float = rumi_art.position.y
	var scales: Array[float] = []
	for frame: int in range(40):
		await process_frame
		scales.append(rumi_art.scale.y)
	check(scales.max() - scales.min() > 0.0005 and scales.max() < 1.02 and scales.min() > 0.98, "Idle NPC breathes subtly")
	check(is_equal_approx(rumi_art.position.y, foot_y), "Breathing moved the feet")
	check(is_equal_approx((player.get("sprite") as SpriteBase3D).scale.y, 1.0), "Hero breathing is left to the player script")

	# The back-step can be interrupted: closing the box stops it on the next tick.
	player.global_position = rumi.global_position + Vector3(0.3, 0.03, 0.0)
	world.call("_handle_interaction", "rumi")
	check(dialogue.call("is_open") and world.call("is_conversation_step_active"), "Close talk starts an eased step")
	check(rumi_life.get("speaking") == true, "Partner nods while its first line types")
	await physics_frame
	await physics_frame
	var interrupted_at: Vector3 = player.global_position
	check(interrupted_at.x > rumi.global_position.x + 0.3, "Step moved the hero back")
	while dialogue.call("is_open"):
		dialogue.call("advance")
	check(not rumi_life.get("speaking"), "Nod stops when dialogue closes")
	check(not dialogue.call("is_open") and state.get("mode") == 0, "Closing stays synchronous")
	var root_control := dialogue.get_node("DialogueRoot") as Control
	check(root_control.visible, "Dialogue box fades out rather than popping")
	for frame: int in range(3):
		await physics_frame
	check(not world.call("is_conversation_step_active"), "Closed conversation stopped the step")
	check(not player.axis_lock_linear_x and not player.axis_lock_linear_z, "Step cancel released its axis locks")
	check(player.global_position.distance_to(interrupted_at) < 0.1, "Cancelled step kept walking")
	check(not player.get_collision_exceptions().has(rumi.get_node("ActorBody")), "Cancelled step restored NPC collision")
	await create_timer(0.2).timeout
	check(not root_control.visible and is_equal_approx(root_control.modulate.a, 1.0), "Faded dialogue box hides and resets")

	# A map change mid-step must not walk the hero back toward the old spot.
	player.global_position = rumi.global_position + Vector3(0.2, 0.03, 0.0)
	world.call("_handle_interaction", "rumi")
	check(world.call("is_conversation_step_active"), "Second step started")
	world.call("_load_map", "ruins", "from_village")
	var spawn: Vector3 = player.global_position
	for frame: int in range(4):
		await physics_frame
	check(not world.call("is_conversation_step_active") and player.global_position.distance_to(spawn) < 0.1, "Map change cancelled the step")
	while dialogue.call("is_open"):
		dialogue.call("advance")
	world.call("_load_map", "village", "default")
	await process_frame
	map_root = world.get("_map_root") as Node3D

	# Speaker nods map to the hero or the partner, never narrators.
	var elder := map_root.get_node("Elder") as Node3D
	var elder_life := elder.get_node("CharacterArt/BodyLife")
	player.global_position = elder.global_position + Vector3(0, 0.03, 1.6)
	dialogue.call("show_dialogue", [{"speaker": "長老・艾爾", "text": "測試"}, {"speaker": "旅人", "text": "好。"}, {"speaker": "旁白", "text": "風。"}])
	world.call("_begin_actor_conversation", elder)
	check(elder_life.get("speaking") == true and not hero_life.get("speaking"), "Elder nods on his line")
	dialogue.call("_complete_reveal")
	check(not elder_life.get("speaking"), "Nod ends when the line finishes typing")
	dialogue.call("advance")
	check(hero_life.get("speaking") == true and not elder_life.get("speaking"), "Hero nods on his line")
	var nod_scales: Array[float] = []
	for frame: int in range(20):
		await process_frame
		nod_scales.append((player.get("sprite") as SpriteBase3D).scale.y)
	check(nod_scales.min() < 0.999, "Hero sprite nods while speaking")
	dialogue.call("advance")
	check(not hero_life.get("speaking") and not elder_life.get("speaking"), "Narration moves nobody")
	dialogue.call("advance")
	await create_timer(0.5).timeout # The last nod finishes its cycle.
	check(is_equal_approx((player.get("sprite") as SpriteBase3D).scale.y, 1.0), "Hero sprite returns to rest after nodding")

	# Villagers ease in, yield with hysteresis, and keep strolling under cutscenes.
	var villager := get_nodes_in_group("wandering_villagers")[0] as CharacterBody3D
	player.global_position = Vector3(18, 0.1, 16)
	var route: PackedVector3Array = villager.get("route")
	villager.global_position = (route[0] + route[1]) * 0.5
	villager.set("_target", 1)
	villager.set("_direction", 1)
	villager.set("_heading", (route[1] - route[0]).normalized())
	state.call("set_mode", state.Mode.DIALOGUE) # Freeze: a stopped walker has no speed.
	await physics_frame
	await physics_frame # Signal fires before nodes tick; let one frozen tick run.
	state.call("set_mode", state.Mode.EXPLORE)
	villager.set("wait_time", 0.0)
	await physics_frame
	await physics_frame
	var early_speed: float = Vector2(villager.velocity.x, villager.velocity.z).length()
	check(early_speed > 0.0 and early_speed < float(villager.get("speed")) * 0.5, "Villager ramps up instead of jumping to full speed")
	for frame: int in range(40):
		await physics_frame
	check(absf(Vector2(villager.velocity.x, villager.velocity.z).length() - float(villager.get("speed"))) < 0.05 or float(villager.get("wait_time")) > 0.0, "Villager reaches stroll speed")
	var art := villager.get_node("CharacterArt")
	check(float(art.get("ground_speed")) > 0.3, "Walker reports ground speed for gait")
	check(float(art.call("_walk_fps")) >= 4.0 and float(art.call("_walk_fps")) <= 9.0, "Distance cadence stays legible")
	state.call("set_mode", state.Mode.CUTSCENE)
	var filmed: Vector3 = villager.global_position
	for frame: int in range(30):
		await physics_frame
	check(villager.global_position.distance_to(filmed) > 0.05 or float(villager.get("wait_time")) > 0.0, "Ambient villager keeps walking during cutscenes")
	state.call("set_mode", state.Mode.EXPLORE)
	# Hysteresis: stop inside 1.6 m, stay stopped until beyond 2.0 m.
	var flat := Vector3(1.0, 0.0, 0.0)
	player.global_position = villager.global_position + flat * 1.5
	await physics_frame
	await physics_frame
	check(villager.get("_yielding"), "Villager yields near the player")
	player.global_position = villager.global_position + flat * 1.8
	await physics_frame
	await physics_frame
	check(villager.get("_yielding"), "Yield must not flicker inside the hysteresis band")
	player.global_position = villager.global_position + flat * 2.3
	await physics_frame
	await physics_frame
	check(not villager.get("_yielding"), "Villager resumes once the player steps away")

	# The road traveler follows a nearby hero with a lagging look.
	player.global_position = Vector3(18, 0.1, 16)
	world.call("_load_map", "east_road", "from_village")
	await process_frame
	var traveler := world.get("_map_root").get_node("Road Traveler") as Node3D
	var traveler_art := traveler.get_node("CharacterArt")
	check(traveler_art.get("watch_target") == player, "Road traveler watches the hero")
	var camera := world.get_node("CameraRig/Camera3D") as Camera3D
	player.global_position = traveler.global_position + Vector3(3.0, 0.1, 0.0)
	var wanted := Facing.ANIMATIONS[Facing.direction_index(Facing.screen_direction(Vector3.RIGHT, camera))]
	await process_frame
	check(traveler_art.get("animation") != wanted, "Traveler's look lags behind the hero")
	await create_timer(1.5).timeout
	check(traveler_art.get("animation") == wanted, "Traveler turns to watch the passing hero")
	player.global_position = traveler.global_position + Vector3(9.0, 0.1, 0.0)
	await create_timer(1.5).timeout
	var home := Facing.ANIMATIONS[Facing.direction_index(Facing.screen_direction(Vector3.BACK, camera))]
	check(traveler_art.get("animation") == home, "Traveler looks back down the road once the hero has gone")

	world.queue_free()
	await process_frame
	for singleton: String in ["GameAudio", "GameMusic", "GameAmbience"]:
		root.get_node(singleton).call("stop_all")
	await create_timer(0.25).timeout
	if failures == 0:
		print("CONVERSATION_MOTION_TEST_PASS stepped_turns back_step cancel nods breathing fade villagers cutscene traveler seal")
	quit(0 if failures == 0 else 1)


func _check_facing_math() -> void:
	for current: int in range(8):
		for target: int in range(8):
			var index: int = current
			for step: int in range(4):
				var next: int = Facing.step_toward(index, target)
				var gap: int = absi(posmod(_sector(next) - _sector(index) + 4, 8) - 4)
				check(gap <= 1, "step_toward skipped a view")
				index = next
			check(index == target, "step_toward did not arrive within four steps")
	# Half turns from the side pass through the front (down) view.
	var left: int = Facing.ANIMATIONS.find(&"left")
	var right: int = Facing.ANIMATIONS.find(&"right")
	var first: int = Facing.step_toward(left, right)
	check(Facing.ANIMATIONS[first] == &"down_left", "Half turn should pass through the front")
	# Dead band keeps a sector slightly past its edge, then lets go.
	var down: int = Facing.ANIMATIONS.find(&"down")
	var edge := Vector2.from_angle(PI / 2.0 + PI / 8.0 + deg_to_rad(4.0))
	check(Facing.direction_index_stable(edge, down, deg_to_rad(7.0)) == down, "Dead band holds the previous view")
	var beyond := Vector2.from_angle(PI / 2.0 + PI / 8.0 + deg_to_rad(10.0))
	check(Facing.direction_index_stable(beyond, down, deg_to_rad(7.0)) != down, "Dead band releases past its width")
	var world := Facing.world_direction(Facing.sector_vector(right), null)
	check(world.is_equal_approx(Vector3.RIGHT), "Sector vector round-trips to world")
