class_name ChantOverlay
extends Control
## Bullet-time Japanese vocabulary chant overlay with dramatic shrine-seal open animation,
## word-colored elemental card border, VFX effect pill, and tactile 4-choice kana tiles.

signal chant_completed(is_success: bool, is_typed_perfect: bool)
signal chant_cancelled

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
var _input_edit: LineEdit
var _choices_grid: GridContainer

var _active: bool = false
var _word: Dictionary = {}
var _remaining: float = 0.0
var _max_time: float = 8.5


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

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(780 if is_mob else 600, 540 if is_mob else 460)
	_panel.add_theme_stylebox_override("panel", UiStyle.make_shrine_modal("#080d1c", "#e8c474", 24, 30, 22))
	center.add_child(_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 13 if is_mob else 11)
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
	_timer_label.add_theme_font_size_override("font_size", 19 if is_mob else 14)
	_timer_label.add_theme_color_override("font_color", Color.html("#fecdd3"))
	timer_pill.add_child(_timer_label)
	top_row.add_child(timer_pill)

	# Countdown bar
	_timer_bar = ProgressBar.new()
	_timer_bar.custom_minimum_size = Vector2(0, 12 if is_mob else 9)
	_timer_bar.max_value = 100.0
	_timer_bar.value = 100.0
	UiStyle.apply_bar(_timer_bar, "#f59e0b", "#0d152b", 5, "#fde68a", 0.40)
	vbox.add_child(_timer_bar)

	# Japanese Word Showcase Card (dynamically themed by word element color!)
	_word_card = PanelContainer.new()
	_word_card.add_theme_stylebox_override("panel", UiStyle.make_accent_card("#0c1429", "#e8c474", true, 18, 22, 16))
	vbox.add_child(_word_card)

	var word_box := VBoxContainer.new()
	word_box.add_theme_constant_override("separation", 6)
	_word_card.add_child(word_box)

	var prompt := Label.new()
	prompt.text = "◆ 完成日文言靈詠唱・解放 3D 秘術特效 ◆"
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.add_theme_font_size_override("font_size", 15 if is_mob else 12)
	prompt.add_theme_color_override("font_color", Color.html("#94a3b8"))
	word_box.add_child(prompt)

	_kanji_label = Label.new()
	_kanji_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_kanji_label.add_theme_font_size_override("font_size", 54 if is_mob else 44)
	_kanji_label.add_theme_color_override("font_color", Color.html("#fef3c7"))
	UiStyle.style_label_shadow(_kanji_label, 0.85, 3)
	word_box.add_child(_kanji_label)

	_meaning_label = Label.new()
	_meaning_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_meaning_label.add_theme_font_size_override("font_size", 20 if is_mob else 15)
	_meaning_label.add_theme_color_override("font_color", Color.html("#7dd3fc"))
	word_box.add_child(_meaning_label)

	var vfx_center := CenterContainer.new()
	word_box.add_child(vfx_center)

	_vfx_pill = PanelContainer.new()
	_vfx_pill.add_theme_stylebox_override("panel", UiStyle.make_pill("#091022", 0.90, "#fde68a", 0.45, 16, 6))
	_vfx_label = Label.new()
	_vfx_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_vfx_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_vfx_label.add_theme_font_size_override("font_size", 15 if is_mob else 12)
	_vfx_label.add_theme_color_override("font_color", Color.html("#fde68a"))
	_vfx_pill.add_child(_vfx_label)
	vfx_center.add_child(_vfx_pill)

	# Option A: Hiragana Input (1.5x Perfect Crit)
	var input_lbl := Label.new()
	input_lbl.text = "✍️ 直接輸入平假名讀音（享 1.5 倍完美詠唱暴擊）："
	input_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	input_lbl.add_theme_font_size_override("font_size", 16 if is_mob else 13)
	input_lbl.add_theme_color_override("font_color", Color.html("#fde68a"))
	vbox.add_child(input_lbl)

	var input_row := HBoxContainer.new()
	input_row.add_theme_constant_override("separation", 10)
	vbox.add_child(input_row)

	_input_edit = LineEdit.new()
	_input_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_input_edit.placeholder_text = "輸入平假名，例如：いし"
	_input_edit.custom_minimum_size = Vector2(0, 56 if is_mob else 44)
	_input_edit.add_theme_font_size_override("font_size", 21 if is_mob else 15)
	UiStyle.apply_line_edit(_input_edit, "#e8c474")
	_input_edit.text_submitted.connect(func(_t: String) -> void: _submit_input())
	input_row.add_child(_input_edit)

	var cast_btn := Button.new()
	cast_btn.focus_mode = Control.FOCUS_NONE
	cast_btn.text = "✨ 詠唱！"
	cast_btn.custom_minimum_size = Vector2(138 if is_mob else 104, 56 if is_mob else 44)
	cast_btn.add_theme_font_size_override("font_size", 20 if is_mob else 15)
	UiStyle.apply_button(cast_btn, "#d97706", "#fde68a", "#ffffff", 14, 2, 1.0)
	cast_btn.pressed.connect(_submit_input)
	input_row.add_child(cast_btn)

	# Option B: 4-Choice Quick Buttons
	var choice_lbl := Label.new()
	choice_lbl.text = "或直接點選正確的平假名讀音（標準威力）："
	choice_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	choice_lbl.add_theme_font_size_override("font_size", 15 if is_mob else 12)
	choice_lbl.add_theme_color_override("font_color", Color.html("#94a3b8"))
	vbox.add_child(choice_lbl)

	_choices_grid = GridContainer.new()
	_choices_grid.columns = 2
	_choices_grid.add_theme_constant_override("h_separation", 12)
	_choices_grid.add_theme_constant_override("v_separation", 12)
	vbox.add_child(_choices_grid)

	# Cancel
	var cancel_btn := Button.new()
	cancel_btn.focus_mode = Control.FOCUS_NONE
	cancel_btn.text = "取消詠唱（不消耗 SP）"
	cancel_btn.flat = true
	cancel_btn.add_theme_font_size_override("font_size", 17 if is_mob else 13)
	cancel_btn.add_theme_color_override("font_color", Color.html("#94a3b8"))
	cancel_btn.pressed.connect(_cancel)
	vbox.add_child(cancel_btn)


