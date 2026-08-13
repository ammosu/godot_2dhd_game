class_name PrototypeWorld
extends Node3D

const PALETTE := {
	"stone": Color("686176"),
	"stone_dark": Color("343246"),
	"path": Color("b99069"),
	"grass": Color("405c55"),
	"water": Color("31556d"),
	"gold": Color("d8a45d"),
	"crystal": Color("75d5ce"),
	"ruin": Color("443d55"),
}

@onready var player: Wanderer = $Player
@onready var dialogue_ui: DialogueUI = $DialogueUI
@onready var battle_ui: BattleUI = $BattleUI

var _map_root: Node3D
var _environment: Environment
var _animated_sprites: Array[Sprite3D] = []
var _ambient_time: float = 0.0

var _map_label: Label
var _quest_label: Label
var _prompt_label: Label
var _notice_label: Label
var _heart_atlases: Array[AtlasTexture] = []
var _notice_generation: int = 0
var _test_mode: bool = false


func _ready() -> void:
	_test_mode = "--playthrough-test" in OS.get_cmdline_user_args()
	_build_environment()
	_build_post_process()
	_build_hud()
	GameState.map_change_requested.connect(_on_map_change_requested)
	GameState.state_changed.connect(_refresh_hud)
	GameState.notification_requested.connect(_show_notice)
	battle_ui.battle_finished.connect(_on_battle_finished)
	_load_map(GameState.current_map, GameState.spawn_id)
	if _test_mode:
		GameState.flags["intro_seen"] = true
		_run_playthrough_test.call_deferred()
	elif "--battle-preview" in OS.get_cmdline_user_args():
		GameState.flags["intro_seen"] = true
		_load_map("ruins", "from_village")
		_start_guardian_battle.call_deferred()
	elif not bool(GameState.flags.get("intro_seen", false)):
		GameState.flags["intro_seen"] = true
		_show_intro.call_deferred()
	print("Wanderlight playable slice loaded with Godot %s" % Engine.get_version_info().get("string", "unknown"))


func _process(delta: float) -> void:
	_ambient_time += delta
	var animation_frame := int(floor(_ambient_time * 2.5)) % 2
	for animated_sprite in _animated_sprites:
		if is_instance_valid(animated_sprite):
			animated_sprite.frame = animation_frame
	if _prompt_label != null:
		var prompt := player.get_interaction_prompt() if GameState.mode == GameState.Mode.EXPLORE else ""
		_prompt_label.text = "Space：%s" % prompt if not prompt.is_empty() else ""


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


func _show_intro() -> void:
	dialogue_ui.show_dialogue([
		{"speaker": "旁白", "text": "月光逐漸從暮光村消失，北境的古老封印也開始鬆動。"},
		{"speaker": "旁白", "text": "先與廣場左側的長老交談。靠近可互動目標後按下 Space。"},
	])


func _on_map_change_requested(map_id: String, spawn_id: String) -> void:
	call_deferred("_load_map", map_id, spawn_id)


func _load_map(map_id: String, spawn_id: String) -> void:
	if _map_root != null and is_instance_valid(_map_root):
		_map_root.free()
	_map_root = Node3D.new()
	_map_root.name = "Map_%s" % map_id.capitalize()
	add_child(_map_root)
	_animated_sprites.clear()
	GameState.current_map = map_id
	GameState.spawn_id = spawn_id

	match map_id:
		"ruins":
			_build_ruins()
			_environment.background_color = Color("100e1d")
			_environment.fog_light_color = Color("56506c")
		_:
			GameState.current_map = "village"
			_build_village()
			_environment.background_color = Color("111425")
			_environment.fog_light_color = Color("70758d")

	var target_position := _get_spawn_position(GameState.current_map, spawn_id)
	if spawn_id == "saved_position" and GameState.has_saved_position:
		target_position = GameState.saved_position
	player.global_position = target_position
	player.velocity = Vector3.ZERO
	_refresh_hud()


