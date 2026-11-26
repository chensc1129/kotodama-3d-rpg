class_name ArpgQuestHud
extends Control
## Sleek, collapsible Wafuu Glass quest tracker & floating NPC interaction prompt for
## Chapter 1 Japanese ARPG Adventure Mode.
## Anchored cleanly in the top-left below the status cluster on both desktop and mobile
## so the center 3D viewport and player character remain 100% unobstructed.

signal interact_pressed

var _is_mobile: bool = false
var _arpg_enabled: bool = false
var _prompt_visible: bool = false
var _prompt_npc_name: String = ""
var _prompt_hint_tag: String = ""
var _pulse_elapsed: float = 0.0
var _desc_expanded: bool = false
var _last_quest_desc: String = ""

# Quest tracker nodes
var _quest_panel: PanelContainer
var _zone_trial_lbl: Label
var _expand_btn: Button
var _quest_title_lbl: Label
var _quest_compass_lbl: Label
var _quest_desc_lbl: Label

# Bottom-center NPC interact prompt nodes
var _interact_holder: CenterContainer
var _interact_btn: Button


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_is_mobile = UiStyle.is_mobile_device()
	_desc_expanded = not _is_mobile
	_build_ui()
	_apply_responsive_layout()
	set_arpg_visible(false)


func _input(event: InputEvent) -> void:
	if not _is_mobile and event is InputEventScreenTouch:
		_is_mobile = true
		_desc_expanded = false
		_apply_responsive_layout()
		_refresh_desc_visibility()
		_refresh_interact_label()


func _build_ui() -> void:
	# ==================== COMPACT TOP-LEFT QUEST TRACKER ====================
	_quest_panel = PanelContainer.new()
	_quest_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_quest_panel.anchor_left = 0.0
	_quest_panel.anchor_right = 0.0
	_quest_panel.anchor_top = 0.0
	_quest_panel.anchor_bottom = 0.0
	_quest_panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_quest_panel.add_theme_stylebox_override("panel", UiStyle.make_accent_card("#090f1f", "#34d399", false, 14, 12, 8))
	add_child(_quest_panel)

	var q_vbox := VBoxContainer.new()
	q_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	q_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	q_vbox.add_theme_constant_override("separation", 3)
	_quest_panel.add_child(q_vbox)

	var header_row := HBoxContainer.new()
	header_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header_row.add_theme_constant_override("separation", 6)
	q_vbox.add_child(header_row)

	_zone_trial_lbl = Label.new()
	_zone_trial_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_zone_trial_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_zone_trial_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_zone_trial_lbl.add_theme_color_override("font_color", Color.html("#6ee7b7"))
	_zone_trial_lbl.text = "📍 櫻花村廣場 · 試煉 0/5"
	header_row.add_child(_zone_trial_lbl)

	_expand_btn = Button.new()
	_expand_btn.focus_mode = Control.FOCUS_NONE
	_expand_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	_expand_btn.text = "▼"
	var eb_n := UiStyle.make_panel("#0f1c2e", 0.88, "#34d399", 0.55, 8, 1, 6, 1, 0)
	var eb_h := UiStyle.make_panel("#16304a", 0.96, "#6ee7b7", 0.95, 8, 1, 6, 1, 0)
	_expand_btn.add_theme_stylebox_override("normal", eb_n)
	_expand_btn.add_theme_stylebox_override("hover", eb_h)
	_expand_btn.add_theme_stylebox_override("pressed", eb_h)
	_expand_btn.add_theme_color_override("font_color", Color.html("#a7f3d0"))
	_expand_btn.pressed.connect(_toggle_desc_expanded)
	header_row.add_child(_expand_btn)

	_quest_title_lbl = Label.new()
	_quest_title_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_quest_title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_quest_title_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_quest_title_lbl.add_theme_color_override("font_color", Color.html("#fef3c7"))
	UiStyle.style_label_shadow(_quest_title_lbl, 0.78)
	_quest_title_lbl.text = "📜 第一章：與巫女美桜對話"
	q_vbox.add_child(_quest_title_lbl)

	_quest_compass_lbl = Label.new()
	_quest_compass_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_quest_compass_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_quest_compass_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_quest_compass_lbl.add_theme_color_override("font_color", Color.html("#7dd3fc"))
	_quest_compass_lbl.text = "🧭 前方 12m（巫女・美桜）"
	q_vbox.add_child(_quest_compass_lbl)

	_quest_desc_lbl = Label.new()
	_quest_desc_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_quest_desc_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_quest_desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_quest_desc_lbl.add_theme_color_override("font_color", Color.html("#cbd5e1"))
	_quest_desc_lbl.visible = false
	q_vbox.add_child(_quest_desc_lbl)

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
	UiStyle.apply_button(_interact_btn, "#064e3b", "#fde047", "#fef9c3", 24, 2, 0.96)
	_interact_btn.pressed.connect(func() -> void: interact_pressed.emit())
	_interact_holder.add_child(_interact_btn)


func _toggle_desc_expanded() -> void:
	_desc_expanded = not _desc_expanded
	_refresh_desc_visibility()


