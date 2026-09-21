extends SceneTree
## Native GPU capture of all arena themes; no normal saves are read or written.
const Arena = preload("res://scripts/gameplay/battle_arena_3d.gd")
const Layout = preload("res://scripts/systems/battle_arena_layout.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for singleton: String in ["GameAudio", "GameMusic", "GameAmbience"]:
		root.get_node(singleton).call("stop_all")
	await create_timer(0.25).timeout
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1120, 380)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var arena := Arena.new()
	viewport.add_child(arena)
	for theme: String in Layout.THEMES:
		arena.build(Layout.generate(theme, 2026))
		for index: int in range(6):
			var actor := Sprite3D.new()
			actor.texture = load("res://assets/generated/wanderer_combat_recover.tres") as Texture2D
			actor.pixel_size = 0.0024
			actor.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
			actor.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			actor.position = Vector3((-7.0 if index < 3 else 3.0) + float(index % 3) * 2.0, 0.89, 1.0 if index % 3 == 1 else 0.0)
			actor.flip_h = index >= 3
			arena.add_child(actor)
		await create_timer(0.2).timeout
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			var capture: Image = viewport.get_texture().get_image()
			capture.save_png("/tmp/battle_arena_%s_%s.png" % [theme, RenderingServer.get_current_rendering_method()])
		if arena.get_node_or_null("WalkableFloor") == null or arena.camera == null:
			push_error("Missing battle stage or camera")
			quit(1)
			return
	viewport.free()
	await process_frame
	print("BATTLE_ARENA_RENDER_TEST_PASS five_themes rebuild six_actor_capture")
	quit()
