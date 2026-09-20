extends Node3D
## Temporary presentation on the actual elder; never owns quest state.

const SHEET = preload("res://assets/generated/elder_seal_motion.png")
const REGIONS: Array[Rect2] = [Rect2(129, 84, 416, 735), Rect2(683, 83, 417, 735), Rect2(1258, 79, 421, 739)]
var last_reveal_page: int = 3
var pose_index: int = -1
var _actor: Sprite3D
var _original: Texture2D
var _pixel_size: float
var _offset: Vector2
var _elapsed: float = 0.0
var _frames: Array[AtlasTexture] = []


func bind_actor(actor: Sprite3D) -> void:
	_actor = actor
	_original = actor.texture
	_pixel_size = actor.pixel_size
	_offset = actor.offset
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
		_set_pose(0)
	elif not showing:
		_restore()
	visible = showing


func _process(delta: float) -> void:
	if visible:
		_elapsed += delta
		_set_pose(mini(2, int(_elapsed / 0.24)))


func _set_pose(index: int) -> void:
	if index == pose_index or not is_instance_valid(_actor):
		return
	pose_index = index
	_actor.texture = _frames[index]
	_actor.pixel_size = _pixel_size * 620.0 / 739.0
	# Original elder alpha bounds are x=236..586 inside a 724px atlas cell.
	# Preserve that visible center, not the center of the original empty padding.
	_actor.offset = Vector2((_offset.x + 49.0) * _pixel_size / _actor.pixel_size, 739.0 * 0.5)


func _restore() -> void:
	pose_index = -1
	if is_instance_valid(_actor) and _original != null:
		_actor.texture = _original
		_actor.pixel_size = _pixel_size
		_actor.offset = _offset


func _exit_tree() -> void:
	_restore()
