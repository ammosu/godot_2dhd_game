class_name PrototypeWorld
extends Node3D
const Proportions = preload("res://scripts/gameplay/character_proportions.gd")

signal map_presented

const DoorInteraction = preload("res://scripts/gameplay/door_interaction.gd")
const Starbay = preload("res://scripts/gameplay/starbay.gd")
const CryptLayout = preload("res://scripts/gameplay/crypt_layout.gd")
const Dungeon = preload("res://scripts/gameplay/ashen_crypt.gd")
const ChapterOne = preload("res://scripts/story/chapter_one.gd")
const Outskirts = preload("res://scripts/gameplay/outskirts.gd")

const HouseDetails = preload("res://scripts/gameplay/house_details.gd")
const HouseExterior = preload("res://scripts/gameplay/house_exterior.gd")
const WaterFeature = preload("res://scripts/gameplay/water_feature.gd")
const MeadowDressing = preload("res://scripts/gameplay/meadow_dressing.gd")
const SpriteGrounding = preload("res://scripts/gameplay/sprite_grounding.gd")
const HouseCatalog = preload("res://scripts/gameplay/house_catalog.gd")
const HouseInterior = preload("res://scripts/gameplay/house_interior.gd")
const ForegroundCutaway = preload("res://scripts/gameplay/foreground_cutaway.gd")
const MoonShard = preload("res://scripts/gameplay/moon_shard.gd")
const MoonSeal = preload("res://scripts/gameplay/moon_seal.gd")
const CutscenePlayer = preload("res://scripts/gameplay/cutscene_player.gd")
const VillageMap = preload("res://scripts/gameplay/village_map.gd")
const RuinsMap = preload("res://scripts/gameplay/ruins_map.gd")
const OpeningCutscene = preload("res://scripts/story/opening_cutscene.gd")
const PlaythroughTest = preload("res://scripts/testing/playthrough_test.gd")
const BodyLife = preload("res://scripts/gameplay/body_life.gd")
const ActorActing = preload("res://scripts/gameplay/actor_acting.gd")
const PortalTransition = preload("res://scripts/ui/portal_transition.gd")
const PORTAL_SHOT: StringName = &"portal_cross"
## Seconds of walking into the light before the screen is fully covered.
const PORTAL_COVER_SECONDS: float = 0.85
const PORTAL_REVEAL_SECONDS: float = 0.75
const PortraitFaces = preload("res://scripts/ui/portrait_faces.gd")

const PALETTE := {
	"stone": Color("686176"),
	"stone_dark": Color("343246"),
	"path": Color("786e70"),
	"grass": Color("405c55"),
	"water": Color("31556d"),
	"gold": Color("d8a45d"),
	"crystal": Color("75d5ce"),
	"ruin": Color("443d55"),
}
const MAIN_QUEST_MARKER: StringName = &"main"
const SIDE_CONTENT_MARKER: StringName = &"side"
const MAIN_QUEST_MARKER_COLOR := Color("ffd45c")
const SIDE_CONTENT_MARKER_COLOR := Color("64e6ff")
## Conversation staging: the hero eases back to talking distance (never a
## teleport) at this pace, aiming slightly past the spacing so the walk's
## arrival tolerance still leaves a clear gap.
const CONVERSATION_STEP_SPEED: float = 1.6
const CONVERSATION_STEP_MARGIN: float = 0.05
const CONVERSATION_STEP_TOLERANCE: float = 0.02
const CONVERSATION_RETREAT_ANGLES: Array[float] = [0.0, 30.0, -30.0, 60.0, -60.0, 90.0, -90.0, 120.0, -120.0, 150.0, -150.0, 180.0]
## Speakers with no body in the scene never nod.
const NARRATOR_SPEAKERS: Array[String] = ["", "旁白", "系統"]
## Street patrol strolling pace, tuned to each identity's drawn stride.
const VILLAGER_SPEEDS: Array[float] = [0.6, 0.55, 0.62]

@onready var player: Wanderer = $Player
@onready var dialogue_ui: DialogueUI = $DialogueUI
@onready var battle_ui: ActionBattleUI = $BattleUI

var _map_root: Node3D
# Keep immutable art resident while this world exists; map teardown must not
# force another decode/upload of the same large atlases on the return trip.
var _art_textures: Dictionary[String, Texture2D] = {}
var _art_baselines: Dictionary[String, float] = {}
## Shared scenery prop builder; map scripts reach it as `world.props`.
var props := WorldProps.new(_art_textures)
var _resident_materials: Dictionary[String, Array] = {}
var _environment: Environment
var _ambient_time: float = 0.0
var _moon_lamp_core: MeshInstance3D
var _moon_lamp_light: OmniLight3D
var _village_gate_portal: Interactable3D
var _village_gate_left: Node3D
var _village_gate_right: Node3D
var _village_gate_seal: MeshInstance3D
var _village_gate_seal_core: MeshInstance3D
var _village_gate_light: OmniLight3D
var _village_gate_marker: Label3D
var _village_gate_is_open: bool = false
var _portal_transition_pending: bool = false
var _portal_fx: PortalTransition
var _quest_markers: Dictionary = {}
## Only chapter films return to the player's current exploration location.
var _chapter_cutscene_return: Dictionary = {}
## Floating labels a film hid; restored when a film ends without a map reload.
var _film_hidden: Array[Node3D] = []

var _map_label: Label
var _quest_label: Label
var _prompt_label: Label
var _notice_label: Label
var _mini_map: MiniMap
var _player_status: PanelContainer
var _hud: WorldHud
var _interior_backdrop: ColorRect
var _test_mode: bool = false
var _conversation_art: Node3D
var _speaking_life: Node
var _conversation_step_active: bool = false
var _conversation_step_bodies: Array[PhysicsBody3D] = []


func _ready() -> void:
	_test_mode = "--playthrough-test" in OS.get_cmdline_user_args()
	_build_environment()
	_build_post_process()
	_build_hud()
	$MobileControls/ControlPad.camera_dragged.connect($CameraRig.rotate_from_touch)
	GameState.map_change_requested.connect(_on_map_change_requested)
	GameState.state_changed.connect(_refresh_hud)
	GameState.notification_requested.connect(_show_notice)
	battle_ui.battle_finished.connect(_on_battle_finished)
	GameState.state_changed.connect(_on_conversation_state_changed)
	dialogue_ui.line_revealing.connect(_on_line_revealing)
	dialogue_ui.line_acted.connect(_on_line_acted)
	_portal_fx = PortalTransition.new()
	add_child(_portal_fx)
	var hero_life := BodyLife.new()
	hero_life.breathing = false # Idle motion of the hero belongs to the player script.
	player.sprite.add_child(hero_life)
	_load_map(GameState.current_map, GameState.spawn_id)
	if _test_mode:
		GameState.flags["intro_seen"] = true
		var playthrough := PlaythroughTest.new()
		playthrough.name = "PlaythroughTest"
		playthrough.world = self
		add_child(playthrough)
		playthrough.run.call_deferred()
	elif not _start_preview() and not bool(GameState.flags.get("intro_seen", false)):
		_show_class_selection.call_deferred()
	print("Wanderlight playable slice loaded with Godot %s" % Engine.get_version_info().get("string", "unknown"))


## Developer launch flags such as `-- --village-preview` that jump to a scene.
## Keys: test (no autosaves), map [id, spawn], player, distance, yaw, fov, snap,
## start [node path, method] called deferred. The first flag present wins.
func _preview_table() -> Dictionary:
	return {
		"--story-preview": {"test": true, "start": [".", "_show_story_preview"]},
		"--equipment-preview": {"start": ["EquipmentUI", "open"]},
		"--battle-preview": {"test": true, "map": ["ruins", "from_village"], "player": Vector3(0, 0.1, -5.5), "snap": true, "start": [".", "_start_guardian_battle"]},
		"--civic-preview": {"test": true, "map": ["starbay", "from_road"], "player": Vector3(-6, 0.1, -9), "snap": true},
		"--japanese-preview": {"test": true, "map": ["starbay", "from_house_city_01"], "yaw": -0.6 + atan2(6.0, -8.0), "distance": 14.0, "snap": true},
		"--city-house-preview": {"test": true, "map": ["house_city_01", "entry"]},
		"--city-preview": {"test": true, "map": ["starbay", "from_road"]},
		"--caravan-preview": {"test": true, "map": ["caravan_road", "from_road"]},
		"--crypt-boss-preview": {"test": true, "map": ["ashen_crypt", "entry"]},
		"--dungeon-preview": {"test": true, "map": ["ashen_crypt_1", "entry"]},
		"--roadside-preview": {"test": true, "map": ["east_road", "from_village"], "player": Vector3(-4.7, 0.1, 3.4), "distance": 9.0, "yaw": deg_to_rad(-15.0), "snap": true},
		"--field-preview": {"test": true, "map": ["east_road", "from_village"], "player": Vector3(-1, 0.1, 6), "distance": 15.0, "yaw": deg_to_rad(-35.0), "snap": true},
		"--mountain-preview": {"test": true, "map": ["moss_steps", "from_base"]},
		"--outskirts-preview": {"test": true, "map": ["east_road", "from_village"]},
		"--ruins-preview": {"map": ["ruins", "from_village"], "player": Vector3(-7.0, 0.1, 6.5)},
		"--interior-preview": {"map": ["house_02", "entry"]},
		"--house-route-preview": {"player": HouseCatalog.return_position("house_02"), "snap": true},
		"--opening-preview": {"test": true, "start": [".", "_play_opening"]},
		"--village-preview": {"player": Vector3(0.0, 0.1, 6.0), "fov": 45.0},
	}


func _start_preview() -> bool:
	var args := OS.get_cmdline_user_args()
	var table := _preview_table()
	for flag: String in table:
		if flag not in args:
			continue
		var preview: Dictionary = table[flag]
		GameState.flags["intro_seen"] = true
		if preview.get("test", false):
			_test_mode = true # Previews never write normal autosaves.
		if preview.has("map"):
			_load_map(preview.map[0], preview.map[1])
		if preview.has("player"):
			player.global_position = preview.player
		var rig := $CameraRig as Hd2dCameraRig
		if preview.has("distance"):
			rig.set("_distance", preview.distance)
		if preview.has("yaw"):
			rig.set("_target_yaw", preview.yaw)
		if preview.get("snap", false):
			rig.snap_to_target()
		if preview.has("fov"):
			($CameraRig/Camera3D as Camera3D).fov = preview.fov
		if preview.has("start"):
			get_node(NodePath(preview.start[0])).call_deferred(preview.start[1])
		return true
	return false


func _process(delta: float) -> void:
	if _mini_map.navigation_path != player.auto_walk.path:
		_mini_map.navigation_path = player.auto_walk.path.duplicate()
		_mini_map.queue_redraw()
	_ambient_time += delta
	if is_instance_valid(_moon_lamp_core):
		_moon_lamp_core.rotation.y += delta * 0.45
	if is_instance_valid(_moon_lamp_light):
		var lamp_is_restored := GameState.quest_state == GameState.QuestState.COMPLETE
		var base_energy := 4.2 if lamp_is_restored else 0.28
		var pulse_strength := 0.45 if lamp_is_restored else 0.08
		_moon_lamp_light.light_energy = base_energy + sin(_ambient_time * 2.2) * pulse_strength
	if is_instance_valid(_mini_map):
		var tracked: CharacterBody3D = player
		if battle_ui.is_active() and is_instance_valid(battle_ui.encounter):
			tracked = battle_ui.encounter.bodies[int(battle_ui.session.controlled)]
		_mini_map.set_player_state(tracked.global_position, tracked.velocity)
	if _hud != null:
		_layout_interaction_prompt()
		_hud.set_prompt(player.get_interaction_prompt() if GameState.mode == GameState.Mode.EXPLORE else "")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo() or GameState.is_input_locked():
		return
	if event.is_action_pressed("save_game"):
		GameState.remember_player_position(player.global_position)
		GameState.save_game()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("load_game"):
		GameState.load_game()
		get_viewport().set_input_as_handled()


func _show_class_selection() -> void:
	var selection := preload("res://scripts/ui/class_selection.gd").new()
	selection.journey_started.connect(_play_opening)
	add_child(selection)


func _play_opening() -> CutscenePlayer:
	var film := CutscenePlayer.new()
	film.host = self
	film.actor = player
	film.hidden_layers.assign([$HUD, $MobileControls, $Notices])
	film.pause_on_focus_loss = not _test_mode
	add_child(film)
	film.finished.connect(func(_skipped: bool) -> void: _show_intro())
	film.play(OpeningCutscene.shots())
	return film


## Plays a chapter film and returns to where the traveler stood, or to
## `return_map`/`return_spawn` when the film travels somewhere else.
## `stay_on_map` films only move the lens: the live map (and any fight) is kept as is.
func play_chapter_cutscene(shots: Array[Dictionary], finished: Callable, return_map: String = "", return_spawn: String = "default", stay_on_map: bool = false) -> CutscenePlayer:
	_chapter_cutscene_return = {"map": GameState.current_map, "position": player.global_position}
	if not return_map.is_empty():
		_chapter_cutscene_return = {"map": return_map, "spawn": return_spawn}
	if stay_on_map:
		_chapter_cutscene_return = {"stay": true, "position": player.global_position}
	# Apply the road's final presentation under black, even when its event was skipped.
	for shot: Dictionary in shots:
		for event: Dictionary in shot.get("events", []):
			if str(event.get("id", "")) == "light_turns_east":
				_chapter_cutscene_return["road_east"] = true
	var film := CutscenePlayer.new()
	film.host = self
	film.actor = player
	film.hidden_layers.assign([$HUD, $MobileControls, $Notices])
	film.pause_on_focus_loss = not _test_mode
	add_child(film)
	film.finished.connect(func(_skipped: bool) -> void: finished.call())
	_hide_film_clutter()
	film.play(shots)
	return film


func cutscene_load_map(map_id: String, spawn_id: String) -> void:
	_load_map(map_id, spawn_id)
	_hide_film_clutter()
	# Field enemies attach their bars after the map finishes building.
	_hide_film_clutter.call_deferred()


