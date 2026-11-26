class_name FoliagePhysicsField
extends Node3D

## Real-Time 2D Hooke's Law Spring-Damper Foliage Physics Field &
## Rolling High-Density Near-Player Meadow Grass Carpet (Godot 4.3, GL Compatibility / WebGL2).
##
## Simulates a world-locked 48x48m (1m/cell) damped harmonic oscillator grid around the player
## with zero per-frame allocations, encoding bend X/Z, persistent trample compression, and
## elastic kinetic oscillation energy into a 48x48 RGBA8 ImageTexture for GPU grass shaders.
## Optionally maintains a single-draw-call world-locked rolling MultiMesh grass carpet around
## the player with biome-varied tinting and smooth horizon fade.

const GRID_RES: int = 48
const FIELD_SIZE: float = 48.0
const CELL_SIZE: float = 1.0
const CELL_COUNT: int = GRID_RES * GRID_RES

const SPRING_STIFFNESS: float = 28.0
const SPRING_DAMPING: float = 5.4
const TRAMPLE_RECOVERY_RATE: float = 0.22
const PLAYER_BODY_RADIUS: float = 1.35
const ACTOR_MARGIN: float = 0.85
const ACTOR_MAX_HEIGHT_DIFF: float = 2.4
const MOBILE_STEP_DT: float = 1.0 / 30.0

const CARPET_ANCHOR_MOVE_THRESH: float = 1.8
const CARPET_INNER_FADE_R: float = 15.0
const CARPET_OUTER_R_MOB: float = 21.0
const CARPET_OUTER_R_DESK: float = 22.0
const CARPET_STEP_MOB: float = 1.22
const CARPET_STEP_DESK: float = 0.84
const CARPET_COUNT_MOB: int = 1200
const CARPET_COUNT_DESK: int = 2600

const HIDDEN_XFORM := Transform3D(
	Basis(Vector3.ZERO, Vector3.ZERO, Vector3.ZERO),
	Vector3(0.0, -999.0, 0.0)
)

# Pre-allocated 2D spring-damper buffers (size = 2304, zero per-frame allocations)
var _disp_x := PackedFloat32Array()
var _disp_z := PackedFloat32Array()
var _vel_x := PackedFloat32Array()
var _vel_z := PackedFloat32Array()
var _trample := PackedFloat32Array()

# Pre-allocated scratch buffers for in-place world-locked grid shifting
var _tmp_disp_x := PackedFloat32Array()
var _tmp_disp_z := PackedFloat32Array()
var _tmp_vel_x := PackedFloat32Array()
var _tmp_vel_z := PackedFloat32Array()
var _tmp_trample := PackedFloat32Array()

# Pre-allocated RGBA8 pixel buffer & GPU texture
var _bytes := PackedByteArray()
var _img: Image = null
var _tex: ImageTexture = null
var _buffers_ready: bool = false

# Simulation state
var _arena: Arena3D = null
var _is_mob: bool = false
var _origin := Vector2(-FIELD_SIZE * 0.5, -FIELD_SIZE * 0.5)
var _origin_initialized: bool = false
var _wind_time: float = 0.0
var _phys_accum: float = 0.0
var _first_step_done: bool = false
var _bound_mats: Array[ShaderMaterial] = []

# Rolling high-density near-player meadow carpet state
var _enable_rolling_carpet: bool = false
var _carpet_mm_inst: MultiMeshInstance3D = null
var _carpet_mm: MultiMesh = null
var _carpet_max_count: int = 0
var _carpet_step: float = CARPET_STEP_DESK
var _carpet_outer_r: float = CARPET_OUTER_R_DESK
var _last_carpet_anchor := Vector2(99999.0, 99999.0)
var _carpet_initialized: bool = false
var _prev_active_count: int = 0


