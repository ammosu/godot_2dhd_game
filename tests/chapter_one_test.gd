extends SceneTree
## Chapter 1 end to end: every beat in order on the real maps, companions,
## the bell seal, key items, autosave suppression and save v10 / v9 migration.

const SAVE := "user://chapter_one_test.json"
var failures: int = 0
var world: Node3D
var state: Node


func _initialize() -> void:
	_run.call_deferred()


func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error("CHAPTER_ONE_TEST_FAIL " + message)


func _finish_dialogue() -> void:
	var dialogue: Node = world.get_node("DialogueUI")
	var guard: int = 0
	while dialogue.call("is_open") and guard < 40:
		dialogue.call("advance")
		guard += 1
	await process_frame
	var film := world.get_node_or_null("CutscenePlayer")
	if film != null:
		film.call("skip")
		await film.finished
		await process_frame
		await _finish_dialogue()


## Page every dialogue and skip every film until both are done; returns films skipped.
func _drain() -> int:
	var dialogue: Node = world.get_node("DialogueUI")
	var films: int = 0
	for step: int in range(400):
		var film: Node = world.get_node_or_null("CutscenePlayer")
		if film != null:
			film.call("skip")
			await film.finished
			await process_frame
			films += 1
		elif dialogue.call("is_open"):
			dialogue.call("advance")
			await process_frame
		else:
			break
	return films


func _go(map_id: String, spawn_id: String) -> void:
	world.call("_load_map", map_id, spawn_id)
	await process_frame


func _interact(id: String) -> void:
	world.call("_handle_interaction", id)
	await _finish_dialogue()


func _stage() -> int:
	return int(state.get("chapter_stage"))


func _followers() -> Array[String]:
	var result: Array[String] = []
	for node: Node in get_nodes_in_group("party_followers"):
		if not node.is_queued_for_deletion():
			result.append(str(node.get("resident_id")))
	return result


