class_name WorldProps
extends RefCounted
## Builds shared scenery props into the current map: boxes, paving, foliage,
## lamps, crates and other art. Map builders reach it as `world.props`.

const Footsteps = preload("res://scripts/gameplay/footsteps.gd")
const StreetLantern = preload("res://scripts/gameplay/street_lantern.gd")

## The map being built; replaced whenever the world loads a map.
var map_root: Node3D
## Shared with the world so immutable art stays resident across map rebuilds.
var textures: Dictionary[String, Texture2D]


func _init(texture_cache: Dictionary[String, Texture2D]) -> void:
	textures = texture_cache


func art_texture(path: String) -> Texture2D:
	if not textures.has(path):
		textures[path] = load(path) as Texture2D
	return textures[path]


func make_material(color: Color, roughness: float, metallic: float = 0.0, emission: Color = Color.BLACK, emission_energy: float = 1.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	if emission != Color.BLACK:
		material.emission_enabled = true
		material.emission = emission
		material.emission_energy_multiplier = emission_energy
	return material


func make_coursed_stone() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/coursed_stone.gdshader")
	material.set_shader_parameter("stone_texture", preload("res://assets/generated/moon_lamp_cut_limestone_albedo.png"))
	return material


func make_village_surface(road_surface: bool) -> ShaderMaterial:
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


func add_box(node_name: String, world_position: Vector3, size: Vector3, color: Color, collision: bool, metallic: float = 0.0) -> void:
	var root: Node3D = StaticBody3D.new() if collision else Node3D.new()
	root.name = node_name
	root.set_meta("authored_name", node_name)
	root.position = world_position
	map_root.add_child(root)
	if node_name in ["Ground", "RuinGround"]:
		Footsteps.register_surface(root, size, &"dirt")
	elif node_name.ends_with("RuinCourt") or node_name.begins_with("MoonPath_") or node_name.begins_with("RuinCrossPath_"):
		Footsteps.register_surface(root, size, &"dirt" if GameState.current_map in ["east_road", "firefly_forest", "caravan_road"] else &"stone", 10)
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.material_override = make_material(color, 0.88, metallic)
	if node_name.ends_with("RuinCourt") or node_name == "RuinCourt" or node_name.begins_with("MoonPath_") or node_name.begins_with("RuinCrossPath_"):
		var ruin_material := make_material(Color("b8b7d0"), 0.97)
		ruin_material.albedo_texture = art_texture("res://assets/generated/ruin_flagstone.png")
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
		mesh_instance.material_override = make_village_surface(false)
	elif node_name == "RuinGround":
		var soil := ShaderMaterial.new()
		soil.shader = preload("res://shaders/ruin_soil.gdshader")
		soil.set_shader_parameter("mineral_texture", preload("res://assets/generated/moon_lamp_cut_limestone_albedo.png"))
		mesh_instance.material_override = soil
	elif node_name == "BoundaryWall":
		mesh_instance.material_override = make_coursed_stone()
	root.add_child(mesh_instance)
	if collision:
		var collision_shape := CollisionShape3D.new()
		var box_shape := BoxShape3D.new()
		box_shape.size = size
		collision_shape.shape = box_shape
		root.add_child(collision_shape)


func add_cobble_box(node_name: String, world_position: Vector3, size: Vector3, collision: bool) -> void:
	var root: Node3D = StaticBody3D.new() if collision else Node3D.new()
	root.name = node_name
	if node_name == "GardenWalk":
		root.add_to_group("village_garden_walks")
	root.position = world_position
	map_root.add_child(root)
	Footsteps.register_surface(root, size, &"dirt" if GameState.current_map in ["east_road", "firefly_forest", "caravan_road"] else &"stone", 10)
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.material_override = make_village_surface(true)
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


func add_tree(world_position: Vector3) -> void:
	var root := Node3D.new()
	root.name = "VillageOak"
	root.add_to_group("village_trees")
	root.position = world_position
	map_root.add_child(root)
	preload("res://scripts/gameplay/tree_variants.gd").decorate(root, world_position)
	# Trunk-sized obstacle; the broad billboard canopy stays walkable beneath.
	preload("res://scripts/gameplay/prop_collision.gd").cylinder(root, Vector3(0, 0.8, 0), 0.36, 1.6)


func add_lamp(world_position: Vector3) -> void:
	StreetLantern.build(map_root, world_position)


func add_grass_clump(world_position: Vector3, variant: String, pixel_size: float) -> void:
	var grass := Sprite3D.new()
	grass.name = "MeadowGrass"
	grass.texture = art_texture("res://assets/generated/grass_%s.tres" % variant)
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
	map_root.add_child(grass)


func add_flower_clump(world_position: Vector3, variant: String) -> void:
	var flower := Sprite3D.new()
	flower.name = "FlowerClump"
	flower.texture = art_texture("res://assets/generated/flowers_%s.tres" % variant)
	flower.pixel_size = 0.001
	# All three 640px canvases share the root baseline at y=620.
	# Ground the foliage instead of reusing the old floating sphere height.
	flower.position = world_position + Vector3.UP * (620.0 - 320.0) * flower.pixel_size
	flower.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	flower.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	flower.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	flower.shaded = true
	flower.double_sided = true
	map_root.add_child(flower)


func add_supply_crate(world_position: Vector3, yaw: float) -> void:
	var scene := preload("res://assets/generated/supply_crate.glb") as PackedScene
	var crate := scene.instantiate() as Node3D
	crate.name = "SupplyCrate"
	crate.position = world_position
	crate.rotation.y = yaw
	crate.add_to_group("supply_crate_art")
	map_root.add_child(crate)
	preload("res://scripts/gameplay/prop_collision.gd").from_meshes(crate)
	for node: Node in crate.find_children("*", "MeshInstance3D", true, false):
		var instance := node as MeshInstance3D
		for surface: int in range(instance.mesh.get_surface_count()):
			var material := instance.mesh.surface_get_material(surface) as BaseMaterial3D
			if material != null:
				material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST


func add_crystal(world_position: Vector3, scale_factor: float) -> void:
	var crystal_scene := load("res://assets/generated/moon_crystal.glb") as PackedScene
	var crystal := crystal_scene.instantiate() as Node3D
	preload("res://scripts/gameplay/crystal_materials.gd").apply(crystal)
	crystal.name = "GlowCrystal"
	crystal.position = world_position
	crystal.scale = Vector3.ONE * scale_factor
	crystal.rotation.y = world_position.x * 0.37 + world_position.z * 0.19
	map_root.add_child(crystal)
	preload("res://scripts/gameplay/prop_collision.gd").from_meshes(crystal, true)


func add_village_pig(world_position: Vector3) -> void:
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
	map_root.add_child(pig)
	pig.play(&"idle")


func add_earthenware_jar(world_position: Vector3) -> void:
	var jar := (preload("res://assets/generated/earthenware_jar.glb") as PackedScene).instantiate() as Node3D
	jar.name = "EarthenwareJar"
	jar.position = world_position
	jar.rotation.y = 0.3
	jar.add_to_group("earthenware_jar_art")
	map_root.add_child(jar)
	preload("res://scripts/gameplay/prop_collision.gd").from_meshes(jar, true)
	for node: Node in jar.find_children("*", "MeshInstance3D", true, false):
		var instance := node as MeshInstance3D
		for surface: int in range(instance.mesh.get_surface_count()):
			var material := instance.mesh.surface_get_material(surface) as BaseMaterial3D
			if material != null:
				material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
				material.albedo_color = Color("b6bec4")