func _refresh_desc_visibility() -> void:
	if _quest_desc_lbl == null or _expand_btn == null:
		return
	var show_desc: bool = _desc_expanded and not _last_quest_desc.is_empty()
	_quest_desc_lbl.visible = show_desc
	_expand_btn.text = "▲" if _desc_expanded else "▼"
	call_deferred("_fit_quest_panel")


func _fit_quest_panel() -> void:
	if _quest_panel == null or not is_instance_valid(_quest_panel):
		return
	var target_w: float = 316.0 if _is_mobile else 334.0
	_quest_panel.custom_minimum_size = Vector2(target_w, 0.0)
	_quest_panel.size = Vector2(target_w, 0.0)
	var min_sz: Vector2 = _quest_panel.get_combined_minimum_size()
	_quest_panel.size = Vector2(target_w, min_sz.y)


func _apply_responsive_layout() -> void:
	if _quest_panel == null or _interact_holder == null:
		return

	if _is_mobile:
		# Sleek top-left tracker cleanly tucked below CircularStatusHud — NEVER blocking center viewport!
		var w: float = 316.0
		_quest_panel.position = Vector2(18.0, 128.0)
		_quest_panel.custom_minimum_size = Vector2(w, 0.0)
		_quest_panel.add_theme_stylebox_override("panel", UiStyle.make_accent_card("#090f1f", "#34d399", false, 14, 12, 7))

		_zone_trial_lbl.add_theme_font_size_override("font_size", 13)
		_quest_title_lbl.add_theme_font_size_override("font_size", 14)
		_quest_compass_lbl.add_theme_font_size_override("font_size", 13)
		_quest_desc_lbl.add_theme_font_size_override("font_size", 12)
		_quest_desc_lbl.custom_minimum_size = Vector2(w - 28.0, 0.0)

		_expand_btn.custom_minimum_size = Vector2(30.0, 24.0)
		_expand_btn.add_theme_font_size_override("font_size", 11)

		# Interact prompt sits cleanly centered in the open bottom lane between joystick & skill orbs
		_interact_holder.offset_top = -178.0
		_interact_holder.offset_bottom = -114.0
		_interact_btn.custom_minimum_size = Vector2(330.0, 58.0)
		_interact_btn.add_theme_font_size_override("font_size", 19)
	else:
		# Top-left cleanly below the stage card
		var w: float = 334.0
		_quest_panel.position = Vector2(18.0, 112.0)
		_quest_panel.custom_minimum_size = Vector2(w, 0.0)
		_quest_panel.add_theme_stylebox_override("panel", UiStyle.make_accent_card("#090f1f", "#34d399", false, 14, 14, 8))

		_zone_trial_lbl.add_theme_font_size_override("font_size", 12)
		_quest_title_lbl.add_theme_font_size_override("font_size", 14)
		_quest_compass_lbl.add_theme_font_size_override("font_size", 13)
		_quest_desc_lbl.add_theme_font_size_override("font_size", 12)
		_quest_desc_lbl.custom_minimum_size = Vector2(w - 30.0, 0.0)

		_expand_btn.custom_minimum_size = Vector2(26.0, 22.0)
		_expand_btn.add_theme_font_size_override("font_size", 10)

		# Desktop bottom-center interact prompt
		_interact_holder.offset_top = -138.0
		_interact_holder.offset_bottom = -86.0
		_interact_btn.custom_minimum_size = Vector2(296.0, 46.0)
		_interact_btn.add_theme_font_size_override("font_size", 15)

	_refresh_desc_visibility()


# ==================== PUBLIC API ====================

func set_arpg_visible(enabled: bool) -> void:
	_arpg_enabled = enabled
	visible = enabled
	if _interact_holder != null:
		_interact_holder.visible = enabled and _prompt_visible
	if enabled:
		call_deferred("_fit_quest_panel")


func update_quest(
	zone_name: String,
	quest_title: String,
	quest_desc: String,
	compass_text: String,
	quiz_done: int,
	quiz_total: int
) -> void:
	var changed_layout: bool = false
	if _zone_trial_lbl != null:
		var zt := "📍 %s · 試煉 %d/%d" % [zone_name, quiz_done, quiz_total]
		if _zone_trial_lbl.text != zt:
			_zone_trial_lbl.text = zt
	if _quest_title_lbl != null:
		var qt := "📜 %s" % quest_title if not quest_title.begins_with("📜") else quest_title
		if _quest_title_lbl.text != qt:
			_quest_title_lbl.text = qt
	if _quest_compass_lbl != null:
		var ct := compass_text if compass_text.begins_with("🧭") else ("🧭 %s" % compass_text if not compass_text.is_empty() else "")
		if _quest_compass_lbl.text != ct:
			_quest_compass_lbl.text = ct
	if _last_quest_desc != quest_desc:
		_last_quest_desc = quest_desc
		if _quest_desc_lbl != null:
			_quest_desc_lbl.text = quest_desc
		changed_layout = true
	if changed_layout:
		_refresh_desc_visibility()


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
