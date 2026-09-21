extends RefCounted
## Encounter-local authoritative combat state, owned by GameState.
const AreaSkill = preload("res://scripts/gameplay/area_skill.gd")
const SKILLS: Dictionary = {
	"attack": {"name": "攻擊", "cost": 0, "power": 0, "radius": 0.0},
	"skill": {"name": "月光彈", "cost": 5, "power": 12, "radius": 0.0},
	"slash": {"name": "月影斬", "cost": 5, "power": 14, "radius": 0.0},
	"magic": {"name": "霜星爆", "cost": 8, "power": 8, "radius": 2.0},
	"protect": {"name": "守護同伴", "cost": 4, "power": 0, "radius": 0.0},
	"heal": {"name": "月泉療癒", "cost": 6, "power": 30, "radius": 0.0},
	"guard": {"name": "防禦", "cost": 0, "power": 0, "radius": 0.0},
	"potion": {"name": "藥水", "cost": 0, "power": 35, "radius": 0.0},
}
var actors: Array[Dictionary] = []
var current: int = 0
var round_number: int = 1
const ROW_NAMES: Array[String] = ["前排", "中排", "後排"]
var formation_changed: bool = false
var winner: int = -1
var executing: bool = false
var plans: Dictionary = {}
var turn_queue: Array[Dictionary] = []
const SPEEDS: Array[int] = [18, 14, 10, 8, 22, 12]


func setup(hp: int, mp: int, attack: int, defense: int, enemy: Dictionary) -> void:
	actors = [
		_actor("旅人", 0, 100, mp, attack, defense, Vector2(0, 0), "wanderer"),
		_actor("諾亞", 0, 80, 16, 17, 6, Vector2(1.6, 0.8), "noah"),
		_actor("長老", 0, 65, 32, 15, 3, Vector2(3.2, 0), "elder"),
		_actor(str(enemy.get("name", "遺跡守衛")), 1, int(enemy.get("max_hp", 64)), 10, int(enemy.get("attack", 14)), int(enemy.get("defense", 3)), Vector2(0, 0), "guardian"),
		_actor("苔背狼", 1, 42, 0, 12, 2, Vector2(1.6, 0.8), "moss_wolf"),
		_actor("月蝕術士", 1, 46, 32, 13, 2, Vector2(3.2, 0), "eclipse_mage"),
	]
	for index: int in range(actors.size()):
		actors[index].row = index % 3
		actors[index].speed = SPEEDS[index]
	executing = false
	plans.clear()
	turn_queue.clear()
	formation_changed = false
	actors[0].hp = maxi(0, hp)
	current = 0
	round_number = 1
	winner = -1
	if int(actors[0].hp) == 0:
		advance()


func _actor(label: String, team: int, hp: int, mp: int, attack: int, defense: int, point: Vector2, art: String) -> Dictionary:
	return {"name": label, "team": team, "hp": hp, "max_hp": hp, "mp": mp, "max_mp": mp, "attack": attack, "defense": defense, "position": point, "art": art, "guard": false, "protected_by": -1}


func change_row(row: int) -> String:
	if executing or winner != -1 or actors.is_empty() or int(actors[current].team) != 0 or int(actors[current].hp) <= 0:
		return "目前無法調整站位。"
	if row < 0 or row >= ROW_NAMES.size():
		return "無效的站位。"
	if int(actors[current].row) == row:
		return "已在此排。"
	if formation_changed:
		return "本回合已交換站位，全隊每回合限一次。"
	var previous: int = actors[current].row
	for index: int in range(actors.size()):
		if index != current and int(actors[index].team) == 0 and int(actors[index].row) == row:
			_set_row(index, previous)
			break
	_set_row(current, row)
	formation_changed = true
	return ""


func swap_allies(source: int, target: int) -> String:
	if source < 0 or target < 0 or source >= actors.size() or target >= actors.size() or int(actors[source].team) != 0 or int(actors[target].team) != 0:
		return "請拖曳友方角色至另一位同伴。"
	var previous: int = current
	current = source
	var error := change_row(int(actors[target].row))
	current = previous
	return error


