extends Node2D
## Shared body + independently fitted clothing + weapon + foreground fingers.
## Coordinates are authored against the 1280px source sheets, not combinations.
const ROOT := "res://assets/generated/equipment_layers/"
const CUTOUT: ShaderMaterial = preload("res://shaders/layered_cutout.tres")
const POSES: Array[String] = ["idle", "attack", "hurt", "guard"]
const ORIGINS: Array[Vector2] = [Vector2.ZERO, Vector2(640, 0), Vector2(0, 640), Vector2(640, 640)]
const GRIPS: Array[Vector2] = [Vector2(263, 393), Vector2(1023, 303), Vector2(275, 987), Vector2(919, 882)]
const HEAD_BOTTOM: Array[float] = [278.0, 278.0, 847.0, 854.0]
const LEG_TOP: Array[float] = [423.0, 422.0, 1000.0, 990.0]
static var HANDS: Array[PackedVector2Array] = [
	PackedVector2Array([Vector2(245,373),Vector2(272,373),Vector2(288,384),Vector2(286,400),Vector2(272,410),Vector2(245,406)]),
	PackedVector2Array([Vector2(997,285),Vector2(1033,277),Vector2(1055,290),Vector2(1057,308),Vector2(1040,324),Vector2(1002,319)]),
	PackedVector2Array([Vector2(250,967),Vector2(274,958),Vector2(296,976),Vector2(299,999),Vector2(282,1010),Vector2(250,1002)]),
	PackedVector2Array([Vector2(897,869),Vector2(913,852),Vector2(936,852),Vector2(950,871),Vector2(939,899),Vector2(914,906),Vector2(894,891)])
]
static var FREE_HANDS: Array[PackedVector2Array] = [
	PackedVector2Array([Vector2(418,348),Vector2(439,346),Vector2(458,362),Vector2(455,380),Vector2(435,395),Vector2(413,386)]),
	PackedVector2Array(),
	PackedVector2Array([Vector2(386,803),Vector2(412,799),Vector2(437,819),Vector2(438,840),Vector2(412,864),Vector2(387,850),Vector2(382,824)]),
	PackedVector2Array([Vector2(934,878),Vector2(949,875),Vector2(973,893),Vector2(976,912),Vector2(962,925),Vector2(939,920),Vector2(917,910),Vector2(918,899)])
]
var pose_index: int = 0
var armor: String = "coat"
var weapon: String = "blade"
var exploded: bool = false
var show_hands: bool = true
var actor_id: String = "wanderer"
var _fitting: Dictionary = {}
static var _profiles: Dictionary[String, Dictionary] = {}


static func art_path(actor: String, layer: String) -> String:
	return ROOT + ("" if actor == "wanderer" else actor + "/") + layer + "_combat.png"


static func profile(actor: String) -> Dictionary:
	if not _profiles.has(actor):
		_profiles[actor] = JSON.parse_string(FileAccess.get_file_as_string(ROOT + actor + "/fitting.json")) as Dictionary
	return _profiles[actor]


