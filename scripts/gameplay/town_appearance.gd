extends RefCounted
## Empty-handed exploration art. Equipment and combat loadouts stay authoritative.
const ClassArt = preload("res://scripts/gameplay/class_art.gd")
const Regions = preload("res://assets/generated/town/regions.gd")
const DIAGONALS: Array[String] = ["down_left", "down_right", "up_left", "up_right"]
## Optional "<id>_diagonal" supplements use four columns (DIAGONALS order) and
## three rows (idle, walk A, walk B). Without one, diagonals use side profiles.
const DIAGONAL_SUFFIX := "_diagonal"
const DIAGONAL_ROWS := 3
const SHEET_PATH := "res://assets/generated/town/%s.png"
const WALK_POSES: Array[int] = [0, 1, 0, 2]
const DOOR_POSES: Array[int] = [3, 4]
static var _cache: Dictionary[String, SpriteFrames] = {}


## Every exploration map uses the sheathed wardrobe. Drawn weapons belong to
## the field/arena combat actors, which use their own atlases.
static func applies(_map_id: String, loadout: Dictionary) -> bool:
	return not ClassArt.vocation(loadout).is_empty()


## Boxes and sheet of the "<id>_diagonal" supplement, or {} when it is absent.
static func diagonal_source(id: String) -> Dictionary:
	var diagonal_id := id + DIAGONAL_SUFFIX
	var path := SHEET_PATH % diagonal_id
	if not Regions.DATA.has(diagonal_id) or not ResourceLoader.exists(path):
		return {}
	var boxes: Array = Dictionary(Regions.DATA[diagonal_id]).get("frames", [])
	if boxes.size() < DIAGONALS.size() * DIAGONAL_ROWS:
		return {}
	return {"boxes": boxes, "sheet": load(path) as Texture2D}


static func frames(loadout: Dictionary, door: bool = false) -> SpriteFrames:
	var id := ClassArt.vocation(loadout)
	var key := id + (":door" if door else "")
	if _cache.has(key):
		return _cache[key]
	var result := SpriteFrames.new()
	result.remove_animation(&"default")
	var sheet := load(SHEET_PATH % id) as Texture2D
	var boxes: Array = Regions.DATA[id].frames
	var supplement: Dictionary = {} if door else diagonal_source(id)
	for direction: String in ClassArt.FACINGS:
		var facing: int = int(ClassArt.FACINGS[direction])
		result.add_animation(direction)
		result.set_animation_speed(direction, 8.0)
		result.set_animation_loop(direction, not door)
		var poses: Array[int] = DOOR_POSES if door else WALK_POSES
		var diagonal: bool = not supplement.is_empty() and direction in DIAGONALS
		var source_boxes: Array = supplement.boxes if diagonal else boxes
		var source_sheet: Texture2D = supplement.sheet if diagonal else sheet
		var idle_index: int = DIAGONALS.find(direction) if diagonal else facing * 5
		for pose: int in poses:
			var box: Array = source_boxes[pose * DIAGONALS.size() + idle_index if diagonal else idle_index + pose]
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
			texture.set_meta("direction", direction)
			result.add_frame(direction, texture)
	_cache[key] = result
	return result
