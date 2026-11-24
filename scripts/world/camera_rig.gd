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


func _ready() -> void:
	if camera == null:
		camera = get_node_or_null("Camera3D") as Camera3D


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_is_dragging = mb.pressed
			_last_pos = mb.position
		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			cam_dist = clampf(cam_dist - 1.2, 9.0, 26.0)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			cam_dist = clampf(cam_dist + 1.2, 9.0, 26.0)
	elif event is InputEventMouseMotion and _is_dragging:
		var mm := event as InputEventMouseMotion
		cam_yaw -= mm.relative.x * 0.007
		cam_pitch = clampf(cam_pitch + mm.relative.y * 0.006, 0.25, 1.15)
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
			cam_pitch = clampf(cam_pitch + sd.relative.y * 0.007, 0.25, 1.15)


func _process(delta: float) -> void:
	if camera == null or target == null:
		return
	var tp := target.global_position
	var desired := Vector3(
		tp.x + sin(cam_yaw) * cos(cam_pitch) * cam_dist,
		tp.y + sin(cam_pitch) * cam_dist + 1.5,
		tp.z + cos(cam_yaw) * cos(cam_pitch) * cam_dist
	)
	var lerp_weight := clampf(delta * 8.5, 0.0, 1.0)
	camera.global_position = camera.global_position.lerp(desired, lerp_weight)
	camera.look_at(Vector3(tp.x, tp.y + 1.4, tp.z), Vector3.UP)