static func points(values: Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	for value: Array in values:
		result.append(Vector2(float(value[0]), float(value[1])))
	return result


static func foot_y(pose_name: String, actor: String = "wanderer") -> float:
	var index := POSES.find(pose_name)
	assert(index >= 0)
	var image := (load(art_path(actor, "base")) as Texture2D).get_image()
	var ratio := float(image.get_width()) / 1280.0
	var region := Rect2i(ORIGINS[index] * ratio, Vector2(640,640) * ratio)
	# ImageGen can leave almost-transparent pixels below the boots. They must
	# not move the battle ground anchor to the bottom of the whole atlas cell.
	for y: int in range(region.end.y - 1, region.position.y - 1, -1):
		for x: int in range(region.position.x, region.end.x):
			if image.get_pixel(x, y).a >= 0.5:
				return float(y + 1) / ratio
	return ORIGINS[index].y + 640.0


func configure(pose_name: String, armor_id: String, weapon_id: String, separate: bool = false, fingers: bool = true, character: String = "wanderer") -> void:
	assert(pose_name in POSES and armor_id in ["", "coat", "moonward"] and weapon_id in ["", "blade", "saber"])
	assert(character in ["wanderer", "noah", "elder"])
	actor_id = character
	_fitting = {} if actor_id == "wanderer" else profile(actor_id)
	pose_index = POSES.find(pose_name)
	armor = armor_id
	weapon = weapon_id
	exploded = separate
	show_hands = fingers
	_rebuild()


func _rebuild() -> void:
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var base: Texture2D = load(art_path(actor_id, "base"))
	var origin: Vector2 = ORIGINS[pose_index]
	if armor.is_empty():
		_region("Body", base, Rect2(origin, Vector2(640, 640)))
	else:
		# Covered body regions are hidden per clothing coverage, as in a paper-doll
		# wardrobe. Exposed legs/head are the identical shared base for all outfits.
		var leg_top := LEG_TOP[pose_index] if actor_id == "wanderer" else float(_fitting.leg_top[pose_index])
		_region("SharedLegs", base, Rect2(Vector2(origin.x, leg_top), Vector2(640, origin.y + 640 - leg_top)))
		_clothing()
		if actor_id == "wanderer":
			_region("SharedHead", base, Rect2(origin, Vector2(640, HEAD_BOTTOM[pose_index] - origin.y)))
		else:
			_polygon("SharedHead", base, points(_fitting.head[pose_index]))
	if not weapon.is_empty():
		_weapon()
	if show_hands:
		var hand := HANDS[pose_index] if actor_id == "wanderer" else points(_fitting.hands[pose_index])
		var free_hand := FREE_HANDS[pose_index] if actor_id == "wanderer" else points(_fitting.free_hands[pose_index])
		_polygon("GripFingers", base, hand, Vector2(400, 0) if exploded else Vector2.ZERO)
		if not free_hand.is_empty():
			_polygon("FreeHand", base, free_hand, Vector2(400, 0) if exploded else Vector2.ZERO)


func _region(label: String, texture: Texture2D, rect: Rect2) -> void:
	var corners := PackedVector2Array([rect.position, rect.position + Vector2(rect.size.x, 0), rect.end, rect.position + Vector2(0, rect.size.y)])
	_polygon(label, texture, corners)


func _polygon(label: String, texture: Texture2D, points: PackedVector2Array, offset: Vector2 = Vector2.ZERO) -> Polygon2D:
	var node := Polygon2D.new()
	node.material = CUTOUT
	node.name = label
	node.texture = texture
	var pixels := PackedVector2Array()
	for point: Vector2 in points:
		pixels.append(point * texture.get_size() / 1280.0)
	node.uv = pixels
	var local_points := PackedVector2Array()
	for point: Vector2 in points:
		local_points.append(point - ORIGINS[pose_index])
	node.polygon = local_points
	node.position = offset
	add_child(node)
	return node


func _weapon() -> void:
	if actor_id != "wanderer":
		_companion_weapon()
		return
	var texture: Texture2D = load(art_path(actor_id, weapon))
	var anchors := PackedVector2Array([Vector2(225,370),Vector2(930,334),Vector2(226,980),Vector2(900,938)] if weapon == "blade" else [Vector2(258,425),Vector2(901,348),Vector2(260,1002),Vector2(930,1015)])
	var origin := ORIGINS[pose_index]
	var node := _polygon("Weapon", texture, PackedVector2Array([origin, origin+Vector2(640,0), origin+Vector2(640,640), origin+Vector2(0,640)]))
	var factor := (0.70 if pose_index == 1 else 0.90) if weapon == "saber" else (0.90 if pose_index == 1 else 1.0)
	node.scale = Vector2.ONE * factor
	node.position = GRIPS[pose_index] - origin - (anchors[pose_index] - origin) * factor
	if exploded:
		node.position.x += 270


func _companion_weapon() -> void:
	var texture: Texture2D = load(art_path(actor_id, weapon))
	var origin := ORIGINS[pose_index]
	var anchors := points(_fitting.weapon_anchors[weapon][pose_index])
	var target: Vector2 = points([_fitting.grips[pose_index]])[0]
	var angle := 0.0
	var factor: float = float(_fitting.weapon_scale[weapon][pose_index])
	if anchors.size() == 2:
		var second: Vector2 = points([_fitting.secondary[pose_index]])[0]
		var shaft := anchors[1] - anchors[0]
		var grip_line := second - target
		angle = grip_line.angle() - shaft.angle()
		factor = grip_line.length() / shaft.length()
	var node := _polygon("Weapon", texture, PackedVector2Array([origin,origin+Vector2(640,0),origin+Vector2(640,640),origin+Vector2(0,640)]))
	node.rotation = angle
	node.scale = Vector2.ONE * factor
	node.position = target - origin - (anchors[0] - origin).rotated(angle) * factor
	if exploded:
		node.position.x += 270


func _clothing() -> void:
	var texture: Texture2D = load(art_path(actor_id, armor))
	if actor_id != "wanderer":
		_fit_clothing(texture, points(_fitting[armor][pose_index]), points(_fitting.targets[pose_index]), 620.0)
		return
	var source: Array[PackedVector2Array]
	if armor == "coat":
		source = [
			PackedVector2Array([Vector2(326,265),Vector2(240,391),Vector2(459,390),Vector2(325,389),Vector2(320,503)]),
			PackedVector2Array([Vector2(873,275),Vector2(1049,315),Vector2(854,394),Vector2(866,492)]),
			PackedVector2Array([Vector2(289,816),Vector2(276,962),Vector2(433,827),Vector2(360,918),Vector2(375,1030)]),
			PackedVector2Array([Vector2(885,822),Vector2(933,881),Vector2(985,896),Vector2(886,955),Vector2(888,1045)])]
	else:
		source = [
			PackedVector2Array([Vector2(330,263),Vector2(271,418),Vector2(472,394),Vector2(333,388),Vector2(343,504)]),
			PackedVector2Array([Vector2(906,277),Vector2(1054,316),Vector2(876,388),Vector2(872,522)]),
			PackedVector2Array([Vector2(287,812),Vector2(289,994),Vector2(430,836),Vector2(350,927),Vector2(360,1050)]),
			PackedVector2Array([Vector2(920,826),Vector2(991,892),Vector2(1010,904),Vector2(915,955),Vector2(926,1076)])]
	var targets: Array[PackedVector2Array] = [
		PackedVector2Array([Vector2(329,266),Vector2(259,377),Vector2(422,365),Vector2(321,361),Vector2(327,448)]),
		PackedVector2Array([Vector2(891,268),Vector2(1006,301),Vector2(843,359),Vector2(838,450)]),
		PackedVector2Array([Vector2(272,830),Vector2(262,974),Vector2(402,843),Vector2(341,928),Vector2(370,1040)]),
		PackedVector2Array([Vector2(881,841),Vector2(903,886),Vector2(954,910),Vector2(868,951),Vector2(869,1036)])]
	_fit_clothing(texture, source[pose_index], targets[pose_index], 575.0)


func _fit_clothing(texture: Texture2D, source: PackedVector2Array, targets: PackedVector2Array, split: float) -> void:
	var origin := ORIGINS[pose_index]
	var vertices := PackedVector2Array()
	var uvs := PackedVector2Array()
	var triangles: Array[PackedInt32Array] = []
	const STEPS := 32
	for y: int in range(STEPS + 1):
		for x: int in range(STEPS + 1):
			# Cape pixels from the right actor extend left of x=640. Crop at the
			# actual inter-character gutter to avoid drawing a second cape fragment.
			var left := 0.0 if pose_index % 2 == 0 else split
			var width := split if pose_index % 2 == 0 else 1280.0 - split
			var point := Vector2(left + x * width / STEPS, origin.y + y * 640.0 / STEPS)
			var delta := Vector2.ZERO
			var sum := 0.0
			for i: int in range(source.size()):
				var weight := 1.0 / pow(maxf(4.0, point.distance_to(source[i])), 3.0)
				delta += (targets[i] - source[i]) * weight
				sum += weight
			vertices.append(point - origin + delta / sum)
			uvs.append(point * texture.get_size() / 1280.0)
	for y: int in range(STEPS):
		for x: int in range(STEPS):
			var a := y * (STEPS + 1) + x
			triangles.append(PackedInt32Array([a, a+1, a+STEPS+2]))
			triangles.append(PackedInt32Array([a, a+STEPS+2, a+STEPS+1]))
	var node := Polygon2D.new()
	node.material = CUTOUT
	node.name = "Clothing"
	node.texture = texture
	node.polygon = vertices
	node.uv = uvs
	node.polygons = triangles
	node.position.x = 130 if exploded else 0
	add_child(node)
