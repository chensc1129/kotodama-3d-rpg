class_name LeafPhysicsSystem
extends Node3D

## High-craft 3D 6-DOF Aerodynamic Falling & Swirling Leaf/Petal Physics System
## for Godot 4.3 (GL Compatibility / WebGL2).
## Simulates 110 (mobile) / 220 (desktop) curved 3D leaves & petals in a SINGLE
## MultiMeshInstance3D (1 GPU draw call) with zero per-frame heap allocations.

const MOBILE_LEAF_COUNT: int = 110
const DESKTOP_LEAF_COUNT: int = 220

const STATE_AIRBORNE: int = 0
const STATE_GROUND: int = 1
const STATE_WATER: int = 2

const SPECIES_SAKURA: int = 0
const SPECIES_MAPLE: int = 1
const SPECIES_BROADLEAF: int = 2
const SPECIES_PINE: int = 3

const GRAVITY: float = -2.4
const SPAWN_RADIUS: float = 28.0
const RECYCLE_RADIUS_SQ: float = 31.0 * 31.0
const SLIPSTREAM_RADIUS: float = 4.2
const SLIPSTREAM_RADIUS_SQ: float = 4.2 * 4.2
const SLIPSTREAM_MIN_SPEED_SQ: float = 1.8 * 1.8
const FADE_OUT_WINDOW: float = 0.6

const SAKURA_COLORS: Array[Color] = [
	Color(0.99, 0.84, 0.91),
	Color(0.98, 0.72, 0.84),
	Color(1.00, 0.91, 0.95),
	Color(0.96, 0.56, 0.74),
]
const MAPLE_COLORS: Array[Color] = [
	Color(0.88, 0.18, 0.16),
	Color(0.95, 0.34, 0.15),
	Color(0.97, 0.55, 0.14),
	Color(0.96, 0.72, 0.16),
	Color(0.76, 0.14, 0.15),
]
const BROADLEAF_COLORS: Array[Color] = [
	Color(0.32, 0.80, 0.42),
	Color(0.22, 0.72, 0.34),
	Color(0.48, 0.78, 0.24),
	Color(0.58, 0.84, 0.28),
]
const PINE_COLORS: Array[Color] = [
	Color(0.14, 0.50, 0.24),
	Color(0.12, 0.42, 0.20),
	Color(0.24, 0.44, 0.16),
	Color(0.10, 0.36, 0.18),
]

var _arena: Arena3D = null
var _is_mobile: bool = false
var _stage_id: String = "arpg_ch1"
var _count: int = 0
var _elapsed: float = 0.0
var _has_synced_player: bool = false
var _shed_cursor: int = 0

var _mmi: MultiMeshInstance3D = null
var _mm: MultiMesh = null

# Flat zero-allocation per-leaf simulation buffers
var _pos: PackedVector3Array = PackedVector3Array()
var _vel: PackedVector3Array = PackedVector3Array()
var _rot: PackedVector3Array = PackedVector3Array()
var _ang_vel: PackedVector3Array = PackedVector3Array()
var _phase: PackedFloat32Array = PackedFloat32Array()
var _state: PackedByteArray = PackedByteArray()
var _rest_timer: PackedFloat32Array = PackedFloat32Array()
var _scale: PackedFloat32Array = PackedFloat32Array()
var _species: PackedByteArray = PackedByteArray()
var _flutter_freq: PackedFloat32Array = PackedFloat32Array()
var _terminal_vy: PackedFloat32Array = PackedFloat32Array()
var _water_y: PackedFloat32Array = PackedFloat32Array()

# Flat unpacked canopy registry + preallocated scratch buffer (zero per-frame allocs)
var _canopy_pos: PackedVector3Array = PackedVector3Array()
var _canopy_rad: PackedFloat32Array = PackedFloat32Array()
var _canopy_species: PackedByteArray = PackedByteArray()
var _canopy_count: int = 0
var _nearby_canopy_buf: PackedInt32Array = PackedInt32Array()


