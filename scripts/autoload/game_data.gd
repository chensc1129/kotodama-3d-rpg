extends Node
## Static game definitions: characters, stages, equipment, shikigami,
## monsters, bosses, Japanese chant words, game modes, and blessings.

const ARENA_RADIUS: float = 28.0
const MAX_LEVEL: int = 100
const MAX_SKILL_LEVEL: int = 10
const MAX_EQUIP_ENHANCE: int = 10

const CHARACTER_ORDER: Array[String] = [
	"sakura",
	"kickboxer",
	"swordsman",
	"raijin",
	"yukionna",
]

const CHARACTERS: Dictionary = {
	"sakura": {
		"id": "sakura",
		"name": "櫻花妹",
		"title": "言霊巫女",
		"icon": "👘",
		"sig_key": "石頭",
		"sig_name": "石化魔眼",
		"sig_icon": "🪨",
		"chant_word_id": "stone",
		"hotkey_hint": "E",
		"desc": "施放「石頭」將全場妖怪石化封印 5 秒，用「あ」攻擊石像觸發 1.5 倍碎石暴擊！",
		"color_primary": "#f43f5e",
		"color_secondary": "#fce7f3",
		"color_hair": "#3b1d2a",
		"base_hp": 130,
		"base_atk": 24,
		"base_spd": 9.2,
	},
	"kickboxer": {
		"id": "kickboxer",
		"name": "腳鬥士",
		"title": "烈風腿王",
		"icon": "🥋",
		"sig_key": "腳",
		"sig_name": "超烈風神腳",
		"sig_icon": "🦶",
		"chant_word_id": "foot",
		"hotkey_hint": "E",
		"desc": "施放「腳」發動騰空飛踢衝擊波，大幅擊飛妖怪並附帶 2.6 秒暈眩重創！",
		"color_primary": "#2563eb",
		"color_secondary": "#f8fafc",
		"color_hair": "#1e293b",
		"base_hp": 145,
		"base_atk": 26,
		"base_spd": 9.8,
	},
	"swordsman": {
		"id": "swordsman",
		"name": "言霊剣士",
		"title": "紅蓮武士",
		"icon": "🥷",
		"sig_key": "火炎斬",
		"sig_name": "紅蓮烈焰斬",
		"sig_icon": "🔥",
		"chant_word_id": "flame",
		"hotkey_hint": "E",
		"desc": "均衡型劍豪，施放「火炎斬」釋放巨型烈焰劍氣旋風並持續灼燒周圍敵人！",
		"color_primary": "#dc2626",
		"color_secondary": "#1e293b",
		"color_hair": "#0f172a",
		"base_hp": 140,
		"base_atk": 25,
		"base_spd": 9.4,
	},
	"raijin": {
		"id": "raijin",
		"name": "雷神忍者",
		"title": "疾風雷影 (NEW)",
		"icon": "⚡",
		"sig_key": "雷光",
		"sig_name": "九天雷鳴陣",
		"sig_icon": "⚡",
		"chant_word_id": "thunder",
		"hotkey_hint": "E",
		"desc": "【新角色】超高速刺客！施放「雷光」召喚落雷連環劈擊並附加感電易傷！",
		"color_primary": "#eab308",
		"color_secondary": "#1e1b4b",
		"color_hair": "#fef08a",
		"base_hp": 120,
		"base_atk": 29,
		"base_spd": 10.8,
	},
	"yukionna": {
		"id": "yukionna",
		"name": "冰霜雪女",
		"title": "極寒姫 (NEW)",
		"icon": "❄️",
		"sig_key": "冰結",
		"sig_name": "絶対零度氷華",
		"sig_icon": "❄️",
		"chant_word_id": "ice",
		"hotkey_hint": "E",
		"desc": "【新角色】控場法師！施放「冰結」召喚 3D 冰蓮陣凍結全場妖怪並持續造成寒霜傷害！",
		"color_primary": "#06b6d4",
		"color_secondary": "#e0f2fe",
		"color_hair": "#bae6fd",
		"base_hp": 125,
		"base_atk": 27,
		"base_spd": 9.0,
	},
}

