class_name HudUI
extends Control
## Genshin-inspired Wafuu Luminous Glass HUD:
## - Desktop: clean top floating pills, bottom-center HP/SP/EXP bar, glowing circular E/Q/Attack orbs,
##   and center CrosshairReticle (mobile movement wheel hidden).
## - Mobile/Touch: enlarged top status card, 360° joystick/D-Pad, and extra-large circular action orbs.

signal attack_pressed
signal jump_pressed
signal dash_pressed
signal sig_skill_pressed
signal ult_skill_pressed
signal upgrade_requested(tab: String)
signal pause_requested
signal joystick_changed(vec: Vector2)

var _is_mobile_ui: bool = false

# Top HUD references
var _stage_card: PanelContainer
var _stage_lbl: Label
var _mode_lbl: Label
var _enemy_count_lbl: Label
var _endless_lbl: Label
var _stage_mech_lbl: Label

var _gold_lbl: Label
var _sp_pts_lbl: Label
var _menu_buttons: Array[Button] = []
var _audio_btn: Button

var _boss_panel: PanelContainer
var _boss_name_lbl: Label
var _boss_hp_lbl: Label
var _boss_bar: ProgressBar

# Player Status Card (placed top-left on Mobile, bottom-center Genshin-style on Desktop!)
var _status_card: PanelContainer
var _mobile_status_slot: HBoxContainer
var _desktop_status_slot: CenterContainer
var _icon_box: PanelContainer
var _char_icon_lbl: Label
var _bars_box: VBoxContainer
var _player_name_lbl: Label
var _level_lbl: Label
var _hp_text_lbl: Label
var _hp_bar: ProgressBar
var _sp_text_lbl: Label
var _sp_bar: ProgressBar
var _stamina_text_lbl: Label
var _stamina_bar: ProgressBar
var _exp_bar: ProgressBar
var _stamina_low_state: bool = false

# Genshin-style Floating Action Stamina Bar (appears while sprinting/dashing/recovering)
var _floating_sta_panel: PanelContainer
var _floating_sta_bar: ProgressBar
var _floating_sta_lbl: Label

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
var _hint_panel: PanelContainer
var _hint_lbl: Label

var _right_vbox: VBoxContainer
var _skill_row: HBoxContainer
var _btn_jump: Button
var _btn_dash: Button
var _btn_ult: Button
var _btn_sig: Button
var _btn_atk: Button

# Toast & Desktop Crosshair / Mouse-Lock Hint
var _toast_panel: PanelContainer
var _toast_lbl: Label
var _toast_timer: float = 0.0
var _last_combo: int = 0
var _boss_was_visible: bool = false
var _last_char_id: String = ""
var _crosshair: CrosshairReticle
var _lock_hint_panel: PanelContainer
var _lock_hint_lbl: Label


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


func is_mobile_mode() -> bool:
	return _is_mobile_ui


func set_mouse_lock_ui(is_locked: bool, show_crosshair: bool, show_unlock_hint: bool) -> void:
	if _crosshair != null:
		_crosshair.visible = (not _is_mobile_ui) and show_crosshair
		_crosshair.set_locked_state(is_locked)
	if _lock_hint_panel != null:
		_lock_hint_panel.visible = (not _is_mobile_ui) and show_unlock_hint and (not is_locked)


func trigger_crosshair_bloom(step: int) -> void:
	if _crosshair != null and _crosshair.visible:
		_crosshair.trigger_bloom(step)


func trigger_crosshair_hit(is_crit: bool) -> void:
	if _crosshair != null and _crosshair.visible:
		_crosshair.trigger_hit_marker(is_crit)


func _input(event: InputEvent) -> void:
	if not _is_mobile_ui and event is InputEventScreenTouch:
		_is_mobile_ui = true
		_apply_responsive_layout()


