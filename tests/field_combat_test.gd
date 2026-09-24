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
	_check_hero_art(field, player)
	assert(field.enemies.size() == 4)
	assert(field.enemies[1].max_hp > field.enemies[0].max_hp, "Elite wolf is tougher")
	assert(field.enemies[2].max_hp < field.enemies[0].max_hp, "Caster trades durability for damage")
	assert(field.enemies[2].attack_power > field.enemies[1].attack_power)
	for enemy: Dictionary in field.enemies:
		assert(enemy.hp > state.player_attack * 2, "Starting enemies survive two basic attacks")
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
	assert(wolf.state in ["return", "patrol"], "Leaving clearing ends chase, including enemies already home after losing sight")
	# Delayed melee hit; a fighter survives and completes its telegraph.
	player.position = Vector3(-4, 0.02, 9)
	var first: Dictionary = field.enemies[0]
	first.body.position = Vector3(-4, 0.02, 10)
	first.windup = 0.7
	assert(field.perform("attack"))
	assert(first.hp == 72)
	assert(not field.perform("attack"))
	field._physics_process(0.13)
	assert(first.hp == 72 - state.player_attack)
	assert(first.windup > 0, "Basic attacks cannot suppress a fighter")
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
	assert(first.hp > 0, "A fighter survives one basic attack plus one skill")
	assert(first.windup == 0, "Skills interrupt a fighter's telegraph")
	field._damage_enemy(first, 999)
	assert(first.hp == 0)
	assert(state.player_xp == 18)
	assert(state.field_defeated.has(first.id))
	assert(first.body.collision_layer == 0 and first.body.collision_mask == 0, "Defeated enemies cannot block movement")
	var death: Node3D = field._effects.back()
	assert(death.get_script() == preload("res://scripts/gameplay/enemy_death_effect.gd"))
	state.set_mode(state.Mode.EQUIPMENT)
	var death_age: float = death.age
	field._physics_process(0.4)
	assert(death.age == death_age, "Death particles pause with combat")
	state.set_mode(state.Mode.EXPLORE)
	death.advance(0.6)
	assert(not first.body.visible, "Corpse disappears after the short fade")
	player.position += Vector3(2, 0, 0)
	death.advance(0.45)
	var point: Vector3 = death._orbs[0].global_position
	death.advance(0.1)
	assert(death._orbs[0].global_position.distance_to(player.global_position + Vector3.UP * 0.85) < point.distance_to(player.global_position + Vector3.UP * 0.85), "Light homes toward the moving hero")
	death.advance(1.0)
	assert(death.is_queued_for_deletion(), "Absorbed light cleans itself up")
	field._effects.erase(death)
	assert(state.player_xp == 18, "Cosmetic absorption cannot award XP twice")
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
	assert(field.enemies.size() == 2)
	assert(state.player_level == 2 and state.player_xp == 6)
	assert(field.loot_nodes.has("road_wolf_ramp"))
	var potions: int = state.inventory.potion
	player.position = field.loot_nodes["road_wolf_ramp"].position
	field._physics_process(0.02)
	assert(state.inventory.potion == potions + 1)
	assert(not state.collect_field_loot("road_wolf_ramp"))
	# Bat telegraph, hover, interruption, rewards and persistence use the real adapter.
	var bat: Dictionary = field.enemies[1]
	assert(bat.art == "dusk_bat" and bat.hp == 42)
	player.position = bat.body.position + Vector3(0, 0, -0.8)
	bat.cooldown = 0.0
	field._advance_enemy(bat, 0.02)
	assert(bat.windup > 0 and not bat.warning.visible, "Basic bite has a short startup without a skill warning")
	assert(bat.sprite.position.y > 0.4, "Living bat hovers above its ground anchor")
	field.invulnerable = 0.0
	var before_bite: int = state.player_hp
	field._advance_enemy(bat, 0.61)
	assert(state.player_hp == before_bite - maxi(1, roundi(11 * 0.75) - state.player_defense))
	bat.windup = 0.5
	field._damage_enemy(bat, 1)
	assert(bat.windup == 0 and not bat.warning.visible, "Hit interrupts bat windup")
	bat.windup = 0.5
	bat.warning.show()
	field._damage_enemy(bat, 1)
	assert(bat.windup > 0 and bat.warning.visible, "Stagger recovery prevents permanent interruption")
	field._damage_enemy(bat, 999)
	field._advance_enemy(bat, 0.02)
	assert(bat.sprite.position.y < 0.1, "Defeated bat rests on ground")
	assert(state.field_defeated.has("road_bat_south"))
	assert(state.field_loot["road_bat_south"].item == "potion")
	assert(not state.defeat_field_enemy(bat.id, bat.body.position, false))
	assert(state.save_game(SAVE, false))
	assert(state.load_game(SAVE, false))
	await process_frame
	field = world.get("_map_root").get_node("FieldCombat")
	while not field.ready_for_combat:
		await physics_frame
	field.set_physics_process(false)
	assert(field.enemies.size() == 1 and field.enemies[0].caster)
	assert(field.loot_nodes.has("road_bat_south"), "Bat drop survives reload")
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
	print("FIELD_COMBAT_TEST_PASS slope chase elevation timing dodge rewards save migration defeat bat")
	quit()

