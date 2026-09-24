extends SceneTree
const Classes = preload("res://scripts/systems/hero_classes.gd")
var failures: Array[String] = []

func _init() -> void:
	run.call_deferred()

func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
		push_error(message)

func run() -> void:
	var state: Node = root.get_node("GameState")
	var path := "user://hero_class_test_%d.json" % Time.get_ticks_usec()
	for id: String in Classes.ORDER:
		state.reset_new_game(false, id)
		var profile := Classes.profile(id)
		check(state.player_max_hp == int(profile.hp) and state.player_max_mp == int(profile.mp), "Class resources: " + id)
		var defaults: Dictionary = state.ClassEquipment.defaults(id)
		check(state.equipped == defaults, "Wrong vocation starter gear: " + id)
		check(state.player_attack == int(profile.attack) + int(state.EQUIPMENT_CATALOG[defaults.weapon].attack), "Equipment + class stats: " + id)
		var choices: Array = state.equipment_for_slot("weapon")
		check(choices.size() == 2 and state.equipment_for_slot("armor").size() == 2, "Wrong compatible equipment count")
		var upgrade: String = str(choices[1])
		check(state.equip_item(upgrade), "Upgrade rejected")
		check(state.player_attack == int(profile.attack) + int(state.EQUIPMENT_CATALOG[upgrade].attack), "Equipment lost class bonus")
		for other: String in Classes.ORDER:
			if other != id:
				check(not state.equip_item(state.ClassEquipment.defaults(other).weapon), "Cross-class weapon accepted")
		state.player_level = 3
		state._refresh_equipment_stats()
		check(state.player_max_hp == int(profile.hp) + 24, "Level growth lost class")
		check(state.save_game(path, false), "Save failed")
		state.reset_new_game(false)
		check(state.load_game(path, false) and state.player_class == id, "Class roundtrip: " + id)
		var battle: RefCounted = state.begin_action_battle({"max_hp": 200})
		check(battle.actors[0].max_hp == state.player_max_hp and battle.actors[0].hero_class == id, "Battle class transfer")
		battle.actors[0].position = Vector2.ZERO
		battle.actors[0].facing = Vector2.RIGHT
		battle.actors[3].position = Vector2(4, 0)
		battle.actors[4].position = Vector2(5, 0)
		battle.actors[5].position = Vector2(5, 3)
		var hp: int = battle.actors[3].hp
		check(battle.command("attack"), "Class attack rejected")
		battle._impact(0)
		check((int(battle.actors[3].hp) < hp) == bool(profile.ranged), "Ranged reach: " + id)
		battle.actors[0].cooldown = 0.0
		battle.actors[0].windup = 0.0
		for actor: Dictionary in battle.actors:
			actor.invulnerable = 0.0
		if id == "thief":
			battle.actors[3].position = Vector2(1.5, 0)
			battle.actors[3].facing = Vector2.RIGHT
		var mp: int = battle.actors[0].mp
		check(battle.command("skill") and battle.actors[0].mp == mp - int(profile.cost), "Skill cost")
		check(is_equal_approx(battle.actors[0].skill_cd, float(profile.cooldown)), "Vocation cooldown")
		var skill_hp: int = battle.actors[3].hp
		battle._impact(0)
		if id == "mage":
			check(battle.actors[3].slow == 3.0, "Frost slow missing")
			var start: Vector2 = battle.actors[3].position
			battle._move(3, Vector2(1, 0))
			check(is_equal_approx(Vector2(battle.actors[3].position).distance_to(start), 0.5), "Slow must halve movement")
		if id == "thief":
			var expected: int = (int(battle.actors[0].attack) + int(profile.power) - int(battle.actors[3].defense)) * 2
			check(skill_hp - int(battle.actors[3].hp) == expected, "Backstab bonus")
			check(battle.actors[4].hp == battle.actors[4].max_hp, "Shadow strike must be single target")
		if bool(profile.ranged):
			check(battle.actors[4].hp < battle.actors[4].max_hp, "Ranged skill did not hit second enemy: " + id)
		check(battle.command("dodge"), "Dodge rejected")
		if id == "thief":
			check(battle.actors[0].dodge_cd < 1.0, "Thief dodge bonus missing")
		state.set_mode(state.Mode.EXPLORE)
	# v6 classes gain compatible gear rather than keeping the shared sword.
	for id: String in ["archer", "mage", "thief"]:
		state.reset_new_game(false, id)
		var old: Dictionary = state._serialize()
		old.version = 6
		old.equipped = {"weapon": "moonsteel_saber", "armor": "moonward_cloak"}
		old.owned_equipment = ["moonsteel_saber", "moonward_cloak"]
		write_save(path, old)
		check(state.load_game(path, false), "v6 migration rejected")
		check(state.equipped == state.ClassEquipment.defaults(id), "v6 did not migrate vocation equipment")
		check(state.owned_equipment.has("moonsteel_saber"), "Migration removed prior ownership")
	# Legacy migration does not inherit the currently selected class.
	var legacy: Dictionary = state._serialize()
	legacy.version = 5
	legacy.erase("player_class")
	write_save(path, legacy)
	check(state.load_game(path, false) and state.player_class == "traveler", "v5 migration")
	var malformed: Dictionary = state._serialize()
	malformed.player_class = "invalid"
	write_save(path, malformed)
	check(not state.load_game(path, false) and state.player_class == "traveler", "Invalid class changed state")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var selection: CanvasLayer = load("res://scripts/ui/class_selection.gd").new()
	root.add_child(selection)
	check(state.is_input_locked(), "Selection must lock gameplay")
	selection.select_class("mage")
	check(selection._choices.mage.button_pressed and not selection._choices.traveler.button_pressed, "Exactly one class should be selected")
	check(state.player_class == "traveler", "Preview mutated current game")
	if "--class-capture" in OS.get_cmdline_user_args():
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/wanderlight-class-selection.png")
	selection.start_journey()
	check(state.player_class == "mage" and state.player_mp == 40 and state.player_level == 1, "Selection did not start chosen class")
	await process_frame
	var art: GDScript = load("res://scripts/gameplay/class_art.gd")
	var equipment_ui: CanvasLayer = load("res://scripts/ui/equipment_ui.gd").new()
	root.add_child(equipment_ui)
	for id: String in ["archer", "mage", "thief"]:
		state.reset_new_game(false, id)
		for facing: int in range(4):
			for pose: String in art.POSES:
				var texture: AtlasTexture = art.texture_for(id, pose, facing)
				check(texture.region.has_area() and texture.region.end.x <= texture.atlas.get_width() and texture.region.end.y <= texture.atlas.get_height(), "Invalid class sprite crop")
		equipment_ui.open()
		check(equipment_ui._buttons[str(state.equipped.weapon)].visible and not equipment_ui._buttons.traveler_blade.visible, "Equipment UI shows wrong vocation")
		if "--class-capture" in OS.get_cmdline_user_args():
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("/tmp/wanderlight-class-equipment-%s.png" % id)
		equipment_ui.close()
	equipment_ui.queue_free()
	await process_frame
	state.reset_new_game(false)
	if failures.is_empty():
		print("HERO_CLASS_TEST_PASS selection stats equipment combat save migration")
	quit(0 if failures.is_empty() else 1)

func write_save(path: String, data: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()
