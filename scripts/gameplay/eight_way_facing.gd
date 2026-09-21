extends RefCounted
## Screen-relative directions shared by walking and conversation billboards.
const ANIMATIONS: Array[StringName] = [&"down", &"up", &"left", &"right", &"down_left", &"down_right", &"up_left", &"up_right"]
const SECTORS: Array[int] = [3, 5, 0, 4, 2, 6, 1, 7]


static func direction_index(direction: Vector2) -> int:
	return SECTORS[posmod(int(floor(direction.angle() / (PI / 4.0) + 0.5)), 8)]


static func screen_direction(world_direction: Vector3, camera: Camera3D) -> Vector2:
	if camera == null:
		return Vector2(world_direction.x, world_direction.z)
	var right := camera.global_basis.x
	var back := camera.global_basis.z
	right.y = 0.0
	back.y = 0.0
	return Vector2(world_direction.dot(right.normalized()), world_direction.dot(back.normalized()))
