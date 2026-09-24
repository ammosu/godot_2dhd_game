extends SceneTree
## Render the actual player scene's thirty-two walking poses for art inspection.
## A diagnostic contact sheet, not a gameplay screenshot or animation approval.

const DIRECTIONS: Array[StringName] = [&"down", &"up", &"left", &"right", &"down_left", &"down_right", &"up_left", &"up_right"]
const INPUTS: Array[Vector2] = [Vector2.DOWN, Vector2.UP, Vector2.LEFT, Vector2.RIGHT, Vector2(-1, 1), Vector2(1, 1), Vector2(-1, -1), Vector2(1, -1)]


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var output: String = ""
	var vocation: String = ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-dir="):
			output = argument.trim_prefix("--capture-dir=")
		if argument.begins_with("--class="):
			vocation = argument.trim_prefix("--class=")
	if DisplayServer.get_name() == "headless" or not DirAccess.dir_exists_absolute(output):
		push_error("Requires actual renderer and existing --capture-dir directory")
		quit(1)
		return
	if not vocation.is_empty():
		root.get_node("GameState").call("reset_new_game", false, vocation)
	var stage := Node3D.new()
	root.add_child(stage)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("283340")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = 0.9
	stage.add_child(environment)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 12.5
	stage.add_child(camera)
	camera.position = Vector3(0, 12, 12)
	camera.look_at(Vector3(0, 0.7, 0))
	camera.current = true
	var floor := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(24, 24)
	floor.mesh = plane
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("56616a")
	material.roughness = 1.0
	floor.material_override = material
	stage.add_child(floor)
	var canvas := CanvasLayer.new()
	stage.add_child(canvas)
	# Load after SceneTree autoload initialization, as the real game does.
	var scene := load("res://scenes/player.tscn") as PackedScene
	for direction: int in range(DIRECTIONS.size()):
		for frame: int in range(4):
			var player := scene.instantiate() as CharacterBody3D
			player.position = Vector3(-7.0 + (direction / 4) * 8.0 + frame * 2.0, 0.01, -4.5 + (direction % 4) * 3.0)
			stage.add_child(player)
			player.set_physics_process(false)
			player.set("_walk_time", float(frame))
			player.call("_update_sprite", INPUTS[direction], Vector3.FORWARD, 0.0)
			var sprite := player.get_node("Sprite3D") as AnimatedSprite3D
			assert(sprite.animation == DIRECTIONS[direction] and sprite.frame == frame)
			var label := Label.new()
			label.text = "%s / %d" % [DIRECTIONS[direction], frame]
			label.add_theme_font_size_override("font_size", 18)
			label.add_theme_color_override("font_color", Color.WHITE)
			label.position = camera.unproject_position(player.position) + Vector2(-35, 10)
			canvas.add_child(label)
	for frame: int in range(10):
		await process_frame
	await RenderingServer.frame_post_draw
	var prefix := "player" if vocation.is_empty() else vocation
	var path := output.path_join("%s-walk-%s.png" % [prefix, RenderingServer.get_current_rendering_method()])
	var error := root.get_texture().get_image().save_png(path)
	stage.free()
	for singleton: String in ["GameAudio", "GameMusic", "GameAmbience"]:
		root.get_node(singleton).call("stop_all")
	await create_timer(0.25).timeout
	assert(error == OK)
	print("PLAYER_MOTION_CAPTURE_PASS thirty_two_actual_player_poses ", path)
	quit()