func _get_spawn_position(map_id: String, spawn_id: String) -> Vector3:
	if map_id == "ruins":
		match spawn_id:
			"after_battle":
				return Vector3(0.0, 0.1, 1.8)
			_:
				return Vector3(0.0, 0.1, 5.3)
	match spawn_id:
		"from_ruins":
			return Vector3(0.0, 0.1, -5.1)
		_:
			return Vector3(0.0, 0.1, 2.0)


func _build_village() -> void:
	_add_box("Ground", Vector3(0.0, -0.35, 0.0), Vector3(22.0, 0.7, 18.0), PALETTE.grass, true)
	_add_box("CentralPlaza", Vector3(0.0, -0.02, 0.0), Vector3(7.0, 0.12, 6.5), PALETTE.stone, true)
	_add_box("WaterNorth", Vector3(0.0, -0.23, -6.3), Vector3(8.5, 0.18, 3.6), PALETTE.water, false, 0.18)

	for z_index in range(-7, 8):
		_add_box("Path_%02d" % (z_index + 7), Vector3(0.0, 0.025, float(z_index)), Vector3(1.45, 0.08, 0.82), PALETTE.path, false)
	for x_position in [-8.5, 8.5]:
		_add_box("BoundaryWall", Vector3(x_position, 0.75, 0.0), Vector3(0.7, 1.8, 17.0), PALETTE.stone_dark, true)
	for z_position in [-8.2, 8.2]:
		_add_box("BoundaryWall", Vector3(0.0, 0.75, z_position), Vector3(17.0, 1.8, 0.7), PALETTE.stone_dark, true)

	for column_position in [Vector3(-3.1, 0.0, -2.7), Vector3(3.1, 0.0, -2.7), Vector3(-3.1, 0.0, 2.7), Vector3(3.1, 0.0, 2.7)]:
		_add_column(column_position)
	for tree_position in [Vector3(-6.0, 0.0, -4.5), Vector3(6.0, 0.0, -4.5), Vector3(-6.2, 0.0, 4.8), Vector3(6.2, 0.0, 4.8)]:
		_add_tree(tree_position)
	for lamp_position in [Vector3(-1.65, 0.0, -3.5), Vector3(1.65, 0.0, -3.5), Vector3(-1.65, 0.0, 3.5), Vector3(1.65, 0.0, 3.5)]:
		_add_lamp(lamp_position)

	_add_crystal(Vector3(-5.0, 0.0, 0.2), 1.1)
	_add_crystal(Vector3(5.2, 0.0, 0.8), 0.85)
	_add_pixel_prop("res://assets/third_party/ninja_adventure/props/crate.png", Vector3(-2.55, 0.42, -1.45), 0.056, "PixelCrate")
	_add_pixel_prop("res://assets/third_party/ninja_adventure/props/crate.png", Vector3(-2.1, 0.42, -1.65), 0.056, "PixelCrate")
	_add_pixel_prop("res://assets/third_party/ninja_adventure/props/pot.png", Vector3(2.55, 0.43, -1.6), 0.054, "PixelPot")
	for grass_position in [Vector3(-5.5, 0.35, 2.4), Vector3(-5.1, 0.35, 2.0), Vector3(5.7, 0.35, -2.1), Vector3(5.3, 0.35, -2.45)]:
		_add_pixel_prop("res://assets/third_party/ninja_adventure/props/grass.png", grass_position, 0.045, "PixelGrass")
	_add_pixel_prop("res://assets/third_party/ninja_adventure/characters/pig.png", Vector3(4.4, 0.46, 4.1), 0.058, "PixelPig", 2, true)

	_add_actor_interactable("elder", "與長老交談", Vector3(-2.0, 0.0, 0.9), "res://assets/characters/wanderer.svg", 0.026, Color("e4b7ff"))
	_add_portal("portal_to_ruins", "前往北境遺跡", Vector3(0.0, 0.0, -6.0), Color("86d9ff"))


