extends "res://scripts/systems/party_battle.gd"
## Fixed-step spatial combat. Owned by GameState; presentation never resolves damage.
const BOUNDS := Rect2(-8.0, -3.2, 16.0, 6.4)
var bounds: Rect2 = BOUNDS
var movement_resolver: Callable
var steering_resolver: Callable
var visibility_resolver: Callable
var controlled: int = 0
var paused: bool = false
var auto_enabled: bool = false
var auto_use_skills: bool = true
var auto_use_potions: bool = false
var auto_potion_threshold: float = 0.3
var events: Array[Dictionary] = []

func setup(hp: int, mp: int, attack: int, defense: int, enemy: Dictionary) -> void:
	super.setup(hp, mp, attack, defense, enemy)
	controlled = 0
	paused = false
	auto_enabled = false
	auto_use_skills = true
	auto_use_potions = false
	auto_potion_threshold = 0.3
	events.clear()
	for index: int in range(actors.size()):
		var actor: Dictionary = actors[index]
		actor.position = Vector2((-4.0 - float(index) * 1.4) if index < 3 else (3.2 + float(index - 3) * 1.4), float(index % 3 - 1) * 2.0)
		actor.facing = Vector2.RIGHT if index < 3 else Vector2.LEFT
		actor.cooldown = 0.0 if index < 3 else 0.6 + float(index - 3) * 0.3
		actor.skill_cd = 0.0
		actor.dodge_cd = 0.0
		actor.dash = 0.0
		actor.invulnerable = 0.0
		actor.hurt = 0.0
		actor.swing = 0.0
		actor.recovery = 0.0
		actor.support_cast = 0.0
		actor.windup = 0.0
		actor.intent = ""
		actor.aim = Vector2.ZERO
		actor.radius = 0.0
		actor.ward = 0.0
		actor.slow = 0.0
		actor.skill_target = -1
	_check_end()

func switch_actor() -> void:
	if winner != -1 or paused:
		return
	for offset: int in range(1, 4):
		var index: int = (controlled + offset) % 3
		if int(actors[index].hp) > 0:
			controlled = index
			return

func command(action: String) -> bool:
	if winner != -1 or paused or int(actors[controlled].hp) <= 0:
		return false
	var actor: Dictionary = actors[controlled]
	if action == "dodge":
		if float(actor.dodge_cd) > 0.0:
			return false
		actor.dodge_cd = float(hero_profile(controlled).dodge) if controlled == 0 else 1.1
		actor.dash = 0.22
		actor.invulnerable = 0.30
		actor.windup = 0.0
		actor.intent = ""
		actor.swing = 0.0
		actor.recovery = 0.0
		actor.support_cast = 0.0
		return true
	if float(actor.cooldown) > 0.0 or float(actor.windup) > 0.0 or float(actor.dash) > 0.0:
		return false
	if action == "skill":
		return _use_skill(controlled)
	if action == "attack":
		_start_attack(controlled, false)
		return true
	return false

func set_auto_enabled(enabled: bool) -> void:
	auto_enabled = enabled and winner == -1

func configure_automation(options: Dictionary) -> void:
	auto_use_skills = bool(options.get("skills", true))
	auto_use_potions = bool(options.get("potions", false))
	auto_potion_threshold = clampf(float(options.get("threshold", 0.3)), 0.1, 0.9)
	set_auto_enabled(bool(options.get("auto", false)))

func wants_auto_potion() -> bool:
	if not auto_enabled or not auto_use_potions or paused or winner != -1:
		return false
	var actor: Dictionary = actors[controlled]
	return int(actor.hp) > 0 and float(actor.hp) / maxf(float(actor.max_hp), 1.0) <= auto_potion_threshold

func skill_cost(index: int) -> int:
	return int(hero_profile(index).cost) if index == 0 else 5

func skill_cooldown(index: int) -> float:
	return float(hero_profile(index).cooldown) if index == 0 else 3.0

func _use_skill(index: int) -> bool:
	var actor: Dictionary = actors[index]
	if float(actor.skill_cd) > 0.0 or int(actor.mp) < skill_cost(index):
		return false
	if index == 0 and str(actor.get("hero_class", "")) == "thief":
		var target: int = nearest_enemy(index)
		if target < 0 or Vector2(actor.position).distance_to(actors[target].position) > 2.8 or not _visible(index, target, actors[target].position):
			return false
		actor.skill_target = target
	actor.mp = int(actor.mp) - skill_cost(index)
	actor.skill_cd = skill_cooldown(index)
	if index == 1:
		for ally: int in living(0):
			actors[ally].ward = 3.0
		actor.cooldown = 0.4
		actor.support_cast = 0.4
		events.append({"kind": "ward", "index": index, "amount": 0})
	else:
		_start_attack(index, true)
	return true

func _auto_dodge() -> void:
	var actor: Dictionary = actors[controlled]
	if float(actor.dodge_cd) > 0.0 or float(actor.dash) > 0.0:
		return
	for enemy: int in living(1):
		var threat: Dictionary = actors[enemy]
		if float(threat.windup) <= 0.0 or float(threat.windup) > 0.28:
			continue
		var away: Vector2 = Vector2(actor.position) - Vector2(threat.aim)
		if away.length() <= float(threat.radius) + 0.4:
			actor.facing = away.normalized() if away.length() > 0.01 else Vector2(threat.facing).orthogonal()
			command("dodge")
			return

