extends Node3D
## The visible half of a walk-through portal: a swirling veil, its light and
## rising motes. It brightens and quickens as the traveler approaches and flares
## on `surge()` while they cross. Presentation only; the threshold is a RoadExit.

const VEIL_SIZE := Vector2(2.44, 3.55)
const NEAR: float = 1.2
const FAR: float = 6.5
const IDLE_LIGHT: float = 0.8
const NEAR_LIGHT: float = 2.2
const SURGE_LIGHT: float = 6.0

var traveler: Node3D
var color := Color("63dfff")
var proximity: float = 0.0
var surge_amount: float = 0.0
var _veil: MeshInstance3D
var _material: ShaderMaterial
var _light: OmniLight3D
var _motes: CPUParticles3D


func _ready() -> void:
	_veil = MeshInstance3D.new()
	_veil.name = "Veil"
	var plane := QuadMesh.new()
	plane.size = VEIL_SIZE
	plane.orientation = PlaneMesh.FACE_Z
	_veil.mesh = plane
	_material = ShaderMaterial.new()
	_material.shader = preload("res://shaders/crypt_portal.gdshader")
	_material.set_shader_parameter("core_color", Color(color, 1.0))
	_veil.material_override = _material
	_veil.position = Vector3(0, 1.8, -0.16)
	_veil.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_veil)
	_light = OmniLight3D.new()
	_light.name = "PortalLight"
	_light.position = Vector3(0, 1.6, 0.4)
	_light.light_color = color
	_light.light_energy = IDLE_LIGHT
	_light.omni_range = 5.0
	add_child(_light)
	_motes = CPUParticles3D.new()
	_motes.name = "Motes"
	_motes.amount = 26
	_motes.lifetime = 2.6
	_motes.preprocess = 2.6
	_motes.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_motes.emission_box_extents = Vector3(1.0, 0.05, 0.25)
	_motes.direction = Vector3.UP
	_motes.spread = 12.0
	_motes.gravity = Vector3(0, 0.35, 0)
	_motes.initial_velocity_min = 0.25
	_motes.initial_velocity_max = 0.55
	_motes.scale_amount_min = 0.6
	_motes.scale_amount_max = 1.2
	var fade := Gradient.new()
	fade.set_color(0, Color(color.lightened(0.5), 0.0))
	fade.add_point(0.2, Color(color.lightened(0.5), 0.9))
	fade.set_color(fade.get_point_count() - 1, Color(color, 0.0))
	_motes.color_ramp = fade
	var quad := QuadMesh.new()
	quad.size = Vector2(0.05, 0.05)
	var mote_material := StandardMaterial3D.new()
	mote_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mote_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mote_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mote_material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mote_material.vertex_color_use_as_albedo = true
	quad.material = mote_material
	_motes.mesh = quad
	_motes.position = Vector3(0, 0.15, 0.25)
	add_child(_motes)


func _process(delta: float) -> void:
	var target: float = 0.0
	if is_instance_valid(traveler):
		var distance: float = Vector2(traveler.global_position.x - global_position.x, traveler.global_position.z - global_position.z).length()
		target = 1.0 - smoothstep(NEAR, FAR, distance)
	proximity = move_toward(proximity, target, delta * 1.6)
	_material.set_shader_parameter("proximity", proximity)
	_material.set_shader_parameter("surge", surge_amount)
	_light.light_energy = lerpf(lerpf(IDLE_LIGHT, NEAR_LIGHT, proximity), SURGE_LIGHT, surge_amount)
	_motes.speed_scale = 1.0 + proximity * 1.2 + surge_amount * 3.0


## Flare for a crossing: rise quickly, then hold until the map changes.
func surge(seconds: float = 0.6) -> void:
	var rise := create_tween()
	rise.tween_property(self, "surge_amount", 1.0, seconds).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


## World-space center of the opening, used to aim the lens and the ripple.
func opening_center() -> Vector3:
	return _veil.global_position if is_instance_valid(_veil) else global_position + Vector3.UP * 1.8
