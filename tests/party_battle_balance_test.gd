extends SceneTree
const Model = preload("res://scripts/systems/party_battle.gd")
var failures: int = 0

func _initialize() -> void:
	for policy: String in ["basic", "roles", "no_mana"]:
		var model := Model.new()
		model.setup(100, 20, 18, 4, {})
		if policy == "no_mana":
			for actor: Dictionary in model.actors:
				if int(actor.team) == 0:
					actor.mp = 0
		var turns: int = 0
		while model.winner == -1 and turns < 100:
			for index: int in model.living(0):
				model.current = index
				var targets := model.living(1)
				var target: int = model.valid_targets("attack")[0]
				var action := "attack"
				if policy == "roles":
					if model.current == 0 and model.validate("slash", target).is_empty():
						action = "slash"
					elif model.current == 1 and model.validate("protect", 0).is_empty():
						action = "protect"
						target = 0
					elif model.current == 2:
						for ally: int in model.living(0):
							if int(model.actors[ally].max_hp) - int(model.actors[ally].hp) >= 25 and model.validate("heal", ally).is_empty():
								action = "heal"
								target = ally
								break
						if action == "attack":
							target = 4 if targets.has(4) else targets[0]
							if model.validate("magic", target).is_empty():
								action = "magic"
				if not model.validate(action, target).is_empty():
					target = model.valid_targets(action)[0]
				var error := model.plan_action(action, target, 0)
				if not error.is_empty():
					push_error("Balance plan rejected: " + error)
					failures += 1
			model.begin_round(0)
			while model.winner == -1:
				var command := model.next_command(0)
				if command.is_empty():
					break
				var result := model.resolve(str(command.action), int(command.target))
				if result.has("error"):
					push_error("Balance action rejected: " + policy)
					failures += 1
				turns += 1
			model.finish_round()
		print("PARTY_BALANCE %s winner=%d round=%d actions=%d ally_hp=%s ally_mp=%s" % [
			policy, model.winner, model.round_number, turns,
			[model.actors[0].hp, model.actors[1].hp, model.actors[2].hp],
			[model.actors[0].mp, model.actors[1].mp, model.actors[2].mp]])
		if model.winner != 0 or turns >= 100:
			push_error("Baseline party policy failed to win: " + policy)
			failures += 1
	if failures == 0:
		print("PARTY_BALANCE_TEST_PASS basic roles no_mana")
	quit(0 if failures == 0 else 1)
