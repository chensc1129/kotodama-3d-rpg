class_name Enemy3D
extends Node3D
## Procedural 3D Yokai / Boss entity with status effects (petrify, freeze, stun, shock, burn).

var enemy_name: String = ""
var is_boss: bool = false
var hp: int = 100
var max_hp: int = 100
var move_speed: float = 3.5
var atk: int = 10
var ranged: bool = false
var atk_timer: float = 1.5

var petrify_timer: float = 0.0
var freeze_timer: float = 0.0
var stun_timer: float = 0.0
var shock_timer: float = 0.0
var burn_timer: float = 0.0
var frost_tick_timer: float = 0.0
var dead: bool = false

var _orig_color: Color = Color.WHITE
var _body_mat: StandardMaterial3D
var _status_ring: MeshInstance3D
var _status_mat: StandardMaterial3D


func setup(tpl: Dictionary, p_is_boss: bool, wave_num: int, is_hard: bool) -> void:
	enemy_name = tpl["name"]
	is_boss = p_is_boss

	var scale_factor: float = 1.0 + float(wave_num - 1) * 0.24 + (0.45 if is_hard else 0.0)
	max_hp = int(round(75.0 * float(tpl["hp_mult"]) * scale_factor))
	hp = max_hp
	move_speed = float(tpl["spd"]) * (1.15 if is_hard else 1.0)
	atk = int(round(float(tpl["atk"]) * (1.0 + float(wave_num - 1) * 0.14) * (1.3 if is_hard else 1.0)))
	ranged = bool(tpl["ranged"]) or is_hard
	atk_timer = 1.2 + randf() * 1.5

	var ang := randf() * TAU
	var dist := 10.0 + randf() * 6.0
	position = Vector3(cos(ang) * dist, 0.0, sin(ang) * dist)

	_orig_color = Color.html(tpl["color"])
	_build_mesh(tpl)


func _build_mesh(tpl: Dictionary) -> void:
	_body_mat = StandardMaterial3D.new()
	_body_mat.albedo_color = _orig_color
	_body_mat.roughness = 0.45

	var eye_mat := StandardMaterial3D.new()
	eye_mat.albedo_color = Color.html("#fef08a")
	eye_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	var body_mesh := CylinderMesh.new()
	body_mesh.top_radius = 0.55
	body_mesh.bottom_radius = 0.72
	body_mesh.height = 1.4
	body_mesh.radial_segments = 12
	var body := MeshInstance3D.new()
	body.mesh = body_mesh
	body.material_override = _body_mat
	body.position = Vector3(0.0, 0.75, 0.0)
	add_child(body)

	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.52
	head_mesh.height = 1.04
	var head := MeshInstance3D.new()
	head.mesh = head_mesh
	head.material_override = _body_mat
	head.position = Vector3(0.0, 1.65, 0.0)
	add_child(head)

	var eye_mesh := SphereMesh.new()
	eye_mesh.radius = 0.10
	eye_mesh.height = 0.20
	for ex in [-0.18, 0.18]:
		var eye := MeshInstance3D.new()
		eye.mesh = eye_mesh
		eye.material_override = eye_mat
		eye.position = Vector3(ex, 1.72, 0.44)
		add_child(eye)

	# Horns for Oni & Bosses
	if is_boss or tpl["id"] == "aooni":
		var horn_mat := StandardMaterial3D.new()
		horn_mat.albedo_color = Color.html("#fef08a")
		var horn_mesh := CylinderMesh.new()
		horn_mesh.top_radius = 0.0
		horn_mesh.bottom_radius = 0.14
		horn_mesh.height = 0.60
		horn_mesh.radial_segments = 8
		for side in [-1.0, 1.0]:
			var horn := MeshInstance3D.new()
			horn.mesh = horn_mesh
			horn.material_override = horn_mat
			horn.position = Vector3(0.28 * side, 2.25, 0.05)
			horn.rotation.z = -0.25 * side
			add_child(horn)

	# Status indicator ring (Petrify / Freeze / Stun)
	_status_mat = StandardMaterial3D.new()
	_status_mat.albedo_color = Color.html("#94a3b8")
	_status_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.78
	ring_mesh.outer_radius = 0.92
	ring_mesh.rings = 24
	ring_mesh.ring_segments = 8
	_status_ring = MeshInstance3D.new()
	_status_ring.mesh = ring_mesh
	_status_ring.material_override = _status_mat
	_status_ring.position = Vector3(0.0, 0.2, 0.0)
	_status_ring.visible = false
	add_child(_status_ring)

	var s: float = float(tpl["scale"])
	scale = Vector3(s, s, s)


func is_controlled() -> bool:
	return petrify_timer > 0.0 or freeze_timer > 0.0 or stun_timer > 0.0


func update_status_visuals(delta: float) -> void:
	if _body_mat == null or _status_ring == null:
		return
	if petrify_timer > 0.0:
		_body_mat.albedo_color = Color.html("#94a3b8")
		_status_ring.visible = true
		_status_mat.albedo_color = Color.html("#f472b6")
		_status_ring.rotation.y += delta * 3.0
	elif freeze_timer > 0.0:
		_body_mat.albedo_color = Color.html("#67e8f9")
		_status_ring.visible = true
		_status_mat.albedo_color = Color.html("#06b6d4")
	elif stun_timer > 0.0:
		_body_mat.albedo_color = Color.html("#fde047")
		_status_ring.visible = true
		_status_mat.albedo_color = Color.html("#facc15")
	else:
		_body_mat.albedo_color = _orig_color
		_status_ring.visible = false


func clamp_to_arena() -> void:
	var limit: float = GameData.ARENA_RADIUS - 0.8
	var flat := Vector2(position.x, position.z)
	if flat.length() > limit:
		flat = flat.normalized() * limit
		position.x = flat.x
		position.z = flat.y
