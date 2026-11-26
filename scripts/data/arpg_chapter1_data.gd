class_name ArpgChapter1Data
extends RefCounted
## Static data definitions for ARPG Adventure Mode — Chapter 1:
## 「第一章：櫻花之里・失落的言靈碑」.

const STAGE_ID: String = "arpg_ch1"
const CHAPTER_TITLE: String = "第一章：櫻花之里・失落的言靈碑"

const MIN_X: float = -120.0
const MAX_X: float = 120.0
const MIN_Z: float = -140.0
const MAX_Z: float = 140.0

const PLAYER_SPAWN: Vector3 = Vector3(0.0, 0.0, 104.0)
const HEAL_SPRING_POS: Vector3 = Vector3(-18.0, 0.0, -72.0)
const HEAL_SPRING_RADIUS: float = 4.8

const QUEST_STEPS: Array = [
	{
		"step": 0,
		"title": "初臨蒼海峽灣・前往櫻花之里會見巫女美桜",
		"desc": "你甦醒於『蒼海峽灣・海濱沙灘』，西側巍峨的『櫻岳高山』與碧海相映。請穿越北方的海風花海曠野前往『櫻花之里』中央，與巫女・美桜對話（村中兩側還有茶屋店主與鍛冶師可切磋日語）。",
		"target_pos": Vector3(0.0, 0.0, 30.0),
		"target_label": "⛩️ 巫女・美桜",
	},
	{
		"step": 1,
		"title": "跨越緋紅太鼓橋・擊退橋上伏擊妖怪",
		"desc": "沿著櫻花參道向北踏上緋紅太鼓橋，討伐盤踞在橋面的提燈小鬼與傘妖！",
		"target_pos": Vector3(0.0, 0.0, 2.0),
		"target_label": "🌉 緋紅太鼓橋",
	},
	{
		"step": 2,
		"title": "深入幽暗竹海・淨化荒野溪谷妖群",
		"desc": "穿過緋紅太鼓橋進入幽暗竹海與荒野溪谷，肅清潛伏於竹影間的妖怪伏兵（西側地藏神龕空地似有旅人受困）。",
		"target_pos": Vector3(2.0, 0.0, -34.0),
		"target_label": "🎋 幽暗竹海・荒野溪谷",
	},
	{
		"step": 3,
		"title": "登上千本鳥居山道・請益白狐神主",
		"desc": "步上千本鳥居山道，拜見東側石龕的白狐神主獲取神護與言靈祝福（西側靈泉可恢復體力，亦可直接前往大祭壇迎戰首領）。",
		"target_pos": Vector3(18.0, 2.6, -72.0),
		"target_label": "🦊 白狐神主",
	},
	{
		"step": 4,
		"title": "決戰滿月夜櫻大祭壇・討伐赤鬼大将",
		"desc": "登上最高處的滿月夜櫻大祭壇，以劍技與日語「言靈奧義」擊敗第一章首領「赤鬼大将・獄炎」，奪回失落的言靈碑！",
		"target_pos": Vector3(0.0, 4.6, -108.0),
		"target_label": "👹 赤鬼大将・獄炎",
	},
	{
		"step": 5,
		"title": "第一章通關・蒼海峽灣與櫻花之里自由探索",
		"desc": "言靈碑已重拾神光、櫻花之里恢復寧靜！你可以自由探索蒼海峽灣、櫻岳高山、月見湖與整片曠野，完成尚未挑戰的日語 NPC 試煉並強化自身實力。",
		"target_pos": Vector3(0.0, 0.5, 30.0),
		"target_label": "🌸 櫻花之里",
	},
]

