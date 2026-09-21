extends SceneTree
const EXPECTED_IDS: Array[String] = ["flo", "mira", "owen"]
const EXPECTED_NAMES: Array[String] = ["園丁・芙蘿", "織工・米菈", "藏書人・歐文"]
var failures: int = 0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _run() -> void:
	var state := root.get_node("GameState")
	state.call("reset_new_game", false)
	state.get("flags")["intro_seen"] = true
	var world := load("res://scenes/main.tscn").instantiate() as Node3D
	root.add_child(world)
	world.set("_test_mode", true)
	var player := world.get_node("Player") as Node3D
	player.set_physics_process(false)
	player.position = Vector3(18, 0.1, 16)
	await physics_frame
	var villagers: Array[Node] = get_nodes_in_group("wandering_villagers")
	check(villagers.size() == 3, "Expected three village walkers")
	var dialogue := world.get_node("DialogueUI")
	var inventory_before: Dictionary = state.get("inventory").duplicate(true)
	var flags_before: Dictionary = state.get("flags").duplicate(true)
	var texts: Dictionary = {}
	for index: int in range(villagers.size()):
		var npc := villagers[index] as Node3D
		check(npc.get("resident_id") == EXPECTED_IDS[index], "Wrong fixed street identity")
		check(npc.get("display_name") == EXPECTED_NAMES[index], "Wrong street speaker name")
		var talk_area := npc.get_node("TalkArea") as Interactable3D
		check(talk_area.prompt_text == "與" + EXPECTED_NAMES[index] + "交談", "Missing named interaction prompt")
		texts[npc.get("dialogue_text")] = true
		for attempt: int in range(2):
			player.global_position = npc.global_position + Vector3(0.75, 0, 0.4)
			await physics_frame
			await physics_frame
			check(player.call("get_nearest_interactable") == talk_area, "Street dialogue cannot be reached through player detector")
			talk_area.interact()
			check(dialogue.call("is_open"), "Street interaction did not open dialogue")
			var lines: Array = dialogue.get("_lines")
			check(lines.size() == 1 and lines[0].speaker == EXPECTED_NAMES[index] and lines[0].text == npc.get("dialogue_text"), "Wrong street dialogue content")
			var positions: Array[Vector3] = []
			for walker: Node3D in villagers:
				positions.append(walker.position)
			for tick: int in range(15):
				await physics_frame
			for walker_index: int in range(villagers.size()):
				check((villagers[walker_index] as Node3D).position.is_equal_approx(positions[walker_index]), "Dialogue must pause every walker")
			check(npc.get_node("CharacterArt").get("pose_index") == 0, "Talking villager still plays walking animation")
			# An overlapping second interaction must not replace the current speaker.
			(villagers[(index + 1) % villagers.size()].get_node("TalkArea") as Interactable3D).interact()
			check(dialogue.get("_lines")[0].speaker == EXPECTED_NAMES[index], "Locked dialogue switched speakers")
			while dialogue.call("is_open"):
				dialogue.call("advance")
			player.position = Vector3(18, 0.1, 16)
	check(texts.size() == 3, "Each walker needs distinct dialogue")
	check(state.get("inventory") == inventory_before and state.get("flags") == flags_before, "Small talk must not change persistent gameplay state")
	var starts: Array[Vector3] = []
	for npc: Node3D in villagers:
		starts.append(npc.position)
	for frame: int in range(180):
		await physics_frame
	for index: int in range(villagers.size()):
		var npc := villagers[index] as Node3D
		check(npc.position.distance_to(starts[index]) > 0.5, "Villager failed to walk")
	var first := villagers[0] as Node3D
	state.set("mode", 1)
	await physics_frame
	var stopped: Vector3 = first.position
	for frame: int in range(30):
		await physics_frame
	check(first.position.is_equal_approx(stopped), "Dialogue must freeze patrols")
	state.set("mode", 0)
	player.position = first.position + Vector3(0.7, 0, 0)
	for frame: int in range(30):
		await physics_frame
	check(Vector2(first.position.x, first.position.z).distance_to(Vector2(stopped.x, stopped.z)) < 0.05, "Villager must yield to nearby player")
	player.position = Vector3(18, 0.1, 16)
	var changed_target: bool = false
	var initial_target: int = first.get("_target")
	for frame: int in range(720):
		await physics_frame
		changed_target = changed_target or first.get("_target") != initial_target
	check(changed_target, "Patrol must reach its endpoint and turn back")
	world.call("_load_map", "ruins", "from_village")
	await process_frame
	check(get_nodes_in_group("wandering_villagers").is_empty(), "Walkers must be removed outside village")
	world.call("_load_map", "village", "default")
	await process_frame
	check(get_nodes_in_group("wandering_villagers").size() == 3, "Returning must recreate exactly three walkers")
	var returned: Array[Node] = get_nodes_in_group("wandering_villagers")
	for index: int in range(returned.size()):
		check(returned[index].get("resident_id") == EXPECTED_IDS[index], "Returning reshuffled the street identities")
		check(returned[index].get_node("TalkArea").get("prompt_text") == "與" + EXPECTED_NAMES[index] + "交談", "Returning lost dialogue interaction")
	world.queue_free()
	await process_frame
	for singleton: String in ["GameAudio", "GameMusic", "GameAmbience"]:
		root.get_node(singleton).call("stop_all")
	if failures == 0:
		print("WANDERING_VILLAGER_TEST_PASS movement pause proximity patrol maps fixed_roster dialogue repeat")
	quit(1 if failures else 0)
