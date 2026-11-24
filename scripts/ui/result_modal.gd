class_name ResultModal
extends Control
## Victory / Defeat summary overlay shown when a battle ends, with Replay and Return to Main Menu.

signal replay_pressed
signal return_to_menu_pressed

var _title_lbl: Label
var _summary_lbl: Label


func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()


func _build_ui() -> void:
	var is_mob := UiStyle.is_mobile_device()

	var backdrop := ColorRect.new()
	backdrop.color = Color(0.02, 0.03, 0.08, 0.84)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(540 if is_mob else 460, 0)
	panel.add_theme_stylebox_override("panel", UiStyle.make_panel("#0f172a", 0.96, "#fbbf24", 0.85, 24, 2, 28, 24))
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	panel.add_child(vbox)

	_title_lbl = Label.new()
	_title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_lbl.add_theme_font_size_override("font_size", 30 if is_mob else 25)
	vbox.add_child(_title_lbl)

	var info_card := PanelContainer.new()
	info_card.add_theme_stylebox_override("panel", UiStyle.make_panel("#0b1120", 0.95, "#334155", 0.9, 16, 1, 18, 14))
	vbox.add_child(info_card)

	_summary_lbl = Label.new()
	_summary_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_summary_lbl.add_theme_font_size_override("font_size", 18 if is_mob else 15)
	_summary_lbl.add_theme_color_override("font_color", Color.html("#e2e8f0"))
	info_card.add_child(_summary_lbl)

	var btn_h := 64 if is_mob else 50
	var btn_fs := 20 if is_mob else 16

	var replay_btn := Button.new()
	replay_btn.text = "🔄 再戰一場"
	replay_btn.custom_minimum_size = Vector2(0, btn_h)
	replay_btn.add_theme_font_size_override("font_size", btn_fs)
	UiStyle.apply_button(replay_btn, "#dc2626", "#fde68a", "#ffffff", 14, 2, 1.0)
	replay_btn.pressed.connect(func() -> void:
		visible = false
		replay_pressed.emit()
	)
	vbox.add_child(replay_btn)

	var menu_btn := Button.new()
	menu_btn.text = "⛩️ 返回主選單（更換角色／關卡）"
	menu_btn.custom_minimum_size = Vector2(0, btn_h)
	menu_btn.add_theme_font_size_override("font_size", btn_fs)
	UiStyle.apply_button(menu_btn, "#1e293b", "#94a3b8", "#f8fafc", 14, 2, 0.96)
	menu_btn.pressed.connect(func() -> void:
		visible = false
		return_to_menu_pressed.emit()
	)
	vbox.add_child(menu_btn)


func open_result(is_victory: bool, reached_wave: int) -> void:
	var p := GameState.player
	var char_cfg: Dictionary = GameData.get_character(p["char_id"])
	var stage_cfg: Dictionary = GameData.get_stage(p["stage_id"])

	if is_victory:
		_title_lbl.text = "👑 全 12 幕制覇！"
		_title_lbl.add_theme_color_override("font_color", Color.html("#fcd34d"))
	else:
		_title_lbl.text = "💀 体力歸零・修行敗北"
		_title_lbl.add_theme_color_override("font_color", Color.html("#fb7185"))

	_summary_lbl.text = "角色：%s %s (Lv.%d)\n關卡：%s %s（到達第 %d 幕）\n累計擊殺：%d 隻  ｜  持有金幣：%d 🪙" % [
		char_cfg["icon"],
		char_cfg["name"],
		int(p["level"]),
		stage_cfg["icon"],
		stage_cfg["name"],
		reached_wave,
		int(p["total_kills"]),
		int(p["gold"]),
	]
	visible = true