func _ensure_buffers() -> void:
	if _buffers_ready:
		return
	_disp_x.resize(CELL_COUNT)
	_disp_z.resize(CELL_COUNT)
	_vel_x.resize(CELL_COUNT)
	_vel_z.resize(CELL_COUNT)
	_trample.resize(CELL_COUNT)
	_tmp_disp_x.resize(CELL_COUNT)
	_tmp_disp_z.resize(CELL_COUNT)
	_tmp_vel_x.resize(CELL_COUNT)
	_tmp_vel_z.resize(CELL_COUNT)
	_tmp_trample.resize(CELL_COUNT)
	_bytes.resize(CELL_COUNT * 4)
	_reset_buffers_neutral()
	_img = Image.create_from_data(GRID_RES, GRID_RES, false, Image.FORMAT_RGBA8, _bytes)
	_tex = ImageTexture.create_from_image(_img)
	_buffers_ready = true


func _reset_buffers_neutral() -> void:
	_disp_x.fill(0.0)
	_disp_z.fill(0.0)
	_vel_x.fill(0.0)
	_vel_z.fill(0.0)
	_trample.fill(0.0)
	_tmp_disp_x.fill(0.0)
	_tmp_disp_z.fill(0.0)
	_tmp_vel_x.fill(0.0)
	_tmp_vel_z.fill(0.0)
	_tmp_trample.fill(0.0)
	for i: int in range(CELL_COUNT):
		var bi: int = i * 4
		_bytes[bi] = 128
		_bytes[bi + 1] = 128
		_bytes[bi + 2] = 0
		_bytes[bi + 3] = 0


func setup(
	arena_ref: Arena3D,
	is_mob: bool,
	grass_material: ShaderMaterial,
	enable_rolling_carpet: bool = true
) -> void:
	_ensure_buffers()
	_reset_buffers_neutral()
	_img.set_data(GRID_RES, GRID_RES, false, Image.FORMAT_RGBA8, _bytes)
	_tex.update(_img)

	_arena = arena_ref
	_is_mob = is_mob
	_enable_rolling_carpet = enable_rolling_carpet
	_origin = Vector2(-FIELD_SIZE * 0.5, -FIELD_SIZE * 0.5)
	_origin_initialized = false
	_wind_time = 0.0
	_phys_accum = 0.0
	_first_step_done = false
	_bound_mats.clear()

	if is_instance_valid(_carpet_mm_inst):
		_carpet_mm_inst.queue_free()
	_carpet_mm_inst = null
	_carpet_mm = null
	_carpet_initialized = false
	_last_carpet_anchor = Vector2(99999.0, 99999.0)
	_prev_active_count = 0

	if grass_material != null:
		bind_material(grass_material)

	if _enable_rolling_carpet:
		_create_rolling_carpet(grass_material)


func _create_rolling_carpet(grass_material: ShaderMaterial) -> void:
	_carpet_max_count = CARPET_COUNT_MOB if _is_mob else CARPET_COUNT_DESK
	_carpet_step = CARPET_STEP_MOB if _is_mob else CARPET_STEP_DESK
	_carpet_outer_r = CARPET_OUTER_R_MOB if _is_mob else CARPET_OUTER_R_DESK

	var grass_mesh: ArrayMesh = ArpgNatureProps.make_grass_tuft_mesh(_is_mob)
	if grass_material != null and grass_mesh.get_surface_count() > 0:
		grass_mesh.surface_set_material(0, grass_material)

	_carpet_mm = MultiMesh.new()
	_carpet_mm.transform_format = MultiMesh.TRANSFORM_3D
	_carpet_mm.use_colors = true
	_carpet_mm.mesh = grass_mesh
	_carpet_mm.instance_count = _carpet_max_count

	for i: int in range(_carpet_max_count):
		_carpet_mm.set_instance_transform(i, HIDDEN_XFORM)
		_carpet_mm.set_instance_color(i, Color.WHITE)

	_carpet_mm_inst = MultiMeshInstance3D.new()
	_carpet_mm_inst.name = "RollingMeadowGrassCarpet"
	_carpet_mm_inst.multimesh = _carpet_mm
	_carpet_mm_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if grass_material != null:
		_carpet_mm_inst.material_override = grass_material
	_carpet_mm_inst.custom_aabb = AABB(
		Vector3(-_carpet_outer_r - 8.0, -24.0, -_carpet_outer_r - 8.0),
		Vector3((_carpet_outer_r + 8.0) * 2.0, 64.0, (_carpet_outer_r + 8.0) * 2.0)
	)
	add_child(_carpet_mm_inst)


