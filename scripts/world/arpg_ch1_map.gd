class_name ArpgCh1Map
extends RefCounted
## Procedurally builds the expanded 240m × 280m Japanese Coastal Fjord, Mountain & Open Wilderness Map
## for Chapter 1: 「第一章：櫻花之里・失落的言靈碑」 (X: [-120, 120], Z: [-140, 140]).
## Features: Seaside Fjord Golden Beach spawn beside towering 50m Mount Sakuradake (櫻岳高山),
## hikeable mountain cliff overlook trail, sprawling coastal wildflower wilderness, cozy Sakura Village,
## winding Koi River & Moonlit Lake, Bamboo & Maple Mountain Gorge, 10-gate Senbon Torii ascent,
## elevated Full-Moon Night-Sakura Grand Altar, and 4 batched real-leaf MultiMesh wilderness forests.

const MIN_X: float = -120.0
const MAX_X: float = 120.0
const MIN_Z: float = -140.0
const MAX_Z: float = 140.0
const MAP_CENTER_Z: float = 0.0

const WATER_LEVEL: float = -0.42
const FJORD_BAY_CENTER: Vector2 = Vector2(0.0, 126.0)
const LAKE_CENTER: Vector2 = Vector2(56.0, 16.0)
const LAKE_RX: float = 24.0
const LAKE_RZ: float = 17.0

const SPRING_POS_2D: Vector2 = Vector2(-18.0, -72.0)
const SPRING_RADIUS: float = 5.2

# Walkable coastal mountain trail endpoints (beach-meadow foot -> scenic 9.5m cliff overlook terrace)
const TRAIL_START_2D: Vector2 = Vector2(-21.0, 96.0)
const TRAIL_END_2D: Vector2 = Vector2(-42.0, 72.0)


static func _smooth01(t: float) -> float:
	var c: float = clampf(t, 0.0, 1.0)
	return c * c * (3.0 - 2.0 * c)


static func _smax(a: float, b: float, k: float) -> float:
	var h: float = maxf(k - absf(a - b), 0.0) / k
	return maxf(a, b) + h * h * k * 0.25


static func _lake_norm_dist(x: float, z: float) -> float:
	var lx: float = (x - LAKE_CENTER.x) / LAKE_RX
	var lz: float = (z - LAKE_CENTER.y) / LAKE_RZ
	return sqrt(lx * lx + lz * lz)


static func _coastal_trail_x(z: float) -> float:
	if z < 42.0 or z > 100.0:
		return 0.0
	var u: float = clampf((z - 43.0) / 55.0, 0.0, 1.0)
	return sin(u * TAU) * 4.8 * sin(u * PI)


static func _river_center_z(x: float) -> float:
	return 8.0 + sin(x * 0.045) * 2.4


static func _fjord_shore_z(x: float) -> float:
	var xn: float = clampf(absf(x) / 34.0, 0.0, 1.35)
	return 112.0 + xn * xn * 6.2


static func _mountain_trail_info(x: float, z: float) -> Vector2:
	# Returns Vector2(distance_to_segment, param_t) along TRAIL_START_2D -> TRAIL_END_2D
	var p := Vector2(x, z)
	var ab: Vector2 = TRAIL_END_2D - TRAIL_START_2D
	var ab_len_sq: float = maxf(0.001, ab.length_squared())
	var t: float = clampf((p - TRAIL_START_2D).dot(ab) / ab_len_sq, 0.0, 1.0)
	var closest: Vector2 = TRAIL_START_2D + ab * t
	return Vector2(p.distance_to(closest), t)


# ==============================================================================
#  1. EXACT ANALYTICAL TERRAIN HEIGHT & BIOME QUERIES
# ==============================================================================
static func get_base_terrain_height(x: float, z: float) -> float:
	# Base longitudinal datum:
	# - Seaside Fjord Beach (z ~ 104): ~0.35m (dry golden beach sand)
	# - Sakura Village (z: 16..42): ~0.50m
	# - Bamboo & Maple Wilderness (z: -56..0): gentle rise 0.55m -> 0.85m
	# - Senbon Torii Ascent (z: -96..-56): smooth climb 0.85m -> 4.60m (~5.4 deg slope)
	# - Grand Night-Sakura Altar (z: -140..-96): flat plateau at 4.60m
	var h: float = 0.50
	h -= 0.15 * _smooth01((z - 86.0) / 16.0)
	h += 0.35 * _smooth01((2.0 - z) / 56.0)
	h += 3.75 * _smooth01((-z - 56.0) / 40.0)

	# --------------------------------------------------------------------------
	# A. COASTAL WILDERNESS & FLOWER HILLS (z: +44 .. +98, X: -40 .. +115)
	# --------------------------------------------------------------------------
	var coastal_mask: float = _smooth01((z - 42.0) / 9.0) * (1.0 - _smooth01((z - 94.0) / 10.0))
	if coastal_mask > 0.0001:
		var road_cx: float = _coastal_trail_x(z)
		var road_fade: float = _smooth01((absf(x - road_cx) - 4.4) / 7.5)
		var east_lift: float = _smooth01((x - 16.0) / 48.0) * 2.4
		var hills: float = (
			1.25
			+ 1.15 * sin(x * 0.055 + 0.6) * cos(z * 0.062 - 0.4)
			+ 0.65 * sin((x * 0.082 - z * 0.074) + 1.1)
			+ east_lift
		)
		h += maxf(0.0, hills) * coastal_mask * road_fade

	# --------------------------------------------------------------------------
	# B. BAMBOO, MAPLE & MOUNTAIN WILDERNESS (z: -58 .. +4)
	# --------------------------------------------------------------------------
	var wild_mask: float = _smooth01((4.0 - z) / 7.0) * _smooth01((z + 60.0) / 8.0)
	if wild_mask > 0.0001:
		var road_fade: float = _smooth01((absf(x) - 6.0) / 8.5)
		var east_br_fade: float = 1.0 - (1.0 - _smooth01((absf(x - 24.0) - 4.2) / 5.5)) * _smooth01((z + 10.0) / 10.0)
		var ambush_fade: float = _smooth01((Vector2(x - 2.0, z + 34.0).length() - 10.5) / 7.0)
		var lake_clear: float = _smooth01((_lake_norm_dist(x, z) - 1.12) / 0.32)
		var roll: float = (
			0.95
			+ 1.35 * sin(x * 0.048 + 0.3) * cos(z * 0.058 - 0.5)
			+ 0.72 * cos((x * 0.075 + z * 0.068) - 0.8)
		)
		h += maxf(0.0, roll) * wild_mask * road_fade * east_br_fade * ambush_fade * lake_clear

	# Outer East & West Wilderness Mountain Ridges (|x| > 64, z: -96 .. +42)
	var ridge_z_mask: float = _smooth01((z + 100.0) / 14.0) * (1.0 - _smooth01((z - 38.0) / 16.0))
	if ridge_z_mask > 0.0001 and absf(x) > 58.0:
		var outer_t: float = _smooth01((absf(x) - 62.0) / 52.0)
		var crag: float = 0.78 + 0.22 * sin(z * 0.085 + signf(x) * 1.3) * cos(x * 0.075)
		var ridge_h: float = (18.5 * outer_t * outer_t + 5.5 * outer_t) * crag
		# Fade gently near Moonlit Lake eastern shore so lake beach remains open
		var east_lake_fade: float = _smooth01((_lake_norm_dist(x, z) - 1.18) / 0.42)
		h += ridge_h * ridge_z_mask * east_lake_fade

	# --------------------------------------------------------------------------
	# C. TOWERING WEST COASTAL MOUNTAIN: 櫻岳高山 (X: -120..-30, Z: +18..+140)
	#    Peaks at ~49m around (-82, 82) with craggy ridges at (-66, 46) & (-92, 118)!
	# --------------------------------------------------------------------------
	if x < -22.0 and z > 6.0:
		var west_gate: float = _smooth01((-x - 24.0) / 14.0) * _smooth01((z - 12.0) / 16.0)
		if west_gate > 0.0001:
			var d_main: Vector2 = Vector2((x + 82.0) / 34.0, (z - 82.0) / 34.0)
			var p_main: float = 47.5 * exp(-d_main.length_squared())

			var d_north: Vector2 = Vector2((x + 66.0) / 24.0, (z - 46.0) / 22.0)
			var p_north: float = 27.5 * exp(-d_north.length_squared())

			var d_south: Vector2 = Vector2((x + 92.0) / 28.0, (z - 118.0) / 25.0)
			var p_south: float = 38.5 * exp(-d_south.length_squared())

			var d_wall: float = _smooth01((-x - 90.0) / 28.0) * _smooth01((z - 28.0) / 24.0)
			var p_wall: float = 30.0 * d_wall

			var m_core: float = _smax(_smax(p_main, p_north, 4.5), _smax(p_south, p_wall, 4.5), 4.5)
			var rock_detail: float = 1.0 + 0.08 * sin(x * 0.11 + z * 0.06) * cos(z * 0.13 - x * 0.05)
			h += m_core * rock_detail * west_gate

	# --------------------------------------------------------------------------
	# D. EAST FJORD HEADLAND CLIFF (X: +34..+120, Z: +54..+140)
	#    Rises dramatically to +24m..+27m around (78, 102) framing the east fjord jaw!
	# --------------------------------------------------------------------------
	if x > 28.0 and z > 46.0:
		var east_gate: float = _smooth01((x - 32.0) / 16.0) * _smooth01((z - 52.0) / 16.0)
		if east_gate > 0.0001:
			var d_head: Vector2 = Vector2((x - 78.0) / 31.0, (z - 102.0) / 27.0)
			var p_head: float = 24.8 * exp(-d_head.length_squared())

			var d_bluff: Vector2 = Vector2((x - 104.0) / 26.0, (z - 126.0) / 24.0)
			var p_bluff: float = 21.0 * exp(-d_bluff.length_squared())

			var head_core: float = _smax(p_head, p_bluff, 3.8)
			var bluff_detail: float = 1.0 + 0.07 * sin(x * 0.10 - z * 0.08)
			h += head_core * bluff_detail * east_gate

	# --------------------------------------------------------------------------
	# E. WALKABLE COASTAL MOUNTAIN OVERLOOK TRAIL & CLIFF TERRACE
	#    Unified smooth hike from (-21, 96) through (-26, 92) up to (-42, 72) at y = 9.5m (slope < 22 deg!)
	# --------------------------------------------------------------------------
	if x < -10.0 and x > -62.0 and z > 54.0 and z < 110.0:
		var tinfo: Vector2 = _mountain_trail_info(x, z)
		var d_trail: float = tinfo.x
		var t_param: float = tinfo.y
		var d_terrace: float = Vector2(x - TRAIL_END_2D.x, z - TRAIL_END_2D.y).length()
		var blend_t: float = 1.0 - _smooth01((d_trail - 3.6) / 8.5)
		var terr_blend: float = 1.0 - _smooth01((d_terrace - 5.2) / 7.5)
		var unified_blend: float = maxf(blend_t, terr_blend)
		if unified_blend > 0.0001:
			var ramp_t: float = clampf(t_param / 0.84, 0.0, 1.0)
			var ramp_u: float = lerpf(ramp_t, _smooth01(ramp_t), 0.25)
			var trail_y: float = lerpf(0.55, 9.50, ramp_u)
			h = lerpf(h, trail_y, unified_blend)

	# --------------------------------------------------------------------------
	# F. KEY FLAT SANCTUARY CLEARINGS, VILLAGE PLAZA & ALTAR RIM CLIFFS
	# --------------------------------------------------------------------------
	# 1. Cozy Sakura Village Clearing (X: -28..+28, Z: 16..43) flattened smoothly around y = 0.50m
	if absf(x) < 38.0 and z > 12.0 and z < 50.0:
		var vx: float = 1.0 - _smooth01((absf(x) - 27.5) / 9.5)
		var vz: float = _smooth01((z - 13.5) / 4.5) * (1.0 - _smooth01((z - 42.5) / 6.5))
		h = lerpf(h, 0.50, vx * vz)

	# 2. Scholar Kenta & Jizo Shrine Mossy Clearing at (-35, -29) -> y = 1.20m
	var kenta_d: float = Vector2(x + 35.0, z + 29.0).length()
	if kenta_d < 13.0:
		var kenta_t: float = 1.0 - _smooth01((kenta_d - 5.5) / 7.2)
		h = lerpf(h, 1.20, kenta_t)

	# 3. Eastern Wilderness Lookout Terrace at (32, -26) -> y = 2.60m
	var look_d: float = Vector2(x - 32.0, z + 26.0).length()
	if look_d < 14.0:
		var look_t: float = 1.0 - _smooth01((look_d - 5.6) / 8.0)
		h = lerpf(h, 2.60, look_t)

	# 4. Senbon Torii Flanking Mountain Slopes (z: -96..-56, |x| > 26)
	var torii_mask: float = _smooth01((-z - 54.0) / 8.0) * (1.0 - _smooth01((-z - 96.0) / 8.0))
	if torii_mask > 0.0001 and absf(x) > 25.0:
		var side_slope: float = _smooth01((absf(x) - 26.0) / 56.0)
		var hill_wave: float = 0.85 + 0.15 * sin(z * 0.11 + x * 0.06)
		h += (15.5 * side_slope * side_slope + 3.5 * side_slope) * hill_wave * torii_mask

	# 5. Sakura Healing Spring Level Terrace (-18, -72) -> y = 2.60m
	var spring_d: float = Vector2(x - SPRING_POS_2D.x, z - SPRING_POS_2D.y).length()
	if spring_d < 9.5:
		var spring_t: float = 1.0 - _smooth01((spring_d - 4.8) / 4.5)
		h = lerpf(h, 2.60, spring_t)

	# 6. Elder Byakko Stone Shrine Alcove Terrace (19.0, -72.0) -> y = 2.60m
	var byakko_d: float = Vector2(x - 19.0, z + 72.0).length()
	if byakko_d < 9.5:
		var byakko_t: float = 1.0 - _smooth01((byakko_d - 4.6) / 4.6)
		h = lerpf(h, 2.60, byakko_t)

	# 7. Grand Night-Sakura Altar High Framing Rim Cliffs (z < -94, |x| > 52 or z < -133)
	var altar_mask: float = _smooth01((-z - 94.0) / 6.0)
	if altar_mask > 0.0001:
		var rim_x: float = _smooth01((absf(x) - 52.0) / 46.0)
		var rim_n: float = _smooth01((-z - 131.0) / 10.0)
		var rim_c: float = maxf(rim_x, rim_n)
		if rim_c > 0.0001:
			var rim_wave: float = 0.88 + 0.12 * cos(x * 0.09 - z * 0.09)
			h += (17.5 * rim_c * rim_c + 4.0 * rim_c) * rim_wave * altar_mask

	# --------------------------------------------------------------------------
	# G. SEASIDE FJORD OCEAN BAY, KOI RIVER & MOONLIT LAKE BASIN CARVES
	# --------------------------------------------------------------------------
	# 1. Seaside Fjord Crescent Beach & Ocean Bay (z > 98 -> deep turquoise fjord opening south)
	if z > 96.0:
		var bay_half_w: float = lerpf(27.5, 43.0, _smooth01((z - 104.0) / 36.0))
		var bay_x_mask: float = 1.0 - _smooth01((absf(x) - bay_half_w) / 12.0)
		if bay_x_mask > 0.0001:
			var shore_z: float = _fjord_shore_z(x)
			# Smooth beach slope from dry sand (z ~ 104, y ~ +0.35m) across waterline (z ~ 112, y = -0.42m)
			# down to deep seabed (z >= 128, y ~ -2.35m)
			var dry_beach_flat: float = (1.0 - _smooth01((z - 103.5) / 6.5)) * _smooth01((z - 96.0) / 6.0) * bay_x_mask
			h = lerpf(h, 0.35, dry_beach_flat * 0.85)
			var sea_t: float = _smooth01((z - (shore_z - 7.5)) / 21.0)
			if sea_t > 0.0001:
				var target_sea_y: float = lerpf(h, -2.35, sea_t)
				h = lerpf(h, target_sea_y, bay_x_mask * _smooth01((z - (shore_z - 8.0)) / 5.5))

	# 2. Inland Koi River (z ~ 8.0 + sin(x * 0.045) * 3.1, x: -120..+46)
	var river_east_fade: float = 1.0 - _smooth01((x - 36.0) / 10.0)
	var river_z: float = _river_center_z(x)
	var river_d: float = absf(z - river_z)
	var river_carve: float = 0.0
	if river_d < 4.2 and river_east_fade > 0.0001:
		var river_t: float = 1.0 - _smooth01((river_d - 1.4) / 2.8)
		river_carve = 1.65 * river_t * river_east_fade

	# 3. Moonlit Lake (月見湖) Basin centered at (56.0, 16.0), semi-axes (24.0, 17.0)
	var lake_r: float = _lake_norm_dist(x, z)
	var lake_carve: float = 0.0
	if lake_r < 1.12:
		var basin_t: float = 1.0 - _smooth01((lake_r - 0.22) / 0.88)
		lake_carve = 2.25 * basin_t
		# Subtle sandy beach berm framing the outer rim
	elif lake_r < 1.38 and x > 32.0:
		var berm_in: float = _smooth01((lake_r - 1.08) / 0.14)
		var berm_out: float = 1.0 - _smooth01((lake_r - 1.22) / 0.16)
		h += 0.18 * berm_in * berm_out

	if river_carve > 0.0001 or lake_carve > 0.0001:
		h -= _smax(river_carve, lake_carve, 0.20)

	return h


