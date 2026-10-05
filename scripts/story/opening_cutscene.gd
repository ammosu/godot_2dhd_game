extends RefCounted
## Opening film after class selection: the traveler wakes in the fog and walks the east road into Twilight Village.
## Pure data for CutscenePlayer; the traveler is the live player actor, so the chosen class,
## body and colour scheme appear without extra art.
##
## Staging: the east road shots keep the lens on the south side of the westward path (z = 5),
## so the traveler always moves screen-left across the cuts instead of crossing the line.
## Walking speeds sit near a relaxed stroll so the stride reads without foot sliding.

const ROAD_WALK_SPEED: float = 1.9
const VILLAGE_WALK_SPEED: float = 1.8

static func shots() -> Array[Dictionary]:
	return [
		{
			"duration": 6.0, "black": true, "letterbox": false,
			"caption": "夜裡會起霧。\n霧會讓人迷路，忘記回家的路。",
		},
		{
			# Waking in the fog: a low point-of-view that opens from black, looks up into the
			# murk, then rises as if sitting up to find the road west. The traveler stands
			# behind the lens so only the world is seen; the fog thins over the shot.
			"duration": 8.5, "map": "east_road", "spawn": "from_caravan", "music": "ruins",
			"fade_in": 2.6, "fov": 50.0, "actor_at": Vector3(21.0, 0.0, 5.0),
			"camera": {"from": Vector3(18.2, 0.45, 5.3), "to": Vector3(17.8, 1.45, 5.1),
				"look_from": Vector3(14.0, 7.5, 2.0), "look_to": Vector3(6.0, 0.9, 5.0)},
			"events": [{"at": 0.0, "id": "waking_fog"}],
			"speaker": "旅人", "caption": "……這裡是哪裡？我什麼都想不起來。",
			"fade_out": 0.9,
		},
		{
			"duration": 9.0, "fade_in": 1.0, "fov": 40.0, "actor_at": Vector3(15.6, 0.0, 5.0),
			"camera": {"from": Vector3(-11.0, 9.5, 15.0), "to": Vector3(-3.0, 8.0, 14.0),
				"look_from": Vector3(-5.0, 0.0, 2.0), "look_to": Vector3(3.0, 0.0, 3.0)},
			"caption": "只有月光，能穿過霧。",
		},
		{
			"duration": 10.0, "fov": 40.0, "actor_at": Vector3(11.0, 0.0, 5.0),
			"actor_path": [Vector3(-3.2, 0.0, 5.0)], "actor_speed": ROAD_WALK_SPEED, "actor_delay": 0.4,
			"camera": {"look_actor": true, "from": Vector3(4.5, 3.2, 10.2), "to": Vector3(3.0, 2.3, 10.0),
				"look_from": Vector3(0.0, 0.9, 0.0), "look_to": Vector3(0.0, 0.9, 0.0)},
			"caption": "旅人什麼都不記得，只記得一句話。",
		},
		{
			"duration": 7.0, "fov": 36.0, "actor_at": Vector3(-3.2, 0.0, 5.0),
			"actor_face": Vector3(-12.0, 0.0, 5.0),
			"camera": {"track": true, "from": Vector3(-2.6, 1.5, 3.4), "to": Vector3(-1.6, 1.25, 2.2),
				"look_from": Vector3(-0.4, 1.05, 0.0), "look_to": Vector3(-0.5, 1.05, 0.0)},
			# The whisper makes him glance around toward the lens side, then settle back on the road west.
			"events": [{"at": 2.2, "id": "road_whisper"}, {"at": 2.5, "face": Vector3(-6.0, 0.0, 9.0)},
				{"at": 3.5, "face": Vector3(-12.0, 0.0, 5.0)}],
			# Startled by the voice, then a small nod: he will go west.
			"acts": [{"at": 2.3, "who": "actor", "act": "surprise", "emote": "question"}, {"at": 4.4, "who": "actor", "act": "nod"}],
			"speaker": "低語", "caption": "……往西走。那裡還有一盞燈。",
			"fade_out": 1.0,
		},
		{
			"duration": 10.0, "map": "village", "spawn": "from_east_road", "music": "village",
			"fade_in": 1.2, "fov": 40.0,
			"camera": {"from": Vector3(27.0, 3.0, 11.0), "to": Vector3(12.0, 15.0, 17.0),
				"look_from": Vector3(20.0, 2.5, 3.0), "look_to": Vector3(0.0, 0.5, 0.0)},
			"caption": "暮光村。月光已經三個晚上沒有照進這裡。",
		},
		{
			"duration": 5.5, "fov": 40.0, "actor_at": Vector3(23.5, 0.0, 4.6),
			"actor_path": [Vector3(16.5, 0.0, 4.6)], "actor_speed": VILLAGE_WALK_SPEED,
			"camera": {"look_actor": true, "from": Vector3(26.4, 2.5, 4.9), "to": Vector3(26.2, 2.8, 4.8),
				"look_from": Vector3(0.0, 0.9, 0.0), "look_to": Vector3(-2.0, 0.6, 0.0)},
		},
		{
			"duration": 6.5, "fov": 38.0, "actor_at": Vector3(16.5, 0.0, 4.6),
			"actor_face": Vector3(0.0, 0.0, -19.3),
			"camera": {"from": Vector3(-3.4, 2.3, -10.5), "to": Vector3(-2.2, 2.7, -12.6),
				"look_from": Vector3(0.0, 1.5, -19.3), "look_to": Vector3(0.0, 1.7, -19.3)},
			"events": [{"at": 1.6, "id": "gate_glow"}],
			"caption": "那一夜，關了十二年的北門，月紋微微亮了一下。",
			"fade_out": 1.4,
		},
		{
			"duration": 5.5, "black": true, "letterbox": false,
			"title": "Wanderlight: Moon Shard", "subtitle": "序章〈熄滅的月燈〉",
		},
	]
