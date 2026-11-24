class_name HudUI
extends Control
## Main in-game HUD with responsive Desktop vs Mobile layout:
## - Desktop: hides touch movement wheel/D-Pad, shows keyboard hints & direct input.
## - Mobile/Touch: shows enlarged 360° joystick/D-Pad and large thumb-friendly action & menu buttons.

signal attack_pressed
signal dash_pressed
signal sig_skill_pressed
signal ult_skill_pressed
signal upgrade_requested(tab: String)
signal lobby_requested
signal joystick_changed(vec: Vector2)

var _is_mobile_ui: bool = false

# Top HUD references
var _icon_box: PanelContainer
var _char_icon_lbl: Label
var _bars_box: VBoxContainer
var _player_name_lbl: Label
var _level_lbl: Label
var _hp_text_lbl: Label
var _hp_bar: ProgressBar
var _sp_text_lbl: Label
var _sp_bar: ProgressBar
var _exp_bar: ProgressBar

var _stage_lbl: Label
var _mode_lbl: Label
var _enemy_count_lbl: Label
var _endless_lbl: Label

var _gold_lbl: Label
var _sp_pts_lbl: Label
var _menu_buttons: Array[Button] = []
var _audio_btn: Button

var _boss_panel: PanelContainer
var _boss_name_lbl: Label
var _boss_hp_lbl: Label
var _boss_bar: ProgressBar

# Bottom controls
var _bot_margin: MarginContainer
var _left_ctrl: VBoxContainer
var _joystick: VirtualJoystick
var _dpad_grid: GridContainer
var _dpad_buttons: Array[Button] = []
var _dpad_cells: Array[Control] = []
var _ctrl_toggle_btn: Button
var _is_dpad_mode: bool = false

var _combo_panel: PanelContainer
var _combo_lbl: Label
var _direct_center: CenterContainer
var _direct_input: LineEdit
var _hint_lbl: Label

var _right_vbox: VBoxContainer
var _skill_row: HBoxContainer
var _btn_dash: Button
var _btn_ult: Button
var _btn_sig: Button
var _btn_atk: Button

# Toast
var _toast_panel: PanelContainer
var _toast_lbl: Label
var _toast_timer: float = 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_is_mobile_ui = UiStyle.is_mobile_device()
	_build_ui()
	_apply_responsive_layout()
	GameState.toast_requested.connect(show_toast)
	AudioManager.audio_toggled.connect(func(on: bool) -> void:
		if _audio_btn != null:
			_audio_btn.text = "🔊" if on else "🔇"
	)


func _input(event: InputEvent) -> void:
	# If a touch event occurs on a tablet/hybrid device in desktop browser mode,
	# automatically enable the touch-friendly mobile layout.
	if not _is_mobile_ui and event is InputEventScreenTouch:
		_is_mobile_ui = true
		_apply_responsive_layout()


