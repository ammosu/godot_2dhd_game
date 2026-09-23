extends RefCounted
## Eight true perspectives, clockwise from front through the right profile.
const DATA: Dictionary = preload("res://assets/generated/enemy_movement/regions.gd").DATA
const POSES: Array[String] = ["idle", "walk_a", "walk_b"]
static var _cache: Dictionary[String, AtlasTexture] = {}

static func supports(actor: String, pose: String) -> bool:
	return DATA.has(actor) and pose in POSES

static func direction(screen: Vector2, previous: int = -1) -> int:
	if screen.is_zero_approx():
		return previous if previous >= 0 else 0
	var angle: float = PI * 0.5 - screen.angle()
	# A small dead band keeps path/camera jitter from flickering between frames.
	if previous >= 0 and absf(wrapf(angle - previous * PI / 4.0, -PI, PI)) < PI / 8.0 + deg_to_rad(6.0):
		return previous
	return posmod(roundi(angle / (PI / 4.0)), 8)

static func texture_for(actor: String, pose: String, facing: int) -> AtlasTexture:
	var key: String = "%s:%s:%d" % [actor, pose, facing]
	if _cache.has(key):
		return _cache[key]
	var data: Dictionary = DATA[actor]
	var row: int = facing
	var sheet: String = actor
	if actor == "dusk_bat" and facing in [3, 5]:
		data = data.rear
		row = 0 if facing == 3 else 1
		sheet = "dusk_bat_rear"
	var box: Array = data.frames[row * 3 + POSES.find(pose)]
	var texture := AtlasTexture.new()
	texture.atlas = load("res://assets/generated/enemy_movement/%s.png" % sheet)
	texture.region = Rect2(box[0], box[1], box[2], box[3])
	texture.filter_clip = true
	texture.set_meta("ground_y", float(box[3]))
	texture.set_meta("anchor_x", float(box[4]))
	var height: float = 0.8 if actor == "dusk_bat" else 1.45 if actor == "moss_wolf" else 1.88 if actor == "guardian" else 3.35 if actor == "ash_warden" else 1.575
	texture.set_meta("pixel_size", height / float(data.frames[row * 3][3]))
	texture.set_meta("movement_facing", facing)
	texture.set_meta("pose", pose)
	_cache[key] = texture
	return texture

static func walk_pose(clock: float) -> String:
	return ["walk_a", "idle", "walk_b", "idle"][posmod(int(clock * 10.0), 4)]
