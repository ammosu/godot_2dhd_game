extends Node3D
## Visual clocks and radii mirror the encounter wave and staggered landing times.
const FLAMES = preload("res://assets/generated/dungeon/ash_eruption.png")
const Ring = preload("res://scripts/gameplay/combat_ground_ring.gd")
var _rain_points: Array[Vector3] = []
var _markers: Array[MeshInstance3D] = []
var _curtain: MeshInstance3D
var _curtain_material: ShaderMaterial
var _crystal_mesh: ArrayMesh
var _crystal_material: StandardMaterial3D
var _ground: MeshInstance3D
var _material: ShaderMaterial
var _jets: Array[Sprite3D] = []
var _waves: Array[MeshInstance3D] = []
var _embers: MultiMeshInstance3D
var _ember_material: StandardMaterial3D
var _ember_origins: Array[Vector3] = []
var _flame_frames: Array[AtlasTexture] = []
var _cast_light: OmniLight3D
var _ring_lights: Array[OmniLight3D] = []
var _shards: Array[MeshInstance3D] = []
var _age: float = 0.0
var _released: bool = false
var _kind: String = ""
var _center := Vector3.ZERO
var _radius: float = 1.0

func _ready() -> void:
	_crystal_mesh = load("res://scripts/gameplay/ashen_crypt.gd").faceted_crystal()
	_crystal_material = StandardMaterial3D.new()
	_crystal_material.albedo_color = Color("b52b43")
	_crystal_material.vertex_color_use_as_albedo = false
	_crystal_material.metallic = 0.55
	_crystal_material.roughness = 0.18
	_crystal_material.emission_enabled = true
	_crystal_material.emission = Color("751a35")
	_crystal_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for i: int in range(4):
		var frame := AtlasTexture.new()
		frame.atlas = FLAMES
		frame.region = Rect2((i % 2) * FLAMES.get_width() / 2.0, (i / 2) * FLAMES.get_height() / 2.0, FLAMES.get_width() / 2.0, FLAMES.get_height() / 2.0)
		frame.filter_clip = true
		_flame_frames.append(frame)
	_cast_light = OmniLight3D.new()
	_cast_light.light_color = Color("ff481e")
	_cast_light.omni_range = 4.5
	_cast_light.light_energy = 0.0
	add_child(_cast_light)
	for i: int in range(8):
		var light := OmniLight3D.new()
		light.light_color = Color("ff761b")
		light.omni_range = 3.5
		light.light_energy = 0
		light.light_specular = 0.15
		add_child(light)
		_ring_lights.append(light)
	_ground = MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(18.3, 23.3)
	_ground.mesh = plane
	_ground.position = Vector3(0, 0.078, -1)
	_ground.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_material = ShaderMaterial.new()
	_material.shader = preload("res://shaders/crypt_boss_spell.gdshader")
	_ground.material_override = _material
	add_child(_ground)
	_build_curtain()
	hide()

func begin(kind: String, center: Vector3, radius: float, caster: Vector3 = Vector3.ZERO) -> void:
	clear()
	_kind = kind
	_center = center
	_radius = radius
	_cast_light.position = caster + Vector3.UP * 1.8
	_material.set_shader_parameter("pattern", 1 if kind == "ash_tide" else 2 if kind == "crystal_rain" else 0)
	_material.set_shader_parameter("center", Vector2(center.x, center.z))
	_material.set_shader_parameter("radius", radius)
	_material.set_shader_parameter("burst", 0.0)
	_material.set_shader_parameter("progress", 0.0)
	_curtain.hide()
	_ground.visible = kind != "crystal_rain"
	show()

func set_rain(points: Array) -> void:
	for at: Vector3 in points:
		_rain_points.append(at)
		var marker := Ring.new()
		marker.configure(1.15, Color("f8758f"), 0.05)
		marker.position = at
		add_child(marker)
		_markers.append(marker)

func charge(progress: float, clock: float) -> void:
	_material.set_shader_parameter("progress", progress)
	_material.set_shader_parameter("phase", clock)
	_cast_light.light_energy = 0.25 + progress * 1.1