func _build_ui() -> void:
	# ==================== TOP BAR ====================
	var top_margin := MarginContainer.new()
	top_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_margin.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_margin.add_theme_constant_override("margin_left", 14)
	top_margin.add_theme_constant_override("margin_right", 14)
	top_margin.add_theme_constant_override("margin_top", 10)
	add_child(top_margin)

	var top_vbox := VBoxContainer.new()
	top_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_vbox.add_theme_constant_override("separation", 8)
	top_margin.add_child(top_vbox)

	var top_row := HBoxContainer.new()
	top_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_row.add_theme_constant_override("separation", 10)
	top_vbox.add_child(top_row)

	# Left: Player Status Card
	var status_card := PanelContainer.new()
	status_card.add_theme_stylebox_override("panel", UiStyle.make_panel("#0f172a", 0.84, "#ffffff", 0.16, 16, 1, 12, 8))
	top_row.add_child(status_card)

	var st_hbox := HBoxContainer.new()
	st_hbox.add_theme_constant_override("separation", 10)
	status_card.add_child(st_hbox)

	_icon_box = PanelContainer.new()
	_icon_box.custom_minimum_size = Vector2(48, 48)
	_icon_box.add_theme_stylebox_override("panel", UiStyle.make_panel("#e11d48", 0.9, "#fde68a", 0.5, 12, 1, 4, 4))
	_char_icon_lbl = Label.new()
	_char_icon_lbl.text = "👘"
	_char_icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_char_icon_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_char_icon_lbl.add_theme_font_size_override("font_size", 24)
	_icon_box.add_child(_char_icon_lbl)
	st_hbox.add_child(_icon_box)

	_bars_box = VBoxContainer.new()
	_bars_box.custom_minimum_size = Vector2(185, 0)
	_bars_box.add_theme_constant_override("separation", 3)
	st_hbox.add_child(_bars_box)

	var name_row := HBoxContainer.new()
	_bars_box.add_child(name_row)
	_player_name_lbl = Label.new()
	_player_name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_player_name_lbl.add_theme_color_override("font_color", Color.html("#fcd34d"))
	name_row.add_child(_player_name_lbl)

	_level_lbl = Label.new()
	_level_lbl.add_theme_color_override("font_color", Color.html("#fde68a"))
	name_row.add_child(_level_lbl)

	# HP
	_hp_text_lbl = Label.new()
	_hp_text_lbl.add_theme_color_override("font_color", Color.html("#fecdd3"))
	_bars_box.add_child(_hp_text_lbl)
	_hp_bar = ProgressBar.new()
	UiStyle.apply_bar(_hp_bar, "#10b981", "#1e293b", 4)
	_bars_box.add_child(_hp_bar)

	# SP
	_sp_text_lbl = Label.new()
	_sp_text_lbl.add_theme_color_override("font_color", Color.html("#bae6fd"))
	_bars_box.add_child(_sp_text_lbl)
	_sp_bar = ProgressBar.new()
	UiStyle.apply_bar(_sp_bar, "#38bdf8", "#1e293b", 3)
	_bars_box.add_child(_sp_bar)

	# EXP
	_exp_bar = ProgressBar.new()
	_exp_bar.custom_minimum_size = Vector2(0, 5)
	UiStyle.apply_bar(_exp_bar, "#fbbf24", "#1e293b", 2)
	_bars_box.add_child(_exp_bar)

	# Center: Stage & Wave Info
	var center_spacer_l := Control.new()
	center_spacer_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_spacer_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_row.add_child(center_spacer_l)

	var stage_card := PanelContainer.new()
	stage_card.add_theme_stylebox_override("panel", UiStyle.make_panel("#0f172a", 0.84, "#ffffff", 0.16, 16, 1, 16, 8))
	top_row.add_child(stage_card)

	var stage_vbox := VBoxContainer.new()
	stage_vbox.add_theme_constant_override("separation", 2)
	stage_card.add_child(stage_vbox)

	_stage_lbl = Label.new()
	_stage_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stage_lbl.add_theme_color_override("font_color", Color.html("#fcd34d"))
	stage_vbox.add_child(_stage_lbl)

	var sub_row := HBoxContainer.new()
	sub_row.alignment = BoxContainer.ALIGNMENT_CENTER
	sub_row.add_theme_constant_override("separation", 12)
	stage_vbox.add_child(sub_row)

	_mode_lbl = Label.new()
	_mode_lbl.add_theme_color_override("font_color", Color.html("#fda4af"))
	sub_row.add_child(_mode_lbl)

	_enemy_count_lbl = Label.new()
	_enemy_count_lbl.add_theme_color_override("font_color", Color.html("#e2e8f0"))
	sub_row.add_child(_enemy_count_lbl)

	_endless_lbl = Label.new()
	_endless_lbl.add_theme_color_override("font_color", Color.html("#fcd34d"))
	_endless_lbl.visible = false
	sub_row.add_child(_endless_lbl)

	var center_spacer_r := Control.new()
	center_spacer_r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_spacer_r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_row.add_child(center_spacer_r)

	# Right: Currency & System Menu
	var menu_row := HBoxContainer.new()
	menu_row.add_theme_constant_override("separation", 8)
	top_row.add_child(menu_row)

	var cur_panel := PanelContainer.new()
	cur_panel.add_theme_stylebox_override("panel", UiStyle.make_panel("#0f172a", 0.84, "#ffffff", 0.16, 12, 1, 10, 6))
	var cur_hbox := HBoxContainer.new()
	cur_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	cur_hbox.add_theme_constant_override("separation", 10)
	cur_panel.add_child(cur_hbox)
	_gold_lbl = Label.new()
	_gold_lbl.add_theme_color_override("font_color", Color.html("#fcd34d"))
	cur_hbox.add_child(_gold_lbl)
	_sp_pts_lbl = Label.new()
	_sp_pts_lbl.add_theme_color_override("font_color", Color.html("#7dd3fc"))
	cur_hbox.add_child(_sp_pts_lbl)
	menu_row.add_child(cur_panel)

	var b_sk := _make_menu_btn("⚡ 技能", "#fbbf24", "#fcd34d", func() -> void: upgrade_requested.emit("skills"))
	var b_eq := _make_menu_btn("🎒 裝備", "#34d399", "#6ee7b7", func() -> void: upgrade_requested.emit("equip"))
	var b_sh := _make_menu_btn("🦊 式神", "#f472b6", "#f9a8d4", func() -> void: upgrade_requested.emit("shikigami"))
	var b_lb := _make_menu_btn("⛩️ 大廳", "#94a3b8", "#ffffff", func() -> void: lobby_requested.emit())
	_audio_btn = _make_menu_btn("🔊", "#94a3b8", "#ffffff", func() -> void: AudioManager.toggle_audio())

	_menu_buttons = [b_sk, b_eq, b_sh, b_lb]
	for mb in _menu_buttons:
		menu_row.add_child(mb)
	menu_row.add_child(_audio_btn)

	# Boss HP Bar (centered under top bar)
	var boss_center := CenterContainer.new()
	boss_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_vbox.add_child(boss_center)

	_boss_panel = PanelContainer.new()
	_boss_panel.visible = false
	_boss_panel.custom_minimum_size = Vector2(480, 0)
	_boss_panel.add_theme_stylebox_override("panel", UiStyle.make_panel("#0f172a", 0.88, "#f43f5e", 0.75, 16, 2, 16, 8))
	boss_center.add_child(_boss_panel)

	var boss_v := VBoxContainer.new()
	boss_v.add_theme_constant_override("separation", 4)
	_boss_panel.add_child(boss_v)

	var boss_h := HBoxContainer.new()
	boss_v.add_child(boss_h)
	_boss_name_lbl = Label.new()
	_boss_name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_boss_name_lbl.add_theme_color_override("font_color", Color.html("#fb7185"))
	boss_h.add_child(_boss_name_lbl)

	_boss_hp_lbl = Label.new()
	_boss_hp_lbl.add_theme_color_override("font_color", Color.WHITE)
	boss_h.add_child(_boss_hp_lbl)

	_boss_bar = ProgressBar.new()
	_boss_bar.custom_minimum_size = Vector2(0, 14)
	UiStyle.apply_bar(_boss_bar, "#e11d48", "#0f172a", 6)
	boss_v.add_child(_boss_bar)

	# ==================== TOAST ====================
	var toast_center := CenterContainer.new()
	toast_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_center.set_anchors_preset(Control.PRESET_TOP_WIDE)
	toast_center.offset_top = 118
	add_child(toast_center)

	_toast_panel = PanelContainer.new()
	_toast_panel.visible = false
	_toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_panel.add_theme_stylebox_override("panel", UiStyle.make_panel("#0f172a", 0.94, "#fbbf24", 0.75, 20, 2, 20, 8))
	_toast_lbl = Label.new()
	_toast_lbl.add_theme_font_size_override("font_size", 15)
	_toast_lbl.add_theme_color_override("font_color", Color.html("#fcd34d"))
	_toast_panel.add_child(_toast_lbl)
	toast_center.add_child(_toast_panel)

	# ==================== BOTTOM CONTROLS ====================
	_bot_margin = MarginContainer.new()
	_bot_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bot_margin.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_bot_margin.offset_top = -225
	_bot_margin.add_theme_constant_override("margin_left", 24)
	_bot_margin.add_theme_constant_override("margin_right", 24)
	_bot_margin.add_theme_constant_override("margin_bottom", 18)
	add_child(_bot_margin)

	var bot_row := HBoxContainer.new()
	bot_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bot_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_bot_margin.add_child(bot_row)

	# Left: 360 Joystick OR 4-Way D-Pad (Mobile / Touch ONLY)
	_left_ctrl = VBoxContainer.new()
	_left_ctrl.alignment = BoxContainer.ALIGNMENT_END
	_left_ctrl.add_theme_constant_override("separation", 10)
	bot_row.add_child(_left_ctrl)

	_joystick = VirtualJoystick.new()
	_joystick.vector_changed.connect(func(v: Vector2) -> void: joystick_changed.emit(v))
	_left_ctrl.add_child(_joystick)

	_dpad_grid = GridContainer.new()
	_dpad_grid.columns = 3
	_dpad_grid.visible = false
	_dpad_grid.add_theme_constant_override("h_separation", 6)
	_dpad_grid.add_theme_constant_override("v_separation", 6)
	_populate_dpad(_dpad_grid)
	_left_ctrl.add_child(_dpad_grid)

	_ctrl_toggle_btn = Button.new()
	_ctrl_toggle_btn.text = "🕹️ 輪盤 ⇄ 十字鍵"
	UiStyle.apply_button(_ctrl_toggle_btn, "#0f172a", "#fbbf24", "#fde68a", 16, 2, 0.88)
	_ctrl_toggle_btn.pressed.connect(_toggle_control_mode)
	_left_ctrl.add_child(_ctrl_toggle_btn)

	# Center: Combo Banner + Desktop Direct Input + Desktop Keyboard Hint
	var mid_vbox := VBoxContainer.new()
	mid_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid_vbox.alignment = BoxContainer.ALIGNMENT_END
	mid_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mid_vbox.add_theme_constant_override("separation", 6)
	bot_row.add_child(mid_vbox)

	var combo_center := CenterContainer.new()
	combo_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mid_vbox.add_child(combo_center)

	_combo_panel = PanelContainer.new()
	_combo_panel.visible = false
	_combo_panel.add_theme_stylebox_override("panel", UiStyle.make_panel("#e11d48", 0.95, "#fde68a", 0.8, 16, 1, 16, 5))
	_combo_lbl = Label.new()
	_combo_lbl.add_theme_font_size_override("font_size", 18)
	_combo_lbl.add_theme_color_override("font_color", Color.WHITE)
	_combo_panel.add_child(_combo_lbl)
	combo_center.add_child(_combo_panel)

	_direct_center = CenterContainer.new()
	_direct_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mid_vbox.add_child(_direct_center)

	var direct_panel := PanelContainer.new()
	direct_panel.add_theme_stylebox_override("panel", UiStyle.make_panel("#0f172a", 0.84, "#475569", 0.7, 14, 1, 10, 6))
	var direct_row := HBoxContainer.new()
	direct_row.add_theme_constant_override("separation", 8)
	direct_panel.add_child(direct_row)
	var direct_lbl := Label.new()
	direct_lbl.text = "日文感應："
	direct_lbl.add_theme_font_size_override("font_size", 12)
	direct_lbl.add_theme_color_override("font_color", Color.html("#cbd5e1"))
	direct_row.add_child(direct_lbl)

	_direct_input = LineEdit.new()
	_direct_input.custom_minimum_size = Vector2(250, 32)
	_direct_input.placeholder_text = "輸入 あ 攻擊，或 石頭/腳/雷光/冰結"
	UiStyle.apply_line_edit(_direct_input, "#64748b")
	_direct_input.text_changed.connect(_on_direct_input_changed)
	direct_row.add_child(_direct_input)
	_direct_center.add_child(direct_panel)

	_hint_lbl = Label.new()
	_hint_lbl.text = "拖曳畫面旋轉 3D 視角 ｜ WASD/方向鍵移動 ｜ J/あ 攻擊 ｜ 1/K 專屬技 ｜ 2/Q 奧義 ｜ Space 瞬步"
	_hint_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_lbl.add_theme_font_size_override("font_size", 11)
	_hint_lbl.add_theme_color_override("font_color", Color(0.82, 0.86, 0.92, 0.82))
	mid_vbox.add_child(_hint_lbl)

	# Right: Skill Row + Big Red 'あ' Attack Button
	_right_vbox = VBoxContainer.new()
	_right_vbox.alignment = BoxContainer.ALIGNMENT_END
	bot_row.add_child(_right_vbox)

	_skill_row = HBoxContainer.new()
	_skill_row.alignment = BoxContainer.ALIGNMENT_END
	_right_vbox.add_child(_skill_row)

	_btn_dash = Button.new()
	_btn_dash.text = "💨\n瞬步"
	_btn_dash.pressed.connect(func() -> void: dash_pressed.emit())
	_skill_row.add_child(_btn_dash)

	_btn_ult = Button.new()
	_btn_ult.text = "🌟\n全屏奧義\n70 SP"
	_btn_ult.pressed.connect(func() -> void: ult_skill_pressed.emit())
	_skill_row.add_child(_btn_ult)

	_btn_sig = Button.new()
	_btn_sig.pressed.connect(func() -> void: sig_skill_pressed.emit())
	_skill_row.add_child(_btn_sig)

	var atk_row := HBoxContainer.new()
	atk_row.alignment = BoxContainer.ALIGNMENT_END
	_right_vbox.add_child(atk_row)

	_btn_atk = Button.new()
	_btn_atk.text = "あ\n三段斬撃"
	_btn_atk.pressed.connect(func() -> void: attack_pressed.emit())
	atk_row.add_child(_btn_atk)


