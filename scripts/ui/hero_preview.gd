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
const MOONLIT := preload("res://assets/generated/class_selection_moonlit.png")
var _sprite := Sprite2D.new()
var _last_key: String = ""
var _verse: Label
var _foot_centers: Dictionary[AtlasTexture, float] = {}

func _ready() -> void:
	custom_minimum_size = Vector2(280, 280)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_verse = Label.new()
	_verse.text = "微小的光，\n也能照亮\n遙遠的路。"
	_verse.position = Vector2(28, 35)
	_verse.add_theme_font_override("font", GameState.title_font)
	_verse.add_theme_font_size_override("font_size", 16)
	_verse.add_theme_color_override("font_color", Color("99b7cc"))
	_verse.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_verse)
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
	_verse.visible = size.x > 580
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
	var factor: float = minf((size.y * 0.67) / float(texture.get_meta("body_height", idle.get_height())), (size.x - 40.0) / (float(texture.get_meta("body_height", idle.get_height())) * 1.55))
	Style.apply_canvas(_sprite, texture, style_id)
	_sprite.scale = Vector2.ONE * factor
	_sprite.offset = Vector2(texture.get_width() * 0.5 - _foot_center(texture), texture.get_height() * 0.5 - float(texture.get_meta("ground_y")))
	_sprite.flip_h = bool(texture.get_meta("flip_h", false))
	if _sprite.flip_h:
		_sprite.offset.x *= -1.0
	_sprite.position = Vector2(size.x * 0.5, size.y - 42.0)
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
	var ground := Vector2(size.x * 0.5, size.y - 41.0)
	draw_texture_rect(MOONLIT, Rect2(Vector2.ZERO, size), false)
	draw_set_transform(ground, 0, Vector2(1, 0.22))
	var radius: float = size.x * 0.30
	draw_circle(Vector2.ZERO, radius, Color(0.03, 0.06, 0.09, 0.65))
	for ring: float in [0.88, 1.08, 1.38]:
		draw_arc(Vector2.ZERO, radius * ring, 0, TAU, 100, Color(0.91, 0.76, 0.48, 0.68), 1.4, true)
	draw_set_transform(Vector2.ZERO)
	for index: int in range(9):
		var angle: float = TAU * index / 9.0
		var point := ground + Vector2(cos(angle) * radius * 1.38, sin(angle) * radius * 1.38 * 0.22)
		draw_line(point - Vector2(4, 0), point + Vector2(4, 0), Color("e8c889"), 1, true)
		draw_line(point - Vector2(0, 4), point + Vector2(0, 4), Color("e8c889"), 1, true)
	var border := StyleBoxFlat.new()
	border.bg_color = Color.TRANSPARENT
	border.border_color = Color("a08a62")
	border.set_border_width_all(1)
	border.set_corner_radius_all(8)
	draw_style_box(border, Rect2(Vector2.ZERO, size))
	for point: Vector2 in [Vector2(7, 7), Vector2(size.x - 7, 7), Vector2(7, size.y - 7), size - Vector2(7, 7)]:
		draw_arc(point, 5, 0, TAU, 12, Color("b39a6c"), 1, true)