static func get_terrain_normal(x: float, z: float) -> Vector3:
	const EPS: float = 0.32
	var hx1: float = get_base_terrain_height(x + EPS, z)
	var hx0: float = get_base_terrain_height(x - EPS, z)
	var hz1: float = get_base_terrain_height(x, z + EPS)
	var hz0: float = get_base_terrain_height(x, z - EPS)
	return Vector3(hx0 - hx1, 2.0 * EPS, hz0 - hz1).normalized()


static func get_water_level(x: float, z: float) -> float:
	# Water Body 1: Ocean Fjord Bay & Southern Sea (z >= 86)
	# Water Body 2: Inland Koi River & Moonlit Lake (z: -8..+42)
	var in_fjord_water: bool = (z >= 86.0)
	var in_inland_water: bool = (z >= -8.0 and z <= 42.0)
	if not in_fjord_water and not in_inland_water:
		return -99.0
	var h: float = get_base_terrain_height(x, z)
	if h < WATER_LEVEL + 0.15:
		return WATER_LEVEL
	return -99.0


static func get_surface_type(x: float, z: float, entity_y: float) -> String:
	if entity_y < WATER_LEVEL + 0.08 and get_water_level(x, z) > -50.0:
		return "water"
	var h: float = get_base_terrain_height(x, z)
	var w: Color = get_terrain_material_weights(x, z, h)
	if w.b >= 0.42:
		return "sand"
	if w.r >= 0.42 or (w.a >= 0.42 and (z < -92.0 or h >= 1.25)):
		return "stone"
	return "grass"


# ==============================================================================
#  2. MULTI-MATERIAL FLOOR WEIGHTS (arena_floor.gdshader stage_id = 4)
# ==============================================================================
static func get_terrain_material_weights(x: float, z: float, h: float) -> Color:
	# Channel R (w_r): Carved Granite Flagstones & Alpine Rock Crags — Village Plaza, roads, mountain trail, peaks
	# Channel G (w_g): Lush Emerald Meadow Grass & Woodland Soil — sprawling wilderness hills, meadows, forests
	# Channel B (w_b): Golden-White Sandy Beach (白砂浜) — Seaside Fjord Beach AND Moonlit Lake shore
	# Channel A (w_a): Underwater riverbed/lakebed/seabed pebbles (h < -0.50) AND Grand Altar twilight slate (z < -94.5)

	# 1. Underwater seabed/lakebed pebbles + Grand Altar twilight slate + Byakko alcove slate
	var wet_bed: float = _smooth01((-0.52 - h) / 0.38)
	var altar_slate: float = (
		_smooth01((-z - 94.5) / 3.5)
		* (1.0 - _smooth01((absf(x) - 46.0) / 8.0))
		* (1.0 - _smooth01((-z - 131.5) / 4.5))
	)
	var byakko_d: float = Vector2(x - 19.0, z + 72.0).length()
	var byakko_pad: float = 1.0 - _smooth01((byakko_d - 3.2) / 1.8)
	var w_a: float = clampf(maxf(wet_bed, maxf(altar_slate, byakko_pad)), 0.0, 1.0)

	# 2. Golden-White Beach Sand (白砂浜): Seaside Fjord Beach + Moonlit Lake Shore
	# 2a. Seaside Fjord crescent beach (z > 92, inside fjord cove, low beach elevation)
	var shore_z: float = _fjord_shore_z(x)
	var fjord_band: float = _smooth01((z - (shore_z - 19.0)) / 6.5) * (1.0 - _smooth01((absf(x) - 30.0) / 12.0))
	var fjord_h: float = _smooth01((h + 0.90) / 0.30) * (1.0 - _smooth01((h - 0.95) / 0.55))
	var sand_fjord: float = fjord_band * fjord_h * 1.18

	# 2b. Moonlit Lake sandy beach rim
	var lake_r: float = _lake_norm_dist(x, z)
	var lake_ring: float = _smooth01((lake_r - 0.60) / 0.16) * (1.0 - _smooth01((lake_r - 1.06) / 0.24))
	var lake_h: float = _smooth01((h + 0.85) / 0.28) * (1.0 - _smooth01((h - 0.85) / 0.40))
	var sand_lake: float = lake_ring * lake_h * 1.15

	var w_b: float = clampf(maxf(sand_fjord, sand_lake), 0.0, 1.0) * (1.0 - altar_slate) * (1.0 - wet_bed * 0.72)

	# 3. Carved Granite Flagstones & Alpine Crags:
	# 3a. Winding coastal pilgrimage trail (z: 42..98)
	var coastal_cx: float = _coastal_trail_x(z)
	var coastal_road: float = (
		(1.0 - _smooth01((absf(x - coastal_cx) - 2.8) / 1.6))
		* _smooth01((z - 40.0) / 3.0)
		* (1.0 - _smooth01((z - 97.0) / 3.5))
		* 0.85
	)

	# 3b. North pilgrimage road (z: -98..22)
	var north_road: float = (
		(1.0 - _smooth01((absf(x) - 3.6) / 1.6))
		* (1.0 - _smooth01((z - 22.0) / 3.5))
		* (1.0 - _smooth01((-z - 98.0) / 3.5))
	)

	# 3c. Sakura Village Plaza + Teahouse & Forge pads + East Bridge path
	var plaza_w: float = (
		(1.0 - _smooth01((absf(x) - 12.0) / 4.8))
		* _smooth01((z - 16.0) / 3.5)
		* (1.0 - _smooth01((z - 42.0) / 4.0))
		* 0.92
	)
	var east_bridge_path: float = (
		(1.0 - _smooth01((absf(x - 24.0) - 2.1) / 1.5))
		* _smooth01((z + 2.0) / 3.5)
		* (1.0 - _smooth01((z - 22.0) / 3.5))
		* 0.80
	)
	var tea_pad: float = 1.0 - _smooth01((Vector2(x + 18.5, z - 26.5).length() - 4.0) / 1.8)
	var forge_pad: float = 1.0 - _smooth01((Vector2(x - 19.5, z - 25.8).length() - 4.0) / 1.8)

	# 3d. Walkable Mount Sakuradake Overlook Trail & Cliff Terrace stone stepping path
	var mtrail_w: float = 0.0
	if x < -14.0 and x > -54.0 and z > 60.0 and z < 104.0:
		var tinfo: Vector2 = _mountain_trail_info(x, z)
		var path_s: float = (1.0 - _smooth01((tinfo.x - 2.3) / 1.6)) * 0.78
		var terr_s: float = (1.0 - _smooth01((Vector2(x - TRAIL_END_2D.x, z - TRAIL_END_2D.y).length() - 4.5) / 1.8)) * 0.85
		mtrail_w = maxf(path_s, terr_s)

	# 3e. High alpine exposed rock on towering Mount Sakuradake & coastal cliffs (h > 19m)
	var alpine_rock: float = _smooth01((h - 19.0) / 14.0) * 0.72

	var stone_raw: float = maxf(
		maxf(maxf(coastal_road, north_road), maxf(plaza_w, east_bridge_path)),
		maxf(maxf(tea_pad, forge_pad), maxf(mtrail_w, alpine_rock))
	)
	var w_r: float = clampf(stone_raw, 0.0, 1.0) * (1.0 - w_a * 0.88) * (1.0 - w_b * 0.82)

	# 4. Lush Emerald Meadow Grass & Woodland Soil everywhere else (~75-80% open wilderness!)
	var w_g: float = maxf(0.0, 1.0 - (w_r + w_b + w_a))

	var s: float = maxf(w_r + w_g + w_b + w_a, 0.0001)
	return Color(w_r / s, w_g / s, w_b / s, w_a / s)


# ==============================================================================
#  3. RECTANGULAR BOUNDS HELPER
# ==============================================================================
static func clamp_position(pos: Vector3, margin: float = 1.2) -> Vector3:
	return Vector3(
		clampf(pos.x, MIN_X + margin, MAX_X - margin),
		pos.y,
		clampf(pos.z, MIN_Z + margin, MAX_Z - margin)
	)


static func _bridge_pt(x: float, z: float, y_offset: float = 0.0) -> Vector3:
	return Vector3(x, get_base_terrain_height(x, z) + y_offset, z)


# ==============================================================================
#  4. FULL CHAPTER 1 ARPG MAP BUILDER (240m × 280m COASTAL FJORD & WILDERNESS)
# ==============================================================================
static func build_map(
	arena: Arena3D,
	content_root: Node3D,
	floor_shader: Shader,
	prop_shader: Shader,
	water_shader: Shader,
	sky_shader: Shader,
	sky_anim_nodes: Array[Dictionary]
) -> void:
	var is_mob: bool = UiStyle.is_mobile_device()

	# 1. Twilight Night-Sakura Sky & Atmospheric Environment (fog density 0.0017 for crisp 50m mountain vista!)
	_setup_environment(arena, sky_shader, is_mob)

	# 2. High-Resolution Rectangular Heightfield TerrainMesh (stage_id = 4) + Cliff Skirts
	_build_heightfield_terrain(arena, content_root, floor_shader, is_mob)

	# 3. Distant Misty Mountain Horizon Ring (West/North/East silhouettes, open ocean to the South!)
	_build_distant_mountain_ring(content_root, is_mob)

	# 4. Subtle Glowing Perimeter Shrine Boundary Border
	_build_perimeter_border(content_root, Color.html("#e11d48"), is_mob)

	# 5. Two Interactive Water Bodies (Endless South Ocean Fjord + Inland Koi River & Moonlit Lake)
	_build_ocean_and_inland_water(arena, content_root, water_shader, is_mob)

	# 6. Seaside Fjord Beach Props: Fjord Pier, Bobbing Fishing Boat, Driftwood, Coastal Stones & Overlook Markers
	_build_fjord_beach_and_overlook(arena, content_root, prop_shader, sky_anim_nodes, is_mob)

	# 7. Two Flush-Anchored Ornate Walkable Bridges over Koi River
	# Main Grand Vermilion Taiko Bridge (x = 0.0, z: 14.5 -> 0.5)
	WafuuModels3D.add_ornate_bridge(
		arena, content_root, prop_shader,
		_bridge_pt(0.0, 14.5), _bridge_pt(0.0, 0.5),
		5.4, 1.05, "#991b1b", "#450a0a", "#ef4444", 0
	)
	# East Rustic Cedar Footbridge (x = 24.0, z: 14.5 -> 0.5) framing Moonlit Lake mouth!
	WafuuModels3D.add_ornate_bridge(
		arena, content_root, prop_shader,
		_bridge_pt(24.0, 14.5), _bridge_pt(24.0, 0.5),
		3.8, 0.78, "#7c4722", "#43220d", "#d97706", 0
	)

	# 8. Compact Cozy Sakura Village (Z: +16..+43)
	_build_zone1_village(arena, content_root, is_mob)

	# 9. Sprawling Bamboo, Maple & Mountain Wilderness (Z: -56..-2)
	_build_zone3_bamboo_wilderness(arena, content_root, prop_shader, is_mob)

	# 10. Senbon Torii Mountain Ascent (10 Gates + Healing Spring + Elder Byakko Alcove)
	_build_zone4_senbon_torii(arena, content_root, sky_anim_nodes, is_mob)

	# 11. Elevated Grand Night-Sakura Altar (Grand Torii + 4 Columns + Monolith + Giant Weeping Sakura)
	_build_zone5_grand_altar(arena, content_root, sky_anim_nodes, is_mob)

	# 12. 4 Batched Real-Leaf Wilderness Forests (Broadleaf, Pine, Maple, Sakura -> 8 draw calls total!)
	_build_batched_wilderness_forests(arena, content_root, is_mob)

	# 13. Dense Wind-Interactive Grass, 3 Wildflower Species, Fjord/Lake Reeds, Lotus, Moonlit Lake Pier/Boat/Koi
	_build_lush_nature_and_lake(arena, content_root, prop_shader, sky_anim_nodes, is_mob)

	# 14. Sky Landmarks (Drifting Sky Lanterns + Moonlit Cloud Ring + Giant Full Moon)
	_build_sky_landmarks(content_root, sky_anim_nodes)

	# 15. Ambient Falling Sakura Petals across the 240m × 280m world
	_build_ambient_particles(content_root, Color.html("#f9a8d4"), is_mob)