## Floating guide text and health bars are gameplay UI; the concluding reload restores them.
func _hide_film_clutter() -> void:
	if not is_instance_valid(_map_root):
		return
	var health_bar_script: Script = preload("res://scripts/gameplay/world_health_bar.gd")
	for node: Node in _map_root.find_children("*", "Node3D", true, false):
		if (node is Label3D and (node as Label3D).billboard != BaseMaterial3D.BILLBOARD_DISABLED) or node.get_script() == health_bar_script:
			if (node as Node3D).visible:
				_film_hidden.append(node as Node3D)
			(node as Node3D).visible = false


func cutscene_ground(point: Vector3) -> Vector3:
	var landscape: Node = _map_root.get_node_or_null("OutdoorLandscape") if is_instance_valid(_map_root) else null
	var height := 0.1
	if landscape != null:
		height = maxf(height, float(landscape.soil_height(Vector2(point.x, point.z))) + 0.1)
	else:
		# Mountain trails and other authored surfaces: drop onto the walkable collision.
		var query := PhysicsRayQueryParameters3D.create(Vector3(point.x, point.y + 30.0, point.z), Vector3(point.x, point.y - 30.0, point.z))
		query.collision_mask = 1
		query.exclude = [player.get_rid()]
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty():
			height = float((hit.position as Vector3).y) + 0.1
	return Vector3(point.x, height, point.z)


