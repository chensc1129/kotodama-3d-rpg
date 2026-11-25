class_name BlessingModal
extends Control
## Wave-clear Roguelite 3-of-5 Shrine Talisman blessing selection overlay
## with spring-pop open animation and staggered card reveals.

signal blessing_selected(blessing_id: String)

var _backdrop: ColorRect
var _panel: PanelContainer
var _cards_box: HBoxContainer

const BLESSING_ACCENTS: Dictionary = {
	"atk": {"icon": "⚔️", "border": "#fb7185", "bg": "#1f1022", "tag": "攻擊強化"},
	"hp": {"icon": "❤️", "border": "#34d399", "bg": "#0b2022", "tag": "體魄加護"},
	"stone": {"icon": "🪨", "border": "#f59e0b", "bg": "#1f1712", "tag": "破甲奧義"},
	"lifesteal": {"icon": "🩸", "border": "#e11d48", "bg": "#240e1a", "tag": "嗜血續航"},
	"speed": {"icon": "⚡", "border": "#38bdf8", "bg": "#0d1b30", "tag": "神速靈力"},
}


func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()


func _build_ui() -> void:
	var is_mob := UiStyle.is_mobile_device()

	_backdrop = ColorRect.new()
	_backdrop.color = Color(0.02, 0.03, 0.08, 0.82)
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_backdrop)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(1060 if is_mob else 790, 400 if is_mob else 340)
	_panel.add_theme_stylebox_override("panel", UiStyle.make_shrine_modal("#080d1c", "#e8c474", 24, 30, 24))
	center.add_child(_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16 if is_mob else 13)
	_panel.add_child(vbox)

	var badge := Label.new()
	badge.text = "✨  幕間言霊祝福・三選一神明加護  ✨"
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.add_theme_font_size_override("font_size", 17 if is_mob else 13)
	badge.add_theme_color_override("font_color", Color.html("#d4b06a"))
	vbox.add_child(badge)

	var title := Label.new()
	title.text = "⛩️ 擇一奉納神符・強化戰力！"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30 if is_mob else 24)
	title.add_theme_color_override("font_color", Color.html("#fef3c7"))
	UiStyle.style_label_shadow(title, 0.75, 2)
	vbox.add_child(title)

	vbox.add_child(UiStyle.make_ornament_divider("#e6c37a", 0.50))

	_cards_box = HBoxContainer.new()
	_cards_box.add_theme_constant_override("separation", 16 if is_mob else 14)
	vbox.add_child(_cards_box)


func open_blessings() -> void:
	var is_mob := UiStyle.is_mobile_device()
	for child in _cards_box.get_children():
		child.queue_free()

	var pool := GameData.BLESSINGS_POOL.duplicate()
	pool.shuffle()
	var picks := pool.slice(0, 3)

	for item in picks:
		var bid: String = item["id"]
		var theme: Dictionary = BLESSING_ACCENTS.get(bid, {"icon": "✨", "border": "#e8c474", "bg": "#121b33", "tag": "神明祝福"})

		var btn := Button.new()
		btn.focus_mode = Control.FOCUS_NONE
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(300 if is_mob else 224, 240 if is_mob else 196)
		UiStyle.apply_card_button(btn, theme["bg"], theme["border"], true, 18)

		var margin := MarginContainer.new()
		margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
		margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		margin.add_theme_constant_override("margin_left", 14)
		margin.add_theme_constant_override("margin_right", 14)
		margin.add_theme_constant_override("margin_top", 14)
		margin.add_theme_constant_override("margin_bottom", 14)
		btn.add_child(margin)

		var card_v := VBoxContainer.new()
		card_v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card_v.alignment = BoxContainer.ALIGNMENT_CENTER
		card_v.add_theme_constant_override("separation", 8)
		margin.add_child(card_v)

		var pill_center := CenterContainer.new()
		pill_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pill_center.add_child(UiStyle.make_badge_pill(theme["tag"], "#090f20", theme["border"], "#fef3c7", 13 if is_mob else 11))
		card_v.add_child(pill_center)

		var icon_lbl := Label.new()
		icon_lbl.text = theme["icon"]
		icon_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		icon_lbl.add_theme_font_size_override("font_size", 38 if is_mob else 30)
		card_v.add_child(icon_lbl)

		var title_lbl := Label.new()
		title_lbl.text = String(item["title"]).trim_prefix(String(theme["icon"])).strip_edges()
		title_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title_lbl.add_theme_font_size_override("font_size", 21 if is_mob else 16)
		title_lbl.add_theme_color_override("font_color", Color.html("#fef3c7"))
		UiStyle.style_label_shadow(title_lbl, 0.7)
		card_v.add_child(title_lbl)

		var desc_lbl := Label.new()
		desc_lbl.text = String(item["desc"])
		desc_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
		desc_lbl.add_theme_font_size_override("font_size", 16 if is_mob else 12)
		desc_lbl.add_theme_color_override("font_color", Color.html("#cbd5e1"))
		card_v.add_child(desc_lbl)

		var cta_lbl := Label.new()
		cta_lbl.text = "◆ 點擊領受 ◆"
		cta_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cta_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cta_lbl.add_theme_font_size_override("font_size", 15 if is_mob else 11)
		cta_lbl.add_theme_color_override("font_color", Color.html(theme["border"]))
		card_v.add_child(cta_lbl)

		btn.pressed.connect(func() -> void:
			visible = false
			blessing_selected.emit(bid)
		)
		_cards_box.add_child(btn)

	visible = true
	UiStyle.animate_modal_open(self, _backdrop, _panel, 0.25)
	UiStyle.animate_stagger_children(self, _cards_box, 0.08, 0.25)
