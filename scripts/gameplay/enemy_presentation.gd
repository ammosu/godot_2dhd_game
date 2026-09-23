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
	if windup > 0:
		sprite.scale = Vector3(1.025, 0.975, 1.0)
	elif swing > 0:
		sprite.scale = Vector3(1.035, 1.015, 1.0)
	if species == "dusk_bat":
		sprite.position.y += 0.50 + sin(clock * 7.0 + _phase) * 0.065 - (0.14 if swing > 0 else 0.0)
		if shadow != null:
			shadow.scale = Vector3.ONE * (1.0 + sin(clock * 7.0 + _phase) * 0.035)
	# Short readable hit flash without clipping the sprite's colors to white.
	sprite.modulate = Color(1.35, 1.16, 1.12) if hurt > 0.10 else Color.WHITE
