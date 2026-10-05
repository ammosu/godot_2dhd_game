extends SceneTree
## Exercise real player transitions for every sex/class without writing saves.
const ClassArt = preload("res://scripts/gameplay/class_art.gd")
const TownAppearance = preload("res://scripts/gameplay/town_appearance.gd")
const SIDES: Dictionary = {"up_left": "left", "down_left": "left", "up_right": "right", "down_right": "right"}
var _failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures += 1
		push_error(message)


## Diagonals without a "<id>_diagonal" supplement reuse the side profile, never
## the back view; supplied supplements are used for all four diagonals.
func _check_profile_fallback(texture: AtlasTexture, direction: String, loadout: Dictionary, frame: int) -> void:
	if not SIDES.has(direction):
		return
	var id := ClassArt.vocation(loadout)
	var supplement := TownAppearance.diagonal_source(id)
	var side := TownAppearance.frames(loadout).get_frame_texture(StringName(SIDES[direction]), frame) as AtlasTexture
	if supplement.is_empty():
		_check(texture.atlas == side.atlas and texture.region == side.region, "%s %s must fall back to the side profile" % [id, direction])
	else:
		_check(texture.atlas == supplement.sheet and texture.get_meta("direction") == direction, "%s %s ignored its diagonal supplement" % [id, direction])


func _run() -> void:
	var state := root.get_node("GameState")
	var player := (load("res://scenes/player.tscn") as PackedScene).instantiate() as CharacterBody3D
	root.add_child(player)
	player.set_physics_process(false)
	var sprite := player.get_node("Sprite3D") as AnimatedSprite3D
	var legacy := OS.get_cmdline_user_args().has("--legacy-hero")
	_check(TownAppearance.diagonal_source("missing_supplement").is_empty(), "Missing diagonal sheets must no-op")
	_check(not TownAppearance.diagonal_source("archer").is_empty(), "Archer diagonal supplement is data-driven")
	for body: String in ["male", "female"]:
		for vocation: String in ["traveler", "archer", "mage", "thief"]:
			state.reset_new_game(false, vocation, "original", body)
			var gear: Dictionary = state.equipped.duplicate(true)
			for map_id: String in ["village", "east_road", "starbay", "house_02", "house_city_01", "ruins", "village"]:
				state.current_map = map_id
				# Every exploration map is sheathed; only combat actors draw weapons.
				var town: bool = body == "female" or vocation != "traveler"
				for facing: Vector2 in [Vector2.DOWN, Vector2.RIGHT, Vector2.UP, Vector2.LEFT, Vector2(1, 1), Vector2(1, -1), Vector2(-1, -1), Vector2(-1, 1)]:
					for frame: int in range(4):
						player.call("_update_sprite", facing, Vector3.FORWARD, 0.125)
						var texture := sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame) as AtlasTexture
						# Exploration walks with each class's rigged repaint (--legacy-hero
						# restores the hand-painted town atlases checked below).
						var rigged := str(texture.get_meta("variant", "")).begins_with("blender_")
						if legacy:
							_check(bool(texture.get_meta("town_unarmed", false)) == town, "%s %s %s walking art" % [body, vocation, map_id])
							if town:
								_check_profile_fallback(texture, str(sprite.animation), state.call("get_visual_loadout"), sprite.frame)
						else:
							var id := ClassArt.vocation(state.call("get_visual_loadout"))
							_check(rigged and texture.get_meta("variant") == "blender_%s_painted" % ("wanderer" if id.is_empty() else id), "%s %s %s rigged walking art" % [body, vocation, map_id])
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
		print("TOWN_APPEARANCE_TEST_PASS classes bodies walking doors map_transitions equipment profile_diagonals")
	quit(0 if _failures == 0 else 1)
