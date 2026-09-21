extends Node3D
## Presentation-only modular arena. Layout and encounter state belong to GameState.

const Modules = preload("res://scripts/gameplay/battle_arena/modules.gd")
const GENERATED: String = "res://assets/generated/"
var camera: Camera3D
var _stone: StandardMaterial3D
var _wood: StandardMaterial3D
var _foliage: StandardMaterial3D
var _bronze: StandardMaterial3D
var _theme: String = "ruins"


func build(descriptor: Dictionary) -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	_theme = str(descriptor.get("theme", "ruins"))
	if _theme not in ["village", "forest", "ruins", "moon_spring", "eclipse"]:
		_theme = "ruins"
	_stone = Modules.material(Color("788292"), GENERATED + "cut_limestone_albedo.png")
	_wood = Modules.material(Color("827268"), GENERATED + "timber_albedo.png")
	_foliage = Modules.material(Color("345c58"), GENERATED + "meadow_albedo.png")
	_bronze = Modules.material(Color("a99a73"), GENERATED + "aged_bronze_albedo.png")
	_lighting()
	_platform()
	_backdrop()
	_landmarks()
	var props: Array = descriptor.get("props", [])
	for value: Variant in props:
		if not value is Dictionary:
			continue
		var prop: Dictionary = value
		var root := Node3D.new()
		root.name = "Prop_" + str(prop.get("kind", "rock"))
		add_child(root)
		root.position = prop.get("position", Vector3.ZERO)
		root.rotation.y = float(prop.get("rotation", 0.0))
		root.scale = Vector3.ONE * float(prop.get("scale", 1.0))
		_prop(root, str(prop.get("kind", "rock")))


func _lighting() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("182434") if _theme != "eclipse" else Color("251f34")
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("b8c8de")
	environment.ambient_light_energy = 0.58
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-53, -34, 0)
	light.light_color = Color("d5def9") if _theme != "village" else Color("f1dabd")
	light.light_energy = 0.85
	light.shadow_enabled = true
	light.directional_shadow_max_distance = 45.0
	add_child(light)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_WIDTH
	camera.size = 23.8
	camera.far = 90.0
	add_child(camera)
	camera.position = Vector3(0, 10, 23)
	camera.look_at(Vector3(0, 0.85, -0.7))
	camera.current = true


func _platform() -> void:
	var tint := Color("99a5b7")
	var texture: String = GENERATED + "battle_arena_v1/flagstone_albedo.png"
	if _theme == "forest":
		texture = GENERATED + "meadow_albedo.png"
		tint = Color("797c63")
	elif _theme == "village":
		texture = GENERATED + "village_paving_v2.png"
		tint = Color("b5aca0")
	elif _theme == "eclipse":
		tint = Color("838396")
	var ground := PlaneMesh.new()
	ground.size = Vector2(65, 17)
	var ground_material := ShaderMaterial.new()
	ground_material.shader = preload("res://shaders/ruin_soil.gdshader")
	ground_material.set_shader_parameter("mineral_texture", load(GENERATED + "cut_limestone_albedo.png"))
	Modules.mesh_instance(self, ground, Vector3(0, -0.16 if _theme == "forest" else -0.86, 0), ground_material).name = "SurroundingGround"
	# Low broken silhouettes soften the finite apron into the distant landscape.
	var berm := Modules.material(Color("334442"), GENERATED + "pillar_lichen_albedo.png")
	for index: int in range(15):
		var rock := SphereMesh.new()
		rock.radius = 1.2
		rock.height = 1.0
		rock.radial_segments = 7
		rock.rings = 3
		Modules.mesh_instance(self, rock, Vector3(-14 + float(index) * 2, -0.50 if _theme != "forest" else -0.10, -8.4 + float(index % 3) * 0.20), berm).scale = Vector3(1.2, 0.55 + float(index % 2) * 0.25, 0.70)
	var floor_material: Material = ground_material if _theme == "forest" else Modules.material(tint, texture, 3.0)
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(18, 8)
	Modules.mesh_instance(self, floor_mesh, Vector3.ZERO, floor_material).name = "WalkableFloor"
	var foundation: Material = ground_material if _theme == "forest" else _stone
	Modules.box(self, Vector3(0, -0.08 if _theme == "forest" else -0.43, 0), Vector3(18, 0.15 if _theme == "forest" else 0.84, 8), foundation).name = "PlatformFoundation"
	# Individual dressed blocks articulate genuine depth along the front edge.
	for index: int in range(0 if _theme == "forest" else 15):
		Modules.box(self, Vector3(-8.4 + float(index) * 1.2, -0.16, 4.02), Vector3(1.16, 0.30, 0.24), _stone)
	for index: int in range(0 if _theme == "forest" else 3):
		Modules.box(self, Vector3(0, -0.28 - float(index) * 0.23, 4.30 + float(index) * 0.40), Vector3(6.6, 0.22, 0.82), _stone)
	# Rear rail is below knee-height and entirely outside combat paths.
	if _theme != "forest":
		for x: float in [-7.2, -4.8, 4.8, 7.2]:
			Modules.box(self, Vector3(x, 0.24, -4.18), Vector3(2.25, 0.48, 0.48), _stone)
			Modules.box(self, Vector3(x, 0.52, -4.18), Vector3(2.38, 0.13, 0.60), _stone)


