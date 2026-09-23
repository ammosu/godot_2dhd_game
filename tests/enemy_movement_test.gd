extends SceneTree
const Movement = preload("res://scripts/gameplay/enemy_movement_art.gd")
const Art = preload("res://scripts/gameplay/action_sprite_library.gd")
const Facing = preload("res://scripts/gameplay/eight_way_facing.gd")
var failures: int = 0

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var sprite := Sprite3D.new()
	root.add_child(sprite)
	var camera := Camera3D.new()
	root.add_child(camera)
	for actor: String in Movement.DATA:
		var data: Dictionary = Movement.DATA[actor]
		check(data.frames.size() == 24, actor + " must have 24 unique poses")
		check(data.sha256 == FileAccess.get_sha256("res://assets/generated/enemy_movement/%s.png" % actor), "Metadata matches source")
		var regions: Array[Rect2] = []
		for direction: int in range(8):
			var screen := Vector2.from_angle(PI * 0.5 - direction * PI / 4)
			check(Movement.direction(screen) == direction, "All eight screen headings")
			for pose: String in Movement.POSES:
				var texture: AtlasTexture = Art.directional_texture(actor, pose, screen, sprite)
				check(int(texture.get_meta("movement_facing")) == direction, "Runtime selects eight-way atlas")
				check(not regions.has(texture.region), "Every direction and step has its own drawn region")
				regions.append(texture.region)
				check(Rect2(Vector2.ZERO, texture.atlas.get_size()).encloses(texture.region), "Region within source")
				check(float(texture.get_meta("pixel_size")) > 0, "Valid physical size")
				check(float(texture.get_meta("ground_y")) == texture.get_height(), "Ground baseline")
				var img: Image = texture.atlas.get_image()
				if img.is_compressed():
					img.decompress()
				check(img.detect_alpha() != Image.ALPHA_NONE, "True transparency")
		if actor != "ash_warden":
			for pose: String in ["attack", "hurt", "defeated", "cast"]:
				var texture: AtlasTexture = Art.directional_texture(actor, pose, Vector2.RIGHT, sprite)
				check(texture == Art.texture_for(actor, pose, 1), "Combat poses retain original art")
	check(Movement.direction(Vector2.from_angle(deg_to_rad(64)), 0) == 0, "Boundary jitter retains facing")
	check(Movement.direction(Vector2.from_angle(deg_to_rad(59)), 0) == 1, "Intentional turn leaves dead band")
	check(Movement.direction(Vector2.ZERO, 5) == 5, "Standing retains heading")
	for quarter: int in range(4):
		camera.rotation.y = quarter * PI / 2
		check(Movement.direction(Facing.screen_direction(Vector3.BACK, camera)) == posmod(-quarter * 2, 8), "Camera orbit updates relative direction")
	check(Art.directional_texture("wanderer", "idle", Vector2.RIGHT, sprite) == Art.texture_for("wanderer", "idle", 1), "Allied equipment path preserved")
	camera.queue_free()
	sprite.queue_free()
	await process_frame
	if failures == 0:
		print("ENEMY_MOVEMENT_TEST_PASS five_species eight_directions steps camera hysteresis combat_fallback alpha grounding")
	quit(0 if failures == 0 else 1)