func _apply_responsive_layout() -> void:
	if _is_mobile_ui:
		# Mobile / Touch Mode: show large touch wheel, hide desktop keyboard hints, enlarge all buttons
		_left_ctrl.visible = true
		_direct_center.visible = false
		_hint_lbl.visible = false

		_bot_margin.offset_top = -315
		_bot_margin.add_theme_constant_override("margin_left", 28)
		_bot_margin.add_theme_constant_override("margin_right", 28)
		_bot_margin.add_theme_constant_override("margin_bottom", 22)

		_joystick.set_joystick_size(210.0)
		for cell in _dpad_cells:
			cell.custom_minimum_size = Vector2(68, 68)
		for db in _dpad_buttons:
			db.custom_minimum_size = Vector2(68, 68)
			db.add_theme_font_size_override("font_size", 24)
		_ctrl_toggle_btn.custom_minimum_size = Vector2(180, 42)
		_ctrl_toggle_btn.add_theme_font_size_override("font_size", 15)

		_right_vbox.add_theme_constant_override("separation", 14)
		_skill_row.add_theme_constant_override("separation", 14)

		_btn_dash.custom_minimum_size = Vector2(96, 96)
		_btn_dash.add_theme_font_size_override("font_size", 17)
		UiStyle.apply_button(_btn_dash, "#0f172a", "#38bdf8", "#7dd3fc", 20, 2, 0.92)

		_btn_ult.custom_minimum_size = Vector2(124, 96)
		_btn_ult.add_theme_font_size_override("font_size", 15)
		UiStyle.apply_button(_btn_ult, "#d97706", "#fde68a", "#ffffff", 20, 2, 0.96)

		_btn_sig.custom_minimum_size = Vector2(156, 96)
		_btn_sig.add_theme_font_size_override("font_size", 16)
		UiStyle.apply_button(_btn_sig, "#9333ea", "#f9a8d4", "#ffffff", 20, 2, 0.96)

		_btn_atk.custom_minimum_size = Vector2(168, 168)
		_btn_atk.add_theme_font_size_override("font_size", 30)
		UiStyle.apply_button(_btn_atk, "#dc2626", "#fcd34d", "#ffffff", 84, 4, 0.98)

		# Enlarge Top HUD & Menu Buttons for mobile legibility and thumb tapping
		_icon_box.custom_minimum_size = Vector2(56, 56)
		_char_icon_lbl.add_theme_font_size_override("font_size", 28)
		_bars_box.custom_minimum_size = Vector2(210, 0)
		_player_name_lbl.add_theme_font_size_override("font_size", 15)
		_level_lbl.add_theme_font_size_override("font_size", 14)
		_hp_text_lbl.add_theme_font_size_override("font_size", 13)
		_hp_bar.custom_minimum_size = Vector2(0, 11)
		_sp_text_lbl.add_theme_font_size_override("font_size", 13)
		_sp_bar.custom_minimum_size = Vector2(0, 9)

		_stage_lbl.add_theme_font_size_override("font_size", 16)
		_mode_lbl.add_theme_font_size_override("font_size", 13)
		_enemy_count_lbl.add_theme_font_size_override("font_size", 13)
		_endless_lbl.add_theme_font_size_override("font_size", 13)
		_gold_lbl.add_theme_font_size_override("font_size", 15)
		_sp_pts_lbl.add_theme_font_size_override("font_size", 15)
		_boss_name_lbl.add_theme_font_size_override("font_size", 15)
		_boss_hp_lbl.add_theme_font_size_override("font_size", 15)

		for mb in _menu_buttons:
			mb.custom_minimum_size = Vector2(86, 50)
			mb.add_theme_font_size_override("font_size", 16)
		_audio_btn.custom_minimum_size = Vector2(54, 50)
		_audio_btn.add_theme_font_size_override("font_size", 18)
	else:
		# Desktop Mode: hide mobile movement wheel completely!
		_left_ctrl.visible = false
		joystick_changed.emit(Vector2.ZERO)
		_direct_center.visible = true
		_hint_lbl.visible = true

		_bot_margin.offset_top = -225
		_bot_margin.add_theme_constant_override("margin_left", 20)
		_bot_margin.add_theme_constant_override("margin_right", 20)
		_bot_margin.add_theme_constant_override("margin_bottom", 16)

		_right_vbox.add_theme_constant_override("separation", 8)
		_skill_row.add_theme_constant_override("separation", 8)

		_btn_dash.custom_minimum_size = Vector2(66, 66)
		_btn_dash.add_theme_font_size_override("font_size", 12)
		UiStyle.apply_button(_btn_dash, "#0f172a", "#38bdf8", "#7dd3fc", 16, 2, 0.90)

		_btn_ult.custom_minimum_size = Vector2(84, 70)
		_btn_ult.add_theme_font_size_override("font_size", 11)
		UiStyle.apply_button(_btn_ult, "#d97706", "#fde68a", "#ffffff", 16, 2, 0.96)

		_btn_sig.custom_minimum_size = Vector2(104, 70)
		_btn_sig.add_theme_font_size_override("font_size", 12)
		UiStyle.apply_button(_btn_sig, "#9333ea", "#f9a8d4", "#ffffff", 16, 2, 0.96)

		_btn_atk.custom_minimum_size = Vector2(112, 112)
		_btn_atk.add_theme_font_size_override("font_size", 22)
		UiStyle.apply_button(_btn_atk, "#dc2626", "#fcd34d", "#ffffff", 56, 3, 0.98)

		_icon_box.custom_minimum_size = Vector2(46, 46)
		_char_icon_lbl.add_theme_font_size_override("font_size", 24)
		_bars_box.custom_minimum_size = Vector2(180, 0)
		_player_name_lbl.add_theme_font_size_override("font_size", 13)
		_level_lbl.add_theme_font_size_override("font_size", 12)
		_hp_text_lbl.add_theme_font_size_override("font_size", 10)
		_hp_bar.custom_minimum_size = Vector2(0, 8)
		_sp_text_lbl.add_theme_font_size_override("font_size", 10)
		_sp_bar.custom_minimum_size = Vector2(0, 6)

		_stage_lbl.add_theme_font_size_override("font_size", 14)
		_mode_lbl.add_theme_font_size_override("font_size", 11)
		_enemy_count_lbl.add_theme_font_size_override("font_size", 11)
		_endless_lbl.add_theme_font_size_override("font_size", 11)
		_gold_lbl.add_theme_font_size_override("font_size", 12)
		_sp_pts_lbl.add_theme_font_size_override("font_size", 12)
		_boss_name_lbl.add_theme_font_size_override("font_size", 13)
		_boss_hp_lbl.add_theme_font_size_override("font_size", 13)

		for mb in _menu_buttons:
			mb.custom_minimum_size = Vector2(72, 38)
			mb.add_theme_font_size_override("font_size", 13)
		_audio_btn.custom_minimum_size = Vector2(46, 38)
		_audio_btn.add_theme_font_size_override("font_size", 14)


