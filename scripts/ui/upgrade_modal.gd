class_name UpgradeModal
extends Control
## Upgrade modal with 3 tabs: Skills (Lv.1-10), Equipment Forge (+10), and Shikigami Companions.

signal modal_closed

var _current_tab: String = "skills"
var _tab_buttons: Dictionary = {}
var _gold_label: Label
var _sp_pts_label: Label
var _body_box: VBoxContainer


func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()
	GameState.state_changed.connect(func() -> void:
		if visible:
			_render_content()
	)


func _build_ui() -> void:
	var is_mob := UiStyle.is_mobile_device()

	var backdrop := ColorRect.new()
	backdrop.color = Color(0.02, 0.03, 0.08, 0.84)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 16 if is_mob else 30)
	margin.add_theme_constant_override("margin_right", 16 if is_mob else 30)
	margin.add_theme_constant_override("margin_top", 14 if is_mob else 24)
	margin.add_theme_constant_override("margin_bottom", 14 if is_mob else 24)
	add_child(margin)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiStyle.make_shrine_modal("#090e1d", "#e8c474", 24, 26, 20))
	if is_mob:
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
		margin.add_child(panel)
	else:
		var center := CenterContainer.new()
		center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		center.size_flags_vertical = Control.SIZE_EXPAND_FILL
		margin.add_child(center)
		panel.custom_minimum_size = Vector2(820, 580)
		center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14 if is_mob else 12)
	panel.add_child(vbox)

	# Tabs + Close
	var top_bar := HBoxContainer.new()
	top_bar.add_theme_constant_override("separation", 10 if is_mob else 8)
	vbox.add_child(top_bar)

	var tab_h := 56 if is_mob else 42
	var tab_fs := 19 if is_mob else 14
	var tabs := [
		["skills", "⚡ 技能升級"],
		["equip", "🎒 裝備鍛造"],
		["shikigami", "🦊 式神夥伴"],
		["dict", "📖 言靈辭典"],
	]
	for t in tabs:
		var btn := Button.new()
		btn.focus_mode = Control.FOCUS_NONE
		btn.text = t[1]
		btn.custom_minimum_size = Vector2(158 if is_mob else 124, tab_h)
		btn.add_theme_font_size_override("font_size", tab_fs)
		var tab_id: String = t[0]
		btn.pressed.connect(func() -> void: switch_tab(tab_id))
		top_bar.add_child(btn)
		_tab_buttons[tab_id] = btn

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(spacer)

	var close_btn := Button.new()
	close_btn.focus_mode = Control.FOCUS_NONE
	close_btn.text = "✖ 關閉"
	close_btn.custom_minimum_size = Vector2(120 if is_mob else 88, tab_h)
	close_btn.add_theme_font_size_override("font_size", tab_fs)
	UiStyle.apply_button(close_btn, "#172038", "#94a3b8", "#f8fafc", 14, 1, 0.95)
	close_btn.pressed.connect(close_modal)
	top_bar.add_child(close_btn)

	vbox.add_child(UiStyle.make_divider("#e6c37a", 0.32, 1))

	# Resource Bar
	var res_panel := PanelContainer.new()
	res_panel.add_theme_stylebox_override("panel", UiStyle.make_panel("#0d152b", 0.90, "#e6c37a", 0.30, 14, 1, 18, 10, 6))
	vbox.add_child(res_panel)

	var res_row := HBoxContainer.new()
	res_panel.add_child(res_row)

	_gold_label = Label.new()
	_gold_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_gold_label.add_theme_font_size_override("font_size", 20 if is_mob else 15)
	_gold_label.add_theme_color_override("font_color", Color.html("#fcd34d"))
	res_row.add_child(_gold_label)

	_sp_pts_label = Label.new()
	_sp_pts_label.add_theme_font_size_override("font_size", 20 if is_mob else 15)
	_sp_pts_label.add_theme_color_override("font_color", Color.html("#7dd3fc"))
	res_row.add_child(_sp_pts_label)

	# Scrollable Content
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	_body_box = VBoxContainer.new()
	_body_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body_box.add_theme_constant_override("separation", 12 if is_mob else 10)
	scroll.add_child(_body_box)


func open_modal(tab: String = "skills") -> void:
	GameState.battle["paused"] = true
	visible = true
	switch_tab(tab)


func close_modal() -> void:
	visible = false
	modal_closed.emit()


func switch_tab(tab: String) -> void:
	_current_tab = tab
	for k in _tab_buttons.keys():
		var btn: Button = _tab_buttons[k]
		if k == tab:
			UiStyle.apply_button(btn, "#f59e0b", "#fde68a", "#0f172a", 12, 2, 1.0)
		else:
			UiStyle.apply_button(btn, "#1e293b", "#475569", "#cbd5e1", 12, 1, 0.95)
	_render_content()


