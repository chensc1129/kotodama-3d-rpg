class_name NpcDialogueModal
extends Control
## Wafuu Shrine Glass modal supporting 3 states for Chapter 1 ARPG Adventure Mode:
## 1. NPC Dialogue (paginated lines + Japanese TTS greeting + quiz launch)
## 2. Japanese Listening & Reading Quiz (2x2 large touch buttons, retryable wrong answers, reward screen)
## 3. Dramatic Story Cutscene Banner (Chapter 1 opening & epilogue)

signal dialogue_closed(npc_id: String)
signal quiz_completed(npc_id: String, reward: Dictionary, first_clear: bool)
signal cutscene_closed(cutscene_id: String)

enum ModalState {
	NONE,
	DIALOGUE,
	QUIZ,
	REWARD,
	CUTSCENE,
}

const OPTION_TAGS: Array[String] = ["①", "②", "③", "④"]

var _state: ModalState = ModalState.NONE
var _is_mobile: bool = false

# Active NPC / Cutscene data
var _npc_data: Dictionary = {}
var _npc_id: String = ""
var _already_cleared: bool = false
var _dialogue_lines: Array[String] = []
var _dialogue_idx: int = 0
var _jp_greeting: String = ""

var _quiz_title: String = ""
var _quiz_questions: Array[Dictionary] = []
var _quiz_idx: int = 0
var _question_solved: bool = false
var _quiz_option_buttons: Array[Button] = []
var _quiz_current_tts: String = ""

var _cutscene_id: String = ""
var _cutscene_lines: Array[String] = []
var _cutscene_idx: int = 0
var _cutscene_tts: String = ""

# Core visual shell
var _backdrop: ColorRect
var _panel: PanelContainer

# Dialogue / Cutscene view
var _story_view: VBoxContainer
var _story_banner_pill: PanelContainer
var _story_banner_lbl: Label
var _speaker_icon_pill: PanelContainer
var _speaker_icon_lbl: Label
var _speaker_name_lbl: Label
var _speaker_title_lbl: Label
var _tts_btn: Button
var _body_card: PanelContainer
var _body_lbl: Label
var _page_lbl: Label
var _story_btn_row: HBoxContainer

# Quiz view
var _quiz_view: VBoxContainer
var _quiz_title_lbl: Label
var _quiz_prog_lbl: Label
var _quiz_q_card: PanelContainer
var _quiz_prompt_lbl: Label
var _quiz_jp_lbl: Label
var _quiz_tts_btn: Button
var _quiz_grid: GridContainer
var _quiz_feedback_card: PanelContainer
var _quiz_feedback_lbl: Label
var _quiz_footer_row: HBoxContainer
var _quiz_next_btn: Button
var _quiz_exit_btn: Button

# Reward view
var _reward_view: VBoxContainer
var _reward_heading_lbl: Label
var _reward_sub_lbl: Label
var _reward_card: PanelContainer
var _reward_detail_lbl: Label
var _reward_claim_btn: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_is_mobile = UiStyle.is_mobile_device()
	_build_ui()


func _build_ui() -> void:
	var mob: bool = _is_mobile

	_backdrop = ColorRect.new()
	_backdrop.color = Color(0.02, 0.03, 0.08, 0.78)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_backdrop)

	var outer_margin := MarginContainer.new()
	outer_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	outer_margin.add_theme_constant_override("margin_left", 24 if mob else 28)
	outer_margin.add_theme_constant_override("margin_right", 24 if mob else 28)
	outer_margin.add_theme_constant_override("margin_top", 14 if mob else 24)
	outer_margin.add_theme_constant_override("margin_bottom", 14 if mob else 24)
	add_child(outer_margin)

	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer_margin.add_child(center)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(880 if mob else 690, 0)
	_panel.add_theme_stylebox_override("panel", UiStyle.make_shrine_modal("#080d1c", "#e8c474", 24, 26 if mob else 30, 18 if mob else 24))
	center.add_child(_panel)

	var root_stack := VBoxContainer.new()
	root_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_stack.add_theme_constant_override("separation", 0)
	_panel.add_child(root_stack)

	_build_story_view(root_stack, mob)
	_build_quiz_view(root_stack, mob)
	_build_reward_view(root_stack, mob)