# ==============================================================================
#  ENVIRONMENT, TERRAIN & HORIZON BUILDERS
# ==============================================================================
static func _setup_environment(arena: Arena3D, sky_shader: Shader, is_mob: bool) -> void:
	if arena.world_environment != null:
		var env: Environment = arena.world_environment.environment
		if env == null:
			env = Environment.new()
			arena.world_environment.environment = env
		var sky_mat := ShaderMaterial.new()
		sky_mat.shader = sky_shader
		sky_mat.set_shader_parameter("stage_id", 0)
		sky_mat.set_shader_parameter("mobile_mode", is_mob)

		var sky_res := Sky.new()
		sky_res.sky_material = sky_mat
		sky_res.radiance_size = Sky.RADIANCE_SIZE_32

		env.background_mode = Environment.BG_SKY
		env.sky = sky_res
		env.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
		env.background_color = Color.html("#131629")
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = Color.html("#ffd1dc")
		env.ambient_light_energy = 1.12 if is_mob else 0.92
		env.fog_enabled = true
		env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
		env.fog_light_color = Color.html("#1a1530")
		env.fog_density = 0.0017
		env.fog_sky_affect = 0.06

	if arena.center_light != null:
		arena.center_light.light_color = Color.html("#f472b6")
		arena.center_light.light_energy = 1.80
		arena.center_light.omni_range = 240.0


static func _build_heightfield_terrain(arena: Arena3D, content_root: Node3D, floor_shader: Shader, is_mob: bool) -> void:
	var nx: int = 46 if is_mob else 76
	var nz: int = 54 if is_mob else 88

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Build (nz + 1) x (nx + 1) vertex grid
	var grid: Array = []
	var eps: float = 0.32
	for iz: int in range(nz + 1):
		var row: Array = []
		var z: float = lerpf(MIN_Z, MAX_Z, float(iz) / float(nz))
		for ix: int in range(nx + 1):
			var x: float = lerpf(MIN_X, MAX_X, float(ix) / float(nx))
			var y: float = get_base_terrain_height(x, z)
			var hx1: float = get_base_terrain_height(x + eps, z)
			var hx0: float = get_base_terrain_height(x - eps, z)
			var hz1: float = get_base_terrain_height(x, z + eps)
			var hz0: float = get_base_terrain_height(x, z - eps)
			var nrm: Vector3 = Vector3(hx0 - hx1, 2.0 * eps, hz0 - hz1).normalized()
			var weights: Color = get_terrain_material_weights(x, z, y)
			row.append([Vector3(x, y, z), nrm, weights])
		grid.append(row)

	# Emit top terrain triangles with exact Godot 4 CW front-face winding when viewed from +Y
	for iz: int in range(nz):
		for ix: int in range(nx):
			var v00: Array = grid[iz][ix]
			var v10: Array = grid[iz][ix + 1]
			var v11: Array = grid[iz + 1][ix + 1]
			var v01: Array = grid[iz + 1][ix]

			st.set_color(v00[2]); st.set_normal(v00[1]); st.add_vertex(v00[0])
			st.set_color(v10[2]); st.set_normal(v10[1]); st.add_vertex(v10[0])
			st.set_color(v11[2]); st.set_normal(v11[1]); st.add_vertex(v11[0])

			st.set_color(v00[2]); st.set_normal(v00[1]); st.add_vertex(v00[0])
			st.set_color(v11[2]); st.set_normal(v11[1]); st.add_vertex(v11[0])
			st.set_color(v01[2]); st.set_normal(v01[1]); st.add_vertex(v01[0])

	# Cliff skirts along all 4 outer rectangular edges (granite rock strata channel R)
	var skirt_w := Color(1.0, 0.0, 0.0, 0.0)
	var skirt_drop: float = 10.0
	var skirt_flare: float = 4.0

	# North edge (z = MIN_Z, outward normal -Z)
	for ix: int in range(nx):
		var top_a: Vector3 = grid[0][ix + 1][0]
		var top_b: Vector3 = grid[0][ix][0]
		var bot_a := Vector3(top_a.x, minf(top_a.y - skirt_drop, -4.5), top_a.z - skirt_flare)
		var bot_b := Vector3(top_b.x, minf(top_b.y - skirt_drop, -4.5), top_b.z - skirt_flare)
		_emit_skirt_quad(st, top_a, top_b, bot_a, bot_b, Vector3(0.0, 0.0, -1.0), skirt_w)

	# South edge (z = MAX_Z, outward normal +Z) — plunges smoothly below the ocean surface
	for ix: int in range(nx):
		var top_a: Vector3 = grid[nz][ix][0]
		var top_b: Vector3 = grid[nz][ix + 1][0]
		var bot_a := Vector3(top_a.x, minf(top_a.y - skirt_drop, -4.5), top_a.z + skirt_flare)
		var bot_b := Vector3(top_b.x, minf(top_b.y - skirt_drop, -4.5), top_b.z + skirt_flare)
		_emit_skirt_quad(st, top_a, top_b, bot_a, bot_b, Vector3(0.0, 0.0, 1.0), skirt_w)

	# West edge (x = MIN_X, outward normal -X)
	for iz: int in range(nz):
		var top_a: Vector3 = grid[iz][0][0]
		var top_b: Vector3 = grid[iz + 1][0][0]
		var bot_a := Vector3(top_a.x - skirt_flare, minf(top_a.y - skirt_drop, -4.5), top_a.z)
		var bot_b := Vector3(top_b.x - skirt_flare, minf(top_b.y - skirt_drop, -4.5), top_b.z)
		_emit_skirt_quad(st, top_a, top_b, bot_a, bot_b, Vector3(-1.0, 0.0, 0.0), skirt_w)

	# East edge (x = MAX_X, outward normal +X)
	for iz: int in range(nz):
		var top_a: Vector3 = grid[iz + 1][nx][0]
		var top_b: Vector3 = grid[iz][nx][0]
		var bot_a := Vector3(top_a.x + skirt_flare, minf(top_a.y - skirt_drop, -4.5), top_a.z)
		var bot_b := Vector3(top_b.x + skirt_flare, minf(top_b.y - skirt_drop, -4.5), top_b.z)
		_emit_skirt_quad(st, top_a, top_b, bot_a, bot_b, Vector3(1.0, 0.0, 0.0), skirt_w)

	var mat := ShaderMaterial.new()
	mat.shader = floor_shader
	mat.set_shader_parameter("stage_id", 4)
	mat.set_shader_parameter("mobile_mode", is_mob)
	arena.set_meta("terrain_floor_mat", mat)

	var terrain_inst := MeshInstance3D.new()
	terrain_inst.name = "TerrainMesh"
	terrain_inst.mesh = st.commit()
	terrain_inst.material_override = mat
	terrain_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	content_root.add_child(terrain_inst)


static func _emit_skirt_quad(
	st: SurfaceTool,
	top_a: Vector3,
	top_b: Vector3,
	bot_a: Vector3,
	bot_b: Vector3,
	out_n: Vector3,
	col: Color
) -> void:
	st.set_color(col); st.set_normal(out_n); st.add_vertex(top_a)
	st.set_color(col); st.set_normal(out_n); st.add_vertex(top_b)
	st.set_color(col); st.set_normal(out_n); st.add_vertex(bot_b)

	st.set_color(col); st.set_normal(out_n); st.add_vertex(top_a)
	st.set_color(col); st.set_normal(out_n); st.add_vertex(bot_b)
	st.set_color(col); st.set_normal(out_n); st.add_vertex(bot_a)


static func _build_distant_mountain_ring(content_root: Node3D, is_mob: bool) -> void:
	# Dramatic misty mountain silhouette ring beyond West, North & East borders (1 draw call!)
	# Leaves the South ocean horizon (Z > +140) completely open so the fjord opens into endless sea!
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var segs: int = 24 if is_mob else 40
	var base_y: float = -4.0
	var col_base := Color.html("#13172e")
	var col_peak := Color.html("#2a2649")

	# Arc spanning from South-West (angle ~ 2.45 rad) clockwise through West, North, East to South-East (~ 0.70 rad)
	# Using world XZ where angle 0 = +X (East), -PI/2 = -Z (North), -PI = -X (West), +PI/2 = +Z (South)
	var a_start: float = 0.42
	var a_end: float = -PI - 0.42

	var ring_pts_bot: Array[Vector3] = []
	var ring_pts_top: Array[Vector3] = []
	for i: int in range(segs + 1):
		var u: float = float(i) / float(segs)
		var ang: float = lerpf(a_start, a_end, u)
		var rx: float = 205.0 + sin(u * 13.0) * 18.0
		var rz: float = 225.0 + cos(u * 11.0) * 18.0
		var px: float = cos(ang) * rx
		var pz: float = sin(ang) * rz
		var end_fade: float = sin(u * PI)
		var peak_h: float = (
			28.0
			+ 32.0 * absf(sin(u * 9.5 + 0.4))
			+ 18.0 * absf(cos(u * 17.0 - 0.8))
		) * clampf(end_fade * 2.2, 0.0, 1.0)
		ring_pts_bot.append(Vector3(px, base_y, pz))
		ring_pts_top.append(Vector3(px * 1.06, base_y + peak_h, pz * 1.06))

	for i: int in range(segs):
		var b0: Vector3 = ring_pts_bot[i]
		var b1: Vector3 = ring_pts_bot[i + 1]
		var t0: Vector3 = ring_pts_top[i]
		var t1: Vector3 = ring_pts_top[i + 1]
		var n_in: Vector3 = -Vector3(b0.x + b1.x, 0.0, b0.z + b1.z).normalized()
		# Inward-facing triangles toward map center
		st.set_color(col_base); st.set_normal(n_in); st.add_vertex(b0)
		st.set_color(col_peak); st.set_normal(n_in); st.add_vertex(t0)
		st.set_color(col_peak); st.set_normal(n_in); st.add_vertex(t1)

		st.set_color(col_base); st.set_normal(n_in); st.add_vertex(b0)
		st.set_color(col_peak); st.set_normal(n_in); st.add_vertex(t1)
		st.set_color(col_base); st.set_normal(n_in); st.add_vertex(b1)

	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = Color.WHITE
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	var inst := MeshInstance3D.new()
	inst.name = "DistantMistyMountains"
	inst.mesh = st.commit()
	inst.material_override = mat
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	content_root.add_child(inst)


static func _build_perimeter_border(content_root: Node3D, border_col: Color, is_mob: bool) -> void:
	var segs_x: int = 36 if is_mob else 60
	var segs_z: int = 42 if is_mob else 70
	var inset: float = 0.65
	var half_w: float = 0.34
	var x_min: float = MIN_X + inset
	var x_max: float = MAX_X - inset
	var z_min: float = MIN_Z + inset
	var z_max: float = MAX_Z - inset

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# North & South horizontal glowing strips (clamped above waterline across the fjord mouth)
	for side_z: float in [z_min, z_max]:
		var za: float = side_z - half_w
		var zb: float = side_z + half_w
		for i: int in range(segs_x):
			var x0: float = lerpf(x_min - half_w, x_max + half_w, float(i) / float(segs_x))
			var x1: float = lerpf(x_min - half_w, x_max + half_w, float(i + 1) / float(segs_x))
			var y0: float = maxf(get_base_terrain_height(x0, side_z), WATER_LEVEL) + 0.16
			var y1: float = maxf(get_base_terrain_height(x1, side_z), WATER_LEVEL) + 0.16
			var p00 := Vector3(x0, y0, za)
			var p10 := Vector3(x1, y1, za)
			var p11 := Vector3(x1, y1, zb)
			var p01 := Vector3(x0, y0, zb)
			st.set_normal(Vector3.UP); st.add_vertex(p00)
			st.set_normal(Vector3.UP); st.add_vertex(p10)
			st.set_normal(Vector3.UP); st.add_vertex(p11)
			st.set_normal(Vector3.UP); st.add_vertex(p00)
			st.set_normal(Vector3.UP); st.add_vertex(p11)
			st.set_normal(Vector3.UP); st.add_vertex(p01)

	# West & East vertical glowing strips
	for side_x: float in [x_min, x_max]:
		var xa: float = side_x - half_w
		var xb: float = side_x + half_w
		for i: int in range(segs_z):
			var z0: float = lerpf(z_min, z_max, float(i) / float(segs_z))
			var z1: float = lerpf(z_min, z_max, float(i + 1) / float(segs_z))
			var y0: float = maxf(get_base_terrain_height(side_x, z0), WATER_LEVEL) + 0.16
			var y1: float = maxf(get_base_terrain_height(side_x, z1), WATER_LEVEL) + 0.16
			var p00 := Vector3(xa, y0, z0)
			var p10 := Vector3(xb, y0, z0)
			var p11 := Vector3(xb, y1, z1)
			var p01 := Vector3(xa, y1, z1)
			st.set_normal(Vector3.UP); st.add_vertex(p00)
			st.set_normal(Vector3.UP); st.add_vertex(p10)
			st.set_normal(Vector3.UP); st.add_vertex(p11)
			st.set_normal(Vector3.UP); st.add_vertex(p00)
			st.set_normal(Vector3.UP); st.add_vertex(p11)
			st.set_normal(Vector3.UP); st.add_vertex(p01)

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(border_col.r, border_col.g, border_col.b, 0.72)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var inst := MeshInstance3D.new()
	inst.name = "PerimeterBorder"
	inst.mesh = st.commit()
	inst.material_override = mat
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	content_root.add_child(inst)


