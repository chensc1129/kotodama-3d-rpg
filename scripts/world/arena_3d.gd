class_name Arena3D
extends Node3D
## Procedurally builds 4 complex, multi-tiered 3D Japanese battlegrounds with high-resolution
## heightfield terrain, walkable arched bridges & multi-level decks, solid tactical cover pillars,
## atmospheric water/lava/cloud layers, and animated stage-specific mechanics.

const FLOOR_SHADER: Shader = preload("res://assets/shaders/arena_floor.gdshader")
const PROP_SURFACE_SHADER: Shader = preload("res://assets/shaders/arena_prop_surface.gdshader")
const WATER_SHADER: Shader = preload("res://assets/shaders/arena_water.gdshader")
const SKY_SHADER: Shader = preload("res://assets/shaders/arena_sky.gdshader")

@export var world_environment: WorldEnvironment
@export var center_light: OmniLight3D

var current_stage_id: String = "sakura_shrine"

# Walkable elevated circular decks: {pos: Vector3 (XZ center, y=top), radius: float, grounded: bool}
var platforms: Array[Dictionary] = []
# Walkable arched rectangular bridges/walkways: {start: Vector3, end: Vector3, width: float, arch: float}
var bridges: Array[Dictionary] = []
# Solid tactical cover obstacles (pillars, boulders, pagoda columns): {pos: Vector2, radius: float, top_y: float}
var obstacles: Array[Dictionary] = []

const S: float = GameData.ARENA_RADIUS / 28.0

# Stage-specific mechanic zones queried by BattleManager
var sakura_zone_pos: Vector3 = Vector3.ZERO
var sakura_zone_radius: float = 5.6
var wind_zones: Array[Dictionary] = []       # {pos: Vector3, radius: float, node: Node3D}
var jump_pads: Array[Dictionary] = []        # {pos: Vector3, radius: float, node: Node3D}

var _arena_content: Node3D
var _particles: CPUParticles3D
var _sakura_zone_node: Node3D
var _lava_plane_mat: Material
var _water_plane_mat: Material
var _sky_anim_nodes: Array[Dictionary] = []
var _elapsed: float = 0.0
var _splash_time: float = 99.0
var _gust_time: float = 99.0
var _current_wind_strength: float = 1.0
var _wind_gust_val: float = 0.0
var _wafuu_wind_mats: Array[ShaderMaterial] = []
var _foliage_phys: Node3D = null
var _leaf_phys: Node3D = null
var _floor_mat: ShaderMaterial = null
var _sakura_spots: Array[Vector2] = [
	Vector2(0.0, -17.5 * S),
	Vector2(17.5 * S, 2.0 * S),
	Vector2(-17.5 * S, 2.0 * S),
	Vector2(0.0, 1.5 * S),
]
var _sakura_spot_idx: int = 0


func _ready() -> void:
	_arena_content = Node3D.new()
	_arena_content.name = "ArenaContent"
	add_child(_arena_content)


# ==============================================================================
#  EXACT ANALYTICAL TERRAIN HEIGHT + BRIDGES + PLATFORMS + OBSTACLE COLLISION
# ==============================================================================
func get_base_terrain_height(x: float, z: float) -> float:
	if current_stage_id == ArpgChapter1Data.STAGE_ID:
		return ArpgCh1Map.get_base_terrain_height(x, z)
	var r := sqrt(x * x + z * z)
	var radius := GameData.ARENA_RADIUS

	match current_stage_id:
		"sakura_shrine":
			# Multi-tier Shrine Complex: Central Plaza (+0.38m) -> Sunken Moonlit Koi Moat (-0.78m)
			# -> North Grand Torii Altar (+2.75m) + Twin East/West Pavilions (+1.85m) + South Steps (+0.95m)
			var h := 0.0
			# Central stone courtyard mound
			var inner_t := clampf(1.0 - maxf(0.0, r - 5.2 * S) / (2.2 * S), 0.0, 1.0)
			inner_t = inner_t * inner_t * (3.0 - 2.0 * inner_t)
			h = lerpf(0.0, 0.38, inner_t)

			# Sunken circular Koi Pond Moat ring around r = 8.9 * S
			var moat_d := absf(r - 8.9 * S)
			var moat_t := clampf(1.0 - moat_d / (2.4 * S), 0.0, 1.0)
			moat_t = moat_t * moat_t * (3.0 - 2.0 * moat_t)
			h -= 0.78 * moat_t

			# North Elevated Torii Altar (+2.75m) with smooth stepped stone approach
			var north_t := clampf((-z - 10.5 * S) / (6.2 * S), 0.0, 1.0)
			north_t = north_t * north_t * (3.0 - 2.0 * north_t)
			var x_mask := clampf(1.0 - maxf(0.0, absf(x) - 10.5 * S) / (6.2 * S), 0.0, 1.0)
			var north_altar := 2.75 * north_t * x_mask

			# Twin East/West Moon-Viewing Pavilion Terraces (+1.85m)
			var wing_x := clampf((absf(x) - 12.2 * S) / (4.8 * S), 0.0, 1.0)
			wing_x = wing_x * wing_x * (3.0 - 2.0 * wing_x)
			var wing_z := clampf(1.0 - maxf(0.0, absf(z - 2.0 * S) - 7.8 * S) / (5.2 * S), 0.0, 1.0)
			var wing_balcony := 1.85 * wing_x * wing_z

			# South Stepped Approach (+0.95m)
			var south_t := clampf((z - 13.5 * S) / (5.8 * S), 0.0, 1.0)
			var south_step := 0.95 * south_t * south_t * (3.0 - 2.0 * south_t)
			return maxf(h, maxf(maxf(north_altar, wing_balcony), south_step))

		"maple_temple":
			# Winding Mountain Gorge (-1.15m) + Central Pagoda Sanctuary (+2.15m) + Gently Terraced Hills (+2.95m)
			var center_mound := 2.15 * exp(-((r * r) / (42.0 * S * S)))
			var gorge_curve := sin(x * (0.16 / S)) * (4.2 * S)
			var gorge_ring := absf(r - 11.8 * S - sin(atan2(z, x) * 2.0) * (1.8 * S))
			var valley_dip := -1.18 * exp(-((gorge_ring * gorge_ring) / (9.5 * S * S)))
			var stream_cut := -0.45 * exp(-(((z - gorge_curve) * (z - gorge_curve)) / (8.0 * S * S))) * clampf((r - 6.0 * S) / (5.0 * S), 0.0, 1.0)

			var ang := atan2(z, x)
			var outer_t := clampf((r - 14.2 * S) / (8.5 * S), 0.0, 1.0)
			outer_t = outer_t * outer_t * (3.0 - 2.0 * outer_t)
			var raw_hills := (1.95 + 1.05 * sin(ang * 3.0 + 0.5) + 0.55 * cos(ang * 5.0 - 0.7)) * outer_t
			# Very gentle hillside contour (avoid abrupt stair-snap steps)
			var stepped_hills := lerpf(raw_hills, floor(raw_hills * 1.8) / 1.8, 0.10)
			return center_mound + valley_dip + stream_cut + stepped_hills

		"onigashima_lava":
			# Cracked Volcanic Caldera: Deep Magma Chasms (-1.05m) + Central Hub (+1.05m)
			# + 4 Basalt Fortresses (+2.45m) + 4 Safe Diagonal Stone Causeways (+0.78m) + Volcanic Rim
			var h := -1.05
			var center_t := clampf(1.0 - maxf(0.0, r - 4.6 * S) / (4.2 * S), 0.0, 1.0)
			center_t = center_t * center_t * (3.0 - 2.0 * center_t)
			h = maxf(h, lerpf(-1.05, 1.05, center_t))

			# 4 Raised Obsidian Basalt Bastions in NE, NW, SE, SW quadrants (smooth climbable slope)
			var islands := [
				Vector2(18.3, -17.6),
				Vector2(-18.3, -17.6),
				Vector2(18.3, 17.6),
				Vector2(-18.3, 17.6),
			]
			for isl: Vector2 in islands:
				var d := Vector2(x, z).distance_to(isl)
				var it := clampf(1.0 - maxf(0.0, d - 6.0) / 6.8, 0.0, 1.0)
				it = it * it * (3.0 - 2.0 * it)
				h = maxf(h, lerpf(-1.05, 2.45, it))

			# 4 Diagonal Obsidian Stone Causeways (safe above lava)
			var diag_d1 := absf(x - z) * 0.7071
			var diag_d2 := absf(x + z) * 0.7071
			var bridge_d := minf(diag_d1, diag_d2)
			if r > 3.2 * S and r < 22.5 * S:
				var bt := clampf(1.0 - maxf(0.0, bridge_d - 2.0) / 3.0, 0.0, 1.0)
				bt = bt * bt * (3.0 - 2.0 * bt)
				h = maxf(h, lerpf(-1.05, 0.78, bt))

			# Outer jagged volcanic caldera ridge
			var ang := atan2(z, x)
			var rim_t := clampf((r - (radius - 6.0)) / 5.2, 0.0, 1.0)
			var rim_h := 1.45 + 0.55 * sin(ang * 8.0)
			h = maxf(h, lerpf(-1.05, rim_h, rim_t * rim_t))
			return h

		"sky_tenshu":
			# Tiered Golden Sky-Castle Courtyard + 4 Ceremonial Spirit-Ramps (N/S/E/W)
			# Ramps climb smoothly from r=6.0m -> 15.2m, arriving flush at the 15.2m bastion rim (22.0 - 6.8)
			var h := 0.0
			var inner_rim := clampf((r - 15.6) / 6.0, 0.0, 1.0)
			h = 0.55 * inner_rim * inner_rim * (3.0 - 2.0 * inner_rim)
			var outer_rim := clampf((r - 27.8) / 6.0, 0.0, 1.0)
			h += 0.85 * outer_rim * outer_rim * (3.0 - 2.0 * outer_rim)

			# North/South sloped ceremonial spirit-ramps climbing smoothly up to +2.55m bastion rim (|z|=15.2)
			if absf(x) < 3.4 and absf(z) > 6.0 and absf(z) < 16.0:
				var ramp_t := clampf((absf(z) - 6.0) / 9.2, 0.0, 1.0)
				var x_fade := clampf(1.0 - maxf(0.0, absf(x) - 2.1) / 1.3, 0.0, 1.0)
				h = maxf(h, 2.55 * ramp_t * x_fade)
			# East/West sloped ceremonial spirit-ramps climbing smoothly up to +2.65m bastion rim (|x|=15.2)
			if absf(z) < 3.4 and absf(x) > 6.0 and absf(x) < 16.0:
				var ramp_tx := clampf((absf(x) - 6.0) / 9.2, 0.0, 1.0)
				var z_fade := clampf(1.0 - maxf(0.0, absf(z) - 2.1) / 1.3, 0.0, 1.0)
				h = maxf(h, 2.65 * ramp_tx * z_fade)
			return h

	return 0.0


func _bridge_pt(x: float, z: float, y_offset: float = 0.0) -> Vector3:
	return Vector3(x, get_base_terrain_height(x, z) + y_offset, z)


func get_ground_height(x: float, z: float, entity_y: float = 99.0) -> float:
	var h := get_base_terrain_height(x, z)

	# Check walkable circular elevated decks (tight 0.34m step-up prevents teleporting onto high ledges!)
	for plat in platforms:
		var p: Vector3 = plat["pos"]
		var rad: float = float(plat["radius"])
		var dx := x - p.x
		var dz := z - p.z
		if (dx * dx + dz * dz) <= rad * rad:
			if p.y <= entity_y + 0.34:
				h = maxf(h, p.y)

	# Check walkable arched rectangular bridges & sky-walkways
	var pt2 := Vector2(x, z)
	for br in bridges:
		var s3: Vector3 = br["start"]
		var e3: Vector3 = br["end"]
		var s2 := Vector2(s3.x, s3.z)
		var e2 := Vector2(e3.x, e3.z)
		var seg := e2 - s2
		var seg_len_sq := seg.length_squared()
		if seg_len_sq < 0.01:
			continue
		var t := clampf((pt2 - s2).dot(seg) / seg_len_sq, 0.0, 1.0)
		var closest := s2 + seg * t
		var half_w: float = float(br["width"]) * 0.5
		if pt2.distance_to(closest) <= half_w:
			var deck_y := lerpf(s3.y, e3.y, t) + sin(t * PI) * float(br["arch"])
			var step_tol: float = 0.38 if (t <= 0.08 or t >= 0.92) else 0.30
			if deck_y <= entity_y + step_tol:
				h = maxf(h, deck_y)

	return h


