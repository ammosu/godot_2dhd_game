extends SceneTree
## Two independently traversable routes per floor, real thresholds, boss mechanics, v4 migration.
var state: Node
var world: Node3D
var player: CharacterBody3D
var save_path: String
const Layout = preload("res://scripts/gameplay/crypt_layout.gd")

func _initialize() -> void:
	_run.call_deferred()

func check(value: bool, message: String) -> bool:
	if not value:
		push_error("ASHEN_CRYPT_TEST_FAIL " + message)
		quit(1)
	return value

func field_ready() -> Node3D:
	var field: Node3D = world.get("_map_root").get_node("FieldCombat")
	for frame: int in range(180):
		if field.ready_for_combat:
			field.set_physics_process(false)
			return field
		await physics_frame
	check(false, "combat initialization timeout")
	return field

func walk(route: PackedVector3Array) -> bool:
	if not check(not route.is_empty(), "route exists"):
		return false
	for point: Vector3 in route:
		var reached: bool = false
		for frame: int in range(120):
			var offset := (point - player.position) * Vector3(1, 0, 1)
			if offset.length() < 0.16:
				reached = true
				break
			await physics_frame
			player.velocity = offset.normalized() * minf(5, offset.length() * 30) + Vector3.DOWN * 2
			player.move_and_slide()
		if not check(reached, "physical path at " + str(point)):
			return false
	return true

func cross(at: Vector3, expected: String) -> Node3D:
	player.position = at + Vector3.UP * 0.1
	await world.map_presented
	var field: Node3D = await field_ready()
	check(state.current_map == expected, "threshold arrives at " + expected)
	# Arrival must not bounce back through the destination's return threshold.
	for frame: int in range(10):
		await physics_frame
	check(state.current_map == expected, "arrival remains on destination")
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.29
	capsule.height = 0.9
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	query.transform.origin = player.position + Vector3.UP * 0.65
	query.collision_mask = 1
	query.exclude = [player.get_rid()]
	check(player.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty(), "arrival capsule clear of walls")
	return field

