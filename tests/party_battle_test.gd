extends SceneTree
const Model = preload("res://scripts/systems/party_battle.gd")
var failures: int = 0

func _check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var model := Model.new()
	model.setup(100, 20, 18, 4, {})
	_check(model.actors.size() == 6, "Expected three allies and three enemies")
	_check(model.resolve("magic", 4).has("error"), "Traveler accepted Elder skill")
	_check(model.available_actions().has("slash"), "Traveler missing unique skill")
	model.current = 2
	_check(model.preview("magic", 4) == [3, 4, 5], "Centered AoE must hit three enemies")
	_check(model.preview("magic", 3) == [3, 4], "Edge AoE must exclude far enemy")
	_check(model.preview("attack", 4) == [4], "Single-target attack hit extra actors")
	var invalid := model.resolve("magic", 0)
	_check(invalid.has("error") and int(model.actors[0].mp) == 20, "Invalid target spent MP")
	var before: int = model.actors[3].hp
	var result := model.resolve("magic", 4)
	_check(result.targets.size() == 3 and int(model.actors[2].mp) == 24, "AoE MP must be charged once")
	_check(int(model.actors[3].hp) < before and int(model.actors[0].hp) == 100, "AoE damage or friendly fire")
	model.actors[2].mp = 0
	before = model.actors[3].hp
	_check(model.resolve("skill", 3).has("error") and int(model.actors[3].hp) == before, "Insufficient MP changed HP")
	model.actors[1].hp = 0
	model.current = 0
	model.advance()
	_check(model.current == 2, "Turn order did not skip fallen ally")
	model.resolve("guard", 2)
	model.advance()
	result = model.resolve("attack", 2)
	_check(int(result.damage[0]) == 5, "Guard did not halve incoming damage")
	model.actors[4].hp = 0
	model.advance()
	_check(model.current == 5, "Turn order did not skip fallen enemy")
	model.resolve("magic", 2)
	_check(int(model.actors[5].mp) == 24, "Enemy magic did not consume mana")
	model.advance()
	_check(model.current == 0 and model.round_number == 2, "Round order failed")
	model.actors[3].hp = 1
	model.actors[5].hp = 1
	model.current = 2
	model.actors[2].mp = 8
	model.resolve("magic", 3)
	_check(model.winner == -1, "Victory declared before every enemy falls")
	model.resolve("attack", 5)
	_check(model.winner == 0, "All enemies down did not win")
	_check(model.resolve("attack", 5).has("error"), "Resolved battle accepted another action")
	model.setup(1, 20, 18, 4, {})
	model.current = 3
	model.resolve("attack", 0)
	_check(model.winner == -1 and model.living(0) == [1, 2], "Traveler knockout incorrectly ended party battle")
	model.actors[1].hp = 1
	model.actors[2].hp = 1
	model.current = 5
	model.resolve("magic", 1)
	_check(model.winner == 1, "Party wipe did not trigger defeat")
	model.setup(90, 20, 18, 4, {})
	model.current = 1
	_check(model.resolve("protect", 1).has("error"), "Noah protected himself")
	_check(model.resolve("protect", 3).has("error"), "Noah protected enemy")
	model.resolve("protect", 0)
	_check(model.is_protected(0) and int(model.actors[1].mp) == 12, "Protection or mana failed")
	model.current = 3
	result = model.resolve("attack", 0)
	_check(int(result.damage[0]) == 5, "Protection did not halve damage")
	model.actors[0].guard = true
	result = model.resolve("attack", 0)
	_check(int(result.damage[0]) == 5, "Guard and protection stacked")
	model.current = 0
	model.advance()
	_check(not model.is_protected(0), "Protection survived protector next turn")
	model.resolve("protect", 0)
	model.actors[1].hp = 0
	_check(not model.is_protected(0), "Fallen protector still protects")
	model.current = 2
	result = model.resolve("heal", 0)
	_check(int(result.healing) == 20 and int(model.actors[0].hp) == 100 and int(model.actors[2].mp) == 26, "Healing clamp or mana incorrect")
	_check(model.resolve("heal", 0).has("error") and int(model.actors[2].mp) == 26, "Full-health heal spent mana")
	_check(model.resolve("heal", 1).has("error"), "Healing revived fallen actor")
	_check(model.resolve("heal", 3).has("error"), "Healing accepted enemy")
	var state := root.get_node("GameState")
	state.call("reset_new_game", false)
	state.call("begin_party_battle", {})
	state.get("battle_session").actors[0].hp = 20
	var potions: int = state.get("inventory").potion
	state.call("resolve_party_action", "potion", 0)
	_check(int(state.get("player_hp")) == 55 and int(state.get("inventory").potion) == potions - 1, "Potion/persistent HP mismatch")
	state.get("inventory").potion = 0
	_check(state.call("resolve_party_action", "potion", 0).has("error"), "Empty inventory accepted potion")
	state.set("battle_session", null)
	if failures == 0:
		print("PARTY_BATTLE_TEST_PASS teams targeting aoe mana guard turns enemy_magic victory persistence potion")
	quit(0 if failures == 0 else 1)
