extends RefCounted
## Transient field automation; uses the same physical movement and commands as manual play.
var enabled: bool = false
var use_skills: bool = true
var use_potions: bool = false
var path := PackedVector3Array()
var repath: float = 0.0

func set_enabled(value: bool, field: Node3D) -> void:
	enabled = value and field.ready_for_combat
	path.clear()
	repath = 0.0
	if enabled:
		field.player.auto_walk.cancel()

func direction(field: Node3D, delta: float) -> Vector3:
	if not enabled:
		return Vector3.ZERO
	var player: CharacterBody3D = field.player
	var at: Vector3 = player.global_position
	var graph: AStar3D = field.navigation.graph
	if graph.get_point_count() == 0 or at.distance_to(graph.get_point_position(graph.get_closest_point(at))) > 1.2:
		set_enabled(false, field)
		return Vector3.ZERO
	if use_potions and GameState.player_hp <= GameState.player_max_hp * 0.3:
		field.perform("potion", true)
	if field.has_method("has_global_cast") and field.has_global_cast():
		return field.global_escape_direction(at)
	# Time the invulnerable burst against the enemy's announced impact.
	for enemy: Dictionary in field.enemies:
		if enemy.hp <= 0 or enemy.windup <= 0 or enemy.windup > 0.24:
			continue
		if at.distance_to(enemy.aim) < float(enemy.get("radius", 1.5 if enemy.caster else 1.3)) + 0.2:
			var away: Vector3 = (at - enemy.aim) * Vector3(1, 0, 1)
			field.facing = away.normalized() if away.length() > 0.05 else Vector3.LEFT
			if field.perform("dodge", true):
				return Vector3.ZERO
	var target: Vector3 = Vector3.ZERO
	var found: bool = false
	var best: float = INF
	var target_enemy: Dictionary = {}
	for enemy: Dictionary in field.enemies:
		if enemy.hp <= 0:
			continue
		var distance: float = at.distance_squared_to(enemy.body.global_position)
		if distance < best:
			best = distance
			target = enemy.body.global_position
			target_enemy = enemy
			found = true
	if not found:
		for node: Node3D in field.loot_nodes.values():
			var distance: float = at.distance_squared_to(node.global_position)
			if distance < best:
				best = distance
				target = node.global_position
				found = true
	if not found:
		set_enabled(false, field)
		return Vector3.ZERO
	if not target_enemy.is_empty() and field.can_hit(at, target, float(GameState.class_profile().reach) - 0.35):
		field.facing = ((target - at) * Vector3(1, 0, 1)).normalized()
		if not use_skills or not field.perform("skill", true):
			field.perform("attack", true)
		path.clear()
		repath = 0.0
		return Vector3.ZERO
	repath -= delta
	if repath <= 0 or path.is_empty():
		path = field.navigation.path(at, target)
		repath = 0.25
	while not path.is_empty() and Vector2(at.x - path[0].x, at.z - path[0].z).length() < 0.22:
		path.remove_at(0)
	if path.is_empty():
		return Vector3.ZERO
	return ((path[0] - at) * Vector3(1, 0, 1)).normalized()
