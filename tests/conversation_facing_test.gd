extends SceneTree
## Real interaction dispatch, all eight approach directions, camera orbits and gear.
const Proportions = preload("res://scripts/gameplay/character_proportions.gd")
const Facing = preload("res://scripts/gameplay/eight_way_facing.gd")
const Grounding = preload("res://scripts/gameplay/sprite_grounding.gd")
const Catalog = preload("res://scripts/systems/party_equipment.gd")
const INPUTS: Array[Vector2] = [Vector2.DOWN, Vector2.UP, Vector2.LEFT, Vector2.RIGHT, Vector2(-1, 1), Vector2(1, 1), Vector2(-1, -1), Vector2(1, -1)]
const OPPOSITES: Array[StringName] = [&"up", &"down", &"right", &"left", &"up_right", &"up_left", &"down_right", &"down_left"]
var failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)


func _run() -> void:
	var state := root.get_node("GameState")
	state.call("reset_new_game", false)
	state.get("flags")["intro_seen"] = true
	state.set("quest_state", 1) # Active reminder dialogue has no quest callback.
	var world := load("res://scenes/main.tscn").instantiate() as Node3D
	root.add_child(world)
	world.set("_test_mode", true)
	var player := world.get_node("Player") as CharacterBody3D
	player.set_physics_process(false)
	var player_art := player.get_node("Sprite3D") as AnimatedSprite3D
	var rig := world.get_node("CameraRig") as Node3D
	rig.set_process(false)
	var camera := rig.get_node("Camera3D") as Camera3D
	var dialogue := world.get_node("DialogueUI")
	await process_frame
	for actor: String in ["elder", "rumi", "noah"]:
		var npc := world.get("_map_root").get_node(actor.capitalize()) as Node3D
		var sprite := npc.get_node("CharacterArt") as Sprite3D
		var rows := 1 if actor == "rumi" else 4
		for row: int in range(rows):
			if actor != "rumi":
				var gear: Dictionary = Catalog.defaults(actor)
				if row & 1:
					gear.weapon = "astral_staff" if actor == "elder" else "dawn_partisan"
				if row & 2:
					gear.armor = "astral_robe" if actor == "elder" else "dawn_plate"
				check(state.call("equip_loadout", gear, actor), "Cannot equip conversation outfit")
			var original := sprite.texture
			var original_scale := sprite.pixel_size
			check(original.get_meta("facing", &"") == Facing.ANIMATIONS[Facing.direction_index(Facing.screen_direction(Vector3.BACK, camera))], "Idle must preserve world facing")
			check((original as AtlasTexture).atlas.resource_path.ends_with(actor + "_facings.png"), "Map idle uses an unrelated character sheet")
			for yaw: float in [0.0, 45.0, 90.0, 135.0, 180.0, 225.0, 270.0, 315.0]:
				camera.global_position = npc.global_position + Basis(Vector3.UP, deg_to_rad(yaw)) * Vector3(0, 5, 8)
				camera.look_at(npc.global_position + Vector3.UP * 0.7)
				await process_frame
				original = sprite.texture
				original_scale = sprite.pixel_size
				check(original.get_meta("facing", &"") == Facing.ANIMATIONS[Facing.direction_index(Facing.screen_direction(Vector3.BACK, camera))], "Camera orbit rotated the NPC world heading")
				check(original.get_meta("loadout_row", -1) == row, "Idle orbit dropped equipment")
				for index: int in range(INPUTS.size()):
					var offset: Vector3 = player.call("_camera_relative_direction", INPUTS[index])
					player.global_position = npc.global_position + offset * 1.35 + Vector3.UP * 0.03
					if "--facing-capture" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless" and row == rows - 1 and yaw == 0.0 and index == 4:
						await process_frame
						await RenderingServer.frame_post_draw
						var idle_path := "/tmp/map-idle-%s-%s.png" % [actor, RenderingServer.get_current_rendering_method()]
						check(root.get_texture().get_image().save_png(idle_path) == OK, "Idle capture failed")
					world.call("_handle_interaction", actor)
					check(dialogue.call("is_open"), "Interaction did not open dialogue")
					check(sprite.texture.get_meta("facing", &"") == Facing.ANIMATIONS[index], "NPC is not facing player: %s/%s" % [actor, index])
					check(player_art.animation == OPPOSITES[index] and player_art.frame == 0, "Player is not facing NPC")
					check(sprite.texture.get_meta("loadout_row", -1) == row, "Conversation dropped equipment")
					var art := sprite.texture as AtlasTexture
					var image := art.atlas.get_image()
					var region := Rect2i(art.region)
					check(image.get_pixel(region.position.x, region.position.y).a < 0.5, "Opaque atlas margin")
					check(is_equal_approx(Grounding.foot_baseline(art, 0.5), float(art.get_meta("ground_y"))), "Conversation feet are not grounded")
					check(is_equal_approx(sprite.pixel_size * Proportions.profile(art, float(art.get_meta("visible_height"))).x, Proportions.HEIGHT), "Turn changed NPC height")
					var texture_before := sprite.texture
					world.call("_handle_interaction", "noah" if actor != "noah" else "rumi")
					check(sprite.texture == texture_before, "Locked dialogue changed speaker")
					if "--facing-capture" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless" and row == rows - 1 and yaw == 0.0 and index in [4, 7]:
						await process_frame
						await RenderingServer.frame_post_draw
						var path := "/tmp/conversation-%s-%s-%s.png" % [actor, index, RenderingServer.get_current_rendering_method()]
						check(root.get_texture().get_image().save_png(path) == OK, "Capture failed")
					while dialogue.call("is_open"):
						dialogue.call("advance")
					check(sprite.texture == original and is_equal_approx(sprite.pixel_size, original_scale), "Dialogue end did not restore NPC immediately")
	# Close and exactly coincident approaches must separate before framing.
	var rumi := world.get("_map_root").get_node("Rumi") as Node3D
	for distance: float in [0.0, 0.1, 0.65, 1.8]:
		player.global_position = rumi.global_position + Vector3(distance, 0.03, 0.0)
		var before: Vector3 = player.global_position
		player.velocity = Vector3(-4.2, 0.0, 0.0)
		world.call("_handle_interaction", "rumi")
		check(not player.get_collision_exceptions().has(rumi.get_node("ActorBody")), "Conversation did not restore NPC collision")
		var gap: Vector3 = player.global_position - rumi.global_position
		gap.y = 0.0
		check(gap.length() >= 1.34, "Close conversation overlaps the NPC")
		check(is_zero_approx(player.velocity.x) and is_zero_approx(player.velocity.z), "Conversation retains approach momentum")
		check(is_equal_approx(player.global_position.y, before.y), "Spacing changed floor height")
		if distance == 1.8:
			check(player.global_position.is_equal_approx(before), "Already spaced player was moved")
		while dialogue.call("is_open"):
			dialogue.call("advance")
	# A wall behind the player requires another clear retreat direction.
	var obstacle := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.2, 3.0, 6.0)
	collision.shape = box
	obstacle.add_child(collision)
	root.add_child(obstacle)
	obstacle.global_position = Vector3(101.0, 1.0, 100.0)
	var partner := Node3D.new()
	root.add_child(partner)
	partner.global_position = Vector3(100.0, 0.0, 100.0)
	player.global_position = Vector3(100.4, 0.03, 100.0)
	await physics_frame
	await physics_frame
	player.call("make_conversation_space", partner)
	check(player.global_position.x < 100.65, "Conversation retreat crossed a wall")
	check(Vector2(player.global_position.x - 100.0, player.global_position.z - 100.0).length() >= 1.34, "Blocked retreat did not find a clear side")
	obstacle.queue_free()
	partner.queue_free()
	# An actor being freed during a conversation must not retain a dangling target.
	world.call("_handle_interaction", "rumi")
	world.call("_load_map", "ruins", "from_village")
	await process_frame
	world.queue_free()
	await process_frame
	for singleton: String in ["GameAudio", "GameMusic", "GameAmbience"]:
		root.get_node(singleton).call("stop_all")
	await create_timer(0.25).timeout
	if failures == 0:
		print("CONVERSATION_FACING_TEST_PASS three_npcs eight_directions eight_orbits nine_loadouts mutual_facing grounding restore locks map_cleanup")
	quit(0 if failures == 0 else 1)
