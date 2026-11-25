class_name BattleManager
extends Node
## Core 3D action RPG combat controller, wave spawner, enemy AI, and skill execution.

signal hud_updated
signal popup_requested(world_pos: Vector3, text: String, color: Color)
signal chant_started(skill_type: String, word: Dictionary, max_time: float)
signal wave_cleared
signal battle_ended(is_victory: bool, reached_wave: int)
signal attack_swung(step: int)
signal hit_landed(is_crit: bool)

@export var arena: Arena3D
@export var camera_rig: CameraRig
@export var player: Player3D
@export var shikigami: Shikigami3D
@export var enemies_root: Node3D
@export var projectiles_root: Node3D
@export var vfx_root: Node3D

const DASH_STAMINA_COST: float = 24.0
const SPRINT_DRAIN_PER_SEC: float = 20.0
const STAMINA_REGEN_PER_SEC: float = 28.0
const SHIFT_DOUBLE_TAP_WINDOW: float = 0.30

var joy_vector: Vector2 = Vector2.ZERO
var enemies: Array[Enemy3D] = []
var projectiles: Array[EnemyProjectile3D] = []

var _pending_skill_type: String = ""
var _pending_word: Dictionary = {}
var _hitstop_timer: float = 0.0
var _shift_tap_window: float = 0.0
var _dash_dir: Vector3 = Vector3.ZERO
var _move_vel: Vector3 = Vector3.ZERO
var _hud_sync_acc: float = 0.0
var _save_dirty: bool = false
var _save_flush_timer: float = 0.0

# Stage-specific mechanic runtime states
var _sakura_cycle_timer: float = 0.0
var _sakura_heal_acc: float = 0.0
var _in_sakura_buff: bool = false
var _wind_buff_timer: float = 0.0
var _lava_tick_timer: float = 0.0
var _enemy_lava_timer: float = 0.0
var _hazard_spawn_timer: float = 4.2
var _jump_pad_cooldown: float = 0.0
var _stage_hazards: Array[Dictionary] = [] # {pos, radius, timer, max_time, kind, node, mat}


func _ready() -> void:
	GameState.appearance_changed.connect(_on_appearance_changed)
	GameState.stage_changed.connect(_on_stage_changed)

	call_deferred("_initialize_world")


func _get_terrain_y(x: float, z: float, cur_y: float = 99.0) -> float:
	if arena != null:
		return arena.get_ground_height(x, z, cur_y)
	return 0.0


func _reset_stage_mechanics() -> void:
	_clear_stage_hazards()
	_sakura_cycle_timer = 0.0
	_sakura_heal_acc = 0.0
	_in_sakura_buff = false
	_wind_buff_timer = 0.0
	_lava_tick_timer = 0.0
	_enemy_lava_timer = 0.0
	_hazard_spawn_timer = 4.2
	_jump_pad_cooldown = 0.0
	GameState.battle["stage_status"] = ""


func _clear_stage_hazards() -> void:
	for hz in _stage_hazards:
		var n: Node3D = hz.get("node")
		if is_instance_valid(n):
			n.queue_free()
	_stage_hazards.clear()


func _initialize_world() -> void:
	if arena != null:
		arena.build_stage(GameState.player["stage_id"])
	_reset_stage_mechanics()
	if player != null:
		player.position = Vector3(0.0, 0.0, 4.0)
		player.reset_vertical_state(_get_terrain_y(0.0, 4.0))
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
	_reset_stage_mechanics()
	if player != null:
		player.reset_vertical_state(_get_terrain_y(player.position.x, player.position.z))
	hud_updated.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not GameState.battle["active"] or GameState.battle["paused"]:
		return
	var focus_owner := get_viewport().gui_get_focus_owner()
	if focus_owner is LineEdit or focus_owner is TextEdit:
		return

	# When mouse is locked on desktop: Left-Click attacks, Right-Click quick-dashes!
	if event is InputEventMouseButton and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var mb := event as InputEventMouseButton
		if mb.pressed:
			if mb.button_index == MOUSE_BUTTON_LEFT:
				perform_attack_a()
				get_viewport().set_input_as_handled()
				return
			elif mb.button_index == MOUSE_BUTTON_RIGHT:
				perform_dash()
				get_viewport().set_input_as_handled()
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
	elif event.is_action_pressed("jump"):
		perform_jump()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("sprint"):
		# Double-tap Shift within window -> Explosive Quick Dash!
		if _shift_tap_window > 0.0:
			_shift_tap_window = 0.0
			perform_dash()
		else:
			_shift_tap_window = SHIFT_DOUBLE_TAP_WINDOW
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
	_hitstop_timer = 0.0
	_shift_tap_window = 0.0
	_dash_dir = Vector3.ZERO
	_move_vel = Vector3.ZERO
	_hud_sync_acc = 0.0
	_reset_stage_mechanics()
	var stats := GameState.get_computed_stats()
	GameState.battle["active"] = true
	GameState.battle["paused"] = false
	GameState.battle["max_hp"] = stats["max_hp"]
	GameState.battle["hp"] = stats["max_hp"]
	GameState.battle["sp"] = 40.0
	GameState.battle["endless_seconds"] = 0.0

	if arena != null:
		arena.build_stage(GameState.player["stage_id"])
	if player != null:
		player.position = Vector3(0.0, 0.0, 4.0)
		player.reset_vertical_state(_get_terrain_y(0.0, 4.0))
		player.facing = PI
		player.rebuild_mesh()
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
		_reset_stage_mechanics()
		if arena != null:
			arena.build_stage(next_st["id"])
		if player != null:
			player.reset_vertical_state(_get_terrain_y(player.position.x, player.position.z))
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
	_clear_stage_hazards()


func _spawn_enemy(tpl: Dictionary, is_boss: bool, wave_num: int, is_hard: bool) -> void:
	if enemies_root == null:
		return
	var en := Enemy3D.new()
	enemies_root.add_child(en)
	en.setup(tpl, is_boss, wave_num, is_hard)
	en.position.y = _get_terrain_y(en.position.x, en.position.z, 10.0)
	if arena != null:
		en.position = arena.resolve_obstacle_collision(en.position, 0.78 * en.scale.x)
		en.position.y = _get_terrain_y(en.position.x, en.position.z, 10.0)
	enemies.append(en)


func spawn_ring_vfx(world_pos: Vector3, color: Color, max_radius: float = 6.0, duration: float = 0.45) -> void:
	if vfx_root == null:
		return
	var vfx := RingVfx3D.new()
	vfx_root.add_child(vfx)
	vfx.setup(world_pos, color, max_radius, duration)


func spawn_hit_spark(world_pos: Vector3, color: Color, is_crit: bool = false, intensity: float = 1.0) -> void:
	if vfx_root == null:
		return
	var vfx := HitVfx3D.new()
	vfx_root.add_child(vfx)
	vfx.setup_hit_spark(world_pos, color, is_crit, intensity)


func spawn_death_burst(world_pos: Vector3, color: Color, is_boss: bool = false) -> void:
	if vfx_root == null:
		return
	var vfx := HitVfx3D.new()
	vfx_root.add_child(vfx)
	vfx.setup_death_burst(world_pos, color, is_boss)


