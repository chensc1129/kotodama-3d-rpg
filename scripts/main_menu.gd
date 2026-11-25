extends Control
## Standalone Main Menu scene: Wafuu Shrine Preparation Hall with atmospheric gradient backdrop,
## structured hero/stage/mode visual cards, selected hero spotlight banner, pre-battle upgrades
## & Japanese dictionary access, and smooth spring entrance & loading curtain animations.

const GAME_SCENE_PATH: String = "res://scenes/game.tscn"

var _main_panel: PanelContainer
var _name_input: LineEdit
var _stats_badge_lbl: Label
var _audio_btn: Button
var _char_grid: GridContainer
var _hero_spotlight_panel: PanelContainer
var _hero_spotlight_icon: Label
var _hero_spotlight_title: Label
var _hero_spotlight_desc: Label
var _stage_grid: GridContainer
var _mode_grid: GridContainer
var _upgrade_modal: UpgradeModal
var _settings_modal: SettingsModal
var _loading_overlay: ColorRect
var _loading_panel: PanelContainer
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
	call_deferred("_play_entrance")


func _play_entrance() -> void:
	if _main_panel != null:
		UiStyle.animate_modal_open(self, null, _main_panel, 0.30)


func _build_ui() -> void:
	var is_mob := UiStyle.is_mobile_device()

	# Layered Twilight-Indigo to Shrine-Crimson Gradient Backdrop
	add_child(UiStyle.make_gradient_bg("#050814", "#0e152c", "#260d1c"))

	# Subtle Moonlit Glow (Top-Left) + Torii Ember Glow (Bottom-Right)
	var glow_moon := UiStyle.make_radial_glow("#38bdf8", 0.16)
	glow_moon.anchor_left = 0.0
	glow_moon.anchor_top = 0.0
	glow_moon.anchor_right = 0.55
	glow_moon.anchor_bottom = 0.55
	add_child(glow_moon)

	var glow_shrine := UiStyle.make_radial_glow("#e11d48", 0.22)
	glow_shrine.anchor_left = 0.45
	glow_shrine.anchor_top = 0.42
	glow_shrine.anchor_right = 1.0
	glow_shrine.anchor_bottom = 1.0
	add_child(glow_shrine)

	# Lightweight 2D Sakura Petals
	var petals := CPUParticles2D.new()
	petals.position = Vector2(640, -20)
	petals.amount = 54
	petals.lifetime = 9.0
	petals.preprocess = 4.0
	petals.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	petals.emission_rect_extents = Vector2(960, 10)
	petals.direction = Vector2(0.25, 1.0)
	petals.spread = 20.0
	petals.gravity = Vector2(12, 16)
	petals.initial_velocity_min = 42.0
	petals.initial_velocity_max = 92.0
	petals.scale_amount_min = 4.0
	petals.scale_amount_max = 8.5
	petals.color = Color(0.99, 0.70, 0.85, 0.72)
	add_child(petals)

	# Outer Container: Full-screen on mobile, spacious centered shrine card on desktop
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var m_side := 12 if is_mob else 24
	var m_vert := 10 if is_mob else 16
	margin.add_theme_constant_override("margin_left", m_side)
	margin.add_theme_constant_override("margin_right", m_side)
	margin.add_theme_constant_override("margin_top", m_vert)
	margin.add_theme_constant_override("margin_bottom", m_vert)
	add_child(margin)

	_main_panel = PanelContainer.new()
	_main_panel.add_theme_stylebox_override(
		"panel",
		UiStyle.make_shrine_modal("#080d1c", "#e8c474", 24, 26, 20)
	)
	if is_mob:
		_main_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_main_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
		margin.add_child(_main_panel)
	else:
		var center := CenterContainer.new()
		center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		center.size_flags_vertical = Control.SIZE_EXPAND_FILL
		margin.add_child(center)
		_main_panel.custom_minimum_size = Vector2(1060, 670)
		center.add_child(_main_panel)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_main_panel.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 14 if is_mob else 11)
	scroll.add_child(vbox)

	# ==================== HEADER ====================
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	vbox.add_child(header)

	var title_box := VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_box.add_theme_constant_override("separation", 3)
	header.add_child(title_box)

	var ver_lbl := Label.new()
	ver_lbl.text = "✨  和風 3D 動作 RPG｜百鬼夜行・言靈詠唱・立體戰場  ✨"
	ver_lbl.add_theme_font_size_override("font_size", 15 if is_mob else 11)
	ver_lbl.add_theme_color_override("font_color", Color.html("#fda4af"))
	title_box.add_child(ver_lbl)

	var main_title := Label.new()
	main_title.text = "⛩️ 言霊剣士・あの一撃 3D"
	main_title.add_theme_font_size_override("font_size", 36 if is_mob else 28)
	main_title.add_theme_color_override("font_color", Color.html("#fef3c7"))
	UiStyle.style_label_shadow(main_title, 0.85, 2)
	title_box.add_child(main_title)

	# Player Stats + Quick Prep & Dictionary Buttons
	var header_right := HBoxContainer.new()
	header_right.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	header_right.add_theme_constant_override("separation", 8 if is_mob else 7)
	header.add_child(header_right)

	var stat_panel := PanelContainer.new()
	stat_panel.add_theme_stylebox_override("panel", UiStyle.make_pill("#0d162c", 0.94, "#e8c474", 0.50, 14, 7))
	_stats_badge_lbl = Label.new()
	_stats_badge_lbl.add_theme_font_size_override("font_size", 17 if is_mob else 13)
	_stats_badge_lbl.add_theme_color_override("font_color", Color.html("#fef3c7"))
	stat_panel.add_child(_stats_badge_lbl)
	header_right.add_child(stat_panel)

	var btn_h := 54 if is_mob else 38
	var btn_fs := 18 if is_mob else 13
	for item in [
		["⚡ 技能", "#e8c474", "#fef3c7", "skills"],
		["🎒 裝備", "#34d399", "#a7f3d0", "equip"],
		["🦊 式神", "#f472b6", "#fbcfe8", "shikigami"],
		["📖 辭典", "#38bdf8", "#bae6fd", "dict"],
	]:
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.text = item[0]
		b.custom_minimum_size = Vector2(106 if is_mob else 74, btn_h)
		b.add_theme_font_size_override("font_size", btn_fs)
		UiStyle.apply_button(b, "#131d38", item[1], item[2], 18, 2 if is_mob else 1, 0.95)
		var tab_id: String = item[3]
		b.pressed.connect(func() -> void: _upgrade_modal.open_modal(tab_id))
		header_right.add_child(b)

	if is_mob:
		var fs_btn := Button.new()
		fs_btn.focus_mode = Control.FOCUS_NONE
		fs_btn.text = "📱 橫向全螢幕"
		fs_btn.custom_minimum_size = Vector2(150, btn_h)
		fs_btn.add_theme_font_size_override("font_size", 17)
		UiStyle.apply_button(fs_btn, "#0c4a6e", "#38bdf8", "#e0f2fe", 14, 2, 0.95)
		fs_btn.pressed.connect(func() -> void: UiStyle.request_mobile_landscape_fullscreen())
		header_right.add_child(fs_btn)

	var set_btn := Button.new()
	set_btn.focus_mode = Control.FOCUS_NONE
	set_btn.text = "⚙️ 設定"
	set_btn.custom_minimum_size = Vector2(106 if is_mob else 74, btn_h)
	set_btn.add_theme_font_size_override("font_size", btn_fs)
	UiStyle.apply_button(set_btn, "#131d38", "#94a3b8", "#e2e8f0", 18, 2 if is_mob else 1, 0.95)
	set_btn.pressed.connect(func() -> void: _settings_modal.open_settings())
	header_right.add_child(set_btn)

	_audio_btn = Button.new()
	_audio_btn.focus_mode = Control.FOCUS_NONE
	_audio_btn.custom_minimum_size = Vector2(58 if is_mob else 42, btn_h)
	_audio_btn.add_theme_font_size_override("font_size", 20 if is_mob else 15)
	UiStyle.apply_button(_audio_btn, "#151f36", "#94a3b8", "#ffffff", 14, 1, 0.95)
	_audio_btn.pressed.connect(func() -> void: AudioManager.toggle_audio())
	header_right.add_child(_audio_btn)
	_update_audio_btn()

	vbox.add_child(UiStyle.make_ornament_divider("#e6c37a", 0.45))

	# ==================== STEP 1: CHARACTERS ====================
	vbox.add_child(_make_section_header("01", "選擇出戰 3D 劍士", "普攻為「あ」三段斬・E 施放專屬技・Q 詠唱 30 種日文言靈奧義", "#fcd34d", is_mob))

	_char_grid = GridContainer.new()
	_char_grid.columns = 2 if is_mob else 5
	_char_grid.add_theme_constant_override("h_separation", 10)
	_char_grid.add_theme_constant_override("v_separation", 10)
	vbox.add_child(_char_grid)

	# Selected Hero Spotlight Banner
	_hero_spotlight_panel = PanelContainer.new()
	_hero_spotlight_panel.add_theme_stylebox_override("panel", UiStyle.make_accent_card("#0c1428", "#fbbf24", true, 16, 18, 12))
	vbox.add_child(_hero_spotlight_panel)

	var spot_row := HBoxContainer.new()
	spot_row.add_theme_constant_override("separation", 14)
	_hero_spotlight_panel.add_child(spot_row)

	_hero_spotlight_icon = Label.new()
	_hero_spotlight_icon.add_theme_font_size_override("font_size", 38 if is_mob else 30)
	_hero_spotlight_icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	spot_row.add_child(_hero_spotlight_icon)

	var spot_v := VBoxContainer.new()
	spot_v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spot_v.add_theme_constant_override("separation", 3)
	spot_row.add_child(spot_v)

	_hero_spotlight_title = Label.new()
	_hero_spotlight_title.add_theme_font_size_override("font_size", 20 if is_mob else 14)
	_hero_spotlight_title.add_theme_color_override("font_color", Color.html("#fef3c7"))
	UiStyle.style_label_shadow(_hero_spotlight_title, 0.7)
	spot_v.add_child(_hero_spotlight_title)

	_hero_spotlight_desc = Label.new()
	_hero_spotlight_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hero_spotlight_desc.add_theme_font_size_override("font_size", 17 if is_mob else 12)
	_hero_spotlight_desc.add_theme_color_override("font_color", Color.html("#cbd5e1"))
	spot_v.add_child(_hero_spotlight_desc)

	# ==================== STEP 2: STAGES ====================
	vbox.add_child(_make_section_header("02", "選擇 3D 立體戰場", "每張地圖皆有高低差地形、高地斬 +20% 與專屬環境機制", "#7dd3fc", is_mob))

	_stage_grid = GridContainer.new()
	_stage_grid.columns = 2 if is_mob else 4
	_stage_grid.add_theme_constant_override("h_separation", 10)
	_stage_grid.add_theme_constant_override("v_separation", 10)
	vbox.add_child(_stage_grid)

	# ==================== STEP 3: MODES ====================
	vbox.add_child(_make_section_header("03", "選擇挑戰模式", "難度越高金幣與經驗獎勵越豐厚", "#fda4af", is_mob))

	_mode_grid = GridContainer.new()
	_mode_grid.columns = 2 if is_mob else 4
	_mode_grid.add_theme_constant_override("h_separation", 10)
	_mode_grid.add_theme_constant_override("v_separation", 10)
	vbox.add_child(_mode_grid)

	vbox.add_child(UiStyle.make_divider("#e6c37a", 0.25, 1))

	# ==================== FOOTER: NAME + LAUNCH CTA ====================
	var footer_card := PanelContainer.new()
	footer_card.add_theme_stylebox_override("panel", UiStyle.make_panel("#0b1326", 0.92, "#e8c474", 0.36, 18, 1, 16, 12, 10))
	vbox.add_child(footer_card)

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 12)
	footer_card.add_child(footer)

	var name_lbl := Label.new()
	name_lbl.text = "🏷️ 稱號："
	name_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	name_lbl.add_theme_font_size_override("font_size", 19 if is_mob else 13)
	name_lbl.add_theme_color_override("font_color", Color.html("#cbd5e1"))
	footer.add_child(name_lbl)

	_name_input = LineEdit.new()
	_name_input.max_length = 12
	_name_input.custom_minimum_size = Vector2(240 if is_mob else 190, 52 if is_mob else 40)
	_name_input.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_name_input.add_theme_font_size_override("font_size", 19 if is_mob else 14)
	UiStyle.apply_line_edit(_name_input, "#e8c474")
	_name_input.text_submitted.connect(func(_t: String) -> void: GameState.set_player_name(_name_input.text))
	footer.add_child(_name_input)

	var rand_btn := Button.new()
	rand_btn.focus_mode = Control.FOCUS_NONE
	rand_btn.text = "🎲 隨機"
	rand_btn.custom_minimum_size = Vector2(120 if is_mob else 84, 52 if is_mob else 40)
	rand_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rand_btn.add_theme_font_size_override("font_size", 18 if is_mob else 13)
	UiStyle.apply_button(rand_btn, "#15203a", "#64748b", "#fde68a", 12, 1, 0.95)
	rand_btn.pressed.connect(func() -> void:
		var pick: String = GameData.RANDOM_NAMES[randi() % GameData.RANDOM_NAMES.size()]
		_name_input.text = pick
		GameState.set_player_name(pick)
	)
	footer.add_child(rand_btn)

	var confirm_btn := Button.new()
	confirm_btn.focus_mode = Control.FOCUS_NONE
	confirm_btn.text = "儲存"
	confirm_btn.custom_minimum_size = Vector2(96 if is_mob else 68, 52 if is_mob else 40)
	confirm_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	confirm_btn.add_theme_font_size_override("font_size", 18 if is_mob else 13)
	UiStyle.apply_button(confirm_btn, "#1e293b", "#e8c474", "#fef3c7", 12, 1, 0.96)
	confirm_btn.pressed.connect(func() -> void: GameState.set_player_name(_name_input.text))
	footer.add_child(confirm_btn)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(spacer)

	var start_btn := Button.new()
	start_btn.focus_mode = Control.FOCUS_NONE
	start_btn.text = "⚔️ 進入 3D 道場開戰！"
	start_btn.custom_minimum_size = Vector2(360 if is_mob else 256, 68 if is_mob else 48)
	start_btn.add_theme_font_size_override("font_size", 24 if is_mob else 17)
	UiStyle.apply_button(start_btn, "#be123c", "#fde68a", "#ffffff", 16, 2, 1.0)
	start_btn.pressed.connect(_on_start_battle_pressed)
	footer.add_child(start_btn)

	# ==================== EMBEDDED UPGRADE & DICTIONARY MODAL ====================
	_upgrade_modal = UpgradeModal.new()
	add_child(_upgrade_modal)

	_settings_modal = SettingsModal.new()
	add_child(_settings_modal)

	# ==================== TOAST ====================
	var toast_center := CenterContainer.new()
	toast_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_center.set_anchors_preset(Control.PRESET_TOP_WIDE)
	toast_center.offset_top = 24
	add_child(toast_center)

	_toast_panel = PanelContainer.new()
	_toast_panel.visible = false
	_toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_panel.add_theme_stylebox_override("panel", UiStyle.make_pill("#090f20", 0.96, "#fbbf24", 0.85, 22, 8))
	_toast_lbl = Label.new()
	_toast_lbl.add_theme_font_size_override("font_size", 18 if is_mob else 14)
	_toast_lbl.add_theme_color_override("font_color", Color.html("#fef3c7"))
	_toast_panel.add_child(_toast_lbl)
	toast_center.add_child(_toast_panel)

	# ==================== LOADING CURTAIN ====================
	_loading_overlay = ColorRect.new()
	_loading_overlay.visible = false
	_loading_overlay.color = Color(0.02, 0.04, 0.09, 0.94)
	_loading_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_loading_overlay)

	var load_center := CenterContainer.new()
	load_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_loading_overlay.add_child(load_center)

	_loading_panel = PanelContainer.new()
	_loading_panel.add_theme_stylebox_override("panel", UiStyle.make_shrine_modal("#090f20", "#fbbf24", 24, 38, 28))
	load_center.add_child(_loading_panel)

	var load_v := VBoxContainer.new()
	load_v.alignment = BoxContainer.ALIGNMENT_CENTER
	load_v.add_theme_constant_override("separation", 8)
	_loading_panel.add_child(load_v)

	var load_ico := Label.new()
	load_ico.text = "⛩️"
	load_ico.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	load_ico.add_theme_font_size_override("font_size", 46 if is_mob else 36)
	load_v.add_child(load_ico)

	var load_lbl := Label.new()
	load_lbl.text = "🌸 正在開啟 3D 道場與百鬼夜行戰場...\n請稍候片刻"
	load_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	load_lbl.add_theme_font_size_override("font_size", 22 if is_mob else 17)
	load_lbl.add_theme_color_override("font_color", Color.html("#fde68a"))
	load_v.add_child(load_lbl)


