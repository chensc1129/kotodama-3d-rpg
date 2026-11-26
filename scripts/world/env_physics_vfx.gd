class_name EnvPhysicsVfx
extends Node3D
## Pooled, mobile-WebGL2-friendly 3D environmental physics VFX manager.
## Renders ballistic water droplets, concentric water ripples & wading wakes,
## fading beach wet-sand footprints & kicked sand grains, fluttering grass/sakura
## rustle flecks, and translucent wind-gust rings with zero per-step allocations.

const MAX_PARTICLES: int = 48
const MAX_RINGS: int = 16
const MAX_FOOTPRINTS: int = 18

const WATER_GRAVITY: float = -18.0
const SAND_GRAVITY: float = -16.5
const LEAF_GRAVITY: float = -4.2

const KIND_WATER: int = 0
const KIND_SAND: int = 1
const KIND_LEAF: int = 2

const FOOTPRINT_LIFETIME: float = 4.5

var _pools_ready: bool = false
var _is_mobile: bool = false
var _elapsed: float = 0.0
var _foot_side: float = 1.0

# Shared low-poly meshes (zero runtime mesh allocation)
var _droplet_mesh: SphereMesh
var _sand_mesh: BoxMesh
var _leaf_mesh: BoxMesh
var _ring_mesh: TorusMesh
var _footprint_mesh: CylinderMesh

# Ballistic particle pool (fixed size MAX_PARTICLES)
var _p_nodes: Array[MeshInstance3D] = []
var _p_mats: Array[StandardMaterial3D] = []
var _p_active: PackedByteArray = PackedByteArray()
var _p_kind: PackedByteArray = PackedByteArray()
var _p_vel: Array[Vector3] = []
var _p_rot_vel: Array[Vector3] = []
var _p_base_scale: Array[Vector3] = []
var _p_age: PackedFloat32Array = PackedFloat32Array()
var _p_life: PackedFloat32Array = PackedFloat32Array()
var _p_floor_y: PackedFloat32Array = PackedFloat32Array()
var _p_base_alpha: PackedFloat32Array = PackedFloat32Array()
var _p_phase: PackedFloat32Array = PackedFloat32Array()
var _p_cursor: int = 0

# Ripple / wake / wind-gust ring pool (fixed size MAX_RINGS)
var _r_nodes: Array[MeshInstance3D] = []
var _r_mats: Array[StandardMaterial3D] = []
var _r_active: PackedByteArray = PackedByteArray()
var _r_age: PackedFloat32Array = PackedFloat32Array()
var _r_life: PackedFloat32Array = PackedFloat32Array()
var _r_start_r: PackedFloat32Array = PackedFloat32Array()
var _r_end_r: PackedFloat32Array = PackedFloat32Array()
var _r_height_scale: PackedFloat32Array = PackedFloat32Array()
var _r_lift_vel: PackedFloat32Array = PackedFloat32Array()
var _r_base_alpha: PackedFloat32Array = PackedFloat32Array()
var _r_cursor: int = 0

# Wet-sand footprint decal pool (fixed size MAX_FOOTPRINTS)
var _f_nodes: Array[MeshInstance3D] = []
var _f_mats: Array[StandardMaterial3D] = []
var _f_active: PackedByteArray = PackedByteArray()
var _f_age: PackedFloat32Array = PackedFloat32Array()
var _f_life: PackedFloat32Array = PackedFloat32Array()
var _f_base_alpha: PackedFloat32Array = PackedFloat32Array()
var _f_cursor: int = 0


func _ready() -> void:
	_ensure_pools()


