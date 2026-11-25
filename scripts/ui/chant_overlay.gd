class_name ChantOverlay
extends Control
## Bullet-time Japanese vocabulary chant overlay with 4 tactile hiragana choice tiles
## (no text input box; supports mouse/touch tap and desktop 1-4 hotkeys, with 1.5x speed-crit bonus!).

signal chant_completed(is_success: bool, is_typed_perfect: bool)
signal chant_cancelled

const SPEED_PERFECT_WINDOW: float = 2.2

var _backdrop: ColorRect
var _panel: PanelContainer
var _word_card: PanelContainer
var _vfx_pill: PanelContainer
var _skill_badge: Label
var _timer_label: Label
var _timer_bar: ProgressBar
var _kanji_label: Label
var _meaning_label: Label
var _vfx_label: Label
var _choices_grid: GridContainer

var _active: bool = false
var _word: Dictionary = {}
var _options: Array[String] = []
var _remaining: float = 0.0
var _max_time: float = 8.5
var _elapsed_open: float = 0.0


func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()


func _build_ui() -> void:
	var is_mob := UiStyle.is_mobile_device()

	_backdrop = ColorRect.new()
	_backdrop.color = Color(0.02, 0.03, 0.08, 0.82)
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_backdrop)

	var outer_margin := MarginContainer.new()
	outer_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	outer_margin.add_theme_constant_override("margin_left", 24 if is_mob else 20)
	outer_margin.add_theme_constant_override("margin_right", 24 if is_mob else 20)
	outer_margin.add_theme_constant_override("margin_top", 16 if is_mob else 20)
	outer_margin.add_theme_constant_override("margin_bottom", 16 if is_mob else 20)
	add_child(outer_margin)

	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer_margin.add_child(center)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(920 if is_mob else 580, 0)
	_panel.add_theme_stylebox_override("panel", UiStyle.make_shrine_modal("#080d1c", "#e8c474", 22, 24 if is_mob else 28, 18 if is_mob else 22))
	center.add_child(_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12 if is_mob else 11)
	_panel.add_child(vbox)

	# Top row: skill badge + countdown
	var top_row := HBoxContainer.new()
	vbox.add_child(top_row)

	var badge_panel := PanelContainer.new()
	badge_panel.add_theme_stylebox_override("panel", UiStyle.make_pill("#5b21b6", 0.96, "#ddd6fe", 0.75, 16, 6))
	_skill_badge = Label.new()
	_skill_badge.add_theme_font_size_override("font_size", 18 if is_mob else 13)
	_skill_badge.add_theme_color_override("font_color", Color.WHITE)
	badge_panel.add_child(_skill_badge)
	top_row.add_child(badge_panel)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(spacer)

	var timer_pill := PanelContainer.new()
	timer_pill.add_theme_stylebox_override("panel", UiStyle.make_pill("#271022", 0.92, "#fb7185", 0.55, 14, 5))
	_timer_label = Label.new()
	_timer_label.add_theme_font_size_override("font_size", 18 if is_mob else 14)
	_timer_label.add_theme_color_override("font_color", Color.html("#fecdd3"))
	timer_pill.add_child(_timer_label)
	top_row.add_child(timer_pill)

	# Countdown bar
	_timer_bar = ProgressBar.new()
	_timer_bar.custom_minimum_size = Vector2(0, 10 if is_mob else 9)
	_timer_bar.max_value = 100.0
	_timer_bar.value = 100.0
	UiStyle.apply_bar(_timer_bar, "#f59e0b", "#0d152b", 5, "#fde68a", 0.40)
	vbox.add_child(_timer_bar)

	# Body container: 2-Column Landscape on Mobile, Clean Stacked on Desktop
	var body_container: BoxContainer = HBoxContainer.new() if is_mob else VBoxContainer.new()
	body_container.add_theme_constant_override("separation", 18 if is_mob else 12)
	vbox.add_child(body_container)

	# === WORD SHOWCASE CARD ===
	_word_card = PanelContainer.new()
	_word_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if is_mob:
		_word_card.size_flags_stretch_ratio = 0.95
		_word_card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_word_card.add_theme_stylebox_override("panel", UiStyle.make_accent_card("#0c1429", "#e8c474", true, 18, 18, 14))
	body_container.add_child(_word_card)

	var word_box := VBoxContainer.new()
	word_box.alignment = BoxContainer.ALIGNMENT_CENTER
	word_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	word_box.add_theme_constant_override("separation", 8 if is_mob else 6)
	_word_card.add_child(word_box)

	var prompt := Label.new()
	prompt.text = "◆ 選擇正確日文言靈・解放 3D 特效 ◆"
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.add_theme_font_size_override("font_size", 14 if is_mob else 12)
	prompt.add_theme_color_override("font_color", Color.html("#94a3b8"))
	word_box.add_child(prompt)

	_kanji_label = Label.new()
	_kanji_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_kanji_label.add_theme_font_size_override("font_size", 54 if is_mob else 46)
	_kanji_label.add_theme_color_override("font_color", Color.html("#fef3c7"))
	UiStyle.style_label_shadow(_kanji_label, 0.85, 3)
	word_box.add_child(_kanji_label)

	_meaning_label = Label.new()
	_meaning_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_meaning_label.add_theme_font_size_override("font_size", 19 if is_mob else 15)
	_meaning_label.add_theme_color_override("font_color", Color.html("#7dd3fc"))
	word_box.add_child(_meaning_label)

	# Full-width VFX Effect Pill (horizontal wrapping)
	_vfx_pill = PanelContainer.new()
	_vfx_pill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_vfx_pill.add_theme_stylebox_override("panel", UiStyle.make_panel("#091022", 0.92, "#fde68a", 0.55, 14, 1, 14, 8, 4))
	_vfx_label = Label.new()
	_vfx_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_vfx_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_vfx_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_vfx_label.add_theme_font_size_override("font_size", 15 if is_mob else 12)
	_vfx_label.add_theme_color_override("font_color", Color.html("#fde68a"))
	_vfx_pill.add_child(_vfx_label)
	word_box.add_child(_vfx_pill)

	# === CHOICES COLUMN (Pure 4-Choice Tactile Buttons + Cancel, ZERO Text Input!) ===
	var action_col := VBoxContainer.new()
	action_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if is_mob:
		action_col.size_flags_stretch_ratio = 1.12
	action_col.alignment = BoxContainer.ALIGNMENT_CENTER
	action_col.add_theme_constant_override("separation", 12)
	body_container.add_child(action_col)

	var choice_lbl := Label.new()
	choice_lbl.text = "✨ 點選正確平假名發動（2.2秒內神速答對享 1.35 倍暴擊！）" if is_mob else "✨ 點選或按 1-4 鍵選擇正確讀音（2.2秒內神速答對享 1.35 倍暴擊！）"
	choice_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	choice_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	choice_lbl.add_theme_font_size_override("font_size", 15 if is_mob else 13)
	choice_lbl.add_theme_color_override("font_color", Color.html("#fde68a"))
	action_col.add_child(choice_lbl)

	_choices_grid = GridContainer.new()
	_choices_grid.columns = 2
	_choices_grid.add_theme_constant_override("h_separation", 12)
	_choices_grid.add_theme_constant_override("v_separation", 12)
	action_col.add_child(_choices_grid)

	var cancel_btn := Button.new()
	cancel_btn.focus_mode = Control.FOCUS_NONE
	cancel_btn.text = "取消詠唱（不消耗 SP）"
	cancel_btn.flat = true
	cancel_btn.add_theme_font_size_override("font_size", 16 if is_mob else 13)
	cancel_btn.add_theme_color_override("font_color", Color.html("#94a3b8"))
	cancel_btn.pressed.connect(_cancel)
	action_col.add_child(cancel_btn)


