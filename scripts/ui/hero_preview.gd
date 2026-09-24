extends Control
## UI-only animation playback. Never writes to GameState or runs combat commands.
const Style = preload("res://scripts/gameplay/hero_style.gd")
var body_id: String = "male"
var style_id: String = "original"
const Art = preload("res://scripts/gameplay/action_sprite_library.gd")
const Equipment = preload("res://scripts/systems/class_equipment.gd")
const Classes = preload("res://scripts/systems/hero_classes.gd")
const SEQUENCES: Dictionary = {
	"idle": ["idle"],
	"walk": ["idle", "walk_a", "idle", "walk_b"],
	"attack": ["windup", "windup", "attack", "attack", "recover", "recover", "idle", "idle"],
	"cast": ["cast", "cast", "release", "release", "recover", "idle", "idle", "idle"],
	"dodge": ["idle", "dodge_a", "dodge_a", "dodge_b", "dodge_b", "recover", "idle", "idle"],
}
var class_id: String = "traveler"
var action: String = "idle"
var facing: int = 0
var playing: bool = true
var elapsed: float = 0.0
var current_pose: String = "idle"
var _sprite := Sprite2D.new()
var _last_key: String = ""
var _foot_centers: Dictionary[AtlasTexture, float] = {}

func _ready() -> void:
	custom_minimum_size = Vector2(280, 280)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_sprite)
	resized.connect(_refresh)
	_refresh()

func configure(vocation: String, motion: String = "idle", direction: int = 0) -> void:
	if not Classes.DATA.has(vocation) or not SEQUENCES.has(motion):
		return
	class_id = vocation
	action = motion
	facing = clampi(direction, 0, 3)
	elapsed = 0.0
	_last_key = ""
	if is_inside_tree():
		_refresh()

func _process(delta: float) -> void:
	if not is_visible_in_tree() or not playing:
		return
	elapsed += delta
	_refresh()

func _refresh() -> void:
	var sequence: Array = SEQUENCES[action]
	current_pose = str(sequence[int(elapsed * 6.0) % sequence.size()])
	var key := "%s:%s:%s:%d" % [body_id, class_id, current_pose, facing]
	var loadout := Equipment.defaults(class_id)
	loadout["hero_body"] = body_id
	if key != _last_key:
		_last_key = key
		_sprite.texture = Art.texture_for("wanderer", current_pose, facing, loadout)
	var texture := _sprite.texture as AtlasTexture
	var idle := Art.texture_for("wanderer", "idle", facing, loadout)
	var factor: float = minf((size.y - 60.0) / float(texture.get_meta("body_height", idle.get_height())), (size.x - 40.0) / (float(texture.get_meta("body_height", idle.get_height())) * 1.55))
	Style.apply_canvas(_sprite, texture, style_id)
	_sprite.scale = Vector2.ONE * factor
	_sprite.offset = Vector2(texture.get_width() * 0.5 - _foot_center(texture), texture.get_height() * 0.5 - float(texture.get_meta("ground_y")))
	_sprite.flip_h = bool(texture.get_meta("flip_h", false))
	if _sprite.flip_h:
		_sprite.offset.x *= -1.0
	_sprite.position = Vector2(size.x * 0.5, size.y - 35.0)
	queue_redraw()

func _foot_center(texture: AtlasTexture) -> float:
	if _foot_centers.has(texture):
		return _foot_centers[texture]
	var image: Image = texture.atlas.get_image()
	if image.is_compressed() and image.decompress() != OK:
		return float(texture.get_meta("anchor_x"))
	var region := Rect2i(texture.region)
	var left: int = region.end.x
	var right: int = region.position.x - 1
	# Sample only the soles. The atlas anchor uses the lowest 9% of the
	# silhouette, which also catches lowered swords and shifts the body.
	var sole_height: int = maxi(2, int(region.size.y * 0.02))
	for y: int in range(region.end.y - sole_height, region.end.y):
		for x: int in range(region.position.x, region.end.x):
			if image.get_pixel(x, y).a > 100.0 / 255.0:
				left = mini(left, x)
				right = maxi(right, x)
	var center: float = (left + right) * 0.5 - region.position.x if right >= left else float(texture.get_meta("anchor_x"))
	_foot_centers[texture] = center
	return center

func _draw() -> void:
	var tint: Color = Classes.profile(class_id).color
	var ground := Vector2(size.x * 0.5, size.y - 33.0)
	draw_style_box(_background(), Rect2(Vector2.ZERO, size))
	draw_set_transform(ground, 0, Vector2(1, 0.3))
	draw_circle(Vector2.ZERO, minf(100.0, size.x * 0.28), Color(0.03, 0.06, 0.09, 0.9))
	draw_arc(Vector2.ZERO, minf(105.0, size.x * 0.29), 0, TAU, 64, Color(tint, 0.5), 2.0, true)
	draw_set_transform(Vector2.ZERO)

func _background() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("152b3c")
	style.border_color = Color("476074")
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	return style
