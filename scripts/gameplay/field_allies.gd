extends RefCounted
## Travelling companions join field fights as supporting allies.
## Enemies still hunt only the traveler, so companions cannot fall and no new
## defeat rules exist; they add pressure (Noah) and relief (Sia).
## Noah: steps in beside the nearest engaged enemy and thrusts his spear; when
## the traveler is badly hurt he braces and shields them for a few seconds.
## Sia: rings her hand bell, slowing enemies around herself and easing a
## little of the traveler's wounds.

## An enemy counts as engaged while chasing within this range of the traveler.
const Awareness = preload("res://scripts/gameplay/enemy_awareness.gd")
const ENGAGE_RADIUS: float = 9.0
const NOAH_REACH: float = 1.5
const NOAH_STANDOFF: float = 1.4
## Sia keeps this far behind the traveler, away from the fight.
const SIA_BACKOFF: float = 2.0
const NOAH_INTERVAL: float = 1.7
const NOAH_WINDUP: float = 0.28
const NOAH_STRIKE: float = 0.16
const NOAH_RECOVER: float = 0.3
## Share of Noah's attack stat dealt per thrust; the traveler stays the main damage.
const NOAH_POWER: float = 0.7
const WARD_TRIGGER: float = 0.55
const WARD_TIME: float = 4.0
const WARD_COOLDOWN: float = 14.0
const WARD_POSE_TIME: float = 0.6
## Incoming damage multiplier while Noah's ward holds.
const WARD_FACTOR: float = 0.6
const SIA_INTERVAL: float = 7.5
const SIA_WINDUP: float = 0.35
const SIA_RING: float = 0.4
const SIA_RECOVER: float = 0.35
const BELL_RADIUS: float = 5.5
const BELL_SLOW: float = 2.5
const HEAL_TRIGGER: float = 0.7
const HEAL_RATIO: float = 0.12

var ward_time: float = 0.0
var _state: Dictionary = {}
var _introduced: Dictionary = {}
const GUARD_COLOR := Color("9fd4ff")
const BELL_COLOR := Color("ffe0a0")
const HEAL_COLOR := Color("a8f0b8")

func _introduce(field: Node3D, skill: String, message: String) -> void:
	if not _engaged(field).is_empty() and not _introduced.has(skill):
		_introduced[skill] = true
		GameState.notification_requested.emit(message)



## Damage the traveler takes after companion protection.
func incoming_damage(raw: int) -> int:
	return maxi(1, roundi(float(raw) * (WARD_FACTOR if ward_time > 0.0 else 1.0)))


func step(field: Node3D, delta: float) -> void:
	ward_time = maxf(0.0, ward_time - delta)
	var engaged: Array[Dictionary] = _engaged(field)
	for node: Node in field.get_tree().get_nodes_in_group("party_followers"):
		if node.is_queued_for_deletion():
			continue
		var follower := node as Node3D
		var id: String = str(follower.get("resident_id"))
		if not _state.has(id):
			_state[id] = {"phase": "", "time": 0.0, "cooldown": 0.6, "ward_cooldown": 0.0, "target": {}}
		var state: Dictionary = _state[id]
		state.cooldown = maxf(0.0, float(state.cooldown) - delta)
		state.ward_cooldown = maxf(0.0, float(state.ward_cooldown) - delta)
		if engaged.is_empty():
			state.phase = ""
			follower.set("combat_goal", Vector3.INF)
			follower.call("set_action", -1, &"left")
			continue
		if id == "noah":
			_noah(field, follower, state, engaged, delta)
		elif id == "sia":
			_sia(field, follower, state, engaged, delta)


func _engaged(field: Node3D) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var hero: Vector3 = (field.get("player") as Node3D).global_position
	for enemy: Dictionary in field.get("enemies"):
		if not Awareness.suppressed(field, enemy) and int(enemy.hp) > 0 and str(enemy.state) == "chase" and (enemy.body as Node3D).global_position.distance_to(hero) <= ENGAGE_RADIUS:
			result.append(enemy)
	return result


