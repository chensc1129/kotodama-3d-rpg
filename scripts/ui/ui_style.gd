class_name UiStyle
extends RefCounted
## Reusable dark-slate glassmorphism StyleBox helpers and responsive device detection.


static func is_mobile_device() -> bool:
	if OS.has_feature("mobile") or OS.has_feature("android") or OS.has_feature("ios") or OS.has_feature("web_android") or OS.has_feature("web_ios"):
		return true
	if OS.has_feature("web"):
		var res: Variant = JavaScriptBridge.eval(
			"(function(){try{return window.matchMedia('(pointer: coarse)').matches || /Android|iPhone|iPad|iPod|Mobile/i.test(navigator.userAgent);}catch(e){return false;}})()"
		)
		return bool(res)
	return false


static func make_panel(
	bg_hex: String = "#0f172a",
	alpha: float = 0.86,
	border_hex: String = "#fbbf24",
	border_alpha: float = 0.35,
	radius: int = 16,
	border_w: int = 1,
	pad_x: int = 14,
	pad_y: int = 10
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
	sb.content_margin_left = pad_x
	sb.content_margin_right = pad_x
	sb.content_margin_top = pad_y
	sb.content_margin_bottom = pad_y
	return sb


static func apply_button(
	btn: Button,
	bg_hex: String = "#1e293b",
	border_hex: String = "#fbbf24",
	text_hex: String = "#ffffff",
	radius: int = 12,
	border_w: int = 1,
	alpha: float = 0.92
) -> void:
	var normal := make_panel(bg_hex, alpha, border_hex, 0.55, radius, border_w, 12, 8)
	var hover := make_panel(bg_hex, minf(1.0, alpha + 0.08), border_hex, 0.9, radius, border_w, 12, 8)
	hover.bg_color = hover.bg_color.lightened(0.12)
	var pressed := make_panel(bg_hex, alpha, border_hex, 1.0, radius, border_w, 12, 8)
	pressed.bg_color = pressed.bg_color.darkened(0.12)
	var disabled := make_panel("#1e293b", 0.45, "#475569", 0.35, radius, border_w, 12, 8)

	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("focus", hover)
	btn.add_theme_stylebox_override("disabled", disabled)

	var tc := Color.html(text_hex)
	btn.add_theme_color_override("font_color", tc)
	btn.add_theme_color_override("font_hover_color", tc)
	btn.add_theme_color_override("font_pressed_color", tc)
	btn.add_theme_color_override("font_focus_color", tc)
	btn.add_theme_color_override("font_disabled_color", Color(tc.r, tc.g, tc.b, 0.45))


static func apply_bar(bar: ProgressBar, fill_hex: String, bg_hex: String = "#1e293b", radius: int = 6) -> void:
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color.html(bg_hex)
	bg.set_corner_radius_all(radius)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color.html(fill_hex)
	fill.set_corner_radius_all(radius)
	bar.add_theme_stylebox_override("background", bg)
	bar.add_theme_stylebox_override("fill", fill)
	bar.show_percentage = false


static func apply_line_edit(le: LineEdit, border_hex: String = "#fbbf24") -> void:
	var normal := make_panel("#0f172a", 0.95, border_hex, 0.55, 10, 2, 10, 6)
	var focus := make_panel("#0f172a", 1.0, border_hex, 1.0, 10, 2, 10, 6)
	le.add_theme_stylebox_override("normal", normal)
	le.add_theme_stylebox_override("focus", focus)
	le.add_theme_color_override("font_color", Color.html("#fde68a"))
	le.add_theme_color_override("font_placeholder_color", Color.html("#64748b"))