func cutscene_event(event_id: String) -> void:
	match event_id:
		"light_turns_east":
			var road := _map_root.find_child("AwakenedRoad", true, false)
			if road != null:
				road.call("turn_east", 2.5)
		"shard_glow":
			var glow := OmniLight3D.new()
			glow.name = "ShardGlow"
			glow.light_color = Color("d4eeff")
			glow.omni_range = 5.0
			glow.light_energy = 0.0
			_map_root.add_child(glow)
			glow.global_position = player.global_position + Vector3.UP * 1.6
			var pulse := glow.create_tween()
			pulse.tween_property(glow, "light_energy", 3.0, 1.5).set_trans(Tween.TRANS_SINE)
			pulse.tween_property(glow, "light_energy", 0.0, 2.5).set_trans(Tween.TRANS_SINE)
			pulse.tween_callback(glow.queue_free)
		"gate_glow":
			if not is_instance_valid(_village_gate_light):
				return
			var pulse := create_tween()
			pulse.tween_property(_village_gate_light, "light_energy", 3.2, 0.9).set_trans(Tween.TRANS_SINE)
			pulse.tween_property(_village_gate_light, "light_energy", 0.15, 1.6).set_trans(Tween.TRANS_SINE)
		"waking_fog":
			# Start in a thick murk and let it thin back to the map's own density.
			var settled := _environment.fog_density
			_environment.fog_density = 0.09
			# Bound to the map root so a skip or map change stops it before the next map's fog.
			_map_root.create_tween().tween_property(_environment, "fog_density", settled, 6.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		"road_whisper":
			var glow := OmniLight3D.new()
			glow.name = "WhisperGlow"
			glow.light_color = Color("a9d8ff")
			glow.omni_range = 5.0
			glow.light_energy = 0.0
			_map_root.add_child(glow)
			glow.global_position = player.global_position + Vector3(-2.6, 1.3, -0.4)
			var flash := glow.create_tween()
			flash.tween_property(glow, "light_energy", 2.4, 0.7).set_trans(Tween.TRANS_SINE)
			flash.tween_property(glow, "light_energy", 0.0, 1.8).set_trans(Tween.TRANS_SINE)
			flash.tween_callback(glow.queue_free)
		_:
			ChapterOne.cutscene_event(self, event_id)


## A named performer for films: a travelling companion, else a map actor by interaction id.
func cutscene_cast(id: String) -> Node3D:
	for follower: Node in get_tree().get_nodes_in_group("party_followers"):
		if not follower.is_queued_for_deletion() and str(follower.get("resident_id")) == id:
			return follower as Node3D
	if not is_instance_valid(_map_root):
		return null
	for node: Node in _map_root.find_children("*", "Interactable3D", true, false):
		if str(node.get("interaction_id")) == id:
			return node as Node3D
	return null


## The art that visibly acts for a performer; "actor" and "hero" are the traveler.
func cutscene_sprite(id: String) -> SpriteBase3D:
	if id in ["actor", "hero"]:
		var field: Node = _map_root.get_node_or_null("FieldCombat") if is_instance_valid(_map_root) else null
		if field != null:
			var combat_art: Variant = field.get("_hero_sprite")
			if combat_art is SpriteBase3D and is_instance_valid(combat_art) and (combat_art as SpriteBase3D).visible:
				return combat_art
		return player.sprite
	var member: Node3D = cutscene_cast(id)
	if member == null:
		return null
	var art: Node = member.get_node_or_null("CharacterArt")
	if art is SpriteBase3D:
		return art
	for child: Node in member.find_children("*", "SpriteBase3D", true, false):
		return child as SpriteBase3D
	return null


## Dialogue lines may carry "act"/"emote"; the speaker (or the partner) performs it.
func _on_line_acted(speaker: String, beat: StringName, emote: StringName) -> void:
	var face: String = PortraitFaces.speaker_face_id(speaker)
	var sprite: SpriteBase3D = cutscene_sprite(face) if not face.is_empty() else null
	if sprite == null and speaker not in NARRATOR_SPEAKERS and is_instance_valid(_conversation_art) and _conversation_art is SpriteBase3D:
		sprite = _conversation_art as SpriteBase3D
	if sprite != null:
		ActorActing.ensure(sprite).call("act", beat, emote)


func cutscene_conclude() -> void:
	if not _chapter_cutscene_return.is_empty():
		var destination: Dictionary = _chapter_cutscene_return
		_chapter_cutscene_return = {}
		if bool(destination.get("stay", false)):
			player.global_position = destination.position
			player.velocity = Vector3.ZERO
			for node: Node3D in _film_hidden:
				if is_instance_valid(node):
					node.visible = true
			_film_hidden.clear()
			_refresh_hud()
			return
		_load_map(str(destination.map), str(destination.get("spawn", "default")))
		if bool(destination.get("road_east", false)):
			var road := _map_root.find_child("AwakenedRoad", true, false)
			if road != null:
				road.call("turn_east", 0.0)
		if destination.has("position"):
			player.global_position = destination.position
		player.velocity = Vector3.ZERO
		($CameraRig as Hd2dCameraRig).snap_to_target()
		return
	_load_map("village", "default")
	player.face_world_position(player.global_position + Vector3.FORWARD)


func _show_intro() -> void:
	dialogue_ui.show_dialogue([
		{"speaker": "旁白", "text": "月光已經三個晚上沒有照進暮光村了。月亮還在，只是光不再落到這裡。"},
		{"speaker": "旁白", "text": "月燈只剩最後一點光，霧在村外越聚越多。先四處看看，再去廣場左邊找長老。"},
		{"speaker": "系統", "text": "使用左側搖桿移動；靠近頭上有記號的人或物件後，點右側「互動」。" if MobileControls.is_mobile_device() else "使用 WASD 或方向鍵移動；靠近頭上有記號的人或物件後，按 Space 互動。M 靜音，- / = 調整音量。"},
	])


func _show_story_preview() -> void:
	GameState.start_quest()
	if "--story-ending" in OS.get_cmdline_user_args():
		GameState.defeat_guardian()
		GameState.flags["ruin_tablet_read"] = true
		player.position = Vector3(0, 0.1, 3.5)
		($CameraRig as Hd2dCameraRig).snap_to_target()
		_complete_main_quest()
	elif "--story-shard" in OS.get_cmdline_user_args():
		GameState.defeat_guardian()
		_on_battle_finished(true)
	else:
		_load_map("ruins", "from_village")
		var tablet := _map_root.find_child("MoonTabletVisual", true, false) as Node3D
		player.position = tablet.get_parent().position + Vector3(0, 0.1, 2.3)
		($CameraRig as Hd2dCameraRig).snap_to_target()
		_rest_at_moon_spring()


func _on_map_change_requested(map_id: String, spawn_id: String) -> void:
	call_deferred("_load_map", map_id, spawn_id)


func _load_map(map_id: String, spawn_id: String) -> void:
	_film_hidden.clear()
	($CameraRig as Hd2dCameraRig).release_shot(PORTAL_SHOT, true)
	player.auto_walk.cancel()
	_cancel_conversation_step()
	dialogue_ui.clear_illustration()
	var profile_started: int = Time.get_ticks_usec()
	if _map_root != null and is_instance_valid(_map_root):
		_retain_map_materials()
		_map_root.free()
	_profile_map_stamp("free_previous", profile_started)
	_moon_lamp_core = null
	_moon_lamp_light = null
	_village_gate_portal = null
	_village_gate_left = null
	_village_gate_right = null
	_village_gate_seal = null
	_village_gate_seal_core = null
	_village_gate_light = null
	_village_gate_marker = null
	_village_gate_is_open = false
	_portal_transition_pending = false
	_quest_markers.clear()
	_map_root = Node3D.new()
	_map_root.name = "Map_%s" % map_id.capitalize()
	add_child(_map_root)
	props.map_root = _map_root
	GameState.current_map = map_id
	GameState.spawn_id = spawn_id
	if not CryptLayout.NAMES.has(map_id):
		($CameraRig as Hd2dCameraRig).set_dungeon(false)
	var indoors := HouseCatalog.is_interior(map_id)
	player.set_presentation_scale(HouseCatalog.INTERIOR_CHARACTER_SCALE if indoors else 1.45 if CryptLayout.NAMES.has(map_id) else 1.0)
	# Canvas background follows the scene color pipeline in both renderers.
	# Compatibility's BG_COLOR + glow path lifts this dark clear color to purple.
	_interior_backdrop.visible = indoors
	_environment.background_mode = Environment.BG_CANVAS if indoors else Environment.BG_COLOR
	($CameraRig as Hd2dCameraRig).set_interior(indoors)
	$Moonlight.visible = not indoors
	_environment.fog_enabled = not indoors
	_environment.ambient_light_color = Color("d4bb98") if indoors else Color("6e83ad")
	_environment.ambient_light_energy = 0.65 if indoors else 0.48
	_environment.fog_density = 0.009
	($Moonlight as DirectionalLight3D).light_energy = 0.92
	($Moonlight as DirectionalLight3D).light_color = Color("b9c9ed")

	if indoors:
		var room: HouseInterior = preload("res://scripts/gameplay/city_house_interior.gd").new() if HouseCatalog.City.index_of(map_id) >= 0 else HouseInterior.new()
		room.name = "HouseInterior"
		room.house_id = map_id
		room.interaction_requested.connect(_handle_interaction)
		_map_root.add_child(room)
		_add_house_resident(map_id)
		room.configure_furniture_cutaway(player, get_viewport().get_camera_3d())
		_environment.background_color = Color("141119")
	elif Outskirts.NAMES.has(map_id):
		Outskirts.build(self, map_id)
		_environment.background_color = Color("101f24")
		_environment.fog_light_color = Color("375c60")
		_environment.fog_density = 0.006
		if map_id in ["starbay", "moss_steps", "wind_gorge", "moon_highland"]:
			_environment.ambient_light_energy = 0.58
	elif CryptLayout.NAMES.has(map_id):
		if CryptLayout.is_floor(map_id):
			Dungeon.build_floor(self, map_id)
		else:
			Dungeon.build(self)
		_environment.background_color = Color("101317")
		_environment.fog_light_color = Color("29282c")
		_environment.fog_density = 0.004
		_environment.ambient_light_color = Color("8295aa")
		_environment.ambient_light_energy = 0.28
		($Moonlight as DirectionalLight3D).light_energy = 0.20
	elif map_id == "ruins":
		_build_ruins()
		_environment.background_color = Color("100e1d")
		_environment.fog_light_color = Color("56506c")
	else:
		GameState.current_map = "village"
		_build_village()
		_environment.background_color = Color("111425")
		_environment.fog_light_color = Color("344b78")
		_environment.fog_density = 0.004
		_environment.ambient_light_color = Color("7892bd")
		_environment.ambient_light_energy = 0.50
		($Moonlight as DirectionalLight3D).light_energy = 0.70
		($Moonlight as DirectionalLight3D).light_color = Color("91b3ed")

	preload("res://scripts/gameplay/flower_clearance.gd").apply(_map_root)
	($CameraRig as Hd2dCameraRig).set_dungeon(CryptLayout.NAMES.has(map_id))
	var target_position := _get_spawn_position(GameState.current_map, spawn_id)
	if spawn_id == "saved_position" and GameState.has_saved_position:
		target_position = GameState.saved_position
		if GameState.current_map == "village":
			target_position = HouseCatalog.safe_village_position(target_position)
	var landscape: Node = _map_root.get_node_or_null("OutdoorLandscape")
	if landscape != null:
		target_position.y = maxf(target_position.y, float(landscape.soil_height(Vector2(target_position.x, target_position.z))) + 0.1)
	player.global_position = target_position
	player.velocity = Vector3.ZERO
	var recovery_position := _get_spawn_position(GameState.current_map, "default")
	if landscape != null:
		recovery_position.y = maxf(recovery_position.y, float(landscape.soil_height(Vector2(recovery_position.x, recovery_position.z))) + 0.1)
	player.ground_safety.reset(recovery_position)
	player.release_door_facing()
	player.reset_automatic_interaction()
	($CameraRig as Hd2dCameraRig).snap_to_target()
	($CameraRig as Hd2dCameraRig).configure_dialogue_scenery(_map_root)
	if HouseCatalog.is_interior(map_id) and spawn_id == "entry":
		player.face_world_position(player.global_position + Vector3.FORWARD)
	elif map_id in ["village", "starbay"] and spawn_id.begins_with("from_house_"):
		var home: Dictionary = HouseCatalog.find_home(spawn_id.trim_prefix("from_"))
		if not home.is_empty():
			player.face_world_position(player.global_position + Vector3.FORWARD.rotated(Vector3.UP, float(home.yaw)))
	if Outskirts.NAMES.has(map_id):
		var tree_visibility := preload("res://scripts/gameplay/tree_visibility.gd").new()
		tree_visibility.name = "TreeVisibility"
		_map_root.add_child(tree_visibility)
		tree_visibility.configure(_map_root, player, $CameraRig/Camera3D)
	GameMusic.sync_to_state()
	GameAmbience.sync_to_state()
	_refresh_hud()
	if spawn_id in ["from_base", "from_peak", "from_mountain", "from_east_road", "from_village", "from_forest", "from_road", "from_ruins", "from_caravan", "from_city"]:
		var destination: String = str(Outskirts.NAMES.get(GameState.current_map, "北境遺跡" if GameState.current_map == "ruins" else "暮光村"))
		_show_notice("抵達・" + destination)
	ChapterOne.on_map_loaded(self, GameState.current_map)
	_refresh_map_destinations()
	_profile_map_stamp("total_" + map_id, profile_started)
	map_presented.emit()


func _profile_map_stamp(stage: String, started: int) -> int:
	var now: int = Time.get_ticks_usec()
	if "--profile-map-build" in OS.get_cmdline_user_args():
		print("MAP_BUILD_PROFILE ", stage, " ms=", float(now - started) / 1000.0)
	return now


func _retain_map_materials() -> void:
	# Retain only the first material set per visited map for this world's lifetime.
	# Resources stay resident; nodes, collisions and gameplay state are rebuilt.
	var key := String(_map_root.name)
	if _resident_materials.has(key):
		return
	var materials: Array[Material] = []
	for node: Node in _map_root.find_children("*", "GeometryInstance3D", true, false):
		var instance := node as GeometryInstance3D
		if instance.material_override != null and not materials.has(instance.material_override):
			materials.append(instance.material_override)
		if instance.material_overlay != null and not materials.has(instance.material_overlay):
			materials.append(instance.material_overlay)
		var mesh: Mesh
		if instance is MeshInstance3D:
			mesh = (instance as MeshInstance3D).mesh
		elif instance is MultiMeshInstance3D:
			var batch := (instance as MultiMeshInstance3D).multimesh
			if batch != null:
				mesh = batch.mesh
		if mesh != null:
			for surface: int in range(mesh.get_surface_count()):
				var material: Material = instance.material_override
				if instance is MeshInstance3D:
					material = (instance as MeshInstance3D).get_active_material(surface)
				elif material == null:
					material = mesh.surface_get_material(surface)
				if material != null and not materials.has(material):
					materials.append(material)
	_resident_materials[key] = materials


func _get_spawn_position(map_id: String, spawn_id: String) -> Vector3:
	if CryptLayout.NAMES.has(map_id):
		return CryptLayout.spawn(map_id, spawn_id)
	if map_id == "east_road" and spawn_id == "from_crypt":
		return Vector3(-8, 0.1, 1)
	if map_id == "starbay" and spawn_id.begins_with("from_house_city_"):
		return HouseCatalog.return_position(spawn_id.trim_prefix("from_"))
	if Outskirts.NAMES.has(map_id):
		return Outskirts.spawn(map_id, spawn_id)
	if map_id == "village" and spawn_id == "from_east_road":
		return Vector3(24, 0.1, 4.6)
	if HouseCatalog.is_interior(map_id):
		return Vector3(0, 0.15, 1.9)
	if map_id in ["village", "starbay"] and spawn_id.begins_with("from_house_"):
		return HouseCatalog.return_position(spawn_id.trim_prefix("from_"))
	if map_id == "ruins":
		match spawn_id:
			"after_battle":
				return Vector3(0.0, 0.1, -5.8)
			_:
				return Vector3(0.0, 0.1, 13.85)
	match spawn_id:
		"from_ruins":
			return Vector3(0.0, 0.1, -18.05)
		_:
			return Vector3(0.0, 0.1, 7.5)


func _build_village() -> void:
	var stamp: int = Time.get_ticks_usec()
	VillageMap.roads(props)
	# Beams and the name board fade while the traveler walks under the arch.
	for part: Node in _map_root.get_node("VillageEastGate").get_children():
		if part is MeshInstance3D and (part as MeshInstance3D).position.y > 1.9:
			var cutaway := ForegroundCutaway.new()
			part.add_child(cutaway)
			cutaway.configure(part as Node3D, player, $CameraRig/Camera3D, &"gate_cutaways")
	Outskirts.add_interaction(self, "travel_east", "東行・前往東行舊道", Vector3(26, 0, 4.6), true)
	VillageMap.walks(props)
	stamp = _profile_map_stamp("village_surfaces", stamp)

	for column_position in [Vector3(-4.6, 0.0, -3.6), Vector3(4.6, 0.0, -3.6), Vector3(-4.6, 0.0, 3.6), Vector3(4.6, 0.0, 3.6)]:
		_add_column(column_position)
	VillageMap.plaza(props)
	# Eight homes form west, east, north, and south neighborhoods around the plaza.
	stamp = _profile_map_stamp("village_columns_trees_lights", stamp)
	for home: Dictionary in HouseCatalog.HOMES:
		_add_house(home.position, home.wall, home.roof, home.yaw, home.id)
	stamp = _profile_map_stamp("village_houses", stamp)

	VillageMap.dressing(props)
	stamp = _profile_map_stamp("village_props_gardens", stamp)

	_add_moon_lamp(Vector3(0.0, 0.0, 0.0))
	_map_root.add_child(preload("res://scripts/gameplay/awakened_road.gd").new())
	VillageMap.moon_garden(_map_root)
	stamp = _profile_map_stamp("village_moon_lamp", stamp)
	_add_actor_interactable("elder", "與長老交談", Vector3(-3.0, 0.0, 1.2), "res://assets/generated/elder.tres", 1.6 / 724.0, Color.WHITE, false, MAIN_QUEST_MARKER)
	_add_actor_interactable("rumi", "與露米交談", Vector3(6.4, 0.0, 4.2), "res://assets/generated/rumi.tres", 1.6 / 724.0, Color.WHITE, false, SIDE_CONTENT_MARKER)
	if not ChapterOne.noah_left_gate():
		_add_actor_interactable("noah", "與守門人交談", Vector3(2.2, 0.0, -17.0), "res://assets/generated/noah.tres", 1.6 / 724.0, Color.WHITE)
	_add_wandering_villagers()
	_add_portal("portal_to_ruins", "前往北境遺跡", Vector3(0.0, 0.0, -19.3), Color("86d9ff"))
	stamp = _profile_map_stamp("village_actors_portal", stamp)
	MeadowDressing.build(_map_root)
	stamp = _profile_map_stamp("village_meadow", stamp)
	VillageMap.surroundings(_map_root)
	_profile_map_stamp("village_surroundings", stamp)


func _add_wandering_villagers() -> void:
	var routes: Array[PackedVector3Array] = [
		PackedVector3Array([Vector3(2.8, 0.15, 2.2), Vector3(2.8, 0.15, -2.2)]),
		PackedVector3Array([Vector3(-3.0, 0.15, 5.5), Vector3(-9.0, 0.15, 5.5)]),
		PackedVector3Array([Vector3(0.0, 0.15, -6.0), Vector3(0.0, 0.15, -12.0)]),
	]
	for index: int in range(routes.size()):
		var patrol: Dictionary = HouseCatalog.STREET_PATROLS[index]
		var resident: Dictionary = HouseCatalog.RESIDENTS[patrol.house_id]
		var villager := preload("res://scripts/gameplay/wandering_villager.gd").new()
		villager.name = "WalkingVillager%d" % (index + 1)
		villager.route = routes[index]
		villager.position = routes[index][0]
		villager.player = player
		villager.resident_id = str(resident.art).get_file()
		villager.display_name = str(resident.name)
		villager.dialogue_text = str(patrol.text)
		villager.conversation_requested.connect(_talk_to_wandering_villager)
		villager.speed = VILLAGER_SPEEDS[index]
		villager.wait_time = float(index) * 0.8
		_map_root.add_child(villager)


func _talk_to_wandering_villager(villager: CharacterBody3D) -> void:
	if GameState.is_input_locked() or _portal_transition_pending or GameState.current_map not in ["village", "starbay"]:
		return
	dialogue_ui.show_dialogue([{"speaker": str(villager.get("display_name")), "text": str(villager.get("dialogue_text"))}])
	_begin_actor_conversation(villager)


## Stage a face-to-face talk after its dialogue has opened: both characters
## turn (the partner after a short reaction), the camera frames the pair and
## the hero eases back to talking distance while DIALOGUE locks input.
func _begin_actor_conversation(actor: Node3D, frame_shot: bool = true) -> void:
	if not is_instance_valid(actor) or not dialogue_ui.is_open():
		return
	player.velocity.x = 0.0
	player.velocity.z = 0.0
	player.face_world_position(actor.global_position)
	var art := actor.get_node_or_null("CharacterArt") as Node3D
	_conversation_art = art
	if art != null:
		art.call("turn_to", player)
		if frame_shot:
			($CameraRig as Hd2dCameraRig).begin_dialogue_shot(art)
	# The first line began typing before the partner was known.
	if not dialogue_ui.revealing_speaker().is_empty():
		_on_line_revealing(dialogue_ui.revealing_speaker(), true)
	_step_back_for_conversation(actor)


func is_conversation_step_active() -> bool:
	return _conversation_step_active


func _step_back_for_conversation(partner: Node3D) -> void:
	if _conversation_step_active:
		return
	# Saves or scripted placement can start inside the speaker; let the step
	# leave that body while still sweeping against walls and other characters.
	var bodies: Array[PhysicsBody3D] = []
	var candidates: Array[Node] = partner.find_children("*", "PhysicsBody3D", true, false)
	if partner is PhysicsBody3D:
		candidates.append(partner)
	for node: Node in candidates:
		var body := node as PhysicsBody3D
		if body != player and not player.get_collision_exceptions().has(body):
			player.add_collision_exception_with(body)
			bodies.append(body)
	var destination := _conversation_step_destination(partner)
	if destination.is_equal_approx(player.global_position):
		for body: PhysicsBody3D in bodies:
			player.remove_collision_exception_with(body)
		return
	_conversation_step_active = true
	_conversation_step_bodies = bodies
	player.lock_door_facing(partner.global_position)
	await player.walk_to_door_point(destination, CONVERSATION_STEP_SPEED)
	_finish_conversation_step()


func _conversation_step_destination(partner: Node3D) -> Vector3:
	var away: Vector3 = player.global_position - partner.global_position
	away.y = 0.0
	if away.length() >= Wanderer.CONVERSATION_DISTANCE - CONVERSATION_STEP_TOLERANCE:
		return player.global_position
	if away.is_zero_approx():
		away = ($CameraRig/Camera3D as Camera3D).global_basis.x
		away.y = 0.0
	away = away.normalized()
	# Shortest retreat first, then nearby sides when scenery blocks it.
	for degrees: float in CONVERSATION_RETREAT_ANGLES:
		var destination: Vector3 = partner.global_position + away.rotated(Vector3.UP, deg_to_rad(degrees)) * (Wanderer.CONVERSATION_DISTANCE + CONVERSATION_STEP_MARGIN)
		destination.y = player.global_position.y
		if not player.test_move(player.global_transform, destination - player.global_position):
			return destination
	return player.global_position


func _finish_conversation_step() -> void:
	if not _conversation_step_active:
		return
	_conversation_step_active = false
	player.axis_lock_linear_x = false
	player.axis_lock_linear_z = false
	_restore_conversation_collisions()
	if GameState.mode in [GameState.Mode.DIALOGUE, GameState.Mode.EXPLORE]:
		player.release_door_facing()


func _restore_conversation_collisions() -> void:
	# Remove exceptions while the partner still exists; a freed body would
	# leave a dangling physics RID in the player's exception list.
	for body: PhysicsBody3D in _conversation_step_bodies:
		if is_instance_valid(body):
			player.remove_collision_exception_with(body)
	_conversation_step_bodies.clear()


## Stop an unfinished step when its conversation ends or the map changes.
## Locked planar axes make the scripted walk see zero travel and return.
func _cancel_conversation_step() -> void:
	if _conversation_step_active:
		player.axis_lock_linear_x = true
		player.axis_lock_linear_z = true
		_restore_conversation_collisions()


func _on_conversation_state_changed() -> void:
	if GameState.mode == GameState.Mode.DIALOGUE:
		return
	_cancel_conversation_step()
	_set_speaking(null)
	_conversation_art = null


func _on_line_revealing(speaker: String, active: bool) -> void:
	var life: Node = null
	if PortraitFaces.speaker_face_id(speaker) == "hero":
		life = BodyLife.find(player.sprite)
	elif speaker not in NARRATOR_SPEAKERS and is_instance_valid(_conversation_art):
		life = BodyLife.find(_conversation_art)
	if active:
		_set_speaking(life)
	elif life == _speaking_life:
		_set_speaking(null)


func _set_speaking(life: Node) -> void:
	if is_instance_valid(_speaking_life) and _speaking_life != life:
		_speaking_life.set("speaking", false)
	_speaking_life = life
	if is_instance_valid(life):
		life.set("speaking", true)


func _build_ruins() -> void:
	RuinsMap.terrain(props)
	var ruin_columns: Array[Vector3] = [
		Vector3(-6.2, 0.0, -8.8), Vector3(6.2, 0.0, -8.8), Vector3(-6.2, 0.0, -1.5), Vector3(6.2, 0.0, -1.5),
		Vector3(-6.2, 0.0, 6.2), Vector3(6.2, 0.0, 6.2), Vector3(-11.0, 0.0, 3.8), Vector3(11.0, 0.0, -1.5),
	]
	for column_position: Vector3 in ruin_columns:
		_add_column(column_position)
	RuinsMap.dressing(props, ruin_columns)

	_add_pedestal_interactable("ruin_tablet", "閱讀風化石碑", Vector3(-9.0, 0.0, 4.0), Color("8f86ac"))
	_add_pedestal_interactable("moon_spring", "觸碰月泉", Vector3(9.0, 0.0, -1.5), Color("76e5d5"))
	_add_portal("portal_to_village", "返回暮光村", Vector3(0.0, 0.0, 15.1), Color("86d9ff"))
	if not bool(GameState.flags.get("guardian_defeated", false)):
		_add_actor_interactable(
			"guardian",
			"挑戰遺跡守衛",
			Vector3(0.0, 0.0, -8.2),
			"res://assets/generated/guardian_front.tres",
			1.6 / 640.0,
			Color.WHITE,
			false,
			MAIN_QUEST_MARKER
		)
	else:
		props.add_crystal(Vector3(0.0, 0.0, -8.2), 0.65)


func _add_house_resident(house_id: String) -> void:
	var resident: Dictionary = HouseCatalog.resident(house_id)
	# Keep the resident in the central aisle, clear of the table and bed divider.
	_add_actor_interactable("house_resident", "與" + str(resident.name) + "交談",
		Vector3(-0.75, 0.024, 0.0), "res://assets/generated/" + str(resident.art) + ".tres",
		1.6 / 512.0 * HouseCatalog.INTERIOR_CHARACTER_SCALE, resident.tint)
	var actor := _map_root.get_node("HouseResident") as Node3D
	(actor.get_node("CharacterArt") as Sprite3D).billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	actor.get_node("ContactShadow").scale = Vector3(HouseCatalog.INTERIOR_CHARACTER_SCALE, 1.0, HouseCatalog.INTERIOR_CHARACTER_SCALE)
	(actor.get_node("InteractionMarker") as Node3D).position.y = 2.05
	var body := StaticBody3D.new()
	body.name = "ResidentBody"
	var collider := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.26
	capsule.height = 1.4
	collider.shape = capsule
	collider.position.y = 0.7
	body.add_child(collider)
	actor.add_child(body)


func _open_house_door(destination: String) -> void:
	var source_map: Node3D = _map_root
	var doorway: Node3D
	var hinge: Node3D
	for house: Node in source_map.get_children():
		if house.get_meta("house_id", "") == destination:
			doorway = house as Node3D
			hinge = house.get_node("ArchitecturalDetails/DoorHinge") as Node3D
			break
	if hinge == null:
		_portal_transition_pending = false
		return
	GameState.set_mode(GameState.Mode.TRANSITION)
	player.velocity = Vector3.ZERO
	player.lock_door_facing(doorway.global_position)
	var approach := doorway.to_global(Vector3(0, 0, -2.24) * HouseCatalog.EXTERIOR_SCALE)
	if not await player.walk_to_door_point(approach, 2.0):
		player.release_door_facing()
		_portal_transition_pending = false
		GameState.set_mode(GameState.Mode.EXPLORE)
		return
	player.face_world_position(doorway.global_position)
	await DoorInteraction.animate(player, hinge)
	if not is_instance_valid(doorway):
		return
	var threshold := doorway.to_global(Vector3(0, 0, -1.92) * HouseCatalog.EXTERIOR_SCALE)
	if not await player.walk_to_door_point(threshold):
		await DoorInteraction.animate(player, hinge, true)
		player.release_door_facing()
		_portal_transition_pending = false
		GameState.set_mode(GameState.Mode.EXPLORE)
		return
	if is_instance_valid(source_map) and source_map == _map_root and GameState.current_map == HouseCatalog.parent_map(destination):
		GameState.request_map(destination, "entry")
		await map_presented
	if GameState.mode == GameState.Mode.TRANSITION:
		GameState.set_mode(GameState.Mode.EXPLORE)


func _leave_house() -> void:
	var source_map: Node3D = _map_root
	var source_id: String = GameState.current_map
	var room := source_map.get_node("HouseInterior") as HouseInterior
	GameState.set_mode(GameState.Mode.TRANSITION)
	player.velocity = Vector3.ZERO
	player.lock_door_facing(room.to_global(Vector3(0, 0, 3.37)))
	if not await player.walk_to_door_point(room.to_global(Vector3(0, 0, 2.72)), 2.0):
		player.release_door_facing()
		_portal_transition_pending = false
		GameState.set_mode(GameState.Mode.EXPLORE)
		return
	await DoorInteraction.animate(player, room.get_exit_door_hinge())
	if is_instance_valid(source_map) and source_map == _map_root and GameState.current_map == source_id:
		GameState.request_map(HouseCatalog.parent_map(source_id), "from_" + source_id)
		await _close_arrival_door(source_id)
	if GameState.mode == GameState.Mode.TRANSITION:
		GameState.set_mode(GameState.Mode.EXPLORE)


func _close_arrival_door(home_id: String) -> void:
	await map_presented
	var hinge: Node3D
	var target: Vector3
	var reach_point: Vector3
	if HouseCatalog.is_interior(GameState.current_map):
		var room := _map_root.get_node("HouseInterior") as HouseInterior
		hinge = room.get_exit_door_hinge()
		target = room.to_global(Vector3(0, 0, 3.37))
		reach_point = room.to_global(Vector3(0, 0, 2.72))
	else:
		for house: Node in _map_root.get_children():
			if house.get_meta("house_id", "") == home_id:
				hinge = house.get_node("ArchitecturalDetails/DoorHinge") as Node3D
				target = (house as Node3D).global_position
				reach_point = (house as Node3D).to_global(Vector3(0, 0, -2.24) * HouseCatalog.EXTERIOR_SCALE)
				break
	if hinge == null:
		return
	GameState.set_mode(GameState.Mode.TRANSITION)
	var onward := Vector3.FORWARD
	if not HouseCatalog.is_interior(GameState.current_map):
		onward = onward.rotated(Vector3.UP, float(HouseCatalog.find_home(home_id).yaw))
	var arrival := player.global_position
	hinge.rotation.y = DoorInteraction.OPEN_ANGLE
	player.lock_door_facing(target)
	if await player.walk_to_door_point(reach_point, 2.0):
		await DoorInteraction.animate(player, hinge, true)
	else:
		var closing := hinge.create_tween()
		closing.tween_property(hinge, "rotation:y", 0.0, 0.5)
		await closing.finished
	# Return outside the automatic-interaction zone before restoring input.
	# Release the door facing first so the hero turns and walks away.
	player.release_door_facing()
	await player.walk_to_door_point(arrival, 2.0)
	player.face_world_position(player.global_position + onward)


func _handle_interaction(interaction_id: String) -> void:
	if GameState.is_input_locked() or _portal_transition_pending:
		return
	if ChapterOne.handle(self, interaction_id):
		var speaker := _map_root.get_node_or_null(NodePath(interaction_id.capitalize()))
		if interaction_id == "party_talk":
			# Frame the nearest companion, so the person talking is the one on screen.
			var nearest_distance := INF
			for follower: Node in get_tree().get_nodes_in_group("party_followers"):
				var distance := (follower as Node3D).global_position.distance_to(player.global_position)
				if distance < nearest_distance:
					nearest_distance = distance
					speaker = follower
			if speaker != null and dialogue_ui.is_open():
				_begin_actor_conversation(speaker as Node3D)
			return
		if speaker != null and dialogue_ui.is_open() and interaction_id in ["elder", "rumi", "sia", "ch1_noah", "road_traveler", "gate_watch"]:
			_begin_actor_conversation(speaker as Node3D)
		return
	if interaction_id in ["crypt_spring_1", "crypt_cache_2", "crypt_lore_1", "crypt_lore_2"]:
		var lore: String = GameState.resolve_crypt_event(interaction_id)
		if not lore.is_empty():
			dialogue_ui.show_dialogue([{ "speaker": "墓窟遺跡", "text": lore }])
		return
	if interaction_id == "crypt_reliquary" and GameState.current_map == "ashen_crypt":
		GameState.claim_crypt_reward()
		return
	if interaction_id == "shop_inn_rest" and GameState.current_map == "house_city_01":
		GameState.restore_player()
		dialogue_ui.show_dialogue([{ "speaker": "小春・旅店掌櫃", "text": "醒啦，熱茶就在床邊。\n（生命與魔力已恢復。）" }])
		var keeper := _map_root.get_node_or_null("HouseResident") as Node3D
		if keeper != null:
			_begin_actor_conversation(keeper, false)
		return
	if interaction_id == "house_resident" and HouseCatalog.is_interior(GameState.current_map):
		var resident: Dictionary = HouseCatalog.resident(GameState.current_map)
		var actor := _map_root.get_node("HouseResident") as Node3D
		dialogue_ui.show_dialogue([{"speaker": resident.name, "text": resident.text}])
		_begin_actor_conversation(actor, false)
		return
	if interaction_id.begins_with("enter_house_"):
		var destination := interaction_id.trim_prefix("enter_")
		if HouseCatalog.is_interior(destination) and GameState.current_map == HouseCatalog.parent_map(destination):
			_portal_transition_pending = true
			_open_house_door(destination)
		return
	if Starbay.Civic.TALKS.has(interaction_id) and GameState.current_map == "starbay":
		var civic_talk: Array = Starbay.Civic.TALKS[interaction_id]
		dialogue_ui.show_dialogue([{ "speaker": civic_talk[0], "text": civic_talk[1] }])
		return
	if Starbay.TALKS.has(interaction_id) and GameState.current_map == "starbay":
		var talk: Array = Starbay.TALKS[interaction_id]
		if interaction_id == "city_rest":
			GameState.restore_player()
		dialogue_ui.show_dialogue([{ "speaker": talk[0], "text": talk[1] }])
		return
	if interaction_id == "highland_view" and GameState.current_map == "moon_highland":
		dialogue_ui.show_dialogue([{ "speaker": "月冠眺望台", "text": "雲海從層疊的山脊間緩緩流過。來時的石徑已化作山腰的一道細線，暮光村的燈火在遠處閃爍。" }])
		return
	if Outskirts.EXITS.has(interaction_id):
		var route: Array = Outskirts.EXITS[interaction_id]
		if GameState.current_map == route[0]:
			var vortex: Node3D = _portal_vortex(interaction_id)
			if vortex != null:
				_cross_portal(str(route[1]), str(route[2]), vortex.call("opening_center"), vortex)
				return
			_portal_transition_pending = true
			GameState.request_map(route[1], route[2])
		return
	if Outskirts.EVENTS.has(interaction_id):
		var event: Array = Outskirts.EVENTS[interaction_id]
		if GameState.current_map == event[0]:
			var event_lines: Array[Dictionary] = [{ "speaker": "驛路旅人" if interaction_id == "road_traveler" else event[2], "text": GameState.resolve_outskirts_event(interaction_id) }]
			if interaction_id == "road_traveler" and not ChapterOne.road_traveler_line().is_empty():
				event_lines.append({ "speaker": "驛路旅人", "text": ChapterOne.road_traveler_line() })
			dialogue_ui.show_dialogue(event_lines)
			var traveler := _map_root.get_node_or_null(NodePath(interaction_id.capitalize())) as Node3D
			if interaction_id == "road_traveler" and traveler != null:
				_begin_actor_conversation(traveler)
		return
	if interaction_id == "leave_house":
		if HouseCatalog.is_interior(GameState.current_map):
			_portal_transition_pending = true
			_leave_house()
		return
	if interaction_id == "inspect_house_shelf":
		if not HouseCatalog.is_interior(GameState.current_map):
			return
		var furniture: Dictionary = HouseCatalog.furniture(GameState.current_map)
		var text: String = str(furniture.text)
		if GameState.current_map == "house_02" and GameState.quest_state != GameState.QuestState.COMPLETE:
			text = "三盆幼苗在微光裡垂著葉子。盆邊的舊字條寫著：『月光回來的時候，新葉會朝村外長。』"
		var shelf_lines: Array[Dictionary] = [{"speaker": furniture.name, "text": text}]
		# City libraries keep the old street map: optional lore beyond the main path.
		if GameState.current_map.begins_with("house_city_") and str(HouseCatalog.City.home(GameState.current_map).kind) == "library":
			shelf_lines.append_array(ChapterOne.city_map_lines())
		dialogue_ui.show_dialogue(shelf_lines)
		return
	match interaction_id:
		"elder":
			_talk_to_elder()
		"rumi":
			_talk_to_rumi()
		"noah":
			_talk_to_noah()
		"moon_lamp":
			_inspect_moon_lamp()
		"portal_to_ruins":
			_try_enter_portal(interaction_id)
		"portal_to_village":
			_try_enter_portal(interaction_id)
		"ruin_tablet":
			_read_ruin_tablet()
		"moon_spring":
			_rest_at_moon_spring()
		"guardian":
			_talk_to_guardian()
	if interaction_id in ["elder", "rumi", "noah"] and dialogue_ui.is_open():
		var speaker := _map_root.get_node_or_null(NodePath(interaction_id.capitalize()))
		if speaker != null:
			_begin_actor_conversation(speaker as Node3D)


func _talk_to_elder() -> void:
	match GameState.quest_state:
		GameState.QuestState.NOT_STARTED:
			dialogue_ui.show_dialogue([
				{"speaker": "長老・艾爾", "text": "旅人，霧已經到村口了。月燈今晚要是熄了，霧就會進村。"},
				{"speaker": "長老・艾爾", "text": "北邊的遺跡裡有一塊月光碎片。把它放進月燈，燈就能再亮起來。"},
				{"speaker": "旅人", "text": "我在月燈旁聽見一句話：「把借走的光還回去。」那是什麼意思？"},
				{"speaker": "長老・艾爾", "text": "……先讓大家撐過今晚。其他的事，等燈亮了再說。"},
				{"speaker": "長老・艾爾", "text": "我去打開北門。諾亞關好門就會追上你，我隨後也到。"},
				{"speaker": "旅人", "text": "艾妲替我補過外衣，露米每晚都送湯來。我會把碎片帶回來。"},
			], GameState.start_quest)
		GameState.QuestState.ACTIVE:
			dialogue_ui.show_dialogue([
				{"speaker": "長老・艾爾", "text": "沿著遺跡裡發光的石路走，就會找到守衛。"},
				{"speaker": "長老・艾爾", "text": "受了傷，就去找那口還在發光的泉水。"},
			])
		GameState.QuestState.READY_TO_TURN_IN:
			dialogue_ui.show_dialogue([
				{"speaker": "旅人", "text": "碎片拿回來了。"},
				{"speaker": "長老・艾爾", "text": "好……把它放進燈心吧。看看月光還願不願意回來。"},
			], _complete_main_quest)
		GameState.QuestState.COMPLETE:
			dialogue_ui.show_dialogue([
				{"speaker": "長老・艾爾", "text": "燈亮了，霧也退回森林了。謝謝你，旅人。"},
				{"speaker": "長老・艾爾", "text": "我知道碎片會叫醒某樣東西，卻不知道會是什麼。我沒有全部告訴你……對不起。"},
				{"speaker": "長老・艾爾", "text": "手上這個記號，我在父親的舊書裡見過。再給我一點時間。"},
			])


func _talk_to_rumi() -> void:
	if not bool(GameState.flags.get("rumi_tip_seen", false)):
		GameState.flags["rumi_tip_seen"] = true
		GameState.state_changed.emit()
	match GameState.quest_state:
		GameState.QuestState.NOT_STARTED:
			dialogue_ui.show_dialogue([
				{"speaker": "村童・露米", "text": "以前月燈一亮，廣場就跟白天一樣。現在連小豬都不敢靠近村口。"},
				{"speaker": "村童・露米", "text": "還有，好奇怪喔。燈旁邊的影子沒有躲開光，全都朝北邊伸過去。"},
				{"speaker": "村童・露米", "text": "媽媽說你的外衣補好了。艾爾爺爺好像知道發生什麼事，你幫我們問問他好不好？"},
			])
		GameState.QuestState.ACTIVE:
			dialogue_ui.show_dialogue([{"speaker": "村童・露米", "text": "湯我會幫你熱著。一定要回來喔。"}])
		GameState.QuestState.READY_TO_TURN_IN:
			dialogue_ui.show_dialogue([{"speaker": "村童・露米", "text": "你的包包在發光！快拿去給艾爾爺爺！"}])
		GameState.QuestState.COMPLETE:
			dialogue_ui.show_dialogue([{"speaker": "村童・露米", "text": "小豬都跑回來了！媽媽說今晚的湯要多加一塊肉。"}])


func _talk_to_noah() -> void:
	match GameState.quest_state:
		GameState.QuestState.NOT_STARTED:
			dialogue_ui.show_dialogue([
				{"speaker": "守門人・諾亞", "text": "北門已經關了十二年。沒有長老的月印，誰都不能出去。"},
				{"speaker": "守門人・諾亞", "text": "不過……你來的那天晚上，門上的月紋自己亮了一下。"},
			])
		GameState.QuestState.ACTIVE:
			dialogue_ui.show_dialogue([
				{"speaker": "守門人・諾亞", "text": "門開了。我把門關好，馬上去追你。"},
				{"speaker": "系統", "text": "戰鬥：方向鍵移動，J 攻擊、K 技能、空白鍵閃避，Tab 切換隊員。"},
			])
		GameState.QuestState.READY_TO_TURN_IN:
			dialogue_ui.show_dialogue([{"speaker": "守門人・諾亞", "text": "門又亮起來了，我就知道你成功了。長老在月燈旁等你。"}])
		GameState.QuestState.COMPLETE:
			dialogue_ui.show_dialogue([
				{"speaker": "守門人・諾亞", "text": "霧退了。可是我一直在想，門關著的時候，被擋在外面的是誰。"},
				{"speaker": "守門人・諾亞", "text": "十二年前，也有人在霧裡敲這扇門，敲了一整晚。長老叫我別回頭……天亮前，敲門聲就停了。"},
			])


func _inspect_moon_lamp() -> void:
	match GameState.quest_state:
		GameState.QuestState.NOT_STARTED:
			dialogue_ui.show_dialogue([
				{"speaker": "月燈", "text": "燈裡只剩一點冷冷的光，好像隨時會熄。"},
				{"speaker": "不明低語", "text": "……把借走的光，還給原本的路。"},
				{"speaker": "旅人", "text": "是誰在說話？"},
			])
		GameState.QuestState.ACTIVE:
			dialogue_ui.show_dialogue([{"speaker": "月燈", "text": "光又弱了一點。得快點把碎片帶回來。"}])
		GameState.QuestState.READY_TO_TURN_IN:
			dialogue_ui.show_dialogue([{"speaker": "月燈", "text": "包裡的碎片和燈心一起微微發亮。先拿給長老吧。"}])
		GameState.QuestState.COMPLETE:
			dialogue_ui.show_dialogue([{"speaker": "月燈", "text": "月光灑滿廣場。可是石縫裡有一道光，一直往村外延伸。"}])


func _read_ruin_tablet() -> void:
	GameState.flags["ruin_tablet_read"] = true
	GameState.state_changed.emit()
	dialogue_ui.show_dialogue([
		{"speaker": "風化石碑", "text": "『月光不是用來趕走黑暗，是用來帶人穿過黑暗。』"},
		{"speaker": "風化石碑", "text": "『守燈的人，不可以把光留給自己……不可以為了一個地方的平安，讓路上的人永遠迷路。』"},
		{"speaker": "旅人", "text": "下面刻著一個缺了口的圓環。旁邊的名字，被人故意磨掉了。"},
	])


func _rest_at_moon_spring() -> void:
	var memory: Texture2D = props.art_texture("res://assets/generated/moon_spring_memory.png")
	var needs_rest := GameState.player_hp < GameState.player_max_hp or GameState.player_mp < GameState.player_max_mp
	var lines: Array[Dictionary] = [
		{"speaker": "月泉", "text": "水面浮出一段畫面：很多人提著燈走在霧裡，直到一道牆擋住了路。有人在牆外敲門。", "illustration": memory, "cinematic": "moon_memory"},
	]
	if needs_rest:
		GameState.restore_player()
		lines.append({"speaker": "月泉", "text": "畫面散去，清涼的光流過全身。HP 與 MP 已完全恢復。"})
	else:
		lines.append({"speaker": "旅人", "text": "我沒受傷……可是那個敲門的人，為什麼要讓我看見？"})
	if GameState.quest_state == GameState.QuestState.ACTIVE:
		lines.append({"speaker": "系統", "text": "WASD 移動，J 攻擊、K 技能、空白鍵閃避。看到紅色預警，確認範圍後離開。Tab 換人、Q/E 轉鏡頭，石柱可以擋攻擊。"})
		lines.append({"speaker": "系統", "text": "諾亞能保護隊友，艾爾能治療隊友（不能復活）。霜星爆打中間的敵人可以波及三個。普通攻擊不花 MP。"})
		lines.append({"speaker": "系統", "text": "挑戰前可以調整三人的裝備並存檔。全隊倒下會回到村子，可以再試一次。"})
	dialogue_ui.show_dialogue(lines)


func _talk_to_guardian() -> void:
	if GameState.quest_state != GameState.QuestState.ACTIVE or bool(GameState.flags.get("guardian_defeated", false)):
		return
	var lines: Array[Dictionary] = []
	if bool(GameState.flags.get("ruin_tablet_read", false)):
		lines.append({"speaker": "遺跡守衛", "text": "你讀了石碑上的誓言，也看到了那個被磨掉名字的圓環。"})
	else:
		lines.append({"speaker": "遺跡守衛", "text": "碎片能救你的村子，也會叫醒一條被關起來的路。"})
	lines.append({"speaker": "遺跡守衛", "text": "光被關在一個地方，霧裡的路就更暗。你要帶回去的，是希望，還是另一道牆？"})
	lines.append({"speaker": "遺跡守衛", "text": "狼是只想活下去的害怕，術士是想把光據為己有的貪心。我們三個，一起來問你。"})
	lines.append({"speaker": "旅人", "text": "我還不知道答案。但村裡有人在等我回去。"})
	lines.append({"speaker": "諾亞", "text": "我跟著你。這一次，我不會再假裝沒聽見。"})
	lines.append({"speaker": "系統", "text": "諾亞和艾爾會自動幫忙，Tab 可以換人。閃開紅色預警，趁敵人收招時反擊；霜星爆能打到附近的敵人。"})
	dialogue_ui.show_dialogue(lines, _start_guardian_battle)


func _complete_main_quest() -> void:
	GameState.complete_quest()
	_update_moon_lamp_state()
	GameState.remember_player_position(player.global_position)
	if not _test_mode:
		GameState.save_game(GameState.SAVE_PATH, false)
	var ending_lines: Array[Dictionary] = [
		{"speaker": "旁白", "text": "碎片融進燈心。白色的光沿著石縫散開，村外的霧慢慢退去。"},
		{"speaker": "村童・露米", "text": "月光回來了！小豬也跑回廣場了！"},
		{"speaker": "旁白", "text": "歡呼聲中，石縫亮起一條往村外延伸的光路。艾爾手上的月印，燒出了一個缺口的圓環。"},
		{"speaker": "長老・艾爾", "text": "……路醒了。我知道會這樣。可是不點燈，大家今晚就撐不過去。"},
	]
	if bool(GameState.flags.get("ruin_tablet_read", false)):
		ending_lines.append({"speaker": "旅人", "text": "遺跡的石碑上也有這個圓環。它的名字，被人刻意抹去了。"})
	var awakening := load("res://assets/generated/fog_awakening.png") as Texture2D
	ending_lines.append({"speaker": "旁白", "text": "遠方的霧裡，有什麼東西睜開了眼睛。", "illustration": awakening, "motion": "awakening"})
	ending_lines.append({"speaker": "霧中之聲", "text": "最後一盞燈……終於又亮了。", "illustration": awakening, "motion": "awakening"})
	ending_lines.append({"speaker": "系統", "text": "序章〈熄滅的月燈〉完成。可以繼續和村民聊天、逛村裡的房子，或往東邊的路走走看。"})
	var seal: Node3D = preload("res://scripts/gameplay/keeper_seal_motion.gd").new()
	seal.last_reveal_page = 4 if bool(GameState.flags.get("ruin_tablet_read", false)) else 3
	seal.bind_actor(_map_root.get_node("Elder/CharacterArt") as Sprite3D)
	_map_root.add_child(seal)
	dialogue_ui.page_shown.connect(seal.show_for_page)
	var seal_reference: WeakRef = weakref(seal)
	dialogue_ui.show_dialogue(ending_lines, func() -> void:
		var presentation := seal_reference.get_ref() as Node3D
		if presentation != null:
			presentation.queue_free()
	)


func _start_guardian_battle() -> void:
	battle_ui.configure_world(_map_root, player, $CameraRig, _map_root.get_node_or_null("Guardian"))
	battle_ui.start_battle({
		"name": "遺跡守衛",
		"max_hp": 64,
		"attack": 14,
		"defense": 3,
	})


func _on_battle_finished(victory: bool) -> void:
	if victory:
		# Keep the actual map and traveler position after an in-world encounter.
		if GameState.current_map != "ruins":
			_load_map("ruins", "after_battle") # Story preview only.
		var guardian := _map_root.get_node_or_null("Guardian")
		if guardian != null:
			guardian.queue_free()
		_quest_markers.erase("guardian")
		GameState.remember_player_position(player.global_position)
		if not _test_mode:
			GameState.save_game(GameState.SAVE_PATH, false)
		var shard := MoonShard.new()
		shard.name = "MoonShardReward"
		shard.position = (battle_ui.reward_position if battle_ui.reward_position != Vector3.ZERO else Vector3(0, 0, -8.2)) + Vector3.UP * 1.5
		shard.rotation.y = ($CameraRig/Camera3D as Camera3D).global_rotation.y + PI
		shard.scale = Vector3.ONE * 1.3
		_map_root.add_child(shard)
		shard.fly_to(player.position + Vector3.UP * 2.3)
		var shard_reference: WeakRef = weakref(shard)
		dialogue_ui.show_dialogue([
			{"speaker": "遺跡守衛", "text": "你們證明的，不是能把它搶走，而是身邊還有人願意保護你、治療你、陪你走。燈亮的時候，路也會醒來。"},
			{"speaker": "旁白", "text": "守衛化成光點散去。碎片自己飛向旅人，邊上缺了一角，像一個沒閉合的圓環。"},
		], func() -> void:
			var presentation := shard_reference.get_ref() as Node3D
			if presentation != null:
				presentation.queue_free()
		)
	else:
		GameState.restore_after_defeat()
		dialogue_ui.show_dialogue([
			{"speaker": "旁白", "text": "村民在遺跡入口找到你，把你帶回了村子。"},
			{"speaker": "系統", "text": "HP 與 MP 已恢復，北門還開著。調整裝備後可以再挑戰；用掉的藥水不會補回。"},
		], func() -> void: GameState.request_map("village", "default"))


func _add_actor_interactable(interaction_id: String, prompt: String, world_position: Vector3, texture_path: String, pixel_size: float, tint: Color, atlas_character: bool = false, quest_marker_kind: StringName = &"") -> void:
	var actor := Interactable3D.new()
	actor.name = "HouseResident" if interaction_id == "house_resident" else interaction_id.capitalize()
	actor.interaction_id = interaction_id
	actor.prompt_text = prompt
	actor.position = world_position
	actor.collision_layer = 8
	actor.collision_mask = 0
	actor.activated.connect(_handle_interaction)
	_map_root.add_child(actor)

	var shape_node := CollisionShape3D.new()
	shape_node.position.y = 0.75
	var shape := SphereShape3D.new()
	shape.radius = 0.75
	shape_node.shape = shape
	actor.add_child(shape_node)

	# Keep the interaction area generous while blocking movement at the feet.
	if interaction_id in ["elder", "rumi", "noah", "guardian", "road_traveler", "sia", "ch1_noah", "gate_watch"]:
		var body := StaticBody3D.new()
		body.name = "ActorBody"
		body.collision_layer = 1
		body.collision_mask = 0
		var collider := CollisionShape3D.new()
		var capsule := CapsuleShape3D.new()
		capsule.radius = 0.5 if interaction_id == "guardian" else 0.32
		capsule.height = 1.4
		collider.shape = capsule
		collider.position.y = capsule.height * 0.5
		body.add_child(collider)
		actor.add_child(body)

	var sprite := Sprite3D.new()
	sprite.name = "CharacterArt"
	if interaction_id in ["noah", "elder", "rumi", "ch1_noah"]:
		sprite.set_script(preload("res://scripts/gameplay/equipment_actor.gd"))
		sprite.set("actor_id", "noah" if interaction_id == "ch1_noah" else interaction_id)
	if interaction_id in ["house_resident", "road_traveler", "sia", "gate_watch"]:
		if texture_path.contains("/city_residents/"):
			sprite.set_script(preload("res://scripts/gameplay/city_resident_art.gd"))
		else:
			sprite.set_script(preload("res://scripts/gameplay/resident_art.gd"))
			sprite.set("resident_id", texture_path.get_file().get_basename())
		sprite.set("visible_height", Proportions.HEIGHT * (HouseCatalog.INTERIOR_CHARACTER_SCALE if interaction_id == "house_resident" else 1.0))
	sprite.texture = props.art_texture(texture_path)
	sprite.pixel_size = pixel_size
	# Match the upright player: camera pitch must foreshorten every world actor alike.
	sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.modulate = tint
	if atlas_character:
		sprite.hframes = 4
		sprite.vframes = 7
	actor.add_child(sprite)
	# Equipment actors can replace the requested texture in _ready(). Cache by
	# the actual displayed texture, or residents inherit a different atlas's feet.
	var baseline_key := "%s@%s" % [str(sprite.texture.get_instance_id()), str(sprite.alpha_scissor_threshold)]
	if not _art_baselines.has(baseline_key):
		_art_baselines[baseline_key] = SpriteGrounding.foot_baseline(sprite.texture, sprite.alpha_scissor_threshold)
	SpriteGrounding.anchor(sprite, sprite.texture, _art_baselines[baseline_key])
	var ground_height: float = 0.07 if interaction_id == "guardian" else 0.008
	sprite.position.y += ground_height
	SpriteGrounding.add_shadow(actor, 0.62 if interaction_id == "guardian" else 0.34, ground_height + 0.012)

	if quest_marker_kind.is_empty():
		var interaction_marker := Label3D.new()
		interaction_marker.name = "InteractionMarker"
		interaction_marker.text = "◆"
		interaction_marker.position.y = 1.72
		interaction_marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		interaction_marker.font_size = 48
		interaction_marker.outline_size = 10
		interaction_marker.modulate = Color("ffe08a")
		actor.add_child(interaction_marker)
	else:
		_add_quest_marker(actor, interaction_id, quest_marker_kind)


func _add_quest_marker(actor: Interactable3D, interaction_id: String, marker_kind: StringName) -> void:
	var marker := Label3D.new()
	marker.name = "QuestMarker"
	marker.text = "!"
	marker.position.y = 1.82
	marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	marker.font_size = 64
	marker.outline_size = 12
	marker.modulate = SIDE_CONTENT_MARKER_COLOR if marker_kind == SIDE_CONTENT_MARKER else MAIN_QUEST_MARKER_COLOR
	actor.add_child(marker)
	_quest_markers[interaction_id] = marker
	_update_quest_markers()


func _update_quest_markers() -> void:
	var filming: bool = GameState.mode == GameState.Mode.CUTSCENE
	if is_instance_valid(_village_gate_marker):
		_village_gate_marker.visible = not filming
	for interaction_id: String in _quest_markers:
		# Actors who leave mid-map (companions joining) free their markers.
		if not is_instance_valid(_quest_markers[interaction_id]):
			continue
		var marker := _quest_markers[interaction_id] as Label3D
		if filming:
			marker.visible = false
			continue
		match interaction_id:
			"elder":
				marker.visible = GameState.quest_state in [GameState.QuestState.NOT_STARTED, GameState.QuestState.READY_TO_TURN_IN] \
					or (GameState.quest_state == GameState.QuestState.COMPLETE and GameState.chapter_stage == GameState.Chapter.LIGHT_EAST)
			"rumi":
				marker.visible = not bool(GameState.flags.get("rumi_tip_seen", false)) \
					or (GameState.chapter_stage == GameState.Chapter.COMPLETE and int(GameState.inventory.get("starbay_reply", 0)) > 0)
			"guardian":
				marker.visible = GameState.quest_state == GameState.QuestState.ACTIVE and not bool(GameState.flags.get("guardian_defeated", false))
			_:
				var chapter_marker: Variant = ChapterOne.marker_visible(interaction_id)
				if chapter_marker != null:
					marker.visible = bool(chapter_marker)
				else:
					marker.visible = not bool(GameState.flags.get(interaction_id, false)) if Outskirts.EVENTS.has(interaction_id) else true


func _add_moon_lamp(world_position: Vector3) -> void:
	var lamp := Interactable3D.new()
	lamp.name = "MoonLamp"
	lamp.interaction_id = "moon_lamp"
	lamp.prompt_text = "查看中央月燈"
	lamp.position = world_position
	lamp.collision_layer = 8
	lamp.collision_mask = 0
	lamp.activated.connect(_handle_interaction)
	_map_root.add_child(lamp)

	var interaction_shape := CollisionShape3D.new()
	interaction_shape.position.y = 0.85
	var sphere_shape := SphereShape3D.new()
	sphere_shape.radius = 0.9
	interaction_shape.shape = sphere_shape
	lamp.add_child(interaction_shape)

	var art := (load("res://assets/generated/moon_halo.glb") as PackedScene).instantiate() as Node3D
	art.name = "MoonLampArt"
	lamp.add_child(art)
	for mesh: MeshInstance3D in art.find_children("*", "MeshInstance3D", true, false):
		# Layer 2 receives the scene lights, but not this lantern's plaza fill.
		mesh.layers = 2
		var material := (mesh.get_active_material(0) as StandardMaterial3D).duplicate() as StandardMaterial3D
		# Dense hammered metal and stone need minification mip levels to avoid
		# shimmering speckles. Each level still uses nearest-neighbor sampling.
		material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
		if mesh.name == "MoonLampBronzework":
			material.albedo_color = Color("ffd78a")
			material.metallic = 0.25
			material.emission_enabled = true
			material.emission = Color("ffb52e")
			material.emission_energy_multiplier = 3.5
		elif mesh.name == "MoonLampPatinaPanels":
			material.albedo_color = Color("696475")
		elif mesh.name == "MoonLampPlinth":
			material.albedo_color = Color("9fa1ae")
			var weathering := NoiseTexture2D.new()
			weathering.width = 128
			weathering.height = 128
			weathering.seamless = true
			var noise := FastNoiseLite.new()
			noise.seed = 731
			noise.frequency = 0.065
			weathering.noise = noise
			var tones := Gradient.new()
			tones.colors = PackedColorArray([Color("928779"), Color("ede5d5")])
			weathering.color_ramp = tones
			material.detail_enabled = true
			material.detail_albedo = weathering
			material.detail_blend_mode = BaseMaterial3D.BLEND_MODE_MUL
		mesh.material_override = material
	_moon_lamp_core = art.find_child("MoonLampCore", true, false) as MeshInstance3D

	_moon_lamp_light = OmniLight3D.new()
	_moon_lamp_light.name = "MoonLampLight"
	_moon_lamp_light.position.y = 1.52
	_moon_lamp_light.omni_range = 7.5
	_moon_lamp_light.light_cull_mask = 1
	lamp.add_child(_moon_lamp_light)
	var fixture_light := OmniLight3D.new()
	fixture_light.name = "FixtureLight"
	fixture_light.position.y = 1.52
	fixture_light.omni_range = 2.5
	fixture_light.light_cull_mask = 2
	lamp.add_child(fixture_light)

	var marker := Label3D.new()
	marker.text = "◇"
	marker.position.y = 2.60
	marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	marker.font_size = 48
	marker.outline_size = 10
	marker.modulate = Color("d9d2ff")
	lamp.add_child(marker)
	_update_moon_lamp_state()


func _update_moon_lamp_state() -> void:
	if not is_instance_valid(_moon_lamp_core) or not is_instance_valid(_moon_lamp_light):
		return
	var lamp_is_restored := GameState.quest_state == GameState.QuestState.COMPLETE
	var fixture_light := _moon_lamp_light.get_parent().get_node("FixtureLight") as OmniLight3D
	fixture_light.light_color = Color("b9fff0") if lamp_is_restored else Color("d0baf2")
	fixture_light.light_energy = 0.45 if lamp_is_restored else 0.15
	# Keep the imported mineral texture in both story states. Only this instance's
	# material changes; other moon crystals and future map instances are unaffected.
	var core_material := _moon_lamp_core.material_override as StandardMaterial3D
	core_material.emission_enabled = true
	# Imported glTF has no emissive map. Supply the mineral map explicitly so
	# multiply emission has a sampled surface in both rendering backends.
	core_material.emission_texture = core_material.albedo_texture
	core_material.emission_operator = BaseMaterial3D.EMISSION_OP_MULTIPLY
	core_material.vertex_color_use_as_albedo = true
	if lamp_is_restored:
		core_material.albedo_color = Color("fff1bd")
		core_material.roughness = 0.12
		core_material.emission = Color("a9fff1")
		core_material.emission_energy_multiplier = 1.4
		_moon_lamp_light.light_color = Color("b9fff0")
		_moon_lamp_light.light_energy = 4.2
	else:
		core_material.albedo_color = Color("dec8ff")
		core_material.roughness = 0.6
		core_material.emission = Color("9686c9")
		core_material.emission_energy_multiplier = 0.85
		_moon_lamp_light.light_color = Color("8882ab")
		_moon_lamp_light.light_energy = 0.28


func _add_pedestal_interactable(interaction_id: String, prompt: String, world_position: Vector3, color: Color) -> void:
	var pedestal := Interactable3D.new()
	pedestal.name = interaction_id.capitalize()
	pedestal.interaction_id = interaction_id
	pedestal.prompt_text = prompt
	pedestal.position = world_position
	pedestal.collision_layer = 8
	pedestal.collision_mask = 0
	pedestal.activated.connect(_handle_interaction)
	_map_root.add_child(pedestal)

	var interaction_shape := CollisionShape3D.new()
	interaction_shape.position.y = 0.55
	var sphere_shape := SphereShape3D.new()
	sphere_shape.radius = 0.75
	interaction_shape.shape = sphere_shape
	pedestal.add_child(interaction_shape)

	var base := MeshInstance3D.new()
	base.position.y = 0.25
	var base_mesh := CylinderMesh.new()
	base_mesh.top_radius = 0.42
	base_mesh.bottom_radius = 0.52
	base_mesh.height = 0.5
	base_mesh.radial_segments = 8
	base.mesh = base_mesh
	base.material_override = props.make_material(PALETTE.ruin.lightened(0.08), 0.84)
	pedestal.add_child(base)

	var focus := MeshInstance3D.new()
	focus.position.y = 0.7
	var focus_mesh := PrismMesh.new()
	focus_mesh.size = Vector3(0.36, 0.7, 0.3)
	focus.mesh = focus_mesh
	focus.material_override = props.make_material(color, 0.2, 0.0, color, 2.8)
	pedestal.add_child(focus)
	if interaction_id == "moon_spring":
		base.visible = false
		focus.visible = false
		WaterFeature.build(pedestal, Vector3(0.0, 0.2, 0.0), Vector2(1.6, 1.6), true)
	elif interaction_id == "ruin_tablet":
		base.visible = false
		focus.visible = false
		var tablet_scene := load("res://assets/generated/moon_tablet.glb") as PackedScene
		var tablet := tablet_scene.instantiate() as Node3D
		tablet.name = "MoonTabletVisual"
		pedestal.add_child(tablet)
		var stone := tablet.find_child("TabletStone", true, false) as MeshInstance3D
		var inscription := (stone.get_active_material(0) as StandardMaterial3D).duplicate() as StandardMaterial3D
		inscription.albedo_texture = props.art_texture("res://assets/generated/moon_tablet_open_ring.png")
		inscription.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		stone.set_surface_override_material(0, inscription)

	var light := OmniLight3D.new()
	light.position.y = 0.75
	light.light_color = color
	light.light_energy = 1.5
	light.omni_range = 2.6
	pedestal.add_child(light)

	var marker := Label3D.new()
	marker.text = "◆"
	marker.position.y = 2.25 if interaction_id == "ruin_tablet" else 1.4
	marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	marker.font_size = 42
	marker.outline_size = 9
	marker.modulate = color.lightened(0.2)
	pedestal.add_child(marker)


func _add_portal(interaction_id: String, prompt: String, world_position: Vector3, color: Color) -> void:
	var portal := Interactable3D.new()
	portal.name = interaction_id.capitalize()
	portal.interaction_id = interaction_id
	portal.prompt_text = prompt
	portal.position = world_position
	portal.scale.y = 0.82
	portal.collision_layer = 8
	portal.collision_mask = 1
	portal.monitoring = true
	portal.activated.connect(_handle_interaction)
	portal.body_entered.connect(_on_portal_body_entered.bind(interaction_id))
	_map_root.add_child(portal)

	var shape_node := CollisionShape3D.new()
	var approach_side: float = 1.0 if interaction_id == "portal_to_ruins" else -1.0
	# Cross the threshold before changing maps; arrivals remain clear of this area.
	shape_node.position = Vector3(0.0, 0.8, -approach_side * 0.7)
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.2, 1.6, 0.6)
	shape_node.shape = shape
	portal.add_child(shape_node)

	var frame_material := props.make_coursed_stone()
	var trim_material := props.make_material(Color("514a40"), 0.82, 0.35)
	trim_material.albedo_texture = preload("res://assets/generated/aged_bronze_albedo.png")
	trim_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	var door_material := props.make_material(Color("92714e"), 0.94, 0.0)
	door_material.albedo_texture = preload("res://assets/generated/timber_albedo.png")
	door_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	var door_dark_material := props.make_material(Color("30271e"), 0.95, 0.0)

	_add_portal_box(portal, Vector3(-1.48, 1.45, 0.0), Vector3(0.52, 2.9, 0.62), frame_material)
	_add_portal_box(portal, Vector3(1.48, 1.45, 0.0), Vector3(0.52, 2.9, 0.62), frame_material)
	_add_portal_box(portal, Vector3(0.0, 2.88, 0.0), Vector3(3.48, 0.5, 0.66), frame_material)
	_add_portal_box(portal, Vector3(-1.48, 3.18, 0.0), Vector3(0.72, 0.22, 0.78), trim_material)
	_add_portal_box(portal, Vector3(1.48, 3.18, 0.0), Vector3(0.72, 0.22, 0.78), trim_material)
	_add_portal_box(portal, Vector3(0.0, 0.09, 0.06), Vector3(3.35, 0.18, 0.82), frame_material)

	var left_hinge := Node3D.new()
	left_hinge.name = "LeftDoorHinge"
	left_hinge.position = Vector3(-1.2, 1.48, 0.03)
	portal.add_child(left_hinge)
	_add_portal_box(left_hinge, Vector3(0.59, 0.0, 0.0), Vector3(1.18, 2.48, 0.18), door_material)
	_add_portal_box(left_hinge, Vector3(0.59, 0.72, -0.12), Vector3(1.06, 0.1, 0.1), trim_material)
	_add_portal_box(left_hinge, Vector3(0.59, -0.72, -0.12), Vector3(1.06, 0.1, 0.1), trim_material)
	_add_portal_box(left_hinge, Vector3(0.59, 0.0, -0.11), Vector3(0.09, 2.25, 0.08), door_dark_material)

	var right_hinge := Node3D.new()
	right_hinge.name = "RightDoorHinge"
	right_hinge.position = Vector3(1.2, 1.48, 0.03)
	portal.add_child(right_hinge)
	_add_portal_box(right_hinge, Vector3(-0.59, 0.0, 0.0), Vector3(1.18, 2.48, 0.18), door_material)
	_add_portal_box(right_hinge, Vector3(-0.59, 0.72, -0.12), Vector3(1.06, 0.1, 0.1), trim_material)
	_add_portal_box(right_hinge, Vector3(-0.59, -0.72, -0.12), Vector3(1.06, 0.1, 0.1), trim_material)
	_add_portal_box(right_hinge, Vector3(-0.59, 0.0, -0.11), Vector3(0.09, 2.25, 0.08), door_dark_material)
	for hinge: Node3D in [left_hinge, right_hinge]:
		var leaf_center: float = 0.59 if hinge == left_hinge else -0.59
		for height: float in [-0.72, 0.72]:
			_add_portal_box(hinge, Vector3(leaf_center, height, 0.12), Vector3(1.06, 0.1, 0.1), trim_material)
		_add_portal_box(hinge, Vector3(leaf_center, 0.0, 0.11), Vector3(0.09, 2.25, 0.08), door_dark_material)
	preload("res://scripts/gameplay/gate_details.gd").build(portal, left_hinge, right_hinge, frame_material, trim_material, door_dark_material)

	var seal := MeshInstance3D.new()
	seal.name = "MoonSeal"
	seal.position = Vector3(0.0, 1.52, approach_side * 0.19)
	seal.mesh = MoonSeal.ring_mesh(0.37, 0.12, 0.04)
	seal.material_override = props.make_material(color.darkened(0.4), 0.8, 0.3, color, 0.12)
	portal.add_child(seal)

	var seal_core := MeshInstance3D.new()
	seal_core.name = "MoonSealCore"
	seal_core.position = Vector3(0.0, 1.52, approach_side * 0.2)
	seal_core.rotation_degrees = Vector3(0.0, 0.0, 45.0)
	var core_mesh := PrismMesh.new()
	core_mesh.size = Vector3(0.25, 0.38, 0.14)
	seal_core.mesh = core_mesh
	seal_core.material_override = props.make_material(color.darkened(0.25), 0.7, 0.3, color, 0.12)
	portal.add_child(seal_core)

	var light := OmniLight3D.new()
	light.position = Vector3(0.0, 1.55, approach_side * 0.45)
	light.light_color = color
	light.light_energy = 0.15
	light.omni_range = 1.2
	portal.add_child(light)

	var marker := Label3D.new()
	marker.position = Vector3(0.0, 3.72, 0.0)
	marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	marker.font_size = 34
	marker.outline_size = 8
	marker.modulate = color.lightened(0.22)
	portal.add_child(marker)
	# The physical gate carries the landmark; instructions stay in the HUD.
	marker.visible = false

	var starts_open := interaction_id != "portal_to_ruins" or GameState.quest_state != GameState.QuestState.NOT_STARTED
	light.light_energy = 0.0 if starts_open else 0.15
	left_hinge.rotation.y = -1.22 if starts_open else 0.0
	right_hinge.rotation.y = 1.22 if starts_open else 0.0
	var closed_door := StaticBody3D.new()
	closed_door.name = "ClosedDoor"
	var closed_shape := CollisionShape3D.new()
	var closed_box := BoxShape3D.new()
	closed_box.size = Vector3(2.4, 2.5, 0.2)
	closed_shape.shape = closed_box
	closed_shape.position.y = 1.4
	closed_shape.disabled = starts_open
	closed_door.add_child(closed_shape)
	portal.add_child(closed_door)
	seal.visible = not starts_open
	seal_core.visible = not starts_open
	seal.transparency = 1.0 if starts_open else 0.0
	seal_core.transparency = 1.0 if starts_open else 0.0
	marker.text = "◇ 穿過前往暮光村" if interaction_id == "portal_to_village" else ("◇ 穿過前往北境遺跡" if starts_open else "◆ 月印封鎖")
	portal.prompt_text = "" if starts_open else "查看封印的月紋門"
	# Cut away only the individual piece hiding the traveler at the far threshold.
	# Hinge-local bounds follow the opening animation without stale world bounds.
	for part: Node in portal.get_children():
		if part == seal or part == seal_core:
			continue
		if part is MeshInstance3D or part == left_hinge or part == right_hinge:
			var cutaway := ForegroundCutaway.new()
			if part == left_hinge or part == right_hinge:
				cutaway.minimum_height = -INF
			part.add_child(cutaway)
			cutaway.configure(part as Node3D, player, $CameraRig/Camera3D, &"gate_cutaways")
	if interaction_id == "portal_to_ruins":
		_village_gate_portal = portal
		_village_gate_left = left_hinge
		_village_gate_right = right_hinge
		_village_gate_seal = seal
		_village_gate_seal_core = seal_core
		_village_gate_light = light
		_village_gate_marker = marker
		_village_gate_is_open = starts_open