const STAGES: Array = [
	{
		"id": "sakura_shrine",
		"name": "夜櫻神社道場",
		"icon": "🌸",
		"desc": "三層石階神壇・櫻花靈陣回復體力與增傷 +25%",
		"mechanic_name": "🌸 靈櫻祝福陣",
		"sky_color": "#131629",
		"fog_color": "#131629",
		"floor_color": "#2d2438",
		"ring_color": "#e11d48",
		"ambient_color": "#ffd1dc",
		"particle_color": "#f9a8d4",
	},
	{
		"id": "maple_temple",
		"name": "紅葉古寺竹林",
		"icon": "🍁",
		"desc": "起伏楓林丘陵・疾風氣流賦予高速與無限急跑",
		"mechanic_name": "🍃 楓嵐疾風氣流",
		"sky_color": "#291815",
		"fog_color": "#291815",
		"floor_color": "#3b2820",
		"ring_color": "#f97316",
		"ambient_color": "#fed7aa",
		"particle_color": "#fb923c",
	},
	{
		"id": "onigashima_lava",
		"name": "鬼ヶ島熔岩城",
		"icon": "🌋",
		"desc": "黑曜高台與熔岩裂谷・引誘妖怪承受間歇地火噴發",
		"mechanic_name": "🌋 火山熔岩噴發",
		"sky_color": "#1f0c0c",
		"fog_color": "#1f0c0c",
		"floor_color": "#1c1917",
		"ring_color": "#dc2626",
		"ambient_color": "#fca5a5",
		"particle_color": "#fef08a",
	},
	{
		"id": "sky_tenshu",
		"name": "満月雲海天守閣",
		"icon": "⛩️",
		"desc": "懸浮雲海高台・騰雲彈跳陣躍升高地與滿月天雷",
		"mechanic_name": "⚡ 騰雲躍昇・滿月天雷",
		"sky_color": "#0c192c",
		"fog_color": "#0c192c",
		"floor_color": "#1e293b",
		"ring_color": "#facc15",
		"ambient_color": "#bae6fd",
		"particle_color": "#fde047",
	},
]

const GAME_MODES: Array = [
	{
		"id": "normal",
		"label": "⚔️ 標準闖關",
		"desc": "12 幕故事進階・適合練功",
		"color": "#fcd34d",
	},
	{
		"id": "hard",
		"label": "🔥 困難模式",
		"desc": "妖火彈幕＋強敵・1.5倍獎勵",
		"color": "#fb7185",
	},
	{
		"id": "endless",
		"label": "♾️ 無盡模式",
		"desc": "無限波次生存・場景輪換",
		"color": "#38bdf8",
	},
	{
		"id": "hard_endless",
		"label": "💀 困難無盡",
		"desc": "極限修羅場・2.0倍獎勵",
		"color": "#c084fc",
	},
]

const EQUIPMENT_LIST: Array = [
	{"id": "w1", "slot": "weapon", "name": "木霊の練習刀", "icon": "🗡️", "atk": 6, "hp": 0, "cost": 0, "blade_color": "#d6d3d1"},
	{"id": "w2", "slot": "weapon", "name": "桜吹雪・太刀", "icon": "🌸", "atk": 16, "hp": 15, "cost": 180, "blade_color": "#f472b6"},
	{"id": "w3", "slot": "weapon", "name": "雷切・黄金丸", "icon": "⚡", "atk": 30, "hp": 25, "cost": 420, "blade_color": "#facc15"},
	{"id": "w4", "slot": "weapon", "name": "氷輪・蒼穹刃", "icon": "❄️", "atk": 48, "hp": 40, "cost": 850, "blade_color": "#38bdf8"},
	{"id": "w5", "slot": "weapon", "name": "天叢雲・神滅剣", "icon": "👑", "atk": 75, "hp": 80, "cost": 1600, "blade_color": "#f97316"},

	{"id": "a1", "slot": "armor", "name": "道場稽古着", "icon": "🥋", "atk": 0, "hp": 20, "cost": 0, "aura_color": "#94a3b8"},
	{"id": "a2", "slot": "armor", "name": "緋袴・巫女装束", "icon": "👘", "atk": 5, "hp": 65, "cost": 200, "aura_color": "#f43f5e"},
	{"id": "a3", "slot": "armor", "name": "黒鉄・武者鎧", "icon": "🛡️", "atk": 12, "hp": 130, "cost": 480, "aura_color": "#3b82f6"},
	{"id": "a4", "slot": "armor", "name": "龍鱗・神楽羽織", "icon": "🐉", "atk": 24, "hp": 240, "cost": 980, "aura_color": "#10b981"},

	{"id": "r1", "slot": "accessory", "name": "お守り・木札", "icon": "🧿", "atk": 3, "hp": 15, "cost": 0, "gem_color": "#a8a29e"},
	{"id": "r2", "slot": "accessory", "name": "八尺瓊・翡翠勾玉", "icon": "📿", "atk": 14, "hp": 50, "cost": 260, "gem_color": "#34d399"},
	{"id": "r3", "slot": "accessory", "name": "狐火・霊珠", "icon": "🔮", "atk": 28, "hp": 90, "cost": 600, "gem_color": "#c084fc"},
	{"id": "r4", "slot": "accessory", "name": "太陽神・八咫鏡", "icon": "☀️", "atk": 45, "hp": 160, "cost": 1350, "gem_color": "#fbbf24"},
]

