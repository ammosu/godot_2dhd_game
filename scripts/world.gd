class_name PrototypeWorld
extends Node3D

signal map_presented

const DoorInteraction = preload("res://scripts/gameplay/door_interaction.gd")
const Starbay = preload("res://scripts/gameplay/starbay.gd")
const CryptLayout = preload("res://scripts/gameplay/crypt_layout.gd")
const Dungeon = preload("res://scripts/gameplay/ashen_crypt.gd")
const Outskirts = preload("res://scripts/gameplay/outskirts.gd")

const Presentation = preload("res://scripts/ui/presentation_theme.gd")
const MiniMapControl = preload("res://scripts/ui/mini_map.gd")
const HouseDetails = preload("res://scripts/gameplay/house_details.gd")
const HouseExterior = preload("res://scripts/gameplay/house_exterior.gd")
const Footsteps = preload("res://scripts/gameplay/footsteps.gd")
const WaterFeature = preload("res://scripts/gameplay/water_feature.gd")
const GardenFence = preload("res://scripts/gameplay/garden_fence.gd")
const MeadowDressing = preload("res://scripts/gameplay/meadow_dressing.gd")
const SpriteGrounding = preload("res://scripts/gameplay/sprite_grounding.gd")
const HouseCatalog = preload("res://scripts/gameplay/house_catalog.gd")
const HouseInterior = preload("res://scripts/gameplay/house_interior.gd")
const StreetLantern = preload("res://scripts/gameplay/street_lantern.gd")
const ForegroundCutaway = preload("res://scripts/gameplay/foreground_cutaway.gd")
const MoonShard = preload("res://scripts/gameplay/moon_shard.gd")
const MoonSeal = preload("res://scripts/gameplay/moon_seal.gd")

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

@onready var player: Wanderer = $Player
@onready var dialogue_ui: DialogueUI = $DialogueUI
@onready var battle_ui: ActionBattleUI = $BattleUI

var _map_root: Node3D
# Keep immutable art resident while this world exists; map teardown must not
# force another decode/upload of the same large atlases on the return trip.
var _art_textures: Dictionary[String, Texture2D] = {}
var _art_baselines: Dictionary[String, float] = {}
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
var _quest_markers: Dictionary = {}

var _map_label: Label
var _quest_label: Label
var _prompt_label: Label
var _notice_label: Label
var _mini_map: MiniMapControl
var _heart_atlases: Array[AtlasTexture] = []
var _notice_generation: int = 0
var _interior_backdrop: ColorRect
var _test_mode: bool = false


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
	_load_map(GameState.current_map, GameState.spawn_id)
	if _test_mode:
		GameState.flags["intro_seen"] = true
		_run_playthrough_test.call_deferred()
	elif "--story-preview" in OS.get_cmdline_user_args():
		_test_mode = true # Preview never writes normal autosaves.
		GameState.flags["intro_seen"] = true
		_show_story_preview.call_deferred()
	elif "--equipment-preview" in OS.get_cmdline_user_args():
		GameState.flags["intro_seen"] = true
		$EquipmentUI.open.call_deferred()
	elif "--battle-preview" in OS.get_cmdline_user_args():
		_test_mode = true # Preview never writes normal autosaves.
		GameState.flags["intro_seen"] = true
		_load_map("ruins", "from_village")
		player.global_position = Vector3(0, 0.1, -5.5)
		($CameraRig as Hd2dCameraRig).snap_to_target()
		_start_guardian_battle.call_deferred()
	elif "--civic-preview" in OS.get_cmdline_user_args():
		_test_mode = true
		GameState.flags["intro_seen"] = true
		_load_map("starbay", "from_road")
		player.global_position = Vector3(-6, 0.1, -9)
		($CameraRig as Hd2dCameraRig).snap_to_target()
	elif "--japanese-preview" in OS.get_cmdline_user_args():
		_test_mode = true
		GameState.flags["intro_seen"] = true
		_load_map("starbay", "from_house_city_01")
		$CameraRig.set("_target_yaw", -0.6 + atan2(6.0, -8.0))
		$CameraRig.set("_distance", 14.0)
		($CameraRig as Hd2dCameraRig).snap_to_target()
	elif "--city-house-preview" in OS.get_cmdline_user_args():
		_test_mode = true
		GameState.flags["intro_seen"] = true
		_load_map("house_city_01", "entry")
	elif "--city-preview" in OS.get_cmdline_user_args():
		_test_mode = true
		GameState.flags["intro_seen"] = true
		_load_map("starbay", "from_road")
	elif "--caravan-preview" in OS.get_cmdline_user_args():
		_test_mode = true
		GameState.flags["intro_seen"] = true
		_load_map("caravan_road", "from_road")
	elif "--crypt-boss-preview" in OS.get_cmdline_user_args():
		_test_mode = true
		GameState.flags["intro_seen"] = true
		_load_map("ashen_crypt", "entry")
	elif "--dungeon-preview" in OS.get_cmdline_user_args():
		_test_mode = true
		GameState.flags["intro_seen"] = true
		_load_map("ashen_crypt_1", "entry")
	elif "--field-preview" in OS.get_cmdline_user_args():
		_test_mode = true
		GameState.flags["intro_seen"] = true
		_load_map("east_road", "from_village")
		player.global_position = Vector3(-1, 0.1, 6)
		$CameraRig.set("_distance", 15.0)
		$CameraRig.set("_target_yaw", deg_to_rad(-35.0))
		($CameraRig as Hd2dCameraRig).snap_to_target()
	elif "--mountain-preview" in OS.get_cmdline_user_args():
		_test_mode = true
		GameState.flags["intro_seen"] = true
		_load_map("moss_steps", "from_base")
	elif "--outskirts-preview" in OS.get_cmdline_user_args():
		_test_mode = true
		GameState.flags["intro_seen"] = true
		_load_map("east_road", "from_village")
	elif "--ruins-preview" in OS.get_cmdline_user_args():
		GameState.flags["intro_seen"] = true
		_load_map("ruins", "from_village")
		player.global_position = Vector3(-7.0, 0.1, 6.5)
	elif "--interior-preview" in OS.get_cmdline_user_args():
		GameState.flags["intro_seen"] = true
		_load_map("house_02", "entry")
	elif "--house-route-preview" in OS.get_cmdline_user_args():
		GameState.flags["intro_seen"] = true
		player.global_position = HouseCatalog.return_position("house_02")
		($CameraRig as Hd2dCameraRig).snap_to_target()
	elif "--village-preview" in OS.get_cmdline_user_args():
		GameState.flags["intro_seen"] = true
		player.global_position = Vector3(0.0, 0.1, 6.0)
		($CameraRig/Camera3D as Camera3D).fov = 45.0
	elif not bool(GameState.flags.get("intro_seen", false)):
		_show_class_selection.call_deferred()
	print("Wanderlight playable slice loaded with Godot %s" % Engine.get_version_info().get("string", "unknown"))


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
	if _prompt_label != null:
		var prompt := player.get_interaction_prompt() if GameState.mode == GameState.Mode.EXPLORE else ""
		var prompt_prefix := "互動：" if MobileControls.is_mobile_device() else "Space："
		_prompt_label.text = "%s%s" % [prompt_prefix, prompt] if not prompt.is_empty() else ""


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
	selection.journey_started.connect(_show_intro)
	add_child(selection)