func _build_ui() -> void:
	# ==================== DESKTOP CENTER CROSSHAIR ====================
	_crosshair = CrosshairReticle.new()
	_crosshair.visible = not _is_mobile_ui
	add_child(_crosshair)

	var lock_center := CenterContainer.new()
	lock_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lock_center.anchor_left = 0.0
	lock_center.anchor_right = 1.0
	lock_center.anchor_top = 0.56
	lock_center.anchor_bottom = 0.56
	add_child(lock_center)

	_lock_hint_panel = PanelContainer.new()
	_lock_hint_panel.visible = false
	_lock_hint_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lock_hint_panel.add_theme_stylebox_override("panel", UiStyle.make_pill("#090e1d", 0.86, "#e8c474", 0.72, 18, 7))
	_lock_hint_lbl = Label.new()
	_lock_hint_lbl.text = "點擊畫面鎖定視角與準心 ｜ Esc 暫停"
	_lock_hint_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lock_hint_lbl.add_theme_font_size_override("font_size", 13)
	_lock_hint_lbl.add_theme_color_override("font_color", Color.html("#fef3c7"))
	_lock_hint_panel.add_child(_lock_hint_lbl)
	lock_center.add_child(_lock_hint_panel)

	# Dynamic Genshin-style Floating Action Stamina Bar (auto-appears when sprinting/dashing!)
	var sta_float_center := CenterContainer.new()
	sta_float_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sta_float_center.anchor_left = 0.0
	sta_float_center.anchor_right = 1.0
	sta_float_center.anchor_top = 0.63
	sta_float_center.anchor_bottom = 0.63
	add_child(sta_float_center)

	_floating_sta_panel = PanelContainer.new()
	_floating_sta_panel.visible = false
	_floating_sta_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_floating_sta_panel.add_theme_stylebox_override("panel", UiStyle.make_pill("#090e1d", 0.80, "#f59e0b", 0.55, 12, 5))
	var sta_float_row := HBoxContainer.new()
	sta_float_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sta_float_row.add_theme_constant_override("separation", 8)
	_floating_sta_panel.add_child(sta_float_row)
	_floating_sta_lbl = Label.new()
	_floating_sta_lbl.text = "體力"
	_floating_sta_lbl.add_theme_font_size_override("font_size", 11)
	_floating_sta_lbl.add_theme_color_override("font_color", Color.html("#fde68a"))
	sta_float_row.add_child(_floating_sta_lbl)
	_floating_sta_bar = ProgressBar.new()
	_floating_sta_bar.custom_minimum_size = Vector2(130, 8)
	_floating_sta_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	UiStyle.apply_bar(_floating_sta_bar, "#f59e0b", "#141008", 4, "#fde68a", 0.35)
	sta_float_row.add_child(_floating_sta_bar)
	sta_float_center.add_child(_floating_sta_panel)

	# ==================== TOP FLOATING BAR ====================
	var top_margin := MarginContainer.new()
	top_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_margin.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top_margin.add_theme_constant_override("margin_left", 18)
	top_margin.add_theme_constant_override("margin_right", 18)
	top_margin.add_theme_constant_override("margin_top", 14)
	add_child(top_margin)

	var top_vbox := VBoxContainer.new()
	top_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_vbox.add_theme_constant_override("separation", 10)
	top_margin.add_child(top_vbox)

	var top_row := HBoxContainer.new()
	top_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_row.add_theme_constant_override("separation", 10)
	top_vbox.add_child(top_row)

	# Top-Left Slot: Mobile Status Card (when mobile) + Sleek Stage/Wave Pill
	var top_left := HBoxContainer.new()
	top_left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_left.add_theme_constant_override("separation", 10)
	top_row.add_child(top_left)

	_mobile_status_slot = HBoxContainer.new()
	_mobile_status_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_left.add_child(_mobile_status_slot)

	_stage_card = PanelContainer.new()
	_stage_card.add_theme_stylebox_override("panel", UiStyle.make_accent_card("#090f1f", "#e8c474", false, 16, 16, 8))
	top_left.add_child(_stage_card)

	var stage_vbox := VBoxContainer.new()
	stage_vbox.add_theme_constant_override("separation", 2)
	_stage_card.add_child(stage_vbox)

	_stage_lbl = Label.new()
	_stage_lbl.add_theme_color_override("font_color", Color.html("#fef3c7"))
	UiStyle.style_label_shadow(_stage_lbl, 0.72)
	stage_vbox.add_child(_stage_lbl)

	var sub_row := HBoxContainer.new()
	sub_row.add_theme_constant_override("separation", 10)
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

	_stage_mech_lbl = Label.new()
	_stage_mech_lbl.add_theme_font_size_override("font_size", 11)
	_stage_mech_lbl.add_theme_color_override("font_color", Color.html("#fde68a"))
	stage_vbox.add_child(_stage_mech_lbl)

	var top_spacer := Control.new()
	top_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_row.add_child(top_spacer)

	# Top-Right: Translucent Currency Pill + Compact Wafuu Glass Buttons
	var menu_row := HBoxContainer.new()
	menu_row.add_theme_constant_override("separation", 7)
	top_row.add_child(menu_row)

	var cur_panel := PanelContainer.new()
	cur_panel.add_theme_stylebox_override("panel", UiStyle.make_pill("#090f1f", 0.84, "#e8c474", 0.44, 14, 7))
	var cur_hbox := HBoxContainer.new()
	cur_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	cur_hbox.add_theme_constant_override("separation", 12)
	cur_panel.add_child(cur_hbox)
	_gold_lbl = Label.new()
	_gold_lbl.add_theme_color_override("font_color", Color.html("#fcd34d"))
	cur_hbox.add_child(_gold_lbl)
	_sp_pts_lbl = Label.new()
	_sp_pts_lbl.add_theme_color_override("font_color", Color.html("#7dd3fc"))
	cur_hbox.add_child(_sp_pts_lbl)
	menu_row.add_child(cur_panel)

	var b_sk := _make_menu_btn("⚡ 技能", "#e8c474", "#fef3c7", func() -> void: upgrade_requested.emit("skills"))
	var b_eq := _make_menu_btn("🎒 裝備", "#34d399", "#a7f3d0", func() -> void: upgrade_requested.emit("equip"))
	var b_sh := _make_menu_btn("🦊 式神", "#f472b6", "#fbcfe8", func() -> void: upgrade_requested.emit("shikigami"))
	var b_dc := _make_menu_btn("📖 辭典", "#38bdf8", "#bae6fd", func() -> void: upgrade_requested.emit("dict"))
	var b_ps := _make_menu_btn("⏸️ 暫停", "#cbd5e1", "#ffffff", func() -> void: pause_requested.emit())
	_audio_btn = _make_menu_btn("🔊", "#cbd5e1", "#ffffff", func() -> void: AudioManager.toggle_audio())

	_menu_buttons = [b_sk, b_eq, b_sh, b_dc, b_ps]
	for mb in _menu_buttons:
		menu_row.add_child(mb)
	menu_row.add_child(_audio_btn)

	# ==================== GENSHIN-STYLE BOSS HP BAR ====================
	var boss_center := CenterContainer.new()
	boss_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_vbox.add_child(boss_center)

	_boss_panel = PanelContainer.new()
	_boss_panel.visible = false
	_boss_panel.custom_minimum_size = Vector2(560, 0)
	_boss_panel.add_theme_stylebox_override("panel", UiStyle.make_shrine_modal("#120916", "#fb7185", 18, 22, 11))
	boss_center.add_child(_boss_panel)

	var boss_v := VBoxContainer.new()
	boss_v.add_theme_constant_override("separation", 5)
	_boss_panel.add_child(boss_v)

	var boss_h := HBoxContainer.new()
	boss_v.add_child(boss_h)
	_boss_name_lbl = Label.new()
	_boss_name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_boss_name_lbl.add_theme_color_override("font_color", Color.html("#fecdd3"))
	UiStyle.style_label_shadow(_boss_name_lbl, 0.78, 1)
	boss_h.add_child(_boss_name_lbl)

	_boss_hp_lbl = Label.new()
	_boss_hp_lbl.add_theme_color_override("font_color", Color.html("#fef3c7"))
	UiStyle.style_label_shadow(_boss_hp_lbl, 0.72)
	boss_h.add_child(_boss_hp_lbl)

	_boss_bar = ProgressBar.new()
	_boss_bar.custom_minimum_size = Vector2(0, 14)
	UiStyle.apply_bar(_boss_bar, "#e11d48", "#180b16", 6, "#fda4af", 0.50)
	boss_v.add_child(_boss_bar)

	# ==================== PLAYER STATUS CARD (Reparented by Platform) ====================
	_status_card = _build_status_card()

	# ==================== TOAST ====================
	var toast_center := CenterContainer.new()
	toast_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_center.set_anchors_preset(Control.PRESET_TOP_WIDE)
	toast_center.offset_top = 128
	add_child(toast_center)

	_toast_panel = PanelContainer.new()
	_toast_panel.visible = false
	_toast_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_panel.add_theme_stylebox_override("panel", UiStyle.make_pill("#090e1d", 0.92, "#e8c474", 0.80, 22, 8))
	_toast_lbl = Label.new()
	_toast_lbl.add_theme_font_size_override("font_size", 15)
	_toast_lbl.add_theme_color_override("font_color", Color.html("#fef3c7"))
	_toast_panel.add_child(_toast_lbl)
	toast_center.add_child(_toast_panel)

	# ==================== BOTTOM CONTROLS ====================
	_bot_margin = MarginContainer.new()
	_bot_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bot_margin.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_bot_margin.offset_top = -245
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
	_left_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_left_ctrl.alignment = BoxContainer.ALIGNMENT_END
	_left_ctrl.add_theme_constant_override("separation", 10)
	bot_row.add_child(_left_ctrl)

	_joystick = VirtualJoystick.new()
	_joystick.vector_changed.connect(func(v: Vector2) -> void: joystick_changed.emit(v))
	_left_ctrl.add_child(_joystick)

	_dpad_grid = GridContainer.new()
	_dpad_grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dpad_grid.columns = 3
	_dpad_grid.visible = false
	_dpad_grid.add_theme_constant_override("h_separation", 6)
	_dpad_grid.add_theme_constant_override("v_separation", 6)
	_populate_dpad(_dpad_grid)
	_left_ctrl.add_child(_dpad_grid)

	_ctrl_toggle_btn = Button.new()
	_ctrl_toggle_btn.focus_mode = Control.FOCUS_NONE
	_ctrl_toggle_btn.text = "🕹️ 輪盤 ⇄ 十字鍵"
	UiStyle.apply_button(_ctrl_toggle_btn, "#0a0f1f", "#e6c37a", "#fef3c7", 18, 2, 0.88)
	_ctrl_toggle_btn.pressed.connect(_toggle_control_mode)
	_left_ctrl.add_child(_ctrl_toggle_btn)

	# Center: Combo Pill + Genshin Bottom-Center HP/SP/EXP Status Card + Slim Keybind Legend
	var mid_vbox := VBoxContainer.new()
	mid_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid_vbox.alignment = BoxContainer.ALIGNMENT_END
	mid_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mid_vbox.add_theme_constant_override("separation", 7)
	bot_row.add_child(mid_vbox)

	var combo_center := CenterContainer.new()
	combo_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mid_vbox.add_child(combo_center)

	_combo_panel = PanelContainer.new()
	_combo_panel.visible = false
	_combo_panel.add_theme_stylebox_override("panel", UiStyle.make_pill("#be123c", 0.94, "#fde68a", 0.88, 18, 5))
	_combo_lbl = Label.new()
	_combo_lbl.add_theme_font_size_override("font_size", 18)
	_combo_lbl.add_theme_color_override("font_color", Color.WHITE)
	_combo_panel.add_child(_combo_lbl)
	combo_center.add_child(_combo_panel)

	_desktop_status_slot = CenterContainer.new()
	_desktop_status_slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mid_vbox.add_child(_desktop_status_slot)

	var hint_center := CenterContainer.new()
	hint_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mid_vbox.add_child(hint_center)

	_hint_panel = PanelContainer.new()
	_hint_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint_panel.add_theme_stylebox_override("panel", UiStyle.make_pill("#090d1a", 0.64, "#e6c37a", 0.24, 14, 4))
	_hint_lbl = Label.new()
	_hint_lbl.text = "滑鼠轉視角 ｜ 左鍵 斬撃 ｜ Space 跳躍 ｜ Shift 急跑 / 兩下衝刺 ｜ E 專屬技 ｜ Q 奧義 ｜ Esc 暫停"
	_hint_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint_lbl.add_theme_font_size_override("font_size", 11)
	_hint_lbl.add_theme_color_override("font_color", Color(0.88, 0.90, 0.95, 0.88))
	_hint_panel.add_child(_hint_lbl)
	hint_center.add_child(_hint_panel)

	# Right: Genshin-Style Circular Skill Orbs + Luminous 'あ' Attack Orb
	_right_vbox = VBoxContainer.new()
	_right_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_right_vbox.alignment = BoxContainer.ALIGNMENT_END
	bot_row.add_child(_right_vbox)

	_skill_row = HBoxContainer.new()
	_skill_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_skill_row.alignment = BoxContainer.ALIGNMENT_END
	_right_vbox.add_child(_skill_row)

	_btn_jump = Button.new()
	_btn_jump.focus_mode = Control.FOCUS_NONE
	_btn_jump.pressed.connect(func() -> void: jump_pressed.emit())
	_skill_row.add_child(_btn_jump)

	_btn_dash = Button.new()
	_btn_dash.focus_mode = Control.FOCUS_NONE
	_btn_dash.pressed.connect(func() -> void: dash_pressed.emit())
	_skill_row.add_child(_btn_dash)

	_btn_sig = Button.new()
	_btn_sig.focus_mode = Control.FOCUS_NONE
	_btn_sig.pressed.connect(func() -> void: sig_skill_pressed.emit())
	_skill_row.add_child(_btn_sig)

	_btn_ult = Button.new()
	_btn_ult.focus_mode = Control.FOCUS_NONE
	_btn_ult.pressed.connect(func() -> void: ult_skill_pressed.emit())
	_skill_row.add_child(_btn_ult)

	var atk_row := HBoxContainer.new()
	atk_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	atk_row.alignment = BoxContainer.ALIGNMENT_END
	_right_vbox.add_child(atk_row)

	_btn_atk = Button.new()
	_btn_atk.focus_mode = Control.FOCUS_NONE
	_btn_atk.pressed.connect(func() -> void: attack_pressed.emit())
	atk_row.add_child(_btn_atk)


