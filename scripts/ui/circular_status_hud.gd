class_name CircularStatusHud
extends Control
## Wafuu Shrine Astrolabe circular radial status HUD (Bottom-Left on Desktop, Top-Left on Mobile).
## Renders concentric antialiased circular gauges for HP, SP (with 30/70 SP markers), EXP,
## hero portrait medallion + level crest, and a dedicated circular Stamina orb.

var hp_ratio: float = 1.0
var hp_text: String = "130/130"
var sp_ratio: float = 0.4
var sp_text: String = "40/100"
var sta_ratio: float = 1.0
var sta_text: String = "100"
var sta_low: bool = false
var exp_ratio: float = 0.0
var level_num: int = 1
var hero_icon: String = "👘"
var hero_name: String = "櫻花妹"
var hero_accent: Color = Color.html("#f43f5e")
var is_compact: bool = false

var _display_hp: float = 1.0
var _display_sp: float = 0.4
var _display_sta: float = 1.0
var _pulse: float = 0.0

var _icon_lbl: Label
var _lv_lbl: Label
var _sta_lbl: Label
var _info_box: VBoxContainer
var _name_lbl: Label
var _hp_num_lbl: Label
var _sp_num_lbl: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_labels()
	set_compact(false)


func _build_labels() -> void:
	_icon_lbl = Label.new()
	_icon_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_icon_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_icon_lbl)

	_lv_lbl = Label.new()
	_lv_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lv_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lv_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_lv_lbl.add_theme_color_override("font_color", Color.html("#fef3c7"))
	UiStyle.style_label_shadow(_lv_lbl, 0.85, 2)
	add_child(_lv_lbl)

	_sta_lbl = Label.new()
	_sta_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sta_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sta_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_sta_lbl.add_theme_color_override("font_color", Color.html("#fde68a"))
	UiStyle.style_label_shadow(_sta_lbl, 0.80, 1)
	add_child(_sta_lbl)

	_info_box = VBoxContainer.new()
	_info_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_info_box.add_theme_constant_override("separation", 2)
	add_child(_info_box)

	_name_lbl = Label.new()
	_name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_name_lbl.add_theme_color_override("font_color", Color.html("#fef3c7"))
	UiStyle.style_label_shadow(_name_lbl, 0.80, 1)
	_info_box.add_child(_name_lbl)

	_hp_num_lbl = Label.new()
	_hp_num_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hp_num_lbl.add_theme_color_override("font_color", Color.html("#86efac"))
	UiStyle.style_label_shadow(_hp_num_lbl, 0.78, 1)
	_info_box.add_child(_hp_num_lbl)

	_sp_num_lbl = Label.new()
	_sp_num_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sp_num_lbl.add_theme_color_override("font_color", Color.html("#7dd3fc"))
	UiStyle.style_label_shadow(_sp_num_lbl, 0.78, 1)
	_info_box.add_child(_sp_num_lbl)


func set_compact(compact: bool) -> void:
	is_compact = compact
	var main_r := 48.0 if compact else 58.0
	var sat_r := 28.0 if compact else 33.0
	var total_w := 280.0 if compact else 326.0
	var total_h := 116.0 if compact else 136.0
	custom_minimum_size = Vector2(total_w, total_h)
	size = custom_minimum_size

	var mc := _main_center()
	var sc := _sat_center()

	_icon_lbl.position = mc - Vector2(28, 28)
	_icon_lbl.size = Vector2(56, 56)
	_icon_lbl.add_theme_font_size_override("font_size", 28 if compact else 34)

	_lv_lbl.position = Vector2(mc.x - 32.0, mc.y + main_r - 17.0)
	_lv_lbl.size = Vector2(64, 20)
	_lv_lbl.add_theme_font_size_override("font_size", 12 if compact else 13)

	_sta_lbl.position = sc - Vector2(sat_r, sat_r)
	_sta_lbl.size = Vector2(sat_r * 2.0, sat_r * 2.0)
	_sta_lbl.add_theme_font_size_override("font_size", 11 if compact else 12)

	_info_box.position = Vector2(mc.x + main_r + 14.0, 12.0 if compact else 14.0)
	_info_box.size = Vector2(150.0, 62.0)
	_name_lbl.add_theme_font_size_override("font_size", 14 if compact else 13)
	_hp_num_lbl.add_theme_font_size_override("font_size", 13 if compact else 12)
	_sp_num_lbl.add_theme_font_size_override("font_size", 13 if compact else 12)
	queue_redraw()