func setup(arena_ref: Arena3D, is_mob: bool, stage_id: String, canopy_spots: Array = []) -> void:
	_arena = arena_ref
	_is_mobile = is_mob
	_stage_id = stage_id
	_count = MOBILE_LEAF_COUNT if is_mob else DESKTOP_LEAF_COUNT
	_elapsed = 0.0
	_has_synced_player = false
	_shed_cursor = 0

	# Unpack canopy spots once into flat typed arrays
	var valid_spots: int = 0
	_canopy_pos.resize(canopy_spots.size())
	_canopy_rad.resize(canopy_spots.size())
	_canopy_species.resize(canopy_spots.size())
	for raw_spot: Variant in canopy_spots:
		if raw_spot is Dictionary:
			var spot: Dictionary = raw_spot as Dictionary
			var sp_pos: Variant = spot.get("pos", Vector3.ZERO)
			if sp_pos is Vector3:
				_canopy_pos[valid_spots] = sp_pos as Vector3
				_canopy_rad[valid_spots] = maxf(1.2, float(spot.get("radius", 3.2)))
				_canopy_species[valid_spots] = _parse_species(str(spot.get("species", "")))
				valid_spots += 1
	_canopy_count = valid_spots
	_canopy_pos.resize(_canopy_count)
	_canopy_rad.resize(_canopy_count)
	_canopy_species.resize(_canopy_count)
	_nearby_canopy_buf.resize(maxi(1, _canopy_count))

	# Allocate flat per-leaf simulation buffers
	_pos.resize(_count)
	_vel.resize(_count)
	_rot.resize(_count)
	_ang_vel.resize(_count)
	_phase.resize(_count)
	_state.resize(_count)
	_rest_timer.resize(_count)
	_scale.resize(_count)
	_species.resize(_count)
	_flutter_freq.resize(_count)
	_terminal_vy.resize(_count)
	_water_y.resize(_count)

	# Build or reuse the single MultiMeshInstance3D (1 GPU draw call)
	if _mmi == null or not is_instance_valid(_mmi):
		_mm = MultiMesh.new()
		_mm.transform_format = MultiMesh.TRANSFORM_3D
		_mm.use_colors = true
		_mm.mesh = _build_curved_leaf_mesh()

		_mmi = MultiMeshInstance3D.new()
		_mmi.name = "LeafPhysicsMultiMesh"
		_mmi.multimesh = _mm
		_mmi.material_override = _build_leaf_material()
		_mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# Generous world-space AABB so frustum culling never clips leaves as player roams
		_mmi.custom_aabb = AABB(Vector3(-320.0, -40.0, -320.0), Vector3(640.0, 140.0, 640.0))
		add_child(_mmi)

	_mm.instance_count = _count

	# Initial population centered near origin (re-synced automatically on first step_physics)
	_seed_around_origin(Vector3.ZERO)