func _build_status_card() -> PanelContainer:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UiStyle.make_panel("#0a0f1f", 0.80, "#e6c37a", 0.44, 18, 1, 14, 9, 14))

	var st_hbox := HBoxContainer.new()
	st_hbox.add_theme_constant_override("separation", 12)
	card.add_child(st_hbox)

	_icon_box = PanelContainer.new()
	_icon_box.custom_minimum_size = Vector2(46, 46)
	_icon_box.add_theme_stylebox_override("panel", UiStyle.make_panel("#be123c", 0.92, "#fde68a", 0.72, 23, 2, 2, 2, 8))
	_char_icon_lbl = Label.new()
	_char_icon_lbl.text = "👘"
	_char_icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_char_icon_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_icon_box.add_child(_char_icon_lbl)
	st_hbox.add_child(_icon_box)

	_bars_box = VBoxContainer.new()
	_bars_box.add_theme_constant_override("separation", 3)
	st_hbox.add_child(_bars_box)

	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 8)
	_bars_box.add_child(name_row)

	_player_name_lbl = Label.new()
	_player_name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_player_name_lbl.add_theme_color_override("font_color", Color.html("#fef3c7"))
	name_row.add_child(_player_name_lbl)

	_level_lbl = Label.new()
	_level_lbl.add_theme_color_override("font_color", Color.html("#fcd34d"))
	name_row.add_child(_level_lbl)

	# HP row
	var hp_row := HBoxContainer.new()
	hp_row.add_theme_constant_override("separation", 8)
	_bars_box.add_child(hp_row)
	_hp_bar = ProgressBar.new()
	_hp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hp_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	UiStyle.apply_bar(_hp_bar, "#22c55e", "#09121a", 5, "#4ade80", 0.28)
	hp_row.add_child(_hp_bar)
	_hp_text_lbl = Label.new()
	_hp_text_lbl.add_theme_color_override("font_color", Color.html("#d1fae5"))
	hp_row.add_child(_hp_text_lbl)

	# SP row
	var sp_row := HBoxContainer.new()
	sp_row.add_theme_constant_override("separation", 8)
	_bars_box.add_child(sp_row)
	_sp_bar = ProgressBar.new()
	_sp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sp_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	UiStyle.apply_bar(_sp_bar, "#38bdf8", "#091220", 4, "#7dd3fc", 0.28)
	sp_row.add_child(_sp_bar)
	_sp_text_lbl = Label.new()
	_sp_text_lbl.add_theme_color_override("font_color", Color.html("#bae6fd"))
	sp_row.add_child(_sp_text_lbl)

	# Stamina (體力) row
	var sta_row := HBoxContainer.new()
	sta_row.add_theme_constant_override("separation", 8)
	_bars_box.add_child(sta_row)
	_stamina_bar = ProgressBar.new()
	_stamina_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stamina_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	UiStyle.apply_bar(_stamina_bar, "#f59e0b", "#141008", 4, "#fde68a", 0.30)
	sta_row.add_child(_stamina_bar)
	_stamina_text_lbl = Label.new()
	_stamina_text_lbl.add_theme_color_override("font_color", Color.html("#fde68a"))
	sta_row.add_child(_stamina_text_lbl)

	# EXP hairline
	_exp_bar = ProgressBar.new()
	_exp_bar.custom_minimum_size = Vector2(0, 4)
	UiStyle.apply_bar(_exp_bar, "#fbbf24", "#111827", 2, "#fde68a", 0.16)
	_bars_box.add_child(_exp_bar)

	return card