func open_chant(skill_type: String, word: Dictionary, max_time: float) -> void:
	_word = word
	_max_time = max_time
	_remaining = max_time
	_elapsed_open = 0.0
	_active = true

	var is_mob := UiStyle.is_mobile_device()
	var accent_hex: String = String(word.get("color", "#e8c474"))
	var char_cfg: Dictionary = GameData.get_character(GameState.player["char_id"])
	if skill_type == "ult":
		_skill_badge.text = "🌟 全屏言霊奥義詠唱"
	else:
		_skill_badge.text = "%s %s・%s" % [char_cfg["sig_icon"], char_cfg["sig_key"], char_cfg["sig_name"]]

	_panel.add_theme_stylebox_override("panel", UiStyle.make_shrine_modal("#080d1c", accent_hex, 22, 24 if is_mob else 28, 18 if is_mob else 22))
	_word_card.add_theme_stylebox_override("panel", UiStyle.make_accent_card("#0c1429", accent_hex, true, 18, 18, 14))
	_vfx_pill.add_theme_stylebox_override("panel", UiStyle.make_panel("#091022", 0.92, accent_hex, 0.65, 14, 1, 14, 8, 4))

	_kanji_label.text = String(word.get("kanji", ""))
	_meaning_label.text = "中文意思：%s" % String(word.get("mean", ""))
	var w_icon: String = String(word.get("icon", "✨"))
	var w_vfx: String = String(word.get("vfx_label", "言霊爆發"))
	var w_eff: String = String(word.get("effect_desc", ""))
	var w_col := Color.html(accent_hex).lerp(Color.WHITE, 0.25)
	_vfx_label.text = "%s 【%s】\n%s" % [w_icon, w_vfx, w_eff]
	_vfx_label.add_theme_color_override("font_color", w_col)
	_update_timer_ui()

	for child in _choices_grid.get_children():
		child.queue_free()

	_options.clear()
	_options.append(String(word["kana"]))
	for d in word["distractors"]:
		_options.append(String(d))
	_options.shuffle()

	var idx_tags := ["①", "②", "③", "④"]
	for i in range(_options.size()):
		var kana: String = _options[i]
		var btn := Button.new()
		btn.focus_mode = Control.FOCUS_NONE
		btn.text = "%s  %s" % [idx_tags[i], kana]
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(0, 78 if is_mob else 58)
		btn.add_theme_font_size_override("font_size", 26 if is_mob else 19)
		UiStyle.apply_button(btn, "#121d38", accent_hex, "#fef3c7", 15, 1, 0.96)
		var picked: String = kana
		btn.pressed.connect(func() -> void: _pick_option(picked))
		_choices_grid.add_child(btn)

	visible = true
	UiStyle.animate_modal_open(self, _backdrop, _panel, 0.20)