func _on_portal_body_entered(body: Node3D, interaction_id: String) -> void:
	if body != player:
		return
	_try_enter_portal(interaction_id)


func _try_enter_portal(interaction_id: String) -> void:
	if _portal_transition_pending or GameState.is_input_locked():
		return
	if interaction_id == "portal_to_ruins":
		if GameState.quest_state == GameState.QuestState.NOT_STARTED:
			_reject_at_sealed_gate()
			dialogue_ui.show_dialogue([
				{"speaker": "古老門扉", "text": "藍色紋路一閃即逝，門扉沒有開啟。"},
				{"speaker": "守門人・諾亞", "text": "它只聽從長老的月印。先去廣場找艾爾長老吧。"},
			])
			return
		_cross_portal("ruins", "from_village", _portal_gate_center(interaction_id))
	elif interaction_id == "portal_to_village":
		_cross_portal("village", "from_ruins", _portal_gate_center(interaction_id))


func _portal_vortex(exit_id: String) -> Node3D:
	for node: Node in get_tree().get_nodes_in_group("portal_vortices"):
		if is_instance_valid(_map_root) and _map_root.is_ancestor_of(node) and str(node.get_meta("exit_id", "")) == exit_id:
			return node as Node3D
	return null


func _portal_gate_center(interaction_id: String) -> Vector3:
	var gate := _map_root.find_child(interaction_id.capitalize(), false, false) as Node3D if is_instance_valid(_map_root) else null
	return (gate.global_position if gate != null else player.global_position) + Vector3.UP * 1.5