func _noah(field: Node3D, follower: Node3D, state: Dictionary, engaged: Array[Dictionary], delta: float) -> void:
	var hero := field.get("player") as Node3D
	var at: Vector3 = follower.global_position
	var nearest: Dictionary = _noah_target(engaged, at)
	if not nearest.is_empty():
		follower.set("combat_goal", _flank(field, hero.global_position, nearest.body.global_position, at))
	if str(state.phase).is_empty() and float(state.ward_cooldown) <= 0.0 and not engaged.is_empty() \
			and GameState.player_hp < roundi(GameState.player_max_hp * WARD_TRIGGER):
		ward_time = WARD_TIME
		state.ward_cooldown = WARD_COOLDOWN
		_begin(state, "guard", WARD_POSE_TIME)
		follower.call("set_action", 3, _side(field, hero.global_position - at))
		field.call("_effect", "ward", hero.global_position, 1.2)
		field.call("_number", hero.global_position, "守護", GUARD_COLOR, &"noah")
		_introduce(field, "guard", "諾亞・守護：暫時減少旅人受到的傷害")
		GameAudio.play_cue(&"protect")
		return
	state.time = float(state.time) - delta
	match str(state.phase):
		"":
			var target: Dictionary = _noah_target(engaged, at)
			if target.is_empty():
				return
			state.target = target
			var enemy_at: Vector3 = (target.body as Node3D).global_position
			follower.set("combat_goal", _flank(field, hero.global_position, enemy_at, at))
			follower.call("set_action", -1, &"left")
			if at.distance_to(enemy_at) <= NOAH_REACH and at.distance_to(follower.get("combat_goal")) < 0.15 and float(state.cooldown) <= 0.0:
				_begin(state, "windup", NOAH_WINDUP)
				# The ready stance doubles as the windup: it keeps the spearhead in view.
				follower.call("set_action", 0, _side(field, enemy_at - at))
		"windup":
			if float(state.time) <= 0.0:
				var target: Dictionary = state.target
				if not target.is_empty() and not Awareness.suppressed(field, target) and int(target.hp) > 0:
					var enemy_at: Vector3 = (target.body as Node3D).global_position
					if at.distance_to(enemy_at) <= NOAH_REACH + 0.4 and bool(field.call("can_hit", at, enemy_at, NOAH_REACH + 0.4)):
						var stats: Vector2i = GameState.equipment_stats(GameState.get_loadout("noah"), "noah")
						field.call("ally_hit", target, maxi(1, roundi(stats.x * NOAH_POWER)), at)
						field.call("_effect", "spear", enemy_at, 1.0, (enemy_at - at).normalized())
						GameAudio.play_cue(&"spear_thrust")
				_begin(state, "strike", NOAH_STRIKE)
				follower.call("set_action", 2, follower.get("action_side"))
		"strike":
			if float(state.time) <= 0.0:
				_begin(state, "recover", NOAH_RECOVER)
				follower.call("set_action", 0, follower.get("action_side"))
		"recover", "guard":
			if float(state.time) <= 0.0:
				state.phase = ""
				state.cooldown = NOAH_INTERVAL
				follower.call("set_action", -1, &"left")


func _sia(field: Node3D, follower: Node3D, state: Dictionary, engaged: Array[Dictionary], delta: float) -> void:
	var hero := field.get("player") as Node3D
	state.time = float(state.time) - delta
	if not engaged.is_empty():
		var threat: Vector3 = (_nearest(engaged, hero.global_position).body as Node3D).global_position
		var back: Vector3 = (hero.global_position - threat) * Vector3(1, 0, 1)
		back = back.normalized() if not back.is_zero_approx() else Vector3.BACK
		follower.set("combat_goal", _rear_goal(field, hero.global_position, back))
	else:
		follower.set("combat_goal", Vector3.INF)
	match str(state.phase):
		"":
			if not engaged.is_empty() and float(state.cooldown) <= 0.0:
				_begin(state, "windup", SIA_WINDUP)
				var focus: Vector3 = (_nearest(engaged, hero.global_position).body as Node3D).global_position
				follower.call("set_action", 1, _side(field, focus - follower.global_position))
		"windup":
			if float(state.time) <= 0.0:
				_ring(field, follower, hero)
				_begin(state, "ring", SIA_RING)
				follower.call("set_action", 2, follower.get("action_side"))
		"ring":
			if float(state.time) <= 0.0:
				_begin(state, "recover", SIA_RECOVER)
				follower.call("set_action", 3, follower.get("action_side"))
		"recover":
			if float(state.time) <= 0.0:
				state.phase = ""
				state.cooldown = SIA_INTERVAL
				follower.call("set_action", -1, &"left")