func step_physics(
	dt: float,
	player_pos: Vector3,
	player_vel: Vector3,
	wind_dir: Vector2,
	wind_strength: float
) -> void:
	if _count <= 0 or _mm == null or dt <= 0.0:
		return

	var step_dt: float = minf(dt, 0.05)
	_elapsed += step_dt

	# On the first physics tick, re-seed leaves around the player's actual spawn point
	# so the player immediately starts amidst drifting leaves and fallen ground litter.
	if not _has_synced_player:
		_has_synced_player = true
		if player_pos.length_squared() > 16.0:
			_seed_around_origin(player_pos)

	var wd: Vector2 = wind_dir.normalized() if wind_dir.length_squared() > 0.0001 else Vector2(0.85, 0.52)
	var ws: float = maxf(0.0, wind_strength)

	var p_speed_sq: float = player_vel.length_squared()
	var p_moving: bool = p_speed_sq > SLIPSTREAM_MIN_SPEED_SQ
	var p_speed: float = sqrt(p_speed_sq) if p_moving else 0.0
	var p_vel_dir: Vector3 = (player_vel / p_speed) if p_speed > 0.001 else Vector3.ZERO
	var p_speed_f: float = clampf((p_speed - 1.4) * 0.25, 0.28, 2.4) if p_moving else 0.0
	var p_vortex_center := Vector3(player_pos.x, player_pos.y + 0.55, player_pos.z)

	for i: int in range(_count):
		var p: Vector3 = _pos[i]
		var dx_pl: float = p.x - player_pos.x
		var dz_pl: float = p.z - player_pos.z
		if (dx_pl * dx_pl + dz_pl * dz_pl) > RECYCLE_RADIUS_SQ or p.y < -35.0:
			_respawn_leaf(i, player_pos, false)
			_write_instance_transform(i)
			continue

		var st: int = _state[i]
		var v: Vector3 = _vel[i]
		var r: Vector3 = _rot[i]
		var av: Vector3 = _ang_vel[i]
		var ph: float = _phase[i]

		# 1. Real-Time Player Slipstream & Helical Vortex Pickup (airborne OR resting on ground!)
		if p_moving and st != STATE_WATER:
			var dp: Vector3 = p - p_vortex_center
			var d_sq: float = dp.length_squared()
			if d_sq < SLIPSTREAM_RADIUS_SQ:
				var dist: float = sqrt(d_sq)
				var falloff: float = 1.0 - (dist / SLIPSTREAM_RADIUS)
				var strength_f: float = falloff * (0.45 + 0.55 * falloff) * p_speed_f

				if st == STATE_GROUND:
					# Physically lift fallen ground leaves into the trailing vortex!
					st = STATE_AIRBORNE
					_state[i] = STATE_AIRBORNE
					p.y += 0.09
					v.y = maxf(v.y, 1.35 + 2.1 * strength_f)
					av += Vector3(
						sin(ph * 1.7 + float(i)) * 6.5,
						cos(ph * 1.3 + float(i)) * 7.8,
						sin(ph * 2.1 - float(i)) * 6.2
					) * (0.55 + 0.65 * strength_f)

				var rad_xz := Vector3(dp.x, 0.0, dp.z)
				var rad_len: float = rad_xz.length()
				var rad_n: Vector3 = (rad_xz / rad_len) if rad_len > 0.05 else Vector3(cos(ph), 0.0, sin(ph))
				var swirl_sign: float = 1.0 if (i & 1) == 0 else -1.0
				var tang := Vector3(-rad_n.z * swirl_sign, 0.0, rad_n.x * swirl_sign)

				# Helical slipstream: tangential swirl + upward vortex lift + trailing wake pull
				var vortex_acc: Vector3 = (
					tang * (6.2 * strength_f)
					+ Vector3.UP * (5.2 * strength_f)
					+ p_vel_dir * (4.1 * strength_f)
					+ rad_n * (1.4 * strength_f)
				)
				v += vortex_acc * step_dt
				av += Vector3(
					tang.z * 8.5,
					swirl_sign * 10.5,
					-tang.x * 8.5
				) * (strength_f * step_dt)

		# 2. Per-state physics integration
		if st == STATE_AIRBORNE:
			var speed_mod: float = clampf(v.length() * 0.16, 0.0, 1.2)
			ph += (_flutter_freq[i] * (0.88 + 0.24 * ws + speed_mod)) * step_dt
			var flutter_s: float = sin(ph)
			var flutter_c: float = cos(ph)

			# Spatial curl-like turbulent wind advection + vertical gust updrafts
			var gust_wave: float = (
				sin(p.x * 0.16 + p.z * 0.13 - _elapsed * 1.48) * 0.62
				+ cos(p.x * 0.09 - p.z * 0.19 - _elapsed * 0.86) * 0.38
			)
			var swirl_x: float = sin(p.z * 0.26 + p.y * 0.34 + _elapsed * 1.18)
			var swirl_z: float = cos(p.x * 0.26 - p.y * 0.30 + _elapsed * 1.06)
			var updraft: float = (
				sin(p.x * 0.21 - p.z * 0.18 - _elapsed * 1.38) * 0.64
				+ cos((p.x + p.z) * 0.14 - _elapsed * 0.74) * 0.36
			) * (0.36 + 0.88 * ws)
			if ws > 1.05:
				updraft += (ws - 1.0) * 0.85 * maxf(0.0, gust_wave + 0.32)

			var wind_mag: float = (0.78 + 1.58 * ws) * (0.74 + 0.46 * gust_wave)
			var turb_mag: float = 0.42 + 0.56 * ws
			var air_vel := Vector3(
				wd.x * wind_mag + swirl_x * turb_mag,
				updraft,
				wd.y * wind_mag + swirl_z * turb_mag
			)

			# Angle-of-attack aerodynamic drag & lift from current 3D leaf orientation
			var leaf_up: Vector3 = Basis.from_euler(r).y
			var v_rel: Vector3 = v - air_vel
			var v_normal: float = v_rel.dot(leaf_up)
			var aero_drag: Vector3 = -leaf_up * (v_normal * 4.4) - v_rel * 1.18

			# Coupled side-to-side falling leaf glide oscillation
			var glide_dir := Vector3(cos(r.y), 0.0, sin(r.y))
			var glide_force: Vector3 = glide_dir * (flutter_s * 1.55) + Vector3.UP * (absf(flutter_c) * 0.48)

			var acc := Vector3(
				aero_drag.x + glide_force.x,
				GRAVITY + aero_drag.y + glide_force.y,
				aero_drag.z + glide_force.z
			)
			v += acc * step_dt

			# Enforce realistic slow aerodynamic terminal descent (-0.65 .. -1.25 m/s)
			var term_vy: float = _terminal_vy[i]
			if v.y < term_vy:
				v.y = lerpf(v.y, term_vy, minf(1.0, step_dt * 6.5))

			var v_len_sq: float = v.length_squared()
			if v_len_sq > 196.0:
				v *= 14.0 / sqrt(v_len_sq)

			p += v * step_dt

			# 6-DOF rotational flutter coupled with aerodynamic damping
			var ang_damp: float = maxf(0.0, 1.0 - 2.3 * step_dt)
			av *= ang_damp
			var target_pitch: float = flutter_s * 0.54
			var target_roll: float = flutter_c * 0.66
			av.x += (target_pitch - sin(r.x)) * 4.3 * step_dt
			av.z += (target_roll - sin(r.z)) * 3.9 * step_dt
			av.y += (flutter_c * 1.05 + ws * 0.55) * step_dt
			r += av * step_dt

			# Landing detection against terrain & water
			if v.y <= 0.05 and _arena != null:
				var ground_y: float = _arena.get_ground_height(p.x, p.z, p.y + 0.5)
				var wl: float = _arena.get_water_level(p.x, p.z)
				if wl > ground_y + 0.04:
					if p.y <= wl + 0.025:
						st = STATE_WATER
						p.y = wl + 0.016
						_water_y[i] = wl
						v = Vector3(wd.x * 0.24, 0.0, wd.y * 0.24)
						r.x = 0.0
						r.z = 0.0
						av = Vector3(0.0, randf_range(-0.48, 0.48), 0.0)
						_rest_timer[i] = randf_range(4.0, 7.0)
				elif p.y <= ground_y + 0.028:
					st = STATE_GROUND
					p.y = ground_y + 0.022
					# Sample local terrain slope once on landing to align leaf flat to ground
					var gx: float = _arena.get_ground_height(p.x + 0.35, p.z, p.y + 0.5)
					var gz: float = _arena.get_ground_height(p.x, p.z + 0.35, p.y + 0.5)
					var slope_n := Vector3(ground_y - gx, 0.35, ground_y - gz).normalized()
					r = _align_euler_to_normal(slope_n, r.y)
					v = Vector3.ZERO
					av = Vector3.ZERO
					_rest_timer[i] = randf_range(4.0, 8.0)

			_pos[i] = p
			_vel[i] = v
			_rot[i] = r
			_ang_vel[i] = av
			_phase[i] = ph
			_state[i] = st

		elif st == STATE_GROUND:
			var rem: float = _rest_timer[i] - step_dt
			_rest_timer[i] = rem
			if rem <= 0.0:
				_respawn_leaf(i, player_pos, false)
			else:
				# Strong gusts subtly rustle resting leaves on the ground
				if ws > 1.45:
					ph += 4.2 * step_dt
					r.z += sin(ph) * 0.025 * step_dt
					_phase[i] = ph
					_rot[i] = r

		else: # STATE_WATER
			var rem_w: float = _rest_timer[i] - step_dt
			_rest_timer[i] = rem_w
			if rem_w <= 0.0:
				_respawn_leaf(i, player_pos, false)
			else:
				ph += 2.3 * step_dt
				var drift_spd: float = 0.22 + 0.28 * ws
				p.x += (wd.x * drift_spd + sin(ph * 0.65) * 0.07) * step_dt
				p.z += (wd.y * drift_spd + cos(ph * 0.58) * 0.07) * step_dt
				p.y = _water_y[i] + 0.016 + sin(ph) * 0.014
				r.x = sin(ph * 0.85) * 0.09
				r.z = cos(ph * 1.05) * 0.09
				r.y += av.y * step_dt
				_pos[i] = p
				_rot[i] = r
				_phase[i] = ph

		_write_instance_transform(i)


