class_name BattleManager
extends Node
## Core 3D action RPG combat controller, wave spawner, enemy AI, and skill execution.

signal hud_updated
signal popup_requested(world_pos: Vector3, text: String, color: Color)
signal chant_started(skill_type: String, word: Dictionary, max_time: float)
signal wave_cleared
signal battle_ended(is_victory: bool, reached_wave: int)

@export var arena: Arena3D
@export var camera_rig: CameraRig
@export var player: Player3D
@export var shikigami: Shikigami3D
@export var enemies_root: Node3D
@export var projectiles_root: Node3D
@export var vfx_root: Node3D

var joy_vector: Vector2 = Vector2.ZERO
var enemies: Array[Enemy3D] = []
var projectiles: Array[EnemyProjectile3D] = []

var _pending_skill_type: String = ""
var _pending_word: Dictionary = {}


func _ready() -> void:
	GameState.appearance_changed.connect(_on_appearance_changed)
	GameState.stage_changed.connect(_on_stage_changed)

	call_deferred("_initialize_world")


func _initialize_world() -> void:
	if arena != null:
		arena.build_stage(GameState.player["stage_id"])
	if player != null:
		player.position = Vector3(0.0, 0.0, 4.0)
		player.rebuild_mesh()
	if shikigami != null and player != null:
		shikigami.rebuild_mesh(player.position)
	hud_updated.emit()


func _on_appearance_changed() -> void:
	if player != null:
		player.rebuild_mesh()
	if shikigami != null and player != null:
		shikigami.rebuild_mesh(player.position)
	hud_updated.emit()


func _on_stage_changed(stage_id: String) -> void:
	if arena != null:
		arena.build_stage(stage_id)
	hud_updated.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not GameState.battle["active"] or GameState.battle["paused"]:
		return
	var focus_owner := get_viewport().gui_get_focus_owner()
	if focus_owner is LineEdit or focus_owner is TextEdit:
		return

	if event is InputEventKey:
		var ke := event as InputEventKey
		if ke.pressed and not ke.echo:
			if ke.unicode == 0x3042: # Hiragana 'あ'
				perform_attack_a()
				get_viewport().set_input_as_handled()
				return

	if event.is_action_pressed("attack"):
		perform_attack_a()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("dash"):
		perform_dash()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("skill_sig"):
		initiate_skill_chant("sig")
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("skill_ult"):
		initiate_skill_chant("ult")
		get_viewport().set_input_as_handled()


func start_new_battle() -> void:
	GameState.reset_battle_state()
	var stats := GameState.get_computed_stats()
	GameState.battle["active"] = true
	GameState.battle["paused"] = false
	GameState.battle["max_hp"] = stats["max_hp"]
	GameState.battle["hp"] = stats["max_hp"]
	GameState.battle["sp"] = 40.0
	GameState.battle["endless_seconds"] = 0.0

	if player != null:
		player.position = Vector3(0.0, 0.0, 4.0)
		player.facing = PI
		player.rebuild_mesh()
	if arena != null:
		arena.build_stage(GameState.player["stage_id"])
	if shikigami != null and player != null:
		shikigami.rebuild_mesh(player.position)

	start_wave(1)


func start_wave(wave_num: int) -> void:
	GameState.battle["wave"] = wave_num
	_clear_enemies_and_projectiles()

	# Endless mode auto-rotates 3D arenas every 3 waves
	if GameState.is_endless_mode() and wave_num > 1 and (wave_num - 1) % 3 == 0:
		var idx: int = int(floor(float(wave_num - 1) / 3.0)) % GameData.STAGES.size()
		var next_st: Dictionary = GameData.STAGES[idx]
		GameState.player["stage_id"] = next_st["id"]
		if arena != null:
			arena.build_stage(next_st["id"])
		GameState.toast_requested.emit("🌀 空間轉移！進入新戰場「%s」" % next_st["name"])

	var is_hard := GameState.is_hard_mode()
	var has_boss: bool = (wave_num % 2 == 0) or (wave_num >= 5)
	var mob_count: int = mini(12, 3 + int(floor(float(wave_num) * 0.9)) + (2 if is_hard else 0))

	for _i in range(mob_count):
		var tpl: Dictionary = GameData.MONSTER_TEMPLATES[randi() % GameData.MONSTER_TEMPLATES.size()]
		_spawn_enemy(tpl, false, wave_num, is_hard)

	if has_boss:
		var boss_idx: int = int(floor(float(wave_num) / 2.0)) % GameData.BOSS_TEMPLATES.size()
		var b_tpl: Dictionary = GameData.BOSS_TEMPLATES[boss_idx]
		_spawn_enemy(b_tpl, true, wave_num, is_hard)

	hud_updated.emit()


