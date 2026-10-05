extends SceneTree
## Landed field hits freeze, flash, shake and sound; never writes a save.

var _cues: Array[StringName] = []

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var state: Node = root.get_node("GameState")
	root.get_node("GameAudio").cue_played.connect(func(cue: StringName) -> void: _cues.append(cue))
	state.reset_new_game(false)
	state.flags.intro_seen = true
	var world: Node3D = load("res://scenes/main.tscn").instantiate()
	root.add_child(world)
	world.set("_test_mode", true)
	world.call("_load_map", "east_road", "from_village")
	var player: CharacterBody3D = world.get_node("Player")
	player.set_physics_process(false)
	var rig: Node3D = world.get_node("CameraRig")
	var field: Node3D = world.get("_map_root").get_node("FieldCombat")
	while not field.ready_for_combat:
		await physics_frame
	field.set_physics_process(false)
	var enemy: Dictionary = field.enemies[0]
	var sprite: Sprite3D = enemy.sprite
	var HitFeedback: GDScript = load("res://scripts/gameplay/hit_feedback.gd")

	# Heavier, skill and lethal hits hold longer and shake harder, within bounds.
	var light: float = HitFeedback.stop_time(10, 100, false, false)
	var heavy: float = HitFeedback.stop_time(40, 100, false, false)
	var skill: float = HitFeedback.stop_time(10, 100, true, false)
	var lethal: float = HitFeedback.stop_time(1, 100, false, true)
	assert(light > 0.0 and light < heavy and light < skill and lethal >= 0.10)
	assert(HitFeedback.stop_time(999, 1, true, true) <= 0.12, "Hit stop stays brief")
	assert(HitFeedback.shake_strength(10, 100, false, false) < HitFeedback.shake_strength(10, 100, true, false))
	assert(is_equal_approx(HitFeedback.after_stop(0.05, 0.3), 0.25), "Freeze never swallows real time")
	assert(HitFeedback.after_stop(0.05, 0.016) == 0.0)

	# A melee basic hit: attacker and target both freeze; the target flashes and shivers.
	state.player_class = "traveler"
	enemy.body.position = enemy.home
	player.global_position = enemy.body.global_position + Vector3(0, 0, -1.0)
	field.attack_direction = Vector3(0, 0, 1)
	field.skill_pending = false
	field.attack_cooldown = 0.5
	_cues.clear()
	field._strike()
	assert(_cues.has(&"slash") and _cues.has(&"impact"), "Swing and contact have separate cues")
	assert(_cues.count(&"impact") == 1)
	assert(float(enemy.hit_stop) > 0.0 and field.hit_stop > 0.0)
	assert(float(rig.get("_impact_strength")) > 0.0, "Contact shakes the camera")
	var held_at: Vector3 = enemy.body.global_position
	var swing: float = field.swing
	var cooldown: float = field.attack_cooldown
	field._physics_process(0.016)
	assert(enemy.body.global_position.is_equal_approx(held_at), "Held enemies do not move")
	assert(sprite.material_overlay != null, "Contact briefly blends white")
	assert(HitFeedback.FLASH_TIME <= 0.035, "Flash lasts at most half the old 70ms")
	HitFeedback.apply_flash(sprite, 10.0)
	assert(is_equal_approx(sprite.material_overlay.get_shader_parameter("flash"), 0.65), "Even saturated flash retains 35% actor color")
	field._advance_enemy(enemy, 0.025)
	assert(float(enemy.hit_stop) > 0.0 and sprite.material_overlay == null, "Flash expires independently during hit stop")
	assert(not Vector2(sprite.position.x, sprite.position.z).is_zero_approx(), "Held enemies shiver")
	assert(field.swing == swing, "The attacker's swing pose holds")
	assert(field.attack_cooldown < cooldown, "Cooldowns keep running through hit stop")
	assert(field.movement_velocity(Vector3(1, 0, 0) * 4.0, 0.016).is_zero_approx(), "Attacker footing holds")
	for frame: int in range(20):
		field._physics_process(0.016)
	assert(float(enemy.hit_stop) == 0.0 and field.hit_stop == 0.0)
	assert(sprite.material_overlay == null, "Flash overlay is removed after the hit")
	assert(Vector2(sprite.position.x, sprite.position.z).is_zero_approx(), "Shiver leaves no offset")
	assert(is_zero_approx(rig.get_node("Camera3D").h_offset) or float(rig.get("_impact_left")) == 0.0)

	# Dodging cancels the attacker's freeze.
	field.hit_stop = 0.1
	field.dodge_cooldown = 0.0
	field.windup = 0.0
	field.attack_cooldown = 0.0
	assert(field.perform("dodge") and field.hit_stop == 0.0)
	field.dodge_time = 0.0

	# Ranged hits freeze the target only.
	state.player_class = "mage"
	enemy.hit_stop = 0.0
	field.hit_stop = 0.0
	_cues.clear()
	field._damage_enemy(enemy, 1)
	assert(float(enemy.hit_stop) > 0.0 and field.hit_stop == 0.0)

	# Enemy hits on the player also land with sound and shake.
	rig.call("advance_combat_feedback", 1.0)
	field.invulnerable = 0.0
	enemy.aim = player.global_position
	enemy.body.global_position = player.global_position + Vector3(0, 0, 0.8)
	enemy.charged_attack = true
	_cues.clear()
	var hp: int = state.player_hp
	field._enemy_strike(enemy)
	assert(state.player_hp < hp and _cues.has(&"impact") and float(rig.get("_impact_strength")) > 0.0)

	# Leaving the field clears any residual camera offset.
	world.get("_map_root").queue_free()
	await process_frame
	await process_frame
	var camera: Camera3D = rig.get_node("Camera3D")
	assert(is_zero_approx(camera.h_offset) and is_zero_approx(camera.v_offset))
	print("HIT_FEEDBACK_TEST_PASS scaling freeze flash shiver cues shake dodge_cancel ranged player_hit cleanup")
	quit()
