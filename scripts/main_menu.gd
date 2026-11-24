extends Control
## Standalone Main Menu scene: handles name, character, stage, mode selection,
## pre-battle upgrades, fullscreen landscape lock, and loads the 3D Game scene on start.

const GAME_SCENE_PATH: String = "res://scenes/game.tscn"

var _name_input: LineEdit
var _stats_badge_lbl: Label
var _audio_btn: Button
var _char_grid: GridContainer
var _stage_grid: GridContainer
var _mode_grid: GridContainer
var _upgrade_modal: UpgradeModal
var _loading_overlay: Control
var _toast_panel: PanelContainer
var _toast_lbl: Label
var _toast_timer: float = 0.0
var _is_loading_game: bool = false


func _ready() -> void:
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	GameState.reset_battle_state()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	GameState.state_changed.connect(refresh)
	GameState.toast_requested.connect(_show_toast)
	AudioManager.audio_toggled.connect(func(_on: bool) -> void: _update_audio_btn())
	refresh()


func _build_ui() -> void:
	var is_mob := UiStyle.is_mobile_device()

	# Night Sakura Backdrop
	var bg := ColorRect.new()
	bg.color = Color.html("#090d16")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Subtle Torii Crimson Horizon Glow
	var glow := ColorRect.new()
	glow.color = Color(0.55, 0.08, 0.22, 0.20)
	glow.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	glow.offset_top = -260
	add_child(glow)

	# Lightweight 2D Sakura Petals
	var petals := CPUParticles2D.new()
	petals.position = Vector2(640, -20)
	petals.amount = 48
	petals.lifetime = 9.0
	petals.preprocess = 4.0
	petals.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	petals.emission_rect_extents = Vector2(900, 10)
	petals.direction = Vector2(0.25, 1.0)
	petals.spread = 18.0
	petals.gravity = Vector2(12, 16)
	petals.initial_velocity_min = 45.0
	petals.initial_velocity_max = 95.0
	petals.scale_amount_min = 4.0
	petals.scale_amount_max = 8.0
	petals.color = Color(0.98, 0.65, 0.82, 0.68)
	add_child(petals)

	# Outer Container: Full-screen on mobile, centered card on desktop
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var m_side := 12 if is_mob else 24
	var m_vert := 10 if is_mob else 18
	margin.add_theme_constant_override("margin_left", m_side)
	margin.add_theme_constant_override("margin_right", m_side)
	margin.add_theme_constant_override("margin_top", m_vert)
	margin.add_theme_constant_override("margin_bottom", m_vert)
	add_child(margin)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override(
		"panel",
		UiStyle.make_panel("#0f172a", 0.92, "#fbbf24", 0.65, 22, 2, 24 if is_mob else 24, 18)
	)
	if is_mob:
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
		margin.add_child(panel)
	else:
		var center := CenterContainer.new()
		center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		center.size_flags_vertical = Control.SIZE_EXPAND_FILL
		margin.add_child(center)
		panel.custom_minimum_size = Vector2(960, 640)
		center.add_child(panel)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 18 if is_mob else 14)
	scroll.add_child(vbox)

	# ==================== HEADER ====================
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	vbox.add_child(header)

	var title_box := VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_box)

	var ver_lbl := Label.new()
	ver_lbl.text = "Ver 2.0 資料片｜百鬼夜行・新角色與新關卡（Godot 4.3 主選單）"
	ver_lbl.add_theme_font_size_override("font_size", 16 if is_mob else 12)
	ver_lbl.add_theme_color_override("font_color", Color.html("#fda4af"))
	title_box.add_child(ver_lbl)

	var main_title := Label.new()
	main_title.text = "⛩️ 言霊剣士・あの一撃 3D"
	main_title.add_theme_font_size_override("font_size", 36 if is_mob else 28)
	main_title.add_theme_color_override("font_color", Color.html("#fcd34d"))
	title_box.add_child(main_title)

	# Player Stats + Quick Prep Buttons
	var header_right := HBoxContainer.new()
	header_right.add_theme_constant_override("separation", 10 if is_mob else 8)
	header.add_child(header_right)

	var stat_panel := PanelContainer.new()
	stat_panel.add_theme_stylebox_override("panel", UiStyle.make_panel("#1e293b", 0.95, "#fbbf24", 0.45, 12, 1, 14, 8))
	_stats_badge_lbl = Label.new()
	_stats_badge_lbl.add_theme_font_size_override("font_size", 18 if is_mob else 13)
	_stats_badge_lbl.add_theme_color_override("font_color", Color.html("#fde68a"))
	stat_panel.add_child(_stats_badge_lbl)
	header_right.add_child(stat_panel)

	var btn_h := 58 if is_mob else 38
	var btn_fs := 19 if is_mob else 13
	for item in [
		["⚡ 技能", "#fbbf24", "#fcd34d", "skills"],
		["🎒 裝備", "#34d399", "#6ee7b7", "equip"],
		["🦊 式神", "#f472b6", "#f9a8d4", "shikigami"],
	]:
		var b := Button.new()
		b.text = item[0]
		b.custom_minimum_size = Vector2(110 if is_mob else 74, btn_h)
		b.add_theme_font_size_override("font_size", btn_fs)
		UiStyle.apply_button(b, "#1e293b", item[1], item[2], 12, 2 if is_mob else 1, 0.95)
		var tab_id: String = item[3]
		b.pressed.connect(func() -> void: _upgrade_modal.open_modal(tab_id))
		header_right.add_child(b)

	if is_mob:
		var fs_btn := Button.new()
		fs_btn.text = "📱 橫向全螢幕"
		fs_btn.custom_minimum_size = Vector2(150, btn_h)
		fs_btn.add_theme_font_size_override("font_size", 18)
		UiStyle.apply_button(fs_btn, "#0c4a6e", "#38bdf8", "#e0f2fe", 12, 2, 0.95)
		fs_btn.pressed.connect(func() -> void: UiStyle.request_mobile_landscape_fullscreen())
		header_right.add_child(fs_btn)

	_audio_btn = Button.new()
	_audio_btn.custom_minimum_size = Vector2(64 if is_mob else 44, btn_h)
	_audio_btn.add_theme_font_size_override("font_size", 22 if is_mob else 15)
	UiStyle.apply_button(_audio_btn, "#1e293b", "#94a3b8", "#ffffff", 12, 2 if is_mob else 1, 0.95)
	_audio_btn.pressed.connect(func() -> void: AudioManager.toggle_audio())
	header_right.add_child(_audio_btn)
	_update_audio_btn()

	# ==================== CUSTOM NAME BAR ====================
	var name_panel := PanelContainer.new()
	name_panel.add_theme_stylebox_override("panel", UiStyle.make_panel("#0b1120", 0.92, "#334155", 0.9, 14, 1, 16, 12))
	vbox.add_child(name_panel)

	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 12)
	name_panel.add_child(name_row)

	var name_lbl := Label.new()
	name_lbl.text = "🏷️ 自訂角色名稱："
	name_lbl.add_theme_font_size_override("font_size", 20 if is_mob else 14)
	name_lbl.add_theme_color_override("font_color", Color.html("#cbd5e1"))
	name_row.add_child(name_lbl)

	_name_input = LineEdit.new()
	_name_input.max_length = 12
	_name_input.custom_minimum_size = Vector2(280 if is_mob else 220, 54 if is_mob else 36)
	_name_input.add_theme_font_size_override("font_size", 20 if is_mob else 15)
	UiStyle.apply_line_edit(_name_input, "#fbbf24")
	_name_input.text_submitted.connect(func(_t: String) -> void: GameState.set_player_name(_name_input.text))
	name_row.add_child(_name_input)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_row.add_child(spacer)

	var rand_btn := Button.new()
	rand_btn.text = "🎲 隨機和風取名"
	rand_btn.custom_minimum_size = Vector2(200 if is_mob else 0, 54 if is_mob else 36)
	rand_btn.add_theme_font_size_override("font_size", 18 if is_mob else 13)
	UiStyle.apply_button(rand_btn, "#1e293b", "#64748b", "#fde68a", 12, 1, 0.95)
	rand_btn.pressed.connect(func() -> void:
		var pick: String = GameData.RANDOM_NAMES[randi() % GameData.RANDOM_NAMES.size()]
		_name_input.text = pick
		GameState.set_player_name(pick)
	)
	name_row.add_child(rand_btn)

	var confirm_btn := Button.new()
	confirm_btn.text = "確認名字"
	confirm_btn.custom_minimum_size = Vector2(140 if is_mob else 0, 54 if is_mob else 36)
	confirm_btn.add_theme_font_size_override("font_size", 18 if is_mob else 13)
	UiStyle.apply_button(confirm_btn, "#f59e0b", "#fde68a", "#0f172a", 12, 1, 1.0)
	confirm_btn.pressed.connect(func() -> void: GameState.set_player_name(_name_input.text))
	name_row.add_child(confirm_btn)

	# ==================== STEP 1: CHARACTERS ====================
	vbox.add_child(_make_section_title("🎭 1. 選擇出戰 3D 角色（普攻皆為「あ」三段斬，技能按鍵各有專屬奧義）：", "#fcd34d", is_mob))
	_char_grid = GridContainer.new()
	_char_grid.columns = 2 if is_mob else 3
	_char_grid.add_theme_constant_override("h_separation", 12 if is_mob else 10)
	_char_grid.add_theme_constant_override("v_separation", 12 if is_mob else 10)
	vbox.add_child(_char_grid)

	# ==================== STEP 2: STAGES ====================
	vbox.add_child(_make_section_title("🗺️ 2. 選擇 3D 戰鬥關卡場景：", "#7dd3fc", is_mob))
	_stage_grid = GridContainer.new()
	_stage_grid.columns = 2 if is_mob else 4
	_stage_grid.add_theme_constant_override("h_separation", 12 if is_mob else 10)
	_stage_grid.add_theme_constant_override("v_separation", 12 if is_mob else 10)
	vbox.add_child(_stage_grid)

	# ==================== STEP 3: MODES ====================
	vbox.add_child(_make_section_title("🔥 3. 選擇挑戰模式：", "#fda4af", is_mob))
	_mode_grid = GridContainer.new()
	_mode_grid.columns = 2 if is_mob else 4
	_mode_grid.add_theme_constant_override("h_separation", 12 if is_mob else 10)
	_mode_grid.add_theme_constant_override("v_separation", 12 if is_mob else 10)
	vbox.add_child(_mode_grid)

	# ==================== FOOTER CTA ====================
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 16)
	vbox.add_child(footer)

	var tip := Label.new()
	tip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip.text = "💡 選擇好角色、關卡與模式後點擊右側按鈕，才會正式載入 3D 戰鬥本體！"
	tip.add_theme_font_size_override("font_size", 18 if is_mob else 12)
	tip.add_theme_color_override("font_color", Color.html("#94a3b8"))
	footer.add_child(tip)

	var start_btn := Button.new()
	start_btn.text = "⚔️ 進入 3D 道場開戰！"
	start_btn.custom_minimum_size = Vector2(400 if is_mob else 240, 76 if is_mob else 52)
	start_btn.add_theme_font_size_override("font_size", 26 if is_mob else 18)
	UiStyle.apply_button(start_btn, "#dc2626", "#fde68a", "#ffffff", 18, 3 if is_mob else 2, 1.0)
	start_btn.pressed.connect(_on_start_battle_pressed)
	footer.add_child(start_btn)

	# ==================== EMBEDDED UPGRADE MODAL ====================
	_upgrade_modal = UpgradeModal.new()
	add_child(_upgrade_modal)

	# ==================== TOAST ====================
	var toast_center := CenterContainer.new()
	toast_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_center.set_anchors_preset(Control.PRESET_TOP_WIDE)
	toast_center.offset_top = 24
	add_child(toast_center)

	_toast_panel = PanelContainer.new()
	_toast_panel.visible = false
	_toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_panel.add_theme_stylebox_override("panel", UiStyle.make_panel("#0f172a", 0.96, "#fbbf24", 0.85, 20, 2, 20, 8))
	_toast_lbl = Label.new()
	_toast_lbl.add_theme_font_size_override("font_size", 18 if is_mob else 15)
	_toast_lbl.add_theme_color_override("font_color", Color.html("#fcd34d"))
	_toast_panel.add_child(_toast_lbl)
	toast_center.add_child(_toast_panel)

	# ==================== LOADING OVERLAY ====================
	_loading_overlay = ColorRect.new()
	_loading_overlay.visible = false
	_loading_overlay.color = Color(0.03, 0.05, 0.09, 0.94)
	_loading_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_loading_overlay)

	var load_center := CenterContainer.new()
	load_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_loading_overlay.add_child(load_center)

	var load_panel := PanelContainer.new()
	load_panel.add_theme_stylebox_override("panel", UiStyle.make_panel("#0f172a", 0.96, "#fbbf24", 0.8, 20, 2, 32, 24))
	load_center.add_child(load_panel)

	var load_lbl := Label.new()
	load_lbl.text = "🌸 正在載入 3D 道場與百鬼夜行戰場...\n請稍候片刻"
	load_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	load_lbl.add_theme_font_size_override("font_size", 24 if is_mob else 18)
	load_lbl.add_theme_color_override("font_color", Color.html("#fcd34d"))
	load_panel.add_child(load_lbl)


