extends RefCounted
## Empty-handed exploration art. Equipment and combat loadouts stay authoritative.
const ClassArt = preload("res://scripts/gameplay/class_art.gd")
const Houses = preload("res://scripts/gameplay/house_catalog.gd")
const Regions = preload("res://assets/generated/town/regions.gd")
const DIAGONALS: Array[String] = ["down_left", "down_right", "up_left", "up_right"]
static var _cache: Dictionary[String, SpriteFrames] = {}


static func applies(map_id: String, loadout: Dictionary) -> bool:
	return (map_id in ["village", "starbay"] or Houses.is_interior(map_id)) and not ClassArt.vocation(loadout).is_empty()


static func frames(loadout: Dictionary, door: bool = false) -> SpriteFrames:
	var id := ClassArt.vocation(loadout)
	var key := id + (":door" if door else "")
	if _cache.has(key):
		return _cache[key]
	var result := SpriteFrames.new()
	result.remove_animation(&"default")
	var sheet := load("res://assets/generated/town/%s.png" % id) as Texture2D
	var boxes: Array = Regions.DATA[id].frames
	for direction: String in ClassArt.FACINGS:
		var facing: int = int(ClassArt.FACINGS[direction])
		result.add_animation(direction)
		result.set_animation_speed(direction, 8.0)
		result.set_animation_loop(direction, not door)
		var poses: Array[int] = [0, 1, 0, 2]
		if door:
			poses.assign([3, 4])
		var diagonal: bool = id == "archer" and not door and direction in DIAGONALS
		var source_boxes: Array = Regions.DATA.archer_diagonal.frames if diagonal else boxes
		var source_sheet: Texture2D = load("res://assets/generated/town/archer_diagonal.png") if diagonal else sheet
		var idle_index: int = DIAGONALS.find(direction) if diagonal else facing * 5
		for pose: int in poses:
			var box: Array = source_boxes[pose * 4 + idle_index if diagonal else idle_index + pose]
			var texture := AtlasTexture.new()
			texture.atlas = source_sheet
			texture.region = Rect2(box[0], box[1], box[2], box[3])
			texture.filter_clip = true
			texture.set_meta("body_height", float(source_boxes[idle_index][3]))
			texture.set_meta("ground_y", float(box[3]))
			texture.set_meta("anchor_x", float(box[4]))
			texture.set_meta("foot_center", float(box[4]))
			texture.set_meta("town_unarmed", true)
			texture.set_meta("variant", "class_" + id)
			result.add_frame(direction, texture)
	_cache[key] = result
	return result