func spawn_kotodama_vfx(world_pos: Vector3, word: Dictionary, is_perfect: bool = false) -> void:
	if vfx_root == null:
		return
	var vfx := KotodamaVfx3D.new()
	vfx_root.add_child(vfx)
	vfx.setup(world_pos, word, is_perfect)


func spawn_hero_attack_vfx(char_id: String, world_pos: Vector3, facing: float, step: int, reach: float) -> void:
	if vfx_root == null:
		return
	var vfx := HeroAttackVfx3D.new()
	vfx_root.add_child(vfx)
	vfx.setup(char_id, world_pos, facing, step, reach)


func trigger_hitstop(duration: float) -> void:
	_hitstop_timer = maxf(_hitstop_timer, duration)


func _trigger_camera_impact(trauma: float, fov_delta: float = 0.0) -> void:
	if camera_rig != null:
		camera_rig.add_trauma(trauma)
		if absf(fov_delta) > 0.01:
			camera_rig.add_fov_punch(fov_delta)


func perform_attack_a() -> void:
	var b := GameState.battle
	if not b["active"] or b["paused"] or float(b["atk_cooldown"]) > 0.0:
		return

	var char_cfg: Dictionary = GameData.get_character(GameState.player["char_id"])
	var cid: String = String(char_cfg["id"])
	var prof: Dictionary = char_cfg.get("attack_profile", {})
	var reaches: Array = prof.get("reach", [4.35, 4.5, 5.4])
	var lunges: Array = prof.get("lunge", [0.38, 0.42, 0.78])
	var step_mults: Array = prof.get("step_mult", [1.0, 1.2, 1.55])

	b["atk_step"] = (int(b["atk_step"]) % 3) + 1
	b["atk_reset_timer"] = 1.25
	b["atk_cooldown"] = float(prof.get("cd", 0.22))
	var step: int = int(b["atk_step"])
	var idx: int = clampi(step - 1, 0, 2)
	var reach: float = float(reaches[idx])
	var lunge_dist: float = float(lunges[idx])
	var step_mult: float = float(step_mults[idx])
	var kb_mult: float = float(prof.get("kb_mult", 1.0))
	var hitstop_mult: float = float(prof.get("hitstop_mult", 1.0))
	var trauma_mult: float = float(prof.get("trauma_mult", 1.0))

	attack_swung.emit(step)
	var forward := Vector3(0.0, 0.0, 1.0)
	if player != null:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and camera_rig != null:
			player.facing = camera_rig.get_aim_facing()
		player.trigger_slash(step)
		forward = Vector3(sin(player.facing), 0.0, cos(player.facing)).normalized()
		var pre_lunge := player.position
		player.position += forward * lunge_dist
		player.clamp_to_arena()
		if arena != null:
			player.position = arena.resolve_obstacle_collision(player.position, 0.62)
			player.position = arena.resolve_terrain_step(pre_lunge, player.position, player.is_grounded)

	var sfx_prefix: String = String(prof.get("sfx_prefix", "slash"))
	AudioManager.play_sfx("%s_%d" % [sfx_prefix, step] if sfx_prefix != "slash" else ("slash%d" % step))

	var stats := GameState.get_computed_stats()
	var normal_lv: int = int(GameState.player["skills"].get("normal_a", 1))
	var skill_mult: float = 1.0 + float(normal_lv - 1) * 0.08
	var sakura_mult: float = 1.20 if _in_sakura_buff else 1.0

	var vfx_color := Color.html("#fbbf24") if step == 3 else Color.html(char_cfg["color_primary"])
	if player != null:
		spawn_hero_attack_vfx(cid, player.position, player.facing, step, reach)
		# Keep subtle ground pulse on finishers & heavy strikes
		if step == 3 or cid == "kickboxer" or cid == "swordsman":
			var ring_pos := player.position + (forward * (reach * 0.55) if (cid == "yukionna" and step == 3) else Vector3.ZERO)
			spawn_ring_vfx(ring_pos, vfx_color, reach * (0.52 if cid == "yukionna" else 0.78), 0.28)
		# Swing micro-impulse on heavy/fast heroes
		if step == 3 and cid == "kickboxer":
			_trigger_camera_impact(0.16, -1.2)
		elif cid == "raijin":
			_trigger_camera_impact(0.06, 0.8)

	var hit_count: int = 0
	var any_crit: bool = false
	var crit_tag: String = String(prof.get("crit_tag", "あ!! 暴擊"))
	var base_tag: String = String(prof.get("base_tag", "あ"))

	for item in enemies.duplicate():
		if not is_instance_valid(item):
			continue
		var en := item as Enemy3D
		if en == null or en.dead:
			continue
		var to_en := Vector2(en.position.x - player.position.x, en.position.z - player.position.z)
		var flat_dist := to_en.length()
		var dy := absf(en.position.y - player.position.y)
		# Yukionna's long-range ice darts focus in a generous forward arc (or full lotus burst on step 3!)
		var in_range := flat_dist <= reach and dy <= 3.1
		if in_range and cid == "yukionna" and flat_dist > 3.2:
			var f2 := Vector2(forward.x, forward.z).normalized()
			var dot_val := f2.dot(to_en.normalized())
			if dot_val < (0.15 if step == 3 else 0.35):
				in_range = false
		if in_range:
			hit_count += 1
			var dmg := int(round(float(stats["atk"]) * skill_mult * step_mult * sakura_mult * (0.92 + randf() * 0.16)))
			var tag := crit_tag if step == 3 else base_tag
			var is_crit := (step == 3)

			# High-Ground Advantage (+15% damage when attacking from elevated terrain or mid-air!)
			if player.position.y > en.position.y + 0.70:
				dmg = int(round(float(dmg) * 1.15))
				if step != 3:
					tag = "⛰️高地斬"

			# Petrified Shatter Crit (Sakura synergy)
			if en.petrify_timer > 0.0:
				var stone_bonus := 1.35 + float(b["blessings"].get("stone_bonus", 0.0))
				dmg = int(round(float(dmg) * stone_bonus))
				tag = "🪨碎石暴擊!"
				is_crit = true
			elif (en.freeze_timer > 0.0 or en.stun_timer > 0.0) and float(b["blessings"].get("stone_bonus", 0.0)) > 0.0:
				dmg = int(round(float(dmg) * (1.0 + float(b["blessings"]["stone_bonus"]))))

			# Electro vulnerability bonus (Raijin synergy)
			if en.shock_timer > 0.0:
				dmg = int(round(float(dmg) * 1.20))

			# Per-Hero 3rd-Hit Signature Micro-Effect!
			if step == 3:
				match cid:
					"kickboxer":
						en.stun_timer = maxf(en.stun_timer, 0.85)
					"swordsman":
						en.burn_timer = maxf(en.burn_timer, 2.4)
					"raijin":
						en.shock_timer = maxf(en.shock_timer, 2.2)
					"yukionna":
						en.freeze_timer = maxf(en.freeze_timer, 1.45)

			if is_crit:
				any_crit = true

			var push_dir := en.position - player.position
			push_dir.y = 0.0
			if push_dir.length_squared() > 0.001:
				push_dir = push_dir.normalized()

			# Impact hit sparks, white flash, squash recoil & stagger
			var hit_pos := en.position + Vector3(0.0, 1.35 * en.scale.y, 0.0)
			spawn_hit_spark(hit_pos, vfx_color, is_crit, (1.22 if is_crit else 0.94) * clampf(trauma_mult, 0.85, 1.3))
			en.trigger_hit_react(push_dir, is_crit or step == 2 or cid == "kickboxer")

			var pop_color := Color.html("#fde047") if is_crit else Color.html(char_cfg["color_primary"]).lerp(Color.WHITE, 0.45)
			damage_enemy(en, dmg, tag, pop_color)

			# Hero-tuned Knockback (if still alive)
			if is_instance_valid(en) and not en.dead and push_dir.length_squared() > 0.001:
				var pre_kb := en.position
				var kb: float = (1.55 if is_crit else (0.72 if step == 2 else 0.48)) * kb_mult * (0.45 if en.is_boss else 1.0)
				en.position += push_dir * kb
				if arena != null:
					en.position = arena.resolve_obstacle_collision(en.position, 0.72 * en.scale.x)
					en.position = arena.resolve_terrain_step(pre_kb, en.position, true)
				en.clamp_to_arena()

	if hit_count > 0:
		hit_landed.emit(any_crit)
		if any_crit:
			AudioManager.play_sfx("impact_crit")
			_trigger_camera_impact(0.46 * trauma_mult, -3.2 * trauma_mult)
			trigger_hitstop(0.066 * hitstop_mult)
		elif step == 2 or hit_count >= 2:
			AudioManager.play_sfx("impact_heavy")
			_trigger_camera_impact(0.26 * trauma_mult, -1.5 * trauma_mult)
			trigger_hitstop(0.036 * hitstop_mult)
		else:
			AudioManager.play_sfx("impact_light")
			_trigger_camera_impact(0.17 * trauma_mult, -0.85 * trauma_mult)
			trigger_hitstop(0.025 * hitstop_mult)

		if player != null:
			player.trigger_hit_punch(any_crit or cid == "kickboxer")

		var bonus_sp := 3.5 if (cid == "sakura" and step == 3) else 0.0
		b["sp"] = minf(float(b["max_sp"]), float(b["sp"]) + 7.0 * float(hit_count) + bonus_sp)
		b["combo"] = int(b["combo"]) + hit_count
		b["combo_timer"] = 3.2

		var lifesteal: float = float(b["blessings"].get("lifesteal", 0.0))
		if lifesteal > 0.0:
			var heal := int(round(float(stats["atk"]) * lifesteal))
			b["hp"] = mini(int(b["max_hp"]), int(b["hp"]) + heal)

	hud_updated.emit()


