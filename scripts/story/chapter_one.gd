extends RefCounted
## Chapter 1 "醒來的古道": story beats layered onto the existing maps.
## GameState owns the stage and items; this module only stages scenes and
## decides which beat an interaction plays. Lines live in chapter_one_lines.gd.
const Lines = preload("res://scripts/story/chapter_one_lines.gd")
const Follower = preload("res://scripts/gameplay/party_follower.gd")
const Maze = preload("res://scripts/gameplay/crypt_maze.gd")
const Mountains = preload("res://scripts/gameplay/mountain_maps.gd")
const Films = preload("res://scripts/story/chapter_one_cutscenes.gd")
const EscortWatch = preload("res://scripts/story/escort_watch.gd")
const Stage = preload("res://scripts/systems/game_state.gd").Chapter

const CRYPT_DOOR := Vector3(-8, 0, -1.8)
const SIA_POST := Vector3(-11.5, 0, -26.5)
const NOAH_EAST_POST := Vector3(21.8, 0, 6.6)
const SEAL_ART := "res://assets/generated/crypt_bell_seal.png"
const LANTERN_ART := "res://assets/generated/lantern_bearer.png"
## Pages shown over the art before a scene returns to the live characters.
const SCENE_ART_PAGES: Dictionary = {"sia_joins": 4, "elder_confess": 3, "ember_shard": 5, "campfire": 5}
## The lantern bearer's art holds for his own words; the party's reactions play live.
const LANTERN_ART_PAGES: int = 6
## Full-screen story art behind a scene's dialogue (system lines stay plain).
const SCENE_ART: Dictionary = {
	"elder_confess": "res://assets/generated/chapter_one/elder.png",
	"sia_joins": "res://assets/generated/chapter_one/bell.png",
	"ember_shard": "res://assets/generated/chapter_one/throne.png",
	"campfire": "res://assets/generated/chapter_one/campfire.png",
}
const CRYPT_MAPS: Array[String] = ["ashen_crypt_1", "ashen_crypt_2", "ashen_crypt"]


static func stage() -> int:
	return int(GameState.chapter_stage)


static func active() -> bool:
	return GameState.quest_state == GameState.QuestState.COMPLETE


static func objective(current: int, map_id: String) -> String:
	if current == Stage.SEAL_OPEN and map_id in CRYPT_MAPS:
		match map_id:
			"ashen_crypt_1":
				return "第一章：B1・往北找下樓的路"
			"ashen_crypt_2":
				return "第一章：B2・穿過牢廊，前往北端王座"
			_:
				return "第一章：調查血晶祭壇" if GameState.field_defeated.has("crypt_ash_warden") else "第一章：擊敗典獄長維爾莫"
	if current == Stage.CAMPFIRE and map_id == "village":
		return "尾聲：把回信交給露米"
	if current == Stage.NOAH_JOINED and escort() == "fighting" and GameState.flags.has("ch1_escort_left"):
		return "第一章：逼退野獸 %d／2" % (2 - int(GameState.flags.ch1_escort_left))
	if current == Stage.NOAH_JOINED and Lines.ESCORT_OBJECTIVES.has(escort()):
		return str(Lines.ESCORT_OBJECTIVES[escort()])
	if current == Stage.NOAH_JOINED and escort() == "done":
		return "第一章：查看墓窟入口的封門"
	return str(Lines.OBJECTIVES.get(current, ""))


## Road rescue progress: "" (not met), "fighting", "won", "done".
static func escort() -> String:
	return str(GameState.flags.get("ch1_escort", ""))


## The bell seal keeps the crypt shut until Sia rings it open.
static func crypt_sealed() -> bool:
	return int(GameState.chapter_stage) < Stage.SEAL_OPEN


## North-gate Noah leaves his post once he heads for the east exit.
static func noah_left_gate() -> bool:
	return active() and stage() >= Stage.ELDER_CONFESSED


