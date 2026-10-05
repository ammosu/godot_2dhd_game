extends SceneTree
## Companion commands in field fights: refusals outside combat, Noah's taunt
## pulls a wolf onto him and its blow staggers him (no harm to anyone) and breaks
## the taunt, Sia's bell rings at once and heals even a lightly hurt traveler,
## cooldowns, the slowed-time command wheel, the HUD and the hotkeys.
var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error("COMPANION_COMMAND_TEST_FAIL " + message)


func _press(field: Node3D, action: StringName, pressed: bool = true) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = pressed
	field._unhandled_input(event)


func _run() -> void:
	var Allies: GDScript = load("res://scripts/gameplay/field_allies.gd")
	var Awareness: GDScript = load("res://scripts/gameplay/enemy_awareness.gd")
	var Acting: GDScript = load("res://scripts/gameplay/actor_acting.gd")
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
	field.automation.set_enabled(false, field)
	var base_scale: float = Engine.time_scale
	var noah: Node3D = Allies.find_follower(field, "noah")
	var sia: Node3D = Allies.find_follower(field, "sia")
	check(noah != null and sia != null, "both companions present")
	var notices: Array[String] = []
	state.notification_requested.connect(func(message: String) -> void: notices.append(message))

	# Outside a fight there is nothing to order.
	var wolf: Dictionary = field.enemies[0]
	for enemy: Dictionary in field.enemies:
		if enemy != wolf:
			enemy.hp = 0
			enemy.state = "dead"
	check(not field.command_ally("noah"), "no command without an engaged enemy")
	check(notices.has("沒有交戰中的敵人"), "refusal explains itself")
	check(not field.open_command_wheel(), "wheel stays shut outside a fight")
	check(field._command_row.visible, "companion orders shown while they travel")
	check(field._command_buttons["noah"].disabled, "orders disabled without a fight")

	# Engage one wolf; keep the traveler far from Noah so only Noah is in reach.
	player.global_position = Vector3(-4, 0.1, 7.5)
	(wolf.body as Node3D).global_position = Vector3(-4, 0.1, 10.0)
	for follower: Node in get_nodes_in_group("party_followers"):
		follower.call("snap_behind_leader")
	Awareness.engage(field, wolf)
	await physics_frame
	await physics_frame
	check(field.is_engaged(), "fight engaged")
	check(not field._command_buttons["noah"].disabled, "orders enabled in a fight")
	check(notices.any(func(message: String) -> bool: return message.contains("諾亞挑釁")), "orders introduced on first fight")

	# The wheel slows time and closes on an order.
	_press(field, &"command_wheel")
	check(field.is_command_wheel_open(), "Tab opens the wheel")
	check(is_equal_approx(Engine.time_scale, base_scale * 0.25), "wheel slows time to a quarter")
	_press(field, &"command_noah")
	check(not field.is_command_wheel_open() and is_equal_approx(Engine.time_scale, base_scale), "ordering closes the wheel and restores time")
	_press(field, &"command_wheel", false)
	check(is_equal_approx(Engine.time_scale, base_scale), "releasing Tab after an order is harmless")

	# Noah's taunt.
	check(float(wolf.get("taunt", 0.0)) > 0.0 and wolf.get("taunt_by") == noah, "taunt marks the wolf")
	check(is_equal_approx(field.allies.command_cooldown("noah"), Allies.TAUNT_COOLDOWN), "taunt goes on cooldown")
	check(field.director.engaged and field._rig.has_shot(field.director.COMMAND_SHOT), "order glances toward Noah")
	var noah_acting: Node = Acting.find(noah.get_node("CharacterArt"))
	check(noah_acting != null and noah_acting.current_emote() == &"exclaim", "Noah answers the order")
	check(not field.command_ally("noah"), "taunt cannot repeat during cooldown")
	# Hold Noah still well away from the traveler; the wolf must come to him.
	noah.set_physics_process(false)
	noah.global_position = player.global_position + Vector3(4.5, 0, 2.0)
	var hp_before: int = state.player_hp
	var staggered: bool = false
	var closest_to_noah: float = INF
	for frame: int in range(60 * 6):
		await physics_frame
		closest_to_noah = minf(closest_to_noah, (wolf.body as Node3D).global_position.distance_to(noah.global_position))
		if field.allies.is_staggered("noah"):
			staggered = true
			break
		# Keep the taunt alive however long the approach takes.
		wolf.taunt = maxf(float(wolf.taunt), 0.5)
	check(closest_to_noah < 2.2, "taunted wolf closes on Noah (%f)" % closest_to_noah)
	check(staggered, "the wolf's blow staggers Noah")
	check(state.player_hp == hp_before, "the traveler is untouched while Noah holds attention")
	check(is_zero_approx(float(wolf.taunt)), "stagger breaks the taunt")
	check(int(noah.get("action_pose")) == 3, "Noah braces while staggered")
	check(noah_acting.current_emote() == &"shock", "stagger reads as a shock")
	check(field.allies.command_block(field, "noah") == "諾亞還沒站穩" or field.allies.command_cooldown("noah") > 0.0, "no orders mid-stagger")
	for frame: int in range(roundi(60 * (Allies.STAGGER_TIME + 0.2))):
		await physics_frame
	check(not field.allies.is_staggered("noah"), "Noah recovers from the stagger")
	noah.set_physics_process(true)

	# Sia's bell: immediate, and it heals even above the automatic threshold.
	state.player_hp = roundi(state.player_max_hp * 0.85)
	var lightly_hurt: int = state.player_hp
	sia.global_position = (wolf.body as Node3D).global_position + Vector3(2.0, 0, 0)
	_press(field, &"command_sia")
	check(is_equal_approx(field.allies.command_cooldown("sia"), Allies.BELL_COMMAND_COOLDOWN), "bell goes on cooldown")
	var rang: bool = false
	for frame: int in range(30):
		await physics_frame
		for effect: Node3D in field._effects:
			rang = rang or effect.kind == "bell_wave"
	check(rang, "bell rings within half a second")
	check(state.player_hp > lightly_hurt, "commanded bell heals a lightly hurt traveler")

	# Leaving the map with the wheel open never strands slow time.
	field.allies._state["noah"].command_cooldown = 0.0
	check(field.open_command_wheel(), "wheel reopens in the fight")
	world.queue_free()
	await process_frame
	await process_frame
	check(is_equal_approx(Engine.time_scale, base_scale) and Engine.physics_ticks_per_second == 60, "map exit closes the wheel's slow time")
	if failures == 0:
		print("COMPANION_COMMAND_TEST_PASS refuse wheel taunt stagger unharmed bell cooldown exit")
	quit(0 if failures == 0 else 1)