func plan_action(action: String, target: int, potions: int) -> String:
	if executing or actors.is_empty() or int(actors[current].team) != 0:
		return "目前無法安排指令。"
	var error := validate(action, target)
	if not error.is_empty():
		return error
	var reserved: int = 0
	for index: int in plans:
		if index != current and str(plans[index].action) == "potion":
			reserved += 1
	if action == "potion" and reserved >= potions:
		return "藥水不足，其他同伴已預定使用。"
	plans[current] = {"caster": current, "action": action, "target": current if action in ["guard", "potion"] else target}
	return ""


func ready_to_resolve() -> bool:
	if executing or winner != -1:
		return false
	for index: int in living(0):
		if not plans.has(index):
			return false
	return not living(0).is_empty()


func initiative_order() -> Array[int]:
	var order: Array[int] = living(0)
	order.append_array(living(1))
	order.sort_custom(func(a: int, b: int) -> bool:
		return int(actors[a].speed) > int(actors[b].speed) if actors[a].speed != actors[b].speed else a < b)
	return order


func begin_round(potions: int) -> String:
	if not ready_to_resolve():
		return "請先安排所有存活同伴的動作。"
	var previous: int = current
	var reserved: int = 0
	for index: int in living(0):
		current = index
		var command: Dictionary = plans[index]
		var error := validate(str(command.action), int(command.target))
		if str(command.action) == "potion":
			reserved += 1
		if not error.is_empty() or reserved > potions:
			current = previous
			return "%s 的指令需要重新安排。" % actors[index].name
	for index: int in living(1):
		current = index
		var action := "magic" if actors[index].art == "eclipse_mage" and int(actors[index].mp) >= 8 else "attack"
		var targets := valid_targets(action)
		plans[index] = {"caster": index, "action": action, "target": targets[(round_number - 1) % targets.size()]}
	turn_queue.clear()
	for index: int in initiative_order():
		turn_queue.append(plans[index].duplicate())
	for actor: Dictionary in actors:
		actor.guard = false
		actor.protected_by = -1
	current = previous
	executing = true
	return ""


func next_command(potions: int) -> Dictionary:
	if not executing or winner != -1:
		return {}
	while not turn_queue.is_empty():
		var command: Dictionary = turn_queue.pop_front()
		current = int(command.caster)
		if int(actors[current].hp) <= 0:
			continue
		var action: String = command.action
		var target: int = command.target
		if action == "potion" and potions <= 0:
			return {"caster": current, "action": "guard", "target": current}
		if not validate(action, target).is_empty():
			# Offensive actions follow a surviving reachable enemy. Support never
			# silently changes recipient; an invalid support action becomes guard.
			var targets: Array[int] = []
			if action in ["attack", "slash", "skill", "magic"]:
				targets = valid_targets(action)
			if not targets.is_empty():
				command.target = targets[0]
			else:
				command.action = "guard"
				command.target = current
		return command
	return {}


func finish_round() -> void:
	if not executing or winner != -1 or not turn_queue.is_empty():
		return
	executing = false
	round_number += 1
	formation_changed = false
	plans.clear()
	current = living(0)[0]


func _set_row(index: int, row: int) -> void:
	actors[index].row = row
	actors[index].position = Vector2(row * 1.6, 0.8 if row == 1 else 0.0)


func attack_reach(action: String) -> int:
	if action not in ["attack", "slash"]:
		return 3
	return 2 if action == "slash" or str(actors[current].art) == "noah" else 1


func in_reach(action: String, target: int) -> bool:
	if action not in ["attack", "slash"]:
		return true
	var front: int = 2
	for index: int in living(int(actors[target].team)):
		front = mini(front, int(actors[index].row))
	return int(actors[target].row) - front < attack_reach(action)


func valid_targets(action: String) -> Array[int]:
	var result: Array[int] = []
	for index: int in range(actors.size()):
		if validate(action, index).is_empty():
			result.append(index)
	return result


func available_actions() -> Array[String]:
	match str(actors[current].art):
		"wanderer": return ["attack", "slash", "guard", "potion"]
		"noah": return ["attack", "protect", "guard", "potion"]
		"elder": return ["attack", "skill", "magic", "heal", "guard", "potion"]
		"eclipse_mage": return ["attack", "magic"]
	return ["attack", "guard"]