static func companions() -> Array[String]:
	var result: Array[String] = []
	for actor: String in ["noah", "sia"]:
		if GameState.has_companion(actor):
			result.append(actor)
	return result


## Map-specific staging; called after every map build.
static func on_map_loaded(world: Node3D, map_id: String) -> void:
	var root: Node3D = world.get("_map_root")
	if map_id == "village" and active() and stage() == Stage.ELDER_CONFESSED:
		_post_noah_east(world)
	if map_id == "village" and stage() == Stage.COMPLETE:
		# The open road now has a night watch at the east gate.
		world.call("_add_actor_interactable", "gate_watch", "與守夜的洛克交談", Vector3(22.6, 0, 6.8), "res://assets/generated/residents/locke.tres", 1.6 / 512.0, Color.WHITE)
	if map_id == "starbay" and not GameState.has_companion("sia"):
		world.call("_add_actor_interactable", "sia", "與希雅交談", SIA_POST, "res://assets/generated/residents/sia.tres", 1.6 / 512.0, Color.WHITE, false, &"main")
	if map_id == "east_road" and active() and stage() == Stage.NOAH_JOINED and escort() in ["", "fighting"]:
		# The rescue needs its two beasts even if they fell on an earlier visit.
		for beast: String in EscortWatch.BEASTS:
			GameState.field_defeated.erase(beast)
		var watch := EscortWatch.new()
		watch.name = "EscortWatch"
		watch.world = world
		root.add_child(watch)
	if map_id == "wind_gorge" and active() and stage() >= Stage.EMBER_SHARD:
		_build_campfire(world)
	_spawn_followers(world)


static func _post_noah_east(world: Node3D) -> void:
	world.call("_add_actor_interactable", "ch1_noah", "與諾亞交談", NOAH_EAST_POST, "res://assets/generated/noah.tres", 1.6 / 724.0, Color.WHITE, false, &"main")


## Companions walk outdoors and in the crypt; they wait outside homes and the ruins.
static func _spawn_followers(world: Node3D) -> void:
	var map_id: String = GameState.current_map
	if map_id.begins_with("house_") or map_id == "ruins":
		return
	var root: Node3D = world.get("_map_root")
	var slot: int = 1
	for actor: String in companions():
		var follower := Follower.new()
		follower.name = "Companion" + actor.capitalize()
		follower.resident_id = actor
		follower.slot = slot
		follower.leader = world.get_node("Player")
		root.add_child(follower)
		(follower.get_node("TalkArea") as Interactable3D).activated.connect(Callable(world, "_handle_interaction"))
		slot += 1


static func build_crypt_entrance(world: Node3D) -> void:
	if crypt_sealed():
		_build_seal(world)
	else:
		Maze.portal(world, CRYPT_DOOR, "enter_crypt")


