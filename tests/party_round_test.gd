extends SceneTree
const Model = preload("res://scripts/systems/party_battle.gd")
var failures: int = 0

func _check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _initialize() -> void:
	var model := Model.new()
	model.setup(100, 20, 18, 4, {})
	_check(model.initiative_order() == [4, 0, 1, 5, 2, 3], "Speed order must mix both teams")
	_check(not model.begin_round(1).is_empty(), "Incomplete plans started combat")
	_check(model.swap_allies(0, 2).is_empty(), "First swap failed")
	for index: int in range(3):
		model.current = index
		_check(model.plan_action("attack", 3, 1).is_empty(), "Could not plan attack")
	_check(not model.swap_allies(1, 2).is_empty(), "Second planner gained another swap")
	_check(model.actors[3].hp == 64 and model.actors[0].mp == 20, "Planning mutated resources")
	model.current = 0
	_check(model.plan_action("slash", 3, 1).is_empty() and model.plans.size() == 3, "Plan editing appended action")
	_check(model.begin_round(1).is_empty(), "Complete round rejected")
	_check(not model.swap_allies(0, 1).is_empty() and not model.plan_action("guard", 0, 1).is_empty(), "Execution accepted input")
	var acted: Array[int] = []
	while true:
		var command := model.next_command(1)
		if command.is_empty():
			break
		acted.append(int(command.caster))
		_check(not model.resolve(str(command.action), int(command.target)).has("error"), "Queued action invalid at execution")
	_check(acted == [4, 0, 1, 5, 2, 3], "Round not executed in speed order")
	model.finish_round()
	_check(model.round_number == 2 and not model.formation_changed and model.plans.is_empty() and not model.executing, "Round did not reset planning/formation")
	model.setup(50, 20, 18, 4, {})
	model.actors[1].hp = 30
	_check(model.plan_action("potion", 0, 1).is_empty(), "First potion reservation failed")
	model.current = 1
	_check(not model.plan_action("potion", 1, 1).is_empty(), "Shared potion overbooked")
	model.current = 0
	model.plan_action("guard", 0, 1)
	model.current = 1
	_check(model.plan_action("potion", 1, 1).is_empty(), "Edited plan did not release potion")
	model.current = 2
	model.plan_action("attack", 3, 1)
	model.begin_round(1)
	model.actors[0].hp = 0
	model.actors[3].hp = 0
	while true:
		var command := model.next_command(1)
		if command.is_empty():
			break
		_check(int(command.caster) != 0 and int(command.caster) != 3, "Dead actor acted")
		_check(model.validate(str(command.action), int(command.target)).is_empty(), "Dead target not handled")
	model.finish_round()
	model.actors[1].speed = 10
	model.actors[2].speed = 10
	_check(model.initiative_order().find(1) < model.initiative_order().find(2), "Speed ties are not stable")
	if failures == 0:
		print("PARTY_ROUND_TEST_PASS planning speed mixed_teams swap_budget reservations retarget dead_skip")
	quit(0 if failures == 0 else 1)
