extends Node
## Persistent player state, auto-save/load, computed RPG stats, and active battle state.

signal state_changed
signal appearance_changed
signal stage_changed(stage_id: String)
signal toast_requested(message: String)
signal leveled_up(new_level: int)

const SAVE_PATH: String = "user://kotodama_3d_rpg_v2_save.json"

var player: Dictionary = {
	"name": "櫻花見習生",
	"char_id": "sakura",
	"arpg_char_id": "sakura",
	"stage_id": "sakura_shrine",
	"mode": "normal",
	"level": 1,
	"exp": 0,
	"gold": 200,
	"skill_points": 2,
	"skills": {
		"normal_a": 1,
		"sig_skill": 1,
		"ult_skill": 1,
		"dash_skill": 1,
	},
	"owned_equip": ["w1", "a1", "r1"],
	"equipped": {
		"weapon": "w1",
		"armor": "a1",
		"accessory": "r1",
	},
	"equip_enhance": {},
	"owned_shikigami": ["none"],
	"active_shikigami": "none",
	"total_kills": 0,
	"arpg_ch1": {
		"quiz_cleared_npcs": [],
		"chapter_cleared": false,
	},
}

var battle: Dictionary = {}
var mouse_sens_mult: float = 1.0


func _ready() -> void:
	reset_battle_state()
	load_save_data()


func reset_battle_state() -> void:
	var stats := get_computed_stats_base()
	var dash_lv: int = int(player["skills"].get("dash_skill", 1))
	var max_sta: float = 100.0 + float(dash_lv - 1) * 10.0
	battle = {
		"active": false,
		"paused": true,
		"wave": 1,
		"hp": stats["max_hp"],
		"max_hp": stats["max_hp"],
		"sp": 40.0,
		"max_sp": 100.0,
		"stamina": max_sta,
		"max_stamina": max_sta,
		"stamina_regen_delay": 0.0,
		"stamina_exhausted": false,
		"is_sprinting": false,
		"combo": 0,
		"combo_timer": 0.0,
		"atk_step": 0,
		"atk_reset_timer": 0.0,
		"atk_cooldown": 0.0,
		"dash_cooldown": 0.0,
		"dash_timer": 0.0,
		"invuln_timer": 0.0,
		"endless_seconds": 0.0,
		"shikigami_timer": 0.0,
		"blessings": {
			"atk_pct": 0.0,
			"hp_pct": 0.0,
			"spd_pct": 0.0,
			"stone_bonus": 0.0,
			"lifesteal": 0.0,
		},
	}


