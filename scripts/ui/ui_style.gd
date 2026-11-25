class_name UiStyle
extends RefCounted
## Wafuu Luminous Glass & Lacquer UI design system (inspired by Genshin Impact × Japanese Action RPGs).
## Provides soft drop shadows, champagne-gold filigree borders, structured accent cards,
## circular glowing skill orbs, sleek progress bars, gradient backdrops, and smooth pause-safe animations.


static func is_mobile_device() -> bool:
	if OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios") or OS.has_feature("web_android") or OS.has_feature("web_ios"):
		return true
	if OS.has_feature("web"):
		var res: Variant = JavaScriptBridge.eval(
			"(function(){try{return window.matchMedia('(pointer: coarse)').matches || /Android|iPhone|iPad|iPod|Mobile/i.test(navigator.userAgent);}catch(e){return false;}})()"
		)
		return bool(res)
	return false


static func request_mobile_landscape_fullscreen() -> void:
	if OS.has_feature("web") and is_mobile_device():
		JavaScriptBridge.eval("if(window.kotodamaLockLandscape){window.kotodamaLockLandscape();}")


static func make_panel(
	bg_hex: String = "#0c1122",
	alpha: float = 0.88,
	border_hex: String = "#e6c37a",
	border_alpha: float = 0.42,
	radius: int = 16,
	border_w: int = 1,
	pad_x: int = 16,
	pad_y: int = 10,
	shadow_sz: int = 12
) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	var bg := Color.html(bg_hex)
	bg.a = alpha
	sb.bg_color = bg
	var bc := Color.html(border_hex)
	bc.a = border_alpha
	sb.border_color = bc
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(radius)
	sb.anti_aliasing = true
	sb.anti_aliasing_size = 1.25
	if shadow_sz > 0:
		sb.shadow_color = Color(0.01, 0.02, 0.06, 0.50)
		sb.shadow_size = shadow_sz
		sb.shadow_offset = Vector2(0.0, 4.0)
	sb.content_margin_left = pad_x
	sb.content_margin_right = pad_x
	sb.content_margin_top = pad_y
	sb.content_margin_bottom = pad_y
	return sb


static func make_shrine_modal(bg_hex: String = "#080d1c", accent_hex: String = "#e8c474", radius: int = 24, pad_x: int = 30, pad_y: int = 24) -> StyleBoxFlat:
	var sb := make_panel(bg_hex, 0.96, accent_hex, 0.72, radius, 2, pad_x, pad_y, 32)
	sb.border_width_top = 4
	sb.border_width_bottom = 2
	sb.shadow_color = Color(0.0, 0.01, 0.05, 0.78)
	sb.shadow_offset = Vector2(0.0, 12.0)
	return sb


static func make_accent_card(
	bg_hex: String = "#0d152a",
	accent_hex: String = "#e6c37a",
	selected: bool = false,
	radius: int = 16,
	pad_x: int = 16,
	pad_y: int = 12
) -> StyleBoxFlat:
	var sb := make_panel(
		bg_hex,
		0.95 if selected else 0.88,
		accent_hex,
		0.92 if selected else 0.42,
		radius,
		2 if selected else 1,
		pad_x,
		pad_y,
		16 if selected else 8
	)
	sb.border_width_left = 5 if selected else 3
	return sb


static func make_pill(bg_hex: String = "#0b1122", alpha: float = 0.82, border_hex: String = "#e6c37a", border_alpha: float = 0.40, pad_x: int = 16, pad_y: int = 7) -> StyleBoxFlat:
	return make_panel(bg_hex, alpha, border_hex, border_alpha, 22, 1, pad_x, pad_y, 10)


static func make_badge_pill(text: String, bg_hex: String, border_hex: String, text_hex: String, font_size: int = 12) -> PanelContainer:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override("panel", make_pill(bg_hex, 0.92, border_hex, 0.70, 11, 4))
	var lbl := Label.new()
	lbl.text = text
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", Color.html(text_hex))
	p.add_child(lbl)
	return p


static func make_divider(color_hex: String = "#e6c37a", alpha: float = 0.35, height: int = 2) -> ColorRect:
	var line := ColorRect.new()
	var c := Color.html(color_hex)
	c.a = alpha
	line.color = c
	line.custom_minimum_size = Vector2(0, height)
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return line


static func make_ornament_divider(color_hex: String = "#e6c37a", alpha: float = 0.50) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var l1 := make_divider(color_hex, alpha * 0.7, 1)
	l1.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(l1)

	var gem := Label.new()
	gem.text = "◆"
	gem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gem.add_theme_font_size_override("font_size", 11)
	var gc := Color.html(color_hex)
	gc.a = minf(1.0, alpha + 0.3)
	gem.add_theme_color_override("font_color", gc)
	row.add_child(gem)

	var l2 := make_divider(color_hex, alpha * 0.7, 1)
	l2.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(l2)
	return row


