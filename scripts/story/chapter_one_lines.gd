extends RefCounted
## Chapter 1 dialogue data (drafted with Codex CLI, edited for continuity).
## Plain data only; ChapterOne decides when each scene plays.
## Optional "act"/"emote" make the speaker perform (see actor_acting.gd).

const SCENES: Dictionary = {
	"seal_open_post": [
		{"speaker": "諾亞", "text": "我先走。裡面還看不清。", "act": "nod"},
		{"speaker": "希雅", "text": "才叫你退後，又走到最前面了。慢點，等我們。", "emote": "ellipsis"},
	],
	"seal_open_pre": [
		{"speaker": "希雅", "text": "鐘槌給我。讓我試試這裡。", "act": "hop"},
		{"speaker": "希雅", "text": "先用小鈴問問它。會回應的話，再用大槌敲。"},
		{"speaker": "希雅", "text": "大家退後。諾亞，你也算大家。", "act": "laugh", "emote": "exclaim"},
	],
	"escort_done": [
		{"speaker": "驛路旅人", "text": "謝、謝謝。腿還在抖……你們有沒有受傷？", "act": "shiver", "emote": "ellipsis"},
		{"speaker": "旅人", "text": "沒事。先坐一下，等腿不抖了再走。", "act": "nod"},
		{"speaker": "旁白", "text": "諾亞蹲下替他撿起行囊，聲音壓得很低。"},
		{"speaker": "諾亞", "text": "……那時我沒有回頭。", "emote": "ellipsis"},
		{"speaker": "驛路旅人", "text": "嗯？你說什麼？", "emote": "question"},
		{"speaker": "旅人", "text": "我們想沿這條路走。前面能通嗎？"},
		{"speaker": "驛路旅人", "text": "墓窟有道封門。上面的鐘紋是星灣城鐘樓的，去問守鐘的人吧。"},
	],
	"escort_start": [
		{"speaker": "旁白", "text": "路上的燈剛亮起，兩隻野獸便循光跑來，把一人逼到路邊。"},
		{"speaker": "諾亞", "text": "回村把門關上。快。", "act": "surprise"},
		{"speaker": "驛路旅人", "text": "別、別往這邊走！牠們會撲人！", "act": "shiver", "emote": "shock"},
		{"speaker": "旅人", "text": "他還在那裡。我得去幫他。", "act": "hop", "emote": "exclaim"},
		{"speaker": "旁白", "text": "諾亞望向村口，攥緊了手，又轉回身。"},
		{"speaker": "諾亞", "text": "……狼交給我。那隻蝙蝠擋著他的路，你去！", "act": "hop", "emote": "exclaim"},
		{"speaker": "系統", "text": "擊退靠近驛路旅人的野獸。"},
	],
	"lamp_east": [
		{"speaker": "旁白", "text": "露米抱著一封信跑過來。"},
		{"speaker": "村童・露米", "text": "你看！我的影子也朝東邊跑了！", "act": "joy", "emote": "music"},
		{"speaker": "村童・露米", "text": "這封信，可以幫我帶給外面的人嗎？", "act": "hop"},
		{"speaker": "旅人", "text": "信上怎麼沒寫名字？", "emote": "question"},
		{"speaker": "村童・露米", "text": "我還不認識他們呀。", "act": "laugh"},
		{"speaker": "旁白", "text": "你收下了露米的信。"},
	],
	"elder_confess": [
		{"speaker": "旅人", "text": "你手上的灼痕，怎麼和月燈上的記號一樣？", "emote": "question"},
		{"speaker": "旁白", "text": "艾爾把袖口拉低，又慢慢鬆開。"},
		{"speaker": "長老・艾爾", "text": "這盞燈是從更大的東西上拆下來的。"},
		{"speaker": "旅人", "text": "是誰拆的？", "emote": "question"},
		{"speaker": "長老・艾爾", "text": "……祖先把光留在村裡。從那以後，外面的路就暗了。", "emote": "ellipsis"},
		{"speaker": "長老・艾爾", "text": "村裡的舊紀錄被撕掉了幾頁。我一直知道，卻從沒說出口。"},
		{"speaker": "旅人", "text": "路暗下來的時候，外面的人怎麼辦？"},
		{"speaker": "長老・艾爾", "text": "……舊紀錄沒有留下他們的名字。", "emote": "ellipsis"},
		{"speaker": "旅人", "text": "我也是從那條路走來的。我想去看看。", "act": "nod"},
		{"speaker": "長老・艾爾", "text": "請你沿著光路往東走。", "act": "nod"},
		{"speaker": "長老・艾爾", "text": "村裡的月燈，我會守著。"},
	],
	"noah_joins": [
		{"speaker": "守門人・諾亞", "text": "我在等你。", "act": "nod"},
		{"speaker": "旅人", "text": "今天不守門了？", "emote": "question"},
		{"speaker": "守門人・諾亞", "text": "找人換班了。不能擅自走。"},
		{"speaker": "守門人・諾亞", "text": "門我守了很多年。"},
		{"speaker": "守門人・諾亞", "text": "這一次，換我替你開路。", "act": "hop", "emote": "exclaim"},
		{"speaker": "旁白", "text": "諾亞提起放在腳邊的行囊，站到你身旁。"},
	],
	"seal_blocked": [
		{"speaker": "諾亞", "text": "退後。我試試。", "act": "nod"},
		{"speaker": "旁白", "text": "諾亞抵住石門，推了兩次。門一動也不動。"},
		{"speaker": "旅人", "text": "別硬推了。我們去星灣城。"},
		{"speaker": "諾亞", "text": "嗯。記住這個地方，還要回來。", "act": "nod"},
	],
	"sia_joins": [
		{"speaker": "鐘守・希雅", "text": "別靠太近。這口鐘裂了，今天脾氣不好。", "act": "hop", "emote": "exclaim"},
		{"speaker": "旅人", "text": "我們從暮光村來。墓窟有道門推不開，鐘紋是這樣的。"},
		{"speaker": "旁白", "text": "你蹲下，用小石子在地上畫出門上的鐘紋。"},
		{"speaker": "鐘守・希雅", "text": "暮光村？那個關起門的村子……好啦，至少你們走出來了。", "act": "surprise", "emote": "shock"},
		{"speaker": "鐘守・希雅", "text": "門上的鐘，跟我們鐘樓用的是同一種記號。"},
		{"speaker": "鐘守・希雅", "text": "這幾年，鐘聲一年比一年傳得近。說不定答案就在那道門後。", "emote": "ellipsis"},
		{"speaker": "旅人", "text": "還有這封信。露米寫給外面的人。"},
		{"speaker": "鐘守・希雅", "text": "交給我吧。孩子們，先別敲了，有信！", "act": "joy", "emote": "music"},
		{"speaker": "鐘樓的孩子・小汐", "text": "她家也聽得到鐘嗎？我要寫回信！"},
		{"speaker": "鐘樓的孩子・阿遙", "text": "我來畫鐘！畫大一點，他們才看得到。"},
		{"speaker": "鐘守・希雅", "text": "師父，今晚的鐘交給你了！"},
		{"speaker": "鐘樓師父・嚴", "text": "去吧。鐘聲變近的事，我也想知道答案。"},
	],
	"ember_shard": [
		{"speaker": "旁白", "text": "祭壇後的空王座，傳來一陣低語。"},
		{"speaker": "燼冠的低語", "text": "分出去的月光……不會回來了。"},
		{"speaker": "旅人", "text": "誰在說話？", "act": "surprise", "emote": "shock"},
		{"speaker": "旁白", "text": "王座旁有一扇小門。門栓從裡面插上了。"},
		{"speaker": "諾亞", "text": "……有人嗎？", "emote": "question"},
		{"speaker": "旁白", "text": "沒有回聲。"},
		{"speaker": "諾亞", "text": "門是從裡面鎖上的。"},
		{"speaker": "旁白", "text": "沒有回應。你從祭壇取下碎片，上面覆著一層灰。"},
		{"speaker": "旁白", "text": "一道月光從王座上方的裂縫照進來。碎片上的灰微微一亮，又暗下去。"},
		{"speaker": "希雅", "text": "看見了嗎？月光照到的時候，灰亮了一下。", "act": "hop", "emote": "exclaim"},
		{"speaker": "希雅", "text": "也許要找月光最強、霧最薄的高處。去月冠高地試試吧。"},
		{"speaker": "旅人", "text": "好。我們帶它上去。", "act": "nod"},
	],
	"campfire": [
		{"speaker": "旁白", "text": "三人圍著營火坐下。湯還冒著熱氣。"},
		{"speaker": "諾亞", "text": "那天在舊道，我只想回村關門。你卻回頭去救人。"},
		{"speaker": "旅人", "text": "他還在喊。我走不了。"},
		{"speaker": "諾亞", "text": "……有些門，是為了讓人回家而開。", "emote": "ellipsis"},
		{"speaker": "希雅", "text": "我們敲鐘，也是想告訴外面的人：還有人等你。", "emote": "music"},
		{"speaker": "旅人", "text": "我連以前有誰等過我，都想不起來。", "emote": "ellipsis"},
		{"speaker": "諾亞", "text": "……你讓我想起一個人。只是有點像。", "emote": "ellipsis"},
		{"speaker": "旅人", "text": "是誰？", "emote": "question"},
		{"speaker": "旁白", "text": "諾亞張了張嘴，沒說下去，只把湯碗往你手邊推近。"},
		{"speaker": "希雅", "text": "先喝一口吧。想事情也得暖著肚子。", "act": "laugh"},
	],
	"lantern_bearer": [
		{"speaker": "提燈人", "text": "古道醒來時，我也醒了。"},
		{"speaker": "提燈人", "text": "把碎片帶回它原本的地方。"},
		{"speaker": "提燈人", "text": "……你終於回來了。"},
		{"speaker": "諾亞", "text": "你認得他？先別走，把話說清楚。", "act": "surprise", "emote": "shock"},
		{"speaker": "希雅", "text": "原本的地方在哪？總得給我們指個方向吧。", "emote": "question"},
		{"speaker": "旅人", "text": "等等……是你叫我往西走，去找那盞燈的嗎？", "act": "surprise", "emote": "exclaim"},
		{"speaker": "提燈人", "text": "是我。那晚在舊道上，霧太濃，我只能替你指一個方向。"},
		{"speaker": "提燈人", "text": "碎片每回到一盞燈裡，就會有一條路從霧裡亮起來。你們走過的路，就是第一條。"},
		{"speaker": "提燈人", "text": "看見海那邊，那盞藍色的燈了嗎？下一片碎片，就在那盞燈底下。"},
		{"speaker": "旁白", "text": "提燈人轉身走回霧裡。遠方的雲海裡，亮起了幾點燈。"},
		{"speaker": "希雅", "text": "……那些燈，都是還在等人的地方吧。先回家，把信交給露米。", "act": "nod"},
	],
}
const ELDER_REPEAT: Dictionary = {
	1: "你一直看著我的手……有話就問吧。",
	2: "諾亞在村子東口等你。",
	3: "我習慣往門邊看，才想起諾亞已經跟你走了。",
	4: "那道門上的鐘，我也不懂，去星灣城問問吧。",
	5: "鐘守也肯幫我們……回頭該好好謝謝人家。",
	6: "門後若有人，先聽聽他們說什麼。",
	7: "碎片上的灰燼……我不敢亂碰。",
	8: "山上冷，村裡還有厚衣，帶一件再走。",
	9: "你回來了……這回，我會好好聽你說。",
}
const RUMI_REPEAT: Dictionary = {
	1: "信裡畫的那隻是小豬，不是馬鈴薯喔。",
	2: "諾亞哥哥帶好多東西，他也要出門嗎？",
	3: "外面的人，吃飯也會配湯嗎？",
	4: "門上畫著鐘，那敲門會噹噹響嗎？",
	5: "星灣城的小朋友，會喜歡我畫的小豬嗎？",
	6: "我又畫了一隻小豬。這次有畫尾巴，不會像馬鈴薯了吧？",
	7: "媽媽教我煮湯了！不過她只讓我負責洗碗。",
	8: "到山上以後，幫我看看月亮有沒有變大。",
	9: "下次去星灣城，我想帶媽媽一起。",
}
const ROAD_TRAVELER: Dictionary = {
	3: "墓窟門上那口鐘，跟星灣城鐘樓的一樣。",
	4: "找守鐘的就去星灣城鐘樓庭，那裡白天也有人。",
	5: "鐘槌都帶來了？看來那道門有得吵了。",
	6: "墓窟的門開了，路過的人總算不用繞去看石縫。",
	7: "要上山就走螢光森林那頭，接著是苔階山徑。",
	8: "山上的霧厚，走慢點，別只顧著看月亮。",
	9: "昨晚遠處多了幾點燈，我還以為自己看花了。",
}
const SEAL_REPEAT: Dictionary = {
	3: "石門仍推不動，石縫裡露著一枚鐘紋。",
	4: "門上的鐘紋沒有動靜，得去星灣城找守鐘的人。",
}
const OBJECTIVES: Dictionary = {
	0: "第一章：查看廣場月燈",
	1: "第一章：向艾爾詢問灼痕",
	2: "第一章：到村子東口找諾亞",
	3: "第一章：沿光路走向東行舊道",
	4: "第一章：到星灣城鐘樓庭找希雅",
	5: "第一章：返回墓窟敲響封門",
	6: "第一章：擊敗維爾莫並調查血晶祭壇",
	7: "第一章：在風切峽道營火旁休息",
	8: "第一章：前往月冠高地眺望台",
	9: "第一章：醒來的古道・完",
}
const SIA_WAITING: String = "找我嗎？等我把鐘槌放下，免得敲到你的腳。"
const PARTY_TALK: Dictionary = {
	"only_noah": {
		"east_road": [
			{"speaker": "諾亞", "text": "這幾盞路燈，昨天還沒亮。"},
			{"speaker": "諾亞", "text": "跟著亮處走。我看著後面。"},
		],
		"firefly_forest": [
			{"speaker": "諾亞", "text": "剛才還以為那些亮點是別人的燈。", "emote": "question"},
			{"speaker": "諾亞", "text": "……是蟲子。走吧。", "emote": "ellipsis"},
		],
		"caravan_road": [
			{"speaker": "諾亞", "text": "車輪印很深，這裡常有人走。"},
			{"speaker": "諾亞", "text": "有人迎面來，就讓半步。"},
		],
		"starbay": [
			{"speaker": "諾亞", "text": "這麼晚了，門還開著。"},
			{"speaker": "諾亞", "text": "我想問問，他們怎麼知道人都回來了。"},
		],
		"ashen_crypt_1": [
			{"speaker": "諾亞", "text": "這裡的腳步聲會繞回來。"},
			{"speaker": "諾亞", "text": "別急著回頭，我在你後面。"},
		],
		"ashen_crypt_2": [
			{"speaker": "諾亞", "text": "這些門，從裡面都碰不到門栓。"},
			{"speaker": "諾亞", "text": "……再看看，別漏下誰。"},
		],
		"moss_steps": [
			{"speaker": "諾亞", "text": "踩石頭邊上，中間的苔會滑。"},
			{"speaker": "諾亞", "text": "我的手空著。要扶就扶。"},
		],
		"wind_gorge": [
			{"speaker": "諾亞", "text": "風大的時候，先停下來。"},
			{"speaker": "諾亞", "text": "沒人催我們。站穩再走。"},
		],
		"moon_highland": [
			{"speaker": "諾亞", "text": "從這裡看，村子只剩一點光。"},
			{"speaker": "諾亞", "text": "原來外面這麼大。"},
		],
		"village": [
			{"speaker": "諾亞", "text": "剛才又想往守門的位置走。"},
			{"speaker": "諾亞", "text": "不用等我。我記得今天跟著你。"},
		],
	},
	"both": {
		"east_road": [
			{"speaker": "希雅", "text": "諾亞，你連路邊的石頭都要檢查？", "act": "laugh"},
			{"speaker": "諾亞", "text": "怕有人絆倒。", "act": "nod"},
			{"speaker": "希雅", "text": "那顆太大了，咱們提醒人繞過去吧。"},
		],
		"firefly_forest": [
			{"speaker": "希雅", "text": "這些小亮點，比我的鈴還會招人。"},
			{"speaker": "諾亞", "text": "但牠們不會等人。"},
			{"speaker": "希雅", "text": "那還是跟著我們吧。"},
		],
		"caravan_road": [
			{"speaker": "諾亞", "text": "又有車來了，往旁邊站。"},
			{"speaker": "希雅", "text": "你這句，比路牌還管用。", "act": "laugh", "emote": "music"},
			{"speaker": "諾亞", "text": "先站過來。"},
		],
		"starbay": [
			{"speaker": "希雅", "text": "聽，今天換別人在敲鐘了。"},
			{"speaker": "諾亞", "text": "你聽得出來？"},
			{"speaker": "希雅", "text": "他每次都慢半拍，我等得手癢。", "act": "hop"},
		],
		"ashen_crypt_1": [
			{"speaker": "希雅", "text": "我的鈴只響一下，這裡倒回了三下。"},
			{"speaker": "諾亞", "text": "先收起來。免得聽漏腳步聲。"},
			{"speaker": "希雅", "text": "好，出去再吵。", "act": "laugh"},
		],
		"ashen_crypt_2": [
			{"speaker": "諾亞", "text": "門裡也有抓痕。"},
			{"speaker": "希雅", "text": "……我有點懂你們為什麼怕了。", "act": "shiver", "emote": "ellipsis"},
			{"speaker": "諾亞", "text": "再怕，也得看看裡面還有沒有誰。"},
		],
		"moss_steps": [
			{"speaker": "希雅", "text": "誰把路修成這樣，天天上山練腿嗎？", "emote": "shock"},
			{"speaker": "諾亞", "text": "鐘槌給我拿一段。"},
			{"speaker": "希雅", "text": "借你拿，可別順手拿去敲石頭。"},
		],
		"wind_gorge": [
			{"speaker": "希雅", "text": "我的話剛出口，就被風吹走了。"},
			{"speaker": "諾亞", "text": "靠近一點。我聽著。"},
			{"speaker": "希雅", "text": "我說，想找個沒風的地方吃飯！", "act": "hop", "emote": "exclaim"},
		],
		"moon_highland": [
			{"speaker": "諾亞", "text": "離邊上遠一點。"},
			{"speaker": "希雅", "text": "知道啦。你也抬頭看看月亮。"},
			{"speaker": "諾亞", "text": "……看見了。真亮。", "act": "nod"},
		],
		"village": [
			{"speaker": "希雅", "text": "露米畫的小豬，是廣場那隻吧？"},
			{"speaker": "諾亞", "text": "嗯。別餵，剛吃過。"},
			{"speaker": "希雅", "text": "你連牠的飯都管啊。", "act": "laugh", "emote": "music"},
		],
	},
}
const HIDDEN: Dictionary = {
	"city_map": [
		{"speaker": "旁白", "text": "古城街巷圖的角落，留著一枚完整的紋章。"},
		{"speaker": "旁白", "text": "紋章是一個留有缺口的圓環，旁邊寫著「引路之環」。"},
		{"speaker": "旁白", "text": "圖上，暮光村與星灣城被標為同一條路上的兩個驛站。"},
		{"speaker": "旅人", "text": "原來以前，這條路是連著的。", "act": "surprise", "emote": "exclaim"},
	],
	"city_map_after": [
		{"speaker": "旅人", "text": "圖上的路也經過墓窟入口，現在那裡卻多了一道門。"},
	],
	"rumi_reply": [
		{"speaker": "旅人", "text": "露米，這是星灣城的回信。"},
		{"speaker": "旁白", "text": "露米接過回信，小心地攤平折角。"},
		{"speaker": "村童・露米", "text": "「露米，你畫的小豬很可愛。」"},
		{"speaker": "村童・露米", "text": "「下次來，帶你看看我們的鐘。」"},
		{"speaker": "村童・露米", "text": "「也想去你家喝湯。」……他們想來耶！", "act": "joy", "emote": "heart"},
		{"speaker": "旅人", "text": "那要先跟你媽媽說一聲。"},
		{"speaker": "村童・露米", "text": "嗯！我要問她，我們有幾個碗。"},
		{"speaker": "旁白", "text": "旁邊的村民聽見了，笑著比了比自家門口，說碗不夠就來拿。"},
		{"speaker": "長老・艾爾", "text": "光路亮了，野獸也會跟著來。東口以後要有人守著——不是擋人，是接人。"},
		{"speaker": "守門人・諾亞", "text": "我來排班。晚上沿路巡燈，燈滅了就點。這次，我會開門。"},
		{"speaker": "鐘守・希雅", "text": "那我教大家認鐘號。三短聲，就是還少一個人。"},
	],
}
## Stage 3 road rescue objectives, by GameState.flags["ch1_escort"].
const ESCORT_OBJECTIVES: Dictionary = {"fighting": "第一章：擊退靠近驛路旅人的野獸", "won": "第一章：與驛路旅人交談"}