func release() -> void:
	for node: Node in _jets + _shards + _waves:
		node.queue_free()
	_jets.clear()
	_shards.clear()
	_waves.clear()
	if is_instance_valid(_embers):
		_embers.queue_free()
		_embers = null
	_ember_origins.clear()
	_released = true
	_age = 0
	var points: Array[Vector3] = []
	if _kind == "ash_tide":
		for i: int in range(64):
			points.append(_center + Vector3(cos(i * TAU / 64), 0, sin(i * TAU / 64)) * 0.1)
	elif _kind == "crystal_rain":
		points.assign(_rain_points)
	else:
		points.append(_center)
		for i: int in range(6):
			points.append(_center + Vector3(cos(i * TAU / 6), 0, sin(i * TAU / 6)) * _radius * 0.65)
	for i: int in range(points.size()):
		if _kind == "crystal_rain":
			var shard := MeshInstance3D.new()
			shard.mesh = _crystal_mesh
			shard.material_override = _crystal_material
			shard.scale = Vector3(0.8, 1.5, 0.8)
			shard.rotation.z = -0.15 + float(i % 3) * 0.15
			shard.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			shard.position = points[i] + Vector3.UP * 3.0
			add_child(shard)
			_shards.append(shard)
		else:
			var jet := Sprite3D.new()
			jet.texture = _flame_frames[i % 4]
			var height: float = 1.1 + fposmod(sin(float(i) * 3.73) * 7.1, 0.9)
			jet.pixel_size = height / jet.texture.get_height()
			jet.set_meta("height", height)
			jet.set_meta("delay", float(i % 4) * 0.025)
			jet.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
			jet.shaded = false
			jet.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
			jet.position = points[i] + Vector3.UP * float(jet.get_meta("height")) * 0.5
			jet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(jet)
			_jets.append(jet)
		if _kind != "ash_tide":
			var wave := preload("res://scripts/gameplay/combat_ground_ring.gd").new()
			wave.configure(0.7, Color(1.0, 0.24, 0.035, 0.7), 0.025)
			wave.position = Vector3(points[i].x, 0.085, points[i].z)
			add_child(wave)
			_waves.append(wave)
	_build_embers(points)

func advance(delta: float) -> void:
	if not _released:
		return
	_age += delta
	_curtain.visible = _kind == "ash_tide"
	_curtain.position = Vector3(_center.x, 0.08, _center.z)
	_curtain.scale = Vector3(maxf(0.01, _age * 8.0), 1.35, maxf(0.01, _age * 8.0))
	_curtain_material.set_shader_parameter("age", _age)
	_curtain_material.set_shader_parameter("opacity", clampf((3.6 - _age) / 0.7, 0, 1))
	var duration: float = 3.6 if _kind == "ash_tide" else 2.6 if _kind == "crystal_rain" else 1.1
	var fade: float = clampf((duration - _age) / 0.7, 0, 1)
	_cast_light.light_energy = fade * 1.4
	_material.set_shader_parameter("burst", fade)
	_material.set_shader_parameter("wave_radius", _age * 8.0)
	_material.set_shader_parameter("phase", _age)
	for i: int in range(_ring_lights.size()):
		var angle: float = i * TAU / _ring_lights.size()
		var light: OmniLight3D = _ring_lights[i]
		light.position = _center + Vector3(cos(angle), 0, sin(angle)) * _age * 8.0 + Vector3.UP * 0.55
		light.light_energy = 1.8 * fade if _kind == "ash_tide" and absf(light.position.x) < 8.8 and light.position.z > -12 and light.position.z < 10 else 0.0
	for i: int in range(_jets.size()):
		var jet: Sprite3D = _jets[i]
		var age: float = maxf(0, _age - float(jet.get_meta("delay")))
		jet.texture = _flame_frames[(int(age * 12.0) + i) % 4]
		jet.scale = Vector3(0.75 + fposmod(sin(i * 7.3) * 5.0, 0.7), 0.75 + sin(age * 9 + i) * 0.15, 1)
		jet.rotation.z = sin(i * 3.7) * 0.3
		jet.modulate = Color(1.1, 0.95, 0.8, fade)
		if _kind == "ash_tide":
			var angle: float = i * TAU / _jets.size()
			jet.position = _center + Vector3(cos(angle), 0, sin(angle)) * _age * 8.0 + Vector3.UP * float(jet.get_meta("height")) * 0.40
			jet.visible = absf(jet.position.x) < 9 and jet.position.z > -12 and jet.position.z < 10
	for i: int in range(_waves.size()):
		var local_age: float = _age - (0.3 + float(i % 4) * 0.5 if _kind == "crystal_rain" else 0.0)
		var wave: MeshInstance3D = _waves[i]
		wave.visible = local_age >= 0 and local_age < 0.65
		wave.scale = Vector3.ONE * (0.5 + maxf(0, local_age) * 1.5)
		(wave.material_override as StandardMaterial3D).albedo_color.a = maxf(0, 1.0 - local_age / 0.65)
	for i: int in range(_markers.size()):
		var landing: float = 0.3 + float(i % 4) * 0.5
		_markers[i].visible = _age < landing
		(_markers[i].material_override as StandardMaterial3D).albedo_color = Color(1, 0.22 + clampf(landing - _age, 0, 1) * 0.25, 0.35, 1)
	if is_instance_valid(_embers):
		_ember_material.albedo_color.a = fade
		for i: int in range(_ember_origins.size()):
			var angle: float = float(i) * 2.399
			var offset := Vector3(cos(angle) * _age * 0.65, _age * (1.4 + float(i % 4) * 0.35), sin(angle) * _age * 0.65)
			var at: Vector3 = _ember_origins[i] + offset
			if _kind == "ash_tide":
				angle = float(i / 2) * TAU / 64.0 + sin(float(i) * 7.1) * 0.03
				at = _center + Vector3(cos(angle), 0, sin(angle)) * (_age * 8.0 + sin(float(i) * 3.1) * 0.25) + Vector3.UP * fposmod(_age * 2.0 + float(i) * 0.13, 1.8)
				if absf(at.x) > 9 or at.z < -12 or at.z > 10:
					at.y = -5
			_embers.multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY, at))
	for i: int in range(_shards.size()):
		var shard: MeshInstance3D = _shards[i]
		var local_age: float = _age - float(i % 4) * 0.5
		shard.visible = local_age >= 0 and local_age < 0.9
		shard.position.y = maxf(0.2, 4.0 - local_age * 12.67)
		shard.rotation.y += delta * 3.0
		shard.scale = Vector3(0.6, 1.3, 0.6) * clampf((0.9 - local_age) / 0.3, 0, 1)
	if _age >= duration:
		clear()

