extends SceneTree
## Size contracts across human art families; optional visual lineup, no saves.
const Proportions = preload("res://scripts/gameplay/character_proportions.gd")
const Art = preload("res://scripts/gameplay/action_sprite_library.gd")
const Equipment = preload("res://scripts/systems/class_equipment.gd")
var _failures: int = 0
var _entries: Array[Dictionary] = []

func _initialize() -> void:
	_run.call_deferred()

func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures += 1
		push_error(message)

func _entry(label: String, texture: Texture2D, height: float) -> void:
	var fit := Proportions.profile(texture, height)
	_check(fit.x > 0.0 and fit.y >= 0.8499 and fit.y <= 1.2001, label + " valid fit")
	_entries.append({"label": label, "texture": texture, "fit": fit})

func _run() -> void:
	var image := Image.create(160, 220, false, Image.FORMAT_RGBA8)
	image.fill_rect(Rect2i(50, 40, 60, 160), Color.WHITE)
	var bare := ImageTexture.create_from_image(image)
	image.fill_rect(Rect2i(10, 0, 4, 200), Color.WHITE)
	var armed := ImageTexture.create_from_image(image)
	_check(Proportions.profile(bare, 200.0, 200.0, 80.0).is_equal_approx(Proportions.profile(armed, 200.0, 200.0, 80.0)), "Raised weapon must not shrink the person")
	var state := root.get_node("GameState")
	state.reset_new_game(false)
	state.flags.intro_seen = true
	for body: String in ["male", "female"]:
		for vocation: String in ["traveler", "archer", "mage", "thief"]:
			var gear: Dictionary = Equipment.defaults(vocation)
			gear.hero_body = body
			for direction: int in range(4):
				var idle := Art.texture_for("wanderer", "idle", direction, gear)
				for pose: String in Art.POSES:
					var texture := Art.texture_for("wanderer", pose, direction, gear)
					_check(is_equal_approx(float(texture.get_meta("pixel_size")) * float(texture.get_meta("source_body_height", 1.0)), float(idle.get_meta("pixel_size")) * float(idle.get_meta("source_body_height", 1.0))), "%s %s %s stable pose size" % [body, vocation, pose])
				_check(is_equal_approx(float(idle.get_meta("body_height")) * float(idle.get_meta("pixel_size")), Proportions.HEIGHT), "Shared player stature")
				if direction == 0:
					_entry(body + " " + vocation, idle, float(idle.get_meta("body_height")))
	for actor: String in ["noah", "elder"]:
		for direction: int in range(4):
			var idle := Art.texture_for(actor, "idle", direction)
			for pose: String in Art.POSES:
				var texture := Art.texture_for(actor, pose, direction)
				_check(is_equal_approx(float(texture.get_meta("pixel_size")) * float(texture.get_meta("source_body_height", 1.0)), float(idle.get_meta("pixel_size")) * float(idle.get_meta("source_body_height", 1.0))), actor + " stable action size")
			_check(is_equal_approx(float(idle.get_meta("body_height")) * float(idle.get_meta("pixel_size")), Proportions.HEIGHT), "Shared companion stature")
			if direction == 0:
				_entry(actor + " combat", idle, float(idle.get_meta("body_height")))
	for actor: String in ["noah", "elder", "rumi"]:
		var frames := load("res://assets/generated/" + actor + "_facings.tres") as SpriteFrames
		var texture := frames.get_frame_texture(&"down", 0)
		_entry(actor + " town", texture, float(texture.get_meta("visible_height")))
	for actor: String in ["mira", "flo", "sien", "locke", "ada", "rain", "seph", "owen"]:
		var frames := load("res://assets/generated/residents/" + actor + "_walk.tres") as SpriteFrames
		var texture := frames.get_frame_texture(&"down", 0)
		_entry(actor, texture, float(texture.get_meta("reference_height")))
	for actor: String in preload("res://scripts/gameplay/city_resident_catalog.gd").RESIDENTS:
		var texture := load("res://assets/generated/city_residents/" + actor + ".tres") as Texture2D
		_entry(actor, texture, float(texture.get_meta("reference_height")))
	# Equipment previews keep the same standing reference across attack poses,
	# and their fitted copies must not alter world atlas metadata.
	for actor: String in ["wanderer", "noah", "elder"]:
		var portrait: TextureRect = load("res://scripts/ui/equipment_portrait.gd").new()
		root.add_child(portrait)
		var expected_height: float = 0.0
		for pose: String in ["idle", "attack", "hurt", "guard"]:
			var base := load("res://assets/generated/%s_combat_%s.tres" % [actor, pose]) as Texture2D
			var had_metrics: bool = base.has_meta("body_height")
			portrait.call("dress", base, pose, state.get_loadout(actor), actor)
			var height: float = float(portrait.texture.get_meta("body_height"))
			if pose == "idle":
				expected_height = height
			_check(is_equal_approx(height, expected_height), actor + " stable portrait reference")
			_check(base.has_meta("body_height") == had_metrics, "Portrait must not mutate shared world art")
		portrait.queue_free()
	var world: Node3D = load("res://scenes/main.tscn").instantiate()
	root.add_child(world)
	world.set("_test_mode", true)
	world.call("_load_map", "east_road", "from_village")
	var road: Sprite3D = world.get("_map_root").get_node("Road Traveler/CharacterArt")
	_check(road.get("resident_id") == "rain", "Road traveler uses resident art")
	_check(is_equal_approx(float(road.get("visible_height")), Proportions.HEIGHT), "Road traveler shared stature")
	if DisplayServer.get_name() != "headless":
		var player: Node3D = world.get_node("Player")
		player.position = Vector3(3.4, 0.1, 2.0)
		world.get_node("CameraRig").set("_distance", 9.0)
		world.get_node("CameraRig").call("snap_to_target")
		for frame: int in range(30):
			await physics_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/character-proportions-world-" + RenderingServer.get_current_rendering_method() + ".png")
	world.queue_free()
	await process_frame
	if DisplayServer.get_name() != "headless":
		var canvas := SubViewport.new()
		canvas.size = Vector2i(1440, 1000)
		canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(canvas)
		var background := ColorRect.new()
		background.color = Color("202c38")
		background.size = Vector2(1440, 1000)
		canvas.add_child(background)
		for index: int in range(_entries.size()):
			var entry: Dictionary = _entries[index]
			var sprite := Sprite2D.new()
			sprite.texture = entry.texture
			sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			var factor: float = 126.0 / entry.fit.x
			sprite.scale = Vector2(entry.fit.y, 1.0) * factor
			var ground: float = float(sprite.texture.get_meta("ground_y", sprite.texture.get_height()))
			sprite.offset.y = sprite.texture.get_height() * 0.5 - ground
			sprite.position = Vector2(80 + (index % 9) * 160, 166 + (index / 9) * 194)
			canvas.add_child(sprite)
			var label := Label.new()
			label.text = entry.label
			label.position = Vector2(sprite.position.x - 73, sprite.position.y + 10)
			label.add_theme_font_size_override("font_size", 13)
			canvas.add_child(label)
		await process_frame
		await RenderingServer.frame_post_draw
		canvas.get_texture().get_image().save_png("/tmp/character-proportions.png")
	if _failures == 0:
		print("CHARACTER_PROPORTIONS_TEST_PASS humans npcs poses stature")
	quit(1 if _failures else 0)
