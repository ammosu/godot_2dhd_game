extends Node3D
## Cosmetic only: rewards are committed by GameState at the moment of defeat.
## Driven by the adapter's combat clock, including its pause and cleanup rules.
const FADE_TIME: float = 0.55
const LIFETIME: float = 1.65
var age: float = 0.0
var _body: Node3D
var _sprite: Sprite3D
var _target: Node3D
var _origin: Vector3
var _orbs: Array[Sprite3D] = []
var _scatter: Array[Vector3] = []

func configure(body: CharacterBody3D, visual: Sprite3D, target: Node3D) -> void:
	_body = body
	_sprite = visual
	_target = target
	_origin = body.global_position + Vector3.UP * 0.8
	body.velocity = Vector3.ZERO
	body.collision_layer = 0
	body.collision_mask = 0
	# A tiny original pixel star with its own halo works without renderer bloom.
	var pixels := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	for y: int in range(16):
		for x: int in range(16):
			var distance: float = Vector2(x - 7.5, y - 7.5).length()
			var alpha: float = maxf(0.0, 1.0 - distance / 8.0) * 0.3
			if absf(x - 7.5) + absf(y - 7.5) < 3.0:
				alpha = 1.0
			pixels.set_pixel(x, y, Color(1, 1, 1, alpha))
	var texture := ImageTexture.create_from_image(pixels)
	for index: int in range(9):
		var orb := Sprite3D.new()
		orb.texture = texture
		orb.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		orb.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		orb.shaded = false
		orb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		orb.pixel_size = 0.035
		orb.modulate = Color("ffe8a0") if index % 3 else Color("a5efff")
		add_child(orb)
		orb.global_position = _origin
		orb.hide()
		_orbs.append(orb)
		var angle: float = TAU * index / 9.0
		_scatter.append(Vector3(cos(angle) * 0.8, 0.3 + float(index % 3) * 0.22, sin(angle) * 0.65))

func advance(delta: float) -> void:
	age += delta
	if is_instance_valid(_body):
		if age >= FADE_TIME:
			_body.hide()
		elif is_instance_valid(_sprite):
			_sprite.modulate = Color(1.4, 1.25, 0.9, 1.0 - clampf((age - 0.12) / 0.43, 0.0, 1.0))
			var shadow := _body.get_node_or_null("ContactShadow") as Node3D
			if shadow != null:
				shadow.hide()
	if age >= LIFETIME or not is_instance_valid(_target):
		if is_instance_valid(_body):
			_body.hide()
		queue_free()
		return
	var destination: Vector3 = _target.global_position + Vector3.UP * 0.85
	for index: int in range(_orbs.size()):
		var orb: Sprite3D = _orbs[index]
		var elapsed: float = age - 0.15 - float(index) * 0.035
		orb.visible = elapsed >= 0.0
		if elapsed < 0.0:
			continue
		var scatter_end: Vector3 = _origin + _scatter[index]
		if elapsed < 0.35:
			orb.global_position = _origin.lerp(scatter_end, sin(elapsed / 0.35 * PI * 0.5))
		else:
			var progress: float = clampf((elapsed - 0.35) / 0.8, 0.0, 1.0)
			orb.global_position = scatter_end.lerp(destination, progress * progress)
			orb.global_position.y += sin(progress * PI) * 0.55
			orb.scale = Vector3.ONE * (1.0 - progress * 0.65)
			orb.modulate.a = clampf((1.0 - progress) / 0.12, 0.0, 1.0)
