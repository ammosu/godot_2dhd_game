extends SceneTree
## Capture actual resident sprites at every direction/pose for visual review.
## Diagnostic gallery, not a normal gameplay scene or an automatic art verdict.
var Art: GDScript
const HEADINGS: Array[Vector3] = [Vector3.BACK, Vector3(-1, 0, 1), Vector3.LEFT, Vector3(-1, 0, -1),
	Vector3.FORWARD, Vector3(1, 0, -1), Vector3.RIGHT, Vector3(1, 0, 1)]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	# --script loads before autoload names exist; defer the actor script load.
	Art = load("res://scripts/gameplay/resident_art.gd") as GDScript
	var output: String = ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="):
			output = argument.trim_prefix("--capture-dir=")
	if DisplayServer.get_name() == "headless" or not DirAccess.dir_exists_absolute(output):
		push_error("Requires actual renderer and existing --capture-dir directory")
		quit(1)
		return
	var viewport := SubViewport.new()
	viewport.size = Vector2i(960, 1600)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var state := root.get_node("GameState")
	state.call("reset_new_game", false)
	var stage := Node3D.new()
	viewport.add_child(stage)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("293541")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = 1.0
	stage.add_child(environment)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 18.0
	camera.position = Vector3(0, 0, 20)
	stage.add_child(camera)
	camera.current = true
	for identity: String in Art.IDENTITIES:
		var group := Node3D.new()
		stage.add_child(group)
		for direction: int in range(HEADINGS.size()):
			for pose: int in range(4):
				var anchor := Node3D.new()
				anchor.position = Vector3(-3.6 + pose * 2.4, 6.8 - direction * 2.1, 0)
				group.add_child(anchor)
				var sprite: Variant = Art.new()
				sprite.resident_id = identity
				sprite.world_heading = HEADINGS[direction]
				sprite.visible_height = 1.7
				sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
				anchor.add_child(sprite)
				sprite.set_process(false)
				if pose > 0:
					sprite.walking = true
					sprite.call("_update_presentation", (float(pose - 1) + 0.1) / Art.WALK_FPS)
				assert(sprite.pose_index == pose)
				var label := Label3D.new()
				label.text = "%s / %d" % [sprite.animation, pose]
				label.font_size = 24
				label.pixel_size = 0.008
				label.position.y = -0.15
				anchor.add_child(label)
		await process_frame
		await RenderingServer.frame_post_draw
		var path := output.path_join("%s-%s.png" % [identity, RenderingServer.get_current_rendering_method()])
		assert(viewport.get_texture().get_image().save_png(path) == OK)
		group.free()
	viewport.free()
	for singleton: String in ["GameAudio", "GameMusic", "GameAmbience"]:
		root.get_node(singleton).call("stop_all")
	await create_timer(0.25).timeout
	print("RESIDENT_MOTION_CAPTURE_PASS eight_identities 256_actual_poses ", output)
	quit()