func get_ceiling_height(x: float, z: float, feet_y: float) -> float:
	var ceil_y := 999.0
	for plat in platforms:
		if bool(plat.get("grounded", false)):
			continue
		var p: Vector3 = plat["pos"]
		var slab_bottom: float = p.y - float(plat.get("slab_h", 0.52))
		if slab_bottom > feet_y + 0.45:
			var rad: float = float(plat["radius"]) + 0.35
			var dx := x - p.x
			var dz := z - p.z
			if (dx * dx + dz * dz) <= rad * rad:
				ceil_y = minf(ceil_y, slab_bottom)
	return ceil_y


func resolve_obstacle_collision(pos: Vector3, entity_radius: float = 0.65) -> Vector3:
	var out := pos

	# 1. Solid tactical pillars, boulders, pagoda core, pavilion columns
	for obs in obstacles:
		if out.y >= float(obs["top_y"]) - 0.15:
			continue # Jumped cleanly over low cover!
		var op: Vector2 = obs["pos"]
		var min_d: float = float(obs["radius"]) + entity_radius
		var diff := Vector2(out.x - op.x, out.z - op.y)
		var dist_sq := diff.length_squared()
		if dist_sq < min_d * min_d:
			var dir := diff.normalized() if dist_sq > 0.0001 else Vector2(1.0, 0.0)
			out.x = op.x + dir.x * min_d
			out.z = op.y + dir.y * min_d

	# 2. Elevated deck pedestals & floating deck slab anti-clipping
	for plat in platforms:
		var p: Vector3 = plat["pos"]
		if out.y >= p.y - 0.34:
			continue # Standing cleanly on top or jumping high enough to land on deck
		var is_grounded_deck := bool(plat.get("grounded", false))
		var slab_bottom: float = p.y - float(plat.get("slab_h", 0.52))
		# Block grounded pedestals completely below deck top; block floating slabs if body overlaps slab!
		if (not is_grounded_deck) and (out.y + 2.05 <= slab_bottom):
			continue
		var rad: float = float(plat["radius"])
		var min_d: float = rad + entity_radius * 0.85
		var diff := Vector2(out.x - p.x, out.z - p.z)
		var dist_sq := diff.length_squared()
		if dist_sq < min_d * min_d:
			var dir := diff.normalized() if dist_sq > 0.0001 else Vector2(1.0, 0.0)
			out.x = p.x + dir.x * min_d
			out.z = p.z + dir.y * min_d

	# 3. Prevent walking sideways into bridges or underneath low-headroom bridges (< 2.35m clearance)
	var pt2 := Vector2(out.x, out.z)
	for br in bridges:
		var s3: Vector3 = br["start"]
		var e3: Vector3 = br["end"]
		var s2 := Vector2(s3.x, s3.z)
		var e2 := Vector2(e3.x, e3.z)
		var seg := e2 - s2
		var seg_len_sq := seg.length_squared()
		if seg_len_sq < 0.01:
			continue
		var t_raw := (pt2 - s2).dot(seg) / seg_len_sq
		if t_raw <= 0.06 or t_raw >= 0.94:
			continue # Open bridge entrance/exit
		var closest := s2 + seg * t_raw
		var deck_y := lerpf(s3.y, e3.y, t_raw) + sin(t_raw * PI) * float(br["arch"])
		# Block whenever hero/enemy head would clip through bridge underside (< 2.35m headroom)
		if out.y < deck_y - 0.36 and out.y > deck_y - 2.35:
			var half_w: float = float(br["width"]) * 0.5 + entity_radius * 0.78
			var diff := pt2 - closest
			var d := diff.length()
			if d < half_w:
				var side_dir: Vector2
				if d > 0.001:
					side_dir = diff / d
				else:
					side_dir = Vector2(-seg.y, seg.x).normalized()
				pt2 = closest + side_dir * half_w
				out.x = pt2.x
				out.z = pt2.y

	return out


func _is_steep_step(from_pos: Vector3, to_x: float, to_z: float) -> bool:
	var horiz := sqrt((to_x - from_pos.x) * (to_x - from_pos.x) + (to_z - from_pos.z) * (to_z - from_pos.z))
	if horiz < 0.001:
		return false
	var next_gy := get_ground_height(to_x, to_z, from_pos.y)
	var step_up := next_gy - from_pos.y
	if step_up <= 0.02:
		return false
	# Smooth hiking/sprinting on gentle mountain trails (<= 38 deg, tan=0.781) while
	# solidly blocking sheer coastal cliffs (> 48 deg, tan=1.111, cos=0.669)
	if (step_up / horiz) > 1.04:
		return true
	if not is_on_bridge_or_pier(to_x, to_z, next_gy):
		# Prevent diagonal crab-walking up sheer > 47.5 deg cliff faces (cos(47.5 deg) = 0.6756)
		var nrm := get_terrain_normal(to_x, to_z)
		if nrm.y < 0.676:
			return true
	return step_up > 0.85


func _is_airborne_cliff_hit(from_pos: Vector3, to_x: float, to_z: float) -> bool:
	var next_gy := get_ground_height(to_x, to_z, from_pos.y)
	if next_gy <= from_pos.y + 0.42:
		return false
	if is_on_bridge_or_pier(to_x, to_z, next_gy):
		return false
	var nrm := get_terrain_normal(to_x, to_z)
	return nrm.y < 0.676 or (next_gy - from_pos.y) > 0.95


func resolve_terrain_step(prev_pos: Vector3, next_pos: Vector3, is_grounded: bool) -> Vector3:
	var dx := next_pos.x - prev_pos.x
	var dz := next_pos.z - prev_pos.z
	if (dx * dx + dz * dz) < 0.000001:
		return next_pos

	if not is_grounded:
		if not _is_airborne_cliff_hit(prev_pos, next_pos.x, next_pos.z):
			return next_pos
		var air_ok_x := not _is_airborne_cliff_hit(prev_pos, next_pos.x, prev_pos.z)
		var air_ok_z := not _is_airborne_cliff_hit(prev_pos, prev_pos.x, next_pos.z)
		if air_ok_x and absf(dx) >= absf(dz):
			return Vector3(next_pos.x, next_pos.y, prev_pos.z)
		if air_ok_z:
			return Vector3(prev_pos.x, next_pos.y, next_pos.z)
		if air_ok_x:
			return Vector3(next_pos.x, next_pos.y, prev_pos.z)
		return Vector3(prev_pos.x, next_pos.y, prev_pos.z)

	if _is_steep_step(prev_pos, next_pos.x, next_pos.z):
		# First attempt smooth sliding along the cliff contour tangent
		var nrm := get_terrain_normal(next_pos.x, next_pos.z)
		var slope_xz := Vector2(nrm.x, nrm.z)
		if slope_xz.length_squared() > 0.001:
			slope_xz = slope_xz.normalized()
			var move_xz := Vector2(dx, dz)
			var into_cliff := move_xz.dot(-slope_xz)
			if into_cliff > 0.0:
				var slide_xz := move_xz + slope_xz * (into_cliff + 0.002)
				var sx := prev_pos.x + slide_xz.x
				var sz := prev_pos.z + slide_xz.y
				if not _is_steep_step(prev_pos, sx, sz):
					return Vector3(sx, next_pos.y, sz)

		var ok_x := not _is_steep_step(prev_pos, next_pos.x, prev_pos.z)
		var ok_z := not _is_steep_step(prev_pos, prev_pos.x, next_pos.z)
		if ok_x and absf(dx) >= absf(dz):
			return Vector3(next_pos.x, next_pos.y, prev_pos.z)
		if ok_z:
			return Vector3(prev_pos.x, next_pos.y, next_pos.z)
		if ok_x:
			return Vector3(next_pos.x, next_pos.y, prev_pos.z)
		return Vector3(prev_pos.x, next_pos.y, prev_pos.z)
	return next_pos


func is_in_lava(x: float, z: float, entity_y: float) -> bool:
	if current_stage_id != "onigashima_lava":
		return false
	return entity_y < -0.35 and get_base_terrain_height(x, z) < -0.45


func is_on_bridge_or_pier(x: float, z: float, entity_y: float) -> bool:
	var pt := Vector2(x, z)
	for br in bridges:
		var s3: Vector3 = br["start"]
		var e3: Vector3 = br["end"]
		var s2 := Vector2(s3.x, s3.z)
		var e2 := Vector2(e3.x, e3.z)
		var seg := e2 - s2
		var seg_len_sq := seg.length_squared()
		if seg_len_sq < 0.01:
			continue
		var t := clampf((pt - s2).dot(seg) / seg_len_sq, 0.0, 1.0)
		var closest := s2 + seg * t
		var half_w: float = float(br["width"]) * 0.52
		if pt.distance_to(closest) <= half_w:
			var deck_y := lerpf(s3.y, e3.y, t) + sin(t * PI) * float(br["arch"])
			if entity_y >= deck_y - 0.45 and entity_y <= deck_y + 1.25:
				return true
	return false


func get_terrain_normal(x: float, z: float) -> Vector3:
	if current_stage_id == ArpgChapter1Data.STAGE_ID:
		return ArpgCh1Map.get_terrain_normal(x, z)
	var eps := 0.30
	var hx1 := get_base_terrain_height(x + eps, z)
	var hx0 := get_base_terrain_height(x - eps, z)
	var hz1 := get_base_terrain_height(x, z + eps)
	var hz0 := get_base_terrain_height(x, z - eps)
	return Vector3(hx0 - hx1, 2.0 * eps, hz0 - hz1).normalized()


func get_water_level(x: float, z: float) -> float:
	if current_stage_id == ArpgChapter1Data.STAGE_ID:
		return ArpgCh1Map.get_water_level(x, z)
	if current_stage_id == "sakura_shrine":
		if get_base_terrain_height(x, z) < -0.22:
			return -0.34
	elif current_stage_id == "maple_temple":
		if get_base_terrain_height(x, z) < -0.48:
			return -0.62
	return -99.0


func get_surface_type(x: float, z: float, entity_y: float) -> String:
	if is_on_bridge_or_pier(x, z, entity_y):
		return "wood"
	if current_stage_id == ArpgChapter1Data.STAGE_ID:
		return ArpgCh1Map.get_surface_type(x, z, entity_y)
	var wl := get_water_level(x, z)
	if wl > -50.0 and entity_y < wl + 0.08:
		return "water"
	if current_stage_id == "maple_temple":
		return "grass"
	return "stone"


func update_interactive_env(
	player_pos: Vector3,
	player_vel: Vector3,
	wind_strength: float,
	wind_dir: Vector2,
	dynamic_actors: Array = [],
	dt: float = 0.0167
) -> void:
	_current_wind_strength = wind_strength
	_wind_gust_val = clampf((wind_strength - 0.85) * 1.15, 0.0, 2.0)

	if _foliage_phys != null and is_instance_valid(_foliage_phys):
		_foliage_phys.call("step_physics", dt, player_pos, player_vel, wind_dir, wind_strength, dynamic_actors)
	if _leaf_phys != null and is_instance_valid(_leaf_phys):
		_leaf_phys.call("step_physics", dt, player_pos, player_vel, wind_dir, wind_strength)

	if has_meta("interactive_foliage_mats"):
		var fmats: Array = get_meta("interactive_foliage_mats")
		for m in fmats:
			if m is ShaderMaterial:
				var sm := m as ShaderMaterial
				sm.set_shader_parameter("player_pos", player_pos)
				sm.set_shader_parameter("player_vel", player_vel)
				sm.set_shader_parameter("wind_strength", wind_strength)
				sm.set_shader_parameter("wind_dir", wind_dir)
				sm.set_shader_parameter("wind_gust", _wind_gust_val)
	if has_meta("interactive_water_mats"):
		var wmats: Array = get_meta("interactive_water_mats")
		for m in wmats:
			if m is ShaderMaterial:
				var sm := m as ShaderMaterial
				sm.set_shader_parameter("player_pos", player_pos)
				sm.set_shader_parameter("wind_strength", wind_strength)
	elif _water_plane_mat is ShaderMaterial:
		var wsm := _water_plane_mat as ShaderMaterial
		wsm.set_shader_parameter("player_pos", player_pos)
		wsm.set_shader_parameter("wind_strength", wind_strength)
	for wm in _wafuu_wind_mats:
		if is_instance_valid(wm):
			wm.set_shader_parameter("wind_strength", wind_strength)
			if wm.shader != null and wm.shader.resource_path.ends_with("tree_leaves_alpha.gdshader"):
				wm.set_shader_parameter("wind_dir", wind_dir)
				wm.set_shader_parameter("wind_gust", _wind_gust_val)
				wm.set_shader_parameter("player_pos", player_pos)
				wm.set_shader_parameter("player_vel", player_vel)
	if _floor_mat != null and is_instance_valid(_floor_mat):
		_floor_mat.set_shader_parameter("wind_dir", wind_dir)
		_floor_mat.set_shader_parameter("wind_strength", wind_strength)