func _build_ruins() -> void:
	_add_box("RuinGround", Vector3(0.0, -0.35, 0.0), Vector3(18.0, 0.7, 18.0), Color("292b3e"), true)
	_add_box("RuinCourt", Vector3(0.0, -0.02, -0.6), Vector3(8.5, 0.12, 8.5), PALETTE.ruin, true)
	for z_index in range(-6, 7):
		_add_box("MoonPath", Vector3(0.0, 0.025, float(z_index)), Vector3(1.35, 0.08, 0.82), Color("786c8d"), false)
	for x_position in [-7.8, 7.8]:
		_add_box("RuinBoundary", Vector3(x_position, 0.8, 0.0), Vector3(0.8, 2.0, 16.5), Color("242235"), true)
	for z_position in [-7.8, 7.8]:
		_add_box("RuinBoundary", Vector3(0.0, 0.8, z_position), Vector3(16.5, 2.0, 0.8), Color("242235"), true)
	for column_position in [Vector3(-3.7, 0.0, -3.6), Vector3(3.7, 0.0, -3.6), Vector3(-3.7, 0.0, 2.2), Vector3(3.7, 0.0, 2.2)]:
		_add_column(column_position)
	for crystal_data in [[Vector3(-5.5, 0.0, -1.2), 1.3], [Vector3(5.3, 0.0, -2.0), 1.0], [Vector3(-4.8, 0.0, 4.6), 0.75]]:
		_add_crystal(crystal_data[0], crystal_data[1])
	for rubble_position in [Vector3(-2.6, 0.42, 4.0), Vector3(2.9, 0.42, 3.6), Vector3(-5.2, 0.42, -5.1)]:
		_add_pixel_prop("res://assets/third_party/ninja_adventure/props/crate.png", rubble_position, 0.052, "RuinSupply")

	_add_portal("portal_to_village", "返回暮光村", Vector3(0.0, 0.0, 6.1), Color("efb56d"))
	if not bool(GameState.flags.get("guardian_defeated", false)):
		_add_actor_interactable(
			"guardian",
			"挑戰遺跡守衛",
			Vector3(0.0, 0.0, -1.2),
			"res://assets/third_party/ninja_adventure/characters/ninja_blue.png",
			0.082,
			Color("ca8cff"),
			true
		)
	else:
		_add_crystal(Vector3(0.0, 0.0, -1.2), 0.65)


func _handle_interaction(interaction_id: String) -> void:
	match interaction_id:
		"elder":
			_talk_to_elder()
		"portal_to_ruins":
			if GameState.quest_state == GameState.QuestState.NOT_STARTED:
				dialogue_ui.show_dialogue([{"speaker": "古老門扉", "text": "門扉沒有回應。也許應該先詢問村莊長老。"}])
			else:
				GameState.request_map("ruins", "from_village")
		"portal_to_village":
			GameState.request_map("village", "from_ruins")
		"guardian":
			dialogue_ui.show_dialogue([
				{"speaker": "遺跡守衛", "text": "月光碎片只會交給能承受試煉之人。"},
				{"speaker": "旅人", "text": "那就開始吧。"},
			], _start_guardian_battle)


func _talk_to_elder() -> void:
	match GameState.quest_state:
		GameState.QuestState.NOT_STARTED:
			dialogue_ui.show_dialogue([
				{"speaker": "長老・艾爾", "text": "旅人，村中的月燈正在熄滅。只有北境遺跡的月光碎片能重新點亮它。"},
				{"speaker": "長老・艾爾", "text": "穿過北方的藍色門扉，擊敗守護碎片的古老守衛。"},
				{"speaker": "旅人", "text": "我會把月光帶回來。"},
			], GameState.start_quest)
		GameState.QuestState.ACTIVE:
			dialogue_ui.show_dialogue([{"speaker": "長老・艾爾", "text": "北方門扉已經開啟。月光碎片就在遺跡深處。"}])
		GameState.QuestState.READY_TO_TURN_IN:
			dialogue_ui.show_dialogue([
				{"speaker": "旅人", "text": "我帶回月光碎片了。"},
				{"speaker": "長老・艾爾", "text": "太好了。暮光村會記住你的勇氣。"},
			], _complete_main_quest)
		GameState.QuestState.COMPLETE:
			dialogue_ui.show_dialogue([{"speaker": "長老・艾爾", "text": "月燈再次閃耀。謝謝你，暮光村的朋友。"}])