func _build_story_view(parent: VBoxContainer, mob: bool) -> void:
	_story_view = VBoxContainer.new()
	_story_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_story_view.add_theme_constant_override("separation", 12 if mob else 14)
	_story_view.visible = false
	parent.add_child(_story_view)

	# Cutscene dramatic banner pill (hidden during normal NPC dialogue)
	var banner_center := CenterContainer.new()
	banner_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_story_view.add_child(banner_center)

	_story_banner_pill = PanelContainer.new()
	_story_banner_pill.visible = false
	_story_banner_pill.add_theme_stylebox_override("panel", UiStyle.make_pill("#451a03", 0.96, "#fbbf24", 0.85, 20, 6))
	_story_banner_lbl = Label.new()
	_story_banner_lbl.add_theme_font_size_override("font_size", 18 if mob else 15)
	_story_banner_lbl.add_theme_color_override("font_color", Color.html("#fef3c7"))
	UiStyle.style_label_shadow(_story_banner_lbl, 0.78)
	_story_banner_pill.add_child(_story_banner_lbl)
	banner_center.add_child(_story_banner_pill)

	# Header: Speaker icon badge + Name + Title + TTS button
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 14)
	header.alignment = BoxContainer.ALIGNMENT_CENTER
	_story_view.add_child(header)

	_speaker_icon_pill = PanelContainer.new()
	_speaker_icon_pill.custom_minimum_size = Vector2(62 if mob else 54, 62 if mob else 54)
	_speaker_icon_pill.add_theme_stylebox_override("panel", UiStyle.make_pill("#131c36", 0.96, "#e8c474", 0.78, 12, 8))
	_speaker_icon_lbl = Label.new()
	_speaker_icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_speaker_icon_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_speaker_icon_lbl.add_theme_font_size_override("font_size", 32 if mob else 28)
	_speaker_icon_pill.add_child(_speaker_icon_lbl)
	header.add_child(_speaker_icon_pill)

	var name_col := VBoxContainer.new()
	name_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_col.add_theme_constant_override("separation", 2)
	header.add_child(name_col)

	_speaker_name_lbl = Label.new()
	_speaker_name_lbl.add_theme_font_size_override("font_size", 28 if mob else 23)
	_speaker_name_lbl.add_theme_color_override("font_color", Color.html("#fef3c7"))
	UiStyle.style_label_shadow(_speaker_name_lbl, 0.80, 2)
	name_col.add_child(_speaker_name_lbl)

	_speaker_title_lbl = Label.new()
	_speaker_title_lbl.add_theme_font_size_override("font_size", 16 if mob else 13)
	_speaker_title_lbl.add_theme_color_override("font_color", Color.html("#7dd3fc"))
	name_col.add_child(_speaker_title_lbl)

	_tts_btn = Button.new()
	_tts_btn.focus_mode = Control.FOCUS_NONE
	_tts_btn.text = "🔊 聽日語"
	_tts_btn.custom_minimum_size = Vector2(142 if mob else 118, 50 if mob else 42)
	_tts_btn.add_theme_font_size_override("font_size", 18 if mob else 14)
	UiStyle.apply_button(_tts_btn, "#0f2942", "#38bdf8", "#e0f2fe", 18, 2, 0.95)
	_tts_btn.pressed.connect(_on_story_tts_pressed)
	header.add_child(_tts_btn)

	_story_view.add_child(UiStyle.make_ornament_divider("#e8c474", 0.50))

	# Dialogue body card
	_body_card = PanelContainer.new()
	_body_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body_card.add_theme_stylebox_override("panel", UiStyle.make_accent_card("#0c1429", "#e8c474", false, 18, 22 if mob else 20, 18 if mob else 16))
	_story_view.add_child(_body_card)

	var body_vbox := VBoxContainer.new()
	body_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body_vbox.add_theme_constant_override("separation", 10)
	_body_card.add_child(body_vbox)

	_body_lbl = Label.new()
	_body_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body_lbl.custom_minimum_size = Vector2(0, 128 if mob else 116)
	_body_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_body_lbl.add_theme_font_size_override("font_size", 24 if mob else 19)
	_body_lbl.add_theme_color_override("font_color", Color.html("#f8fafc"))
	UiStyle.style_label_shadow(_body_lbl, 0.65)
	body_vbox.add_child(_body_lbl)

	var page_row := HBoxContainer.new()
	page_row.alignment = BoxContainer.ALIGNMENT_END
	body_vbox.add_child(page_row)

	var page_pill := PanelContainer.new()
	page_pill.add_theme_stylebox_override("panel", UiStyle.make_pill("#091022", 0.90, "#e8c474", 0.42, 12, 4))
	_page_lbl = Label.new()
	_page_lbl.add_theme_font_size_override("font_size", 15 if mob else 12)
	_page_lbl.add_theme_color_override("font_color", Color.html("#cbd5e1"))
	page_pill.add_child(_page_lbl)
	page_row.add_child(page_pill)

	# Action buttons row
	_story_btn_row = HBoxContainer.new()
	_story_btn_row.alignment = BoxContainer.ALIGNMENT_END
	_story_btn_row.add_theme_constant_override("separation", 12)
	_story_view.add_child(_story_btn_row)