func _pick_option(picked: String) -> void:
	if not _active:
		return
	var is_ok := (picked == String(_word.get("kana", "")))
	var is_perfect := is_ok and (_elapsed_open <= SPEED_PERFECT_WINDOW)
	_finish(is_ok, is_perfect)


func _input(event: InputEvent) -> void:
	if not _active or not visible:
		return
	if event is InputEventKey:
		var ke := event as InputEventKey
		if ke.pressed and not ke.echo:
			var idx := -1
			if ke.keycode == KEY_1 or ke.keycode == KEY_KP_1:
				idx = 0
			elif ke.keycode == KEY_2 or ke.keycode == KEY_KP_2:
				idx = 1
			elif ke.keycode == KEY_3 or ke.keycode == KEY_KP_3:
				idx = 2
			elif ke.keycode == KEY_4 or ke.keycode == KEY_KP_4:
				idx = 3
			elif ke.keycode == KEY_ESCAPE:
				_cancel()
				get_viewport().set_input_as_handled()
				return
			if idx >= 0 and idx < _options.size():
				_pick_option(_options[idx])
				get_viewport().set_input_as_handled()


func _cancel() -> void:
	_active = false
	visible = false
	chant_cancelled.emit()


func _finish(is_success: bool, is_typed_perfect: bool) -> void:
	_active = false
	visible = false
	chant_completed.emit(is_success, is_typed_perfect)


func _update_timer_ui() -> void:
	_timer_label.text = "⏳ 剩餘 %.1fs" % maxf(0.0, _remaining)
	_timer_bar.value = clampf((_remaining / maxf(0.1, _max_time)) * 100.0, 0.0, 100.0)


func _process(delta: float) -> void:
	if not _active:
		return
	var dt := minf(0.05, delta)
	_elapsed_open += dt
	_remaining -= dt
	_update_timer_ui()
	if _remaining <= 0.0:
		_finish(false, false)