func _ensure_pools() -> void:
	if _pools_ready:
		return
	_pools_ready = true
	_is_mobile = UiStyle.is_mobile_device()

	# 1. Shared lightweight primitive meshes
	_droplet_mesh = SphereMesh.new()
	_droplet_mesh.radius = 0.085
	_droplet_mesh.height = 0.17
	_droplet_mesh.radial_segments = 6
	_droplet_mesh.rings = 4

	_sand_mesh = BoxMesh.new()
	_sand_mesh.size = Vector3(0.085, 0.085, 0.085)

	_leaf_mesh = BoxMesh.new()
	_leaf_mesh.size = Vector3(0.16, 0.022, 0.095)

	_ring_mesh = TorusMesh.new()
	_ring_mesh.inner_radius = 0.78
	_ring_mesh.outer_radius = 0.96
	_ring_mesh.rings = 22
	_ring_mesh.ring_segments = 5

	_footprint_mesh = CylinderMesh.new()
	_footprint_mesh.top_radius = 0.18
	_footprint_mesh.bottom_radius = 0.20
	_footprint_mesh.height = 0.014
	_footprint_mesh.radial_segments = 10
	_footprint_mesh.rings = 1

	# 2. Pre-allocate ballistic particle pool
	_p_active.resize(MAX_PARTICLES)
	_p_active.fill(0)
	_p_kind.resize(MAX_PARTICLES)
	_p_kind.fill(0)
	_p_age.resize(MAX_PARTICLES)
	_p_age.fill(0.0)
	_p_life.resize(MAX_PARTICLES)
	_p_life.fill(0.5)
	_p_floor_y.resize(MAX_PARTICLES)
	_p_floor_y.fill(-999.0)
	_p_base_alpha.resize(MAX_PARTICLES)
	_p_base_alpha.fill(0.9)
	_p_phase.resize(MAX_PARTICLES)
	_p_phase.fill(0.0)

	for i in range(MAX_PARTICLES):
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.albedo_color = Color(1.0, 1.0, 1.0, 0.0)

		var mi := MeshInstance3D.new()
		mi.mesh = _droplet_mesh
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visible = false
		add_child(mi)

		_p_nodes.append(mi)
		_p_mats.append(mat)
		_p_vel.append(Vector3.ZERO)
		_p_rot_vel.append(Vector3.ZERO)
		_p_base_scale.append(Vector3.ONE)

	# 3. Pre-allocate ripple / wake / wind-gust ring pool
	_r_active.resize(MAX_RINGS)
	_r_active.fill(0)
	_r_age.resize(MAX_RINGS)
	_r_age.fill(0.0)
	_r_life.resize(MAX_RINGS)
	_r_life.fill(0.5)
	_r_start_r.resize(MAX_RINGS)
	_r_start_r.fill(0.3)
	_r_end_r.resize(MAX_RINGS)
	_r_end_r.fill(1.8)
	_r_height_scale.resize(MAX_RINGS)
	_r_height_scale.fill(0.06)
	_r_lift_vel.resize(MAX_RINGS)
	_r_lift_vel.fill(0.0)
	_r_base_alpha.resize(MAX_RINGS)
	_r_base_alpha.fill(0.75)

	for i in range(MAX_RINGS):
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.albedo_color = Color(0.85, 0.96, 1.0, 0.0)

		var mi := MeshInstance3D.new()
		mi.mesh = _ring_mesh
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visible = false
		add_child(mi)

		_r_nodes.append(mi)
		_r_mats.append(mat)

	# 4. Pre-allocate sand footprint pool
	_f_active.resize(MAX_FOOTPRINTS)
	_f_active.fill(0)
	_f_age.resize(MAX_FOOTPRINTS)
	_f_age.fill(0.0)
	_f_life.resize(MAX_FOOTPRINTS)
	_f_life.fill(FOOTPRINT_LIFETIME)
	_f_base_alpha.resize(MAX_FOOTPRINTS)
	_f_base_alpha.fill(0.42)

	for i in range(MAX_FOOTPRINTS):
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_color = Color(0.31, 0.23, 0.13, 0.0)

		var mi := MeshInstance3D.new()
		mi.mesh = _footprint_mesh
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visible = false
		add_child(mi)

		_f_nodes.append(mi)
		_f_mats.append(mat)