## Walk into the light, ripple the screen shut, change maps under it, and open
## again on arrival with a small burst. A short scripted beat, not a skippable film.
func _cross_portal(map_id: String, spawn: String, center: Vector3, vortex: Node3D = null) -> void:
	if _portal_transition_pending:
		return
	_portal_transition_pending = true
	var source: Node3D = _map_root
	GameState.set_mode(GameState.Mode.CUTSCENE)
	var rig := $CameraRig as Hd2dCameraRig
	rig.request_shot(PORTAL_SHOT, {"focus": player.global_position.lerp(Vector3(center.x, player.global_position.y, center.z), 0.6), "distance_scale": 0.72, "relative": true, "blend_in": 0.6}, 50)
	var inward: Vector3 = (center - player.global_position) * Vector3(1, 0, 1)
	inward = inward.normalized() if inward.length() > 0.05 else -player.global_basis.z
	player.play_scripted_walk(PackedVector3Array([player.global_position + inward * 1.1]), 1.7)
	if vortex != null:
		vortex.call("surge", PORTAL_COVER_SECONDS * 0.8)
	GameAudio.play_cue(&"skill", 0.72)
	var camera := get_viewport().get_camera_3d()
	var screen := Vector2(0.5, 0.5)
	if camera != null and not camera.is_position_behind(center):
		screen = (camera.unproject_position(center) / get_viewport().get_visible_rect().size).clamp(Vector2(0.15, 0.15), Vector2(0.85, 0.85))
	await _portal_fx.cover(PORTAL_COVER_SECONDS, screen, Color("dcf2ff") if vortex != null else Color("eef4ff"))
	player.stop_scripted_walk()
	if not is_instance_valid(source) or source != _map_root:
		# Something else changed the map meanwhile; just clear the screen.
		_portal_fx.cancel()
		return
	# Hand control back before the new map runs its arrival beats (dialogue, films).
	GameState.set_mode(GameState.Mode.EXPLORE)
	GameState.request_map(map_id, spawn)
	await map_presented
	_portal_arrival_burst()
	var hero_art: SpriteBase3D = cutscene_sprite("hero")
	if hero_art != null:
		ActorActing.ensure(hero_art).call("act", &"hop", &"none")
	GameAudio.play_cue(&"moon_heal", 1.25)
	# The map build is one long frame; start opening only once frames are short again.
	await get_tree().process_frame
	await get_tree().process_frame
	await _portal_fx.reveal(PORTAL_REVEAL_SECONDS)