static func _build_seal(world: Node3D) -> void:
	var root: Node3D = world.get("_map_root")
	var seal := Node3D.new()
	seal.name = "CryptBellSeal"
	root.add_child(seal)
	var plate := Sprite3D.new()
	plate.name = "SealPlate"
	plate.texture = load(SEAL_ART) as Texture2D
	plate.pixel_size = 1.7 / float(plate.texture.get_width())
	plate.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	plate.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	plate.shaded = true
	plate.position = CRYPT_DOOR + Vector3(0, 1.75, 0.02)
	seal.add_child(plate)
	var slab := MeshInstance3D.new()
	slab.name = "SealedDoor"
	var door := BoxMesh.new()
	door.size = Vector3(2.4, 3.5, 0.2)
	slab.mesh = door
	# The same weathered crypt stone as the arch around it.
	slab.material_override = load("res://scripts/gameplay/ashen_crypt.gd").material(Vector2(1, 0), 0.5)
	slab.position = CRYPT_DOOR + Vector3(0, 1.75, -0.14)
	seal.add_child(slab)
	var blocker := StaticBody3D.new()
	blocker.name = "SealBlocker"
	blocker.collision_layer = 1
	blocker.collision_mask = 0
	var collider := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.6, 2.4, 0.8)
	collider.shape = box
	collider.position = CRYPT_DOOR + Vector3(0, 1.2, 0.1)
	blocker.add_child(collider)
	seal.add_child(blocker)
	var area := Interactable3D.new()
	area.name = "crypt_seal"
	area.interaction_id = "crypt_seal"
	area.prompt_text = "查看鐘紋封門"
	area.position = CRYPT_DOOR + Vector3(0, 0, 1.1)
	area.collision_layer = 8
	area.collision_mask = 0
	area.activated.connect(Callable(world, "_handle_interaction"))
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 1.1
	shape.shape = sphere
	shape.position.y = 0.75
	area.add_child(shape)
	seal.add_child(area)
	var marker := Label3D.new()
	marker.name = "QuestMarker"
	marker.text = "!"
	marker.position = Vector3(0, 3.2, 0)
	marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	marker.font_size = 64
	marker.outline_size = 12
	marker.modulate = Color("ffcf5a")
	area.add_child(marker)
	(world.get("_quest_markers") as Dictionary)["crypt_seal"] = marker


static func _open_seal(world: Node3D) -> void:
	var root: Node3D = world.get("_map_root")
	var seal := root.get_node_or_null("CryptBellSeal")
	if seal != null:
		(world.get("_quest_markers") as Dictionary).erase("crypt_seal")
		seal.free()
	# Idempotent: the film opens it mid-shot, the map reload may already have built it.
	if root.get_node_or_null("enter_crypt") == null:
		Maze.portal(world, CRYPT_DOOR, "enter_crypt")
	world.call("_refresh_map_destinations")


static func _build_campfire(world: Node3D) -> void:
	var root: Node3D = world.get("_map_root")
	var points: PackedVector3Array = Mountains.route("wind_gorge")
	var index: int = points.size() / 2
	var at: Vector3 = points[index] + Mountains.side_at(points, index) * 1.2
	var fire: Node3D = preload("res://scripts/gameplay/hearth_fire.gd").new()
	fire.name = "Campfire"
	fire.position = at
	fire.scale = Vector3.ONE * 0.8
	root.add_child(fire)
	var outskirts: GDScript = load("res://scripts/gameplay/outskirts.gd")
	outskirts.add_interaction(world, "ch1_campfire", "在營火旁休息", at)


static func marker_visible(interaction_id: String) -> Variant:
	match interaction_id:
		"sia":
			return active() and stage() == Stage.SEAL_FOUND
		"ch1_noah":
			return true
		"crypt_seal":
			return active() and (stage() == Stage.SIA_JOINED or stage() == Stage.NOAH_JOINED and escort() == "done")
		"road_traveler":
			if active() and stage() == Stage.NOAH_JOINED and escort() != "done":
				return escort() == "won"
	return null


