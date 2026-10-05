extends RefCounted
## Prologue "霧中醒來": after class selection the amnesiac traveler wakes on the foggy east
## road, reads the fallen sign and a cold lamp, hears the whisper, follows the moonlight west,
## collapses at Twilight Village and wakes three days later in the travelers' lodge.
##
## Progress lives in GameState.flags["prologue"] ("road" -> "follow" -> "house") and is
## erased once the mended coat is taken. Saving is refused while it runs, so quitting
## midway simply starts the prologue again; the save format does not change.
const Lines = preload("res://scripts/story/prologue_lines.gd")
const Films = preload("res://scripts/story/prologue_cutscenes.gd")
const Road = preload("res://scripts/story/prologue_road.gd")
const StreetLantern = preload("res://scripts/gameplay/street_lantern.gd")
const Outskirts = preload("res://scripts/gameplay/outskirts.gd")

const LODGE: String = "house_06"
const WAKE := Vector3(10.0, 0.1, 5.0)
## Where the traveler is held back if they reach the village mouth before finding the way.
const WEST_HOLD := Vector3(-10.5, 0.1, 5.0)
const BED_SIDE := Vector3(-0.85, 0.15, -1.0)
const CLUES: Dictionary = {
	"prologue_belongings": ["belongings", "檢查隨身物品", Vector3(9.0, 0, 6.2)],
	"prologue_lamp": ["lamp", "查看熄滅的路燈", Vector3(4.5, 0, 6.6)],
	"prologue_sign": ["sign", "查看倒下的路標", Vector3(-6.0, 0, 2.9)],
}
const COLD_LAMP := Vector3(4.5, 0, 7.4)
const MAIN_MARKER := Color("ffd45c")
## Both must be read before the whisper; the belongings are optional.
const REQUIRED: Array[String] = ["lamp", "sign"]
const RUMI_POST := Vector3(0.35, 0.024, -1.25)
const RAIN_SEAT := Vector3(0.7, 0.024, 1.5)
const LODGE_DOOR := Vector3(0.0, 0.024, 2.7)
## The "露米抱著空碗跑出門" page of the wake scene.
const RUMI_LEAVES_PAGE: int = 11


static func stage() -> String:
	return str(GameState.flags.get("prologue", ""))


static func active() -> bool:
	return GameState.flags.has("prologue")


static func objective() -> String:
	return str(Lines.OBJECTIVES.get(stage(), ""))


static func found(clue: String) -> bool:
	return bool((GameState.flags.get("prologue_found", {}) as Dictionary).get(clue, false))


## Starts a new journey's prologue; returns the waking film.
static func start(world: Node3D) -> Node:
	GameState.flags["prologue"] = "road"
	GameState.flags["prologue_found"] = {}
	return world.call("play_chapter_cutscene", Films.waking(), func() -> void:
		var controls: String = Lines.CONTROLS_MOBILE if MobileControls.is_mobile_device() else Lines.CONTROLS_DESKTOP
		world.get("dialogue_ui").show_dialogue([{"speaker": "系統", "text": controls}]), "east_road", "prologue_wake")


static func finish() -> void:
	GameState.flags.erase("prologue")
	GameState.flags.erase("prologue_found")
	GameState.state_changed.emit()


## Spawn points used only by the prologue, or null.
static func spawn(map_id: String, spawn_id: String) -> Variant:
	if map_id == "east_road" and spawn_id == "prologue_wake":
		return WAKE
	if map_id == LODGE and spawn_id == "prologue_bed":
		return BED_SIDE
	return null


static func on_map_loaded(world: Node3D, map_id: String) -> void:
	if not active():
		return
	if map_id == "east_road" and stage() in ["road", "follow"]:
		_stage_road(world)
	elif map_id == LODGE and stage() == "house":
		_stage_lodge(world)


## True while the map should not offer a destination (the village is still unknown).
static func hides_destination(interaction_id: String) -> bool:
	return stage() == "road" and interaction_id == "travel_home"