func _build_quiz_view(parent: VBoxContainer, mob: bool) -> void:
	_quiz_view = VBoxContainer.new()
	_quiz_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_quiz_view.add_theme_constant_override("separation", 11 if mob else 12)
	_quiz_view.visible = false
	parent.add_child(_quiz_view)

	# Quiz header: title + progress pill
	var q_header := HBoxContainer.new()
	q_header.add_theme_constant_override("separation", 12)
	_quiz_view.add_child(q_header)

	_quiz_title_lbl = Label.new()
	_quiz_title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_quiz_title_lbl.add_theme_font_size_override("font_size", 24 if mob else 20)
	_quiz_title_lbl.add_theme_color_override("font_color", Color.html("#fef3c7"))
	UiStyle.style_label_shadow(_quiz_title_lbl, 0.78, 2)
	q_header.add_child(_quiz_title_lbl)

	var prog_pill := PanelContainer.new()
	prog_pill.add_theme_stylebox_override("panel", UiStyle.make_pill("#0c2440", 0.94, "#38bdf8", 0.78, 16, 6))
	_quiz_prog_lbl = Label.new()
	_quiz_prog_lbl.add_theme_font_size_override("font_size", 17 if mob else 14)
	_quiz_prog_lbl.add_theme_color_override("font_color", Color.html("#bae6fd"))
	prog_pill.add_child(_quiz_prog_lbl)
	q_header.add_child(prog_pill)

	# Question showcase card
	_quiz_q_card = PanelContainer.new()
	_quiz_q_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_quiz_q_card.add_theme_stylebox_override("panel", UiStyle.make_accent_card("#0c1429", "#38bdf8", true, 18, 20, 14))
	_quiz_view.add_child(_quiz_q_card)

	var q_vbox := VBoxContainer.new()
	q_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	q_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	q_vbox.add_theme_constant_override("separation", 8 if mob else 7)
	_quiz_q_card.add_child(q_vbox)

	_quiz_prompt_lbl = Label.new()
	_quiz_prompt_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_quiz_prompt_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_quiz_prompt_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_quiz_prompt_lbl.add_theme_font_size_override("font_size", 20 if mob else 16)
	_quiz_prompt_lbl.add_theme_color_override("font_color", Color.html("#e2e8f0"))
	q_vbox.add_child(_quiz_prompt_lbl)

	_quiz_jp_lbl = Label.new()
	_quiz_jp_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_quiz_jp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_quiz_jp_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_quiz_jp_lbl.add_theme_font_size_override("font_size", 38 if mob else 34)
	_quiz_jp_lbl.add_theme_color_override("font_color", Color.html("#fde68a"))
	UiStyle.style_label_shadow(_quiz_jp_lbl, 0.85, 3)
	q_vbox.add_child(_quiz_jp_lbl)

	var tts_center := CenterContainer.new()
	tts_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	q_vbox.add_child(tts_center)

	_quiz_tts_btn = Button.new()
	_quiz_tts_btn.focus_mode = Control.FOCUS_NONE
	_quiz_tts_btn.text = "🔊 播放日語發音"
	_quiz_tts_btn.custom_minimum_size = Vector2(220 if mob else 186, 46 if mob else 38)
	_quiz_tts_btn.add_theme_font_size_override("font_size", 18 if mob else 14)
	UiStyle.apply_button(_quiz_tts_btn, "#0f2942", "#38bdf8", "#e0f2fe", 18, 2, 0.96)
	_quiz_tts_btn.pressed.connect(_on_quiz_tts_pressed)
	tts_center.add_child(_quiz_tts_btn)

	# 2x2 Options grid (zero text input box)
	_quiz_grid = GridContainer.new()
	_quiz_grid.columns = 2
	_quiz_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_quiz_grid.add_theme_constant_override("h_separation", 12)
	_quiz_grid.add_theme_constant_override("v_separation", 12)
	_quiz_view.add_child(_quiz_grid)

	# Feedback banner
	_quiz_feedback_card = PanelContainer.new()
	_quiz_feedback_card.visible = false
	_quiz_feedback_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_quiz_feedback_lbl = Label.new()
	_quiz_feedback_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_quiz_feedback_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_quiz_feedback_lbl.add_theme_font_size_override("font_size", 18 if mob else 15)
	_quiz_feedback_card.add_child(_quiz_feedback_lbl)
	_quiz_view.add_child(_quiz_feedback_card)

	# Footer buttons
	_quiz_footer_row = HBoxContainer.new()
	_quiz_footer_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_quiz_footer_row.add_theme_constant_override("separation", 12)
	_quiz_view.add_child(_quiz_footer_row)

	_quiz_exit_btn = Button.new()
	_quiz_exit_btn.focus_mode = Control.FOCUS_NONE
	_quiz_exit_btn.text = "👋 稍後再來"
	_quiz_exit_btn.custom_minimum_size = Vector2(150 if mob else 128, 54 if mob else 44)
	_quiz_exit_btn.add_theme_font_size_override("font_size", 18 if mob else 14)
	UiStyle.apply_button(_quiz_exit_btn, "#182135", "#64748b", "#cbd5e1", 16, 1, 0.90)
	_quiz_exit_btn.pressed.connect(_close_and_emit_dialogue)
	_quiz_footer_row.add_child(_quiz_exit_btn)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_quiz_footer_row.add_child(spacer)

	_quiz_next_btn = Button.new()
	_quiz_next_btn.focus_mode = Control.FOCUS_NONE
	_quiz_next_btn.visible = false
	_quiz_next_btn.custom_minimum_size = Vector2(240 if mob else 210, 56 if mob else 46)
	_quiz_next_btn.add_theme_font_size_override("font_size", 20 if mob else 16)
	UiStyle.apply_button(_quiz_next_btn, "#065f46", "#fde047", "#fef9c3", 16, 2, 0.98)
	_quiz_next_btn.pressed.connect(_on_quiz_next_pressed)
	_quiz_footer_row.add_child(_quiz_next_btn)


