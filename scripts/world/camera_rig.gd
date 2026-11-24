class_name CameraRig
extends Node3D
## Third-person orbital camera with smooth target follow, mouse/touch drag orbit, and zoom.

@export var target: Node3D
@export var camera: Camera3D

var cam_yaw: float = 0.0
var cam_pitch: float = 0.58
var cam_dist: float = 17.0

var _is_dragging: bool = false
var _drag_touch_index: int = -1
var _last_pos: Vector2 = Vector2.ZERO

var _trauma: float = 0.0
var _shake_time: float = 0.0
var _base_pos: Vector3 = Vector3(0.0, 9.0, 17.0)
var _base_fov: float = 50.0
var _fov_offset: float = 0.0


func _ready() -> void:
	if camera == null:
		camera = get_node_or_null("Camera3D") as Camera3D
	if camera != null:
		_base_fov = camera.fov
		_base_pos = camera.global_position


func add_trauma(amount: float) -> void:
	_trauma = clampf(_trauma + amount, 0.0, 1.0)


func add_fov_punch(delta_fov: float) -> void:
	_fov_offset = clampf(_fov_offset + delta_fov, -8.5, 6.5)


func get_aim_facing() -> float:
	# Camera sits at (+sin(cam_yaw), +cos(cam_yaw)) looking toward target; forward XZ aim is (-sin, -cos)
	return atan2(-sin(cam_yaw), -cos(cam_yaw))


func _unhandled_input(event: InputEvent) -> void:
	var is_captured := (Input.mouse_mode == Input.MOUSE_MODE_CAPTURED)
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			cam_dist = clampf(cam_dist - 1.2, 8.5, 25.0)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			cam_dist = clampf(cam_dist + 1.2, 8.5, 25.0)
		elif not is_captured and mb.button_index == MOUSE_BUTTON_RIGHT:
			_is_dragging = mb.pressed
			_last_pos = mb.position
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if is_captured:
			cam_yaw -= mm.relative.x * 0.0042
			cam_pitch = clampf(cam_pitch + mm.relative.y * 0.0036, 0.14, 1.12)
		elif _is_dragging:
			cam_yaw -= mm.relative.x * 0.007
			cam_pitch = clampf(cam_pitch + mm.relative.y * 0.006, 0.14, 1.12)
	elif event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed and _drag_touch_index == -1:
			_drag_touch_index = st.index
			_last_pos = st.position
		elif not st.pressed and st.index == _drag_touch_index:
			_drag_touch_index = -1
	elif event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		if sd.index == _drag_touch_index:
			cam_yaw -= sd.relative.x * 0.008
			cam_pitch = clampf(cam_pitch + sd.relative.y * 0.007, 0.18, 1.15)


func _process(delta: float) -> void:
	if camera == null or target == null:
		return
	var tp := target.global_position
	var desired := Vector3(
		tp.x + sin(cam_yaw) * cos(cam_pitch) * cam_dist,
		tp.y + sin(cam_pitch) * cam_dist + 1.75,
		tp.z + cos(cam_yaw) * cos(cam_pitch) * cam_dist
	)
	var lerp_weight := clampf(delta * 11.0, 0.0, 1.0)
	_base_pos = _base_pos.lerp(desired, lerp_weight)

	# Trauma-based damped high-frequency camera shake (runs crisply even during hitstop!)
	var shake_offset := Vector3.ZERO
	var roll_offset := 0.0
	if _trauma > 0.001:
		_shake_time += delta * 58.0
		var shake := _trauma * _trauma
		var sx := sin(_shake_time * 1.7 + 0.3) * 0.55 + cos(_shake_time * 3.1) * 0.45
		var sy := cos(_shake_time * 2.3 + 1.1) * 0.55 + sin(_shake_time * 3.7) * 0.45
		var sz := sin(_shake_time * 2.9 + 2.4) * 0.45
		shake_offset = Vector3(sx, sy, sz) * shake * 0.82
		roll_offset = sin(_shake_time * 2.1) * shake * 0.042
		_trauma = maxf(0.0, _trauma - delta * 2.65)

	camera.global_position = _base_pos + shake_offset
	camera.look_at(Vector3(tp.x, tp.y + 1.85, tp.z) + shake_offset * 0.35, Vector3.UP)
	if absf(roll_offset) > 0.0001:
		camera.rotate_object_local(Vector3.FORWARD, roll_offset)

	# Dynamic impact FOV punch spring
	if absf(_fov_offset) > 0.01:
		_fov_offset = lerpf(_fov_offset, 0.0, clampf(delta * 10.5, 0.0, 1.0))
	else:
		_fov_offset = 0.0
	camera.fov = _base_fov + _fov_offset
