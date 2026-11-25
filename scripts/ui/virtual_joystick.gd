class_name VirtualJoystick
extends Control
## Smooth 360-degree analog virtual joystick supporting multi-touch without
## emulated-mouse interference on Android/iOS Chrome WebGL.

signal vector_changed(vec: Vector2)

var output_vector: Vector2 = Vector2.ZERO

var _knob_offset: Vector2 = Vector2.ZERO
var _touch_index: int = -1
var _mouse_active: bool = false
var _using_touch: bool = false


func _ready() -> void:
	custom_minimum_size = Vector2(268, 268)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_using_touch = UiStyle.is_mobile_device()


func set_joystick_size(diameter: float) -> void:
	custom_minimum_size = Vector2(diameter, diameter)
	queue_redraw()


func _draw() -> void:
	var center := size * 0.5
	var base_r := minf(size.x, size.y) * 0.48
	var knob_r := base_r * 0.42

	draw_circle(center, base_r, Color(0.06, 0.09, 0.16, 0.84))
	draw_arc(center, base_r, 0.0, TAU, 48, Color(0.98, 0.75, 0.14, 0.65), 3.5, true)
	draw_arc(center, base_r * 0.62, 0.0, TAU, 36, Color(0.98, 0.75, 0.14, 0.22), 2.0, true)

	var knob_pos := center + _knob_offset
	draw_circle(knob_pos, knob_r, Color.html("#f59e0b"))
	draw_circle(knob_pos + Vector2(-knob_r * 0.18, -knob_r * 0.18), knob_r * 0.45, Color(1.0, 0.94, 0.72, 0.65))
	draw_arc(knob_pos, knob_r, 0.0, TAU, 32, Color.html("#fffbeb"), 3.0, true)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_using_touch = true
		_mouse_active = false
		var st := event as InputEventScreenTouch
		if st.pressed and _touch_index == -1:
			var center := size * 0.5
			var hit_r := minf(size.x, size.y) * 0.56
			if st.position.distance_to(center) <= hit_r:
				_touch_index = st.index
				_update_from_local(st.position)
				accept_event()
		elif not st.pressed and st.index == _touch_index:
			_reset()
			accept_event()
	elif event is InputEventScreenDrag:
		_using_touch = true
		var sd := event as InputEventScreenDrag
		if sd.index == _touch_index:
			_update_from_local(sd.position)
			accept_event()
	elif not _using_touch:
		if event is InputEventMouseButton:
			var mb := event as InputEventMouseButton
			if mb.button_index == MOUSE_BUTTON_LEFT:
				if mb.pressed:
					_mouse_active = true
					_update_from_local(mb.position)
					accept_event()
				elif _mouse_active:
					_reset()
					accept_event()
		elif event is InputEventMouseMotion and _mouse_active:
			var mm := event as InputEventMouseMotion
			_update_from_local(mm.position)
			accept_event()


func _input(event: InputEvent) -> void:
	if not _using_touch and _mouse_active and event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
			_reset()
	elif _touch_index != -1 and event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.index == _touch_index and not st.pressed:
			_reset()
			get_viewport().set_input_as_handled()
	elif _touch_index != -1 and event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		if sd.index == _touch_index:
			var local_pos := get_global_transform_with_canvas().affine_inverse() * sd.position
			_update_from_local(local_pos)
			get_viewport().set_input_as_handled()


func _update_from_local(local_pos: Vector2) -> void:
	var center := size * 0.5
	var max_r := minf(size.x, size.y) * 0.36
	var delta := local_pos - center
	var dist := delta.length()
	if dist > max_r:
		delta = (delta / dist) * max_r
		dist = max_r
	_knob_offset = delta
	var raw_vec := delta / maxf(1.0, max_r)
	if raw_vec.length() < 0.08:
		output_vector = Vector2.ZERO
	else:
		output_vector = raw_vec
	vector_changed.emit(output_vector)
	queue_redraw()


func _reset() -> void:
	_mouse_active = false
	_touch_index = -1
	_knob_offset = Vector2.ZERO
	output_vector = Vector2.ZERO
	vector_changed.emit(Vector2.ZERO)
	queue_redraw()
