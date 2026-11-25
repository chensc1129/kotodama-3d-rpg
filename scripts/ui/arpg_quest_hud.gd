class_name ArpgQuestHud
extends Control
## Lightweight Wafuu Glass quest tracker & floating NPC interaction prompt for
## Chapter 1 Japanese ARPG Adventure Mode. Responsive across desktop and mobile
## without overlapping the circular status HUD, virtual joystick, or action orbs.

signal interact_pressed

var _is_mobile: bool = false
var _arpg_enabled: bool = false
var _prompt_visible: bool = false
var _prompt_npc_name: String = ""
var _prompt_hint_tag: String = ""
var _pulse_elapsed: float = 0.0

# Quest tracker nodes
var _quest_anchor: Control
var _quest_panel: PanelContainer
var _zone_trial_lbl: Label
var _quest_title_lbl: Label
var _quest_compass_lbl: Label

# Bottom-center NPC interact prompt nodes
var _interact_holder: CenterContainer
var _interact_btn: Button


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_is_mobile = UiStyle.is_mobile_device()
	_build_ui()
	_apply_responsive_layout()
	set_arpg_visible(false)


func _input(event: InputEvent) -> void:
	if not _is_mobile and event is InputEventScreenTouch:
		_is_mobile = true
		_apply_responsive_layout()
		_refresh_interact_label()


func _build_ui() -> void:
	# ==================== QUEST TRACKER PANEL ====================
	_quest_anchor = Control.new()
	_quest_anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_quest_anchor)

	_quest_panel = PanelContainer.new()
	_quest_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_quest_panel.add_theme_stylebox_override("panel", UiStyle.make_accent_card("#090f1f", "#34d399", false, 16, 15, 9))
	_quest_anchor.add_child(_quest_panel)

	var q_vbox := VBoxContainer.new()
	q_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	q_vbox.add_theme_constant_override("separation", 3)
	_quest_panel.add_child(q_vbox)

	_zone_trial_lbl = Label.new()
	_zone_trial_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_zone_trial_lbl.add_theme_color_override("font_color", Color.html("#6ee7b7"))
	_zone_trial_lbl.text = "📍 櫻花村廣場  ｜  🇯🇵 日文試煉 0/5"
	q_vbox.add_child(_zone_trial_lbl)

	_quest_title_lbl = Label.new()
	_quest_title_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_quest_title_lbl.add_theme_color_override("font_color", Color.html("#fef3c7"))
	UiStyle.style_label_shadow(_quest_title_lbl, 0.78)
	_quest_title_lbl.text = "📜 第一章：與巫女美桜對話"
	q_vbox.add_child(_quest_title_lbl)

	_quest_compass_lbl = Label.new()
	_quest_compass_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_quest_compass_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_quest_compass_lbl.add_theme_color_override("font_color", Color.html("#bae6fd"))
	_quest_compass_lbl.text = "🧭 前方 12m（巫女・美桜）"
	q_vbox.add_child(_quest_compass_lbl)

	# ==================== FLOATING NPC INTERACT PROMPT ====================
	_interact_holder = CenterContainer.new()
	_interact_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_interact_holder.anchor_left = 0.0
	_interact_holder.anchor_right = 1.0
	_interact_holder.anchor_top = 1.0
	_interact_holder.anchor_bottom = 1.0
	_interact_holder.visible = false
	add_child(_interact_holder)

	_interact_btn = Button.new()
	_interact_btn.focus_mode = Control.FOCUS_NONE
	_interact_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	UiStyle.apply_button(_interact_btn, "#064e3b", "#fde047", "#fef9c3", 26, 2, 0.96)
	_interact_btn.pressed.connect(func() -> void: interact_pressed.emit())
	_interact_holder.add_child(_interact_btn)