static func make_gradient_bg(top_hex: String = "#060914", mid_hex: String = "#11162b", bot_hex: String = "#220c1a") -> TextureRect:
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.58, 1.0])
	grad.colors = PackedColorArray([Color.html(top_hex), Color.html(mid_hex), Color.html(bot_hex)])
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.width = 64
	tex.height = 256
	tex.fill_from = Vector2(0.5, 0.0)
	tex.fill_to = Vector2(0.5, 1.0)
	var rect := TextureRect.new()
	rect.texture = tex
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


static func make_radial_glow(color_hex: String, alpha: float = 0.28) -> TextureRect:
	var grad := Gradient.new()
	var c := Color.html(color_hex)
	grad.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	grad.colors = PackedColorArray([Color(c.r, c.g, c.b, alpha), Color(c.r, c.g, c.b, alpha * 0.32), Color(c.r, c.g, c.b, 0.0)])
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	tex.width = 192
	tex.height = 192
	var rect := TextureRect.new()
	rect.texture = tex
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


static func style_label_shadow(lbl: Label, shadow_alpha: float = 0.72, outline_sz: int = 0, outline_hex: String = "#060913") -> void:
	lbl.add_theme_color_override("font_shadow_color", Color(0.0, 0.01, 0.04, shadow_alpha))
	lbl.add_theme_constant_override("shadow_offset_x", 0)
	lbl.add_theme_constant_override("shadow_offset_y", 2)
	lbl.add_theme_constant_override("shadow_outline_size", 2)
	if outline_sz > 0:
		lbl.add_theme_color_override("font_outline_color", Color.html(outline_hex))
		lbl.add_theme_constant_override("outline_size", outline_sz)


static func apply_button(
	btn: Button,
	bg_hex: String = "#172038",
	border_hex: String = "#e6c37a",
	text_hex: String = "#f8fafc",
	radius: int = 14,
	border_w: int = 1,
	alpha: float = 0.92
) -> void:
	var normal := make_panel(bg_hex, alpha, border_hex, 0.54, radius, border_w, 15, 9, 8)
	normal.border_width_top = maxi(border_w, 1)
	var hover := make_panel(bg_hex, minf(1.0, alpha + 0.08), border_hex, 0.98, radius, maxi(border_w, 2), 15, 9, 16)
	hover.bg_color = hover.bg_color.lightened(0.15)
	var pressed := make_panel(bg_hex, alpha, border_hex, 1.0, radius, maxi(border_w, 2), 15, 9, 4)
	pressed.bg_color = pressed.bg_color.darkened(0.14)
	var disabled := make_panel("#111827", 0.42, "#475569", 0.30, radius, border_w, 15, 9, 0)

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("focus", hover)
	btn.add_theme_stylebox_override("disabled", disabled)

	var tc := Color.html(text_hex)
	btn.add_theme_color_override("font_color", tc)
	btn.add_theme_color_override("font_hover_color", tc.lerp(Color.WHITE, 0.28))
	btn.add_theme_color_override("font_pressed_color", tc)
	btn.add_theme_color_override("font_focus_color", tc)
	btn.add_theme_color_override("font_disabled_color", Color(tc.r, tc.g, tc.b, 0.38))


static func apply_card_button(
	btn: Button,
	bg_hex: String,
	accent_hex: String,
	selected: bool,
	radius: int = 16
) -> void:
	var normal := make_accent_card(bg_hex, accent_hex, selected, radius, 16, 12)
	var hover := make_accent_card(bg_hex, accent_hex, true, radius, 16, 12)
	hover.bg_color = hover.bg_color.lightened(0.12)
	hover.shadow_size = 20
	var pressed := make_accent_card(bg_hex, accent_hex, true, radius, 16, 12)
	pressed.bg_color = pressed.bg_color.darkened(0.08)
	pressed.shadow_size = 6

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("focus", hover)


