extends SceneTree
var failures: int = 0
var cues: Array[StringName] = []

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _wait_round(battle: Node) -> void:
	var deadline := Time.get_ticks_msec() + 15000
	while not battle.call("can_accept_action") and not battle.call("is_resolved") and Time.get_ticks_msec() < deadline:
		await process_frame
	_check(battle.call("can_accept_action") or battle.call("is_resolved"), "Round timed out")

func _run() -> void:
	var state: Node = root.get_node("GameState")
	state.call("reset_new_game", false)
	root.get_node("GameAudio").connect("cue_played", func(cue: StringName) -> void: cues.append(cue))
	var battle: Node = load("res://scripts/ui/party_battle_ui.gd").new()
	root.add_child(battle)
	battle.call("start_battle", {})
	await process_frame
	var model: RefCounted = state.get("battle_session")
	_check((battle.get("_round_button") as Button).disabled, "Start enabled before planning")
	battle.call("_select_action", "slash")
	battle.call("choose_action", "slash")
	_check(model.current == 1 and model.actors[0].mp == 20 and model.actors[3].hp == 64 and cues.is_empty(), "Planning executed attack")
	battle.call("_select_action", "protect")
	battle.call("_select_target", 0)
	battle.call("choose_action", "protect")
	battle.call("_select_action", "magic")
	battle.call("_select_target", 4)
	_check((battle.get("_ring") as Line2D).visible, "Magic preview missing")
	battle.call("choose_action", "magic")
	_check(model.ready_to_resolve() and not (battle.get("_round_button") as Button).disabled, "Full plans cannot start")
	battle.call("_select_planner", 0)
	battle.call("_select_action", "attack")
	battle.call("choose_action", "attack")
	_check(model.plans[0].action == "attack" and model.plans.size() == 3, "Editing duplicated plan")
	var drag_data := {"battle": battle.get_instance_id(), "actor": 0}
	_check(not battle.call("_can_drop_actor", Vector2.ZERO, drag_data, 3), "Enemy accepted drop")
	_check(not battle.call("_can_drop_actor", Vector2.ZERO, {}, 1), "Foreign drag accepted")
	_check(battle.call("_can_drop_actor", Vector2.ZERO, drag_data, 2), "Ally rejected drag")
	battle.call("_drop_actor", Vector2.ZERO, drag_data, 2)
	_check(model.actors[0].row == 2 and model.actors[2].row == 0, "Drag did not swap")
	_check(not battle.call("_can_drop_actor", Vector2.ZERO, drag_data, 1), "Second swap accepted")
	for index: int in range(6):
		var bar: ProgressBar = battle.get("_speed_bars")[index]
		_check(bar.value == float(model.actors[index].speed), "Speed bar differs from model")
	if "--party-art-capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/party-round-planning.png")
	battle.call("_run_round")
	_check(not battle.call("can_accept_action") and model.current == 4, "Fastest actor did not start")
	battle.call("choose_action", "attack")
	battle.call("_run_round")
	battle.call("_drop_actor", Vector2.ZERO, drag_data, 1)
	_check(model.actors[0].row == 2, "Execution accepted drag")
	await _wait_round(battle)
	_check(model.round_number == 2 and model.current == 0 and not model.formation_changed and model.plans.is_empty(), "Next round not ready")
	_check(cues.count(&"frost_nova") == 2 and cues.count(&"protect") == 1, "Queued spells executed more than once")
	_check(model.actors[2].mp == 24 and model.actors[1].mp == 12, "MP spent at wrong time")
	_check(model.actors[3].hp == 29 and model.actors[4].hp == 21 and model.actors[5].hp == 25, "Queued damage differs from preview")
	_check(model.actors[2].hp < 65, "Enemy did not hit swapped front")
	for round_index: int in range(10):
		if battle.call("is_resolved"):
			break
		for index: int in model.living(0):
			battle.call("_select_planner", index)
			battle.call("_select_action", "attack")
			battle.call("choose_action", "attack")
		battle.call("_run_round")
		await _wait_round(battle)
	_check(battle.call("did_player_win"), "Planned battle did not reach victory")
	await process_frame
	_check(root.get_visible_rect().encloses((battle.get("_continue") as Button).get_global_rect()), "Continue clipped")
	battle.call("_finish_battle")
	_check(state.get("battle_session") == null and not battle.call("is_active"), "Encounter not released")
	battle.free()
	for singleton: String in ["GameAudio", "GameMusic", "GameAmbience"]:
		root.get_node(singleton).call("stop_all")
	await create_timer(0.25).timeout
	if failures == 0:
		print("PARTY_BATTLE_UI_TEST_PASS planning editing drag speed input_lock mana rounds victory")
	quit(0 if failures == 0 else 1)