func _make_menu_btn(label: String, border_hex: String, text_hex: String, cb: Callable) -> Button:
	var btn := Button.new()
	btn.text = label
	UiStyle.apply_button(btn, "#0f172a", border_hex, text_hex, 12, 1, 0.88)
	btn.pressed.connect(cb)
	return btn


func _populate_dpad(grid: GridContainer) -> void:
	var cells := [
		["", Vector2.ZERO], ["▲", Vector2(0, -1)], ["", Vector2.ZERO],
		["◀", Vector2(-1, 0)], ["移動", Vector2.ZERO], ["▶", Vector2(1, 0)],
		["", Vector2.ZERO], ["▼", Vector2(0, 1)], ["", Vector2.ZERO],
	]
	for cell in cells:
		var lbl: String = cell[0]
		var vec: Vector2 = cell[1]
		if lbl.is_empty():
			var empty := Control.new()
			empty.custom_minimum_size = Vector2(68, 68)
			grid.add_child(empty)
			_dpad_cells.append(empty)
		elif vec == Vector2.ZERO:
			var mid := Label.new()
			mid.text = lbl
			mid.custom_minimum_size = Vector2(68, 68)
			mid.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			mid.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			mid.add_theme_font_size_override("font_size", 14)
			mid.add_theme_color_override("font_color", Color.html("#94a3b8"))
			grid.add_child(mid)
			_dpad_cells.append(mid)
		else:
			var b := Button.new()
			b.text = lbl
			b.custom_minimum_size = Vector2(68, 68)
			UiStyle.apply_button(b, "#0f172a", "#fbbf24", "#fcd34d", 14, 2, 0.90)
			b.button_down.connect(func() -> void: joystick_changed.emit(vec))
			b.button_up.connect(func() -> void: joystick_changed.emit(Vector2.ZERO))
			grid.add_child(b)
			_dpad_buttons.append(b)