func perform_jump() -> void:
	var b := GameState.battle
	if not b["active"] or b["paused"] or player == null:
		return
	var jump_mult: float = 1.30 if _wind_buff_timer > 0.0 else 1.0
	if player.trigger_jump(jump_mult):
		AudioManager.play_sfx("jump")
		var gy := _get_terrain_y(player.position.x, player.position.z, player.position.y)
		var ring_col := Color.html("#34d399") if _wind_buff_timer > 0.0 else Color.html("#fef3c7")
		spawn_ring_vfx(Vector3(player.position.x, gy, player.position.z), ring_col, 2.2, 0.24)


func perform_dash() -> void:
	var b := GameState.battle
	if not b["active"] or b["paused"] or float(b["dash_cooldown"]) > 0.0 or player == null:
		return
	if float(b["stamina"]) < DASH_STAMINA_COST:
		GameState.toast_requested.emit("💨 體力不足，無法快速衝刺！")
		return

	b["stamina"] = maxf(0.0, float(b["stamina"]) - DASH_STAMINA_COST)
	b["stamina_regen_delay"] = 0.60
	if float(b["stamina"]) <= 0.01:
		b["stamina_exhausted"] = true

	# Determine explosive dash direction: WASD input -> camera aim (if locked) -> current facing
	var move_in := _read_move_input()
	if move_in.length() > 0.05:
		var clamped := move_in / maxf(1.0, move_in.length())
		var yaw: float = camera_rig.cam_yaw if camera_rig != null else 0.0
		var wx := clamped.x * cos(yaw) + clamped.y * sin(yaw)
		var wz := -clamped.x * sin(yaw) + clamped.y * cos(yaw)
		_dash_dir = Vector3(wx, 0.0, wz).normalized()
		player.facing = atan2(_dash_dir.x, _dash_dir.z)
	else:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and camera_rig != null:
			player.facing = camera_rig.get_aim_facing()
		_dash_dir = Vector3(sin(player.facing), 0.0, cos(player.facing)).normalized()

	AudioManager.play_sfx("dash")
	var dash_lv: int = int(GameState.player["skills"].get("dash_skill", 1))
	b["dash_timer"] = 0.24
	b["invuln_timer"] = 0.45
	b["dash_cooldown"] = maxf(0.45, 1.05 - float(dash_lv - 1) * 0.05)
	spawn_ring_vfx(Vector3(player.position.x, 0.0, player.position.z), Color.html("#38bdf8"), 3.2, 0.32)
	_trigger_camera_impact(0.14, 2.6)
	hud_updated.emit()