func trigger_water_splash(pos: Vector3, strength: float = 1.0) -> void:
	_splash_time = 0.0
	if has_meta("interactive_water_mats"):
		var wmats: Array = get_meta("interactive_water_mats")
		for m in wmats:
			if m is ShaderMaterial:
				var sm := m as ShaderMaterial
				sm.set_shader_parameter("splash_pos", pos)
				sm.set_shader_parameter("splash_time", 0.0)
				sm.set_shader_parameter("splash_strength", clampf(strength, 0.0, 2.0))
	elif _water_plane_mat is ShaderMaterial:
		var wsm := _water_plane_mat as ShaderMaterial
		wsm.set_shader_parameter("splash_pos", pos)
		wsm.set_shader_parameter("splash_time", 0.0)
		wsm.set_shader_parameter("splash_strength", clampf(strength, 0.0, 2.0))


func trigger_foliage_gust(pos: Vector3, strength: float = 1.0, radius: float = 5.2, shed_leaves: int = 10) -> void:
	_gust_time = 0.0
	if has_meta("interactive_foliage_mats"):
		var fmats: Array = get_meta("interactive_foliage_mats")
		for m in fmats:
			if m is ShaderMaterial:
				var sm := m as ShaderMaterial
				sm.set_shader_parameter("gust_pos", pos)
				sm.set_shader_parameter("gust_time", 0.0)
				sm.set_shader_parameter("gust_strength", strength)
	for wm in _wafuu_wind_mats:
		if is_instance_valid(wm) and wm.shader != null and wm.shader.resource_path.ends_with("tree_leaves_alpha.gdshader"):
			wm.set_shader_parameter("gust_pos", pos)
			wm.set_shader_parameter("gust_time", 0.0)
			wm.set_shader_parameter("gust_strength", strength)
	if _foliage_phys != null and is_instance_valid(_foliage_phys):
		_foliage_phys.call("apply_impulse", pos, radius, strength * 1.45, clampf(0.42 * strength, 0.25, 0.95))
	if _leaf_phys != null and is_instance_valid(_leaf_phys):
		_leaf_phys.call("apply_vortex_impulse", pos, radius + 2.2, strength * 1.35, shed_leaves)


func _try_register_wind_mat(mat: Material, seen: Dictionary) -> void:
	if mat is ShaderMaterial:
		var sm := mat as ShaderMaterial
		if sm.shader != null:
			var spath := sm.shader.resource_path
			if spath.ends_with("wafuu_prop.gdshader") or spath.ends_with("tree_leaves_alpha.gdshader"):
				var rid_id := sm.get_instance_id()
				if not seen.has(rid_id):
					seen[rid_id] = true
					_wafuu_wind_mats.append(sm)


func _collect_wafuu_wind_materials() -> void:
	_wafuu_wind_mats.clear()
	var seen: Dictionary = {}
	var stack: Array[Node] = [_arena_content]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is MeshInstance3D:
			var mi := n as MeshInstance3D
			_try_register_wind_mat(mi.material_override, seen)
			if mi.mesh != null:
				for si in range(mi.mesh.get_surface_count()):
					_try_register_wind_mat(mi.get_surface_override_material(si), seen)
					_try_register_wind_mat(mi.mesh.surface_get_material(si), seen)
		elif n is MultiMeshInstance3D:
			var mmi := n as MultiMeshInstance3D
			_try_register_wind_mat(mmi.material_override, seen)
			if mmi.multimesh != null and mmi.multimesh.mesh != null:
				var mm_mesh := mmi.multimesh.mesh
				for si in range(mm_mesh.get_surface_count()):
					_try_register_wind_mat(mm_mesh.surface_get_material(si), seen)
		for child in n.get_children():
			stack.append(child)


func cycle_sakura_zone() -> Vector3:
	_sakura_spot_idx = (_sakura_spot_idx + 1) % _sakura_spots.size()
	var pt := _sakura_spots[_sakura_spot_idx]
	var y := get_ground_height(pt.x, pt.y)
	sakura_zone_pos = Vector3(pt.x, y, pt.y)
	if _sakura_zone_node != null and is_instance_valid(_sakura_zone_node):
		_sakura_zone_node.position = sakura_zone_pos + Vector3(0.0, 0.08, 0.0)
	return sakura_zone_pos


# ==============================================================================
#  STAGE BUILDER
# ==============================================================================
func build_stage(stage_id: String) -> void:
	current_stage_id = stage_id
	var st: Dictionary = GameData.get_stage(stage_id)
	var is_mob := UiStyle.is_mobile_device()

	for child in _arena_content.get_children():
		_arena_content.remove_child(child)
		child.queue_free()

	platforms.clear()
	bridges.clear()
	obstacles.clear()
	wind_zones.clear()
	jump_pads.clear()
	_sky_anim_nodes.clear()
	_wafuu_wind_mats.clear()
	_sakura_zone_node = null
	_lava_plane_mat = null
	_water_plane_mat = null
	_foliage_phys = null
	_leaf_phys = null
	_floor_mat = null
	_wind_gust_val = 0.0
	_sakura_spot_idx = 0
	_splash_time = 99.0
	_gust_time = 99.0
	if has_meta("interactive_foliage_mats"):
		remove_meta("interactive_foliage_mats")
	if has_meta("interactive_water_mats"):
		remove_meta("interactive_water_mats")
	if has_meta("leaf_canopy_spots"):
		remove_meta("leaf_canopy_spots")
	if has_meta("meadow_grass_mat"):
		remove_meta("meadow_grass_mat")
	if has_meta("terrain_floor_mat"):
		remove_meta("terrain_floor_mat")

	if current_stage_id == ArpgChapter1Data.STAGE_ID:
		if center_light != null:
			center_light.light_color = Color.html("#f472b6")
			center_light.light_energy = 1.65
			center_light.omni_range = 140.0
		ArpgCh1Map.build_map(self, _arena_content, FLOOR_SHADER, PROP_SURFACE_SHADER, WATER_SHADER, SKY_SHADER, _sky_anim_nodes)
		_finalize_stage_physics_and_wind(is_mob)
		return

	var sky_col := Color.html(st["sky_color"])
	var fog_col := Color.html(st["fog_color"])
	var floor_col := Color.html(st["floor_color"])
	var ring_col := Color.html(st["ring_color"])
	var ambient_col := Color.html(st["ambient_color"])
	var particle_col := Color.html(st["particle_color"])

	if world_environment != null:
		var env := world_environment.environment
		if env == null:
			env = Environment.new()
			world_environment.environment = env
		var sky_mat := ShaderMaterial.new()
		sky_mat.shader = SKY_SHADER
		sky_mat.set_shader_parameter("stage_id", _stage_shader_index())
		sky_mat.set_shader_parameter("mobile_mode", is_mob)
		var sky_res := Sky.new()
		sky_res.sky_material = sky_mat
		sky_res.radiance_size = Sky.RADIANCE_SIZE_32
		env.background_mode = Environment.BG_SKY
		env.sky = sky_res
		# Critical WebGL2 mobile optimization: prevent per-frame 6-face radiance cubemap updates!
		env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
		env.background_color = sky_col
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = ambient_col
		env.ambient_light_energy = 1.05 if is_mob else 0.85
		env.fog_enabled = true
		env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
		env.fog_light_color = fog_col
		env.fog_density = 0.0046
		env.fog_sky_affect = 0.08

	if center_light != null:
		center_light.light_color = ring_col
		center_light.light_energy = 1.9
		center_light.omni_range = GameData.ARENA_RADIUS * 2.6

	# 1. Higher-Resolution Sculpted Heightfield Terrain Mesh
	_build_heightfield_terrain(floor_col, ring_col)

	# 2. Glowing Outer Boundary Ring conforming to edge terrain
	_build_boundary_ring(ring_col)

	# 3. Complex Stage Architecture, Walkable Bridges, Multi-Level Decks & Tactical Pillars
	match current_stage_id:
		"sakura_shrine":
			_build_sakura_shrine_props(ring_col)
		"maple_temple":
			_build_maple_temple_props(ring_col)
		"onigashima_lava":
			_build_onigashima_lava_props(ring_col)
		"sky_tenshu":
			_build_sky_tenshu_props(ring_col)

	# 4. 3D Distant Sky Landmarks (Sky Lanterns, Sunset Clouds/Cranes, Volcanic Peaks, Celestial Rings)
	_build_sky_landmarks()

	# 5. Ambient Falling Petals / Leaves / Embers / Starlight
	_build_ambient_particles(particle_col)

	# 6. Collect wind materials & wire FoliagePhysicsField / LeafPhysicsSystem
	_finalize_stage_physics_and_wind(is_mob)


func _finalize_stage_physics_and_wind(is_mob: bool) -> void:
	_collect_wafuu_wind_materials()

	# Track terrain floor ShaderMaterial for real-time wind waves on terrain grass
	if has_meta("terrain_floor_mat") and get_meta("terrain_floor_mat") is ShaderMaterial:
		_floor_mat = get_meta("terrain_floor_mat") as ShaderMaterial
	elif _floor_mat == null:
		var terrain_mi := _arena_content.get_node_or_null("TerrainMesh") as MeshInstance3D
		if terrain_mi != null and terrain_mi.material_override is ShaderMaterial:
			_floor_mat = terrain_mi.material_override as ShaderMaterial

	# Real-Time Foliage Physics Field + Rolling Near-Player Meadow Carpet (Chapter 1 ARPG)
	const FOLIAGE_PHYS_PATH: String = "res://scripts/world/foliage_physics_field.gd"
	if current_stage_id == ArpgChapter1Data.STAGE_ID and ResourceLoader.exists(FOLIAGE_PHYS_PATH):
		var fpf_script := load(FOLIAGE_PHYS_PATH) as GDScript
		if fpf_script != null:
			var fpf := fpf_script.new() as Node3D
			if fpf != null:
				fpf.name = "FoliagePhysicsField"
				_arena_content.add_child(fpf)
				var grass_mat: ShaderMaterial = get_meta("meadow_grass_mat", null) as ShaderMaterial
				fpf.call("setup", self, is_mob, grass_mat, true)
				if has_meta("interactive_foliage_mats"):
					for m in get_meta("interactive_foliage_mats"):
						if m is ShaderMaterial:
							fpf.call("bind_material", m as ShaderMaterial)
				_foliage_phys = fpf

	# 6-DOF Aerodynamic Falling Leaf Physics System (stages with trees)
	const LEAF_PHYS_PATH: String = "res://scripts/world/leaf_physics_system.gd"
	var has_trees: bool = (
		current_stage_id == ArpgChapter1Data.STAGE_ID
		or current_stage_id == "arpg_ch1"
		or current_stage_id == "sakura_shrine"
		or current_stage_id == "maple_temple"
	)
	if has_trees and ResourceLoader.exists(LEAF_PHYS_PATH):
		var lps_script := load(LEAF_PHYS_PATH) as GDScript
		if lps_script != null:
			var lps := lps_script.new() as Node3D
			if lps != null:
				lps.name = "LeafPhysicsSystem"
				_arena_content.add_child(lps)
				var canopy_spots: Array = get_meta("leaf_canopy_spots", [])
				lps.call("setup", self, is_mob, current_stage_id, canopy_spots)
				_leaf_phys = lps


func _stage_shader_index() -> int:
	match current_stage_id:
		"sakura_shrine": return 0
		"maple_temple": return 1
		"onigashima_lava": return 2
		"sky_tenshu": return 3
	return 0