func get_field_texture() -> ImageTexture:
	_ensure_buffers()
	return _tex


func get_field_origin() -> Vector2:
	return _origin


func get_field_size() -> float:
	return FIELD_SIZE


func bind_material(mat: ShaderMaterial) -> void:
	if mat == null:
		return
	_ensure_buffers()
	mat.set_shader_parameter("phys_field", _tex)
	mat.set_shader_parameter("phys_origin", _origin)
	mat.set_shader_parameter("phys_size", FIELD_SIZE)
	mat.set_shader_parameter("has_phys_field", true)
	if not _bound_mats.has(mat):
		_bound_mats.append(mat)


func _sync_bound_materials_origin() -> void:
	var write_idx: int = 0
	var count: int = _bound_mats.size()
	for i: int in range(count):
		var m: ShaderMaterial = _bound_mats[i]
		if is_instance_valid(m):
			m.set_shader_parameter("phys_origin", _origin)
			if write_idx != i:
				_bound_mats[write_idx] = m
			write_idx += 1
	if write_idx < count:
		_bound_mats.resize(write_idx)


func apply_impulse(
	world_pos: Vector3,
	radius: float = 4.5,
	strength: float = 1.4,
	trample_amt: float = 0.55
) -> void:
	if not _buffers_ready or radius <= 0.01:
		return

	var ox: float = _origin.x
	var oz: float = _origin.y
	var min_gx: int = maxi(0, int(floorf((world_pos.x - radius - ox) / CELL_SIZE)))
	var max_gx: int = mini(GRID_RES - 1, int(ceilf((world_pos.x + radius - ox) / CELL_SIZE)))
	var min_gz: int = maxi(0, int(floorf((world_pos.z - radius - oz) / CELL_SIZE)))
	var max_gz: int = mini(GRID_RES - 1, int(ceilf((world_pos.z + radius - oz) / CELL_SIZE)))
	if min_gx > max_gx or min_gz > max_gz:
		return

	var rad_sq: float = radius * radius
	var inv_rad: float = 1.0 / radius
	var vel_scale: float = strength * 8.4

	for gz: int in range(min_gz, max_gz + 1):
		var wz: float = oz + (float(gz) + 0.5) * CELL_SIZE
		var dz: float = wz - world_pos.z
		var dz_sq: float = dz * dz
		var row_off: int = gz * GRID_RES
		for gx: int in range(min_gx, max_gx + 1):
			var wx: float = ox + (float(gx) + 0.5) * CELL_SIZE
			var dx: float = wx - world_pos.x
			var d2: float = dx * dx + dz_sq
			if d2 >= rad_sq:
				continue

			var dist: float = sqrt(d2)
			var falloff: float = 1.0 - dist * inv_rad
			var f: float = falloff * (0.45 + 0.55 * falloff)
			var rx: float
			var rz: float
			if dist > 0.001:
				var inv_d: float = 1.0 / dist
				rx = dx * inv_d
				rz = dz * inv_d
			else:
				var ang: float = float((gx * 73 + gz * 137) & 255) * (TAU / 256.0)
				rx = cos(ang)
				rz = sin(ang)

			var idx: int = row_off + gx
			var imp: float = vel_scale * f
			_vel_x[idx] = clampf(_vel_x[idx] + rx * imp, -14.0, 14.0)
			_vel_z[idx] = clampf(_vel_z[idx] + rz * imp, -14.0, 14.0)
			if trample_amt > 0.0:
				var tr_add: float = trample_amt * falloff
				_trample[idx] = clampf(
					maxf(_trample[idx], tr_add) + tr_add * falloff * 0.25,
					0.0,
					1.0
				)


