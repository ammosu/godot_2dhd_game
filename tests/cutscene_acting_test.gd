extends SceneTree
## Films with a cast: performers are placed, turned and walked point to point,
## timed acting beats reach the traveler, companions and villagers, and everyone
## is handed back at rest when the film ends. Dialogue lines act through their
## speaker. Every authored beat and bubble name exists.
var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error("CUTSCENE_ACTING_TEST_FAIL " + message)


func _validate(beat: Dictionary, where: String, Acting: GDScript) -> void:
	var act: String = str(beat.get("act", ""))
	var emote: String = str(beat.get("emote", ""))
	check(act.is_empty() or Acting.BEATS.has(StringName(act)), "%s: unknown beat %s" % [where, act])
	check(emote.is_empty() or emote == "none" or Acting.EMOTES.has(StringName(emote)), "%s: unknown emote %s" % [where, emote])


func _validate_lines(value: Variant, where: String, Acting: GDScript) -> int:
	var count: int = 0
	if value is Dictionary:
		var entry: Dictionary = value
		if entry.has("text") and (entry.has("act") or entry.has("emote")):
			_validate(entry, where, Acting)
			count += 1
		for key: Variant in entry:
			count += _validate_lines(entry[key], "%s/%s" % [where, key], Acting)
	elif value is Array:
		for item: Variant in value:
			count += _validate_lines(item, where, Acting)
	return count