func _clear_enemies_and_projectiles() -> void:
	for en in enemies:
		if is_instance_valid(en):
			en.queue_free()
	enemies.clear()

	for pr in projectiles:
		if is_instance_valid(pr):
			pr.queue_free()
	projectiles.clear()


func _spawn_enemy(tpl: Dictionary, is_boss: bool, wave_num: int, is_hard: bool) -> void:
	if enemies_root == null:
		return
	var en := Enemy3D.new()
	enemies_root.add_child(en)
	en.setup(tpl, is_boss, wave_num, is_hard)
	enemies.append(en)


func spawn_ring_vfx(world_pos: Vector3, color: Color, max_radius: float = 6.0, duration: float = 0.45) -> void:
	if vfx_root == null:
		return
	var vfx := RingVfx3D.new()
	vfx_root.add_child(vfx)
	vfx.setup(world_pos, color, max_radius, duration)


func perform_attack_a() -> void:
	var b := GameState.battle
	if not b["active"] or b["paused"] or float(b["atk_cooldown"]) > 0.0:
		return

	b["atk_step"] = (int(b["atk_step"]) % 3) + 1
	b["atk_reset_timer"] = 1.2
	b["atk_cooldown"] = 0.22
	if player != null:
		player.slash_anim_timer = 0.24

	var step: int = int(b["atk_step"])
	AudioManager.play_sfx("slash%d" % step)

	var stats := GameState.get_computed_stats()
	var normal_lv: int = int(GameState.player["skills"].get("normal_a", 1))
	var skill_mult: float = 1.0 + float(normal_lv - 1) * 0.14
	var step_mult: float = 1.55 if step == 3 else (1.2 if step == 2 else 1.0)
	var reach: float = 5.2 if step == 3 else 4.2

	var char_cfg: Dictionary = GameData.get_character(GameState.player["char_id"])
	var vfx_color := Color.html("#fbbf24") if step == 3 else Color.html(char_cfg["color_primary"])
	spawn_ring_vfx(player.position, vfx_color, reach, 0.28)

	var hit_count: int = 0
	for en: Enemy3D in enemies.duplicate():
		if not is_instance_valid(en) or en.dead:
			continue
		var dist := en.position.distance_to(player.position)
		if dist <= reach:
			hit_count += 1
			var dmg := int(round(float(stats["atk"]) * skill_mult * step_mult * (0.92 + randf() * 0.16)))
			var tag := "あ!! 暴擊" if step == 3 else "あ"

			# Petrified Shatter Crit (Sakura synergy)
			if en.petrify_timer > 0.0:
				var stone_bonus := 1.5 + float(b["blessings"].get("stone_bonus", 0.0))
				dmg = int(round(float(dmg) * stone_bonus))
				tag = "🪨碎石暴擊!"
			elif (en.freeze_timer > 0.0 or en.stun_timer > 0.0) and float(b["blessings"].get("stone_bonus", 0.0)) > 0.0:
				dmg = int(round(float(dmg) * (1.0 + float(b["blessings"]["stone_bonus"]))))

			# Electro vulnerability bonus (Raijin synergy)
			if en.shock_timer > 0.0:
				dmg = int(round(float(dmg) * 1.25))

			var pop_color := Color.html("#fde047") if step == 3 else Color.WHITE
			damage_enemy(en, dmg, tag, pop_color)

			# Knockback
			var push_dir := en.position - player.position
			push_dir.y = 0.0
			if push_dir.length_squared() > 0.001:
				push_dir = push_dir.normalized()
				en.position += push_dir * (1.35 if step == 3 else 0.45)
				en.clamp_to_arena()

	if hit_count > 0:
		b["sp"] = minf(float(b["max_sp"]), float(b["sp"]) + 7.0 * float(hit_count))
		b["combo"] = int(b["combo"]) + hit_count
		b["combo_timer"] = 3.2

		var lifesteal: float = float(b["blessings"].get("lifesteal", 0.0))
		if lifesteal > 0.0:
			var heal := int(round(float(stats["atk"]) * lifesteal))
			b["hp"] = mini(int(b["max_hp"]), int(b["hp"]) + heal)

	hud_updated.emit()


