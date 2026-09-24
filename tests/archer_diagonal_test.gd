extends SceneTree
## Exercise the actual male archer player and both bow tiers without writing saves.
const ClassArt = preload("res://scripts/gameplay/class_art.gd")
const ActionArt = preload("res://scripts/gameplay/action_sprite_library.gd")
const INPUTS: Array[Vector2] = [Vector2(-1, 1), Vector2(1, 1), Vector2(-1, -1), Vector2(1, -1)]
const DIRECTIONS: Array[StringName] = [&"down_left", &"down_right", &"up_left", &"up_right"]
var failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)


func _run() -> void:
	var state := root.get_node("GameState")
	state.call("reset_new_game", false, "archer")
	state.set("current_map", "east_road") # Armed exploration atlas; towns have empty-handed art.
	var player := (load("res://scenes/player.tscn") as PackedScene).instantiate() as CharacterBody3D
	root.add_child(player)
	player.set_physics_process(false)
	var sprite := player.get_node("Sprite3D") as AnimatedSprite3D
	var combat_sprite := Sprite3D.new()
	for weapon: String in ["willow_bow", "moonstring_bow"]:
		state.get("equipped")["weapon"] = weapon
		state.emit_signal("state_changed")
		for direction: int in range(DIRECTIONS.size()):
			var pivot: float = 0.0
			var scale: float = 0.0
			for frame: int in range(4):
				player.set("_walk_time", float(frame))
				player.call("_update_sprite", INPUTS[direction], Vector3.FORWARD, 0.0)
				var texture := sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame) as AtlasTexture
				check(sprite.animation == DIRECTIONS[direction] and sprite.frame == frame, "Archer direction or phase lost")
				check(texture.atlas.resource_path.ends_with("classes/archer_diagonal_walk.png"), "Archer fell back to cardinal or traveler art")
				check(texture.get_meta("direction") == DIRECTIONS[direction], "Wrong diagonal crop")
				check(texture.get_meta("pose") == ["idle", "walk_a", "idle", "walk_b"][frame], "Wrong stride order")
				check(is_equal_approx(sprite.offset.y, texture.get_height() * 0.5) and is_equal_approx(sprite.position.y, 0.012), "Archer feet lost ground contact")
				var source_pivot := texture.region.position.x + float(texture.get_meta("anchor_x"))
				if frame == 0:
					pivot = source_pivot
					scale = sprite.pixel_size
				check(is_equal_approx(pivot, source_pivot) and is_equal_approx(scale, sprite.pixel_size), "Stride changes body pivot or scale")
				check(Rect2(Vector2.ZERO, texture.atlas.get_size()).encloses(texture.region), "Archer crop outside atlas")
				var combat_art := ActionArt.directional_texture("wanderer", str(texture.get_meta("pose")), INPUTS[direction], combat_sprite, state.call("get_visual_loadout"))
				check(combat_art == texture and combat_art.has_meta("pixel_size"), "Field/arena walking did not use the same diagonal art")
			player.call("_update_sprite", Vector2.ZERO, Vector3.ZERO, 0.1)
			check(sprite.animation == DIRECTIONS[direction] and sprite.frame == 0, "Archer idle lost diagonal facing")
	# Door poses retain the separate existing cast/release art.
	var doors := ClassArt.walking_frames(state.call("get_visual_loadout"), true)
	check(doors.get_frame_count(&"down_left") == 2 and doors.get_frame_texture(&"down_left", 0).get_meta("pose") == "cast", "Walking repair replaced door gestures")
	# Sex selection must continue to use the heroine's own art.
	var female := ClassArt.walking_frames({"weapon": "willow_bow", "hero_body": "female"})
	check(female.get_frame_texture(&"down_left", 1).get_meta("variant") == "class_female_archer", "Male repair changed female identity")
	var attack := ActionArt.directional_texture("wanderer", "attack", INPUTS[0], combat_sprite, state.call("get_visual_loadout"))
	check(attack.atlas.resource_path.ends_with("classes/archer.png") and attack.get_meta("pose") == "attack", "Walk repair replaced bow attack")
	combat_sprite.free()
	player.queue_free()
	for singleton: String in ["GameAudio", "GameMusic", "GameAmbience"]:
		root.get_node(singleton).call("stop_all")
	await create_timer(0.25).timeout
	if failures == 0:
		print("ARCHER_DIAGONAL_TEST_PASS male four_facings two_bows phases pivots scale idle doors female_identity")
	quit(0 if failures == 0 else 1)
