extends SceneTree
## Integration coverage: physical slope, AI path, combat timing, rewards and v3 migration.
const SAVE := "user://field_combat_test.json"
var state: Node
var world: Node3D

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	state = root.get_node("GameState")
	state.reset_new_game(false)
	state.flags.intro_seen = true
	world = load("res://scenes/main.tscn").instantiate()
	root.add_child(world)
	world.set("_test_mode", true)
	world.call("_load_map", "east_road", "from_village")
	var player: CharacterBody3D = world.get_node("Player")
	player.set_physics_process(false)
	var field: Node3D = world.get("_map_root").get_node("FieldCombat")
	while not field.ready_for_combat:
		await physics_frame
	field.set_physics_process(false)
	assert(field.enemies.size() == 3)
	assert(field.navigation.graph.get_point_count() > 200)
	# The path from below the south cliff must go round to the west ramp.
	var path: PackedVector3Array = field.navigation.path(Vector3(9, 0, 7), Vector3(9, 1.8, 10))
	assert(path.size() > 10)
	var uses_ramp: bool = false
	for point: Vector3 in path:
		if point.x < 5.5 and point.y > 0.1:
			uses_ramp = true
	assert(uses_ramp, "The cliff path must use the ramp")
	assert(not field.can_hit(Vector3(8, 0, 7.7), Vector3(8, 1.8, 8.3), 3.0), "No attacks across elevation")
	# A real player capsule climbs and descends the incline without teleport steps.
	player.position = Vector3(0.4, 0.08, 10.5)
	for frame: int in range(140):
		await physics_frame
		player.velocity = Vector3(3.6, -1.5, 0)
		player.move_and_slide()
	assert(player.position.x > 6.5 and player.position.y > 1.7, "Player must climb terrace")
	for frame: int in range(140):
		await physics_frame
		player.velocity = Vector3(-3.6, -2, 0)
		player.move_and_slide()
	assert(player.position.x < 1.0 and player.position.y < 0.2, "Player must descend terrace")
	# Dodge uses an immediate burst, not walking acceleration, and keeps physics sweeps.
	player.position = Vector3(-7, 0.03, 8)
	field.facing = Vector3.RIGHT
	assert(field.perform("dodge"))
	for frame: int in range(13):
		await physics_frame
		player.call("_physics_process", 1.0 / 60.0)
		field.dodge_time = maxf(0, field.dodge_time - 1.0 / 60.0)
	assert(player.position.x > -5.2, "Dodge must visibly cover ground")
	field.dodge_time = 0
	field.dodge_cooldown = 0
	# Actual AI body follows the sampled slope while chasing an elevated player.
	var wolf: Dictionary = field.enemies[1]
	player.position = Vector3(3, 0.72, 10.5)
	field._advance_enemy(wolf, 1.0 / 60.0)
	assert(wolf.state == "chase")
	player.position = Vector3(8, 1.8, 10.5)
	for frame: int in range(250):
		await physics_frame
		field._advance_enemy(wolf, 1.0 / 60.0)
	assert(wolf.body.position.y > 1.6, "Wolf must reach upper level via ramp")
	player.position = Vector3(1, 0.03, 10.5)
	for frame: int in range(230):
		await physics_frame
		field._advance_enemy(wolf, 1.0 / 60.0)
	assert(wolf.body.position.y < 0.9, "Wolf must follow down ramp")
	player.position = Vector3(-12, 0.1, 5)
	field._advance_enemy(wolf, 1.0 / 60.0)
	assert(wolf.state == "return", "Leaving clearing ends chase")
	# Delayed melee hit, cooldown and interruption of an enemy's telegraph.
	player.position = Vector3(-4, 0.02, 9)
	var first: Dictionary = field.enemies[0]
	first.body.position = Vector3(-4, 0.02, 10)
	first.windup = 0.7
	assert(field.perform("attack"))
	assert(first.hp == 38)
	assert(not field.perform("attack"))
	field._physics_process(0.13)
	assert(first.hp == 38 - state.player_attack)
	assert(first.windup == 0)
	# Dodge avoids the locked target strike and pauses respect GameState mode.
	first.aim = player.position
	field.windup = 0.0
	assert(field.perform("dodge"))
	var hp: int = state.player_hp
	field._enemy_strike(first)
	assert(state.player_hp == hp)
	state.set_mode(state.Mode.EQUIPMENT)
	var timer: float = field.dodge_time
	field._physics_process(0.1)
	assert(field.dodge_time == timer)
	assert(not field.perform("skill"))
	state.set_mode(state.Mode.EXPLORE)
	field.dodge_time = 0
	field.attack_cooldown = 0
	field.skill_cooldown = 0
	var mp: int = state.player_mp
	assert(field.perform("skill"))
	assert(state.player_mp == mp - 5)
	field._physics_process(0.19)
	assert(first.hp == 0)
	assert(state.player_xp == 18)
	assert(state.field_defeated.has(first.id))
	assert(not state.defeat_field_enemy(first.id, first.body.position, false))
	# Persist the second drop uncollected and reload it in a newly built map.
	field._damage_enemy(wolf, 999)
	assert(state.player_level == 2 and state.player_xp == 6)
	assert(state.player_max_hp == 112 and state.player_attack == 20)
	assert(state.field_loot.has(wolf.id))
	state.remember_player_position(Vector3(-12, 0.1, 5))
	assert(state.save_game(SAVE, false))
	state.reset_new_game(false)
	assert(state.player_level == 1 and state.player_max_hp == 100)
	assert(state.load_game(SAVE, false))
	await process_frame
	field = world.get("_map_root").get_node("FieldCombat")
	while not field.ready_for_combat:
		await physics_frame
	field.set_physics_process(false)
	assert(field.enemies.size() == 1)
	assert(state.player_level == 2 and state.player_xp == 6)
	assert(field.loot_nodes.has("road_wolf_ramp"))
	var potions: int = state.inventory.potion
	player.position = field.loot_nodes["road_wolf_ramp"].position
	field._physics_process(0.02)
	assert(state.inventory.potion == potions + 1)
	assert(not state.collect_field_loot("road_wolf_ramp"))
	# Failure recovers in the village and removes the overworld adapter.
	var mage: Dictionary = field.enemies[0]
	player.position = mage.body.position + Vector3(0, 0, -0.5)
	mage.aim = player.position
	field.invulnerable = 0
	state.player_hp = 1
	field._enemy_strike(mage)
	await process_frame
	await process_frame
	assert(state.current_map == "village")
	assert(state.player_hp == state.player_max_hp)
	assert(player.get("field_combat") == null)
	# Deliberate v3 migration: reset progression but preserve prior quest/inventory.
	var old: Dictionary = state._serialize()
	old.version = 3
	for key: String in ["player_level", "player_xp", "field_defeated", "field_loot"]:
		old.erase(key)
	var file := FileAccess.open(SAVE, FileAccess.WRITE)
	file.store_string(JSON.stringify(old))
	file.close()
	assert(state.load_game(SAVE, false))
	assert(state.player_level == 1 and state.player_xp == 0)
	assert(state.player_max_hp == 100 and state.field_defeated.is_empty())
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	print("FIELD_COMBAT_TEST_PASS slope chase elevation timing dodge rewards save migration defeat")
	quit()