func perform_dash() -> void:
	var b := GameState.battle
	if not b["active"] or b["paused"] or float(b["dash_cooldown"]) > 0.0:
		return
	AudioManager.play_sfx("dash")
	var dash_lv: int = int(GameState.player["skills"].get("dash_skill", 1))
	b["dash_timer"] = 0.22
	b["invuln_timer"] = 0.45
	b["dash_cooldown"] = maxf(0.6, 1.3 - float(dash_lv - 1) * 0.06)
	spawn_ring_vfx(player.position, Color.html("#38bdf8"), 2.5, 0.30)


func initiate_skill_chant(skill_type: String) -> void:
	var b := GameState.battle
	if not b["active"] or b["paused"]:
		return
	var cost: float = 70.0 if skill_type == "ult" else 30.0
	if float(b["sp"]) < cost:
		GameState.toast_requested.emit("言霊能量不足！（需要 %d SP，請用「あ」攻擊累積）" % int(cost))
		return

	_pending_skill_type = skill_type
	b["paused"] = true

	if skill_type == "sig":
		var char_cfg: Dictionary = GameData.get_character(GameState.player["char_id"])
		_pending_word = GameData.get_chant_word_by_id(char_cfg.get("chant_word_id", ""))
	else:
		_pending_word = GameData.get_random_chant_word()

	var max_time: float = 5.5 if GameState.is_hard_mode() else 8.5
	chant_started.emit(skill_type, _pending_word, max_time)


func cancel_chant() -> void:
	GameState.battle["paused"] = false
	_pending_skill_type = ""
	_pending_word = {}


func complete_skill_chant(is_success: bool, is_typed_perfect: bool) -> void:
	GameState.battle["paused"] = false
	var skill_type := _pending_skill_type
	var word := _pending_word
	_pending_skill_type = ""
	_pending_word = {}

	if skill_type.is_empty():
		return

	if not is_success:
		AudioManager.play_sfx("hit")
		GameState.toast_requested.emit("❌ 詠唱讀音錯誤，技能發動失敗！")
		return

	var cost: float = 70.0 if skill_type == "ult" else 30.0
	GameState.battle["sp"] = maxf(0.0, float(GameState.battle["sp"]) - cost)
	AudioManager.speak_japanese(String(word.get("kana", "")))
	AudioManager.play_sfx("skill")

	var crit_mult: float = 1.5 if is_typed_perfect else 1.0
	var stats := GameState.get_computed_stats()

	if skill_type == "ult":
		var ult_lv: int = int(GameState.player["skills"].get("ult_skill", 1))
		var ult_mult: float = 1.0 + float(ult_lv - 1) * 0.22
		var dmg := int(round(float(stats["atk"]) * 3.8 * ult_mult * crit_mult))
		spawn_ring_vfx(player.position, Color.html("#fbbf24"), 18.0, 0.75)
		for en: Enemy3D in enemies.duplicate():
			if is_instance_valid(en) and not en.dead:
				damage_enemy(en, dmg, "🌟完美奧義!" if is_typed_perfect else "🌟言霊奧義", Color.html("#fde047"))
		GameState.toast_requested.emit("🌟 完美詠唱！1.5 倍全屏言霊奧義爆發！" if is_typed_perfect else "🌟 言霊奧義發動！")
	else:
		_execute_signature_skill(stats, crit_mult)

	hud_updated.emit()


