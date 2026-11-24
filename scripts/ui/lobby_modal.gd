class_name LobbyModal
extends Control
## Lobby modal for custom name, 5-character selection, 4-stage selection, and 4 challenge modes.

signal start_battle_pressed

var _name_input: LineEdit
var _char_grid: GridContainer
var _stage_grid: GridContainer
var _mode_grid: GridContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	GameState.state_changed.connect(refresh)
	refresh()


func _build_ui() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.02, 0.03, 0.09, 0.78)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	add_child(margin)

	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(920, 620)
	panel.add_theme_stylebox_override("panel", UiStyle.make_panel("#0f172a", 0.94, "#fbbf24", 0.65, 24, 2, 24, 20))
	center.add_child(panel)

	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 14)
	scroll.add_child(vbox)

	# Header
	var header := HBoxContainer.new()
	vbox.add_child(header)

	var title_box := VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title_box)

	var ver_lbl := Label.new()
	ver_lbl.text = "Ver 2.0 資料片｜百鬼夜行・新角色與新關卡（Godot 4.3 引擎驅動）"
	ver_lbl.add_theme_font_size_override("font_size", 12)
	ver_lbl.add_theme_color_override("font_color", Color.html("#fda4af"))
	title_box.add_child(ver_lbl)

	var main_title := Label.new()
	main_title.text = "⛩️ 言霊剣士・あの一撃 3D"
	main_title.add_theme_font_size_override("font_size", 28)
	main_title.add_theme_color_override("font_color", Color.html("#fcd34d"))
	title_box.add_child(main_title)

	var cap_panel := PanelContainer.new()
	cap_panel.add_theme_stylebox_override("panel", UiStyle.make_panel("#1e293b", 0.95, "#fbbf24", 0.45, 12, 1, 12, 6))
	var cap_lbl := Label.new()
	cap_lbl.text = "最高等級 Lv.100 制覇"
	cap_lbl.add_theme_font_size_override("font_size", 13)
	cap_lbl.add_theme_color_override("font_color", Color.html("#fcd34d"))
	cap_panel.add_child(cap_lbl)
	header.add_child(cap_panel)

	# Custom Name Bar
	var name_panel := PanelContainer.new()
	name_panel.add_theme_stylebox_override("panel", UiStyle.make_panel("#0b1120", 0.92, "#334155", 0.9, 14, 1, 14, 10))
	vbox.add_child(name_panel)

	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 10)
	name_panel.add_child(name_row)

	var name_lbl := Label.new()
	name_lbl.text = "🏷️ 自訂角色名稱："
	name_lbl.add_theme_font_size_override("font_size", 14)
	name_lbl.add_theme_color_override("font_color", Color.html("#cbd5e1"))
	name_row.add_child(name_lbl)

	_name_input = LineEdit.new()
	_name_input.max_length = 12
	_name_input.custom_minimum_size = Vector2(220, 36)
	UiStyle.apply_line_edit(_name_input, "#fbbf24")
	_name_input.text_submitted.connect(func(_t: String) -> void: GameState.set_player_name(_name_input.text))
	name_row.add_child(_name_input)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_row.add_child(spacer)

	var rand_btn := Button.new()
	rand_btn.text = "🎲 隨機和風取名"
	UiStyle.apply_button(rand_btn, "#1e293b", "#64748b", "#fde68a", 10, 1, 0.95)
	rand_btn.pressed.connect(func() -> void:
		var pick: String = GameData.RANDOM_NAMES[randi() % GameData.RANDOM_NAMES.size()]
		_name_input.text = pick
		GameState.set_player_name(pick)
	)
	name_row.add_child(rand_btn)

	var confirm_btn := Button.new()
	confirm_btn.text = "確認名字"
	UiStyle.apply_button(confirm_btn, "#f59e0b", "#fde68a", "#0f172a", 10, 1, 1.0)
	confirm_btn.pressed.connect(func() -> void: GameState.set_player_name(_name_input.text))
	name_row.add_child(confirm_btn)

	# Step 1: Characters
	vbox.add_child(_make_section_title("🎭 選擇出戰 3D 角色（普攻皆為「あ」三段斬，技能按鍵各有專屬奧義）：", "#fcd34d"))
	_char_grid = GridContainer.new()
	_char_grid.columns = 3
	_char_grid.add_theme_constant_override("h_separation", 10)
	_char_grid.add_theme_constant_override("v_separation", 10)
	vbox.add_child(_char_grid)

	# Step 2: Stages
	vbox.add_child(_make_section_title("🗺️ 選擇 3D 戰鬥關卡場景：", "#7dd3fc"))
	_stage_grid = GridContainer.new()
	_stage_grid.columns = 4
	_stage_grid.add_theme_constant_override("h_separation", 10)
	_stage_grid.add_theme_constant_override("v_separation", 10)
	vbox.add_child(_stage_grid)

	# Step 3: Modes
	vbox.add_child(_make_section_title("🔥 選擇挑戰模式：", "#fda4af"))
	_mode_grid = GridContainer.new()
	_mode_grid.columns = 4
	_mode_grid.add_theme_constant_override("h_separation", 10)
	_mode_grid.add_theme_constant_override("v_separation", 10)
	vbox.add_child(_mode_grid)

	# Footer CTA
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 14)
	vbox.add_child(footer)

	var tip := Label.new()
	tip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip.text = "💡 提示：WASD/方向鍵移動，按 J 或「あ」三段斬累積 30 SP，按 1/K 或技能鍵詠唱日文施放專屬技（2/Q 全屏奧義，Space 瞬步）！"
	tip.add_theme_font_size_override("font_size", 12)
	tip.add_theme_color_override("font_color", Color.html("#94a3b8"))
	footer.add_child(tip)

	var start_btn := Button.new()
	start_btn.text = "⚔️ 進入 3D 道場開戰！"
	start_btn.custom_minimum_size = Vector2(230, 50)
	start_btn.add_theme_font_size_override("font_size", 17)
	UiStyle.apply_button(start_btn, "#dc2626", "#fde68a", "#ffffff", 14, 2, 1.0)
	start_btn.pressed.connect(func() -> void:
		if _name_input.text.strip_edges() != GameState.player["name"] and not _name_input.text.strip_edges().is_empty():
			GameState.set_player_name(_name_input.text)
		visible = false
		start_battle_pressed.emit()
	)
	footer.add_child(start_btn)


