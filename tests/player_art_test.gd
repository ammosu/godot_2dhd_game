extends SceneTree
## Structural atlas checks plus real player animation selection; no save writes.

var _failures: int = 0
const DIRECTIONS: Array[StringName] = [&"down", &"up", &"left", &"right", &"down_left", &"down_right", &"up_left", &"up_right"]

const INPUTS: Array[Vector2] = [Vector2.DOWN, Vector2.UP, Vector2.LEFT, Vector2.RIGHT, Vector2(-1, 1), Vector2(1, 1), Vector2(-1, -1), Vector2(1, -1)]


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)


func _run() -> void:
	var scene := load("res://scenes/player.tscn") as PackedScene
	if scene == null:
		push_error("Player scene failed to load")
		quit(1)
		return
	var player := scene.instantiate() as CharacterBody3D
	if player == null:
		push_error("Player scene failed to instantiate")
		quit(1)
		return
	root.add_child(player)
	player.set_physics_process(false)
	var sprite := player.get_node("Sprite3D") as AnimatedSprite3D
	var first_frame := sprite.sprite_frames.get_frame_texture(&"down", 0) as AtlasTexture
	var atlas_image := first_frame.atlas.get_image()
	_check(atlas_image != null and atlas_image.detect_alpha() != Image.ALPHA_NONE, "Player atlas requires a transparent background")
	for row: int in range(4):
		for column: int in range(DIRECTIONS.size()):
			var animation: StringName = DIRECTIONS[column]
			_check(sprite.sprite_frames.get_frame_count(animation) == 4, "Each direction needs four poses")
			var frame := sprite.sprite_frames.get_frame_texture(animation, row) as AtlasTexture
			_check(frame.get_size() == (Vector2(320, 320) if column < 4 else Vector2(352, 352)), "All poses need the same presentation canvas")
			atlas_image = frame.atlas.get_image()
			var region := Rect2i(frame.region)
			_check(Rect2i(Vector2i.ZERO, atlas_image.get_size()).encloses(region), "Frame outside source image")
			var visible_pixels: int = 0
			var bottom: int = 0
			for y: int in range(region.position.y, region.end.y):
				for x: int in range(region.position.x, region.end.x):
					if atlas_image.get_pixel(x, y).a >= sprite.alpha_scissor_threshold:
						visible_pixels += 1
						bottom = maxi(bottom, y - region.position.y + 1)
						_check(x > region.position.x and x < region.end.x - 1 and y > region.position.y and y < region.end.y - 1, "Visible silhouette clipped by frame")
			_check(visible_pixels > 1000, "Empty or incomplete player pose")
			_check(is_equal_approx(float(bottom) + frame.margin.position.y, 300.0 if column < 4 else 316.0), "Player feet must share a baseline")
	var directions: Array[Vector2] = INPUTS
	for column: int in range(DIRECTIONS.size()):
		player.set("_walk_time", 0.0)
		for row: int in range(4):
			player.call("_update_sprite", directions[column], Vector3.FORWARD, 0.0 if row == 0 else 0.125)
			_check(sprite.animation == DIRECTIONS[column] and sprite.frame == row, "Wrong player animation selection")
			_check(is_equal_approx(sprite.offset.y, 140.0) and is_equal_approx(sprite.position.y, 0.012), "Walking frame changed grounded pivot")
			_check(is_zero_approx(sprite.rotation.z), "Walking frame introduced artificial lean")
		player.call("_update_sprite", Vector2.ZERO, Vector3.ZERO, 0.1)
		_check(sprite.animation == DIRECTIONS[column] and sprite.frame == 0, "Idle must retain facing and reset pose")
	# Analog samples on either side of the diagonal sector boundaries.
	var angles: Array[float] = [20.0, 25.0, 65.0, 70.0, -20.0, -25.0, -65.0, -70.0]
	var expected: Array[StringName] = [&"right", &"down_right", &"down_right", &"down", &"right", &"up_right", &"up_right", &"up"]
	for index: int in range(angles.size()):
		player.call("_update_sprite", Vector2.RIGHT.rotated(deg_to_rad(angles[index])) * 0.6, Vector3.FORWARD, 0.125)
		_check(sprite.animation == expected[index], "Analog facing sector is incorrect")
	# Switching gear mid-stride must preserve a diagonal's direction and phase.
	var state := root.get_node("GameState")
	var original_gear: Dictionary = state.get("equipped").duplicate()
	for gear: Dictionary in [{"weapon": "moonsteel_saber"}, {"armor": "moonward_cloak"}, {"weapon": "moonsteel_saber", "armor": "moonward_cloak"}, original_gear]:
		player.set("_walk_time", 1.0)
		player.call("_update_sprite", Vector2(-1, -1), Vector3.FORWARD, 0.0)
		state.set("equipped", gear)
		state.emit_signal("state_changed")
		_check(sprite.animation == &"up_left" and sprite.frame == 1, "Equipment switch lost diagonal stride")
		var art := sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
		var ground: float = preload("res://scripts/gameplay/sprite_grounding.gd").foot_baseline(art)
		_check(is_equal_approx(ground - art.get_height() * 0.5, sprite.offset.y), "Equipment switch moved feet")
	# A correct atlas alone does not prove camera-relative presentation: project
	# actual computed movement onto the screen at all eight orbit orientations.
	var camera := Camera3D.new()
	root.add_child(camera)
	camera.current = true
	for orbit: int in range(8):
		camera.position = Basis(Vector3.UP, deg_to_rad(float(orbit) * 45.0)) * Vector3(0, 4, 6)
		camera.look_at(Vector3.ZERO)
		for index: int in range(directions.size()):
			var movement: Vector3 = player.call("_camera_relative_direction", directions[index])
			_check(is_equal_approx(movement.length(), 1.0) and is_zero_approx(movement.y), "Orbit movement must remain normalized on ground")
			var projected := camera.unproject_position(movement) - camera.unproject_position(Vector3.ZERO)
			_check(projected.normalized().dot(directions[index].normalized()) > (0.99 if index < 4 else 0.95), "Camera orbit reversed screen-relative movement")
			player.call("_update_sprite", directions[index], movement, 0.125)
			_check(sprite.animation == DIRECTIONS[index], "Camera orbit selected wrong character facing")
		_check((player.call("_camera_relative_direction", Vector2.ZERO) as Vector3).is_zero_approx(), "Idle acquired orbit movement")
	await _check_live_walk(player, sprite, camera)
	camera.queue_free()
	player.queue_free()
	await process_frame
	for singleton: String in ["GameAudio", "GameMusic", "GameAmbience"]:
		root.get_node(singleton).call("stop_all")
	await create_timer(0.25).timeout
	if _failures == 0:
		print("PLAYER_ART_TEST_PASS atlas alpha directions walk idle grounded_pivots eight_camera_orbits live_input")
	quit(0 if _failures == 0 else 1)