static func _build_ocean_and_inland_water(
	arena: Arena3D,
	content_root: Node3D,
	water_shader: Shader,
	is_mob: bool
) -> void:
	# 1. Ocean Fjord & Endless South Sea Horizon (X: -260..+260, Z: +86..+320)
	var ocean_pm := PlaneMesh.new()
	ocean_pm.size = Vector2(520.0, 234.0)
	ocean_pm.subdivide_width = 28 if is_mob else 52
	ocean_pm.subdivide_depth = 20 if is_mob else 38

	var ocean_mat := ShaderMaterial.new()
	ocean_mat.shader = water_shader
	var odc := Color.html("#0a3b6c")
	var osc := Color.html("#22d3ee")
	ocean_mat.set_shader_parameter("deep_color", Color(odc.r, odc.g, odc.b, 0.86))
	ocean_mat.set_shader_parameter("shallow_color", Color(osc.r, osc.g, osc.b, 0.64))
	ocean_mat.set_shader_parameter("glint_color", Color.html("#e0f2fe"))
	ocean_mat.set_shader_parameter("wave_speed", 1.24)
	ocean_mat.set_shader_parameter("wave_amp", 0.056)
	ocean_mat.set_shader_parameter("wind_strength", 1.05)
	ocean_mat.set_shader_parameter("mobile_mode", is_mob)

	var ocean_inst := MeshInstance3D.new()
	ocean_inst.name = "FjordOceanWater"
	ocean_inst.mesh = ocean_pm
	ocean_inst.material_override = ocean_mat
	ocean_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ocean_inst.position = Vector3(0.0, WATER_LEVEL, 203.0)
	content_root.add_child(ocean_inst)

	# 2. Inland Koi River & Moonlit Lake (X: -120..+120, Z: -8..+42)
	var lake_pm := PlaneMesh.new()
	lake_pm.size = Vector2(MAX_X - MIN_X, 50.0)
	lake_pm.subdivide_width = 28 if is_mob else 56
	lake_pm.subdivide_depth = 18 if is_mob else 36

	var lake_mat := ShaderMaterial.new()
	lake_mat.shader = water_shader
	var ldc := Color.html("#0f4c81")
	var lsc := Color.html("#38bdf8")
	lake_mat.set_shader_parameter("deep_color", Color(ldc.r, ldc.g, ldc.b, 0.78))
	lake_mat.set_shader_parameter("shallow_color", Color(lsc.r, lsc.g, lsc.b, 0.60))
	lake_mat.set_shader_parameter("glint_color", Color.html("#e0f2fe"))
	lake_mat.set_shader_parameter("wave_speed", 1.08)
	lake_mat.set_shader_parameter("wave_amp", 0.040)
	lake_mat.set_shader_parameter("wind_strength", 1.0)
	lake_mat.set_shader_parameter("mobile_mode", is_mob)

	var lake_inst := MeshInstance3D.new()
	lake_inst.name = "MoonlitLakeAndRiverWater"
	lake_inst.mesh = lake_pm
	lake_inst.material_override = lake_mat
	lake_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	lake_inst.position = Vector3(0.0, WATER_LEVEL, 17.0)
	content_root.add_child(lake_inst)

	arena.set_meta("interactive_water_mats", [ocean_mat, lake_mat])


# ==============================================================================
#  SEASIDE FJORD BEACH, PIER, FISHING BOAT & MOUNT SAKURADAKE OVERLOOK
# ==============================================================================
static func _build_fjord_beach_and_overlook(
	arena: Arena3D,
	content_root: Node3D,
	prop_shader: Shader,
	sky_anim_nodes: Array[Dictionary],
	is_mob: bool
) -> void:
	# 1. Walkable Wooden Fjord Landing Pier jutting from golden sand into turquoise ocean cove
	var fjord_pier_start := Vector3(12.0, get_base_terrain_height(12.0, 108.0) + 0.04, 108.0)
	var fjord_pier_end := Vector3(18.0, WATER_LEVEL + 0.55, 118.0)
	ArpgNatureProps.add_lakeside_pier(arena, content_root, prop_shader, fjord_pier_start, fjord_pier_end, 3.2)

	# 2. Gently bobbing traditional Japanese Wasen fishing boat (和舟) moored beside the fjord pier tip
	var fjord_boat_pos := Vector3(21.4, WATER_LEVEL + 0.04, 118.2)
	ArpgNatureProps.add_moored_rowboat(content_root, fjord_boat_pos, -0.62, sky_anim_nodes)

	# 3. Coastal Fjord & Moonlit Lake Driftwood + Smooth Tide-Pool Stones (merged into 2 draw calls!)
	_build_coastal_driftwood_and_stones(content_root, is_mob)

	# 4. Scenic Coastal Boulders framing the fjord beach jaws (clear of spawn (0, 104) & pier!)
	var fjord_boulders: Array = [
		[Vector2(-24.5, 110.5), 2.15],
		[Vector2(-28.0, 116.0), 2.65],
		[Vector2(28.5, 112.0),  2.35],
		[Vector2(32.5, 118.5),  2.80],
		[Vector2(-19.0, 106.5), 1.45],
		[Vector2(25.0, 104.5),  1.50],
	]
	for fb in fjord_boulders:
		var bp: Vector2 = fb[0]
		WafuuModels3D.add_mossy_boulder(
			arena, content_root,
			Vector3(bp.x, get_base_terrain_height(bp.x, bp.y), bp.y),
			float(fb[1])
		)

	# 5. Trailhead & Mount Sakuradake Scenic Overlook Stone Lanterns (guides players north AND up the mountain!)
	var coast_lantern_2d: Array[Vector2] = [
		Vector2(-5.5, 96.0), Vector2(5.5, 96.0),
		Vector2(-5.2, 74.0), Vector2(6.5, 74.0),
		Vector2(-5.2, 56.0), Vector2(5.2, 56.0),
		# Mountain Overlook Trailhead & 9.5m Cliff Overlook Terrace (-42, 72)
		Vector2(-23.0, 94.5),
		Vector2(-32.0, 84.0),
		Vector2(-38.5, 69.5), Vector2(-45.5, 74.5),
	]
	var coast_lantern_pts: Array[Vector3] = []
	for lp: Vector2 in coast_lantern_2d:
		coast_lantern_pts.append(Vector3(lp.x, get_base_terrain_height(lp.x, lp.y), lp.y))
	WafuuModels3D.add_batched_stone_lanterns(content_root, coast_lantern_pts, "#fde047", is_mob)

	# 6. Small Scenic Torii Shrine Gate crowning the Mount Sakuradake Overlook Terrace (-42, 72)
	var overlook_pos := Vector3(-43.8, get_base_terrain_height(-43.8, 70.2), 70.2)
	var overlook_torii := WafuuModels3D.add_torii_gate(content_root, overlook_pos, "#dc2626", 0.85, false)
	if overlook_torii != null:
		# Face SE looking out over the fjord bay!
		overlook_torii.rotation.y = 0.72


static func _build_coastal_driftwood_and_stones(content_root: Node3D, is_mob: bool) -> void:
	var st_wood := SurfaceTool.new()
	st_wood.begin(Mesh.PRIMITIVE_TRIANGLES)
	var st_stone := SurfaceTool.new()
	st_stone.begin(Mesh.PRIMITIVE_TRIANGLES)

	var c_drift_dark := Color.html("#786b5b")
	var c_drift_lit := Color.html("#cec4b0")
	var c_stone_wet := Color.html("#475569")
	var c_stone_dry := Color.html("#94a3b8")

	# Sun-bleached driftwood logs on Seaside Fjord Beach AND Moonlit Lake Beach
	var drift_specs: Array = [
		[Vector2(-10.5, 108.5), 0.35, 3.2, 0.22],
		[Vector2(-16.2, 102.0), -0.82, 2.6, 0.18],
		[Vector2(21.5, 105.5),  0.58, 2.9, 0.19],
		[Vector2(45.5, 31.2),   0.40, 2.8, 0.19],
		[Vector2(73.5, 23.0),  -1.10, 2.6, 0.18],
		[Vector2(62.0, -0.5),   0.65, 2.7, 0.18],
	]
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.78; cyl.bottom_radius = 1.0; cyl.height = 1.0
	cyl.radial_segments = 6; cyl.rings = 1
	for ds in drift_specs:
		var p2: Vector2 = ds[0]
		var yaw: float = float(ds[1])
		var dlen: float = float(ds[2])
		var drad: float = float(ds[3])
		var y0: float = get_base_terrain_height(p2.x, p2.y)
		var b := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, PI * 0.5)
		b = b.scaled(Vector3(drad, dlen, drad))
		_append_colored_mesh(st_wood, cyl, Transform3D(b, Vector3(p2.x, y0 + drad * 0.45, p2.y)), c_drift_dark, c_drift_lit)

	# Smooth tide-pool & coastal pebble clusters on both beaches
	var sp := SphereMesh.new()
	sp.radius = 1.0; sp.height = 2.0
	sp.radial_segments = 7 if is_mob else 9; sp.rings = 4 if is_mob else 5
	var stone_spots: Array = [
		# Seaside Fjord Beach stones (well clear of spawn (0, 104) & pier)
		[Vector2(-12.5, 110.2), Vector3(0.95, 0.42, 0.75), 0.5],
		[Vector2(-14.0, 109.5), Vector3(0.55, 0.28, 0.48), 1.4],
		[Vector2(8.2, 110.8),   Vector3(0.72, 0.32, 0.58), 2.1],
		[Vector2(24.0, 109.2),  Vector3(0.92, 0.44, 0.76), 0.9],
		[Vector2(-7.8, 109.6),  Vector3(0.46, 0.22, 0.38), 1.7],
		# Moonlit Lake Beach stones
		[Vector2(43.2, 29.8),   Vector3(0.92, 0.40, 0.72), 0.4],
		[Vector2(62.5, 31.0),   Vector3(0.84, 0.36, 0.66), 2.2],
		[Vector2(76.5, 18.2),   Vector3(1.05, 0.48, 0.82), 0.8],
		[Vector2(72.0, 5.5),    Vector3(0.88, 0.40, 0.70), 2.5],
		[Vector2(46.0, 2.2),    Vector3(0.82, 0.36, 0.64), 1.3],
	]
	for ss in stone_spots:
		var sp2: Vector2 = ss[0]
		var ssc: Vector3 = ss[1]
		var syaw: float = float(ss[2])
		var sy: float = get_base_terrain_height(sp2.x, sp2.y)
		var xf := Transform3D(Basis(Vector3.UP, syaw).scaled(ssc), Vector3(sp2.x, sy + ssc.y * 0.22, sp2.y))
		_append_colored_mesh(st_stone, sp, xf, c_stone_wet, c_stone_dry)

	var wood_inst := MeshInstance3D.new()
	wood_inst.name = "CoastalDriftwood"
	wood_inst.mesh = st_wood.commit()
	wood_inst.material_override = WafuuModels3D.make_wafuu_mat(0, is_mob, 0.84, 0.02, 0.06)
	wood_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	content_root.add_child(wood_inst)

	var stone_inst := MeshInstance3D.new()
	stone_inst.name = "CoastalBeachStones"
	stone_inst.mesh = st_stone.commit()
	stone_inst.material_override = WafuuModels3D.make_wafuu_mat(3, is_mob, 0.64, 0.06, 0.16)
	stone_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	content_root.add_child(stone_inst)


static func _append_colored_mesh(
	st: SurfaceTool,
	src_mesh: Mesh,
	xform: Transform3D,
	col_bot: Color,
	col_top: Color
) -> void:
	var arrays: Array = src_mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var norms: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var n_basis: Basis = xform.basis.inverse().transposed()

	if indices.size() > 0:
		for idx: int in indices:
			var v: Vector3 = verts[idx]
			var n: Vector3 = (n_basis * norms[idx]).normalized()
			var t: float = clampf(n.y * 0.5 + 0.5, 0.0, 1.0)
			st.set_color(col_bot.lerp(col_top, t))
			st.set_normal(n)
			st.add_vertex(xform * v)
	else:
		for i: int in range(verts.size()):
			var v: Vector3 = verts[i]
			var n: Vector3 = (n_basis * norms[i]).normalized()
			var t: float = clampf(n.y * 0.5 + 0.5, 0.0, 1.0)
			st.set_color(col_bot.lerp(col_top, t))
			st.set_normal(n)
			st.add_vertex(xform * v)