func apply_vortex_impulse(
	world_pos: Vector3,
	radius: float = 6.5,
	strength: float = 1.4,
	shed_count: int = 10
) -> void:
	if _count <= 0 or _mm == null:
		return

	var eff_rad: float = maxf(0.5, radius)
	var r_sq: float = eff_rad * eff_rad

	# 1. Blast all nearby airborne & resting leaves outward & upward with swirling spin
	for i: int in range(_count):
		var p: Vector3 = _pos[i]
		var dp: Vector3 = p - world_pos
		var d_sq: float = dp.length_squared()
		if d_sq < r_sq:
			var dist: float = sqrt(d_sq)
			var falloff: float = 1.0 - (dist / eff_rad)
			var imp: float = (0.35 + 0.65 * falloff) * strength
			if _state[i] != STATE_AIRBORNE:
				_state[i] = STATE_AIRBORNE
				p.y += 0.10
				_pos[i] = p

			var out_xz := Vector3(dp.x, 0.0, dp.z)
			var out_n: Vector3 = out_xz.normalized() if out_xz.length_squared() > 0.002 else Vector3(cos(_phase[i]), 0.0, sin(_phase[i]))
			var tang := Vector3(-out_n.z, 0.0, out_n.x)

			_vel[i] += (
				out_n * (3.4 * imp)
				+ tang * (4.6 * imp)
				+ Vector3.UP * ((2.6 + 2.6 * falloff) * imp)
			)
			_ang_vel[i] += Vector3(
				randf_range(-8.0, 8.0),
				randf_range(-10.0, 10.0),
				randf_range(-8.0, 8.0)
			) * imp

	# 2. Canopy Shake Shedding: detach fresh leaves directly from tree crowns near world_pos
	if shed_count <= 0 or _canopy_count <= 0:
		return

	var canopy_reach: float = eff_rad + 7.5
	var canopy_reach_sq: float = canopy_reach * canopy_reach
	var match_count: int = 0
	for ci: int in range(_canopy_count):
		var cp: Vector3 = _canopy_pos[ci]
		var dx: float = cp.x - world_pos.x
		var dz: float = cp.z - world_pos.z
		if (dx * dx + dz * dz) <= canopy_reach_sq:
			_nearby_canopy_buf[match_count] = ci
			match_count += 1

	if match_count <= 0:
		return

	var to_shed: int = mini(shed_count, _count)
	var shed_done: int = 0
	# Pass A: prefer recycling resting ground/water leaves first
	for attempt: int in range(_count):
		if shed_done >= to_shed:
			break
		var idx: int = (_shed_cursor + attempt) % _count
		if _state[idx] != STATE_AIRBORNE:
			var spot_i: int = _nearby_canopy_buf[shed_done % match_count]
			_detach_from_canopy(idx, spot_i, world_pos, strength)
			shed_done += 1
	# Pass B: if fewer resting leaves than shed_count, recycle airborne leaves via cursor
	while shed_done < to_shed:
		var idx: int = _shed_cursor % _count
		_shed_cursor = (_shed_cursor + 1) % _count
		var spot_i: int = _nearby_canopy_buf[shed_done % match_count]
		_detach_from_canopy(idx, spot_i, world_pos, strength)
		shed_done += 1
	_shed_cursor = (_shed_cursor + to_shed) % _count