func step_physics(
	dt: float,
	center_pos: Vector3,
	player_vel: Vector3,
	wind_dir: Vector2,
	wind_strength: float,
	dynamic_actors: Array = []
) -> void:
	_ensure_buffers()

	# Rolling carpet updates lazily only when player moves >= 1.8m from last anchor
	if _enable_rolling_carpet and _carpet_mm != null:
		var adx: float = center_pos.x - _last_carpet_anchor.x
		var adz: float = center_pos.z - _last_carpet_anchor.y
		if (not _carpet_initialized) or (adx * adx + adz * adz >= CARPET_ANCHOR_MOVE_THRESH * CARPET_ANCHOR_MOVE_THRESH):
			_update_rolling_carpet(center_pos)

	# Mobile runs spring integration cleanly at 30Hz; desktop runs at full frame rate
	var sim_dt: float = dt
	if _is_mob and _first_step_done:
		_phys_accum += dt
		if _phys_accum < MOBILE_STEP_DT:
			return
		sim_dt = _phys_accum
		_phys_accum = 0.0
	_first_step_done = true
	sim_dt = clampf(sim_dt, 0.001, 0.05)

	# 1. Snap 48x48m grid origin to integer world coordinates and shift buffers world-locked
	var new_ox: float = floorf(center_pos.x) - FIELD_SIZE * 0.5
	var new_oz: float = floorf(center_pos.z) - FIELD_SIZE * 0.5
	if not _origin_initialized:
		_origin = Vector2(new_ox, new_oz)
		_origin_initialized = true
		_sync_bound_materials_origin()
	else:
		var shift_x: int = int(roundf((new_ox - _origin.x) / CELL_SIZE))
		var shift_z: int = int(roundf((new_oz - _origin.y) / CELL_SIZE))
		if shift_x != 0 or shift_z != 0:
			_shift_grid(shift_x, shift_z)
			_origin = Vector2(new_ox, new_oz)
			_sync_bound_materials_origin()

	# 2. Apply physical body parting, velocity wake drag, and trample for player & dynamic actors
	var wdir: Vector2 = wind_dir.normalized() if wind_dir.length_squared() > 0.0001 else Vector2(0.85, 0.52).normalized()
	_apply_actor_forces(center_pos, player_vel, PLAYER_BODY_RADIUS, sim_dt, wdir)

	var actor_count: int = dynamic_actors.size()
	for ai: int in range(actor_count):
		var a: Variant = dynamic_actors[ai]
		if not (a is Dictionary):
			continue
		var adict: Dictionary = a as Dictionary
		if not adict.has("pos"):
			continue
		var apos: Vector3 = adict["pos"]
		var avel: Vector3 = adict.get("vel", Vector3.ZERO)
		var arad: float = float(adict.get("radius", 1.15))
		_apply_actor_forces(apos, avel, arad, sim_dt, wdir)

	# 3. Integrate Hooke's law spring-damper + traveling wind gusts + trample recovery + pack RGBA8
	_wind_time += sim_dt
	var wdir_x: float = wdir.x
	var wdir_z: float = wdir.y
	var wperp_x: float = -wdir_z
	var wperp_z: float = wdir_x

	var ox: float = _origin.x
	var oz: float = _origin.y
	var w_step_x: float = wdir_x * 0.24
	var w_step_z: float = wdir_z * 0.24
	var c_step_x: float = wperp_x * 0.19
	var c_step_z: float = wperp_z * 0.19
	var w_time_off: float = _wind_time * (1.85 + wind_strength * 0.75)
	var c_time_off: float = _wind_time * 1.15
	var cross_time_off: float = _wind_time * 0.85
	var wind_amp: float = wind_strength * 3.8
	var cross_amp: float = wind_strength * 1.15
	var trample_decay: float = sim_dt * TRAMPLE_RECOVERY_RATE

	# Two substeps when sim_dt is large (> 33ms) keeps underdamped oscillation crisp & stable
	var substeps: int = 2 if sim_dt > 0.034 else 1
	var sub_dt: float = sim_dt / float(substeps)

	for gz: int in range(GRID_RES):
		var wz: float = oz + (float(gz) + 0.5) * CELL_SIZE
		var row_off: int = gz * GRID_RES
		var row_wph: float = (ox + 0.5) * w_step_x + wz * w_step_z - w_time_off
		var row_cph: float = (ox + 0.5) * c_step_x + wz * c_step_z - c_time_off

		for gx: int in range(GRID_RES):
			var idx: int = row_off + gx
			var ph: float = row_wph + float(gx) * w_step_x
			var cph: float = row_cph + float(gx) * c_step_x
			var gust: float = sin(ph) * 0.62 + sin(ph * 1.83 + cph) * 0.38
			var wf: float = (0.32 + 0.68 * gust) * wind_amp
			var cf: float = sin(cph * 1.35 - cross_time_off) * cross_amp
			var fx: float = wdir_x * wf + wperp_x * cf
			var fz: float = wdir_z * wf + wperp_z * cf

			var dx: float = _disp_x[idx]
			var dz: float = _disp_z[idx]
			var vx: float = _vel_x[idx]
			var vz: float = _vel_z[idx]

			for _s: int in range(substeps):
				vx += (-SPRING_STIFFNESS * dx - SPRING_DAMPING * vx + fx) * sub_dt
				vz += (-SPRING_STIFFNESS * dz - SPRING_DAMPING * vz + fz) * sub_dt
				vx = clampf(vx, -14.0, 14.0)
				vz = clampf(vz, -14.0, 14.0)
				dx = clampf(dx + vx * sub_dt, -1.0, 1.0)
				dz = clampf(dz + vz * sub_dt, -1.0, 1.0)

			_vel_x[idx] = vx
			_vel_z[idx] = vz
			_disp_x[idx] = dx
			_disp_z[idx] = dz

			var tr: float = _trample[idx]
			if tr > 0.0:
				tr = maxf(0.0, tr - trample_decay)
				_trample[idx] = tr

			# Encode RGBA8: R=bendX[-1,1], G=bendZ[-1,1], B=trample[0,1], A=kinetic energy
			var bi: int = idx * 4
			_bytes[bi] = int(clampf(dx * 0.5 + 0.5, 0.0, 1.0) * 255.0 + 0.5)
			_bytes[bi + 1] = int(clampf(dz * 0.5 + 0.5, 0.0, 1.0) * 255.0 + 0.5)
			_bytes[bi + 2] = int(clampf(tr, 0.0, 1.0) * 255.0 + 0.5)
			var energy: float = sqrt(vx * vx + vz * vz) * 0.25
			_bytes[bi + 3] = int(clampf(energy, 0.0, 1.0) * 255.0 + 0.5)

	_img.set_data(GRID_RES, GRID_RES, false, Image.FORMAT_RGBA8, _bytes)
	_tex.update(_img)


