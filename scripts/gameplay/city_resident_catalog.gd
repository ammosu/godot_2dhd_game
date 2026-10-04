extends RefCounted
## Stable appearances and introductions for Starbay's stationary household hosts.
## One distinct person per address; several may share an outfit atlas.
const HOUSEHOLDS: Array[Dictionary] = [
	{"art": "musician", "name": "汐音・笛手", "line": "我每天在市集吹笛，魚攤老闆總嫌太小聲。鐘一響，我就收笛子。"},
	{"art": "ronin", "name": "蓮・佩刀浪人", "line": "今晚輪到我跟接應隊出城找人。刀先擦好，找人的繩子也得帶上。"},
	{"art": "spice_merchant", "name": "莎菈・香料商", "line": "港邊太潮，香料袋得天天翻。隔壁總說，聞到胡椒味就知道我起床了。"},
	{"art": "silk_merchant", "name": "茜・布商", "line": "下午若有太陽，整條街都在曬布。我得早點收，免得夜霧又把布弄濕。"},
	{"art": "blacksmith", "name": "布倫・鐵匠", "line": "碼頭送來一袋生鏽的扣環，夠我忙三天。晚飯又得請鄰居留一碗了。"},
	{"art": "tea_master", "name": "千穗・茶師", "line": "水手們愛喝濃茶，一坐下就聊到忘了時間。我收杯子，他們才肯回家。"},
	{"art": "apothecary", "name": "白朮・藥師", "line": "海風一吹，藥草總乾得不勻。我每天翻三回，比翻自家菜鍋還勤。"},
	{"art": "scholar", "name": "青禾・遊學者", "line": "我替碼頭的人寫家書。有人只說一切都好，卻坐著不肯走。"},
	{"art": "scholar", "name": "文川・抄書人", "line": "這裡的書容易受潮，得常翻開晾晾。最難找回來的，倒是借給鄰居的食譜。"},
	{"art": "silk_merchant", "name": "藍枝・染布商", "line": "今天染的藍布，跟港裡的水一個顏色。可別摸，我的手到現在還洗不乾淨。"},
	{"art": "pilgrim", "name": "岳心・山行者", "line": "我走慣山路，也不敢趁夜霧出門。留在城裡補草鞋，明早再走。"},
	{"art": "shrine_keeper", "name": "鈴・巫女", "line": "鐘樓庭那面牆掛滿了木牌。上頭寫的，都是沒等到鐘聲的人。"},
	{"art": "clockmaker", "name": "伊瑟・鐘錶匠", "line": "我修小鐘，也常聽樓上的大鐘。敲一聲長的，就是叫大家回家。"},
	{"art": "astronomer", "name": "納迪爾・觀星人", "line": "我在屋頂看星星，晚飯都靠樓下喊。起霧後，只有月光還能穿過去。"},
	{"art": "apothecary", "name": "芷安・藥師", "line": "港邊老人常來這裡歇腳。說是問草藥，其實都在等我那壺熱水。"},
	{"art": "lantern_maker", "name": "源藏・燈籠匠", "line": "茶棚訂的燈籠又破了，八成是那隻貓。牠每晚都來撥底下的流蘇。"},
	{"art": "blacksmith", "name": "鐵平・鐵匠", "line": "陶坊請我修爐架，拿一只碗抵工錢。我家都快沒地方擺了。"},
	{"art": "silk_merchant", "name": "綾乃・布商", "line": "船一靠岸，大家就來補袖口。海風吹裂的地方，得多縫一層。"},
	{"art": "sailor", "name": "芙蕾雅・水手", "line": "船還沒卸完貨，我先回來煮魚湯。住得離碼頭近，就這點好。"},
	{"art": "apothecary", "name": "冬青・藥師", "line": "藥草不能跟鹹魚一起曬。我跟樓上的水手說了好幾回，他總忘。"},
	{"art": "clockmaker", "name": "修恩・鐘錶匠", "line": "茶棚那座鐘又慢了。老闆說不用急，客人多坐一會兒也好。"},
	{"art": "shinobi", "name": "影葉・信使", "line": "送晚信時，我最怕聽到三聲短鐘。那是說，還少一個人。"},
	{"art": "tea_master", "name": "澄江・茶師", "line": "我把靠窗的座位留給卸貨的人。他們喝完茶，常常就坐著睡著了。"},
	{"art": "ranger", "name": "羅文・巡林人", "line": "我替接應隊試過手鈴，這只最響。今晚他們出城找人，就帶它去。"},
	{"art": "spice_merchant", "name": "米娜・香料商", "line": "貨船還沒到，今天沒香料可賣。鄰居倒先端了魚來，問我怎麼煮。"},
	{"art": "shrine_keeper", "name": "真緒・巫女", "line": "市集的孩子常來借掃帚，說要幫我掃地。結果都拿去趕偷魚的貓。"},
]


static func resident(index: int, room_line: String) -> Dictionary:
	var person: Dictionary = HOUSEHOLDS[index]
	return {"name": person.name, "art": "city_residents/" + str(person.art), "tint": Color.WHITE,
		"text": str(person.line) + "\n" + room_line}