func _build_reward_view(parent: VBoxContainer, mob: bool) -> void:
	_reward_view = VBoxContainer.new()
	_reward_view.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_reward_view.alignment = BoxContainer.ALIGNMENT_CENTER
	_reward_view.add_theme_constant_override("separation", 16)
	_reward_view.visible = false
	parent.add_child(_reward_view)

	_reward_heading_lbl = Label.new()
	_reward_heading_lbl.text = "🎉 試煉達成！"
	_reward_heading_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_reward_heading_lbl.add_theme_font_size_override("font_size", 36 if mob else 30)
	_reward_heading_lbl.add_theme_color_override("font_color", Color.html("#fde047"))
	UiStyle.style_label_shadow(_reward_heading_lbl, 0.85, 3)
	_reward_view.add_child(_reward_heading_lbl)

	_reward_sub_lbl = Label.new()
	_reward_sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_reward_sub_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_reward_sub_lbl.add_theme_font_size_override("font_size", 20 if mob else 16)
	_reward_sub_lbl.add_theme_color_override("font_color", Color.html("#bae6fd"))
	_reward_view.add_child(_reward_sub_lbl)

	_reward_view.add_child(UiStyle.make_ornament_divider("#34d399", 0.55))

	_reward_card = PanelContainer.new()
	_reward_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_reward_card.add_theme_stylebox_override("panel", UiStyle.make_accent_card("#08241d", "#34d399", true, 18, 22, 18))
	_reward_view.add_child(_reward_card)

	_reward_detail_lbl = Label.new()
	_reward_detail_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_reward_detail_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_reward_detail_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_reward_detail_lbl.add_theme_font_size_override("font_size", 22 if mob else 18)
	_reward_detail_lbl.add_theme_color_override("font_color", Color.html("#ecfdf5"))
	UiStyle.style_label_shadow(_reward_detail_lbl, 0.65)
	_reward_card.add_child(_reward_detail_lbl)

	var btn_center := CenterContainer.new()
	btn_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_reward_view.add_child(btn_center)

	_reward_claim_btn = Button.new()
	_reward_claim_btn.focus_mode = Control.FOCUS_NONE
	_reward_claim_btn.text = "✨ 收下獎勵並繼續冒險"
	_reward_claim_btn.custom_minimum_size = Vector2(340 if mob else 280, 62 if mob else 50)
	_reward_claim_btn.add_theme_font_size_override("font_size", 22 if mob else 17)
	UiStyle.apply_button(_reward_claim_btn, "#065f46", "#fde047", "#fef9c3", 20, 2, 0.98)
	_reward_claim_btn.pressed.connect(_close_and_emit_dialogue)
	btn_center.add_child(_reward_claim_btn)


# ==================== PUBLIC API ====================

func open_npc(npc_data: Dictionary, already_cleared: bool) -> void:
	_npc_data = npc_data
	_npc_id = String(npc_data.get("id", ""))
	_already_cleared = already_cleared
	_state = ModalState.DIALOGUE

	var accent_hex: String = String(npc_data.get("accent", npc_data.get("color", "#e8c474")))
	var icon: String = String(npc_data.get("icon", "⛩️"))
	var speaker_name: String = String(npc_data.get("name", "NPC"))
	var speaker_title: String = String(npc_data.get("title", "櫻花村住民"))
	_jp_greeting = String(npc_data.get("jp_greeting", npc_data.get("jp_tts", "")))

	_dialogue_lines.clear()
	var raw_lines: Variant = npc_data.get("dialogue", npc_data.get("lines", []))
	if raw_lines is Array:
		for item in raw_lines:
			_dialogue_lines.append(String(item))
	if _dialogue_lines.is_empty():
		_dialogue_lines.append("你好，旅人！準備好接受日文言靈試煉了嗎？")
	_dialogue_idx = 0

	_parse_quiz_data(npc_data)

	_apply_modal_accent(accent_hex)
	_story_banner_pill.visible = false
	_speaker_icon_lbl.text = icon
	_speaker_name_lbl.text = speaker_name
	_speaker_title_lbl.text = speaker_title
	_tts_btn.visible = not _jp_greeting.is_empty()

	_show_only_view(_story_view)
	_render_dialogue_page()

	visible = true
	UiStyle.animate_modal_open(self, _backdrop, _panel, 0.22)
	if not _jp_greeting.is_empty():
		AudioManager.speak_japanese(_jp_greeting)


