extends RefCounted
## Stable house identities shared by entrances, interiors and return spawns.

const EXTERIOR_SCALE := Vector3(1.15, 1.08, 1.15)
const EXTERIOR_COLLISION := Vector3(4.0, 2.3, 3.2) * EXTERIOR_SCALE

const HOMES: Array[Dictionary] = [
	{"id": "house_01", "name": "西街木屋", "position": Vector3(-12, 0, -8), "yaw": -PI * 0.5, "wall": Color("806967"), "roof": Color("59465f")},
	{"id": "house_02", "name": "花園小屋", "position": Vector3(-12, 0, 1.2), "yaw": -PI * 0.5, "wall": Color("73736a"), "roof": Color("5a4965")},
	{"id": "house_03", "name": "東街居所", "position": Vector3(12, 0, -3), "yaw": PI * 0.5, "wall": Color("667776"), "roof": Color("47566b")},
	{"id": "house_04", "name": "陶匠小屋", "position": Vector3(12, 0, 6), "yaw": PI * 0.5, "wall": Color("826b61"), "roof": Color("654957")},
	{"id": "house_05", "name": "南街暖屋", "position": Vector3(-11, 0, 10.7), "yaw": 0.0, "wall": Color("765f70"), "roof": Color("50445f")},
	{"id": "house_06", "name": "旅人居所", "position": Vector3(-4.8, 0, 11), "yaw": 0.0, "wall": Color("6c747d"), "roof": Color("46536a")},
	{"id": "house_07", "name": "東南小屋", "position": Vector3(12, 0, 12.3), "yaw": 0.0, "wall": Color("706a80"), "roof": Color("514b6e")},
	{"id": "house_08", "name": "北街書屋", "position": Vector3(-6, 0, -11), "yaw": PI, "wall": Color("7f725d"), "roof": Color("624b51")},
]


const FURNITURE: Dictionary = {
	"house_01": {"name": "織布架", "text": "半織好的布面反覆出現菱形紋樣。仔細看，那其實像是被簡化的道路交會圖。"},
	"house_02": {"name": "育苗工作架", "text": "三盆幼苗沒有朝窗邊，而是齊齊向村外伸展。盆沿註記寫著：只在月光恢復時才會如此。"},
	"house_03": {"name": "月相紀錄架", "text": "多年卷冊顯示月相如常，照進村裡的月光卻逐年偏移。這場異常並非三天前才開始。"},
	"house_04": {"name": "晾陶架", "text": "舊陶器底部都壓著帶缺口的環形印記，較新的器皿卻不再使用它。沒有人留下原因。"},
	"house_05": {"name": "布料櫃", "text": "布卷依顏色排好，下層疊著洗淨的亞麻布。暖紅與米白的布料讓屋內顯得格外溫暖。"},
	"house_06": {"name": "旅人裝備架", "text": "架上留著許多不同尺寸的舊行裝。暮光村曾接待大量過路者；北門封閉後，這間屋才漸漸空下來。"},
	"house_07": {"name": "草藥架", "text": "幾束乾草藥旁標著早已陌生的地名。採集筆記說，它們來自如今無人能抵達的古道路線。"},
	"house_08": {"name": "藏書閱讀櫃", "text": "建村紀錄有兩種互相矛盾的版本；夾頁間留下整齊撕痕，所有提到『引路人』的段落都不見了。"},
}


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
	return (home.position as Vector3) + Basis(Vector3.UP, float(home.yaw)) * Vector3(0, 0.1, -2.85 * EXTERIOR_SCALE.z)


static func safe_village_position(position: Vector3) -> Vector3:
	# Old saves retain world coordinates. Relocate only points now inside an
	# expanded home (including the player's radius), without rewriting the save.
	for home: Dictionary in HOMES:
		var local: Vector3 = Basis(Vector3.UP, -float(home.yaw)) * (position - (home.position as Vector3))
		var half_size: Vector3 = EXTERIOR_COLLISION * 0.5
		if absf(local.x) < half_size.x + 0.3 and absf(local.z) < half_size.z + 0.3 and local.y < EXTERIOR_COLLISION.y:
			return return_position(home.id)
	return position
