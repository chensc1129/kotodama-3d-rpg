class_name UpgradeModal
extends Control
## Luminous Wafuu Shrine Upgrade & Compendium Modal with 4 tabs:
## Skills (with level progress bars), Equipment Forge (color swatches & slot badges),
## Shikigami Companions, and the 30-word Interactive Japanese Kotodama Dictionary.

signal modal_closed

var _backdrop: ColorRect
var _panel: PanelContainer
var _current_tab: String = "skills"
var _tab_buttons: Dictionary = {}
var _gold_label: Label
var _sp_pts_label: Label
var _combat_stat_label: Label
var _body_box: VBoxContainer
var _dict_card_count: int = 0


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

	_backdrop = ColorRect.new()
	_backdrop.color = Color(0.02, 0.03, 0.08, 0.85)
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_backdrop)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 16 if is_mob else 30)
	margin.add_theme_constant_override("margin_right", 16 if is_mob else 30)
	margin.add_theme_constant_override("margin_top", 14 if is_mob else 22)
	margin.add_theme_constant_override("margin_bottom", 14 if is_mob else 22)
	add_child(margin)

	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", UiStyle.make_shrine_modal("#080d1c", "#e8c474", 24, 26, 20))
	if is_mob:
		_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
		margin.add_child(_panel)
	else:
		var center := CenterContainer.new()
		center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		center.size_flags_vertical = Control.SIZE_EXPAND_FILL
		margin.add_child(center)
		_panel.custom_minimum_size = Vector2(920, 620)
		center.add_child(_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12 if is_mob else 10)
	_panel.add_child(vbox)

	# Top Segmented Tab Bar + Close
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
		btn.custom_minimum_size = Vector2(160 if is_mob else 132, tab_h)
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
	close_btn.custom_minimum_size = Vector2(120 if is_mob else 90, tab_h)
	close_btn.add_theme_font_size_override("font_size", tab_fs)
	UiStyle.apply_button(close_btn, "#1c1326", "#fb7185", "#fecdd3", 14, 1, 0.95)
	close_btn.pressed.connect(close_modal)
	top_bar.add_child(close_btn)

	vbox.add_child(UiStyle.make_ornament_divider("#e6c37a", 0.45))

	# Resource & Live Combat Stats Strip
	var res_panel := PanelContainer.new()
	res_panel.add_theme_stylebox_override("panel", UiStyle.make_panel("#0c142a", 0.92, "#e6c37a", 0.34, 14, 1, 18, 9, 6))
	vbox.add_child(res_panel)

	var res_row := HBoxContainer.new()
	res_row.add_theme_constant_override("separation", 18)
	res_panel.add_child(res_row)

	_gold_label = Label.new()
	_gold_label.add_theme_font_size_override("font_size", 19 if is_mob else 14)
	_gold_label.add_theme_color_override("font_color", Color.html("#fcd34d"))
	res_row.add_child(_gold_label)

	_sp_pts_label = Label.new()
	_sp_pts_label.add_theme_font_size_override("font_size", 19 if is_mob else 14)
	_sp_pts_label.add_theme_color_override("font_color", Color.html("#7dd3fc"))
	res_row.add_child(_sp_pts_label)

	var res_spacer := Control.new()
	res_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	res_row.add_child(res_spacer)

	_combat_stat_label = Label.new()
	_combat_stat_label.add_theme_font_size_override("font_size", 18 if is_mob else 13)
	_combat_stat_label.add_theme_color_override("font_color", Color.html("#a7f3d0"))
	res_row.add_child(_combat_stat_label)

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
	UiStyle.animate_modal_open(self, _backdrop, _panel, 0.24)


func close_modal() -> void:
	visible = false
	modal_closed.emit()


func switch_tab(tab: String) -> void:
	_current_tab = tab
	for k in _tab_buttons.keys():
		var btn: Button = _tab_buttons[k]
		if k == tab:
			var act_col := "#38bdf8" if k == "dict" else ("#ec4899" if k == "shikigami" else ("#10b981" if k == "equip" else "#f59e0b"))
			UiStyle.apply_button(btn, act_col, "#fef3c7", "#090d16", 14, 2, 1.0)
		else:
			UiStyle.apply_button(btn, "#121b33", "#475569", "#cbd5e1", 14, 1, 0.94)
	_render_content()


