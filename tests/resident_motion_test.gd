extends SceneTree
## All eight identities, real household interactions, orbit and walk transitions.
var Art: GDScript
const Facing = preload("res://scripts/gameplay/eight_way_facing.gd")
const Grounding = preload("res://scripts/gameplay/sprite_grounding.gd")
const HEADINGS: Array[Vector3] = [Vector3.BACK, Vector3.FORWARD, Vector3.LEFT, Vector3.RIGHT,
	Vector3(-1, 0, 1), Vector3(1, 0, 1), Vector3(-1, 0, -1), Vector3(1, 0, -1)]
var failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)


func _run() -> void:
	# --script loads before autoload names exist; defer the actor script load.
	Art = load("res://scripts/gameplay/resident_art.gd") as GDScript
	var state := root.get_node("GameState")
	state.call("reset_new_game", false)
	state.get("flags")["intro_seen"] = true
	var world := (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(world)
	world.set("_test_mode", true)
	var player := world.get_node("Player") as CharacterBody3D
	player.set_physics_process(false)
	var rig := world.get_node("CameraRig") as Node3D
	rig.set_process(false)
	var camera := rig.get_node("Camera3D") as Camera3D
	var roster: Array[String] = []
	for villager: Node in get_nodes_in_group("wandering_villagers"):
		var identity: String = villager.get("resident_id")
		check(identity in Art.IDENTITIES and identity not in roster, "Patrol identity must be distinct original resident")
		roster.append(identity)
		check(villager.get_node("CharacterArt").get_script() == Art, "Patrol does not use shared resident presentation")
	check(roster.size() == 3, "Keep three street patrols")
	for index: int in range(Art.IDENTITIES.size()):
		var identity: String = Art.IDENTITIES[index]
		world.call("_load_map", "house_%02d" % (index + 1), "default")
		var actor := (world.get("_map_root") as Node3D).get_node("HouseResident") as Node3D
		var sprite: Variant = actor.get_node("CharacterArt")
		sprite.set_process(false)
		check(sprite.resident_id == identity, "Wrong resident in house")
		check(sprite.billboard == BaseMaterial3D.BILLBOARD_FIXED_Y, "Indoor resident must remain upright")
		for direction: StringName in Facing.ANIMATIONS:
			check(sprite.sprite_frames.get_frame_count(direction) == 4, "Missing pose: " + identity + "/" + direction)
			var footprints: Array[int] = []
			for pose: int in range(4):
				var texture := sprite.sprite_frames.get_frame_texture(direction, pose) as AtlasTexture
				check(texture.atlas.resource_path.ends_with(identity + "_walk.png"), "Unexpected identity atlas")
				check(is_equal_approx(Grounding.foot_baseline(texture), float(texture.get_meta("ground_y"))), "Frame foot anchor mismatch")
				check(texture.get_size() == Vector2(320, 320), "Inconsistent animation canvas")
				footprints.append(hash(texture.get_image().get_data()))
			check(footprints[1] != footprints[3], "Opposite contacts reuse the same pixels")
		# A fixed world heading viewed from eight camera yaws must expose eight drawings.
		var views: Dictionary = {}
		for step: int in range(8):
			camera.global_position = actor.global_position + Basis(Vector3.UP, step * PI / 4.0) * Vector3(0, 5, 8)
			camera.look_at(actor.global_position + Vector3.UP * 0.7)
			sprite.call("_update_presentation", 0.0)
			views[sprite.animation] = true
			check(sprite.pose_index == 0, "Idle orbit should not animate walking")
		check(views.size() == 8, "Camera orbit did not expose all eight views: " + identity)
		camera.global_position = actor.global_position + Vector3(0, 5, 8)
		camera.look_at(actor.global_position + Vector3.UP * 0.7)
		for heading: Vector3 in HEADINGS:
			player.global_position = actor.global_position + heading.normalized() * 1.4
			world.call("_handle_interaction", "house_resident")
			check(world.get_node("DialogueUI").call("is_open"), "Household dialogue failed")
			check(sprite.animation == Facing.ANIMATIONS[Facing.direction_index(Facing.screen_direction(heading, camera))], "Resident does not face conversation partner")
			while world.get_node("DialogueUI").call("is_open"):
				world.get_node("DialogueUI").call("advance")
			sprite.call("end_conversation")
		# Deterministic time samples exercise actual cycle, stop, and input lock.
		sprite.walking = true
		var poses: Dictionary = {}
		for sample: int in range(8):
			sprite.call("_update_presentation", 0.09)
			poses[sprite.pose_index] = true
		check(poses.has(1) and poses.has(2) and poses.has(3), "Walking cycle skips a contact or passing pose")
		state.set("mode", 1)
		sprite.call("_update_presentation", 0.2)
		check(sprite.pose_index == 0, "Dialogue lock must return walkers to idle")
		state.set("mode", 0)
		sprite.walking = false
		sprite.call("_update_presentation", 0.2)
		check(sprite.pose_index == 0, "Stopped resident still walking")
	world.queue_free()
	await process_frame
	for singleton: String in ["GameAudio", "GameMusic", "GameAmbience"]:
		root.get_node(singleton).call("stop_all")
	if failures == 0:
		print("RESIDENT_MOTION_TEST_PASS eight_identities eight_views 256_poses grounding conversation walk pause patrol")
	quit(0 if failures == 0 else 1)