const NPCS: Array = [
	{
		"id": "miko_mio",
		"name": "巫女・美桜",
		"title": "櫻花古社巫女",
		"icon": "⛩️",
		"accent": "#f472b6",
		"pos": Vector3(0.0, 0.0, 30.0),
		"facing": 0.0,
		"model_key": "sakura",
		"is_story_npc": true,
		"story_step_trigger": 0,
		"jp_greeting": "こんばんは！桜の里へようこそ。",
		"intro_lines": [
			"「こんばんは！（晚上好！）歡迎來到櫻花之里，遠道而來的言靈勇者！」",
			"「今夜本殿祭壇的『言靈碑』遭到『赤鬼大将・獄炎』竊據，妖怪們已湧向北方的緋紅太鼓橋與竹林參道……」",
			"「在您啟程討伐之前，請讓我先為您獻上神社的祝詞。只要通過兩道基礎日語問答，我便將櫻花古社的攻勢神護賜予您！」",
		],
		"after_lines": [
			"「太棒了！您的言靈清澈有力，連櫻花花瓣都隨之共鳴呢。」",
			"「沿著正北方的石板路跨越『緋紅太鼓橋』，穿過竹林與千本鳥居即可抵達夜櫻本殿祭壇。若受傷了，千本鳥居西側的靈泉可以隨時回復體力喔！」",
		],
		"quiz_title": "⛩️ 神社參拜與日語問候試煉",
		"questions": [
			{
				"prompt": "櫻花古社是一座歷史悠久的「神社」，請問「神社」的正確日文讀音是？",
				"jp_text": "神社",
				"kana_tts": "じんじゃ",
				"options": [
					"じんじゃ (jinja)",
					"おてら (otera)",
					"しろ (shiro)",
					"とりい (torii)",
				],
				"correct_idx": 0,
				"explain": "「神社」讀作「じんじゃ (jinja)」；おてら 是寺廟、しろ 是城堡、とりい 則是鳥居。",
			},
			{
				"prompt": "在月夜降臨櫻花之里、向巫女打招呼「晚上好」時，最適合使用哪一句日文？",
				"jp_text": "こんばんは",
				"kana_tts": "こんばんは",
				"options": [
					"おはよう (早安)",
					"こんばんは (晚上好)",
					"おやすみ (晚安／睡前)",
					"さようなら (再見)",
				],
				"correct_idx": 1,
				"explain": "傍晚與夜間見面問候要用「こんばんは (konbanwa)」，「おはよう」用於早晨問安。",
			},
		],
		"reward": {
			"gold": 120,
			"exp": 80,
			"skill_points": 0,
			"buff_key": "atk_pct",
			"buff_val": 0.08,
			"heal_full": true,
			"sp_full": true,
			"summary": "+120 金幣・+80 EXP・攻擊 +8%・狀態全滿",
		},
	},
	{
		"id": "teahouse_gen",
		"name": "茶屋店主・源さん",
		"title": "和菓子老舖店主",
		"icon": "🍡",
		"accent": "#fb923c",
		"pos": Vector3(-14.5, 0.0, 26.0),
		"facing": 1.1,
		"model_key": "kickboxer",
		"is_story_npc": false,
		"story_step_trigger": -1,
		"jp_greeting": "いらっしゃいませ！温かいお茶と団子はいかがですか？",
		"intro_lines": [
			"「いらっしゃいませ！（歡迎光臨！）喔呀，這位客官氣宇軒昂，看來正準備去驅妖吧？」",
			"「老夫經營這間和菓子茶屋五十年了，剛現刷好的宇治抹茶配三色糰子最補體力啦！」",
			"「答對老夫這兩道茶屋日語小考題，這份秘傳元氣茶點就免費招待你，包準你氣血充盈！」",
		],
		"after_lines": [
			"「哈哈，真是好眼力！喝了這碗秘傳抹茶，氣色整個亮起來了呢。」",
			"「戰鬥累了隨時歡迎再回來茶屋歇歇腳，ごゆっくりどうぞ（請慢慢享用）！」",
		],
		"quiz_title": "🍡 和菓子茶屋・美食日語試煉",
		"questions": [
			{
				"prompt": "源大叔親手現刷的招牌飲品「抹茶」，請問正確的日文讀音是？",
				"jp_text": "抹茶",
				"kana_tts": "まっちゃ",
				"options": [
					"こうちゃ (koucha)",
					"りょくちゃ (ryokucha)",
					"まっちゃ (matcha)",
					"むぎちゃ (mugicha)",
				],
				"correct_idx": 2,
				"explain": "「抹茶」讀作「まっちゃ (matcha)」，其中促音「っ」要短暫停頓一拍！",
			},
			{
				"prompt": "在日本品嚐餐點或和菓子前，雙手合十說的「いただきます」代表什麼意思？",
				"jp_text": "いただきます",
				"kana_tts": "いただきます",
				"options": [
					"謝謝款待（用餐後說）",
					"我要開動了（餐前感謝）",
					"老闆請再來一碗",
					"不好意思打擾了",
				],
				"correct_idx": 1,
				"explain": "「いただきます (itadakimasu)」用於開動前表達對食材與料理者的感謝；餐後則說「ごちそうさまでした」。",
			},
		],
		"reward": {
			"gold": 150,
			"exp": 90,
			"skill_points": 0,
			"buff_key": "hp_pct",
			"buff_val": 0.15,
			"heal_full": true,
			"sp_full": false,
			"summary": "+150 金幣・+90 EXP・最大 HP +15%・回滿 HP",
		},
	},
	{
		"id": "smith_tessai",
		"name": "鍛冶師・鉄斎",
		"title": "名刀鍛造師",
		"icon": "⚒️",
		"accent": "#ef4444",
		"pos": Vector3(15.0, 0.0, 25.0),
		"facing": -1.1,
		"model_key": "swordsman",
		"is_story_npc": false,
		"story_step_trigger": -1,
		"jp_greeting": "おお、良い目をしておるな！刀の魂を語ろうか。",
		"intro_lines": [
			"「鏗鏘——！喔，好銳利的眼神！看你的架勢，是懂得駕馭言靈與刀鋒的豪傑啊！」",
			"「赤鬼大将那廝皮粗肉厚，單靠凡鐵可劈不開牠的妖氣鎧甲，必須以武士之魂為刃開鋒。」",
			"「來接下老夫的武道日語考驗吧！若能全數答對，我便替你的武器開鋒，再傳授你一點實戰武藝心得！」",
		],
		"after_lines": [
			"「好刀配好主！刃口已淬上紅蓮靈火，現在斬下去的手感肯定截然不同！」",
			"「記得在戰鬥中善用三連斬與言靈奧義，『一刀両断（一刀兩斷）』把妖魔全劈個粉碎吧！」",
		],
		"quiz_title": "⚒️ 鍛冶工房・武道名刀試煉",
		"questions": [
			{
				"prompt": "日本鍛冶師以玉鋼千錘百鍊鑄成的「刀」，其正確的日文訓讀是？",
				"jp_text": "刀",
				"kana_tts": "かたな",
				"options": [
					"かたな (katana)",
					"やり (yari)",
					"ゆみ (yumi)",
					"たて (tate)",
				],
				"correct_idx": 0,
				"explain": "日本刀的「刀」讀作「かたな (katana)」；やり 是長槍、ゆみ 是弓、たて 是盾。",
			},
			{
				"prompt": "恪守信念、揮刃守護里民的「武士」，正確的日文音讀讀音是？",
				"jp_text": "武士",
				"kana_tts": "ぶし",
				"options": [
					"にんじゃ (ninja)",
					"ぶし (bushi)",
					"しょうぐん (shougun)",
					"けんし (kenshi)",
				],
				"correct_idx": 1,
				"explain": "「武士」音讀為「ぶし (bushi)」，亦即武士道（ぶしどう）的語源！",
			},
		],
		"reward": {
			"gold": 180,
			"exp": 110,
			"skill_points": 1,
			"buff_key": "atk_pct",
			"buff_val": 0.12,
			"heal_full": false,
			"sp_full": false,
			"summary": "+180 金幣・技能點 +1・攻擊 +12%",
		},
	},
	{
		"id": "scholar_kenta",
		"name": "旅人學者・健太",
		"title": "迷途竹林旅人",
		"icon": "📜",
		"accent": "#38bdf8",
		"pos": Vector3(-34.0, 0.0, -28.0),
		"facing": 1.3,
		"model_key": "yukionna",
		"is_story_npc": false,
		"story_step_trigger": -1,
		"jp_greeting": "助けてくれてありがとう！ここは妖気がすごいですね……",
		"intro_lines": [
			"「呼、呼……太好了，終於遇到活人了！助けて（救命）……剛剛差點被竹林裡的妖狐包圍！」",
			"「我是四處考據古社文獻的旅行學者健太，原本想抄錄竹林裡的古石碑，沒想到天一黑整片竹海就起了怪霧。」",
			"「為了答謝你願意深入竹林關照我，來試試我筆記裡的兩道旅行自然日語吧！答對的話，我把隨身攜帶的疾行靈符送給你！」",
		],
		"after_lines": [
			"「真是學識淵博！這張『疾行靈符』能讓你腳步生風，躲避妖怪彈幕時一定大派用場。」",
			"「據古書記載，再往北穿過千本鳥居就能見到守護此地的『白狐神主』，祝你一路順風、お気をつけて（請多保重）！」",
		],
		"quiz_title": "📜 竹林行腳・自然與旅行日語試煉",
		"questions": [
			{
				"prompt": "健太迷失方向的這片翠綠「竹林」，在日文中的正確讀音是？",
				"jp_text": "竹林",
				"kana_tts": "ちくりん",
				"options": [
					"しんりん (shinrin)",
					"もみじ (momiji)",
					"ちくりん (chikurin)",
					"さくら (sakura)",
				],
				"correct_idx": 2,
				"explain": "「竹林」音讀為「ちくりん (chikurin)」（竹＝ちく、林＝りん）；しんりん 則是森林。",
			},
			{
				"prompt": "在旅途中遭遇危險、急需旁人伸出援手時大喊的「助けて（たすけて）」是什麼意思？",
				"jp_text": "助けて",
				"kana_tts": "たすけて",
				"options": [
					"請稍等一下",
					"請問這條路怎麼走",
					"沒關係、不用在意",
					"救命！請幫幫我！",
				],
				"correct_idx": 3,
				"explain": "「助けて (tasukete)」源自動詞「助ける（救助、幫忙）」，是危急時最實用的求救日語。",
			},
		],
		"reward": {
			"gold": 200,
			"exp": 140,
			"skill_points": 0,
			"buff_key": "spd_pct",
			"buff_val": 0.10,
			"heal_full": true,
			"sp_full": true,
			"summary": "+200 金幣・+140 EXP・移速 +10%・全滿回復",
		},
	},
	{
		"id": "elder_byakko",
		"name": "白狐神主",
		"title": "櫻花古社守護神主",
		"icon": "🦊",
		"accent": "#facc15",
		"pos": Vector3(18.0, 0.0, -72.0),
		"facing": -1.4,
		"model_key": "kitsune",
		"is_story_npc": true,
		"story_step_trigger": 3,
		"jp_greeting": "よくぞ千本鳥居を登り切ったな、言霊の継承者よ。",
		"intro_lines": [
			"「よくぞここまで参った（辛苦你一路走到此處），身懷純粹言靈之力的年輕旅人啊。」",
			"「前方石階盡頭的『夜櫻本殿祭壇』，正是『赤鬼大将・獄炎』盤踞之地。牠奪走言靈碑，意圖以業火吞噬整座櫻花之里。」",
			"「在踏入決戰之前，請向神明證明你對日本神道與言靈文化的領悟。通過吾之神前問答，吾將賜予你最強的神護與技能秘傳！」",
		],
		"after_lines": [
			"「神妙なり（精彩絕倫）！白狐神護已降臨你身，體力與靈力皆已臻至巔峰。」",
			"「去吧，登上北方的夜櫻本殿祭壇，讓『赤鬼大将・獄炎』見識真正的『言霊（ことだま）』之威！武運を祈る（祝你武運昌隆）！」",
		],
		"quiz_title": "🦊 千本鳥居・言靈與日本神道試煉",
		"questions": [
			{
				"prompt": "日本自古相信蘊含於話語之中、能化為奇蹟力量的「言霊」，其正確讀音是？",
				"jp_text": "言霊",
				"kana_tts": "ことだま",
				"options": [
					"ことば (kotoba)",
					"ことだま (kotodama)",
					"たましい (tamashii)",
					"しんれい (shinrei)",
				],
				"correct_idx": 1,
				"explain": "「言霊」讀作「ことだま (kotodama)」，由「こと（言）」與「たま（靈）」連濁結合而成。",
			},
			{
				"prompt": "矗立於神社參道、綿延成群的朱紅「鳥居（とりい）」在日本文化中象徵什麼？",
				"jp_text": "鳥居",
				"kana_tts": "とりい",
				"options": [
					"人界與神聖領域的分界門",
					"專門收納祈願木牌的倉庫",
					"讓旅人歇腳喝抹茶的茶亭",
					"鍛冶師用來鑄造太刀的熔爐",
				],
				"correct_idx": 0,
				"explain": "「鳥居 (torii)」是區隔凡俗世界與神明聖域的結界之門，參拜時通常會先在鳥居前行禮。",
			},
		],
		"reward": {
			"gold": 250,
			"exp": 160,
			"skill_points": 1,
			"buff_key": "atk_pct",
			"buff_val": 0.15,
			"heal_full": true,
			"sp_full": true,
			"summary": "+250 金幣・技能點 +1・攻擊 +15%・神護全滿",
		},
	},
]

