extends SceneTree
## test-requires: gpu
## Verify the actual depth-free outline shader against an opaque foreground actor.
func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(256, 256)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.0
	camera.position.z = 5.0
	viewport.add_child(camera)
	var pixels := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	pixels.fill(Color.TRANSPARENT)
	pixels.fill_rect(Rect2i(8, 4, 16, 24), Color.WHITE)
	var texture := ImageTexture.create_from_image(pixels)
	var foreground := Sprite3D.new()
	foreground.texture = texture
	foreground.pixel_size = 0.04
	foreground.position.z = 1.0
	foreground.modulate = Color.RED
	foreground.shaded = false
	foreground.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	viewport.add_child(foreground)
	var outline := Sprite3D.new()
	outline.texture = texture
	outline.pixel_size = 0.03
	var shader := Shader.new()
	shader.code = preload("res://scripts/gameplay/hit_feedback.gd").OUTLINE_SHADER
	var material := ShaderMaterial.new()
	material.shader = shader
	material.render_priority = 20
	material.set_shader_parameter("character_texture", texture)
	outline.material_override = material
	viewport.add_child(outline)
	for show_outline: bool in [false, true]:
		outline.visible = show_outline
		for frame: int in range(3):
			await process_frame
		await RenderingServer.frame_post_draw
		var rendered: Image = viewport.get_texture().get_image()
		var cyan: int = 0
		for y: int in range(256):
			for x: int in range(256):
				var color: Color = rendered.get_pixel(x, y)
				if color.g > 0.5 and color.b > 0.5:
					cyan += 1
		assert(cyan > 100 if show_outline else cyan == 0, "Only enabled outline remains visible through opaque foreground")
	viewport.queue_free()
	await process_frame
	print("HIT_OUTLINE_RENDER_TEST_PASS depth_free_edges visibility")
	quit()
