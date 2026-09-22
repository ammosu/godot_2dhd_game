extends SceneTree
## Native renderer visual fixture; gameplay state and saves remain isolated.
const Art = preload("res://scripts/gameplay/action_sprite_library.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var state: Node = root.get_node("GameState")
	state.reset_new_game(false)
	state.flags["intro_seen"] = true
	var world: Node3D = load("res://scenes/main.tscn").instantiate()
	root.add_child(world)
	world._test_mode = true
	world._load_map("ruins", "from_village")
	world.player.global_position = Vector3(0, 0.1, -4.5)
	world.get_node("CameraRig").snap_to_target()
	for frame: int in range(3):
		await physics_frame
	world._start_guardian_battle()
	var ui: CanvasLayer = world.battle_ui
	ui.set_physics_process(false)
	ui.session.paused = false
	var points: Array[Vector2] = [Vector2(-2, -4), Vector2(0, -3), Vector2(2, -3), Vector2(-2, -8), Vector2(0, -8), Vector2(3, -8)]
	for index: int in range(6):
		var actor: Dictionary = ui.session.actors[index]
		actor.position = points[index]
		actor.facing = Vector2.UP if index < 3 else Vector2.DOWN
		ui.encounter.bodies[index].position = Vector3(points[index].x, 0.1, points[index].y)
	ui.session.actors[0].swing = 0.18
	ui.session.actors[1].support_cast = 0.3
	ui.session.actors[2].swing = 0.18
	ui.session.actors[2].intent = "skill"
	ui.session.actors[3].hurt = 0.2
	ui.session.actors[4].swing = 0.18
	ui.session.actors[5].windup = 0.3
	ui.session.actors[5].aim = points[0]
	ui.encounter.refresh(0.0)
	for sprite: Sprite3D in ui.encounter.sprites:
		var bottom: float = sprite.offset.y - sprite.texture.get_height() * 0.5
		assert(absf(bottom) < 0.01, "Every visible sprite bottom must remain on its actor's ground origin")
		assert(is_equal_approx(sprite.position.y, 0.012), "Ground anchor height must remain stable")
	ui.encounter._effect("moon_slash", points[0] + Vector2.UP, 1.5)
	ui.encounter._effect("ward", points[1])
	ui.encounter._effect("frost", Vector2(2, -6), 1.8)
	ui.encounter._effect("heal", points[2])
	for frame: int in range(3):
		await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/wanderlight-action-art-world.png")
	# Expire raster effects on the same clock and verify every temporary node is gone.
	ui.encounter.refresh(2.0)
	await process_frame
	assert(ui.encounter._effects.is_empty(), "Raster effects must clean up")
	ui.encounter.finish()
	world.queue_free()
	await process_frame
	for audio_player: Node in root.find_children("*", "AudioStreamPlayer", true, false):
		audio_player.stop()
	await create_timer(0.15).timeout
	print("ACTION_ART_WORLD_TEST_PASS poses magic grounding cleanup")
	quit()
