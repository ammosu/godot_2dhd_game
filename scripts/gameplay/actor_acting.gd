extends Node
## Procedural acting for a standing billboard: short body beats (a startled hop,
## a nod, laughter, a shiver) and an emote bubble above the head. Presentation
## only; cutscenes, dialogue and combat barks all drive it the same way.
##
## Channels: sprite.position.y (and x for sideways beats) while a beat plays (captured at its start and
## restored exactly when it ends), BodyLife dips for nods so scale.y keeps one owner,
## and a sibling Label3D for the bubble. Owners that rewrite position every
## frame (player.gd re-anchors y) are fine: the beat writes later, in _process.
## Do not play a beat on a sprite whose x is being shivered by hit feedback.

const BodyLife = preload("res://scripts/gameplay/body_life.gd")
const SpriteGrounding = preload("res://scripts/gameplay/sprite_grounding.gd")
const FONT: Font = preload("res://assets/fonts/SourceHanSansTW-Regular.otf")

## Body beats: duration in seconds.
const BEATS: Dictionary[StringName, float] = {
	&"surprise": 0.34,
	&"hop": 0.3,
	&"joy": 0.62,
	&"laugh": 0.66,
	&"nod": 0.5,
	&"shiver": 0.6,
	&"recoil": 0.32,
}
## Beats that also sway sideways (x); the rest only write y.
const SIDEWAYS_BEATS: Array[StringName] = [&"shiver", &"recoil"]
## Bubble text and color per emote.
const EMOTES: Dictionary[StringName, Array] = {
	&"exclaim": ["!", Color("ffe08a")],
	&"question": ["?", Color("bfe4ff")],
	&"ellipsis": ["…", Color("e8e2d6")],
	&"music": ["♪", Color("ffc6e0")],
	&"shock": ["!?", Color("ffb36b")],
	&"heart": ["♥", Color("ff9ab8")],
}
## Beats that pop a matching bubble unless the caller names another one.
const DEFAULT_EMOTE: Dictionary[StringName, StringName] = {&"surprise": &"exclaim", &"laugh": &"music"}
const EMOTE_SECONDS: float = 1.4
const EMOTE_POP_SECONDS: float = 0.18
const EMOTE_FADE_SECONDS: float = 0.25
## Used when a sprite cannot report its own height.
const DEFAULT_HEAD_HEIGHT: float = 1.75

## Visible body height in texture rows, per texture instance.
static var _visible_rows: Dictionary[int, float] = {}

var _sprite: SpriteBase3D
var _beat: StringName = &""
var _beat_time: float = 0.0
var _second_nod_done: bool = false
var _base_position: Vector3 = Vector3.ZERO
var _bubble: Label3D
var _bubble_time: float = 0.0
var _bubble_seconds: float = 0.0


func _init() -> void:
	name = "Acting"


func _ready() -> void:
	_sprite = get_parent() as SpriteBase3D


## Returns the sprite's acting component, adding one on first use.
static func ensure(sprite: SpriteBase3D) -> Node:
	var existing: Node = find(sprite)
	if existing != null:
		return existing
	var acting: Node = load("res://scripts/gameplay/actor_acting.gd").new()
	sprite.add_child(acting)
	return acting


static func find(sprite: Node) -> Node:
	return sprite.get_node_or_null("Acting") if sprite != null else null


## Play a body beat; an empty or unknown kind only shows the emote. emote_kind
## overrides the beat's default bubble, and &"none" suppresses it.
func act(kind: StringName, emote_kind: StringName = &"") -> void:
	if BEATS.has(kind):
		if _beat.is_empty():
			_base_position = _sprite.position
		else:
			clear_beat()
		_beat = kind
		_beat_time = 0.0
		_second_nod_done = false
		if kind == &"nod":
			_nod()
	elif not kind.is_empty():
		push_warning("Unknown acting beat: %s" % kind)
	var bubble: StringName = emote_kind if not emote_kind.is_empty() else DEFAULT_EMOTE.get(kind, &"")
	if bubble != &"none" and not bubble.is_empty():
		emote(bubble)


func emote(kind: StringName, seconds: float = EMOTE_SECONDS) -> void:
	if not EMOTES.has(kind):
		push_warning("Unknown emote: %s" % kind)
		return
	if not is_instance_valid(_bubble):
		_bubble = Label3D.new()
		_bubble.name = "Emote"
		_bubble.font = FONT
		_bubble.font_size = 72
		_bubble.outline_size = 14
		_bubble.outline_modulate = Color("1b1622")
		_bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_bubble.no_depth_test = true
		_bubble.render_priority = 4
		_bubble.outline_render_priority = 3
		_bubble.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
		# A sibling of the sprite: unaffected by breathing, nods or hop offsets.
		var host: Node = _sprite.get_parent() if _sprite.get_parent() != null else _sprite
		host.add_child(_bubble)
	var entry: Array = EMOTES[kind]
	_bubble.text = str(entry[0])
	_bubble.modulate = entry[1]
	_bubble.set_meta("emote", kind)
	_bubble.position = _sprite.position * Vector3(1.0, 0.0, 1.0) + Vector3.UP * (_head_height() + 0.3)
	_bubble.scale = Vector3.ONE * 0.01
	_bubble.visible = true
	_bubble_time = 0.0
	_bubble_seconds = seconds


