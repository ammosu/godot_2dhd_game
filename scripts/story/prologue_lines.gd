extends RefCounted
## Prologue "霧中醒來" dialogue data (see docs/SCRIPT.md). Plain data only;
## Prologue decides when each scene plays.

const OBJECTIVES: Dictionary = {
	"road": "序幕：看看四周",
	"follow": "序幕：跟著月光往西走",
	"house": "序幕：換上外衣，到廣場找長老",
}
const CONTROLS_DESKTOP: String = "使用 WASD 或方向鍵移動；靠近有記號的東西後，按 Space 調查。M 靜音，- / = 調整音量。"
const CONTROLS_MOBILE: String = "使用左側搖桿移動；靠近有記號的東西後，點右側「互動」。"

const SCENES: Dictionary = {
	"belongings": [
		{"speaker": "旁白", "text": "外衣的袖子被荊棘劃開一道長口子。口袋裡什麼也沒有，只有一個空水壺。"},
		{"speaker": "旅人", "text": "我叫什麼名字？……想不起來。", "emote": "ellipsis"},
		{"speaker": "旅人", "text": "從哪裡來的，也想不起來。"},
	],
	"sign": [
		{"speaker": "旁白", "text": "路標倒在泥裡。往東和往北的木牌泡了水，字都糊了。"},
		{"speaker": "旁白", "text": "只有往西那塊還讀得出來：「西・暮光村」。"},
		{"speaker": "旅人", "text": "暮光村……那裡應該有人住。", "act": "nod"},
	],
	"lamp": [
		{"speaker": "旁白", "text": "路邊立著一盞舊路燈。燈罩裡積滿了灰，摸上去是冷的。"},
		{"speaker": "旅人", "text": "這條路以前應該很多人走。現在連一盞亮著的燈都沒有。"},
	],
	"east_fog": [
		{"speaker": "旁白", "text": "往東走了幾步，霧濃得連腳都看不見。回過神來，又站在剛才醒來的地方。"},
		{"speaker": "旅人", "text": "……這邊走不出去。", "emote": "ellipsis"},
	],
	"west_too_soon": [
		{"speaker": "旅人", "text": "霧太濃了，前面什麼都看不見。……先看看附近有沒有路標。", "emote": "question"},
	],
	"whisper_after": [
		{"speaker": "旅人", "text": "誰？", "act": "surprise", "emote": "question"},
		{"speaker": "旁白", "text": "沒有人回答。"},
	],
	"halfway": [
		{"speaker": "旅人", "text": "……燈。前面真的有燈。"},
	],
	"wake": [
		{"speaker": "村童・露米", "text": "你醒了！媽媽，旅人醒了！", "act": "joy", "emote": "exclaim"},
		{"speaker": "旅人", "text": "……這裡是？"},
		{"speaker": "村童・露米", "text": "這裡是旅人居所。以前很多過路的人住這裡，現在只剩雷恩叔叔。"},
		{"speaker": "村童・露米", "text": "三天前你倒在村口，是我先看到的喔。你一直在睡，我每天晚上都送湯來，今天是蘿蔔湯。"},
		{"speaker": "村童・露米", "text": "你睡著的時候一直皺著眉頭。做了很長的夢嗎？", "emote": "question"},
		{"speaker": "旅人", "text": "……夢到很多燈。醒來就想不起來了。", "emote": "ellipsis"},
		{"speaker": "旅人", "text": "我什麼都不記得，只記得一句話：「往西走，那裡還有一盞燈。」"},
		{"speaker": "村童・露米", "text": "燈？村裡最大的燈，就是廣場的月燈呀。", "emote": "question"},
		{"speaker": "村童・露米", "text": "可是月燈快熄了。從你來的那天晚上開始，月光就沒有照進村子。", "emote": "ellipsis"},
		{"speaker": "村童・露米", "text": "你的外衣破了一個大洞，媽媽幫你補好了，放在床邊。穿好再出門喔。"},
		{"speaker": "村童・露米", "text": "艾爾爺爺一直守在廣場那邊。你去看看好不好？", "act": "hop"},
		{"speaker": "旁白", "text": "露米抱著空碗跑出門。"},
		{"speaker": "旅人・雷恩", "text": "我也是過路的。本來只想住一晚，北門卻一直沒開。……多吃點，你瘦得跟樹枝一樣。"},
	],
	"coat": [
		{"speaker": "旁白", "text": "外衣袖子上的長口子縫好了，針腳很細。口袋裡多了一小包乾果。"},
		{"speaker": "旅人", "text": "……謝謝。", "act": "nod"},
	],
	"coat_first": [
		{"speaker": "旅人", "text": "外衣還放在床邊。先穿上再出門吧。"},
	],
	"window": [
		{"speaker": "旁白", "text": "窗外看得到廣場的月燈，光弱得像快熄的炭火。天上明明有月亮，月光卻落不進來。"},
	],
	"rack_echo": [
		{"speaker": "旅人", "text": "……燈排成一列。為什麼會想到這個？", "emote": "ellipsis"},
	],
}