func use_potion() -> bool:
	if winner != -1 or paused:
		return false
	var actor: Dictionary = actors[controlled]
	if int(actor.hp) <= 0 or int(actor.hp) >= int(actor.max_hp) or float(actor.cooldown) > 0.0 or float(actor.windup) > 0.0 or float(actor.dash) > 0.0:
		return false
	var amount: int = mini(35, int(actor.max_hp) - int(actor.hp))
	actor.hp = int(actor.hp) + amount
	actor.cooldown = 0.6
	events.append({"kind": "heal", "index": controlled, "amount": amount})
	return true

func step(delta: float, movement: Vector2) -> void:
	if winner != -1 or paused:
		return
	_check_end()
	if winner != -1:
		return
	if not movement.is_zero_approx():
		set_auto_enabled(false)
	# Caller uses a fixed physics step; bound accidental large frame gaps.
	var dt: float = clampf(delta, 0.0, 0.05)
	for index: int in range(actors.size()):
		var actor: Dictionary = actors[index]
		if int(actor.hp) <= 0:
			continue
		for timer: String in ["cooldown", "skill_cd", "dodge_cd", "invulnerable", "hurt", "swing", "ward", "recovery", "support_cast", "slow"]:
			actor[timer] = maxf(0.0, float(actor[timer]) - dt)
		if index == controlled and auto_enabled:
			_auto_dodge()
		if float(actor.dash) > 0.0:
			actor.dash = maxf(0.0, float(actor.dash) - dt)
			_move(index, Vector2(actor.facing) * 12.0 * dt)
			continue
		if float(actor.windup) > 0.0:
			actor.windup = maxf(0.0, float(actor.windup) - dt)
			if float(actor.windup) == 0.0:
				_impact(index)
				_check_end()
				if winner != -1:
					return
			continue
		if index == controlled and not auto_enabled:
			if movement.length_squared() > 0.01:
				actor.facing = movement.normalized()
				_move(index, movement.limit_length() * 4.5 * dt)
		else:
			_ai(index, dt)
	_separate()
	_check_end()

func _move(index: int, offset: Vector2) -> void:
	var point: Vector2 = actors[index].position + offset * (0.5 if float(actors[index].get("slow", 0.0)) > 0 else 1.0)
	point = point.clamp(bounds.position, bounds.end)
	actors[index].position = movement_resolver.call(index, point) if movement_resolver.is_valid() else point

func _separate() -> void:
	for a: int in range(actors.size()):
		if int(actors[a].hp) <= 0:
			continue
		for b: int in range(a + 1, actors.size()):
			if int(actors[b].hp) <= 0:
				continue
			var diff: Vector2 = actors[b].position - actors[a].position
			if diff.length() < 0.65:
				var shift: Vector2 = (diff.normalized() if diff.length() > 0.01 else Vector2.RIGHT) * (0.65 - diff.length()) * 0.5
				_move(a, -shift)
				_move(b, shift)

func nearest_enemy(index: int) -> int:
	var nearest: int = -1
	var distance: float = INF
	for target: int in living(1 - int(actors[index].team)):
		var candidate: float = Vector2(actors[index].position).distance_squared_to(actors[target].position)
		if candidate < distance:
			distance = candidate
			nearest = target
	return nearest

func _ai(index: int, dt: float) -> void:
	var actor: Dictionary = actors[index]
	var target: int = nearest_enemy(index)
	if target < 0:
		return
	var diff: Vector2 = actors[target].position - actor.position
	var ranged: bool = index in [2, 5] or (index == 0 and bool(hero_profile(index).ranged))
	var reach: float = float(hero_profile(index).reach) - 0.3 if index == 0 else 5.0 if ranged else 1.35
	actor.facing = diff.normalized()
	if diff.length() > reach or not _visible(index, target, actors[target].position):
		var direction: Vector2 = steering_resolver.call(index, target) if steering_resolver.is_valid() else diff.normalized()
		_move(index, direction * (2.8 if index < 3 else 2.0 if index != 4 else 3.0) * dt)
	elif float(actor.cooldown) <= 0.0:
		if auto_use_skills and index == 2 and int(actor.mp) >= 6:
			for ally: int in living(0):
				if int(actors[ally].hp) < int(actors[ally].max_hp) / 2:
					var amount: int = mini(25, int(actors[ally].max_hp) - int(actors[ally].hp))
					actors[ally].hp = int(actors[ally].hp) + amount
					actor.mp = int(actor.mp) - 6
					actor.cooldown = 4.0
					actor.support_cast = 0.4
					events.append({"kind": "heal", "index": ally, "amount": amount})
					return
		if auto_enabled and auto_use_skills and index < 3:
			var should_cast: bool = index == 0 or (index == 2 and int(actor.mp) >= 11)
			if index == 1:
				for ally: int in living(0):
					if float(actors[ally].ward) <= 0.0 and int(actors[ally].hp) < int(actors[ally].max_hp) * 0.75:
						should_cast = true
			if should_cast and _use_skill(index):
				return
		_start_attack(index, false)