const SHIKIGAMI_LIST: Array = [
	{"id": "none", "name": "無式神跟隨", "icon": "➖", "desc": "獨自修行", "cost": 0, "color": "#ffffff"},
	{"id": "kitsune", "name": "小狐火・コン太", "icon": "🦊", "desc": "每 2.5 秒自動發射狐火彈攻擊最近妖怪", "cost": 220, "color": "#f97316"},
	{"id": "neko", "name": "招財福貓・タマ", "icon": "🐱", "desc": "每 4 秒為主人回復 5% HP 並提升金幣掉落 +20%", "cost": 380, "color": "#facc15"},
	{"id": "raiju", "name": "迷你雷獸・ライ", "icon": "🐺", "desc": "每 2.2 秒釋放閃電鏈劈擊妖怪並回復 4 SP", "cost": 650, "color": "#38bdf8"},
]

const MONSTER_TEMPLATES: Array = [
	{"id": "chochin", "name": "提灯小鬼", "color": "#f97316", "hp_mult": 1.0, "spd": 3.8, "atk": 10, "scale": 1.0, "ranged": false},
	{"id": "kasa", "name": "傘妖・跳躍者", "color": "#a855f7", "hp_mult": 1.15, "spd": 4.6, "atk": 12, "scale": 1.05, "ranged": false},
	{"id": "aooni", "name": "青鬼武者", "color": "#2563eb", "hp_mult": 1.6, "spd": 3.4, "atk": 16, "scale": 1.25, "ranged": false},
	{"id": "kyubi", "name": "九尾妖狐", "color": "#facc15", "hp_mult": 1.35, "spd": 4.1, "atk": 15, "scale": 1.15, "ranged": true},
	{"id": "jorogumo", "name": "絡新婦・毒蛛", "color": "#10b981", "hp_mult": 1.45, "spd": 4.8, "atk": 14, "scale": 1.15, "ranged": true},
	{"id": "dogu", "name": "古代土偶石魔", "color": "#78716c", "hp_mult": 2.1, "spd": 2.7, "atk": 20, "scale": 1.35, "ranged": false},
]

const BOSS_TEMPLATES: Array = [
	{"id": "akaoni_boss", "name": "赤鬼大将・獄炎", "color": "#dc2626", "hp_mult": 6.5, "spd": 3.6, "atk": 26, "scale": 2.1, "ranged": true},
	{"id": "tengu_boss", "name": "大天狗・覇王", "color": "#4f46e5", "hp_mult": 7.5, "spd": 4.5, "atk": 30, "scale": 2.2, "ranged": true},
	{"id": "orochi_boss", "name": "八岐大蛇・幻影", "color": "#059669", "hp_mult": 9.0, "spd": 3.9, "atk": 34, "scale": 2.4, "ranged": true},
]

