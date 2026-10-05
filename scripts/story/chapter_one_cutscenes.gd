extends RefCounted
## Chapter 1 scenery beats; dialogue and persistent progress stay with chapter_one.gd.
## The live player stays in place, and the host restores exploration after each film.

const Mountains = preload("res://scripts/gameplay/mountain_maps.gd")


static func light_east() -> Array[Dictionary]:
	return [
		{
			# A lower angle keeps the villagers standing rather than flattened on the paving.
			"duration": 5.5, "fade_in": 1.0, "fov": 42.0,
			"camera": {"from": Vector3(-3.5, 6.0, 8.5), "to": Vector3(-1.5, 5.0, 7.0),
				"look_from": Vector3(0, 0.6, 0), "look_to": Vector3(0, 0.6, 0)},
			"events": [{"at": 1.5, "id": "light_turns_east"}],
			"caption": "月燈下的光路，慢慢轉向了東方。",
		},
		{
			# Follow the broken inlays before lifting toward the village's east exit.
			"duration": 5.5, "fov": 42.0,
			"camera": {"from": Vector3(1, 7, 6), "to": Vector3(11, 6, 7),
				"look_from": Vector3(3, 0, 0), "look_to": Vector3(13, 0, 1)},
			"caption": "石縫裡的光，一道接著一道亮起。",
		},
		{
			"duration": 5.0, "fov": 40.0, "fade_out": 1.0,
			"camera": {"from": Vector3(13, 7, 11), "to": Vector3(19, 5, 10),
				"look_from": Vector3(19, 0, 4.6), "look_to": Vector3(24, 0, 4.6)},
			"caption": "光指向村口。那裡有一條往東的路。",
		},
	]


## Sia rings the bell crest and the sealed slab sinks into the road.
static func seal_open() -> Array[Dictionary]:
	var door := Vector3(-8, 0, -1.8)
	return [
		{
			# Three-quarter view from the west: the traveler stands aside so the crest stays clear.
			"duration": 4.6, "fade_in": 0.6, "fov": 40.0, "actor_at": door + Vector3(1.5, 0, 2.8),
			"actor_face": door,
			"camera": {"from": door + Vector3(-3.6, 2.0, 5.2), "to": door + Vector3(-3.0, 1.8, 4.6),
				"look_from": door + Vector3(0, 1.5, 0.3), "look_to": door + Vector3(0, 1.5, 0.3)},
			# First a light test with the hand bell (the crest answers), then the real strike.
			"events": [{"at": 0.0, "id": "party_to_door"}, {"at": 0.9, "id": "crest_answer"}, {"at": 2.4, "id": "seal_ring"}],
			"caption": "叮……鐘紋回應了。噹——",
		},
		{
			# Hold on the door while the slab sinks and dust rises.
			"duration": 4.6, "fov": 38.0,
			"camera": {"from": door + Vector3(-1.2, 1.7, 6.0), "to": door + Vector3(-0.8, 1.8, 5.0),
				"look_from": door + Vector3(0, 1.5, 0), "look_to": door + Vector3(0, 1.2, 0)},
			"events": [{"at": 0.2, "id": "seal_sink"}],
		},
		{
			# Hold on the open passage, then Noah is first through it.
			"duration": 3.4, "fov": 40.0,
			"camera": {"from": door + Vector3(-2.4, 1.7, 4.4), "to": door + Vector3(-2.1, 1.6, 4.0),
				"look_from": door + Vector3(0, 1.1, -0.6), "look_to": door + Vector3(0, 1.1, -1.0)},
			"events": [{"at": 1.0, "id": "noah_enters"}],
			"caption": "門後的通道，通往地下。",
			"fade_out": 0.8,
		},
	]


## Ending, part one: the party at the lookout, then the shard catching the moon.
## Lenses look west and north over the cloud sea, away from the summit tree.
static func shard_rise() -> Array[Dictionary]:
	var points: PackedVector3Array = Mountains.route("moon_highland")
	var overlook: Vector3 = points[-9]
	return [
		{
			# Facing the party from the summit side; the moon hangs behind them.
			"duration": 4.5, "fade_in": 1.0, "fov": 48.0, "actor_at": overlook, "actor_face": overlook + Vector3(0, 0, -10),
			"camera": {"from": overlook + Vector3(-2.6, 1.9, -5.2), "to": overlook + Vector3(-2.2, 1.8, -4.4),
				"look_from": overlook + Vector3(1.2, 2.2, 3.0), "look_to": overlook + Vector3(1.0, 2.3, 3.0)},
			"events": [{"at": 0.0, "id": "shard_in_hand"}],
			"caption": "雲海上方，月光最亮的地方。",
		},
		{
			# A chest-height medium shot: the shard beside the traveler as the ash flakes away.
			"duration": 5.0, "fov": 34.0,
			"camera": {"track": true, "from": Vector3(2.3, 1.35, -2.4), "to": Vector3(2.1, 1.3, -2.2),
				"look_from": Vector3(-0.12, 1.0, -0.2), "look_to": Vector3(-0.12, 1.02, -0.2)},
			"events": [{"at": 0.8, "id": "ash_fall"}, {"at": 1.4, "id": "shard_glow"}],
			"caption": "碎片上的灰落下了。淡淡的光，重新亮了起來。",
		},
		{
			# Down the trail: a lantern climbing toward them out of the fog.
			"duration": 5.0, "fov": 40.0, "fade_out": 1.0,
			"camera": {"from": overlook + Vector3(-1.2, 3.2, 1.6), "to": overlook + Vector3(-1.1, 2.9, 2.2),
				"look_from": points[-26] + Vector3(0, 1.2, 0), "look_to": points[-21] + Vector3(0, 1.4, 0)},
			"events": [{"at": 0.0, "id": "lantern_approach"}],
			"caption": "霧裡，有一盞燈正朝這裡走來。",
		},
	]


