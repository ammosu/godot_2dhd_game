extends SceneTree

const Water = preload("res://scripts/gameplay/natural_water.gd")


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene := Node3D.new()
	root.add_child(scene)
	current_scene = scene
	var creek: Node3D = Water.creek(scene, Vector3.ZERO)
	var pond: Node3D = Water.pond(scene, Vector3(0, 0, 10), Vector2(9, 5))
	await physics_frame
	await physics_frame
	var actor := CharacterBody3D.new()
	var shape_node := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.28
	capsule.height = 1.05
	shape_node.shape = capsule
	actor.add_child(shape_node)
	scene.add_child(actor)
	await physics_frame
	actor.position = Vector3(0, 0.6, -3)
	assert(not actor.test_move(actor.global_transform, Vector3(0, 0, 6)), "Main road ford must be passable")
	actor.position = Vector3(6, 0.6, -3)
	assert(actor.test_move(actor.global_transform, Vector3(0, 0, 6)), "Deep creek must stop a swept player capsule")
	actor.position = Vector3(0, 0.6, 13)
	assert(not actor.test_move(actor.global_transform, Vector3(0, 0, -0.85)), "Pond shore must admit the player")
	assert(actor.test_move(actor.global_transform, Vector3(0, 0, -3)), "Pond center must block the player")
	assert(creek.depth_at(Vector3.ZERO) < 1.0)
	assert(pond.depth_at(Vector3.ZERO) == 1.0)
	assert(pond.depth_at(Vector3(0, 0, 2.2)) == 0.2)
	assert(pond.depth_at(Vector3(0, 0, 3)) < 0.0)
	if DisplayServer.get_name() != "headless":
		var environment := WorldEnvironment.new()
		environment.environment = Environment.new()
		environment.environment.background_mode = Environment.BG_COLOR
		environment.environment.background_color = Color("304b48")
		environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		environment.environment.ambient_light_color = Color.WHITE
		environment.environment.ambient_light_energy = 0.9
		scene.add_child(environment)
		var camera := Camera3D.new()
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = 34
		camera.position = Vector3(0, 25, 21)
		scene.add_child(camera)
		camera.look_at(Vector3(0, 0, 4))
		await create_timer(0.5).timeout
		await RenderingServer.frame_post_draw
		var first: Image = root.get_texture().get_image()
		await create_timer(0.8).timeout
		await RenderingServer.frame_post_draw
		var second: Image = root.get_texture().get_image()
		var changed: int = 0
		for y: int in range(0, first.get_height(), 3):
			for x: int in range(0, first.get_width(), 3):
				if first.get_pixel(x, y) != second.get_pixel(x, y):
					changed += 1
		assert(changed > 50, "Water must visibly animate")
		second.save_png("/tmp/natural-water.png")
	print("NATURAL_WATER_TEST_PASS shallow_shore ford deep_collision animated_if_graphical")
	quit()
