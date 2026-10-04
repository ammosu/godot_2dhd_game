extends RefCounted
## Chapter 1 "醒來的古道": story beats layered onto the existing maps.
## GameState owns the stage and items; this module only stages scenes and
## decides which beat an interaction plays. Lines live in chapter_one_lines.gd.
const Lines = preload("res://scripts/story/chapter_one_lines.gd")
const Follower = preload("res://scripts/gameplay/party_follower.gd")
const Maze = preload("res://scripts/gameplay/crypt_maze.gd")
const Mountains = preload("res://scripts/gameplay/mountain_maps.gd")
const Stage = preload("res://scripts/systems/game_state.gd").Chapter

const CRYPT_DOOR := Vector3(-8, 0, -1.8)
const SIA_POST := Vector3(-11.5, 0, -26.5)
const NOAH_EAST_POST := Vector3(21.5, 0, 2.4)
const SEAL_ART := "res://assets/generated/crypt_bell_seal.png"
const LANTERN_ART := "res://assets/generated/lantern_bearer.png"
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
	return str(Lines.OBJECTIVES.get(current, ""))


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
	if map_id == "starbay" and not GameState.has_companion("sia"):
		world.call("_add_actor_interactable", "sia", "與希雅交談", SIA_POST, "res://assets/generated/residents/sia.tres", 1.6 / 512.0, Color.WHITE, false, &"main")
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
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color("3d4048")
	stone.roughness = 1.0
	slab.material_override = stone
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
			return active() and stage() in [Stage.NOAH_JOINED, Stage.SIA_JOINED]
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
				_scene(world, "lamp_east", func() -> void:
					GameState.give_item("rumi_letter")
					GameState.advance_chapter(Stage.LIGHT_EAST))
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
		"crypt_reliquary":
			if current == Stage.SEAL_OPEN and GameState.current_map == "ashen_crypt" and GameState.field_defeated.has("crypt_ash_warden"):
				GameState.claim_crypt_reward()
				_scene(world, "ember_shard", func() -> void:
					GameState.give_item("ember_shard")
					GameState.advance_chapter(Stage.EMBER_SHARD))
				return true
		"highland_view":
			if current == Stage.CAMPFIRE and GameState.current_map == "moon_highland":
				var art := load(LANTERN_ART) as Texture2D
				var lines: Array[Dictionary] = []
				for index: int in range(Lines.SCENES.lantern_bearer.size()):
					var line: Dictionary = (Lines.SCENES.lantern_bearer[index] as Dictionary).duplicate()
					if index >= 1 and str(line.speaker) != "系統":
						line["illustration"] = art
					lines.append(line)
				world.get("dialogue_ui").show_dialogue(lines, func() -> void:
					GameState.advance_chapter(Stage.COMPLETE)
					_autosave(world))
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
	elif current == Stage.NOAH_JOINED:
		_scene(world, "seal_blocked", func() -> void: GameState.advance_chapter(Stage.SEAL_FOUND))
	elif current == Stage.SIA_JOINED:
		_scene(world, "seal_open", func() -> void:
			GameState.advance_chapter(Stage.SEAL_OPEN)
			_open_seal(world))
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


static func _scene(world: Node3D, key: String, finished: Callable) -> void:
	var lines: Array[Dictionary] = []
	for line: Dictionary in Lines.SCENES[key]:
		lines.append(line)
	world.get("dialogue_ui").show_dialogue(lines, func() -> void:
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


## Story beats persist like the prologue's: autosave unless running a test.
static func _autosave(world: Node3D) -> void:
	world.call("_refresh_hud")
	if bool(world.get("_test_mode")):
		return
	GameState.remember_player_position((world.get_node("Player") as Node3D).global_position)
	GameState.save_game(GameState.SAVE_PATH, false)