func _ring(field: Node3D, follower: Node3D, hero: Node3D) -> void:
	GameAudio.play_cue(&"hand_bell")
	field.call("_effect", "bell_wave", follower.global_position, BELL_RADIUS)
	var slowed: bool = false
	for enemy: Dictionary in field.get("enemies"):
		var enemy_at: Vector3 = (enemy.body as Node3D).global_position
		if not Awareness.suppressed(field, enemy) and int(enemy.hp) > 0 and (enemy_at - follower.global_position).slide(Vector3.UP).length() <= BELL_RADIUS:
			slowed = true
			enemy.slow = maxf(float(enemy.get("slow", 0.0)), BELL_SLOW)
	if slowed:
		field.call("_number", follower.global_position, "鐘聲：減速", BELL_COLOR, &"sia")
		_introduce(field, "slow", "希雅・鐘聲：減速附近敵人")
	if GameState.player_hp < roundi(GameState.player_max_hp * HEAL_TRIGGER):
		var amount: int = maxi(1, roundi(GameState.player_max_hp * HEAL_RATIO))
		GameState.heal_player(amount)
		field.call("_number", hero.global_position, "回復 +%d" % amount, HEAL_COLOR, &"sia")
		_introduce(field, "heal", "希雅・鐘聲：回復旅人體力")


## A camera-right offset remains horizontal on screen at every orbit angle.
func _screen_right(field: Node3D) -> Vector3:
	var camera := field.get_viewport().get_camera_3d()
	var right: Vector3 = camera.global_basis.x if camera != null else Vector3.RIGHT
	return (right * Vector3(1, 0, 1)).normalized()


func _flank(field: Node3D, hero_at: Vector3, enemy_at: Vector3, noah_at: Vector3) -> Vector3:
	var right: Vector3 = _screen_right(field)
	var offset: float = (enemy_at - hero_at).dot(right)
	var side: float = signf(offset) if absf(offset) > 0.15 else signf((noah_at - hero_at).dot(right))
	if is_zero_approx(side):
		side = -1.0
	return enemy_at + right * side * NOAH_STANDOFF


func _rear_goal(field: Node3D, hero_at: Vector3, back: Vector3) -> Vector3:
	var right: Vector3 = _screen_right(field)
	var side: float = 1.0
	for node: Node in field.get_tree().get_nodes_in_group("party_followers"):
		if not node.is_queued_for_deletion() and str(node.get("resident_id")) == "noah":
			var goal: Vector3 = node.get("combat_goal")
			if goal.is_finite():
				side = -signf((goal - hero_at).dot(right))
	var rear: Vector3 = back * SIA_BACKOFF
	return hero_at + rear - right * rear.dot(right) + right * side * 1.8


func _begin(state: Dictionary, phase: String, time: float) -> void:
	state.phase = phase
	state.time = time


## Rescue events mark the beast threatening the civilian with ally_focus.
func _noah_target(enemies: Array[Dictionary], from: Vector3) -> Dictionary:
	var living: Array[Dictionary] = []
	var priority: Array[Dictionary] = []
	for enemy: Dictionary in enemies:
		if int(enemy.hp) <= 0:
			continue
		living.append(enemy)
		if bool(enemy.get("ally_focus", false)):
			priority.append(enemy)
	return _nearest(priority if not priority.is_empty() else living, from)


func _nearest(enemies: Array[Dictionary], from: Vector3) -> Dictionary:
	var best: Dictionary = {}
	var best_distance: float = INF
	for enemy: Dictionary in enemies:
		var distance: float = (enemy.body as Node3D).global_position.distance_to(from)
		if distance < best_distance:
			best = enemy
			best_distance = distance
	return best


func _side(field: Node3D, direction: Vector3) -> StringName:
	var camera := field.get_viewport().get_camera_3d()
	if camera == null or direction.is_zero_approx():
		return &"left"
	return &"left" if camera.global_basis.x.dot(direction) < 0.0 else &"right"
