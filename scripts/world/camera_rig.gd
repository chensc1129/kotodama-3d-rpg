class_name CameraRig
extends Node3D
## Buttery-smooth Genshin-style third-person over-the-shoulder orbital camera.
## Uses frame-rate-independent exponential smoothing in spherical coordinates (yaw/pitch)
## around a smoothly followed pivot so touch & mouse rotation never stutters or rubber-bands.

@export var target: Node3D
@export var camera: Camera3D
@export var arena: Arena3D

const CAMERA_FAR_CLIP: float = 680.0

var cam_yaw: float = 0.0
var cam_pitch: float = 0.22
var cam_dist: float = 7.4
var shoulder_offset: float = 0.85
var look_height: float = 1.92

var _target_yaw: float = 0.0
var _target_pitch: float = 0.22
var _target_dist: float = 7.4
var _effective_dist: float = 7.4
var _smooth_terrain_floor: float = -999.0
var _follow_pos: Vector3 = Vector3(0.0, 0.0, 4.0)

var _is_dragging: bool = false
var _drag_touch_index: int = -1

var _trauma: float = 0.0
var _shake_time: float = 0.0
var _initialized: bool = false
var _base_fov: float = 56.0
var _fov_offset: float = 0.0


func _ready() -> void:
	process_priority = 20
	if GameState.is_arpg_mode():
		# Face cleanly North (-Z) toward Fjord Cove, towering West Mountain & wilderness trail
		cam_yaw = 0.0
		cam_pitch = 0.20
	_target_yaw = cam_yaw
	_target_pitch = cam_pitch
	_target_dist = cam_dist
	_effective_dist = cam_dist
	if camera == null:
		camera = get_node_or_null("Camera3D") as Camera3D
	if arena == null:
		arena = get_node_or_null("../Arena3D") as Arena3D
	if camera != null:
		camera.fov = _base_fov
		camera.far = CAMERA_FAR_CLIP


func reset_camera(yaw: float = 0.0, pitch: float = 0.20, dist: float = 7.4) -> void:
	cam_yaw = yaw
	_target_yaw = yaw
	cam_pitch = pitch
	_target_pitch = pitch
	cam_dist = dist
	_target_dist = dist
	_effective_dist = dist
	_smooth_terrain_floor = -999.0
	if target != null:
		_follow_pos = target.global_position
		_initialized = true


func add_trauma(amount: float) -> void:
	_trauma = clampf(_trauma + amount, 0.0, 1.0)


func add_fov_punch(delta_fov: float) -> void:
	_fov_offset = clampf(_fov_offset + delta_fov, -8.5, 6.5)


func get_aim_facing() -> float:
	# Camera sits behind target along (+sin(cam_yaw), +cos(cam_yaw)); forward XZ aim is (-sin, -cos)
	return atan2(-sin(cam_yaw), -cos(cam_yaw))


func _sample_camera_terrain_floor(x: float, z: float) -> float:
	if arena == null:
		return -999.0
	# 5-point cross probe around camera XZ protects the near clip plane on steep 45-50 deg mountain slopes
	var probe_r := 0.48
	var h := arena.get_base_terrain_height(x, z)
	h = maxf(h, arena.get_base_terrain_height(x + probe_r, z))
	h = maxf(h, arena.get_base_terrain_height(x - probe_r, z))
	h = maxf(h, arena.get_base_terrain_height(x, z + probe_r))
	h = maxf(h, arena.get_base_terrain_height(x, z - probe_r))
	var wl := arena.get_water_level(x, z)
	if wl > -50.0:
		h = maxf(h, wl)
	return h + 0.68


func _input(event: InputEvent) -> void:
	# ALWAYS clear our touch/mouse drag lock on release even if the finger lifts over a UI widget!
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if not st.pressed and st.index == _drag_touch_index:
			_drag_touch_index = -1
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT and not mb.pressed:
			_is_dragging = false


func _unhandled_input(event: InputEvent) -> void:
	var is_captured := (Input.mouse_mode == Input.MOUSE_MODE_CAPTURED)
	var sens: float = GameState.mouse_sens_mult

	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_target_dist = clampf(_target_dist - 0.75, 4.2, 16.5)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_target_dist = clampf(_target_dist + 0.75, 4.2, 16.5)
		elif not is_captured and mb.button_index == MOUSE_BUTTON_RIGHT:
			_is_dragging = mb.pressed
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if is_captured:
			var rel := mm.relative.clamp(Vector2(-120.0, -120.0), Vector2(120.0, 120.0))
			_target_yaw -= rel.x * 0.0040 * sens
			_target_pitch = clampf(_target_pitch + rel.y * 0.0034 * sens, -0.36, 0.95)
		elif _is_dragging:
			var rel := mm.relative.clamp(Vector2(-120.0, -120.0), Vector2(120.0, 120.0))
			_target_yaw -= rel.x * 0.0065 * sens
			_target_pitch = clampf(_target_pitch + rel.y * 0.0055 * sens, -0.36, 0.95)
	elif event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed and _drag_touch_index == -1:
			_drag_touch_index = st.index
		elif not st.pressed and st.index == _drag_touch_index:
			_drag_touch_index = -1
	elif event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		# Auto-adopt unhandled drag immediately so swiping never misses frame 1!
		if _drag_touch_index == -1:
			_drag_touch_index = sd.index
		if sd.index == _drag_touch_index:
			# Clamp browser touch-coalescing spikes for silky smooth Android/iOS camera turns
			var rel := sd.relative.clamp(Vector2(-95.0, -95.0), Vector2(95.0, 95.0))
			_target_yaw -= rel.x * 0.0056 * sens
			_target_pitch = clampf(_target_pitch + rel.y * 0.0044 * sens, -0.32, 0.95)