func _shift_grid(shift_x: int, shift_z: int) -> void:
	if absi(shift_x) >= GRID_RES or absi(shift_z) >= GRID_RES:
		_disp_x.fill(0.0)
		_disp_z.fill(0.0)
		_vel_x.fill(0.0)
		_vel_z.fill(0.0)
		_trample.fill(0.0)
		return

	for nz: int in range(GRID_RES):
		var oz_idx: int = nz + shift_z
		var dst_row: int = nz * GRID_RES
		if oz_idx < 0 or oz_idx >= GRID_RES:
			for nx: int in range(GRID_RES):
				var di: int = dst_row + nx
				_tmp_disp_x[di] = 0.0
				_tmp_disp_z[di] = 0.0
				_tmp_vel_x[di] = 0.0
				_tmp_vel_z[di] = 0.0
				_tmp_trample[di] = 0.0
		else:
			var src_row: int = oz_idx * GRID_RES
			for nx: int in range(GRID_RES):
				var ox_idx: int = nx + shift_x
				var di: int = dst_row + nx
				if ox_idx < 0 or ox_idx >= GRID_RES:
					_tmp_disp_x[di] = 0.0
					_tmp_disp_z[di] = 0.0
					_tmp_vel_x[di] = 0.0
					_tmp_vel_z[di] = 0.0
					_tmp_trample[di] = 0.0
				else:
					var si: int = src_row + ox_idx
					_tmp_disp_x[di] = _disp_x[si]
					_tmp_disp_z[di] = _disp_z[si]
					_tmp_vel_x[di] = _vel_x[si]
					_tmp_vel_z[di] = _vel_z[si]
					_tmp_trample[di] = _trample[si]

	# Swap scratch buffers in-place (zero allocation; local temps drop refcount back to 1 on return)
	var s0 := _disp_x; _disp_x = _tmp_disp_x; _tmp_disp_x = s0
	var s1 := _disp_z; _disp_z = _tmp_disp_z; _tmp_disp_z = s1
	var s2 := _vel_x; _vel_x = _tmp_vel_x; _tmp_vel_x = s2
	var s3 := _vel_z; _vel_z = _tmp_vel_z; _tmp_vel_z = s3
	var s4 := _trample; _trample = _tmp_trample; _tmp_trample = s4


