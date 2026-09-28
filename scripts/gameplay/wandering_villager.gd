extends CharacterBody3D
## Ambient street patrols; routes are transient and rebuilt with the village.
const ResidentArt = preload("res://scripts/gameplay/resident_art.gd")
const Grounding = preload("res://scripts/gameplay/sprite_grounding.gd")

signal conversation_requested(villager: CharacterBody3D)

## Start and stop over a few steps instead of a single frame.
const ACCELERATION: float = 2.5 # m/s^2, about a 0.3 s ramp at stroll speed
const YIELD_DECELERATION: float = 3.8 # stop within ~0.25 s for the player
const ARRIVAL_EASE_DISTANCE: float = 0.4
const MIN_ARRIVAL_SPEED: float = 0.12
const TURN_RATE: float = 8.0 # heading smoothing, 1/s
## Intermediate route points are rounded off instead of stopped at.
const PASS_THROUGH_DISTANCE: float = 0.5
## Yield to the player with hysteresis so the stop cannot flicker.
const YIELD_STOP_DISTANCE: float = 1.6
const YIELD_RESUME_DISTANCE: float = 2.0
## Linger after a chat instead of walking off as the box closes.
const AFTER_TALK_WAIT: float = 1.5

var route: PackedVector3Array = PackedVector3Array()
var player: Node3D
var resident_id: String = "mira"
var display_name: String = "村民"
var dialogue_text: String = "今天也出來走走嗎？"
var speed: float = 0.85
var wait_time: float = 0.5
var _target: int = 1
var _direction: int = 1
var _blocked_time: float = 0.0
var _heading: Vector3 = Vector3.BACK
var _travel: Vector3 = Vector3.BACK
var _current_speed: float = 0.0
var _yielding: bool = false
var _sprite: ResidentArt


func _ready() -> void:
	add_to_group("wandering_villagers")
	collision_layer = 0 # Yield to the player without blocking narrow streets.
	collision_mask = 1
	var collider := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.25
	capsule.height = 1.0
	collider.shape = capsule
	collider.position.y = 0.5
	add_child(collider)
	_sprite = ResidentArt.new()
	_sprite.name = "CharacterArt"
	_sprite.resident_id = resident_id
	# Use the resident's default body height outdoors as well as inside homes.
	_sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	_sprite.alpha_scissor_threshold = 0.25
	add_child(_sprite)
	Grounding.add_shadow(self, 0.28, 0.025)
	var talk_area := Interactable3D.new()
	talk_area.name = "TalkArea"
	talk_area.interaction_id = "walking_" + resident_id
	talk_area.prompt_text = "與" + display_name + "交談"
	talk_area.collision_layer = 8
	talk_area.collision_mask = 0
	talk_area.monitoring = false
	talk_area.activated.connect(_request_conversation)
	var talk_shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.65
	talk_shape.shape = sphere
	talk_shape.position.y = 0.75
	talk_area.add_child(talk_shape)
	add_child(talk_area)
	var marker := Label3D.new()
	marker.name = "InteractionMarker"
	marker.text = "◆"
	marker.position.y = 1.55
	marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	marker.font_size = 32
	marker.outline_size = 8
	marker.modulate = Color("ffe08a")
	add_child(marker)


func _request_conversation(_interaction_id: String) -> void:
	if GameState.is_input_locked():
		return
	velocity = Vector3.ZERO
	_current_speed = 0.0
	wait_time = maxf(wait_time, AFTER_TALK_WAIT)
	_sprite.walking = false
	conversation_requested.emit(self)