func load_save_data() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return

	for key in ["name", "char_id", "arpg_char_id", "stage_id", "mode", "active_shikigami"]:
		if parsed.has(key) and typeof(parsed[key]) == TYPE_STRING:
			player[key] = parsed[key]

	for key in ["level", "exp", "gold", "skill_points", "total_kills"]:
		if parsed.has(key):
			player[key] = int(parsed[key])

	if parsed.has("skills") and typeof(parsed["skills"]) == TYPE_DICTIONARY:
		for sk in player["skills"].keys():
			if parsed["skills"].has(sk):
				player["skills"][sk] = clampi(int(parsed["skills"][sk]), 1, GameData.MAX_SKILL_LEVEL)

	if parsed.has("owned_equip") and typeof(parsed["owned_equip"]) == TYPE_ARRAY:
		var cleaned_eq: Array = []
		for item in parsed["owned_equip"]:
			if typeof(item) == TYPE_STRING and not cleaned_eq.has(item):
				cleaned_eq.append(item)
		for starter in ["w1", "a1", "r1"]:
			if not cleaned_eq.has(starter):
				cleaned_eq.append(starter)
		player["owned_equip"] = cleaned_eq

	if parsed.has("equipped") and typeof(parsed["equipped"]) == TYPE_DICTIONARY:
		for slot in ["weapon", "armor", "accessory"]:
			if parsed["equipped"].has(slot) and typeof(parsed["equipped"][slot]) == TYPE_STRING:
				player["equipped"][slot] = parsed["equipped"][slot]

	if parsed.has("equip_enhance") and typeof(parsed["equip_enhance"]) == TYPE_DICTIONARY:
		var enh: Dictionary = {}
		for eq_id in parsed["equip_enhance"].keys():
			enh[String(eq_id)] = clampi(int(parsed["equip_enhance"][eq_id]), 0, GameData.MAX_EQUIP_ENHANCE)
		player["equip_enhance"] = enh

	if parsed.has("owned_shikigami") and typeof(parsed["owned_shikigami"]) == TYPE_ARRAY:
		var cleaned_sh: Array = ["none"]
		for item in parsed["owned_shikigami"]:
			if typeof(item) == TYPE_STRING and not cleaned_sh.has(item):
				cleaned_sh.append(item)
		player["owned_shikigami"] = cleaned_sh

	if parsed.has("arpg_ch1") and typeof(parsed["arpg_ch1"]) == TYPE_DICTIONARY:
		var ch1_in: Dictionary = parsed["arpg_ch1"]
		var cleared_npcs: Array = []
		if ch1_in.has("quiz_cleared_npcs") and typeof(ch1_in["quiz_cleared_npcs"]) == TYPE_ARRAY:
			for nid in ch1_in["quiz_cleared_npcs"]:
				if typeof(nid) == TYPE_STRING and not cleared_npcs.has(nid):
					cleared_npcs.append(nid)
		player["arpg_ch1"] = {
			"quiz_cleared_npcs": cleared_npcs,
			"chapter_cleared": bool(ch1_in.get("chapter_cleared", false)),
		}

	if not is_arpg_char_unlocked(String(player.get("arpg_char_id", "sakura"))):
		player["arpg_char_id"] = GameData.ARPG_STARTER_CHARACTERS[0]

	var stats := get_computed_stats()
	battle["max_hp"] = stats["max_hp"]
	battle["hp"] = stats["max_hp"]


func save_game_data() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(player, "\t"))
	file.close()


func get_exp_to_next_level(lv: int) -> int:
	return int(floor(80.0 + pow(float(lv), 1.55) * 35.0))


func get_computed_stats_base() -> Dictionary:
	var char_cfg: Dictionary = GameData.get_character(player["char_id"])
	var lv: int = int(player["level"])
	# Smooth diminishing returns so late-game stats stay crisp & readable
	var tier1: int = maxi(0, mini(lv, 15) - 1)
	var tier2: int = maxi(0, mini(lv, 30) - 15)
	var tier3: int = maxi(0, lv - 30)
	var lv_bonus_hp: int = tier1 * 8 + tier2 * 5 + tier3 * 3
	var lv_bonus_atk: int = int(round(float(tier1) * 2.0 + float(tier2) * 1.0 + float(tier3) * 0.5))

	var equip_hp: int = 0
	var equip_atk: int = 0
	for slot in ["weapon", "armor", "accessory"]:
		var eq_id: String = player["equipped"].get(slot, "")
		var eq: Dictionary = GameData.get_equipment(eq_id)
		if not eq.is_empty():
			var plus: int = int(player["equip_enhance"].get(eq_id, 0))
			equip_hp += int(round(float(eq["hp"]) * (1.0 + float(plus) * 0.08)))
			equip_atk += int(round(float(eq["atk"]) * (1.0 + float(plus) * 0.08)))

	var dash_lv: int = int(player["skills"].get("dash_skill", 1))
	return {
		"max_hp": int(char_cfg["base_hp"]) + lv_bonus_hp + equip_hp,
		"atk": int(char_cfg["base_atk"]) + lv_bonus_atk + equip_atk,
		"speed": float(char_cfg["base_spd"]) * (1.0 + float(dash_lv - 1) * 0.02),
	}