func open_cutscene(cutscene_id: String, title: String, speaker: String, icon: String, jp_tts: String, lines: Array) -> void:
	_cutscene_id = cutscene_id
	_cutscene_tts = jp_tts
	_state = ModalState.CUTSCENE

	_cutscene_lines.clear()
	for item in lines:
		_cutscene_lines.append(String(item))
	if _cutscene_lines.is_empty():
		_cutscene_lines.append(title)
	_cutscene_idx = 0

	_apply_modal_accent("#f59e0b")
	_story_banner_pill.visible = true
	_story_banner_lbl.text = "📖 %s" % title
	_speaker_icon_lbl.text = icon if not icon.is_empty() else "⛩️"
	_speaker_name_lbl.text = speaker if not speaker.is_empty() else "物語旁白"
	_speaker_title_lbl.text = title
	_tts_btn.visible = not _cutscene_tts.is_empty()

	_show_only_view(_story_view)
	_render_cutscene_page()

	visible = true
	UiStyle.animate_modal_open(self, _backdrop, _panel, 0.24)
	if not _cutscene_tts.is_empty():
		AudioManager.speak_japanese(_cutscene_tts)


func close_modal() -> void:
	_state = ModalState.NONE
	_question_solved = false
	visible = false


# ==================== INTERNAL HELPERS ====================

func _apply_modal_accent(accent_hex: String) -> void:
	var mob: bool = _is_mobile
	_panel.add_theme_stylebox_override("panel", UiStyle.make_shrine_modal("#080d1c", accent_hex, 24, 26 if mob else 30, 18 if mob else 24))
	_body_card.add_theme_stylebox_override("panel", UiStyle.make_accent_card("#0c1429", accent_hex, false, 18, 22 if mob else 20, 18 if mob else 16))
	_speaker_icon_pill.add_theme_stylebox_override("panel", UiStyle.make_pill("#131c36", 0.96, accent_hex, 0.80, 12, 8))


func _show_only_view(target: Control) -> void:
	_story_view.visible = (target == _story_view)
	_quiz_view.visible = (target == _quiz_view)
	_reward_view.visible = (target == _reward_view)


func _parse_quiz_data(data: Dictionary) -> void:
	_quiz_title = String(data.get("quiz_title", "🇯🇵 日文言靈試煉"))
	_quiz_questions.clear()

	var raw_quiz: Variant = data.get("quiz", data.get("questions", []))
	if raw_quiz is Dictionary:
		var q_dict: Dictionary = raw_quiz
		if q_dict.has("title"):
			_quiz_title = String(q_dict["title"])
		raw_quiz = q_dict.get("questions", [])

	if raw_quiz is Array:
		for q in raw_quiz:
			if q is Dictionary:
				_quiz_questions.append(q)


func _clear_story_buttons() -> void:
	for child in _story_btn_row.get_children():
		child.queue_free()


func _render_dialogue_page() -> void:
	var mob: bool = _is_mobile
	var total: int = _dialogue_lines.size()
	_dialogue_idx = clampi(_dialogue_idx, 0, maxi(0, total - 1))
	_body_lbl.text = _dialogue_lines[_dialogue_idx]
	_page_lbl.text = "%d / %d" % [_dialogue_idx + 1, total]

	_clear_story_buttons()
	var is_last: bool = (_dialogue_idx >= total - 1)
	if not is_last:
		var skip_btn := Button.new()
		skip_btn.focus_mode = Control.FOCUS_NONE
		skip_btn.text = "⏭ 跳至最後"
		skip_btn.custom_minimum_size = Vector2(160 if mob else 132, 56 if mob else 44)
		skip_btn.add_theme_font_size_override("font_size", 18 if mob else 14)
		UiStyle.apply_button(skip_btn, "#182135", "#64748b", "#cbd5e1", 16, 1, 0.92)
		skip_btn.pressed.connect(func() -> void:
			AudioManager.play_sfx("dash")
			_dialogue_idx = total - 1
			_render_dialogue_page()
		)
		_story_btn_row.add_child(skip_btn)

		var next_btn := Button.new()
		next_btn.focus_mode = Control.FOCUS_NONE
		next_btn.text = "▶ 繼續對話"
		next_btn.custom_minimum_size = Vector2(210 if mob else 168, 56 if mob else 44)
		next_btn.add_theme_font_size_override("font_size", 20 if mob else 16)
		UiStyle.apply_button(next_btn, "#1e293b", "#e8c474", "#fef3c7", 16, 2, 0.96)
		next_btn.pressed.connect(func() -> void:
			AudioManager.play_sfx("dash")
			_dialogue_idx += 1
			_render_dialogue_page()
		)
		_story_btn_row.add_child(next_btn)
	else:
		var later_btn := Button.new()
		later_btn.focus_mode = Control.FOCUS_NONE
		later_btn.text = "👋 稍後再來"
		later_btn.custom_minimum_size = Vector2(162 if mob else 134, 58 if mob else 46)
		later_btn.add_theme_font_size_override("font_size", 18 if mob else 14)
		UiStyle.apply_button(later_btn, "#182135", "#64748b", "#cbd5e1", 16, 1, 0.92)
		later_btn.pressed.connect(_close_and_emit_dialogue)
		_story_btn_row.add_child(later_btn)

		if not _quiz_questions.is_empty():
			var quiz_btn := Button.new()
			quiz_btn.focus_mode = Control.FOCUS_NONE
			quiz_btn.text = "🇯🇵 再次挑戰日文試煉（練習 +30金幣）" if _already_cleared else "🇯🇵 接受日文試煉（領取獎勵）"
			quiz_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			quiz_btn.custom_minimum_size = Vector2(320 if mob else 280, 60 if mob else 48)
			quiz_btn.add_theme_font_size_override("font_size", 20 if mob else 16)
			UiStyle.apply_button(quiz_btn, "#065f46", "#fde047", "#fef9c3", 18, 2, 0.98)
			quiz_btn.pressed.connect(_start_quiz)
			_story_btn_row.add_child(quiz_btn)