## Motes thrown up around the traveler as they step out of the light.
func _portal_arrival_burst() -> void:
	var burst := CPUParticles3D.new()
	burst.name = "PortalArrival"
	burst.one_shot = true
	burst.amount = 36
	burst.lifetime = 1.1
	burst.explosiveness = 0.85
	burst.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	burst.emission_ring_axis = Vector3.UP
	burst.emission_ring_radius = 0.55
	burst.emission_ring_inner_radius = 0.2
	burst.emission_ring_height = 0.1
	burst.direction = Vector3.UP
	burst.spread = 35.0
	burst.initial_velocity_min = 0.8
	burst.initial_velocity_max = 1.8
	burst.gravity = Vector3(0, -0.6, 0)
	var fade := Gradient.new()
	fade.set_color(0, Color(0.85, 0.96, 1.0, 1.0))
	fade.set_color(1, Color(0.4, 0.85, 1.0, 0.0))
	burst.color_ramp = fade
	var quad := QuadMesh.new()
	quad.size = Vector2(0.06, 0.06)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.vertex_color_use_as_albedo = true
	quad.material = material
	burst.mesh = quad
	_map_root.add_child(burst)
	burst.global_position = player.global_position + Vector3.UP * 0.1
	burst.emitting = true
	burst.finished.connect(burst.queue_free)
	var glow := OmniLight3D.new()
	glow.light_color = Color("bfe9ff")
	glow.omni_range = 4.0
	glow.light_energy = 2.5
	_map_root.add_child(glow)
	glow.global_position = player.global_position + Vector3.UP * 1.2
	var dim := glow.create_tween()
	dim.tween_property(glow, "light_energy", 0.0, 0.9).set_trans(Tween.TRANS_SINE)
	dim.tween_callback(glow.queue_free)


