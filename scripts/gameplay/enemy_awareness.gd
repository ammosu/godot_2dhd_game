extends RefCounted
## Local perception and one-hop assistance for field encounters.
const SIGHT_RANGE: float = 5.8
const CLOSE_RANGE: float = 1.6
const VIEW_DOT: float = 0.5 # 120-degree forward cone.
const HELP_RANGE: float = 4.0
const MEMORY_TIME: float = 4.0
const LEASH_RANGE: float = 9.0

static func clear_sight(field: Node3D, from: Vector3, to: Vector3) -> bool:
	var ray := PhysicsRayQueryParameters3D.create(from + Vector3.UP * 0.7, to + Vector3.UP * 0.7, 1, [field.player.get_rid()])
	return field.get_world_3d().direct_space_state.intersect_ray(ray).is_empty()

static func in_territory(field: Node3D, enemy: Dictionary) -> bool:
	return field.navigation.contains(field.player.global_position) and field.player.global_position.distance_to(enemy.home) < LEASH_RANGE

static func detects(field: Node3D, enemy: Dictionary) -> bool:
	var offset: Vector3 = field.player.global_position - enemy.body.global_position
	if offset.length() > SIGHT_RANGE:
		return false
	var direction: Vector3 = (offset * Vector3(1, 0, 1)).normalized()
	var facing: Vector3 = (Vector3(enemy.facing) * Vector3(1, 0, 1)).normalized()
	return (offset.length() <= CLOSE_RANGE or facing.dot(direction) >= VIEW_DOT) and clear_sight(field, enemy.body.global_position, field.player.global_position)

static func engage(field: Node3D, enemy: Dictionary) -> void:
	if int(enemy.hp) <= 0 or enemy.state == "chase" or not in_territory(field, enemy):
		return
	_begin_chase(field, enemy)
	# Helpers do not broadcast again: a nearby pack can react, not the whole map.
	for ally: Dictionary in field.enemies:
		if ally == enemy or int(ally.hp) <= 0 or ally.state != "patrol" or not in_territory(field, ally):
			continue
		var origin: Vector3 = enemy.body.global_position
		var target: Vector3 = ally.body.global_position
		if origin.distance_to(target) <= HELP_RANGE and clear_sight(field, origin, target) and not field.navigation.path(target, origin).is_empty():
			_begin_chase(field, ally)

static func _begin_chase(field: Node3D, enemy: Dictionary) -> void:
	enemy.state = "chase"
	enemy.last_seen = field.player.global_position
	enemy.lost_sight = 0.0
	enemy.repath = 0.0

static func update(field: Node3D, enemy: Dictionary, delta: float) -> void:
	if enemy.state == "patrol" and in_territory(field, enemy) and detects(field, enemy):
		engage(field, enemy)
	if enemy.state != "chase":
		return
	var at: Vector3 = enemy.body.global_position
	# Once alerted, turning around does not instantly erase the target.
	enemy.target_visible = at.distance_to(field.player.global_position) <= LEASH_RANGE and clear_sight(field, at, field.player.global_position)
	if enemy.target_visible:
		enemy.last_seen = field.player.global_position
		enemy.lost_sight = 0.0
	else:
		enemy.lost_sight = float(enemy.lost_sight) + delta
	if not in_territory(field, enemy) or at.distance_to(enemy.home) > 10.0 or float(enemy.lost_sight) >= MEMORY_TIME:
		enemy.state = "return"
		enemy.windup = 0.0
		enemy.warning.hide()
		enemy.repath = 0.0
