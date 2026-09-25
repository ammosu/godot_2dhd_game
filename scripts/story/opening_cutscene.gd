extends RefCounted
## Opening film after class selection: the traveler walks the east road into Twilight Village.
## Pure data for CutscenePlayer; the traveler is the live player actor, so the chosen class,
## body and colour scheme appear without extra art.

static func shots() -> Array[Dictionary]:
	return [
		{
			"duration": 6.0, "black": true, "letterbox": false,
			"caption": "很久以前，月光並非驅散黑暗，\n而是指引迷途之人穿過黑暗。",
		},
		{
			"duration": 9.0, "map": "east_road", "spawn": "from_caravan", "music": "ruins",
			"fade_in": 1.2, "fov": 40.0, "actor_at": Vector3(15.6, 0.0, 5.0),
			"camera": {"from": Vector3(-11.0, 9.5, 15.0), "to": Vector3(-3.0, 8.0, 14.0),
				"look_from": Vector3(-5.0, 0.0, 2.0), "look_to": Vector3(3.0, 0.0, 3.0)},
			"caption": "引路人守著道路與路燈，\n讓夜霧中的旅人找得到彼此。",
		},
		{
			"duration": 10.0, "fov": 40.0, "actor_at": Vector3(11.0, 0.0, 5.0),
			"actor_path": [Vector3(-3.2, 0.0, 5.0)], "actor_speed": 1.6, "actor_delay": 0.4,
			"camera": {"look_actor": true, "from": Vector3(-3.0, 2.3, 2.6), "to": Vector3(-3.6, 2.1, 2.3),
				"look_from": Vector3(0.0, 0.9, 0.0), "look_to": Vector3(0.0, 0.9, 0.0)},
			"caption": "後來，路燈一盞盞熄滅，道路被人遺忘。",
		},
		{
			"duration": 7.0, "fov": 36.0, "actor_at": Vector3(-3.2, 0.0, 5.0),
			"actor_face": Vector3(-12.0, 0.0, 5.0),
			"camera": {"track": true, "from": Vector3(-2.6, 1.5, 3.4), "to": Vector3(-1.6, 1.25, 2.2),
				"look_from": Vector3(-0.4, 1.05, 0.0), "look_to": Vector3(-0.5, 1.05, 0.0)},
			"events": [{"at": 2.2, "id": "road_whisper"}],
			"speaker": "低語", "caption": "……往西走。那裡還有一盞燈。",
			"fade_out": 1.0,
		},
		{
			"duration": 10.0, "map": "village", "spawn": "from_east_road", "music": "village",
			"fade_in": 1.2, "fov": 40.0,
			"camera": {"from": Vector3(27.0, 3.0, 11.0), "to": Vector3(12.0, 15.0, 17.0),
				"look_from": Vector3(20.0, 2.5, 3.0), "look_to": Vector3(0.0, 0.5, 0.0)},
			"caption": "暮光村。月光已經連續三晚沒有照進這裡。",
		},
		{
			"duration": 5.5, "fov": 40.0, "actor_at": Vector3(23.5, 0.0, 4.6),
			"actor_path": [Vector3(16.5, 0.0, 4.6)], "actor_speed": 1.5,
			"camera": {"look_actor": true, "from": Vector3(26.4, 2.5, 4.9), "to": Vector3(26.2, 2.8, 4.8),
				"look_from": Vector3(0.0, 0.9, 0.0), "look_to": Vector3(-2.0, 0.6, 0.0)},
		},
		{
			"duration": 6.5, "fov": 38.0, "actor_at": Vector3(16.5, 0.0, 4.6),
			"actor_face": Vector3(0.0, 0.0, -19.3),
			"camera": {"from": Vector3(-3.4, 2.3, -10.5), "to": Vector3(-2.2, 2.7, -12.6),
				"look_from": Vector3(0.0, 1.5, -19.3), "look_to": Vector3(0.0, 1.7, -19.3)},
			"events": [{"at": 1.6, "id": "gate_glow"}],
			"caption": "那一夜，沉睡多年的北門月紋，微微亮了一下。",
			"fade_out": 1.4,
		},
		{
			"duration": 5.5, "black": true, "letterbox": false,
			"title": "Wanderlight: Moon Shard", "subtitle": "序章〈熄滅的月燈〉",
		},
	]
