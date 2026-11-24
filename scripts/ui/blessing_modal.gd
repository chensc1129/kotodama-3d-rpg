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
	var is_mob := UiStyle.is_mobile_device()

	var backdrop := ColorRect.new()
	backdrop.color = Color(0.02, 0.03, 0.08, 0.80)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(1040 if is_mob else 740, 360 if is_mob else 290)
	panel.add_theme_stylebox_override("panel", UiStyle.make_shrine_modal("#090e1d", "#e8c474", 24, 30, 24))
	center.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16 if is_mob else 14)
	panel.add_child(vbox)

	var badge := Label.new()
	badge.text = "✨  幕間言霊祝福・三選一強化  ✨"
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.add_theme_font_size_override("font_size", 17 if is_mob else 13)
	badge.add_theme_color_override("font_color", Color.html("#d4b06a"))
	vbox.add_child(badge)

	var title := Label.new()
	title.text = "選擇一項神明加護繼續前進！"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28 if is_mob else 22)
	title.add_theme_color_override("font_color", Color.html("#fef3c7"))
	vbox.add_child(title)

	vbox.add_child(UiStyle.make_divider("#e6c37a", 0.35, 1))

	_cards_box = HBoxContainer.new()
	_cards_box.add_theme_constant_override("separation", 14 if is_mob else 14)
	vbox.add_child(_cards_box)


func open_blessings() -> void:
	var is_mob := UiStyle.is_mobile_device()
	for child in _cards_box.get_children():
		child.queue_free()

	var pool := GameData.BLESSINGS_POOL.duplicate()
	pool.shuffle()
	var picks := pool.slice(0, 3)

	for item in picks:
		var btn := Button.new()
		btn.focus_mode = Control.FOCUS_NONE
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.custom_minimum_size = Vector2(280 if is_mob else 200, 190 if is_mob else 136)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		btn.text = "%s\n\n%s" % [item["title"], item["desc"]]
		UiStyle.apply_button(btn, "#121b33", "#e8c474", "#fef3c7", 18, 2, 0.96)
		btn.add_theme_font_size_override("font_size", 21 if is_mob else 15)
		var bid: String = item["id"]
		btn.pressed.connect(func() -> void:
			visible = false
			blessing_selected.emit(bid)
		)
		_cards_box.add_child(btn)

	visible = true