func is_protected(index: int) -> bool:
	var source: int = actors[index].protected_by
	return source >= 0 and source < actors.size() and int(actors[source].hp) > 0


func living(team: int) -> Array[int]:
	var result: Array[int] = []
	for index: int in range(actors.size()):
		if int(actors[index].team) == team and int(actors[index].hp) > 0:
			result.append(index)
	return result


func preview(action: String, target: int) -> Array[int]:
	var empty: Array[int] = []
	if winner != -1 or not SKILLS.has(action) or actors.is_empty():
		return empty
	if not available_actions().has(action):
		return empty
	if action == "guard" or action == "potion":
		return [current]
	if target < 0 or target >= actors.size() or int(actors[target].hp) <= 0:
		return empty
	if action in ["heal", "protect"]:
		if actors[target].team != actors[current].team or (action == "protect" and target == current):
			return empty
		return [target]
	if actors[target].team == actors[current].team:
		return empty
	if not in_reach(action, target):
		return empty
	if action != "magic":
		return [target]
	return AreaSkill.enemy_indices(actors, int(actors[current].team), actors[target].position, float(SKILLS[action].radius))


func validate(action: String, target: int) -> String:
	if winner != -1 or actors.is_empty() or int(actors[current].hp) <= 0:
		return "戰鬥已結束或角色無法行動。"
	if not SKILLS.has(action):
		return "未知技能。"
	if not available_actions().has(action):
		return "這名角色無法使用此技能。"
	if int(actors[current].mp) < int(SKILLS[action].cost):
		return "MP 不足，請改用攻擊或防禦。"
	if action == "potion" and int(actors[current].hp) >= int(actors[current].max_hp):
		return "HP 已滿，不需要藥水。"
	if target >= 0 and target < actors.size() and int(actors[target].hp) > 0 and actors[target].team != actors[current].team and not in_reach(action, target):
		return "超出攻擊距離：前方仍有敵人阻擋，請選前排或使用遠程法術。"
	if preview(action, target).is_empty():
		return "請選擇存活的同伴。" if action in ["heal", "protect"] else "請選擇仍在場上的敵人。"
	if action == "heal" and int(actors[target].hp) >= int(actors[target].max_hp):
		return "目標 HP 已滿，請選擇受傷的同伴。"
	return ""


func resolve(action: String, target: int) -> Dictionary:
	var error := validate(action, target)
	if not error.is_empty():
		return {"error": error}
	var affected := preview(action, target)
	actors[current].mp = int(actors[current].mp) - int(SKILLS[action].cost)
	var damage: Array[int] = []
	var healing: int = 0
	if action == "guard":
		actors[current].guard = true
	elif action == "potion":
		healing = mini(35, int(actors[current].max_hp) - int(actors[current].hp))
		actors[current].hp = int(actors[current].hp) + healing
	elif action == "heal":
		healing = mini(30, int(actors[target].max_hp) - int(actors[target].hp))
		actors[target].hp = int(actors[target].hp) + healing
	elif action == "protect":
		actors[target].protected_by = current
	else:
		for index: int in affected:
			var amount := maxi(1, int(actors[current].attack) + int(SKILLS[action].power) - int(actors[index].defense))
			if bool(actors[index].guard) or is_protected(index):
				amount = maxi(1, amount / 2)
			amount = mini(amount, int(actors[index].hp))
			actors[index].hp = int(actors[index].hp) - amount
			damage.append(amount)
	if living(1).is_empty():
		winner = 0
	elif living(0).is_empty():
		winner = 1
	return {"targets": affected, "damage": damage, "healing": healing, "action": action, "caster": current}


func advance() -> void:
	if winner != -1:
		return
	for step: int in range(actors.size()):
		current = (current + 1) % actors.size()
		if current == 0:
			round_number += 1
			formation_changed = false
		if int(actors[current].hp) > 0:
			actors[current].guard = false
			for actor: Dictionary in actors:
				if int(actor.protected_by) == current:
					actor.protected_by = -1
			return
