class_name ChantOverlay
extends Control
## Bullet-time Japanese vocabulary chant overlay for signature and ultimate skills.

signal chant_completed(is_success: bool, is_typed_perfect: bool)
signal chant_cancelled

var _skill_badge: Label
var _timer_label: Label
var _timer_bar: ProgressBar
var _kanji_label: Label
var _meaning_label: Label
var _input_edit: LineEdit
var _choices_grid: GridContainer

var _active: bool = false
var _word: Dictionary = {}
var _remaining: float = 0.0
var _max_time: float = 8.5


func _ready() -> void:
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()


func _build_ui() -> void:
	var is_mob := UiStyle.is_mobile_device()

	var backdrop := ColorRect.new()
	backdrop.color = Color(0.02, 0.03, 0.08, 0.80)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(760 if is_mob else 540, 500 if is_mob else 410)
	panel.add_theme_stylebox_override("panel", UiStyle.make_panel("#0f172a", 0.96, "#fbbf24", 0.9, 24, 2, 26, 20))
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14 if is_mob else 12)
	panel.add_child(vbox)

	# Top row: skill badge + countdown
	var top_row := HBoxContainer.new()
	vbox.add_child(top_row)

	var badge_panel := PanelContainer.new()
	badge_panel.add_theme_stylebox_override("panel", UiStyle.make_panel("#7c3aed", 0.95, "#c4b5fd", 0.6, 12, 1, 12, 6))
	_skill_badge = Label.new()
	_skill_badge.add_theme_font_size_override("font_size", 18 if is_mob else 13)
	_skill_badge.add_theme_color_override("font_color", Color.WHITE)
	badge_panel.add_child(_skill_badge)
	top_row.add_child(badge_panel)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(spacer)

	_timer_label = Label.new()
	_timer_label.add_theme_font_size_override("font_size", 20 if is_mob else 15)
	_timer_label.add_theme_color_override("font_color", Color.html("#fb7185"))
	top_row.add_child(_timer_label)

	# Countdown bar
	_timer_bar = ProgressBar.new()
	_timer_bar.custom_minimum_size = Vector2(0, 12 if is_mob else 10)
	_timer_bar.max_value = 100.0
	_timer_bar.value = 100.0
	UiStyle.apply_bar(_timer_bar, "#f59e0b", "#1e293b", 5)
	vbox.add_child(_timer_bar)

	# Japanese Word Card
	var word_card := PanelContainer.new()
	word_card.add_theme_stylebox_override("panel", UiStyle.make_panel("#0b1120", 0.95, "#334155", 0.9, 16, 1, 16, 14))
	vbox.add_child(word_card)

	var word_box := VBoxContainer.new()
	word_box.add_theme_constant_override("separation", 6)
	word_card.add_child(word_box)

	var prompt := Label.new()
	prompt.text = "請完成日文言霊詠唱以釋放技能！"
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.add_theme_font_size_override("font_size", 16 if is_mob else 13)
	prompt.add_theme_color_override("font_color", Color.html("#94a3b8"))
	word_box.add_child(prompt)

	_kanji_label = Label.new()
	_kanji_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_kanji_label.add_theme_font_size_override("font_size", 46 if is_mob else 36)
	_kanji_label.add_theme_color_override("font_color", Color.html("#fcd34d"))
	word_box.add_child(_kanji_label)

	_meaning_label = Label.new()
	_meaning_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_meaning_label.add_theme_font_size_override("font_size", 20 if is_mob else 15)
	_meaning_label.add_theme_color_override("font_color", Color.html("#7dd3fc"))
	word_box.add_child(_meaning_label)

	# Option A: Hiragana Input (1.5x Perfect Crit)
	var input_lbl := Label.new()
	input_lbl.text = "✍️ 輸入平假名讀音（享 1.5 倍完美詠唱暴擊）："
	input_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	input_lbl.add_theme_font_size_override("font_size", 17 if is_mob else 13)
	input_lbl.add_theme_color_override("font_color", Color.html("#fde68a"))
	vbox.add_child(input_lbl)

	var input_row := HBoxContainer.new()
	input_row.add_theme_constant_override("separation", 10)
	vbox.add_child(input_row)

	_input_edit = LineEdit.new()
	_input_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_input_edit.placeholder_text = "輸入平假名，例如：いし"
	_input_edit.custom_minimum_size = Vector2(0, 56 if is_mob else 42)
	_input_edit.add_theme_font_size_override("font_size", 21 if is_mob else 15)
	UiStyle.apply_line_edit(_input_edit, "#fbbf24")
	_input_edit.text_submitted.connect(func(_t: String) -> void: _submit_input())
	input_row.add_child(_input_edit)

	var cast_btn := Button.new()
	cast_btn.text = "詠唱！"
	cast_btn.custom_minimum_size = Vector2(124 if is_mob else 88, 56 if is_mob else 42)
	cast_btn.add_theme_font_size_override("font_size", 20 if is_mob else 15)
	UiStyle.apply_button(cast_btn, "#f59e0b", "#fde68a", "#0f172a", 12, 1, 1.0)
	cast_btn.pressed.connect(_submit_input)
	input_row.add_child(cast_btn)

	# Option B: 4-Choice Quick Buttons
	var choice_lbl := Label.new()
	choice_lbl.text = "或直接點選正確的平假名讀音（標準威力）："
	choice_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	choice_lbl.add_theme_font_size_override("font_size", 16 if is_mob else 12)
	choice_lbl.add_theme_color_override("font_color", Color.html("#94a3b8"))
	vbox.add_child(choice_lbl)

	_choices_grid = GridContainer.new()
	_choices_grid.columns = 2
	_choices_grid.add_theme_constant_override("h_separation", 12)
	_choices_grid.add_theme_constant_override("v_separation", 12)
	vbox.add_child(_choices_grid)

	# Cancel
	var cancel_btn := Button.new()
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

	var char_cfg: Dictionary = GameData.get_character(GameState.player["char_id"])
	if skill_type == "ult":
		_skill_badge.text = "🌟 全屏言霊奥義詠唱"
	else:
		_skill_badge.text = "%s %s・%s" % [char_cfg["sig_icon"], char_cfg["sig_key"], char_cfg["sig_name"]]

	_kanji_label.text = String(word.get("kanji", ""))
	_meaning_label.text = "中文意思：%s" % String(word.get("mean", ""))
	_input_edit.text = ""
	_update_timer_ui()

	for child in _choices_grid.get_children():
		child.queue_free()

	var options: Array = [word["kana"]]
	for d in word["distractors"]:
		options.append(d)
	options.shuffle()

	var is_mob := UiStyle.is_mobile_device()
	for kana in options:
		var btn := Button.new()
		btn.text = String(kana)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(0, 72 if is_mob else 46)
		btn.add_theme_font_size_override("font_size", 26 if is_mob else 17)
		UiStyle.apply_button(btn, "#1e293b", "#fbbf24", "#ffffff", 14, 2, 0.95)
		var picked: String = String(kana)
		btn.pressed.connect(func() -> void:
			_finish(picked == String(_word.get("kana", "")), false)
		)
		_choices_grid.add_child(btn)

	visible = true
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