func clear() -> void:
	for node: Node in _jets + _shards + _waves + _markers:
		node.queue_free()
	_jets.clear()
	_shards.clear()
	_waves.clear()
	_markers.clear()
	_rain_points.clear()
	if is_instance_valid(_embers):
		_embers.queue_free()
		_embers = null
	_ember_origins.clear()
	_cast_light.light_energy = 0.0
	for light: OmniLight3D in _ring_lights:
		light.light_energy = 0.0
	_released = false
	hide()


func _build_embers(points: Array[Vector3]) -> void:
	_embers = MultiMeshInstance3D.new()
	_embers.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mesh := QuadMesh.new()
	mesh.size = Vector2(0.025, 0.045)
	_ember_material = StandardMaterial3D.new()
	_ember_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ember_material.albedo_color = Color("ff973f")
	_ember_material.emission_enabled = true
	_ember_material.emission = Color("ff7924")
	_ember_material.emission_energy_multiplier = 2.0
	_ember_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ember_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mesh.material = _ember_material
	var instances := MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	instances.mesh = mesh
	instances.instance_count = points.size() * 2
	for i: int in range(instances.instance_count):
		var at: Vector3 = points[i / 2] + Vector3(sin(i * 3.7) * 0.3, 0.2, cos(i * 4.1) * 0.3)
		_ember_origins.append(at)
		instances.set_instance_transform(i, Transform3D(Basis.IDENTITY, at))
	_embers.multimesh = instances
	add_child(_embers)

func _build_curtain() -> void:
	_curtain = MeshInstance3D.new()
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for i: int in range(192):
		var u: float = float(i) / 192.0
		var v: float = float(i + 1) / 192.0
		for uv: Vector2 in [Vector2(u, 1), Vector2(v, 1), Vector2(v, 0), Vector2(u, 1), Vector2(v, 0), Vector2(u, 0)]:
			mesh.surface_set_uv(uv)
			mesh.surface_add_vertex(Vector3(cos(uv.x * TAU), 1.0 - uv.y, sin(uv.x * TAU)))
	mesh.surface_end()
	_curtain.mesh = mesh
	_curtain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_curtain_material = ShaderMaterial.new()
	_curtain_material.shader = preload("res://shaders/crypt_fire_curtain.gdshader")
	_curtain_material.set_shader_parameter("flames", FLAMES)
	_curtain.material_override = _curtain_material
	add_child(_curtain)
	_curtain.hide()
