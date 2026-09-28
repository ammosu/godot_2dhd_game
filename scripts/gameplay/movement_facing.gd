extends RefCounted
## Preserve a diagonal when its two keys are released a few frames apart.
## Only heading is filtered; velocity always uses the current input.
const RELEASE_GRACE: float = 0.10
const EightWayFacing = preload("res://scripts/gameplay/eight_way_facing.gd")
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


## Eight-way sector choice that resists flicker when an analog heading or a
## slowly orbiting camera sits on a sector boundary. The current sector is kept
## until the heading leaves it by more than `margin_degrees` from its centre
## (22.5 degrees is the plain boundary). Returns an EightWayFacing column.
static func column_with_hysteresis(direction: Vector2, current_column: int, margin_degrees: float) -> int:
	var column: int = EightWayFacing.direction_index(direction)
	var current_sector: int = EightWayFacing.SECTORS.find(current_column)
	if current_sector < 0 or column == current_column:
		return column
	var centre := Vector2.from_angle(float(current_sector) * PI / 4.0)
	if absf(centre.angle_to(direction)) <= deg_to_rad(margin_degrees):
		return current_column
	return column