func get_computed_stats() -> Dictionary:
	var base := get_computed_stats_base()
	var bless: Dictionary = battle.get("blessings", {})
	var hp_mult: float = 1.0 + minf(0.96, float(bless.get("hp_pct", 0.0)))
	var atk_mult: float = 1.0 + minf(0.80, float(bless.get("atk_pct", 0.0)))
	var spd_pct: float = minf(0.42, float(bless.get("spd_pct", 0.0)))

	var char_cfg: Dictionary = GameData.get_character(player["char_id"])
	var dash_lv: int = int(player["skills"].get("dash_skill", 1))
	var speed: float = float(char_cfg["base_spd"]) * (1.0 + float(dash_lv - 1) * 0.02 + spd_pct)

	return {
		"max_hp": int(round(float(base["max_hp"]) * hp_mult)),
		"atk": int(round(float(base["atk"]) * atk_mult)),
		"speed": speed,
	}


func is_arpg_mode() -> bool:
	return String(player.get("mode", "normal")) == "arpg_story"


func is_arpg_npc_cleared(npc_id: String) -> bool:
	var ch1: Dictionary = player.get("arpg_ch1", {})
	var arr: Array = ch1.get("quiz_cleared_npcs", [])
	return arr.has(npc_id)


func get_arpg_quiz_cleared_count() -> int:
	var ch1: Dictionary = player.get("arpg_ch1", {})
	var arr: Array = ch1.get("quiz_cleared_npcs", [])
	return arr.size()


func claim_arpg_npc_reward(npc_id: String, reward: Dictionary, first_clear: bool) -> void:
	if not player.has("arpg_ch1") or typeof(player["arpg_ch1"]) != TYPE_DICTIONARY:
		player["arpg_ch1"] = {"quiz_cleared_npcs": [], "chapter_cleared": false}
	var ch1: Dictionary = player["arpg_ch1"]
	var arr: Array = ch1.get("quiz_cleared_npcs", [])
	var prev_unlocked := get_arpg_unlocked_chars()
	if first_clear:
		if not arr.has(npc_id):
			arr.append(npc_id)
		ch1["quiz_cleared_npcs"] = arr
		player["gold"] = int(player["gold"]) + int(reward.get("gold", 100))
		var sp_gain: int = int(reward.get("skill_points", 0))
		if sp_gain > 0:
			player["skill_points"] = int(player["skill_points"]) + sp_gain
		var exp_gain: int = int(reward.get("exp", 0))
		if exp_gain > 0:
			grant_exp(exp_gain)
		var bkey: String = String(reward.get("buff_key", ""))
		var bval: float = float(reward.get("buff_val", 0.0))
		if not bkey.is_empty() and bval > 0.0 and battle.has("blessings"):
			var bless: Dictionary = battle["blessings"]
			if bless.has(bkey):
				bless[bkey] = float(bless[bkey]) + bval
				var st := get_computed_stats()
				battle["max_hp"] = st["max_hp"]
	else:
		# Repeat Japanese quiz practice reward!
		player["gold"] = int(player["gold"]) + 30
		grant_exp(20)

	var st_now := get_computed_stats()
	battle["max_hp"] = st_now["max_hp"]
	if bool(reward.get("heal_full", false)) or not first_clear:
		battle["hp"] = int(battle["max_hp"])
		battle["stamina"] = float(battle["max_stamina"])
	if bool(reward.get("sp_full", false)):
		battle["sp"] = float(battle["max_sp"])
	save_game_data()
	state_changed.emit()

	if first_clear:
		var now_unlocked := get_arpg_unlocked_chars()
		for cid in now_unlocked:
			if not prev_unlocked.has(cid):
				var ch_cfg := GameData.get_character(cid)
				toast_requested.emit("🎉 新 ARPG 夥伴解鎖！%s %s 已可在 RPG 專區出戰！" % [ch_cfg["icon"], ch_cfg["name"]])


func is_arpg_char_unlocked(char_id: String) -> bool:
	if GameData.ARPG_STARTER_CHARACTERS.has(char_id):
		return true
	if not GameData.ARPG_CHARACTER_UNLOCKS.has(char_id):
		return false
	var rule: Dictionary = GameData.ARPG_CHARACTER_UNLOCKS[char_id]
	var req_q: int = int(rule.get("quizzes", 0))
	var req_clear: bool = bool(rule.get("chapter_clear", false))
	var ch1: Dictionary = player.get("arpg_ch1", {})
	var cleared_ch1: bool = bool(ch1.get("chapter_cleared", false))
	if req_clear:
		return cleared_ch1
	return get_arpg_quiz_cleared_count() >= req_q