static func apply_orb_button(
	btn: Button,
	bg_hex: String,
	border_hex: String,
	text_hex: String,
	diameter: float,
	border_w: int = 3,
	alpha: float = 0.92
) -> void:
	var rad := int(ceil(diameter * 0.5))
	var normal := make_panel(bg_hex, alpha, border_hex, 0.84, rad, border_w, 4, 4, 16)
	var hover := make_panel(bg_hex, minf(1.0, alpha + 0.08), "#fff7ed", 1.0, rad, border_w + 1, 4, 4, 22)
	hover.bg_color = hover.bg_color.lightened(0.16)
	var pressed := make_panel(bg_hex, 1.0, "#fde68a", 1.0, rad, border_w, 4, 4, 6)
	pressed.bg_color = pressed.bg_color.darkened(0.14)
	var disabled := make_panel("#0b1120", 0.52, "#475569", 0.38, rad, 2, 4, 4, 6)

	btn.custom_minimum_size = Vector2(diameter, diameter)
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("focus", hover)
	btn.add_theme_stylebox_override("disabled", disabled)

	var tc := Color.html(text_hex)
	btn.add_theme_color_override("font_color", tc)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_color_override("font_pressed_color", tc)
	btn.add_theme_color_override("font_focus_color", tc)
	btn.add_theme_color_override("font_disabled_color", Color(0.75, 0.80, 0.88, 0.42))


static func apply_bar(bar: ProgressBar, fill_hex: String, bg_hex: String = "#0b1122", radius: int = 6, border_hex: String = "#ffffff", border_alpha: float = 0.16) -> void:
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color.html(bg_hex)
	bg.bg_color.a = 0.90
	var bc := Color.html(border_hex)
	bc.a = border_alpha
	bg.border_color = bc
	bg.set_border_width_all(1)
	bg.set_corner_radius_all(radius)
	bg.anti_aliasing = true

	var fill := StyleBoxFlat.new()
	fill.bg_color = Color.html(fill_hex)
	fill.set_corner_radius_all(maxi(1, radius - 1))
	fill.border_color = Color(1.0, 1.0, 1.0, 0.32)
	fill.border_width_top = 1
	fill.anti_aliasing = true

	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fill)
	bar.show_percentage = false


static func apply_line_edit(le: LineEdit, border_hex: String = "#e6c37a") -> void:
	var normal := make_panel("#090e1c", 0.94, border_hex, 0.56, 12, 1, 14, 8, 6)
	var focus := make_panel("#0d152b", 1.0, "#fde68a", 0.98, 12, 2, 14, 8, 14)
	le.add_theme_stylebox_override("normal", normal)
	le.add_theme_stylebox_override("focus", focus)
	le.add_theme_color_override("font_color", Color.html("#fef3c7"))
	le.add_theme_color_override("font_placeholder_color", Color.html("#64748b"))


# ==================== SMOOTH PAUSE-SAFE UI ANIMATIONS ====================

static func animate_modal_open(host: Control, backdrop: ColorRect, panel: Control, duration: float = 0.24) -> void:
	if host == null or not is_instance_valid(host) or not host.is_inside_tree():
		return
	var tw := host.create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.set_parallel(true)

	if backdrop != null:
		var target_a := backdrop.color.a
		backdrop.modulate = Color(1.0, 1.0, 1.0, 0.0)
		tw.tween_property(backdrop, "modulate:a", 1.0, duration * 0.85).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		backdrop.color.a = target_a

	if panel != null:
		panel.pivot_offset = panel.size * 0.5 if panel.size.x > 10.0 else panel.custom_minimum_size * 0.5
		panel.modulate = Color(1.0, 1.0, 1.0, 0.0)
		panel.scale = Vector2(0.91, 0.91)
		tw.tween_property(panel, "modulate:a", 1.0, duration * 0.80).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.tween_property(panel, "scale", Vector2.ONE, duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


static func animate_stagger_children(host: Control, container: Control, step_delay: float = 0.055, duration: float = 0.24) -> void:
	if host == null or container == null or not host.is_inside_tree():
		return
	var idx := 0
	for child in container.get_children():
		if child is Control:
			var ctrl := child as Control
			ctrl.modulate = Color(1.0, 1.0, 1.0, 0.0)
			var tw := host.create_tween()
			tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
			tw.tween_interval(float(idx) * step_delay)
			tw.tween_property(ctrl, "modulate:a", 1.0, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
			idx += 1


static func animate_pop_bounce(host: Control, target: Control, peak_scale: float = 1.14, duration: float = 0.22) -> void:
	if host == null or target == null or not host.is_inside_tree():
		return
	target.pivot_offset = target.size * 0.5
	var tw := host.create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	target.scale = Vector2(peak_scale, peak_scale)
	tw.tween_property(target, "scale", Vector2.ONE, duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


static func animate_toast_in(host: Control, toast: Control) -> void:
	if host == null or toast == null or not host.is_inside_tree():
		return
	toast.pivot_offset = toast.size * 0.5
	toast.modulate = Color(1.0, 1.0, 1.0, 0.0)
	toast.scale = Vector2(0.90, 0.90)
	var tw := host.create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.set_parallel(true)
	tw.tween_property(toast, "modulate:a", 1.0, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(toast, "scale", Vector2.ONE, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