func _make_section_header(num: String, title: String, subtitle: String, hex_col: String, is_mob: bool) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.add_child(UiStyle.make_badge_pill(num, "#101830", hex_col, hex_col, 14 if is_mob else 11))

	var t_lbl := Label.new()
	t_lbl.text = title
	t_lbl.add_theme_font_size_override("font_size", 21 if is_mob else 15)
	t_lbl.add_theme_color_override("font_color", Color.html(hex_col))
	UiStyle.style_label_shadow(t_lbl, 0.7)
	row.add_child(t_lbl)

	var s_lbl := Label.new()
	s_lbl.text = "｜ " + subtitle
	s_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s_lbl.add_theme_font_size_override("font_size", 15 if is_mob else 11)
	s_lbl.add_theme_color_override("font_color", Color.html("#94a3b8"))
	row.add_child(s_lbl)
	return row


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

	# 1. Structured Hero Cards + Spotlight
	if _char_grid != null:
		for c in _char_grid.get_children():
			c.queue_free()
		for cid in GameData.CHARACTER_ORDER:
			var ch: Dictionary = GameData.CHARACTERS[cid]
			var selected: bool = p["char_id"] == cid
			var accent_hex: String = String(ch["color_primary"])
			var bg_hex := "#1e162e" if selected else "#0c1326"

			var btn := Button.new()
			btn.focus_mode = Control.FOCUS_NONE
			btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			btn.custom_minimum_size = Vector2(0, 148 if is_mob else 114)
			UiStyle.apply_card_button(btn, bg_hex, accent_hex, selected, 16)

			var m := MarginContainer.new()
			m.mouse_filter = Control.MOUSE_FILTER_IGNORE
			m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			m.add_theme_constant_override("margin_left", 12)
			m.add_theme_constant_override("margin_right", 10)
			m.add_theme_constant_override("margin_top", 9)
			m.add_theme_constant_override("margin_bottom", 9)
			btn.add_child(m)

			var cv := VBoxContainer.new()
			cv.mouse_filter = Control.MOUSE_FILTER_IGNORE
			cv.add_theme_constant_override("separation", 4)
			m.add_child(cv)

			var top_r := HBoxContainer.new()
			top_r.mouse_filter = Control.MOUSE_FILTER_IGNORE
			top_r.add_theme_constant_override("separation", 6)
			cv.add_child(top_r)

			var ico := Label.new()
			ico.text = ch["icon"]
			ico.mouse_filter = Control.MOUSE_FILTER_IGNORE
			ico.add_theme_font_size_override("font_size", 28 if is_mob else 22)
			top_r.add_child(ico)

			var name_v := VBoxContainer.new()
			name_v.mouse_filter = Control.MOUSE_FILTER_IGNORE
			name_v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			name_v.add_theme_constant_override("separation", 1)
			top_r.add_child(name_v)

			var nm := Label.new()
			nm.text = ch["name"]
			nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
			nm.add_theme_font_size_override("font_size", 19 if is_mob else 14)
			nm.add_theme_color_override("font_color", Color.html("#fef3c7" if selected else "#e2e8f0"))
			name_v.add_child(nm)

			var ttl := Label.new()
			ttl.text = String(ch["title"]).replace(" (NEW)", "")
			ttl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			ttl.add_theme_font_size_override("font_size", 13 if is_mob else 10)
			ttl.add_theme_color_override("font_color", Color.html(accent_hex).lerp(Color.WHITE, 0.30))
			name_v.add_child(ttl)

			var sig_lbl := Label.new()
			sig_lbl.text = "%s E：%s" % [ch["sig_icon"], ch["sig_name"]]
			sig_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			sig_lbl.add_theme_font_size_override("font_size", 14 if is_mob else 11)
			sig_lbl.add_theme_color_override("font_color", Color.html("#fde68a"))
			cv.add_child(sig_lbl)

			var st_lbl := Label.new()
			st_lbl.text = "❤️%d  ⚔️%d  💨%.0f" % [int(ch["base_hp"]), int(ch["base_atk"]), float(ch["base_spd"]) * 10.0]
			st_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			st_lbl.add_theme_font_size_override("font_size", 13 if is_mob else 10)
			st_lbl.add_theme_color_override("font_color", Color.html("#94a3b8"))
			cv.add_child(st_lbl)

			var pick_id: String = cid
			btn.pressed.connect(func() -> void: GameState.set_character(pick_id))
			_char_grid.add_child(btn)

	# Update Selected Hero Spotlight Banner
	var cur_ch: Dictionary = GameData.get_character(p["char_id"])
	if _hero_spotlight_panel != null:
		var c_hex: String = String(cur_ch["color_primary"])
		_hero_spotlight_panel.add_theme_stylebox_override("panel", UiStyle.make_accent_card("#0e152b", c_hex, true, 16, 18, 11))
		_hero_spotlight_icon.text = cur_ch["icon"]
		_hero_spotlight_title.text = "◆ 已選定：%s【%s】  ｜  專屬技（E）：%s %s（%s）" % [
			cur_ch["name"], cur_ch["title"], cur_ch["sig_icon"], cur_ch["sig_name"], cur_ch["sig_key"]
		]
		var style_txt: String = String(cur_ch.get("combat_style", ""))
		_hero_spotlight_desc.text = "%s\n%s" % [style_txt, String(cur_ch["desc"])] if not style_txt.is_empty() else String(cur_ch["desc"])

	# 2. Structured Stage Cards
	if _stage_grid != null:
		for c in _stage_grid.get_children():
			c.queue_free()
		for st in GameData.STAGES:
			var selected: bool = p["stage_id"] == st["id"]
			var st_hex: String = String(st.get("ring_color", "#38bdf8"))
			var bg_hex := "#112238" if selected else "#0c1326"

			var btn := Button.new()
			btn.focus_mode = Control.FOCUS_NONE
			btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			btn.custom_minimum_size = Vector2(0, 128 if is_mob else 96)
			UiStyle.apply_card_button(btn, bg_hex, st_hex, selected, 16)

			var m := MarginContainer.new()
			m.mouse_filter = Control.MOUSE_FILTER_IGNORE
			m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			m.add_theme_constant_override("margin_left", 12)
			m.add_theme_constant_override("margin_right", 10)
			m.add_theme_constant_override("margin_top", 9)
			m.add_theme_constant_override("margin_bottom", 9)
			btn.add_child(m)

			var sv := VBoxContainer.new()
			sv.mouse_filter = Control.MOUSE_FILTER_IGNORE
			sv.add_theme_constant_override("separation", 4)
			m.add_child(sv)

			var nm := Label.new()
			nm.text = "%s %s" % [st["icon"], st["name"]]
			nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
			nm.add_theme_font_size_override("font_size", 18 if is_mob else 13)
			nm.add_theme_color_override("font_color", Color.html("#fef3c7" if selected else "#e2e8f0"))
			sv.add_child(nm)

			var mech_lbl := Label.new()
			mech_lbl.text = String(st.get("mechanic_name", ""))
			mech_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			mech_lbl.add_theme_font_size_override("font_size", 14 if is_mob else 11)
			mech_lbl.add_theme_color_override("font_color", Color.html(st_hex).lerp(Color.WHITE, 0.30))
			sv.add_child(mech_lbl)

			var desc := Label.new()
			desc.text = st["desc"]
			desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
			desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			desc.add_theme_font_size_override("font_size", 13 if is_mob else 10)
			desc.add_theme_color_override("font_color", Color.html("#94a3b8"))
			sv.add_child(desc)

			var sid: String = st["id"]
			btn.pressed.connect(func() -> void: GameState.set_stage(sid))
			_stage_grid.add_child(btn)

	# 3. Structured Mode Cards
	if _mode_grid != null:
		for c in _mode_grid.get_children():
			c.queue_free()
		for m in GameData.GAME_MODES:
			var selected: bool = p["mode"] == m["id"]
			var m_hex: String = String(m["color"])
			var bg_hex := "#241914" if selected else "#0c1326"

			var btn := Button.new()
			btn.focus_mode = Control.FOCUS_NONE
			btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			btn.custom_minimum_size = Vector2(0, 96 if is_mob else 68)
			UiStyle.apply_card_button(btn, bg_hex, m_hex, selected, 14)

			var pad := MarginContainer.new()
			pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
			pad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			pad.add_theme_constant_override("margin_left", 12)
			pad.add_theme_constant_override("margin_right", 10)
			pad.add_theme_constant_override("margin_top", 8)
			pad.add_theme_constant_override("margin_bottom", 8)
			btn.add_child(pad)

			var mv := VBoxContainer.new()
			mv.mouse_filter = Control.MOUSE_FILTER_IGNORE
			mv.alignment = BoxContainer.ALIGNMENT_CENTER
			mv.add_theme_constant_override("separation", 3)
			pad.add_child(mv)

			var lbl := Label.new()
			lbl.text = m["label"]
			lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			lbl.add_theme_font_size_override("font_size", 18 if is_mob else 13)
			lbl.add_theme_color_override("font_color", Color.html(m_hex))
			mv.add_child(lbl)

			var desc := Label.new()
			desc.text = m["desc"]
			desc.mouse_filter = Control.MOUSE_FILTER_IGNORE
			desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			desc.add_theme_font_size_override("font_size", 14 if is_mob else 10)
			desc.add_theme_color_override("font_color", Color.html("#cbd5e1"))
			mv.add_child(desc)

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
	UiStyle.animate_modal_open(self, _loading_overlay, _loading_panel, 0.22)
	call_deferred("_load_game_scene")


func _load_game_scene() -> void:
	await get_tree().process_frame
	get_tree().change_scene_to_file(GAME_SCENE_PATH)


func _show_toast(msg: String) -> void:
	_toast_lbl.text = msg
	_toast_panel.visible = true
	_toast_timer = 2.4
	UiStyle.animate_toast_in(self, _toast_panel)


func _process(delta: float) -> void:
	if _toast_timer > 0.0:
		_toast_timer -= delta
		if _toast_timer <= 0.0:
			_toast_panel.visible = false