func _toggle_control_mode() -> void:
	_is_dpad_mode = not _is_dpad_mode
	_joystick.visible = not _is_dpad_mode
	_dpad_grid.visible = _is_dpad_mode
	joystick_changed.emit(Vector2.ZERO)
	_ctrl_toggle_btn.text = "➕ 十字鍵 ⇄ 輪盤" if _is_dpad_mode else "🕹️ 輪盤 ⇄ 十字鍵"


func _on_direct_input_changed(new_text: String) -> void:
	var val := new_text.strip_edges()
	if val.is_empty():
		return
	if val.contains("あ") or val.to_lower().contains("a"):
		_direct_input.text = ""
		attack_pressed.emit()
	elif val.contains("石頭") or val.contains("腳") or val.contains("火") or val.contains("雷") or val.contains("冰"):
		_direct_input.text = ""
		sig_skill_pressed.emit()
	elif val.contains("奧義") or val.contains("必殺"):
		_direct_input.text = ""
		ult_skill_pressed.emit()


func refresh(enemy_count: int, boss: Enemy3D) -> void:
	var p := GameState.player
	var b := GameState.battle
	var char_cfg: Dictionary = GameData.get_character(p["char_id"])
	var stage_cfg: Dictionary = GameData.get_stage(p["stage_id"])
	var mode_cfg: Dictionary = GameData.get_mode(p["mode"])

	_char_icon_lbl.text = char_cfg["icon"]
	_player_name_lbl.text = String(p["name"])
	_level_lbl.text = "Lv.%d" % int(p["level"])

	_hp_text_lbl.text = "HP  %d / %d" % [int(b["hp"]), int(b["max_hp"])]
	_hp_bar.max_value = maxf(1.0, float(b["max_hp"]))
	_hp_bar.value = float(b["hp"])

	_sp_text_lbl.text = "言霊 SP  %d / %d" % [int(floor(float(b["sp"]))), int(b["max_sp"])]
	_sp_bar.max_value = float(b["max_sp"])
	_sp_bar.value = float(b["sp"])

	var exp_need := GameState.get_exp_to_next_level(int(p["level"]))
	_exp_bar.max_value = 100.0
	_exp_bar.value = 100.0 if int(p["level"]) >= GameData.MAX_LEVEL else minf(100.0, (float(p["exp"]) / float(exp_need)) * 100.0)

	_stage_lbl.text = "%s %s  |  第 %d 幕" % [stage_cfg["icon"], stage_cfg["name"], int(b["wave"])]
	_mode_lbl.text = mode_cfg["label"]
	_enemy_count_lbl.text = "👹 剩餘: %d" % enemy_count

	_endless_lbl.visible = GameState.is_endless_mode()
	if _endless_lbl.visible:
		var secs := int(floor(float(b["endless_seconds"])))
		_endless_lbl.text = "⏱️ %02d:%02d" % [secs / 60, secs % 60]

	_gold_lbl.text = "🪙 %d" % int(p["gold"])
	_sp_pts_lbl.text = "✨ %dpt" % int(p["skill_points"])

	_btn_sig.text = "%s %s\n%s (30SP)" % [char_cfg["sig_icon"], char_cfg["sig_key"], char_cfg["sig_name"]]
	_btn_sig.disabled = float(b["sp"]) < 30.0
	_btn_ult.disabled = float(b["sp"]) < 70.0

	if int(b["combo"]) >= 2:
		_combo_panel.visible = true
		_combo_lbl.text = "⚔️ %d HITS!" % int(b["combo"])
	else:
		_combo_panel.visible = false

	if boss != null and is_instance_valid(boss) and not boss.dead:
		_boss_panel.visible = true
		_boss_name_lbl.text = "👹 大頭目・%s" % boss.enemy_name
		_boss_hp_lbl.text = "%d / %d" % [maxi(0, boss.hp), boss.max_hp]
		_boss_bar.max_value = maxf(1.0, float(boss.max_hp))
		_boss_bar.value = float(maxi(0, boss.hp))
	else:
		_boss_panel.visible = false


func show_toast(msg: String) -> void:
	_toast_lbl.text = msg
	_toast_panel.visible = true
	_toast_timer = 2.6


func _process(delta: float) -> void:
	if _toast_timer > 0.0:
		_toast_timer -= delta
		if _toast_timer <= 0.0:
			_toast_panel.visible = false