func _run() -> void:
	state = root.get_node("GameState")
	state.call("reset_new_game", false)
	state.get("flags")["intro_seen"] = true
	world = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(world)
	world.set("_test_mode", true)
	await process_frame
	var Chapter: Dictionary = state.get_script().get_script_constant_map().Chapter

	# Before the prologue ends nothing advances and the crypt stays sealed.
	await _go("east_road", "from_village")
	check(world.get("_map_root").get_node_or_null("CryptBellSeal") != null, "crypt sealed before chapter")
	check(world.get("_map_root").get_node_or_null("enter_crypt") == null, "no crypt threshold while sealed")
	await _interact("crypt_seal")
	check(_stage() == Chapter.NONE, "seal does not start chapter early")

	state.set("quest_state", 3)
	await _go("village", "default")
	check(str(state.call("get_quest_text")).contains("月燈"), "objective points to lamp")
	await _interact("moon_lamp")
	check(_stage() == Chapter.LIGHT_EAST and int(state.get("inventory").get("rumi_letter", 0)) == 1, "lamp beat gives letter")
	check(world.get("_quest_markers")["elder"].visible, "elder marked for confession")
	await _interact("elder")
	check(_stage() == Chapter.ELDER_CONFESSED, "elder confession")
	# Without reloading the map, Noah must already have moved to the east exit.
	check(world.get("_map_root").get_node_or_null("Noah") == null, "north gate Noah left his post")
	check(world.get("_map_root").get_node_or_null(NodePath("ch1_noah".capitalize())) != null, "Noah waits at the east exit")
	await _interact("ch1_noah")
	await process_frame
	check(_stage() == Chapter.NOAH_JOINED and _followers() == ["noah"], "Noah joins and follows")

	# Followers keep up with the traveler and stay behind him.
	var player := world.get_node("Player") as CharacterBody3D
	await _go("east_road", "from_village")
	check(_followers() == ["noah"], "Noah follows across maps")
	# Road rescue: the lamps drew two beasts onto the road traveler.
	var watch: Node = (world.get("_map_root") as Node3D).get_node_or_null("EscortWatch")
	check(watch != null, "rescue staged on first arrival")
	var guard: int = 0
	while not world.get_node("DialogueUI").call("is_open") and world.get_node_or_null("CutscenePlayer") == null and guard < 300:
		await physics_frame
		guard += 1
	var intro: Node = world.get_node_or_null("CutscenePlayer")
	check(intro != null, "rescue opens on a framing shot")
	if intro != null:
		intro.call("skip")
		await intro.finished
		await process_frame
	check(str(state.get("flags").get("ch1_escort", "")) == "fighting", "rescue begins with its scene")
	await _finish_dialogue()
	await _interact("crypt_seal")
	check(_stage() == Chapter.NOAH_JOINED, "seal waits until the traveler is safe")
	var field: Node3D = world.get("_map_root").get_node("FieldCombat")
	for enemy: Dictionary in field.get("enemies"):
		if str(enemy.id) in ["road_wolf_west", "road_bat_south"]:
			check((enemy.body as Node3D).global_position.distance_to(Vector3(5, 0, 2)) < 4.5, "beast moved to the traveler " + str(enemy.id))
			enemy.hp = 0
	for frame: int in range(5):
		await physics_frame
	check(str(state.get("flags").get("ch1_escort", "")) == "won", "rescue won")
	check(world.get("_quest_markers")["road_traveler"].visible, "traveler marked after the rescue")
	await _interact("road_traveler")
	check(str(state.get("flags").get("ch1_escort", "")) == "done", "rescue thanked")
	player.global_position = Vector3(-4, player.global_position.y, 5)
	for frame: int in range(90):
		await physics_frame
	var noah := get_nodes_in_group("party_followers")[0] as Node3D
	check(noah.global_position.distance_to(player.global_position) < 3.0, "follower catches up")
	check(world.get("_map_root").get_node_or_null("CryptBellSeal") != null, "seal still shut")
	# Companions are always within reach; story objects must still win the prompt.
	player.global_position = Vector3(-8, player.global_position.y, 0.2)
	player.call("face_world_position", Vector3(-8, 0, -3))
	for frame: int in range(60):
		await physics_frame
	check(str(player.call("get_interaction_prompt")) == "查看鐘紋封門", "seal prompt outranks companions")
	await _interact("crypt_seal")
	check(_stage() == Chapter.SEAL_FOUND, "seal found")
	check(world.get("_quest_markers").has("crypt_seal") and not world.get("_quest_markers")["crypt_seal"].visible, "seal marker idle while searching")

	await _go("starbay", "from_road")
	var sia := world.get("_map_root").get_node_or_null("Sia") as Node3D
	check(sia != null and world.get("_quest_markers")["sia"].visible, "Sia waits, marked")
	await _interact("sia")
	await process_frame
	check(_stage() == Chapter.SIA_JOINED, "Sia joins")
	check(not state.get("inventory").has("rumi_letter") and int(state.get("inventory").get("bell_mallet", 0)) == 1 and int(state.get("inventory").get("starbay_reply", 0)) == 1, "letter exchanged for mallet and reply")
	check(_followers() == ["noah", "sia"], "both companions follow")
	# Talk through the companion's own interaction area, as the player would.
	var talk_area := (get_nodes_in_group("party_followers")[0] as Node).get_node("TalkArea") as Interactable3D
	talk_area.interact()
	check(world.get_node("DialogueUI").call("is_open"), "companion talk opens from its area")
	await _finish_dialogue()
	await _go("house_city_09", "entry")
	world.call("_handle_interaction", "inspect_house_shelf")
	check((world.get_node("DialogueUI").get("_lines") as Array).size() >= 5, "library reveals old street map")
	await _finish_dialogue()
	check(_followers().is_empty(), "companions wait outside houses")

	await _go("east_road", "from_caravan")
	await _interact("crypt_seal")
	check(_stage() == Chapter.SEAL_OPEN, "bell opens the seal")
	check(world.get("_map_root").get_node_or_null("CryptBellSeal") == null and world.get("_map_root").get_node_or_null("enter_crypt") != null, "threshold replaces seal")
	check(str(state.call("get_quest_text")).contains("墓窟") or str(state.call("get_quest_text")).contains("維爾莫"), "crypt objective")

	await _go("ashen_crypt", "entry")
	await _interact("crypt_reliquary")
	check(_stage() == Chapter.SEAL_OPEN, "altar waits for the warden")
	state.get("field_defeated")["crypt_ash_warden"] = true
	await _interact("crypt_reliquary")
	check(_stage() == Chapter.EMBER_SHARD and int(state.get("inventory").get("ember_shard", 0)) == 1 and bool(state.get("flags").get("crypt_cleared", false)), "ember shard claimed")

	await _go("wind_gorge", "from_base")
	check(world.get("_map_root").get_node_or_null("Campfire") != null, "camp pitched in the gorge")
	state.set("player_hp", 1)
	await _interact("ch1_campfire")
	check(_stage() == Chapter.CAMPFIRE and int(state.get("player_hp")) == int(state.get("player_max_hp")), "campfire talk and rest")

	await _go("moon_highland", "from_base")
	world.call("_handle_interaction", "highland_view")
	# Ending order: shard film -> illustrated lantern bearer -> one chapter card -> hint home.
	var film: Node = world.get_node_or_null("CutscenePlayer")
	check(film != null, "ending opens with the shard film")
	if film != null:
		film.call("skip")
		await film.finished
		await process_frame
	var lines: Array = world.get_node("DialogueUI").get("_lines")
	var illustrated: int = 0
	for line: Dictionary in lines:
		if line.has("illustration"):
			illustrated += 1
	check(illustrated >= 5 and illustrated < lines.size(), "bearer pages illustrated, party reactions live")
	# Bearer -> blue lamp film -> the traveler's decision -> homecoming -> reply -> card.
	var films_seen: int = await _drain()
	check(films_seen >= 3, "blue lamp, homecoming and card films all play")
	check(str(state.get("current_map")) == "village", "the party comes home")
	check(_stage() == Chapter.COMPLETE, "chapter complete after the card")
	check(not state.get("inventory").has("starbay_reply"), "reply handed over in the ending")

	await _go("village", "default")
	await _interact("rumi")
	check(not state.get("inventory").has("starbay_reply"), "reply delivered to Rumi")
	check(str(state.call("get_quest_text")).contains("第一章完成"), "completion objective after the epilogue")

	# Save v10 round trip keeps the stage and party.
	check(int(state.get("SAVE_VERSION")) == 10, "save version bumped")
	check(state.call("save_game", SAVE, false), "save")
	state.call("reset_new_game", false)
	check(_stage() == Chapter.NONE, "new game resets chapter")
	check(state.call("load_game", SAVE, false), "load v10")
	await process_frame
	check(_stage() == Chapter.COMPLETE and state.call("has_companion", "sia"), "v10 restores chapter")

	# A v9 save that finished the prologue resumes at the first chapter beat.
	var file := FileAccess.open(SAVE, FileAccess.READ)
	var data: Dictionary = JSON.parse_string(file.get_as_text())
	file.close()
	data.version = 9
	data.erase("chapter_stage")
	file = FileAccess.open(SAVE, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()
	check(state.call("load_game", SAVE, false), "load v9")
	await process_frame
	check(_stage() == Chapter.NONE and int(state.get("quest_state")) == 3, "v9 migrates to chapter start")
	data.version = 10
	for bad: Variant in ["bad", 999, -1, 5.9]:
		data.chapter_stage = bad
		file = FileAccess.open(SAVE, FileAccess.WRITE)
		file.store_string(JSON.stringify(data))
		file.close()
		check(not state.call("load_game", SAVE, false), "reject malformed chapter stage %s" % str(bad))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))

	world.queue_free()
	await process_frame
	if failures == 0:
		print("CHAPTER_ONE_TEST_PASS beats companions seal items ending save_v10 migration")
	quit(0 if failures == 0 else 1)