static func marker_visible(interaction_id: String) -> Variant:
	if CLUES.has(interaction_id):
		return not found(str(CLUES[interaction_id][0]))
	if interaction_id in ["prologue_coat", "prologue_window"]:
		return stage() == "house"
	return null


static func handle(world: Node3D, interaction_id: String) -> bool:
	if not active():
		return false
	if CLUES.has(interaction_id):
		_read_clue(world, str(CLUES[interaction_id][0]))
		return true
	match interaction_id:
		"travel_home":
			if stage() == "road":
				var player := world.get_node("Player") as Node3D
				player.global_position = world.call("cutscene_ground", WEST_HOLD)
				player.call("face_world_position", WEST_HOLD + Vector3.RIGHT)
				world.get_node("CameraRig").call("snap_to_target")
				play_lines(world, "west_too_soon")
			elif stage() == "follow":
				GameState.flags["prologue"] = "house"
				world.call("play_chapter_cutscene", Films.arrival(), func() -> void: _wake(world), LODGE, "prologue_bed")
			return true
		"leave_house":
			if stage() == "house":
				play_lines(world, "coat_first")
				return true
		"rumi":
			# Rumi only speaks in the wake scene; she leaves right after.
			return stage() == "house" and GameState.current_map == LODGE
		"prologue_coat":
			var coat := (world.get("_map_root") as Node3D).get_node_or_null("MendedCoat")
			if coat != null:
				coat.queue_free()
			play_lines(world, "coat", func() -> void:
				finish()
				var area := (world.get("_map_root") as Node3D).get_node_or_null("prologue_coat")
				if area != null:
					area.queue_free()
				var window := (world.get("_map_root") as Node3D).get_node_or_null("prologue_window")
				if window != null:
					window.queue_free()
				world.call("_refresh_map_destinations"))
			return true
		"prologue_window":
			play_lines(world, "window")
			return true
	return false


## Extra lines after the lodge's equipment rack (the caravan tag echoes the dream).
static func rack_lines() -> Array[Dictionary]:
	var lines: Array[Dictionary] = []
	for line: Dictionary in Lines.SCENES.rack_echo:
		lines.append(line)
	return lines


static func play_lines(world: Node3D, key: String, finished: Callable = Callable()) -> void:
	var lines: Array[Dictionary] = []
	for line: Dictionary in Lines.SCENES[key]:
		lines.append(line)
	world.get("dialogue_ui").show_dialogue(lines, finished)


## Film beats the host forwards; returns false for ids that are not the prologue's.
static func cutscene_event(world: Node3D, event_id: String) -> bool:
	match event_id:
		"moonbeam":
			var road := (world.get("_map_root") as Node3D).get_node_or_null("PrologueRoad")
			if road != null:
				road.call("light_the_way", true)
			return true
		"dream_knock":
			# Three slow knocks on a door that does not open.
			var knocks: Tween = world.create_tween()
			for index: int in range(3):
				knocks.tween_callback(func() -> void: GameAudio.play_cue(&"impact", 0.5))
				knocks.tween_interval(0.55)
			return true
	return false


static func _read_clue(world: Node3D, clue: String) -> void:
	var seen: Dictionary = GameState.flags.get("prologue_found", {})
	seen[clue] = true
	GameState.flags["prologue_found"] = seen
	GameState.state_changed.emit()
	play_lines(world, clue, func() -> void:
		if stage() != "road":
			return
		for needed: String in REQUIRED:
			if not found(needed):
				return
		_whisper(world))


## The whisper, the traveler's question, then moonlight on the road west.
static func _whisper(world: Node3D) -> void:
	world.call("play_chapter_cutscene", Films.whisper(), func() -> void:
		play_lines(world, "whisper_after", func() -> void:
			world.call("play_chapter_cutscene", Films.moonbeam(), func() -> void:
				GameState.flags["prologue"] = "follow"
				var road := (world.get("_map_root") as Node3D).get_node_or_null("PrologueRoad")
				if road != null:
					road.call("light_the_way", false)
				world.call("_refresh_map_destinations")
				GameState.state_changed.emit(), "", "default", true)), "", "default", true)