func update_stats(
	p_hp: float, p_max_hp: float,
	p_sp: float, p_max_sp: float,
	p_sta: float, p_max_sta: float, p_sta_low: bool,
	p_exp_ratio: float,
	p_lv: int, p_icon: String, p_name: String, p_accent_hex: String
) -> void:
	hp_ratio = clampf(p_hp / maxf(1.0, p_max_hp), 0.0, 1.0)
	hp_text = "HP %d/%d" % [int(round(p_hp)), int(round(p_max_hp))]
	sp_ratio = clampf(p_sp / maxf(1.0, p_max_sp), 0.0, 1.0)
	sp_text = "SP %d/%d" % [int(floor(p_sp)), int(round(p_max_sp))]
	sta_ratio = clampf(p_sta / maxf(1.0, p_max_sta), 0.0, 1.0)
	sta_text = "體力\n%d" % int(floor(p_sta))
	sta_low = p_sta_low
	exp_ratio = clampf(p_exp_ratio, 0.0, 1.0)
	level_num = p_lv
	hero_icon = p_icon
	hero_name = p_name
	hero_accent = Color.html(p_accent_hex)

	_icon_lbl.text = hero_icon
	_lv_lbl.text = "Lv.%d" % level_num
	_sta_lbl.text = sta_text
	_sta_lbl.add_theme_color_override("font_color", Color.html("#fda4af") if sta_low else Color.html("#fde68a"))
	_name_lbl.text = hero_name
	_hp_num_lbl.text = hp_text
	_sp_num_lbl.text = sp_text
	queue_redraw()


func _main_center() -> Vector2:
	return Vector2(56.0, 58.0) if is_compact else Vector2(66.0, 68.0)


func _sat_center() -> Vector2:
	return Vector2(142.0, 84.0) if is_compact else Vector2(166.0, 98.0)


func _process(delta: float) -> void:
	_pulse += delta * 4.2
	var spd := clampf(delta * 12.0, 0.0, 1.0)
	var changed := false
	if absf(_display_hp - hp_ratio) > 0.002:
		_display_hp = lerpf(_display_hp, hp_ratio, spd)
		changed = true
	if absf(_display_sp - sp_ratio) > 0.002:
		_display_sp = lerpf(_display_sp, sp_ratio, spd)
		changed = true
	if absf(_display_sta - sta_ratio) > 0.002:
		_display_sta = lerpf(_display_sta, sta_ratio, spd)
		changed = true
	if changed or sp_ratio >= 0.70 or sta_low:
		queue_redraw()