## Plays the chapter's version of an interaction. Returns true when handled.
static func handle(world: Node3D, interaction_id: String) -> bool:
	var dialogue: Node = world.get("dialogue_ui")
	var current: int = stage()
	match interaction_id:
		"crypt_seal":
			_seal(world, dialogue, current)
			return true
		"sia":
			if active() and current == Stage.SEAL_FOUND:
				_stage_bell_household(world)
				_scene(world, "sia_joins", func() -> void:
					GameState.take_item("rumi_letter")
					GameState.give_item("starbay_reply")
					GameState.give_item("bell_mallet")
					GameState.advance_chapter(Stage.SIA_JOINED)
					var sia := (world.get("_map_root") as Node3D).get_node_or_null(NodePath("sia".capitalize()))
					if sia != null:
						sia.queue_free()
					_refresh_party(world)
					GameState.notification_requested.emit("希雅加入了隊伍"))
			else:
				dialogue.show_dialogue([{"speaker": "鐘守・希雅", "text": Lines.SIA_WAITING}])
			return true
		"party_talk":
			_party_talk(dialogue)
			return true
		"gate_watch":
			dialogue.show_dialogue([{"speaker": "陶匠・洛克", "text": "今晚輪我守東口。燈亮著，有人來就喊一聲——喊的是「歡迎」。"}])
			return true
		"ch1_campfire":
			GameState.restore_player()
			if active() and current == Stage.EMBER_SHARD:
				_scene(world, "campfire", func() -> void: GameState.advance_chapter(Stage.CAMPFIRE))
			else:
				dialogue.show_dialogue([{"speaker": "營火", "text": "火還暖著。你們坐了一會兒，體力與魔力都恢復了。"}])
			return true
	if not active():
		return false
	match interaction_id:
		"moon_lamp":
			if current == Stage.NONE:
				world.call("play_chapter_cutscene", Films.light_east(), func() -> void:
					# Rumi runs over from the pigs with her letter before she speaks.
					var rumi := (world.get("_map_root") as Node3D).get_node_or_null("Rumi") as Node3D
					if rumi != null:
						rumi.create_tween().tween_property(rumi, "position", Vector3(2.0, 0, 2.6), 0.9).set_trans(Tween.TRANS_SINE)
					_scene(world, "lamp_east", func() -> void:
						GameState.give_item("rumi_letter")
						GameState.advance_chapter(Stage.LIGHT_EAST)))
				return true
		"elder":
			if current == Stage.LIGHT_EAST:
				_scene(world, "elder_confess", func() -> void:
					GameState.advance_chapter(Stage.ELDER_CONFESSED)
					# Noah leaves the north gate for the east exit right away.
					var gate_noah := (world.get("_map_root") as Node3D).get_node_or_null("Noah")
					if gate_noah != null:
						gate_noah.free()
					_post_noah_east(world)
					world.call("_refresh_map_destinations"))
				return true
			if Lines.ELDER_REPEAT.has(current) and current > Stage.NONE:
				dialogue.show_dialogue([{"speaker": "長老・艾爾", "text": Lines.ELDER_REPEAT[current]}])
				return true
		"rumi":
			if current == Stage.COMPLETE and int(GameState.inventory.get("starbay_reply", 0)) > 0:
				_hidden(world, "rumi_reply", func() -> void: GameState.take_item("starbay_reply"))
				return true
			if Lines.RUMI_REPEAT.has(current) and current > Stage.NONE:
				dialogue.show_dialogue([{"speaker": "村童・露米", "text": Lines.RUMI_REPEAT[current]}])
				return true
		"ch1_noah":
			if current == Stage.ELDER_CONFESSED:
				_scene(world, "noah_joins", func() -> void:
					GameState.advance_chapter(Stage.NOAH_JOINED)
					var post := (world.get("_map_root") as Node3D).get_node_or_null(NodePath("ch1_noah".capitalize()))
					if post != null:
						post.queue_free()
					_refresh_party(world)
					GameState.notification_requested.emit("諾亞加入了隊伍"))
				return true
		"road_traveler":
			if current == Stage.NOAH_JOINED and escort() == "won":
				play_scene(world, "escort_done", func() -> void:
					GameState.flags["ch1_escort"] = "done"
					GameState.state_changed.emit())
				return true
			if current == Stage.NOAH_JOINED and escort() == "fighting":
				world.get("dialogue_ui").show_dialogue([{"speaker": "驛路旅人", "text": "牠、牠們還在附近！"}])
				return true
		"crypt_reliquary":
			if current == Stage.SEAL_OPEN and GameState.current_map == "ashen_crypt" and GameState.field_defeated.has("crypt_ash_warden"):
				GameState.claim_crypt_reward()
				_scene(world, "ember_shard", func() -> void:
					GameState.give_item("ember_shard")
					GameState.advance_chapter(Stage.EMBER_SHARD)
					# The throne's hoarded light runs for the exit once the shard is taken.
					world.call("play_chapter_cutscene", Films.ember_flow(), func() -> void:
						world.get("dialogue_ui").show_dialogue([{"speaker": "諾亞", "text": "光往出口走了。……我們也走吧，別把它關在這裡。"}]), "", "default", true))
				return true
		"highland_view":
			if current == Stage.CAMPFIRE and GameState.current_map == "moon_highland":
				# Shard catches the moon -> the lantern bearer -> home to Rumi -> one chapter card.
				world.call("play_chapter_cutscene", Films.shard_rise(), func() -> void:
					var art := load(LANTERN_ART) as Texture2D
					var lines: Array[Dictionary] = []
					for source: Dictionary in Lines.SCENES.lantern_bearer:
						var line: Dictionary = source.duplicate()
						if lines.size() < LANTERN_ART_PAGES:
							line["illustration"] = art
						lines.append(line)
					world.get("dialogue_ui").show_dialogue(lines, func() -> void:
						world.call("play_chapter_cutscene", Films.blue_lamp(), func() -> void:
							world.get("dialogue_ui").show_dialogue([{"speaker": "旅人", "text": "先把回信送回去。然後，我們去找那盞藍燈。"}], func() -> void:
								world.call("play_chapter_cutscene", Films.homecoming(), func() -> void: _deliver_reply(world), "village", "default")), "", "default", true)))
				return true
	return false


