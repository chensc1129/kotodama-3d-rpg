class_name ResultModal
extends Control
## Victory / Defeat summary overlay with dynamic victory/defeat crest theme,
## 4-tile structured Battle Report Grid, and spring-pop opening animation.

signal replay_pressed
signal return_to_menu_pressed

var _backdrop: ColorRect
var _panel: PanelContainer
var _badge_lbl: Label
var _title_lbl: Label
var _tile_hero: Label
var _tile_stage: Label
var _tile_kills: Label
var _tile_gold: Label


func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()


func _build_ui() -> void:
	var is_mob := UiStyle.is_mobile_device()

	_backdrop = ColorRect.new()
	_backdrop.color = Color(0.02, 0.03, 0.08, 0.85)
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_backdrop)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(680 if is_mob else 510, 0)
	_panel.add_theme_stylebox_override("panel", UiStyle.make_shrine_modal("#080d1c", "#e8c474", 24, 30, 26))
	center.add_child(_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 15)
	_panel.add_child(vbox)

	_badge_lbl = Label.new()
	_badge_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_badge_lbl.add_theme_font_size_override("font_size", 16 if is_mob else 12)
	_badge_lbl.add_theme_color_override("font_color", Color.html("#d4b06a"))
	vbox.add_child(_badge_lbl)

	_title_lbl = Label.new()
	_title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_lbl.add_theme_font_size_override("font_size", 38 if is_mob else 28)
	UiStyle.style_label_shadow(_title_lbl, 0.8, 2)
	vbox.add_child(_title_lbl)

	vbox.add_child(UiStyle.make_ornament_divider("#e6c37a", 0.50))

	# 2x2 Battle Report KPI Grid
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 12)
	vbox.add_child(grid)

	_tile_hero = _add_report_tile(grid, "出戰劍士", "#fef3c7", "#e8c474", is_mob)
	_tile_stage = _add_report_tile(grid, "到達戰場", "#7dd3fc", "#38bdf8", is_mob)
	_tile_kills = _add_report_tile(grid, "累計斬妖", "#fda4af", "#f43f5e", is_mob)
	_tile_gold = _add_report_tile(grid, "持有金幣", "#fcd34d", "#f59e0b", is_mob)

	var btn_h := 72 if is_mob else 50
	var btn_fs := 22 if is_mob else 16

	var replay_btn := Button.new()
	replay_btn.focus_mode = Control.FOCUS_NONE
	replay_btn.text = "🔄 再戰一場"
	replay_btn.custom_minimum_size = Vector2(0, btn_h)
	replay_btn.add_theme_font_size_override("font_size", btn_fs)
	UiStyle.apply_button(replay_btn, "#be123c", "#fde68a", "#ffffff", 16, 2, 1.0)
	replay_btn.pressed.connect(func() -> void:
		visible = false
		replay_pressed.emit()
	)
	vbox.add_child(replay_btn)

	var menu_btn := Button.new()
	menu_btn.focus_mode = Control.FOCUS_NONE
	menu_btn.text = "⛩️ 返回主選單（更換角色／關卡）"
	menu_btn.custom_minimum_size = Vector2(0, btn_h)
	menu_btn.add_theme_font_size_override("font_size", btn_fs)
	UiStyle.apply_button(menu_btn, "#15203b", "#e6c37a", "#fef3c7", 16, 1, 0.96)
	menu_btn.pressed.connect(func() -> void:
		visible = false
		return_to_menu_pressed.emit()
	)
	vbox.add_child(menu_btn)


func _add_report_tile(parent: GridContainer, label_txt: String, val_hex: String, accent_hex: String, is_mob: bool) -> Label:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", UiStyle.make_accent_card("#0d162c", accent_hex, false, 14, 14, 10))
	parent.add_child(card)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	card.add_child(v)

	var cap := Label.new()
	cap.text = label_txt
	cap.add_theme_font_size_override("font_size", 14 if is_mob else 11)
	cap.add_theme_color_override("font_color", Color.html("#94a3b8"))
	v.add_child(cap)

	var val := Label.new()
	val.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	val.add_theme_font_size_override("font_size", 20 if is_mob else 15)
	val.add_theme_color_override("font_color", Color.html(val_hex))
	v.add_child(val)
	return val


func open_result(is_victory: bool, reached_wave: int) -> void:
	var p := GameState.player
	var char_cfg: Dictionary = GameData.get_character(p["char_id"])
	var stage_cfg: Dictionary = GameData.get_stage(p["stage_id"])

	if is_victory:
		_panel.add_theme_stylebox_override("panel", UiStyle.make_shrine_modal("#0a1020", "#fbbf24", 24, 30, 26))
		_badge_lbl.text = "✨  百鬼退散・道場制覇  ✨"
		_title_lbl.text = "👑 全 12 幕制覇！"
		_title_lbl.add_theme_color_override("font_color", Color.html("#fcd34d"))
	else:
		_panel.add_theme_stylebox_override("panel", UiStyle.make_shrine_modal("#140914", "#fb7185", 24, 30, 26))
		_badge_lbl.text = "🔥  捲土重來・再試鋒芒  🔥"
		_title_lbl.text = "💀 体力歸零・修行敗北"
		_title_lbl.add_theme_color_override("font_color", Color.html("#fb7185"))

	_tile_hero.text = "%s %s（Lv.%d）" % [char_cfg["icon"], char_cfg["name"], int(p["level"])]
	_tile_stage.text = "%s %s・第 %d 幕" % [stage_cfg["icon"], stage_cfg["name"], reached_wave]
	_tile_kills.text = "%d 隻妖怪" % int(p["total_kills"])
	_tile_gold.text = "%d 🪙" % int(p["gold"])

	visible = true
	UiStyle.animate_modal_open(self, _backdrop, _panel, 0.28)
