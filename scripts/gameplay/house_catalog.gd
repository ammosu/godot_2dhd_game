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


const FURNITURE: Dictionary = {
	"house_01": {"name": "織布架", "text": "經線繃在木框之間，半織好的布面露出菱形紋樣。木梭停在布邊，像是屋主剛起身歇息。"},
	"house_02": {"name": "育苗工作架", "text": "三盆幼苗向光伸展，下層土盤已經備好。盆沿還留著照料植物時沾上的泥土。"},
	"house_03": {"name": "月相紀錄架", "text": "木架上的月相圖與下層卷冊排得整齊。村人似乎一直記錄著月光的變化。"},
	"house_04": {"name": "晾陶架", "text": "陶器分層晾在木架上，大小略有不同。每件都留出了空隙，等待陶土慢慢乾透。"},
	"house_05": {"name": "布料櫃", "text": "布卷依顏色排好，下層疊著洗淨的亞麻布。暖紅與米白的布料讓屋內顯得格外溫暖。"},
	"house_06": {"name": "旅人裝備架", "text": "背包扣得整齊，睡袋捲在上方，手杖靠在架邊。這些行裝隨時可以帶上旅途。"},
	"house_07": {"name": "草藥架", "text": "成束草藥倒掛在通風處，下層陶罐等待收納。淡淡的草木氣味留在屋裡。"},
	"house_08": {"name": "藏書閱讀櫃", "text": "卷軸與書冊分格收好，一本書攤在斜面閱讀台上。屋主似乎正在比對月光與星辰的紀錄。"},
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
	return (home.position as Vector3) + Basis(Vector3.UP, float(home.yaw)) * Vector3(0, 0.1, -2.85)