func _check_live_walk(player: CharacterBody3D, sprite: AnimatedSprite3D, camera: Camera3D) -> void:
	var floor := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(20, 1, 20)
	collision.shape = shape
	collision.position.y = -0.5
	floor.add_child(collision)
	root.add_child(floor)
	var actions: Array[Array] = [[&"move_back"], [&"move_forward"], [&"move_left"], [&"move_right"], [&"move_back", &"move_left"], [&"move_back", &"move_right"], [&"move_forward", &"move_left"], [&"move_forward", &"move_right"]]
	root.get_node("GameState").call("set_mode", 0)
	for yaw: float in [0.0, 225.0]:
		camera.position = Basis(Vector3.UP, deg_to_rad(yaw)) * Vector3(0, 4, 6)
		camera.look_at(Vector3.ZERO)
		for direction: int in range(DIRECTIONS.size()):
			player.set_physics_process(false)
			player.position = Vector3(0, 0.03, 0)
			player.velocity = Vector3.ZERO
			player.set_physics_process(true)
			await _frames(8)
			var start := player.position
			var observed: Dictionary = {}
			for action: StringName in actions[direction]:
				Input.action_press(action)
			for frame: int in range(40):
				await _frames(1)
				observed[sprite.frame] = true
				_check(sprite.animation == DIRECTIONS[direction], "Live input selected wrong walking direction")
				_check(absf(player.position.y) < 0.02 and is_equal_approx(sprite.position.y, 0.012), "Live walk lifted roots off floor")
			for action: StringName in actions[direction]:
				Input.action_release(action)
			_check(is_equal_approx(Vector2(player.velocity.x, player.velocity.z).length(), player.get("move_speed")), "Diagonal input changed movement speed")
			_check(observed.size() == 4, "Live walk did not cycle through all four poses")
			var screen_travel := camera.unproject_position(player.position) - camera.unproject_position(start)
			var input := INPUTS[direction].normalized()
			_check(screen_travel.normalized().dot(input) > (0.99 if direction < 4 else 0.94), "Live movement and facing disagree after orbit")
			_check(player.position.distance_to(start) > 1.5, "Pose cycling without actual movement")
			await _frames(20)
			_check(sprite.frame == 0 and sprite.animation == DIRECTIONS[direction], "Input release did not restore facing idle")
	player.set_physics_process(false)
	floor.queue_free()


func _frames(count: int) -> void:
	for frame: int in range(count):
		await physics_frame
		await process_frame