func _terrain_material_weights(x: float, z: float, h: float) -> Color:
	var r := sqrt(x * x + z * z)
	var radius := GameData.ARENA_RADIUS
	var w_a := 0.0
	var w_b := 0.0
	var w_c := 0.0
	var w_d := 0.0

	match current_stage_id:
		"sakura_shrine":
			# A: Carved Granite Flagstones (central courtyard + North Altar + South approach)
			# B: Raked Zen Lavender-White Gravel (mid temple grounds)
			# C: Polished Dark Slate Pavilion Tiles (East/West wings + North Altar crown)
			# D: Wet Koi Pond River Cobblestones (sunken moat & banks)
			var moat_w := clampf((-0.02 - h) / 0.36, 0.0, 1.0)
			var wing_w := clampf((absf(x) - 12.0 * S) / (3.2 * S), 0.0, 1.0) * clampf(1.0 - maxf(0.0, absf(z - 2.0 * S) - 8.5 * S) / (3.5 * S), 0.0, 1.0)
			var altar_slate := clampf((h - 2.15) / 0.55, 0.0, 1.0)
			var center_flag := clampf(1.0 - maxf(0.0, r - 4.8 * S) / (2.2 * S), 0.0, 1.0)
			var north_path := clampf((-z - 11.0 * S) / (3.0 * S), 0.0, 1.0) * clampf(1.0 - maxf(0.0, absf(x) - 4.5 * S) / (3.5 * S), 0.0, 1.0)
			var south_path := clampf((z - 12.0 * S) / (3.0 * S), 0.0, 1.0) * clampf(1.0 - maxf(0.0, absf(x) - 4.0 * S) / (3.5 * S), 0.0, 1.0)
			w_d = moat_w
			w_c = maxf(wing_w, altar_slate) * (1.0 - moat_w)
			w_a = clampf(maxf(center_flag, maxf(north_path, south_path)), 0.0, 1.0) * (1.0 - moat_w) * (1.0 - w_c * 0.65)
			w_b = maxf(0.0, 1.0 - (w_a + w_c + w_d))

		"maple_temple":
			# A: Aged Mossy Temple Flagstones (central pagoda mound + bridge approaches)
			# B: Lush Forest Moss & Bamboo Soil (mid valley banks)
			# C: Autumn Fallen Maple Leaf Carpet (outer hills & terraces)
			# D: Wet Dark Gorge Riverbed Slate (deep stream bed)
			var river_w := clampf((-0.25 - h) / 0.45, 0.0, 1.0)
			var center_stone := clampf(1.0 - maxf(0.0, r - 5.2 * S) / (3.0 * S), 0.0, 1.0)
			var maple_ridge := clampf((h - 0.85) / 1.05, 0.0, 1.0) * clampf((r - 11.0 * S) / (5.5 * S), 0.0, 1.0)
			w_d = river_w
			w_a = center_stone * (1.0 - river_w)
			w_c = maple_ridge * (1.0 - river_w) * (1.0 - w_a)
			w_b = maxf(0.0, 1.0 - (w_a + w_c + w_d))

		"onigashima_lava":
			# A: Fractured Basalt Columns w/ Ember Seams (central hub + 4 bastion plateaus)
			# B: Forged Obsidian Causeway Slabs (4 diagonal safe paths)
			# C: Scorched Volcanic Ash & Caldera Rim (slopes + outer ridge)
			# D: Flowing Molten Magma Crust (deep chasms)
			var magma_w := clampf((-0.38 - h) / 0.40, 0.0, 1.0)
			var diag_d := minf(absf(x - z) * 0.7071, absf(x + z) * 0.7071)
			var causeway_w := clampf(1.0 - maxf(0.0, diag_d - 1.9) / 1.7, 0.0, 1.0) * clampf((r - 4.2 * S) / (2.2 * S), 0.0, 1.0) * clampf((22.5 * S - r) / (2.8 * S), 0.0, 1.0)
			var plateau_w := clampf((h - 0.85) / 0.65, 0.0, 1.0) * clampf((radius - 4.5 - r) / 3.5, 0.0, 1.0)
			var center_hub := clampf(1.0 - maxf(0.0, r - 4.8 * S) / (2.4 * S), 0.0, 1.0)
			w_d = magma_w
			w_b = causeway_w * (1.0 - magma_w) * (1.0 - plateau_w * 0.7)
			w_a = clampf(maxf(plateau_w, center_hub), 0.0, 1.0) * (1.0 - magma_w) * (1.0 - w_b * 0.5)
			w_c = maxf(0.0, 1.0 - (w_a + w_b + w_d))

		"sky_tenshu":
			# A: Polished Indigo Celestial Marble (central sanctuary circle)
			# B: Imperial Geometric Stone Paving (mid courtyard)
			# C: Gilded Gold-Inlaid Spirit Ramps (4 ceremonial N/S/E/W ramps)
			# D: Weathered Castle Ishigaki Masonry (outer raised terrace rim)
			var ns_ramp: float = 1.0 if (absf(x) < 3.5 and absf(z) > 5.8 and absf(z) < 16.0) else 0.0
			var ew_ramp: float = 1.0 if (absf(z) < 3.5 and absf(x) > 5.8 and absf(x) < 16.0) else 0.0
			var ramp_w := maxf(ns_ramp, ew_ramp) * clampf((h - 0.12) / 0.45, 0.0, 1.0)
			var center_marble := clampf(1.0 - maxf(0.0, r - 9.2) / 4.2, 0.0, 1.0)
			var outer_wall := clampf((r - 26.0) / 5.0, 0.0, 1.0)
			w_c = ramp_w
			w_a = center_marble * (1.0 - w_c)
			w_d = outer_wall * (1.0 - w_c)
			w_b = maxf(0.0, 1.0 - (w_a + w_c + w_d))

		_:
			w_a = 1.0

	var s := maxf(w_a + w_b + w_c + w_d, 0.0001)
	return Color(w_a / s, w_b / s, w_c / s, w_d / s)


func _build_heightfield_terrain(_floor_col: Color, _ring_col: Color) -> void:
	var radius := GameData.ARENA_RADIUS
	var is_mob := UiStyle.is_mobile_device()
	var rings := 32 if is_mob else 48
	var segs := 64 if is_mob else 92

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var grid: Array = []
	for ri in range(rings + 1):
		var row: Array = []
		var rr := (float(ri) / float(rings)) * radius
		for si in range(segs):
			var ang := (float(si) / float(segs)) * TAU
			var x := cos(ang) * rr
			var z := sin(ang) * rr
			var y := get_base_terrain_height(x, z)
			var eps := 0.28
			var hx1 := get_base_terrain_height(x + eps, z)
			var hx0 := get_base_terrain_height(x - eps, z)
			var hz1 := get_base_terrain_height(x, z + eps)
			var hz0 := get_base_terrain_height(x, z - eps)
			var nrm := Vector3(hx0 - hx1, 2.0 * eps, hz0 - hz1).normalized()
			var weights := _terrain_material_weights(x, z, y)
			row.append([Vector3(x, y, z), nrm, weights])
		grid.append(row)

	for ri in range(rings):
		for si in range(segs):
			var sn := (si + 1) % segs
			var v00: Array = grid[ri][si]
			var v10: Array = grid[ri + 1][si]
			var v11: Array = grid[ri + 1][sn]
			var v01: Array = grid[ri][sn]

			# Godot 4 front-face winding is Clockwise (CW) when viewed from above (+Y)
			st.set_color(v00[2]); st.set_normal(v00[1]); st.add_vertex(v00[0])
			st.set_color(v10[2]); st.set_normal(v10[1]); st.add_vertex(v10[0])
			st.set_color(v11[2]); st.set_normal(v11[1]); st.add_vertex(v11[0])

			st.set_color(v00[2]); st.set_normal(v00[1]); st.add_vertex(v00[0])
			st.set_color(v11[2]); st.set_normal(v11[1]); st.add_vertex(v11[0])
			st.set_color(v01[2]); st.set_normal(v01[1]); st.add_vertex(v01[0])

	# Outer rocky cliff skirt (use stone/rock channel per stage, never golden ramp!)
	var skirt_w := Color(0.0, 0.0, 0.0, 1.0) if current_stage_id == "sky_tenshu" else Color(0.0, 0.0, 1.0, 0.0)
	for si in range(segs):
		var sn := (si + 1) % segs
		var top0: Vector3 = grid[rings][si][0]
		var top1: Vector3 = grid[rings][sn][0]
		var bot0 := Vector3(top0.x * 1.05, top0.y - 5.2, top0.z * 1.05)
		var bot1 := Vector3(top1.x * 1.05, top1.y - 5.2, top1.z * 1.05)
		var out_n := Vector3(top0.x + top1.x, 0.0, top0.z + top1.z).normalized()

		# Outward-facing CW winding for cliff skirt
		st.set_color(skirt_w); st.set_normal(out_n); st.add_vertex(top0)
		st.set_color(skirt_w); st.set_normal(out_n); st.add_vertex(bot1)
		st.set_color(skirt_w); st.set_normal(out_n); st.add_vertex(top1)

		st.set_color(skirt_w); st.set_normal(out_n); st.add_vertex(top0)
		st.set_color(skirt_w); st.set_normal(out_n); st.add_vertex(bot0)
		st.set_color(skirt_w); st.set_normal(out_n); st.add_vertex(bot1)

	var mesh := st.commit()
	var mat := ShaderMaterial.new()
	mat.shader = FLOOR_SHADER
	mat.set_shader_parameter("stage_id", _stage_shader_index())
	mat.set_shader_parameter("mobile_mode", is_mob)
	_floor_mat = mat

	var terrain_inst := MeshInstance3D.new()
	terrain_inst.name = "TerrainMesh"
	terrain_inst.mesh = mesh
	terrain_inst.material_override = mat
	terrain_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_arena_content.add_child(terrain_inst)


func _build_boundary_ring(ring_col: Color) -> void:
	var radius := GameData.ARENA_RADIUS - 0.35
	var segs := 64 if UiStyle.is_mobile_device() else 84
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for si in range(segs):
		var a0 := (float(si) / float(segs)) * TAU
		var a1 := (float(si + 1) / float(segs)) * TAU
		var x0_i := cos(a0) * (radius - 0.45); var z0_i := sin(a0) * (radius - 0.45)
		var x0_o := cos(a0) * (radius + 0.15); var z0_o := sin(a0) * (radius + 0.15)
		var x1_i := cos(a1) * (radius - 0.45); var z1_i := sin(a1) * (radius - 0.45)
		var x1_o := cos(a1) * (radius + 0.15); var z1_o := sin(a1) * (radius + 0.15)
		var y0 := get_base_terrain_height(x0_i, z0_i) + 0.12
		var y1 := get_base_terrain_height(x1_i, z1_i) + 0.12
		var p0i := Vector3(x0_i, y0, z0_i); var p0o := Vector3(x0_o, y0, z0_o)
		var p1i := Vector3(x1_i, y1, z1_i); var p1o := Vector3(x1_o, y1, z1_o)
		st.set_normal(Vector3.UP); st.add_vertex(p0i); st.set_normal(Vector3.UP); st.add_vertex(p0o); st.set_normal(Vector3.UP); st.add_vertex(p1o)
		st.set_normal(Vector3.UP); st.add_vertex(p0i); st.set_normal(Vector3.UP); st.add_vertex(p1o); st.set_normal(Vector3.UP); st.add_vertex(p1i)

	var mat := StandardMaterial3D.new()
	mat.albedo_color = ring_col
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var inst := MeshInstance3D.new()
	inst.mesh = st.commit()
	inst.material_override = mat
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_arena_content.add_child(inst)


