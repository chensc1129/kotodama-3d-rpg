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

	for key in ["name", "char_id", "stage_id", "mode", "active_shikigami"]:
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
	var lv_bonus_hp: int = (lv - 1) * 18
	var lv_bonus_atk: int = (lv - 1) * 4

	var equip_hp: int = 0
	var equip_atk: int = 0
	for slot in ["weapon", "armor", "accessory"]:
		var eq_id: String = player["equipped"].get(slot, "")
		var eq: Dictionary = GameData.get_equipment(eq_id)
		if not eq.is_empty():
			var plus: int = int(player["equip_enhance"].get(eq_id, 0))
			equip_hp += int(round(float(eq["hp"]) * (1.0 + float(plus) * 0.18)))
			equip_atk += int(round(float(eq["atk"]) * (1.0 + float(plus) * 0.18)))

	var dash_lv: int = int(player["skills"].get("dash_skill", 1))
	return {
		"max_hp": int(char_cfg["base_hp"]) + lv_bonus_hp + equip_hp,
		"atk": int(char_cfg["base_atk"]) + lv_bonus_atk + equip_atk,
		"speed": float(char_cfg["base_spd"]) * (1.0 + float(dash_lv - 1) * 0.03),
	}


func get_computed_stats() -> Dictionary:
	var base := get_computed_stats_base()
	var bless: Dictionary = battle.get("blessings", {})
	var hp_mult: float = 1.0 + float(bless.get("hp_pct", 0.0))
	var atk_mult: float = 1.0 + float(bless.get("atk_pct", 0.0))
	var spd_pct: float = float(bless.get("spd_pct", 0.0))

	var char_cfg: Dictionary = GameData.get_character(player["char_id"])
	var dash_lv: int = int(player["skills"].get("dash_skill", 1))
	var speed: float = float(char_cfg["base_spd"]) * (1.0 + float(dash_lv - 1) * 0.03 + spd_pct)

	return {
		"max_hp": int(round(float(base["max_hp"]) * hp_mult)),
		"atk": int(round(float(base["atk"]) * atk_mult)),
		"speed": speed,
	}


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
			bless["atk_pct"] = float(bless["atk_pct"]) + 0.18
		"hp":
			bless["hp_pct"] = float(bless["hp_pct"]) + 0.20
			var st := get_computed_stats()
			battle["max_hp"] = st["max_hp"]
			battle["hp"] = mini(int(battle["max_hp"]), int(battle["hp"]) + int(round(float(battle["max_hp"]) * 0.4)))
		"stone":
			bless["stone_bonus"] = float(bless["stone_bonus"]) + 0.35
		"lifesteal":
			bless["lifesteal"] = float(bless["lifesteal"]) + 0.12
		"speed":
			bless["spd_pct"] = float(bless["spd_pct"]) + 0.12
			battle["sp"] = battle["max_sp"]
	state_changed.emit()