## Lines appended after the road traveler's own event text.
static func road_traveler_line() -> String:
	return str(Lines.ROAD_TRAVELER.get(stage(), "")) if active() else ""


static func city_map_lines() -> Array[Dictionary]:
	var lines: Array[Dictionary] = []
	for line: Dictionary in Lines.HIDDEN.city_map:
		lines.append(line)
	if active() and stage() >= Stage.SEAL_FOUND:
		for line: Dictionary in Lines.HIDDEN.city_map_after:
			lines.append(line)
	return lines


static func _seal(world: Node3D, dialogue: Node, current: int) -> void:
	if not active() or current < Stage.NOAH_JOINED:
		dialogue.show_dialogue([{"speaker": "鐘紋封門", "text": "墓窟的石門被一塊青銅圓板封住了。圓板上刻著一口鐘。"}])
	elif current == Stage.NOAH_JOINED and escort() != "done":
		dialogue.show_dialogue([{"speaker": "諾亞", "text": "門晚點再看。先顧好那個旅人。"}])
	elif current == Stage.NOAH_JOINED:
		_scene(world, "seal_blocked", func() -> void: GameState.advance_chapter(Stage.SEAL_FOUND))
	elif current == Stage.SIA_JOINED:
		# Shown, not told: Sia rings the crest and the slab sinks on camera.
		_scene(world, "seal_open_pre", func() -> void:
			world.call("play_chapter_cutscene", Films.seal_open(), func() -> void:
				if stage() < Stage.SEAL_OPEN:
					GameState.advance_chapter(Stage.SEAL_OPEN)
				_open_seal(world)
				_scene(world, "seal_open_post", Callable())))
	else:
		dialogue.show_dialogue([{"speaker": "鐘紋封門", "text": str(Lines.SEAL_REPEAT.get(current, Lines.SEAL_REPEAT[Stage.SEAL_FOUND]))}])


static func _party_talk(dialogue: Node) -> void:
	var version: String = "both" if GameState.has_companion("sia") else "only_noah"
	var talks: Dictionary = Lines.PARTY_TALK[version]
	var key: String = GameState.current_map
	if key.begins_with("ashen_crypt") and not talks.has(key):
		key = "ashen_crypt_2"
	if not talks.has(key):
		key = "east_road"
	var lines: Array[Dictionary] = []
	for line: Dictionary in talks[key]:
		lines.append(line)
	dialogue.show_dialogue(lines)


