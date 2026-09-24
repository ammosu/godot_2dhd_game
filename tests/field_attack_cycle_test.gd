extends SceneTree
## Exercise real enemy timing and damage; never writes a save.

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
	var patterns: Array[int] = [2, 1, 2, 3]
	for enemy_index: int in range(field.enemies.size()):
		var enemy: Dictionary = field.enemies[enemy_index]
		var basics: int = patterns[enemy_index]
		var length: int = basics + 1
		for index: int in range(length * 2):
			enemy.body.position = enemy.home
			player.position = enemy.home + Vector3(0, 0, -0.8)
			enemy.cooldown = 0.0
			field.invulnerable = 0.0
			state.player_hp = state.player_max_hp
			field._advance_enemy(enemy, 0.01)
			var charged: bool = index % length == basics
			assert(enemy.charged_attack == charged)
			assert(enemy.warning.visible == charged, "Only the finisher has a skill warning")
			assert(float(enemy.cooldown) > float(enemy.attack_interval) if charged else float(enemy.cooldown) < float(enemy.attack_interval), "Finisher leaves a longer recovery gap")
			var startup: float = enemy.windup
			assert(startup >= 0.45 if charged else startup <= 0.22)
			field._advance_enemy(enemy, startup * 0.5)
			assert(state.player_hp == state.player_max_hp, "Attack cannot hit before release")
			assert(enemy.attack_cycle == index % length, "Startup must not advance the cycle")
			field._advance_enemy(enemy, startup * 0.5 + 0.001)
			var power: int = int(enemy.attack_power) if charged else roundi(float(enemy.attack_power) * 0.75)
			assert(state.player_hp == state.player_max_hp - maxi(1, power - state.player_defense))
			assert(enemy.attack_cycle == (index + 1) % length)
			assert(not enemy.warning.visible)
		# A dodged attack still counts, and a cancelled skill restarts the combo.
		enemy.cooldown = 0.0
		field._advance_enemy(enemy, 0.01)
		field.invulnerable = 1.0
		var hp: int = state.player_hp
		field._advance_enemy(enemy, 0.23)
		assert(state.player_hp == hp and enemy.attack_cycle == 1)
		enemy.attack_cycle = basics
		enemy.cooldown = 0.0
		field._advance_enemy(enemy, 0.01)
		field.skill_pending = true
		field._damage_enemy(enemy, 1)
		assert(enemy.windup == 0.0 and enemy.attack_cycle == 0 and not enemy.warning.visible)
		field.skill_pending = false
		# Returning home clears a partially completed combo.
		enemy.attack_cycle = basics
		enemy.body.position = enemy.home
		player.position = Vector3(-14, 0.1, 0)
		field._advance_enemy(enemy, 0.3)
		assert(enemy.state == "patrol" and enemy.attack_cycle == 0)
	print("FIELD_ATTACK_CYCLE_TEST_PASS four_enemies species_patterns damage timing dodge interruption reset")
	quit()