# ==============================================================================
#  STAGE 1: SAKURA SHRINE (Koi Moat + 4 Flush Vermilion Bridges + Carved Decks)
# ==============================================================================
func _build_sakura_shrine_props(_ring_col: Color) -> void:
	# Shimmering Moonlit Koi Pond Water Ring peeking in the sunken moat (y = -0.34)
	_add_water_plane(-0.34, 13.0 * S, "#1d4ed8", "#38bdf8", 0.62)

	# Double Ceremonial Vermilion Torii Gates (Inner & Grand North Altar)
	_add_torii_gate(Vector3(0.0, get_base_terrain_height(0.0, -23.5 * S), -23.5 * S), "#dc2626", 1.36)
	_add_torii_gate(Vector3(0.0, get_base_terrain_height(0.0, 21.5 * S), 21.5 * S), "#b91c1c", 1.08)

	# 4 Flush-Anchored Arched Vermilion Taiko Bridges spanning the sunken Koi Moat!
	_add_walkable_bridge(_bridge_pt(0.0, -5.2 * S), _bridge_pt(0.0, -13.0 * S), 4.8, 0.85, "#991b1b", "#450a0a", "#ef4444", 0)
	_add_walkable_bridge(_bridge_pt(5.2 * S, 1.0 * S), _bridge_pt(13.8 * S, 1.5 * S), 4.4, 0.78, "#991b1b", "#450a0a", "#ef4444", 0)
	_add_walkable_bridge(_bridge_pt(-5.2 * S, 1.0 * S), _bridge_pt(-13.8 * S, 1.5 * S), 4.4, 0.78, "#991b1b", "#450a0a", "#ef4444", 0)
	_add_walkable_bridge(_bridge_pt(0.0, 5.4 * S), _bridge_pt(0.0, 13.4 * S), 4.6, 0.72, "#991b1b", "#450a0a", "#ef4444", 0)

	# 2 Elevated Carved-Stone Moon-Viewing Decks flanking the North Altar (with rim-flush approach stairs!)
	_add_walkable_deck(Vector3(-16.0, 2.25, -20.1), 4.8, "#4c3b63", "#2b1f3a", "#f472b6", 1, true)
	_add_walkable_deck(Vector3(16.0, 2.25, -20.1), 4.8, "#4c3b63", "#2b1f3a", "#f472b6", 1, true)
	_add_walkable_bridge(_bridge_pt(-7.4, -20.4), Vector3(-11.35, 2.25, -20.1), 3.0, 0.06, "#523f66", "#2f223d", "#f472b6", 0)
	_add_walkable_bridge(_bridge_pt(7.4, -20.4), Vector3(11.35, 2.25, -20.1), 3.0, 0.06, "#523f66", "#2f223d", "#f472b6", 0)

	# Twin East/West Open Shrine Pavilion Roofs (ornate corners, walkable under!)
	_add_shrine_pavilion(Vector3(26.5, get_base_terrain_height(26.5, 2.7), 2.7), "#991b1b", "#1e1b2e", 1.08)
	_add_shrine_pavilion(Vector3(-26.5, get_base_terrain_height(-26.5, 2.7), 2.7), "#991b1b", "#1e1b2e", 1.08)

	# 4 Solid Tactical Shrine Stone Columns around outer moat corners
	for cp: Vector2 in [
		Vector2(-7.8 * S, -7.8 * S), Vector2(7.8 * S, -7.8 * S),
		Vector2(-7.8 * S, 9.5 * S), Vector2(7.8 * S, 9.5 * S),
	]:
		var cy := get_base_terrain_height(cp.x, cp.y)
		_add_tactical_pillar(Vector3(cp.x, cy, cp.y), 0.85, 4.5, "#4c3b5e", "#f472b6")

	# 8 Lush Night Sakura Trees framing the terraced shrine
	var sakura_canopies: Array = []
	for tp: Vector2 in [
		Vector2(-20.5 * S, -13.0 * S), Vector2(20.5 * S, -13.0 * S),
		Vector2(-21.0 * S, 13.0 * S), Vector2(21.0 * S, 13.0 * S),
		Vector2(-12.5 * S, -21.5 * S), Vector2(12.5 * S, -21.5 * S),
		Vector2(-13.5 * S, 19.5 * S), Vector2(13.5 * S, 19.5 * S),
	]:
		var ty := get_base_terrain_height(tp.x, tp.y)
		_add_stylized_tree(Vector3(tp.x, ty, tp.y), "#3b231e", "#f472b6", 1.38)
		sakura_canopies.append({
			"pos": Vector3(tp.x, ty + 4.8 * 1.38, tp.y),
			"species": "sakura",
			"radius": 3.4 * 1.38,
		})
	set_meta("leaf_canopy_spots", sakura_canopies)

	# 8 Glowing Stone Lanterns along terraces
	for ang in [0.35, 1.15, 1.95, 2.75, -0.45, -1.15, -2.0, -2.7]:
		var lx := cos(ang) * (GameData.ARENA_RADIUS - 2.4)
		var lz := sin(ang) * (GameData.ARENA_RADIUS - 2.4)
		_add_stone_lantern(Vector3(lx, get_base_terrain_height(lx, lz), lz), "#fde047")

	# Stage Mechanic: Rotating Sakura Spirit Blessing Circle
	var pt := _sakura_spots[0]
	sakura_zone_pos = Vector3(pt.x, get_ground_height(pt.x, pt.y), pt.y)
	_sakura_zone_node = Node3D.new()
	_sakura_zone_node.position = sakura_zone_pos + Vector3(0.0, 0.08, 0.0)
	var ring_m := StandardMaterial3D.new()
	ring_m.albedo_color = Color(0.98, 0.56, 0.78, 0.85)
	ring_m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_sakura_zone_node.add_child(_make_flat_ring(sakura_zone_radius - 0.45, sakura_zone_radius, ring_m, 0.05))
	_sakura_zone_node.add_child(_make_flat_ring(2.1, 2.45, ring_m, 0.06))
	_arena_content.add_child(_sakura_zone_node)


# ==============================================================================
#  STAGE 2: MAPLE TEMPLE (Mountain Gorge + 4 Flush Timber Bridges + 3 Canopy Decks)
# ==============================================================================
func _build_maple_temple_props(_ring_col: Color) -> void:
	# Shimmering Mountain Gorge Stream in the deep ravine (y = -0.62)
	_add_water_plane(-0.62, 23.0 * S, "#0e7490", "#22d3ee", 0.58)

	_add_torii_gate(Vector3(0.0, get_base_terrain_height(0.0, -23.5 * S), -23.5 * S), "#ea580c", 1.25)

	# 4 Flush-Anchored Weathered Cedar Suspension Bridges spanning the autumn ravine!
	_add_walkable_bridge(_bridge_pt(0.0, -5.0 * S), _bridge_pt(0.0, -17.0 * S), 4.2, 0.78, "#7c4722", "#43220d", "#f59e0b", 0)
	_add_walkable_bridge(_bridge_pt(0.0, 5.0 * S), _bridge_pt(0.0, 17.0 * S), 4.2, 0.78, "#7c4722", "#43220d", "#f59e0b", 0)
	_add_walkable_bridge(_bridge_pt(5.0 * S, 0.0), _bridge_pt(17.0 * S, 0.0), 4.2, 0.78, "#7c4722", "#43220d", "#f59e0b", 0)
	_add_walkable_bridge(_bridge_pt(-5.0 * S, 0.0), _bridge_pt(-17.0 * S, 0.0), 4.2, 0.78, "#7c4722", "#43220d", "#f59e0b", 0)

	# 3 Walkable Elevated Wooden Tea-House Canopy Decks perched on outer autumn hills (rim-flush timber stairs!)
	var nw_y := maxf(2.45, get_base_terrain_height(-21.0, -17.0) + 0.95)
	var ne_y := maxf(2.45, get_base_terrain_height(21.0, -17.0) + 0.95)
	var s_y := maxf(2.25, get_base_terrain_height(0.0, 26.0) + 0.95)
	_add_walkable_deck(Vector3(-21.0, nw_y, -17.0), 5.0, "#713819", "#421d0b", "#fb923c", 1, true)
	_add_walkable_deck(Vector3(21.0, ne_y, -17.0), 5.0, "#713819", "#421d0b", "#fb923c", 1, true)
	_add_walkable_deck(Vector3(0.0, s_y, 26.0), 5.2, "#713819", "#421d0b", "#fb923c", 1, true)
	# Smooth timber stairs climbing up from surrounding hillside right onto each canopy deck rim
	_add_walkable_bridge(_bridge_pt(-27.2, -24.5), Vector3(-24.2, nw_y, -20.8), 3.0, 0.05, "#7c4722", "#43220d", "#fb923c", 0)
	_add_walkable_bridge(_bridge_pt(27.2, -24.5), Vector3(24.2, ne_y, -20.8), 3.0, 0.05, "#7c4722", "#43220d", "#fb923c", 0)
	_add_walkable_bridge(_bridge_pt(8.8, 31.0), Vector3(4.45, s_y, 28.55), 3.0, 0.05, "#7c4722", "#43220d", "#fb923c", 0)

	# Central Pagoda Sanctuary Spire (tall landmark perched at dead center, solid core!)
	_add_temple_pagoda(Vector3(0.0, get_base_terrain_height(0.0, 0.0), 0.0))

	# 4 Tactical Mossy Temple Boulders providing flank cover in the ravine & ridges
	for bp: Vector2 in [
		Vector2(-9.5 * S, -9.2 * S), Vector2(9.5 * S, -9.2 * S),
		Vector2(-9.5 * S, 9.2 * S), Vector2(9.5 * S, 9.2 * S),
	]:
		_add_mossy_boulder(Vector3(bp.x, get_base_terrain_height(bp.x, bp.y), bp.y), 1.55)

	# Perimeter Tall Realistic Segmented Bamboo Groves (batched into 1 MultiMeshInstance3D = 1 draw call!)
	var is_mob_bm := UiStyle.is_mobile_device()
	var stalk_mesh := WafuuModels3D.make_realistic_bamboo_mesh(is_mob_bm)
	stalk_mesh.surface_set_material(0, WafuuModels3D.make_wafuu_mat(5, is_mob_bm, 0.44, 0.04))
	var bamboo_xforms: Array[Transform3D] = []
	for i in range(22):
		var ang := (float(i) / 22.0) * TAU + 0.12
		if absf(ang - (-PI * 0.5)) < 0.35 or absf(ang - (PI * 1.5)) < 0.35:
			continue
		var dist := GameData.ARENA_RADIUS - 2.3 - (1.0 if i % 2 == 0 else 0.0)
		var bx := cos(ang) * dist; var bz := sin(ang) * dist
		var by := get_base_terrain_height(bx, bz)
		for offset: Vector2 in [Vector2(0.0, 0.0), Vector2(0.75, 0.55), Vector2(-0.65, 0.75)]:
			var basis := Basis.from_euler(Vector3(0.0, float(i) * 0.7 + offset.x, sin(float(i) + offset.x) * 0.06))
			bamboo_xforms.append(Transform3D(basis, Vector3(bx + offset.x, by - 0.12, bz + offset.y)))
	_add_batched_multimesh(stalk_mesh, bamboo_xforms, false)

	# 7 Crimson & Golden Maple Trees atop outer hills
	var maple_canopies: Array = []
	for mp: Vector2 in [
		Vector2(-19.5 * S, -8.5 * S), Vector2(19.5 * S, -8.5 * S),
		Vector2(-18.5 * S, 14.5 * S), Vector2(18.5 * S, 14.5 * S),
		Vector2(-11.0 * S, -21.0 * S), Vector2(11.0 * S, -21.0 * S),
		Vector2(12.5 * S, 20.0 * S),
	]:
		var my := get_base_terrain_height(mp.x, mp.y)
		_add_stylized_tree(Vector3(mp.x, my, mp.y), "#451a03", "#ea580c", 1.42)
		maple_canopies.append({
			"pos": Vector3(mp.x, my + 4.8 * 1.42, mp.y),
			"species": "maple",
			"radius": 3.4 * 1.42,
		})
	set_meta("leaf_canopy_spots", maple_canopies)

	# Stage Mechanic: 3 Swirling Emerald-Gold Wind Draft Pillars (疾風氣流)
	var wind_coords := [Vector2(-12.5 * S, 4.0 * S), Vector2(12.5 * S, 4.0 * S), Vector2(0.0, -12.5 * S)]
	var wind_mat := StandardMaterial3D.new()
	wind_mat.albedo_color = Color(0.28, 0.94, 0.72, 0.78)
	wind_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	wind_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for wc: Vector2 in wind_coords:
		var wy := get_ground_height(wc.x, wc.y)
		var wn := Node3D.new()
		wn.position = Vector3(wc.x, wy, wc.y)
		for ri in range(3):
			wn.add_child(_make_flat_ring(1.8 + float(ri) * 0.72, 2.1 + float(ri) * 0.72, wind_mat, 0.35 + float(ri) * 1.15))
		_arena_content.add_child(wn)
		wind_zones.append({"pos": Vector3(wc.x, wy, wc.y), "radius": 4.5, "node": wn})


