extends SceneTree
## Availability audit: report unique source facings separately from input support.
const Facing = preload("res://scripts/gameplay/eight_way_facing.gd")
const ActionArt = preload("res://scripts/gameplay/action_sprite_library.gd")
const Directions: Array[Vector2] = [Vector2.DOWN, Vector2.RIGHT, Vector2.UP, Vector2.LEFT, Vector2(1, 1), Vector2(1, -1), Vector2(-1, -1), Vector2(-1, 1)]
var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _signature(texture: AtlasTexture) -> String:
	if texture == null or texture.atlas == null or not texture.region.has_area():
		failures += 1
		push_error("Missing directional frame")
		return "missing"
	if not Rect2(Vector2.ZERO, texture.atlas.get_size()).encloses(texture.region):
		failures += 1
		push_error("Directional frame outside atlas")
	return "%s:%s:%s" % [texture.atlas.resource_path, texture.region, texture.get_meta("flip_h", false)]


func _run() -> void:
	var state: Node = root.get_node("GameState")
	var player := (load("res://scenes/player.tscn") as PackedScene).instantiate() as CharacterBody3D
	root.add_child(player)
	player.set_physics_process(false)
	var sprite := player.get_node("Sprite3D") as AnimatedSprite3D
	var combat_sprite := Sprite3D.new()
	for body: String in ["male", "female"]:
		for vocation: String in ["traveler", "archer", "mage", "thief"]:
			state.reset_new_game(false, vocation, "original", body)
			var counts: Array[String] = []
			for category: String in ["town_walk", "town_door", "field_walk"]:
				state.current_map = "east_road" if category == "field_walk" else "village"
				var signatures: Dictionary = {}
				for direction: Vector2 in Directions:
					var signature: String = ""
					for phase: int in range(2 if category == "town_door" else 4):
						player.set("_door_pose", phase if category == "town_door" else -1)
						player.set("_walk_time", float(phase))
						player.call("_update_sprite", direction, Vector3.FORWARD, 0.0)
						if category == "field_walk":
							signature += _signature(ActionArt.directional_texture("wanderer", ["idle", "walk_a", "idle", "walk_b"][phase], direction, combat_sprite, state.get_visual_loadout()))
						else:
							# Door gestures keep the already selected direction.
							if category == "town_door":
								player.set("_facing_column", Facing.direction_index(direction))
								player.call("_update_sprite", Vector2.ZERO, Vector3.ZERO, 0.0)
							signature += _signature(sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame) as AtlasTexture)
						if sprite.animation != Facing.ANIMATIONS[Facing.direction_index(direction)]:
							failures += 1
							push_error("Input direction did not select the matching animation")
					signatures[signature] = true
				counts.append("%s=%d/8" % [category, signatures.size()])
			player.set("_door_pose", -1)
			var combat_counts: Array[String] = []
			for pose: String in ActionArt.POSES:
				if pose in ["idle", "walk_a", "walk_b"]:
					continue
				var signatures: Dictionary = {}
				for direction: Vector2 in Directions:
					signatures[_signature(ActionArt.directional_texture("wanderer", pose, direction, combat_sprite, state.get_visual_loadout()))] = true
				combat_counts.append("%s:%d" % [pose, signatures.size()])
			print("DIRECTION_AUDIT %s/%s %s combat={%s}" % [body, vocation, ", ".join(counts), ", ".join(combat_counts)])
	combat_sprite.free()
	player.queue_free()
	for singleton: String in ["GameAudio", "GameMusic", "GameAmbience"]:
		root.get_node(singleton).call("stop_all")
	await create_timer(0.25).timeout
	if failures == 0:
		print("HERO_DIRECTION_AUDIT_PASS frame_availability_only; counts below 8 mean shared directional art")
	quit(0 if failures == 0 else 1)