func _complete_main_quest() -> void:
	GameState.complete_quest()
	GameState.remember_player_position(player.global_position)
	if not _test_mode:
		GameState.save_game(GameState.SAVE_PATH, false)
	dialogue_ui.show_dialogue([
		{"speaker": "旁白", "text": "主線任務完成！你仍可自由探索兩張地圖，或按 F9 讀取存檔。"},
	])


func _start_guardian_battle() -> void:
	battle_ui.start_battle({
		"name": "遺跡守衛",
		"max_hp": 64,
		"attack": 14,
		"defense": 3,
	})


func _on_battle_finished(victory: bool) -> void:
	if victory:
		_load_map("ruins", "after_battle")
		GameState.remember_player_position(player.global_position)
		if not _test_mode:
			GameState.save_game(GameState.SAVE_PATH, false)
		dialogue_ui.show_dialogue([
			{"speaker": "旁白", "text": "守衛消散後，一枚溫暖的月光碎片落入你手中。"},
			{"speaker": "旅人", "text": "該回村莊找長老了。"},
		])
	else:
		GameState.restore_after_defeat()
		dialogue_ui.show_dialogue([
			{"speaker": "旁白", "text": "村民在遺跡入口發現了你，並將你送回暮光村。"},
		], func() -> void: GameState.request_map("village", "default"))


func _add_actor_interactable(interaction_id: String, prompt: String, world_position: Vector3, texture_path: String, pixel_size: float, tint: Color, atlas_character: bool = false) -> void:
	var actor := Interactable3D.new()
	actor.name = interaction_id.capitalize()
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

	var sprite := Sprite3D.new()
	sprite.position.y = 0.75
	sprite.texture = load(texture_path) as Texture2D
	sprite.pixel_size = pixel_size
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.modulate = tint
	if atlas_character:
		sprite.hframes = 4
		sprite.vframes = 7
	actor.add_child(sprite)

	var marker := Label3D.new()
	marker.text = "◆"
	marker.position.y = 1.72
	marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	marker.font_size = 48
	marker.outline_size = 10
	marker.modulate = Color("ffe08a")
	actor.add_child(marker)


func _add_portal(interaction_id: String, prompt: String, world_position: Vector3, color: Color) -> void:
	var portal := Interactable3D.new()
	portal.name = interaction_id.capitalize()
	portal.interaction_id = interaction_id
	portal.prompt_text = prompt
	portal.position = world_position
	portal.collision_layer = 8
	portal.collision_mask = 0
	portal.activated.connect(_handle_interaction)
	_map_root.add_child(portal)

	var shape_node := CollisionShape3D.new()
	shape_node.position.y = 0.8
	var shape := SphereShape3D.new()
	shape.radius = 1.1
	shape_node.shape = shape
	portal.add_child(shape_node)

	var mesh_instance := MeshInstance3D.new()
	mesh_instance.position.y = 0.8
	var mesh := PrismMesh.new()
	mesh.size = Vector3(0.7, 1.6, 0.35)
	mesh_instance.mesh = mesh
	mesh_instance.material_override = _make_material(color, 0.15, 0.0, color, 3.4)
	portal.add_child(mesh_instance)

	var light := OmniLight3D.new()
	light.position.y = 0.8
	light.light_color = color
	light.light_energy = 2.6
	light.omni_range = 4.0
	portal.add_child(light)


func _add_box(node_name: String, world_position: Vector3, size: Vector3, color: Color, collision: bool, metallic: float = 0.0) -> void:
	var root: Node3D = StaticBody3D.new() if collision else Node3D.new()
	root.name = node_name
	root.position = world_position
	_map_root.add_child(root)
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.material_override = _make_material(color, 0.88, metallic)
	root.add_child(mesh_instance)
	if collision:
		var collision_shape := CollisionShape3D.new()
		var box_shape := BoxShape3D.new()
		box_shape.size = size
		collision_shape.shape = box_shape
		root.add_child(collision_shape)


