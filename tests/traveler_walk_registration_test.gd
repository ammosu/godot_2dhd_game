extends SceneTree
## Default traveler walk registration: both foot contacts dip evenly below the
## neutral head (no limp) and diagonal contact B keeps the neutral head size.
## Reads wanderer_steady_frames.tres metadata only; no saves, no rendering.
const Proportions = preload("res://scripts/gameplay/character_proportions.gd")
const FRAMES: SpriteFrames = preload("res://assets/generated/wanderer_steady_frames.tres")
const GROUND: float = 316.0
const STANDING_REFERENCE: float = 290.0
const MAX_CONTACT_SPREAD: float = 3.0
const MAX_WIDTH_ERROR: float = 3.0
var _failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _check(ok: bool, message: String) -> void:
	if not ok:
		_failures += 1
		push_error(message)


## Crown row, head width (70th percentile widest run) and head centroid x, in
## canvas pixels, matching tools/art/repair_diagonal_stride.py head_metrics().
func _head(texture: AtlasTexture) -> Vector3:
	var image := texture.atlas.get_image()
	var region := Rect2i(texture.region)
	var top: int = -1
	for y: int in range(region.size.y):
		var count: int = 0
		for x: int in range(region.size.x):
			if image.get_pixel(region.position.x + x, region.position.y + y).a >= 0.5:
				count += 1
		if count >= 6:
			top = y
			break
	var span: float = GROUND - texture.margin.position.y - top
	var widths: Array[int] = []
	var sum_x: float = 0.0
	var samples: int = 0
	for y: int in range(top + int(span * 0.06), top + int(span * 0.18)):
		var run: int = 0
		var widest: int = 0
		for x: int in range(region.size.x):
			if image.get_pixel(region.position.x + x, region.position.y + y).a >= 0.5:
				run += 1
				widest = maxi(widest, run)
				sum_x += x
				samples += 1
			else:
				run = 0
		widths.append(widest)
	widths.sort()
	return Vector3(top + texture.margin.position.y, widths[int(widths.size() * 0.7)], sum_x / samples + texture.margin.position.x)


func _run() -> void:
	for animation: StringName in FRAMES.get_animation_names():
		var neutral := FRAMES.get_frame_texture(animation, 0) as AtlasTexture
		_check(not neutral.has_meta("width_scale"), "%s neutral frame must keep runtime fitting" % animation)
		var standing := Proportions.profile(neutral, STANDING_REFERENCE)
		var base := _head(neutral)
		var contacts: Array[float] = []
		for frame: int in range(1, FRAMES.get_frame_count(animation)):
			var texture := FRAMES.get_frame_texture(animation, frame) as AtlasTexture
			if texture == neutral:
				continue
			_check(texture.has_meta("walk_registration") and texture.has_meta("body_height") and texture.has_meta("width_scale"), "%s/%d lacks registration" % [animation, frame])
			var wanted: Vector2 = texture.get_meta("walk_registration")
			# player.gd: pixel_size = height / body_height, scale.x = width_scale.
			var scale_y: float = standing.x / float(texture.get_meta("body_height"))
			var scale_x: float = scale_y * float(texture.get_meta("width_scale")) / standing.y
			_check(absf(scale_y - wanted.y) < 0.002 and absf(scale_x - wanted.x) < 0.002, "%s/%d metadata disagrees with runtime standing fit: %s vs %s" % [animation, frame, Vector2(scale_x, scale_y), wanted])
			_check(absf(scale_y - 1.0) < 0.08 and scale_x / scale_y >= 0.899 and scale_x / scale_y <= 1.061, "%s/%d rescale too strong" % [animation, frame])
			var head := _head(texture)
			var top: float = GROUND - (GROUND - head.x) * scale_y
			var width: float = head.y * scale_x
			var center: float = 176.0 + (head.z - 176.0) * scale_x
			_check(absf(width - base.y) <= MAX_WIDTH_ERROR, "%s/%d head width %.1f vs neutral %.1f" % [animation, frame, width, base.y])
			_check(absf(center - base.z) <= 1.5, "%s/%d head drifts sideways %.1f vs %.1f" % [animation, frame, center, base.z])
			_check(is_equal_approx(float(texture.get_meta("ground_y")), GROUND) and texture.get_size() == Vector2(352, 352), "%s/%d moved the foot canvas" % [animation, frame])
			if frame == 2:
				_check(absf(top - base.x) <= 1.0, "%s passing head should match neutral" % animation)
			else:
				contacts.append(top)
				_check(top > base.x and top - base.x <= MAX_CONTACT_SPREAD + 1.0, "%s/%d contact should dip slightly below neutral: %.1f vs %.1f" % [animation, frame, top, base.x])
		_check(contacts.size() == 2 and absf(contacts[0] - contacts[1]) <= MAX_CONTACT_SPREAD, "%s contacts limp: %s" % [animation, contacts])
	if _failures == 0:
		print("TRAVELER_WALK_REGISTRATION_TEST_PASS eight_facings_even_contacts")
	quit(1 if _failures else 0)
