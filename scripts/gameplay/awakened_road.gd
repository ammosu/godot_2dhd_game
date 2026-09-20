extends MeshInstance3D
## Original open-ring inlay: its northern opening feeds the forgotten road.
## Pure presentation; GameState owns restoration and persistence.

func _ready() -> void:
	name = "AwakenedRoad"
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	# The missing arc faces north (-Z), leaving an entrance rather than a cage.
	for index: int in range(84):
		var a: float = lerpf(deg_to_rad(-50.0), deg_to_rad(230.0), float(index) / 84.0)
		var b: float = lerpf(deg_to_rad(-50.0), deg_to_rad(230.0), float(index + 1) / 84.0)
		_quad(surface, Vector2(cos(a), sin(a)) * 1.95,
			Vector2(cos(b), sin(b)) * 1.95,
			Vector2(cos(b), sin(b)) * 2.01,
			Vector2(cos(a), sin(a)) * 2.01)
	# Broken parallel inlays suggest light travelling along stone joints.
	for index: int in range(21):
		var z: float = -2.05 - float(index) * 0.49
		for side: float in [-1.0, 1.0]:
			var x: float = side * 0.65
			_quad(surface, Vector2(x - 0.025, z), Vector2(x + 0.025, z),
				Vector2(x + 0.025, z - 0.38), Vector2(x - 0.025, z - 0.38))
	mesh = surface.commit()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = Color("8ac8c7")
	material.emission_enabled = true
	material.emission = Color("8ac8c7")
	material.emission_energy_multiplier = 0.65
	material_override = material
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	GameState.state_changed.connect(_sync)
	_sync()


func _sync() -> void:
	visible = GameState.quest_state == GameState.QuestState.COMPLETE


func _quad(surface: SurfaceTool, a: Vector2, b: Vector2, c: Vector2, d: Vector2) -> void:
	for point: Vector2 in [a, b, c, a, c, d]:
		surface.set_normal(Vector3.UP)
		surface.add_vertex(Vector3(point.x, 0.018, point.y))
