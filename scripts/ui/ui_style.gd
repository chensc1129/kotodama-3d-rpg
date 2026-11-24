class_name UiStyle
extends RefCounted
## Wafuu Luminous Glass & Lacquer UI design system (inspired by Genshin Impact × Japanese Action RPGs).
## Provides soft drop shadows, champagne-gold filigree borders, circular glowing skill orbs,
## sleek progress bars, hairline dividers, and responsive mobile/desktop detection.


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
		sb.shadow_color = Color(0.01, 0.02, 0.06, 0.48)
		sb.shadow_size = shadow_sz
		sb.shadow_offset = Vector2(0.0, 4.0)
	sb.content_margin_left = pad_x
	sb.content_margin_right = pad_x
	sb.content_margin_top = pad_y
	sb.content_margin_bottom = pad_y
	return sb


static func make_shrine_modal(bg_hex: String = "#0a0f1f", accent_hex: String = "#e8c474", radius: int = 24, pad_x: int = 30, pad_y: int = 24) -> StyleBoxFlat:
	var sb := make_panel(bg_hex, 0.96, accent_hex, 0.72, radius, 2, pad_x, pad_y, 26)
	sb.border_width_top = 3
	sb.shadow_color = Color(0.0, 0.01, 0.04, 0.72)
	sb.shadow_offset = Vector2(0.0, 10.0)
	return sb


static func make_pill(bg_hex: String = "#0b1122", alpha: float = 0.78, border_hex: String = "#e6c37a", border_alpha: float = 0.36, pad_x: int = 16, pad_y: int = 7) -> StyleBoxFlat:
	return make_panel(bg_hex, alpha, border_hex, border_alpha, 22, 1, pad_x, pad_y, 10)


static func make_divider(color_hex: String = "#e6c37a", alpha: float = 0.35, height: int = 2) -> ColorRect:
	var line := ColorRect.new()
	var c := Color.html(color_hex)
	c.a = alpha
	line.color = c
	line.custom_minimum_size = Vector2(0, height)
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return line


static func apply_button(
	btn: Button,
	bg_hex: String = "#172038",
	border_hex: String = "#e6c37a",
	text_hex: String = "#f8fafc",
	radius: int = 14,
	border_w: int = 1,
	alpha: float = 0.92
) -> void:
	var normal := make_panel(bg_hex, alpha, border_hex, 0.52, radius, border_w, 14, 9, 8)
	var hover := make_panel(bg_hex, minf(1.0, alpha + 0.08), border_hex, 0.95, radius, maxi(border_w, 2), 14, 9, 14)
	hover.bg_color = hover.bg_color.lightened(0.14)
	var pressed := make_panel(bg_hex, alpha, border_hex, 1.0, radius, maxi(border_w, 2), 14, 9, 4)
	pressed.bg_color = pressed.bg_color.darkened(0.12)
	var disabled := make_panel("#111827", 0.42, "#475569", 0.30, radius, border_w, 14, 9, 0)

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("focus", hover)
	btn.add_theme_stylebox_override("disabled", disabled)

	var tc := Color.html(text_hex)
	btn.add_theme_color_override("font_color", tc)
	btn.add_theme_color_override("font_hover_color", tc.lerp(Color.WHITE, 0.25))
	btn.add_theme_color_override("font_pressed_color", tc)
	btn.add_theme_color_override("font_focus_color", tc)
	btn.add_theme_color_override("font_disabled_color", Color(tc.r, tc.g, tc.b, 0.38))


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
	var normal := make_panel(bg_hex, alpha, border_hex, 0.80, rad, border_w, 4, 4, 14)
	var hover := make_panel(bg_hex, minf(1.0, alpha + 0.08), "#fff7ed", 1.0, rad, border_w + 1, 4, 4, 20)
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


static func apply_bar(bar: ProgressBar, fill_hex: String, bg_hex: String = "#0b1122", radius: int = 6, border_hex: String = "#ffffff", border_alpha: float = 0.14) -> void:
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color.html(bg_hex)
	bg.bg_color.a = 0.88
	var bc := Color.html(border_hex)
	bc.a = border_alpha
	bg.border_color = bc
	bg.set_border_width_all(1)
	bg.set_corner_radius_all(radius)
	bg.anti_aliasing = true

	var fill := StyleBoxFlat.new()
	fill.bg_color = Color.html(fill_hex)
	fill.set_corner_radius_all(maxi(1, radius - 1))
	fill.border_color = Color(1.0, 1.0, 1.0, 0.28)
	fill.border_width_top = 1
	fill.anti_aliasing = true

	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fill)
	bar.show_percentage = false


static func apply_line_edit(le: LineEdit, border_hex: String = "#e6c37a") -> void:
	var normal := make_panel("#090e1c", 0.94, border_hex, 0.52, 12, 1, 12, 7, 6)
	var focus := make_panel("#0b1226", 1.0, "#fde68a", 0.98, 12, 2, 12, 7, 12)
	le.add_theme_stylebox_override("normal", normal)
	le.add_theme_stylebox_override("focus", focus)
	le.add_theme_color_override("font_color", Color.html("#fef3c7"))
	le.add_theme_color_override("font_placeholder_color", Color.html("#64748b"))