## The sealed moon gate refuses: its seal flares, the traveler starts back.
func _reject_at_sealed_gate() -> void:
	var hero_art: SpriteBase3D = cutscene_sprite("hero")
	if hero_art != null:
		ActorActing.ensure(hero_art).call("act", &"recoil", &"shock")
	GameAudio.play_cue(&"guard", 1.3)
	if is_instance_valid(_village_gate_light):
		var flare := create_tween()
		flare.tween_property(_village_gate_light, "light_energy", 2.6, 0.12)
		flare.tween_property(_village_gate_light, "light_energy", 0.15, 0.7).set_trans(Tween.TRANS_SINE)
	if is_instance_valid(_village_gate_seal):
		var pulse := create_tween()
		pulse.tween_property(_village_gate_seal, "scale", Vector3.ONE * 1.12, 0.1)
		pulse.tween_property(_village_gate_seal, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_BACK)


func _add_portal_box(parent: Node3D, local_position: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.position = local_position
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.material_override = material
	parent.add_child(mesh_instance)
	return mesh_instance


func _update_village_gate_state() -> void:
	if not is_instance_valid(_village_gate_left) or not is_instance_valid(_village_gate_right):
		return
	var should_open := GameState.quest_state != GameState.QuestState.NOT_STARTED
	if should_open == _village_gate_is_open:
		return
	_village_gate_is_open = should_open
	(_village_gate_portal.get_node("ClosedDoor").get_child(0) as CollisionShape3D).set_deferred("disabled", should_open)
	_village_gate_portal.prompt_text = "" if should_open else "查看封印的月紋門"
	_village_gate_marker.text = "◇ 穿過前往北境遺跡" if should_open else "◆ 月印封鎖"
	_village_gate_light.light_energy = 0.0 if should_open else 0.15
	_village_gate_seal.visible = not should_open
	_village_gate_seal_core.visible = not should_open
	var tween := create_tween().set_parallel(true)
	tween.tween_property(_village_gate_left, "rotation:y", -1.22 if should_open else 0.0, 0.72).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_village_gate_right, "rotation:y", 1.22 if should_open else 0.0, 0.72).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(_village_gate_seal, "transparency", 1.0 if should_open else 0.0, 0.36)
	tween.tween_property(_village_gate_seal_core, "transparency", 1.0 if should_open else 0.0, 0.36)


