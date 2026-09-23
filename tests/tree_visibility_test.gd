extends SceneTree
## Controlled camera/tree geometry verifies masking independently of placement rules.
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var scene := Node3D.new()
	root.add_child(scene)
	var player := Node3D.new()
	scene.add_child(player)
	var camera := Camera3D.new()
	scene.add_child(camera)
	camera.current = true
	var tree := Node3D.new()
	scene.add_child(tree)
	var art := Sprite3D.new()
	art.name = "TreeArt"
	var texture := GradientTexture2D.new()
	texture.width = 64
	texture.height = 256
	art.texture = texture
	art.pixel_size = 0.025
	art.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	art.position.y = 2.5
	art.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	tree.add_child(art)
	var controller := preload("res://scripts/gameplay/tree_visibility.gd").new()
	scene.add_child(controller)
	controller.configure(scene, player, camera)
	controller.set_process(false)
	for projection: int in [Camera3D.PROJECTION_PERSPECTIVE, Camera3D.PROJECTION_ORTHOGONAL]:
		camera.projection = projection
		camera.size = 15
		for index: int in range(8):
			var angle: float = index * TAU / 8
			var direction := Vector3(sin(angle), 0, cos(angle))
			camera.position = direction * 10 + Vector3.UP * 5
			camera.look_at(Vector3.UP * 0.8)
			tree.position = direction * 4
			await process_frame
			controller.call("_process", 0.4)
			assert(art.modulate.a <= 0.17, "foreground tree must fade at orbit %d" % index)
			tree.position = -direction * 4
			controller.call("_process", 0.5)
			assert(is_equal_approx(art.modulate.a, 1), "background tree must restore")
			assert(art.alpha_cut == SpriteBase3D.ALPHA_CUT_DISCARD)
			tree.position = direction * 4 + camera.global_basis.x * 4
			controller.call("_process", 0.5)
			assert(is_equal_approx(art.modulate.a, 1), "side tree must stay opaque")
	scene.free()
	print("TREE_VISIBILITY_TEST_PASS eight_angles perspective orthographic restore")
	quit()
