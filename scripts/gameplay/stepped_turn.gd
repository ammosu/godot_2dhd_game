extends RefCounted
## Presentation-only body heading for eight-view billboards. A turn passes
## through the drawn three-quarter and profile views one 45-degree step at a
## time instead of snapping across the circle. The heading is stored in world
## space, so a camera orbit still re-selects the view immediately.
const Facing = preload("res://scripts/gameplay/eight_way_facing.gd")
## Seconds each intermediate view is held; a half turn takes about 0.3 s.
const STEP_SECONDS: float = 0.07
## Listener beat before an NPC starts turning toward the speaker.
const REACTION_DELAY: float = 0.1
## Degrees past a sector edge before the view changes (anti-flicker).
const DEAD_BAND: float = deg_to_rad(7.0)

var heading: Vector3 = Vector3.BACK
var index: int = -1
var _step_clock: float = STEP_SECONDS
var _delay: float = 0.0


func _init(initial_heading: Vector3 = Vector3.BACK) -> void:
	heading = _planar(initial_heading, Vector3.BACK)


## Wait a moment before the next turn begins, like a listener reacting.
func react(delay: float = REACTION_DELAY) -> void:
	_delay = maxf(_delay, delay)


func is_turning(target: Vector3, camera: Camera3D) -> bool:
	return _delay > 0.0 or _view(heading, camera) != _target_view(target, camera)


## Finish any turn instantly (cutscene entry and other synchronous paths).
func snap(target: Vector3, camera: Camera3D) -> int:
	_delay = 0.0
	_step_clock = STEP_SECONDS
	heading = _planar(target, heading)
	index = _view(heading, camera)
	return index


## Advance toward `target` and return the animation index to display.
func update(target: Vector3, camera: Camera3D, delta: float) -> int:
	var current: int = _view(heading, camera)
	var wanted: int = _target_view(target, camera)
	if _delay > 0.0:
		_delay = maxf(0.0, _delay - delta)
	elif current == wanted:
		heading = _planar(target, heading)
		_step_clock = STEP_SECONDS
	else:
		_step_clock += delta
		if _step_clock >= STEP_SECONDS:
			_step_clock = 0.0
			current = Facing.step_toward(current, wanted)
			heading = Facing.world_direction(Facing.sector_vector(current), camera) if current != wanted else _planar(target, heading)
	index = current
	return index


func _view(world_heading: Vector3, camera: Camera3D) -> int:
	var screen := Facing.screen_direction(world_heading, camera)
	if screen.is_zero_approx():
		return maxi(index, 0)
	return Facing.direction_index_stable(screen, index, DEAD_BAND)


func _target_view(target: Vector3, camera: Camera3D) -> int:
	var screen := Facing.screen_direction(target, camera)
	if screen.is_zero_approx():
		return _view(heading, camera)
	return Facing.direction_index_stable(screen, _view(heading, camera), DEAD_BAND)


static func _planar(direction: Vector3, fallback: Vector3) -> Vector3:
	var flat := Vector3(direction.x, 0.0, direction.z)
	return flat.normalized() if not flat.is_zero_approx() else fallback