const ENCOUNTERS: Array = [
	{
		"id": "bridge_ambush",
		"title": "🌉 太鼓橋妖鬼伏擊",
		"desc": "提燈小鬼與傘妖封鎖了緋紅太鼓橋！擊倒牠們開闢前往竹海荒野的道路。",
		"req_step": 0,
		"next_step": 2,
		"is_boss": false,
		"trigger_pos": Vector3(0.0, 0.0, 2.0),
		"trigger_radius": 15.0,
		"spawn_center": Vector3(0.0, 0.0, -2.0),
		"spawn_radius": 7.0,
		"wave_scale": 1,
		"monsters": [
			{"id": "chochin", "count": 3, "is_boss": false},
			{"id": "kasa", "count": 1, "is_boss": false},
		],
		"reward_gold": 120,
		"reward_exp": 90,
	},
	{
		"id": "bamboo_ambush",
		"title": "🎋 幽暗竹海・荒野伏兵",
		"desc": "青鬼武者率領九尾妖狐與絡新婦自竹影溪谷現身！淨化整片竹海荒野！",
		"req_step": 2,
		"next_step": 3,
		"is_boss": false,
		"trigger_pos": Vector3(2.0, 0.0, -34.0),
		"trigger_radius": 17.0,
		"spawn_center": Vector3(2.0, 0.0, -36.0),
		"spawn_radius": 9.0,
		"wave_scale": 3,
		"monsters": [
			{"id": "aooni", "count": 2, "is_boss": false},
			{"id": "kyubi", "count": 2, "is_boss": false},
			{"id": "jorogumo", "count": 1, "is_boss": false},
		],
		"reward_gold": 200,
		"reward_exp": 150,
	},
	{
		"id": "altar_boss",
		"title": "👹 第一章首領・赤鬼大将 獄炎",
		"desc": "竊據言靈碑的赤鬼大将・獄炎現身於滿月夜櫻大祭壇！全神貫注迎戰！",
		"req_step": 3,
		"next_step": 5,
		"is_boss": true,
		"trigger_pos": Vector3(0.0, 4.6, -108.0),
		"trigger_radius": 18.0,
		"spawn_center": Vector3(0.0, 4.6, -114.0),
		"spawn_radius": 8.5,
		"wave_scale": 4,
		"monsters": [
			{"id": "akaoni_boss", "count": 1, "is_boss": true},
			{"id": "chochin", "count": 2, "is_boss": false},
		],
		"reward_gold": 500,
		"reward_exp": 320,
	},
]

