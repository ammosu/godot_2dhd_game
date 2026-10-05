extends SceneTree
## Projected floating text and melee spacing regressions.
var failures: int = 0

func _initialize() -> void:
	_run.call_deferred()

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _run() -> void:
	var state: Node = root.get_node("GameState")
	state.reset_new_game(false)
	state.flags.intro_seen = true
	var world: Node3D = load("res://scenes/main.tscn").instantiate()
	root.add_child(world)
	world.set("_test_mode", true)
	world._load_map("east_road", "from_village")
	var field: Node3D = world._map_root.get_node("FieldCombat")
	while not field.ready_for_combat:
		await physics_frame
	field.set_physics_process(false)
	var player: CharacterBody3D = world.get_node("Player")
	player.set_physics_process(false)
	var camera: Camera3D = root.get_camera_3d()
	var first: Dictionary = field.enemies[0]
	var second: Dictionary = field.enemies[1]
	for enemy: Dictionary in field.enemies:
		enemy.hp = 0
	first.hp = 100
	second.hp = 100
	first.body.global_position = Vector3(0, 1, 0)
	second.body.global_position = first.body.global_position
	field._art(first.sprite, first.art, "idle", Vector3.FORWARD)
	field._art(second.sprite, second.art, "idle", Vector3.FORWARD)
	second.sprite.pixel_size *= 1.25
	var required_gap: float = maxf(1.1, (field._sprite_width(first.sprite) + field._sprite_width(second.sprite)) * 0.5 + 0.12)
	# Integrate the steering against converging chase velocities.
	for frame: int in range(180):
		var a: Vector3 = field._separate_enemy_velocity(first, Vector3.LEFT * 2.0)
		var b: Vector3 = field._separate_enemy_velocity(second, Vector3.RIGHT * 2.0)
		first.body.global_position += a / 60.0
		second.body.global_position += b / 60.0
	check(first.body.global_position.distance_to(second.body.global_position) >= required_gap - 0.01, "coincident melee enemies separate by their actual unequal sprite widths")
	second.hp = 0
	check(field._separate_enemy_velocity(first, Vector3.RIGHT).is_equal_approx(Vector3.RIGHT), "dead enemies do not repel")

	player.global_position = Vector3(-4, 0.05, 10)
	var first_goal: Vector3 = field._approach_position(first, player.global_position)
	var second_goal: Vector3 = field._approach_position(second, player.global_position)
	check(first_goal.distance_to(second_goal) > 1.0, "Enemy index assigns distinct approach lanes")
	var original_art: String = second.art
	second.art = "dusk_bat"
	check(field._approach_position(second, player.global_position).distance_to(player.global_position) >= 1.6 - 0.001, "Flying enemy stands 1.6m away")
	second.art = original_art
	for zoom: float in [8.0, 18.0, 28.0]:
		camera.size = zoom
		for index: int in range(12):
			# Different world origins can occupy the same projected location.
			field._number(player.global_position + camera.global_basis.z * float(index) * 0.2, "回復 +12" if index % 2 else "17", Color.WHITE)
		for angle: int in [0, 45, 135]:
			camera.global_position = player.global_position + Vector3(0, 10, 12).rotated(Vector3.UP, deg_to_rad(float(angle)))
			camera.look_at(player.global_position)
			field._space_numbers()
			for i: int in range(field._numbers.size()):
				for j: int in range(i):
					var a: Vector2 = camera.unproject_position(field._numbers[i].node.global_position)
					var b: Vector2 = camera.unproject_position(field._numbers[j].node.global_position)
					check(a.distance_to(b) >= 27.99, "concurrent damage and healing stay 28px apart through zoom/orbit")
		for number: Dictionary in field._numbers:
			number.node.free()
		field._numbers.clear()
	# Projected bars separate only while their actual screen bounds overlap.
	var bars: Array[Node] = [first.bar, second.bar]
	first.bar.set_health(100, 100)
	second.bar.set_health(100, 100)
	first.body.global_position = player.global_position
	second.body.global_position = first.body.global_position
	for projection: int in [Camera3D.PROJECTION_PERSPECTIVE, Camera3D.PROJECTION_ORTHOGONAL]:
		camera.projection = projection
		first.bar.space_bars(bars, camera)
		check(first.bar.screen_offset.is_zero_approx() and second.bar.screen_offset.y < -4.0, "overlapping health bars separate vertically")
		var initial: Vector2 = second.bar.screen_offset
		first.bar.space_bars(bars, camera)
		check(second.bar.screen_offset.is_equal_approx(initial), "health bar offsets never accumulate")
		second.body.global_position += camera.global_basis.x * 4.0
		first.bar.space_bars(bars, camera)
		check(second.bar.screen_offset.is_zero_approx(), "separated health bars immediately return to actor anchors")
		second.body.global_position = first.body.global_position
	field._update_readability()
	first.label.show()
	first.label.text = "苔原狼"
	field._number(first.body.global_position, "槍 18", Color("9fd4ff"), &"noah")
	field._space_numbers()
	var name_bounds: Rect2 = first.label.get_meta("layout_bounds")
	var number_bounds: Rect2 = field._numbers[0].node.get_meta("layout_bounds")
	check(not name_bounds.intersects(number_bounds), "Enemy name and damage share avoidance rectangles")
	bars.reverse()
	var occupied: Array[Rect2] = first.bar.space_bars(bars, camera)
	for bounds: Rect2 in occupied:
		check(not bounds.intersects(name_bounds) and not bounds.intersects(number_bounds), "Bars, names and damage never overlap")
	check(field._numbers[0].node.text == "槍 18" and field._numbers[0].node.modulate == Color("9fd4ff"), "Noah keeps blue spear source")
	world.queue_free()
	await process_frame
	if failures == 0:
		print("FIELD_READABILITY_TEST_PASS separation projected_numbers zoom orbit")
	quit(0 if failures == 0 else 1)
