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
}

var _animated_sprites: Array[Sprite3D] = []
var _ambient_time: float = 0.0


func _ready() -> void:
	_build_environment()
	_build_level()
	_build_post_process()
	_build_hud()
	print("Wanderlight prototype loaded with Godot %s" % Engine.get_version_info().get("string", "unknown"))


func _process(delta: float) -> void:
	_ambient_time += delta
	var animation_frame := int(floor(_ambient_time * 2.5)) % 2
	for animated_sprite in _animated_sprites:
		animated_sprite.frame = animation_frame


func _build_environment() -> void:
	var world_environment := WorldEnvironment.new()
	world_environment.name = "WorldEnvironment"
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("111425")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("8290b5")
	environment.ambient_light_energy = 0.62
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.glow_enabled = true
	environment.glow_intensity = 0.75
	environment.glow_bloom = 0.12
	environment.fog_enabled = true
	environment.fog_light_color = Color("70758d")
	environment.fog_light_energy = 0.55
	environment.fog_density = 0.009
	environment.fog_height = -1.0
	environment.fog_height_density = 0.18
	world_environment.environment = environment
	add_child(world_environment)

	var sun := DirectionalLight3D.new()
	sun.name = "Moonlight"
	sun.rotation_degrees = Vector3(-52.0, -34.0, 0.0)
	sun.light_color = Color("ffe1bc")
	sun.light_energy = 1.35
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 35.0
	add_child(sun)


func _build_level() -> void:
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


func _add_box(node_name: String, world_position: Vector3, size: Vector3, color: Color, collision: bool, metallic: float = 0.0) -> void:
	var root: Node3D
	if collision:
		root = StaticBody3D.new()
	else:
		root = Node3D.new()
	root.name = node_name
	root.position = world_position
	add_child(root)

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
	add_child(root)

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
	add_child(root)

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

	for layer in range(3):
		var crown := MeshInstance3D.new()
		crown.position.y = 1.55 + float(layer) * 0.52
		var crown_mesh := SphereMesh.new()
		crown_mesh.radius = 0.9 - float(layer) * 0.13
		crown_mesh.height = (0.9 - float(layer) * 0.13) * 1.45
		crown_mesh.radial_segments = 8
		crown_mesh.rings = 4
		crown.mesh = crown_mesh
		crown.material_override = _make_material(Color("31554f").lightened(float(layer) * 0.06), 1.0)
		root.add_child(crown)


func _add_lamp(world_position: Vector3) -> void:
	var root := Node3D.new()
	root.name = "Lantern"
	root.position = world_position
	add_child(root)

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
	light.shadow_enabled = false
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
	add_child(crystal)


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
	sprite.alpha_scissor_threshold = 0.25
	add_child(sprite)
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
	panel.custom_minimum_size = Vector2(405.0, 0.0)
	hud.add_child(panel)

	var panel_style := StyleBoxTexture.new()
	panel_style.texture = load("res://assets/third_party/ninja_adventure/ui/panel.png") as Texture2D
	panel_style.modulate_color = Color(0.26, 0.20, 0.34, 0.96)
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		panel_style.set_texture_margin(side, 5.0)
		panel_style.set_content_margin(side, 16.0)
	panel.add_theme_stylebox_override("panel", panel_style)

	var text := Label.new()
	text.text = "WANDERLIGHT  /  HD-2D PROTOTYPE\nWASD / 方向鍵：移動    Q E：旋轉    R F：縮放"
	text.add_theme_color_override("font_color", Color("f3dfbd"))
	text.add_theme_font_size_override("font_size", 16)
	panel.add_child(text)

	var heart_row := HBoxContainer.new()
	heart_row.name = "HealthPreview"
	heart_row.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	heart_row.position = Vector2(-164.0, 24.0)
	heart_row.add_theme_constant_override("separation", 4)
	hud.add_child(heart_row)
	var heart_sheet := load("res://assets/third_party/ninja_adventure/ui/heart.png") as Texture2D
	for index in range(5):
		var heart_atlas := AtlasTexture.new()
		heart_atlas.atlas = heart_sheet
		heart_atlas.region = Rect2(64.0, 0.0, 16.0, 16.0)
		var heart := TextureRect.new()
		heart.texture = heart_atlas
		heart.custom_minimum_size = Vector2(24.0, 24.0)
		heart.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		heart.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		heart.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		heart_row.add_child(heart)
