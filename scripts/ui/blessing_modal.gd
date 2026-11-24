class_name BlessingModal
extends Control
## Wave-clear Roguelite 3-of-5 blessing selection overlay.

signal blessing_selected(blessing_id: String)

var _cards_box: HBoxContainer


func _ready() -> void:
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build_ui()


func _build_ui() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = Color(0.02, 0.03, 0.08, 0.80)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(680, 260)
	panel.add_theme_stylebox_override("panel", UiStyle.make_panel("#0f172a", 0.95, "#fbbf24", 0.85, 22, 2, 24, 22))
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	panel.add_child(vbox)

	var badge := Label.new()
	badge.text = "✨ 幕間言霊祝福・三選一強化"
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.add_theme_font_size_override("font_size", 14)
	badge.add_theme_color_override("font_color", Color.html("#fcd34d"))
	vbox.add_child(badge)

	var title := Label.new()
	title.text = "選擇一項神明加護繼續前進！"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(title)

	_cards_box = HBoxContainer.new()
	_cards_box.add_theme_constant_override("separation", 12)
	vbox.add_child(_cards_box)


func open_blessings() -> void:
	for child in _cards_box.get_children():
		child.queue_free()

	var pool := GameData.BLESSINGS_POOL.duplicate()
	pool.shuffle()
	var picks := pool.slice(0, 3)

	for item in picks:
		var btn := Button.new()
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(190, 124)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		btn.text = "%s\n\n%s" % [item["title"], item["desc"]]
		UiStyle.apply_button(btn, "#1e293b", "#fbbf24", "#fde68a", 16, 2, 0.95)
		btn.add_theme_font_size_override("font_size", 15)
		var bid: String = item["id"]
		btn.pressed.connect(func() -> void:
			visible = false
			blessing_selected.emit(bid)
		)
		_cards_box.add_child(btn)

	visible = true
