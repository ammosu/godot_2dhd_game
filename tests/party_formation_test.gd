extends SceneTree
const Model = preload("res://scripts/systems/party_battle.gd")
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
	_check(model.preview("attack", 3) == [3] and model.preview("attack", 4).is_empty(), "Melee ignored front screen")
	var mana: int = model.actors[0].mp
	_check(model.resolve("slash", 5).has("error") and model.actors[0].mp == mana and model.actors[5].hp == 46, "Out of range action mutated state")
	_check(model.preview("slash", 4) == [4], "Slash cannot reach middle")
	model.current = 1
	_check(model.preview("attack", 4) == [4] and model.preview("attack", 5).is_empty(), "Spear reach incorrect")
	model.current = 2
	_check(model.preview("skill", 5) == [5] and model.preview("magic", 4) == [3, 4, 5], "Magic blocked by formation")
	model.current = 0
	_check(model.change_row(-1) != "" and not model.formation_changed, "Invalid row spent move")
	_check(model.change_row(2).is_empty(), "Formation change rejected")
	_check(model.actors[0].row == 2 and model.actors[2].row == 0 and model.actors[0].position == Vector2(3.2, 0), "Swap did not update positions")
	_check(model.change_row(1) != "" and model.current == 0 and model.actors[0].mp == mana, "Swap repeated or consumed turn/mana")
	model.current = 3
	_check(model.preview("attack", 0).is_empty() and model.preview("attack", 2) == [2], "Enemy ignored swapped screen")
	_check(not model.change_row(1).is_empty(), "Enemy accepted player formation control")
	model.actors[2].hp = 0
	_check(model.preview("attack", 1) == [1], "Fallen front still blocks")
	model.actors[1].hp = 0
	_check(model.preview("attack", 0) == [0], "Last rear survivor unreachable")
	model.current = 0
	model.advance()
	_check(model.formation_changed, "Move reset before next round")
	model.setup(100, 20, 18, 4, {})
	_check(not model.formation_changed and model.actors[0].row == 0, "New encounter retained formation")
	var state: Node = root.get_node("GameState")
	state.call("reset_new_game", false)
	var battle: Node = load("res://scripts/ui/party_battle_ui.gd").new()
	root.add_child(battle)
	battle.call("start_battle", {})
	await process_frame
	var before: Vector2 = battle.call("_point", 0)
	battle.call("_change_row", 2)
	await process_frame
	_check(battle.call("_point", 0) != before and battle.session.actors[0].row == 2, "UI formation did not move actor")
	for row_button: Button in battle.get("_row_buttons"):
		_check(row_button.disabled, "Repeated move enabled in UI")
	for index: int in range(6):
		var card: Button = battle.get("_cards")[index]
		var hp_bar: ProgressBar = battle.get("_hp_bars")[index]
		var mp_bar: ProgressBar = battle.get("_mp_bars")[index]
		_check(card.get_rect().size.y >= hp_bar.position.y + hp_bar.size.y and hp_bar.position.y + hp_bar.size.y <= mp_bar.position.y, "Stat bars overlap")
		_check(hp_bar.value == float(battle.session.actors[index].hp) and mp_bar.value == float(battle.session.actors[index].mp), "Actor bars differ from state")
		_check((hp_bar.get_node("Value") as Label).text.contains("HP ") and (mp_bar.get_node("Value") as Label).text.contains("MP "), "Actor stats missing")
		_check(Rect2(Vector2.ZERO, battle.get("_stage").size).encloses(card.get_rect()), "Actor stats clipped: " + str(card.get_rect()))
		for other: int in range(index + 1, 6):
			_check(not card.get_rect().intersects(battle.get("_cards")[other].get_rect()), "Actor stats overlap")
	if "--formation-capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/party-formation.png")
	battle.set("_busy", true)
	battle.call("_change_row", 1)
	_check(battle.session.actors[0].row == 2, "Busy UI changed formation")
	battle.free()
	state.set("battle_session", null)
	for singleton: String in ["GameAudio", "GameMusic", "GameAmbience"]:
		root.get_node(singleton).call("stop_all")
	await create_timer(0.25).timeout
	if failures == 0:
		print("PARTY_FORMATION_TEST_PASS reach swap fallen_screen magic stats layout input_lock")
	quit(0 if failures == 0 else 1)