func _make_section_title(text: String, hex_col: String, is_mob: bool) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 21 if is_mob else 15)
	lbl.add_theme_color_override("font_color", Color.html(hex_col))
	return lbl


func _update_audio_btn() -> void:
	if _audio_btn != null:
		_audio_btn.text = "🔊" if AudioManager.audio_enabled else "🔇"


func refresh() -> void:
	var is_mob := UiStyle.is_mobile_device()
	var p := GameState.player

	if _stats_badge_lbl != null:
		_stats_badge_lbl.text = "Lv.%d ｜ 🪙 %d ｜ ✨ %dpt" % [int(p["level"]), int(p["gold"]), int(p["skill_points"])]

	if _name_input != null and not _name_input.has_focus():
		_name_input.text = String(p["name"])

	if _char_grid != null:
		for c in _char_grid.get_children():
			c.queue_free()
		for cid in GameData.CHARACTER_ORDER:
			var ch: Dictionary = GameData.CHARACTERS[cid]
			var selected: bool = p["char_id"] == cid
			var btn := Button.new()
			btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			btn.custom_minimum_size = Vector2(0, 152 if is_mob else 96)
			btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
			btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			btn.text = "%s %s【%s】 鍵：%s\n%s" % [ch["icon"], ch["name"], ch["title"], ch["sig_key"], ch["desc"]]
			btn.add_theme_font_size_override("font_size", 20 if is_mob else 12)
			if selected:
				UiStyle.apply_button(btn, "#78350f", "#fbbf24", "#fef3c7", 16, 3 if is_mob else 2, 0.85)
			else:
				UiStyle.apply_button(btn, "#0f172a", "#334155", "#e2e8f0", 16, 1, 0.90)
			var pick_id: String = cid
			btn.pressed.connect(func() -> void: GameState.set_character(pick_id))
			_char_grid.add_child(btn)

	if _stage_grid != null:
		for c in _stage_grid.get_children():
			c.queue_free()
		for st in GameData.STAGES:
			var selected: bool = p["stage_id"] == st["id"]
			var btn := Button.new()
			btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			btn.custom_minimum_size = Vector2(0, 118 if is_mob else 82)
			btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
			btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			btn.text = "%s %s\n%s" % [st["icon"], st["name"], st["desc"]]
			btn.add_theme_font_size_override("font_size", 19 if is_mob else 12)
			if selected:
				UiStyle.apply_button(btn, "#0c4a6e", "#38bdf8", "#e0f2fe", 16, 3 if is_mob else 2, 0.85)
			else:
				UiStyle.apply_button(btn, "#0f172a", "#334155", "#cbd5e1", 16, 1, 0.90)
			var sid: String = st["id"]
			btn.pressed.connect(func() -> void: GameState.set_stage(sid))
			_stage_grid.add_child(btn)

	if _mode_grid != null:
		for c in _mode_grid.get_children():
			c.queue_free()
		for m in GameData.GAME_MODES:
			var selected: bool = p["mode"] == m["id"]
			var btn := Button.new()
			btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			btn.custom_minimum_size = Vector2(0, 108 if is_mob else 72)
			btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
			btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			btn.text = "%s\n%s" % [m["label"], m["desc"]]
			btn.add_theme_font_size_override("font_size", 19 if is_mob else 12)
			if selected:
				UiStyle.apply_button(btn, "#78350f", "#fbbf24", m["color"], 16, 3 if is_mob else 2, 0.85)
			else:
				UiStyle.apply_button(btn, "#0f172a", "#334155", m["color"], 16, 1, 0.90)
			var mid: String = m["id"]
			btn.pressed.connect(func() -> void: GameState.set_mode(mid))
			_mode_grid.add_child(btn)


func _on_start_battle_pressed() -> void:
	if _is_loading_game:
		return
	_is_loading_game = true

	UiStyle.request_mobile_landscape_fullscreen()

	var typed := _name_input.text.strip_edges()
	if not typed.is_empty() and typed != String(GameState.player["name"]):
		GameState.set_player_name(typed)
	GameState.save_game_data()

	AudioManager.play_sfx("skill")
	_loading_overlay.visible = true
	call_deferred("_load_game_scene")


func _load_game_scene() -> void:
	await get_tree().process_frame
	get_tree().change_scene_to_file(GAME_SCENE_PATH)


func _show_toast(msg: String) -> void:
	_toast_lbl.text = msg
	_toast_panel.visible = true
	_toast_timer = 2.4


func _process(delta: float) -> void:
	if _toast_timer > 0.0:
		_toast_timer -= delta
		if _toast_timer <= 0.0:
			_toast_panel.visible = false
