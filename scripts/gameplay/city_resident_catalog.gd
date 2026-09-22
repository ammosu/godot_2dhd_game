extends RefCounted
## Stable appearances and introductions for Starbay's stationary household hosts.
const RESIDENTS := {
	"tea_master": {"name": "小春・茶師", "line": "這身和服陪我走過很遠的路。請喝一口焙茶，星灣的水泡起來格外甘甜。"},
	"ronin": {"name": "蓮・浪人", "line": "我把刀留在鞘裡，替往來的車隊看顧行路安全。若要遠行，先檢查鞋帶和行囊。"},
	"shrine_keeper": {"name": "鈴・巫女", "line": "我從海那邊帶來了祈願木札。有人願旅途平安，也有人只盼家人早些回家。"},
	"shinobi": {"name": "影葉・信使", "line": "夜路走熟了，就能聽出每條巷子不同的風聲。我的腰包裡裝的是待送的信。"},
	"lantern_maker": {"name": "源藏・燈籠匠", "line": "竹骨要輕，糊紙要勻。等這盞燈做好，門前的晚路就會多一點暖光。"},
	"musician": {"name": "汐音・笛手", "line": "祭典散場以後，曲子還會留在心裡。我正把星灣的潮聲編進下一首笛曲。"},
	"pilgrim": {"name": "岳心・山行者", "line": "斗笠擋雨，也替我收著一路的風。山路不怕慢，只怕忘了停下來看方向。"},
	"silk_merchant": {"name": "茜・布商", "line": "這匹靛布用植物慢慢染成。和服的腰帶、旅人的披巾，都能從同一匹布開始。"},
	"spice_merchant": {"name": "莎菈・香料商", "line": "商隊越過沙地，把香料帶到海邊。打開袋口時，我總會想起故鄉市集的氣味。"},
	"astronomer": {"name": "納迪爾・觀星人", "line": "在沙漠，我們看星星辨認方向。到了星灣，天上的座標依然認得回家的路。"},
	"sailor": {"name": "芙蕾雅・水手", "line": "北方的海風會把繩結凍得發硬。這條圍巾和一手牢靠的繩結，陪我走過不少港口。"},
	"blacksmith": {"name": "布倫・鐵匠", "line": "鉸鏈、爐架、船上的扣環，都比漂亮的劍更常送到我的工作臺。工具趁手，日子才穩當。"},
	"scholar": {"name": "青禾・遊學者", "line": "我把各地的傳說記在卷冊裡。你的村子若也有關於月光的故事，我很想聽聽。"},
	"apothecary": {"name": "白朮・藥師", "line": "草藥抵達海港後，要先重新晾乾分類。這只木匣隔成小格，免得不同葉片串了氣味。"},
	"clockmaker": {"name": "伊瑟・鐘錶匠", "line": "小小的齒輪也有自己的節奏。我喜歡先聽鐘走一會兒，再找出是哪一處需要照料。"},
	"ranger": {"name": "羅文・巡林人", "line": "我從林間帶來了新畫的路線。披風沾著草木味，但只要進城，我就先找一張安穩的椅子。"},
}
const HOUSE_IDENTITIES := [
	"musician", "ronin", "spice_merchant", "silk_merchant", "blacksmith", "tea_master",
	"apothecary", "scholar", "scholar", "silk_merchant", "pilgrim", "shrine_keeper",
	"clockmaker", "astronomer", "apothecary", "lantern_maker", "blacksmith", "silk_merchant",
	"sailor", "apothecary", "clockmaker", "shinobi", "tea_master", "ranger", "spice_merchant", "shrine_keeper",
]


static func resident(index: int, room_line: String) -> Dictionary:
	var identity: String = HOUSE_IDENTITIES[index]
	var person: Dictionary = RESIDENTS[identity]
	return {"name": person.name, "art": "city_residents/" + identity, "tint": Color.WHITE,
		"text": str(person.line) + "\n" + room_line}