const OPENING_CUTSCENE: Dictionary = {
	"title": "第一章：櫻花之里・失落的言靈碑",
	"speaker": "巫女・美桜",
	"icon": "🌸",
	"jp_tts": "ようこそ、桜の里へ。失われた言霊碑を取り戻しましょう。",
	"lines": [
		"「從『蒼海峽灣・海濱沙灘』仰望身旁巍峨的『櫻岳高山』，穿越北方海風吹拂的花海曠野，便是言靈清澄的和平古村『櫻花之里』——然而今夜，赤紅妖霧卻吞沒了這片淨土……」",
		"「盤踞於北方滿月夜櫻大祭壇的『赤鬼大将・獄炎』奪走了鎮社之寶『言靈碑』，並放出成群妖怪封鎖了太鼓橋與竹海荒野。」",
		"「請從海濱沙灘沿著曠野參道北上『櫻花之里』與我（巫女・美桜）會合，也可以拜訪茶屋店主與鍛冶師，透過日語言靈試煉獲得祝福與強化！」",
	],
}

const EPILOGUE_CUTSCENE: Dictionary = {
	"title": "第一章通關・言靈碑重輝",
	"speaker": "白狐神主",
	"icon": "🦊",
	"jp_tts": "お見事です！桜の里に再び平和と光が戻りました。",
	"lines": [
		"「お見事です！（真是太精彩了！）隨著赤鬼大将・獄炎化作清風散去，滿月夜櫻大祭壇上的『言靈碑』再次綻放出燦爛金光！」",
		"「散落的櫻瓣重新舞動於晴朗月空，櫻花之里的結界已然修復，村人們又能安穩度日了。」",
		"「第一章冒險圓滿落幕！你仍可留在蒼海峽灣與櫻花之里自由探索、完成尚未挑戰的日語 NPC 試煉，為接下來的百鬼夜行新篇章做好萬全準備！」",
	],
}