func spawn_water_splash(pos: Vector3, intensity: float = 1.0) -> void:
	_ensure_pools()
	var clamped_int := clampf(intensity, 0.35, 2.4)
	var surf_pos := Vector3(pos.x, pos.y + 0.04, pos.z)

	# Concentric translucent white-cyan water ripple rings hugging pos.y + 0.04
	_alloc_ring(
		surf_pos,
		0.32 * clamped_int,
		(1.75 + 0.95 * clamped_int),
		0.52 + 0.14 * clamped_int,
		0.055,
		0.0,
		Color(0.86, 0.97, 1.0, 0.78)
	)
	if clamped_int >= 0.85:
		_alloc_ring(
			Vector3(pos.x, pos.y + 0.045, pos.z),
			0.18 * clamped_int,
			(1.10 + 0.65 * clamped_int),
			0.40 + 0.10 * clamped_int,
			0.05,
			0.0,
			Color(0.96, 0.99, 1.0, 0.70)
		)

	# Ballistic water droplet beads arcing upward & outward under -18.0 m/s^2 gravity
	var count := 6 if _is_mobile else 12
	for i in range(count):
		var angle := (TAU * float(i) / float(count)) + randf_range(-0.28, 0.28)
		var out_speed := randf_range(1.6, 3.8) * sqrt(clamped_int)
		var up_speed := randf_range(3.6, 6.4) * clampf(0.75 + clamped_int * 0.35, 0.7, 1.65)
		var vel := Vector3(cos(angle) * out_speed, up_speed, sin(angle) * out_speed)
		var bead_sc := randf_range(0.75, 1.35) * clampf(0.82 + clamped_int * 0.22, 0.75, 1.45)
		var col := Color(0.92, 0.98, 1.0, 0.88) if (i % 2 == 0) else Color(0.68, 0.92, 1.0, 0.82)
		var spawn_p := Vector3(
			pos.x + cos(angle) * randf_range(0.08, 0.32),
			pos.y + randf_range(0.06, 0.16),
			pos.z + sin(angle) * randf_range(0.08, 0.32)
		)
		_alloc_particle(
			KIND_WATER,
			_droplet_mesh,
			spawn_p,
			vel,
			Vector3.ZERO,
			Vector3(bead_sc, bead_sc * 1.25, bead_sc),
			randf_range(0.55, 0.88),
			pos.y - 0.02,
			col
		)


func spawn_water_wake_ring(pos: Vector3, scale_mult: float = 1.0) -> void:
	_ensure_pools()
	var sm := clampf(scale_mult, 0.4, 2.2)
	_alloc_ring(
		Vector3(pos.x, pos.y + 0.04, pos.z),
		0.34 * sm,
		1.55 * sm,
		0.62,
		0.045,
		0.0,
		Color(0.80, 0.95, 1.0, 0.62)
	)


