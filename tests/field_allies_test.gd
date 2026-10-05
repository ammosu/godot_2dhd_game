extends SceneTree
## Companions in field fights: Noah steps in and thrusts, wards a badly hurt
## traveler, Sia's bell slows nearby enemies and heals; ally blows never freeze
## the traveler; poses return to walking once the fight is over.
var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error("FIELD_ALLIES_TEST_FAIL " + message)


func _run() -> void:
	var state := root.get_node("GameState")
	state.reset_new_game(false)
	state.flags.intro_seen = true
	state.quest_state = state.QuestState.COMPLETE
	state.chapter_stage = state.Chapter.SIA_JOINED
	var world: Node3D = load("res://scenes/main.tscn").instantiate()
	root.add_child(world)
	world.set("_test_mode", true)
	world.call("_load_map", "east_road", "from_village")
	var player: CharacterBody3D = world.get_node("Player")
	player.set_physics_process(false)
	var field: Node3D = world.get("_map_root").get_node("FieldCombat")
	while not field.ready_for_combat:
		await physics_frame
	var heard: Array[StringName] = []
	root.get_node("GameAudio").cue_played.connect(func(cue: StringName) -> void: heard.append(cue))

	# With every spawn alive, only the closest name is shown; bars stay visible.
	field.set_physics_process(false)
	player.global_position = field.enemies[2].body.global_position + Vector3(0, 0, 0.2)
	field._update_readability()
	var named: int = 0
	for enemy: Dictionary in field.enemies:
		named += int(enemy.label.visible)
		check(enemy.bar.visible, "non-target health bars stay visible")
	check(named == 1 and field.enemies[2].label.visible, "nearest of multiple living enemies named")
	field.set_physics_process(true)
	# Bring one wolf to the traveler and hold everyone else back.
	var wolf: Dictionary = field.enemies[0]
	for enemy: Dictionary in field.enemies:
		if enemy != wolf:
			enemy.hp = 0
			enemy.state = "dead"
	player.global_position = Vector3(-4, 0.1, 7.5)
	(wolf.body as Node3D).global_position = Vector3(-4, 0.1, 9.0)
	for follower: Node in get_nodes_in_group("party_followers"):
		follower.call("snap_behind_leader")
	var Awareness: GDScript = load("res://scripts/gameplay/enemy_awareness.gd")
	Awareness.engage(field, wolf)
	field._update_readability()
	var sign: Label3D = get_first_node_in_group("field_location_labels")
	check(not sign.visible, "engaged hides location text")
	var visible_names: int = 0
	for enemy: Dictionary in field.enemies:
		visible_names += int(enemy.label.visible)
	check(visible_names == 1 and wolf.label.visible, "only nearest living name visible")
	var notices: Array[String] = []
	state.notification_requested.connect(func(message: String) -> void: notices.append(message))
	var start_hp: int = int(wolf.hp)
	var noah: Node3D
	var sia: Node3D
	for follower: Node in get_nodes_in_group("party_followers"):
		if str(follower.get("resident_id")) == "noah":
			noah = follower
		else:
			sia = follower
	check(noah != null and sia != null, "both companions present")
	# Hold the scene so the same low-priority target remains in range.
	field.set_physics_process(false)
	noah.set_physics_process(false)
	sia.set_physics_process(false)
	noah.global_position = player.global_position + Vector3(0.5, 0, 0)
	for frame: int in range(3):
		await physics_frame
	var hud: Node = world.get_node("HUD")
	check(player.get_nearest_interactable() != null and player.get_nearest_interactable().low_priority, "companion is the prompt target")
	hud.set_prompt(player.get_interaction_prompt())
	check(not hud._prompt_pill.visible, "engaged suppresses companion prompt")
	wolf.state = "return"
	field._update_readability()
	hud.set_prompt(player.get_interaction_prompt())
	check(sign.visible and not hud._prompt_pill.visible, "near returning enemy still suppresses companion prompt")
	wolf.state = "patrol"
	hud.set_prompt(player.get_interaction_prompt())
	check(not hud._prompt_pill.visible, "near patrol enemy suppresses companion prompt")
	var near_position: Vector3 = wolf.body.global_position
	wolf.body.global_position = player.global_position + Vector3(8, 0, 0)
	hud.set_prompt(player.get_interaction_prompt())
	check(hud._prompt_pill.visible, "distant patrol restores companion prompt")
	wolf.body.global_position = near_position
	wolf.state = "chase"
	field.set_physics_process(true)
	noah.set_physics_process(true)
	sia.set_physics_process(true)
	# Tutorials deferred by dialogue must be discarded at disengagement.
	hud.set_dialogue_open(true)
	hud.show_notice("希雅・測試：交戰提示")
	check(hud._notice_queue.any(func(entry: Dictionary) -> bool: return entry.kind == "tutorial"), "engaged tutorial queues")
	wolf.state = "return"
	hud._process(0.0)
	check(not hud._notice_queue.any(func(entry: Dictionary) -> bool: return entry.kind == "tutorial"), "disengagement expires queued tutorial")
	field.allies._introduce(field, "outside", "希雅・測試：不應出現")
	check(not field.allies._introduced.has("outside"), "skills cannot introduce outside combat")
	wolf.state = "chase"
	hud.set_dialogue_open(false)
	var bell_seen: bool = false
	var spear_seen: bool = false
	var separated: bool = false
	var noah_posed: bool = false
	var sia_posed: bool = false
	var hero_frozen: bool = false
	state.player_hp = roundi(state.player_max_hp * 0.4)
	for frame: int in range(60 * 9):
		await physics_frame
		# Keep the traveler idle and alive: only companions act.
		state.player_hp = maxi(int(state.player_hp), roundi(state.player_max_hp * 0.3))
		for effect: Node3D in field._effects:
			if effect.kind == "bell_wave":
				bell_seen = true
				check(effect._wave != null and effect._sparks.is_empty() and effect._halo == null, "bell uses a single procedural ring")
		for number: Dictionary in field._numbers:
			if number.node.text.begins_with("槍 "):
				spear_seen = true
				check(Color(number.node.modulate, 1.0).is_equal_approx(Color("9fd4ff")), "Noah spear damage is consistently blue")
		var camera: Camera3D = root.get_camera_3d()
		var hero_screen: Vector2 = camera.unproject_position(player.global_position)
		var noah_screen: Vector2 = camera.unproject_position(noah.global_position)
		var sia_screen: Vector2 = camera.unproject_position(sia.global_position)
		var minimum: float = absf(camera.unproject_position(player.global_position + camera.global_basis.x * 1.2).x - hero_screen.x)
		separated = separated or (absf(noah_screen.x - hero_screen.x) >= minimum and absf(sia_screen.x - hero_screen.x) >= minimum and absf(sia_screen.x - noah_screen.x) >= minimum)
		noah_posed = noah_posed or int(noah.get("action_pose")) == 2
		sia_posed = sia_posed or int(sia.get("action_pose")) == 2
		hero_frozen = hero_frozen or float(field.hit_stop) > 0.0
		if int(wolf.hp) <= 0:
			break
	check(bell_seen and spear_seen, "bell wave and marked spear damage both appear in combat")
	check(separated, "moving followers settle at separate screen positions")
	check(field.allies._introduced.has("guard") and field.allies._introduced.has("slow") and field.allies._introduced.has("heal"), "all three skills introduced")
	var count: int = notices.size()
	field.allies._introduce(field, "guard", "duplicate")
	field.allies._introduce(field, "slow", "duplicate")
	field.allies._introduce(field, "heal", "duplicate")
	check(notices.size() == count, "skill introductions only once per map")
	field._number(player.global_position, "1", Color.WHITE, &"hero")
	field._number(player.global_position, "2", Color.WHITE, &"noah")
	field._number(player.global_position, "3", Color.WHITE, &"sia")
	var n: int = field._numbers.size()
	var center: Vector3 = field._numbers[n - 3].node.position
	var left: Vector3 = field._numbers[n - 2].node.position
	var right: Vector3 = field._numbers[n - 1].node.position
	var axis: Vector3 = root.get_camera_3d().global_basis.x
	check((left - center).dot(axis) < -0.5 and (right - center).dot(axis) > 0.5, "screen-relative source lanes")
	check(not is_equal_approx(left.y, right.y), "successive numbers stagger vertically")
	check(int(wolf.hp) < start_hp, "Noah damaged the wolf")
	check(noah_posed and sia_posed, "both companions used battle poses")
	check(not hero_frozen, "ally blows never freeze the traveler")
	check(&"spear_thrust" in heard and &"hand_bell" in heard and &"protect" in heard, "thrust, bell and ward cues")
	check(field.allies.incoming_damage(10) == 10 or field.allies.ward_time > 0.0, "ward state consistent")
	field.allies.ward_time = 1.0
	check(field.allies.incoming_damage(10) == 6, "ward reduces incoming damage")
	field.allies.ward_time = 0.0
	check(field.allies.incoming_damage(10) == 10, "no ward, full damage")

	# Rotate a real orthographic camera through a full orbit and let followers
	# settle using their actual movement code, including while posing.
	field.set_physics_process(false)
	noah.set_physics_process(false)
	sia.set_physics_process(false)
	var camera: Camera3D = root.get_camera_3d()
	var saved_transform: Transform3D = camera.global_transform
	wolf.hp = 100
	wolf.state = "chase"
	wolf.body.global_position = player.global_position + Vector3(0, 0, 0.8)
	for angle: int in range(0, 360, 45):
		camera.global_position = player.global_position + Vector3(0, 10, 12).rotated(Vector3.UP, deg_to_rad(float(angle)))
		camera.look_at(player.global_position)
		for frame: int in range(150):
			field.allies.step(field, 0.0)
			noah._physics_process(1.0 / 60.0)
			sia._physics_process(1.0 / 60.0)
		var hero_screen: Vector2 = camera.unproject_position(player.global_position)
		var noah_screen: Vector2 = camera.unproject_position(noah.global_position)
		var sia_screen: Vector2 = camera.unproject_position(sia.global_position)
		var minimum: float = absf(camera.unproject_position(player.global_position + camera.global_basis.x * 1.2).x - hero_screen.x)
		check(absf(noah_screen.x - hero_screen.x) >= minimum, "Noah screen separation at orbit %d" % angle)
		check(absf(sia_screen.x - hero_screen.x) >= minimum and absf(sia_screen.x - noah_screen.x) >= minimum, "Sia screen separation at orbit %d" % angle)
	camera.global_transform = saved_transform
	field.set_physics_process(true)
	noah.set_physics_process(true)
	sia.set_physics_process(true)

	# Bell hit radius is centered on Sia, with planar distance matching the ring.
	field.set_physics_process(false)
	sia.set_physics_process(false)
	var saved_sia: Vector3 = sia.global_position
	sia.global_position = player.global_position + Vector3(8, 0, 0)
	wolf.hp = 100
	wolf.slow = 0.0
	wolf.body.global_position = sia.global_position + Vector3(5.4, 1, 0)
	state.player_hp = 20
	field.allies._ring(field, sia, player)
	check(float(wolf.slow) > 0.0, "bell slows within 5.5m of Sia even far from hero")
	check(state.player_hp > 20, "bell still heals traveler")
	wolf.slow = 0.0
	wolf.body.global_position = player.global_position
	field.allies._ring(field, sia, player)
	check(is_zero_approx(float(wolf.slow)), "enemy near hero outside Sia radius is not slowed")
	wolf.body.global_position = sia.global_position + Vector3(5.6, 0, 0)
	field.allies._ring(field, sia, player)
	check(is_zero_approx(float(wolf.slow)), "bell excludes outside 5.5m")
	sia.global_position = saved_sia
	sia.set_physics_process(true)
	field.set_physics_process(true)

	# Status marks track duration, movement, refreshed slow and dead targets.
	field.set_physics_process(false)
	wolf.slow = 1.0
	wolf.hp = 100
	field.allies.ward_time = 1.0
	field._update_status_markers()
	check(wolf.slow_marker.visible and field._ward_marker.visible, "slow and ward show persistent rings")
	check(wolf.slow_marker.material_override.albedo_color.is_equal_approx(Color("ffe0a0")), "slow mark is gold")
	check(field._ward_marker.material_override.albedo_color.b > 0.9 and field._ward_marker.material_override.albedo_color.a < 0.7, "ward mark is pale blue")
	wolf.body.global_position += Vector3.RIGHT
	player.global_position += Vector3.RIGHT
	field._update_status_markers()
	check(wolf.slow_marker.global_position.distance_to(wolf.body.global_position) < 0.04, "slow ring follows moving enemy")
	check(field._ward_marker.global_position.distance_to(player.global_position) < 0.04, "ward ring follows traveler")
	wolf.slow = 0.0
	field.allies.ward_time = 0.0
	field._update_status_markers()
	check(not wolf.slow_marker.visible and not field._ward_marker.visible, "both rings disappear as timers end")
	wolf.slow = 2.5
	field._update_status_markers()
	check(wolf.slow_marker.visible, "renewed slow restores ring")
	wolf.hp = 0
	field._update_status_markers()
	check(not wolf.slow_marker.visible, "dead enemy loses slow ring")
	var other: Dictionary = field.enemies[1]
	wolf.hp = 100
	other.hp = 100
	wolf.ally_focus = true
	wolf.body.global_position = noah.global_position + Vector3.RIGHT * 4.0
	other.body.global_position = noah.global_position + Vector3.RIGHT
	var candidates: Array[Dictionary] = [other, wolf]
	check(field.allies._noah_target(candidates, noah.global_position) == wolf, "rescue priority beats nearer living enemy")
	wolf.hp = 0
	check(field.allies._noah_target(candidates, noah.global_position) == other, "dead rescue target falls back to nearest living enemy")
	wolf.hp = 100
	wolf.erase("ally_focus")
	check(field.allies._noah_target(candidates, noah.global_position) == other, "no rescue flag uses nearest enemy")
	other.hp = 0
	field.set_physics_process(true)

	# Once nothing is engaged the companions walk again.
	wolf.hp = 0
	wolf.state = "dead"
	for frame: int in range(90):
		await physics_frame
	check(sign.visible, "disengaged restores location text")
	check(int(noah.get("action_pose")) == -1 and int(sia.get("action_pose")) == -1, "poses clear after the fight")
	check(not Vector3(noah.get("combat_goal")).is_finite(), "Noah back on the trail")

	world.queue_free()
	await process_frame
	if failures == 0:
		print("FIELD_ALLIES_TEST_PASS noah_thrust ward sia_bell poses no_hitstop disengage")
	quit(0 if failures == 0 else 1)
