extends SceneTree
## Real field sprite: diagonal input must not oscillate between cardinal atlases.
const Facing = preload("res://scripts/gameplay/eight_way_facing.gd")
const Art = preload("res://scripts/gameplay/action_sprite_library.gd")
const INPUTS: Array[Vector2] = [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]
const COLUMNS: Array[int] = [1, 3, 2, 2]
var failures: int = 0

func _initialize() -> void:
	_run.call_deferred()

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		if failures <= 8:
			push_error(message)

func _run() -> void:
	var state: Node = root.get_node("GameState")
	state.reset_new_game(false)
	state.flags.intro_seen = true
	var world: Node3D = load("res://scenes/main.tscn").instantiate()
	root.add_child(world)
	world.set("_test_mode", true)
	world.call("_load_map", "east_road", "from_village")
	var player: CharacterBody3D = world.get_node("Player")
	player.set_physics_process(false)
	var field: Node3D = world.get("_map_root").get_node("FieldCombat")
	while not field.ready_for_combat:
		await physics_frame
	field.set_physics_process(false)
	field.automation.set_enabled(false, field)
	var rig: Node3D = world.get_node("CameraRig")
	rig.set_process(false)
	var sprite: Sprite3D = field.get("_hero_sprite")
	for vocation: String in ["traveler", "archer", "mage", "thief"]:
		for body: String in ["male", "female"]:
			state.reset_new_game(false, vocation, "original", body)
			state.current_map = "east_road"
			for yaw: float in [-35.0, 0.0, 45.0]:
				rig.set("_target_yaw", deg_to_rad(yaw))
				rig.call("snap_to_target")
				for index: int in range(INPUTS.size()):
					for epsilon: float in [-0.00001, 0.0, 0.00001]:
						var input: Vector2 = INPUTS[index] + Vector2(epsilon, 0)
						var direction: Vector3 = player.call("_camera_relative_direction", input)
						player.velocity = field.movement_velocity(direction * 4.2)
						for phase: int in range(4):
							field.clock = float(phase) * 0.1
							field.call("_update_hero_art")
							var texture: AtlasTexture = sprite.texture
							var label := "%s/%s yaw=%s input=%s phase=%s" % [vocation, body, yaw, input, phase]
							if vocation == "archer" and body == "male":
								check(texture.get_meta("direction", &"") == Facing.ANIMATIONS[Facing.direction_index(INPUTS[index])], "Diagonal archer changed direction: " + label)
							else:
								var expected: AtlasTexture = Art.texture_for("wanderer", str(texture.get_meta("pose")), COLUMNS[index], state.get_visual_loadout())
								check(texture == expected, "Field flashed a different cardinal atlas: " + label)
							check(sprite.visible and not player.get_node("Sprite3D").visible, "Duplicate player sprite: " + label)
	world.queue_free()
	await process_frame
	for singleton: String in ["GameAudio", "GameMusic", "GameAmbience"]:
		root.get_node(singleton).call("stop_all")
	await create_timer(0.2).timeout
	if failures == 0:
		print("FIELD_DIRECTION_TEST_PASS four_classes both_bodies four_diagonals camera_yaws float_jitter walk_phases single_sprite")
	else:
		print("FIELD_DIRECTION_TEST_FAILURES ", failures)
	quit(0 if failures == 0 else 1)