func _run() -> void:
	state = root.get_node("GameState")
	state.reset_new_game(false)
	state.flags.intro_seen = true
	save_path = "user://ashen_crypt_test_%d.json" % OS.get_process_id()
	world = load("res://scenes/main.tscn").instantiate()
	root.add_child(world)
	world.set("_test_mode", true)
	player = world.get_node("Player")
	player.set_physics_process(false)
	world.call("_load_map", "east_road", "from_village")
	await field_ready()
	var field: Node3D = await cross(Vector3(-8, 0, -1.8), "ashen_crypt_1")
	for floor_id: String in ["ashen_crypt_1", "ashen_crypt_2"]:
		if not check(state.current_map == floor_id and world.get("_mini_map").get_map_id() == floor_id, "floor and map"):
			return
		var graph: AStar3D = field.navigation.graph
		for side: int in [-1, 1]:
			player.position = Vector3(0, 0.1, 32.5)
			# Block the other half of the middle zone. Each side must independently connect.
			for id: int in graph.get_point_ids():
				var point := graph.get_point_position(id)
				graph.set_point_disabled(id, point.z > 18 and point.z < 31.5 and point.x * side < 2.8)
			var route: PackedVector3Array = field.navigation.path(player.position, Layout.spawn(floor_id, "from_below"))
			if not await walk(route):
				return
			for id: int in graph.get_point_ids():
				graph.set_point_disabled(id, false)
		# Branches must be genuinely reachable with the capsule too.
		for destination: Vector3 in [Vector3(-11.5, 0, 26), Vector3(11.5, 0, 26)]:
			if not await walk(field.navigation.path(player.position, destination)):
				return
		if floor_id == "ashen_crypt_1":
			state.player_hp = 1
			if not check(not state.resolve_crypt_event("crypt_spring_1").is_empty() and state.player_hp == state.player_max_hp, "spring restores once"):
				return
			state.player_hp = 2
			state.resolve_crypt_event("crypt_spring_1")
			if not check(state.player_hp == 2, "spring cannot repeat"):
				return
			state.restore_player()
		else:
			var potions: int = state.inventory.potion
			state.resolve_crypt_event("crypt_cache_2")
			state.resolve_crypt_event("crypt_cache_2")
			if not check(state.inventory.potion == potions + 2, "cache one time"):
				return
		# Save in each floor; same map, position and consumed landmarks must survive.
		state.remember_player_position(player.position)
		if not check(state.save_game(save_path, false) and state.load_game(save_path, false), "floor save/load"):
			return
		await world.map_presented
		field = await field_ready()
		if not check(state.current_map == floor_id, "save restores correct level"):
			return
		field = await cross(Vector3(0, 0, 11.8), "ashen_crypt_2" if floor_id == "ashen_crypt_1" else "ashen_crypt")
	if not check(field.enemies.size() == 1 and field.enemies[0].id == Layout.BOSS_ID, "original boss only after both floors"):
		return
	if not check(not state.claim_crypt_reward(), "boss seals reward"):
		return
	var boss: Dictionary = field.enemies[0]
	player.position = boss.body.position + Vector3(0, 0, 1)
	boss.aim = player.position
	boss.radius = 2.5
	boss.spell = false
	var hp: int = state.player_hp
	field.invulnerable = 0
	field.call("_enemy_strike", boss)
	if not check(state.player_hp < hp, "boss attack damages"):
		return
	hp = state.player_hp
	field.invulnerable = 1
	field.call("_enemy_strike", boss)
	if not check(state.player_hp == hp, "dodge invulnerability"):
		return
	field.invulnerable = 0
	boss.aim = player.position + Vector3(4, 0, 0)
	boss.spell = true
	boss.radius = 1.45
	field.call("_enemy_strike", boss)
	if not check(state.player_hp == hp, "leave telegraph avoids locked eruption"):
		return
	boss.hp = boss.max_hp / 2
	boss.windup = 0
	boss.cooldown = 0
	boss.state = "chase"
	boss.cycle = 1
	field.call("_advance_enemy", boss, 0.016)
	if not check(boss.enraged and boss.spell and boss.windup > 0 and boss.windup < 1, "half health phase and eruption telegraph"):
		return
	var telegraph: float = boss.windup
	field.call("_damage_enemy", boss, 1)
	if not check(is_equal_approx(boss.windup, telegraph), "boss cannot be stunlocked"):
		return
	# Expanding wave and staggered rain: no authored safe corridor or shield.
	for kind: String in ["ash_tide", "crystal_rain"]:
		player.position = Vector3(3, 0.05, 7)
		state.restore_player()
		field.call("_begin_cast", boss, kind)
		if not check(boss.windup >= 1.5 and field.has_global_cast(), "readable global cast"):
			return
		var countdown: float = boss.windup
		state.set_mode(state.Mode.MAP)
		field.call("_physics_process", 0.5)
		if not check(is_equal_approx(boss.windup, countdown), "menu pauses global countdown"):
			return
		state.set_mode(state.Mode.EXPLORE)
		hp = state.player_hp
		field.invulnerable = 0
		boss.windup = 0
		field.call("_enemy_strike", boss)
		if not check(state.player_hp == hp, "release does not instantly hit whole room"):
			return
		state.set_mode(state.Mode.MAP)
		field.call("_physics_process", 0.5)
		if not check(boss.spell_age == 0, "menu pauses traveling attack"):
			return
		state.set_mode(state.Mode.EXPLORE)
		if kind == "ash_tide":
			var distance: float = Vector2(player.position.x - boss.aim.x, player.position.z - boss.aim.z).length()
			field.call("_advance_enemy", boss, distance / 8.0)
			if not check(state.player_hp < hp, "swept wave hits at distant radius even on long frame"):
				return
			hp = state.player_hp
			field.invulnerable = 0
			field.call("_advance_enemy", boss, 0.01)
			if not check(state.player_hp == hp, "one wave cannot repeatedly damage player"):
				return
			field.call("_begin_cast", boss, kind)
			boss.windup = 0
			field.call("_enemy_strike", boss)
			field.call("_advance_enemy", boss, maxf(0, (distance - 1.9) / 8.0))
			field.dodge_cooldown = 0
			field.global_escape_direction(player.position)
			if not check(field.invulnerable > 0, "automation times dodge against approaching wave"):
				return
			field.call("_advance_enemy", boss, 0.25)
			if not check(state.player_hp == hp, "dodge crosses wave without damage"):
				return
		else:
			field.automation.set_enabled(true, field)
			if not check(field.automation.direction(field, 0.016).length() > 0, "automation finds a gap between landing marks"):
				return
			field.automation.set_enabled(false, field)
			field.call("_advance_enemy", boss, 0.29)
			if not check(state.player_hp == hp, "crystal has not landed yet"):
				return
			field.call("_advance_enemy", boss, 0.02)
			if not check(state.player_hp < hp and boss.rain_done[0] and not boss.rain_done[1], "crystal landing damages only released batch"):
				return
			hp = state.player_hp
			player.position = boss.rain_points[1]
			field.invulnerable = 1
			field.call("_advance_enemy", boss, 0.5)
			if not check(state.player_hp == hp and boss.rain_done[1], "dodge avoids second batch"):
				return
			player.position = Vector3(1.7, 0.05, 1)
			field.invulnerable = 0
			field.call("_advance_enemy", boss, 1.0)
			if not check(state.player_hp == hp, "unmarked gap avoids later rain"):
				return
		field.call("_advance_enemy", boss, 4.0)
		if not check(not field.has_global_cast(), "global attack expires"):
			return
	player.position = boss.body.position + Vector3(0, 0, 1)
	field.call("_begin_cast", boss, "crystal_rain")
	boss.windup = 0
	field.call("_enemy_strike", boss)
	boss.hp = 1
	field.windup = 0
	field.skill_cooldown = 0
	field.dodge_time = 0
	state.restore_player()
	field.facing = Vector3.FORWARD
	if not check(field.perform("skill"), "real player skill"):
		return
	field.call("_strike")
	if not check(not field.get("_spell_visual").visible and boss.spell_age < 0, "death cancels global telegraph and pending impact"):
		return
	if not check(state.field_defeated.has(Layout.BOSS_ID), "boss killed by actual combat"):
		return
	if not check(state.claim_crypt_reward() and not state.claim_crypt_reward(), "one time victory reward"):
		return
	state.remember_player_position(player.position)
	state.save_game(save_path, false)
	state.load_game(save_path, false)
	await world.map_presented
	field = await field_ready()
	if not check(field.enemies.is_empty(), "boss never respawns after saved victory"):
		return
	field = await cross(Vector3(0, 0, 10), "ashen_crypt_2")
	field = await cross(Layout.return_point("ashen_crypt_2"), "ashen_crypt_1")
	field = await cross(Layout.return_point("ashen_crypt_1"), "east_road")
	# Deliberate v4 migration preserves claimed rewards and old uncollected drops.
	var legacy: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	legacy.version = 4
	legacy.current_map = "ashen_crypt"
	legacy.saved_position = [0, 0.1, 32]
	legacy.field_loot["crypt_wolf_west"] = {"position": [-3, 0.05, -1], "item": "potion"}
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(legacy))
	file.close()
	state.load_game(save_path, false)
	await world.map_presented
	field = await field_ready()
	if not check(state.current_map == "ashen_crypt_1" and player.position.z > 31 and state.flags.crypt_cleared, "v4 safe spawn and reward preservation"):
		return
	if not check(state.field_loot.crypt_wolf_west.position[2] > 11, "v4 loot relocation"):
		return
	field.call("_recover")
	await world.map_presented
	await field_ready()
	if not check(state.current_map == "east_road" and not world.get_node("CameraRig").get("_dungeon"), "defeat recovery"):
		return
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	world.free()
	for singleton: String in ["GameAudio", "GameMusic", "GameAmbience"]:
		root.get_node(singleton).call("stop_all")
	print("ASHEN_CRYPT_TEST_PASS two_floors two_routes branches portals boss phases dodge reward save migration recovery")
	quit()
