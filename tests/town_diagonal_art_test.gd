extends SceneTree
## Measured sanity checks for empty-handed diagonal town-walk sheets (no saves, no gameplay).
const Regions = preload("res://assets/generated/town/regions.gd")
const SUFFIX := "_diagonal"
const COLUMNS := 4 # down_left, down_right, up_left, up_right
const POSES := 3 # neutral passing, contact A, contact B
## Generated in the codex pass; the older male archer supplement keeps its own test.
const REGISTERED_IDS: Array[String] = ["thief", "female_traveler", "female_thief"]
## Source pixels (sprites are about 330 px tall). Contact A/B must not limp against
## each other; contacts may dip below the passing pose like a real walk, never pop up.
const MAX_CONTACT_LIMP_PX := 5
const MAX_CONTACT_DIP_PX := 15
const MAX_CONTACT_RISE_PX := 4
const MAX_ROW_BASELINE_SPREAD_PX := 8
const MAX_WIDTH_CHANGE := 0.15
var failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)


func _run() -> void:
	var sheets: Array[String] = []
	for key: String in Regions.DATA:
		if key.ends_with(SUFFIX):
			sheets.append(key)
			var base := key.trim_suffix(SUFFIX)
			check(Regions.DATA.has(base), "%s has no matching town wardrobe" % key)
			_check_layout(key)
	for id: String in REGISTERED_IDS:
		check(sheets.has(id + SUFFIX), "Missing diagonal sheet for " + id)
		if sheets.has(id + SUFFIX):
			_check_registration(id + SUFFIX)
	if failures == 0:
		print("TOWN_DIAGONAL_ART_TEST_PASS sheets=%d layout registration baseline" % sheets.size())
	quit(0 if failures == 0 else 1)


func _check_layout(key: String) -> void:
	var data: Dictionary = Regions.DATA[key]
	var texture := load("res://assets/generated/town/%s.png" % key) as Texture2D
	check(texture != null, "Missing texture " + key)
	if texture == null:
		return
	var size := Vector2(data.size[0], data.size[1])
	check(texture.get_size() == size, "%s size differs from measured regions" % key)
	var frames: Array = data.frames
	check(frames.size() == COLUMNS * POSES, "%s must have 4 directions x 3 poses" % key)
	for index: int in range(frames.size()):
		var box: Array = frames[index]
		var rect := Rect2(box[0], box[1], box[2], box[3])
		check(Rect2(Vector2.ZERO, size).encloses(rect), "%s frame %d outside atlas" % [key, index])
		check(float(box[4]) > 0.0 and float(box[4]) < float(box[2]), "%s frame %d foot anchor outside crop" % [key, index])
		if index % COLUMNS > 0:
			var left: Array = frames[index - 1]
			check(float(left[0]) + float(left[2]) < float(box[0]), "%s frame %d not ordered left to right" % [key, index])
	for pose: int in range(1, POSES):
		check(float(frames[pose * COLUMNS][1]) > float(frames[(pose - 1) * COLUMNS][1]) + float(frames[(pose - 1) * COLUMNS][3]) * 0.5,
			"%s rows not ordered top to bottom" % key)


func _check_registration(key: String) -> void:
	var frames: Array = Regions.DATA[key].frames
	for pose: int in range(POSES):
		var bottoms: Array[float] = []
		for column: int in range(COLUMNS):
			var box: Array = frames[pose * COLUMNS + column]
			bottoms.append(float(box[1]) + float(box[3]))
		check(bottoms.max() - bottoms.min() <= MAX_ROW_BASELINE_SPREAD_PX, "%s row %d feet not on one baseline" % [key, pose])
	for column: int in range(COLUMNS):
		var neutral: Array = frames[column]
		var contact_a: Array = frames[COLUMNS + column]
		var contact_b: Array = frames[2 * COLUMNS + column]
		var height := float(neutral[3])
		check(absf(float(contact_a[3]) - float(contact_b[3])) <= MAX_CONTACT_LIMP_PX, "%s column %d contacts limp" % [key, column])
		for contact: Array in [contact_a, contact_b]:
			check(height - float(contact[3]) <= MAX_CONTACT_DIP_PX, "%s column %d contact dips too far" % [key, column])
			check(float(contact[3]) - height <= MAX_CONTACT_RISE_PX, "%s column %d contact pops upward" % [key, column])
			check(absf(float(contact[2]) / float(neutral[2]) - 1.0) <= MAX_WIDTH_CHANGE, "%s column %d body width pops" % [key, column])
