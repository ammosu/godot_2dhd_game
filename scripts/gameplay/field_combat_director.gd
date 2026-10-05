extends RefCounted
## Camera direction for field fights. Presentation only: it reads the fight and
## asks the camera rig for shots; it never changes combat rules.
##
## - Framing: while a fight is engaged the lens centers between the traveler, the
##   enemies on them and the companions, and pulls in or out with their spread.
##   It scales the field's default distance, so the player's own zoom still counts.
## - Engage: a short push-in and a startled "!" when a fight begins.
## - Skill: a quick punch-in on the traveler's skill.
## - Finish: the blow that ends a fight slows time briefly and leans in on it.

const Acting = preload("res://scripts/gameplay/actor_acting.gd")
const TimeDilation = preload("res://scripts/systems/time_dilation.gd")

const FRAME_SHOT: StringName = &"combat_frame"
const ENGAGE_SHOT: StringName = &"combat_engage"
const SKILL_SHOT: StringName = &"combat_skill"
const COMMAND_SHOT: StringName = &"combat_command"
const FINISH_SHOT: StringName = &"combat_finish"
const FINISH_SLOW: StringName = &"combat_finish"
const FRAME_PRIORITY: int = 10
const ENGAGE_PRIORITY: int = 20
const COMMAND_PRIORITY: int = 25
const SKILL_PRIORITY: int = 30
const FINISH_PRIORITY: int = 40

const HERO_WEIGHT: float = 2.0
const ALLY_WEIGHT: float = 0.5
## The traveler never drifts further than this from the frame's center.
const MAX_FOCUS_OFFSET: float = 3.0
const FRAME_NEAR: float = 11.0
const FRAME_FAR: float = 18.0
const FRAME_BASE: float = 8.0
const FRAME_PER_METER: float = 1.6
## Seconds without an engaged enemy before the framing lets go.
const RELEASE_DELAY: float = 1.2
const FINISH_TIME_SCALE: float = 0.3
const FINISH_SLOW_SECONDS: float = 0.42

var enabled: bool = true
var engaged: bool = false
var _calm: float = 0.0
var _frame: Dictionary = {}
## Real (unscaled) seconds of finishing slow motion left.
var _slow_left: float = 0.0
## Enemies that were part of the current fight; a fight only "finishes" on one of them.
var _fight_size: int = 0


## Every physics frame, even while combat is paused, so slow motion always ends.
func advance_real(delta: float) -> void:
	if _slow_left <= 0.0:
		return
	_slow_left -= delta / maxf(Engine.time_scale, 0.001)
	if _slow_left <= 0.0:
		TimeDilation.release(FINISH_SLOW)


func step(field: Node3D, delta: float) -> void:
	if not enabled:
		return
	var rig: Hd2dCameraRig = field.get("_rig")
	var fighting: Array[Dictionary] = (field.get("allies") as RefCounted).call("_engaged", field)
	if not fighting.is_empty():
		_calm = 0.0
		_fight_size = maxi(_fight_size, fighting.size())
		if not engaged:
			engaged = true
			_begin_fight(field, rig, fighting)
		_update_frame(field, rig, fighting)
	elif engaged:
		_calm += delta
		if _calm >= RELEASE_DELAY:
			engaged = false
			_fight_size = 0
			rig.release_shot(FRAME_SHOT)


func _begin_fight(field: Node3D, rig: Hd2dCameraRig, fighting: Array[Dictionary]) -> void:
	var hero := field.get("player") as Node3D
	var first: Vector3 = (fighting[0].body as Node3D).global_position
	_frame = {"focus": hero.global_position, "distance_scale": 1.0, "blend_in": 0.6, "blend_out": 0.8, "follow_rate": 2.5}
	rig.request_shot(FRAME_SHOT, _frame, FRAME_PRIORITY)
	# Lean toward the threat for a beat, then settle into the framing.
	rig.request_shot(ENGAGE_SHOT, {"focus": hero.global_position.lerp(first, 0.4), "distance_scale": 0.82, "relative": true, "blend_in": 0.18, "blend_out": 0.45}, ENGAGE_PRIORITY, 0.55)
	_act(field.get("_hero_sprite"), &"surprise")
	for follower: Node3D in _followers(field):
		_act(follower.get_node_or_null("CharacterArt"), &"hop", &"exclaim")