# ==============================================================================
#  ZONE 1: COMPACT COZY SAKURA VILLAGE (Z: +16..+43, X: -26..+26)
# ==============================================================================
static func _build_zone1_village(arena: Arena3D, content_root: Node3D, is_mob: bool) -> void:
	# Welcoming South Village Myojin Torii Gate with sacred shimenawa at (0, y, 43.0)
	WafuuModels3D.add_torii_gate(content_root, Vector3(0.0, get_base_terrain_height(0.0, 43.0), 43.0), "#dc2626", 1.20, true)

	# Traditional Japanese Teahouse (櫻花茶屋) at (-20.0, y, 26.5) + bamboo-ribbed red wagasa
	var tea_pos := Vector3(-20.0, get_base_terrain_height(-20.0, 26.5), 26.5)
	WafuuModels3D.add_japanese_teahouse(arena, content_root, tea_pos, 1.05, 0.58)
	WafuuModels3D.add_wagasa_umbrella(content_root, Vector3(-12.2, get_base_terrain_height(-12.2, 31.0), 31.0))

	# Traditional Japanese Blacksmith Forge (鉄斎鍛冶屋) at (20.8, y, 25.8)
	var forge_pos := Vector3(20.8, get_base_terrain_height(20.8, 25.8), 25.8)
	WafuuModels3D.add_japanese_forge(arena, content_root, forge_pos, 1.05, -0.58)

	# Twin Edo-style Machiya Village Homes framing the warm lantern-lit village flanks
	var house_w := Vector3(-29.0, get_base_terrain_height(-29.0, 38.5), 38.5)
	WafuuModels3D.add_japanese_house(arena, content_root, house_w, 1.08, 0.48, "#1e293b")
	var house_e := Vector3(29.0, get_base_terrain_height(29.0, 38.5), 38.5)
	WafuuModels3D.add_japanese_house(arena, content_root, house_e, 1.08, -0.48, "#262038")

	# Batched Carved Granite Kasuga-doro Stone Lanterns lining village plaza & bridges
	var village_lanterns_2d: Array[Vector2] = [
		Vector2(-6.2, 41.5), Vector2(6.2, 41.5),
		Vector2(-7.2, 32.0), Vector2(7.2, 32.0),
		Vector2(-6.0, 17.5), Vector2(6.0, 17.5),
		Vector2(20.5, 17.2), Vector2(27.5, 17.2),
		Vector2(-15.5, 20.5), Vector2(15.5, 20.5),
	]
	var village_lantern_pts: Array[Vector3] = []
	for lp: Vector2 in village_lanterns_2d:
		village_lantern_pts.append(Vector3(lp.x, get_base_terrain_height(lp.x, lp.y), lp.y))
	WafuuModels3D.add_batched_stone_lanterns(content_root, village_lantern_pts, "#fde047", is_mob)


# ==============================================================================
#  ZONE 3: SPRAWLING BAMBOO, MAPLE & MOUNTAIN WILDERNESS (Z: -56..-2)
# ==============================================================================
static func _build_zone3_bamboo_wilderness(
	arena: Arena3D,
	content_root: Node3D,
	prop_shader: Shader,
	is_mob: bool
) -> void:
	# 1. Wild Bamboo Groves batched into ONE single MultiMeshInstance3D (180 mobile / 320 desktop!)
	var bamboo_mesh := WafuuModels3D.make_realistic_bamboo_mesh(is_mob)
	var bamboo_mat := WafuuModels3D.make_wafuu_mat(5, is_mob, 0.44, 0.04)
	bamboo_mesh.surface_set_material(0, bamboo_mat)

	var rng := RandomNumberGenerator.new()
	rng.seed = 10101
	var target_count: int = 180 if is_mob else 320
	var bamboo_xforms: Array[Transform3D] = []
	var attempts: int = 0
	var max_attempts: int = target_count * 8

	while bamboo_xforms.size() < target_count and attempts < max_attempts:
		attempts += 1
		var side: float = -1.0 if (attempts % 2 == 0) else 1.0
		var bx: float = side * rng.randf_range(7.8, 76.0)
		var bz: float = rng.randf_range(-54.0, -2.5)

		# Keep clearings, combat zone, Jizo shrine, Scholar Kenta, Lookout Deck & Moonlit Lake open:
		if Vector2(bx + 35.0, bz + 29.0).length() < 9.2:
			continue
		if Vector2(bx - 2.0, bz + 34.0).length() < 12.5:
			continue
		if Vector2(bx - 32.0, bz + 26.0).length() < 9.5:
			continue
		if bx > 18.0 and bx < 29.5 and absf(bz + 26.0) < 3.6:
			continue
		if absf(bx - 24.0) < 4.5 and bz > -10.0:
			continue
		if _lake_norm_dist(bx, bz) < 1.24:
			continue
		if (
			Vector2(bx + 11.5, bz + 24.0).length() < 3.2
			or Vector2(bx - 12.0, bz + 22.5).length() < 3.2
			or Vector2(bx + 11.0, bz + 42.0).length() < 3.2
			or Vector2(bx - 12.5, bz + 43.0).length() < 3.2
		):
			continue

		var by: float = get_base_terrain_height(bx, bz)
		if by < 0.15 or by > 9.0:
			continue
		var h_scale: float = rng.randf_range(0.92, 1.52)
		var r_scale: float = rng.randf_range(0.88, 1.22)
		var yaw: float = rng.randf_range(0.0, TAU)
		var tilt_x: float = rng.randf_range(-0.06, 0.06)
		var tilt_z: float = rng.randf_range(-0.06, 0.06)
		var basis: Basis = Basis.from_euler(Vector3(tilt_x, yaw, tilt_z)).scaled(Vector3(r_scale, h_scale, r_scale))
		bamboo_xforms.append(Transform3D(basis, Vector3(bx, by - 0.15, bz)))

	_add_batched_multimesh(content_root, bamboo_mesh, bamboo_xforms, "BambooGroveMultiMesh")

	# 2. Roofed Wooden Hokora Jizo Shrine at (-36.5, y, -30.5) beside Scholar Kenta (-34, -28)
	var jizo_pos := Vector3(-36.5, get_base_terrain_height(-36.5, -30.5), -30.5)
	WafuuModels3D.add_jizo_shrine(arena, content_root, jizo_pos)

	# 3. Elevated Wooden Lookout Deck at (32.0, y + 1.2, -26.0) + Flush Ornate Wooden Ramp!
	var terrace_y: float = get_base_terrain_height(32.0, -26.0)
	var deck_top_y: float = terrace_y + 1.2
	_add_walkable_deck(
		arena, content_root, prop_shader,
		Vector3(32.0, deck_top_y, -26.0), 4.8,
		"#713819", "#421d0b", "#f59e0b", 1, true
	)
	WafuuModels3D.add_ornate_bridge(
		arena, content_root, prop_shader,
		_bridge_pt(20.5, -26.0), Vector3(27.35, deck_top_y, -26.0),
		3.2, 0.06, "#7c4722", "#43220d", "#f59e0b", 0
	)

	# 4. Four Tactical Mossy Granite Boulders framing the Bamboo Wilderness combat arena
	var boulders: Array[Vector2] = [
		Vector2(-11.5, -24.0),
		Vector2(12.0, -22.5),
		Vector2(-11.0, -42.0),
		Vector2(12.5, -43.0),
	]
	for bp: Vector2 in boulders:
		WafuuModels3D.add_mossy_boulder(arena, content_root, Vector3(bp.x, get_base_terrain_height(bp.x, bp.y), bp.y), 1.65)

	# Wilderness trail + Jizo + Lookout stone lanterns batched into 2 draw calls
	var forest_lantern_pts: Array[Vector3] = [
		Vector3(-31.5, get_base_terrain_height(-31.5, -31.5), -31.5),
		Vector3(34.5, deck_top_y, -28.2),
		Vector3(-5.8, get_base_terrain_height(-5.8, -2.5), -2.5),
		Vector3(5.8, get_base_terrain_height(5.8, -2.5), -2.5),
		Vector3(-6.2, get_base_terrain_height(-6.2, -26.0), -26.0),
		Vector3(6.2, get_base_terrain_height(6.2, -26.0), -26.0),
		Vector3(-6.2, get_base_terrain_height(-6.2, -50.0), -50.0),
		Vector3(6.2, get_base_terrain_height(6.2, -50.0), -50.0),
	]
	WafuuModels3D.add_batched_stone_lanterns(content_root, forest_lantern_pts, "#fde68a", is_mob)


# ==============================================================================
#  ZONE 4: SENBON TORII MOUNTAIN ASCENT (10 GATES, Z: -96..-56)
# ==============================================================================
static func _build_zone4_senbon_torii(
	arena: Arena3D,
	content_root: Node3D,
	sky_anim_nodes: Array[Dictionary],
	is_mob: bool
) -> void:
	# 1. Ten sequential Curved Myojin Torii Gates climbing smoothly from z = -58 to z = -94 (2 draw calls!)
	var torii_pts: Array[Vector3] = []
	for i: int in range(10):
		var tz: float = -58.0 - float(i) * 4.0
		torii_pts.append(Vector3(0.0, get_base_terrain_height(0.0, tz), tz))
	WafuuModels3D.build_senbon_torii(content_root, torii_pts, "#dc2626")

	# 2. Glowing Sakura Healing Spring at (-18.0, y, -72.0)
	var spring_y: float = get_base_terrain_height(SPRING_POS_2D.x, SPRING_POS_2D.y)
	var spring_world := Vector3(SPRING_POS_2D.x, spring_y, SPRING_POS_2D.y)
	arena.sakura_zone_pos = spring_world
	arena.sakura_zone_radius = SPRING_RADIUS

	var basin_mat := StandardMaterial3D.new()
	basin_mat.albedo_color = Color(0.28, 0.80, 0.96, 0.48)
	basin_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	basin_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var basin_cyl := CylinderMesh.new()
	basin_cyl.top_radius = SPRING_RADIUS - 0.35; basin_cyl.bottom_radius = SPRING_RADIUS - 0.35
	basin_cyl.height = 0.05; basin_cyl.radial_segments = 24 if is_mob else 36; basin_cyl.rings = 1
	var basin_inst := MeshInstance3D.new()
	basin_inst.mesh = basin_cyl
	basin_inst.material_override = basin_mat
	basin_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	basin_inst.position = spring_world + Vector3(0.0, 0.04, 0.0)
	content_root.add_child(basin_inst)

	var spring_rings := Node3D.new()
	spring_rings.name = "SakuraHealingSpring"
	spring_rings.position = spring_world + Vector3(0.0, 0.08, 0.0)

	var pink_ring_mat := StandardMaterial3D.new()
	pink_ring_mat.albedo_color = Color(0.98, 0.48, 0.76, 0.88)
	pink_ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pink_ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	var cyan_ring_mat := StandardMaterial3D.new()
	cyan_ring_mat.albedo_color = Color(0.22, 0.86, 0.98, 0.88)
	cyan_ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cyan_ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	spring_rings.add_child(_make_flat_ring(SPRING_RADIUS - 0.42, SPRING_RADIUS, pink_ring_mat, 0.04, is_mob))
	spring_rings.add_child(_make_flat_ring(2.35, 2.75, cyan_ring_mat, 0.06, is_mob))
	content_root.add_child(spring_rings)
	sky_anim_nodes.append({"node": spring_rings, "kind": "spin", "speed": 1.15})

	WafuuModels3D.add_stone_lantern(content_root, Vector3(-23.5, get_base_terrain_height(-23.5, -72.0), -72.0), "#f472b6")

	# 3. Carved Stone Shrine Alcove for Elder Byakko at (20.5, y, -72.0) (Byakko stands at (18.0, -72.0))
	var byakko_y: float = get_base_terrain_height(20.5, -72.0)
	WafuuModels3D.add_byakko_alcove(
		arena, content_root,
		Vector3(20.5, byakko_y, -72.0),
		Callable(ArpgCh1Map, "get_base_terrain_height")
	)


# ==============================================================================
#  ZONE 5: ELEVATED NIGHT-SAKURA GRAND ALTAR (Z: -140..-96, y = 4.6m)
# ==============================================================================
static func _build_zone5_grand_altar(
	arena: Arena3D,
	content_root: Node3D,
	sky_anim_nodes: Array[Dictionary],
	is_mob: bool
) -> void:
	var altar_y: float = get_base_terrain_height(0.0, -108.0)

	# 1. Grand North Myojin Torii Gate with sacred shimenawa at (0.0, y, -96.0), scale 1.55
	WafuuModels3D.add_torii_gate(content_root, Vector3(0.0, get_base_terrain_height(0.0, -96.0), -96.0), "#dc2626", 1.55, true)

	# 2. Four Tactical Shrine Columns framing the boss sanctuary
	var columns: Array[Vector2] = [
		Vector2(-16.0, -104.0), Vector2(16.0, -104.0),
		Vector2(-16.0, -118.0), Vector2(16.0, -118.0),
	]
	for cp: Vector2 in columns:
		_add_tactical_pillar(
			arena, content_root,
			Vector3(cp.x, get_base_terrain_height(cp.x, cp.y), cp.y),
			0.95, 5.2, "#4c3b5e", "#f472b6", is_mob
		)

	# 3. Corrupted/Sacred Kotodama Monolith Stone (言靈守護碑) at (0.0, y, -124.0)
	WafuuModels3D.add_kotodama_monolith(arena, content_root, Vector3(0.0, altar_y, -124.0), sky_anim_nodes, is_mob)

	# 4. Monumental Real-Leaf Weeping Sakura Tree with Shimenawa behind the Monolith at (0.0, y, -129.0)
	WafuuModels3D.add_giant_weeping_sakura(content_root, Vector3(0.0, get_base_terrain_height(0.0, -129.0), -129.0), is_mob)

	# 5. Batched Kasuga-doro Lanterns illuminating the Grand Altar
	var altar_lantern_pts: Array[Vector3] = []
	for lp: Vector2 in [
		Vector2(-8.5, -97.5), Vector2(8.5, -97.5),
		Vector2(-22.5, -111.0), Vector2(22.5, -111.0),
		Vector2(-8.0, -123.5), Vector2(8.0, -123.5),
	]:
		altar_lantern_pts.append(Vector3(lp.x, get_base_terrain_height(lp.x, lp.y), lp.y))
	WafuuModels3D.add_batched_stone_lanterns(content_root, altar_lantern_pts, "#f472b6", is_mob)