func _process(delta: float) -> void:
	if camera == null or target == null:
		return
	if arena == null:
		arena = get_node_or_null("../Arena3D") as Arena3D
	if camera.far < CAMERA_FAR_CLIP - 1.0:
		camera.far = CAMERA_FAR_CLIP

	var dt := minf(0.05, delta)
	var tp := target.global_position
	var snapped := false

	if (not _initialized) or _follow_pos.distance_squared_to(tp) > 576.0:
		_initialized = true
		snapped = true
		_follow_pos = tp
		cam_yaw = _target_yaw
		cam_pitch = _target_pitch
		cam_dist = _target_dist
		_effective_dist = cam_dist
		_smooth_terrain_floor = -999.0
	else:
		# Tight XZ follow + smooth Y slope damping + smooth spherical angles = zero walking jitter!
		var ang_w := 1.0 - exp(-26.0 * dt)
		var xz_w := 1.0 - exp(-28.0 * dt)
		var y_w := 1.0 - exp(-14.0 * dt)
		var dist_w := 1.0 - exp(-14.0 * dt)
		cam_yaw = lerpf(cam_yaw, _target_yaw, ang_w)
		cam_pitch = lerpf(cam_pitch, _target_pitch, ang_w)
		cam_dist = lerpf(cam_dist, _target_dist, dist_w)
		_follow_pos.x = lerpf(_follow_pos.x, tp.x, xz_w)
		_follow_pos.z = lerpf(_follow_pos.z, tp.z, xz_w)
		_follow_pos.y = lerpf(_follow_pos.y, tp.y, y_w)

	# Compute camera directly on exact orbital sphere around smoothly-followed hero pivot
	var back_xz := Vector3(sin(cam_yaw), 0.0, cos(cam_yaw))
	var right_xz := Vector3(cos(cam_yaw), 0.0, -sin(cam_yaw))
	var fwd_xz := -back_xz

	var shoulder_scale := clampf(cam_dist / 7.4, 0.65, 1.15)
	var pivot := Vector3(_follow_pos.x, _follow_pos.y + look_height, _follow_pos.z) + right_xz * (shoulder_offset * shoulder_scale)
	var ray_dir := back_xz * cos(cam_pitch) + Vector3.UP * sin(cam_pitch)

	# Smooth spring-arm anti-clipping against steep mountain cliffs behind the hero
	var desired_dist := cam_dist
	if arena != null:
		var fracs := [0.34, 0.52, 0.70, 0.86, 1.0]
		for f_val in fracs:
			var frac: float = float(f_val)
			var sp := pivot + ray_dir * (cam_dist * frac)
			var sg := arena.get_base_terrain_height(sp.x, sp.z)
			if sg + 0.65 > sp.y and sg > pivot.y + 1.35:
				desired_dist = minf(desired_dist, maxf(2.5, cam_dist * frac - 0.55))
				break

	if snapped:
		_effective_dist = desired_dist
	elif desired_dist < _effective_dist:
		_effective_dist = lerpf(_effective_dist, desired_dist, 1.0 - exp(-22.0 * dt))
	else:
		_effective_dist = lerpf(_effective_dist, desired_dist, 1.0 - exp(-9.0 * dt))

	var cam_pos := pivot + ray_dir * _effective_dist

	# Smooth terrain-height floor clearance so the camera never clips underground on steep slopes
	var min_cam_y := _follow_pos.y + 0.62
	if arena != null:
		var terrain_floor := _sample_camera_terrain_floor(cam_pos.x, cam_pos.z)
		if snapped or _smooth_terrain_floor < -500.0:
			_smooth_terrain_floor = terrain_floor
		elif terrain_floor > _smooth_terrain_floor:
			_smooth_terrain_floor = lerpf(_smooth_terrain_floor, terrain_floor, 1.0 - exp(-26.0 * dt))
		else:
			_smooth_terrain_floor = lerpf(_smooth_terrain_floor, terrain_floor, 1.0 - exp(-10.0 * dt))
		# Hard floor (terrain_floor - 0.12 = h_max + 0.56) guarantees zero underground clipping even on whip-turns
		min_cam_y = maxf(min_cam_y, maxf(_smooth_terrain_floor, terrain_floor - 0.12))
	else:
		min_cam_y = _follow_pos.y + 0.92

	cam_pos.y = maxf(cam_pos.y, min_cam_y)
	var look_pos := pivot + fwd_xz * 2.2

	# Trauma-based damped high-frequency camera shake (runs crisply even during hitstop!)
	var shake_offset := Vector3.ZERO
	var roll_offset := 0.0
	if _trauma > 0.001:
		_shake_time += dt * 58.0
		var shake := _trauma * _trauma
		var sx := sin(_shake_time * 1.7 + 0.3) * 0.55 + cos(_shake_time * 3.1) * 0.45
		var sy := cos(_shake_time * 2.3 + 1.1) * 0.55 + sin(_shake_time * 3.7) * 0.45
		var sz := sin(_shake_time * 2.9 + 2.4) * 0.45
		shake_offset = Vector3(sx, sy, sz) * shake * 0.56
		roll_offset = sin(_shake_time * 2.1) * shake * 0.036
		_trauma = maxf(0.0, _trauma - dt * 2.75)

	camera.global_position = cam_pos + shake_offset
	camera.look_at(look_pos + shake_offset * 0.28, Vector3.UP)
	if absf(roll_offset) > 0.0001:
		camera.rotate_object_local(Vector3.FORWARD, roll_offset)

	# Dynamic impact FOV punch spring
	if absf(_fov_offset) > 0.01:
		_fov_offset = lerpf(_fov_offset, 0.0, 1.0 - exp(-12.0 * dt))
	else:
		_fov_offset = 0.0
	camera.fov = _base_fov + _fov_offset
