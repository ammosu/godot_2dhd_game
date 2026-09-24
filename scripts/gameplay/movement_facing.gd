extends RefCounted
## Preserve a diagonal when its two keys are released a few frames apart.
## Only heading is filtered; velocity always uses the current input.
const RELEASE_GRACE: float = 0.10
var _heading: Vector2 = Vector2.ZERO
var _pending: Vector2 = Vector2.ZERO
var _pending_time: float = 0.0


func update(requested: Vector2, delta: float) -> Vector2:
	if requested.is_zero_approx():
		_heading = Vector2.ZERO
		_pending = Vector2.ZERO
		_pending_time = 0.0
		return Vector2.ZERO
	var dropping_axis: bool = not is_zero_approx(_heading.x) and not is_zero_approx(_heading.y) and (
		(is_zero_approx(requested.x) and requested.y * _heading.y > 0.0)
		or (is_zero_approx(requested.y) and requested.x * _heading.x > 0.0))
	if dropping_axis:
		if not requested.is_equal_approx(_pending):
			_pending = requested
			_pending_time = 0.0
		_pending_time += delta
		if _pending_time < RELEASE_GRACE:
			return _heading
	_heading = requested
	_pending = Vector2.ZERO
	_pending_time = 0.0
	return _heading
