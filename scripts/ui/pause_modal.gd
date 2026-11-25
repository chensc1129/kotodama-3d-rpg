class_name PauseModal
extends Control
## Refined Wafuu Shrine Glass pause menu overlay with spring-pop opening animation,
## 3-tile battle snapshot cards, quick dictionary/prep access, audio, restart, and main menu.

signal resume_pressed
signal restart_pressed
signal upgrade_pressed
signal dictionary_pressed
signal settings_pressed
signal return_to_menu_pressed

var _backdrop: ColorRect
var _panel: PanelContainer
var _hero_val_lbl: Label
var _stage_val_lbl: Label
var _res_val_lbl: Label
var _audio_btn: Button


func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	AudioManager.audio_toggled.connect(func(_on: bool) -> void: _update_audio_text())


func _build_ui() -> void:
	var is_mob := UiStyle.is_mobile_device()

	_backdrop = ColorRect.new()
	_backdrop.color = Color(0.02, 0.03, 0.08, 0.80)
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_backdrop)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(680 if is_mob else 490, 0)
	_panel.add_theme_stylebox_override("panel", UiStyle.make_shrine_modal("#080d1c", "#e8c474", 24, 30, 26))
	center.add_child(_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14 if is_mob else 11)
	_panel.add_child(vbox)

	# Shrine crest subtitle + shadowed title
	var sub_tag := Label.new()
	sub_tag.text = "✨  言霊剣士・休息整備  ✨"
	sub_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_tag.add_theme_font_size_override("font_size", 15 if is_mob else 12)
	sub_tag.add_theme_color_override("font_color", Color.html("#d4b06a"))
	vbox.add_child(sub_tag)

	var title := Label.new()
	title.text = "⏸️ 遊戲暫停"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 36 if is_mob else 27)
	title.add_theme_color_override("font_color", Color.html("#fef3c7"))
	UiStyle.style_label_shadow(title, 0.75, 2)
	vbox.add_child(title)

	vbox.add_child(UiStyle.make_ornament_divider("#e6c37a", 0.50))

	# 3-Tile Structured Battle Snapshot Strip
	var snap_row := HBoxContainer.new()
	snap_row.add_theme_constant_override("separation", 10 if is_mob else 8)
	vbox.add_child(snap_row)

	_hero_val_lbl = _add_kpi_tile(snap_row, "出戰角色", "#fcd34d", "#e8c474", is_mob)
	_stage_val_lbl = _add_kpi_tile(snap_row, "目前戰場", "#7dd3fc", "#38bdf8", is_mob)
	_res_val_lbl = _add_kpi_tile(snap_row, "資源狀態", "#a7f3d0", "#34d399", is_mob)

	var btn_h := 68 if is_mob else 46
	var btn_fs := 22 if is_mob else 15

	var resume_btn := _make_btn("▶️ 繼續戰鬥（Esc）", "#059669", "#a7f3d0", "#ffffff", btn_h, btn_fs, 2)
	resume_btn.pressed.connect(func() -> void:
		visible = false
		resume_pressed.emit()
	)
	vbox.add_child(resume_btn)

	# Two-column secondary action row: Prep & Dictionary
	var mid_row := HBoxContainer.new()
	mid_row.add_theme_constant_override("separation", 10)
	vbox.add_child(mid_row)

	var upg_btn := _make_btn("⚡ 技能／裝備／式神", "#15203b", "#e8c474", "#fef3c7", btn_h, btn_fs - 1, 1)
	upg_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	upg_btn.pressed.connect(func() -> void:
		visible = false
		upgrade_pressed.emit()
	)
	mid_row.add_child(upg_btn)

	var dict_btn := _make_btn("📖 言靈辭典", "#102340", "#38bdf8", "#bae6fd", btn_h, btn_fs - 1, 1)
	dict_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dict_btn.pressed.connect(func() -> void:
		visible = false
		dictionary_pressed.emit()
	)
	mid_row.add_child(dict_btn)

	var util_row := HBoxContainer.new()
	util_row.add_theme_constant_override("separation", 10)
	vbox.add_child(util_row)

	var set_btn := _make_btn("⚙️ 設定與操作說明", "#132238", "#38bdf8", "#bae6fd", btn_h, btn_fs - 1, 1)
	set_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	set_btn.pressed.connect(func() -> void:
		visible = false
		settings_pressed.emit()
	)
	util_row.add_child(set_btn)

	var restart_btn := _make_btn("🔄 重新開局", "#1c1a30", "#f59e0b", "#fde68a", btn_h, btn_fs - 1, 1)
	restart_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	restart_btn.pressed.connect(func() -> void:
		visible = false
		restart_pressed.emit()
	)
	util_row.add_child(restart_btn)

	vbox.add_child(UiStyle.make_ornament_divider("#fb7185", 0.35))

	var menu_btn := _make_btn("⛩️ 返回主選單", "#7f1d1d", "#fda4af", "#ffffff", btn_h, btn_fs, 1)
	menu_btn.pressed.connect(func() -> void:
		visible = false
		return_to_menu_pressed.emit()
	)
	vbox.add_child(menu_btn)

	_update_audio_text()


func _add_kpi_tile(parent: HBoxContainer, title_txt: String, val_hex: String, border_hex: String, is_mob: bool) -> Label:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", UiStyle.make_panel("#0d162c", 0.92, border_hex, 0.36, 14, 1, 10, 9, 6))
	parent.add_child(card)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	card.add_child(v)

	var cap := Label.new()
	cap.text = title_txt
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cap.add_theme_font_size_override("font_size", 14 if is_mob else 11)
	cap.add_theme_color_override("font_color", Color.html("#94a3b8"))
	v.add_child(cap)

	var val := Label.new()
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	val.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	val.add_theme_font_size_override("font_size", 17 if is_mob else 12)
	val.add_theme_color_override("font_color", Color.html(val_hex))
	v.add_child(val)
	return val


func _make_btn(label: String, bg: String, border: String, txt: String, h: int, fs: int, bw: int = 1) -> Button:
	var btn := Button.new()
	btn.focus_mode = Control.FOCUS_NONE
	btn.text = label
	btn.custom_minimum_size = Vector2(0, h)
	btn.add_theme_font_size_override("font_size", fs)
	UiStyle.apply_button(btn, bg, border, txt, 15, bw, 0.96)
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

	_hero_val_lbl.text = "%s %s\nLv.%d｜HP %d/%d" % [
		char_cfg["icon"], char_cfg["name"], int(p["level"]), int(b.get("hp", 100)), int(b.get("max_hp", 100))
	]
	_stage_val_lbl.text = "%s %s\n第 %d 幕｜%s" % [
		stage_cfg["icon"], stage_cfg["name"], int(b.get("wave", 1)), mode_cfg["label"]
	]
	_res_val_lbl.text = "🪙 %d 金幣\n✨ %d 技能點" % [int(p["gold"]), int(p["skill_points"])]
	_update_audio_text()
	visible = true
	UiStyle.animate_modal_open(self, _backdrop, _panel, 0.24)
