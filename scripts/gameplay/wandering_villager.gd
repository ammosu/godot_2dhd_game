extends CharacterBody3D
## Ambient street patrols; routes are transient and rebuilt with the village.
const ResidentArt = preload("res://scripts/gameplay/resident_art.gd")
const Grounding = preload("res://scripts/gameplay/sprite_grounding.gd")

signal conversation_requested(villager: CharacterBody3D)

var route: PackedVector3Array = PackedVector3Array()
var player: Node3D
var resident_id: String = "mira"
var display_name: String = "村民"
var dialogue_text: String = "今天也出來走走嗎？"
var speed: float = 0.85
var wait_time: float = 0.5
var _target: int = 1
var _blocked_time: float = 0.0
var _heading: Vector3 = Vector3.BACK
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
	_sprite.visible_height = 1.3
	_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
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
	_sprite.walking = false
	conversation_requested.emit(self)


func _physics_process(delta: float) -> void:
	velocity = Vector3.ZERO
	var paused: bool = GameState.is_input_locked()
	var near_player: bool = is_instance_valid(player) and global_position.distance_to(player.global_position) < 1.35
	if not paused and not near_player and route.size() >= 2:
		wait_time = maxf(0.0, wait_time - delta)
		if wait_time <= 0.0:
			var offset: Vector3 = route[_target] - global_position
			offset.y = 0.0
			if offset.length() < 0.15:
				_next_stop()
			else:
				_heading = offset.normalized()
				velocity = _heading * minf(speed, offset.length() / delta)
	if near_player:
		_heading = player.global_position - global_position
	var walking: bool = velocity.length_squared() > 0.01
	if not paused:
		velocity.y = -2.0
		var before: Vector3 = global_position
		move_and_slide()
		var traveled: float = Vector2(global_position.x - before.x, global_position.z - before.z).length()
		if walking and traveled < speed * delta * 0.1:
			_blocked_time += delta
			walking = false
			if _blocked_time > 1.0:
				_next_stop()
		else:
			_blocked_time = 0.0
	_sprite.world_heading = _heading
	_sprite.walking = walking


func _next_stop() -> void:
	_target = (_target + 1) % route.size()
	wait_time = randf_range(1.0, 2.8)
	_blocked_time = 0.0
