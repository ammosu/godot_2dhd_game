extends Node3D
## Decorative hearth only: no gameplay state, collision, or additional audio.

const FLAMES: Texture2D = preload("res://assets/generated/hearth_flames.png")
const REGIONS: Array[Rect2] = [
	Rect2(147, 92, 409, 494), Rect2(702, 116, 413, 470),
	Rect2(140, 704, 416, 460), Rect2(710, 682, 413, 482),
]
var _light: OmniLight3D
var _elapsed: float = 0.0
var _flame: AnimatedSprite3D
var _baselines: Array[float] = []
var _tongues: Array[AnimatedSprite3D] = []
var _embers: MultiMeshInstance3D
var _coal_material: StandardMaterial3D
var _phase: float = 0.0


func _ready() -> void:
	_phase = global_position.x * 1.73 + global_position.z * 0.91
	var wood := StandardMaterial3D.new()
	wood.albedo_texture = preload("res://assets/generated/timber_albedo.png")
	wood.albedo_color = Color("403536")
	wood.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	wood.roughness = 1.0
	for index: int in range(3):
		var log_mesh := CylinderMesh.new()
		log_mesh.top_radius = 0.085
		log_mesh.bottom_radius = 0.105
		log_mesh.height = 0.94 if index == 2 else 1.12
		log_mesh.radial_segments = 7
		log_mesh.rings = 1
		var log := MeshInstance3D.new()
		log.name = "CharredLog%d" % index
		log.mesh = log_mesh
		log.material_override = wood
		log.position = Vector3(0, 0.09 + (0.12 if index == 2 else 0.0), (float(index) - 1.0) * 0.16)
		log.rotation = Vector3(0, -0.3 if index == 2 else 0.18, PI * 0.5)
		add_child(log)
	_flame = AnimatedSprite3D.new()
	_flame.name = "Flames"
	_flame.sprite_frames = SpriteFrames.new()
	_flame.sprite_frames.set_animation_speed(&"default", 7.0)
	_flame.sprite_frames.set_animation_loop(&"default", true)
	for region: Rect2 in REGIONS:
		_baselines.append(region.size.y * 0.5)
		var frame := AtlasTexture.new()
		frame.atlas = FLAMES
		frame.region = region
		_flame.sprite_frames.add_frame(&"default", frame)
	_flame.pixel_size = 0.88 / 494.0
	_flame.position = Vector3(0, 0.14, 0.10)
	_flame.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	_flame.shaded = false
	_flame.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_flame.frame_changed.connect(_align_base)
	add_child(_flame)
	_align_base()
	_flame.play()
	_build_coals()
	# Smaller, offset rear tongues break up the single looping billboard silhouette.
	for index: int in range(2):
		var tongue := AnimatedSprite3D.new()
		tongue.name = "RearFlame%d" % index
		tongue.sprite_frames = _flame.sprite_frames
		tongue.pixel_size = _flame.pixel_size
		tongue.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		tongue.shaded = false
		tongue.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		tongue.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		tongue.modulate = Color(1.0, 0.64, 0.32, 0.78)
		tongue.position = Vector3(-0.24 if index == 0 else 0.24, 0.12, -0.07)
		tongue.scale = Vector3(0.64, 0.68, 1.0)
		add_child(tongue)
		tongue.play(&"default", 0.79 if index == 0 else 1.13)
		tongue.set_frame_and_progress(index + 1, 0.35)
		tongue.offset.y = _baselines[tongue.frame]
		_tongues.append(tongue)
	_build_embers()
	_light = OmniLight3D.new()
	_light.name = "Firelight"
	_light.position = Vector3(0, 0.45, 0.3)
	_light.light_color = Color("ffb56f")
	_light.light_energy = 2.2
	_light.omni_range = 4.5
	add_child(_light)


func _align_base() -> void:
	_flame.offset.y = _baselines[_flame.frame]


func _process(delta: float) -> void:
	_elapsed += delta
	var time: float = _elapsed + _phase
	# Low-amplitude, smooth variations avoid a strobe or full-room brightness jumps.
	var flicker: float = sin(time * 5.1) * 0.06 + sin(time * 8.7) * 0.04
	_light.light_energy = 2.2 + flicker
	_light.light_color = Color("ffb56f").lerp(Color("ffc487"), (flicker + 0.1) * 1.5)
	_flame.scale = Vector3(1.0 + sin(time * 3.7) * 0.025, 1.0 + sin(time * 4.3) * 0.035, 1.0)
	for index: int in range(_tongues.size()):
		var tongue: AnimatedSprite3D = _tongues[index]
		tongue.offset.y = _baselines[tongue.frame]
		tongue.scale.y = 0.68 + sin(time * 3.3 + index * 2.4) * 0.08
	_coal_material.emission_energy_multiplier = 1.1 + sin(time * 1.7) * 0.16
	for index: int in range(_embers.multimesh.instance_count):
		# Short, staggered lifetimes fade out below the mantel. No opaque smoke card.
		var age: float = fposmod(_elapsed * (0.48 + index * 0.017) + index * 0.137, 1.0)
		var fade: float = sin(age * PI)
		var at := Vector3(sin(index * 2.4) * 0.29 + sin(time * 1.9 + index) * age * 0.06, 0.20 + age * 0.83, 0.04 + cos(index * 1.7) * 0.10)
		var size: float = 0.008 * fade * (0.7 + float(index % 3) * 0.2)
		_embers.multimesh.set_instance_transform(index, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * size), at))
		_embers.multimesh.set_instance_color(index, Color(1.0, 0.24 + (1.0 - age) * 0.46, 0.045) * fade)


func _build_coals() -> void:
	_coal_material = StandardMaterial3D.new()
	_coal_material.albedo_color = Color("541c12")
	_coal_material.roughness = 1.0
	_coal_material.emission_enabled = true
	_coal_material.emission = Color("ff5214")
	_coal_material.emission_energy_multiplier = 1.1
	var mesh := SphereMesh.new()
	mesh.radius = 0.075
	mesh.height = 0.075
	mesh.radial_segments = 8
	mesh.rings = 4
	for index: int in range(9):
		var coal := MeshInstance3D.new()
		coal.name = "GlowingCoal%d" % index
		coal.mesh = mesh
		coal.material_override = _coal_material
		coal.position = Vector3(-0.39 + (index % 5) * 0.19, 0.035, -0.19 + (index / 5) * 0.35)
		coal.scale = Vector3(1.0 + (index % 3) * 0.15, 1.0, 0.85)
		add_child(coal)


func _build_embers() -> void:
	_embers = MultiMeshInstance3D.new()
	_embers.name = "RisingEmbers"
	_embers.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_embers.multimesh = MultiMesh.new()
	_embers.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	_embers.multimesh.use_colors = true
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 4
	mesh.rings = 2
	_embers.multimesh.mesh = mesh
	_embers.multimesh.instance_count = 10
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	_embers.material_override = material
	for index: int in range(10):
		_embers.multimesh.set_instance_transform(index, Transform3D(Basis.IDENTITY.scaled(Vector3.ZERO), Vector3.ZERO))
	add_child(_embers)
