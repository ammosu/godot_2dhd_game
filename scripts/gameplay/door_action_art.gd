extends RefCounted
## Measured, grounded reach/contact poses. Walking and equipment remain separate.
const Facing = preload("res://scripts/gameplay/eight_way_facing.gd")
const Appearance = preload("res://scripts/gameplay/equipment_appearance.gd")
# Measured transparent row gutters; generated atlases are not perfectly uniform.
const ROW_EDGES: Dictionary = {
	"base": [0, 328, 640, 952, 1254],
	"moonward": [0, 329, 640, 954, 1254],
	"saber": [0, 328, 640, 952, 1254],
	"moonward_saber": [0, 328, 640, 952, 1254],
}
static var _cache: Dictionary[String, SpriteFrames] = {}


static func frames(loadout: Dictionary) -> SpriteFrames:
	if not Appearance.ClassArt.vocation(loadout).is_empty():
		return Appearance.ClassArt.walking_frames(loadout, true)
	var outfit := Appearance.variant(loadout)
	var key := "base" if outfit.is_empty() else outfit
	if _cache.has(key):
		return _cache[key]
	var texture := load("res://assets/generated/door_actions/%s.png" % key) as Texture2D
	var pixels := texture.get_image()
	if pixels.is_compressed():
		pixels.decompress()
	var result := SpriteFrames.new()
	result.remove_animation(&"default")
	for direction: int in range(8):
		var animation: StringName = Facing.ANIMATIONS[direction]
		result.add_animation(animation)
		result.set_animation_loop(animation, false)
		for pose: int in range(2):
			var row := direction / 4 + pose * 2
			var column := direction % 4
			var left := roundi(float(column) * pixels.get_width() / 4.0)
			var top: int = ROW_EDGES[key][row]
			var right := roundi(float(column + 1) * pixels.get_width() / 4.0)
			var bottom: int = ROW_EDGES[key][row + 1]
			var bounds := Rect2i(left, top, right - left, bottom - top)
			var visible := pixels.get_region(bounds).get_used_rect()
			# Alpha fuzz does not count as boots. Measure opaque silhouette only.
			var first: int = bounds.size.y
			var ground: int = 0
			for y: int in range(bounds.size.y):
				for x: int in range(bounds.size.x):
					if pixels.get_pixel(left + x, top + y).a >= 0.5:
						first = mini(first, y)
						ground = maxi(ground, y + 1)
			var foot_left: int = bounds.size.x
			var foot_right: int = 0
			for y: int in range(maxi(0, ground - 18), ground):
				for x: int in range(bounds.size.x):
					if pixels.get_pixel(left + x, top + y).a >= 0.5:
						foot_left = mini(foot_left, x)
						foot_right = maxi(foot_right, x + 1)
			assert(visible.has_area() and ground > first)
			var frame := AtlasTexture.new()
			frame.atlas = texture
			frame.region = Rect2(bounds)
			frame.filter_clip = true
			frame.set_meta("ground_y", ground)
			frame.set_meta("body_height", ground - first)
			frame.set_meta("foot_center", (foot_left + foot_right) * 0.5)
			frame.set_meta("door_pose", "reach" if pose == 0 else "contact")
			frame.set_meta("variant", key)
			result.add_frame(animation, frame)
	_cache[key] = result
	return result
