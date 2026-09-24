extends SceneTree
## Real physics world, skill targeting and in-game visual captures. No normal saves.
var failures: Array[String] = []

func _init() -> void:
	run.call_deferred()

func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
		push_error(message)

func run() -> void:
	var state: Node = root.get_node("GameState")
	state.reset_new_game(false)
	state.flags.intro_seen = true
	var world: Node3D = load("res://scenes/main.tscn").instantiate()
	root.add_child(world)
	world.set("_test_mode", true)
	for id: String in ["archer", "mage", "thief"]:
		state.reset_new_game(false, id, "ember" if "--style-capture" in OS.get_cmdline_user_args() else "original", "female" if "--female" in OS.get_cmdline_user_args() else "male")
		state.flags.intro_seen = true
		world.call("_load_map", "east_road", "from_village")
		var player: CharacterBody3D = world.get_node("Player")
		player.set_physics_process(false)
		if "--female" in OS.get_cmdline_user_args():
			player.call("_update_sprite", Vector2.ZERO, Vector3.ZERO, 0.0)
			var sprite: AnimatedSprite3D = player.get_node("Sprite3D")
			check(str(sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame).get_meta("variant")) == "class_female_" + id, "Exploration lost heroine")
			await player.reach_for_door()
			check(str(sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame).get_meta("variant")) == "class_female_" + id, "Door lost heroine")
			await player.withdraw_door_hand()
		var field: Node3D = world.get("_map_root").get_node("FieldCombat")
		while not field.ready_for_combat:
			await physics_frame
		field.set_physics_process(false)
		player.position = Vector3(-6, 0.06, 8)
		field.facing = Vector3.RIGHT
		for index: int in range(field.enemies.size()):
			var enemy: Dictionary = field.enemies[index]
			enemy.body.position = Vector3(-3.0 + index, 0.06, 8 if index < 2 else 11)
			enemy.hp = 200
			enemy.max_hp = 200
			enemy.facing = Vector3.RIGHT
			field.call("_art", enemy.sprite, enemy.art, "idle", enemy.facing)
		if id == "thief":
			field.enemies[0].body.position.x = -4.3
		await physics_frame
		var mp: int = state.player_mp
		check(field.perform("skill"), "Field skill rejected: " + id)
		check(state.player_mp == mp - int(state.class_profile().cost), "Field skill cost")
		field.windup = 0.0
		field.call("_strike")
		check(int(field.enemies[0].hp) < 200, "Field skill missed target: " + id)
		if id in ["mage", "archer"]:
			check(int(field.enemies[1].hp) < 200, "Area/piercing skill missed second enemy")
		if id == "mage":
			check(float(field.enemies[0].slow) == 3.0, "Field frost must slow")
		if id == "thief":
			check(int(field.enemies[1].hp) == 200, "Shadow must not cleave")
			var expected: int = (state.player_attack + int(state.class_profile().power)) * 2
			check(200 - int(field.enemies[0].hp) == expected, "Field backstab bonus")
		check(int(field.enemies[2].hp) == 200, "Skill damaged off-axis enemy")
		field.call("_update_hero_art")
		field.call("_update_hud")
		for effect: Node3D in field.get("_effects"):
			effect.advance(0.09 if id == "archer" else 0.15)
		world.get_node("CameraRig").set("_distance", 9.0)
		world.get_node("CameraRig").call("snap_to_target")
		check(str(field.get("_hero_sprite").texture.get_meta("variant")) == "class_" + ("female_" if "--female" in OS.get_cmdline_user_args() else "") + id, "Field wardrobe not applied")
		if "--class-capture" in OS.get_cmdline_user_args():
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("/tmp/wanderlight-class-skill-%s.png" % id)
	world.queue_free()
	await process_frame
	for singleton: String in ["GameAudio", "GameMusic", "GameAmbience"]:
		root.get_node(singleton).call("stop_all")
	await create_timer(0.2).timeout
	if failures.is_empty():
		print("CLASS_FIELD_TEST_PASS gear effects piercing frost slow single_target backstab")
	quit(0 if failures.is_empty() else 1)