func _detach_from_canopy(leaf_idx: int, canopy_idx: int, shock_origin: Vector3, strength: float) -> void:
	var c_pos: Vector3 = _canopy_pos[canopy_idx]
	var c_rad: float = _canopy_rad[canopy_idx]
	var sp: int = _canopy_species[canopy_idx]

	var az: float = randf() * TAU
	var r_frac: float = sqrt(randf()) * c_rad * 0.92
	var y_off: float = randf_range(-c_rad * 0.42, c_rad * 0.48)
	var spawn_p := Vector3(c_pos.x + cos(az) * r_frac, c_pos.y + y_off, c_pos.z + sin(az) * r_frac)

	var out_xz := Vector3(spawn_p.x - shock_origin.x, 0.0, spawn_p.z - shock_origin.z)
	var out_n: Vector3 = out_xz.normalized() if out_xz.length_squared() > 0.01 else Vector3(cos(az), 0.0, sin(az))
	var tang := Vector3(-out_n.z, 0.0, out_n.x)

	_species[leaf_idx] = sp
	_state[leaf_idx] = STATE_AIRBORNE
	_pos[leaf_idx] = spawn_p
	_vel[leaf_idx] = (
		out_n * (randf_range(1.4, 3.2) * strength)
		+ tang * (randf_range(-2.6, 2.6) * strength)
		+ Vector3.UP * (randf_range(-0.4, 1.5) * strength)
	)
	_rot[leaf_idx] = Vector3(randf() * TAU, randf() * TAU, randf() * TAU)
	_ang_vel[leaf_idx] = Vector3(
		randf_range(-7.5, 7.5),
		randf_range(-9.5, 9.5),
		randf_range(-7.5, 7.5)
	) * clampf(strength, 0.7, 2.2)
	_phase[leaf_idx] = randf() * TAU
	_rest_timer[leaf_idx] = 0.0
	_configure_species_traits(leaf_idx, sp)
	_write_instance_transform(leaf_idx)


