extends Node3D
## Shallow visual water, local light glints and foot ripples; never changes collision.
const STONE_ATLAS := preload("res://assets/generated/dungeon/crypt_materials.png")
const PUDDLE_SHADER := preload("res://shaders/crypt_puddle.gdshader")
var player: Node3D
var _puddles: Array[Dictionary] = []
var _last_step := Vector3.INF

static func build(world: Node3D, floor_id: String) -> void:
	var damp := new()
	damp.name = "CryptDampness"
	damp.player = world.get_node("Player")
	world.get("_map_root").add_child(damp)
	if floor_id == "ashen_crypt":
		damp.add_puddle(Vector2(-2.4, 3.2), Vector2(3.2, 2.0), Vector3(-3.75, 1.2, 0.7), Color("ffb05b"))
		damp.add_puddle(Vector2(2.5, -3.8), Vector2(2.6, 3.5), Vector3(3.75, 1.2, -8), Color("ff9c48"))
		damp.add_puddle(Vector2(-2, -7.9), Vector2(2.5, 1.8), Vector3(0, 2.0, -11), Color("e44b53"))
		damp.add_puddle(Vector2(2.4, 7.6), Vector2(2.5, 1.6), Vector3(0, 1.8, 10), Color("64cbd9"))
	else:
		var second: bool = floor_id == "ashen_crypt_2"
		var sign: float = -1.0 if second else 1.0
		damp.add_puddle(Vector2(-3.0 * sign, 32.8), Vector2(3.6, 2.4), Vector3(-3.9 * sign, 1.2, 34.3), Color("ffc079"))
		damp.add_puddle(Vector2(6.5, 30.0), Vector2(2.4, 3.0), Vector3(7, 1.2, 32), Color("ffb66c"))
		damp.add_puddle(Vector2(-6.2, 20.5), Vector2(2.7, 2.0), Vector3(-7, 1.2, 18.8), Color("ffb66c"))
		damp.add_puddle(Vector2(5.8, 19.9), Vector2(2.9, 1.8), Vector3(7, 1.2, 18.8), Color("ffad59"))
		damp.add_puddle(Vector2(-12, 27.4), Vector2(2.6, 1.7), Vector3(-12, 0.8, 26), Color("73c4d5"))
		damp.add_puddle(Vector2(1.7, 13.4), Vector2(2.0, 1.7), Vector3(0, 1.8, 11.8), Color("64cbd9"))
		if second:
			damp.add_puddle(Vector2(-5.3, 26.8), Vector2(3.4, 2.0), Vector3(0, 1.6, 24), Color("77cfde"))
			damp.add_puddle(Vector2(11.8, 21.4), Vector2(2.5, 3.0), Vector3(12.5, 1.2, 28.8), Color("a4b0be"))

func add_puddle(at: Vector2, extent: Vector2, source: Vector3, color: Color) -> void:
	var surface := MeshInstance3D.new()
	surface.name = "ShallowPuddle"
	var plane := PlaneMesh.new()
	plane.size = extent
	surface.mesh = plane
	surface.position = Vector3(at.x, 0.054, at.y)
	surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := ShaderMaterial.new()
	material.shader = PUDDLE_SHADER
	material.set_shader_parameter("atlas", STONE_ATLAS)
	material.set_shader_parameter("extent", extent)
	material.set_shader_parameter("reflected_light", source)
	material.set_shader_parameter("light_tint", color)
	material.set_shader_parameter("seed", float(_puddles.size()) * 1.37)
	surface.material_override = material
	add_child(surface)
	_puddles.append({"at": at, "extent": extent, "material": material, "age": 5.0})

func _process(delta: float) -> void:
	if not is_instance_valid(player):
		return
	var moved: bool = player.global_position.distance_to(_last_step) > 0.48
	for puddle: Dictionary in _puddles:
		puddle.age = minf(5.0, float(puddle.age) + delta)
		var offset := Vector2(player.global_position.x, player.global_position.z) - Vector2(puddle.at)
		var extent: Vector2 = puddle.extent
		if moved and (offset / (extent * 0.5)).length() < 0.82 and absf(player.global_position.y) < 0.3:
			puddle.age = 0.0
			puddle.material.set_shader_parameter("step_uv", offset / extent + Vector2.ONE * 0.5)
		puddle.material.set_shader_parameter("step_age", puddle.age)
	if moved:
		_last_step = player.global_position
