extends SceneTree
## Exercise real player transitions for every sex/class without writing saves.
var _failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures += 1
		push_error(message)


func _run() -> void:
	var state := root.get_node("GameState")
	var player := (load("res://scenes/player.tscn") as PackedScene).instantiate() as CharacterBody3D
	root.add_child(player)
	player.set_physics_process(false)
	var sprite := player.get_node("Sprite3D") as AnimatedSprite3D
	for body: String in ["male", "female"]:
		for vocation: String in ["traveler", "archer", "mage", "thief"]:
			state.reset_new_game(false, vocation, "original", body)
			var gear: Dictionary = state.equipped.duplicate(true)
			for map_id: String in ["village", "east_road", "starbay", "house_02", "house_city_01", "ruins", "village"]:
				state.current_map = map_id
				var town: bool = map_id in ["village", "starbay", "house_02", "house_city_01"] and (body == "female" or vocation != "traveler")
				for facing: Vector2 in [Vector2.DOWN, Vector2.RIGHT, Vector2.UP, Vector2.LEFT, Vector2(1, 1), Vector2(1, -1), Vector2(-1, -1), Vector2(-1, 1)]:
					for frame: int in range(4):
						player.call("_update_sprite", facing, Vector3.FORWARD, 0.125)
						var texture := sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame) as AtlasTexture
						_check(bool(texture.get_meta("town_unarmed", false)) == town, "%s %s %s walking art" % [body, vocation, map_id])
						_check(sprite.pixel_size > 0.0 and is_finite(sprite.offset.x), "Valid grounded pose")
					player.call("_update_sprite", Vector2.ZERO, Vector3.ZERO, 0.0)
					_check(sprite.frame == 0, "Idle resets walking frame")
				if town:
					for pose: int in range(2):
						player.set("_door_pose", pose)
						player.call("_update_sprite", Vector2.ZERO, Vector3.ZERO, 0.0)
						var texture := sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
						_check(bool(texture.get_meta("town_unarmed", false)), "Door gesture stays empty-handed")
					player.call("release_door_facing")
				_check(state.equipped == gear, "Presentation never changes equipped gear")
	player.queue_free()
	await process_frame
	if _failures == 0:
		print("TOWN_APPEARANCE_TEST_PASS classes bodies walking doors map_transitions equipment")
	quit(0 if _failures == 0 else 1)
