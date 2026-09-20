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
var winner: int = -1


func setup(hp: int, mp: int, attack: int, defense: int, enemy: Dictionary) -> void:
	actors = [
		_actor("旅人", 0, 100, mp, attack, defense, Vector2(0, 0), "wanderer"),
		_actor("諾亞", 0, 80, 16, 17, 6, Vector2(1.6, 0.8), "noah"),
		_actor("長老", 0, 65, 32, 15, 3, Vector2(3.2, 0), "elder"),
		_actor(str(enemy.get("name", "遺跡守衛")), 1, int(enemy.get("max_hp", 64)), 10, int(enemy.get("attack", 14)), int(enemy.get("defense", 3)), Vector2(0, 0), "guardian"),
		_actor("苔背狼", 1, 42, 0, 12, 2, Vector2(1.6, 0.8), "moss_wolf"),
		_actor("月蝕術士", 1, 46, 32, 13, 2, Vector2(3.2, 0), "eclipse_mage"),
	]
	actors[0].hp = maxi(0, hp)
	current = 0
	round_number = 1
	winner = -1
	if int(actors[0].hp) == 0:
		advance()


func _actor(label: String, team: int, hp: int, mp: int, attack: int, defense: int, point: Vector2, art: String) -> Dictionary:
	return {"name": label, "team": team, "hp": hp, "max_hp": hp, "mp": mp, "max_mp": mp, "attack": attack, "defense": defense, "position": point, "art": art, "guard": false, "protected_by": -1}


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
		if int(actors[current].hp) > 0:
			actors[current].guard = false
			for actor: Dictionary in actors:
				if int(actor.protected_by) == current:
					actor.protected_by = -1
			return
