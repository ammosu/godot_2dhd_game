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

func configure(effect: String, point: Vector3, radius: float, direction: Vector2, camera: Camera3D) -> void:
	kind = effect
	position = point
	add_child(sprite)
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.shaded = false
	sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var size: float = 1.8
	match kind:
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
	_update_frame()

func advance(delta: float) -> void:
	age += delta
	if age >= lifetime:
		queue_free()
		return
	_update_frame()
	sprite.modulate.a = clampf((lifetime - age) / 0.16, 0.0, 1.0)

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