func _seed_around_origin(origin_pos: Vector3) -> void:
	for i: int in range(_count):
		_respawn_leaf(i, origin_pos, true)
		# Start ~22% of leaves already resting naturally on ground/water for immediate visual richness
		if (i % 9) < 2 and _arena != null:
			var p: Vector3 = _pos[i]
			var gy: float = _arena.get_ground_height(p.x, p.z, p.y + 4.0)
			var wl: float = _arena.get_water_level(p.x, p.z)
			if wl > gy + 0.04:
				_state[i] = STATE_WATER
				_water_y[i] = wl
				_pos[i] = Vector3(p.x, wl + 0.016, p.z)
				_rot[i] = Vector3(0.0, randf() * TAU, 0.0)
				_vel[i] = Vector3.ZERO
				_ang_vel[i] = Vector3(0.0, randf_range(-0.4, 0.4), 0.0)
				_rest_timer[i] = randf_range(1.2, 6.5)
			else:
				_state[i] = STATE_GROUND
				_pos[i] = Vector3(p.x, gy + 0.022, p.z)
				var gx: float = _arena.get_ground_height(p.x + 0.35, p.z, gy + 0.5)
				var gz: float = _arena.get_ground_height(p.x, p.z + 0.35, gy + 0.5)
				var slope_n := Vector3(gy - gx, 0.35, gy - gz).normalized()
				_rot[i] = _align_euler_to_normal(slope_n, randf() * TAU)
				_vel[i] = Vector3.ZERO
				_ang_vel[i] = Vector3.ZERO
				_rest_timer[i] = randf_range(1.2, 7.5)
		_write_instance_transform(i)


func _respawn_leaf(idx: int, around_pos: Vector3, initial_stagger: bool) -> void:
	var match_count: int = 0
	var r_sq: float = SPAWN_RADIUS * SPAWN_RADIUS
	for ci: int in range(_canopy_count):
		var cp: Vector3 = _canopy_pos[ci]
		var dx: float = cp.x - around_pos.x
		var dz: float = cp.z - around_pos.z
		if (dx * dx + dz * dz) <= r_sq:
			_nearby_canopy_buf[match_count] = ci
			match_count += 1

	var spawn_p: Vector3
	var sp: int
	if match_count > 0 and randf() < 0.76:
		var spot_i: int = _nearby_canopy_buf[randi() % match_count]
		var c_pos: Vector3 = _canopy_pos[spot_i]
		var c_rad: float = _canopy_rad[spot_i]
		sp = _canopy_species[spot_i]
		var az: float = randf() * TAU
		var rr: float = sqrt(randf()) * c_rad
		var sx: float = c_pos.x + cos(az) * rr
		var sz: float = c_pos.z + sin(az) * rr
		var sy: float = c_pos.y + randf_range(-c_rad * 0.38, c_rad * 0.45)
		if initial_stagger:
			var gy: float = _arena.get_ground_height(sx, sz, sy + 2.0) if _arena != null else around_pos.y
			sy = lerpf(gy + 0.75, maxf(gy + 1.5, sy), randf())
		spawn_p = Vector3(sx, sy, sz)
	else:
		sp = _pick_stage_ambient_species()
		var az: float = randf() * TAU
		var rr: float = sqrt(randf()) * (SPAWN_RADIUS - 1.0)
		var sx: float = around_pos.x + cos(az) * rr
		var sz: float = around_pos.z + sin(az) * rr
		var gy: float = _arena.get_ground_height(sx, sz, around_pos.y + 12.0) if _arena != null else around_pos.y
		var sy: float = gy + (randf_range(0.8, 10.5) if initial_stagger else randf_range(4.5, 10.5))
		spawn_p = Vector3(sx, sy, sz)

	_species[idx] = sp
	_state[idx] = STATE_AIRBORNE
	_pos[idx] = spawn_p
	_vel[idx] = Vector3(randf_range(-0.6, 0.6), randf_range(-0.85, -0.25), randf_range(-0.6, 0.6))
	_rot[idx] = Vector3(randf_range(-0.8, 0.8), randf() * TAU, randf_range(-0.8, 0.8))
	_ang_vel[idx] = Vector3(randf_range(-1.8, 1.8), randf_range(-2.2, 2.2), randf_range(-1.8, 1.8))
	_phase[idx] = randf() * TAU
	_rest_timer[idx] = 0.0
	_water_y[idx] = -99.0
	_configure_species_traits(idx, sp)


