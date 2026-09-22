extends SceneTree
const Model = preload("res://scripts/systems/action_battle.gd")
var failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func fresh() -> RefCounted:
	var model := Model.new()
	model.setup(100, 20, 18, 4, {})
	return model

func _run() -> void:
	var model: RefCounted = fresh()
	check(not model.auto_enabled, "Every encounter defaults to manual")
	model.set_auto_enabled(true)
	var before: Vector2 = model.actors[0].position
	model.step(1.0 / 60.0, Vector2.ZERO)
	check(model.actors[0].position != before, "Auto must move controlled character toward enemies")
	model.paused = true
	var snapshot: Array[Dictionary] = model.actors.duplicate(true)
	for frame: int in range(60):
		model.step(1.0 / 60.0, Vector2.ZERO)
	check(model.actors == snapshot and model.auto_enabled, "Pause freezes auto without clearing selected mode")
	model.set_auto_enabled(false)
	check(not model.auto_enabled, "Auto can be disabled while paused")
	model.paused = false
	model.set_auto_enabled(true)
	model.step(1.0 / 60.0, Vector2.LEFT)
	check(not model.auto_enabled, "Movement immediately restores manual control")
	model = fresh()
	model.actors[0].position = Vector2.ZERO
	model.actors[3].position = Vector2(1.3, 0)
	model.actors[3].cooldown = 10.0
	model.set_auto_enabled(true)
	model.step(1.0 / 60.0, Vector2.ZERO)
	check(int(model.actors[0].mp) == 15 and model.actors[0].intent == "skill", "Auto uses traveler skill in reach")
	model = fresh()
	model.actors[0].position = Vector2.ZERO
	model.actors[3].position = Vector2(1.0, 0)
	model._start_attack(3, false)
	model.actors[3].windup = 0.2
	model.set_auto_enabled(true)
	model.step(1.0 / 60.0, Vector2.ZERO)
	check(float(model.actors[0].dash) > 0.0 and float(model.actors[0].invulnerable) > 0.0, "Auto reacts to imminent warning with normal dodge")
	model = fresh()
	model.set_auto_enabled(true)
	model.switch_actor()
	check(model.controlled == 1 and model.auto_enabled, "Switching followed character retains auto")
	model.actors[1].hp = 0
	model.step(1.0 / 60.0, Vector2.ZERO)
	check(model.controlled != 1 and model.auto_enabled, "Auto survives controlled ally defeat")
	model = fresh()
	for actor: Dictionary in model.actors:
		if int(actor.team) == 0:
			actor.mp = 0
	model.set_auto_enabled(true)
	for frame: int in range(7200):
		model.step(1.0 / 60.0, Vector2.ZERO)
		if model.winner != -1:
			break
	check(model.winner == 0 and not model.auto_enabled, "Auto completes encounter without MP and stops on victory")
	model.set_auto_enabled(true)
	check(not model.auto_enabled, "Resolved battle cannot restart auto")
	model = fresh()
	model.set_auto_enabled(true)
	for index: int in [0, 1, 2]:
		model.actors[index].hp = 0
	model.step(1.0 / 60.0, Vector2.ZERO)
	check(model.winner == 1 and not model.auto_enabled, "Defeat stops auto")
	model = fresh()
	model.configure_automation({"auto": true, "skills": false})
	model.actors[0].position = Vector2.ZERO
	model.actors[3].position = Vector2(1.3, 0)
	model._ai(0, 0.01)
	check(model.actors[0].mp == 20 and model.actors[0].intent == "attack", "Disabled skills use normal attacks without spending MP")
	model.actors[2].position = Vector2.ZERO
	model.actors[1].hp = 1
	var elder_mp: int = model.actors[2].mp
	model._ai(2, 0.01)
	check(model.actors[2].mp == elder_mp and model.actors[1].hp == 1, "Disabled skills also stop automatic healing")
	model.set_auto_enabled(false)
	model.actors[0].cooldown = 0.0
	model.actors[0].windup = 0.0
	check(model.command("skill"), "Disabling automatic skills still allows manual skills")
	var state: Node = root.get_node("GameState")
	state.reset_new_game(false)
	model = state.begin_action_battle({})
	state.inventory["potion"] = 3
	model.actors[0].hp = 30
	model.configure_automation({"auto": true, "skills": false, "potions": false})
	state.advance_action_battle(0.01, Vector2.ZERO)
	check(state.inventory.potion == 3 and model.actors[0].hp == 30, "Disabled auto potions never consume stock")
	model.configure_automation({"auto": true, "skills": false, "potions": true, "threshold": 0.3})
	model.actors[0].hp = 31
	state.advance_action_battle(0.01, Vector2.ZERO)
	check(state.inventory.potion == 3, "HP above threshold must not consume potion")
	model.actors[0].hp = 30
	model.paused = true
	state.advance_action_battle(0.01, Vector2.ZERO)
	check(state.inventory.potion == 3, "Paused auto must not consume potion")
	model.paused = false
	state.advance_action_battle(0.01, Vector2.ZERO)
	check(state.inventory.potion == 2 and model.actors[0].hp == 65 and state.player_hp == 65, "Threshold consumes one shared potion and syncs persistent HP")
	model.actors[0].hp = 10
	state.advance_action_battle(0.01, Vector2.ZERO)
	check(state.inventory.potion == 2, "Cooldown blocks repeated potion consumption")
	model.actors[0].cooldown = 0.0
	state.advance_action_battle(0.01, Vector2.LEFT)
	check(state.inventory.potion == 2 and not model.auto_enabled, "Manual takeover precedes automatic consumables")
	model.set_auto_enabled(true)
	state.inventory["potion"] = 0
	state.advance_action_battle(0.01, Vector2.ZERO)
	check(state.inventory.potion == 0 and model.actors[0].hp == 10, "Empty stock neither heals nor becomes negative")
	model.winner = 0
	state.inventory["potion"] = 1
	state.advance_action_battle(0.01, Vector2.ZERO)
	check(state.inventory.potion == 1, "Resolved combat does not consume potions")
	if failures == 0:
		print("ACTION_AUTO_BATTLE_TEST_PASS default pursuit skills dodge pause takeover switch no_mp victory defeat settings potions")
	quit(0 if failures == 0 else 1)