func _render_content() -> void:
	var is_mob := UiStyle.is_mobile_device()
	var row_fs := 19 if is_mob else 14
	var btn_h := 56 if is_mob else 40
	var btn_fs := 18 if is_mob else 14

	_gold_label.text = "持有金幣：%d 🪙" % int(GameState.player["gold"])
	_sp_pts_label.text = "可用技能點：%d pt" % int(GameState.player["skill_points"])

	for child in _body_box.get_children():
		child.queue_free()

	var char_cfg: Dictionary = GameData.get_character(GameState.player["char_id"])

	if _current_tab == "skills":
		var items := [
			{"key": "normal_a", "icon": "あ", "name": "「あ」三段斬撃奥義", "desc": "提升普攻連斬傷害倍率（每級 +14%）"},
			{"key": "sig_skill", "icon": char_cfg["sig_icon"], "name": "專屬奧義・%s（%s）" % [char_cfg["sig_name"], char_cfg["sig_key"]], "desc": "提升角色專屬技能威力與控制持續時間（每級 +20%）"},
			{"key": "ult_skill", "icon": "🌟", "name": "全屏言霊大奥義", "desc": "提升 70 SP 全屏大招毀滅傷害（每級 +22%）"},
			{"key": "dash_skill", "icon": "💨", "name": "疾風瞬步體術", "desc": "提升移動速度並縮短瞬步冷卻時間"},
		]
		for sk in items:
			var lv: int = int(GameState.player["skills"].get(sk["key"], 1))
			var is_max := lv >= GameData.MAX_SKILL_LEVEL
			var row := _make_row_panel("#0b1120", "#334155")
			var hbox := HBoxContainer.new()
			hbox.add_theme_constant_override("separation", 14)
			row.add_child(hbox)

			var info := Label.new()
			info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			info.text = "%s  %s  [Lv.%d / %d]\n%s" % [sk["icon"], sk["name"], lv, GameData.MAX_SKILL_LEVEL, sk["desc"]]
			info.add_theme_font_size_override("font_size", row_fs)
			hbox.add_child(info)

			var up_btn := Button.new()
			up_btn.text = "MAX" if is_max else "升級 (1pt)"
			up_btn.disabled = is_max or int(GameState.player["skill_points"]) <= 0
			up_btn.custom_minimum_size = Vector2(160 if is_mob else 115, btn_h)
			up_btn.add_theme_font_size_override("font_size", btn_fs)
			UiStyle.apply_button(up_btn, "#f59e0b", "#fde68a", "#0f172a", 12, 1, 1.0)
			var sk_key: String = sk["key"]
			up_btn.pressed.connect(func() -> void: GameState.upgrade_skill(sk_key))
			hbox.add_child(up_btn)
			_body_box.add_child(row)

	elif _current_tab == "equip":
		for eq in GameData.EQUIPMENT_LIST:
			var eq_id: String = eq["id"]
			var owned: bool = GameState.player["owned_equip"].has(eq_id)
			var is_eq: bool = GameState.player["equipped"].get(eq["slot"], "") == eq_id
			var plus: int = int(GameState.player["equip_enhance"].get(eq_id, 0))
			var enh_cost: int = 80 + plus * 60
			var atk_val := int(round(float(eq["atk"]) * (1.0 + float(plus) * 0.18)))
			var hp_val := int(round(float(eq["hp"]) * (1.0 + float(plus) * 0.18)))

			var row := _make_row_panel("#064e3b" if is_eq else "#0b1120", "#34d399" if is_eq else "#334155")
			var hbox := HBoxContainer.new()
			hbox.add_theme_constant_override("separation", 12)
			row.add_child(hbox)

			var tag := "【裝備中】" if is_eq else ""
			var plus_txt := " +%d" % plus if plus > 0 else ""
			var info := Label.new()
			info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			info.text = "%s  %s%s %s\n攻擊 +%d ｜ 生命 +%d" % [eq["icon"], eq["name"], plus_txt, tag, atk_val, hp_val]
			info.add_theme_font_size_override("font_size", row_fs)
			hbox.add_child(info)

			if not owned:
				var buy_btn := Button.new()
				buy_btn.text = "購買 (%d 🪙)" % int(eq["cost"])
				buy_btn.disabled = int(GameState.player["gold"]) < int(eq["cost"])
				buy_btn.custom_minimum_size = Vector2(175 if is_mob else 130, btn_h)
				buy_btn.add_theme_font_size_override("font_size", btn_fs)
				UiStyle.apply_button(buy_btn, "#f59e0b", "#fde68a", "#0f172a", 12, 1, 1.0)
				buy_btn.pressed.connect(func() -> void: GameState.buy_or_equip_item(eq_id, "buy"))
				hbox.add_child(buy_btn)
			else:
				if not is_eq:
					var eq_btn := Button.new()
					eq_btn.text = "裝備"
					eq_btn.custom_minimum_size = Vector2(115 if is_mob else 80, btn_h)
					eq_btn.add_theme_font_size_override("font_size", btn_fs)
					UiStyle.apply_button(eq_btn, "#10b981", "#6ee7b7", "#0f172a", 12, 1, 1.0)
					eq_btn.pressed.connect(func() -> void: GameState.buy_or_equip_item(eq_id, "equip"))
					hbox.add_child(eq_btn)
				var enh_btn := Button.new()
				enh_btn.text = "強化 MAX" if plus >= GameData.MAX_EQUIP_ENHANCE else "鍛造 +1 (%d 🪙)" % enh_cost
				enh_btn.disabled = plus >= GameData.MAX_EQUIP_ENHANCE or int(GameState.player["gold"]) < enh_cost
				enh_btn.custom_minimum_size = Vector2(205 if is_mob else 145, btn_h)
				enh_btn.add_theme_font_size_override("font_size", btn_fs)
				UiStyle.apply_button(enh_btn, "#38bdf8", "#bae6fd", "#0f172a", 12, 1, 1.0)
				enh_btn.pressed.connect(func() -> void: GameState.buy_or_equip_item(eq_id, "enh"))
				hbox.add_child(enh_btn)

			_body_box.add_child(row)

	elif _current_tab == "shikigami":
		for sh in GameData.SHIKIGAMI_LIST:
			var sh_id: String = sh["id"]
			var owned: bool = GameState.player["owned_shikigami"].has(sh_id)
			var active: bool = GameState.player["active_shikigami"] == sh_id

			var row := _make_row_panel("#500724" if active else "#0b1120", "#f472b6" if active else "#334155")
			var hbox := HBoxContainer.new()
			hbox.add_theme_constant_override("separation", 14)
			row.add_child(hbox)

			var info := Label.new()
			info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			info.text = "%s  %s\n%s" % [sh["icon"], sh["name"], sh["desc"]]
			info.add_theme_font_size_override("font_size", row_fs)
			hbox.add_child(info)

			var btn := Button.new()
			btn.text = "跟隨中" if active else ("召喚跟隨" if owned else "契約 (%d 🪙)" % int(sh["cost"]))
			btn.disabled = (not owned) and int(GameState.player["gold"]) < int(sh["cost"])
			btn.custom_minimum_size = Vector2(175 if is_mob else 130, btn_h)
			btn.add_theme_font_size_override("font_size", btn_fs)
			UiStyle.apply_button(btn, "#ec4899" if active else "#f59e0b", "#fbcfe8" if active else "#fde68a", "#0f172a", 12, 1, 1.0)
			btn.pressed.connect(func() -> void: GameState.contract_or_summon_shikigami(sh_id))
			hbox.add_child(btn)
			_body_box.add_child(row)

	elif _current_tab == "dict":
		var intro := Label.new()
		intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		intro.text = "📖 共收錄 %d 組日文言靈詞彙・施放 E / Q 詠唱成功即觸發對應 3D 特效與戰鬥加成（點擊「🔊」可聽日文發音）" % GameData.JAPANESE_CHANT_WORDS.size()
		intro.add_theme_font_size_override("font_size", 17 if is_mob else 13)
		intro.add_theme_color_override("font_color", Color.html("#bae6fd"))
		_body_box.add_child(intro)

		for w in GameData.JAPANESE_CHANT_WORDS:
			var accent_hex: String = String(w.get("color", "#fbbf24"))
			var row := _make_row_panel("#0b1326", accent_hex)
			var hbox := HBoxContainer.new()
			hbox.add_theme_constant_override("separation", 12)
			row.add_child(hbox)

			var info := Label.new()
			info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			info.text = "%s  %s（%s） — %s\n✨【%s】%s" % [
				String(w.get("icon", "✨")),
				String(w.get("kanji", "")),
				String(w.get("kana", "")),
				String(w.get("mean", "")),
				String(w.get("vfx_label", "言靈特效")),
				String(w.get("effect_desc", "")),
			]
			info.add_theme_font_size_override("font_size", row_fs)
			info.add_theme_color_override("font_color", Color.html("#f8fafc"))
			hbox.add_child(info)

			var speak_btn := Button.new()
			speak_btn.focus_mode = Control.FOCUS_NONE
			speak_btn.text = "🔊 發音"
			speak_btn.custom_minimum_size = Vector2(126 if is_mob else 92, btn_h)
			speak_btn.add_theme_font_size_override("font_size", btn_fs)
			UiStyle.apply_button(speak_btn, "#172554", accent_hex, "#fef3c7", 12, 1, 0.96)
			var kana_str: String = String(w.get("kana", ""))
			speak_btn.pressed.connect(func() -> void: AudioManager.speak_japanese(kana_str))
			hbox.add_child(speak_btn)
			_body_box.add_child(row)


func _make_row_panel(bg_hex: String, border_hex: String) -> PanelContainer:
	var p := PanelContainer.new()
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.add_theme_stylebox_override("panel", UiStyle.make_panel(bg_hex, 0.92, border_hex, 0.7, 14, 1, 16, 12))
	return p
