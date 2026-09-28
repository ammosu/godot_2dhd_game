extends RefCounted
## Screen-relative directions shared by walking and conversation billboards.
const ANIMATIONS: Array[StringName] = [&"down", &"up", &"left", &"right", &"down_left", &"down_right", &"up_left", &"up_right"]
const SECTORS: Array[int] = [3, 5, 0, 4, 2, 6, 1, 7]
const SECTOR_ANGLE: float = PI / 4.0


static func direction_index(direction: Vector2) -> int:
	return SECTORS[posmod(int(floor(direction.angle() / SECTOR_ANGLE + 0.5)), 8)]


## Keep `previous` while the direction stays within `dead_band` radians past
## its sector edge, so headings near a boundary do not flicker between views.
static func direction_index_stable(direction: Vector2, previous: int, dead_band: float) -> int:
	if previous >= 0 and dead_band > 0.0:
		var center: float = float(SECTORS.find(previous)) * SECTOR_ANGLE
		if absf(angle_difference(center, direction.angle())) <= SECTOR_ANGLE * 0.5 + dead_band:
			return previous
	return direction_index(direction)


## One 45-degree view along the shorter way from `current` toward `target`.
## A half turn prefers passing through the front-facing views.
static func step_toward(current: int, target: int) -> int:
	var from: int = SECTORS.find(current)
	var to: int = SECTORS.find(target)
	if from < 0 or to < 0 or from == to:
		return target
	var difference: int = posmod(to - from + 4, 8) - 4
	var step: int = signi(difference)
	if difference == -4:
		# Screen sector 2 is "down": turn through whichever side reaches it.
		step = 1 if posmod(2 - from, 8) <= 4 else -1
	return SECTORS[posmod(from + step, 8)]


## Screen-space unit vector at the center of an animation index's sector.
static func sector_vector(index: int) -> Vector2:
	return Vector2.from_angle(float(SECTORS.find(index)) * SECTOR_ANGLE)


static func screen_direction(world_direction: Vector3, camera: Camera3D) -> Vector2:
	if camera == null:
		return Vector2(world_direction.x, world_direction.z)
	var right := camera.global_basis.x
	var back := camera.global_basis.z
	right.y = 0.0
	back.y = 0.0
	return Vector2(world_direction.dot(right.normalized()), world_direction.dot(back.normalized()))


## Inverse of `screen_direction` on the ground plane.
static func world_direction(screen: Vector2, camera: Camera3D) -> Vector3:
	if camera == null:
		return Vector3(screen.x, 0.0, screen.y).normalized()
	var right := camera.global_basis.x
	var back := camera.global_basis.z
	right.y = 0.0
	back.y = 0.0
	return (right.normalized() * screen.x + back.normalized() * screen.y).normalized()
