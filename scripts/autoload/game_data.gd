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
		"combat_style": "🌸 輕盈櫻舞連斬｜花瓣刀風・第3擊額外回 SP",
		"desc": "【櫻舞連斬】輕盈流暢的花瓣斬擊，第 3 擊綻放櫻花旋風並額外回復 SP；「石頭」石化全場後可觸發 1.5 倍碎石暴擊！",
		"color_primary": "#f43f5e",
		"color_secondary": "#fce7f3",
		"color_hair": "#3b1d2a",
		"base_hp": 130,
		"base_atk": 24,
		"base_spd": 9.2,
		"attack_profile": {
			"cd": 0.21, "reach": [4.5, 4.8, 5.9], "lunge": [0.40, 0.45, 0.88],
			"step_mult": [1.0, 1.18, 1.55], "kb_mult": 1.0, "hitstop_mult": 0.95, "trauma_mult": 0.95,
			"sfx_prefix": "atk_sakura", "crit_tag": "🌸櫻舞暴擊!", "base_tag": "🌸櫻斬",
		},
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
		"combat_style": "🦶 剛猛音爆重腿｜超強擊退與重噸位卡肉・第3擊震暈",
		"desc": "【剛猛烈腿】拳拳到肉的高頓幀重擊與音爆衝擊波，第 3 擊騰空旋風踢轟飛並震暈妖怪；「腳」可大範圍擊飛控場！",
		"color_primary": "#2563eb",
		"color_secondary": "#f8fafc",
		"color_hair": "#1e293b",
		"base_hp": 145,
		"base_atk": 26,
		"base_spd": 9.8,
		"attack_profile": {
			"cd": 0.25, "reach": [4.2, 4.6, 5.8], "lunge": [0.58, 0.65, 1.15],
			"step_mult": [1.08, 1.28, 1.72], "kb_mult": 1.58, "hitstop_mult": 1.42, "trauma_mult": 1.38,
			"sfx_prefix": "atk_kick", "crit_tag": "🦶裂風重踢!", "base_tag": "🦶烈腿",
		},
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
		"combat_style": "🔥 沉穩居合太刀｜巨幅烈焰劍氣・第3擊十字業火灼燒",
		"desc": "【居合炎斬】大開大闔的紅蓮太刀斬擊與銳利刀鋒卡肉感，第 3 擊釋放十字業火斬並附加灼燒；「火炎斬」橫掃全場！",
		"color_primary": "#dc2626",
		"color_secondary": "#1e293b",
		"color_hair": "#0f172a",
		"base_hp": 140,
		"base_atk": 25,
		"base_spd": 9.4,
		"attack_profile": {
			"cd": 0.24, "reach": [4.9, 5.2, 6.4], "lunge": [0.46, 0.52, 0.96],
			"step_mult": [1.05, 1.25, 1.76], "kb_mult": 1.18, "hitstop_mult": 1.25, "trauma_mult": 1.20,
			"sfx_prefix": "atk_sword", "crit_tag": "🔥紅蓮十字!", "base_tag": "🔥炎斬",
		},
	},
	"raijin": {
		"id": "raijin",
		"name": "雷神忍者",
		"title": "疾風雷影",
		"icon": "⚡",
		"sig_key": "雷光",
		"sig_name": "九天雷鳴陣",
		"sig_icon": "⚡",
		"chant_word_id": "thunder",
		"hotkey_hint": "E",
		"combat_style": "⚡ 極速瞬閃連砍｜0.14s 超高攻速電弧・第3擊落雷感電",
		"desc": "【迅雷連閃】超高速刺客！極短出招冷卻配瞬步突進與鋸齒電弧斬，第 3 擊劈下落雷附加感電易傷，連擊手感極致爽快！",
		"color_primary": "#eab308",
		"color_secondary": "#1e1b4b",
		"color_hair": "#fef08a",
		"base_hp": 120,
		"base_atk": 29,
		"base_spd": 10.8,
		"attack_profile": {
			"cd": 0.145, "reach": [4.3, 4.5, 5.5], "lunge": [0.65, 0.72, 1.22],
			"step_mult": [0.82, 0.98, 1.38], "kb_mult": 0.68, "hitstop_mult": 0.62, "trauma_mult": 0.85,
			"sfx_prefix": "atk_raijin", "crit_tag": "⚡迅雷一閃!", "base_tag": "⚡電斬",
		},
	},
	"yukionna": {
		"id": "yukionna",
		"name": "冰霜雪女",
		"title": "極寒姫",
		"icon": "❄️",
		"sig_key": "冰結",
		"sig_name": "絶対零度氷華",
		"sig_icon": "❄️",
		"chant_word_id": "ice",
		"hotkey_hint": "E",
		"combat_style": "❄️ 遠距冰晶法術｜9m 超長射程冰錐・第3擊綻放冰蓮凍結",
		"desc": "【寒霜法術】優雅的中遠距法師！揮袖激射三連發光冰晶錐貫穿敵陣，第 3 擊綻放 3D 冰蓮法陣短暫冰封目標！",
		"color_primary": "#06b6d4",
		"color_secondary": "#e0f2fe",
		"color_hair": "#bae6fd",
		"base_hp": 125,
		"base_atk": 27,
		"base_spd": 9.0,
		"attack_profile": {
			"cd": 0.255, "reach": [7.4, 7.8, 9.2], "lunge": [0.14, 0.16, 0.22],
			"step_mult": [0.96, 1.14, 1.56], "kb_mult": 0.85, "hitstop_mult": 0.82, "trauma_mult": 0.88,
			"sfx_prefix": "atk_yuki", "crit_tag": "❄️氷華綻放!", "base_tag": "❄️冰錐",
		},
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
	# === 角色專屬核心言靈 (5) ===
	{"id": "stone", "kanji": "石頭", "kana": "いし", "mean": "石頭 / 岩石", "distractors": ["やま", "かわ", "き"], "icon": "🪨", "color": "#a8a29e", "vfx": "earth_shatter", "vfx_label": "裂地岩柱", "effect_desc": "破土岩柱震擊・石化封印周圍妖怪"},
	{"id": "foot", "kanji": "脚・足", "kana": "あし", "mean": "腳 / 腿部", "distractors": ["て", "め", "くち"], "icon": "🦶", "color": "#38bdf8", "vfx": "dragon_vortex", "vfx_label": "烈風龍捲", "effect_desc": "疾風龍捲擊飛・暈眩並賦予 5 秒加速"},
	{"id": "thunder", "kanji": "雷光", "kana": "らいこう", "mean": "雷光 / 閃電", "distractors": ["たいよう", "げっこう", "かぜ"], "icon": "⚡", "color": "#facc15", "vfx": "lightning", "vfx_label": "九天天雷", "effect_desc": "六道天雷齊降・感電易傷＋暴擊增傷"},
	{"id": "ice", "kanji": "氷結", "kana": "ひょうけつ", "mean": "冰結 / 凍結", "distractors": ["ねったい", "かんそう", "ふっとう"], "icon": "❄️", "color": "#22d3ee", "vfx": "blizzard", "vfx_label": "極寒冰柱", "effect_desc": "十座冰晶柱破地・凍結全場並持續凍傷"},
	{"id": "flame", "kanji": "火炎", "kana": "かえん", "mean": "火焰 / 烈焰", "distractors": ["すいりゅう", "どしゃ", "しんりん"], "icon": "🔥", "color": "#f97316", "vfx": "meteor", "vfx_label": "業火流星", "effect_desc": "赤紅流星墜落轟炸・附加高溫灼燒"},

	# === 原有經典言靈升級特效 (7) ===
	{"id": "sakura", "kanji": "桜花", "kana": "おうか", "mean": "櫻花", "distractors": ["うめ", "もも", "きく"], "icon": "🌸", "color": "#f472b6", "vfx": "sakura_storm", "vfx_label": "千本櫻嵐", "effect_desc": "螺旋櫻吹雪斬擊・回復 22% HP 與體力"},
	{"id": "finisher", "kanji": "必殺", "kana": "ひっさつ", "mean": "必殺", "distractors": ["ぼうぎょ", "かいふく", "とうそう"], "icon": "💥", "color": "#fb7185", "vfx": "lightning", "vfx_label": "紅蓮天罰", "effect_desc": "赤金天雷直劈・感電易傷＋暴擊增傷"},
	{"id": "victory", "kanji": "勝利", "kana": "しょうり", "mean": "勝利", "distractors": ["はいぼく", "どりょく", "しゅぎょう"], "icon": "🏆", "color": "#fbbf24", "vfx": "sacred_halo", "vfx_label": "榮耀聖光", "effect_desc": "黃金天柱降臨・大回血並返還 25 SP"},
	{"id": "sword", "kanji": "剣術", "kana": "けんじゅつ", "mean": "劍術", "distractors": ["まほう", "たいじゅつ", "きゅうどう"], "icon": "⚔️", "color": "#e2e8f0", "vfx": "sword_rain", "vfx_label": "萬劍歸宗", "effect_desc": "十道光劍凌空墜斬・額外 +25% 穿透傷害"},
	{"id": "courage", "kanji": "勇気", "kana": "ゆうき", "mean": "勇氣", "distractors": ["げんき", "てんき", "びょうき"], "icon": "🛡️", "color": "#f59e0b", "vfx": "sacred_halo", "vfx_label": "勇者聖環", "effect_desc": "神聖光環守護・回復 30% HP 與滿體力"},
	{"id": "invincible", "kanji": "無敵", "kana": "むてき", "mean": "無敵", "distractors": ["じゃくてん", "きけん", "あんぜん"], "icon": "👑", "color": "#fde047", "vfx": "sacred_halo", "vfx_label": "霸王金輪", "effect_desc": "雙重黃金光輪爆發・回血並返還 25 SP"},
	{"id": "training", "kanji": "修行", "kana": "しゅぎょう", "mean": "修行 / 鍛鍊", "distractors": ["りょこう", "べんきょう", "うんどう"], "icon": "📿", "color": "#34d399", "vfx": "sacred_halo", "vfx_label": "靈氣覺醒", "effect_desc": "禪意靈光灌頂・回復 HP 與 25 SP"},

	# === 新增自然天象＆元素詞彙 (9) ===
	{"id": "meteor", "kanji": "流星", "kana": "りゅうせい", "mean": "流星 / 隕星", "distractors": ["まんげつ", "たいよう", "すいせい"], "icon": "☄️", "color": "#fb923c", "vfx": "meteor", "vfx_label": "星隕天降", "effect_desc": "群星火隕從天而降・全場轟炸並燃燒"},
	{"id": "starlight", "kanji": "星光", "kana": "せいこう", "mean": "星光 / 星辰", "distractors": ["にっこう", "げっこう", "でんこう"], "icon": "🌟", "color": "#fcd34d", "vfx": "meteor", "vfx_label": "星辰墜擊", "effect_desc": "璀璨星光雨轟炸・範圍爆破與灼燒"},
	{"id": "hellfire", "kanji": "紅蓮", "kana": "ぐれん", "mean": "紅蓮 / 烈火", "distractors": ["はくれん", "せいれん", "すいれん"], "icon": "🔥", "color": "#ef4444", "vfx": "meteor", "vfx_label": "紅蓮火隕", "effect_desc": "深紅業火流星雨・灼燒全場妖怪 5 秒"},
	{"id": "lightning_strike", "kanji": "迅雷", "kana": "じんらい", "mean": "迅雷 / 疾電", "distractors": ["しっぷう", "ごうう", "らいめい"], "icon": "⚡", "color": "#38bdf8", "vfx": "lightning", "vfx_label": "蒼穹迅雷", "effect_desc": "蒼藍雷柱瞬降・感電 5.5 秒＋傷害 +15%"},
	{"id": "snowstorm", "kanji": "吹雪", "kana": "ふぶき", "mean": "暴風雪", "distractors": ["こさめ", "あられ", "きりさめ"], "icon": "❄️", "color": "#67e8f9", "vfx": "blizzard", "vfx_label": "極地吹雪", "effect_desc": "暴雪冰晶陣爆發・凍結全場妖怪 4 秒"},
	{"id": "moonlight", "kanji": "月光", "kana": "げっこう", "mean": "月光 / 滿月清輝", "distractors": ["にっこう", "ほしぞら", "あさひ"], "icon": "🌙", "color": "#a5b4fc", "vfx": "blizzard", "vfx_label": "銀月冰輝", "effect_desc": "銀藍月華晶柱升騰・凍結並淨化敵群"},
	{"id": "gale", "kanji": "疾風", "kana": "しっぷう", "mean": "疾風 / 狂風", "distractors": ["そよかぜ", "たいふう", "じんらい"], "icon": "🌪️", "color": "#2dd4bf", "vfx": "dragon_vortex", "vfx_label": "翡翠嵐捲", "effect_desc": "巨型翠風龍捲擊飛・暈眩並加速 5 秒"},
	{"id": "tsunami", "kanji": "怒涛", "kana": "どとう", "mean": "怒濤 / 驚濤駭浪", "distractors": ["さざなみ", "しずく", "いずみ"], "icon": "🌊", "color": "#0ea5e9", "vfx": "dragon_vortex", "vfx_label": "碧海怒濤", "effect_desc": "奔騰水渦席捲戰場・擊退暈眩＋疾行"},
	{"id": "earthquake", "kanji": "地震", "kana": "じしん", "mean": "地震 / 大地動", "distractors": ["かざん", "つなみ", "たつまき"], "icon": "🌋", "color": "#d97706", "vfx": "earth_shatter", "vfx_label": "崩山裂地", "effect_desc": "熔岩地刺環狀爆起・強震石化 4 秒"},

	# === 新增武道、神獸＆奇蹟詞彙 (9) ===
	{"id": "dragon", "kanji": "蒼龍", "kana": "そうりゅう", "mean": "蒼龍 / 神龍", "distractors": ["びゃっこ", "すざく", "げんぶ"], "icon": "🐉", "color": "#10b981", "vfx": "dragon_vortex", "vfx_label": "蒼龍昇天", "effect_desc": "蒼翠龍捲貫穿天際・擊退暈眩＋疾風"},
	{"id": "phoenix", "kanji": "不死鳥", "kana": "ふしちょう", "mean": "不死鳥 / 鳳凰", "distractors": ["くじゃく", "はくちょう", "らいちょう"], "icon": "🔥", "color": "#f43f5e", "vfx": "earth_shatter", "vfx_label": "鳳凰炎岩", "effect_desc": "赤金炎柱破空震撼・重創石化並燃燒"},
	{"id": "butterfly", "kanji": "胡蝶", "kana": "こちょう", "mean": "蝴蝶 / 夢幻胡蝶", "distractors": ["とんぼ", "ほたる", "せみ"], "icon": "🦋", "color": "#c084fc", "vfx": "sakura_storm", "vfx_label": "紫蝶亂舞", "effect_desc": "幻紫蝶影螺旋起舞・造成傷害並回血"},
	{"id": "rainbow", "kanji": "虹色", "kana": "にじいろ", "mean": "七彩虹色", "distractors": ["きんいろ", "ぎんいろ", "ももいろ"], "icon": "🌈", "color": "#f472b6", "vfx": "sakura_storm", "vfx_label": "七彩花嵐", "effect_desc": "霓虹光羽旋風爆發・回復 22% HP 與體力"},
	{"id": "flash_slash", "kanji": "一閃", "kana": "いっせん", "mean": "居合一閃", "distractors": ["れんげき", "ざんげき", "とつげき"], "icon": "🗡️", "color": "#f8fafc", "vfx": "sword_rain", "vfx_label": "白銀一閃", "effect_desc": "銀白光刃齊落斬殺・額外 +25% 穿透傷害"},
	{"id": "phantom", "kanji": "幻影", "kana": "げんえい", "mean": "幻影 / 分身", "distractors": ["ざんぞう", "しんきろう", "かがみ"], "icon": "👻", "color": "#a855f7", "vfx": "sword_rain", "vfx_label": "幻影劍陣", "effect_desc": "紫魅劍雨覆蓋戰場・額外 +25% 穿透斬擊"},
	{"id": "shadow", "kanji": "暗黒", "kana": "あんこく", "mean": "暗黑 / 漆黑", "distractors": ["こうめい", "しんぴ", "せいかい"], "icon": "🌑", "color": "#818cf8", "vfx": "sword_rain", "vfx_label": "冥界魔劍", "effect_desc": "暗紫魔劍自虛空墜落・+25% 破甲重創"},
	{"id": "miracle", "kanji": "奇跡", "kana": "きせき", "mean": "奇蹟", "distractors": ["うんめい", "きぼう", "ゆめ"], "icon": "✨", "color": "#fef08a", "vfx": "sacred_halo", "vfx_label": "天界奇蹟", "effect_desc": "天界聖光柱降臨・回 30% HP＋滿體力＋25 SP"},
	{"id": "healing", "kanji": "治癒", "kana": "ちゆ", "mean": "治癒 / 療癒", "distractors": ["こうげき", "ぼうぎょ", "かいひ"], "icon": "💚", "color": "#4ade80", "vfx": "sacred_halo", "vfx_label": "翡翠聖癒", "effect_desc": "翠綠生命光柱綻放・回 30% HP＋滿體力＋25 SP"},
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