func _physics_process(delta: float) -> void:
	velocity = Vector3.ZERO
	# Ambient life continues under cutscene cameras; dialogue, menus and battle freeze it.
	var paused: bool = GameState.mode not in [GameState.Mode.EXPLORE, GameState.Mode.CUTSCENE]
	var near_player: bool = _update_yielding()
	var desired: Vector3 = Vector3.ZERO
	var target_speed: float = 0.0
	if paused:
		_current_speed = 0.0
	elif not near_player and route.size() >= 2:
		var offset: Vector3 = route[_target] - global_position
		offset.y = 0.0
		var endpoint: bool = _is_endpoint(_target)
		if offset.length() < (0.15 if endpoint else PASS_THROUGH_DISTANCE):
			_next_stop()
			offset = route[_target] - global_position
			offset.y = 0.0
		desired = offset.normalized() if not offset.is_zero_approx() else Vector3.ZERO
		wait_time = maxf(0.0, wait_time - delta)
		if wait_time <= 0.0 and not desired.is_zero_approx():
			target_speed = speed
			if _is_endpoint(_target):
				target_speed = minf(speed, maxf(MIN_ARRIVAL_SPEED, speed * offset.length() / ARRIVAL_EASE_DISTANCE))
	if near_player:
		desired = player.global_position - global_position
		desired.y = 0.0
	if not paused:
		var rate: float = YIELD_DECELERATION if near_player else ACCELERATION
		_current_speed = move_toward(_current_speed, target_speed, rate * delta)
		if not desired.is_zero_approx():
			_turn_heading(desired.normalized(), delta)
		if near_player:
			# Coast to a stop along the path while turning to look at the player.
			velocity = _travel * _current_speed
		else:
			# Slow down while the body is still coming around a sharp corner.
			var alignment: float = maxf(0.0, _heading.dot(desired.normalized())) if not desired.is_zero_approx() else 1.0
			velocity = _heading * _current_speed * alignment
			if not velocity.is_zero_approx():
				_travel = _heading
	var planned: float = velocity.length()
	var walking: bool = planned > 0.05
	var traveled: float = 0.0
	if not paused:
		velocity.y = -2.0
		var before: Vector3 = global_position
		move_and_slide()
		traveled = Vector2(global_position.x - before.x, global_position.z - before.z).length()
		# Judge blockage against the intended stroll, not the current (ramping)
		# speed: zeroing the speed on a block would otherwise make the next
		# re-acceleration tick look like standing still and reset the timer.
		var trying: bool = target_speed > 0.0 and not near_player
		if trying and traveled < maxf(planned, MIN_ARRIVAL_SPEED) * delta * 0.1:
			_blocked_time += delta
			walking = false
			_current_speed = 0.0
			if _blocked_time > 1.0:
				_next_stop()
		elif not trying or traveled >= MIN_ARRIVAL_SPEED * delta * 0.5:
			_blocked_time = 0.0
	_sprite.world_heading = _heading
	_sprite.walking = walking
	_sprite.ground_speed = traveled / delta if delta > 0.0 else 0.0


func _update_yielding() -> bool:
	if not is_instance_valid(player):
		_yielding = false
		return false
	var gap := Vector2(player.global_position.x - global_position.x, player.global_position.z - global_position.z).length()
	if _yielding:
		_yielding = gap <= YIELD_RESUME_DISTANCE
	else:
		_yielding = gap < YIELD_STOP_DISTANCE
	return _yielding


func _turn_heading(desired: Vector3, delta: float) -> void:
	var from: float = atan2(_heading.x, _heading.z)
	var angle: float = lerp_angle(from, atan2(desired.x, desired.z), 1.0 - exp(-TURN_RATE * delta))
	_heading = Vector3(sin(angle), 0.0, cos(angle))


func _is_endpoint(index: int) -> bool:
	return index == 0 or index == route.size() - 1


func _next_stop() -> void:
	# Ping-pong along the route; only its ends are resting places.
	var resting: bool = _is_endpoint(_target)
	if _target + _direction < 0 or _target + _direction >= route.size():
		_direction = -_direction
	_target += _direction
	if resting:
		wait_time = randf_range(1.0, 2.8)
	_blocked_time = 0.0