func spawn_sand_step(pos: Vector3, move_dir: Vector3, is_sprint: bool = false) -> void:
	_ensure_pools()
	var flat_dir := Vector3(move_dir.x, 0.0, move_dir.z)
	if flat_dir.length_squared() < 0.0004:
		flat_dir = Vector3(0.0, 0.0, 1.0)
	else:
		flat_dir = flat_dir.normalized()

	var side_vec := Vector3(-flat_dir.z, 0.0, flat_dir.x)
	_foot_side = -_foot_side
	var foot_pos := Vector3(
		pos.x + side_vec.x * _foot_side * 0.18,
		pos.y + 0.03,
		pos.z + side_vec.z * _foot_side * 0.18
	)
	var yaw := atan2(flat_dir.x, flat_dir.z)
	_alloc_footprint(foot_pos, yaw, 0.44 if is_sprint else 0.36)

	# Kicked warm golden sand dust grains opposite move_dir with gravity arc
	var count := 3 if _is_mobile else 6
	var back_dir := -flat_dir
	var boost := 1.38 if is_sprint else 1.0
	for i in range(count):
		var spread := randf_range(-0.68, 0.68)
		var kick_dir := (back_dir.rotated(Vector3.UP, spread)).normalized()
		var horiz_v := randf_range(1.1, 2.45) * boost
		var up_v := randf_range(1.8, 3.4) * boost
		var vel := Vector3(kick_dir.x * horiz_v, up_v, kick_dir.z * horiz_v)
		var grain_sc := randf_range(0.65, 1.25) * (1.12 if is_sprint else 0.92)
		var tone := randf_range(-0.05, 0.06)
		var col := Color(
			clampf(0.87 + tone, 0.0, 1.0),
			clampf(0.73 + tone, 0.0, 1.0),
			clampf(0.49 + tone * 0.8, 0.0, 1.0),
			0.78
		)
		var spawn_p := Vector3(
			foot_pos.x + randf_range(-0.14, 0.14),
			pos.y + randf_range(0.05, 0.12),
			foot_pos.z + randf_range(-0.14, 0.14)
		)
		_alloc_particle(
			KIND_SAND,
			_sand_mesh,
			spawn_p,
			vel,
			Vector3(randf_range(-8.0, 8.0), randf_range(-8.0, 8.0), randf_range(-8.0, 8.0)),
			Vector3(grain_sc, grain_sc, grain_sc),
			randf_range(0.32, 0.54),
			pos.y - 0.02,
			col
		)


func spawn_grass_rustle(pos: Vector3, move_dir: Vector3, is_dash: bool = false) -> void:
	_ensure_pools()
	var flat_dir := Vector3(move_dir.x, 0.0, move_dir.z)
	if flat_dir.length_squared() < 0.0004:
		flat_dir = Vector3(1.0, 0.0, 0.0)
	else:
		flat_dir = flat_dir.normalized()

	var count := 3 if _is_mobile else 6
	var boost := 1.45 if is_dash else 1.0
	for i in range(count):
		var angle := randf() * TAU
		var radial := Vector3(cos(angle), 0.0, sin(angle))
		var drift := (-flat_dir * randf_range(0.6, 1.7) + radial * randf_range(0.8, 2.0)) * boost
		var up_v := randf_range(1.6, 3.3) * boost
		var vel := Vector3(drift.x, up_v, drift.z)

		# Mix emerald grass blades & sakura/wildflower petals
		var is_petal := (i % 3 == 2)
		var col: Color
		var sc: Vector3
		if is_petal:
			col = Color(0.99, 0.68, 0.78, 0.90) if (randf() > 0.25) else Color(0.99, 0.90, 0.52, 0.88)
			var ps := randf_range(0.80, 1.25)
			sc = Vector3(ps * 0.95, ps, ps * 1.15)
		else:
			col = Color(0.28, 0.82, 0.42, 0.90) if (i % 2 == 0) else Color(0.50, 0.92, 0.55, 0.88)
			var gs := randf_range(0.75, 1.25)
			sc = Vector3(gs * 1.35, gs, gs * 0.52)

		var spawn_p := Vector3(
			pos.x + randf_range(-0.32, 0.32),
			pos.y + randf_range(0.08, 0.26),
			pos.z + randf_range(-0.32, 0.32)
		)
		_alloc_particle(
			KIND_LEAF,
			_leaf_mesh,
			spawn_p,
			vel,
			Vector3(randf_range(-7.5, 7.5), randf_range(-6.5, 6.5), randf_range(-7.5, 7.5)),
			sc,
			randf_range(0.62, 1.05),
			pos.y + 0.01,
			col
		)


func spawn_wind_gust_ring(pos: Vector3, radius: float = 2.6) -> void:
	_ensure_pools()
	var end_r := clampf(radius, 0.8, 6.0)
	_alloc_ring(
		Vector3(pos.x, pos.y + 0.16, pos.z),
		0.42,
		end_r,
		0.34,
		0.09,
		0.75,
		Color(0.92, 0.97, 1.0, 0.58)
	)