func get_arpg_unlocked_chars() -> Array[String]:
	var res: Array[String] = []
	for cid in GameData.CHARACTER_ORDER:
		if is_arpg_char_unlocked(cid):
			res.append(cid)
	return res


func get_arpg_char_unlock_hint(char_id: String) -> String:
	if GameData.ARPG_CHARACTER_UNLOCKS.has(char_id):
		return String(GameData.ARPG_CHARACTER_UNLOCKS[char_id].get("hint", "推進 ARPG 劇情解鎖"))
	return ""


func get_arpg_char_id() -> String:
	var cid: String = String(player.get("arpg_char_id", "sakura"))
	if is_arpg_char_unlocked(cid):
		return cid
	return GameData.ARPG_STARTER_CHARACTERS[0]


func set_arpg_character(char_id: String) -> bool:
	if not GameData.CHARACTERS.has(char_id):
		return false
	if not is_arpg_char_unlocked(char_id):
		var ch_cfg := GameData.get_character(char_id)
		toast_requested.emit("🔒 %s 尚未在 ARPG 解鎖（%s）" % [ch_cfg["name"], get_arpg_char_unlock_hint(char_id)])
		return false
	player["arpg_char_id"] = char_id
	save_game_data()
	state_changed.emit()
	return true


func is_hard_mode() -> bool:
	return player["mode"] == "hard" or player["mode"] == "hard_endless"


func is_endless_mode() -> bool:
	return player["mode"] == "endless" or player["mode"] == "hard_endless"


func set_player_name(new_name: String) -> void:
	var trimmed := new_name.strip_edges()
	if trimmed.is_empty():
		return
	player["name"] = trimmed.substr(0, 12)
	save_game_data()
	appearance_changed.emit()
	state_changed.emit()
	toast_requested.emit("🏷️ 角色名稱已更新為「%s」" % player["name"])


func set_character(char_id: String) -> void:
	if not GameData.CHARACTERS.has(char_id):
		return
	player["char_id"] = char_id
	save_game_data()
	appearance_changed.emit()
	state_changed.emit()


func set_stage(stage_id: String) -> void:
	player["stage_id"] = stage_id
	save_game_data()
	stage_changed.emit(stage_id)
	state_changed.emit()


func set_mode(mode_id: String) -> void:
	player["mode"] = mode_id
	save_game_data()
	state_changed.emit()


func grant_exp(amount: int) -> void:
	if int(player["level"]) >= GameData.MAX_LEVEL:
		return
	player["exp"] = int(player["exp"]) + amount
	var did_level_up := false

	while int(player["level"]) < GameData.MAX_LEVEL and int(player["exp"]) >= get_exp_to_next_level(int(player["level"])):
		player["exp"] = int(player["exp"]) - get_exp_to_next_level(int(player["level"]))
		player["level"] = int(player["level"]) + 1
		player["skill_points"] = int(player["skill_points"]) + 1
		did_level_up = true

	if did_level_up:
		AudioManager.play_sfx("levelup")
		var stats := get_computed_stats()
		battle["max_hp"] = stats["max_hp"]
		battle["hp"] = stats["max_hp"]
		battle["sp"] = battle["max_sp"]
		appearance_changed.emit()
		leveled_up.emit(int(player["level"]))
		toast_requested.emit("🎉 升級至 Lv.%d！全能力提升並獲得技能點 +1！" % int(player["level"]))

	state_changed.emit()


func upgrade_skill(skill_key: String) -> bool:
	var lv: int = int(player["skills"].get(skill_key, 1))
	if int(player["skill_points"]) <= 0 or lv >= GameData.MAX_SKILL_LEVEL:
		return false
	player["skill_points"] = int(player["skill_points"]) - 1
	player["skills"][skill_key] = lv + 1
	AudioManager.play_sfx("levelup")
	save_game_data()
	state_changed.emit()
	return true


