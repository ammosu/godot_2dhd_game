extends RefCounted
## Class wardrobe atlases shared by field, arena, exploration and portraits.
const Equipment = preload("res://scripts/systems/class_equipment.gd")
const Regions = preload("res://assets/generated/classes/regions.gd")
const Heroines = preload("res://assets/generated/heroines/regions.gd")
const ARCHER_DIAGONALS: SpriteFrames = preload("res://assets/generated/classes/archer_diagonal_frames.tres")
const EightWayFacing = preload("res://scripts/gameplay/eight_way_facing.gd")
const POSES: Array[String] = ["idle", "walk_a", "walk_b", "windup", "attack", "recover", "cast", "release", "dodge_a", "dodge_b", "hurt", "defeated"]
const FACINGS: Dictionary = {"down": 0, "down_right": 1, "right": 1, "up_right": 2, "up": 2, "up_left": 2, "left": 3, "down_left": 3}
static var _textures: Dictionary[String, AtlasTexture] = {}
static var _walk: Dictionary[String, SpriteFrames] = {}

static func vocation(loadout: Dictionary) -> String:
	var id := str(Dictionary(Equipment.ITEMS.get(str(loadout.get("weapon", "")), {})).get("class", ""))
	if str(loadout.get("hero_body", "male")) == "female":
		return "female_" + ("traveler" if id.is_empty() else id)
	return id

static func texture_for(id: String, pose: String, facing: int = 0) -> AtlasTexture:
	var pose_index: int = maxi(0, POSES.find(pose))
	var key := "%s:%d:%d" % [id, pose_index, facing]
	if _textures.has(key):
		return _textures[key]
	if id.begins_with("female_"):
		var entry: Dictionary = Heroines.DATA[id][facing * 12 + pose_index]
		var box: Array = entry.box
		var result := AtlasTexture.new()
		result.atlas = load("res://assets/generated/heroines/%s.png" % str(entry.sheet))
		result.region = Rect2(box[0], box[1], box[2], box[3])
		result.filter_clip = true
		result.set_meta("ground_y", float(box[3]))
		result.set_meta("anchor_x", float(box[4]))
		result.set_meta("foot_center", float(box[4]))
		result.set_meta("body_height", float(entry.body_height))
		result.set_meta("display_height", float(box[3]))
		result.set_meta("pixel_size", 1.575 / float(entry.body_height))
		result.set_meta("pose", pose)
		result.set_meta("facing", facing)
		result.set_meta("variant", "class_" + id)
		result.set_meta("flip_h", bool(entry.flip))
		_textures[key] = result
		return result
	var frames: Array = Regions.DATA[id].frames
	var box: Array = frames[facing * 12 + pose_index]
	var idle: Array = frames[facing * 12]
	var result := AtlasTexture.new()
	result.atlas = load("res://assets/generated/classes/%s.png" % id)
	result.region = Rect2(box[0], box[1], box[2], box[3])
	result.filter_clip = true
	result.set_meta("ground_y", float(box[3]))
	result.set_meta("anchor_x", float(box[4]))
	result.set_meta("foot_center", float(box[4]))
	result.set_meta("body_height", float(idle[3]))
	result.set_meta("display_height", float(box[3]))
	result.set_meta("pixel_size", 1.575 / float(idle[3]))
	result.set_meta("pose", pose)
	result.set_meta("facing", facing)
	result.set_meta("variant", "class_" + id)
	_textures[key] = result
	return result

static func diagonal_walking_texture(loadout: Dictionary, pose: String, screen: Vector2) -> AtlasTexture:
	if vocation(loadout) != "archer" or pose not in ["idle", "walk_a", "walk_b"]:
		return null
	var direction: StringName = EightWayFacing.ANIMATIONS[EightWayFacing.direction_index(screen)]
	if not ARCHER_DIAGONALS.has_animation(direction):
		return null
	var frame: int = 1 if pose == "walk_a" else 3 if pose == "walk_b" else 0
	return ARCHER_DIAGONALS.get_frame_texture(direction, frame) as AtlasTexture


static func walking_frames(loadout: Dictionary, door: bool = false) -> SpriteFrames:
	var id := vocation(loadout)
	var key := id + (":door" if door else "")
	if _walk.has(key):
		return _walk[key]
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	for direction: String in FACINGS:
		frames.add_animation(direction)
		frames.set_animation_speed(direction, 8.0)
		if id == "archer" and not door and ARCHER_DIAGONALS.has_animation(direction):
			for index: int in range(ARCHER_DIAGONALS.get_frame_count(direction)):
				frames.add_frame(direction, ARCHER_DIAGONALS.get_frame_texture(direction, index))
			continue
		var poses: Array[String] = ["idle", "walk_a", "idle", "walk_b"]
		if door:
			poses.assign(["cast", "release"])
		for pose: String in poses:
			frames.add_frame(direction, texture_for(id, pose, int(FACINGS[direction])))
	_walk[key] = frames
	return frames