func _apply_actor_forces(
	actor_pos: Vector3,
	actor_vel: Vector3,
	radius: float,
	sim_dt: float,
	fallback_dir: Vector2
) -> void:
	var eff_r: float = maxf(0.35, radius) + ACTOR_MARGIN
	var ox: float = _origin.x
	var oz: float = _origin.y

	# Quick AABB reject against the 48x48m grid
	if (
		actor_pos.x + eff_r < ox
		or actor_pos.x - eff_r > ox + FIELD_SIZE
		or actor_pos.z + eff_r < oz
		or actor_pos.z - eff_r > oz + FIELD_SIZE
	):
		return

	var terrain_y: float = _arena.get_base_terrain_height(actor_pos.x, actor_pos.z) if _arena != null else 0.0
	var dy: float = absf(actor_pos.y - terrain_y)
	if dy >= ACTOR_MAX_HEIGHT_DIFF:
		return

	var height_fade: float = clampf(1.0 - maxf(0.0, dy - 1.1) / (ACTOR_MAX_HEIGHT_DIFF - 1.1), 0.0, 1.0)
	var min_gx: int = maxi(0, int(floorf((actor_pos.x - eff_r - ox) / CELL_SIZE)))
	var max_gx: int = mini(GRID_RES - 1, int(ceilf((actor_pos.x + eff_r - ox) / CELL_SIZE)))
	var min_gz: int = maxi(0, int(floorf((actor_pos.z - eff_r - oz) / CELL_SIZE)))
	var max_gz: int = mini(GRID_RES - 1, int(ceilf((actor_pos.z + eff_r - oz) / CELL_SIZE)))
	if min_gx > max_gx or min_gz > max_gz:
		return

	var eff_r_sq: float = eff_r * eff_r
	var inv_eff_r: float = 1.0 / eff_r
	var avx: float = clampf(actor_vel.x, -12.0, 12.0)
	var avz: float = clampf(actor_vel.z, -12.0, 12.0)
	var speed: float = sqrt(avx * avx + avz * avz)
	var speed_boost: float = 1.0 + minf(speed * 0.14, 1.25)
	var move_dir_x: float = (avx / speed) if speed > 0.15 else fallback_dir.x
	var move_dir_z: float = (avz / speed) if speed > 0.15 else fallback_dir.y
	var push_base: float = 28.0 * speed_boost * height_fade * sim_dt
	var wake_scale: float = 2.6 * height_fade * sim_dt
	var trample_base: float = (0.72 + minf(speed * 0.07, 0.28)) * height_fade

	for gz: int in range(min_gz, max_gz + 1):
		var wz: float = oz + (float(gz) + 0.5) * CELL_SIZE
		var dz: float = wz - actor_pos.z
		var dz_sq: float = dz * dz
		var row_off: int = gz * GRID_RES
		for gx: int in range(min_gx, max_gx + 1):
			var wx: float = ox + (float(gx) + 0.5) * CELL_SIZE
			var dx: float = wx - actor_pos.x
			var d2: float = dx * dx + dz_sq
			if d2 >= eff_r_sq:
				continue

			var dist: float = sqrt(d2)
			var falloff: float = 1.0 - dist * inv_eff_r
			var weight: float = falloff * (0.45 + 0.55 * falloff)
			var rx: float
			var rz: float
			if dist > 0.001:
				var inv_d: float = 1.0 / dist
				rx = dx * inv_d
				rz = dz * inv_d
			else:
				rx = move_dir_x
				rz = move_dir_z

			var idx: int = row_off + gx
			_vel_x[idx] = clampf(_vel_x[idx] + (rx * push_base + avx * wake_scale) * weight, -14.0, 14.0)
			_vel_z[idx] = clampf(_vel_z[idx] + (rz * push_base + avz * wake_scale) * weight, -14.0, 14.0)

			var tr_target: float = clampf(falloff * trample_base, 0.0, 1.0)
			if tr_target > _trample[idx]:
				_trample[idx] = tr_target