func current_beat() -> StringName:
	return _beat


func current_emote() -> StringName:
	return StringName(_bubble.get_meta("emote", &"")) if is_instance_valid(_bubble) and _bubble.visible else &""


func is_acting() -> bool:
	return not _beat.is_empty() or not current_emote().is_empty()


## Stop at once and hand the sprite back at rest (skips, map changes).
func clear() -> void:
	clear_beat()
	if is_instance_valid(_bubble):
		_bubble.visible = false


func clear_beat() -> void:
	if not _beat.is_empty():
		_sprite.position.y = _base_position.y
		if SIDEWAYS_BEATS.has(_beat):
			_sprite.position.x = _base_position.x
		_beat = &""


## Height of the visible head above the feet, ignoring transparent atlas margins.
func _head_height() -> float:
	var owner_body: Node = _sprite.get_parent()
	if owner_body != null and owner_body.has_method("presentation_height"):
		return float(owner_body.call("presentation_height"))
	var texture: Texture2D = _current_texture()
	if texture == null:
		return DEFAULT_HEAD_HEIGHT
	var key: int = texture.get_instance_id()
	if not _visible_rows.has(key):
		_visible_rows[key] = _measure_visible_rows(texture)
	var pixels: float = float(_visible_rows[key])
	var height: float = pixels * _sprite.pixel_size * _sprite.scale.y
	return height if height > 0.4 and height < 6.0 else DEFAULT_HEAD_HEIGHT


func _current_texture() -> Texture2D:
	if _sprite is Sprite3D:
		return (_sprite as Sprite3D).texture
	if _sprite is AnimatedSprite3D:
		var animated := _sprite as AnimatedSprite3D
		return animated.sprite_frames.get_frame_texture(animated.animation, animated.frame) if animated.sprite_frames != null else null
	return null


## Rows from the topmost opaque pixel to the feet baseline.
static func _measure_visible_rows(texture: Texture2D) -> float:
	var image: Image
	var region: Rect2i
	var margin_y: float = 0.0
	if texture is AtlasTexture:
		image = (texture as AtlasTexture).atlas.get_image()
		region = Rect2i((texture as AtlasTexture).region)
		margin_y = (texture as AtlasTexture).margin.position.y
	else:
		image = texture.get_image()
		region = Rect2i(Vector2i.ZERO, image.get_size())
	if image == null:
		return 0.0
	if image.is_compressed():
		image = image.duplicate() as Image
		if image.decompress() != OK:
			return 0.0
	var baseline: float = SpriteGrounding.foot_baseline(texture)
	for y: int in range(region.position.y, region.end.y):
		for x: int in range(region.position.x, region.end.x, 2):
			if image.get_pixel(x, y).a >= 0.25:
				return baseline - float(y - region.position.y) - margin_y
	return 0.0


func _nod() -> void:
	var life: Node = BodyLife.find(_sprite)
	if life != null:
		life.call("acknowledge")


## Vertical and sideways offset (meters) of a beat at time t.
static func beat_offset(kind: StringName, t: float) -> Vector2:
	var length: float = BEATS.get(kind, 0.0)
	if t >= length:
		return Vector2.ZERO
	var u: float = t / length
	match kind:
		&"surprise":
			return Vector2(0.0, 0.2 * sin(PI * u))
		&"hop":
			return Vector2(0.0, 0.12 * sin(PI * u))
		&"joy":
			return Vector2(0.0, 0.26 * absf(sin(TAU * u)))
		&"laugh":
			return Vector2(0.0, 0.05 * absf(sin(3.0 * PI * u)))
		&"shiver":
			return Vector2(0.03 * sin(t * 70.0) * (1.0 - u), 0.0)
		&"recoil":
			return Vector2(0.05 * sin(t * 55.0) * (1.0 - u), 0.08 * sin(PI * u))
	return Vector2.ZERO


func _process(delta: float) -> void:
	if _sprite == null:
		return
	if not _beat.is_empty():
		_beat_time += delta
		if _beat == &"nod" and not _second_nod_done and _beat_time >= 0.25:
			_second_nod_done = true
			_nod()
		var offset: Vector2 = beat_offset(_beat, _beat_time)
		var finished: bool = _beat_time >= float(BEATS[_beat])
		# Write only the axes this beat animates, leaving hit shivers on x/z alone.
		_sprite.position.y = _base_position.y + offset.y
		if SIDEWAYS_BEATS.has(_beat):
			_sprite.position.x = _base_position.x + offset.x
		if finished:
			_beat = &""
	if is_instance_valid(_bubble) and _bubble.visible:
		_bubble_time += delta
		var pop: float = clampf(_bubble_time / EMOTE_POP_SECONDS, 0.0, 1.0)
		# Overshoot then settle, like a comic bubble springing open.
		var size: float = pop + 0.25 * sin(PI * pop)
		_bubble.scale = Vector3.ONE * maxf(size, 0.01)
		var fade: float = clampf((_bubble_seconds - _bubble_time) / EMOTE_FADE_SECONDS, 0.0, 1.0)
		_bubble.modulate.a = fade
		_bubble.outline_modulate.a = fade
		if _bubble_time >= _bubble_seconds:
			_bubble.visible = false


func _exit_tree() -> void:
	if is_instance_valid(_bubble):
		_bubble.queue_free()
