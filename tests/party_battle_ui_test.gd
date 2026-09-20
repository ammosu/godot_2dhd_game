extends SceneTree
var failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _ready_for_action(battle: Node) -> void:
	var deadline := Time.get_ticks_msec() + 10000
	while not bool(battle.call("can_accept_action")) and not bool(battle.call("is_resolved")) and Time.get_ticks_msec() < deadline:
		await process_frame
	_check(bool(battle.call("can_accept_action")) or bool(battle.call("is_resolved")), "Party UI action timed out")

func _run() -> void:
	var state := root.get_node("GameState")
	state.call("reset_new_game", false)
	var battle: Node = load("res://scripts/ui/party_battle_ui.gd").new()
	root.add_child(battle)
	battle.call("start_battle", {"max_hp": 64})
	await process_frame
	var model: RefCounted = state.get("battle_session")
	battle.call("_select_action", "magic")
	battle.call("_select_target", 4)
	_check((battle.get("_ring") as Line2D).visible, "AoE range preview missing")
	_check((battle.get("_preview") as Label).text.contains("3 人"), "AoE preview count differs from model")
	if "--party-art-capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.dream-loop/party-range-preview.png")
	(battle.get("_confirm") as Button).pressed.emit()
	battle.call("choose_action", "magic")
	_check(int(state.get("player_mp")) == 20, "MP charged before impact")
	await create_timer(0.22).timeout
	_check(int(state.get("player_mp")) == 12, "Repeated input double-charged MP or impact missing")
	_check(int(model.actors[3].hp) == 41 and int(model.actors[4].hp) == 18 and int(model.actors[5].hp) == 22, "Actual AoE targets/damage differ from preview")
	if "--party-art-capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.dream-loop/party-magic-impact.png")
	await _ready_for_action(battle)
	_check(int(model.current) == 1, "Noah did not receive second turn")
	battle.call("choose_action", "guard")
	await _ready_for_action(battle)
	_check(int(model.current) == 2, "Elder did not receive third turn")
	battle.call("choose_action", "guard")
	await _ready_for_action(battle)
	_check(int(model.current) == 0 and int(model.round_number) == 2, "Enemy phase did not return control")
	_check(int(model.actors[5].mp) == 24, "Enemy mage never cast AoE")
	_check(int(model.actors[0].hp) < 100 and int(model.actors[1].hp) < 80 and int(model.actors[2].hp) == 65, "Enemy edge AoE did not honor range/friendly-fire rules")
	_check((battle.get("_stage") as Control).find_children("*", "Node2D", true, false).filter(func(node: Node) -> bool: return node.get_script() == load("res://scripts/ui/magic_burst.gd")).is_empty(), "Magic effects leaked after turn")
	battle.call("choose_action", "magic")
	await _ready_for_action(battle)
	for turn: int in range(10):
		if bool(battle.call("is_resolved")):
			break
		battle.call("choose_action", "attack")
		await _ready_for_action(battle)
	_check(bool(battle.call("did_player_win")), "Party UI did not resolve victory")
	await process_frame
	var continue_button := battle.get("_continue") as Button
	_check(continue_button.visible and root.get_visible_rect().encloses(continue_button.get_global_rect()), "Victory button outside viewport")
	battle.call("_finish_battle")
	_check(state.get("battle_session") == null and not bool(battle.call("is_active")), "Party encounter state not released")
	battle.queue_free()
	state.set("battle_session", null)
	for singleton: String in ["GameAudio", "GameMusic", "GameAmbience"]:
		root.get_node(singleton).call("stop_all")
	await create_timer(0.3).timeout
	if failures == 0:
		print("PARTY_BATTLE_UI_TEST_PASS preview impact targets input_lock mana turn_order enemy_aoe cleanup")
	quit(0 if failures == 0 else 1)
