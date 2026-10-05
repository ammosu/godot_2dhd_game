extends RefCounted
## Keyed slow-motion requests. The slowest active request wins and multiplies
## whatever time scale was set before the first request (tests run fast-forward),
## which is restored when the last request is released.
##
## Physics ticks are raised in step with the slowdown so bodies and sprites driven
## from _physics_process still update every rendered frame instead of stuttering.

const MAX_PHYSICS_TICKS: int = 480

static var _requests: Dictionary[StringName, float] = {}
static var _base_scale: float = 1.0
static var _base_ticks: int = 60


static func request(key: StringName, scale: float) -> void:
	if _requests.is_empty():
		_base_scale = Engine.time_scale
		_base_ticks = Engine.physics_ticks_per_second
	_requests[key] = clampf(scale, 0.05, 1.0)
	_apply()


static func release(key: StringName) -> void:
	if not _requests.has(key):
		return
	_requests.erase(key)
	if _requests.is_empty():
		Engine.time_scale = _base_scale
		Engine.physics_ticks_per_second = _base_ticks
	else:
		_apply()


static func release_all() -> void:
	for key: StringName in _requests.keys():
		release(key)


static func is_active(key: StringName) -> bool:
	return _requests.has(key)


## Current slowdown factor (1.0 when nothing is slowed).
static func factor() -> float:
	var slowest: float = 1.0
	for scale: float in _requests.values():
		slowest = minf(slowest, scale)
	return slowest


static func _apply() -> void:
	var slowest: float = factor()
	Engine.time_scale = _base_scale * slowest
	Engine.physics_ticks_per_second = mini(MAX_PHYSICS_TICKS, roundi(float(_base_ticks) / slowest))
