class_name PauseModal
extends Control
## Refined Wafuu Shrine Glass pause menu overlay with battle snapshot, resume, upgrades, audio, restart, and main menu.

signal resume_pressed
signal restart_pressed
signal upgrade_pressed
signal return_to_menu_pressed

var _hero_badge_lbl: Label
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
	backdrop.color = Color(0.02, 0.03, 0.08, 0.78)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(640 if is_mob else 450, 0)
	panel.add_theme_stylebox_override("panel", UiStyle.make_shrine_modal("#090e1d", "#e8c474", 24, 30, 26))
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 15 if is_mob else 12)
	panel.add_child(vbox)

	var sub_tag := Label.new()
	sub_tag.text = "✨  言霊剣士・休息整備  ✨"
	sub_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_tag.add_theme_font_size_override("font_size", 15 if is_mob else 12)
	sub_tag.add_theme_color_override("font_color", Color.html("#d4b06a"))
	vbox.add_child(sub_tag)

	var title := Label.new()
	title.text = "⏸️ 遊戲暫停"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36 if is_mob else 26)
	title.add_theme_color_override("font_color", Color.html("#fef3c7"))
	vbox.add_child(title)

	vbox.add_child(UiStyle.make_divider("#e6c37a", 0.35, 1))

	# Battle snapshot glass card
	var snap_card := PanelContainer.new()
	snap_card.add_theme_stylebox_override("panel", UiStyle.make_panel("#0d152b", 0.88, "#e6c37a", 0.28, 16, 1, 16, 11, 6))
	vbox.add_child(snap_card)

	var snap_v := VBoxContainer.new()
	snap_v.add_theme_constant_override("separation", 4)
	snap_card.add_child(snap_v)

	_hero_badge_lbl = Label.new()
	_hero_badge_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hero_badge_lbl.add_theme_font_size_override("font_size", 21 if is_mob else 15)
	_hero_badge_lbl.add_theme_color_override("font_color", Color.html("#fcd34d"))
	snap_v.add_child(_hero_badge_lbl)

	_info_lbl = Label.new()
	_info_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info_lbl.add_theme_font_size_override("font_size", 18 if is_mob else 13)
	_info_lbl.add_theme_color_override("font_color", Color.html("#cbd5e1"))
	snap_v.add_child(_info_lbl)

	var btn_h := 72 if is_mob else 48
	var btn_fs := 23 if is_mob else 15

	var resume_btn := _make_btn("▶️ 繼續戰鬥（Esc）", "#059669", "#a7f3d0", "#ffffff", btn_h, btn_fs)
	resume_btn.pressed.connect(func() -> void:
		visible = false
		resume_pressed.emit()
	)
	vbox.add_child(resume_btn)

	var upg_btn := _make_btn("⚡ 技能 / 裝備 / 式神 / 辭典", "#172038", "#e8c474", "#fef3c7", btn_h, btn_fs)
	upg_btn.pressed.connect(func() -> void:
		visible = false
		upgrade_pressed.emit()
	)
	vbox.add_child(upg_btn)

	_audio_btn = _make_btn("🔊 音效：開啟", "#172038", "#38bdf8", "#bae6fd", btn_h, btn_fs)
	_audio_btn.pressed.connect(func() -> void: AudioManager.toggle_audio())
	vbox.add_child(_audio_btn)

	var restart_btn := _make_btn("🔄 重新開始本局", "#172038", "#f59e0b", "#fde68a", btn_h, btn_fs)
	restart_btn.pressed.connect(func() -> void:
		visible = false
		restart_pressed.emit()
	)
	vbox.add_child(restart_btn)

	vbox.add_child(UiStyle.make_divider("#f43f5e", 0.25, 1))

	var menu_btn := _make_btn("⛩️ 返回主選單", "#7f1d1d", "#fda4af", "#ffffff", btn_h, btn_fs)
	menu_btn.pressed.connect(func() -> void:
		visible = false
		return_to_menu_pressed.emit()
	)
	vbox.add_child(menu_btn)

	_update_audio_text()


func _make_btn(label: String, bg: String, border: String, txt: String, h: int, fs: int) -> Button:
	var btn := Button.new()
	btn.focus_mode = Control.FOCUS_NONE
	btn.text = label
	btn.custom_minimum_size = Vector2(0, h)
	btn.add_theme_font_size_override("font_size", fs)
	UiStyle.apply_button(btn, bg, border, txt, 16, 1, 0.95)
	return btn


func _update_audio_text() -> void:
	if _audio_btn != null:
		_audio_btn.text = "🔊 音效：開啟" if AudioManager.audio_enabled else "🔇 音效：靜音"


func open_pause() -> void:
	var p := GameState.player
	var b := GameState.battle
	var char_cfg: Dictionary = GameData.get_character(p["char_id"])
	var stage_cfg: Dictionary = GameData.get_stage(p["stage_id"])
	var mode_cfg: Dictionary = GameData.get_mode(p["mode"])
	_hero_badge_lbl.text = "%s %s（Lv.%d）  ｜  %s %s・第 %d 幕" % [
		char_cfg["icon"],
		char_cfg["name"],
		int(p["level"]),
		stage_cfg["icon"],
		stage_cfg["name"],
		int(b.get("wave", 1)),
	]
	_info_lbl.text = "%s  ｜  HP %d/%d  ｜  🪙 %d  ｜  ✨ %dpt" % [
		mode_cfg["label"],
		int(b.get("hp", 100)),
		int(b.get("max_hp", 100)),
		int(p["gold"]),
		int(p["skill_points"]),
	]
	_update_audio_text()
	visible = true