const JAPANESE_CHANT_WORDS: Array = [
	{"id": "stone", "kanji": "石頭", "kana": "いし", "mean": "石頭 / 岩石", "distractors": ["やま", "かわ", "き"]},
	{"id": "foot", "kanji": "脚・足", "kana": "あし", "mean": "腳 / 腿部", "distractors": ["て", "め", "くち"]},
	{"id": "thunder", "kanji": "雷光", "kana": "らいこう", "mean": "雷光 / 閃電", "distractors": ["たいよう", "げっこう", "かぜ"]},
	{"id": "ice", "kanji": "氷結", "kana": "ひょうけつ", "mean": "冰結 / 凍結", "distractors": ["ねったい", "かんそう", "ふっとう"]},
	{"id": "flame", "kanji": "火炎", "kana": "かえん", "mean": "火焰 / 烈焰", "distractors": ["すいりゅう", "どしゃ", "しんりん"]},
	{"id": "sakura", "kanji": "桜花", "kana": "おうか", "mean": "櫻花", "distractors": ["うめ", "もも", "きく"]},
	{"id": "finisher", "kanji": "必殺", "kana": "ひっさつ", "mean": "必殺", "distractors": ["ぼうぎょ", "かいふく", "とうそう"]},
	{"id": "victory", "kanji": "勝利", "kana": "しょうり", "mean": "勝利", "distractors": ["はいぼく", "どりょく", "しゅぎょう"]},
	{"id": "sword", "kanji": "剣術", "kana": "けんじゅつ", "mean": "劍術", "distractors": ["まほう", "たいじゅつ", "きゅうどう"]},
	{"id": "courage", "kanji": "勇気", "kana": "ゆうき", "mean": "勇氣", "distractors": ["げんき", "てんき", "びょうき"]},
	{"id": "invincible", "kanji": "無敵", "kana": "むてき", "mean": "無敵", "distractors": ["じゃくてん", "きけん", "あんぜん"]},
	{"id": "training", "kanji": "修行", "kana": "しゅぎょう", "mean": "修行 / 鍛鍊", "distractors": ["りょこう", "べんきょう", "うんどう"]},
]

const BLESSINGS_POOL: Array = [
	{"id": "atk", "title": "⚔️ 鬼神剛力", "desc": "全攻擊力永久 +18%"},
	{"id": "hp", "title": "❤️ 不動明王體", "desc": "最大 HP +20% 並立即回復 40% HP"},
	{"id": "stone", "title": "🪨 碎石破甲奧義", "desc": "對石化/控場怪物傷害額外 +35%"},
	{"id": "lifesteal", "title": "🩸 妖刀吸血", "desc": "每次「あ」命中回復 12% 攻擊力 HP"},
	{"id": "speed", "title": "⚡ 神速疾風步", "desc": "移動速度 +12% 並立即補滿 100 SP"},
]

const RANDOM_NAMES: Array[String] = [
	"桜吹雪の剣豪",
	"月影の巫女",
	"烈風脚王",
	"雷鳴忍者",
	"白銀の雪姫",
	"言霊の勇者",
	"紅蓮武士",
]


func get_character(char_id: String) -> Dictionary:
	return CHARACTERS.get(char_id, CHARACTERS["sakura"])


func get_stage(stage_id: String) -> Dictionary:
	for st in STAGES:
		if st["id"] == stage_id:
			return st
	return STAGES[0]


func get_equipment(equip_id: String) -> Dictionary:
	for eq in EQUIPMENT_LIST:
		if eq["id"] == equip_id:
			return eq
	return {}


func get_shikigami(sh_id: String) -> Dictionary:
	for sh in SHIKIGAMI_LIST:
		if sh["id"] == sh_id:
			return sh
	return SHIKIGAMI_LIST[0]


func get_mode(mode_id: String) -> Dictionary:
	for m in GAME_MODES:
		if m["id"] == mode_id:
			return m
	return GAME_MODES[0]


func get_chant_word_by_id(word_id: String) -> Dictionary:
	for w in JAPANESE_CHANT_WORDS:
		if w["id"] == word_id:
			return w
	return JAPANESE_CHANT_WORDS[randi() % JAPANESE_CHANT_WORDS.size()]


func get_random_chant_word() -> Dictionary:
	return JAPANESE_CHANT_WORDS[randi() % JAPANESE_CHANT_WORDS.size()]