func buy_or_equip_item(eq_id: String, action: String) -> bool:
	var eq: Dictionary = GameData.get_equipment(eq_id)
	if eq.is_empty():
		return false
	var owned: bool = player["owned_equip"].has(eq_id)
	var plus: int = int(player["equip_enhance"].get(eq_id, 0))
	var enh_cost: int = 80 + plus * 60

	if action == "buy":
		if owned or int(player["gold"]) < int(eq["cost"]):
			return false
		player["gold"] = int(player["gold"]) - int(eq["cost"])
		player["owned_equip"].append(eq_id)
		player["equipped"][eq["slot"]] = eq_id
		AudioManager.play_sfx("levelup")
	elif action == "equip":
		if not owned:
			return false
		player["equipped"][eq["slot"]] = eq_id
		AudioManager.play_sfx("dash")
	elif action == "enh":
		if not owned or plus >= GameData.MAX_EQUIP_ENHANCE or int(player["gold"]) < enh_cost:
			return false
		player["gold"] = int(player["gold"]) - enh_cost
		player["equip_enhance"][eq_id] = plus + 1
		AudioManager.play_sfx("levelup")
	else:
		return false

	var stats := get_computed_stats()
	battle["max_hp"] = stats["max_hp"]
	battle["hp"] = mini(int(battle["hp"]), int(battle["max_hp"]))
	save_game_data()
	appearance_changed.emit()
	state_changed.emit()
	return true


func contract_or_summon_shikigami(sh_id: String) -> bool:
	var sh: Dictionary = GameData.get_shikigami(sh_id)
	if sh.is_empty():
		return false
	var owned: bool = player["owned_shikigami"].has(sh_id)
	if not owned:
		if int(player["gold"]) < int(sh["cost"]):
			return false
		player["gold"] = int(player["gold"]) - int(sh["cost"])
		player["owned_shikigami"].append(sh_id)
	player["active_shikigami"] = sh_id
	AudioManager.play_sfx("levelup")
	save_game_data()
	appearance_changed.emit()
	state_changed.emit()
	return true


func apply_blessing(blessing_id: String) -> void:
	var bless: Dictionary = battle["blessings"]
	match blessing_id:
		"atk":
			if float(bless["atk_pct"]) < 0.80:
				bless["atk_pct"] = minf(0.80, float(bless["atk_pct"]) + 0.10)
			else:
				player["gold"] = int(player["gold"]) + 120
				toast_requested.emit("⚔️ 鬼神剛力已達上限，轉化為 120 金幣！")
		"hp":
			bless["hp_pct"] = minf(0.96, float(bless["hp_pct"]) + 0.12)
			var st := get_computed_stats()
			battle["max_hp"] = st["max_hp"]
			battle["hp"] = mini(int(battle["max_hp"]), int(battle["hp"]) + int(round(float(battle["max_hp"]) * 0.35)))
		"stone":
			if float(bless["stone_bonus"]) < 1.00:
				bless["stone_bonus"] = minf(1.00, float(bless["stone_bonus"]) + 0.20)
			else:
				player["gold"] = int(player["gold"]) + 120
				toast_requested.emit("🪨 破甲奧義已達上限，轉化為 120 金幣！")
		"lifesteal":
			if float(bless["lifesteal"]) < 0.30:
				bless["lifesteal"] = minf(0.30, float(bless["lifesteal"]) + 0.06)
			else:
				battle["hp"] = mini(int(battle["max_hp"]), int(battle["hp"]) + int(round(float(battle["max_hp"]) * 0.35)))
				toast_requested.emit("🩸 妖刀吸血已達上限，轉化為立即回復 35% HP！")
		"speed":
			bless["spd_pct"] = minf(0.42, float(bless["spd_pct"]) + 0.07)
			battle["sp"] = minf(float(battle["max_sp"]), float(battle["sp"]) + 80.0)
	state_changed.emit()