## The party comes home at first light; Rumi is waiting by the lamp.
static func homecoming() -> Array[Dictionary]:
	return [
		{
			"duration": 5.0, "map": "village", "spawn": "from_east_road", "music": "village",
			"fade_in": 1.2, "fov": 42.0, "actor_at": Vector3(24.0, 0.0, 4.6),
			"actor_path": [Vector3(10.0, 0.0, 5.2)], "actor_speed": 1.9,
			# On the road's centre line, facing the gate: the party walks in toward the lens.
			"camera": {"look_actor": true, "from": Vector3(8.2, 2.0, 4.8), "to": Vector3(8.0, 2.0, 4.8),
				"look_from": Vector3(0, 1.0, 0), "look_to": Vector3(0, 1.0, 0)},
			"caption": "回到暮光村的時候，天快亮了。",
		},
		{
			"duration": 4.0, "fov": 40.0, "actor_at": Vector3(5.0, 0.0, 6.6), "actor_face": Vector3(6.4, 0.0, 4.2),
			"camera": {"from": Vector3(9.5, 2.6, 9.5), "to": Vector3(9.0, 2.4, 8.6),
				"look_from": Vector3(6.8, 1.0, 4.4), "look_to": Vector3(7.0, 1.0, 4.6)},
			"caption": "露米還守在月燈旁。",
			"fade_out": 0.8,
		},
	]


## The rescue, framed: the traveler against the crate, the wolf and bat, the open road behind.
static func rescue_intro() -> Array[Dictionary]:
	return [
		{
			"duration": 3.8, "fade_in": 0.5, "fov": 44.0,
			"camera": {"from": Vector3(1.0, 3.4, 9.0), "to": Vector3(1.6, 3.0, 8.2),
				"look_from": Vector3(5.0, 0.8, 3.4), "look_to": Vector3(5.2, 0.8, 3.4)},
			"caption": "新點亮的路燈，引來了野獸。",
			"fade_out": 0.4,
		},
	]


## The crypt answers the choice: the throne's last light runs out along the floor seams.
static func ember_flow() -> Array[Dictionary]:
	return [
		{
			"duration": 4.6, "fade_in": 0.4, "fov": 46.0,
			"camera": {"from": Vector3(3.4, 3.6, -3.0), "to": Vector3(3.0, 3.4, 0.0),
				"look_from": Vector3(0, 0.3, -7.0), "look_to": Vector3(0, 0.3, 4.0)},
			"events": [{"at": 0.3, "id": "ember_flow"}],
			"caption": "王座的微光，沿著石縫流向出口。",
			"fade_out": 0.6,
		},
	]


## The lantern bearer's destination, made visible: a blue lamp beyond the cloud sea.
static func blue_lamp() -> Array[Dictionary]:
	var points: PackedVector3Array = Mountains.route("moon_highland")
	var overlook: Vector3 = points[-9]
	return [
		{
			"duration": 4.0, "fade_in": 0.6, "fov": 38.0,
			# Over the party's shoulders toward the open south-east sky, under the moon.
			"camera": {"from": overlook + Vector3(-0.8, 2.3, -1.4), "to": overlook + Vector3(-0.7, 2.3, -1.2),
				"look_from": overlook + Vector3(24, 3.6, 31), "look_to": overlook + Vector3(24.5, 3.8, 31.5)},
			"caption": "海的那一邊，一盞藍色的燈亮著。",
			"fade_out": 0.6,
		},
	]


## Ending, part two: the single chapter card.
static func end_card() -> Array[Dictionary]:
	return [
		{
			"duration": 4.0, "black": true, "letterbox": false, "fade_in": 0.8,
			"title": "第一章〈醒來的古道〉", "subtitle": "完",
		},
	]