func _add_column(world_position: Vector3) -> void:
	var root := StaticBody3D.new()
	root.name = "Column"
	root.position = world_position
	_map_root.add_child(root)
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.position.y = 1.0
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.42
	mesh.bottom_radius = 0.55
	mesh.height = 2.0
	mesh.radial_segments = 8
	mesh_instance.mesh = mesh
	mesh_instance.material_override = _make_material(PALETTE.stone, 0.9)
	root.add_child(mesh_instance)
	var collision_shape := CollisionShape3D.new()
	collision_shape.position.y = 1.0
	var shape := CylinderShape3D.new()
	shape.radius = 0.5
	shape.height = 2.0
	collision_shape.shape = shape
	root.add_child(collision_shape)


func _add_tree(world_position: Vector3) -> void:
	var root := Node3D.new()
	root.name = "LowPolyTree"
	root.position = world_position
	_map_root.add_child(root)
	var trunk := MeshInstance3D.new()
	trunk.position.y = 0.85
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.18
	trunk_mesh.bottom_radius = 0.26
	trunk_mesh.height = 1.7
	trunk_mesh.radial_segments = 6
	trunk.mesh = trunk_mesh
	trunk.material_override = _make_material(Color("594452"), 1.0)
	root.add_child(trunk)
	for layer_index in range(3):
		var crown := MeshInstance3D.new()
		crown.position.y = 1.55 + float(layer_index) * 0.52
		var crown_mesh := SphereMesh.new()
		crown_mesh.radius = 0.9 - float(layer_index) * 0.13
		crown_mesh.height = crown_mesh.radius * 1.45
		crown_mesh.radial_segments = 8
		crown_mesh.rings = 4
		crown.mesh = crown_mesh
		crown.material_override = _make_material(Color("31554f").lightened(float(layer_index) * 0.06), 1.0)
		root.add_child(crown)


func _add_lamp(world_position: Vector3) -> void:
	var root := Node3D.new()
	root.name = "Lantern"
	root.position = world_position
	_map_root.add_child(root)
	var post := MeshInstance3D.new()
	post.position.y = 0.65
	var post_mesh := CylinderMesh.new()
	post_mesh.top_radius = 0.055
	post_mesh.bottom_radius = 0.08
	post_mesh.height = 1.3
	post_mesh.radial_segments = 6
	post.mesh = post_mesh
	post.material_override = _make_material(PALETTE.stone_dark, 0.8, 0.45)
	root.add_child(post)
	var bulb := MeshInstance3D.new()
	bulb.position.y = 1.42
	var bulb_mesh := SphereMesh.new()
	bulb_mesh.radius = 0.13
	bulb_mesh.height = 0.26
	bulb_mesh.radial_segments = 8
	bulb_mesh.rings = 4
	bulb.mesh = bulb_mesh
	bulb.material_override = _make_material(Color("f8c675"), 0.25, 0.0, Color("f8a94d"), 3.0)
	root.add_child(bulb)
	var light := OmniLight3D.new()
	light.position.y = 1.42
	light.light_color = Color("ffb968")
	light.light_energy = 3.2
	light.omni_range = 4.5
	root.add_child(light)


func _add_crystal(world_position: Vector3, scale_factor: float) -> void:
	var crystal := MeshInstance3D.new()
	crystal.name = "GlowCrystal"
	crystal.position = world_position + Vector3.UP * (0.58 * scale_factor)
	crystal.rotation_degrees = Vector3(0.0, 0.0, 8.0)
	var mesh := PrismMesh.new()
	mesh.size = Vector3(0.5, 1.2, 0.5) * scale_factor
	crystal.mesh = mesh
	crystal.material_override = _make_material(PALETTE.crystal, 0.15, 0.0, PALETTE.crystal, 2.4)
	_map_root.add_child(crystal)