func _render_cutscene_page() -> void:
	var mob: bool = _is_mobile
	var total: int = _cutscene_lines.size()
	_cutscene_idx = clampi(_cutscene_idx, 0, maxi(0, total - 1))
	_body_lbl.text = _cutscene_lines[_cutscene_idx]
	_page_lbl.text = "%d / %d" % [_cutscene_idx + 1, total]

	_clear_story_buttons()
	var is_last: bool = (_cutscene_idx >= total - 1)
	if not is_last:
		var skip_btn := Button.new()
		skip_btn.focus_mode = Control.FOCUS_NONE
		skip_btn.text = "⏭ 跳過劇情"
		skip_btn.custom_minimum_size = Vector2(156 if mob else 130, 56 if mob else 44)
		skip_btn.add_theme_font_size_override("font_size", 18 if mob else 14)
		UiStyle.apply_button(skip_btn, "#182135", "#64748b", "#cbd5e1", 16, 1, 0.92)
		skip_btn.pressed.connect(_close_and_emit_cutscene)
		_story_btn_row.add_child(skip_btn)

		var cont_btn := Button.new()
		cont_btn.focus_mode = Control.FOCUS_NONE
		cont_btn.text = "▶ 繼續"
		cont_btn.custom_minimum_size = Vector2(200 if mob else 160, 56 if mob else 44)
		cont_btn.add_theme_font_size_override("font_size", 20 if mob else 16)
		UiStyle.apply_button(cont_btn, "#451a03", "#fbbf24", "#fef3c7", 16, 2, 0.96)
		cont_btn.pressed.connect(func() -> void:
			AudioManager.play_sfx("dash")
			_cutscene_idx += 1
			_render_cutscene_page()
		)
		_story_btn_row.add_child(cont_btn)
	else:
		var is_ending: bool = (
			_cutscene_id.contains("clear")
			or _cutscene_id.contains("end")
			or _cutscene_id.contains("complete")
			or _cutscene_id.contains("epilogue")
		)
		var finish_btn := Button.new()
		finish_btn.focus_mode = Control.FOCUS_NONE
		finish_btn.text = "🏆 完成第一章！" if is_ending else "⚔️ 啟程冒險！"
		finish_btn.custom_minimum_size = Vector2(270 if mob else 220, 62 if mob else 50)
		finish_btn.add_theme_font_size_override("font_size", 22 if mob else 17)
		UiStyle.apply_button(finish_btn, "#065f46" if is_ending else "#7c2d12", "#fde047", "#fef9c3", 18, 2, 0.98)
		finish_btn.pressed.connect(_close_and_emit_cutscene)
		_story_btn_row.add_child(finish_btn)


# ==================== QUIZ FLOW ====================

func _start_quiz() -> void:
	AudioManager.play_sfx("skill")
	_state = ModalState.QUIZ
	_quiz_idx = 0
	_apply_modal_accent("#38bdf8")
	_show_only_view(_quiz_view)
	_render_quiz_question()


func _render_quiz_question() -> void:
	var mob: bool = _is_mobile
	var total: int = _quiz_questions.size()
	if total == 0:
		_show_reward_screen()
		return

	_quiz_idx = clampi(_quiz_idx, 0, total - 1)
	_question_solved = false
	var q: Dictionary = _quiz_questions[_quiz_idx]

	_quiz_title_lbl.text = _quiz_title
	_quiz_prog_lbl.text = "第 %d / %d 題" % [_quiz_idx + 1, total]

	var prompt_txt: String = String(q.get("prompt", q.get("question", q.get("zh", "請選出正確答案："))))
	var jp_txt: String = String(q.get("jp_text", q.get("jp", q.get("kanji", ""))))
	_quiz_current_tts = String(q.get("kana_tts", q.get("tts", jp_txt)))

	_quiz_prompt_lbl.text = prompt_txt
	_quiz_jp_lbl.text = jp_txt
	_quiz_jp_lbl.visible = not jp_txt.is_empty()
	_quiz_tts_btn.visible = not _quiz_current_tts.is_empty()

	_quiz_feedback_card.visible = false
	_quiz_next_btn.visible = false
	_quiz_exit_btn.visible = true

	for child in _quiz_grid.get_children():
		child.queue_free()
	_quiz_option_buttons.clear()

	var raw_opts: Variant = q.get("options", q.get("choices", []))
	var opts: Array[String] = []
	if raw_opts is Array:
		for item in raw_opts:
			opts.append(String(item))

	for i in range(opts.size()):
		var opt_text: String = opts[i]
		var tag: String = OPTION_TAGS[i] if i < OPTION_TAGS.size() else "%d." % (i + 1)
		var btn := Button.new()
		btn.focus_mode = Control.FOCUS_NONE
		btn.text = "%s  %s" % [tag, opt_text]
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		btn.custom_minimum_size = Vector2(0, 74 if mob else 58)
		btn.add_theme_font_size_override("font_size", 22 if mob else 17)
		UiStyle.apply_button(btn, "#121d38", "#38bdf8", "#f8fafc", 15, 1, 0.96)
		var idx_copy: int = i
		var txt_copy: String = opt_text
		btn.pressed.connect(func() -> void: _on_quiz_option_picked(idx_copy, txt_copy, btn))
		_quiz_grid.add_child(btn)
		_quiz_option_buttons.append(btn)

	if not _quiz_current_tts.is_empty():
		AudioManager.speak_japanese(_quiz_current_tts)


