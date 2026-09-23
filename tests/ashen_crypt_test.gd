extends SceneTree
## Real map transitions, collision/navigation, attack resolution and isolated persistence.
var state: Node
var world: Node3D
var save_path: String

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

func _run() -> void:
	state = root.get_node("GameState")
	state.reset_new_game(false)
	state.flags.intro_seen = true
	save_path = "user://ashen_crypt_test_%d.json" % OS.get_process_id()
	world = load("res://scenes/main.tscn").instantiate()
	root.add_child(world)
	world.set("_test_mode", true)
	world.call("_load_map", "east_road", "from_village")
	var player: CharacterBody3D = world.get_node("Player")
	player.set_physics_process(false)
	await field_ready()
	if not check(world.get("_map_root").has_node("enter_crypt"), "entrance exists"):
		return
	world.call("_handle_interaction", "enter_crypt")
	await world.map_presented
	var field: Node3D = await field_ready()
	if not check(state.current_map == "ashen_crypt" and field.enemies.size() == 5, "enter crypt and spawn five guards"):
		return
	if not check(world.get("_mini_map").get_map_id() == "ashen_crypt", "crypt minimap"):
		return
	if not check(not state.claim_crypt_reward(), "sealed altar refuses early reward"):
		return
	var route: PackedVector3Array = field.navigation.path(player.position, Vector3(0, 0, -9.2))
	if not check(route.size() > 20, "entry-to-altar navigation"):
		return
	# Move the real player capsule north along the nave and verify the end wall.
	for frame: int in range(360):
		await physics_frame
		player.velocity = Vector3(0, -2, -4)
		player.move_and_slide()
	if not check(player.position.z < -9.4 and player.position.z > -10.3, "walkable nave and solid altar"):
		return
	if not check(not field.can_hit(Vector3(3.7, 0, -1), Vector3(5.5, 0, -1), 3), "pier blocks attacks"):
		return
	# Kill guards through the same timed skill strike used during play.
	for enemy: Dictionary in field.enemies:
		player.position = enemy.body.position + Vector3(0, 0, 0.85)
		field.facing = Vector3.FORWARD
		field.attack_cooldown = 0
		field.skill_cooldown = 0
		field.windup = 0
		field.dodge_time = 0
		state.player_mp = state.player_max_mp
		enemy.hp = 1
		if not check(field.perform("skill"), "skill accepted"):
			return
		field.call("_strike")
		if not check(state.field_defeated.has(enemy.id), "guard killed through combat"):
			return
	var potions: int = state.inventory.potion
	if not check(state.claim_crypt_reward() and state.inventory.potion == potions + 3, "clear reward"):
		return
	if not check(not state.claim_crypt_reward() and state.inventory.potion == potions + 3, "no duplicate reward"):
		return
	# Existing v4 dictionaries hold both maps without changing the save schema.
	state.field_loot["road_wolf_west"] = {"position": [-4, 0.05, 10], "item": "potion"}
	field.call("_sync_loot")
	if not check(not field.loot_nodes.has("road_wolf_west"), "old-road loot isolated from dungeon"):
		return
	player.position = Vector3(0, 0.1, 8)
	state.remember_player_position(player.position)
	if not check(state.save_game(save_path, false), "isolated save"):
		return
	world.call("_handle_interaction", "leave_crypt")
	await world.map_presented
	field = await field_ready()
	if not check(state.current_map == "east_road" and player.position.distance_to(Vector3(-8, 0.1, 1)) < 0.5, "return outside entrance"):
		return
	if not check(field.loot_nodes.has("road_wolf_west") and not field.loot_nodes.has("crypt_bat_entry"), "dungeon loot isolated from old road"):
		return
	if not check(state.load_game(save_path, false), "load isolated save"):
		return
	await world.map_presented
	field = await field_ready()
	if not check(state.current_map == "ashen_crypt" and field.enemies.is_empty() and state.flags.crypt_cleared, "clear state persists without respawn"):
		return
	if not check(player.position.distance_to(Vector3(0, 0.1, 8)) < 0.05, "saved player position restored"):
		return
	if not check(field.loot_nodes.size() == 5, "uncollected dungeon loot persists"):
		return
	# Defeat recovery returns to a valid safe map and resets camera mode.
	field.call("_recover")
	await world.map_presented
	await field_ready()
	if not check(state.current_map == "east_road" and not world.get_node("CameraRig").get("_dungeon"), "recovery leaves dungeon camera"):
		return
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	world.free()
	for singleton: String in ["GameAudio", "GameMusic", "GameAmbience"]:
		root.get_node(singleton).call("stop_all")
	await process_frame
	print("ASHEN_CRYPT_TEST_PASS entrance navigation collision combat reward loot save return recovery")
	quit()