## The bell tower's children and master step in around Sia for her farewell.
static func _stage_bell_household(world: Node3D) -> void:
	var root: Node3D = world.get("_map_root")
	for extra: Array in [["BellChildGirl", "folk_girl", Vector3(-10.0, 0, -25.4), 1.0], ["BellChildBoy", "folk_boy", Vector3(-9.2, 0, -26.6), 1.02], ["BellMaster", "bell_master", Vector3(-13.3, 0, -27.8), 1.55]]:
		if root.get_node_or_null(str(extra[0])) != null:
			continue
		var figure := Sprite3D.new()
		figure.name = str(extra[0])
		figure.texture = load("res://assets/generated/chapter_one/%s.png" % extra[1]) as Texture2D
		figure.pixel_size = float(extra[3]) / float(figure.texture.get_height())
		figure.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		figure.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		figure.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		root.add_child(figure)
		figure.global_position = world.call("cutscene_ground", extra[2]) + Vector3.UP * (float(extra[3]) * 0.5 - 0.09)


## Final beat: the reply reaches Rumi on the plaza, then the chapter card.
static func _deliver_reply(world: Node3D) -> void:
	var hero := world.get_node("Player") as Node3D
	hero.global_position = world.call("cutscene_ground", Vector3(5.0, 0, 6.6))
	hero.call("face_world_position", Vector3(6.4, 0, 4.2))
	_refresh_party(world)
	var rumi := (world.get("_map_root") as Node3D).get_node_or_null("Rumi") as Node3D
	_hidden(world, "rumi_reply", func() -> void:
		GameState.take_item("starbay_reply")
		world.call("play_chapter_cutscene", Films.end_card(), func() -> void:
			GameState.advance_chapter(Stage.COMPLETE)
			_autosave(world)))
	if rumi != null:
		world.call("_begin_actor_conversation", rumi)


static func play_scene(world: Node3D, key: String, finished: Callable) -> void:
	_scene(world, key, finished)