func _read_move_input() -> Vector2:
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
	return move_input


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
		_trigger_camera_impact(0.22)
		GameState.toast_requested.emit("❌ 詠唱讀音錯誤，技能發動失敗！")
		return

	var cost: float = 70.0 if skill_type == "ult" else 30.0
	GameState.battle["sp"] = maxf(0.0, float(GameState.battle["sp"]) - cost)
	AudioManager.speak_japanese(String(word.get("kana", "")))
	AudioManager.play_sfx("skill")

	var crit_mult: float = 1.35 if is_typed_perfect else 1.0
	var stats := GameState.get_computed_stats()

	if skill_type == "ult":
		var ult_lv: int = int(GameState.player["skills"].get("ult_skill", 1))
		var ult_mult: float = 1.0 + float(ult_lv - 1) * 0.11
		var vfx_type: String = String(word.get("vfx", "sacred_halo"))
		var w_col := Color.html(String(word.get("color", "#fbbf24")))
		var w_icon: String = String(word.get("icon", "🌟"))
		var w_kanji: String = String(word.get("kanji", "言霊"))
		var w_label: String = String(word.get("vfx_label", "言霊奧義"))

		var archetype_dmg_mult := 1.0
		if vfx_type == "sword_rain":
			archetype_dmg_mult = 1.20
		elif vfx_type == "lightning":
			archetype_dmg_mult = 1.12

		var dmg := int(round(float(stats["atk"]) * 2.8 * ult_mult * crit_mult * archetype_dmg_mult))
		if player != null:
			spawn_kotodama_vfx(player.position, word, is_typed_perfect)
			spawn_ring_vfx(player.position, w_col, 18.0, 0.78)
		AudioManager.play_sfx("impact_crit")
		_trigger_camera_impact(0.82 if is_typed_perfect else 0.72, -5.8)
		trigger_hitstop(0.095)
		if player != null:
			player.trigger_hit_punch(true)

		# Apply self-buffs / healing archetypes
		var b := GameState.battle
		if vfx_type == "sakura_storm":
			var heal := int(round(float(b["max_hp"]) * 0.22))
			b["hp"] = mini(int(b["max_hp"]), int(b["hp"]) + heal)
			b["stamina"] = minf(float(b["max_stamina"]), float(b["stamina"]) + 45.0)
			if player != null:
				popup_requested.emit(player.position + Vector3(0.0, 2.7, 0.0), "%s +%d HP" % [w_icon, heal], Color.html("#f9a8d4"))
		elif vfx_type == "sacred_halo":
			var heal := int(round(float(b["max_hp"]) * 0.30))
			b["hp"] = mini(int(b["max_hp"]), int(b["hp"]) + heal)
			b["stamina"] = float(b["max_stamina"])
			b["sp"] = minf(100.0, float(b["sp"]) + 25.0)
			if player != null:
				popup_requested.emit(player.position + Vector3(0.0, 2.7, 0.0), "%s +%d HP / +25 SP" % [w_icon, heal], Color.html("#86efac"))
		elif vfx_type == "dragon_vortex":
			_wind_buff_timer = maxf(_wind_buff_timer, 5.0)
			if player != null:
				popup_requested.emit(player.position + Vector3(0.0, 2.7, 0.0), "%s 疾風加速 5s!" % w_icon, Color.html("#5eead4"))

		var ult_hit := false
		var ult_sparks := 0
		var dmg_tag := "%s%s!" % [w_icon, ("完美・" + w_kanji) if is_typed_perfect else w_kanji]
		for item in enemies.duplicate():
			if not is_instance_valid(item):
				continue
			var en := item as Enemy3D
			if en != null and not en.dead:
				ult_hit = true
				var push := en.position - player.position
				push.y = 0.0
				en.trigger_hit_react(push, true)
				match vfx_type:
					"meteor":
						en.burn_timer = maxf(en.burn_timer, 5.0)
					"lightning":
						en.shock_timer = maxf(en.shock_timer, 5.5)
					"blizzard":
						en.freeze_timer = maxf(en.freeze_timer, 4.0)
						en.frost_tick_timer = 0.55
					"dragon_vortex":
						en.stun_timer = maxf(en.stun_timer, 2.2)
						if push.length_squared() > 0.001:
							en.position += push.normalized() * (2.2 if en.is_boss else 5.0)
							en.clamp_to_arena()
					"earth_shatter":
						en.petrify_timer = maxf(en.petrify_timer, 4.0)
						if String(word.get("id", "")) == "phoenix":
							en.burn_timer = maxf(en.burn_timer, 4.5)
				if ult_sparks < 5:
					spawn_hit_spark(en.position + Vector3(0.0, 1.45 * en.scale.y, 0.0), w_col, true, 1.45)
					ult_sparks += 1
				damage_enemy(en, dmg, dmg_tag, w_col.lerp(Color.WHITE, 0.35))
		if ult_hit:
			hit_landed.emit(true)
		var perfect_prefix := "🌟 神速詠唱 1.35x！" if is_typed_perfect else ""
		GameState.toast_requested.emit("%s%s「%s」%s爆發！" % [perfect_prefix, w_icon, w_kanji, w_label])
	else:
		if player != null and not word.is_empty():
			spawn_kotodama_vfx(player.position, word, is_typed_perfect)
		_execute_signature_skill(stats, crit_mult)

	hud_updated.emit()


func _execute_signature_skill(stats: Dictionary, crit_mult: float) -> void:
	var char_cfg: Dictionary = GameData.get_character(GameState.player["char_id"])
	var sig_lv: int = int(GameState.player["skills"].get("sig_skill", 1))
	var sig_mult: float = 1.0 + float(sig_lv - 1) * 0.10
	var cid: String = char_cfg["id"]
	var any_hit: bool = false
	var sig_sparks: int = 0

	if cid == "sakura":
		var duration: float = 4.6 + float(sig_lv - 1) * 0.25
		var dmg := int(round(float(stats["atk"]) * 1.45 * sig_mult * crit_mult))
		spawn_ring_vfx(player.position, Color.html("#f472b6"), 13.0, 0.65)
		for en: Enemy3D in enemies.duplicate():
			if is_instance_valid(en) and not en.dead and en.position.distance_to(player.position) <= 13.5:
				any_hit = true
				en.petrify_timer = duration
				en.trigger_hit_react(en.position - player.position, true)
				if sig_sparks < 5:
					spawn_hit_spark(en.position + Vector3(0.0, 1.35 * en.scale.y, 0.0), Color.html("#f472b6"), true, 1.2)
					sig_sparks += 1
				damage_enemy(en, dmg, "🪨石化封印!", Color.html("#f9a8d4"))
		GameState.toast_requested.emit("🪨「石頭」石化魔眼！妖怪石化 %.1f 秒，快用「あ」碎石暴擊！" % duration)
	elif cid == "kickboxer":
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and camera_rig != null:
			player.facing = camera_rig.get_aim_facing()
		player.kick_anim_timer = 0.5
		var forward := Vector3(sin(player.facing), 0.0, cos(player.facing))
		var pre_rush := player.position
		player.position += forward * 4.0
		player.clamp_to_arena()
		if arena != null:
			player.position = arena.resolve_obstacle_collision(player.position, 0.62)
			player.position = arena.resolve_terrain_step(pre_rush, player.position, player.is_grounded)
		var dmg := int(round(float(stats["atk"]) * 2.35 * sig_mult * crit_mult))
		spawn_ring_vfx(player.position, Color.html("#38bdf8"), 9.5, 0.55)
		for en: Enemy3D in enemies.duplicate():
			if is_instance_valid(en) and not en.dead and en.position.distance_to(player.position) <= 9.5:
				any_hit = true
				en.stun_timer = 2.4
				var push := en.position - player.position
				push.y = 0.0
				en.trigger_hit_react(push, true)
				if sig_sparks < 5:
					spawn_hit_spark(en.position + Vector3(0.0, 1.35 * en.scale.y, 0.0), Color.html("#38bdf8"), true, 1.3)
					sig_sparks += 1
				if push.length_squared() > 0.001:
					var pre_ekb := en.position
					en.position += push.normalized() * (2.2 if en.is_boss else 4.5)
					if arena != null:
						en.position = arena.resolve_obstacle_collision(en.position, 0.72 * en.scale.x)
						en.position = arena.resolve_terrain_step(pre_ekb, en.position, true)
					en.clamp_to_arena()
				damage_enemy(en, dmg, "🦶超烈風神腳!", Color.html("#7dd3fc"))
		GameState.toast_requested.emit("🦶「腳」超烈風神腳！轟飛並暈眩周圍妖怪！")
	elif cid == "raijin":
		var dmg := int(round(float(stats["atk"]) * 2.15 * sig_mult * crit_mult))
		spawn_ring_vfx(player.position, Color.html("#facc15"), 12.0, 0.60)
		for en: Enemy3D in enemies.duplicate():
			if is_instance_valid(en) and not en.dead and en.position.distance_to(player.position) <= 12.0:
				any_hit = true
				en.shock_timer = 4.6
				en.trigger_hit_react(en.position - player.position, true)
				if sig_sparks < 5:
					spawn_hit_spark(en.position + Vector3(0.0, 1.35 * en.scale.y, 0.0), Color.html("#facc15"), true, 1.25)
					sig_sparks += 1
				damage_enemy(en, dmg, "⚡九天雷鳴!", Color.html("#fef08a"))
		GameState.toast_requested.emit("⚡「雷光」九天雷鳴陣！妖怪陷入感電易傷狀態！")
	elif cid == "yukionna":
		var dmg := int(round(float(stats["atk"]) * 1.90 * sig_mult * crit_mult))
		spawn_ring_vfx(player.position, Color.html("#06b6d4"), 12.5, 0.65)
		for en: Enemy3D in enemies.duplicate():
			if is_instance_valid(en) and not en.dead and en.position.distance_to(player.position) <= 12.5:
				any_hit = true
				en.freeze_timer = 4.2
				en.frost_tick_timer = 0.6
				en.trigger_hit_react(en.position - player.position, true)
				if sig_sparks < 5:
					spawn_hit_spark(en.position + Vector3(0.0, 1.35 * en.scale.y, 0.0), Color.html("#67e8f9"), true, 1.2)
					sig_sparks += 1
				damage_enemy(en, dmg, "❄️絶対零度!", Color.html("#67e8f9"))
		GameState.toast_requested.emit("❄️「冰結」絶対零度氷華！凍結周圍妖怪！")
	else:
		var dmg := int(round(float(stats["atk"]) * 2.25 * sig_mult * crit_mult))
		spawn_ring_vfx(player.position, Color.html("#ef4444"), 10.5, 0.60)
		for en: Enemy3D in enemies.duplicate():
			if is_instance_valid(en) and not en.dead and en.position.distance_to(player.position) <= 10.5:
				any_hit = true
				en.burn_timer = 4.0
				en.trigger_hit_react(en.position - player.position, true)
				if sig_sparks < 5:
					spawn_hit_spark(en.position + Vector3(0.0, 1.35 * en.scale.y, 0.0), Color.html("#ef4444"), true, 1.3)
					sig_sparks += 1
				damage_enemy(en, dmg, "🔥紅蓮烈焰!", Color.html("#fca5a5"))
		GameState.toast_requested.emit("🔥「火炎斬」紅蓮烈焰斬爆發！")

	if any_hit:
		hit_landed.emit(true)
		AudioManager.play_sfx("impact_crit")
		_trigger_camera_impact(0.56, -3.8)
		trigger_hitstop(0.072)
		if player != null:
			player.trigger_hit_punch(true)
	else:
		_trigger_camera_impact(0.24, -1.5)