func _execute_signature_skill(stats: Dictionary, crit_mult: float) -> void:
	var char_cfg: Dictionary = GameData.get_character(GameState.player["char_id"])
	var sig_lv: int = int(GameState.player["skills"].get("sig_skill", 1))
	var sig_mult: float = 1.0 + float(sig_lv - 1) * 0.20
	var cid: String = char_cfg["id"]

	if cid == "sakura":
		var duration: float = 5.0 + float(sig_lv - 1) * 0.35
		var dmg := int(round(float(stats["atk"]) * 1.6 * sig_mult * crit_mult))
		spawn_ring_vfx(player.position, Color.html("#f472b6"), 13.0, 0.65)
		for en: Enemy3D in enemies.duplicate():
			if is_instance_valid(en) and not en.dead and en.position.distance_to(player.position) <= 13.5:
				en.petrify_timer = duration
				damage_enemy(en, dmg, "🪨石化封印!", Color.html("#f9a8d4"))
		GameState.toast_requested.emit("🪨「石頭」石化魔眼！妖怪石化 %.1f 秒，快用「あ」碎石暴擊！" % duration)
	elif cid == "kickboxer":
		player.kick_anim_timer = 0.5
		var forward := Vector3(sin(player.facing), 0.0, cos(player.facing))
		player.position += forward * 4.0
		player.clamp_to_arena()
		var dmg := int(round(float(stats["atk"]) * 2.9 * sig_mult * crit_mult))
		spawn_ring_vfx(player.position, Color.html("#38bdf8"), 9.5, 0.55)
		for en: Enemy3D in enemies.duplicate():
			if is_instance_valid(en) and not en.dead and en.position.distance_to(player.position) <= 9.5:
				en.stun_timer = 2.6
				var push := en.position - player.position
				push.y = 0.0
				if push.length_squared() > 0.001:
					en.position += push.normalized() * 4.5
					en.clamp_to_arena()
				damage_enemy(en, dmg, "🦶超烈風神腳!", Color.html("#7dd3fc"))
		GameState.toast_requested.emit("🦶「腳」超烈風神腳！轟飛並暈眩周圍妖怪！")
	elif cid == "raijin":
		var dmg := int(round(float(stats["atk"]) * 2.6 * sig_mult * crit_mult))
		spawn_ring_vfx(player.position, Color.html("#facc15"), 12.0, 0.60)
		for en: Enemy3D in enemies.duplicate():
			if is_instance_valid(en) and not en.dead and en.position.distance_to(player.position) <= 12.0:
				en.shock_timer = 5.0
				damage_enemy(en, dmg, "⚡九天雷鳴!", Color.html("#fef08a"))
		GameState.toast_requested.emit("⚡「雷光」九天雷鳴陣！妖怪陷入感電易傷狀態！")
	elif cid == "yukionna":
		var dmg := int(round(float(stats["atk"]) * 2.2 * sig_mult * crit_mult))
		spawn_ring_vfx(player.position, Color.html("#06b6d4"), 12.5, 0.65)
		for en: Enemy3D in enemies.duplicate():
			if is_instance_valid(en) and not en.dead and en.position.distance_to(player.position) <= 12.5:
				en.freeze_timer = 4.5
				en.frost_tick_timer = 0.6
				damage_enemy(en, dmg, "❄️絶対零度!", Color.html("#67e8f9"))
		GameState.toast_requested.emit("❄️「冰結」絶対零度氷華！凍結周圍妖怪！")
	else:
		var dmg := int(round(float(stats["atk"]) * 2.75 * sig_mult * crit_mult))
		spawn_ring_vfx(player.position, Color.html("#ef4444"), 10.5, 0.60)
		for en: Enemy3D in enemies.duplicate():
			if is_instance_valid(en) and not en.dead and en.position.distance_to(player.position) <= 10.5:
				en.burn_timer = 4.0
				damage_enemy(en, dmg, "🔥紅蓮烈焰!", Color.html("#fca5a5"))
		GameState.toast_requested.emit("🔥「火炎斬」紅蓮烈焰斬爆發！")


func damage_enemy(en: Enemy3D, dmg: int, tag: String, color: Color = Color.WHITE) -> void:
	if not is_instance_valid(en) or en.dead:
		return
	en.hp -= dmg
	popup_requested.emit(en.position + Vector3(0.0, 2.2, 0.0), "%s -%d" % [tag, dmg], color)

	if en.hp <= 0:
		en.dead = true
		en.queue_free()
		GameState.player["total_kills"] = int(GameState.player["total_kills"]) + 1

		var mode_mult: float = 2.0 if GameState.player["mode"] == "hard_endless" else (1.5 if GameState.is_hard_mode() else 1.0)
		var neko_bonus: float = 1.2 if GameState.player["active_shikigami"] == "neko" else 1.0
		var gold_gain := int(round((120.0 if en.is_boss else 18.0) * mode_mult * neko_bonus))
		var exp_gain := int(round((160.0 if en.is_boss else 26.0) * mode_mult))

		GameState.player["gold"] = int(GameState.player["gold"]) + gold_gain
		GameState.grant_exp(exp_gain)
		GameState.save_game_data()


