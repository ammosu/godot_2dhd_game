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
	if failures == 0:
		print("ACTION_AUTO_BATTLE_TEST_PASS default pursuit skills dodge pause takeover switch no_mp victory defeat")
	quit(0 if failures == 0 else 1)