func _make_icon_medallion(icon_txt: String, accent_hex: String, is_mob: bool) -> PanelContainer:
	var box := PanelContainer.new()
	var sz := 66 if is_mob else 52
	box.custom_minimum_size = Vector2(sz, sz)
	box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.add_theme_stylebox_override("panel", UiStyle.make_panel("#091022", 0.96, accent_hex, 0.72, 14, 2, 4, 4, 8))
	var lbl := Label.new()
	lbl.text = icon_txt
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 30 if is_mob else 24)
	box.add_child(lbl)
	return box


func _render_content() -> void:
	var is_mob := UiStyle.is_mobile_device()
	var title_fs := 20 if is_mob else 15
	var desc_fs := 16 if is_mob else 12
	var btn_h := 54 if is_mob else 40
	var btn_fs := 18 if is_mob else 13

	var stats := GameState.get_computed_stats()
	_gold_label.text = "🪙 金幣：%d" % int(GameState.player["gold"])
	_sp_pts_label.text = "✨ 技能點：%d pt" % int(GameState.player["skill_points"])
	_combat_stat_label.text = "⚔️ 總攻擊 %d  ｜  ❤️ 總生命 %d" % [int(stats["atk"]), int(stats["max_hp"])]

	for child in _body_box.get_children():
		child.queue_free()
	_dict_card_count = 0

	var char_cfg: Dictionary = GameData.get_character(GameState.player["char_id"])

	if _current_tab == "skills":
		var items := [
			{"key": "normal_a", "icon": "あ", "accent": "#f43f5e", "name": "「あ」三段斬撃奥義", "desc": "提升普攻三段連斬威力（每級 +8%）"},
			{"key": "sig_skill", "icon": char_cfg["sig_icon"], "accent": char_cfg["color_primary"], "name": "專屬奧義・%s（%s）" % [char_cfg["sig_name"], char_cfg["sig_key"]], "desc": "提升角色專屬技能傷害與控場時間（每級 +10%）"},
			{"key": "ult_skill", "icon": "🌟", "accent": "#f59e0b", "name": "全屏言靈大奧義（Q）", "desc": "提升 70 SP 言靈詠唱奧義毀滅傷害（每級 +11%）"},
			{"key": "dash_skill", "icon": "💨", "accent": "#38bdf8", "name": "疾風瞬步體術", "desc": "提升移動速度、最大體力並縮短衝刺冷卻時間"},
		]
		for sk in items:
			var lv: int = int(GameState.player["skills"].get(sk["key"], 1))
			var is_max := lv >= GameData.MAX_SKILL_LEVEL
			var row := _make_accent_row("#0c1428", sk["accent"], is_max)
			var hbox := HBoxContainer.new()
			hbox.add_theme_constant_override("separation", 14)
			row.add_child(hbox)

			hbox.add_child(_make_icon_medallion(sk["icon"], sk["accent"], is_mob))

			var mid := VBoxContainer.new()
			mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			mid.add_theme_constant_override("separation", 5)
			hbox.add_child(mid)

			var head_row := HBoxContainer.new()
			head_row.add_theme_constant_override("separation", 8)
			mid.add_child(head_row)

			var nm := Label.new()
			nm.text = sk["name"]
			nm.add_theme_font_size_override("font_size", title_fs)
			nm.add_theme_color_override("font_color", Color.html("#fef3c7"))
			head_row.add_child(nm)

			head_row.add_child(UiStyle.make_badge_pill(
				"Lv.%d / %d" % [lv, GameData.MAX_SKILL_LEVEL],
				"#1b162d",
				"#fbbf24" if is_max else sk["accent"],
				"#fde68a",
				13 if is_mob else 11
			))

			var desc := Label.new()
			desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			desc.text = sk["desc"]
			desc.add_theme_font_size_override("font_size", desc_fs)
			desc.add_theme_color_override("font_color", Color.html("#cbd5e1"))
			mid.add_child(desc)

			var lv_bar := ProgressBar.new()
			lv_bar.custom_minimum_size = Vector2(0, 8)
			lv_bar.max_value = GameData.MAX_SKILL_LEVEL
			lv_bar.value = lv
			UiStyle.apply_bar(lv_bar, "#fbbf24" if is_max else sk["accent"], "#080d1a", 4, "#ffffff", 0.14)
			mid.add_child(lv_bar)

			var up_btn := Button.new()
			up_btn.focus_mode = Control.FOCUS_NONE
			up_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			up_btn.text = "◆ MAX" if is_max else "升級 (1pt)"
			up_btn.disabled = is_max or int(GameState.player["skill_points"]) <= 0
			up_btn.custom_minimum_size = Vector2(158 if is_mob else 116, btn_h)
			up_btn.add_theme_font_size_override("font_size", btn_fs)
			UiStyle.apply_button(up_btn, "#f59e0b", "#fde68a", "#0f172a", 12, 1, 1.0)
			var sk_key: String = sk["key"]
			up_btn.pressed.connect(func() -> void: GameState.upgrade_skill(sk_key))
			hbox.add_child(up_btn)
			_body_box.add_child(row)

	elif _current_tab == "equip":
		var slot_names := {"weapon": "武器", "armor": "防具", "accessory": "飾品"}
		for eq in GameData.EQUIPMENT_LIST:
			var eq_id: String = eq["id"]
			var owned: bool = GameState.player["owned_equip"].has(eq_id)
			var is_eq: bool = GameState.player["equipped"].get(eq["slot"], "") == eq_id
			var plus: int = int(GameState.player["equip_enhance"].get(eq_id, 0))
			var enh_cost: int = 80 + plus * 60
			var atk_val := int(round(float(eq["atk"]) * (1.0 + float(plus) * 0.08)))
			var hp_val := int(round(float(eq["hp"]) * (1.0 + float(plus) * 0.08)))
			var swatch_hex: String = String(eq.get("blade_color", eq.get("aura_color", eq.get("gem_color", "#94a3b8"))))

			var row := _make_accent_row("#092226" if is_eq else "#0c1428", "#34d399" if is_eq else swatch_hex, is_eq)
			var hbox := HBoxContainer.new()
			hbox.add_theme_constant_override("separation", 12)
			row.add_child(hbox)

			hbox.add_child(_make_icon_medallion(eq["icon"], swatch_hex, is_mob))

			var mid := VBoxContainer.new()
			mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			mid.add_theme_constant_override("separation", 5)
			hbox.add_child(mid)

			var head_row := HBoxContainer.new()
			head_row.add_theme_constant_override("separation", 8)
			mid.add_child(head_row)

			head_row.add_child(UiStyle.make_badge_pill(slot_names.get(eq["slot"], "裝備"), "#111b33", swatch_hex, "#e2e8f0", 12 if is_mob else 10))

			var nm := Label.new()
			var plus_txt := " +%d" % plus if plus > 0 else ""
			nm.text = "%s%s" % [eq["name"], plus_txt]
			nm.add_theme_font_size_override("font_size", title_fs)
			nm.add_theme_color_override("font_color", Color.html("#fef3c7"))
			head_row.add_child(nm)

			if is_eq:
				head_row.add_child(UiStyle.make_badge_pill("◆ 裝備中", "#064e3b", "#34d399", "#a7f3d0", 12 if is_mob else 10))

			var stat_row := HBoxContainer.new()
			stat_row.add_theme_constant_override("separation", 8)
			mid.add_child(stat_row)
			stat_row.add_child(UiStyle.make_badge_pill("⚔️ 攻擊 +%d" % atk_val, "#1b1222", "#fb7185", "#fecdd3", 13 if is_mob else 11))
			stat_row.add_child(UiStyle.make_badge_pill("❤️ 生命 +%d" % hp_val, "#0d2224", "#34d399", "#a7f3d0", 13 if is_mob else 11))

			var act_row := HBoxContainer.new()
			act_row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			act_row.add_theme_constant_override("separation", 8)
			hbox.add_child(act_row)

			if not owned:
				var buy_btn := Button.new()
				buy_btn.focus_mode = Control.FOCUS_NONE
				buy_btn.text = "購買 (%d 🪙)" % int(eq["cost"])
				buy_btn.disabled = int(GameState.player["gold"]) < int(eq["cost"])
				buy_btn.custom_minimum_size = Vector2(170 if is_mob else 128, btn_h)
				buy_btn.add_theme_font_size_override("font_size", btn_fs)
				UiStyle.apply_button(buy_btn, "#f59e0b", "#fde68a", "#0f172a", 12, 1, 1.0)
				buy_btn.pressed.connect(func() -> void: GameState.buy_or_equip_item(eq_id, "buy"))
				act_row.add_child(buy_btn)
			else:
				if not is_eq:
					var eq_btn := Button.new()
					eq_btn.focus_mode = Control.FOCUS_NONE
					eq_btn.text = "裝備"
					eq_btn.custom_minimum_size = Vector2(106 if is_mob else 76, btn_h)
					eq_btn.add_theme_font_size_override("font_size", btn_fs)
					UiStyle.apply_button(eq_btn, "#10b981", "#6ee7b7", "#0f172a", 12, 1, 1.0)
					eq_btn.pressed.connect(func() -> void: GameState.buy_or_equip_item(eq_id, "equip"))
					act_row.add_child(eq_btn)
				var enh_btn := Button.new()
				enh_btn.focus_mode = Control.FOCUS_NONE
				enh_btn.text = "強化 MAX" if plus >= GameData.MAX_EQUIP_ENHANCE else "鍛造 +1 (%d 🪙)" % enh_cost
				enh_btn.disabled = plus >= GameData.MAX_EQUIP_ENHANCE or int(GameState.player["gold"]) < enh_cost
				enh_btn.custom_minimum_size = Vector2(198 if is_mob else 142, btn_h)
				enh_btn.add_theme_font_size_override("font_size", btn_fs)
				UiStyle.apply_button(enh_btn, "#38bdf8", "#bae6fd", "#0f172a", 12, 1, 1.0)
				enh_btn.pressed.connect(func() -> void: GameState.buy_or_equip_item(eq_id, "enh"))
				act_row.add_child(enh_btn)

			_body_box.add_child(row)

	elif _current_tab == "shikigami":
		for sh in GameData.SHIKIGAMI_LIST:
			var sh_id: String = sh["id"]
			var owned: bool = GameState.player["owned_shikigami"].has(sh_id)
			var active: bool = GameState.player["active_shikigami"] == sh_id
			var sh_col: String = String(sh.get("color", "#f472b6"))

			var row := _make_accent_row("#2c0b22" if active else "#0c1428", "#f472b6" if active else sh_col, active)
			var hbox := HBoxContainer.new()
			hbox.add_theme_constant_override("separation", 14)
			row.add_child(hbox)

			hbox.add_child(_make_icon_medallion(sh["icon"], sh_col, is_mob))

			var mid := VBoxContainer.new()
			mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			mid.add_theme_constant_override("separation", 4)
			hbox.add_child(mid)

			var head_row := HBoxContainer.new()
			head_row.add_theme_constant_override("separation", 8)
			mid.add_child(head_row)

			var nm := Label.new()
			nm.text = sh["name"]
			nm.add_theme_font_size_override("font_size", title_fs)
			nm.add_theme_color_override("font_color", Color.html("#fef3c7"))
			head_row.add_child(nm)

			if active:
				head_row.add_child(UiStyle.make_badge_pill("◆ 跟隨出戰中", "#831843", "#f472b6", "#fbcfe8", 12 if is_mob else 10))

			var desc := Label.new()
			desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			desc.text = sh["desc"]
			desc.add_theme_font_size_override("font_size", desc_fs)
			desc.add_theme_color_override("font_color", Color.html("#cbd5e1"))
			mid.add_child(desc)

			var btn := Button.new()
			btn.focus_mode = Control.FOCUS_NONE
			btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			btn.text = "跟隨中" if active else ("召喚跟隨" if owned else "契約 (%d 🪙)" % int(sh["cost"]))
			btn.disabled = (not owned) and int(GameState.player["gold"]) < int(sh["cost"])
			btn.custom_minimum_size = Vector2(170 if is_mob else 128, btn_h)
			btn.add_theme_font_size_override("font_size", btn_fs)
			UiStyle.apply_button(btn, "#ec4899" if active else "#f59e0b", "#fbcfe8" if active else "#fde68a", "#0f172a", 12, 1, 1.0)
			btn.pressed.connect(func() -> void: GameState.contract_or_summon_shikigami(sh_id))
			hbox.add_child(btn)
			_body_box.add_child(row)

	elif _current_tab == "dict":
		var intro_card := PanelContainer.new()
		intro_card.add_theme_stylebox_override("panel", UiStyle.make_panel("#0e1a36", 0.90, "#38bdf8", 0.45, 14, 1, 16, 10, 6))
		var intro := Label.new()
		intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		intro.text = "📖 共收錄 %d 組日文言靈詞彙・涵蓋 8 大專屬 3D 法術特效！施放 E / Q 詠唱成功即觸發對應特效與加成，點「🔊」可聽日文發音。" % GameData.JAPANESE_CHANT_WORDS.size()
		intro.add_theme_font_size_override("font_size", 16 if is_mob else 12)
		intro.add_theme_color_override("font_color", Color.html("#bae6fd"))
		intro_card.add_child(intro)
		_body_box.add_child(intro_card)

		var dict_grid := GridContainer.new()
		dict_grid.columns = 1 if is_mob else 2
		dict_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		dict_grid.add_theme_constant_override("h_separation", 12)
		dict_grid.add_theme_constant_override("v_separation", 10)
		_body_box.add_child(dict_grid)

		for w in GameData.JAPANESE_CHANT_WORDS:
			_dict_card_count += 1
			var accent_hex: String = String(w.get("color", "#fbbf24"))
			var card := _make_accent_row("#0c1428", accent_hex, false)
			var v := VBoxContainer.new()
			v.add_theme_constant_override("separation", 6)
			card.add_child(v)

			var top_r := HBoxContainer.new()
			top_r.add_theme_constant_override("separation", 8)
			v.add_child(top_r)

			var kanji_lbl := Label.new()
			kanji_lbl.text = "%s %s" % [String(w.get("icon", "✨")), String(w.get("kanji", ""))]
			kanji_lbl.add_theme_font_size_override("font_size", 24 if is_mob else 18)
			kanji_lbl.add_theme_color_override("font_color", Color.html("#fef3c7"))
			UiStyle.style_label_shadow(kanji_lbl, 0.7)
			top_r.add_child(kanji_lbl)

			top_r.add_child(UiStyle.make_badge_pill(String(w.get("kana", "")), "#111b36", accent_hex, "#e0f2fe", 15 if is_mob else 12))

			var sp := Control.new()
			sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			top_r.add_child(sp)

			var speak_btn := Button.new()
			speak_btn.focus_mode = Control.FOCUS_NONE
			speak_btn.text = "🔊"
			speak_btn.custom_minimum_size = Vector2(54 if is_mob else 42, 42 if is_mob else 32)
			speak_btn.add_theme_font_size_override("font_size", 18 if is_mob else 14)
			UiStyle.apply_button(speak_btn, "#162447", accent_hex, "#fef3c7", 11, 1, 0.96)
			var kana_str: String = String(w.get("kana", ""))
			speak_btn.pressed.connect(func() -> void: AudioManager.speak_japanese(kana_str))
			top_r.add_child(speak_btn)

			var mid_r := HBoxContainer.new()
			mid_r.add_theme_constant_override("separation", 8)
			v.add_child(mid_r)

			var mean_lbl := Label.new()
			mean_lbl.text = "意思：%s" % String(w.get("mean", ""))
			mean_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			mean_lbl.add_theme_font_size_override("font_size", 16 if is_mob else 12)
			mean_lbl.add_theme_color_override("font_color", Color.html("#94a3b8"))
			mid_r.add_child(mean_lbl)

			mid_r.add_child(UiStyle.make_badge_pill("✨ %s" % String(w.get("vfx_label", "言靈")), "#131c36", accent_hex, accent_hex, 13 if is_mob else 11))

			var eff_lbl := Label.new()
			eff_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			eff_lbl.text = String(w.get("effect_desc", ""))
			eff_lbl.add_theme_font_size_override("font_size", 15 if is_mob else 12)
			eff_lbl.add_theme_color_override("font_color", Color.html("#e2e8f0"))
			v.add_child(eff_lbl)

			dict_grid.add_child(card)


func _make_accent_row(bg_hex: String, accent_hex: String, selected: bool) -> PanelContainer:
	var p := PanelContainer.new()
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	p.add_theme_stylebox_override("panel", UiStyle.make_accent_card(bg_hex, accent_hex, selected, 14, 15, 11))
	return p
