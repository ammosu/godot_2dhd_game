extends Node3D
## Depth-tested original raster effects, advanced only by the combat clock.
const Facing = preload("res://scripts/gameplay/eight_way_facing.gd")
var sprite := Sprite3D.new()
var age: float = 0.0
var lifetime: float = 0.48
var kind: String
var sheet: Texture2D
var animated: bool = false
var first_frame: int = 0
var _sparks: Array[Sprite3D] = []
var _wave: MeshInstance3D
var _radius: float = 1.0
var _halo: MeshInstance3D
var _tint := Color("ffe5a1")

func configure(effect: String, point: Vector3, radius: float, direction: Vector2, camera: Camera3D) -> void:
	kind = effect
	_radius = radius
	position = point
	add_child(sprite)
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.shaded = false
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var size: float = 1.8
	match kind:
		"impact":
			sheet = preload("res://assets/generated/sword_slash.png")
			lifetime = 0.28
			size = 0.8
		"frost", "bolt", "heal":
			var file: String = "frost_nova" if kind == "frost" else "moon_bolt" if kind == "bolt" else "moon_heal"
			sheet = load("res://assets/generated/%s.png" % file) as Texture2D
			animated = true
			first_frame = 0 if kind == "heal" else 1
			lifetime = 0.64 if kind == "heal" else 0.48
			size = radius * 2.0 if kind == "frost" else 2.0
		"ward":
			sheet = preload("res://assets/generated/moon_ward.png")
			size = 2.25
			lifetime = 0.8
		"moon_slash", "spear", "claw":
			sheet = load("res://assets/generated/%s_hit.tres" % kind) as Texture2D
			size = radius * 1.8 if kind == "moon_slash" else 1.4
			lifetime = 0.24
		_:
			sheet = preload("res://assets/generated/sword_slash.png")
			lifetime = 0.24
	sprite.pixel_size = size / (sheet.get_width() * (0.5 if animated else 1.0))
	if kind in ["heal", "ward"]:
		sprite.position.y = size * 0.3
	else:
		sprite.position.y = 0.7
	var screen: Vector2 = Facing.screen_direction(Vector3(direction.x, 0, direction.y), camera)
	sprite.flip_h = screen.x < 0
	_tint = Color("9feaff") if kind in ["moon_slash", "frost", "bolt"] else Color("9fffc8") if kind == "heal" else Color("b8ceff") if kind == "ward" else Color("ffe5a1")
	_build_sparks()
	if kind in ["moon_slash", "frost", "heal", "ward"]:
		_wave = preload("res://scripts/gameplay/combat_ground_ring.gd").new()
		_wave.configure(radius, _tint, 0.07)
		add_child(_wave)
	if kind in ["frost", "heal", "ward", "bolt"]:
		_halo = preload("res://scripts/gameplay/combat_ground_ring.gd").new()
		_halo.configure(maxf(0.6, radius * 0.65), _tint, 0.035)
		add_child(_halo)
	_update_frame()

func advance(delta: float) -> void:
	age += delta
	if age >= lifetime:
		queue_free()
		return
	_update_frame()
	var progress: float = age / lifetime
	sprite.modulate.a = clampf((lifetime - age) / 0.16, 0.0, 1.0)
	if kind in ["slash", "moon_slash", "spear", "claw", "impact"]:
		sprite.scale = Vector3.ONE * lerpf(0.75, 1.18, sin(progress * PI * 0.5))
	for index: int in range(_sparks.size()):
		var angle: float = TAU * float(index) / float(_sparks.size()) + float(index % 3) * 0.19
		var eased: float = 1.0 - pow(1.0 - progress, 3.0)
		var distance: float = eased * maxf(0.7, _radius) * (0.55 + float(index % 4) * 0.17)
		var rising: bool = kind in ["heal", "ward", "frost"]
		if rising:
			angle += progress * 2.0
		_sparks[index].position = Vector3(cos(angle) * distance, 0.5 + (progress * 2.2 + float(index % 3) * 0.2 if rising else sin(angle) * distance * 0.7 - progress * progress * 0.4), sin(angle) * distance * 0.6)
		_sparks[index].modulate.a = (1.0 - progress) * 0.9
		_sparks[index].scale = Vector3.ONE * (1.0 - progress * 0.8)
	if is_instance_valid(_wave):
		_wave.scale = Vector3.ONE * lerpf(0.2, 1.15, progress)
		(_wave.material_override as StandardMaterial3D).albedo_color.a = (1.0 - progress) * 0.7
	if is_instance_valid(_halo):
		_halo.position.y = 0.1 + progress * 1.7
		_halo.scale = Vector3.ONE * lerpf(0.35, 1.0, sin(progress * PI))
		(_halo.material_override as StandardMaterial3D).albedo_color.a = sin(progress * PI) * 0.55

func _update_frame() -> void:
	if not animated:
		sprite.texture = sheet
		return
	var frame: int = mini(3, first_frame + int(age / 0.16))
	var texture := AtlasTexture.new()
	texture.atlas = sheet
	var cell: Vector2 = sheet.get_size() * 0.5
	texture.region = Rect2(Vector2(frame % 2, frame / 2) * cell, cell)
	texture.filter_clip = true
	sprite.texture = texture


func _build_sparks() -> void:
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color.WHITE, Color.WHITE])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 16
	texture.height = 4
	for index: int in range(18 if kind in ["frost", "moon_slash"] else 10):
		var spark := Sprite3D.new()
		spark.texture = texture
		spark.pixel_size = 0.012 if kind in ["heal", "ward"] else 0.019
		spark.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		spark.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		spark.shaded = false
		spark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		spark.modulate = _tint
		spark.rotation.z = TAU * float(index) / 10.0
		spark.position.y = 0.7
		add_child(spark)
		_sparks.append(spark)
