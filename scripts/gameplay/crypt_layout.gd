extends RefCounted
## Shared progression contract for builders, save migration and maps.
const NAMES := {"ashen_crypt_1": "灰燼墓窟・B1 燭火迴廊", "ashen_crypt_2": "灰燼墓窟・B2 沉灰牢廊", "ashen_crypt": "灰燼墓窟・燼冠王座"}
const BOSS_ID := "crypt_ash_warden"
const FLOOR_SPAWNS: Dictionary = {
	"ashen_crypt_1": [
		{"id": "crypt_bat_entry", "at": Vector3(-6.5, 0.05, 25), "caster": false, "art": "dusk_bat"},
		{"id": "crypt_wolf_west", "at": Vector3(6.5, 0.05, 19), "caster": false}],
	"ashen_crypt_2": [
		{"id": "crypt_wolf_east", "at": Vector3(6.5, 0.05, 25), "caster": false},
		{"id": "crypt_mage_west", "at": Vector3(-6.5, 0.05, 19), "caster": true},
		{"id": "crypt_mage_altar", "at": Vector3(5.5, 0.05, 13.5), "caster": true}],
}
static func is_floor(id: String) -> bool:
	return FLOOR_SPAWNS.has(id)
static func spawn(id: String, entrance: String) -> Vector3:
	if is_floor(id):
		return Vector3(-2 if id == "ashen_crypt_2" else 0, 0.1, 14) if entrance == "from_below" else Vector3(0, 0.1, 32.5)
	return Vector3(0, 0.1, 8.5)
static func return_point(id: String) -> Vector3:
	return Vector3(6 if id == "ashen_crypt_2" else -6, 0, 34.3)