func _is_option_correct(q: Dictionary, picked_idx: int, picked_text: String) -> bool:
	var ans: Variant = null
	if q.has("answer"):
		ans = q["answer"]
	elif q.has("correct"):
		ans = q["correct"]
	elif q.has("correct_idx"):
		ans = q["correct_idx"]
	elif q.has("correct_index"):
		ans = q["correct_index"]
	elif q.has("answer_idx"):
		ans = q["answer_idx"]

	if ans is int or ans is float:
		return picked_idx == int(ans)
	if ans is String:
		return picked_text.strip_edges() == String(ans).strip_edges()
	return picked_idx == 0


func _on_quiz_option_picked(picked_idx: int, picked_text: String, btn: Button) -> void:
	if _state != ModalState.QUIZ or _question_solved:
		return
	if _quiz_idx < 0 or _quiz_idx >= _quiz_questions.size():
		return

	var q: Dictionary = _quiz_questions[_quiz_idx]
	if _is_option_correct(q, picked_idx, picked_text):
		_question_solved = true
		AudioManager.play_sfx("levelup")
		UiStyle.apply_button(btn, "#065f46", "#34d399", "#ecfdf5", 15, 2, 0.98)
		UiStyle.animate_pop_bounce(self, btn, 1.06, 0.20)

		var explain: String = String(q.get("explain", q.get("explanation", "")))
		_quiz_feedback_card.add_theme_stylebox_override("panel", UiStyle.make_accent_card("#06291e", "#34d399", true, 14, 16, 10))
		_quiz_feedback_lbl.add_theme_color_override("font_color", Color.html("#a7f3d0"))
		_quiz_feedback_lbl.text = "✅ 正解！%s" % (("\n" + explain) if not explain.is_empty() else "")
		_quiz_feedback_card.visible = true

		var is_final: bool = (_quiz_idx >= _quiz_questions.size() - 1)
		_quiz_next_btn.text = "🎁 領取獎勵！" if is_final else "▶ 下一題"
		_quiz_next_btn.visible = true
		UiStyle.animate_pop_bounce(self, _quiz_next_btn, 1.08, 0.22)
	else:
		AudioManager.play_sfx("hit")
		UiStyle.apply_button(btn, "#450a0a", "#fb7185", "#fecdd3", 15, 2, 0.96)
		_quiz_feedback_card.add_theme_stylebox_override("panel", UiStyle.make_accent_card("#2c0a14", "#fb7185", true, 14, 16, 10))
		_quiz_feedback_lbl.add_theme_color_override("font_color", Color.html("#fecdd3"))
		_quiz_feedback_lbl.text = "❌ 再試一次！提示：點擊「🔊 播放發音」仔細聽讀音"
		_quiz_feedback_card.visible = true


func _on_quiz_next_pressed() -> void:
	if _state != ModalState.QUIZ or not _question_solved:
		return
	if _quiz_idx < _quiz_questions.size() - 1:
		AudioManager.play_sfx("dash")
		_quiz_idx += 1
		_render_quiz_question()
	else:
		_complete_quiz_and_show_reward()


func _complete_quiz_and_show_reward() -> void:
	AudioManager.play_sfx("levelup")
	var reward: Dictionary = {}
	var raw_reward: Variant = _npc_data.get("reward", {})
	if raw_reward is Dictionary:
		reward = raw_reward.duplicate(true)
	var first_clear: bool = not _already_cleared
	quiz_completed.emit(_npc_id, reward, first_clear)
	_show_reward_screen(reward, first_clear)


func _show_reward_screen(reward: Dictionary = {}, first_clear: bool = true) -> void:
	_state = ModalState.REWARD
	_apply_modal_accent("#34d399")
	_show_only_view(_reward_view)

	var speaker_name: String = String(_npc_data.get("name", "導師"))
	_reward_heading_lbl.text = "🎉 試煉達成！"
	_reward_sub_lbl.text = "%s 稱讚了你的言靈修為！" % speaker_name
	_reward_detail_lbl.text = _format_reward_summary(reward, first_clear)
	UiStyle.animate_pop_bounce(self, _reward_card, 1.06, 0.24)