# ==============================================================================
#  STAGE 3: ONIGASHIMA LAVA (Flowing Magma + Forged Bridges + Obsidian Fortresses)
# ==============================================================================
func _build_onigashima_lava_props(_ring_col: Color) -> void:
	_add_torii_gate(Vector3(0.0, get_base_terrain_height(0.0, -24.0 * S), -24.0 * S), "#991b1b", 1.40)

	# Animated Flowing Molten Lava Surface Plane peeking through all sunken chasms (y = -0.58)
	var lava_mesh := CylinderMesh.new()
	lava_mesh.top_radius = GameData.ARENA_RADIUS - 0.4
	lava_mesh.bottom_radius = GameData.ARENA_RADIUS - 0.4
	lava_mesh.height = 0.1
	lava_mesh.radial_segments = 36 if UiStyle.is_mobile_device() else 56
	lava_mesh.rings = 1
	var lava_shader_mat := ShaderMaterial.new()
	lava_shader_mat.shader = PROP_SURFACE_SHADER
	lava_shader_mat.set_shader_parameter("surface_type", 4)
	lava_shader_mat.set_shader_parameter("albedo_a", Color.html("#ea580c"))
	lava_shader_mat.set_shader_parameter("albedo_b", Color.html("#1c0d0a"))
	lava_shader_mat.set_shader_parameter("accent_color", Color.html("#fde047"))
	_lava_plane_mat = lava_shader_mat
	var lava_inst := MeshInstance3D.new()
	lava_inst.mesh = lava_mesh; lava_inst.material_override = _lava_plane_mat
	lava_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	lava_inst.position = Vector3(0.0, -0.58, 0.0)
	_arena_content.add_child(lava_inst)

	# 2 High-Altitude Walkable Chain-Plank Fortress Bridges spanning between Obsidian Plateaus!
	_add_walkable_bridge(Vector3(-17.0, 2.45, -17.6), Vector3(17.0, 2.45, -17.6), 4.0, 0.85, "#362f2d", "#1c1917", "#f97316", 0)
	_add_walkable_bridge(Vector3(-17.0, 2.45, 17.6), Vector3(17.0, 2.45, 17.6), 4.0, 0.85, "#362f2d", "#1c1917", "#f97316", 0)

	# 2 Ultra-High Demon Watch-Decks (+3.25m) perched above East & West rim!
	_add_walkable_deck(Vector3(26.5, 3.25, 0.0), 4.8, "#292224", "#120e10", "#f97316", 2, true)
	_add_walkable_deck(Vector3(-26.5, 3.25, 0.0), 4.8, "#292224", "#120e10", "#f97316", 2, true)
	# Walkable rim-flush ramps connecting NE/NW plateaus right to the East/West Demon Watch-Deck rims
	_add_walkable_bridge(Vector3(19.6, 2.45, -15.6), Vector3(24.8, 3.25, -4.4), 3.4, 0.18, "#362f2d", "#1c1917", "#dc2626", 0)
	_add_walkable_bridge(Vector3(-19.6, 2.45, -15.6), Vector3(-24.8, 3.25, -4.4), 3.4, 0.18, "#362f2d", "#1c1917", "#dc2626", 0)

	# 4 Tactical Obsidian Monolith Pillars around the central battle hub
	for op: Vector2 in [Vector2(0.0, -7.8), Vector2(0.0, 7.8), Vector2(7.8, 0.0), Vector2(-7.8, 0.0)]:
		_add_tactical_pillar(Vector3(op.x, get_base_terrain_height(op.x, op.y), op.y), 0.78, 3.8, "#1c1917", "#f97316")

	# Jagged Obsidian Crystal Spires crowning the outer volcanic rim (batched into 1 MultiMesh!)
	var obs_mat := StandardMaterial3D.new()
	obs_mat.albedo_color = Color.html("#1c1917"); obs_mat.roughness = 0.32; obs_mat.metallic = 0.50
	var spire_mesh := CylinderMesh.new()
	spire_mesh.top_radius = 0.06; spire_mesh.bottom_radius = 1.45; spire_mesh.height = 7.4
	spire_mesh.radial_segments = 5; spire_mesh.rings = 1
	spire_mesh.material = obs_mat
	var spire_xforms: Array[Transform3D] = []
	for sp: Vector2 in [
		Vector2(20.0 * S, -18.0 * S), Vector2(-20.0 * S, -18.0 * S),
		Vector2(20.0 * S, 18.0 * S), Vector2(-20.0 * S, 18.0 * S),
		Vector2(24.5 * S, -6.0 * S), Vector2(-24.5 * S, -6.0 * S),
		Vector2(24.5 * S, 6.0 * S), Vector2(-24.5 * S, 6.0 * S),
	]:
		var sy := get_base_terrain_height(sp.x, sp.y)
		var basis := Basis.from_euler(Vector3(0.0, 0.0, -signf(sp.x) * 0.20))
		spire_xforms.append(Transform3D(basis, Vector3(sp.x, sy + 3.2, sp.y)))
	_add_batched_multimesh(spire_mesh, spire_xforms, false)

	# 4 Flaming Oni Braziers on the 4 Obsidian Plateaus
	for bp: Vector2 in [Vector2(18.3, -17.6), Vector2(-18.3, -17.6), Vector2(18.3, 17.6), Vector2(-18.3, 17.6)]:
		_add_stone_lantern(Vector3(bp.x, get_base_terrain_height(bp.x, bp.y), bp.y), "#f97316")


# ==============================================================================
#  STAGE 4: SKY TENSHU (4 Solid Marble Bastions + 2 High Floating Decks + 4 Sky-Bridges)
# ==============================================================================
func _build_sky_tenshu_props(_ring_col: Color) -> void:
	_add_torii_gate(Vector3(0.0, get_base_terrain_height(0.0, -24.5 * S), -24.5 * S), "#f59e0b", 1.42)

	# 4 Mid-Tier Solid Celestial-Marble Bastion Platforms (+2.55m ~ +2.65m, 6.8m radius -> inner rim at 15.2m!)
	_add_walkable_deck(Vector3(0.0, 2.55, -22.0), 6.8, "#274775", "#142442", "#facc15", 3, true)
	_add_walkable_deck(Vector3(0.0, 2.55, 22.0), 6.8, "#274775", "#142442", "#facc15", 3, true)
	_add_walkable_deck(Vector3(22.0, 2.65, 0.0), 6.8, "#274775", "#142442", "#facc15", 3, true)
	_add_walkable_deck(Vector3(-22.0, 2.65, 0.0), 6.8, "#274775", "#142442", "#facc15", 3, true)

	# 2 Sovereign Upper-Tier Floating Moon-Decks (+4.25m high, sleek 0.48m slab -> >3.2m headroom underneath!)
	_add_walkable_deck(Vector3(-17.5, 4.25, -17.5), 5.4, "#1e3a6e", "#0f1e3d", "#fef08a", 3, false)
	_add_walkable_deck(Vector3(17.5, 4.25, -17.5), 5.4, "#1e3a6e", "#0f1e3d", "#fef08a", 3, false)

	# 4 Walkable Glowing Golden Sky-Bridges linking the bastion rims into an aerial ring!
	_add_walkable_bridge(Vector3(5.8, 2.55, -20.4), Vector3(20.4, 2.65, -5.8), 3.6, 0.78, "#244370", "#132240", "#facc15", 2)
	_add_walkable_bridge(Vector3(-5.8, 2.55, -20.4), Vector3(-20.4, 2.65, -5.8), 3.6, 0.78, "#244370", "#132240", "#facc15", 2)
	_add_walkable_bridge(Vector3(5.8, 2.55, 20.4), Vector3(20.4, 2.65, 5.8), 3.6, 0.78, "#244370", "#132240", "#facc15", 2)
	_add_walkable_bridge(Vector3(-5.8, 2.55, 20.4), Vector3(-20.4, 2.65, 5.8), 3.6, 0.78, "#244370", "#132240", "#facc15", 2)

	# Visual Golden Curb Posts along the 4 Ceremonial Spirit-Ramps (6.0m -> 15.2m, batched into 1 MultiMesh!)
	var curb_mat := StandardMaterial3D.new()
	curb_mat.albedo_color = Color.html("#facc15")
	curb_mat.metallic = 0.65
	curb_mat.roughness = 0.25
	var curb_mesh := BoxMesh.new()
	curb_mesh.size = Vector3(0.26, 0.65, 0.26)
	curb_mesh.material = curb_mat
	var curb_xforms: Array[Transform3D] = []
	for dist in [6.8, 9.6, 12.4, 14.8]:
		for side in [-2.35, 2.35]:
			for pt: Vector2 in [
				Vector2(side, -dist), Vector2(side, dist),
				Vector2(dist, side), Vector2(-dist, side),
			]:
				curb_xforms.append(Transform3D(Basis.IDENTITY, Vector3(pt.x, get_base_terrain_height(pt.x, pt.y) + 0.30, pt.y)))
	_add_batched_multimesh(curb_mesh, curb_xforms, false)

	# 4 Ornate Golden Castle Columns guarding the central Tenshu courtyard
	for cp: Vector2 in [Vector2(-8.8, -8.8), Vector2(8.8, -8.8), Vector2(-8.8, 8.8), Vector2(8.8, 8.8)]:
		_add_tactical_pillar(Vector3(cp.x, get_base_terrain_height(cp.x, cp.y), cp.y), 0.78, 5.0, "#1e293b", "#facc15")

	# 6 Glowing Cloud Jump Pads (4 Courtyard + 2 Mid-Tier launching up to Sovereign +4.25m Moon-Decks!)
	var pad_mat := StandardMaterial3D.new()
	pad_mat.albedo_color = Color(0.38, 0.90, 1.0, 0.92)
	pad_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pad_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var gold_rim_mat := StandardMaterial3D.new()
	gold_rim_mat.albedo_color = Color.html("#facc15")
	gold_rim_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	var pad_coords := [
		Vector3(12.5, 0.0, -12.5), Vector3(-12.5, 0.0, -12.5),
		Vector3(12.5, 0.0, 12.5), Vector3(-12.5, 0.0, 12.5),
		Vector3(21.2, 2.65, -5.2), Vector3(-21.2, 2.65, -5.2),
	]
	for jp: Vector3 in pad_coords:
		var jy: float = jp.y if jp.y > 0.5 else get_base_terrain_height(jp.x, jp.z)
		var jn := Node3D.new()
		jn.position = Vector3(jp.x, jy, jp.z)
		jn.add_child(_make_flat_ring(1.3, 2.25, pad_mat, 0.14))
		jn.add_child(_make_flat_ring(0.5, 0.95, gold_rim_mat, 0.24))
		_arena_content.add_child(jn)
		jump_pads.append({"pos": Vector3(jp.x, jy, jp.z), "radius": 2.7, "node": jn})

	# Soft Floating Cloud Banks beneath the castle horizon
	var cloud_mat := StandardMaterial3D.new()
	cloud_mat.albedo_color = Color(0.75, 0.88, 1.0, 0.28)
	cloud_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cloud_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var cm := SphereMesh.new()
	cm.radius = 6.5; cm.height = 3.0; cm.radial_segments = 10; cm.rings = 5
	cm.material = cloud_mat
	var cloud_xforms: Array[Transform3D] = []
	var cloud_r := GameData.ARENA_RADIUS + 9.0
	for ci in range(8):
		var a := (float(ci) / 8.0) * TAU
		cloud_xforms.append(Transform3D(Basis.IDENTITY, Vector3(cos(a) * cloud_r, -1.5 + sin(float(ci)) * 1.5, sin(a) * cloud_r)))
	_add_batched_multimesh(cm, cloud_xforms, false)

	# Giant Luminous Full Moon perched high beyond the North Torii (low-poly sphere, no shadows!)
	var moon := MeshInstance3D.new()
	var ms := SphereMesh.new(); ms.radius = 8.4; ms.height = 16.8; ms.radial_segments = 16; ms.rings = 10
	var mm := StandardMaterial3D.new()
	mm.albedo_color = Color.html("#fef9c3"); mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	moon.mesh = ms; moon.material_override = mm
	moon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	moon.position = Vector3(0.0, 24.5, -64.0)
	_arena_content.add_child(moon)


