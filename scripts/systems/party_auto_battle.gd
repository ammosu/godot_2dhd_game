extends RefCounted
## Deterministic planning only; the normal battle model validates and resolves.
## Items and formation remain under the player's control.

static func plan_round(battle: RefCounted, potions: int) -> String:
	if battle.executing or int(battle.winner) != -1:
		return "目前無法安排自動戰鬥。"
	var previous: int = battle.current
	battle.plans.clear()
	for index: int in battle.living(0):
		battle.current = index
		var command := _choose(battle)
		var error: String = battle.plan_action(str(command.action), int(command.target), potions)
		if not error.is_empty():
			battle.current = previous
			return error
	battle.current = previous
	return ""


static func _choose(battle: RefCounted) -> Dictionary:
	var actions: Array[String] = battle.available_actions()
	var patient: int = -1
	var lowest: float = 1.0
	for index: int in battle.living(0):
		var actor: Dictionary = battle.actors[index]
		var ratio := float(actor.hp) / float(actor.max_hp)
		if ratio < lowest and int(actor.max_hp) - int(actor.hp) >= 20:
			patient = index
			lowest = ratio
	if patient >= 0 and lowest <= 0.6:
		for support: String in ["heal", "protect"]:
			if actions.has(support) and battle.validate(support, patient).is_empty():
				return {"action": support, "target": patient}
	if actions.has("magic"):
		var center: int = -1
		var count: int = 1
		for index: int in battle.valid_targets("magic"):
			var hits: Array[int] = battle.preview("magic", index)
			if hits.size() > count:
				center = index
				count = hits.size()
		if center >= 0:
			return {"action": "magic", "target": center}
	var target: int = -1
	var weakest: int = 2147483647
	for index: int in battle.valid_targets("attack"):
		if int(battle.actors[index].hp) < weakest:
			target = index
			weakest = int(battle.actors[index].hp)
	if target < 0:
		return {"action": "guard", "target": battle.current}
	var basic_damage := maxi(1, int(battle.actors[battle.current].attack) - int(battle.actors[target].defense))
	if weakest > basic_damage:
		for skill: String in ["slash", "skill"]:
			if actions.has(skill) and battle.validate(skill, target).is_empty():
				return {"action": skill, "target": target}
	return {"action": "attack", "target": target}
