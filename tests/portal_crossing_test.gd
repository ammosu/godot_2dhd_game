extends SceneTree
## Portals: the crypt veil brightens as the traveler nears, a crossing locks input,
## leans the lens in, flares the veil and ripples the screen shut before the map
## changes, then hands control back and opens on an arrival burst. The sealed moon
## gate refuses with a flare and a startled traveler; the open gate crosses too.
var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error("PORTAL_CROSSING_TEST_FAIL " + message)


func _vortex(exit_id: String) -> Node3D:
	for node: Node in get_nodes_in_group("portal_vortices"):
		if str(node.get_meta("exit_id")) == exit_id and not node.is_queued_for_deletion():
			return node as Node3D
	return null


func _run() -> void:
	var Acting: GDScript = load("res://scripts/gameplay/actor_acting.gd")
	var state := root.get_node("GameState")
	state.reset_new_game(false)
	state.flags.intro_seen = true
	var world: Node3D = load("res://scenes/main.tscn").instantiate()
	root.add_child(world)
	world.set("_test_mode", true)
	var player: CharacterBody3D = world.get_node("Player")
	var rig: Node3D = world.get_node("CameraRig")
	var fx: CanvasLayer = world.get("_portal_fx")
	check(fx != null and not fx.is_running(), "transition overlay idle at start")

	# The sealed north gate refuses before the elder's moon seal.
	world._handle_interaction("portal_to_ruins")
	check(state.current_map == "village" and world.dialogue_ui.is_open(), "sealed gate stays shut and explains")
	var hero_acting: Node = Acting.find(player.sprite)
	check(hero_acting != null and hero_acting.current_emote() == &"shock", "traveler starts back from the seal")
	check(not fx.is_running() and not world.get("_portal_transition_pending"), "refusal plays no crossing")
	while world.dialogue_ui.is_open():
		world.dialogue_ui.advance()

	# Crypt veil responds to distance.
	world.call("_load_map", "ashen_crypt_1", "entry")
	for frame: int in range(5):
		await physics_frame
	var field: Node = world.get("_map_root").get_node_or_null("FieldCombat")
	if field != null:
		for enemy: Dictionary in field.enemies:
			(enemy.body as Node3D).global_position += Vector3.DOWN * 50.0
	var vortex: Node3D = _vortex("crypt_descend")
	check(vortex != null, "crypt portal has a vortex")
	player.global_position = vortex.global_position + Vector3(0, 0.1, 9.0)
	await create_timer(1.0).timeout
	var far: float = float(vortex.proximity)
	player.global_position = vortex.global_position + Vector3(0, 0.1, 1.6)
	await create_timer(1.0).timeout
	var near: float = float(vortex.proximity)
	check(far < 0.05 and near > 0.6, "veil wakes as the traveler nears (%f -> %f)" % [far, near])

	# Crossing.
	world._handle_interaction("crypt_descend")
	check(state.mode == state.Mode.CUTSCENE and world.get("_portal_transition_pending"), "crossing locks input")
	check(rig.active_shot_id() == &"portal_cross", "lens leans into the portal")
	check(fx.is_running(), "screen ripple starts")
	world._handle_interaction("crypt_descend")
	var requested: Array[String] = []
	state.map_change_requested.connect(func(map_id: String, _spawn: String) -> void: requested.append(map_id))
	await create_timer(0.4).timeout
	check(state.current_map == "ashen_crypt_1", "map holds while the light closes in")
	check(float(vortex.surge_amount) > 0.1, "veil flares during the crossing")
	await world.map_presented
	# Let the crossing's own continuation (connected later) run its arrival beat.
	await process_frame
	check(requested == ["ashen_crypt_2"], "exactly one map change (%s)" % str(requested))
	check(state.current_map == "ashen_crypt_2", "crossing arrives")
	check(state.mode == state.Mode.EXPLORE, "control returns on arrival")
	check(not rig.has_shot(&"portal_cross"), "portal lens released on arrival")
	check(world.get("_map_root").get_node_or_null("PortalArrival") != null, "arrival burst plays")
	check(fx.is_running() and fx.amount().x == 1.0, "screen opens from full light")
	var waited: int = 0
	while fx.is_running() and waited < 600:
		await process_frame
		waited += 1
	check(not fx.is_running(), "ripple clears and hides after arrival")

	# The open moon gate crosses the same way.
	state.quest_state = state.QuestState.ACTIVE
	world.call("_load_map", "village", "from_ruins")
	for frame: int in range(5):
		await physics_frame
	world._handle_interaction("portal_to_ruins")
	check(fx.is_running() and state.mode == state.Mode.CUTSCENE, "open gate plays the crossing")
	await world.map_presented
	check(state.current_map == "ruins" and state.mode == state.Mode.EXPLORE, "open gate arrives at the ruins")

	world.queue_free()
	await process_frame
	if failures == 0:
		print("PORTAL_CROSSING_TEST_PASS seal proximity lock lens ripple flare single arrive burst reveal gate")
	quit(0 if failures == 0 else 1)