# ==============================================================================
#  SHARED ARCHITECTURAL PROP, BRIDGE, DECK & OBSTACLE HELPERS
# ==============================================================================
func _add_batched_multimesh(mesh: Mesh, transforms: Array[Transform3D], cast_shadows: bool = false) -> void:
	if transforms.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = transforms.size()
	for i in range(transforms.size()):
		mm.set_instance_transform(i, transforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	if not cast_shadows:
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_arena_content.add_child(mmi)


func _add_water_plane(y_level: float, rad: float, deep_hex: String, shallow_hex: String, alpha: float) -> void:
	var wm := CylinderMesh.new()
	wm.top_radius = rad; wm.bottom_radius = rad; wm.height = 0.08
	wm.radial_segments = 32 if UiStyle.is_mobile_device() else 48
	wm.rings = 1
	var wmat := ShaderMaterial.new()
	wmat.shader = WATER_SHADER
	var dc := Color.html(deep_hex)
	var sc := Color.html(shallow_hex)
	wmat.set_shader_parameter("deep_color", Color(dc.r, dc.g, dc.b, alpha + 0.14))
	wmat.set_shader_parameter("shallow_color", Color(sc.r, sc.g, sc.b, alpha))
	wmat.set_shader_parameter("glint_color", Color.html("#e0f2fe"))
	_water_plane_mat = wmat
	var wi := MeshInstance3D.new()
	wi.mesh = wm; wi.material_override = _water_plane_mat
	wi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	wi.position = Vector3(0.0, y_level, 0.0)
	_arena_content.add_child(wi)


func _add_walkable_deck(top_pos: Vector3, rad: float, deck_hex: String, deck_dark_hex: String, rim_hex: String, surface_type: int = 1, grounded: bool = true) -> void:
	var terrain_below := get_base_terrain_height(top_pos.x, top_pos.z)
	var deck_h: float = maxf(1.2, top_pos.y - terrain_below + 0.85) if grounded else 0.48
	platforms.append({"pos": top_pos, "radius": rad, "grounded": grounded, "slab_h": deck_h})

	var deck_mat := ShaderMaterial.new()
	deck_mat.shader = PROP_SURFACE_SHADER
	deck_mat.set_shader_parameter("surface_type", surface_type)
	deck_mat.set_shader_parameter("albedo_a", Color.html(deck_hex))
	deck_mat.set_shader_parameter("albedo_b", Color.html(deck_dark_hex))
	deck_mat.set_shader_parameter("accent_color", Color.html(rim_hex))
	deck_mat.set_shader_parameter("roughness_val", 0.36 if surface_type == 3 else 0.56)
	deck_mat.set_shader_parameter("metallic_val", 0.32 if surface_type >= 2 else 0.14)
	deck_mat.set_shader_parameter("emission_strength", 0.35 if surface_type >= 2 else 0.0)

	var rim_mat := StandardMaterial3D.new()
	rim_mat.albedo_color = Color.html(rim_hex); rim_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	var cyl := CylinderMesh.new()
	cyl.top_radius = rad
	cyl.bottom_radius = rad * (0.96 if grounded else 0.82)
	cyl.height = deck_h
	cyl.radial_segments = 20 if UiStyle.is_mobile_device() else 28
	cyl.rings = 1
	var deck := MeshInstance3D.new()
	deck.mesh = cyl; deck.material_override = deck_mat
	deck.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	deck.position = Vector3(top_pos.x, top_pos.y - deck_h * 0.5, top_pos.z)
	_arena_content.add_child(deck)

	var rim := _make_flat_ring(rad - 0.32, rad + 0.06, rim_mat, top_pos.y + 0.04)
	rim.position.x = top_pos.x; rim.position.z = top_pos.z
	_arena_content.add_child(rim)


func _add_walkable_bridge(start_p: Vector3, end_p: Vector3, width: float, arch: float, deck_hex: String, deck_dark_hex: String, rail_hex: String, surface_type: int = 0) -> void:
	bridges.append({"start": start_p, "end": end_p, "width": width, "arch": arch})

	var deck_mat := ShaderMaterial.new()
	deck_mat.shader = PROP_SURFACE_SHADER
	deck_mat.set_shader_parameter("surface_type", surface_type)
	deck_mat.set_shader_parameter("albedo_a", Color.html(deck_hex))
	deck_mat.set_shader_parameter("albedo_b", Color.html(deck_dark_hex))
	deck_mat.set_shader_parameter("accent_color", Color.html(rail_hex))
	deck_mat.set_shader_parameter("roughness_val", 0.62 if surface_type == 0 else 0.34)
	deck_mat.set_shader_parameter("metallic_val", 0.08 if surface_type == 0 else 0.38)
	deck_mat.set_shader_parameter("emission_strength", 0.25 if surface_type == 2 else 0.0)
	deck_mat.set_shader_parameter("tile_scale", width * 0.55)

	var rail_mat := StandardMaterial3D.new()
	rail_mat.albedo_color = Color.html(rail_hex); rail_mat.roughness = 0.40; rail_mat.metallic = 0.20

	var dir3 := end_p - start_p
	var total_len := Vector2(dir3.x, dir3.z).length()
	var dy_total := end_p.y - start_p.y
	var yaw := atan2(dir3.x, dir3.z)

	# Merge all bridge planks into 1 ArrayMesh and rails+posts into 1 ArrayMesh (2 draw calls total!)
	# Built in bridge-local space (+Z along bridge, X across width) so PROP_SURFACE_SHADER planks align cleanly.
	var segs := 8
	var seg_len := (total_len / float(segs)) * 1.08
	var plank_box := BoxMesh.new(); plank_box.size = Vector3(width, 0.24, seg_len)
	var rail_box := BoxMesh.new(); rail_box.size = Vector3(0.16, 0.18, seg_len)
	var post_box := BoxMesh.new(); post_box.size = Vector3(0.22, 0.92, 0.22)

	var st_planks := SurfaceTool.new()
	st_planks.begin(Mesh.PRIMITIVE_TRIANGLES)
	var st_rails := SurfaceTool.new()
	st_rails.begin(Mesh.PRIMITIVE_TRIANGLES)

	for i in range(segs):
		var t0 := float(i) / float(segs)
		var t1 := float(i + 1) / float(segs)
		var z0 := t0 * total_len
		var z1 := t1 * total_len
		var y0 := dy_total * t0 + sin(t0 * PI) * arch
		var y1 := dy_total * t1 + sin(t1 * PI) * arch
		var zm := (z0 + z1) * 0.5
		var ym := (y0 + y1) * 0.5
		var pitch := -atan2(y1 - y0, maxf(0.001, z1 - z0))
		var tilt_basis := Basis(Vector3.RIGHT, pitch)

		st_planks.append_from(plank_box, 0, Transform3D(tilt_basis, Vector3(0.0, ym - 0.12, zm)))
		for side: float in [-1.0, 1.0]:
			var sx: float = side * (width * 0.48)
			st_rails.append_from(rail_box, 0, Transform3D(tilt_basis, Vector3(sx, ym + 0.72, zm)))
			if i % 2 == 0:
				st_rails.append_from(post_box, 0, Transform3D(Basis.IDENTITY, Vector3(sx, ym + 0.42, zm)))

	var bridge_root := Node3D.new()
	bridge_root.position = start_p
	bridge_root.rotation.y = yaw

	var planks_inst := MeshInstance3D.new()
	planks_inst.mesh = st_planks.commit()
	planks_inst.material_override = deck_mat
	planks_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	bridge_root.add_child(planks_inst)

	var rails_inst := MeshInstance3D.new()
	rails_inst.mesh = st_rails.commit()
	rails_inst.material_override = rail_mat
	rails_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	bridge_root.add_child(rails_inst)

	_arena_content.add_child(bridge_root)


func _add_tactical_pillar(base_pos: Vector3, rad: float, height: float, stone_hex: String, trim_hex: String) -> void:
	obstacles.append({"pos": Vector2(base_pos.x, base_pos.z), "radius": rad + 0.15, "top_y": base_pos.y + height})

	var smat := StandardMaterial3D.new()
	smat.albedo_color = Color.html(stone_hex); smat.roughness = 0.65; smat.metallic = 0.22
	var tmat := StandardMaterial3D.new()
	tmat.albedo_color = Color.html(trim_hex); tmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	var col := MeshInstance3D.new()
	var cm := CylinderMesh.new(); cm.top_radius = rad * 0.85; cm.bottom_radius = rad; cm.height = height; cm.radial_segments = 8; cm.rings = 1
	col.mesh = cm; col.material_override = smat
	col.position = base_pos + Vector3(0.0, height * 0.5, 0.0)
	_arena_content.add_child(col)

	var ring := _make_flat_ring(rad * 0.82, rad * 1.12, tmat, base_pos.y + height - 0.35)
	ring.position.x = base_pos.x; ring.position.z = base_pos.z
	_arena_content.add_child(ring)


func _add_mossy_boulder(base_pos: Vector3, rad: float) -> void:
	WafuuModels3D.add_mossy_boulder(self, _arena_content, base_pos, rad)


func _add_shrine_pavilion(base_pos: Vector3, pillar_hex: String, roof_hex: String, sc: float = 1.0) -> void:
	WafuuModels3D.add_shrine_pavilion(self, _arena_content, base_pos, pillar_hex, roof_hex, sc)


func _add_temple_pagoda(base_pos: Vector3) -> void:
	WafuuModels3D.add_temple_pagoda(self, _arena_content, base_pos)


func _add_torii_gate(base_pos: Vector3, pillar_hex: String, sc: float = 1.0) -> void:
	WafuuModels3D.add_torii_gate(_arena_content, base_pos, pillar_hex, sc, sc >= 1.2)


func _add_stone_lantern(base_pos: Vector3, glow_hex: String) -> void:
	WafuuModels3D.add_stone_lantern(_arena_content, base_pos, glow_hex)


func _add_stylized_tree(base_pos: Vector3, trunk_hex: String, leaf_hex: String, sc: float = 1.0) -> void:
	var variant: int = int(absf(base_pos.x * 3.0 + base_pos.z * 7.0)) % 3
	WafuuModels3D.add_realistic_tree(_arena_content, base_pos, trunk_hex, leaf_hex, sc, variant)


func _build_ambient_particles(particle_col: Color) -> void:
	var is_mob := UiStyle.is_mobile_device()
	_particles = CPUParticles3D.new()
	_particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_particles.amount = 45 if is_mob else 110
	_particles.lifetime = 8.0
	_particles.preprocess = 4.0
	_particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_particles.emission_box_extents = Vector3(GameData.ARENA_RADIUS + 2.0, 1.0, GameData.ARENA_RADIUS + 2.0)
	_particles.position = Vector3(0.0, 16.0, 0.0)
	_particles.direction = Vector3(0.15, -1.0, 0.1)
	_particles.spread = 20.0
	_particles.gravity = Vector3(0.0, -0.15, 0.0)
	_particles.initial_velocity_min = 1.2
	_particles.initial_velocity_max = 2.0

	var p_mesh := QuadMesh.new(); p_mesh.size = Vector2(0.28, 0.28)
	var p_mat := StandardMaterial3D.new()
	p_mat.albedo_color = particle_col
	p_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	p_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	p_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	p_mat.albedo_color.a = 0.85
	p_mesh.material = p_mat
	_particles.mesh = p_mesh
	_arena_content.add_child(_particles)


func _make_flat_ring(inner_r: float, outer_r: float, mat: Material, y_pos: float) -> MeshInstance3D:
	var torus := TorusMesh.new()
	torus.inner_radius = inner_r; torus.outer_radius = outer_r
	torus.rings = 24 if UiStyle.is_mobile_device() else 36
	torus.ring_segments = 6
	var inst := MeshInstance3D.new()
	inst.mesh = torus; inst.material_override = mat
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	inst.position = Vector3(0.0, y_pos, 0.0)
	inst.scale = Vector3(1.0, 0.08, 1.0)
	return inst


func _build_sky_landmarks() -> void:
	match current_stage_id:
		"sakura_shrine":
			# 14 Glowing Wafuu Sky Lanterns (天燈) softly drifting outside the 38m arena rim
			var lantern_mesh := CylinderMesh.new()
			lantern_mesh.top_radius = 0.62; lantern_mesh.bottom_radius = 0.38; lantern_mesh.height = 1.40; lantern_mesh.radial_segments = 6; lantern_mesh.rings = 1
			var warm_mat := StandardMaterial3D.new()
			warm_mat.albedo_color = Color.html("#fde68a")
			warm_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			var pink_mat := StandardMaterial3D.new()
			pink_mat.albedo_color = Color.html("#f9a8d4")
			pink_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

			for i in range(14):
				var ang := (float(i) / 14.0) * TAU + 0.25
				var dist := GameData.ARENA_RADIUS + 8.0 + float(i % 3) * 8.0
				var y_base := 11.5 + float(i % 4) * 4.5
				var pos := Vector3(cos(ang) * dist, y_base, sin(ang) * dist)
				var lan := MeshInstance3D.new()
				lan.mesh = lantern_mesh
				lan.material_override = warm_mat if i % 2 == 0 else pink_mat
				lan.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				lan.position = pos
				_arena_content.add_child(lan)
				_sky_anim_nodes.append({"node": lan, "kind": "bob", "base_pos": pos, "speed": 0.65 + float(i % 3) * 0.22, "phase": float(i) * 1.3, "amp": 1.45})

			# 6 Drifting Moonlit Sakura Cloud Puffs
			_add_sky_cloud_ring(6, 64.0, 22.0, Color(0.95, 0.72, 0.86, 0.34), 0.03)

		"maple_temple":
			# 8 Golden-Rimmed Sunset Cloud Ribbons
			_add_sky_cloud_ring(8, 65.0, 19.5, Color(1.0, 0.74, 0.44, 0.44), 0.045)

			# 8 Stylized Circling Autumn Sky Cranes (紙鶴・飛鳥) overhead
			var bird_mat := StandardMaterial3D.new()
			bird_mat.albedo_color = Color.html("#fef3c7")
			bird_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			var st_bird := SurfaceTool.new()
			st_bird.begin(Mesh.PRIMITIVE_TRIANGLES)
			var wing_mesh := BoxMesh.new()
			wing_mesh.size = Vector3(1.65, 0.08, 0.44)
			st_bird.append_from(wing_mesh, 0, Transform3D(Basis.from_euler(Vector3(0.0, 0.0, 0.24)), Vector3(-0.72, 0.0, 0.0)))
			st_bird.append_from(wing_mesh, 0, Transform3D(Basis.from_euler(Vector3(0.0, 0.0, -0.24)), Vector3(0.72, 0.0, 0.0)))
			var bird_mesh := st_bird.commit()
			for i in range(8):
				var b_inst := MeshInstance3D.new()
				b_inst.mesh = bird_mesh
				b_inst.material_override = bird_mat
				b_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				var rad := 41.0 + float(i % 3) * 6.5
				var y_h := 19.5 + float(i % 4) * 2.4
				_arena_content.add_child(b_inst)
				_sky_anim_nodes.append({"node": b_inst, "kind": "orbit", "base_pos": Vector3(0.0, y_h, 0.0), "radius": rad, "speed": 0.16 + float(i % 2) * 0.04, "phase": float(i) * 0.78})

		"onigashima_lava":
			# 6 Towering Distant Volcanic Caldera Peaks glowing at their base (batched into 1 MultiMesh!)
			var peak_mat := StandardMaterial3D.new()
			peak_mat.albedo_color = Color.html("#1c1012"); peak_mat.roughness = 0.90
			var peak_mesh := CylinderMesh.new()
			peak_mesh.top_radius = 1.6; peak_mesh.bottom_radius = 14.0; peak_mesh.height = 28.0; peak_mesh.radial_segments = 7; peak_mesh.rings = 1
			peak_mesh.material = peak_mat
			var peak_xforms: Array[Transform3D] = []
			for i in range(6):
				var ang := (float(i) / 6.0) * TAU + 0.52
				var dist := 68.0 + float(i % 2) * 10.0
				peak_xforms.append(Transform3D(Basis.IDENTITY, Vector3(cos(ang) * dist, 6.5 + float(i % 2) * 3.5, sin(ang) * dist)))
			_add_batched_multimesh(peak_mesh, peak_xforms, false)

			# High-Altitude Swirling Ember Storm Vortex Rings overhead
			var storm_mat := StandardMaterial3D.new()
			storm_mat.albedo_color = Color(0.95, 0.32, 0.08, 0.34)
			storm_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			storm_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			for ri in range(2):
				var ring := _make_flat_ring(22.0 + float(ri) * 14.0, 29.0 + float(ri) * 15.0, storm_mat, 26.0 + float(ri) * 5.0)
				_arena_content.add_child(ring)
				_sky_anim_nodes.append({"node": ring, "kind": "spin", "speed": 0.25 if ri == 0 else -0.18})

		"sky_tenshu":
			# Dual Counter-Rotating Celestial Astrolabe Halo Rings orbiting the Giant Full Moon (lockstep at z=-64)!
			var halo_mat := StandardMaterial3D.new()
			halo_mat.albedo_color = Color(1.0, 0.90, 0.45, 0.78)
			halo_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			halo_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			for hi in range(2):
				var torus := TorusMesh.new()
				torus.inner_radius = 10.8 + float(hi) * 2.8
				torus.outer_radius = 11.3 + float(hi) * 2.8
				torus.rings = 28 if UiStyle.is_mobile_device() else 40
				torus.ring_segments = 6
				var h_inst := MeshInstance3D.new()
				h_inst.mesh = torus; h_inst.material_override = halo_mat
				h_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				h_inst.position = Vector3(0.0, 24.5, -64.0)
				h_inst.rotation = Vector3(PI * 0.42 if hi == 0 else PI * 0.58, 0.0, 0.25 if hi == 0 else -0.35)
				_arena_content.add_child(h_inst)
				_sky_anim_nodes.append({"node": h_inst, "kind": "tumble", "speed": 0.32 if hi == 0 else -0.24})

			# 4 Distant Floating Sky-Shrine Islands with Silhouetted Pagodas in the Sea of Clouds
			var isl_mat := StandardMaterial3D.new()
			isl_mat.albedo_color = Color.html("#1e3a5f"); isl_mat.roughness = 0.65
			var gold_mat := StandardMaterial3D.new()
			gold_mat.albedo_color = Color.html("#fde047"); gold_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			var st_isl := SurfaceTool.new()
			st_isl.begin(Mesh.PRIMITIVE_TRIANGLES)
			var rm := CylinderMesh.new(); rm.top_radius = 5.4; rm.bottom_radius = 0.7; rm.height = 6.2; rm.radial_segments = 7; rm.rings = 1
			var sm := CylinderMesh.new(); sm.top_radius = 0.22; sm.bottom_radius = 3.0; sm.height = 4.8; sm.radial_segments = 4; sm.rings = 1
			st_isl.append_from(rm, 0, Transform3D.IDENTITY)
			st_isl.append_from(sm, 0, Transform3D(Basis.IDENTITY, Vector3(0.0, 5.2, 0.0)))
			var isl_mesh := st_isl.commit()
			var bm := SphereMesh.new(); bm.radius = 0.65; bm.height = 1.3; bm.radial_segments = 8; bm.rings = 5
			for i in range(4):
				var ang := (float(i) / 4.0) * TAU + PI * 0.25
				var dist := 70.0
				var pos := Vector3(cos(ang) * dist, 6.5 + float(i % 2) * 3.8, sin(ang) * dist)
				var isl := Node3D.new()
				isl.position = pos
				var body := MeshInstance3D.new()
				body.mesh = isl_mesh; body.material_override = isl_mat; body.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				isl.add_child(body)
				var beacon := MeshInstance3D.new()
				beacon.mesh = bm; beacon.material_override = gold_mat; beacon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				beacon.position = Vector3(0.0, 8.2, 0.0)
				isl.add_child(beacon)
				_arena_content.add_child(isl)
				_sky_anim_nodes.append({"node": isl, "kind": "bob", "base_pos": pos, "speed": 0.55, "phase": float(i) * 1.5, "amp": 0.9})

			# Upper Moonlit Cloud Ring
			_add_sky_cloud_ring(7, 64.0, 19.0, Color(0.84, 0.92, 1.0, 0.34), 0.035)


func _add_sky_cloud_ring(count: int, ring_radius: float, y_base: float, tint: Color, orbit_speed: float) -> void:
	var cloud_mat := StandardMaterial3D.new()
	cloud_mat.albedo_color = tint
	cloud_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cloud_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var puff_a := SphereMesh.new(); puff_a.radius = 6.2; puff_a.height = 3.0; puff_a.radial_segments = 10; puff_a.rings = 5
	var puff_b := SphereMesh.new(); puff_b.radius = 4.2; puff_b.height = 2.3; puff_b.radial_segments = 8; puff_b.rings = 4

	# Merge entire cloud ring into 1 single MeshInstance3D = 1 draw call!
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(count):
		var ang := (float(i) / float(count)) * TAU
		var grp_xform := Transform3D(Basis.from_euler(Vector3(0.0, -ang, 0.0)), Vector3(cos(ang) * ring_radius, y_base + sin(float(i) * 2.1) * 3.0, sin(ang) * ring_radius))
		st.append_from(puff_a, 0, grp_xform)
		st.append_from(puff_b, 0, grp_xform * Transform3D(Basis.IDENTITY, Vector3(0.0, -0.4, 4.4)))
		st.append_from(puff_b, 0, grp_xform * Transform3D(Basis.IDENTITY, Vector3(0.0, -0.3, -4.2)))

	var ring_inst := MeshInstance3D.new()
	ring_inst.mesh = st.commit()
	ring_inst.material_override = cloud_mat
	ring_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_arena_content.add_child(ring_inst)
	_sky_anim_nodes.append({"node": ring_inst, "kind": "spin", "speed": orbit_speed})


func _process(delta: float) -> void:
	var dt := minf(0.05, delta)
	_elapsed += dt
	if _splash_time < 4.0:
		_splash_time += dt
		if has_meta("interactive_water_mats"):
			for m in get_meta("interactive_water_mats"):
				if m is ShaderMaterial:
					(m as ShaderMaterial).set_shader_parameter("splash_time", _splash_time)
		elif _water_plane_mat is ShaderMaterial:
			(_water_plane_mat as ShaderMaterial).set_shader_parameter("splash_time", _splash_time)
	if _gust_time < 3.0:
		_gust_time += dt
		if has_meta("interactive_foliage_mats"):
			for m in get_meta("interactive_foliage_mats"):
				if m is ShaderMaterial:
					(m as ShaderMaterial).set_shader_parameter("gust_time", _gust_time)
		for wm in _wafuu_wind_mats:
			if is_instance_valid(wm) and wm.shader != null and wm.shader.resource_path.ends_with("tree_leaves_alpha.gdshader"):
				wm.set_shader_parameter("gust_time", _gust_time)

	if _sakura_zone_node != null and is_instance_valid(_sakura_zone_node):
		_sakura_zone_node.rotation.y = _elapsed * 1.15
	for wz in wind_zones:
		var n: Node3D = wz["node"]
		if is_instance_valid(n):
			n.rotation.y = _elapsed * 3.8
	for jp in jump_pads:
		var n: Node3D = jp["node"]
		if is_instance_valid(n):
			n.rotation.y = _elapsed * 2.4
			n.position.y = float(jp["pos"].y) + sin(_elapsed * 4.5) * 0.08
	for sk in _sky_anim_nodes:
		var sn: Node3D = sk["node"]
		if not is_instance_valid(sn):
			continue
		var kind: String = sk["kind"]
		if kind == "bob":
			var bp: Vector3 = sk["base_pos"]
			var spd: float = float(sk["speed"])
			var ph: float = float(sk["phase"])
			var amp: float = float(sk["amp"])
			sn.position.y = bp.y + sin(_elapsed * spd + ph) * amp
			sn.rotation.y = _elapsed * 0.25 + ph
		elif kind == "orbit":
			var bp: Vector3 = sk["base_pos"]
			var r: float = float(sk["radius"])
			var ang: float = _elapsed * float(sk["speed"]) + float(sk["phase"])
			sn.position = Vector3(cos(ang) * r, bp.y + sin(ang * 2.0) * 1.2, sin(ang) * r)
			sn.rotation.y = -ang
		elif kind == "spin":
			sn.rotation.y = _elapsed * float(sk["speed"])
		elif kind == "tumble":
			sn.rotation.y = _elapsed * float(sk["speed"])
			sn.rotation.z = sin(_elapsed * 0.5) * 0.32
		elif kind == "float_boat":
			var bp: Vector3 = sk["base_pos"]
			var base_yaw: float = float(sk.get("base_yaw", 0.0))
			var ph: float = float(sk.get("phase", 0.0))
			var wf: float = 0.70 + 0.30 * _current_wind_strength
			var t_w: float = _elapsed * 1.15
			var heave: float = (sin(t_w * 1.85 + ph) * 0.048 + cos(t_w * 1.25 - ph) * 0.026) * wf
			var pitch_w: float = cos(t_w * 1.55 + ph) * 0.045 * wf
			var roll_w: float = sin(t_w * 1.95 + ph * 1.3) * 0.068 * wf
			sn.position = Vector3(bp.x + sin(t_w * 0.55 + ph) * 0.06, bp.y + heave, bp.z + cos(t_w * 0.45 + ph) * 0.05)
			sn.rotation = Vector3(pitch_w, base_yaw + sin(t_w * 0.42 + ph) * 0.05, roll_w)
		elif kind == "koi_swim":
			var ctr: Vector3 = sk["center"]
			var rx: float = float(sk.get("rx", 4.0))
			var rz: float = float(sk.get("rz", 3.0))
			var spd: float = float(sk.get("speed", 0.45))
			var ph: float = float(sk.get("phase", 0.0))
			var ang: float = _elapsed * spd + ph
			var nx: float = ctr.x + cos(ang) * rx
			var nz: float = ctr.z + sin(ang) * rz
			var vx: float = -sin(ang) * rx * spd
			var vz: float = cos(ang) * rz * spd
			var wiggle: float = sin(_elapsed * 7.2 + ph * 2.0) * 0.11
			sn.position = Vector3(nx, ctr.y + sin(_elapsed * 1.6 + ph) * 0.03, nz)
			sn.rotation = Vector3(0.0, atan2(vx, vz) + wiggle, wiggle * 0.35)
	if _lava_plane_mat is StandardMaterial3D:
		(_lava_plane_mat as StandardMaterial3D).emission_energy_multiplier = 1.45 + sin(_elapsed * 3.2) * 0.30