func _draw() -> void:
	var mc := _main_center()
	var sc := _sat_center()
	var main_r := 48.0 if is_compact else 58.0
	var sat_r := 28.0 if is_compact else 33.0

	# Sweeps: 270-degree horseshoe starting bottom-left (135 deg) clockwise to bottom-right (405 deg)
	var start_ang := deg_to_rad(135.0)
	var full_sweep := deg_to_rad(270.0)

	# 1. Soft dark lacquer backdrop discs + outer gold astrolabe filigree
	draw_circle(mc + Vector2(0.0, 4.0), main_r + 6.0, Color(0.01, 0.02, 0.06, 0.55))
	draw_circle(mc, main_r + 4.0, Color(0.04, 0.06, 0.13, 0.88))
	draw_arc(mc, main_r + 4.0, 0.0, TAU, 48, Color(0.91, 0.77, 0.45, 0.52), 1.6, true)

	# Hero-colored core portrait medallion
	var core_r := main_r - 22.0
	draw_circle(mc, core_r, Color(hero_accent.r * 0.45, hero_accent.g * 0.45, hero_accent.b * 0.45, 0.92))
	draw_arc(mc, core_r, 0.0, TAU, 40, Color(0.99, 0.90, 0.54, 0.45), 1.5, true)

	# EXP fine gold 360-degree halo right around core portrait
	var exp_r := core_r + 2.5
	draw_arc(mc, exp_r, -PI * 0.5, -PI * 0.5 + TAU * maxf(0.01, exp_ratio), 40, Color.html("#fbbf24"), 2.4, true)

	# 2. HP Outer Circular Ring (Emerald -> Amber -> Crimson when low)
	var hp_r := main_r - 5.0
	var hp_w := 8.0 if not is_compact else 7.0
	draw_arc(mc, hp_r, start_ang, start_ang + full_sweep, 48, Color(0.08, 0.12, 0.20, 0.90), hp_w, true)
	var hp_col := Color.html("#22c55e")
	if _display_hp < 0.30:
		hp_col = Color.html("#f43f5e")
	elif _display_hp < 0.60:
		hp_col = Color.html("#f59e0b")
	if _display_hp > 0.005:
		var hp_end := start_ang + full_sweep * _display_hp
		draw_arc(mc, hp_r, start_ang, hp_end, 48, hp_col, hp_w, true)
		var tip := mc + Vector2(cos(hp_end), sin(hp_end)) * hp_r
		draw_circle(tip, hp_w * 0.52, hp_col.lerp(Color.WHITE, 0.55))

	# 3. SP Middle Circular Ring (Sky-Blue -> Pulsing Gold when >= 70% Ult Ready!)
	var sp_r := main_r - 15.0
	var sp_w := 6.0 if not is_compact else 5.2
	draw_arc(mc, sp_r, start_ang, start_ang + full_sweep, 44, Color(0.06, 0.11, 0.22, 0.92), sp_w, true)
	var sp_col := Color.html("#38bdf8")
	if sp_ratio >= 0.70:
		var glow := 0.5 + 0.5 * sin(_pulse)
		sp_col = Color.html("#38bdf8").lerp(Color.html("#fde047"), 0.55 + glow * 0.35)
	elif sp_ratio >= 0.30:
		sp_col = Color.html("#60a5fa")
	if _display_sp > 0.005:
		var sp_end := start_ang + full_sweep * _display_sp
		draw_arc(mc, sp_r, start_ang, sp_end, 44, sp_col, sp_w, true)
		var stip := mc + Vector2(cos(sp_end), sin(sp_end)) * sp_r
		draw_circle(stip, sp_w * 0.52, Color.WHITE)

	# SP 30% & 70% notch tick marks (signature / ultimate cost thresholds!)
	for thresh in [0.30, 0.70]:
		var ta := start_ang + full_sweep * float(thresh)
		var p_in := mc + Vector2(cos(ta), sin(ta)) * (sp_r - sp_w * 0.55)
		var p_out := mc + Vector2(cos(ta), sin(ta)) * (sp_r + sp_w * 0.55)
		draw_line(p_in, p_out, Color(1.0, 0.96, 0.75, 0.82), 1.8, true)

	# Level badge pill backing at bottom gap of main horseshoe
	var lv_rect := Rect2(mc.x - 24.0, mc.y + main_r - 15.0, 48.0, 18.0)
	draw_rect(lv_rect, Color(0.06, 0.09, 0.18, 0.94), true)
	draw_rect(lv_rect, Color(0.91, 0.77, 0.45, 0.85), false, 1.2)

	# 4. Dedicated Satellite Circular Stamina Orb (體力)
	draw_circle(sc + Vector2(0.0, 3.0), sat_r + 3.0, Color(0.01, 0.02, 0.06, 0.52))
	draw_circle(sc, sat_r + 1.5, Color(0.05, 0.07, 0.14, 0.88))
	draw_arc(sc, sat_r + 1.5, 0.0, TAU, 36, Color(0.91, 0.77, 0.45, 0.42), 1.2, true)

	var sta_ring_r := sat_r - 4.5
	var sta_w := 5.5 if not is_compact else 4.8
	draw_arc(sc, sta_ring_r, -PI * 0.5, -PI * 0.5 + TAU, 36, Color(0.14, 0.11, 0.06, 0.88), sta_w, true)
	var sta_col := Color.html("#f59e0b")
	if sta_low:
		var warn := 0.5 + 0.5 * sin(_pulse * 1.8)
		sta_col = Color.html("#f43f5e").lerp(Color.html("#fda4af"), warn * 0.45)
	if _display_sta > 0.005:
		var sta_end := -PI * 0.5 + TAU * _display_sta
		draw_arc(sc, sta_ring_r, -PI * 0.5, sta_end, 36, sta_col, sta_w, true)
		var tip_s := sc + Vector2(cos(sta_end), sin(sta_end)) * sta_ring_r
		draw_circle(tip_s, sta_w * 0.5, Color.WHITE)