# ==============================================================================
#  BATCHED REAL-LEAF WILDERNESS FORESTS (4 SPECIES = 8 DRAW CALLS TOTAL!)
# ==============================================================================
static func _build_species_tree_meshes(
	variant_idx: int,
	trunk_hex: String,
	top_hex: String,
	mid_hex: String,
	bot_hex: String,
	is_mob: bool,
	species: String
) -> Dictionary:
	return WafuuModels3D.build_tree_meshes(
		variant_idx, trunk_hex, top_hex, mid_hex, bot_hex, is_mob, species
	)


static func _add_forest_layer_multimesh(
	content_root: Node3D,
	layer_name: String,
	variant_idx: int,
	trunk_hex: String,
	top_hex: String,
	mid_hex: String,
	bot_hex: String,
	species: String,
	transforms: Array[Transform3D],
	is_mob: bool
) -> void:
	if transforms.is_empty():
		return
	var meshes: Dictionary = _build_species_tree_meshes(
		variant_idx, trunk_hex, top_hex, mid_hex, bot_hex, is_mob, species
	)
	var trunk_mesh: Mesh = meshes.get("trunk") as Mesh
	var foliage_mesh: Mesh = meshes.get("foliage") as Mesh
	var trunk_mat: Material = meshes.get("trunk_mat") as Material
	if trunk_mat == null:
		trunk_mat = WafuuModels3D.make_wafuu_mat(0, is_mob, 0.86, 0.02, 0.18)
	var foliage_mat: Material = meshes.get("foliage_mat") as Material
	if foliage_mat == null:
		foliage_mat = WafuuModels3D.make_wafuu_mat(1, is_mob, 0.54, 0.02, 0.0)

	if trunk_mesh != null:
		_add_batched_multimesh(content_root, trunk_mesh, transforms, "%s_Trunks" % layer_name, trunk_mat)
	if foliage_mesh != null:
		_add_batched_multimesh(content_root, foliage_mesh, transforms, "%s_Foliage" % layer_name, foliage_mat)


static func _is_blocked_for_tree(x: float, z: float) -> bool:
	if x < MIN_X + 4.5 or x > MAX_X - 4.5 or z < MIN_Z + 5.0 or z > MAX_Z - 6.0:
		return true
	# Player spawn & fjord beach opening
	if Vector2(x, z - 104.0).length() < 11.5:
		return true
	if z > 100.0 and absf(x) < 22.0:
		return true
	# Fjord pier & boat corridor
	if x > 7.5 and x < 26.5 and z > 103.5 and z < 123.5:
		return true
	# Winding coastal pilgrimage trail & North pilgrimage road
	if z >= 42.0 and z <= 100.0 and absf(x - _coastal_trail_x(z)) < 7.2:
		return true
	if z >= -98.0 and z <= 42.0 and absf(x) < 8.0:
		return true
	# Mountain Overlook Trail & Cliff Terrace (-42, 72)
	var tinfo: Vector2 = _mountain_trail_info(x, z)
	if tinfo.x < 6.8 or Vector2(x - TRAIL_END_2D.x, z - TRAIL_END_2D.y).length() < 8.5:
		return true
	# Sakura Village buildings, plaza & NPCs
	if z > 15.0 and z < 44.5 and absf(x) < 34.5:
		# Allow curated Sakura trees only via explicit Sakura placements; block random forest overlap!
		if absf(x) < 26.0:
			return true
		if Vector2(x + 29.0, z - 38.5).length() < 8.5 or Vector2(x - 29.0, z - 38.5).length() < 8.5:
			return true
	# East Cedar Bridge & Koi River corridor
	if absf(x - 24.0) < 6.0 and z > -4.0 and z < 22.0:
		return true
	if absf(z - _river_center_z(x)) < 5.6 and x < 42.0:
		return true
	# Moonlit Lake water & south sandy beach / pier corridor
	if _lake_norm_dist(x, z) < 1.12:
		return true
	if x > 45.0 and x < 64.0 and z > 20.0 and z < 36.5:
		return true
	# Scholar Kenta, Jizo Shrine, Bamboo Ambush Arena & Lookout Deck
	if Vector2(x + 35.0, z + 29.0).length() < 10.5:
		return true
	if Vector2(x - 2.0, z + 34.0).length() < 14.0:
		return true
	if Vector2(x - 32.0, z + 26.0).length() < 10.0:
		return true
	if x > 18.0 and x < 29.5 and absf(z + 26.0) < 5.0:
		return true
	# Sakura Healing Spring & Elder Byakko Alcove
	if Vector2(x - SPRING_POS_2D.x, z - SPRING_POS_2D.y).length() < 9.5:
		return true
	if Vector2(x - 19.0, z + 72.0).length() < 9.5:
		return true
	# Grand Night-Sakura Altar central boss arena, columns, monolith & giant weeping sakura
	if z < -93.0 and absf(x) < 28.0:
		return true
	return false


static func _append_canopy_spots(canopy_spots: Array, xforms: Array[Transform3D], species: String) -> void:
	for xf: Transform3D in xforms:
		var p: Vector3 = xf.origin
		var sc: float = xf.basis.x.length()
		var ground_y: float = get_base_terrain_height(p.x, p.z)
		canopy_spots.append({
			"pos": Vector3(p.x, ground_y + 4.8 * sc, p.z),
			"species": species,
			"radius": 3.4 * sc,
		})


static func _build_batched_wilderness_forests(arena: Arena3D, content_root: Node3D, is_mob: bool) -> void:
	var rng := RandomNumberGenerator.new()
	var canopy_spots: Array = []

	# 1. Wilderness Broadleaf Forest (45 mobile / 85 desktop) — lush emerald & sunlit green canopy
	rng.seed = 71001
	var broad_target: int = 45 if is_mob else 85
	var broad_xforms: Array[Transform3D] = []
	var att: int = 0
	while broad_xforms.size() < broad_target and att < broad_target * 14:
		att += 1
		var x: float = rng.randf_range(MIN_X + 6.0, MAX_X - 6.0)
		var z: float = rng.randf_range(-108.0, 102.0)
		if _is_blocked_for_tree(x, z):
			continue
		var y: float = get_base_terrain_height(x, z)
		if y < 0.35 or y > 22.0:
			continue
		var nrm: Vector3 = get_terrain_normal(x, z)
		if nrm.y < 0.72:
			continue
		var sc: float = rng.randf_range(1.15, 1.85)
		var yaw: float = rng.randf_range(0.0, TAU)
		var b: Basis = Basis(Vector3.UP, yaw).scaled(Vector3(sc, sc * rng.randf_range(0.92, 1.18), sc))
		broad_xforms.append(Transform3D(b, Vector3(x, y - 0.18, z)))

	_add_forest_layer_multimesh(
		content_root, "WildernessBroadleafForest", 0,
		"#3f2c1f", "#65a30d", "#2e7d32", "#14532d",
		"broadleaf", broad_xforms, is_mob
	)
	_append_canopy_spots(canopy_spots, broad_xforms, "broadleaf")

	# 2. Coastal & Mountain Red Pines (28 mobile / 55 desktop) — Mount Sakuradake, East Headland, Fjord Cliffs & Lake Cove
	rng.seed = 72002
	var pine_target: int = 28 if is_mob else 55
	var pine_xforms: Array[Transform3D] = []
	# Curated signature coastal pines framing the Fjord Beach, Overlook & Moonlit Lake!
	var curated_pines: Array = [
		[Vector2(-26.5, 106.0), 1.45, 0.8],
		[Vector2(-35.0, 96.0),  1.60, 1.4],
		[Vector2(-48.0, 82.0),  1.75, 2.2],
		[Vector2(-50.5, 65.0),  1.65, 0.3],
		[Vector2(34.0, 106.0),  1.48, -1.2],
		[Vector2(44.0, 96.0),   1.65, -2.0],
		[Vector2(54.0, 110.0),  1.72, -0.7],
		[Vector2(78.5, 29.0),   1.42, -2.2],
		[Vector2(82.0, 11.0),   1.50, -1.5],
		[Vector2(72.0, -3.5),   1.48, -0.9],
		[Vector2(34.5, 29.0),   1.38,  0.9],
	]
	for cp in curated_pines:
		var pp: Vector2 = cp[0]
		var py: float = get_base_terrain_height(pp.x, pp.y)
		var psc: float = float(cp[1])
		var pb: Basis = Basis(Vector3.UP, float(cp[2])).scaled(Vector3(psc, psc, psc))
		pine_xforms.append(Transform3D(pb, Vector3(pp.x, py - 0.25, pp.y)))

	att = 0
	while pine_xforms.size() < pine_target and att < pine_target * 16:
		att += 1
		var px: float
		var pz: float
		if att % 3 != 0:
			# Mount Sakuradake & West Fjord Mountain slopes
			px = rng.randf_range(-112.0, -28.0)
			pz = rng.randf_range(16.0, 128.0)
		else:
			# East Fjord Headland & outer mountain ridges
			px = rng.randf_range(36.0, 112.0)
			pz = rng.randf_range(-90.0, 128.0)
		if _is_blocked_for_tree(px, pz):
			continue
		var py: float = get_base_terrain_height(px, pz)
		if py < 0.45 or py > 34.0:
			continue
		var nrm: Vector3 = get_terrain_normal(px, pz)
		if nrm.y < 0.62:
			continue
		var psc: float = rng.randf_range(1.22, 1.95)
		var pyaw: float = rng.randf_range(0.0, TAU)
		var pb: Basis = Basis(Vector3.UP, pyaw).scaled(Vector3(psc, psc * rng.randf_range(0.95, 1.25), psc))
		pine_xforms.append(Transform3D(pb, Vector3(px, py - 0.30, pz)))

	_add_forest_layer_multimesh(
		content_root, "CoastalMountainPines", 1,
		"#5c3322", "#3b8c52", "#1e6138", "#0f3d23",
		"pine", pine_xforms, is_mob
	)
	_append_canopy_spots(canopy_spots, pine_xforms, "pine")

	# 3. Autumn Mountain Maples (18 mobile / 36 desktop) — fiery crimson accents in gorge & mountain flanks
	rng.seed = 73003
	var maple_target: int = 18 if is_mob else 36
	var maple_xforms: Array[Transform3D] = []
	var curated_maples: Array = [
		[Vector2(-46.0, -22.0), 1.50, 0.4],
		[Vector2(-44.0, -38.0), 1.42, 1.9],
		[Vector2(44.0, -20.0),  1.52, 2.7],
		[Vector2(46.0, -38.0),  1.45, 0.9],
		[Vector2(-24.0, -60.0), 1.48, 1.5],
		[Vector2(26.0, -60.0),  1.48, 3.1],
	]
	for cm in curated_maples:
		var mp: Vector2 = cm[0]
		var my: float = get_base_terrain_height(mp.x, mp.y)
		var msc: float = float(cm[1])
		maple_xforms.append(Transform3D(Basis(Vector3.UP, float(cm[2])).scaled(Vector3.ONE * msc), Vector3(mp.x, my - 0.18, mp.y)))

	att = 0
	while maple_xforms.size() < maple_target and att < maple_target * 16:
		att += 1
		var mx: float = rng.randf_range(-104.0, 104.0)
		var mz: float = rng.randf_range(-108.0, 2.0)
		if _is_blocked_for_tree(mx, mz):
			continue
		var my: float = get_base_terrain_height(mx, mz)
		if my < 0.45 or my > 19.0:
			continue
		var nrm: Vector3 = get_terrain_normal(mx, mz)
		if nrm.y < 0.72:
			continue
		var msc: float = rng.randf_range(1.18, 1.72)
		var myaw: float = rng.randf_range(0.0, TAU)
		maple_xforms.append(Transform3D(Basis(Vector3.UP, myaw).scaled(Vector3.ONE * msc), Vector3(mx, my - 0.18, mz)))

	_add_forest_layer_multimesh(
		content_root, "AutumnMountainMaples", 2,
		"#3b241d", "#fb923c", "#dc2626", "#7f1d1d",
		"maple", maple_xforms, is_mob
	)
	_append_canopy_spots(canopy_spots, maple_xforms, "maple")

	# 4. Sakura Groves (20 mobile / 36 desktop) — Sakura Village, Flower Meadows, Senbon Torii & Grand Altar
	rng.seed = 74004
	var sakura_target: int = 20 if is_mob else 36
	var sakura_xforms: Array[Transform3D] = []
	var curated_sakura: Array = [
		# Framing Sakura Village Plaza (zero building/NPC overlap!)
		[Vector2(-19.5, 44.5), 1.38, 0.5],
		[Vector2(19.5, 44.5),  1.42, 1.8],
		[Vector2(-38.0, 28.0), 1.48, 2.4],
		[Vector2(-32.0, 19.0), 1.34, 0.9],
		[Vector2(-11.5, 47.5), 1.32, 3.1],
		[Vector2(11.5, 47.5),  1.35, 1.2],
		# Scenic Coastal Wildflower Meadow Sakura
		[Vector2(-16.0, 70.0), 1.52, 0.6],
		[Vector2(20.0, 68.0),  1.55, 2.1],
		[Vector2(-14.0, 86.0), 1.40, 1.4],
		[Vector2(16.0, 84.0),  1.45, 2.8],
		# Framing Senbon Torii & Healing Spring
		[Vector2(-25.5, -77.5), 1.50, 0.7],
		[Vector2(-12.5, -62.0), 1.38, 1.9],
		[Vector2(12.5, -62.0),  1.38, 2.5],
		[Vector2(-14.5, -86.0), 1.46, 0.4],
		[Vector2(14.5, -86.0),  1.46, 3.0],
		# Framing Grand Night-Sakura Altar Sanctuary
		[Vector2(-32.0, -102.0), 1.68, 0.8],
		[Vector2(32.0, -102.0),  1.68, 2.1],
		[Vector2(-34.0, -118.0), 1.72, 1.5],
		[Vector2(34.0, -118.0),  1.72, 2.9],
		[Vector2(-22.0, -128.0), 1.62, 0.3],
		[Vector2(22.0, -128.0),  1.62, 2.4],
	]
	for cs in curated_sakura:
		if sakura_xforms.size() >= sakura_target:
			break
		var sp: Vector2 = cs[0]
		var sy: float = get_base_terrain_height(sp.x, sp.y)
		var ssc: float = float(cs[1])
		sakura_xforms.append(Transform3D(Basis(Vector3.UP, float(cs[2])).scaled(Vector3.ONE * ssc), Vector3(sp.x, sy - 0.16, sp.y)))

	att = 0
	while sakura_xforms.size() < sakura_target and att < sakura_target * 16:
		att += 1
		var sx: float = rng.randf_range(-56.0, 56.0)
		var sz: float = rng.randf_range(-126.0, 92.0)
		if _is_blocked_for_tree(sx, sz):
			continue
		var sy: float = get_base_terrain_height(sx, sz)
		if sy < 0.42 or sy > 12.0:
			continue
		var nrm: Vector3 = get_terrain_normal(sx, sz)
		if nrm.y < 0.78:
			continue
		var ssc: float = rng.randf_range(1.24, 1.66)
		var syaw: float = rng.randf_range(0.0, TAU)
		sakura_xforms.append(Transform3D(Basis(Vector3.UP, syaw).scaled(Vector3.ONE * ssc), Vector3(sx, sy - 0.16, sz)))

	_add_forest_layer_multimesh(
		content_root, "SakuraGroves", 0,
		"#44291f", "#fce7f3", "#f472b6", "#9d174d",
		"sakura", sakura_xforms, is_mob
	)
	_append_canopy_spots(canopy_spots, sakura_xforms, "sakura")

	# 5. Monumental Giant Weeping Sakura behind the Grand Altar Monolith
	var altar_y: float = get_base_terrain_height(0.0, -129.0)
	canopy_spots.append({
		"pos": Vector3(0.0, altar_y + 7.5, -129.0),
		"species": "sakura",
		"radius": 6.5,
	})
	arena.set_meta("leaf_canopy_spots", canopy_spots)