func damage_player(dmg: int) -> void:
	var b := GameState.battle
	if float(b["invuln_timer"]) > 0.0:
		return
	b["invuln_timer"] = 0.65
	b["hp"] = maxi(0, int(b["hp"]) - dmg)
	AudioManager.play_sfx("hit")
	popup_requested.emit(player.position + Vector3(0.0, 2.2, 0.0), "-%d" % dmg, Color.html("#f43f5e"))

	if int(b["hp"]) <= 0:
		b["active"] = false
		b["paused"] = true
		GameState.toast_requested.emit("💀 体力歸零！返回道場重整裝備與技能再戰！")
		battle_ended.emit(false, int(b["wave"]))
	hud_updated.emit()


func get_active_boss() -> Enemy3D:
	for en in enemies:
		if is_instance_valid(en) and not en.dead and en.is_boss:
			return en
	return null


func _process(delta: float) -> void:
	var dt := minf(0.05, delta)
	var b := GameState.battle
	if not b["active"] or b["paused"]:
		if player != null:
			player.update_animations(dt, false)
		return

	# Timers & cooldowns
	b["atk_cooldown"] = maxf(0.0, float(b["atk_cooldown"]) - dt)
	b["dash_cooldown"] = maxf(0.0, float(b["dash_cooldown"]) - dt)
	b["dash_timer"] = maxf(0.0, float(b["dash_timer"]) - dt)
	b["invuln_timer"] = maxf(0.0, float(b["invuln_timer"]) - dt)

	if float(b["atk_reset_timer"]) > 0.0:
		b["atk_reset_timer"] = float(b["atk_reset_timer"]) - dt
		if float(b["atk_reset_timer"]) <= 0.0:
			b["atk_step"] = 0

	if float(b["combo_timer"]) > 0.0:
		b["combo_timer"] = float(b["combo_timer"]) - dt
		if float(b["combo_timer"]) <= 0.0:
			b["combo"] = 0

	if GameState.is_endless_mode():
		b["endless_seconds"] = float(b["endless_seconds"]) + dt

	# Movement input (camera-aligned)
	var move_input := joy_vector
	var focus_owner := get_viewport().gui_get_focus_owner()
	if not (focus_owner is LineEdit or focus_owner is TextEdit):
		if Input.is_action_pressed("move_up"):
			move_input.y -= 1.0
		if Input.is_action_pressed("move_down"):
			move_input.y += 1.0
		if Input.is_action_pressed("move_left"):
			move_input.x -= 1.0
		if Input.is_action_pressed("move_right"):
			move_input.x += 1.0

	var stats := GameState.get_computed_stats()
	var is_moving := move_input.length() > 0.05
	if is_moving and player != null:
		var clamped := move_input / maxf(1.0, move_input.length())
		var yaw: float = camera_rig.cam_yaw if camera_rig != null else 0.0
		var sin_y := sin(yaw)
		var cos_y := cos(yaw)
		var world_dx := clamped.x * cos_y + clamped.y * sin_y
		var world_dz := -clamped.x * sin_y + clamped.y * cos_y

		var dash_mult: float = 2.6 if float(b["dash_timer"]) > 0.0 else 1.0
		player.position.x += world_dx * float(stats["speed"]) * dash_mult * dt
		player.position.z += world_dz * float(stats["speed"]) * dash_mult * dt
		player.clamp_to_arena()
		player.facing = atan2(world_dx, world_dz)

	if player != null:
		player.update_animations(dt, is_moving)

	# Shikigami Companion Follow & Auto-Support
	if shikigami != null and shikigami.visible and player != null:
		shikigami.update_follow(dt, player.position, player.facing)
		b["shikigami_timer"] = float(b["shikigami_timer"]) + dt
		var active_sh: String = GameState.player.get("active_shikigami", "none")
		if active_sh == "kitsune" and float(b["shikigami_timer"]) >= 2.5 and not enemies.is_empty():
			b["shikigami_timer"] = 0.0
			var target := _find_nearest_enemy()
			if target != null:
				damage_enemy(target, int(round(float(stats["atk"]) * 0.85)), "🦊狐火", Color.html("#fb923c"))
				spawn_ring_vfx(target.position, Color.html("#f97316"), 2.2, 0.3)
		elif active_sh == "neko" and float(b["shikigami_timer"]) >= 4.0:
			b["shikigami_timer"] = 0.0
			var heal := int(round(float(b["max_hp"]) * 0.05))
			b["hp"] = mini(int(b["max_hp"]), int(b["hp"]) + heal)
			popup_requested.emit(player.position + Vector3(0.0, 2.2, 0.0), "🐱招財回復 +%d" % heal, Color.html("#fde047"))
		elif active_sh == "raiju" and float(b["shikigami_timer"]) >= 2.2 and not enemies.is_empty():
			b["shikigami_timer"] = 0.0
			var target := _find_nearest_enemy()
			if target != null:
				damage_enemy(target, int(round(float(stats["atk"]) * 0.90)), "🐺雷撃", Color.html("#38bdf8"))
				b["sp"] = minf(float(b["max_sp"]), float(b["sp"]) + 4.0)

	# Enemy AI & Status Effects
	for en: Enemy3D in enemies.duplicate():
		if not is_instance_valid(en) or en.dead:
			continue
		if en.petrify_timer > 0.0:
			en.petrify_timer = maxf(0.0, en.petrify_timer - dt)
		if en.freeze_timer > 0.0:
			en.freeze_timer = maxf(0.0, en.freeze_timer - dt)
			en.frost_tick_timer -= dt
			if en.frost_tick_timer <= 0.0:
				en.frost_tick_timer = 0.65
				damage_enemy(en, maxi(3, int(round(float(stats["atk"]) * 0.16))), "❄️寒霜", Color.html("#67e8f9"))
				if en.dead:
					continue
		if en.stun_timer > 0.0:
			en.stun_timer = maxf(0.0, en.stun_timer - dt)
		if en.shock_timer > 0.0:
			en.shock_timer = maxf(0.0, en.shock_timer - dt)
		if en.burn_timer > 0.0:
			en.burn_timer = maxf(0.0, en.burn_timer - dt)
			if randf() < dt * 2.0:
				damage_enemy(en, maxi(3, int(round(float(stats["atk"]) * 0.2))), "🔥灼燒", Color.html("#f87171"))
				if en.dead:
					continue

		en.update_status_visuals(dt)
		if en.is_controlled():
			continue

		var to_player := player.position - en.position
		to_player.y = 0.0
		var dist := to_player.length()
		if dist > 0.1:
			en.rotation.y = atan2(to_player.x, to_player.z)

		var stop_dist: float = 7.5 if en.ranged else 1.7
		if dist > stop_dist and dist > 0.001:
			en.position += to_player.normalized() * en.move_speed * dt
			en.clamp_to_arena()

		en.atk_timer -= dt
		if en.atk_timer <= 0.0:
			if dist <= 2.3:
				en.atk_timer = 1.4
				damage_player(en.atk)
			elif en.ranged and dist <= 15.0 and dist > 0.001:
				en.atk_timer = 2.4
				_spawn_enemy_projectile(en.position, to_player.normalized(), en.atk)

	# Prune dead enemies
	var alive: Array[Enemy3D] = []
	for en in enemies:
		if is_instance_valid(en) and not en.dead:
			alive.append(en)
	enemies = alive

	# Update Enemy Projectiles
	var alive_proj: Array[EnemyProjectile3D] = []
	for pr in projectiles:
		if not is_instance_valid(pr):
			continue
		pr.life -= dt
		pr.position += pr.direction * 9.5 * dt
		if pr.position.distance_to(Vector3(player.position.x, 1.2, player.position.z)) < 1.15:
			damage_player(pr.dmg)
			pr.queue_free()
			continue
		if pr.life <= 0.0:
			pr.queue_free()
			continue
		alive_proj.append(pr)
	projectiles = alive_proj

	# Check Wave Clear
	if enemies.is_empty() and b["active"]:
		if not GameState.is_endless_mode() and int(b["wave"]) >= 12:
			GameState.toast_requested.emit("👑 恭喜通關全 12 幕！獲得通關大賞 500 金幣！")
			GameState.player["gold"] = int(GameState.player["gold"]) + 500
			GameState.save_game_data()
			b["active"] = false
			b["paused"] = true
			battle_ended.emit(true, int(b["wave"]))
		else:
			b["paused"] = true
			wave_cleared.emit()

	hud_updated.emit()


func _find_nearest_enemy() -> Enemy3D:
	var best: Enemy3D = null
	var best_d := INF
	for en in enemies:
		if not is_instance_valid(en) or en.dead:
			continue
		var d := en.position.distance_squared_to(player.position)
		if d < best_d:
			best_d = d
			best = en
	return best


func _spawn_enemy_projectile(origin: Vector3, dir: Vector3, dmg: int) -> void:
	if projectiles_root == null:
		return
	var pr := EnemyProjectile3D.new()
	projectiles_root.add_child(pr)
	pr.setup(origin, dir, dmg)
	projectiles.append(pr)