func _reparent_status_card(to_mobile: bool) -> void:
	if _status_card == null:
		return
	var target_parent: Node = _mobile_status_slot if to_mobile else _desktop_status_slot
	if _status_card.get_parent() == target_parent:
		return
	if _status_card.get_parent() != null:
		_status_card.get_parent().remove_child(_status_card)
	target_parent.add_child(_status_card)


func _apply_responsive_layout() -> void:
	_reparent_status_card(_is_mobile_ui)
	if _is_mobile_ui:
		# Mobile / Touch Mode: enlarged thumb-friendly layout
		if _crosshair != null:
			_crosshair.visible = false
		if _lock_hint_panel != null:
			_lock_hint_panel.visible = false
		_left_ctrl.visible = true
		_hint_panel.visible = false

		_bot_margin.offset_top = -425
		_bot_margin.add_theme_constant_override("margin_left", 28)
		_bot_margin.add_theme_constant_override("margin_right", 28)
		_bot_margin.add_theme_constant_override("margin_bottom", 20)

		_joystick.set_joystick_size(268.0)
		for cell in _dpad_cells:
			cell.custom_minimum_size = Vector2(90, 90)
		for db in _dpad_buttons:
			db.custom_minimum_size = Vector2(90, 90)
			db.add_theme_font_size_override("font_size", 32)
		_ctrl_toggle_btn.custom_minimum_size = Vector2(220, 52)
		_ctrl_toggle_btn.add_theme_font_size_override("font_size", 18)

		_right_vbox.add_theme_constant_override("separation", 16)
		_skill_row.add_theme_constant_override("separation", 12)

		_btn_jump.text = "▲\n跳躍"
		_btn_jump.add_theme_font_size_override("font_size", 20)
		UiStyle.apply_orb_button(_btn_jump, "#0f2419", "#34d399", "#a7f3d0", 118.0, 3, 0.92)

		_btn_dash.text = "💨\n衝刺"
		_btn_dash.add_theme_font_size_override("font_size", 20)
		UiStyle.apply_orb_button(_btn_dash, "#0d1b2a", "#38bdf8", "#bae6fd", 118.0, 3, 0.92)

		_btn_sig.add_theme_font_size_override("font_size", 18)
		UiStyle.apply_orb_button(_btn_sig, "#581c87", "#f0abfc", "#ffffff", 136.0, 3, 0.95)

		_btn_ult.text = "🌟\n奧義\n70SP"
		_btn_ult.add_theme_font_size_override("font_size", 18)
		UiStyle.apply_orb_button(_btn_ult, "#b45309", "#fde68a", "#ffffff", 136.0, 3, 0.96)

		_btn_atk.text = "あ\n斬撃"
		_btn_atk.add_theme_font_size_override("font_size", 42)
		UiStyle.apply_orb_button(_btn_atk, "#be123c", "#fde68a", "#ffffff", 236.0, 5, 0.98)

		_icon_box.custom_minimum_size = Vector2(62, 62)
		_char_icon_lbl.add_theme_font_size_override("font_size", 30)
		_bars_box.custom_minimum_size = Vector2(246, 0)
		_player_name_lbl.add_theme_font_size_override("font_size", 17)
		_level_lbl.add_theme_font_size_override("font_size", 16)
		_hp_text_lbl.add_theme_font_size_override("font_size", 14)
		_hp_bar.custom_minimum_size = Vector2(0, 11)
		_sp_text_lbl.add_theme_font_size_override("font_size", 14)
		_sp_bar.custom_minimum_size = Vector2(0, 9)
		_stamina_text_lbl.add_theme_font_size_override("font_size", 13)
		_stamina_bar.custom_minimum_size = Vector2(0, 9)

		_stage_lbl.add_theme_font_size_override("font_size", 18)
		_mode_lbl.add_theme_font_size_override("font_size", 15)
		_enemy_count_lbl.add_theme_font_size_override("font_size", 15)
		_endless_lbl.add_theme_font_size_override("font_size", 15)
		_gold_lbl.add_theme_font_size_override("font_size", 17)
		_sp_pts_lbl.add_theme_font_size_override("font_size", 17)
		_boss_name_lbl.add_theme_font_size_override("font_size", 17)
		_boss_hp_lbl.add_theme_font_size_override("font_size", 17)

		for mb in _menu_buttons:
			mb.custom_minimum_size = Vector2(104, 62)
			mb.add_theme_font_size_override("font_size", 18)
		_audio_btn.custom_minimum_size = Vector2(66, 62)
		_audio_btn.add_theme_font_size_override("font_size", 22)
	else:
		# Desktop Mode: Genshin-style bottom-center status bar + glowing circular orbs!
		if _crosshair != null:
			_crosshair.visible = true
		_left_ctrl.visible = false
		joystick_changed.emit(Vector2.ZERO)
		_hint_panel.visible = true

		_bot_margin.offset_top = -230
		_bot_margin.add_theme_constant_override("margin_left", 24)
		_bot_margin.add_theme_constant_override("margin_right", 24)
		_bot_margin.add_theme_constant_override("margin_bottom", 18)

		_right_vbox.add_theme_constant_override("separation", 10)
		_skill_row.add_theme_constant_override("separation", 8)

		_btn_jump.text = "▲\n跳躍\nSpace"
		_btn_jump.add_theme_font_size_override("font_size", 10)
		UiStyle.apply_orb_button(_btn_jump, "#0f2419", "#34d399", "#a7f3d0", 68.0, 2, 0.90)

		_btn_dash.text = "💨\n衝刺\n2×Shift"
		_btn_dash.add_theme_font_size_override("font_size", 10)
		UiStyle.apply_orb_button(_btn_dash, "#0d1b2a", "#38bdf8", "#bae6fd", 74.0, 2, 0.90)

		_btn_sig.add_theme_font_size_override("font_size", 11)
		UiStyle.apply_orb_button(_btn_sig, "#581c87", "#f0abfc", "#ffffff", 84.0, 2, 0.94)

		_btn_ult.text = "🌟 [Q]\n奧義\n70SP"
		_btn_ult.add_theme_font_size_override("font_size", 11)
		UiStyle.apply_orb_button(_btn_ult, "#b45309", "#fde68a", "#ffffff", 84.0, 2, 0.95)

		_btn_atk.text = "あ\n左鍵"
		_btn_atk.add_theme_font_size_override("font_size", 20)
		UiStyle.apply_orb_button(_btn_atk, "#be123c", "#fde68a", "#ffffff", 104.0, 3, 0.97)

		# Sleek bottom-center Genshin HP/SP/Stamina/EXP card
		_icon_box.custom_minimum_size = Vector2(48, 48)
		_char_icon_lbl.add_theme_font_size_override("font_size", 24)
		_bars_box.custom_minimum_size = Vector2(320, 0)
		_player_name_lbl.add_theme_font_size_override("font_size", 13)
		_level_lbl.add_theme_font_size_override("font_size", 12)
		_hp_text_lbl.add_theme_font_size_override("font_size", 11)
		_hp_bar.custom_minimum_size = Vector2(0, 9)
		_sp_text_lbl.add_theme_font_size_override("font_size", 11)
		_sp_bar.custom_minimum_size = Vector2(0, 7)
		_stamina_text_lbl.add_theme_font_size_override("font_size", 11)
		_stamina_bar.custom_minimum_size = Vector2(0, 7)

		_stage_lbl.add_theme_font_size_override("font_size", 14)
		_mode_lbl.add_theme_font_size_override("font_size", 11)
		_enemy_count_lbl.add_theme_font_size_override("font_size", 11)
		_endless_lbl.add_theme_font_size_override("font_size", 11)
		_gold_lbl.add_theme_font_size_override("font_size", 13)
		_sp_pts_lbl.add_theme_font_size_override("font_size", 13)
		_boss_name_lbl.add_theme_font_size_override("font_size", 14)
		_boss_hp_lbl.add_theme_font_size_override("font_size", 13)

		for mb in _menu_buttons:
			mb.custom_minimum_size = Vector2(74, 38)
			mb.add_theme_font_size_override("font_size", 13)
		_audio_btn.custom_minimum_size = Vector2(44, 38)
		_audio_btn.add_theme_font_size_override("font_size", 14)