static func get_zone_name(pos: Vector3) -> String:
	if pos.x <= -36.0 and pos.z >= 15.0:
		return "⛰️ 櫻岳高山・峽灣山徑"
	if pos.z >= 88.0:
		return "🌊 蒼海峽灣・海濱沙灘"
	if pos.x >= 26.0 and pos.z >= -4.0 and pos.z <= 44.0:
		return "🌊 月見湖・白砂浜"
	if pos.z >= 44.0:
		return "🌸 峽灣曠野・海風花海"
	if pos.z >= 14.0 and absf(pos.x) <= 28.0:
		return "🌸 櫻花之里"
	if pos.z >= 2.0:
		return "🌉 緋紅太鼓橋"
	if pos.z >= -56.0:
		return "🎋 幽暗竹海・荒野溪谷"
	if pos.z >= -96.0:
		return "🏮 千本鳥居山道"
	return "⛩️ 滿月夜櫻大祭壇"


static func get_npc(npc_id: String) -> Dictionary:
	for raw_npc in NPCS:
		var npc: Dictionary = raw_npc
		if String(npc.get("id", "")) == npc_id:
			return npc
	return {}


static func get_quest_step(step_idx: int) -> Dictionary:
	var clamped_idx: int = clampi(step_idx, 0, QUEST_STEPS.size() - 1)
	var step_dict: Dictionary = QUEST_STEPS[clamped_idx]
	return step_dict


static func get_encounter(enc_id: String) -> Dictionary:
	for raw_enc in ENCOUNTERS:
		var enc: Dictionary = raw_enc
		if String(enc.get("id", "")) == enc_id:
			return enc
	return {}
