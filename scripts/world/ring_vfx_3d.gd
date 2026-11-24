class_name RingVfx3D
extends MeshInstance3D
## Expanding glowing shockwave ring effect in 3D space.

var _timer: float = 0.0
var _duration: float = 0.45
var _max_radius: float = 6.0
var _mat: StandardMaterial3D


func setup(world_pos: Vector3, color: Color, max_radius: float = 6.0, duration: float = 0.45) -> void:
	_max_radius = max_radius
	_duration = maxf(0.05, duration)
	position = Vector3(world_pos.x, 0.14, world_pos.z)

	var torus := TorusMesh.new()
	torus.inner_radius = 0.45
	torus.outer_radius = 0.75
	torus.rings = 32
	torus.ring_segments = 8
	mesh = torus

	_mat = StandardMaterial3D.new()
	_mat.albedo_color = Color(color.r, color.g, color.b, 0.9)
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material_override = _mat
	scale = Vector3(1.0, 0.08, 1.0)


func _process(delta: float) -> void:
	_timer += delta
	var t := clampf(_timer / _duration, 0.0, 1.0)
	var s := 1.0 + t * _max_radius
	scale = Vector3(s, 0.08, s)
	if _mat != null:
		_mat.albedo_color.a = 1.0 - t
	if _timer >= _duration:
		queue_free()