# ==============================================================================
#  LUSH INTERACTIVE FLORA, WILDFLOWERS, REEDS, LOTUS & MOONLIT LAKE
# ==============================================================================
static func _make_foliage_mat(
	foliage_shader: Shader,
	sway_scale: float,
	bend_radius: float,
	is_mob: bool,
	foliage_mats_out: Array
) -> Material:
	if foliage_shader != null:
		var sm := ShaderMaterial.new()
		sm.shader = foliage_shader
		sm.set_shader_parameter("wind_strength", 1.0)
		sm.set_shader_parameter("wind_dir", Vector2(0.85, 0.52))
		sm.set_shader_parameter("sway_scale", sway_scale)
		sm.set_shader_parameter("bend_radius", bend_radius)
		sm.set_shader_parameter("mobile_mode", is_mob)
		foliage_mats_out.append(sm)
		return sm

	var fb := StandardMaterial3D.new()
	fb.vertex_color_use_as_albedo = true
	fb.albedo_color = Color.WHITE
	fb.roughness = 0.72
	fb.cull_mode = BaseMaterial3D.CULL_DISABLED
	return fb


static func _basis_align_normal(nrm: Vector3, yaw: float) -> Basis:
	var up: Vector3 = Vector3.UP.lerp(nrm.normalized(), 0.65).normalized()
	var ref_fwd := Vector3(sin(yaw), 0.0, cos(yaw))
	var right: Vector3 = up.cross(ref_fwd)
	if right.length_squared() < 0.0001:
		right = Vector3.RIGHT
	right = right.normalized()
	var fwd: Vector3 = right.cross(up).normalized()
	return Basis(right, up, fwd)


static func _is_blocked_for_meadow(x: float, z: float) -> bool:
	if x < MIN_X + 3.0 or x > MAX_X - 3.0 or z < -95.0 or z > 106.0:
		return true
	# Player spawn & 5 NPC clearings
	if Vector2(x, z - 104.0).length() < 6.0:
		return true
	if Vector2(x, z - 30.0).length() < 4.2:
		return true
	if Vector2(x + 14.5, z - 26.0).length() < 3.8:
		return true
	if Vector2(x - 15.0, z - 25.0).length() < 3.8:
		return true
	if Vector2(x + 34.0, z + 28.0).length() < 4.2:
		return true
	if Vector2(x - 18.0, z + 72.0).length() < 5.5:
		return true
	# Sakura Healing Spring
	if Vector2(x - SPRING_POS_2D.x, z - SPRING_POS_2D.y).length() < SPRING_RADIUS + 1.0:
		return true
	# Village buildings, Jizo shrine, Lookout terrace + ramp, piers
	if Vector2(x + 20.0, z - 26.5).length() < 6.2:
		return true
	if Vector2(x + 12.2, z - 31.0).length() < 2.4:
		return true
	if Vector2(x - 20.8, z - 25.8).length() < 6.0:
		return true
	if Vector2(x + 29.0, z - 38.5).length() < 7.0:
		return true
	if Vector2(x - 29.0, z - 38.5).length() < 7.0:
		return true
	if Vector2(x + 36.5, z + 30.5).length() < 4.0:
		return true
	if Vector2(x - 32.0, z + 26.0).length() < 6.8:
		return true
	if x > 19.5 and x < 28.5 and absf(z + 26.0) < 2.8:
		return true
	if x > 49.0 and x < 59.0 and z > 21.0 and z < 34.0:
		return true
	if x > 9.0 and x < 21.0 and z > 105.0 and z < 120.0:
		return true
	# Four bamboo clearing boulders
	if (
		Vector2(x + 11.5, z + 24.0).length() < 2.4
		or Vector2(x - 12.0, z + 22.5).length() < 2.4
		or Vector2(x + 11.0, z + 42.0).length() < 2.4
		or Vector2(x - 12.5, z + 43.0).length() < 2.4
	):
		return true
	return false


static func _build_lush_nature_and_lake(
	arena: Arena3D,
	content_root: Node3D,
	prop_shader: Shader,
	sky_anim_nodes: Array[Dictionary],
	is_mob: bool
) -> void:
	const FOLIAGE_SHADER_PATH: String = "res://assets/shaders/foliage_wind_interactive.gdshader"
	var foliage_shader: Shader = null
	if ResourceLoader.exists(FOLIAGE_SHADER_PATH):
		foliage_shader = load(FOLIAGE_SHADER_PATH) as Shader

	var foliage_mats: Array = []
	var grass_mat := _make_foliage_mat(foliage_shader, 0.28, 1.65, is_mob, foliage_mats)
	var reed_mat := _make_foliage_mat(foliage_shader, 0.42, 1.95, is_mob, foliage_mats)
	var flower_mat := _make_foliage_mat(foliage_shader, 0.25, 1.65, is_mob, foliage_mats)
	arena.set_meta("interactive_foliage_mats", foliage_mats)
	if grass_mat is ShaderMaterial:
		arena.set_meta("meadow_grass_mat", grass_mat)

	var rng := RandomNumberGenerator.new()

	# 1. Distant Wind-Interactive Grass Meadow Accents (360 mobile / 680 desktop; near-player rolling carpet handles high density!)
	var grass_mesh := ArpgNatureProps.make_grass_tuft_mesh(is_mob)
	grass_mesh.surface_set_material(0, grass_mat)
	rng.seed = 20261
	var grass_target: int = 360 if is_mob else 680
	var grass_xforms: Array[Transform3D] = []
	var attempts: int = 0
	var max_attempts: int = grass_target * 10

	while grass_xforms.size() < grass_target and attempts < max_attempts:
		attempts += 1
		var gx: float
		var gz: float
		var bucket: int = attempts % 4
		if bucket == 0:
			# Lush coastal pilgrimage trail & flower meadow borders (visible immediately from beach!)
			gz = rng.randf_range(44.0, 96.0)
			var side: float = -1.0 if (attempts % 8 == 0) else 1.0
			gx = _coastal_trail_x(gz) + side * rng.randf_range(4.2, 24.0)
		elif bucket == 1:
			# North pilgrimage road & Senbon Torii grass edges
			var side: float = -1.0 if (attempts % 8 == 1) else 1.0
			gx = side * rng.randf_range(4.8, 18.0)
			gz = rng.randf_range(-92.0, 42.0)
		else:
			# Sprawling open wilderness across the entire 240x280m map
			gx = rng.randf_range(MIN_X + 5.0, MAX_X - 5.0)
			gz = rng.randf_range(-94.0, 102.0)

		if _is_blocked_for_meadow(gx, gz):
			continue
		var gy: float = get_base_terrain_height(gx, gz)
		if gy < 0.16 or gy > 18.0:
			continue
		var w: Color = get_terrain_material_weights(gx, gz, gy)
		if w.r > 0.34 or w.b > 0.30 or w.a > 0.24:
			continue
		var nrm: Vector3 = get_terrain_normal(gx, gz)
		if nrm.y < 0.72:
			continue

		var yaw: float = rng.randf_range(0.0, TAU)
		var sc_xz: float = rng.randf_range(0.90, 1.55)
		var sc_y: float = rng.randf_range(0.85, 1.42)
		var b: Basis = _basis_align_normal(nrm, yaw).scaled(Vector3(sc_xz, sc_y, sc_xz))
		grass_xforms.append(Transform3D(b, Vector3(gx, gy - 0.04, gz)))

	_add_batched_multimesh(content_root, grass_mesh, grass_xforms, "GrassMeadowMultiMesh")

	# 2. Three Wildflower Species (240 mobile / 460 desktop total)
	# Kind 0: Cosmos 秋櫻 (95/180) | Kind 1: Nanohana 油菜花 (85/160) | Kind 2: Higanbana 彼岸花 (60/120)
	var flower_specs: Array = [
		[0, "CosmosFlowersMM",    95 if is_mob else 180, 30301],
		[1, "NanohanaFlowersMM",  85 if is_mob else 160, 30302],
		[2, "HiganbanaFlowersMM", 60 if is_mob else 120, 30303],
	]
	for fspec in flower_specs:
		var fkind: int = int(fspec[0])
		var fname: String = String(fspec[1])
		var ftarget: int = int(fspec[2])
		rng.seed = int(fspec[3])

		var fmesh := ArpgNatureProps.make_flower_cluster_mesh(fkind, is_mob)
		fmesh.surface_set_material(0, flower_mat)
		var fxforms: Array[Transform3D] = []
		var fatt: int = 0
		var fmax: int = ftarget * 14

		while fxforms.size() < ftarget and fatt < fmax:
			fatt += 1
			var fx: float
			var fz: float
			if fkind == 0:
				# Cosmos: sweeping coastal sea-breeze flower sea (峽灣曠野・海風花海) & village lawns
				if fatt % 3 != 0:
					fz = rng.randf_range(44.0, 96.0)
					fx = rng.randf_range(-34.0, 48.0)
				else:
					fx = rng.randf_range(-60.0, 34.0)
					fz = rng.randf_range(16.0, 48.0)
			elif fkind == 1:
				# Nanohana: sunny golden coastal hills & Moonlit Lake meadows
				if fatt % 2 == 0:
					fx = rng.randf_range(8.0, 92.0)
					fz = rng.randf_range(36.0, 88.0)
				else:
					fx = rng.randf_range(24.0, 92.0)
					fz = rng.randf_range(-4.0, 42.0)
			else:
				# Higanbana: dramatic crimson lilies lining bamboo gorge & Senbon Torii mountain ascent
				if fatt % 2 == 0:
					var side: float = -1.0 if (fatt % 4 == 0) else 1.0
					fx = side * rng.randf_range(4.8, 16.0)
					fz = rng.randf_range(-92.0, -52.0)
				else:
					fx = rng.randf_range(-62.0, 62.0)
					fz = rng.randf_range(-56.0, -2.0)

			if _is_blocked_for_meadow(fx, fz):
				continue
			var fy: float = get_base_terrain_height(fx, fz)
			if fy < 0.18 or fy > 14.0:
				continue
			var fw: Color = get_terrain_material_weights(fx, fz, fy)
			if fw.r > 0.36 or fw.b > 0.30 or fw.a > 0.24:
				continue
			var fnrm: Vector3 = get_terrain_normal(fx, fz)
			if fnrm.y < 0.74:
				continue

			var fyaw: float = rng.randf_range(0.0, TAU)
			var fsc: float = rng.randf_range(0.92, 1.42)
			var fb: Basis = _basis_align_normal(fnrm, fyaw).scaled(Vector3(fsc, fsc * rng.randf_range(0.92, 1.18), fsc))
			fxforms.append(Transform3D(fb, Vector3(fx, fy - 0.03, fz)))

		_add_batched_multimesh(content_root, fmesh, fxforms, fname)

	# 3. Lakeside, Riverbank & Fjord Cove Reeds (90 mobile / 160 desktop)
	var reed_mesh := ArpgNatureProps.make_reed_cluster_mesh(is_mob)
	reed_mesh.surface_set_material(0, reed_mat)
	rng.seed = 40401
	var reed_target: int = 90 if is_mob else 160
	var reed_xforms: Array[Transform3D] = []
	var ratt: int = 0
	var rmax: int = reed_target * 16

	while reed_xforms.size() < reed_target and ratt < rmax:
		ratt += 1
		var rx: float
		var rz: float
		var rbucket: int = ratt % 3
		if rbucket == 0:
			# Moonlit Lake shoreline rim (leaving south sandy beach & pier entrance wide open!)
			var ang: float = rng.randf_range(0.0, TAU)
			var rad_n: float = rng.randf_range(0.74, 0.94)
			rx = LAKE_CENTER.x + cos(ang) * LAKE_RX * rad_n
			rz = LAKE_CENTER.y + sin(ang) * LAKE_RZ * rad_n
			if rx > 47.0 and rx < 64.0 and rz > 22.0:
				continue
		elif rbucket == 1:
			# Koi River north & south banks
			rx = rng.randf_range(-108.0, 34.0)
			var bank_side: float = -1.0 if (ratt % 2 == 0) else 1.0
			rz = _river_center_z(rx) + bank_side * rng.randf_range(2.2, 4.0)
		else:
			# Fjord beach rocky flanks (leaving central spawn beach & fjord pier clear!)
			var fside: float = -1.0 if (ratt % 2 == 0) else 1.0
			rx = fside * rng.randf_range(19.0, 34.0)
			rz = _fjord_shore_z(rx) + rng.randf_range(-3.0, 2.5)
			if rx > 10.0 and rx < 24.0:
				continue

		# Keep bridges clear
		if absf(rx) < 4.8 or absf(rx - 24.0) < 3.8:
			continue
		if rx < MIN_X + 2.5 or rx > MAX_X - 2.5:
			continue

		var ry: float = get_base_terrain_height(rx, rz)
		if ry < -0.52 or ry > 0.25:
			continue

		var ryaw: float = rng.randf_range(0.0, TAU)
		var rsc: float = rng.randf_range(0.86, 1.32)
		var rbasis: Basis = Basis(Vector3.UP, ryaw).scaled(Vector3(rsc, rsc * rng.randf_range(0.90, 1.22), rsc))
		reed_xforms.append(Transform3D(rbasis, Vector3(rx, ry - 0.05, rz)))

	_add_batched_multimesh(content_root, reed_mesh, reed_xforms, "LakesideAndFjordReedsMM")

	# 4. Floating Lotus Pads & Blossoms (18 mobile / 32 desktop) on Moonlit Lake
	var lotus_mesh := ArpgNatureProps.make_lotus_pad_mesh()
	var lotus_mat := WafuuModels3D.make_wafuu_mat(1, is_mob, 0.44, 0.02, 0.0)
	lotus_mat.set_shader_parameter("wind_strength", 0.0)
	lotus_mesh.surface_set_material(0, lotus_mat)

	rng.seed = 50501
	var lotus_target: int = 18 if is_mob else 32
	var lotus_xforms: Array[Transform3D] = []
	var latt: int = 0
	while lotus_xforms.size() < lotus_target and latt < lotus_target * 14:
		latt += 1
		var ang: float = rng.randf_range(0.0, TAU)
		var rr: float = sqrt(rng.randf_range(0.04, 0.56))
		var lx: float = LAKE_CENTER.x + cos(ang) * LAKE_RX * rr
		var lz: float = LAKE_CENTER.y + sin(ang) * LAKE_RZ * rr
		# Keep Moonlit Lake pier corridor & moored rowboat zone clear
		if lx > 49.0 and lx < 62.5 and lz > 20.5 and lz < 32.5:
			continue
		if get_base_terrain_height(lx, lz) > WATER_LEVEL - 0.30:
			continue
		var lyaw: float = rng.randf_range(0.0, TAU)
		var lsc: float = rng.randf_range(0.82, 1.32)
		var lbasis: Basis = Basis(Vector3.UP, lyaw).scaled(Vector3(lsc, lsc, lsc))
		lotus_xforms.append(Transform3D(lbasis, Vector3(lx, WATER_LEVEL + 0.02, lz)))

	_add_batched_multimesh(content_root, lotus_mesh, lotus_xforms, "FloatingLotusMM")

	# 5. Walkable Wooden Lakeside Boat Pier jutting from Moonlit Lake's South Sandy Beach
	var lake_pier_start := Vector3(52.0, get_base_terrain_height(52.0, 31.5) + 0.04, 31.5)
	var lake_pier_end := Vector3(55.5, WATER_LEVEL + 0.55, 22.5)
	ArpgNatureProps.add_lakeside_pier(arena, content_root, prop_shader, lake_pier_start, lake_pier_end, 3.2)

	# 6. Moored Traditional Japanese Wasen Rowboat gently bobbing beside the Moonlit Lake pier tip
	var lake_boat_pos := Vector3(59.2, WATER_LEVEL + 0.04, 23.0)
	ArpgNatureProps.add_moored_rowboat(content_root, lake_boat_pos, -0.45, sky_anim_nodes)

	# 7. Swimming School of Colorful Japanese Koi gliding beneath Moonlit Lake
	ArpgNatureProps.add_swimming_koi_school(
		content_root, Vector3(LAKE_CENTER.x, WATER_LEVEL, LAKE_CENTER.y),
		WATER_LEVEL, sky_anim_nodes, is_mob
	)