func damage_enemy(en: Enemy3D, dmg: int, tag: String, color: Color = Color.WHITE) -> void:
	if not is_instance_valid(en) or en.dead:
		return
	en.hp -= dmg
	popup_requested.emit(en.position + Vector3(0.0, 2.2, 0.0), "%s -%d" % [tag, dmg], color)

	if en.hp <= 0:
		var death_pos := en.position + Vector3(0.0, 1.15 * en.scale.y, 0.0)
		var death_col := en.primary_color
		var was_boss := en.is_boss
		en.dead = true
		enemies.erase(en)
		en.queue_free()

		# Explosive Yokai spirit-shatter VFX + audio + boss finisher impact!
		spawn_death_burst(death_pos, death_col, was_boss)
		spawn_ring_vfx(Vector3(death_pos.x, 0.0, death_pos.z), death_col, 7.5 if was_boss else 3.2, 0.55 if was_boss else 0.30)
		AudioManager.play_sfx("boss_die" if was_boss else "enemy_die")
		if was_boss:
			_trigger_camera_impact(0.85, -5.2)
			trigger_hitstop(0.10)
		else:
			_trigger_camera_impact(0.18)

		GameState.player["total_kills"] = int(GameState.player["total_kills"]) + 1

		var mode_mult: float = 2.0 if GameState.player["mode"] == "hard_endless" else (1.5 if GameState.is_hard_mode() else 1.0)
		var neko_bonus: float = 1.2 if GameState.player["active_shikigami"] == "neko" else 1.0
		var gold_gain := int(round((120.0 if was_boss else 18.0) * mode_mult * neko_bonus))
		var exp_gain := int(round((160.0 if was_boss else 26.0) * mode_mult))

		GameState.player["gold"] = int(GameState.player["gold"]) + gold_gain
		GameState.grant_exp(exp_gain)
		# Debounce IndexedDB save writes to avoid mid-combat frame & WebAudio stalls
		_save_dirty = true