func _show_intro() -> void:
	dialogue_ui.show_dialogue([
		{"speaker": "旁白", "text": "月光已連續三晚沒有照進暮光村，但遠方雲層仍泛著銀白。月亮沒有消失，只是不再回應這裡。"},
		{"speaker": "旁白", "text": "中央月燈只剩最後一點冰冷微光，夜霧正在村界外聚集。先四處看看，再與廣場左側的長老交談。"},
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
	player.auto_walk.cancel()
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
	_refresh_map_destinations()
	_profile_map_stamp("total_" + map_id, profile_started)
	map_presented.emit()


func _profile_map_stamp(stage: String, started: int) -> int:
	var now: int = Time.get_ticks_usec()
	if "--profile-map-build" in OS.get_cmdline_user_args():
		print("MAP_BUILD_PROFILE ", stage, " ms=", float(now - started) / 1000.0)
	return now


func _art_texture(path: String) -> Texture2D:
	if not _art_textures.has(path):
		_art_textures[path] = load(path) as Texture2D
	return _art_textures[path]


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
	_add_box("Ground", Vector3(0.0, -0.35, 0.0), Vector3(46.0, 0.7, 40.0), Color("304b48"), true)
	_add_cobble_box("CentralPlaza", Vector3(0.0, -0.02, 0.0), Vector3(7.8, 0.12, 8.0), true)
	preload("res://scripts/gameplay/natural_water.gd").pond(_map_root, Vector3(11.5, 0.085, -10.0), Vector2(9.0, 5.0))

	_add_cobble_box("NorthRoad", Vector3(0.0, 0.025, -3.75), Vector3(2.35, 0.08, 32.5), false)
	_add_cobble_box("MarketRoad", Vector3(0.0, 0.023, 4.6), Vector3(29.0, 0.075, 2.25), false)
	_add_cobble_box("GateRoad", Vector3(0.0, 0.022, -4.8), Vector3(29.0, 0.07, 1.9), false)
	_build_village_routes()
	# Outer garden promenade expands exploration without stretching the village square.
	for x_position: float in [-19.0, 19.0]:
		_add_cobble_box("GardenWalk", Vector3(x_position, 0.022, 0), Vector3(1.8, 0.07, 34), false)
	for z_position: float in [-16.8, 16.8]:
		_add_cobble_box("GardenWalk", Vector3(0, 0.022, z_position), Vector3(38, 0.07, 1.8), false)
	_configure_village_surfaces()
	for x_position: float in [-20.7, 20.7]:
		for z_position: float in [-15, -7, 2, 11, 17]:
			_add_tree(Vector3(x_position + sin(z_position * 1.7) * 0.55, 0, z_position + cos(z_position) * 0.75))
	for position: Vector3 in [Vector3(-19, 0, -12), Vector3(19, 0, -12), Vector3(-19, 0, 10), Vector3(19, 0, 10), Vector3(-6, 0, 16.8), Vector3(6, 0, 16.8)]:
		_add_lamp(position)
	stamp = _profile_map_stamp("village_surfaces", stamp)

	for column_position in [Vector3(-4.6, 0.0, -3.6), Vector3(4.6, 0.0, -3.6), Vector3(-4.6, 0.0, 3.6), Vector3(4.6, 0.0, 3.6)]:
		_add_column(column_position)
	for tree_position in [
		Vector3(-16.2, 0.0, -11.8), Vector3(-16.0, 0.0, -4.0), Vector3(-16.1, 0.0, 5.8), Vector3(-15.2, 0.0, 12.4),
		Vector3(16.1, 0.0, -5.3), Vector3(16.0, 0.0, 3.8), Vector3(15.5, 0.0, 11.9),
		Vector3(0.0, 0.0, 13.7), Vector3(14.8, 0.0, -13.0),
	]:
		_add_tree(tree_position)
	for lamp_position in [
		Vector3(-1.75, 0.0, -8.2), Vector3(1.75, 0.0, -8.2), Vector3(-1.75, 0.0, -3.5), Vector3(1.75, 0.0, -3.5),
		Vector3(-1.75, 0.0, 3.5), Vector3(1.75, 0.0, 3.5), Vector3(-1.75, 0.0, 8.6), Vector3(1.75, 0.0, 8.6),
		Vector3(-8.0, 0.0, 4.0), Vector3(8.0, 0.0, 4.0),
	]:
		_add_lamp(lamp_position)

	# Eight homes form west, east, north, and south neighborhoods around the plaza.
	stamp = _profile_map_stamp("village_columns_trees_lights", stamp)
	for home: Dictionary in HouseCatalog.HOMES:
		_add_house(home.position, home.wall, home.roof, home.yaw, home.id)
	stamp = _profile_map_stamp("village_houses", stamp)

	_add_crystal(Vector3(-7.0, 0.0, -3.2), 1.1)
	_add_crystal(Vector3(7.2, 0.0, 1.2), 0.85)
	_add_crystal(Vector3(14.0, 0.0, 9.0), 0.72)
	_add_supply_crate(Vector3(-6.5, 0.01, 4.0), 0.12)
	_add_supply_crate(Vector3(-5.5, 0.01, 4.6), -0.10)
	_add_earthenware_jar(Vector3(6.2, 0.01, 3.3))
	for grass_position: Vector3 in [Vector3(-14.0, 0.01, 3.0), Vector3(-13.5, 0.01, 2.6), Vector3(14.5, 0.01, -2.1), Vector3(14.0, 0.01, -2.45), Vector3(5.4, 0.01, 8.8)]:
		_add_grass_clump(grass_position, "seed", 0.001)
	_add_village_pig(Vector3(8.5, 0.015, 8.4))
	_add_village_gardens()
	stamp = _profile_map_stamp("village_props_gardens", stamp)

	_add_moon_lamp(Vector3(0.0, 0.0, 0.0))
	_map_root.add_child(preload("res://scripts/gameplay/awakened_road.gd").new())
	# Low planted crescent frames the landmark but leaves its south approach open.
	var planting := Node3D.new()
	planting.name = "MoonGarden"
	_map_root.add_child(planting)
	for index: int in range(20):
		var angle := PI + index * PI / 19.0
		var flower := Sprite3D.new()
		flower.texture = preload("res://assets/generated/flowers_ivory.tres")
		flower.pixel_size = 0.00065
		flower.position = Vector3(cos(angle) * 1.16, 0.015, sin(angle) * 1.16)
		flower.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		flower.shaded = true
		flower.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		flower.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		flower.modulate = Color("bc95da") if index % 3 != 0 else Color.WHITE
		planting.add_child(flower)
		SpriteGrounding.anchor(flower, flower.texture, SpriteGrounding.foot_baseline(flower.texture, flower.alpha_scissor_threshold))
		flower.remove_from_group("grounded_character_art")
	stamp = _profile_map_stamp("village_moon_lamp", stamp)
	_add_actor_interactable("elder", "與長老交談", Vector3(-3.0, 0.0, 1.2), "res://assets/generated/elder.tres", 1.6 / 724.0, Color.WHITE, false, MAIN_QUEST_MARKER)
	_add_actor_interactable("rumi", "與露米交談", Vector3(6.4, 0.0, 4.2), "res://assets/generated/rumi.tres", 1.6 / 724.0, Color.WHITE, false, SIDE_CONTENT_MARKER)
	_add_actor_interactable("noah", "與守門人交談", Vector3(2.2, 0.0, -17.0), "res://assets/generated/noah.tres", 1.6 / 724.0, Color.WHITE)
	_add_wandering_villagers()
	_add_portal("portal_to_ruins", "前往北境遺跡", Vector3(0.0, 0.0, -19.3), Color("86d9ff"))
	stamp = _profile_map_stamp("village_actors_portal", stamp)
	MeadowDressing.build(_map_root)
	_profile_map_stamp("village_meadow", stamp)


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
		villager.speed = 0.7 + float(index) * 0.12
		villager.wait_time = float(index) * 0.8
		_map_root.add_child(villager)


func _talk_to_wandering_villager(villager: CharacterBody3D) -> void:
	if GameState.is_input_locked() or _portal_transition_pending or GameState.current_map not in ["village", "starbay"]:
		return
	player.make_conversation_space(villager)
	player.face_world_position(villager.global_position)
	dialogue_ui.show_dialogue([{"speaker": str(villager.get("display_name")), "text": str(villager.get("dialogue_text"))}])
	var art := villager.get_node("CharacterArt") as Sprite3D
	art.call("turn_to", player)
	($CameraRig as Hd2dCameraRig).begin_dialogue_shot(art)


func _build_village_routes() -> void:
	# Visible terrain beyond the checkpoint makes the opening read as a road.
	_add_box("NorthApproachGround", Vector3(0, -0.35, -22.5), Vector3(12, 0.7, 7), Color("292b3e"), false)
	_add_cobble_box("NorthApproachRoad", Vector3(0, 0.025, -22.0), Vector3(2.35, 0.08, 5.5), false)
	for side: float in [-1.0, 1.0]:
		_add_tree(Vector3(side * 4.0, 0, -22.0))
	# Clipped, uneven corners soften the enclosure; preserve both portal gaps.
	var boundary: Array[Vector2] = [
		Vector2(1.75, -19.3), Vector2(17.8, -19.3), Vector2(21.5, -16.7),
		Vector2(22.3, -9.0), Vector2(22.3, 2.1),
		Vector2(22.3, 7.1), Vector2(21.9, 15.7), Vector2(18.2, 19.0),
		Vector2(6.0, 19.3), Vector2(-16.8, 19.0), Vector2(-22.0, 15.4),
		Vector2(-22.3, 4.0), Vector2(-21.8, -15.8), Vector2(-17.8, -19.3), Vector2(-1.75, -19.3),
	]
	for index: int in range(boundary.size() - 1):
		if index == 4:
			continue # East road opening.
		var start: Vector2 = boundary[index]
		var finish: Vector2 = boundary[index + 1]
		var middle: Vector2 = (start + finish) * 0.5
		_add_box("BoundaryWall", Vector3(middle.x, 0.75, middle.y), Vector3(0.7, 1.8, start.distance_to(finish) + 0.2), PALETTE.stone_dark, true)
		(_map_root.get_child(_map_root.get_child_count() - 1) as Node3D).rotation.y = atan2(finish.x - start.x, finish.y - start.y)
	_add_box("OutskirtsGround", Vector3(29.0, -0.38, 4.6), Vector3(16.0, 0.7, 19.0), Color("304b48"), false)
	_add_cobble_box("EastRoad", Vector3(30.5, 0.022, 4.6), Vector3(8.0, 0.075, 3.6), false)
	for tree_position: Vector3 in [Vector3(29, 0, 0), Vector3(32, 0, 1), Vector3(29, 0, 10), Vector3(33, 0, 9)]:
		_add_tree(tree_position)
	_add_box("EastRoadGround", Vector3(24.5, -0.35, 4.6), Vector3(6.0, 0.7, 5.0), Color("304b48"), true)
	_add_cobble_box("EastRoad", Vector3(20.75, 0.025, 4.6), Vector3(12.5, 0.08, 3.6), false)
	# A safety backstop sits beyond the automatic walking threshold.
	_add_box("EastTrailEdge", Vector3(27.25, 0.5, 4.6), Vector3(0.35, 1.0, 5), Color("405b49"), true)
	for z: float in [2.25, 6.95]:
		_add_box("EastTrailEdge", Vector3(25, 0.5, z), Vector3(4.5, 1.0, 0.3), Color("405b49"), true)
	for at: Vector3 in [Vector3(18.2, 0, 2.35), Vector3(18.2, 0, 6.85), Vector3(22.3, 0, 1.95), Vector3(22.3, 0, 7.25)]:
		_add_lamp(at)
	Outskirts.add_interaction(self, "travel_east", "東行・前往東行舊道", Vector3(26, 0, 4.6), true)


func _build_ruins() -> void:
	_add_box("SouthApproachGround", Vector3(0, -0.35, 18.5), Vector3(12, 0.7, 7), Color("304b48"), false)
	_add_cobble_box("SouthApproachRoad", Vector3(0, 0.025, 18.0), Vector3(2.35, 0.08, 5.5), false)
	_add_box("RuinGround", Vector3(0.0, -0.35, 0.0), Vector3(34.0, 0.7, 32.0), Color("292b3e"), true)
	_add_box("RuinCourt", Vector3(0.0, -0.02, -2.0), Vector3(14.0, 0.12, 17.0), PALETTE.ruin, true)
	_add_box("WestRuinCourt", Vector3(-9.0, -0.015, 4.0), Vector3(5.5, 0.1, 5.5), PALETTE.ruin.darkened(0.08), true)
	_add_box("EastRuinCourt", Vector3(9.0, -0.015, -1.5), Vector3(5.5, 0.1, 5.5), PALETTE.ruin.darkened(0.08), true)
	preload("res://scripts/gameplay/ruin_surfaces.gd").configure(_map_root)
	for z_index in range(-11, 16):
		_add_box("MoonPath_%02d" % (z_index + 11), Vector3(0.0, 0.025, float(z_index)), Vector3(1.45, 0.08, 0.82), Color("786c8d"), false)
	for x_index in range(-9, 10):
		_add_box("RuinCrossPath_%02d" % (x_index + 9), Vector3(float(x_index), 0.022, 3.8), Vector3(0.82, 0.07, 1.18), Color("6c617f"), false)
	for x_position in [-16.1, 16.1]:
		_add_box("RuinBoundary", Vector3(x_position, 0.8, 0.0), Vector3(0.8, 2.0, 31.0), Color("242235"), true)
	_add_box("RuinBoundary", Vector3(0.0, 0.8, -15.1), Vector3(33.0, 2.0, 0.8), Color("242235"), true)
	for side: float in [-1.0, 1.0]:
		_add_box("RuinBoundary", Vector3(side * 9.125, 0.8, 15.1), Vector3(14.75, 2.0, 0.8), Color("242235"), true)
	var ruin_columns: Array[Vector3] = [
		Vector3(-6.2, 0.0, -8.8), Vector3(6.2, 0.0, -8.8), Vector3(-6.2, 0.0, -1.5), Vector3(6.2, 0.0, -1.5),
		Vector3(-6.2, 0.0, 6.2), Vector3(6.2, 0.0, 6.2), Vector3(-11.0, 0.0, 3.8), Vector3(11.0, 0.0, -1.5),
	]
	for column_position: Vector3 in ruin_columns:
		_add_column(column_position)
	preload("res://scripts/gameplay/ruin_rubble.gd").build(_map_root, ruin_columns)
	for crystal_data in [
		[Vector3(-11.8, 0.0, -5.2), 1.3], [Vector3(11.5, 0.0, -7.0), 1.0], [Vector3(-12.0, 0.0, 9.0), 0.75],
		[Vector3(10.5, 0.0, 7.8), 1.15], [Vector3(5.6, 0.0, 11.0), 0.72],
	]:
		_add_crystal(crystal_data[0], crystal_data[1])
	for supply_position: Vector3 in [Vector3(-4.6, 0.01, 8.0), Vector3(4.9, 0.01, 7.2), Vector3(-9.2, 0.01, -3.8), Vector3(8.4, 0.01, 3.7), Vector3(-3.4, 0.01, -10.8)]:
		_add_supply_crate(supply_position, supply_position.x * 0.13)

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
		_add_crystal(Vector3(0.0, 0.0, -8.2), 0.65)


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
		await _close_arrival_door(destination)
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
	await player.walk_to_door_point(arrival, 2.0)
	player.release_door_facing()
	player.face_world_position(player.global_position + onward)


func _handle_interaction(interaction_id: String) -> void:
	if GameState.is_input_locked() or _portal_transition_pending:
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
		dialogue_ui.show_dialogue([{ "speaker": "小春・旅店掌櫃", "text": "睡得好嗎？熱茶已經泡好了。\n（生命與魔力已恢復。）" }])
		return
	if interaction_id == "house_resident" and HouseCatalog.is_interior(GameState.current_map):
		var resident: Dictionary = HouseCatalog.resident(GameState.current_map)
		var actor := _map_root.get_node("HouseResident") as Node3D
		player.make_conversation_space(actor)
		player.face_world_position(actor.global_position)
		dialogue_ui.show_dialogue([{"speaker": resident.name, "text": resident.text}])
		actor.get_node("CharacterArt").call("turn_to", player)
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
			_portal_transition_pending = true
			GameState.request_map(route[1], route[2])
		return
	if Outskirts.EVENTS.has(interaction_id):
		var event: Array = Outskirts.EVENTS[interaction_id]
		if GameState.current_map == event[0]:
			dialogue_ui.show_dialogue([{ "speaker": event[2], "text": GameState.resolve_outskirts_event(interaction_id) }])
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
			text = "三盆幼苗在微光中垂著葉。盆沿的舊註記寫著：月光恢復時，新葉會朝村外的道路伸展。"
		dialogue_ui.show_dialogue([{"speaker": furniture.name, "text": text}])
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
		var speaker := _map_root.get_node_or_null(NodePath(interaction_id.capitalize() + "/CharacterArt"))
		if speaker != null:
			player.make_conversation_space(speaker.get_parent() as Node3D)
			speaker.call("turn_to", player)
			($CameraRig as Hd2dCameraRig).begin_dialogue_shot(speaker as Node3D)


func _talk_to_elder() -> void:
	match GameState.quest_state:
		GameState.QuestState.NOT_STARTED:
			dialogue_ui.show_dialogue([
				{"speaker": "長老・艾爾", "text": "旅人，你也看見夜霧了吧。月燈若在今晚熄滅，霧就會越過村界。"},
				{"speaker": "長老・艾爾", "text": "北境遺跡保存著一枚月光碎片，是古人留下的備用燈心。只有它能讓月燈重新燃起。"},
				{"speaker": "旅人", "text": "月燈要我把借走的光送回原本的道路。那句話是什麼意思？"},
				{"speaker": "長老・艾爾", "text": "夜霧已逼近，我們得先讓村民活過今晚。其餘的事，等月燈復燃再談。"},
				{"speaker": "長老・艾爾", "text": "我會用月印開啟北方門扉。遺跡守衛或許會試探你；諾亞完成封印操作後會追上你，我也會隨後進入遺跡。"},
				{"speaker": "旅人", "text": "我會在月燈熄滅以前，把碎片帶回來。"},
			], GameState.start_quest)
		GameState.QuestState.ACTIVE:
			dialogue_ui.show_dialogue([
				{"speaker": "長老・艾爾", "text": "北方門扉已經開啟。沿著遺跡中的月紋石路前進，就能找到守衛。"},
				{"speaker": "長老・艾爾", "text": "若受了傷，找找遺跡裡仍在發光的月泉。"},
			])
		GameState.QuestState.READY_TO_TURN_IN:
			dialogue_ui.show_dialogue([
				{"speaker": "旅人", "text": "我帶回月光碎片了。"},
				{"speaker": "長老・艾爾", "text": "太好了。把它放進月燈的燈心，讓我們看看月光是否還願意回應。"},
			], _complete_main_quest)
		GameState.QuestState.COMPLETE:
			dialogue_ui.show_dialogue([
				{"speaker": "長老・艾爾", "text": "月燈再次閃耀，夜霧也退回了森林。謝謝你，暮光村的朋友。"},
				{"speaker": "長老・艾爾", "text": "我只知道碎片可能喚醒古道，卻不知道道路另一端還有什麼。為了讓大家活過今晚，我沒有把一切告訴你。"},
				{"speaker": "長老・艾爾", "text": "那道灼痕與月印同源。這場黑夜恐怕還沒有真正結束。"},
			])


func _talk_to_rumi() -> void:
	if not bool(GameState.flags.get("rumi_tip_seen", false)):
		GameState.flags["rumi_tip_seen"] = true
		GameState.state_changed.emit()
	match GameState.quest_state:
		GameState.QuestState.NOT_STARTED:
			dialogue_ui.show_dialogue([
				{"speaker": "村童・露米", "text": "以前月燈亮起來時，整個廣場都像白天一樣。現在連小豬都不敢靠近村口了。"},
				{"speaker": "村童・露米", "text": "奇怪的是，月燈周圍的影子沒有躲開光，反而全都朝北境遺跡伸過去。"},
				{"speaker": "村童・露米", "text": "艾爾爺爺好像知道發生了什麼。你可以替我們問問他嗎？"},
			])
		GameState.QuestState.ACTIVE:
			dialogue_ui.show_dialogue([{"speaker": "村童・露米", "text": "請小心回來。我會在這裡守著月燈最後的光。"}])
		GameState.QuestState.READY_TO_TURN_IN:
			dialogue_ui.show_dialogue([{"speaker": "村童・露米", "text": "你的行囊在發光！快把碎片交給艾爾爺爺！"}])
		GameState.QuestState.COMPLETE:
			dialogue_ui.show_dialogue([{"speaker": "村童・露米", "text": "你看，連小豬都跑回來了！謝謝你把月光帶回家。"}])


func _talk_to_noah() -> void:
	match GameState.quest_state:
		GameState.QuestState.NOT_STARTED:
			dialogue_ui.show_dialogue([
				{"speaker": "守門人・諾亞", "text": "北方門扉已沉睡多年。沒有長老的月印，我不能讓任何人冒險進去。"},
				{"speaker": "守門人・諾亞", "text": "但你抵達村莊的那一晚，門上的月紋曾自行亮起。我不知道那是否只是巧合。"},
			])
		GameState.QuestState.ACTIVE:
			dialogue_ui.show_dialogue([
				{"speaker": "守門人・諾亞", "text": "月印已經生效。門後就是北境遺跡。"},
				{"speaker": "守門人・諾亞", "text": "戰鬥時用方向鍵移動，J 攻擊、K 技能、空白鍵閃避。Tab 可切換隊員，我能用技能守護全隊。"},
			])
		GameState.QuestState.READY_TO_TURN_IN:
			dialogue_ui.show_dialogue([{"speaker": "守門人・諾亞", "text": "我看見門扉重新亮起，就知道你成功了。長老正在月燈旁等你。"}])
		GameState.QuestState.COMPLETE:
			dialogue_ui.show_dialogue([{"speaker": "守門人・諾亞", "text": "夜霧退去了，但遺跡的門仍在低鳴。我開始懷疑：這扇門究竟是在阻擋危險，還是在阻擋被我們遺忘的人？"}])


func _inspect_moon_lamp() -> void:
	match GameState.quest_state:
		GameState.QuestState.NOT_STARTED:
			dialogue_ui.show_dialogue([
				{"speaker": "月燈", "text": "燈心裡只剩一點冰冷的銀光，彷彿隨時會被風吹熄。"},
				{"speaker": "不明低語", "text": "把借走的光，送回它原本要照亮的道路。"},
				{"speaker": "旅人", "text": "……是聲音，還是某段不屬於我的記憶？"},
			])
		GameState.QuestState.ACTIVE:
			dialogue_ui.show_dialogue([{"speaker": "月燈", "text": "微光比剛才更弱了。必須盡快從北境遺跡帶回月光碎片。"}])
		GameState.QuestState.READY_TO_TURN_IN:
			dialogue_ui.show_dialogue([{"speaker": "月燈", "text": "行囊中的月光碎片正與燈心共鳴。先讓長老確認它的力量。"}])
		GameState.QuestState.COMPLETE:
			dialogue_ui.show_dialogue([{"speaker": "月燈", "text": "溫暖的月光灑滿廣場，石縫中的環形光路卻仍朝村外延伸。這盞燈正在重新指向某條道路。"}])


func _read_ruin_tablet() -> void:
	GameState.flags["ruin_tablet_read"] = true
	GameState.state_changed.emit()
	dialogue_ui.show_dialogue([
		{"speaker": "風化石碑", "text": "『月光並非驅散黑暗，而是指引迷途之人穿過黑暗。』"},
		{"speaker": "風化石碑", "text": "『持燈者不得將光據為己有……不得因一地的安寧，使道路上的人永遠迷失。』"},
		{"speaker": "旅人", "text": "下方刻著一枚帶缺口的環形紋章，名稱卻被人刻意磨去了。"},
	])


func _rest_at_moon_spring() -> void:
	var memory: Texture2D = _art_texture("res://assets/generated/moon_spring_memory.png")
	var needs_rest := GameState.player_hp < GameState.player_max_hp or GameState.player_mp < GameState.player_max_mp
	var lines: Array[Dictionary] = [
		{"speaker": "月泉", "text": "泉面映出一段不屬於此刻的景象：許多人曾沿月光穿過夜霧，直到一道新建的村牆截斷道路。", "illustration": memory, "cinematic": "moon_memory"},
	]
	if needs_rest:
		GameState.restore_player()
		lines.append({"speaker": "月泉", "text": "景象散去，清澈的光流過全身。HP 與 MP 已完全恢復。"})
	else:
		lines.append({"speaker": "旅人", "text": "HP 與 MP 都很充足。但這段被截斷歸途的記憶，為什麼要讓我看見？"})
	if GameState.quest_state == GameState.QuestState.ACTIVE:
		lines.append({"speaker": "系統", "text": "試煉就在遺跡原地進行。WASD 移動，J 攻擊、K 技能、空白鍵閃避；確認紅色預警後離開危險區。Tab 換人、Q/E 轉鏡頭，石柱能擋住攻擊。"})
		lines.append({"speaker": "系統", "text": "諾亞的守護、艾爾的療癒要選存活同伴；療癒不能復活。霜星爆選中央敵人可波及三人，普通攻擊不耗 MP。"})
		lines.append({"speaker": "系統", "text": "挑戰前可開啟裝備調整三人的武器與防具，並在探索時存檔。全隊倒下會回村恢復，任務仍可重試。"})
	dialogue_ui.show_dialogue(lines)


func _talk_to_guardian() -> void:
	if GameState.quest_state != GameState.QuestState.ACTIVE or bool(GameState.flags.get("guardian_defeated", false)):
		return
	var lines: Array[Dictionary] = []
	if bool(GameState.flags.get("ruin_tablet_read", false)):
		lines.append({"speaker": "遺跡守衛", "text": "你讀過引路人的誓言，也看見了那枚被抹去名字的缺口環紋。"})
	else:
		lines.append({"speaker": "遺跡守衛", "text": "碎片能救你的村莊，也會喚醒一條被封閉的古道。力量與道路的責任不可分離。"})
	lines.append({"speaker": "遺跡守衛", "text": "每當引路之光被鎖在一地，霧中的道路便更加黯淡。證明你帶回村莊的是希望，而不是另一道只保護少數人的牆。"})
	lines.append({"speaker": "遺跡守衛", "text": "苔背狼是只求存活的恐懼，月蝕術士是占有月光的執念。這兩段失敗的記憶，將與我一同試問你們的決心。"})
	lines.append({"speaker": "旅人", "text": "我要讓村民活過今晚，也不會忘記仍在霧中尋路的人。那就開始吧。"})
	lines.append({"speaker": "諾亞", "text": "我和長老會自動助戰，你可以用 Tab 換人。確認站位、閃開紅色預警，再趁敵人收招攻擊。"})
	lines.append({"speaker": "長老", "text": "霜星爆能波及附近的敵人。注意範圍圈和命中標記，不必只盯著守衛。"})
	dialogue_ui.show_dialogue(lines, _start_guardian_battle)


func _complete_main_quest() -> void:
	GameState.complete_quest()
	_update_moon_lamp_state()
	GameState.remember_player_position(player.global_position)
	if not _test_mode:
		GameState.save_game(GameState.SAVE_PATH, false)
	var ending_lines: Array[Dictionary] = [
		{"speaker": "旁白", "text": "碎片融入燈心。銀白光芒沿著廣場的石縫擴散，村外的夜霧開始退去。"},
		{"speaker": "村童・露米", "text": "月光回來了！小豬也敢靠近廣場了！"},
		{"speaker": "旁白", "text": "歡呼聲中，石縫浮現一條通往村外的環形光路。艾爾手中的月印同時烙下一枚缺口環紋。"},
		{"speaker": "長老・艾爾", "text": "……古道真的醒了。我知道碎片可能帶來這個結果，但若不點燈，村莊今晚便會被夜霧吞沒。"},
	]
	if bool(GameState.flags.get("ruin_tablet_read", false)):
		ending_lines.append({"speaker": "旅人", "text": "我在遺跡的石碑上看過相同的紋章。有人刻意抹去了它的名字。"})
	var awakening := load("res://assets/generated/fog_awakening.png") as Texture2D
	ending_lines.append({"speaker": "旁白", "text": "遠方的夜霧中，某個沉睡已久的存在因古道復甦而睜開了眼睛。", "illustration": awakening, "motion": "awakening"})
	ending_lines.append({"speaker": "霧中之聲", "text": "最後一盞路燈，終於又亮了。", "illustration": awakening, "motion": "awakening"})
	ending_lines.append({"speaker": "系統", "text": "序章〈熄滅的月燈〉完成。可繼續與村民交談、調查月燈，或探索八棟住宅；古道另一端的旅程尚未開放。"})
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
			{"speaker": "遺跡守衛", "text": "試煉證明的不是你能奪走它，而是你身邊仍有人願意守護、療癒與同行。燈亮起時，路也會醒來。"},
			{"speaker": "旁白", "text": "守衛解除形體，碎片主動飛向旅人；它的斷裂外環與石碑紋章吻合。終有一天，旅人必須決定月光該照向一座村莊，還是所有迷途之人。"},
		], func() -> void:
			var presentation := shard_reference.get_ref() as Node3D
			if presentation != null:
				presentation.queue_free()
		)
	else:
		GameState.restore_after_defeat()
		dialogue_ui.show_dialogue([
			{"speaker": "旁白", "text": "村民在遺跡入口發現了你，並將你送回暮光村。"},
			{"speaker": "系統", "text": "HP 與 MP 已恢復，北門仍然開啟。調整裝備後可再次挑戰；已使用的藥水不會補回，普通攻擊與閃避可免費使用。"},
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
	if interaction_id in ["elder", "rumi", "noah", "guardian", "road_traveler"]:
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
	if interaction_id in ["noah", "elder", "rumi"]:
		sprite.set_script(preload("res://scripts/gameplay/equipment_actor.gd"))
		sprite.set("actor_id", interaction_id)
	if interaction_id == "house_resident":
		if texture_path.contains("/city_residents/"):
			sprite.set_script(preload("res://scripts/gameplay/city_resident_art.gd"))
		else:
			sprite.set_script(preload("res://scripts/gameplay/resident_art.gd"))
			sprite.set("resident_id", texture_path.get_file().get_basename())
		sprite.set("visible_height", 1.4 * HouseCatalog.INTERIOR_CHARACTER_SCALE)
	sprite.texture = _art_texture(texture_path)
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
	for interaction_id: String in _quest_markers:
		var marker := _quest_markers[interaction_id] as Label3D
		if not is_instance_valid(marker):
			continue
		match interaction_id:
			"elder":
				marker.visible = GameState.quest_state in [GameState.QuestState.NOT_STARTED, GameState.QuestState.READY_TO_TURN_IN]
			"rumi":
				marker.visible = not bool(GameState.flags.get("rumi_tip_seen", false))
			"guardian":
				marker.visible = GameState.quest_state == GameState.QuestState.ACTIVE and not bool(GameState.flags.get("guardian_defeated", false))
			_:
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
	base.material_override = _make_material(PALETTE.ruin.lightened(0.08), 0.84)
	pedestal.add_child(base)

	var focus := MeshInstance3D.new()
	focus.position.y = 0.7
	var focus_mesh := PrismMesh.new()
	focus_mesh.size = Vector3(0.36, 0.7, 0.3)
	focus.mesh = focus_mesh
	focus.material_override = _make_material(color, 0.2, 0.0, color, 2.8)
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
		inscription.albedo_texture = _art_texture("res://assets/generated/moon_tablet_open_ring.png")
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

	var frame_material := _make_coursed_stone()
	var trim_material := _make_material(Color("514a40"), 0.82, 0.35)
	trim_material.albedo_texture = preload("res://assets/generated/aged_bronze_albedo.png")
	trim_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	var door_material := _make_material(Color("92714e"), 0.94, 0.0)
	door_material.albedo_texture = preload("res://assets/generated/timber_albedo.png")
	door_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	var door_dark_material := _make_material(Color("30271e"), 0.95, 0.0)

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
	seal.material_override = _make_material(color.darkened(0.4), 0.8, 0.3, color, 0.12)
	portal.add_child(seal)

	var seal_core := MeshInstance3D.new()
	seal_core.name = "MoonSealCore"
	seal_core.position = Vector3(0.0, 1.52, approach_side * 0.2)
	seal_core.rotation_degrees = Vector3(0.0, 0.0, 45.0)
	var core_mesh := PrismMesh.new()
	core_mesh.size = Vector3(0.25, 0.38, 0.14)
	seal_core.mesh = core_mesh
	seal_core.material_override = _make_material(color.darkened(0.25), 0.7, 0.3, color, 0.12)
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
			dialogue_ui.show_dialogue([
				{"speaker": "古老門扉", "text": "藍色紋路一閃即逝，門扉沒有開啟。"},
				{"speaker": "守門人・諾亞", "text": "它只聽從長老的月印。先去廣場找艾爾長老吧。"},
			])
			return
		_portal_transition_pending = true
		GameState.request_map("ruins", "from_village")
	elif interaction_id == "portal_to_village":
		_portal_transition_pending = true
		GameState.request_map("village", "from_ruins")


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


func _add_box(node_name: String, world_position: Vector3, size: Vector3, color: Color, collision: bool, metallic: float = 0.0) -> void:
	var root: Node3D = StaticBody3D.new() if collision else Node3D.new()
	root.name = node_name
	root.set_meta("authored_name", node_name)
	root.position = world_position
	_map_root.add_child(root)
	if node_name in ["Ground", "RuinGround"]:
		Footsteps.register_surface(root, size, &"dirt")
	elif node_name.ends_with("RuinCourt") or node_name.begins_with("MoonPath_") or node_name.begins_with("RuinCrossPath_"):
		Footsteps.register_surface(root, size, &"dirt" if GameState.current_map in ["east_road", "firefly_forest", "caravan_road"] else &"stone", 10)
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.material_override = _make_material(color, 0.88, metallic)
	if node_name.ends_with("RuinCourt") or node_name == "RuinCourt" or node_name.begins_with("MoonPath_") or node_name.begins_with("RuinCrossPath_"):
		var ruin_material := _make_material(Color("b8b7d0"), 0.97)
		ruin_material.albedo_texture = _art_texture("res://assets/generated/ruin_flagstone.png")
		ruin_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		ruin_material.uv1_scale = Vector3(maxf(size.x / 4.0, 0.25), maxf(size.z / 4.0, 0.25), 1.0)
		mesh_instance.material_override = ruin_material
	if node_name.ends_with("RuinCourt"):
		var court := ShaderMaterial.new()
		court.shader = preload("res://shaders/ruin_court.gdshader")
		court.set_shader_parameter("stone_texture", preload("res://assets/generated/ruin_flagstone.png"))
		court.set_shader_parameter("mineral_texture", preload("res://assets/generated/moon_lamp_cut_limestone_albedo.png"))
		court.set_shader_parameter("court_rect", Vector4(world_position.x, world_position.z, size.x * 0.5, size.z * 0.5))
		court.set_shader_parameter("stone_scale", Vector2(maxf(size.x / 4.0, 0.25), maxf(size.z / 4.0, 0.25)))
		mesh_instance.material_override = court
		# A 3–4 cm collision lip must not outline the soil blend with a hard shadow.
		mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if node_name in ["Ground", "EastRoadGround", "OutskirtsGround"]:
		mesh_instance.material_override = _make_village_surface(false)
	elif node_name == "RuinGround":
		var soil := ShaderMaterial.new()
		soil.shader = preload("res://shaders/ruin_soil.gdshader")
		soil.set_shader_parameter("mineral_texture", preload("res://assets/generated/moon_lamp_cut_limestone_albedo.png"))
		mesh_instance.material_override = soil
	elif node_name == "BoundaryWall":
		mesh_instance.material_override = _make_coursed_stone()
	root.add_child(mesh_instance)
	if collision:
		var collision_shape := CollisionShape3D.new()
		var box_shape := BoxShape3D.new()
		box_shape.size = size
		collision_shape.shape = box_shape
		root.add_child(collision_shape)


func _make_coursed_stone() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/coursed_stone.gdshader")
	material.set_shader_parameter("stone_texture", preload("res://assets/generated/moon_lamp_cut_limestone_albedo.png"))
	return material


func _configure_village_surfaces() -> void:
	var roads: Dictionary[String, String] = {
		"CentralPlaza": "plaza_rect", "NorthRoad": "north_rect",
		"MarketRoad": "market_rect", "GateRoad": "gate_rect",
	}
	var surfaces: Array[Node] = []
	for child: Node in _map_root.get_children():
		if str(child.name) in ["Ground", "CentralPlaza", "NorthRoad", "MarketRoad", "GateRoad"] or child.is_in_group("village_garden_walks"):
			surfaces.append(child)
	for surface_root: Node in surfaces:
		var surface := surface_root.get_child(0) as MeshInstance3D
		var material := surface.material_override as ShaderMaterial
		material.set_shader_parameter("organic_village", true)
		for road_name: String in roads:
			var road := _map_root.get_node(road_name) as Node3D
			var mesh := (road.get_child(0) as MeshInstance3D).mesh as BoxMesh
			material.set_shader_parameter(roads[road_name], Vector4(road.position.x, road.position.z, mesh.size.x * 0.5, mesh.size.z * 0.5))


func _make_village_surface(road_surface: bool) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/village_surface.gdshader")
	material.set_shader_parameter("meadow_texture", preload("res://assets/generated/meadow_albedo.png"))
	material.set_shader_parameter("cobble_texture", preload("res://assets/generated/village_paving_v2.png"))
	material.set_shader_parameter("road_surface", road_surface)
	material.set_shader_parameter("dirt_texture", preload("res://assets/generated/terrain/trampled_gravel.png"))
	material.set_shader_parameter("broken_texture", preload("res://assets/generated/terrain/weathered_stone.png"))
	material.set_shader_parameter("dry_grass_texture", preload("res://assets/generated/terrain/meadow_dry.png"))
	material.set_shader_parameter("road_kind", 2 if GameState.current_map in ["east_road", "firefly_forest", "caravan_road"] else 0)
	return material


func _add_cobble_box(node_name: String, world_position: Vector3, size: Vector3, collision: bool) -> void:
	var root: Node3D = StaticBody3D.new() if collision else Node3D.new()
	root.name = node_name
	if node_name == "GardenWalk":
		root.add_to_group("village_garden_walks")
	root.position = world_position
	_map_root.add_child(root)
	Footsteps.register_surface(root, size, &"dirt" if GameState.current_map in ["east_road", "firefly_forest", "caravan_road"] else &"stone", 10)
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.material_override = _make_village_surface(true)
	if node_name in ["GardenWalk", "EastRoad", "NorthApproachRoad", "SouthApproachRoad"]:
		(mesh_instance.material_override as ShaderMaterial).set_shader_parameter("plaza_rect", Vector4(world_position.x, world_position.z, size.x * 0.5, size.z * 0.5))
	if node_name == "EastRoad":
		(mesh_instance.material_override as ShaderMaterial).set_shader_parameter("road_brightness", 1.12)
	# Visual paving and collision share the same top, avoiding invisible steps.
	mesh_instance.position.y = 0.006 - world_position.y - size.y * 0.5
	# These shallow paving overlays blend into the ground; their straight box
	# silhouette must not cast an artificial curb shadow across that blend.
	mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mesh_instance)
	if collision:
		var collision_shape := CollisionShape3D.new()
		var box_shape := BoxShape3D.new()
		box_shape.size = size
		collision_shape.shape = box_shape
		collision_shape.position.y = mesh_instance.position.y
		root.add_child(collision_shape)


func _add_house(world_position: Vector3, wall_color: Color, roof_color: Color, rotation_y: float, house_id: String, japanese_variant: int = -1, shop_id: String = "") -> void:
	var house := StaticBody3D.new()
	house.name = "VillageHouse"
	house.set_meta("house_id", house_id)
	house.position = world_position
	house.rotation.y = rotation_y
	_map_root.add_child(house)

	var wall_material := _make_material(wall_color, 0.92)
	wall_material.albedo_color = wall_color.lightened(0.32)
	wall_material.albedo_texture = _art_texture("res://assets/generated/plaster_albedo.png")
	wall_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	wall_material.uv1_scale = Vector3(2.0, 1.0, 1.0)
	var timber_material := _make_material(Color("a99b92"), 0.92)
	timber_material.albedo_texture = _art_texture("res://assets/generated/timber_albedo.png")
	timber_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	var roof_material := _make_material(roof_color.lightened(0.78), 0.94)
	roof_material.albedo_texture = _art_texture("res://assets/generated/slate_roof_albedo.png")
	roof_material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	var window_material := ShaderMaterial.new()
	window_material.shader = preload("res://shaders/house_window.gdshader")
	var foundation_material := _make_material(Color("aaa6af"), 0.96)
	foundation_material.albedo_texture = _art_texture("res://assets/generated/ruin_flagstone.png")
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


func _add_tree(world_position: Vector3) -> void:
	var root := Node3D.new()
	root.name = "VillageOak"
	root.add_to_group("village_trees")
	root.position = world_position
	_map_root.add_child(root)
	preload("res://scripts/gameplay/tree_variants.gd").decorate(root, world_position)
	# Trunk-sized obstacle; the broad billboard canopy stays walkable beneath.
	preload("res://scripts/gameplay/prop_collision.gd").cylinder(root, Vector3(0, 0.8, 0), 0.36, 1.6)


func _add_lamp(world_position: Vector3) -> void:
	StreetLantern.build(_map_root, world_position)


func _add_village_gardens() -> void:
	# Local seed keeps dressing stable without changing gameplay randomness.
	var garden_rng := RandomNumberGenerator.new()
	garden_rng.seed = 704
	var grass_variants: Array[String] = ["low", "seed", "fan"]
	for side: float in [-1.0, 1.0]:
		for index: int in range(90):
			var z := garden_rng.randf_range(6.1, 12.0)
			var x := side * garden_rng.randf_range(1.4, 3.5)
			_add_grass_clump(Vector3(x, 0.01, z), grass_variants[index % 3], garden_rng.randf_range(0.00065, 0.00095))
		for index: int in range(60):
			var x := side * garden_rng.randf_range(5.7, 10.0)
			var z := garden_rng.randf_range(2.5, 3.2)
			_add_grass_clump(Vector3(x, 0.01, z), grass_variants[index % 3], garden_rng.randf_range(0.00065, 0.00095))
	for fence_data: Array in [
		# Keep the garden-house doorway apron open; the fence borders its south bed.
		[Vector3(-8.4, 0.35, 2.3), Vector3(4.0, 0.7, 0.16)],
		[Vector3(8.2, 0.35, 1.8), Vector3(3.5, 0.7, 0.16)],
		[Vector3(-8.5, 0.35, 7.3), Vector3(3.8, 0.7, 0.16)],
		[Vector3(8.6, 0.35, 7.3), Vector3(3.2, 0.7, 0.16)],
	]:
		var fence_position: Vector3 = fence_data[0]
		var fence_size: Vector3 = fence_data[1]
		GardenFence.build(_map_root, Vector3(fence_position.x, 0.0, fence_position.z), fence_size.x)
	var flower_variants: Array[String] = ["ivory", "mauve", "blue"]
	var flower_positions: Array[Vector3] = [
		Vector3(-7.4, 0.01, 2.35), Vector3(-8.2, 0.01, 2.55), Vector3(-9.1, 0.01, 2.3),
		Vector3(7.2, 0.01, 2.35), Vector3(8.1, 0.01, 2.55), Vector3(9.0, 0.01, 2.3),
		Vector3(-7.2, 0.01, 7.85), Vector3(-8.1, 0.01, 8.05), Vector3(7.5, 0.01, 7.8),
		Vector3(9.4, 0.01, 7.9), Vector3(-5.2, 0.01, -2.1), Vector3(5.3, 0.01, -1.9),
	]
	for flower_index: int in range(flower_positions.size()):
		_add_flower_clump(flower_positions[flower_index], flower_variants[flower_index % flower_variants.size()])


func _add_grass_clump(world_position: Vector3, variant: String, pixel_size: float) -> void:
	var grass := Sprite3D.new()
	grass.name = "MeadowGrass"
	grass.texture = _art_texture("res://assets/generated/grass_%s.tres" % variant)
	grass.pixel_size = pixel_size
	# 704px canvas, root baseline at 680. Keep roots fixed while orbiting.
	grass.position = world_position + Vector3.UP * (680.0 - 352.0) * pixel_size
	grass.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	grass.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	grass.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	grass.shaded = true
	grass.double_sided = true
	var patch: float = sin(world_position.x * 0.29 + sin(world_position.z * 0.37)) * 0.5 + 0.5
	grass.modulate = Color.WHITE.lerp(Color("c4ba8b"), patch * 0.32)
	grass.flip_h = sin(world_position.x * 7.1 + world_position.z * 3.7) > 0.0
	_map_root.add_child(grass)


func _add_flower_clump(world_position: Vector3, variant: String) -> void:
	var flower := Sprite3D.new()
	flower.name = "FlowerClump"
	flower.texture = _art_texture("res://assets/generated/flowers_%s.tres" % variant)
	flower.pixel_size = 0.001
	# All three 640px canvases share the root baseline at y=620.
	# Ground the foliage instead of reusing the old floating sphere height.
	flower.position = world_position + Vector3.UP * (620.0 - 320.0) * flower.pixel_size
	flower.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	flower.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	flower.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	flower.shaded = true
	flower.double_sided = true
	_map_root.add_child(flower)


func _add_supply_crate(world_position: Vector3, yaw: float) -> void:
	var scene := preload("res://assets/generated/supply_crate.glb") as PackedScene
	var crate := scene.instantiate() as Node3D
	crate.name = "SupplyCrate"
	crate.position = world_position
	crate.rotation.y = yaw
	crate.add_to_group("supply_crate_art")
	_map_root.add_child(crate)
	preload("res://scripts/gameplay/prop_collision.gd").from_meshes(crate)
	for node: Node in crate.find_children("*", "MeshInstance3D", true, false):
		var instance := node as MeshInstance3D
		for surface: int in range(instance.mesh.get_surface_count()):
			var material := instance.mesh.surface_get_material(surface) as BaseMaterial3D
			if material != null:
				material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST


func _add_crystal(world_position: Vector3, scale_factor: float) -> void:
	var crystal_scene := load("res://assets/generated/moon_crystal.glb") as PackedScene
	var crystal := crystal_scene.instantiate() as Node3D
	preload("res://scripts/gameplay/crystal_materials.gd").apply(crystal)
	crystal.name = "GlowCrystal"
	crystal.position = world_position
	crystal.scale = Vector3.ONE * scale_factor
	crystal.rotation.y = world_position.x * 0.37 + world_position.z * 0.19
	_map_root.add_child(crystal)
	preload("res://scripts/gameplay/prop_collision.gd").from_meshes(crystal, true)


func _add_village_pig(world_position: Vector3) -> void:
	var pig := AnimatedSprite3D.new()
	pig.name = "VillagePig"
	pig.sprite_frames = preload("res://assets/generated/pig_idle.tres")
	pig.pixel_size = 0.00105
	# The 800x640 presentation canvas anchors both poses' hooves at y=620.
	pig.position = world_position + Vector3.UP * 300.0 * pig.pixel_size
	pig.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	pig.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	pig.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	# Match the readable character-sprite treatment, with a muted dusk tint.
	pig.shaded = false
	pig.modulate = Color("c8b9c5")
	pig.double_sided = true
	pig.add_to_group("village_pig_art")
	_map_root.add_child(pig)
	pig.play(&"idle")


func _add_earthenware_jar(world_position: Vector3) -> void:
	var jar := (preload("res://assets/generated/earthenware_jar.glb") as PackedScene).instantiate() as Node3D
	jar.name = "EarthenwareJar"
	jar.position = world_position
	jar.rotation.y = 0.3
	jar.add_to_group("earthenware_jar_art")
	_map_root.add_child(jar)
	preload("res://scripts/gameplay/prop_collision.gd").from_meshes(jar, true)
	for node: Node in jar.find_children("*", "MeshInstance3D", true, false):
		var instance := node as MeshInstance3D
		for surface: int in range(instance.mesh.get_surface_count()):
			var material := instance.mesh.surface_get_material(surface) as BaseMaterial3D
			if material != null:
				material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
				material.albedo_color = Color("b6bec4")


func _make_material(color: Color, roughness: float, metallic: float = 0.0, emission: Color = Color.BLACK, emission_energy: float = 1.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	if emission != Color.BLACK:
		material.emission_enabled = true
		material.emission = emission
		material.emission_energy_multiplier = emission_energy
	return material


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
	var hud := CanvasLayer.new()
	hud.name = "HUD"
	hud.layer = 30
	add_child(hud)

	var panel := PanelContainer.new()
	panel.position = Vector2(24.0, 24.0)
	panel.name = "QuestPanel"
	panel.custom_minimum_size = Vector2(360.0, 0.0)
	panel.theme = GameState.ui_theme
	hud.add_child(panel)
	panel.add_theme_stylebox_override("panel", Presentation.panel())
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 5)
	panel.add_child(info)
	var brand := Label.new()
	brand.text = "W A N D E R L I G H T"
	brand.add_theme_font_size_override("font_size", 11)
	brand.add_theme_color_override("font_color", Presentation.GOLD)
	info.add_child(brand)
	_map_label = Label.new()
	_map_label.theme_type_variation = &"TitleLabel"
	_map_label.add_theme_font_size_override("font_size", 28)
	_map_label.add_theme_color_override("font_color", Presentation.PAPER)
	info.add_child(_map_label)
	var rule := HSeparator.new()
	var rule_style := StyleBoxLine.new()
	rule_style.color = Color("665c49")
	rule.add_theme_stylebox_override("separator", rule_style)
	info.add_child(rule)
	_quest_label = Label.new()
	_quest_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_quest_label.add_theme_color_override("font_color", Color("fff2d2"))
	_quest_label.add_theme_font_size_override("font_size", 17)
	info.add_child(_quest_label)
	_quest_label.minimum_size_changed.connect(func() -> void: panel.set_deferred("size", Vector2(panel.size.x, 0)))
	var footer := PanelContainer.new()
	footer.name = "TravelHints"
	footer.theme = GameState.ui_theme
	footer.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	footer.offset_left = 24
	footer.offset_top = -64
	footer.offset_right = 24
	footer.offset_bottom = -24
	footer.add_theme_stylebox_override("panel", Presentation.panel(10))
	hud.add_child(footer)
	var shortcuts := HBoxContainer.new()
	shortcuts.add_theme_constant_override("separation", 12)
	footer.add_child(shortcuts)
	for shortcut: Array in [["WASD", "移動"], ["Space", "互動"], ["I", "裝備"], ["F5", "存檔"], ["F9", "讀檔"]]:
		var key := Label.new()
		key.text = shortcut[0]
		key.custom_minimum_size.x = 26
		key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		key.add_theme_color_override("font_color", Presentation.GOLD)
		var key_style := Presentation.panel(4)
		key_style.set_corner_radius_all(3)
		key_style.shadow_size = 0
		key.add_theme_stylebox_override("normal", key_style)
		shortcuts.add_child(key)
		var action := Label.new()
		action.text = shortcut[1]
		action.add_theme_color_override("font_color", Presentation.PAPER)
		shortcuts.add_child(action)

	var heart_row := HBoxContainer.new()
	heart_row.name = "ExplorationHearts"
	heart_row.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	heart_row.position = Vector2(-164.0, 24.0)
	heart_row.add_theme_constant_override("separation", 4)
	hud.add_child(heart_row)
	var heart_sheet := load("res://assets/third_party/ninja_adventure/ui/heart.png") as Texture2D
	for index in range(5):
		var atlas := AtlasTexture.new()
		atlas.atlas = heart_sheet
		atlas.region = Rect2(64.0, 0.0, 16.0, 16.0)
		_heart_atlases.append(atlas)
		var heart := TextureRect.new()
		heart.texture = atlas
		heart.custom_minimum_size = Vector2(24.0, 24.0)
		heart.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		heart.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		heart.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		heart_row.add_child(heart)

	_mini_map = MiniMapControl.new()
	_mini_map.name = "MiniMap"
	_mini_map.anchor_left = 1.0
	_mini_map.anchor_right = 1.0
	_mini_map.offset_left = -194.0 if MobileControls.is_mobile_device() else -250.0
	_mini_map.offset_right = -24.0
	_mini_map.offset_top = 146.0 if MobileControls.is_mobile_device() else 62.0
	_mini_map.offset_bottom = _mini_map.offset_top + (170.0 if MobileControls.is_mobile_device() else 226.0)
	_mini_map.theme = GameState.ui_theme
	hud.add_child(_mini_map)
	_mini_map.destination_selected.connect(_on_map_destination)
	var map_ui := preload("res://scripts/ui/map_ui.gd").new()
	map_ui.name = "MapUI"
	map_ui.source_map = _mini_map
	add_child(map_ui)
	var map_button := Button.new()
	map_button.name = "OpenMap"
	map_button.text = "地圖  G" if not MobileControls.is_mobile_device() else "地圖"
	map_button.theme = GameState.ui_theme
	map_button.anchor_left = 1.0
	map_button.anchor_right = 1.0
	map_button.offset_left = _mini_map.offset_left
	map_button.offset_right = -24.0
	map_button.offset_top = _mini_map.offset_top + (178.0 if MobileControls.is_mobile_device() else 234.0)
	map_button.offset_bottom = map_button.offset_top + (64.0 if MobileControls.is_mobile_device() else 48.0)
	if MobileControls.is_mobile_device():
		map_button.add_theme_font_size_override("font_size", 22)
	var map_glyph := preload("res://scripts/ui/map_glyph.gd").new()
	map_glyph.position = Vector2(28, 17 if MobileControls.is_mobile_device() else 10)
	map_button.add_child(map_glyph)
	map_button.pressed.connect(map_ui.open)
	hud.add_child(map_button)
	map_ui.open_button = map_button

	_prompt_label = Label.new()
	_prompt_label.anchor_left = 0.5
	_prompt_label.anchor_top = 1.0
	_prompt_label.anchor_right = 0.5
	_prompt_label.anchor_bottom = 1.0
	_prompt_label.offset_left = -260.0
	_prompt_label.offset_top = -72.0 if MobileControls.is_mobile_device() else -120.0
	_prompt_label.offset_right = 260.0
	_prompt_label.offset_bottom = -26.0 if MobileControls.is_mobile_device() else -74.0
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_prompt_label.add_theme_color_override("font_color", Color("ffe7a8"))
	_prompt_label.add_theme_color_override("font_outline_color", Color("171326"))
	_prompt_label.add_theme_constant_override("outline_size", 8)
	_prompt_label.add_theme_font_size_override("font_size", 20)
	_prompt_label.theme = GameState.ui_theme
	hud.add_child(_prompt_label)

	_notice_label = Label.new()
	_notice_label.anchor_left = 0.5
	_notice_label.anchor_right = 0.5
	_notice_label.offset_left = -280.0
	_notice_label.offset_top = 208.0
	_notice_label.offset_right = 280.0
	_notice_label.offset_bottom = 252.0
	_notice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_notice_label.add_theme_color_override("font_color", Color("9ef4df"))
	_notice_label.add_theme_color_override("font_outline_color", Color("171326"))
	_notice_label.add_theme_constant_override("outline_size", 8)
	_notice_label.add_theme_font_size_override("font_size", 21)
	_notice_label.theme = GameState.ui_theme
	# Notifications must remain legible over dialogue and battle layers.
	var notices := CanvasLayer.new()
	notices.name = "Notices"
	notices.layer = 90
	add_child(notices)
	_notice_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	notices.add_child(_notice_label)
	for control: Node in hud.get_children():
		if control is Control:
			control.add_to_group("camera_touch_blocker")
	get_viewport().size_changed.connect(_layout_hud)
	_refresh_hud()


func _layout_hud() -> void:
	var panel := get_node("HUD/QuestPanel") as PanelContainer
	var mobile: bool = MobileControls.is_mobile_device()
	var available: float = get_viewport().get_visible_rect().size.x - (352.0 if mobile else 298.0)
	panel.custom_minimum_size.x = minf(360.0, maxf(240.0, available))
	panel.size.x = panel.custom_minimum_size.x
	panel.reset_size()
	get_node("HUD/TravelHints").visible = not mobile and GameState.mode == GameState.Mode.EXPLORE


func _refresh_hud() -> void:
	if _map_label == null:
		return
	var fighting: bool = GameState.mode == GameState.Mode.BATTLE
	if is_instance_valid(_mini_map):
		_mini_map.visible = not fighting
	get_node("HUD/ExplorationHearts").visible = not fighting
	get_node("HUD/OpenMap").visible = not fighting
	_quest_label.visible = not fighting
	get_node("HUD/QuestPanel").visible = not fighting or not MobileControls.is_mobile_device()
	_layout_hud()
	_update_village_gate_state()
	_update_quest_markers()
	if GameState.current_map == "east_road" and is_instance_valid(_map_root):
		var sign_board := _map_root.get_node_or_null("RoadSign") as Node3D
		if sign_board != null:
			sign_board.rotation.z = 0.0 if bool(GameState.flags.get("road_sign", false)) else -0.45
	_update_mini_map_targets()
	_map_label.text = "北境遺跡" if GameState.current_map == "ruins" else "暮光村"
	if Outskirts.NAMES.has(GameState.current_map):
		_map_label.text = str(Outskirts.NAMES[GameState.current_map])
	if CryptLayout.NAMES.has(GameState.current_map):
		_map_label.text = CryptLayout.NAMES[GameState.current_map]
	if HouseCatalog.is_interior(GameState.current_map):
		_map_label.text = str(HouseCatalog.find_home(GameState.current_map).name)
	_quest_label.text = "◇  " + GameState.get_quest_text().trim_prefix("主線：").strip_edges()
	var filled_hearts := ceili(float(GameState.player_hp) / float(GameState.player_max_hp) * 5.0)
	for index in range(_heart_atlases.size()):
		_heart_atlases[index].region = Rect2(64.0 if index < filled_hearts else 0.0, 0.0, 16.0, 16.0)


func _update_mini_map_targets() -> void:
	if not is_instance_valid(_mini_map):
		return
	_mini_map.set_map(GameState.current_map)
	var main_target_position := Vector3.ZERO
	var main_target_visible := false
	var optional_target_position := Vector3.ZERO
	var optional_target_visible := false
	if GameState.current_map == "village":
		match GameState.quest_state:
			GameState.QuestState.NOT_STARTED, GameState.QuestState.READY_TO_TURN_IN:
				main_target_position = Vector3(-3.0, 0.0, 1.2)
				main_target_visible = true
			GameState.QuestState.ACTIVE:
				main_target_position = Vector3(0.0, 0.0, -19.3)
				main_target_visible = true
		optional_target_position = Vector3(6.4, 0.0, 4.2)
		optional_target_visible = not bool(GameState.flags.get("rumi_tip_seen", false))
	elif CryptLayout.is_floor(GameState.current_map):
		main_target_position = Vector3(0, 0, 11.8)
		main_target_visible = true
	elif GameState.current_map == "ashen_crypt":
		optional_target_position = Vector3(0, 0, -9)
		optional_target_visible = not bool(GameState.flags.get("crypt_cleared", false))
	elif HouseCatalog.is_interior(GameState.current_map):
		main_target_position = Vector3(0, 0, 2.95)
		main_target_visible = true
	elif Outskirts.NAMES.has(GameState.current_map):
		for id: String in Outskirts.EVENTS:
			var event: Array = Outskirts.EVENTS[id]
			if event[0] == GameState.current_map and not bool(GameState.flags.get(id, false)):
				optional_target_position = event[1]
				optional_target_visible = true
				break
	elif GameState.quest_state == GameState.QuestState.ACTIVE:
		main_target_position = Vector3(0.0, 0.0, -8.2)
		main_target_visible = not bool(GameState.flags.get("guardian_defeated", false))
	elif GameState.quest_state == GameState.QuestState.READY_TO_TURN_IN:
		main_target_position = Vector3(0.0, 0.0, 15.1)
		main_target_visible = true
	_mini_map.set_main_target(main_target_position, main_target_visible)
	_mini_map.set_optional_target(optional_target_position, optional_target_visible)


func _show_notice(message: String) -> void:
	_notice_generation += 1
	var generation := _notice_generation
	_notice_label.text = message
	await get_tree().create_timer(2.6).timeout
	if generation == _notice_generation:
		_notice_label.text = ""


func _run_playthrough_test() -> void:
	var test_save_path := "user://wanderlight_playthrough_test_%d.json" % OS.get_process_id()
	var read_tablet := "--skip-tablet" not in OS.get_cmdline_user_args()
	GameState.reset_new_game(false)
	_load_map("village", "default")
	if not _test_require(GameState.quest_state == GameState.QuestState.NOT_STARTED, "new game quest state"):
		return
	if not _test_require(is_instance_valid(_moon_lamp_light) and _moon_lamp_light.light_energy < 1.0, "moon lamp starts dim"):
		return
	if not _test_require(
		is_instance_valid(_mini_map)
		and _mini_map.get_map_id() == "village"
		and _mini_map.has_main_target()
		and _mini_map.has_optional_target(),
		"village minimap and quest targets"
	):
		return
	var elder_quest_marker := _map_root.get_node_or_null("Elder/QuestMarker") as Label3D
	var rumi_quest_marker := _map_root.get_node_or_null("Rumi/QuestMarker") as Label3D
	if not _test_require(
		elder_quest_marker != null
		and elder_quest_marker.text == "!"
		and elder_quest_marker.visible,
		"main quest giver marker"
	):
		return
	if not _test_require(
		rumi_quest_marker != null
		and rumi_quest_marker.text == "!"
		and rumi_quest_marker.visible
		and rumi_quest_marker.modulate != elder_quest_marker.modulate,
		"optional content marker color"
	):
		return

	var dialogue_camera := $CameraRig as Hd2dCameraRig
	var original_camera_distance: float = dialogue_camera._distance
	var original_camera_yaw: float = dialogue_camera._target_yaw
	_handle_interaction("rumi")
	dialogue_camera._process(0.4)
	if not _test_require(dialogue_camera._dialogue_active and dialogue_camera._dialogue_blend > 0.0 and dialogue_camera._dialogue_blend < 1.0, "dialogue camera eases into two-person shot"):
		return
	if not _test_require(dialogue_ui.is_open() and GameState.mode == GameState.Mode.DIALOGUE, "village story dialogue"):
		return
	var village_dialogue_safety := 0
	while dialogue_ui.is_open() and village_dialogue_safety < 6:
		dialogue_ui.advance()
		village_dialogue_safety += 1
	if not _test_require(not dialogue_camera._dialogue_active, "dialogue completion releases cinematic camera"):
		return
	dialogue_camera._process(1.0)
	if not _test_require(is_zero_approx(dialogue_camera._dialogue_blend) and is_equal_approx(dialogue_camera._distance, original_camera_distance) and is_equal_approx(dialogue_camera._target_yaw, original_camera_yaw), "dialogue restores exploration zoom and angle"):
		return
	if not _test_require(not rumi_quest_marker.visible, "optional marker clears after dialogue"):
		return
	if not _test_require(not _mini_map.has_optional_target(), "optional minimap target clears after dialogue"):
		return

	_handle_interaction("portal_to_ruins")
	if not _test_require(GameState.current_map == "village" and dialogue_ui.is_open(), "north gate requires elder's moon seal"):
		return
	while dialogue_ui.is_open():
		dialogue_ui.advance()
	_handle_interaction("elder")
	_handle_interaction("rumi")
	if not _test_require(GameState.quest_state == GameState.QuestState.NOT_STARTED and str(dialogue_ui._lines[0].speaker) == "長老・艾爾", "dialogue cannot be replaced by another interaction"):
		return
	while dialogue_ui.is_open():
		dialogue_ui.advance()
	if not _test_require(GameState.quest_state == GameState.QuestState.ACTIVE, "quest acceptance"):
		return
	if not _test_require(not elder_quest_marker.visible, "main quest marker clears while objective is active"):
		return
	if not _test_require(_village_gate_portal.prompt_text.is_empty(), "open portal has no interaction prompt"):
		return

	_village_gate_portal.body_entered.emit(player)
	await get_tree().process_frame
	await get_tree().process_frame
	if not _test_require(GameState.current_map == "ruins" and _map_root.name == "Map_Ruins", "automatic portal transition to ruins"):
		return
	if not _test_require(_mini_map.get_map_id() == "ruins" and _mini_map.has_main_target(), "ruins minimap and quest target"):
		return
	var guardian_quest_marker := _map_root.get_node_or_null("Guardian/QuestMarker") as Label3D
	if not _test_require(
		guardian_quest_marker != null
		and guardian_quest_marker.text == "!"
		and guardian_quest_marker.visible,
		"main quest objective marker"
	):
		return

	if read_tablet:
		_handle_interaction("ruin_tablet")
		while dialogue_ui.is_open():
			dialogue_ui.advance()
	if not _test_require(bool(GameState.flags.get("ruin_tablet_read", false)) == read_tablet, "optional ruin lore flag"):
		return
	# Full-health visitors still need the same preparation and combat tutorial.
	_handle_interaction("moon_spring")
	if not _test_require(dialogue_ui._lines.size() == 5 and str(dialogue_ui._lines[2].text).contains("確認"), "full-health spring battle tutorial"):
		return
	while dialogue_ui.is_open():
		dialogue_ui.advance()

	GameState.player_hp = 22
	GameState.player_mp = 0
	_handle_interaction("moon_spring")
	if not _test_require(GameState.player_hp == GameState.player_max_hp and GameState.player_mp == GameState.player_max_mp, "moon spring recovery"):
		return
	var spring_dialogue_safety := 0
	while dialogue_ui.is_open() and spring_dialogue_safety < 6:
		dialogue_ui.advance()
		spring_dialogue_safety += 1

	GameState.player_hp = 1
	player.global_position = Vector3(0, 0.1, -5.5)
	_start_guardian_battle()
	battle_ui.confirm_preparation()
	for ally: Dictionary in GameState.battle_session.actors:
		if int(ally.team) == 0:
			ally.hp = 1
	battle_ui.set_physics_process(false)
	for step_index: int in range(3600):
		battle_ui.advance_combat(1.0 / 60.0, Vector2.ZERO)
		if battle_ui.is_resolved():
			break
	if not _test_require(battle_ui.is_resolved() and not battle_ui.did_player_win(), "battle defeat state"):
		return
	battle_ui._finish_battle()
	await get_tree().process_frame
	while dialogue_ui.is_open():
		dialogue_ui.advance()
	await get_tree().process_frame
	await get_tree().process_frame
	if not _test_require(GameState.player_hp == GameState.player_max_hp and GameState.current_map == "village", "battle defeat recovery"):
		return

	if not _test_require(GameState.quest_state == GameState.QuestState.ACTIVE and not GameState.flags.get("guardian_defeated", false) and not GameState.inventory.has("moon_shard"), "defeat preserves trial for retry"):
		return
	_on_portal_body_entered(player, "portal_to_ruins")
	await get_tree().process_frame
	await get_tree().process_frame
	if not _test_require(GameState.current_map == "ruins" and _map_root.has_node("Guardian"), "return to trial after defeat"):
		return

	# Checkpoint restoration must retain the optional route as well as the main quest.
	GameState.remember_player_position(player.global_position)
	if not _test_require(GameState.save_game(test_save_path, false), "pre-trial checkpoint write"):
		return
	GameState.flags.erase("ruin_tablet_read")
	if not _test_require(GameState.load_game(test_save_path, false), "pre-trial checkpoint load"):
		return
	await get_tree().process_frame
	await get_tree().process_frame
	player.global_position = Vector3(0, 0.1, -5.5)
	_handle_interaction("guardian")
	if not _test_require(dialogue_ui.is_open() and str(dialogue_ui._lines[0].text).contains("誓言") == read_tablet, "guardian acknowledges optional lore route"):
		return
	while dialogue_ui.is_open():
		dialogue_ui.advance()
	if not _test_require(battle_ui._preparing and GameState.battle_session.paused, "battle preparation pauses combat"):
		return
	battle_ui.confirm_preparation()
	if not _test_require(battle_ui.is_active() and GameState.mode == GameState.Mode.BATTLE, "battle start"):
		return
	battle_ui.set_physics_process(false)
	for step_index: int in range(7200):
		if battle_ui.is_resolved():
			break
		var combat: RefCounted = GameState.battle_session
		var controlled: int = combat.controlled
		var target: int = combat.nearest_enemy(controlled)
		var direction := Vector2.ZERO
		if target >= 0:
			var difference: Vector2 = combat.actors[target].position - combat.actors[controlled].position
			direction = difference.normalized()
			combat.actors[controlled].facing = direction
			if difference.length() < 1.6:
				battle_ui.choose_action("skill")
				battle_ui.choose_action("attack")
				direction = Vector2.ZERO
		battle_ui.advance_combat(1.0 / 60.0, direction)
	if not _test_require(battle_ui.is_resolved() and battle_ui.did_player_win(), "action battle spatial victory"):
		return
	if not _test_require(bool(GameState.flags.get("guardian_defeated", false)), "battle victory flag"):
		return
	if not _test_require(GameState.quest_state == GameState.QuestState.READY_TO_TURN_IN and int(GameState.inventory.get("moon_shard", 0)) == 1, "battle quest reward"):
		return

	battle_ui._finish_battle()
	await get_tree().process_frame
	var dialogue_safety := 0
	while dialogue_ui.is_open() and dialogue_safety < 10:
		dialogue_ui.advance()
		dialogue_safety += 1
	if not _test_require(GameState.mode == GameState.Mode.EXPLORE, "dialogue returns to exploration"):
		return

	_on_portal_body_entered(player, "portal_to_village")
	await get_tree().process_frame
	await get_tree().process_frame
	if not _test_require(GameState.current_map == "village", "automatic portal transition to village"):
		return
	if not _test_require(_mini_map.get_map_id() == "village" and _mini_map.has_main_target(), "minimap returns to village target"):
		return
	elder_quest_marker = _map_root.get_node_or_null("Elder/QuestMarker") as Label3D
	if not _test_require(elder_quest_marker != null and elder_quest_marker.visible, "main quest turn-in marker"):
		return
	_talk_to_elder()
	dialogue_ui.advance()
	if not _test_require(GameState.quest_state == GameState.QuestState.READY_TO_TURN_IN, "turn-in waits for dialogue completion"):
		return
	dialogue_ui.advance()
	var ending_acknowledges_tablet := false
	for line: Dictionary in dialogue_ui._lines:
		if str(line.text).contains("刻意抹去"):
			ending_acknowledges_tablet = true
	if not _test_require(ending_acknowledges_tablet == read_tablet, "ending acknowledges optional lore route"):
		return
	dialogue_safety = 0
	while dialogue_ui.is_open() and dialogue_safety < 12:
		dialogue_ui.advance()
		dialogue_safety += 1
	if not _test_require(GameState.quest_state == GameState.QuestState.COMPLETE and not GameState.inventory.has("moon_shard"), "quest turn-in"):
		return
	if not _test_require(not elder_quest_marker.visible, "main quest marker clears after completion"):
		return
	if not _test_require(not _mini_map.has_main_target(), "minimap target clears after quest completion"):
		return
	if not _test_require(is_instance_valid(_moon_lamp_light) and _moon_lamp_light.light_energy > 3.0, "moon lamp restored"):
		return

	GameState.remember_player_position(Vector3(2.25, 0.1, 3.5))
	if not _test_require(GameState.save_game(test_save_path, false), "save write"):
		return
	GameState.quest_state = GameState.QuestState.NOT_STARTED
	GameState.player_hp = 1
	GameState.current_map = "ruins"
	if not _test_require(GameState.load_game(test_save_path, false), "save load"):
		return
	await get_tree().process_frame
	await get_tree().process_frame
	if not _test_require(
		GameState.quest_state == GameState.QuestState.COMPLETE
		and GameState.player_hp == GameState.player_max_hp
		and GameState.current_map == "village"
		and GameState.saved_position.is_equal_approx(Vector3(2.25, 0.1, 3.5))
		and bool(GameState.flags.get("ruin_tablet_read", false)) == read_tablet,
		"save data restoration"
	):
		return
	DirAccess.remove_absolute(ProjectSettings.globalize_path(test_save_path))
	print("PLAYTHROUGH_TEST_PASS dialogue quest maps save battle")
	get_tree().quit(0)


func _test_wait_for_battle(resolved: bool) -> bool:
	var deadline := Time.get_ticks_msec() + 10000
	while Time.get_ticks_msec() < deadline:
		if battle_ui.is_resolved() or (not resolved and battle_ui.can_accept_action()):
			return true
		await get_tree().process_frame
	return _test_require(false, "battle resolution timeout" if resolved else "battle action readiness timeout")


func _test_require(condition: bool, label: String) -> bool:
	if condition:
		print("PLAYTHROUGH_TEST_OK %s" % label)
		return true
	push_error("PLAYTHROUGH_TEST_FAIL %s" % label)
	get_tree().quit(1)
	return false


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