func _format_reward_summary(reward: Dictionary, first_clear: bool) -> String:
	if not first_clear:
		return "🏅 複習獎勵：+30 金幣\n（已再次熟練本區日文言靈！）"

	var parts: Array[String] = []
	var custom_label: String = String(reward.get("label", reward.get("desc", reward.get("summary", ""))))
	if not custom_label.is_empty():
		parts.append("✨ %s" % custom_label)

	var gold_amt: int = int(reward.get("gold", 0))
	if gold_amt > 0:
		parts.append("🪙 +%d 金幣" % gold_amt)
	var exp_amt: int = int(reward.get("exp", 0))
	if exp_amt > 0:
		parts.append("⭐ +%d 經驗值" % exp_amt)
	var sp_pts: int = int(reward.get("skill_pts", reward.get("sp_pts", 0)))
	if sp_pts > 0:
		parts.append("💠 +%d 技能點" % sp_pts)
	var atk_bonus: int = int(reward.get("atk", reward.get("atk_bonus", 0)))
	if atk_bonus > 0:
		parts.append("⚔️ 永久攻擊 +%d" % atk_bonus)
	var hp_bonus: int = int(reward.get("max_hp", reward.get("hp_bonus", 0)))
	if hp_bonus > 0:
		parts.append("❤️ 最大生命 +%d" % hp_bonus)
	if bool(reward.get("heal_full", false)):
		parts.append("💚 生命與靈力全回復")

	if parts.is_empty():
		return "🪙 +80 金幣  ｜  ⭐ +50 經驗值"
	return "\n".join(parts)


# ==================== CALLBACKS & INPUT ====================

func _on_story_tts_pressed() -> void:
	if _state == ModalState.CUTSCENE and not _cutscene_tts.is_empty():
		AudioManager.speak_japanese(_cutscene_tts)
	elif not _jp_greeting.is_empty():
		AudioManager.speak_japanese(_jp_greeting)


func _on_quiz_tts_pressed() -> void:
	if not _quiz_current_tts.is_empty():
		AudioManager.speak_japanese(_quiz_current_tts)


func _close_and_emit_dialogue() -> void:
	var closed_id: String = _npc_id
	close_modal()
	dialogue_closed.emit(closed_id)


func _close_and_emit_cutscene() -> void:
	var closed_id: String = _cutscene_id
	close_modal()
	cutscene_closed.emit(closed_id)


func _input(event: InputEvent) -> void:
	if not visible or _state == ModalState.NONE:
		return
	if not (event is InputEventKey):
		return
	var ke := event as InputEventKey
	if not ke.pressed or ke.echo:
		return

	if ke.keycode == KEY_ESCAPE:
		if _state == ModalState.CUTSCENE:
			_close_and_emit_cutscene()
		else:
			_close_and_emit_dialogue()
		get_viewport().set_input_as_handled()
		return

	if _state == ModalState.QUIZ:
		if not _question_solved:
			var idx: int = -1
			if ke.keycode == KEY_1 or ke.keycode == KEY_KP_1:
				idx = 0
			elif ke.keycode == KEY_2 or ke.keycode == KEY_KP_2:
				idx = 1
			elif ke.keycode == KEY_3 or ke.keycode == KEY_KP_3:
				idx = 2
			elif ke.keycode == KEY_4 or ke.keycode == KEY_KP_4:
				idx = 3
			if idx >= 0 and idx < _quiz_option_buttons.size():
				_quiz_option_buttons[idx].pressed.emit()
				get_viewport().set_input_as_handled()
		elif ke.keycode == KEY_ENTER or ke.keycode == KEY_KP_ENTER or ke.keycode == KEY_SPACE:
			_on_quiz_next_pressed()
			get_viewport().set_input_as_handled()
	elif _state == ModalState.REWARD:
		if ke.keycode == KEY_ENTER or ke.keycode == KEY_KP_ENTER or ke.keycode == KEY_SPACE:
			_close_and_emit_dialogue()
			get_viewport().set_input_as_handled()
	elif _state == ModalState.DIALOGUE:
		if ke.keycode == KEY_ENTER or ke.keycode == KEY_KP_ENTER or ke.keycode == KEY_SPACE:
			if _dialogue_idx < _dialogue_lines.size() - 1:
				AudioManager.play_sfx("dash")
				_dialogue_idx += 1
				_render_dialogue_page()
				get_viewport().set_input_as_handled()
	elif _state == ModalState.CUTSCENE:
		if ke.keycode == KEY_ENTER or ke.keycode == KEY_KP_ENTER or ke.keycode == KEY_SPACE:
			if _cutscene_idx < _cutscene_lines.size() - 1:
				AudioManager.play_sfx("dash")
				_cutscene_idx += 1
				_render_cutscene_page()
			else:
				_close_and_emit_cutscene()
			get_viewport().set_input_as_handled()
