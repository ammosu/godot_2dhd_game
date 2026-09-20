extends SceneTree

const Grounding = preload("res://scripts/gameplay/sprite_grounding.gd")
var _failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)


func _check_pivot(sprite: SpriteBase3D, texture: Texture2D) -> void:
	var feet_y := (float(texture.get_height()) * 0.5 - Grounding.foot_baseline(texture, sprite.alpha_scissor_threshold) + sprite.offset.y) * sprite.pixel_size
	_check(absf(feet_y) < 0.001, "Visible feet must coincide with billboard pivot")
	_check(sprite.position.y >= 0.0 and sprite.position.y < 0.1, "Character pivot must sit on surface, not at body center")
	_check(sprite.get_parent().get_node_or_null("ContactShadow") != null, "Character lacks ground contact shadow")
	_check(sprite.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "Billboard card shadow would detach from feet")


func _run() -> void:
	var state := root.get_node("GameState")
	state.get("flags")["intro_seen"] = true
	var world := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(world)
	var player := world.get_node("Player") as CharacterBody3D
	player.position = Vector3(0.0, 0.2, 0.0)
	state.call("set_mode", 1)
	for frame: int in range(60):
		await physics_frame
	_check(player.is_on_floor(), "Player did not settle on plaza")
	_check(absf(player.position.y - 0.006) < 0.005, "Player stands above visual plaza due to collision mismatch")
	player.set_physics_process(false)
	var sprite := player.get_node("Sprite3D") as AnimatedSprite3D
	for animation: StringName in sprite.sprite_frames.get_animation_names():
		for frame: int in range(sprite.sprite_frames.get_frame_count(animation)):
			_check_pivot(sprite, sprite.sprite_frames.get_frame_texture(animation, frame))
	for step: int in range(16):
		player.call("_update_sprite", Vector2.RIGHT, Vector3.RIGHT, 0.1)
		_check(is_equal_approx(sprite.position.y, 0.012), "Walking must not lift foot pivot")
	_check(get_nodes_in_group("grounded_character_art").size() == 4, "Village requires player plus three grounded NPCs")
	for node: Node in get_nodes_in_group("grounded_character_art"):
		if node is Sprite3D:
			_check_pivot(node as Sprite3D, (node as Sprite3D).texture)
	world.call("_load_map", "ruins", "from_village")
	await process_frame
	_check(get_nodes_in_group("grounded_character_art").size() == 2, "Village character art leaked into ruins")
	for node: Node in get_nodes_in_group("grounded_character_art"):
		if node is Sprite3D:
			_check_pivot(node as Sprite3D, (node as Sprite3D).texture)
	world.queue_free()
	await process_frame
	if _failures == 0:
		print("GROUNDING_TEST_PASS feet_pivots all_walk_frames npc guardian plaza_collision")
	quit(0 if _failures == 0 else 1)