func damage_player(dmg: int) -> void:
	var b := GameState.battle
	if float(b["invuln_timer"]) > 0.0:
		return
	b["invuln_timer"] = 0.65
	b["hp"] = maxi(0, int(b["hp"]) - dmg)
	AudioManager.play_sfx("hit")
	_trigger_camera_impact(0.42, 2.4)
	if player != null:
		spawn_hit_spark(player.position + Vector3(0.0, 1.35, 0.0), Color.html("#f43f5e"), false, 0.95)
		popup_requested.emit(player.position + Vector3(0.0, 2.2, 0.0), "-%d" % dmg, Color.html("#f43f5e"))

	if int(b["hp"]) <= 0:
		b["active"] = false
		b["paused"] = true
		if _save_dirty:
			_save_dirty = false
			GameState.save_game_data()
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
		_move_vel = Vector3.ZERO
		if player != null:
			player.update_animations(dt, false)
		return

	# Crisp action-RPG hitstop freeze frames (CameraRig keeps shaking smoothly!)
	if _hitstop_timer > 0.0:
		_hitstop_timer = maxf(0.0, _hitstop_timer - dt)
		return

	# Timers & cooldowns
	b["atk_cooldown"] = maxf(0.0, float(b["atk_cooldown"]) - dt)
	b["dash_cooldown"] = maxf(0.0, float(b["dash_cooldown"]) - dt)
	b["dash_timer"] = maxf(0.0, float(b["dash_timer"]) - dt)
	b["invuln_timer"] = maxf(0.0, float(b["invuln_timer"]) - dt)
	if _shift_tap_window > 0.0:
		_shift_tap_window = maxf(0.0, _shift_tap_window - dt)

	# Sync max stamina with dash_skill level
	var dash_lv_now: int = int(GameState.player["skills"].get("dash_skill", 1))
	var max_sta: float = 100.0 + float(dash_lv_now - 1) * 10.0
	b["max_stamina"] = max_sta

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

	# Movement input (camera-aligned) + Shift Sprint + Double-Tap Shift Quick Dash + Stamina
	var move_input := _read_move_input()
	var focus_owner := get_viewport().gui_get_focus_owner()
	var wants_sprint: bool = (not (focus_owner is LineEdit or focus_owner is TextEdit)) and Input.is_action_pressed("sprint")

	var stats := GameState.get_computed_stats()
	var is_moving := move_input.length() > 0.05
	var is_dashing := float(b["dash_timer"]) > 0.0
	var is_sprinting := false
	var prev_player_pos: Vector3 = player.position if player != null else Vector3.ZERO

	if is_dashing:
		# High-speed directional burst even from standstill
		b["is_sprinting"] = true
		is_sprinting = true
		if player != null:
			var dvec := _dash_dir if _dash_dir.length_squared() > 0.001 else Vector3(sin(player.facing), 0.0, cos(player.facing))
			_move_vel = dvec * float(stats["speed"]) * 2.85
			player.position.x += _move_vel.x * dt
			player.position.z += _move_vel.z * dt
			player.clamp_to_arena()
	else:
		var has_wind: bool = _wind_buff_timer > 0.0
		if wants_sprint and is_moving and (has_wind or ((not bool(b["stamina_exhausted"])) and float(b["stamina"]) > 0.0)):
			is_sprinting = true
			b["is_sprinting"] = true
			if not has_wind:
				b["stamina"] = maxf(0.0, float(b["stamina"]) - SPRINT_DRAIN_PER_SEC * dt)
				b["stamina_regen_delay"] = 0.55
				if float(b["stamina"]) <= 0.01:
					b["stamina"] = 0.0
					b["stamina_exhausted"] = true
					is_sprinting = false
					b["is_sprinting"] = false
		else:
			b["is_sprinting"] = false
			if float(b["stamina_regen_delay"]) > 0.0:
				b["stamina_regen_delay"] = maxf(0.0, float(b["stamina_regen_delay"]) - dt)
			else:
				b["stamina"] = minf(max_sta, float(b["stamina"]) + STAMINA_REGEN_PER_SEC * dt)
				if bool(b["stamina_exhausted"]) and float(b["stamina"]) >= max_sta * 0.22:
					b["stamina_exhausted"] = false

		var target_vel := Vector3.ZERO
		if is_moving and player != null:
			var clamped := move_input / maxf(1.0, move_input.length())
			var yaw: float = camera_rig.cam_yaw if camera_rig != null else 0.0
			var sin_y := sin(yaw)
			var cos_y := cos(yaw)
			var world_dx := clamped.x * cos_y + clamped.y * sin_y
			var world_dz := -clamped.x * sin_y + clamped.y * cos_y

			var speed_mult: float = (1.58 if is_sprinting else 1.0) * (1.40 if has_wind else 1.0)
			target_vel = Vector3(world_dx, 0.0, world_dz) * float(stats["speed"]) * speed_mult
			player.facing = atan2(world_dx, world_dz)

		if player != null:
			var accel_rate: float = 18.0 if is_moving else 22.0
			_move_vel = _move_vel.lerp(target_vel, 1.0 - exp(-accel_rate * dt))
			if _move_vel.length_squared() > 0.01:
				player.position.x += _move_vel.x * dt
				player.position.z += _move_vel.z * dt
				player.clamp_to_arena()
			else:
				_move_vel = Vector3.ZERO

	if player != null:
		if arena != null:
			player.position = arena.resolve_obstacle_collision(player.position, 0.62)
			player.position = arena.resolve_terrain_step(prev_player_pos, player.position, player.is_grounded)
		var player_gy := _get_terrain_y(player.position.x, player.position.z, player.position.y)
		var player_ceil: float = arena.get_ceiling_height(player.position.x, player.position.z, player.position.y) if arena != null else 999.0
		var landed := player.update_vertical_physics(dt, player_gy, player_ceil)
		if landed:
			AudioManager.play_sfx("land")
			spawn_ring_vfx(Vector3(player.position.x, player_gy, player.position.z), Color.html("#e2e8f0"), 1.6, 0.20)
		player.update_animations(dt, is_moving or is_dashing or _move_vel.length_squared() > 0.35, is_sprinting)

	# Update Stage-Specific Map Mechanics (Sakura Sanctuary / Maple Wind / Lava Geysers / Sky Jump Pads & Thunder)
	_update_stage_mechanics(dt, stats)

	# Shikigami Companion Follow & Auto-Support
	if shikigami != null and shikigami.visible and player != null:
		shikigami.update_follow(dt, player.position, player.facing)
		b["shikigami_timer"] = float(b["shikigami_timer"]) + dt
		var active_sh: String = GameState.player.get("active_shikigami", "none")
		if active_sh == "kitsune" and float(b["shikigami_timer"]) >= 2.5 and not enemies.is_empty():
			b["shikigami_timer"] = 0.0
			var target := _find_nearest_enemy()
			if target != null:
				target.trigger_hit_react(target.position - player.position, false)
				spawn_hit_spark(target.position + Vector3(0.0, 1.2 * target.scale.y, 0.0), Color.html("#f97316"), false, 0.75)
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
				target.trigger_hit_react(target.position - player.position, false)
				spawn_hit_spark(target.position + Vector3(0.0, 1.2 * target.scale.y, 0.0), Color.html("#38bdf8"), false, 0.75)
				damage_enemy(target, int(round(float(stats["atk"]) * 0.90)), "🐺雷撃", Color.html("#38bdf8"))
				b["sp"] = minf(float(b["max_sp"]), float(b["sp"]) + 4.0)

	# Enemy AI, Terrain Grounding & Status Effects
	for item in enemies.duplicate():
		if not is_instance_valid(item):
			continue
		var en := item as Enemy3D
		if en == null or en.dead:
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
		var en_gy := _get_terrain_y(en.position.x, en.position.z, en.position.y)
		en.position.y = lerpf(en.position.y, en_gy, clampf(dt * 14.0, 0.0, 1.0))

		if en.is_controlled() or en.is_staggered():
			continue

		var to_player := player.position - en.position
		var to_player_flat := Vector3(to_player.x, 0.0, to_player.z)
		var dist := to_player_flat.length()
		if dist > 0.1:
			en.rotation.y = atan2(to_player_flat.x, to_player_flat.z)

		var stop_dist: float = 8.5 if en.ranged else (1.55 + 0.35 * en.scale.x)
		if dist > stop_dist and dist > 0.001:
			var prev_en_pos := en.position
			en.position += to_player_flat.normalized() * en.move_speed * dt
			if arena != null:
				en.position = arena.resolve_obstacle_collision(en.position, 0.72 * en.scale.x)
				en.position = arena.resolve_terrain_step(prev_en_pos, en.position, true)
			en.clamp_to_arena()
			en.position.y = lerpf(en.position.y, _get_terrain_y(en.position.x, en.position.z, en.position.y), clampf(dt * 14.0, 0.0, 1.0))

		en.atk_timer -= dt
		if en.atk_timer <= 0.0:
			if dist <= 2.3 and absf(player.position.y - en.position.y) < 1.45:
				en.atk_timer = 1.4
				damage_player(en.atk)
			elif en.ranged and dist <= 22.0 and dist > 0.001:
				en.atk_timer = 2.4
				var aim_3d := ((player.position + Vector3(0.0, 1.0, 0.0)) - (en.position + Vector3(0.0, 1.2, 0.0))).normalized()
				_spawn_enemy_projectile(en.position, aim_3d, en.atk)

	# Prune dead enemies
	var alive: Array[Enemy3D] = []
	for en in enemies:
		if is_instance_valid(en) and not en.dead:
			alive.append(en)
	enemies = alive

	# Soft entity-vs-entity & player-vs-enemy body separation to eliminate character clipping
	var en_count := enemies.size()
	for i in range(en_count):
		var ea := enemies[i]
		# Separate from player horizontally when on same elevation band
		if player != null and absf(ea.position.y - player.position.y) < 1.85:
			var min_p := 0.62 + 0.62 * ea.scale.x
			var diff_p := Vector2(ea.position.x - player.position.x, ea.position.z - player.position.z)
			var dp_sq := diff_p.length_squared()
			if dp_sq < min_p * min_p:
				var dp := sqrt(dp_sq)
				var sep_dir := (diff_p / dp) if dp > 0.001 else Vector2(1.0, 0.0)
				var push_amt := (min_p - dp)
				ea.position.x += sep_dir.x * push_amt
				ea.position.z += sep_dir.y * push_amt
				if arena != null:
					ea.position = arena.resolve_obstacle_collision(ea.position, 0.72 * ea.scale.x)
				ea.clamp_to_arena()
		# Separate from other enemies
		for j in range(i + 1, en_count):
			var eb := enemies[j]
			if absf(ea.position.y - eb.position.y) >= 1.85:
				continue
			var min_e := 0.58 * (ea.scale.x + eb.scale.x)
			var diff_e := Vector2(eb.position.x - ea.position.x, eb.position.z - ea.position.z)
			var de_sq := diff_e.length_squared()
			if de_sq < min_e * min_e:
				var de := sqrt(de_sq)
				var sdir := (diff_e / de) if de > 0.001 else Vector2(1.0, 0.0)
				var half_push := (min_e - de) * 0.5
				ea.position.x -= sdir.x * half_push
				ea.position.z -= sdir.y * half_push
				eb.position.x += sdir.x * half_push
				eb.position.z += sdir.y * half_push

	# Update Enemy Projectiles (3D height check lets jumping clear low projectiles!)
	var alive_proj: Array[EnemyProjectile3D] = []
	for pr in projectiles:
		if not is_instance_valid(pr):
			continue
		pr.life -= dt
		pr.position += pr.direction * 9.5 * dt
		if pr.position.distance_to(player.position + Vector3(0.0, 1.2, 0.0)) < 1.15:
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
		if _save_dirty:
			_save_dirty = false
			_save_flush_timer = 0.0
			GameState.save_game_data()
		if not GameState.is_endless_mode() and int(b["wave"]) >= 12:
			GameState.toast_requested.emit("👑 恭喜通關全 12 幕！獲得通關大賞 500 金幣！")
			GameState.player["gold"] = int(GameState.player["gold"]) + 500
			GameState.save_game_data()
			b["active"] = false
			b["paused"] = true
			hud_updated.emit()
			battle_ended.emit(true, int(b["wave"]))
		else:
			b["paused"] = true
			hud_updated.emit()
			wave_cleared.emit()
		return

	# Periodic debounced save flush (every 8s if kills occurred)
	if _save_dirty:
		_save_flush_timer += dt
		if _save_flush_timer >= 8.0:
			_save_dirty = false
			_save_flush_timer = 0.0
			GameState.save_game_data()

	# Throttle routine HUD sync to ~12 Hz to avoid per-frame CJK text shaping stutter on WebGL
	_hud_sync_acc += dt
	if _hud_sync_acc >= 0.08:
		_hud_sync_acc = 0.0
		hud_updated.emit()


