class_name CameraRig
extends Node3D
## Genshin-style third-person over-the-shoulder orbital camera with pointer-lock free-look,
## right-shoulder framing offset, smooth follow, trauma shake, and impact FOV punch.

@export var target: Node3D
@export var camera: Camera3D

var cam_yaw: float = 0.0
var cam_pitch: float = 0.22
var cam_dist: float = 7.4
var shoulder_offset: float = 0.85
var look_height: float = 1.92

var _is_dragging: bool = false
var _drag_touch_index: int = -1
var _last_pos: Vector2 = Vector2.ZERO

var _trauma: float = 0.0
var _shake_time: float = 0.0
var _base_pos: Vector3 = Vector3(0.85, 3.6, 11.2)
var _base_look: Vector3 = Vector3(0.85, 1.92, 4.0)
var _initialized: bool = false
var _base_fov: float = 56.0
var _fov_offset: float = 0.0


func _ready() -> void:
	if camera == null:
		camera = get_node_or_null("Camera3D") as Camera3D
	if camera != null:
		camera.fov = _base_fov
		_base_pos = camera.global_position


func add_trauma(amount: float) -> void:
	_trauma = clampf(_trauma + amount, 0.0, 1.0)


func add_fov_punch(delta_fov: float) -> void:
	_fov_offset = clampf(_fov_offset + delta_fov, -8.5, 6.5)


func get_aim_facing() -> float:
	# Camera sits behind target along (+sin(cam_yaw), +cos(cam_yaw)); forward XZ aim is (-sin, -cos)
	return atan2(-sin(cam_yaw), -cos(cam_yaw))


func _unhandled_input(event: InputEvent) -> void:
	var is_captured := (Input.mouse_mode == Input.MOUSE_MODE_CAPTURED)
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			cam_dist = clampf(cam_dist - 0.75, 4.2, 13.5)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			cam_dist = clampf(cam_dist + 0.75, 4.2, 13.5)
		elif not is_captured and mb.button_index == MOUSE_BUTTON_RIGHT:
			_is_dragging = mb.pressed
			_last_pos = mb.position
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		var sens: float = GameState.mouse_sens_mult
		if is_captured:
			cam_yaw -= mm.relative.x * 0.0040 * sens
			cam_pitch = clampf(cam_pitch + mm.relative.y * 0.0034 * sens, -0.14, 0.95)
		elif _is_dragging:
			cam_yaw -= mm.relative.x * 0.0068 * sens
			cam_pitch = clampf(cam_pitch + mm.relative.y * 0.0058 * sens, -0.14, 0.95)
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
			cam_yaw -= sd.relative.x * 0.0075
			cam_pitch = clampf(cam_pitch + sd.relative.y * 0.0065, -0.10, 0.95)


func _process(delta: float) -> void:
	if camera == null or target == null:
		return
	var tp := target.global_position

	# Over-the-shoulder basis vectors on XZ plane
	var back_xz := Vector3(sin(cam_yaw), 0.0, cos(cam_yaw))
	var right_xz := Vector3(cos(cam_yaw), 0.0, -sin(cam_yaw))
	var fwd_xz := -back_xz

	# Slightly tighter shoulder offset as camera zooms in, framing hero to left of center crosshair
	var shoulder_scale := clampf(cam_dist / 7.4, 0.65, 1.15)
	var pivot := Vector3(tp.x, tp.y + look_height, tp.z) + right_xz * (shoulder_offset * shoulder_scale)

	var desired_pos := pivot + (back_xz * cos(cam_pitch) + Vector3.UP * sin(cam_pitch)) * cam_dist
	# Keep camera cleanly above the arena floor when pitching upward at tall Bosses
	desired_pos.y = maxf(desired_pos.y, tp.y + 0.92)
	var desired_look := pivot + fwd_xz * 2.2

	if not _initialized:
		_initialized = true
		_base_pos = desired_pos
		_base_look = desired_look
	else:
		var pos_w := clampf(delta * 13.5, 0.0, 1.0)
		var look_w := clampf(delta * 16.0, 0.0, 1.0)
		_base_pos = _base_pos.lerp(desired_pos, pos_w)
		_base_look = _base_look.lerp(desired_look, look_w)

	# Trauma-based damped high-frequency camera shake (runs crisply even during hitstop!)
	var shake_offset := Vector3.ZERO
	var roll_offset := 0.0
	if _trauma > 0.001:
		_shake_time += delta * 58.0
		var shake := _trauma * _trauma
		var sx := sin(_shake_time * 1.7 + 0.3) * 0.55 + cos(_shake_time * 3.1) * 0.45
		var sy := cos(_shake_time * 2.3 + 1.1) * 0.55 + sin(_shake_time * 3.7) * 0.45
		var sz := sin(_shake_time * 2.9 + 2.4) * 0.45
		shake_offset = Vector3(sx, sy, sz) * shake * 0.56
		roll_offset = sin(_shake_time * 2.1) * shake * 0.036
		_trauma = maxf(0.0, _trauma - delta * 2.75)

	camera.global_position = _base_pos + shake_offset
	camera.look_at(_base_look + shake_offset * 0.28, Vector3.UP)
	if absf(roll_offset) > 0.0001:
		camera.rotate_object_local(Vector3.FORWARD, roll_offset)

	# Dynamic impact FOV punch spring
	if absf(_fov_offset) > 0.01:
		_fov_offset = lerpf(_fov_offset, 0.0, clampf(delta * 10.5, 0.0, 1.0))
	else:
		_fov_offset = 0.0
	camera.fov = _base_fov + _fov_offset
