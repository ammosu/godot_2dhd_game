extends RefCounted
## Stable house identities shared by entrances, interiors and return spawns.

const HOMES: Array[Dictionary] = [
	{"id": "house_01", "name": "西街木屋", "position": Vector3(-12, 0, -8), "yaw": -PI * 0.5, "wall": Color("806967"), "roof": Color("59465f")},
	{"id": "house_02", "name": "花園小屋", "position": Vector3(-12, 0, 1.2), "yaw": -PI * 0.5, "wall": Color("73736a"), "roof": Color("5a4965")},
	{"id": "house_03", "name": "東街居所", "position": Vector3(12, 0, -3), "yaw": PI * 0.5, "wall": Color("667776"), "roof": Color("47566b")},
	{"id": "house_04", "name": "陶匠小屋", "position": Vector3(12, 0, 6), "yaw": PI * 0.5, "wall": Color("826b61"), "roof": Color("654957")},
	{"id": "house_05", "name": "南街暖屋", "position": Vector3(-11, 0, 10.7), "yaw": 0.0, "wall": Color("765f70"), "roof": Color("50445f")},
	{"id": "house_06", "name": "旅人居所", "position": Vector3(-4.8, 0, 11), "yaw": 0.0, "wall": Color("6c747d"), "roof": Color("46536a")},
	{"id": "house_07", "name": "東南小屋", "position": Vector3(12, 0, 11), "yaw": 0.0, "wall": Color("706a80"), "roof": Color("514b6e")},
	{"id": "house_08", "name": "北街書屋", "position": Vector3(-6, 0, -11), "yaw": PI, "wall": Color("7f725d"), "roof": Color("624b51")},
]


static func find_home(map_id: String) -> Dictionary:
	for home: Dictionary in HOMES:
		if home.id == map_id:
			return home
	return {}


static func is_interior(map_id: String) -> bool:
	return not find_home(map_id).is_empty()


static func return_position(map_id: String) -> Vector3:
	var home := find_home(map_id)
	if home.is_empty():
		return Vector3(0, 0.1, 7.5)
	return (home.position as Vector3) + Basis(Vector3.UP, float(home.yaw)) * Vector3(0, 0.1, -2.85)