# ==============================================================================
#  FOUR UNIQUE STAGE MECHANICS
# ==============================================================================
func _update_stage_mechanics(dt: float, stats: Dictionary) -> void:
	if arena == null or player == null:
		return
	var b := GameState.battle
	var sid := arena.current_stage_id
	_in_sakura_buff = false
	if _wind_buff_timer > 0.0:
		_wind_buff_timer = maxf(0.0, _wind_buff_timer - dt)
	if _jump_pad_cooldown > 0.0:
		_jump_pad_cooldown = maxf(0.0, _jump_pad_cooldown - dt)

	match sid:
		"sakura_shrine":
			_sakura_cycle_timer += dt
			if _sakura_cycle_timer >= 12.0:
				_sakura_cycle_timer = 0.0
				var np := arena.cycle_sakura_zone()
				spawn_ring_vfx(np, Color.html("#f472b6"), 5.5, 0.50)
				GameState.toast_requested.emit("🌸 櫻花靈陣轉移至新神壇高台！")

			var d := Vector2(player.position.x - arena.sakura_zone_pos.x, player.position.z - arena.sakura_zone_pos.z).length()
			if d <= arena.sakura_zone_radius:
				_in_sakura_buff = true
				b["sp"] = minf(float(b["max_sp"]), float(b["sp"]) + 10.0 * dt)
				b["stamina"] = minf(float(b["max_stamina"]), float(b["stamina"]) + 45.0 * dt)
				b["stamina_exhausted"] = false
				_sakura_heal_acc += float(b["max_hp"]) * 0.05 * dt
				if _sakura_heal_acc >= 2.0:
					var h_amt := int(floor(_sakura_heal_acc))
					_sakura_heal_acc -= float(h_amt)
					if int(b["hp"]) < int(b["max_hp"]):
						b["hp"] = mini(int(b["max_hp"]), int(b["hp"]) + h_amt)
				b["stage_status"] = "🌸 靈櫻加護中！攻擊 +25%・高速回復"
			else:
				b["stage_status"] = "🌸 尋訪發光櫻花靈陣獲得回復與增傷"

		"maple_temple":
			for wz in arena.wind_zones:
				var wp: Vector3 = wz["pos"]
				var wr: float = float(wz["radius"])
				if Vector2(player.position.x - wp.x, player.position.z - wp.z).length() <= wr:
					if _wind_buff_timer < 3.6:
						AudioManager.play_sfx("dash")
						spawn_ring_vfx(wp, Color.html("#34d399"), 4.2, 0.35)
					_wind_buff_timer = 4.8
					b["stamina"] = minf(float(b["max_stamina"]), float(b["stamina"]) + 35.0 * dt)
					b["stamina_exhausted"] = false
					break
			if _wind_buff_timer > 0.0:
				b["stage_status"] = "🍃 疾風祝福 %.1fs（加速＋無限急跑＋高跳）" % _wind_buff_timer
			else:
				b["stage_status"] = "🍃 踏入翠綠風場啟動疾風加速與高跳"

		"onigashima_lava":
			# 1. Lava Trench Ground Burn (jump over trenches or stay on obsidian plateaus!)
			if arena.is_in_lava(player.position.x, player.position.z, player.position.y):
				_lava_tick_timer += dt
				if _lava_tick_timer >= 0.75:
					_lava_tick_timer = 0.0
					damage_player(maxi(5, int(round(float(b["max_hp"]) * 0.06))))
					popup_requested.emit(player.position + Vector3(0.0, 2.4, 0.0), "🌋岩漿灼燒!", Color.html("#fb923c"))
			else:
				_lava_tick_timer = 0.35

			_enemy_lava_timer += dt
			if _enemy_lava_timer >= 0.90:
				_enemy_lava_timer = 0.0
				for item in enemies.duplicate():
					if not is_instance_valid(item):
						continue
					var en := item as Enemy3D
					if en != null and not en.dead and arena.is_in_lava(en.position.x, en.position.z, en.position.y):
						damage_enemy(en, maxi(6, int(round(float(stats["atk"]) * 0.35))), "🌋地火灼燒", Color.html("#fb923c"))

			# 2. Periodic Volcanic Geyser Eruptions (telegraphed AoE that hurts both player & lured monsters!)
			_hazard_spawn_timer -= dt
			if _hazard_spawn_timer <= 0.0:
				_hazard_spawn_timer = 6.5
				_spawn_stage_hazards("lava_geyser", 3, 3.6, 1.65)
			_update_stage_hazards(dt, stats)
			b["stage_status"] = "🌋 熔岩噴發預警！跳躍閃避或引怪入陣" if not _stage_hazards.is_empty() else "🌋 佔領黑曜高台・跳過發光熔岩裂谷"

		"sky_tenshu":
			# 1. Cloud Jump Pads launching hero onto Floating Golden Sky Platforms!
			if _jump_pad_cooldown <= 0.0:
				for jp in arena.jump_pads:
					var jpos: Vector3 = jp["pos"]
					var jrad: float = float(jp["radius"])
					if Vector2(player.position.x - jpos.x, player.position.z - jpos.z).length() <= jrad and absf(player.position.y - jpos.y) < 1.1:
						_jump_pad_cooldown = 0.75
						player.launch_upward(16.8)
						AudioManager.play_sfx("jump")
						AudioManager.play_sfx("dash")
						spawn_ring_vfx(jpos, Color.html("#38bdf8"), 4.2, 0.38)
						_trigger_camera_impact(0.14, 2.2)
						popup_requested.emit(player.position + Vector3(0.0, 2.2, 0.0), "⚡騰雲躍昇!", Color.html("#7dd3fc"))
						break

			# 2. Full-Moon Thunder Strikes (telegraphed sky lightning that shocks monsters!)
			_hazard_spawn_timer -= dt
			if _hazard_spawn_timer <= 0.0:
				_hazard_spawn_timer = 7.0
				_spawn_stage_hazards("sky_thunder", 3, 3.5, 1.55)
			_update_stage_hazards(dt, stats)
			if not _stage_hazards.is_empty():
				b["stage_status"] = "⚡ 滿月天雷降臨！閃避雷圈並引雷劈怪"
			elif player.position.y > 1.8:
				b["stage_status"] = "⚡ 雲海高地制壓中（高地斬 +20% 傷害）"
			else:
				b["stage_status"] = "⚡ 踏上藍金騰雲陣躍升懸浮天守高台"