static func _hash01(ix: int, iz: int, salt: int) -> float:
	var h: int = (ix * 374761393 + iz * 668265263 + salt * 1442695041) & 0x7FFFFFFF
	h = ((h ^ (h >> 13)) * 1274126177) & 0x7FFFFFFF
	h = (h ^ (h >> 16)) & 0x7FFFFFFF
	return float(h & 0xFFFF) * (1.0 / 65536.0)


func _update_rolling_carpet(center_pos: Vector3) -> void:
	if _carpet_mm == null or _arena == null:
		return

	_last_carpet_anchor = Vector2(center_pos.x, center_pos.z)
	_carpet_initialized = true

	var step: float = _carpet_step
	var jitter_span: float = 0.90 * step
	var outer_r: float = _carpet_outer_r
	var outer_r_sq: float = outer_r * outer_r
	var inv_fade_span: float = 1.0 / maxf(0.1, outer_r - CARPET_INNER_FADE_R)
	var cx_idx: int = int(floorf(center_pos.x / step))
	var cz_idx: int = int(floorf(center_pos.z / step))
	var r_cells: int = int(ceilf(outer_r / step))
	var max_inst: int = _carpet_max_count

	# Biome tint multipliers (applied onto vertex colors by MultiMesh use_colors)
	var col_meadow := Color(0.96, 1.06, 0.90, 1.0)
	var col_coastal_sage := Color(0.84, 0.98, 0.93, 1.0)
	var col_autumn_olive := Color(1.14, 0.98, 0.72, 1.0)

	var idx: int = 0
	for iz: int in range(cz_idx - r_cells, cz_idx + r_cells + 1):
		if idx >= max_inst:
			break
		var base_z: float = (float(iz) + 0.5) * step
		for ix: int in range(cx_idx - r_cells, cx_idx + r_cells + 1):
			if idx >= max_inst:
				break
			var jx: float = (_hash01(ix, iz, 1) - 0.5) * jitter_span
			var jz: float = (_hash01(ix, iz, 2) - 0.5) * jitter_span
			var wx: float = (float(ix) + 0.5) * step + jx
			var wz: float = base_z + jz

			var ddx: float = wx - center_pos.x
			var ddz: float = wz - center_pos.z
			var dist_sq: float = ddx * ddx + ddz * ddz
			if dist_sq >= outer_r_sq:
				continue

			if ArpgCh1Map._is_blocked_for_meadow(wx, wz):
				continue

			var gy: float = _arena.get_base_terrain_height(wx, wz)
			if gy < 0.14 or gy > 22.0:
				continue

			var w: Color = ArpgCh1Map.get_terrain_material_weights(wx, wz, gy)
			if w.r > 0.32 or w.b > 0.28 or w.a > 0.22:
				continue

			var nrm: Vector3 = _arena.get_terrain_normal(wx, wz)
			if nrm.y < 0.70:
				continue

			var dist: float = sqrt(dist_sq)
			var edge_fade: float = 1.0
			if dist > CARPET_INNER_FADE_R:
				var te: float = clampf((dist - CARPET_INNER_FADE_R) * inv_fade_span, 0.0, 1.0)
				edge_fade = 1.0 - te * te * (3.0 - 2.0 * te)
				if edge_fade < 0.04:
					continue

			var yaw: float = _hash01(ix, iz, 3) * TAU
			var sc_xz: float = lerpf(0.82, 1.45, _hash01(ix, iz, 4)) * (0.45 + 0.55 * edge_fade)
			var sc_y: float = lerpf(0.78, 1.38, _hash01(ix, iz, 5)) * edge_fade

			var up: Vector3 = Vector3.UP.lerp(nrm, 0.60).normalized()
			var ref_fwd := Vector3(sin(yaw), 0.0, cos(yaw))
			var right: Vector3 = up.cross(ref_fwd)
			if right.length_squared() < 0.0001:
				right = Vector3.RIGHT
			else:
				right = right.normalized()
			var fwd: Vector3 = right.cross(up).normalized()
			var b := Basis(right * sc_xz, up * sc_y, fwd * sc_xz)

			_carpet_mm.set_instance_transform(idx, Transform3D(b, Vector3(wx, gy - 0.03, wz)))

			# Biome-varied meadow palette + subtle macro patchiness + per-tuft hue jitter
			var tint: Color = col_meadow
			if wz > 58.0:
				var coast_t: float = clampf((wz - 58.0) * (1.0 / 22.0), 0.0, 1.0)
				tint = tint.lerp(col_coastal_sage, coast_t)
			var autumn_x: float = clampf((-20.0 - wx) * (1.0 / 20.0), 0.0, 1.0)
			var autumn_y: float = clampf((gy - 5.2) * (1.0 / 6.5), 0.0, 1.0)
			var autumn_t: float = maxf(autumn_x, autumn_y)
			if autumn_t > 0.001:
				tint = tint.lerp(col_autumn_olive, autumn_t * 0.85)

			var patch: float = sin(wx * 0.11 + wz * 0.08) * cos(wz * 0.09 - wx * 0.06) * 0.07
			var val_jit: float = lerpf(0.89, 1.11, _hash01(ix, iz, 6)) + patch
			var hue_jit: float = (_hash01(ix, iz, 7) - 0.5) * 0.12
			tint = Color(
				clampf((tint.r + hue_jit) * val_jit, 0.55, 1.35),
				clampf((tint.g + hue_jit * 0.25) * val_jit, 0.60, 1.35),
				clampf((tint.b - hue_jit * 0.85) * val_jit, 0.50, 1.30),
				1.0
			)
			_carpet_mm.set_instance_color(idx, tint)
			idx += 1

	# Zero-scale any unused slots that were previously active
	var clear_end: int = maxi(idx, _prev_active_count)
	for ci: int in range(idx, clear_end):
		_carpet_mm.set_instance_transform(ci, HIDDEN_XFORM)
	_prev_active_count = idx

	# Keep frustum culling AABB centered tightly on the rolling grass disk
	if is_instance_valid(_carpet_mm_inst):
		var pad: float = outer_r + 6.0
		_carpet_mm_inst.custom_aabb = AABB(
			Vector3(center_pos.x - pad, center_pos.y - 24.0, center_pos.z - pad),
			Vector3(pad * 2.0, 56.0, pad * 2.0)
		)
