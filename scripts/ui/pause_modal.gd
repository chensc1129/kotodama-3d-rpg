class_name PauseModal
extends Control
## In-game pause menu overlay with resume, restart, upgrade/equipment, audio toggle, and return to main menu.

signal resume_pressed
signal restart_pressed
signal upgrade_pressed
signal return_to_menu_pressed

var _info_lbl: Label
var _audio_btn: Button


func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	AudioManager.audio_toggled.connect(func(_on: bool) -> void: _update_audio_text())


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
	panel.custom_minimum_size = Vector2(520 if is_mob else 440, 0)
	panel.add_theme_stylebox_override("panel", UiStyle.make_panel("#0f172a", 0.96, "#fbbf24", 0.85, 24, 2, 28, 24))
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14 if is_mob else 11)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "⏸️ 遊戲暫停"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30 if is_mob else 25)
	title.add_theme_color_override("font_color", Color.html("#fcd34d"))
	vbox.add_child(title)

	_info_lbl = Label.new()
	_info_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info_lbl.add_theme_font_size_override("font_size", 16 if is_mob else 13)
	_info_lbl.add_theme_color_override("font_color", Color.html("#cbd5e1"))
	vbox.add_child(_info_lbl)

	var btn_h := 62 if is_mob else 48
	var btn_fs := 20 if is_mob else 16

	var resume_btn := _make_btn("▶️ 繼續戰鬥", "#10b981", "#6ee7b7", "#0f172a", btn_h, btn_fs)
	resume_btn.pressed.connect(func() -> void:
		visible = false
		resume_pressed.emit()
	)
	vbox.add_child(resume_btn)

	var upg_btn := _make_btn("⚡ 技能 / 裝備 / 式神整備", "#1e293b", "#fbbf24", "#fde68a", btn_h, btn_fs)
	upg_btn.pressed.connect(func() -> void:
		visible = false
		upgrade_pressed.emit()
	)
	vbox.add_child(upg_btn)

	_audio_btn = _make_btn("🔊 音效：開啟", "#1e293b", "#38bdf8", "#bae6fd", btn_h, btn_fs)
	_audio_btn.pressed.connect(func() -> void: AudioManager.toggle_audio())
	vbox.add_child(_audio_btn)

	var restart_btn := _make_btn("🔄 重新開始本局", "#1e293b", "#f97316", "#fed7aa", btn_h, btn_fs)
	restart_btn.pressed.connect(func() -> void:
		visible = false
		restart_pressed.emit()
	)
	vbox.add_child(restart_btn)

	var menu_btn := _make_btn("⛩️ 返回主選單", "#7f1d1d", "#fca5a5", "#ffffff", btn_h, btn_fs)
	menu_btn.pressed.connect(func() -> void:
		visible = false
		return_to_menu_pressed.emit()
	)
	vbox.add_child(menu_btn)

	_update_audio_text()


func _make_btn(label: String, bg: String, border: String, txt: String, h: int, fs: int) -> Button:
	var btn := Button.new()
	btn.text = label
	btn.custom_minimum_size = Vector2(0, h)
	btn.add_theme_font_size_override("font_size", fs)
	UiStyle.apply_button(btn, bg, border, txt, 14, 2, 0.96)
	return btn


func _update_audio_text() -> void:
	if _audio_btn != null:
		_audio_btn.text = "🔊 音效：開啟" if AudioManager.audio_enabled else "🔇 音效：靜音"


func open_pause() -> void:
	var char_cfg: Dictionary = GameData.get_character(GameState.player["char_id"])
	var stage_cfg: Dictionary = GameData.get_stage(GameState.player["stage_id"])
	var mode_cfg: Dictionary = GameData.get_mode(GameState.player["mode"])
	_info_lbl.text = "%s %s ｜ %s %s 第 %d 幕 ｜ %s" % [
		char_cfg["icon"],
		char_cfg["name"],
		stage_cfg["icon"],
		stage_cfg["name"],
		int(GameState.battle.get("wave", 1)),
		mode_cfg["label"],
	]
	_update_audio_text()
	visible = true