func _backdrop() -> void:
	var material := Modules.material(Color("909cab") if _theme != "eclipse" else Color("997fa2"), GENERATED + "battle_arena_v1/distant_backdrop.png")
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var mesh := QuadMesh.new()
	mesh.size = Vector2(36, 12)
	var visual := Modules.mesh_instance(self, mesh, Vector3(0, -2.4, -18), material)
	visual.rotation.x = camera.rotation.x
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visual.name = "DistantMountainLayer"


func _landmarks() -> void:
	if _theme == "village":
		var plaster := Modules.material(Color("a69c97"), GENERATED + "plaster_albedo.png")
		var roof := Modules.material(Color("68738b"), GENERATED + "slate_roof_albedo.png", 2.0)
		var window := Modules.material(Color("e8b575"))
		window.emission_enabled = true
		window.emission = Color("956a34")
		for x: float in [-7.1, 7.1]:
			var house := Node3D.new()
			add_child(house)
			house.position = Vector3(x, -0.85, -5.9)
			house.scale = Vector3.ONE * 0.82
			house.rotation.y = -0.10 if x < 0.0 else 0.10
			Modules.house(house, plaster, _wood, roof, window)
		var landmark := Node3D.new()
		add_child(landmark)
		landmark.position = Vector3(-2.6, -0.85, -5.8)
		var halo := Modules.imported(landmark, GENERATED + "moon_halo.glb", 2.3)
		for child: Node in halo.find_children("*", "MeshInstance3D", true, false):
			var visual := child as MeshInstance3D
			for surface_index: int in range(visual.mesh.get_surface_count()):
				var surface := visual.get_surface_override_material(surface_index) as BaseMaterial3D
				if surface != null:
					surface.albedo_color = Color("8b8994")
	elif _theme == "forest":
		for index: int in range(9):
			var tree := Node3D.new()
			add_child(tree)
			tree.position = Vector3(-12 + float(index) * 3.0, -0.16, -6.7 - float(index % 3) * 0.65)
			Modules.pine(tree, 3.3 + float(index % 3) * 0.4, _wood, _foliage)
	else:
		for x: float in [-8.0, 8.0]:
			var pillar := Node3D.new()
			add_child(pillar)
			pillar.position = Vector3(x, -0.85, -5.2)
			Modules.imported(pillar, GENERATED + "weathered_pillar_v2.glb", 3.0)
		if _theme == "moon_spring":
			_pool()
		elif _theme == "eclipse":
			_arch()


func _pool() -> void:
	preload("res://scripts/gameplay/water_feature.gd").build(self, Vector3(0, -0.18, -6.4), Vector2(12.0, 3.8), false)


func _arch() -> void:
	for x: float in [-3.5, 3.5]:
		Modules.box(self, Vector3(x, 0.52, -6.4), Vector3(0.8, 1.8, 0.9), _stone)
		Modules.box(self, Vector3(x, -0.45, -6.4), Vector3(1.45, 0.36, 1.3), _stone)
	for index: int in range(12):
		var angle: float = PI * float(index) / 12.0
		Modules.arch_stone(self, Vector3(0, 1.4, -6.4), angle + 0.006, angle + PI / 12.0 - 0.006, _stone)


func _prop(root: Node3D, kind: String) -> void:
	match kind:
		"pillar", "broken_pillar", "column":
			Modules.imported(root, GENERATED + "weathered_pillar_v2.glb", 2.7, 0.65)
		"crate":
			Modules.imported(root, GENERATED + "supply_crate.glb", 0.72, 0.60)
		"jar", "pot":
			Modules.imported(root, GENERATED + "earthenware_jar.glb", 0.70, 0.45)
		"tree", "pine":
			Modules.pine(root, 3.6, _wood, _foliage)
		"log", "fallen_log":
			var trunk := Modules.cylinder(root, Vector3(0, 0.24, 0), 0.25, 1.5, _wood)
			trunk.rotation.z = PI / 2.0
		"sign", "signpost", "marker":
			Modules.box(root, Vector3(0, 0.55, 0), Vector3(0.12, 1.1, 0.12), _wood)
			Modules.box(root, Vector3(0, 0.95, 0), Vector3(0.85, 0.30, 0.12), _wood)
		"grass", "fern", "flower", "flowers", "reed", "reeds", "moss":
			var sprig := Sprite3D.new()
			sprig.texture = load(GENERATED + ("flowers_mauve.tres" if kind in ["flowers", "flower"] else ("grass_seed.tres" if kind in ["reed", "reeds"] else "grass_fan.tres"))) as Texture2D
			sprig.pixel_size = (0.70 if kind in ["flower", "flowers"] else 0.78) / float(sprig.texture.get_width())
			sprig.position.y = sprig.texture.get_height() * sprig.pixel_size * 0.5
			sprig.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
			sprig.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
			sprig.shaded = true
			root.add_child(sprig)
		"lantern", "moon_lamp":
			Modules.imported(root, GENERATED + "moon_lamp.glb", 1.25)
		"bronze", "bronze_fragment":
			Modules.cylinder(root, Vector3(0, 0.14, 0), 0.35, 0.28, _bronze)
		_:
			var rock := SphereMesh.new()
			rock.radius = 0.42
			rock.height = 0.56
			rock.radial_segments = 7
			rock.rings = 3
			Modules.mesh_instance(root, rock, Vector3(0, 0.18, 0), _stone).scale = Vector3(1.3, 1, 0.8)