func _make_section_title(text: String, hex_col: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 15)
	lbl.add_theme_color_override("font_color", Color.html(hex_col))
	return lbl


func open_lobby() -> void:
	GameState.battle["paused"] = true
	refresh()
	visible = true


func refresh() -> void:
	if _name_input != null and not _name_input.has_focus():
		_name_input.text = String(GameState.player["name"])

	if _char_grid != null:
		for c in _char_grid.get_children():
			c.queue_free()
		for cid in GameData.CHARACTER_ORDER:
			var ch: Dictionary = GameData.CHARACTERS[cid]
			var selected: bool = GameState.player["char_id"] == cid
			var btn := Button.new()
			btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			btn.custom_minimum_size = Vector2(0, 96)
			btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
			btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			btn.text = "%s %s【%s】 鍵：%s\n%s" % [ch["icon"], ch["name"], ch["title"], ch["sig_key"], ch["desc"]]
			btn.add_theme_font_size_override("font_size", 12)
			if selected:
				UiStyle.apply_button(btn, "#78350f", "#fbbf24", "#fef3c7", 14, 2, 0.72)
			else:
				UiStyle.apply_button(btn, "#0f172a", "#334155", "#e2e8f0", 14, 1, 0.90)
			var pick_id: String = cid
			btn.pressed.connect(func() -> void: GameState.set_character(pick_id))
			_char_grid.add_child(btn)

	if _stage_grid != null:
		for c in _stage_grid.get_children():
			c.queue_free()
		for st in GameData.STAGES:
			var selected: bool = GameState.player["stage_id"] == st["id"]
			var btn := Button.new()
			btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			btn.custom_minimum_size = Vector2(0, 82)
			btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
			btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			btn.text = "%s %s\n%s" % [st["icon"], st["name"], st["desc"]]
			btn.add_theme_font_size_override("font_size", 12)
			if selected:
				UiStyle.apply_button(btn, "#0c4a6e", "#38bdf8", "#e0f2fe", 14, 2, 0.78)
			else:
				UiStyle.apply_button(btn, "#0f172a", "#334155", "#cbd5e1", 14, 1, 0.90)
			var sid: String = st["id"]
			btn.pressed.connect(func() -> void: GameState.set_stage(sid))
			_stage_grid.add_child(btn)

	if _mode_grid != null:
		for c in _mode_grid.get_children():
			c.queue_free()
		for m in GameData.GAME_MODES:
			var selected: bool = GameState.player["mode"] == m["id"]
			var btn := Button.new()
			btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			btn.custom_minimum_size = Vector2(0, 72)
			btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
			btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			btn.text = "%s\n%s" % [m["label"], m["desc"]]
			btn.add_theme_font_size_override("font_size", 12)
			if selected:
				UiStyle.apply_button(btn, "#78350f", "#fbbf24", m["color"], 14, 2, 0.75)
			else:
				UiStyle.apply_button(btn, "#0f172a", "#334155", m["color"], 14, 1, 0.90)
			var mid: String = m["id"]
			btn.pressed.connect(func() -> void: GameState.set_mode(mid))
			_mode_grid.add_child(btn)