static func _stage_road(world: Node3D) -> void:
	var root: Node3D = world.get("_map_root")
	var markers: Dictionary = world.get("_quest_markers")
	# Only the way home stays: no traveler, side events, crypt seal or other exits yet.
	for node: Node in root.find_children("*", "Interactable3D", true, false):
		var id: String = str(node.get("interaction_id"))
		if id == "travel_home":
			continue
		markers.erase(id)
		node.get_parent().remove_child(node)
		node.queue_free()
	StreetLantern.build(root, COLD_LAMP)
	for id: String in CLUES:
		Outskirts.add_interaction(world, id, str(CLUES[id][1]), CLUES[id][2])
		(markers[id] as Label3D).modulate = MAIN_MARKER
	var road := Road.new()
	road.world = world
	root.add_child(road)
	if stage() == "follow":
		road.light_the_way(false)


static func _stage_lodge(world: Node3D) -> void:
	var root: Node3D = world.get("_map_root")
	var rain := root.get_node_or_null("HouseResident") as Node3D
	if rain != null:
		rain.position = RAIN_SEAT
	world.call("_add_actor_interactable", "rumi", "與露米交談", RUMI_POST, "res://assets/generated/rumi.tres", 1.6 / 724.0, Color.WHITE)
	var rumi := root.get_node("Rumi") as Node3D
	rumi.scale = Vector3.ONE * preload("res://scripts/gameplay/house_catalog.gd").INTERIOR_CHARACTER_SCALE
	var mark := rumi.get_node_or_null("InteractionMarker")
	if mark != null:
		mark.queue_free()
	# The mended coat, folded on the blanket.
	var coat := MeshInstance3D.new()
	coat.name = "MendedCoat"
	var fold := BoxMesh.new()
	fold.size = Vector3(0.52, 0.08, 0.42)
	coat.mesh = fold
	var cloth := StandardMaterial3D.new()
	cloth.albedo_color = Color("5d6b8a")
	cloth.roughness = 0.95
	coat.material_override = cloth
	root.add_child(coat)
	coat.position = Vector3(-2.15, 0.7, -0.75)
	coat.rotation.y = 0.2
	Outskirts.add_interaction(world, "prologue_coat", "穿上補好的外衣", Vector3(-1.7, 0, -0.65))
	(world.get("_quest_markers")["prologue_coat"] as Label3D).modulate = MAIN_MARKER
	Outskirts.add_interaction(world, "prologue_window", "看看窗外", Vector3(0.0, 0, -2.75))
	world.call("_update_quest_markers")


## The traveler wakes beside the bed; Rumi has brought the evening soup.
static func _wake(world: Node3D) -> void:
	var player := world.get_node("Player") as Node3D
	var rumi := (world.get("_map_root") as Node3D).get_node_or_null("Rumi") as Node3D
	if rumi != null:
		player.call("face_world_position", rumi.global_position)
	var dialogue: Node = world.get("dialogue_ui")
	var on_page := func(index: int) -> void:
		if index == RUMI_LEAVES_PAGE and is_instance_valid(rumi):
			_rumi_runs_out(rumi)
	dialogue.connect("page_shown", on_page)
	play_lines(world, "wake", func() -> void:
		if dialogue.is_connected("page_shown", on_page):
			dialogue.disconnect("page_shown", on_page)
		if is_instance_valid(rumi):
			rumi.queue_free()
		world.call("_refresh_map_destinations"))
	if rumi != null:
		world.call("_begin_actor_conversation", rumi, false)


static func _rumi_runs_out(rumi: Node3D) -> void:
	var run: Tween = rumi.create_tween()
	run.tween_property(rumi, "position", LODGE_DOOR, 0.9).set_trans(Tween.TRANS_SINE)
	run.tween_callback(func() -> void: rumi.visible = false)
