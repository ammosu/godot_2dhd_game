extends SceneTree
const Model = preload("res://scripts/systems/party_battle.gd")
const Auto = preload("res://scripts/systems/party_auto_battle.gd")
var failures: int = 0
func _initialize() -> void:
	call_deferred("_run")
func _check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func _run() -> void:
	var model := Model.new()
	model.setup(100, 20, 18, 4, {})
	_check(Auto.plan_round(model, 2).is_empty() and model.ready_to_resolve(), "Auto did not plan everyone")
	_check(model.plans[2].action == "magic" and model.plans[2].target == 4, "Auto missed best AoE")
	_check(model.actors[0].mp == 20 and model.actors[3].hp == 64, "Planning spent resources")
	model.actors[0].hp = 30
	Auto.plan_round(model, 2)
	_check(model.plans[2].action == "heal" and model.plans[2].target == 0, "Auto did not heal injured ally")
	_check(model.plans[1].action == "protect", "Auto did not protect injured ally")
	for index: int in range(3):
		model.actors[index].mp = 0
	Auto.plan_round(model, 2)
	for index: int in range(3):
		_check(model.plans[index].action == "attack", "Zero mana did not fall back to attack")
	var state: Node = root.get_node("GameState")
	state.reset_new_game(false)
	var battle: Node = load("res://scripts/ui/party_battle_ui.gd").new()
	root.add_child(battle)
	battle.start_battle({})
	await process_frame
	var potions: int = state.inventory.potion
	battle._toggle_auto()
	battle._toggle_auto()
	await create_timer(0.8).timeout
	_check(battle.session.round_number == 1 and not battle.session.executing and battle.session.plans.is_empty(), "Cancelled timer started a round")
	battle._toggle_auto()
	await create_timer(0.8).timeout
	_check(battle.session.executing and not battle.can_accept_action(), "Auto did not start or manual input unlocked")
	_check(not battle._auto_button.disabled, "Stop button disabled during execution")
	battle._toggle_auto()
	var deadline := Time.get_ticks_msec() + 10000
	while not battle.can_accept_action() and Time.get_ticks_msec() < deadline:
		await process_frame
	_check(battle.can_accept_action() and battle.session.round_number == 2, "Stop did not return control after round")
	await create_timer(0.8).timeout
	_check(battle.session.round_number == 2 and not battle.session.executing, "Stopped auto restarted")
	battle._toggle_auto()
	if "--auto-capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/party-auto-battle.png")
	deadline = Time.get_ticks_msec() + 30000
	while not battle.is_resolved() and Time.get_ticks_msec() < deadline:
		await process_frame
	_check(battle.did_player_win() and battle.is_resolved(), "Auto did not finish encounter")
	_check(not battle._auto_enabled and state.inventory.potion == potions, "Auto remained active or spent potions")
	battle._finish_battle()
	battle.start_battle({})
	_check(not battle._auto_enabled and battle.can_accept_action(), "Auto leaked into next encounter")
	for actor: Dictionary in battle.session.actors:
		if int(actor.team) == 0:
			actor.hp = 1
		else:
			actor.attack = 1000
	battle._toggle_auto()
	deadline = Time.get_ticks_msec() + 10000
	while not battle.is_resolved() and Time.get_ticks_msec() < deadline:
		await process_frame
	_check(battle.is_resolved() and not battle.did_player_win() and not battle._auto_enabled, "Defeat did not stop auto")
	battle.free()
	state.battle_session = null
	for singleton: String in ["GameAudio", "GameMusic", "GameAmbience"]:
		root.get_node(singleton).stop_all()
	await create_timer(0.25).timeout
	if failures == 0:
		print("PARTY_AUTO_BATTLE_TEST_PASS planning support aoe mana stop resume victory lifecycle no_items")
	quit(0 if failures == 0 else 1)
