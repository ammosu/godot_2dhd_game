extends Node3D
## Species-specific presentation only. Combat adapters supply the authoritative timers.
const AuraShader = preload("res://shaders/enemy_aura.gdshader")
var species: String
var sprite: Sprite3D
var shadow: MeshInstance3D
var aura: MeshInstance3D
var nameplate: Label3D
var health_bar: Node3D
var _phase: float = 0.0
## Timers only count down, so a rise marks a new windup/swing and its length.
var _windup_total: float = 0.0
var _last_windup: float = 0.0
var _swing_total: float = 0.0
var _last_swing: float = 0.0
## Anticipation crouch: starts partway and deepens to the full squash on release.
const WINDUP_SQUASH := Vector3(1.04, 0.95, 1.0)
const WINDUP_START: float = 0.35
## Strike stretch decays quickly after contact.
const SWING_STRETCH := Vector3(0.035, 0.02, 0.0)
const SWING_DECAY: float = 20.0
## Heavy follow-through settle while recovering.
const RECOVER_SQUASH := Vector3(1.02, 0.98, 1.0)
const HURT_TINT := Color(1.35, 1.16, 1.12)
const HURT_TIME: float = 0.25

func setup(body: Node3D, art: String, visual: Sprite3D, label: Label3D, bar: Node3D) -> void:
	species = art
	sprite = visual
	nameplate = label
	health_bar = bar
	_phase = fposmod(body.position.x * 1.7 + body.position.z * 0.9, TAU)
	nameplate.font_size = 48
	nameplate.pixel_size = 0.0045
	nameplate.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	nameplate.outline_size = 8
	nameplate.modulate = Color("f4e7cf")
	# Opaque cutout text participates in depth, so Forward+ DOF cannot blur it
	# against scenery behind the actor. It still respects world occlusion.
	nameplate.alpha_cut = Label3D.ALPHA_CUT_DISCARD
	nameplate.alpha_scissor_threshold = 0.35
	var height: float = 2.30 if species == "guardian" else 2.15 if species == "eclipse_mage" else 2.05 if species == "dusk_bat" else 1.92
	nameplate.position.y = height
	health_bar.position.y = height - 0.22
	shadow = body.get_node_or_null("ContactShadow") as MeshInstance3D
	if shadow != null:
		var radius: float = 0.56 if species == "guardian" else 0.43 if species == "moss_wolf" else 0.26 if species == "dusk_bat" else 0.37
		shadow.scale = Vector3.ONE * (radius / 0.32)
		(shadow.material_override as ShaderMaterial).set_shader_parameter("opacity", 0.62)
	if species == "eclipse_mage":
		aura = MeshInstance3D.new()
		aura.name = "CasterAura"
		var plane := PlaneMesh.new()
		plane.size = Vector2(1.65, 1.65)
		aura.mesh = plane
		var material := ShaderMaterial.new()
		material.shader = AuraShader
		aura.material_override = material
		aura.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(aura)
		aura.position.y = 0.025

func advance(clock: float, pose: String, hurt: float, windup: float, swing: float) -> void:
	# Always derive transforms from neutral: no accumulating drift across frames.
	sprite.scale = Vector3.ONE
	var dead: bool = pose == "defeated"
	if aura != null:
		aura.visible = not dead
		var pulse: float = 0.5 + 0.5 * sin(clock * 2.2 + _phase)
		aura.scale = Vector3.ONE * (1.0 + pulse * 0.06)
		(aura.material_override as ShaderMaterial).set_shader_parameter("energy", 0.55 + pulse * 0.12 + (0.22 if windup > 0 else 0.0))
	if dead:
		sprite.modulate = Color("8d909b")
		return
	var breath: float = sin(clock * (2.0 if species == "guardian" else 3.0) + _phase)
	if pose == "idle" or (species == "dusk_bat" and pose in ["walk_a", "walk_b"]):
		sprite.scale.y = 1.0 + breath * (0.008 if species == "guardian" else 0.014)
		sprite.scale.x = 1.0 - breath * 0.005
	if windup > _last_windup:
		_windup_total = windup
	_last_windup = windup
	if swing > _last_swing:
		_swing_total = swing
	_last_swing = swing
	if windup > 0:
		var progress: float = 1.0 - windup / maxf(_windup_total, 0.0001)
		var k: float = lerpf(WINDUP_START, 1.0, sin(clampf(progress, 0.0, 1.0) * PI * 0.5))
		sprite.scale = Vector3.ONE.lerp(WINDUP_SQUASH, k)
	elif swing > 0:
		var decay: float = exp(-(_swing_total - swing) * SWING_DECAY)
		sprite.scale = Vector3.ONE + SWING_STRETCH * decay
	elif pose == "recover":
		sprite.scale = RECOVER_SQUASH
	if species == "dusk_bat":
		sprite.position.y += 0.50 + sin(clock * 7.0 + _phase) * 0.065 - (0.14 if swing > 0 else 0.0)
		if shadow != null:
			shadow.scale = Vector3.ONE * (1.0 + sin(clock * 7.0 + _phase) * 0.035)
	# Short readable hit tint that fades out, without clipping colors to white.
	sprite.modulate = Color.WHITE.lerp(HURT_TINT, clampf(hurt / HURT_TIME, 0.0, 1.0))