func _alloc_particle(
	kind: int,
	mesh_res: Mesh,
	spawn_pos: Vector3,
	vel: Vector3,
	rot_vel: Vector3,
	base_scale: Vector3,
	life: float,
	floor_y: float,
	color: Color
) -> void:
	var idx := -1
	for k in range(MAX_PARTICLES):
		var slot := (_p_cursor + k) % MAX_PARTICLES
		if _p_active[slot] == 0:
			idx = slot
			break
	if idx < 0:
		idx = _p_cursor
	_p_cursor = (idx + 1) % MAX_PARTICLES

	_p_active[idx] = 1
	_p_kind[idx] = kind
	_p_vel[idx] = vel
	_p_rot_vel[idx] = rot_vel
	_p_base_scale[idx] = base_scale
	_p_age[idx] = 0.0
	_p_life[idx] = maxf(0.08, life)
	_p_floor_y[idx] = floor_y
	_p_base_alpha[idx] = color.a
	_p_phase[idx] = randf() * TAU

	var mi := _p_nodes[idx]
	mi.mesh = mesh_res
	mi.position = spawn_pos
	mi.rotation = Vector3(randf() * TAU, randf() * TAU, randf() * TAU)
	mi.scale = base_scale
	mi.visible = true

	var mat := _p_mats[idx]
	mat.albedo_color = color


func _alloc_ring(
	spawn_pos: Vector3,
	start_r: float,
	end_r: float,
	life: float,
	height_scale: float,
	lift_vel: float,
	color: Color
) -> void:
	var idx := -1
	for k in range(MAX_RINGS):
		var slot := (_r_cursor + k) % MAX_RINGS
		if _r_active[slot] == 0:
			idx = slot
			break
	if idx < 0:
		idx = _r_cursor
	_r_cursor = (idx + 1) % MAX_RINGS

	_r_active[idx] = 1
	_r_age[idx] = 0.0
	_r_life[idx] = maxf(0.08, life)
	_r_start_r[idx] = start_r
	_r_end_r[idx] = end_r
	_r_height_scale[idx] = height_scale
	_r_lift_vel[idx] = lift_vel
	_r_base_alpha[idx] = color.a

	var mi := _r_nodes[idx]
	mi.position = spawn_pos
	mi.scale = Vector3(start_r, height_scale, start_r)
	mi.visible = true

	var mat := _r_mats[idx]
	mat.albedo_color = color


func _alloc_footprint(spawn_pos: Vector3, yaw: float, alpha: float) -> void:
	var idx := -1
	for k in range(MAX_FOOTPRINTS):
		var slot := (_f_cursor + k) % MAX_FOOTPRINTS
		if _f_active[slot] == 0:
			idx = slot
			break
	if idx < 0:
		idx = _f_cursor
	_f_cursor = (idx + 1) % MAX_FOOTPRINTS

	_f_active[idx] = 1
	_f_age[idx] = 0.0
	_f_life[idx] = FOOTPRINT_LIFETIME
	_f_base_alpha[idx] = alpha

	var mi := _f_nodes[idx]
	mi.position = spawn_pos
	mi.rotation = Vector3(0.0, yaw, 0.0)
	mi.scale = Vector3(0.76, 1.0, 1.38)
	mi.visible = true

	var mat := _f_mats[idx]
	mat.albedo_color = Color(0.31, 0.23, 0.13, alpha)