func _make_menu_btn(label: String, border_hex: String, text_hex: String, cb: Callable) -> Button:
	var btn := Button.new()
	btn.focus_mode = Control.FOCUS_NONE
	btn.text = label
	UiStyle.apply_button(btn, "#0a0f1f", border_hex, text_hex, 18, 1, 0.80)
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
			b.focus_mode = Control.FOCUS_NONE
			b.text = lbl
			b.custom_minimum_size = Vector2(68, 68)
			UiStyle.apply_button(b, "#0a0f1f", "#e6c37a", "#fef3c7", 16, 2, 0.90)
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


func refresh(enemy_count: int, boss: Enemy3D) -> void:
	var p := GameState.player
	var b := GameState.battle
	var char_cfg: Dictionary = GameData.get_character(p["char_id"])
	var stage_cfg: Dictionary = GameData.get_stage(p["stage_id"])
	var mode_cfg: Dictionary = GameData.get_mode(p["mode"])

	var cur_cid: String = String(char_cfg["id"])
	if cur_cid != _last_char_id:
		_last_char_id = cur_cid
		var hero_hex: String = String(char_cfg.get("color_primary", "#be123c"))
		_icon_box.add_theme_stylebox_override("panel", UiStyle.make_panel(hero_hex, 0.92, "#fde68a", 0.78, 24, 2, 2, 2, 10))
		_status_card.add_theme_stylebox_override("panel", UiStyle.make_accent_card("#090f1f", hero_hex, false, 18, 14, 9))

	_char_icon_lbl.text = char_cfg["icon"]
	_player_name_lbl.text = "%s・%s" % [String(p["name"]), char_cfg["name"]]
	_level_lbl.text = "Lv.%d" % int(p["level"])

	_hp_text_lbl.text = "HP %d/%d" % [int(b["hp"]), int(b["max_hp"])]
	_hp_bar.max_value = maxf(1.0, float(b["max_hp"]))
	_hp_bar.value = float(b["hp"])

	_sp_text_lbl.text = "SP %d/%d" % [int(floor(float(b["sp"]))), int(b["max_sp"])]
	_sp_bar.max_value = float(b["max_sp"])
	_sp_bar.value = float(b["sp"])

	# Stamina (體力條) update + low/exhausted visual cue
	var sta: float = float(b.get("stamina", 100.0))
	var max_sta: float = maxf(1.0, float(b.get("max_stamina", 100.0)))
	var is_low_sta: bool = bool(b.get("stamina_exhausted", false)) or (sta / max_sta) < 0.25
	_stamina_bar.max_value = max_sta
	_stamina_bar.value = sta
	_stamina_text_lbl.text = "體力 %d/%d" % [int(floor(sta)), int(round(max_sta))]
	if _floating_sta_bar != null and _floating_sta_panel != null:
		_floating_sta_bar.max_value = max_sta
		_floating_sta_bar.value = sta
		_floating_sta_panel.visible = bool(b.get("active", false)) and (not bool(b.get("paused", false))) and (sta < max_sta - 0.5)
	if is_low_sta != _stamina_low_state:
		_stamina_low_state = is_low_sta
		var bar_fill := "#fb7185" if is_low_sta else "#f59e0b"
		var bar_border := "#fda4af" if is_low_sta else "#fde68a"
		UiStyle.apply_bar(_stamina_bar, bar_fill, "#141008", 4, bar_border, 0.35)
		_stamina_text_lbl.add_theme_color_override("font_color", Color.html(bar_border))
		if _floating_sta_bar != null:
			UiStyle.apply_bar(_floating_sta_bar, bar_fill, "#141008", 4, bar_border, 0.40)

	var exp_need := GameState.get_exp_to_next_level(int(p["level"]))
	_exp_bar.max_value = 100.0
	_exp_bar.value = 100.0 if int(p["level"]) >= GameData.MAX_LEVEL else minf(100.0, (float(p["exp"]) / float(exp_need)) * 100.0)

	_stage_lbl.text = "%s %s  ・  第 %d 幕" % [stage_cfg["icon"], stage_cfg["name"], int(b["wave"])]
	_mode_lbl.text = mode_cfg["label"]
	_enemy_count_lbl.text = "👹 剩餘 %d" % enemy_count

	_endless_lbl.visible = GameState.is_endless_mode()
	if _endless_lbl.visible:
		var secs := int(floor(float(b["endless_seconds"])))
		_endless_lbl.text = "⏱️ %02d:%02d" % [secs / 60, secs % 60]

	if _stage_mech_lbl != null:
		var status_txt := String(b.get("stage_status", ""))
		_stage_mech_lbl.text = status_txt if not status_txt.is_empty() else String(stage_cfg.get("mechanic_name", ""))

	_gold_lbl.text = "🪙 %d" % int(p["gold"])
	_sp_pts_lbl.text = "✨ %dpt" % int(p["skill_points"])

	if _is_mobile_ui:
		_btn_sig.text = "%s\n%s\n30SP" % [char_cfg["sig_icon"], char_cfg["sig_key"]]
	else:
		_btn_sig.text = "%s [E]\n%s\n30SP" % [char_cfg["sig_icon"], char_cfg["sig_key"]]
	_btn_sig.disabled = float(b["sp"]) < 30.0
	_btn_ult.disabled = float(b["sp"]) < 70.0
	_btn_dash.disabled = sta < 24.0

	var cur_combo := int(b["combo"])
	if cur_combo >= 2:
		_combo_panel.visible = true
		_combo_lbl.text = "⚔️ %d HITS!" % cur_combo
		if cur_combo > _last_combo:
			UiStyle.animate_pop_bounce(self, _combo_panel, 1.18, 0.20)
	else:
		_combo_panel.visible = false
	_last_combo = cur_combo

	var has_boss := boss != null and is_instance_valid(boss) and not boss.dead
	if has_boss:
		_boss_panel.visible = true
		_boss_name_lbl.text = "👹 大頭目・%s" % boss.enemy_name
		_boss_hp_lbl.text = "%d / %d" % [maxi(0, boss.hp), boss.max_hp]
		_boss_bar.max_value = maxf(1.0, float(boss.max_hp))
		_boss_bar.value = float(maxi(0, boss.hp))
		if not _boss_was_visible:
			UiStyle.animate_toast_in(self, _boss_panel)
	else:
		_boss_panel.visible = false
	_boss_was_visible = has_boss


func show_toast(msg: String) -> void:
	_toast_lbl.text = msg
	_toast_panel.visible = true
	_toast_timer = 2.6
	UiStyle.animate_toast_in(self, _toast_panel)


func _process(delta: float) -> void:
	if _toast_timer > 0.0:
		_toast_timer -= delta
		if _toast_timer <= 0.0:
			_toast_panel.visible = false
