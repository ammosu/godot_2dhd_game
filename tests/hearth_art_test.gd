extends SceneTree

var _failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)


func _run() -> void:
	var room: Node3D = load("res://scripts/gameplay/house_interior.gd").new()
	root.add_child(room)
	var fire := room.get_node("HearthFire") as Node3D
	var flames := fire.get_node("Flames") as AnimatedSprite3D
	flames.pause()
	_check(flames.sprite_frames.get_frame_count(&"default") == 4, "Expected four flame poses")
	_check(flames.texture_filter == BaseMaterial3D.TEXTURE_FILTER_NEAREST, "Fire lost nearest sampling")
	_check(flames.billboard == BaseMaterial3D.BILLBOARD_FIXED_Y, "Flames must remain upright on orbit")
	_check(flames.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "Fire must not cast a card shadow")
	for index: int in range(4):
		flames.frame = index
		var texture := flames.sprite_frames.get_frame_texture(&"default", index) as AtlasTexture
		var image := texture.get_image()
		_check(image.get_pixel(0, 0).a < 0.1, "Flame frame has an opaque background")
		var baseline: float = flames.offset.y - texture.get_height() * 0.5
		_check(is_zero_approx(baseline), "Frame base slides away from logs")
		var tip_height: float = fire.position.y + flames.position.y + texture.get_height() * flames.pixel_size
		_check(tip_height < 1.40, "Flame passes through mantel")
	flames.play()
	var start_frame: int = flames.frame
	await create_timer(0.17).timeout
	_check(flames.frame != start_frame, "Flame animation did not advance")
	for index: int in range(3):
		var log := fire.get_node("CharredLog%d" % index) as MeshInstance3D
		_check(log.mesh is CylinderMesh, "Stacked logs reverted to a block")
		_check((log.material_override as StandardMaterial3D).albedo_texture != null, "Log texture missing")
	var light := fire.get_node("Firelight") as OmniLight3D
	for index: int in range(100):
		fire.call("_process", 0.031)
		_check(light.light_energy >= 2.09 and light.light_energy <= 2.31, "Firelight flicker exceeds safe amplitude")
		var tip: float = fire.position.y + flames.position.y + flames.sprite_frames.get_frame_texture(&"default", flames.frame).get_height() * flames.pixel_size * flames.scale.y
		_check(tip < 1.40, "Breathing flame crosses mantel")
		for layer: int in range(2):
			var tongue := fire.get_node("RearFlame%d" % layer) as AnimatedSprite3D
			var frame_height: float = tongue.sprite_frames.get_frame_texture(&"default", tongue.frame).get_height()
			_check(is_zero_approx(tongue.offset.y - frame_height * 0.5), "Rear flame base slides away from logs")
		if DisplayServer.get_name() != "headless":
			var embers := fire.get_node("RisingEmbers") as MultiMeshInstance3D
			for ember: int in range(embers.multimesh.instance_count):
				var transform := embers.multimesh.get_instance_transform(ember)
				_check(transform.origin.y + fire.position.y < 1.40, "Ember escapes through mantel")
				_check(transform.basis.x.length() <= 0.01, "Ember becomes an oversized glowing blob")
	_check(fire.find_children("*", "CollisionObject3D", true, false).is_empty(), "Hearth decoration changed collision")
	room.queue_free()
	for singleton: String in ["GameAudio", "GameMusic", "GameAmbience"]:
		root.get_node(singleton).call("stop_all")
	await create_timer(0.3).timeout
	if _failures == 0:
		print("HEARTH_ART_TEST_PASS frames alpha baseline animation logs light collision")
	quit(0 if _failures == 0 else 1)