func _process(delta: float) -> void:
	if not _pools_ready:
		return
	var dt := minf(0.05, delta)
	_elapsed += dt

	# 1. Update ballistic particles
	for i in range(MAX_PARTICLES):
		if _p_active[i] == 0:
			continue
		var age := _p_age[i] + dt
		var life := _p_life[i]
		if age >= life:
			_p_active[i] = 0
			_p_nodes[i].visible = false
			continue
		_p_age[i] = age
		var t := age / life
		var kind := _p_kind[i]
		var vel := _p_vel[i]
		var mi := _p_nodes[i]

		if kind == KIND_WATER:
			vel.y += WATER_GRAVITY * dt
			vel.x *= exp(-1.1 * dt)
			vel.z *= exp(-1.1 * dt)
			mi.position += vel * dt
			if mi.position.y <= _p_floor_y[i] and vel.y < 0.0:
				_p_active[i] = 0
				mi.visible = false
				continue
			var shrink := 1.0 - t * 0.42
			var stretch := clampf(1.0 + absf(vel.y) * 0.08, 0.95, 1.55)
			var bs := _p_base_scale[i]
			mi.scale = Vector3(bs.x * shrink, bs.y * shrink * stretch, bs.z * shrink)
			_p_mats[i].albedo_color.a = _p_base_alpha[i] * clampf((1.0 - t) * 1.4, 0.0, 1.0)
		elif kind == KIND_SAND:
			vel.y += SAND_GRAVITY * dt
			vel.x *= exp(-2.4 * dt)
			vel.z *= exp(-2.4 * dt)
			mi.position += vel * dt
			if mi.position.y <= _p_floor_y[i] and vel.y < 0.0:
				_p_active[i] = 0
				mi.visible = false
				continue
			mi.rotation += _p_rot_vel[i] * dt
			var sc_f := 1.0 - t * 0.55
			mi.scale = _p_base_scale[i] * sc_f
			_p_mats[i].albedo_color.a = _p_base_alpha[i] * (1.0 - t)
		else:
			# Grass flecks & sakura petals: gentle gravity, air drag, fluttering downwind drift
			vel.y += LEAF_GRAVITY * dt
			var drag := exp(-2.8 * dt)
			vel.x *= drag
			vel.z *= drag
			vel.y = maxf(vel.y, -1.35)
			var sway := sin(_elapsed * 7.5 + _p_phase[i]) * 0.75
			mi.position += Vector3(vel.x + sway * 0.35, vel.y, vel.z - sway * 0.25) * dt
			if mi.position.y < _p_floor_y[i]:
				mi.position.y = _p_floor_y[i]
				vel.x *= 0.85
				vel.z *= 0.85
				vel.y = 0.0
			mi.rotation += _p_rot_vel[i] * dt
			var fade := clampf((1.0 - t) * 1.65, 0.0, 1.0)
			_p_mats[i].albedo_color.a = _p_base_alpha[i] * fade

		_p_vel[i] = vel

	# 2. Update ripple / wake / wind-gust rings
	for i in range(MAX_RINGS):
		if _r_active[i] == 0:
			continue
		var age := _r_age[i] + dt
		var life := _r_life[i]
		if age >= life:
			_r_active[i] = 0
			_r_nodes[i].visible = false
			continue
		_r_age[i] = age
		var t := age / life
		var ease_out := 1.0 - pow(1.0 - t, 2.2)
		var r := lerpf(_r_start_r[i], _r_end_r[i], ease_out)
		var mi := _r_nodes[i]
		mi.scale = Vector3(r, _r_height_scale[i], r)
		var lift := _r_lift_vel[i]
		if lift != 0.0:
			mi.position.y += lift * dt
		_r_mats[i].albedo_color.a = _r_base_alpha[i] * (1.0 - t) * (1.0 - t * 0.35)

	# 3. Update wet-sand footprints
	for i in range(MAX_FOOTPRINTS):
		if _f_active[i] == 0:
			continue
		var age := _f_age[i] + dt
		var life := _f_life[i]
		if age >= life:
			_f_active[i] = 0
			_f_nodes[i].visible = false
			continue
		_f_age[i] = age
		var t := age / life
		# Hold gently for first 25% of lifetime, then fade smoothly to 0
		var fade := 1.0 if t < 0.25 else clampf(1.0 - (t - 0.25) / 0.75, 0.0, 1.0)
		_f_mats[i].albedo_color.a = _f_base_alpha[i] * fade