func _add_pixel_prop(texture_path: String, world_position: Vector3, pixel_size: float, node_name: String, horizontal_frames: int = 1, animated: bool = false) -> void:
	var sprite := Sprite3D.new()
	sprite.name = node_name
	sprite.position = world_position
	sprite.texture = load(texture_path) as Texture2D
	sprite.pixel_size = pixel_size
	sprite.hframes = horizontal_frames
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	_map_root.add_child(sprite)
	if animated:
		_animated_sprites.append(sprite)


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
	_environment.ambient_light_color = Color("8290b5")
	_environment.ambient_light_energy = 0.62
	_environment.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	_environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	_environment.glow_enabled = true
	_environment.glow_intensity = 0.75
	_environment.glow_bloom = 0.12
	_environment.fog_enabled = true
	_environment.fog_light_color = Color("70758d")
	_environment.fog_light_energy = 0.55
	_environment.fog_density = 0.009
	_environment.fog_height = -1.0
	_environment.fog_height_density = 0.18
	world_environment.environment = _environment
	add_child(world_environment)
	var sun := DirectionalLight3D.new()
	sun.name = "Moonlight"
	sun.rotation_degrees = Vector3(-52.0, -34.0, 0.0)
	sun.light_color = Color("ffe1bc")
	sun.light_energy = 1.35
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
	panel.custom_minimum_size = Vector2(530.0, 0.0)
	hud.add_child(panel)
	var panel_style := StyleBoxTexture.new()
	panel_style.texture = load("res://assets/third_party/ninja_adventure/ui/panel.png") as Texture2D
	panel_style.modulate_color = Color(0.26, 0.20, 0.34, 0.96)
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		panel_style.set_texture_margin(side, 5.0)
		panel_style.set_content_margin(side, 16.0)
	panel.add_theme_stylebox_override("panel", panel_style)
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 5)
	panel.add_child(info)
	_map_label = Label.new()
	_map_label.add_theme_color_override("font_color", Color("f3c77f"))
	_map_label.add_theme_font_size_override("font_size", 18)
	info.add_child(_map_label)
	_quest_label = Label.new()
	_quest_label.add_theme_color_override("font_color", Color("fff2d2"))
	_quest_label.add_theme_font_size_override("font_size", 17)
	info.add_child(_quest_label)
	var controls := Label.new()
	controls.text = "WASD 移動｜Space 互動｜Q/E 鏡頭｜F5 存檔｜F9 讀檔"
	controls.add_theme_color_override("font_color", Color("b8a9bc"))
	info.add_child(controls)

	var heart_row := HBoxContainer.new()
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

	_prompt_label = Label.new()
	_prompt_label.anchor_left = 0.5
	_prompt_label.anchor_top = 1.0
	_prompt_label.anchor_right = 0.5
	_prompt_label.anchor_bottom = 1.0
	_prompt_label.offset_left = -260.0
	_prompt_label.offset_top = -72.0
	_prompt_label.offset_right = 260.0
	_prompt_label.offset_bottom = -26.0
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_prompt_label.add_theme_color_override("font_color", Color("ffe7a8"))
	_prompt_label.add_theme_color_override("font_outline_color", Color("171326"))
	_prompt_label.add_theme_constant_override("outline_size", 8)
	_prompt_label.add_theme_font_size_override("font_size", 20)
	hud.add_child(_prompt_label)

	_notice_label = Label.new()
	_notice_label.anchor_left = 0.5
	_notice_label.anchor_right = 0.5
	_notice_label.offset_left = -280.0
	_notice_label.offset_top = 116.0
	_notice_label.offset_right = 280.0
	_notice_label.offset_bottom = 160.0
	_notice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_notice_label.add_theme_color_override("font_color", Color("9ef4df"))
	_notice_label.add_theme_color_override("font_outline_color", Color("171326"))
	_notice_label.add_theme_constant_override("outline_size", 8)
	_notice_label.add_theme_font_size_override("font_size", 21)
	hud.add_child(_notice_label)
	_refresh_hud()