func _update_frame(field: Node3D, rig: Hd2dCameraRig, fighting: Array[Dictionary]) -> void:
	var hero: Vector3 = (field.get("player") as Node3D).global_position
	var points: Array[Vector3] = [hero]
	var total: Vector3 = hero * HERO_WEIGHT
	var weight: float = HERO_WEIGHT
	for enemy: Dictionary in fighting:
		var at: Vector3 = (enemy.body as Node3D).global_position
		points.append(at)
		total += at
		weight += 1.0
	for follower: Node3D in _followers(field):
		if (follower.get("combat_goal") as Vector3).is_finite():
			points.append(follower.global_position)
			total += follower.global_position * ALLY_WEIGHT
			weight += ALLY_WEIGHT
	var focus: Vector3 = total / weight
	var offset: Vector3 = (focus - hero) * Vector3(1, 0, 1)
	focus = hero + offset.limit_length(MAX_FOCUS_OFFSET) + Vector3.UP * (focus.y - hero.y)
	var spread: float = 0.0
	for point: Vector3 in points:
		spread = maxf(spread, Vector2(point.x - focus.x, point.z - focus.z).length())
	var distance: float = framing_distance(spread)
	rig.update_shot(FRAME_SHOT, {"focus": focus, "distance_scale": distance / float(field.get("camera_distance"))})


## Lens distance for a fight whose members lie within `spread` meters of center.
static func framing_distance(spread: float) -> float:
	return clampf(FRAME_BASE + spread * FRAME_PER_METER, FRAME_NEAR, FRAME_FAR)


func on_skill(field: Node3D) -> void:
	if not enabled or not engaged:
		return
	var rig: Hd2dCameraRig = field.get("_rig")
	rig.request_shot(SKILL_SHOT, {"subject": field.get("player"), "distance_scale": 0.86, "relative": true, "blend_in": 0.08, "blend_out": 0.3}, SKILL_PRIORITY, 0.3)


## A companion answered a command: glance toward them without losing the fight.
func on_command(field: Node3D, follower: Node3D) -> void:
	if not enabled or not is_instance_valid(follower):
		return
	var rig: Hd2dCameraRig = field.get("_rig")
	var hero: Vector3 = (field.get("player") as Node3D).global_position
	rig.request_shot(COMMAND_SHOT, {"focus": hero.lerp(follower.global_position, 0.45), "distance_scale": 0.9, "relative": true, "blend_in": 0.15, "blend_out": 0.4}, COMMAND_PRIORITY, 0.5)


## Call after an enemy's HP reaches zero.
func on_enemy_defeated(field: Node3D, enemy: Dictionary) -> void:
	if not enabled or not engaged:
		return
	for other: Dictionary in field.get("enemies"):
		if other != enemy and int(other.hp) > 0 and str(other.state) == "chase":
			return
	var rig: Hd2dCameraRig = field.get("_rig")
	var at: Vector3 = (enemy.body as Node3D).global_position
	var hero: Vector3 = (field.get("player") as Node3D).global_position
	rig.request_shot(FINISH_SHOT, {"focus": hero.lerp(at, 0.5), "distance_scale": 0.72, "relative": true, "yaw_offset": 0.16, "blend_in": 0.12, "blend_out": 0.6}, FINISH_PRIORITY, 0.85)
	TimeDilation.request(FINISH_SLOW, FINISH_TIME_SCALE)
	_slow_left = FINISH_SLOW_SECONDS
	# Only a real skirmish earns a celebration; a lone bat just ends.
	if _fight_size >= 2:
		for follower: Node3D in _followers(field):
			var id: String = str(follower.get("resident_id"))
			_act(follower.get_node_or_null("CharacterArt"), &"nod" if id == "noah" else &"laugh", &"none" if id == "noah" else &"music")


func shutdown(field: Node3D) -> void:
	TimeDilation.release(FINISH_SLOW)
	_slow_left = 0.0
	var rig: Variant = field.get("_rig")
	if is_instance_valid(rig):
		for id: StringName in [FRAME_SHOT, ENGAGE_SHOT, SKILL_SHOT, COMMAND_SHOT, FINISH_SHOT]:
			(rig as Hd2dCameraRig).release_shot(id, true)
	engaged = false


static func _followers(field: Node3D) -> Array[Node3D]:
	var result: Array[Node3D] = []
	for node: Node in field.get_tree().get_nodes_in_group("party_followers"):
		if not node.is_queued_for_deletion():
			result.append(node as Node3D)
	return result


static func _act(sprite: Variant, beat: StringName, emote: StringName = &"") -> void:
	if sprite is SpriteBase3D and is_instance_valid(sprite):
		Acting.ensure(sprite).call("act", beat, emote)