func open_chant(skill_type: String, word: Dictionary, max_time: float) -> void:
	_word = word
	_max_time = max_time
	_remaining = max_time
	_active = true

	var accent_hex: String = String(word.get("color", "#e8c474"))
	var char_cfg: Dictionary = GameData.get_character(GameState.player["char_id"])
	if skill_type == "ult":
		_skill_badge.text = "🌟 全屏言霊奥義詠唱"
	else:
		_skill_badge.text = "%s %s・%s" % [char_cfg["sig_icon"], char_cfg["sig_key"], char_cfg["sig_name"]]

	_panel.add_theme_stylebox_override("panel", UiStyle.make_shrine_modal("#080d1c", accent_hex, 24, 30, 22))
	_word_card.add_theme_stylebox_override("panel", UiStyle.make_accent_card("#0c1429", accent_hex, true, 18, 22, 16))
	_vfx_pill.add_theme_stylebox_override("panel", UiStyle.make_pill("#091022", 0.92, accent_hex, 0.65, 16, 6))

	_kanji_label.text = String(word.get("kanji", ""))
	_meaning_label.text = "中文意思：%s" % String(word.get("mean", ""))
	var w_icon: String = String(word.get("icon", "✨"))
	var w_vfx: String = String(word.get("vfx_label", "言霊爆發"))
	var w_eff: String = String(word.get("effect_desc", ""))
	var w_col := Color.html(accent_hex).lerp(Color.WHITE, 0.25)
	_vfx_label.text = "%s 特效【%s】｜%s" % [w_icon, w_vfx, w_eff]
	_vfx_label.add_theme_color_override("font_color", w_col)
	_input_edit.text = ""
	_update_timer_ui()

	for child in _choices_grid.get_children():
		child.queue_free()

	var options: Array = [word["kana"]]
	for d in word["distractors"]:
		options.append(d)
	options.shuffle()

	var is_mob := UiStyle.is_mobile_device()
	var idx_tags := ["①", "②", "③", "④"]
	for i in range(options.size()):
		var kana: String = String(options[i])
		var btn := Button.new()
		btn.focus_mode = Control.FOCUS_NONE
		btn.text = "%s  %s" % [idx_tags[i], kana]
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(0, 72 if is_mob else 50)
		btn.add_theme_font_size_override("font_size", 25 if is_mob else 18)
		UiStyle.apply_button(btn, "#121d38", accent_hex, "#fef3c7", 15, 1, 0.96)
		var picked: String = kana
		btn.pressed.connect(func() -> void:
			_finish(picked == String(_word.get("kana", "")), false)
		)
		_choices_grid.add_child(btn)

	visible = true
	UiStyle.animate_modal_open(self, _backdrop, _panel, 0.20)
	if not is_mob:
		_input_edit.grab_focus()


func _submit_input() -> void:
	if not _active:
		return
	var val := _input_edit.text.strip_edges()
	if val.is_empty():
		return
	var ok := (val == String(_word.get("kana", ""))) or (val == String(_word.get("kanji", "")))
	_finish(ok, true)


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
	_remaining -= minf(0.05, delta)
	_update_timer_ui()
	if _remaining <= 0.0:
		_finish(false, false)