## Scenery beats for chapter films (the host forwards unknown event ids here).
static func cutscene_event(world: Node3D, event_id: String) -> void:
	var root: Node3D = world.get("_map_root")
	match event_id:
		"party_to_door":
			# Companions take their marks beside the crest so the lens sees the door.
			for follower: Node in world.get_tree().get_nodes_in_group("party_followers"):
				var mark: Vector3 = CRYPT_DOOR + (Vector3(-1.5, 0, 1.4) if str(follower.get("resident_id")) == "sia" else Vector3(2.9, 0, 2.0))
				follower.set("combat_goal", world.call("cutscene_ground", mark))
		"shard_in_hand":
			# The ash-covered shard, held up before the traveler; it brightens on "shard_glow".
			var hero := world.get_node("Player") as Node3D
			var shard: Node3D = preload("res://scripts/gameplay/moon_shard.gd").new()
			shard.name = "HeldShard"
			shard.scale = Vector3.ONE * 0.55
			root.add_child(shard)
			# Held out at chest height on the close-up lens's right, clear of the face.
			shard.global_position = hero.global_position + Vector3(-0.32, 0.92, -0.36)
		"ash_fall":
			var shard := root.get_node_or_null("HeldShard") as Node3D
			if shard == null:
				return
			var ash := CPUParticles3D.new()
			ash.name = "AshFall"
			ash.one_shot = true
			ash.amount = 48
			ash.lifetime = 1.8
			ash.explosiveness = 0.6
			ash.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
			ash.emission_sphere_radius = 0.16
			ash.gravity = Vector3(0, -0.7, 0)
			ash.initial_velocity_min = 0.05
			ash.initial_velocity_max = 0.25
			var flake := QuadMesh.new()
			flake.size = Vector2(0.035, 0.035)
			var grey := StandardMaterial3D.new()
			grey.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			grey.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
			grey.albedo_color = Color("8a8c91")
			flake.material = grey
			ash.mesh = flake
			root.add_child(ash)
			ash.global_position = shard.global_position
			ash.emitting = true
			var bloom := OmniLight3D.new()
			bloom.light_color = Color("dff1ff")
			bloom.omni_range = 2.2
			bloom.light_energy = 0.0
			shard.add_child(bloom)
			var brighten: Tween = shard.create_tween().set_parallel(true)
			brighten.tween_property(bloom, "light_energy", 3.5, 1.6).set_delay(0.4)
			brighten.tween_property(shard, "scale", Vector3.ONE * 0.68, 1.6).set_delay(0.4).set_trans(Tween.TRANS_SINE)
		"lantern_approach":
			# The lantern bearer climbs the trail toward the lookout, a silhouette in the fog.
			var points: PackedVector3Array = Mountains.route("moon_highland")
			var walker := Node3D.new()
			walker.name = "ApproachingBearer"
			var figure := Sprite3D.new()
			figure.texture = load("res://assets/generated/chapter_one/lantern_bearer_sprite.png") as Texture2D
			figure.pixel_size = 2.1 / float(figure.texture.get_height())
			figure.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
			figure.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
			figure.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
			figure.modulate = Color(0.78, 0.84, 0.95)
			figure.position.y = 1.05
			walker.add_child(figure)
			var lantern := OmniLight3D.new()
			lantern.light_color = Color("d8ecff")
			lantern.omni_range = 6.0
			lantern.light_energy = 3.2
			lantern.position = Vector3(-0.45, 1.65, 0.1)
			walker.add_child(lantern)
			root.add_child(walker)
			walker.global_position = world.call("cutscene_ground", points[-34]) - Vector3.UP * 0.1
			var climb: Tween = walker.create_tween()
			for index: int in [-30, -26, -22]:
				climb.tween_property(walker, "global_position", world.call("cutscene_ground", points[index]) - Vector3.UP * 0.1, 1.6)
		"ember_flow":
			# The fallen warden would fill the lens; the film is about the light.
			var field := root.get_node_or_null("FieldCombat")
			if field != null:
				for corpse: Node in field.find_children("*", "Sprite3D", true, false):
					(corpse as Sprite3D).visible = false
			var seams: Tween = root.create_tween()
			for step: int in range(10):
				var z: float = lerpf(-8.4, 9.2, float(step) / 9.0)
				seams.tween_callback(_light_seam.bind(root, Vector3(0.35 * sin(step * 1.7), 0.03, z)))
				seams.tween_interval(0.34)
		"noah_enters":
			for follower: Node in world.get_tree().get_nodes_in_group("party_followers"):
				if str(follower.get("resident_id")) == "noah":
					follower.set("combat_goal", world.call("cutscene_ground", CRYPT_DOOR + Vector3(0, 0, -0.2)))
		"crest_answer":
			GameAudio.play_cue(&"hand_bell", 1.4)
			var plate := root.get_node_or_null("CryptBellSeal/SealPlate") as Sprite3D
			if plate != null:
				var answer: Tween = plate.create_tween()
				answer.tween_property(plate, "modulate", Color(1.6, 1.8, 2.0), 0.35)
				answer.tween_property(plate, "modulate", Color.WHITE, 0.8)
		"seal_ring":
			for follower: Node in world.get_tree().get_nodes_in_group("party_followers"):
				if str(follower.get("resident_id")) == "sia":
					var bell: Tween = follower.create_tween()
					bell.tween_callback(follower.set_action.bind(1, &"right"))
					bell.tween_interval(0.45)
					bell.tween_callback(follower.set_action.bind(2, &"right"))
					bell.tween_interval(0.9)
					bell.tween_callback(follower.set_action.bind(3, &"right"))
					bell.tween_interval(0.6)
					bell.tween_callback(follower.set_action.bind(-1, &"right"))
			var ring: Tween = root.create_tween()
			ring.tween_interval(0.45)
			ring.tween_callback(func() -> void: GameAudio.play_cue(&"hand_bell"))
		"seal_sink":
			var seal := root.get_node_or_null("CryptBellSeal") as Node3D
			if seal == null:
				return
			var sink: Tween = seal.create_tween().set_parallel(true)
			for part: String in ["SealPlate", "SealedDoor"]:
				var node := seal.get_node_or_null(part) as Node3D
				if node != null:
					sink.tween_property(node, "position:y", node.position.y - 3.7, 3.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
			# Once the slab is down the passage is real: commit the stage and raise the portal on camera.
			sink.chain().tween_callback(func() -> void:
				GameState.advance_chapter(Stage.SEAL_OPEN)
				_open_seal(world))
			var dust := OmniLight3D.new()
			dust.light_color = Color("9fd8ff")
			dust.omni_range = 4.0
			dust.light_energy = 0.0
			root.add_child(dust)
			dust.global_position = CRYPT_DOOR + Vector3(0, 1.2, 0.8)
			var glow: Tween = dust.create_tween()
			glow.tween_property(dust, "light_energy", 2.2, 1.2)
			glow.tween_property(dust, "light_energy", 0.0, 2.0)
			glow.tween_callback(dust.queue_free)
			GameAudio.play_cue(&"guard")


static func _scene(world: Node3D, key: String, finished: Callable) -> void:
	var art: Texture2D = load(SCENE_ART[key]) as Texture2D if SCENE_ART.has(key) else null
	var lines: Array[Dictionary] = []
	var art_pages: int = int(SCENE_ART_PAGES.get(key, 999))
	for source: Dictionary in Lines.SCENES[key]:
		var line: Dictionary = source.duplicate()
		if art != null and str(line.speaker) != "系統" and lines.size() < art_pages:
			line["illustration"] = art
		lines.append(line)
	world.get("dialogue_ui").show_dialogue(lines, func() -> void:
		if finished.is_valid():
			finished.call()
		_autosave(world))


static func _hidden(world: Node3D, key: String, finished: Callable) -> void:
	var lines: Array[Dictionary] = []
	for line: Dictionary in Lines.HIDDEN[key]:
		lines.append(line)
	world.get("dialogue_ui").show_dialogue(lines, finished)


## Rebuild companions in place after someone joins.
static func _refresh_party(world: Node3D) -> void:
	for follower: Node in world.get_tree().get_nodes_in_group("party_followers"):
		follower.remove_from_group("party_followers")
		follower.queue_free()
	_spawn_followers(world)
	world.call("_refresh_map_destinations")


## One floor seam catching the freed light: a thin glowing strip with a short-lived glow.
static func _light_seam(root: Node3D, at: Vector3) -> void:
	var strip := MeshInstance3D.new()
	var plane := QuadMesh.new()
	plane.size = Vector2(0.18, 1.6)
	plane.orientation = PlaneMesh.FACE_Y
	strip.mesh = plane
	var glow := StandardMaterial3D.new()
	glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow.albedo_color = Color(1.0, 0.86, 0.6, 0.0)
	strip.material_override = glow
	root.add_child(strip)
	strip.global_position = at
	var light := OmniLight3D.new()
	light.light_color = Color("ffd7a0")
	light.omni_range = 2.4
	light.light_energy = 0.0
	strip.add_child(light)
	light.position.y = 0.3
	var fade: Tween = strip.create_tween().set_parallel(true)
	fade.tween_property(glow, "albedo_color:a", 0.9, 0.3)
	fade.tween_property(light, "light_energy", 2.2, 0.3)


## Story beats persist like the prologue's: autosave unless running a test.
static func _autosave(world: Node3D) -> void:
	world.call("_refresh_hud")
	if bool(world.get("_test_mode")):
		return
	GameState.remember_player_position((world.get_node("Player") as Node3D).global_position)
	GameState.save_game(GameState.SAVE_PATH, false)
