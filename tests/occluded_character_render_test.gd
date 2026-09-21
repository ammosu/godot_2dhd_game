extends SceneTree
## Real GPU regression: hidden pixels gain a hint; clear pixels do not change.

var _failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _capture() -> Image:
	for frame: int in range(4):
		await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()


func _difference(a: Image, b: Image) -> int:
	var changed: int = 0
	for y: int in range(a.get_height()):
		for x: int in range(a.get_width()):
			var delta: Color = a.get_pixel(x, y) - b.get_pixel(x, y)
			if absf(delta.r) + absf(delta.g) + absf(delta.b) > 0.04:
				changed += 1
	return changed


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("This test requires a real GPU renderer")
		quit(1)
		return
	root.size = Vector2i(480, 360)
	var stage := Node3D.new()
	root.add_child(stage)
	var camera := Camera3D.new()
	stage.add_child(camera)
	camera.position = Vector3(0, 2, 5)
	camera.look_at(Vector3(0, 0.8, 0))
	var player := (load("res://scenes/player.tscn") as PackedScene).instantiate() as Node3D
	stage.add_child(player)
	player.set_physics_process(false)
	var blocker := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(2, 2, 0.2)
	blocker.mesh = box
	blocker.position = Vector3(0, 0.8, 1)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.15, 0.2, 0.25)
	blocker.material_override = material
	stage.add_child(blocker)
	var controller := preload("res://scripts/gameplay/foreground_cutaway.gd").new()
	blocker.add_child(controller)
	controller.configure(blocker, player, camera)
	controller.set_process(false)
	var hint := player.get_node("OccludedCharacter") as Sprite3D
	hint.set_process(false)
	var full_coverage: int = 0
	for placement: String in ["behind", "front", "partial"]:
		blocker.position.z = -1.5 if placement == "front" else 1.0
		blocker.position.x = 1.0 if placement == "partial" else 0.0
		# Force a broad-phase false positive in the front case: depth must reject it.
		controller.active = true
		hint.hide()
		var before: Image = await _capture()
		hint.call("_process", 0.016)
		var after: Image = await _capture()
		var changed: int = _difference(before, after)
		print("SILHOUETTE_PIXELS ", placement, " ", changed)
		if placement == "behind":
			full_coverage = changed
		if placement == "partial" and (changed >= full_coverage * 0.8 or changed <= full_coverage * 0.2):
			push_error("Partial obstruction must only tint the covered part of the character")
			_failures += 1
		if (placement == "front" and changed != 0) or (placement != "front" and changed < 20):
			push_error("Incorrect depth mask: " + placement)
			_failures += 1
		for argument: String in OS.get_cmdline_user_args():
			if argument.begins_with("--capture-dir="):
				after.save_png(argument.trim_prefix("--capture-dir=").path_join(RenderingServer.get_current_rendering_method() + "-" + placement + ".png"))
	blocker.hide()
	await _test_pillar_front(stage, player, camera, hint, controller)
	stage.free()
	for singleton: String in ["GameAudio", "GameMusic", "GameAmbience"]:
		root.get_node(singleton).call("stop_all")
	await create_timer(0.25).timeout
	if _failures == 0:
		print("OCCLUDED_CHARACTER_RENDER_TEST_PASS behind front partial pillar_front_16_views")
	quit(_failures)


func _test_pillar_front(stage: Node3D, player: Node3D, camera: Camera3D, hint: Sprite3D, controller: Node) -> void:
	var pillar := (load("res://assets/generated/weathered_pillar_v2.glb") as PackedScene).instantiate() as Node3D
	stage.add_child(pillar)
	var sprite := player.get_node("Sprite3D") as AnimatedSprite3D
	for angle: int in range(8):
		var direction := Vector3(sin(angle * PI / 4.0), 0, cos(angle * PI / 4.0))
		camera.position = direction * 5.81 + Vector3.UP * 3.92
		camera.look_at(Vector3.UP * 0.78)
		for distance: float in [0.8, 1.1]:
			pillar.position = -direction * distance
			pillar.hide()
			hint.hide()
			sprite.hide()
			var empty: Image = await _capture()
			sprite.show()
			var reference: Image = await _capture()
			pillar.show()
			controller.active = true
			hint.call("_process", 0.016)
			var actual: Image = await _capture()
			var covered: int = 0
			for y: int in range(reference.get_height()):
				for x: int in range(reference.get_width()):
					var mask: Color = reference.get_pixel(x, y) - empty.get_pixel(x, y)
					if absf(mask.r) + absf(mask.g) + absf(mask.b) < 0.15:
						continue
					var delta: Color = reference.get_pixel(x, y) - actual.get_pixel(x, y)
					if absf(delta.r) + absf(delta.g) + absf(delta.b) > 0.08:
						covered += 1
			if covered > 0:
				push_error("Pillar behind player covered %d character pixels, angle %d distance %.2f" % [covered, angle, distance])
				_failures += 1
			if angle == 0 and is_equal_approx(distance, 0.8):
				actual.save_png("/tmp/pillar-front-" + RenderingServer.get_current_rendering_method() + ".png")
	pillar.free()
