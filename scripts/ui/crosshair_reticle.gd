class_name CrosshairReticle
extends Control
## Desktop center crosshair reticle with dynamic attack bloom and anime hit-marker X feedback.

var is_locked: bool = false
var _bloom: float = 0.0
var _hit_timer: float = 0.0
var _hit_max: float = 0.18
var _hit_is_crit: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func set_locked_state(locked: bool) -> void:
	if is_locked != locked:
		is_locked = locked
		queue_redraw()


func trigger_bloom(step: int = 1) -> void:
	_bloom = maxf(_bloom, 12.0 if step == 3 else 7.0)
	queue_redraw()


func trigger_hit_marker(is_crit: bool = false) -> void:
	_hit_is_crit = is_crit
	_hit_max = 0.24 if is_crit else 0.16
	_hit_timer = _hit_max
	_bloom = maxf(_bloom, 15.0 if is_crit else 9.0)
	queue_redraw()


func _process(delta: float) -> void:
	var dirty := false
	if _bloom > 0.05:
		_bloom = lerpf(_bloom, 0.0, clampf(delta * 14.0, 0.0, 1.0))
		dirty = true
	elif _bloom != 0.0:
		_bloom = 0.0
		dirty = true

	if _hit_timer > 0.0:
		_hit_timer = maxf(0.0, _hit_timer - delta)
		dirty = true

	if dirty:
		queue_redraw()


func _draw() -> void:
	var center := size * 0.5
	var alpha := 0.94 if is_locked else 0.42
	var outline_col := Color(0.04, 0.06, 0.12, alpha * 0.85)
	var main_col := Color(1.0, 0.98, 0.90, alpha) if is_locked else Color(0.85, 0.90, 0.98, alpha)
	var accent_col := Color(0.98, 0.75, 0.14, alpha)

	var gap := 7.0 + _bloom
	var tick_len := 9.0
	var thick := 2.4

	# 4 crisp cardinal crosshair ticks with dark outline for visibility on snow & lava
	var dirs := [
		Vector2(1.0, 0.0),
		Vector2(-1.0, 0.0),
		Vector2(0.0, 1.0),
		Vector2(0.0, -1.0),
	]
	for d: Vector2 in dirs:
		var p1 := center + d * gap
		var p2 := center + d * (gap + tick_len)
		draw_line(p1, p2, outline_col, thick + 2.4, true)
		draw_line(p1, p2, main_col, thick, true)

	# Subtle outer ring arc when locked
	if is_locked:
		var ring_r := 18.0 + _bloom * 0.55
		draw_arc(center, ring_r, 0.0, TAU, 36, Color(1.0, 0.95, 0.82, 0.22), 1.4, true)

	# Center precision dot
	draw_circle(center, 3.6, outline_col)
	draw_circle(center, 2.2, accent_col if is_locked else main_col)

	# Dynamic diagonal hit-marker X on attack impact!
	if _hit_timer > 0.0:
		var hp := clampf(_hit_timer / maxf(0.001, _hit_max), 0.0, 1.0)
		var hm_col := Color(1.0, 0.86, 0.22, hp) if _hit_is_crit else Color(1.0, 0.42, 0.48, hp)
		var hm_out := Color(0.06, 0.04, 0.08, hp * 0.85)
		var hm_in := 6.0 + (1.0 - hp) * (10.0 if _hit_is_crit else 6.0)
		var hm_out_r := hm_in + (13.0 if _hit_is_crit else 9.0)
		var hm_w := 3.6 if _hit_is_crit else 2.6
		var diags := [
			Vector2(1.0, 1.0).normalized(),
			Vector2(-1.0, 1.0).normalized(),
			Vector2(1.0, -1.0).normalized(),
			Vector2(-1.0, -1.0).normalized(),
		]
		for dg: Vector2 in diags:
			var a := center + dg * hm_in
			var b := center + dg * hm_out_r
			draw_line(a, b, hm_out, hm_w + 2.4, true)
			draw_line(a, b, hm_col, hm_w, true)