# ==============================================================================
#  SKY LANDMARKS & AMBIENT PARTICLES
# ==============================================================================
static func _build_sky_landmarks(content_root: Node3D, sky_anim_nodes: Array[Dictionary]) -> void:
	# 18 Drifting Wafuu Sky Lanterns (天燈) softly bobbing around the grand 240x280m perimeter
	var lantern_mesh := CylinderMesh.new()
	lantern_mesh.top_radius = 0.95; lantern_mesh.bottom_radius = 0.58; lantern_mesh.height = 2.15
	lantern_mesh.radial_segments = 6; lantern_mesh.rings = 1

	var warm_mat := StandardMaterial3D.new()
	warm_mat.albedo_color = Color.html("#fde68a")
	warm_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var pink_mat := StandardMaterial3D.new()
	pink_mat.albedo_color = Color.html("#f9a8d4")
	pink_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	for i: int in range(18):
		var ang: float = (float(i) / 18.0) * TAU + 0.14
		var rx: float = 128.0 + float(i % 3) * 14.0
		var rz: float = 148.0 + float(i % 3) * 14.0
		var y_base: float = 24.0 + float(i % 4) * 6.5
		var pos := Vector3(cos(ang) * rx, y_base, MAP_CENTER_Z + sin(ang) * rz)
		var lan := MeshInstance3D.new()
		lan.mesh = lantern_mesh
		lan.material_override = warm_mat if i % 2 == 0 else pink_mat
		lan.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		lan.position = pos
		content_root.add_child(lan)
		sky_anim_nodes.append({
			"node": lan,
			"kind": "bob",
			"base_pos": pos,
			"speed": 0.58 + float(i % 3) * 0.18,
			"phase": float(i) * 1.15,
			"amp": 1.85,
		})

	# Moonlit Cloud Ring high above the 240x280m world (1 single MeshInstance3D = 1 draw call!)
	var cloud_mat := StandardMaterial3D.new()
	cloud_mat.albedo_color = Color(0.95, 0.74, 0.88, 0.28)
	cloud_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cloud_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var puff_a := SphereMesh.new(); puff_a.radius = 12.5; puff_a.height = 5.4; puff_a.radial_segments = 10; puff_a.rings = 5
	var puff_b := SphereMesh.new(); puff_b.radius = 8.6; puff_b.height = 4.2; puff_b.radial_segments = 8; puff_b.rings = 4

	var st_clouds := SurfaceTool.new()
	st_clouds.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cloud_count: int = 10
	var cloud_rad: float = 175.0
	for ci: int in range(cloud_count):
		var ang: float = (float(ci) / float(cloud_count)) * TAU
		var grp_xform := Transform3D(
			Basis.from_euler(Vector3(0.0, -ang, 0.0)),
			Vector3(cos(ang) * cloud_rad, 56.0 + sin(float(ci) * 2.1) * 5.5, sin(ang) * cloud_rad)
		)
		st_clouds.append_from(puff_a, 0, grp_xform)
		st_clouds.append_from(puff_b, 0, grp_xform * Transform3D(Basis.IDENTITY, Vector3(0.0, -0.7, 8.5)))
		st_clouds.append_from(puff_b, 0, grp_xform * Transform3D(Basis.IDENTITY, Vector3(0.0, -0.6, -8.2)))

	var cloud_ring := MeshInstance3D.new()
	cloud_ring.name = "MoonlitCloudRing"
	cloud_ring.mesh = st_clouds.commit()
	cloud_ring.material_override = cloud_mat
	cloud_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cloud_ring.position = Vector3(0.0, 0.0, MAP_CENTER_Z)
	content_root.add_child(cloud_ring)
	sky_anim_nodes.append({"node": cloud_ring, "kind": "spin", "speed": 0.018})

	# Giant Luminous Full Moon perched majestically beyond the North Grand Altar
	var moon := MeshInstance3D.new()
	var ms := SphereMesh.new()
	ms.radius = 16.5; ms.height = 33.0; ms.radial_segments = 16; ms.rings = 10
	var mm := StandardMaterial3D.new()
	mm.albedo_color = Color.html("#fef3c7")
	mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	moon.mesh = ms
	moon.material_override = mm
	moon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	moon.position = Vector3(0.0, 62.0, -210.0)
	content_root.add_child(moon)


static func _build_ambient_particles(content_root: Node3D, particle_col: Color, is_mob: bool) -> void:
	var particles := CPUParticles3D.new()
	particles.name = "SakuraPetals"
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	particles.amount = 65 if is_mob else 160
	particles.lifetime = 11.0
	particles.preprocess = 5.5
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	particles.emission_box_extents = Vector3(115.0, 2.0, 135.0)
	particles.position = Vector3(0.0, 24.0, MAP_CENTER_Z)
	particles.direction = Vector3(0.16, -1.0, 0.12)
	particles.spread = 24.0
	particles.gravity = Vector3(0.0, -0.14, 0.0)
	particles.initial_velocity_min = 1.2
	particles.initial_velocity_max = 2.2

	var p_mesh := QuadMesh.new()
	p_mesh.size = Vector2(0.32, 0.32)
	var p_mat := StandardMaterial3D.new()
	p_mat.albedo_color = Color(particle_col.r, particle_col.g, particle_col.b, 0.85)
	p_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	p_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	p_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	p_mesh.material = p_mat
	particles.mesh = p_mesh
	content_root.add_child(particles)


# ==============================================================================
#  SHARED MULTIMESH, WALKABLE DECK & PILLAR HELPERS
# ==============================================================================
static func _add_batched_multimesh(
	content_root: Node3D,
	mesh: Mesh,
	transforms: Array[Transform3D],
	node_name: String = "BatchedMultiMesh",
	mat_override: Material = null
) -> void:
	if transforms.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = transforms.size()
	for i: int in range(transforms.size()):
		mm.set_instance_transform(i, transforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = node_name
	mmi.multimesh = mm
	if mat_override != null:
		mmi.material_override = mat_override
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	content_root.add_child(mmi)


static func _add_walkable_deck(
	arena: Arena3D,
	content_root: Node3D,
	prop_shader: Shader,
	top_pos: Vector3,
	rad: float,
	deck_hex: String,
	deck_dark_hex: String,
	rim_hex: String,
	surface_type: int = 1,
	grounded: bool = true
) -> void:
	var is_mob: bool = UiStyle.is_mobile_device()
	var terrain_below: float = get_base_terrain_height(top_pos.x, top_pos.z)
	var deck_h: float = maxf(1.2, top_pos.y - terrain_below + 0.85) if grounded else 0.48
	arena.platforms.append({"pos": top_pos, "radius": rad, "grounded": grounded, "slab_h": deck_h})

	var deck_mat := ShaderMaterial.new()
	deck_mat.shader = prop_shader
	deck_mat.set_shader_parameter("surface_type", surface_type)
	deck_mat.set_shader_parameter("albedo_a", Color.html(deck_hex))
	deck_mat.set_shader_parameter("albedo_b", Color.html(deck_dark_hex))
	deck_mat.set_shader_parameter("accent_color", Color.html(rim_hex))
	deck_mat.set_shader_parameter("roughness_val", 0.36 if surface_type == 3 else 0.56)
	deck_mat.set_shader_parameter("metallic_val", 0.32 if surface_type >= 2 else 0.14)
	deck_mat.set_shader_parameter("emission_strength", 0.35 if surface_type >= 2 else 0.0)

	var rim_mat := StandardMaterial3D.new()
	rim_mat.albedo_color = Color.html(rim_hex)
	rim_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	var cyl := CylinderMesh.new()
	cyl.top_radius = rad
	cyl.bottom_radius = rad * (0.96 if grounded else 0.82)
	cyl.height = deck_h
	cyl.radial_segments = 20 if is_mob else 28
	cyl.rings = 1

	var deck := MeshInstance3D.new()
	deck.mesh = cyl
	deck.material_override = deck_mat
	deck.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	deck.position = Vector3(top_pos.x, top_pos.y - deck_h * 0.5, top_pos.z)
	content_root.add_child(deck)

	var rim := _make_flat_ring(rad - 0.32, rad + 0.06, rim_mat, top_pos.y + 0.04, is_mob)
	rim.position.x = top_pos.x
	rim.position.z = top_pos.z
	content_root.add_child(rim)


static func _add_tactical_pillar(
	arena: Arena3D,
	content_root: Node3D,
	base_pos: Vector3,
	rad: float,
	height: float,
	stone_hex: String,
	trim_hex: String,
	is_mob: bool
) -> void:
	arena.obstacles.append({"pos": Vector2(base_pos.x, base_pos.z), "radius": rad + 0.15, "top_y": base_pos.y + height})

	var smat := StandardMaterial3D.new()
	smat.albedo_color = Color.html(stone_hex); smat.roughness = 0.65; smat.metallic = 0.22
	var tmat := StandardMaterial3D.new()
	tmat.albedo_color = Color.html(trim_hex); tmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	var col := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = rad * 0.85; cm.bottom_radius = rad; cm.height = height; cm.radial_segments = 8; cm.rings = 1
	col.mesh = cm; col.material_override = smat
	col.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	col.position = base_pos + Vector3(0.0, height * 0.5, 0.0)
	content_root.add_child(col)

	var ring := _make_flat_ring(rad * 0.82, rad * 1.12, tmat, base_pos.y + height - 0.35, is_mob)
	ring.position.x = base_pos.x
	ring.position.z = base_pos.z
	content_root.add_child(ring)


static func _make_flat_ring(
	inner_r: float,
	outer_r: float,
	mat: Material,
	y_pos: float,
	is_mob: bool
) -> MeshInstance3D:
	var torus := TorusMesh.new()
	torus.inner_radius = inner_r
	torus.outer_radius = outer_r
	torus.rings = 24 if is_mob else 36
	torus.ring_segments = 6
	var inst := MeshInstance3D.new()
	inst.mesh = torus
	inst.material_override = mat
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	inst.position = Vector3(0.0, y_pos, 0.0)
	inst.scale = Vector3(1.0, 0.08, 1.0)
	return inst
