extends RefCounted
## Pure targeting shared by a future party or network-authoritative battle.
## Positions/radius are battle-space units, never screen pixels.

const FROST_NOVA: Dictionary = {"id": "frost_nova", "name": "霜星爆", "mp_cost": 8, "power": 24, "radius": 2.0}


static func enemy_indices(combatants: Array[Dictionary], caster_team: int, center: Vector2, radius: float) -> Array[int]:
	var result: Array[int] = []
	if not center.is_finite() or not is_finite(radius) or radius < 0.0:
		return result
	for index: int in range(combatants.size()):
		var actor: Dictionary = combatants[index]
		if not actor.has("team") or int(actor.get("hp", 0)) <= 0:
			continue
		if int(actor.team) == caster_team:
			continue
		var point: Variant = actor.get("position")
		if not point is Vector2:
			continue
		var position: Vector2 = point
		if position.is_finite() and position.distance_squared_to(center) <= radius * radius:
			result.append(index)
	return result
