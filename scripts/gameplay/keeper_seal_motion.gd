extends Node3D
## Temporary presentation on the actual elder; never owns quest state.

const SHEET = preload("res://assets/generated/elder_seal_motion.png")
const REGIONS: Array[Rect2] = [Rect2(129, 84, 416, 735), Rect2(683, 83, 417, 735), Rect2(1258, 79, 421, 739)]
## Anticipation reads longer than the raise; the final seal pose is held.
const POSE_HOLD_SECONDS: Array[float] = [0.30, 0.18]
## Lower the seal through the raise pose before standing again.
const RELEASE_SECONDS: float = 0.15
var last_reveal_page: int = 3
var pose_index: int = -1
var _actor: Sprite3D
var _original: Texture2D
var _pixel_size: float
var _offset: Vector2
var _visible_height: float
var _visible_center_x: float
var _elapsed: float = 0.0
var _releasing: float = 0.0
var _frames: Array[AtlasTexture] = []


func bind_actor(actor: Sprite3D) -> void:
	# The elder may still be holding a conversation pose; capture the idle one.
	if actor.has_method("snap_to_idle"):
		actor.call("snap_to_idle")
	_actor = actor
	_original = actor.texture
	_pixel_size = actor.pixel_size
	_offset = actor.offset
	var bounds := _original.get_image().get_used_rect()
	_visible_height = float(_original.get_meta("visible_height", bounds.size.y))
	_visible_center_x = bounds.get_center().x - _original.get_width() * 0.5
	for region: Rect2 in REGIONS:
		var frame := AtlasTexture.new()
		frame.atlas = SHEET
		frame.region = region
		frame.margin = Rect2((460.0 - region.size.x) * 0.5, 739.0 - region.size.y, 460.0 - region.size.x, 739.0 - region.size.y)
		frame.filter_clip = true
		_frames.append(frame)


func _ready() -> void:
	name = "KeeperSealMotion"
	add_to_group("moon_seal_presentations")
	hide()


func show_for_page(index: int) -> void:
	var showing: bool = index >= 2 and index <= last_reveal_page
	if showing and not visible:
		_elapsed = 0.0
		_releasing = 0.0
		_set_pose(0)
	elif not showing and pose_index == 2:
		_releasing = RELEASE_SECONDS
		_set_pose(1)
	elif not showing and _releasing <= 0.0:
		_restore()
	visible = showing


func _process(delta: float) -> void:
	if visible:
		_elapsed += delta
		_set_pose(scheduled_pose(_elapsed))
	elif _releasing > 0.0:
		_releasing -= delta
		if _releasing <= 0.0:
			_restore()


static func scheduled_pose(elapsed: float) -> int:
	var start: float = 0.0
	for index: int in range(POSE_HOLD_SECONDS.size()):
		start += POSE_HOLD_SECONDS[index]
		if elapsed < start:
			return index
	return POSE_HOLD_SECONDS.size()


func _set_pose(index: int) -> void:
	if index == pose_index or not is_instance_valid(_actor):
		return
	if index == 2 and pose_index < 2 and _actor.get_node_or_null("BodyLife") != null:
		_actor.get_node("BodyLife").call("acknowledge") # Small settle on the seal impact.
	pose_index = index
	_actor.texture = _frames[index]
	_actor.pixel_size = _pixel_size * _visible_height / 739.0
	# Preserve visible world size/center across atlases with different resolutions.
	_actor.offset = Vector2((_offset.x + _visible_center_x) * _pixel_size / _actor.pixel_size, 739.0 * 0.5)


func _restore() -> void:
	_releasing = 0.0
	pose_index = -1
	if is_instance_valid(_actor) and _original != null:
		_actor.texture = _original
		_actor.pixel_size = _pixel_size
		_actor.offset = _offset


func _exit_tree() -> void:
	_restore()