func _check_hero_art(field: Node3D, player: CharacterBody3D) -> void:
	var loadout: Dictionary = state.equipped.duplicate()
	var art: Sprite3D = field.get("_hero_sprite")
	for equipment: Dictionary in [{}, {"armor": "moonward_cloak"}, {"weapon": "moonsteel_saber"}, {"armor": "moonward_cloak", "weapon": "moonsteel_saber"}]:
		state.equipped = equipment
		for factor: float in [1.0, 1.45]:
			player.call("set_presentation_scale", factor)
			for direction: Vector3 in [Vector3.FORWARD, Vector3.RIGHT, Vector3.BACK, Vector3.LEFT]:
				field.facing = direction
				player.velocity = Vector3.ZERO
				field.windup = 0.0
				field.swing = 0.0
				field.dodge_time = 0.0
				field.call("_update_hero_art")
				var standing := art.texture as AtlasTexture
				var pixel_size: float = art.pixel_size
				var idle_head: float = (_head_center(standing) - standing.get_width() * 0.5 + art.offset.x) * pixel_size
				assert(is_equal_approx(float(standing.get_meta("body_height", standing.get_height())) * pixel_size, 1.45 * factor), "Field art must match exploration standing height")
				for pose: String in ["walk_a", "walk_b", "windup", "attack", "dodge_a", "dodge_b", "idle"]:
					field.clock = 0.0 if pose == "walk_a" else 0.2
					player.velocity = direction if pose.begins_with("walk") else Vector3.ZERO
					field.windup = 0.1 if pose == "windup" else 0.0
					field.swing = 0.1 if pose == "attack" else 0.0
					field.dodge_time = 0.2 if pose == "dodge_a" else 0.1 if pose == "dodge_b" else 0.0
					field.set("_locomotion_requested", pose.begins_with("walk"))
					field.call("_update_hero_art")
					assert(art.visible and not player.get_node("Sprite3D").visible, "Never swap body atlases at impact or recovery")
					assert(art.texture.get_meta("pose") == pose)
					assert((art.texture as AtlasTexture).atlas == standing.atlas)
					assert(is_equal_approx(art.pixel_size, pixel_size), "Sword reach and crouching must not rescale the body")
					assert(is_zero_approx(art.offset.y - art.texture.get_height() * 0.5), "Every field pose stays foot anchored")
					if pose.begins_with("walk") or pose == "idle":
						var head: float = (_head_center(art.texture) - art.texture.get_width() * 0.5 + art.offset.x) * art.pixel_size
						assert(absf(head - idle_head) < 0.018 * factor, "Armed walking shifts the head with the forward foot or sword")
	state.equipped = loadout
	player.call("set_presentation_scale", 1.0)
	player.velocity = Vector3.ZERO
	field.facing = Vector3.FORWARD
	field.call("_update_hero_art")


func _head_center(texture: AtlasTexture) -> float:
	# Inspect actual upper-head pixels through the live field sprite, using a
	# different sampling band from the metadata builder. No screenshot required.
	var image: Image = texture.atlas.get_image()
	if image.is_compressed():
		image.decompress()
	var region := Rect2i(texture.region)
	var total: float = 0.0
	var count: int = 0
	for y: int in range(region.position.y + int(region.size.y * 0.10), region.position.y + int(region.size.y * 0.27)):
		for x: int in range(region.position.x, region.end.x):
			if image.get_pixel(x, y).a >= 0.3:
				total += x - region.position.x
				count += 1
	assert(count > 0, "Head measurement is empty")
	return total / float(count)