func _configure_species_traits(idx: int, sp: int) -> void:
	if sp == SPECIES_SAKURA:
		_scale[idx] = randf_range(0.76, 1.12)
		_terminal_vy[idx] = randf_range(-0.92, -0.65)
		_flutter_freq[idx] = randf_range(3.0, 4.5)
	elif sp == SPECIES_MAPLE:
		_scale[idx] = randf_range(0.95, 1.35)
		_terminal_vy[idx] = randf_range(-1.12, -0.78)
		_flutter_freq[idx] = randf_range(2.6, 3.9)
	elif sp == SPECIES_PINE:
		_scale[idx] = randf_range(0.85, 1.18)
		_terminal_vy[idx] = randf_range(-1.25, -0.95)
		_flutter_freq[idx] = randf_range(2.2, 3.4)
	else: # SPECIES_BROADLEAF
		_scale[idx] = randf_range(0.88, 1.24)
		_terminal_vy[idx] = randf_range(-1.14, -0.80)
		_flutter_freq[idx] = randf_range(2.5, 3.8)
	_mm.set_instance_color(idx, _pick_species_color(sp))


func _write_instance_transform(idx: int) -> void:
	var sc: float = _scale[idx]
	var st: int = _state[idx]
	if st != STATE_AIRBORNE and _rest_timer[idx] < FADE_OUT_WINDOW:
		sc *= clampf(_rest_timer[idx] / FADE_OUT_WINDOW, 0.0, 1.0)

	var sp: int = _species[idx]
	var sx: float = sc
	var sz: float = sc
	if sp == SPECIES_SAKURA:
		sx = sc * 1.08
		sz = sc * 0.90
	elif sp == SPECIES_MAPLE:
		sx = sc * 1.20
		sz = sc * 1.06
	elif sp == SPECIES_PINE:
		sx = sc * 0.40
		sz = sc * 1.26

	var b: Basis = Basis.from_euler(_rot[idx])
	var scaled_b := Basis(b.x * sx, b.y * sc, b.z * sz)
	_mm.set_instance_transform(idx, Transform3D(scaled_b, _pos[idx]))


func _align_euler_to_normal(nrm: Vector3, yaw: float) -> Vector3:
	var up_n: Vector3 = nrm.normalized()
	if up_n.length_squared() < 0.001:
		up_n = Vector3.UP
	var raw_fwd := Vector3(sin(yaw), 0.0, cos(yaw))
	var fwd: Vector3 = raw_fwd - up_n * raw_fwd.dot(up_n)
	if fwd.length_squared() < 0.001:
		fwd = Vector3.RIGHT.cross(up_n)
	fwd = fwd.normalized()
	var right: Vector3 = up_n.cross(fwd).normalized()
	var aligned := Basis(right, up_n, fwd)
	var e: Vector3 = aligned.get_euler()
	return Vector3(e.x + randf_range(-0.12, 0.12), e.y, e.z + randf_range(-0.12, 0.12))