func _apply_responsive_layout() -> void:
	if _quest_anchor == null or _quest_panel == null or _interact_holder == null:
		return

	if _is_mobile:
		# Compact top-center pill at offset_top = 96 so it never overlaps circular HUD or joystick
		_quest_anchor.anchor_left = 0.5
		_quest_anchor.anchor_right = 0.5
		_quest_anchor.anchor_top = 0.0
		_quest_anchor.anchor_bottom = 0.0
		_quest_anchor.offset_left = -215.0
		_quest_anchor.offset_right = 215.0
		_quest_anchor.offset_top = 96.0
		_quest_anchor.offset_bottom = 184.0

		_quest_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
		_quest_panel.custom_minimum_size = Vector2(430.0, 0.0)
		_quest_panel.add_theme_stylebox_override("panel", UiStyle.make_accent_card("#090f1f", "#34d399", false, 18, 14, 7))

		_zone_trial_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_quest_title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_quest_compass_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_zone_trial_lbl.add_theme_font_size_override("font_size", 14)
		_quest_title_lbl.add_theme_font_size_override("font_size", 16)
		_quest_compass_lbl.add_theme_font_size_override("font_size", 14)

		# Interact prompt sits cleanly above mobile controls
		_interact_holder.offset_top = -256.0
		_interact_holder.offset_bottom = -180.0
		_interact_btn.custom_minimum_size = Vector2(360.0, 64.0)
		_interact_btn.add_theme_font_size_override("font_size", 21)
	else:
		# Top-left cleanly below the stage card
		_quest_anchor.anchor_left = 0.0
		_quest_anchor.anchor_right = 0.0
		_quest_anchor.anchor_top = 0.0
		_quest_anchor.anchor_bottom = 0.0
		_quest_anchor.offset_left = 18.0
		_quest_anchor.offset_right = 370.0
		_quest_anchor.offset_top = 112.0
		_quest_anchor.offset_bottom = 224.0

		_quest_panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
		_quest_panel.custom_minimum_size = Vector2(330.0, 0.0)
		_quest_panel.add_theme_stylebox_override("panel", UiStyle.make_accent_card("#090f1f", "#34d399", false, 16, 15, 9))

		_zone_trial_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		_quest_title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		_quest_compass_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		_zone_trial_lbl.add_theme_font_size_override("font_size", 12)
		_quest_title_lbl.add_theme_font_size_override("font_size", 15)
		_quest_compass_lbl.add_theme_font_size_override("font_size", 13)

		# Desktop bottom-center interact prompt
		_interact_holder.offset_top = -152.0
		_interact_holder.offset_bottom = -95.0
		_interact_btn.custom_minimum_size = Vector2(300.0, 48.0)
		_interact_btn.add_theme_font_size_override("font_size", 16)


# ==================== PUBLIC API ====================

func set_arpg_visible(enabled: bool) -> void:
	_arpg_enabled = enabled
	visible = enabled
	if _interact_holder != null:
		_interact_holder.visible = enabled and _prompt_visible


func update_quest(
	zone_name: String,
	quest_title: String,
	quest_desc: String,
	compass_text: String,
	quiz_done: int,
	quiz_total: int
) -> void:
	if _zone_trial_lbl != null:
		_zone_trial_lbl.text = "📍 %s  ｜  🇯🇵 日文試煉 %d/%d" % [zone_name, quiz_done, quiz_total]
	if _quest_title_lbl != null:
		_quest_title_lbl.text = "📜 %s" % quest_title if not quest_title.begins_with("📜") else quest_title
	if _quest_compass_lbl != null:
		var lines: Array[String] = []
		if not quest_desc.is_empty():
			lines.append(quest_desc)
		if not compass_text.is_empty():
			lines.append(compass_text if compass_text.begins_with("🧭") else "🧭 %s" % compass_text)
		_quest_compass_lbl.text = "  ｜  ".join(lines) if (_is_mobile and lines.size() > 1) else "\n".join(lines)


func set_interact_prompt(visible_flag: bool, npc_name: String, hint_tag: String) -> void:
	var was_visible: bool = _prompt_visible
	_prompt_visible = visible_flag
	_prompt_npc_name = npc_name
	_prompt_hint_tag = hint_tag

	_refresh_interact_label()
	if _interact_holder != null:
		_interact_holder.visible = _arpg_enabled and visible_flag
		if visible_flag and not was_visible and _arpg_enabled:
			_pulse_elapsed = 0.0
			UiStyle.animate_pop_bounce(self, _interact_btn, 1.09, 0.22)


func _refresh_interact_label() -> void:
	if _interact_btn == null:
		return
	var base_txt: String = (
		"💬 點此與 %s 對話" % _prompt_npc_name
		if _is_mobile
		else "💬 [F] 與 %s 對話" % _prompt_npc_name
	)
	if not _prompt_hint_tag.is_empty():
		_interact_btn.text = "%s  %s" % [base_txt, _prompt_hint_tag]
	else:
		_interact_btn.text = base_txt


func _process(delta: float) -> void:
	if not _arpg_enabled or not _prompt_visible or _interact_btn == null:
		return
	_pulse_elapsed += minf(0.05, delta)
	var glow_alpha: float = 0.90 + 0.10 * sin(_pulse_elapsed * 4.5)
	_interact_btn.modulate = Color(1.0, 1.0, 1.0, glow_alpha)
