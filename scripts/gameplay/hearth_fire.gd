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


func _ready() -> void:
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
	# Low-amplitude, smooth variations avoid a strobe or full-room brightness jumps.
	_light.light_energy = 2.2 + sin(_elapsed * 5.1) * 0.06 + sin(_elapsed * 8.7) * 0.04
