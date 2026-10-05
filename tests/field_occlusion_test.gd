extends SceneTree
## Occluded traveler, target attachment, status lifetime and actual sprite widths.
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
	field.set_process(false)
	var player: CharacterBody3D = world.get_node("Player")
	player.set_physics_process(false)
	world.get_node("CameraRig").set_process(false)
	world.get_node("CameraRig").set_physics_process(false)
	var camera: Camera3D = root.get_camera_3d()
	player.global_position = Vector3(0, 0.05, 10)
	camera.global_position = player.global_position + Vector3(0, 4, 10)
	camera.look_at(player.global_position + Vector3.UP)
	var first: Dictionary = field.enemies[0]
	var second: Dictionary = field.enemies[1]
	for enemy: Dictionary in field.enemies:
		enemy.hp = 0
	first.hp = 72
	second.hp = 72
	second.body.global_position = player.global_position + Vector3.RIGHT * 6.0
	field._draw_weapon(false)
	field._update_hero_art()
	field._art(first.sprite, first.art, "idle", Vector3.FORWARD)
	first.body.global_position = player.global_position + camera.global_basis.z * 0.3
	field._update_hero_outline()
	check(is_instance_valid(field._hero_outline) and field._hero_outline.visible, "Foreground overlapping enemy reveals traveler outline")
	if is_instance_valid(field._hero_outline):
		check(field._hero_outline.texture == field._hero_sprite.texture, "Outline follows current actor frame")
		check("depth_test_disabled" in field._hero_outline.material_override.shader.code, "Outline renders through foreground sprite")
	first.body.global_position = player.global_position - camera.global_basis.z * 0.3
	field._update_hero_outline()
	check(not field._hero_outline.visible, "Background overlapping enemy never reveals outline")
	first.body.global_position = player.global_position + camera.global_basis.x * 4.0
	field._update_hero_outline()
	check(not field._hero_outline.visible, "Separated sprite hides outline")
	first.body.global_position = player.global_position + camera.global_basis.z * 0.3
	state.set_mode(state.Mode.DIALOGUE)
	field._update_hero_outline()
	check(not field._hero_outline.visible, "Dialogue hides combat outline")
	state.set_mode(state.Mode.EXPLORE)
	field._relax_now()
	field._update_hero_art()
	field._update_hero_outline()
	check(field._hero_outline.visible and field._hero_outline.texture == field._visual_texture(player.get_node("Sprite3D")), "Relaxed animated traveler also gets a synchronized outline")
	var width: float = field._sprite_width(first.sprite)
	first.sprite.pixel_size *= 2.0
	check(is_equal_approx(field._sprite_width(first.sprite), width * 2.0), "Spacing derives from actual texture pixels and pixel_size")
	check(field._contact_spacing(first) > width, "Wider enemy reserves enough traveler clearance")
	first.sprite.pixel_size *= 0.5
	field._update_readability()
	check(first.label.visible and not second.label.visible, "Only nearest target displays its name")
	field._damage_enemy(second, 1)
	field._update_readability()
	check(second.label.visible and not first.label.visible, "Last attacked target takes name priority")
	second.label.text = second.title
	second.bar.set_health(second.hp, second.max_hp)
	for zoom: float in [8.0, 18.0, 28.0]:
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = zoom
		field._space_numbers()
		var bar_at: Vector2 = camera.unproject_position(second.bar.get_child(0).global_position)
		var name_at: Vector2 = camera.unproject_position(second.label.global_position)
		check(absf(bar_at.x - name_at.x) < 0.01 and bar_at.y > name_at.y and bar_at.distance_to(name_at) <= 28.01, "Target name remains directly above its bar within 28px")
	first.slow = 1.0
	field._update_status_markers()
	check(first.slow_label.visible and first.slow_label.text == "緩" and first.slow_marker.visible, "Slow shows a distinct overhead symbol and ground ring")
	first.slow = 0.0
	field._update_status_markers()
	check(not first.slow_label.visible and not first.slow_marker.visible, "Expired slow clears both marks")
	first.slow = 2.0
	field._update_status_markers()
	check(first.slow_label.visible, "Refreshed slow restores the symbol")
	first.hp = 0
	second.hp = 0
	field._update_readability()
	check(not first.slow_label.visible and not second.label.visible, "Death clears status and target name")
	world.queue_free()
	await process_frame
	if failures == 0:
		print("FIELD_OCCLUSION_TEST_PASS outline flash_target status sprite_width")
	quit(0 if failures == 0 else 1)
