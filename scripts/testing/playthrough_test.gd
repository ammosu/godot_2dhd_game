## End-to-end smoke test for `--playthrough-test`: dialogue, quest, map
## transitions, battle defeat/victory and save restoration on the real world.
extends Node

var world: PrototypeWorld


func run() -> void:
	var test_save_path := "user://wanderlight_playthrough_test_%d.json" % OS.get_process_id()
	var read_tablet := "--skip-tablet" not in OS.get_cmdline_user_args()
	GameState.reset_new_game(false)
	world._load_map("village", "default")
	if not _require(GameState.quest_state == GameState.QuestState.NOT_STARTED, "new game quest state"):
		return
	if not _require(is_instance_valid(world._moon_lamp_light) and world._moon_lamp_light.light_energy < 1.0, "moon lamp starts dim"):
		return
	if not _require(
		is_instance_valid(world._mini_map)
		and world._mini_map.get_map_id() == "village"
		and world._mini_map.has_main_target()
		and world._mini_map.has_optional_target(),
		"village minimap and quest targets"
	):
		return
	var elder_quest_marker := world._map_root.get_node_or_null("Elder/QuestMarker") as Label3D
	var rumi_quest_marker := world._map_root.get_node_or_null("Rumi/QuestMarker") as Label3D
	if not _require(
		elder_quest_marker != null
		and elder_quest_marker.text == "!"
		and elder_quest_marker.visible,
		"main quest giver marker"
	):
		return
	if not _require(
		rumi_quest_marker != null
		and rumi_quest_marker.text == "!"
		and rumi_quest_marker.visible
		and rumi_quest_marker.modulate != elder_quest_marker.modulate,
		"optional content marker color"
	):
		return

	var dialogue_camera := world.get_node("CameraRig") as Hd2dCameraRig
	var original_camera_distance: float = dialogue_camera._distance
	var original_camera_yaw: float = dialogue_camera._target_yaw
	world._handle_interaction("rumi")
	dialogue_camera._process(0.4)
	if not _require(dialogue_camera._dialogue_active and dialogue_camera._dialogue_blend > 0.0 and dialogue_camera._dialogue_blend < 1.0, "dialogue camera eases into two-person shot"):
		return
	if not _require(world.dialogue_ui.is_open() and GameState.mode == GameState.Mode.DIALOGUE, "village story dialogue"):
		return
	var village_dialogue_safety := 0
	while world.dialogue_ui.is_open() and village_dialogue_safety < 6:
		world.dialogue_ui.advance()
		village_dialogue_safety += 1
	if not _require(not dialogue_camera._dialogue_active, "dialogue completion releases cinematic camera"):
		return
	dialogue_camera._process(1.0)
	if not _require(is_zero_approx(dialogue_camera._dialogue_blend) and is_equal_approx(dialogue_camera._distance, original_camera_distance) and is_equal_approx(dialogue_camera._target_yaw, original_camera_yaw), "dialogue restores exploration zoom and angle"):
		return
	if not _require(not rumi_quest_marker.visible, "optional marker clears after dialogue"):
		return
	if not _require(not world._mini_map.has_optional_target(), "optional minimap target clears after dialogue"):
		return

	world._handle_interaction("portal_to_ruins")
	if not _require(GameState.current_map == "village" and world.dialogue_ui.is_open(), "north gate requires elder's moon seal"):
		return
	while world.dialogue_ui.is_open():
		world.dialogue_ui.advance()
	world._handle_interaction("elder")
	world._handle_interaction("rumi")
	if not _require(GameState.quest_state == GameState.QuestState.NOT_STARTED and str(world.dialogue_ui._lines[0].speaker) == "長老・艾爾", "dialogue cannot be replaced by another interaction"):
		return
	while world.dialogue_ui.is_open():
		world.dialogue_ui.advance()
	if not _require(GameState.quest_state == GameState.QuestState.ACTIVE, "quest acceptance"):
		return
	if not _require(not elder_quest_marker.visible, "main quest marker clears while objective is active"):
		return
	if not _require(world._village_gate_portal.prompt_text.is_empty(), "open portal has no interaction prompt"):
		return

	world._village_gate_portal.body_entered.emit(world.player)
	await get_tree().process_frame
	await get_tree().process_frame
	if not _require(GameState.current_map == "ruins" and world._map_root.name == "Map_Ruins", "automatic portal transition to ruins"):
		return
	if not _require(world._mini_map.get_map_id() == "ruins" and world._mini_map.has_main_target(), "ruins minimap and quest target"):
		return
	var guardian_quest_marker := world._map_root.get_node_or_null("Guardian/QuestMarker") as Label3D
	if not _require(
		guardian_quest_marker != null
		and guardian_quest_marker.text == "!"
		and guardian_quest_marker.visible,
		"main quest objective marker"
	):
		return

	if read_tablet:
		world._handle_interaction("ruin_tablet")
		while world.dialogue_ui.is_open():
			world.dialogue_ui.advance()
	if not _require(bool(GameState.flags.get("ruin_tablet_read", false)) == read_tablet, "optional ruin lore flag"):
		return
	# Full-health visitors still need the same preparation and combat tutorial.
	world._handle_interaction("moon_spring")
	if not _require(world.dialogue_ui._lines.size() == 5 and str(world.dialogue_ui._lines[2].text).contains("確認"), "full-health spring battle tutorial"):
		return
	while world.dialogue_ui.is_open():
		world.dialogue_ui.advance()

	GameState.player_hp = 22
	GameState.player_mp = 0
	world._handle_interaction("moon_spring")
	if not _require(GameState.player_hp == GameState.player_max_hp and GameState.player_mp == GameState.player_max_mp, "moon spring recovery"):
		return
	var spring_dialogue_safety := 0
	while world.dialogue_ui.is_open() and spring_dialogue_safety < 6:
		world.dialogue_ui.advance()
		spring_dialogue_safety += 1

	GameState.player_hp = 1
	world.player.global_position = Vector3(0, 0.1, -5.5)
	world._start_guardian_battle()
	world.battle_ui.confirm_preparation()
	for ally: Dictionary in GameState.battle_session.actors:
		if int(ally.team) == 0:
			ally.hp = 1
	world.battle_ui.set_physics_process(false)
	for step_index: int in range(3600):
		world.battle_ui.advance_combat(1.0 / 60.0, Vector2.ZERO)
		if world.battle_ui.is_resolved():
			break
	if not _require(world.battle_ui.is_resolved() and not world.battle_ui.did_player_win(), "battle defeat state"):
		return
	world.battle_ui._finish_battle()
	await get_tree().process_frame
	while world.dialogue_ui.is_open():
		world.dialogue_ui.advance()
	await get_tree().process_frame
	await get_tree().process_frame
	if not _require(GameState.player_hp == GameState.player_max_hp and GameState.current_map == "village", "battle defeat recovery"):
		return

	if not _require(GameState.quest_state == GameState.QuestState.ACTIVE and not GameState.flags.get("guardian_defeated", false) and not GameState.inventory.has("moon_shard"), "defeat preserves trial for retry"):
		return
	world._on_portal_body_entered(world.player, "portal_to_ruins")
	await get_tree().process_frame
	await get_tree().process_frame
	if not _require(GameState.current_map == "ruins" and world._map_root.has_node("Guardian"), "return to trial after defeat"):
		return

	# Checkpoint restoration must retain the optional route as well as the main quest.
	GameState.remember_player_position(world.player.global_position)
	if not _require(GameState.save_game(test_save_path, false), "pre-trial checkpoint write"):
		return
	GameState.flags.erase("ruin_tablet_read")
	if not _require(GameState.load_game(test_save_path, false), "pre-trial checkpoint load"):
		return
	await get_tree().process_frame
	await get_tree().process_frame
	world.player.global_position = Vector3(0, 0.1, -5.5)
	world._handle_interaction("guardian")
	if not _require(world.dialogue_ui.is_open() and str(world.dialogue_ui._lines[0].text).contains("誓言") == read_tablet, "guardian acknowledges optional lore route"):
		return
	while world.dialogue_ui.is_open():
		world.dialogue_ui.advance()
	if not _require(world.battle_ui._preparing and GameState.battle_session.paused, "battle preparation pauses combat"):
		return
	world.battle_ui.confirm_preparation()
	if not _require(world.battle_ui.is_active() and GameState.mode == GameState.Mode.BATTLE, "battle start"):
		return
	world.battle_ui.set_physics_process(false)
	for step_index: int in range(7200):
		if world.battle_ui.is_resolved():
			break
		var combat: RefCounted = GameState.battle_session
		var controlled: int = combat.controlled
		var target: int = combat.nearest_enemy(controlled)
		var direction := Vector2.ZERO
		if target >= 0:
			var difference: Vector2 = combat.actors[target].position - combat.actors[controlled].position
			direction = difference.normalized()
			combat.actors[controlled].facing = direction
			if difference.length() < 1.6:
				world.battle_ui.choose_action("skill")
				world.battle_ui.choose_action("attack")
				direction = Vector2.ZERO
		world.battle_ui.advance_combat(1.0 / 60.0, direction)
	if not _require(world.battle_ui.is_resolved() and world.battle_ui.did_player_win(), "action battle spatial victory"):
		return
	if not _require(bool(GameState.flags.get("guardian_defeated", false)), "battle victory flag"):
		return
	if not _require(GameState.quest_state == GameState.QuestState.READY_TO_TURN_IN and int(GameState.inventory.get("moon_shard", 0)) == 1, "battle quest reward"):
		return

	world.battle_ui._finish_battle()
	await get_tree().process_frame
	var dialogue_safety := 0
	while world.dialogue_ui.is_open() and dialogue_safety < 10:
		world.dialogue_ui.advance()
		dialogue_safety += 1
	if not _require(GameState.mode == GameState.Mode.EXPLORE, "dialogue returns to exploration"):
		return

	world._on_portal_body_entered(world.player, "portal_to_village")
	await get_tree().process_frame
	await get_tree().process_frame
	if not _require(GameState.current_map == "village", "automatic portal transition to village"):
		return
	if not _require(world._mini_map.get_map_id() == "village" and world._mini_map.has_main_target(), "minimap returns to village target"):
		return
	elder_quest_marker = world._map_root.get_node_or_null("Elder/QuestMarker") as Label3D
	if not _require(elder_quest_marker != null and elder_quest_marker.visible, "main quest turn-in marker"):
		return
	world._talk_to_elder()
	world.dialogue_ui.advance()
	if not _require(GameState.quest_state == GameState.QuestState.READY_TO_TURN_IN, "turn-in waits for dialogue completion"):
		return
	world.dialogue_ui.advance()
	var ending_acknowledges_tablet := false
	for line: Dictionary in world.dialogue_ui._lines:
		if str(line.text).contains("刻意抹去"):
			ending_acknowledges_tablet = true
	if not _require(ending_acknowledges_tablet == read_tablet, "ending acknowledges optional lore route"):
		return
	dialogue_safety = 0
	while world.dialogue_ui.is_open() and dialogue_safety < 12:
		world.dialogue_ui.advance()
		dialogue_safety += 1
	if not _require(GameState.quest_state == GameState.QuestState.COMPLETE and not GameState.inventory.has("moon_shard"), "quest turn-in"):
		return
	if not _require(not elder_quest_marker.visible, "main quest marker clears after completion"):
		return
	if not _require(not world._mini_map.has_main_target(), "minimap target clears after quest completion"):
		return
	if not _require(is_instance_valid(world._moon_lamp_light) and world._moon_lamp_light.light_energy > 3.0, "moon lamp restored"):
		return

	GameState.remember_player_position(Vector3(2.25, 0.1, 3.5))
	if not _require(GameState.save_game(test_save_path, false), "save write"):
		return
	GameState.quest_state = GameState.QuestState.NOT_STARTED
	GameState.player_hp = 1
	GameState.current_map = "ruins"
	if not _require(GameState.load_game(test_save_path, false), "save load"):
		return
	await get_tree().process_frame
	await get_tree().process_frame
	if not _require(
		GameState.quest_state == GameState.QuestState.COMPLETE
		and GameState.player_hp == GameState.player_max_hp
		and GameState.current_map == "village"
		and GameState.saved_position.is_equal_approx(Vector3(2.25, 0.1, 3.5))
		and bool(GameState.flags.get("ruin_tablet_read", false)) == read_tablet,
		"save data restoration"
	):
		return
	DirAccess.remove_absolute(ProjectSettings.globalize_path(test_save_path))
	print("PLAYTHROUGH_TEST_PASS dialogue quest maps save battle")
	get_tree().quit(0)


func _require(condition: bool, label: String) -> bool:
	if condition:
		print("PLAYTHROUGH_TEST_OK %s" % label)
		return true
	push_error("PLAYTHROUGH_TEST_FAIL %s" % label)
	get_tree().quit(1)
	return false
