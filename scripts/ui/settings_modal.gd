class_name SettingsModal
extends Control
## Wafuu Shrine Settings & Full Controls Guide Modal.
## Houses audio toggle, camera sensitivity, mobile landscape fullscreen, and all keyboard/mouse/touch
## control instructions (moved cleanly out of the main gameplay HUD!).

signal modal_closed

var _backdrop: ColorRect
var _panel: PanelContainer
var _audio_btn: Button
var _sens_buttons: Dictionary = {}


func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	AudioManager.audio_toggled.connect(func(_on: bool) -> void: _refresh_state())


func _build_ui() -> void:
	var is_mob := UiStyle.is_mobile_device()

	_backdrop = ColorRect.new()
	_backdrop.color = Color(0.02, 0.03, 0.08, 0.84)
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_backdrop)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(820 if is_mob else 660, 0)
	_panel.add_theme_stylebox_override("panel", UiStyle.make_shrine_modal("#080d1c", "#38bdf8", 24, 28, 22))
	center.add_child(_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 13 if is_mob else 11)
	_panel.add_child(vbox)

	# Header
	var header := HBoxContainer.new()
	vbox.add_child(header)

	var title := Label.new()
	title.text = "⚙️ 系統設定與操作指南"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 28 if is_mob else 21)
	title.add_theme_color_override("font_color", Color.html("#fef3c7"))
	UiStyle.style_label_shadow(title, 0.78, 2)
	header.add_child(title)

	var close_btn := Button.new()
	close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.text = "✖ 關閉"
	close_btn.custom_minimum_size = Vector2(116 if is_mob else 86, 48 if is_mob else 38)
	close_btn.add_theme_font_size_override("font_size", 18 if is_mob else 13)
	UiStyle.apply_button(close_btn, "#1c1326", "#fb7185", "#fecdd3", 14, 1, 0.95)
	close_btn.pressed.connect(close_modal)
	header.add_child(close_btn)

	vbox.add_child(UiStyle.make_ornament_divider("#38bdf8", 0.50))

	# === Section 1: Audio & Camera Controls ===
	var sys_card := PanelContainer.new()
	sys_card.add_theme_stylebox_override("panel", UiStyle.make_accent_card("#0c1428", "#e8c474", false, 16, 16, 12))
	vbox.add_child(sys_card)

	var sys_v := VBoxContainer.new()
	sys_v.add_theme_constant_override("separation", 10)
	sys_card.add_child(sys_v)

	# Row 1: Audio Toggle
	var audio_row := HBoxContainer.new()
	audio_row.add_theme_constant_override("separation", 12)
	sys_v.add_child(audio_row)

	var audio_lbl := Label.new()
	audio_lbl.text = "🔊 戰鬥音效與日文語音"
	audio_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	audio_lbl.add_theme_font_size_override("font_size", 18 if is_mob else 14)
	audio_lbl.add_theme_color_override("font_color", Color.html("#e2e8f0"))
	audio_row.add_child(audio_lbl)

	_audio_btn = Button.new()
	_audio_btn.focus_mode = Control.FOCUS_NONE
	_audio_btn.custom_minimum_size = Vector2(168 if is_mob else 130, 48 if is_mob else 36)
	_audio_btn.add_theme_font_size_override("font_size", 17 if is_mob else 13)
	_audio_btn.pressed.connect(func() -> void: AudioManager.toggle_audio())
	audio_row.add_child(_audio_btn)

	# Row 2: Mouse Look Sensitivity
	var sens_row := HBoxContainer.new()
	sens_row.add_theme_constant_override("separation", 8)
	sys_v.add_child(sens_row)

	var sens_lbl := Label.new()
	sens_lbl.text = "🖱️ 滑鼠視角靈敏度"
	sens_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sens_lbl.add_theme_font_size_override("font_size", 18 if is_mob else 14)
	sens_lbl.add_theme_color_override("font_color", Color.html("#e2e8f0"))
	sens_row.add_child(sens_lbl)

	for opt in [[0.7, "低 (0.7×)"], [1.0, "標準 (1.0×)"], [1.4, "高 (1.4×)"]]:
		var sv: float = float(opt[0])
		var sb := Button.new()
		sb.focus_mode = Control.FOCUS_NONE
		sb.text = opt[1]
		sb.custom_minimum_size = Vector2(118 if is_mob else 92, 44 if is_mob else 34)
		sb.add_theme_font_size_override("font_size", 16 if is_mob else 12)
		sb.pressed.connect(func() -> void:
			GameState.mouse_sens_mult = sv
			_refresh_state()
		)
		sens_row.add_child(sb)
		_sens_buttons[sv] = sb

	if is_mob:
		var fs_btn := Button.new()
		fs_btn.focus_mode = Control.FOCUS_NONE
		fs_btn.text = "📱 鎖定橫向全螢幕顯示"
		fs_btn.custom_minimum_size = Vector2(0, 50)
		fs_btn.add_theme_font_size_override("font_size", 18)
		UiStyle.apply_button(fs_btn, "#0c4a6e", "#38bdf8", "#e0f2fe", 14, 1, 0.95)
		fs_btn.pressed.connect(func() -> void: UiStyle.request_mobile_landscape_fullscreen())
		sys_v.add_child(fs_btn)

	# === Section 2: Full Controls Guide (Moved cleanly out of Battle HUD!) ===
	var ctrl_title := Label.new()
	ctrl_title.text = "🎮 戰鬥操作說明（點擊畫面鎖定滑鼠準心）"
	ctrl_title.add_theme_font_size_override("font_size", 19 if is_mob else 14)
	ctrl_title.add_theme_color_override("font_color", Color.html("#7dd3fc"))
	vbox.add_child(ctrl_title)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 8)
	vbox.add_child(grid)

	var controls := [
		["WASD", "360° 角色移動"],
		["滑鼠移動 / 滾輪", "越肩視角轉向 / 縮放視距"],
		["滑鼠左鍵 / あ", "角色專屬三段連擊與特效"],
		["Space", "跳躍（跨越熔岩／躍上高台）"],
		["Shift（長按）", "消耗體力高速急跑"],
		["Shift 連按兩下 / 右鍵", "爆發快速衝刺（附無敵幀）"],
		["E 鍵（30 SP）", "詠唱角色專屬必殺技"],
		["Q 鍵（70 SP）", "詠唱 30 詞彙全屏言靈奧義"],
		["高地壓制", "站得比怪物高自動享 +15% 傷害"],
		["F 鍵（冒險模式）", "與地圖 NPC 對話與日文試煉"],
		["Esc 鍵", "隨時開啟暫停選單與設定"],
	]
	for item in controls:
		var cell := PanelContainer.new()
		cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		cell.add_theme_stylebox_override("panel", UiStyle.make_panel("#0b1326", 0.92, "#334155", 0.65, 12, 1, 12, 8, 4))
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		cell.add_child(row)

		row.add_child(UiStyle.make_badge_pill(item[0], "#16203a", "#e8c474", "#fde68a", 13 if is_mob else 11))

		var desc := Label.new()
		desc.text = item[1]
		desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.add_theme_font_size_override("font_size", 15 if is_mob else 12)
		desc.add_theme_color_override("font_color", Color.html("#cbd5e1"))
		row.add_child(desc)
		grid.add_child(cell)

	_refresh_state()


func _refresh_state() -> void:
	if _audio_btn != null:
		if AudioManager.audio_enabled:
			_audio_btn.text = "🔊 開啟中"
			UiStyle.apply_button(_audio_btn, "#065f46", "#34d399", "#d1fae5", 12, 1, 0.96)
		else:
			_audio_btn.text = "🔇 已靜音"
			UiStyle.apply_button(_audio_btn, "#3f1421", "#fb7185", "#fecdd3", 12, 1, 0.96)

	for k in _sens_buttons.keys():
		var btn: Button = _sens_buttons[k]
		var active := absf(float(k) - GameState.mouse_sens_mult) < 0.05
		if active:
			UiStyle.apply_button(btn, "#0284c7", "#bae6fd", "#ffffff", 11, 2, 1.0)
		else:
			UiStyle.apply_button(btn, "#121b33", "#475569", "#cbd5e1", 11, 1, 0.94)


func open_settings() -> void:
	_refresh_state()
	visible = true
	UiStyle.animate_modal_open(self, _backdrop, _panel, 0.22)


func close_modal() -> void:
	visible = false
	modal_closed.emit()
