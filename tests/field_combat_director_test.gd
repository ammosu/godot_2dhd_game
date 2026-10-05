extends SceneTree
## Field combat camera direction: engage push-in and "!" reactions, framing that
## tracks the fight's spread, skill punch-in, the finishing slow motion (always
## restored), dialogue priority, and a clean release after the fight.
var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error("FIELD_COMBAT_DIRECTOR_TEST_FAIL " + message)


func _run() -> void:
	var Director: GDScript = load("res://scripts/gameplay/field_combat_director.gd")
	var Awareness: GDScript = load("res://scripts/gameplay/enemy_awareness.gd")
	var Acting: GDScript = load("res://scripts/gameplay/actor_acting.gd")
	check(Director.framing_distance(0.5) == Director.FRAME_NEAR, "tight fights frame close")
	check(Director.framing_distance(20.0) == Director.FRAME_FAR, "scattered fights are capped")
	check(Director.framing_distance(3.0) < Director.framing_distance(5.0), "framing widens with spread")

	var state := root.get_node("GameState")
	state.reset_new_game(false)
	state.flags.intro_seen = true
	state.quest_state = state.QuestState.COMPLETE
	state.chapter_stage = state.Chapter.SIA_JOINED
	var world: Node3D = load("res://scenes/main.tscn").instantiate()
	root.add_child(world)
	world.set("_test_mode", true)
	world.call("_load_map", "east_road", "from_village")
	var player: CharacterBody3D = world.get_node("Player")
	player.set_physics_process(false)
	var field: Node3D = world.get("_map_root").get_node("FieldCombat")
	while not field.ready_for_combat:
		await physics_frame
	var rig: Node3D = world.get_node("CameraRig")
	var director: RefCounted = field.director
	var base_scale: float = Engine.time_scale

	# Two wolves close in on the traveler; everyone else stays out of it.
	var wolves: Array[Dictionary] = [field.enemies[0], field.enemies[1]]
	for enemy: Dictionary in field.enemies:
		if not wolves.has(enemy):
			enemy.hp = 0
			enemy.state = "dead"
	player.global_position = Vector3(-4, 0.1, 7.5)
	(wolves[0].body as Node3D).global_position = Vector3(-4, 0.1, 9.0)
	(wolves[1].body as Node3D).global_position = Vector3(-2.5, 0.1, 8.6)
	for follower: Node in get_nodes_in_group("party_followers"):
		follower.call("snap_behind_leader")
	check(not director.engaged and not rig.has_shot(Director.FRAME_SHOT), "no framing before a fight")
	for wolf: Dictionary in wolves:
		Awareness.engage(field, wolf)
	await physics_frame
	await physics_frame
	check(director.engaged, "engagement detected")
	check(rig.has_shot(Director.FRAME_SHOT) and rig.has_shot(Director.ENGAGE_SHOT), "engage requests framing and a push-in")
	check(rig.active_shot_id() == Director.ENGAGE_SHOT, "push-in leads the engagement")
	var hero_acting: Node = Acting.find(field._hero_sprite)
	check(hero_acting != null and hero_acting.current_emote() == &"exclaim", "traveler startles with !")
	for follower: Node in get_nodes_in_group("party_followers"):
		var acting: Node = Acting.find(follower.get_node("CharacterArt"))
		check(acting != null and acting.current_emote() == &"exclaim", "%s reacts to the fight" % follower.get("resident_id"))
	for frame: int in range(60):
		await physics_frame
		state.player_hp = state.player_max_hp
	check(rig.active_shot_id() == Director.FRAME_SHOT, "push-in hands over to the framing")
	check(rig.shot_weight() > 0.99, "framing owns the lens during the fight")

	# Framing follows spread: pull a wolf away and the requested distance grows.
	field.set_physics_process(false)
	for follower: Node in get_nodes_in_group("party_followers"):
		follower.set_physics_process(false)
	var fighting: Array[Dictionary] = field.allies._engaged(field)
	director._update_frame(field, rig, fighting)
	var tight: float = float(director._frame.distance_scale)
	(wolves[1].body as Node3D).global_position = player.global_position + Vector3(7.0, 0, 0)
	director._update_frame(field, rig, field.allies._engaged(field))
	var wide: float = float(director._frame.distance_scale)
	check(wide > tight, "spread fight pulls the lens back (%f > %f)" % [wide, tight])
	var focus: Vector3 = director._frame.focus
	check(Vector2(focus.x - player.global_position.x, focus.z - player.global_position.z).length() <= Director.MAX_FOCUS_OFFSET + 0.001, "traveler stays near the frame center")
	(wolves[1].body as Node3D).global_position = Vector3(-2.5, 0.1, 8.6)
	field.set_physics_process(true)
	for follower: Node in get_nodes_in_group("party_followers"):
		follower.set_physics_process(true)

	# A conversation's framing beats the fight's.
	rig._dialogue_active = true
	for frame: int in range(60):
		rig._process(1.0 / 60.0)
	check(rig.shot_weight() < 0.01, "dialogue framing suppresses combat shots")
	rig._dialogue_active = false

	# Skill punch-in.
	director.on_skill(field)
	check(rig.active_shot_id() == Director.SKILL_SHOT, "skill punches in")
	var skill_distance: float = 0.0
	for shot: Dictionary in rig._shots:
		if shot.id == Director.SKILL_SHOT:
			skill_distance = float(shot.params.distance)
	check(skill_distance > 0.0 and skill_distance < rig._framing_distance(), "skill punch is closer than the current frame")

	# Finishing the last wolf slows time briefly, then restores it exactly.
	field._damage_enemy(wolves[1], 9999)
	check(is_equal_approx(Engine.time_scale, base_scale), "a non-final kill does not slow time")
	field._damage_enemy(wolves[0], 9999)
	check(Engine.time_scale < base_scale * 0.5, "final blow slows time")
	check(Engine.physics_ticks_per_second > 60, "physics keeps pace during slow motion")
	check(rig.has_shot(Director.FINISH_SHOT), "final blow leans in")
	var waited: int = 0
	while Engine.time_scale < base_scale and waited < 600:
		await physics_frame
		waited += 1
	check(is_equal_approx(Engine.time_scale, base_scale) and Engine.physics_ticks_per_second == 60, "slow motion ends and physics ticks restore")
	check(waited < 200, "slow motion is brief (%d physics frames)" % waited)
	var noah_acting: Node
	for follower: Node in get_nodes_in_group("party_followers"):
		if str(follower.get("resident_id")) == "sia":
			check(Acting.find(follower.get_node("CharacterArt")).current_emote() == &"music", "Sia cheers a won skirmish")
		else:
			noah_acting = Acting.find(follower.get_node("CharacterArt"))
	check(noah_acting != null, "Noah has acting")

	# After the calm delay the framing lets go and the rig rests at exploration.
	for frame: int in range(60 * 3):
		await physics_frame
	check(not director.engaged and not rig.has_shot(Director.FRAME_SHOT), "framing released after the fight")
	check(rig.shot_weight() < 0.01, "lens back to exploration")

	# Leaving mid slow-motion never strands the game in slow time.
	var Dilation: GDScript = load("res://scripts/systems/time_dilation.gd")
	Dilation.request(Director.FINISH_SLOW, 0.3)
	director._slow_left = 1.0
	world.queue_free()
	await process_frame
	await process_frame
	check(is_equal_approx(Engine.time_scale, base_scale) and Engine.physics_ticks_per_second == 60, "map exit restores time")
	if failures == 0:
		print("FIELD_COMBAT_DIRECTOR_TEST_PASS engage frame spread dialogue skill finish restore release exit")
	quit(0 if failures == 0 else 1)