func _spawn_stage_hazards(kind: String, count: int, rad: float, delay: float) -> void:
	if vfx_root == null or player == null:
		return
	var col := Color.html("#f97316") if kind == "lava_geyser" else Color.html("#38bdf8")
	for i in range(count):
		var hx := 0.0
		var hz := 0.0
		if i == 0:
			# First zone targets near player (giving clear telegraph time to jump/dash!)
			var a := randf() * TAU
			var d := randf() * 3.5
			hx = player.position.x + cos(a) * d
			hz = player.position.z + sin(a) * d
		elif i == 1 and not enemies.is_empty():
			# Second zone targets near an enemy cluster for tactical synergy!
			var target_en := _find_nearest_enemy()
			if target_en != null:
				hx = target_en.position.x + randf_range(-2.0, 2.0)
				hz = target_en.position.z + randf_range(-2.0, 2.0)
		else:
			var a := randf() * TAU
			var d := 5.0 + randf() * (GameData.ARENA_RADIUS - 8.0)
			hx = cos(a) * d
			hz = sin(a) * d

		var flat := Vector2(hx, hz)
		if flat.length() > GameData.ARENA_RADIUS - 3.0:
			flat = flat.normalized() * (GameData.ARENA_RADIUS - 3.0)
		var hy := _get_terrain_y(flat.x, flat.y)
		var pos := Vector3(flat.x, hy, flat.y)

		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = rad - 0.35
		torus.outer_radius = rad
		torus.rings = 22
		torus.ring_segments = 6
		ring.mesh = torus
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(col.r, col.g, col.b, 0.78)
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		ring.material_override = mat
		ring.position = pos + Vector3(0.0, 0.16, 0.0)
		ring.scale = Vector3(1.0, 0.08, 1.0)
		vfx_root.add_child(ring)

		_stage_hazards.append({
			"pos": pos,
			"radius": rad,
			"timer": delay,
			"max_time": delay,
			"kind": kind,
			"node": ring,
			"mat": mat,
		})


func _update_stage_hazards(dt: float, stats: Dictionary) -> void:
	if _stage_hazards.is_empty():
		return
	var remain: Array[Dictionary] = []
	for hz in _stage_hazards:
		hz["timer"] = float(hz["timer"]) - dt
		var t_left: float = float(hz["timer"])
		var max_t: float = maxf(0.01, float(hz["max_time"]))
		var node: MeshInstance3D = hz["node"]
		var mat: StandardMaterial3D = hz["mat"]
		var p: float = 1.0 - clampf(t_left / max_t, 0.0, 1.0)

		if is_instance_valid(node) and mat != null:
			var pulse := 0.88 + 0.14 * sin(p * 24.0)
			node.scale = Vector3(pulse, 0.08, pulse)
			mat.albedo_color.a = 0.45 + p * 0.50

		if t_left <= 0.0:
			var pos: Vector3 = hz["pos"]
			var rad: float = float(hz["radius"])
			var kind: String = String(hz["kind"])
			if is_instance_valid(node):
				node.queue_free()
			_detonate_stage_hazard(pos, rad, kind, stats)
		else:
			remain.append(hz)
	_stage_hazards = remain


func _detonate_stage_hazard(pos: Vector3, rad: float, kind: String, stats: Dictionary) -> void:
	var is_lava := (kind == "lava_geyser")
	var col := Color.html("#f97316") if is_lava else Color.html("#38bdf8")
	spawn_ring_vfx(pos, col, rad * 1.45, 0.42)
	spawn_hit_spark(pos + Vector3(0.0, 1.4, 0.0), col, true, 1.45)
	AudioManager.play_sfx("impact_heavy")
	_trigger_camera_impact(0.32, -1.6)

	# Player check (can safely jump high above ground geyser or dash out!)
	if player != null:
		var pd := Vector2(player.position.x - pos.x, player.position.z - pos.z).length()
		var vertical_ok := (player.position.y < pos.y + 1.65) if is_lava else true
		if pd <= rad and vertical_ok:
			damage_player(maxi(10, int(round(float(GameState.battle["max_hp"]) * 0.11))))

	# Tactical monster damage! Luring monsters into Lava Geysers or Moon Thunder blasts them!
	var hazard_dmg := int(round(float(stats["atk"]) * 1.85))
	for item in enemies.duplicate():
		if not is_instance_valid(item):
			continue
		var en := item as Enemy3D
		if en == null or en.dead:
			continue
		var ed := Vector2(en.position.x - pos.x, en.position.z - pos.z).length()
		if ed <= rad + 0.8:
			en.trigger_hit_react(en.position - pos, true)
			if is_lava:
				en.burn_timer = maxf(en.burn_timer, 4.0)
				damage_enemy(en, hazard_dmg, "🌋地火噴發!", Color.html("#fb923c"))
			else:
				en.shock_timer = maxf(en.shock_timer, 5.0)
				damage_enemy(en, hazard_dmg, "⚡滿月天雷!", Color.html("#7dd3fc"))


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