func _refresh_hud() -> void:
	if _map_label == null:
		return
	_map_label.text = "WANDERLIGHT  /  %s" % ("北境遺跡" if GameState.current_map == "ruins" else "暮光村")
	_quest_label.text = GameState.get_quest_text()
	var filled_hearts := ceili(float(GameState.player_hp) / float(GameState.player_max_hp) * 5.0)
	for index in range(_heart_atlases.size()):
		_heart_atlases[index].region = Rect2(64.0 if index < filled_hearts else 0.0, 0.0, 16.0, 16.0)


func _show_notice(message: String) -> void:
	_notice_generation += 1
	var generation := _notice_generation
	_notice_label.text = message
	await get_tree().create_timer(2.6).timeout
	if generation == _notice_generation:
		_notice_label.text = ""


func _run_playthrough_test() -> void:
	const TEST_SAVE_PATH := "user://wanderlight_playthrough_test.json"
	GameState.reset_new_game(false)
	_load_map("village", "default")
	if not _test_require(GameState.quest_state == GameState.QuestState.NOT_STARTED, "new game quest state"):
		return

	GameState.start_quest()
	if not _test_require(GameState.quest_state == GameState.QuestState.ACTIVE, "quest acceptance"):
		return

	GameState.request_map("ruins", "from_village")
	await get_tree().process_frame
	await get_tree().process_frame
	if not _test_require(GameState.current_map == "ruins" and _map_root.name == "Map_Ruins", "map transition to ruins"):
		return

	_start_guardian_battle()
	if not _test_require(battle_ui.is_active() and GameState.mode == GameState.Mode.BATTLE, "battle start"):
		return
	for turn_index in range(3):
		battle_ui.choose_action("skill")
		await get_tree().create_timer(0.65).timeout
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

	GameState.request_map("village", "from_ruins")
	await get_tree().process_frame
	await get_tree().process_frame
	if not _test_require(GameState.current_map == "village", "map transition to village"):
		return
	_talk_to_elder()
	dialogue_safety = 0
	while dialogue_ui.is_open() and dialogue_safety < 12:
		dialogue_ui.advance()
		dialogue_safety += 1
	if not _test_require(GameState.quest_state == GameState.QuestState.COMPLETE and not GameState.inventory.has("moon_shard"), "quest turn-in"):
		return

	GameState.player_hp = 1
	_start_guardian_battle()
	battle_ui.choose_action("attack")
	await get_tree().create_timer(0.65).timeout
	if not _test_require(battle_ui.is_resolved() and not battle_ui.did_player_win(), "battle defeat state"):
		return
	battle_ui._finish_battle()
	await get_tree().process_frame
	dialogue_safety = 0
	while dialogue_ui.is_open() and dialogue_safety < 8:
		dialogue_ui.advance()
		dialogue_safety += 1
	await get_tree().process_frame
	await get_tree().process_frame
	if not _test_require(GameState.player_hp == GameState.player_max_hp and GameState.current_map == "village", "battle defeat recovery"):
		return

	GameState.remember_player_position(Vector3(2.25, 0.1, 3.5))
	if not _test_require(GameState.save_game(TEST_SAVE_PATH, false), "save write"):
		return
	GameState.quest_state = GameState.QuestState.NOT_STARTED
	GameState.player_hp = 1
	GameState.current_map = "ruins"
	if not _test_require(GameState.load_game(TEST_SAVE_PATH, false), "save load"):
		return
	await get_tree().process_frame
	await get_tree().process_frame
	if not _test_require(
		GameState.quest_state == GameState.QuestState.COMPLETE
		and GameState.player_hp == GameState.player_max_hp
		and GameState.current_map == "village"
		and GameState.saved_position.is_equal_approx(Vector3(2.25, 0.1, 3.5)),
		"save data restoration"
	):
		return
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE_PATH))
	print("PLAYTHROUGH_TEST_PASS dialogue quest maps save battle")
	get_tree().quit(0)


func _test_require(condition: bool, label: String) -> bool:
	if condition:
		print("PLAYTHROUGH_TEST_OK %s" % label)
		return true
	push_error("PLAYTHROUGH_TEST_FAIL %s" % label)
	get_tree().quit(1)
	return false