func _start_attack(index: int, special: bool) -> void:
	var actor: Dictionary = actors[index]
	var ranged: bool = index in [2, 5] or (index == 0 and bool(hero_profile(index).ranged))
	actor.intent = "skill" if special else "attack"
	actor.windup = 0.18 if index == controlled else 0.45 if index < 3 else 0.85
	actor.radius = 2.2 if special else 1.2 if ranged else 0.9
	actor.aim = Vector2(actor.position) + Vector2(actor.facing) * (1.4 if index == 1 else 1.0)
	if ranged:
		var target: int = nearest_enemy(index)
		if target >= 0 and Vector2(actor.position).distance_to(actors[target].position) <= (float(hero_profile(index).reach) if index == 0 else 6.0):
			actor.aim = actors[target].position
			if index == 0:
				actor.facing = (Vector2(actor.aim) - Vector2(actor.position)).normalized()
	actor.cooldown = (float(hero_profile(index).interval) if index == 0 and str(actor.get("hero_class", "traveler")) != "traveler" else 0.55) if index == controlled else 1.6 if index < 3 else 2.2
	if index == 0:
		var profile := hero_profile(index)
		if special:
			actor.radius = float(profile.radius)
		elif bool(profile.ranged):
			actor.radius = 0.45
		if special and str(actor.get("hero_class", "")) == "thief":
			actor.aim = actors[int(actor.skill_target)].position
			actor.facing = (Vector2(actor.aim) - Vector2(actor.position)).normalized()
			actor.invulnerable = 0.25
		if str(actor.get("hero_class", "")) == "archer":
			var end: Vector2 = Vector2(actor.position) + Vector2(actor.facing) * float(profile.reach) if special else Vector2(actor.aim)
			events.append({"kind": "projectile", "index": index, "origin": Vector2(actor.position), "aim": end, "duration": float(actor.windup), "piercing": special})

func _impact(index: int) -> void:
	var actor: Dictionary = actors[index]
	actor.swing = 0.18
	actor.recovery = 0.32
	events.append({"kind": "swing", "index": index, "amount": 0, "aim": Vector2(actor.aim), "intent": str(actor.intent), "facing": Vector2(actor.facing), "radius": float(actor.radius)})
	for target: int in living(1 - int(actor.team)):
		var victim: Dictionary = actors[target]
		var thief: bool = index == 0 and str(actor.get("hero_class", "")) == "thief" and actor.intent == "skill"
		if thief and (target != int(actor.skill_target) or Vector2(actor.position).distance_to(victim.position) > 2.8):
			continue
		var distance: float = Vector2(victim.position).distance_to(actor.aim)
		if index == 0 and str(actor.get("hero_class", "")) == "archer" and actor.intent == "skill":
			var end: Vector2 = Vector2(actor.position) + Vector2(actor.facing) * float(hero_profile(index).reach)
			distance = Vector2(victim.position).distance_to(Geometry2D.get_closest_point_to_segment(victim.position, actor.position, end))
		if distance > float(actor.radius) + 0.3 or float(victim.invulnerable) > 0.0:
			continue
		if not _visible(index, target, actor.aim):
			continue
		var bonus: int = (int(hero_profile(index).power) if index == 0 else 12) if actor.intent == "skill" else 0
		var amount: int = maxi(1, int(actor.attack) + bonus - int(victim.defense))
		if thief:
			var behind: bool = Vector2(victim.facing).dot((Vector2(actor.position) - Vector2(victim.position)).normalized()) < -0.35
			if behind:
				amount *= 2
		if index == 0 and str(actor.get("hero_class", "")) == "mage" and actor.intent == "skill":
			victim.slow = 3.0
			events.append({"kind": "chill", "index": target, "amount": 0})
		if float(victim.ward) > 0.0:
			amount = maxi(1, amount / 2)
		victim.hp = maxi(0, int(victim.hp) - amount)
		victim.hurt = 0.20
		victim.invulnerable = 0.25
		# Hits interrupt windups and create room, including on enemies.
		victim.windup = 0.0
		victim.cooldown = maxf(float(victim.cooldown), 0.35)
		_move(target, (Vector2(victim.position) - Vector2(actor.position)).normalized() * 0.30)
		events.append({"kind": "hit", "index": target, "amount": amount, "source": index})

func _check_end() -> void:
	if living(0).is_empty():
		winner = 1
		auto_enabled = false
	elif living(1).is_empty():
		winner = 0
		auto_enabled = false
	elif int(actors[controlled].hp) <= 0:
		controlled = living(0)[0]

func _visible(source: int, target: int, aim: Vector2) -> bool:
	return bool(visibility_resolver.call(source, target, aim)) if visibility_resolver.is_valid() else true

func detach_world() -> void:
	# Break model -> scene callbacks when an encounter ends or its map is freed.
	movement_resolver = Callable()
	steering_resolver = Callable()
	visibility_resolver = Callable()
