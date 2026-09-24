extends SceneTree
## Runs the real player physics and field encounter, without touching player saves.
func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var state: Node = root.get_node("GameState")
	state.reset_new_game(false)
	state.flags.intro_seen = true
	var world: Node3D = load("res://scenes/main.tscn").instantiate()
	root.add_child(world)
	world.set("_test_mode", true)
	world.call("_load_map", "east_road", "from_village")
	var player: CharacterBody3D = world.get_node("Player")
	player.set_physics_process(false)
	var field: Node3D = world.get("_map_root").get_node("FieldCombat")
	while not field.ready_for_combat:
		await physics_frame
	field.set_physics_process(false)
	assert(field.automation.enabled, "Combat maps default to automatic combat")
	player.position = Vector3(-14, 0.1, 0)
	assert(field.movement_velocity(Vector3.ZERO, 1.0 / 60.0) == Vector3.ZERO, "Auto waits outside navigable hunting ground")
	assert(field.automation.enabled, "Road entrance retains the default auto setting")
	player.position = Vector3(-1, 0.1, 6)
	field.automation.set_enabled(true, field)
	field.movement_velocity(Vector3.RIGHT, 1.0 / 60.0)
	assert(not field.automation.enabled, "Manual movement takes over")
	field.automation.set_enabled(true, field)
	field.perform("attack")
	assert(not field.automation.enabled, "Manual attack takes over")
	field.windup = 0
	field.attack_cooldown = 0
	field.automation.use_skills = false
	field.automation.use_potions = false
	state.player_hp = 10
	var potion_count: int = state.inventory.get("potion", 0)
	field.automation.set_enabled(true, field)
	field.movement_velocity(Vector3.ZERO, 1.0 / 60.0)
	assert(state.player_hp == 10, "Potion use is opt-in")
	field.automation.use_potions = true
	field.movement_velocity(Vector3.ZERO, 1.0 / 60.0)
	assert(state.player_hp > 10 and state.inventory.get("potion", 0) == potion_count - 1)
	field._pause_focus()
	assert(field.movement_velocity(Vector3.ZERO, 1) == Vector3.ZERO)
	field._resume_focus()
	# A telegraphed hit triggers the ordinary dodge command and invulnerability.
	var wolf: Dictionary = field.enemies[0]
	wolf.aim = player.position
	wolf.windup = 0.2
	wolf.charged_attack = true
	field.movement_velocity(Vector3.ZERO, 1.0 / 60.0)
	assert(field.dodge_time > 0 and field.invulnerable > 0)
	wolf.windup = 0
	wolf.charged_attack = false
	field.dodge_time = 0
	field.dodge_cooldown = 0
	state.player_hp = state.player_max_hp
	var mp_before: int = state.player_mp
	# Freeze simulation while menus are open.
	state.set_mode(state.Mode.EQUIPMENT)
	var before: Vector3 = player.position
	player.call("_physics_process", 1.0 / 60.0)
	field._physics_process(1.0 / 60.0)
	assert(player.position.distance_to(before) < 0.01)
	state.set_mode(state.Mode.EXPLORE)
	# Skill opt-in invokes the same resource cost and cooldown as manual combat.
	player.position = field.enemies[0].body.position + Vector3(0.8, 0, 0)
	field.automation.use_skills = true
	field.movement_velocity(Vector3.ZERO, 1.0 / 60.0)
	assert(state.player_mp == mp_before - 5 and field.skill_cooldown > 0)
	field.automation.use_skills = false
	field.windup = 0
	field.attack_cooldown = 0
	state.player_mp = mp_before
	player.position = Vector3(-1, 0.1, 6)
	# Basic-attacks-only full encounter, including climbing and collecting every drop.
	var climbed: bool = false
	for frame: int in range(7200):
		await physics_frame
		player.call("_physics_process", 1.0 / 60.0)
		field._physics_process(1.0 / 60.0)
		climbed = climbed or player.position.y > 1.6
		if not field.automation.enabled:
			break
	assert(state.field_defeated.size() == field.SPAWNS.size(), "Auto combat must defeat every enemy including the bat")
	assert(climbed, "Auto movement must climb the ramp to the mage")
	assert(field.loot_nodes.is_empty(), "Auto combat must collect remaining loot")
	assert(not field.automation.enabled, "Stop after clearing the encounter")
	assert(state.player_mp >= mp_before, "Skills disabled must not spend MP")
	# With enemies cleared, approach a stationary terrace drop from both ramp
	# sides. Previously these routes hit the low vertical wall and never advanced.
	var drop := Node3D.new()
	field.add_child(drop)
	drop.position = Vector3(10, 1.85, 10.5)
	field.loot_nodes["navigation_probe"] = drop
	for start: Vector3 in [Vector3(-1, 0.1, 6), Vector3(-6, 0.1, 13), Vector3(9, 0.1, 7), Vector3(0, 0.1, 9), Vector3(6, 1.85, 12)]:
		player.position = start
		player.velocity = Vector3.ZERO
		field.automation.set_enabled(true, field)
		for frame: int in range(1800):
			await physics_frame
			player.call("_physics_process", 1.0 / 60.0)
			if player.position.distance_to(drop.position) < 1.0:
				break
		if player.position.distance_to(drop.position) >= 1.0:
			push_error("Auto movement stalled from %s at %s" % [start, player.position])
			quit(1)
			return
	field.loot_nodes.erase("navigation_probe")
	drop.queue_free()
	world.queue_free()
	await process_frame
	await process_frame
	print("FIELD_AUTO_BATTLE_TEST_PASS takeover potion pause dodge ramp combat loot ramp_sides")
	quit()