func _run() -> void:
	var Acting: GDScript = load("res://scripts/gameplay/actor_acting.gd")
	var Lines: GDScript = load("res://scripts/story/chapter_one_lines.gd")
	var Films: GDScript = load("res://scripts/story/chapter_one_cutscenes.gd")
	var Opening: GDScript = load("res://scripts/story/opening_cutscene.gd")

	# Authored data only names beats and bubbles that exist.
	var authored: int = _validate_lines(Lines.SCENES, "SCENES", Acting) + _validate_lines(Lines.PARTY_TALK, "PARTY_TALK", Acting)
	check(authored >= 50, "chapter one dialogue carries acting (%d lines)" % authored)
	var film_acts: int = 0
	var films: Array = [Opening.shots(), Films.light_east(), Films.seal_open(), Films.shard_rise(), Films.homecoming(), Films.rescue_intro(), Films.ember_flow(), Films.blue_lamp(), Films.end_card()]
	for film: Array in films:
		for shot: Dictionary in film:
			for beat: Dictionary in shot.get("acts", []):
				_validate(beat, "film", Acting)
				check(beat.has("at") and beat.has("who"), "film acts name a time and performer")
				film_acts += 1
	check(film_acts >= 12, "films carry acting beats (%d)" % film_acts)

	var state := root.get_node("GameState")
	state.reset_new_game(false)
	state.flags.intro_seen = true
	state.quest_state = state.QuestState.COMPLETE
	state.chapter_stage = state.Chapter.SIA_JOINED
	var world: Node3D = load("res://scenes/main.tscn").instantiate()
	root.add_child(world)
	world.set("_test_mode", true)
	world.call("_load_map", "village", "from_east_road")
	var player: CharacterBody3D = world.get_node("Player")
	for frame: int in range(5):
		await physics_frame
	var noah: Node3D = world.cutscene_cast("noah")
	var sia: Node3D = world.cutscene_cast("sia")
	var rumi: Node3D = world.cutscene_cast("rumi")
	check(noah != null and noah.is_in_group("party_followers"), "companions resolve as cast")
	check(rumi != null and not rumi.is_in_group("party_followers"), "villagers resolve by interaction id")
	check(world.cutscene_sprite("actor") == player.sprite, "the traveler acts through the visible sprite")
	check(world.cutscene_sprite("rumi") != null, "villagers act through their art")

	var hero_at: Vector3 = player.global_position
	var noah_mark: Vector3 = hero_at + Vector3(2.0, 0, 1.0)
	var sia_route: Array[Vector3] = [hero_at + Vector3(-1.5, 0, 1.5), hero_at + Vector3(-3.0, 0, 0.5)]
	var shots: Array[Dictionary] = [
		{
			"duration": 3.0, "fov": 40.0,
			"camera": {"from": hero_at + Vector3(0, 4, 8), "look_from": hero_at},
			"cast": {"noah": {"at": noah_mark, "face": hero_at}, "sia": {"path": sia_route}},
			"acts": [{"at": 0.2, "who": "actor", "act": "surprise"}, {"at": 0.4, "who": "noah", "act": "hop", "emote": "exclaim"},
				{"at": 0.6, "who": "rumi", "act": "joy", "emote": "heart"}],
		},
		{"duration": 0.6, "fov": 40.0, "camera": {"from": hero_at + Vector3(0, 4, 8), "look_from": hero_at}},
	]
	var done: Array[bool] = [false]
	var film: Node = world.play_chapter_cutscene(shots, func() -> void: done[0] = true, "", "default", true)
	await physics_frame
	check(noah.global_position.distance_to(world.cutscene_ground(noah_mark)) < 0.05, "cast placed on its mark")
	var to_hero: Vector3 = (hero_at - noah.global_position) * Vector3(1, 0, 1)
	check((noah.get_node("CharacterArt").get("world_heading") as Vector3).dot(to_hero.normalized()) > 0.95, "cast faces its mark")
	var hero_acting: Node = null
	var noah_acting: Node = null
	var rumi_acting: Node = null
	var sia_reached: float = INF
	var checked: bool = false
	while is_instance_valid(film) and film.shot_index == 0:
		await process_frame
		hero_acting = Acting.find(player.sprite) if hero_acting == null else hero_acting
		noah_acting = Acting.find(noah.get_node("CharacterArt")) if noah_acting == null else noah_acting
		rumi_acting = Acting.find(world.cutscene_sprite("rumi")) if rumi_acting == null else rumi_acting
		sia_reached = minf(sia_reached, sia.global_position.distance_to(world.cutscene_ground(sia_route[1])))
		if not checked and float(film.shot_time) >= 1.0:
			checked = true
			check(hero_acting != null and hero_acting.current_emote() == &"exclaim", "traveler startles on cue")
			check(noah_acting != null and noah_acting.current_emote() == &"exclaim", "Noah reacts on cue")
			check(rumi_acting != null and rumi_acting.current_emote() == &"heart", "Rumi acts on cue")
			check(float(noah.global_position.distance_to(world.cutscene_ground(noah_mark))) < 0.2, "placed cast holds its mark")
	check(checked, "film reached the acting window")
	check(sia_reached < 0.6, "cast walks its route to the last point (%f)" % sia_reached)
	while not done[0]:
		await process_frame
	check(not (noah.get("combat_goal") as Vector3).is_finite() and not (sia.get("combat_goal") as Vector3).is_finite(), "companions released to the trail")
	check(noah.global_position.distance_to(player.global_position) < 3.0, "companions rejoin the traveler")
	check(not noah_acting.is_acting() and not rumi_acting.is_acting() and not hero_acting.is_acting(), "no bubble or beat outlives the film")

	# Skipping mid-beat leaves nobody lifted.
	var rest_y: float = rumi_acting.get_parent().position.y
	var long_shot: Array[Dictionary] = [{"duration": 4.0, "fov": 40.0, "camera": {"from": hero_at + Vector3(0, 4, 8), "look_from": hero_at},
		"acts": [{"at": 0.0, "who": "rumi", "act": "joy"}]}]
	done[0] = false
	film = world.play_chapter_cutscene(long_shot, func() -> void: done[0] = true, "", "default", true)
	for frame: int in range(12):
		await process_frame
	film.skip()
	while not done[0]:
		await process_frame
	check(is_equal_approx(rumi_acting.get_parent().position.y, rest_y), "skip restores a lifted performer")

	# Dialogue lines act through their speaker.
	var ui: Node = world.dialogue_ui
	ui.show_dialogue([
		{"speaker": "旅人", "text": "等等。", "act": "surprise", "emote": "question"},
		{"speaker": "諾亞", "text": "嗯。", "act": "nod", "emote": "ellipsis"},
		{"speaker": "村童・露米", "text": "好耶！", "act": "joy", "emote": "music"},
	])
	await process_frame
	check(hero_acting.current_emote() == &"question", "the traveler's line acts")
	ui.advance()
	await process_frame
	check(noah_acting.current_emote() == &"ellipsis", "a companion's line acts")
	ui.advance()
	await process_frame
	check(rumi_acting.current_emote() == &"music", "a villager's line acts")

	world.queue_free()
	await process_frame
	if failures == 0:
		print("CUTSCENE_ACTING_TEST_PASS data cast place face walk acts release skip dialogue")
	quit(0 if failures == 0 else 1)