func _add_house(world_position: Vector3, wall_color: Color, roof_color: Color, rotation_y: float, house_id: String, japanese_variant: int = -1, shop_id: String = "") -> void:
	var house := StaticBody3D.new()
	house.name = "VillageHouse"
	house.set_meta("house_id", house_id)
	house.position = world_position
	house.rotation.y = rotation_y
	_map_root.add_child(house)

	var wall_material := props.make_material(wall_color, 0.92)
	wall_material.albedo_color = wall_color.lightened(0.32)
	wall_material.albedo_texture = props.art_texture("res://assets/generated/plaster_albedo.png")
	wall_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	wall_material.uv1_scale = Vector3(2.0, 1.0, 1.0)
	var timber_material := props.make_material(Color("a99b92"), 0.92)
	timber_material.albedo_texture = props.art_texture("res://assets/generated/timber_albedo.png")
	timber_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	var roof_material := props.make_material(roof_color.lightened(0.78), 0.94)
	roof_material.albedo_texture = props.art_texture("res://assets/generated/slate_roof_albedo.png")
	roof_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	var window_material := ShaderMaterial.new()
	window_material.shader = preload("res://shaders/house_window.gdshader")
	var foundation_material := props.make_material(Color("aaa6af"), 0.96)
	foundation_material.albedo_texture = props.art_texture("res://assets/generated/ruin_flagstone.png")
	foundation_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	if not shop_id.is_empty():
		preload("res://scripts/gameplay/city_shops.gd").exterior(house, shop_id)
	elif japanese_variant >= 0:
		preload("res://scripts/gameplay/japanese_house.gd").build(house, japanese_variant)
	else:
		_add_portal_box(house, Vector3(0.0, 0.18, 0.0), Vector3(4.16, 0.35, 3.36), foundation_material)
		# Leave an actual doorway recess so the inward swing does not enter plaster.
		for side: float in [-1.0, 1.0]:
			_add_portal_box(house, Vector3(side * 1.205, 1.15, 0.0), Vector3(1.59, 1.9, 3.2), wall_material)
		_add_portal_box(house, Vector3(0.0, 1.86, 0.0), Vector3(0.82, 0.48, 3.2), wall_material)
		_add_portal_box(house, Vector3(0.0, 0.91, 0.41), Vector3(0.82, 1.42, 2.38), wall_material)
		for post_x: float in [-1.98, 1.98]:
			for post_z: float in [-1.60, 0.0, 1.60]:
				_add_portal_box(house, Vector3(post_x, 1.18, post_z), Vector3(0.16, 1.75, 0.16), timber_material)
		_add_portal_box(house, Vector3(0.0, 1.7, -1.64), Vector3(3.85, 0.13, 0.12), timber_material)

		_add_portal_box(house, Vector3(-1.25, 1.18, -1.67), Vector3(0.62, 0.62, 0.11), window_material)
		_add_portal_box(house, Vector3(1.25, 1.18, -1.67), Vector3(0.62, 0.62, 0.11), window_material)
		_add_portal_box(house, Vector3(0.0, 0.12, -2.0), Vector3(1.35, 0.24, 0.72), timber_material)
		_add_portal_box(house, Vector3(0.0, 1.55, -1.9), Vector3(1.3, 0.14, 0.62), roof_material)
		_add_portal_box(house, Vector3(-1.15, 1.18, 1.67), Vector3(0.66, 0.62, 0.11), window_material)
		_add_portal_box(house, Vector3(1.15, 1.18, 1.67), Vector3(0.66, 0.62, 0.11), window_material)
		_add_portal_box(house, Vector3(-2.01, 1.18, -0.72), Vector3(0.11, 0.6, 0.62), window_material)
		_add_portal_box(house, Vector3(-2.01, 1.18, 0.72), Vector3(0.11, 0.6, 0.62), window_material)
		_add_portal_box(house, Vector3(2.01, 1.18, -0.72), Vector3(0.11, 0.6, 0.62), window_material)
		_add_portal_box(house, Vector3(2.01, 1.18, 0.72), Vector3(0.11, 0.6, 0.62), window_material)
		_add_portal_box(house, Vector3(1.15, 2.94, 0.72), Vector3(0.46, 0.99, 0.56), foundation_material)
		# Four separate cap stones leave a real dark opening rather than a solid lid.
		for cap_x: float in [-0.255, 0.255]:
			_add_portal_box(house, Vector3(1.15 + cap_x, 3.49, 0.72), Vector3(0.13, 0.13, 0.70), foundation_material)
		for cap_z: float in [-0.285, 0.285]:
			_add_portal_box(house, Vector3(1.15, 3.49, 0.72 + cap_z), Vector3(0.38, 0.13, 0.13), foundation_material)
		HouseDetails.build(house, timber_material, roof_material, wall_material)
		HouseExterior.build(house, house_id, timber_material)
	# Scale visual roots together, but resize physics shapes explicitly: a
	# non-uniformly scaled StaticBody3D would give unreliable collisions.
	var exterior_transform := Transform3D(Basis.from_scale(HouseCatalog.EXTERIOR_SCALE), Vector3.ZERO)
	for child: Node in house.get_children():
		if child is Node3D:
			(child as Node3D).transform = exterior_transform * (child as Node3D).transform

	if japanese_variant < 0 and shop_id.is_empty():
		HouseExterior.build_collision(house, house_id)
	var collision_shape := CollisionShape3D.new()
	collision_shape.position.y = 1.15 * HouseCatalog.EXTERIOR_SCALE.y
	var shape := BoxShape3D.new()
	shape.size = HouseCatalog.EXTERIOR_COLLISION
	collision_shape.shape = shape
	house.add_child(collision_shape)
	# The visible doorstep must support the actor during handle contact.
	var step_collider := CollisionShape3D.new()
	step_collider.name = "DoorstepCollision"
	step_collider.position = Vector3(0, 0.13, -1.99) * HouseCatalog.EXTERIOR_SCALE
	var step_box := BoxShape3D.new()
	step_box.size = Vector3(1.20, 0.26, 0.65) * HouseCatalog.EXTERIOR_SCALE
	step_collider.shape = step_box
	house.add_child(step_collider)
	var entrance := Interactable3D.new()
	entrance.name = "HouseEntrance"
	entrance.facing_direction = Vector3.BACK
	entrance.automatic_distance = 0.65
	entrance.interaction_id = "enter_" + house_id
	entrance.prompt_text = "進入" + str(HouseCatalog.find_home(house_id).name)
	entrance.position = Vector3(0, 0.7, -2.1) * HouseCatalog.EXTERIOR_SCALE
	entrance.collision_layer = 8
	entrance.collision_mask = 0
	entrance.add_to_group("house_entrances")
	var door_shape := CollisionShape3D.new()
	var door_sphere := SphereShape3D.new()
	door_sphere.radius = 0.55
	door_shape.shape = door_sphere
	entrance.add_child(door_shape)
	entrance.activated.connect(_handle_interaction)
	house.add_child(entrance)
	var cutaway := ForegroundCutaway.new()
	cutaway.name = "ForegroundCutaway"
	house.add_child(cutaway)
	cutaway.configure(house, player, $CameraRig/Camera3D)


func _add_column(world_position: Vector3) -> void:
	var root := StaticBody3D.new()
	root.name = "Column"
	root.position = world_position
	_map_root.add_child(root)
	var pillar_scene := load("res://assets/generated/weathered_pillar_v2.glb") as PackedScene
	var pillar := pillar_scene.instantiate() as Node3D
	pillar.add_to_group("weathered_pillar_art")
	pillar.rotation.y = fposmod(world_position.x * 0.73 + world_position.z * 0.41, TAU)
	root.add_child(pillar)
	for node: Node in pillar.find_children("*", "MeshInstance3D", true, false):
		var mesh := node as MeshInstance3D
		for surface: int in range(mesh.mesh.get_surface_count()):
			var material := mesh.mesh.surface_get_material(surface) as BaseMaterial3D
			if material != null:
				material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	# A low collar stays visible during cutaway and marks the unchanged collider.
	var base := MeshInstance3D.new()
	base.name = "ColumnFooting"
	var footing := CylinderMesh.new()
	footing.bottom_radius = 0.5
	footing.top_radius = 0.46
	footing.height = 0.14
	footing.radial_segments = 16
	base.mesh = footing
	base.position.y = 0.07
	var stone := StandardMaterial3D.new()
	stone.albedo_texture = preload("res://assets/generated/cut_limestone_albedo.png")
	stone.albedo_color = Color("8d929b")
	stone.roughness = 0.96
	stone.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	base.material_override = stone
	root.add_child(base)
	# A few original low grass blades soften the clean footing edge; no new
	# obstacle is added, and this low layer remains visible during cutaway.
	for index: int in range(4):
		var angle: float = pillar.rotation.y + float(index) * TAU / 4.0
		var grass := Sprite3D.new()
		grass.name = "ColumnGrass%d" % index
		grass.texture = preload("res://assets/generated/grass_low.tres")
		grass.pixel_size = 0.00055
		grass.position = Vector3(cos(angle) * 0.39, 0.01 + 328.0 * grass.pixel_size, sin(angle) * 0.39)
		grass.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		grass.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		grass.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		grass.shaded = true
		grass.double_sided = true
		root.add_child(grass)
	var collision_shape := CollisionShape3D.new()
	collision_shape.position.y = 1.0
	var shape := CylinderShape3D.new()
	shape.radius = 0.5
	shape.height = 2.0
	collision_shape.shape = shape
	root.add_child(collision_shape)
	var cutaway := ForegroundCutaway.new()
	cutaway.name = "ColumnCutaway"
	root.add_child(cutaway)
	cutaway.configure(root, player, get_viewport().get_camera_3d(), &"column_cutaways")


func _build_environment() -> void:
	var world_environment := WorldEnvironment.new()
	world_environment.name = "WorldEnvironment"
	_environment = Environment.new()
	_environment.background_mode = Environment.BG_COLOR
	_environment.background_color = Color("111425")
	_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_environment.ambient_light_color = Color("6e83ad")
	_environment.ambient_light_energy = 0.48
	_environment.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	_environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	_environment.glow_enabled = true
	_environment.glow_intensity = 0.48
	_environment.glow_bloom = 0.06
	_environment.fog_enabled = true
	_environment.fog_light_color = Color("536381")
	_environment.fog_light_energy = 0.42
	_environment.fog_density = 0.009
	_environment.fog_height = -1.0
	_environment.fog_height_density = 0.18
	world_environment.environment = _environment
	add_child(world_environment)
	var backdrop_layer := CanvasLayer.new()
	backdrop_layer.name = "InteriorBackdrop"
	backdrop_layer.layer = -10
	add_child(backdrop_layer)
	_interior_backdrop = ColorRect.new()
	_interior_backdrop.name = "Color"
	_interior_backdrop.color = Color("141119")
	_interior_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop_layer.add_child(_interior_backdrop)
	_interior_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_interior_backdrop.hide()
	_environment.background_canvas_max_layer = -10
	var sun := DirectionalLight3D.new()
	sun.name = "Moonlight"
	sun.rotation_degrees = Vector3(-52.0, -34.0, 0.0)
	sun.light_color = Color("b9c9ed")
	sun.light_energy = 0.92
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 35.0
	add_child(sun)


func _build_post_process() -> void:
	var overlay_layer := CanvasLayer.new()
	overlay_layer.name = "ColorGrade"
	overlay_layer.layer = 20
	add_child(overlay_layer)
	var overlay := ColorRect.new()
	overlay.name = "Vignette"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader_material := ShaderMaterial.new()
	shader_material.shader = load("res://shaders/hd2d_grade.gdshader") as Shader
	overlay.material = shader_material
	overlay_layer.add_child(overlay)


func _build_hud() -> void:
	_hud = WorldHud.new()
	add_child(_hud)
	_map_label = _hud.map_label
	_quest_label = _hud.quest_label
	_prompt_label = _hud.prompt_label
	_notice_label = _hud.notice_label
	_mini_map = _hud.mini_map
	_player_status = _hud.player_status
	_hud.destination_selected.connect(_on_map_destination)
	var map_ui := preload("res://scripts/ui/map_ui.gd").new()
	map_ui.name = "MapUI"
	map_ui.source_map = _mini_map
	add_child(map_ui)
	_hud.map_button.pressed.connect(map_ui.open)
	map_ui.open_button = _hud.map_button
	add_child(_hud.notices)
	get_viewport().size_changed.connect(_layout_hud)
	_refresh_hud()


func _layout_hud() -> void:
	_hud.layout(is_instance_valid(player.field_combat))


func _layout_interaction_prompt() -> void:
	var field_panel_top := NAN
	if is_instance_valid(player.field_combat):
		field_panel_top = player.field_combat.get_hud_rect().position.y
	_hud.layout_interaction_prompt(field_panel_top)


func _refresh_hud() -> void:
	if _hud == null:
		return
	_update_village_gate_state()
	_update_quest_markers()
	if GameState.current_map == "east_road" and is_instance_valid(_map_root):
		var sign_board := _map_root.get_node_or_null("RoadSign") as Node3D
		if sign_board != null:
			sign_board.rotation.z = 0.0 if bool(GameState.flags.get("road_sign", false)) else -0.45
	_hud.refresh(is_instance_valid(player.field_combat))


func _show_notice(message: String) -> void:
	_hud.show_notice(message)


func _refresh_map_destinations() -> void:
	_mini_map.destinations.clear()
	for node: Node in _map_root.find_children("*", "Area3D", true, false):
		var target := node as Interactable3D
		if target == null or target.get_parent() is CharacterBody3D:
			continue
		# Ordinary homes are scenery, not navigation landmarks.
		if target.interaction_id.begins_with("enter_house_"):
			continue
		var kind := "event"
		if target.interaction_id.begins_with("portal_") or Outskirts.EXITS.has(target.interaction_id) or target.interaction_id == "leave_house":
			kind = "exit"
		_mini_map.destinations.append({"position": target.global_position, "title": _map_destination_title(target), "kind": kind})
	_mini_map.queue_redraw()


func _on_map_destination(point: Dictionary) -> void:
	if GameState.is_input_locked():
		return
	if player.auto_walk.start(point.position, _mini_map.get_world_bounds()):
		_show_notice("自動前往・" + str(point.title) + "（移動鍵取消）")
	else:
		_show_notice("目前無法到達這個位置，請選擇其他地點")


func _map_destination_title(target: Interactable3D) -> String:
	if Outskirts.EXITS.has(target.interaction_id):
		var destination: String = Outskirts.EXITS[target.interaction_id][1]
		return "前往・" + str(Outskirts.NAMES.get(destination, CryptLayout.NAMES.get(destination, "暮光村")))
	return target.prompt_text