func _parse_species(species_name: String) -> int:
	match species_name.to_lower():
		"sakura":
			return SPECIES_SAKURA
		"maple":
			return SPECIES_MAPLE
		"broadleaf":
			return SPECIES_BROADLEAF
		"pine":
			return SPECIES_PINE
		_:
			return _pick_stage_ambient_species()


func _pick_stage_ambient_species() -> int:
	if _stage_id == "sakura_shrine":
		return SPECIES_SAKURA
	if _stage_id == "maple_temple":
		return SPECIES_MAPLE
	var roll: float = randf()
	if roll < 0.44:
		return SPECIES_SAKURA
	if roll < 0.74:
		return SPECIES_MAPLE
	return SPECIES_BROADLEAF


func _pick_species_color(sp: int) -> Color:
	match sp:
		SPECIES_SAKURA:
			return SAKURA_COLORS[randi() % SAKURA_COLORS.size()]
		SPECIES_MAPLE:
			return MAPLE_COLORS[randi() % MAPLE_COLORS.size()]
		SPECIES_PINE:
			return PINE_COLORS[randi() % PINE_COLORS.size()]
		_:
			return BROADLEAF_COLORS[randi() % BROADLEAF_COLORS.size()]


static func _build_curved_leaf_mesh() -> ArrayMesh:
	## Lightweight 6-triangle curved 3D leaf/petal mesh: tapered ovoid/diamond
	## silhouette with organic V-cup & longitudinal midrib arch so leaves catch
	## directional sunlight glints realistically as they tumble in 6-DOF flight.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var v0 := Vector3(0.0, -0.010, -0.105)      # Stem base
	var v1 := Vector3(-0.058, 0.017, -0.022)    # Lower-left cupped margin
	var v2 := Vector3(0.0, 0.005, -0.004)       # Recessed cupped midrib center
	var v3 := Vector3(0.058, 0.017, -0.022)     # Lower-right cupped margin
	var v4 := Vector3(-0.044, 0.014, 0.052)     # Upper-left cupped margin
	var v5 := Vector3(0.044, 0.014, 0.052)      # Upper-right cupped margin
	var v6 := Vector3(0.0, -0.011, 0.112)       # Tapered drooping leaf tip

	var n0 := Vector3(0.0, 0.94, -0.34).normalized()
	var n1 := Vector3(-0.34, 0.92, -0.16).normalized()
	var n2 := Vector3(0.0, 1.0, 0.0)
	var n3 := Vector3(0.34, 0.92, -0.16).normalized()
	var n4 := Vector3(-0.30, 0.93, 0.18).normalized()
	var n5 := Vector3(0.30, 0.93, 0.18).normalized()
	var n6 := Vector3(0.0, 0.93, 0.36).normalized()

	var c_stem := Color(0.88, 0.88, 0.88)
	var c_mid := Color(0.95, 0.95, 0.95)
	var c_edge := Color(1.0, 1.0, 1.0)

	# 6 triangles covering the full tapered cupped ovoid silhouette
	_emit_tri(st, v0, n0, c_stem, v1, n1, c_edge, v2, n2, c_mid)
	_emit_tri(st, v0, n0, c_stem, v2, n2, c_mid, v3, n3, c_edge)
	_emit_tri(st, v2, n2, c_mid, v1, n1, c_edge, v4, n4, c_edge)
	_emit_tri(st, v2, n2, c_mid, v5, n5, c_edge, v3, n3, c_edge)
	_emit_tri(st, v2, n2, c_mid, v4, n4, c_edge, v6, n6, c_edge)
	_emit_tri(st, v2, n2, c_mid, v6, n6, c_edge, v5, n5, c_edge)

	st.index()
	return st.commit()


static func _emit_tri(
	st: SurfaceTool,
	p0: Vector3, n0: Vector3, c0: Color,
	p1: Vector3, n1: Vector3, c1: Color,
	p2: Vector3, n2: Vector3, c2: Color
) -> void:
	st.set_normal(n0)
	st.set_color(c0)
	st.add_vertex(p0)
	st.set_normal(n1)
	st.set_color(c1)
	st.add_vertex(p1)
	st.set_normal(n2)
	st.set_color(c2)
	st.add_vertex(p2)


static func _build_leaf_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.roughness = 0.48
	mat.metallic = 0.02
	return mat
