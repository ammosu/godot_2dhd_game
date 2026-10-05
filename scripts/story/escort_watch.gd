extends Node
## Chapter 1 road rescue: the newly lit road lamps drew two beasts onto the
## road traveler. Brings them to him once the field fight is ready, and records
## the outcome in GameState.flags["ch1_escort"] ("fighting" -> "won").
## Presentation and flag only; ChapterOne decides when this node exists.

const BEASTS: Array[String] = ["road_wolf_west", "road_bat_south"]
## With one beast down he breaks for the light of the nearest road lamp.
const LAMP_REFUGE := Vector3(-1.2, 0, 6.3)
## Cornered against the supply crate; the beasts block the way from the west.
const CORNERED_AT := Vector3(6.3, 0, 3.7)
const OFFSETS: Array[Vector3] = [Vector3(-1.7, 0, 0.5), Vector3(-0.7, 0, -1.5)]
## Where the party stands once the rescue intro ends: in sight of the traveler and the beasts.
const RUN_UP_TO := Vector3(1.2, 0, 4.8)
## The beasts hold the traveler until the hero comes this close (or waits too long).
const ENGAGE_DISTANCE: float = 6.0
const ENGAGE_AFTER: float = 14.0

var world: Node3D
var _beasts: Array[Dictionary] = []
var _staged: bool = false
var _engaged: bool = false
var _waited: float = 0.0
var _fled: bool = false


func _process(delta: float) -> void:
	var field: Node3D = (world.get("_map_root") as Node3D).get_node_or_null("FieldCombat")
	if field == null:
		return
	if not _staged:
		if not bool(field.get("ready_for_combat")):
			return
		_stage(field)
		return
	if str(GameState.flags.get("ch1_escort", "")) != "fighting" or GameState.mode != GameState.Mode.EXPLORE:
		return
	var standing: int = 0
	for enemy: Dictionary in _beasts:
		if int(enemy.hp) > 0:
			standing += 1
	if not _engaged and standing > 0:
		_waited += delta
		var hero := world.get_node("Player") as Node3D
		if hero.global_position.distance_to(CORNERED_AT) <= ENGAGE_DISTANCE or _waited >= ENGAGE_AFTER:
			_engage(field)
		else:
			_hold()
		return
	if standing != int(GameState.flags.get("ch1_escort_left", -1)):
		GameState.flags["ch1_escort_left"] = standing
		GameState.state_changed.emit()
	var bat_down: bool = false
	for enemy: Dictionary in _beasts:
		bat_down = bat_down or (bool(enemy.get("rescue_target", false)) and int(enemy.hp) <= 0)
	# The escape route opens when the bat blocking it is driven off.
	if bat_down and not _fled:
		_fled = true
		_move_traveler(LAMP_REFUGE, 1.6)
		GameState.notification_requested.emit("驛路旅人逃到了路燈下！")
	if standing > 0:
		return
	GameState.flags["ch1_escort"] = "won"
	GameState.flags.erase("ch1_escort_left")
	GameState.notification_requested.emit("驛路旅人平安了")
	GameState.state_changed.emit()
	# Safe under the lamp: he waits there to thank the party.
	if not _fled:
		_move_traveler(LAMP_REFUGE, 1.6)
	set_process(false)


func _move_traveler(to: Vector3, seconds: float) -> void:
	var traveler := (world.get("_map_root") as Node3D).get_node_or_null("Road Traveler") as Node3D
	if traveler != null:
		traveler.create_tween().tween_property(traveler, "position", world.call("cutscene_ground", to) - Vector3.UP * 0.1, seconds).set_trans(Tween.TRANS_SINE)


## Until the hero closes in, the beasts stay on the traveler, facing him.
func _hold() -> void:
	for enemy: Dictionary in _beasts:
		var body := enemy.body as Node3D
		enemy.state = "patrol"
		enemy.facing = (CORNERED_AT - body.global_position).normalized()


func _engage(field: Node3D) -> void:
	_engaged = true
	var awareness: GDScript = load("res://scripts/gameplay/enemy_awareness.gd")
	for enemy: Dictionary in _beasts:
		awareness.engage(field, enemy)
	# Noah steps in on the wolf first; the hero gets the bat.
	for enemy: Dictionary in _beasts:
		if str(enemy.id) == "road_wolf_west":
			enemy["ally_focus"] = true
		else:
			enemy["rescue_target"] = true


func _stage(field: Node3D) -> void:
	_staged = true
	var traveler := (world.get("_map_root") as Node3D).get_node_or_null("Road Traveler") as Node3D
	if traveler != null:
		traveler.position = CORNERED_AT
	for enemy: Dictionary in field.get("enemies"):
		var index: int = BEASTS.find(str(enemy.id))
		if index < 0 or int(enemy.hp) <= 0:
			continue
		var body := enemy.body as Node3D
		body.global_position = world.call("cutscene_ground", CORNERED_AT + OFFSETS[index])
		enemy.home = body.global_position
		if str(enemy.id) != "road_wolf_west":
			enemy["rescue_target"] = true
		_beasts.append(enemy)
	if _beasts.is_empty():
		GameState.flags["ch1_escort"] = "won"
		GameState.state_changed.emit()
		set_process(false)
		return
	if str(GameState.flags.get("ch1_escort", "")) != "fighting":
		GameState.flags["ch1_escort"] = "fighting"
		var chapter: GDScript = load("res://scripts/story/chapter_one.gd")
		world.call("play_chapter_cutscene", chapter.Films.rescue_intro(), func() -> void:
			# The party has run up the road: close enough to talk, and to fight right after.
			var hero := world.get_node("Player") as Node3D
			hero.global_position = world.call("cutscene_ground", RUN_UP_TO)
			hero.call("face_world_position", CORNERED_AT)
			for follower: Node in world.get_tree().get_nodes_in_group("party_followers"):
				follower.call("snap_behind_leader")
			world.get_node("CameraRig").call("snap_to_target")
			chapter.play_scene(world, "escort_start", Callable())
			# Keep the cornered traveler in the dialogue shot, not just the party.
			if traveler != null:
				world.call("_begin_actor_conversation", traveler), "", "default", true)
