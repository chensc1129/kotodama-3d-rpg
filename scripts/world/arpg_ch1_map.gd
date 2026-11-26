class_name ArpgCh1Map
extends RefCounted
## Procedurally builds the sprawling Japanese-themed 3D ARPG Adventure Map for Chapter 1:
## 「第一章：櫻花之里・失落的言靈碑」 (104m × 132m pilgrimage map, X: [-52, 52], Z: [-76, 56]).

const MIN_X: float = -52.0
const MAX_X: float = 52.0
const MIN_Z: float = -76.0
const MAX_Z: float = 56.0
const MAP_CENTER_Z: float = -10.0

const WATER_LEVEL: float = -0.42
const LAKE_CENTER: Vector2 = Vector2(33.5, 11.5)
const LAKE_RX: float = 16.5
const LAKE_RZ: float = 12.0

const SPRING_POS_2D: Vector2 = Vector2(-14.0, -34.0)
const SPRING_RADIUS: float = 5.2


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


# ==============================================================================
#  1. EXACT ANALYTICAL TERRAIN HEIGHT & BIOME QUERIES
# ==============================================================================
static func get_base_terrain_height(x: float, z: float) -> float:
	var h: float = 0.0

	# Zone 1 (z: +20 .. +56): Sakura Village Plaza — flat cobblestone center around y = 0.0
	# Slight +0.25m gentle rise near village flanks |x| > 12, kept flat at spawn (0, 42)
	# and NPC spots (0, 32), (-14.5, 28), (15, 27).
	var village_z: float = _smooth01((z - 18.5) / 4.5)
	if village_z > 0.0001:
		var side_t: float = _smooth01((absf(x) - 12.0) / 10.0)
		var npc_l: float = _smooth01((Vector2(x + 14.5, z - 28.0).length() - 2.8) / 2.7)
		var npc_r: float = _smooth01((Vector2(x - 15.0, z - 27.0).length() - 2.8) / 2.7)
		h += 0.25 * side_t * village_z * npc_l * npc_r

	# Zone 3 (z: -26 .. +4): Gentle woodland rise from 0.0m (z=+4) up to 0.20m (z=-24)
	var mid_base: float = 0.20 * _smooth01((4.0 - z) / 24.0)
	h += mid_base

	# Rolling bamboo woodland undulation (y ~ 0.0 .. +0.55m), smoothed flat along central road
	var forest_mask: float = _smooth01((5.5 - z) / 4.5) * _smooth01((z + 27.0) / 5.5)
	if forest_mask > 0.0001:
		var road_fade: float = _smooth01((absf(x) - 3.6) / 4.2)
		var undul: float = (
			0.16
			+ 0.13 * sin(x * 0.14 + 0.4) * cos(z * 0.15 - 0.3)
			+ 0.08 * sin((x - z) * 0.09)
		)
		h += undul * forest_mask * road_fade

		# Slight flat mossy clearing at (-24, -10) -> y ≈ 0.35m (NPC Kenta & Jizo shrine)
		var clear_d: float = Vector2(x + 24.0, z + 10.0).length()
		var clear_t: float = (1.0 - _smooth01((clear_d - 4.5) / 5.0)) * forest_mask
		h = lerpf(h, 0.35, clear_t)

		# Eastern lookout terrace at (26, -12) -> y ≈ 1.40m (kept high and dry above Moonlit Lake)
		var terrace_d: float = Vector2(x - 26.0, z + 12.0).length()
		var terrace_t: float = (1.0 - _smooth01((terrace_d - 5.5) / 7.5)) * forest_mask
		h = lerpf(h, 1.40, terrace_t)

	# Zone 4 (z: -48 .. -26): Senbon Torii Hillside climbing smoothly from y = 0.20m at z = -25
	# up to y = 2.80m at z = -46 (~7 deg slope, ultra-walkable!)
	var climb_t: float = _smooth01((-z - 25.0) / 21.0)
	h += 2.60 * climb_t

	# Subtle level terrace around Sakura Healing Spring (-14, -34) so glowing spring rings sit flush
	var spring_d: float = Vector2(x - SPRING_POS_2D.x, z - SPRING_POS_2D.y).length()
	if spring_d < 7.8:
		var spring_t: float = 1.0 - _smooth01((spring_d - 4.0) / 3.8)
		h = lerpf(h, 1.25, spring_t)

	# Subtle level alcove terrace around Elder Byakko (16.5, -34)
	var byakko_d: float = Vector2(x - 16.5, z + 34.0).length()
	if byakko_d < 7.0:
		var byakko_t: float = 1.0 - _smooth01((byakko_d - 3.2) / 3.8)
		h = lerpf(h, 1.25, byakko_t)

	# Zone 5 (z: -76 .. -48): Elevated Grand Night-Sakura Shrine Altar plateau at y = 2.80m
	# Flat sanctuary centered at (0, -58) with gentle rim banks at outer edges |x| > 38
	var altar_mask: float = _smooth01((-z - 47.0) / 5.5)
	if altar_mask > 0.0001:
		var rim_x: float = _smooth01((absf(x) - 38.0) / 11.0)
		h += 1.10 * rim_x * altar_mask

	# Gentle golden sandy beach berm along Moonlit Lake's SE & NE outer rim (y ~ +0.28..+0.40m)
	var lake_r: float = _lake_norm_dist(x, z)
	if lake_r > 0.78 and lake_r < 1.38 and x > 21.0:
		var east_mask: float = _smooth01((x - 21.0) / 8.0)
		var berm_in: float = _smooth01((lake_r - 0.80) / 0.24)
		var berm_out: float = 1.0 - _smooth01((lake_r - 1.04) / 0.34)
		h += 0.22 * berm_in * berm_out * east_mask

	# Zone 2 (z: +4 .. +20): Sunken Koi River Valley flowing East from x=-52 into Moonlit Lake
	# Fades smoothly inside the deep lake basin (x: 25..33) so the East Cove forms an unbroken sandy beach!
	var river_east_fade: float = 1.0 - _smooth01((x - 25.0) / 8.0)
	var river_z: float = 12.0 + sin(x * 0.08) * 2.2
	var river_d: float = absf(z - river_z)
	var river_carve: float = 0.0
	if river_d < 4.4 and river_east_fade > 0.0001:
		var river_t: float = 1.0 - _smooth01((river_d - 1.4) / 3.0)
		river_carve = 1.22 * river_t * river_east_fade

	# Moonlit Lake (月見湖) Basin centered at (33.5, 11.5), semi-axes (16.5, 12.0):
	# Dips smoothly down to y = -1.55m in deep center, rising gently (< 13 deg slope)
	# across the shoreline (y = -0.42m) onto the curved Golden-White Sandy Beach (白砂浜)!
	var lake_carve: float = 0.0
	if lake_r < 1.06:
		var basin_t: float = 1.0 - _smooth01((lake_r - 0.18) / 0.86)
		lake_carve = 1.55 * basin_t

	if river_carve > 0.0001 or lake_carve > 0.0001:
		h -= _smax(river_carve, lake_carve, 0.18)

	return h


static func get_terrain_normal(x: float, z: float) -> Vector3:
	const EPS: float = 0.28
	var hx1: float = get_base_terrain_height(x + EPS, z)
	var hx0: float = get_base_terrain_height(x - EPS, z)
	var hz1: float = get_base_terrain_height(x, z + EPS)
	var hz0: float = get_base_terrain_height(x, z - EPS)
	return Vector3(hx0 - hx1, 2.0 * EPS, hz0 - hz1).normalized()


static func get_water_level(x: float, z: float) -> float:
	if z < -3.0 or z > 26.0:
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
	if w.r >= 0.42 or (w.a >= 0.42 and (z < -44.0 or h >= 1.15)):
		return "stone"
	return "grass"


# ==============================================================================
#  2. MULTI-MATERIAL FLOOR WEIGHTS (arena_floor.gdshader stage_id = 4)
# ==============================================================================
static func get_terrain_material_weights(x: float, z: float, h: float) -> Color:
	# Channel R (w_r): Carved Granite Flagstones — Village Plaza, pilgrimage road, East Bridge path, pavilions
	# Channel G (w_g): Lush Emerald Meadow Grass & Woodland Soil — village lawns, wildflower meadows, bamboo floor
	# Channel B (w_b): Golden-White Sandy Beach (白砂浜) — curved shore rim surrounding Moonlit Lake
	# Channel A (w_a): Underwater riverbed/lakebed pebbles (h < -0.50) AND elevated Grand Altar slate (z < -45.5)

	# 1. Underwater pebbles (y < -0.50) & elevated Grand Altar / Elder Byakko twilight slate (y >= 1.2)
	var wet_bed: float = _smooth01((-0.48 - h) / 0.34)
	var altar_slate: float = _smooth01((-z - 45.5) / 3.0)
	var byakko_d: float = Vector2(x - 16.5, z + 34.0).length()
	var byakko_pad: float = 1.0 - _smooth01((byakko_d - 2.6) / 1.6)
	var w_a: float = clampf(maxf(wet_bed, maxf(altar_slate, byakko_pad)), 0.0, 1.0)

	# 2. Golden-White Beach Sand (白砂浜) ringing Moonlit Lake shore & East sandy cove
	var lake_r: float = _lake_norm_dist(x, z)
	var sand_ring: float = _smooth01((lake_r - 0.56) / 0.16) * (1.0 - _smooth01((lake_r - 1.02) / 0.22))
	var sand_east: float = _smooth01((x - 19.5) / 3.2) * _smooth01((z + 3.0) / 3.0) * (1.0 - _smooth01((z - 25.0) / 3.0))
	var sand_h: float = _smooth01((h + 0.85) / 0.26) * (1.0 - _smooth01((h - 0.50) / 0.26))
	var w_b: float = clampf(sand_ring * sand_east * sand_h * 1.15, 0.0, 1.0) * (1.0 - altar_slate) * (1.0 - wet_bed * 0.72)

	# 3. Carved Granite Flagstones: pilgrimage road, Village Plaza, East Bridge path, Teahouse & Forge pads
	var road_x: float = 1.0 - _smooth01((absf(x) - 3.8) / 1.5)
	var road_z: float = (1.0 - _smooth01((z - 48.0) / 3.0)) * (1.0 - _smooth01((-z - 50.0) / 3.0))
	var road_w: float = road_x * road_z

	var plaza_x: float = 1.0 - _smooth01((absf(x) - 11.5) / 4.5)
	var plaza_z: float = _smooth01((z - 20.0) / 3.5) * (1.0 - _smooth01((z - 46.0) / 4.0))
	var plaza_w: float = plaza_x * plaza_z * 0.92

	# Stone path leading toward the East Cedar Footbridge at x = 17.5
	var east_x: float = 1.0 - _smooth01((absf(x - 17.5) - 2.0) / 1.4)
	var east_z: float = _smooth01((z - 2.0) / 3.0) * (1.0 - _smooth01((z - 24.5) / 3.0))
	var east_w: float = east_x * east_z * 0.82

	var tea_d: float = Vector2(x + 18.5, z - 29.0).length()
	var tea_pad: float = 1.0 - _smooth01((tea_d - 3.8) / 1.8)
	var forge_d: float = Vector2(x - 19.5, z - 28.0).length()
	var forge_pad: float = 1.0 - _smooth01((forge_d - 3.8) / 1.8)

	var stone_raw: float = maxf(maxf(road_w, maxf(plaza_w, east_w)), maxf(tea_pad, forge_pad))
	var w_r: float = clampf(stone_raw, 0.0, 1.0) * (1.0 - w_a * 0.88) * (1.0 - w_b * 0.85)

	# 4. Lush Emerald Meadow Grass & Woodland Soil everywhere else
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
#  4. FULL CHAPTER 1 ARPG MAP BUILDER
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

	# 1. Twilight Night-Sakura Sky & Environment
	_setup_environment(arena, sky_shader, is_mob)

	# 2. Rectangular Heightfield TerrainMesh (stage_id = 4) + 4-Edge Granite Cliff Skirts
	_build_heightfield_terrain(content_root, floor_shader, is_mob)

	# 3. Glowing Perimeter Shrine Boundary Border
	_build_perimeter_border(content_root, Color.html("#e11d48"), is_mob)

	# 4. Shimmering Koi River + Moonlit Lake Interactive Water Plane (Zone 2)
	_build_lake_and_river(arena, content_root, water_shader, is_mob)

	# 5. Two Flush-Anchored Ornate Walkable Bridges over Koi River (Zone 2)
	# Main Grand Vermilion Taiko Bridge (x = 0.0, z: 18.5 -> 5.5)
	WafuuModels3D.add_ornate_bridge(
		arena, content_root, prop_shader,
		_bridge_pt(0.0, 18.5), _bridge_pt(0.0, 5.5),
		5.2, 0.95, "#991b1b", "#450a0a", "#ef4444", 0
	)
	# East Rustic Cedar Footbridge (x = 17.5, z: 19.2 -> 6.2) framing the Moonlit Lake mouth!
	WafuuModels3D.add_ornate_bridge(
		arena, content_root, prop_shader,
		_bridge_pt(17.5, 19.2), _bridge_pt(17.5, 6.2),
		3.8, 0.72, "#7c4722", "#43220d", "#d97706", 0
	)

	# 6. Zone 1: Sakura Village Plaza Architecture
	_build_zone1_village(arena, content_root, is_mob)

	# 7. Zone 3: Misty Bamboo Forest (Single MultiMesh Grove + Jizo + Lookout Deck + Boulders)
	_build_zone3_bamboo_forest(arena, content_root, prop_shader, is_mob)

	# 8. Zone 4: Senbon Torii Hillside + Sakura Healing Spring + Elder Byakko Alcove
	_build_zone4_senbon_torii(arena, content_root, sky_anim_nodes, is_mob)

	# 9. Zone 5: Night-Sakura Grand Altar + Monolith + Giant Weeping Sakura
	_build_zone5_grand_altar(arena, content_root, sky_anim_nodes, is_mob)

	# 10. Lush Interactive Flora Meadows, Wildflowers, Reeds, Pines, Lakeside Pier, Rowboat, Koi & Beach!
	_build_lush_nature_and_lake(arena, content_root, prop_shader, sky_anim_nodes, is_mob)

	# 11. Sky Landmarks (16 Drifting Sky Lanterns + Moonlit Cloud Ring + Full Moon)
	_build_sky_landmarks(content_root, sky_anim_nodes)

	# 12. Ambient Falling Sakura Petals across the entire 104m x 132m map
	_build_ambient_particles(content_root, Color.html("#f9a8d4"), is_mob)


# ==============================================================================
#  ENVIRONMENT & TERRAIN BUILDERS
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
		env.ambient_light_energy = 1.08 if is_mob else 0.88
		env.fog_enabled = true
		env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
		env.fog_light_color = Color.html("#1a1530")
		env.fog_density = 0.0038
		env.fog_sky_affect = 0.08

	if arena.center_light != null:
		arena.center_light.light_color = Color.html("#f472b6")
		arena.center_light.light_energy = 1.75
		arena.center_light.omni_range = 135.0


static func _build_heightfield_terrain(content_root: Node3D, floor_shader: Shader, is_mob: bool) -> void:
	var nx: int = 32 if is_mob else 52
	var nz: int = 40 if is_mob else 66

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Build (nz + 1) x (nx + 1) vertex grid
	var grid: Array = []
	var eps: float = 0.28
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

	# Emit top terrain triangles with exact Godot 4 CW front-face winding when viewed from +Y:
	# v00=(ix,iz), v10=(ix+1,iz), v11=(ix+1,iz+1), v01=(ix,iz+1)
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
	var skirt_drop: float = 6.2
	var skirt_flare: float = 2.4

	# North edge (z = MIN_Z, outward normal -Z): viewer looking from -Z sees +X left, -X right
	for ix: int in range(nx):
		var top_a: Vector3 = grid[0][ix + 1][0]
		var top_b: Vector3 = grid[0][ix][0]
		var bot_a := Vector3(top_a.x, top_a.y - skirt_drop, top_a.z - skirt_flare)
		var bot_b := Vector3(top_b.x, top_b.y - skirt_drop, top_b.z - skirt_flare)
		_emit_skirt_quad(st, top_a, top_b, bot_a, bot_b, Vector3(0.0, 0.0, -1.0), skirt_w)

	# South edge (z = MAX_Z, outward normal +Z): viewer looking from +Z sees -X left, +X right
	for ix: int in range(nx):
		var top_a: Vector3 = grid[nz][ix][0]
		var top_b: Vector3 = grid[nz][ix + 1][0]
		var bot_a := Vector3(top_a.x, top_a.y - skirt_drop, top_a.z + skirt_flare)
		var bot_b := Vector3(top_b.x, top_b.y - skirt_drop, top_b.z + skirt_flare)
		_emit_skirt_quad(st, top_a, top_b, bot_a, bot_b, Vector3(0.0, 0.0, 1.0), skirt_w)

	# West edge (x = MIN_X, outward normal -X): viewer looking from -X sees -Z left, +Z right
	for iz: int in range(nz):
		var top_a: Vector3 = grid[iz][0][0]
		var top_b: Vector3 = grid[iz + 1][0][0]
		var bot_a := Vector3(top_a.x - skirt_flare, top_a.y - skirt_drop, top_a.z)
		var bot_b := Vector3(top_b.x - skirt_flare, top_b.y - skirt_drop, top_b.z)
		_emit_skirt_quad(st, top_a, top_b, bot_a, bot_b, Vector3(-1.0, 0.0, 0.0), skirt_w)

	# East edge (x = MAX_X, outward normal +X): viewer looking from +X sees +Z left, -Z right
	for iz: int in range(nz):
		var top_a: Vector3 = grid[iz + 1][nx][0]
		var top_b: Vector3 = grid[iz][nx][0]
		var bot_a := Vector3(top_a.x + skirt_flare, top_a.y - skirt_drop, top_a.z)
		var bot_b := Vector3(top_b.x + skirt_flare, top_b.y - skirt_drop, top_b.z)
		_emit_skirt_quad(st, top_a, top_b, bot_a, bot_b, Vector3(1.0, 0.0, 0.0), skirt_w)

	var mat := ShaderMaterial.new()
	mat.shader = floor_shader
	mat.set_shader_parameter("stage_id", 4)
	mat.set_shader_parameter("mobile_mode", is_mob)

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
	# Outward-facing CW winding when top_a is left and top_b is right from outside viewer
	st.set_color(col); st.set_normal(out_n); st.add_vertex(top_a)
	st.set_color(col); st.set_normal(out_n); st.add_vertex(top_b)
	st.set_color(col); st.set_normal(out_n); st.add_vertex(bot_b)

	st.set_color(col); st.set_normal(out_n); st.add_vertex(top_a)
	st.set_color(col); st.set_normal(out_n); st.add_vertex(bot_b)
	st.set_color(col); st.set_normal(out_n); st.add_vertex(bot_a)


static func _build_perimeter_border(content_root: Node3D, border_col: Color, is_mob: bool) -> void:
	var segs_x: int = 24 if is_mob else 40
	var segs_z: int = 30 if is_mob else 50
	var inset: float = 0.55
	var half_w: float = 0.30
	var x_min: float = MIN_X + inset
	var x_max: float = MAX_X - inset
	var z_min: float = MIN_Z + inset
	var z_max: float = MAX_Z - inset

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# North & South horizontal glowing strips
	for side_z: float in [z_min, z_max]:
		var za: float = side_z - half_w
		var zb: float = side_z + half_w
		for i: int in range(segs_x):
			var x0: float = lerpf(x_min - half_w, x_max + half_w, float(i) / float(segs_x))
			var x1: float = lerpf(x_min - half_w, x_max + half_w, float(i + 1) / float(segs_x))
			var y0: float = get_base_terrain_height(x0, side_z) + 0.14
			var y1: float = get_base_terrain_height(x1, side_z) + 0.14
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
			var y0: float = get_base_terrain_height(side_x, z0) + 0.14
			var y1: float = get_base_terrain_height(side_x, z1) + 0.14
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
	mat.albedo_color = border_col
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var inst := MeshInstance3D.new()
	inst.name = "PerimeterBorder"
	inst.mesh = st.commit()
	inst.material_override = mat
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	content_root.add_child(inst)


static func _build_lake_and_river(
	arena: Arena3D,
	content_root: Node3D,
	water_shader: Shader,
	is_mob: bool
) -> void:
	# Subdivided water plane spanning Koi River AND Moonlit Lake (X: -52..52, Z: -3..26)
	var pm := PlaneMesh.new()
	pm.size = Vector2(MAX_X - MIN_X, 29.0)
	pm.subdivide_width = 24 if is_mob else 48
	pm.subdivide_depth = 16 if is_mob else 32

	var wmat := ShaderMaterial.new()
	wmat.shader = water_shader
	var dc := Color.html("#0f4c81")
	var sc := Color.html("#38bdf8")
	wmat.set_shader_parameter("deep_color", Color(dc.r, dc.g, dc.b, 0.78))
	wmat.set_shader_parameter("shallow_color", Color(sc.r, sc.g, sc.b, 0.60))
	wmat.set_shader_parameter("glint_color", Color.html("#e0f2fe"))
	wmat.set_shader_parameter("wave_speed", 1.12)
	wmat.set_shader_parameter("wave_amp", 0.042)
	wmat.set_shader_parameter("wind_strength", 1.0)
	wmat.set_shader_parameter("mobile_mode", is_mob)

	var wi := MeshInstance3D.new()
	wi.name = "MoonlitLakeAndRiverWater"
	wi.mesh = pm
	wi.material_override = wmat
	wi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	wi.position = Vector3(0.0, WATER_LEVEL, 11.5)
	content_root.add_child(wi)

	arena.set_meta("interactive_water_mats", [wmat])


# ==============================================================================
#  ZONE 1: SAKURA VILLAGE PLAZA (Authentic Japanese Teahouse, Forge & Machiya!)
# ==============================================================================
static func _build_zone1_village(arena: Arena3D, content_root: Node3D, is_mob: bool) -> void:
	# Welcoming South Village Myojin Torii Gate with sacred shimenawa at (0, y, 48.0)
	WafuuModels3D.add_torii_gate(content_root, Vector3(0.0, get_base_terrain_height(0.0, 48.0), 48.0), "#dc2626", 1.15, true)

	# Traditional Japanese Teahouse (櫻花茶屋) at (-20.0, y, 28.5) facing plaza + bamboo-ribbed red wagasa
	var tea_pos := Vector3(-20.0, get_base_terrain_height(-20.0, 28.5), 28.5)
	WafuuModels3D.add_japanese_teahouse(arena, content_root, tea_pos, 1.05, 0.58)
	WafuuModels3D.add_wagasa_umbrella(content_root, Vector3(-12.2, get_base_terrain_height(-12.2, 33.0), 33.0))

	# Traditional Japanese Blacksmith Forge (鉄斎鍛冶屋) at (20.8, y, 27.8) facing plaza
	var forge_pos := Vector3(20.8, get_base_terrain_height(20.8, 27.8), 27.8)
	WafuuModels3D.add_japanese_forge(arena, content_root, forge_pos, 1.05, -0.58)

	# Twin Edo-style Machiya Village Homes framing the warm lantern-lit village flanks
	var house_w := Vector3(-28.5, get_base_terrain_height(-28.5, 40.5), 40.5)
	WafuuModels3D.add_japanese_house(arena, content_root, house_w, 1.08, 0.48, "#1e293b")
	var house_e := Vector3(28.5, get_base_terrain_height(28.5, 40.5), 40.5)
	WafuuModels3D.add_japanese_house(arena, content_root, house_e, 1.08, -0.48, "#262038")

	# Batched Carved Granite Kasuga-doro Stone Lanterns lining plaza, East Bridge & Beach approach
	var village_lanterns_2d: Array[Vector2] = [
		Vector2(-6.2, 46.5), Vector2(6.2, 46.5),
		Vector2(-7.0, 36.0), Vector2(7.0, 36.0),
		Vector2(-5.8, 21.5), Vector2(5.8, 21.5),
		Vector2(14.5, 20.8), Vector2(20.5, 20.8),
		Vector2(-15.5, 23.0), Vector2(27.2, 22.8),
	]
	var village_lantern_pts: Array[Vector3] = []
	for lp: Vector2 in village_lanterns_2d:
		village_lantern_pts.append(Vector3(lp.x, get_base_terrain_height(lp.x, lp.y), lp.y))
	WafuuModels3D.add_batched_stone_lanterns(content_root, village_lantern_pts, "#fde047", is_mob)

	# Lush Multi-Branching Sakura Trees framing Sakura Village (clear of houses, beach cove, spawn & NPC spots)
	var village_trees: Array[Vector2] = [
		Vector2(-19.5, 46.5), Vector2(19.5, 46.5),
		Vector2(-37.5, 31.0), Vector2(37.5, 31.5),
		Vector2(-29.5, 21.5), Vector2(34.5, 27.5),
		Vector2(-11.5, 49.5), Vector2(11.5, 49.5),
		Vector2(-42.5, 44.0), Vector2(42.5, 44.0),
	]
	for idx: int in range(village_trees.size()):
		var tp: Vector2 = village_trees[idx]
		var sc: float = 1.24 + float(idx % 3) * 0.16
		var leaf_hex: String = "#f472b6" if idx % 2 == 0 else "#f9a8d4"
		WafuuModels3D.add_realistic_tree(
			content_root,
			Vector3(tp.x, get_base_terrain_height(tp.x, tp.y), tp.y),
			"#44291f", leaf_hex, sc, idx % 3
		)


# ==============================================================================
#  ZONE 3: MISTY BAMBOO FOREST
# ==============================================================================
static func _build_zone3_bamboo_forest(
	arena: Arena3D,
	content_root: Node3D,
	prop_shader: Shader,
	is_mob: bool
) -> void:
	# 1. Realistic segmented bamboo groves batched into ONE single MultiMeshInstance3D!
	var bamboo_mesh := WafuuModels3D.make_realistic_bamboo_mesh(is_mob)
	var bamboo_mat := WafuuModels3D.make_wafuu_mat(5, is_mob, 0.44, 0.04)
	bamboo_mesh.surface_set_material(0, bamboo_mat)

	var rng := RandomNumberGenerator.new()
	rng.seed = 10101
	var target_count: int = 115 if is_mob else 195
	var bamboo_xforms: Array[Transform3D] = []
	var attempts: int = 0
	var max_attempts: int = target_count * 7

	while bamboo_xforms.size() < target_count and attempts < max_attempts:
		attempts += 1
		var side: float = -1.0 if (attempts % 2 == 0) else 1.0
		var bx: float = side * rng.randf_range(7.2, 46.0)
		var bz: float = rng.randf_range(-24.0, 2.5)

		# Keep clearings, Moonlit Lake, sandy beach cove & East Bridge approach open:
		if Vector2(bx + 24.0, bz + 10.0).length() < 7.2:
			continue
		if Vector2(bx - 2.0, bz + 16.0).length() < 8.0:
			continue
		if Vector2(bx - 26.0, bz + 12.0).length() < 8.4:
			continue
		if bx > 13.0 and bx < 24.0 and absf(bz + 12.0) < 3.5:
			continue
		if absf(bx - 17.5) < 4.0 and bz > -3.5:
			continue
		if _lake_norm_dist(bx, bz) < 1.18:
			continue
		if (
			Vector2(bx + 9.2, bz + 7.5).length() < 3.0
			or Vector2(bx - 9.5, bz + 6.0).length() < 3.0
			or Vector2(bx + 8.8, bz + 18.5).length() < 3.0
			or Vector2(bx - 10.2, bz + 19.0).length() < 3.0
		):
			continue

		var by: float = get_base_terrain_height(bx, bz)
		if by < 0.02:
			continue
		var h_scale: float = rng.randf_range(0.88, 1.44)
		var r_scale: float = rng.randf_range(0.88, 1.18)
		var yaw: float = rng.randf_range(0.0, TAU)
		var tilt_x: float = rng.randf_range(-0.06, 0.06)
		var tilt_z: float = rng.randf_range(-0.06, 0.06)
		var basis: Basis = Basis.from_euler(Vector3(tilt_x, yaw, tilt_z)).scaled(Vector3(r_scale, h_scale, r_scale))
		bamboo_xforms.append(Transform3D(basis, Vector3(bx, by - 0.15, bz)))

	_add_batched_multimesh(content_root, bamboo_mesh, bamboo_xforms, "BambooGroveMultiMesh")

	# 2. Roofed Wooden Hokora Jizo Shrine + Carved Stone Lantern at (-26, y, -12)
	var jizo_pos := Vector3(-26.0, get_base_terrain_height(-26.0, -12.0), -12.0)
	WafuuModels3D.add_jizo_shrine(arena, content_root, jizo_pos)

	# 3. Elevated Wooden Lookout Deck at (26.0, y + 1.2, -12.0) + Flush Ornate Wooden Ramp!
	var terrace_y: float = get_base_terrain_height(26.0, -12.0)
	var deck_top_y: float = terrace_y + 1.2
	_add_walkable_deck(
		arena, content_root, prop_shader,
		Vector3(26.0, deck_top_y, -12.0), 4.8,
		"#713819", "#421d0b", "#f59e0b", 1, true
	)
	WafuuModels3D.add_ornate_bridge(
		arena, content_root, prop_shader,
		_bridge_pt(15.2, -12.0), Vector3(21.35, deck_top_y, -12.0),
		3.2, 0.06, "#7c4722", "#43220d", "#f59e0b", 0
	)

	# 4. Four Tactical Mossy Granite Boulders (arena.obstacles) in the bamboo clearing
	var boulders: Array[Vector2] = [
		Vector2(-9.2, -7.5),
		Vector2(9.5, -6.0),
		Vector2(-8.8, -18.5),
		Vector2(10.2, -19.0),
	]
	for bp: Vector2 in boulders:
		WafuuModels3D.add_mossy_boulder(arena, content_root, Vector3(bp.x, get_base_terrain_height(bp.x, bp.y), bp.y), 1.55)

	# Road-side + Jizo + Lookout stone lanterns batched into 2 draw calls
	var forest_lantern_pts: Array[Vector3] = [
		Vector3(-22.5, get_base_terrain_height(-22.5, -13.5), -13.5),
		Vector3(28.5, deck_top_y, -14.2),
		Vector3(-5.5, get_base_terrain_height(-5.5, 1.5), 1.5),
		Vector3(5.5, get_base_terrain_height(5.5, 1.5), 1.5),
		Vector3(-5.5, get_base_terrain_height(-5.5, -12.0), -12.0),
		Vector3(5.5, get_base_terrain_height(5.5, -12.0), -12.0),
	]
	WafuuModels3D.add_batched_stone_lanterns(content_root, forest_lantern_pts, "#fde68a", is_mob)


# ==============================================================================
#  ZONE 4: SENBON TORII HILLSIDE (千本鳥居)
# ==============================================================================
static func _build_zone4_senbon_torii(
	arena: Arena3D,
	content_root: Node3D,
	sky_anim_nodes: Array[Dictionary],
	is_mob: bool
) -> void:
	# 1. Eight sequential Curved Myojin Torii Gates climbing from z = -24 to z = -45 (2 draw calls total!)
	var torii_pts: Array[Vector3] = []
	for i: int in range(8):
		var tz: float = -24.0 - float(i) * 3.0
		torii_pts.append(Vector3(0.0, get_base_terrain_height(0.0, tz), tz))
	WafuuModels3D.build_senbon_torii(content_root, torii_pts, "#dc2626")

	# 2. Glowing Sakura Healing Spring circle at (-14.0, y, -34.0)
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

	WafuuModels3D.add_stone_lantern(content_root, Vector3(-19.5, get_base_terrain_height(-19.5, -34.0), -34.0), "#f472b6")
	WafuuModels3D.add_realistic_tree(content_root, Vector3(-20.5, get_base_terrain_height(-20.5, -39.5), -39.5), "#44291f", "#f9a8d4", 1.45, 2)

	# 3. Carved Stone Shrine Alcove for Elder Byakko at (16.5, y, -34.0)
	var byakko_y: float = get_base_terrain_height(16.5, -34.0)
	WafuuModels3D.add_byakko_alcove(
		arena, content_root,
		Vector3(16.5, byakko_y, -34.0),
		Callable(ArpgCh1Map, "get_base_terrain_height")
	)

	# Hillside realistic sakura trees framing the Senbon Torii ascent
	var hill_trees: Array[Vector2] = [
		Vector2(-11.5, -26.5), Vector2(11.5, -26.5),
		Vector2(-26.0, -32.0), Vector2(28.0, -32.0),
		Vector2(-13.5, -42.5), Vector2(13.5, -42.5),
	]
	for idx: int in range(hill_trees.size()):
		var tp: Vector2 = hill_trees[idx]
		WafuuModels3D.add_realistic_tree(
			content_root,
			Vector3(tp.x, get_base_terrain_height(tp.x, tp.y), tp.y),
			"#44291f", "#f472b6", 1.32, idx % 3
		)


# ==============================================================================
#  ZONE 5: NIGHT-SAKURA GRAND ALTAR
# ==============================================================================
static func _build_zone5_grand_altar(
	arena: Arena3D,
	content_root: Node3D,
	sky_anim_nodes: Array[Dictionary],
	is_mob: bool
) -> void:
	# 1. Grand North Myojin Torii Gate with sacred shimenawa at (0.0, 2.8, -47.0), scale 1.45
	WafuuModels3D.add_torii_gate(content_root, Vector3(0.0, 2.8, -47.0), "#dc2626", 1.45, true)

	# 2. Four Tactical Shrine Columns (arena.obstacles) framing the boss sanctuary
	var columns: Array[Vector2] = [
		Vector2(-13.0, -53.0), Vector2(13.0, -53.0),
		Vector2(-13.0, -64.0), Vector2(13.0, -64.0),
	]
	for cp: Vector2 in columns:
		_add_tactical_pillar(
			arena, content_root,
			Vector3(cp.x, get_base_terrain_height(cp.x, cp.y), cp.y),
			0.88, 4.8, "#4c3b5e", "#f472b6", is_mob
		)

	# 3. Corrupted/Sacred Kotodama Monolith Stone (言靈守護碑) at (0.0, 2.8, -69.0)
	WafuuModels3D.add_kotodama_monolith(arena, content_root, Vector3(0.0, 2.8, -69.0), sky_anim_nodes, is_mob)

	# 4. Monumental Sacred Weeping Sakura Tree with Shimenawa behind the Monolith at (0.0, 2.8, -73.0)
	WafuuModels3D.add_giant_weeping_sakura(content_root, Vector3(0.0, 2.8, -73.0), is_mob)

	# 5. Perimeter Night-Sakura Trees & Batched Kasuga-doro Lanterns framing the Grand Altar
	var altar_trees: Array[Vector2] = [
		Vector2(-26.0, -52.0), Vector2(26.0, -52.0),
		Vector2(-29.0, -64.0), Vector2(29.0, -64.0),
		Vector2(-18.0, -71.5), Vector2(18.0, -71.5),
		Vector2(-38.0, -58.0), Vector2(38.0, -58.0),
	]
	for idx: int in range(altar_trees.size()):
		var tp: Vector2 = altar_trees[idx]
		var leaf_hex: String = "#f472b6" if idx % 2 == 0 else "#f9a8d4"
		WafuuModels3D.add_realistic_tree(
			content_root,
			Vector3(tp.x, get_base_terrain_height(tp.x, tp.y), tp.y),
			"#3b231e", leaf_hex, 1.52, idx % 3
		)

	var altar_lantern_pts: Array[Vector3] = []
	for lp: Vector2 in [
		Vector2(-7.5, -48.0), Vector2(7.5, -48.0),
		Vector2(-20.0, -58.0), Vector2(20.0, -58.0),
		Vector2(-7.0, -68.5), Vector2(7.0, -68.5),
	]:
		altar_lantern_pts.append(Vector3(lp.x, get_base_terrain_height(lp.x, lp.y), lp.y))
	WafuuModels3D.add_batched_stone_lanterns(content_root, altar_lantern_pts, "#f472b6", is_mob)


# ==============================================================================
#  LUSH INTERACTIVE FLORA, WILDFLOWERS, REEDS, MOONLIT LAKE & SANDY BEACH COVE
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

	# Safe fallback if interactive foliage shader is unavailable
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
	if x < MIN_X + 2.2 or x > MAX_X - 2.2 or z < -45.5 or z > MAX_Z - 2.2:
		return true
	# Player spawn & 5 NPC clearings
	if Vector2(x, z - 42.0).length() < 4.5:
		return true
	if Vector2(x, z - 32.0).length() < 3.8:
		return true
	if Vector2(x + 14.5, z - 28.0).length() < 3.6:
		return true
	if Vector2(x - 15.0, z - 27.0).length() < 3.6:
		return true
	if Vector2(x + 24.0, z + 10.0).length() < 3.6:
		return true
	if Vector2(x - 15.2, z + 34.0).length() < 5.0:
		return true
	# Sakura Healing Spring
	if Vector2(x - SPRING_POS_2D.x, z - SPRING_POS_2D.y).length() < SPRING_RADIUS + 0.9:
		return true
	# Village buildings, Jizo shrine, Lookout terrace + ramp, bench & pier approach
	if Vector2(x + 20.0, z - 28.5).length() < 5.8:
		return true
	if Vector2(x + 12.2, z - 33.0).length() < 2.4:
		return true
	if Vector2(x - 20.8, z - 27.8).length() < 5.6:
		return true
	if Vector2(x + 28.5, z - 40.5).length() < 6.8:
		return true
	if Vector2(x - 28.5, z - 40.5).length() < 6.8:
		return true
	if Vector2(x + 26.0, z + 12.0).length() < 3.6:
		return true
	if Vector2(x - 26.0, z + 12.0).length() < 6.4:
		return true
	if x > 14.5 and x < 22.5 and absf(z + 12.0) < 2.4:
		return true
	if Vector2(x - 43.2, z - 22.0).length() < 2.8:
		return true
	if x > 27.5 and x < 35.0 and z > 13.0 and z < 23.2:
		return true
	# Four bamboo clearing boulders
	if (
		Vector2(x + 9.2, z + 7.5).length() < 2.2
		or Vector2(x - 9.5, z + 6.0).length() < 2.2
		or Vector2(x + 8.8, z + 18.5).length() < 2.2
		or Vector2(x - 10.2, z + 19.0).length() < 2.2
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

	var rng := RandomNumberGenerator.new()

	# 1. Interactive Meadow Grass (340 mobile / 680 desktop) lining road edges, village lawns & meadows
	var grass_mesh := ArpgNatureProps.make_grass_tuft_mesh(is_mob)
	grass_mesh.surface_set_material(0, grass_mat)
	rng.seed = 20261
	var grass_target: int = 340 if is_mob else 680
	var grass_xforms: Array[Transform3D] = []
	var attempts: int = 0
	var max_attempts: int = grass_target * 9

	while grass_xforms.size() < grass_target and attempts < max_attempts:
		attempts += 1
		var gx: float
		var gz: float
		if attempts % 3 == 0:
			# Lush pilgrimage road-side grass borders!
			var side: float = -1.0 if (attempts % 2 == 0) else 1.0
			gx = side * rng.randf_range(4.4, 9.2)
			gz = rng.randf_range(-44.0, 47.0)
		else:
			gx = rng.randf_range(MIN_X + 2.5, MAX_X - 2.5)
			gz = rng.randf_range(-44.5, MAX_Z - 3.0)

		if _is_blocked_for_meadow(gx, gz):
			continue
		var gy: float = get_base_terrain_height(gx, gz)
		if gy < 0.04:
			continue
		var w: Color = get_terrain_material_weights(gx, gz, gy)
		if w.r > 0.34 or w.b > 0.32 or w.a > 0.24:
			continue

		var nrm: Vector3 = get_terrain_normal(gx, gz)
		var yaw: float = rng.randf_range(0.0, TAU)
		var sc_xz: float = rng.randf_range(0.85, 1.38)
		var sc_y: float = rng.randf_range(0.82, 1.32)
		var b: Basis = _basis_align_normal(nrm, yaw).scaled(Vector3(sc_xz, sc_y, sc_xz))
		grass_xforms.append(Transform3D(b, Vector3(gx, gy - 0.03, gz)))

	_add_batched_multimesh(content_root, grass_mesh, grass_xforms, "GrassMeadowMultiMesh")

	# 2. Three Vibrant Japanese Wildflower Meadows (160 mobile / 320 desktop total)
	# Kind 0: Cosmos 秋櫻 | Kind 1: Nanohana 油菜花 | Kind 2: Higanbana 彼岸花
	var flower_specs: Array = [
		[0, "CosmosFlowersMM",    65 if is_mob else 130, 30301],
		[1, "NanohanaFlowersMM",  55 if is_mob else 110, 30302],
		[2, "HiganbanaFlowersMM", 40 if is_mob else 80,  30303],
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
		var fmax: int = ftarget * 12

		while fxforms.size() < ftarget and fatt < fmax:
			fatt += 1
			var fx: float
			var fz: float
			if fkind == 0:
				# Cosmos: pilgrimage road edges, village gardens & western wildflower meadow
				if fatt % 2 == 0:
					var side: float = -1.0 if (fatt % 4 == 0) else 1.0
					fx = side * rng.randf_range(4.4, 9.5)
					fz = rng.randf_range(-10.0, 47.0)
				else:
					fx = rng.randf_range(-46.0, -8.0)
					fz = rng.randf_range(16.0, 47.0)
			elif fkind == 1:
				# Nanohana: sunny village flanks, lakeside meadows & riverbank wildflower beds
				if fatt % 2 == 0:
					fx = rng.randf_range(22.0, 48.0)
					fz = rng.randf_range(22.0, 46.0)
				else:
					fx = rng.randf_range(-46.0, 14.0)
					fz = rng.randf_range(16.5, 36.0)
			else:
				# Higanbana: dramatic crimson lilies lining bamboo forest & Senbon Torii hillside
				if fatt % 2 == 0:
					var side: float = -1.0 if (fatt % 4 == 0) else 1.0
					fx = side * rng.randf_range(4.3, 12.5)
					fz = rng.randf_range(-44.0, -20.0)
				else:
					fx = rng.randf_range(-42.0, 42.0)
					fz = rng.randf_range(-26.0, 4.0)

			if _is_blocked_for_meadow(fx, fz):
				continue
			var fy: float = get_base_terrain_height(fx, fz)
			if fy < 0.04:
				continue
			var fw: Color = get_terrain_material_weights(fx, fz, fy)
			if fw.r > 0.36 or fw.b > 0.34 or fw.a > 0.25:
				continue

			var fnrm: Vector3 = get_terrain_normal(fx, fz)
			var fyaw: float = rng.randf_range(0.0, TAU)
			var fsc: float = rng.randf_range(0.88, 1.32)
			var fb: Basis = _basis_align_normal(fnrm, fyaw).scaled(Vector3(fsc, fsc * rng.randf_range(0.92, 1.15), fsc))
			fxforms.append(Transform3D(fb, Vector3(fx, fy - 0.03, fz)))

		_add_batched_multimesh(content_root, fmesh, fxforms, fname)

	# 3. Lakeside & Riverbank Reeds (65 mobile / 120 desktop) hugging the water's edge
	var reed_mesh := ArpgNatureProps.make_reed_cluster_mesh(is_mob)
	reed_mesh.surface_set_material(0, reed_mat)
	rng.seed = 40401
	var reed_target: int = 65 if is_mob else 120
	var reed_xforms: Array[Transform3D] = []
	var ratt: int = 0
	var rmax: int = reed_target * 14

	while reed_xforms.size() < reed_target and ratt < rmax:
		ratt += 1
		var rx: float
		var rz: float
		if ratt % 2 == 0:
			# Moonlit Lake shoreline rim (leaving the south sandy beach & pier entrance wide open!)
			var ang: float = rng.randf_range(0.0, TAU)
			var rad_n: float = rng.randf_range(0.71, 0.90)
			rx = LAKE_CENTER.x + cos(ang) * LAKE_RX * rad_n
			rz = LAKE_CENTER.y + sin(ang) * LAKE_RZ * rad_n
			# Keep south swimming beach & pier corridor clear of tall reeds
			if rx > 26.5 and rx < 41.5 and rz > 17.0:
				continue
		else:
			# Koi River north & south banks
			rx = rng.randf_range(-49.0, 15.5)
			var bank_side: float = -1.0 if (ratt % 4 == 1) else 1.0
			var river_z: float = 12.0 + sin(rx * 0.08) * 2.2
			rz = river_z + bank_side * rng.randf_range(2.3, 4.1)

		# Keep bridges clear
		if absf(rx) < 4.2 or absf(rx - 17.5) < 3.4:
			continue
		if rx < MIN_X + 2.0 or rx > MAX_X - 2.0:
			continue

		var ry: float = get_base_terrain_height(rx, rz)
		if ry < -0.50 or ry > 0.16:
			continue

		var ryaw: float = rng.randf_range(0.0, TAU)
		var rsc: float = rng.randf_range(0.84, 1.24)
		var rbasis: Basis = Basis(Vector3.UP, ryaw).scaled(Vector3(rsc, rsc * rng.randf_range(0.90, 1.18), rsc))
		reed_xforms.append(Transform3D(rbasis, Vector3(rx, ry - 0.05, rz)))

	_add_batched_multimesh(content_root, reed_mesh, reed_xforms, "LakesideReedsMM")

	# 4. Floating Lotus Pads & Pink-White Blossoms (16 mobile / 28 desktop) on Moonlit Lake
	var lotus_mesh := ArpgNatureProps.make_lotus_pad_mesh()
	var lotus_mat := WafuuModels3D.make_wafuu_mat(1, is_mob, 0.44, 0.02, 0.0)
	lotus_mat.set_shader_parameter("wind_strength", 0.0)
	lotus_mesh.surface_set_material(0, lotus_mat)

	rng.seed = 50501
	var lotus_target: int = 16 if is_mob else 28
	var lotus_xforms: Array[Transform3D] = []
	var latt: int = 0
	while lotus_xforms.size() < lotus_target and latt < lotus_target * 14:
		latt += 1
		var ang: float = rng.randf_range(0.0, TAU)
		var rr: float = sqrt(rng.randf_range(0.04, 0.46))
		var lx: float = LAKE_CENTER.x + cos(ang) * LAKE_RX * rr
		var lz: float = LAKE_CENTER.y + sin(ang) * LAKE_RZ * rr
		# Keep pier corridor & moored rowboat zone clear
		if lx > 28.0 and lx < 37.5 and lz > 12.8 and lz < 22.5:
			continue
		if get_base_terrain_height(lx, lz) > WATER_LEVEL - 0.32:
			continue
		var lyaw: float = rng.randf_range(0.0, TAU)
		var lsc: float = rng.randf_range(0.78, 1.26)
		var lbasis: Basis = Basis(Vector3.UP, lyaw).scaled(Vector3(lsc, lsc, lsc))
		lotus_xforms.append(Transform3D(lbasis, Vector3(lx, WATER_LEVEL + 0.02, lz)))

	_add_batched_multimesh(content_root, lotus_mesh, lotus_xforms, "FloatingLotusMM")

	# 5. Five Sculpted Japanese Coastal Red Pines (赤松) framing the Sandy Beach Cove & Lake!
	var pine_specs: Array = [
		[Vector2(47.0, 23.5), 1.18, -2.35],
		[Vector2(49.0, 8.0),  1.12, -1.65],
		[Vector2(43.5, 0.2),  1.22, -0.85],
		[Vector2(24.5, 22.8), 1.08,  0.95],
		[Vector2(23.5, 1.5),  1.15,  0.55],
	]
	for ps in pine_specs:
		var pp2: Vector2 = ps[0]
		var py: float = get_base_terrain_height(pp2.x, pp2.y)
		ArpgNatureProps.add_japanese_pine_tree(
			content_root, Vector3(pp2.x, py, pp2.y), float(ps[1]), float(ps[2]), is_mob
		)

	# 6. Walkable Wooden Lakeside Boat Pier jutting from the South Sandy Beach over Moonlit Lake
	var pier_start := Vector3(30.0, get_base_terrain_height(30.0, 21.8) + 0.04, 21.8)
	var pier_end := Vector3(32.5, WATER_LEVEL + 0.55, 14.5)
	ArpgNatureProps.add_lakeside_pier(arena, content_root, prop_shader, pier_start, pier_end, 3.2)

	# 7. Moored Traditional Japanese Wasen Rowboat gently bobbing beside the pier tip
	var boat_pos := Vector3(35.4, WATER_LEVEL + 0.04, 15.2)
	ArpgNatureProps.add_moored_rowboat(content_root, boat_pos, -0.45, sky_anim_nodes)

	# 8. Swimming School of Colorful Japanese Koi gliding beneath Moonlit Lake
	ArpgNatureProps.add_swimming_koi_school(
		content_root, Vector3(LAKE_CENTER.x, WATER_LEVEL, LAKE_CENTER.y),
		WATER_LEVEL, sky_anim_nodes, is_mob
	)

	# 9. Sandy Beach Driftwood, Tide-Pool Stones, Pebbles & Cozy Lakeside Resting Bench
	ArpgNatureProps.add_beach_props(
		arena, content_root, Callable(ArpgCh1Map, "get_base_terrain_height"), is_mob
	)


# ==============================================================================
#  SKY LANDMARKS & AMBIENT PARTICLES
# ==============================================================================
static func _build_sky_landmarks(content_root: Node3D, sky_anim_nodes: Array[Dictionary]) -> void:
	# 16 Drifting Wafuu Sky Lanterns (天燈) softly bobbing outside the map perimeter
	var lantern_mesh := CylinderMesh.new()
	lantern_mesh.top_radius = 0.72; lantern_mesh.bottom_radius = 0.44; lantern_mesh.height = 1.65
	lantern_mesh.radial_segments = 6; lantern_mesh.rings = 1

	var warm_mat := StandardMaterial3D.new()
	warm_mat.albedo_color = Color.html("#fde68a")
	warm_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var pink_mat := StandardMaterial3D.new()
	pink_mat.albedo_color = Color.html("#f9a8d4")
	pink_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	for i: int in range(16):
		var ang: float = (float(i) / 16.0) * TAU + 0.18
		var rx: float = 64.0 + float(i % 3) * 8.0
		var rz: float = 76.0 + float(i % 3) * 8.0
		var y_base: float = 13.0 + float(i % 4) * 4.5
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
			"speed": 0.62 + float(i % 3) * 0.20,
			"phase": float(i) * 1.15,
			"amp": 1.55,
		})

	# Moonlit Cloud Ring outside the map perimeter (merged into 1 single MeshInstance3D = 1 draw call!)
	var cloud_mat := StandardMaterial3D.new()
	cloud_mat.albedo_color = Color(0.95, 0.74, 0.88, 0.32)
	cloud_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cloud_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var puff_a := SphereMesh.new(); puff_a.radius = 7.8; puff_a.height = 3.6; puff_a.radial_segments = 10; puff_a.rings = 5
	var puff_b := SphereMesh.new(); puff_b.radius = 5.4; puff_b.height = 2.8; puff_b.radial_segments = 8; puff_b.rings = 4

	var st_clouds := SurfaceTool.new()
	st_clouds.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cloud_count: int = 8
	var cloud_rad: float = 88.0
	for ci: int in range(cloud_count):
		var ang: float = (float(ci) / float(cloud_count)) * TAU
		var grp_xform := Transform3D(
			Basis.from_euler(Vector3(0.0, -ang, 0.0)),
			Vector3(cos(ang) * cloud_rad, 25.0 + sin(float(ci) * 2.1) * 3.5, sin(ang) * cloud_rad)
		)
		st_clouds.append_from(puff_a, 0, grp_xform)
		st_clouds.append_from(puff_b, 0, grp_xform * Transform3D(Basis.IDENTITY, Vector3(0.0, -0.5, 5.5)))
		st_clouds.append_from(puff_b, 0, grp_xform * Transform3D(Basis.IDENTITY, Vector3(0.0, -0.4, -5.2)))

	var cloud_ring := MeshInstance3D.new()
	cloud_ring.name = "MoonlitCloudRing"
	cloud_ring.mesh = st_clouds.commit()
	cloud_ring.material_override = cloud_mat
	cloud_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cloud_ring.position = Vector3(0.0, 0.0, MAP_CENTER_Z)
	content_root.add_child(cloud_ring)
	sky_anim_nodes.append({"node": cloud_ring, "kind": "spin", "speed": 0.025})

	# Giant Luminous Full Moon perched beyond the North Grand Altar
	var moon := MeshInstance3D.new()
	var ms := SphereMesh.new()
	ms.radius = 10.5; ms.height = 21.0; ms.radial_segments = 16; ms.rings = 10
	var mm := StandardMaterial3D.new()
	mm.albedo_color = Color.html("#fef3c7")
	mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	moon.mesh = ms
	moon.material_override = mm
	moon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	moon.position = Vector3(0.0, 34.0, -114.0)
	content_root.add_child(moon)


static func _build_ambient_particles(content_root: Node3D, particle_col: Color, is_mob: bool) -> void:
	var particles := CPUParticles3D.new()
	particles.name = "SakuraPetals"
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	particles.amount = 45 if is_mob else 110
	particles.lifetime = 9.0
	particles.preprocess = 4.5
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	particles.emission_box_extents = Vector3(54.0, 1.5, 68.0)
	particles.position = Vector3(0.0, 19.0, MAP_CENTER_Z)
	particles.direction = Vector3(0.16, -1.0, 0.12)
	particles.spread = 22.0
	particles.gravity = Vector3(0.0, -0.14, 0.0)
	particles.initial_velocity_min = 1.2
	particles.initial_velocity_max = 2.1

	var p_mesh := QuadMesh.new()
	p_mesh.size = Vector2(0.30, 0.30)
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
	node_name: String = "BatchedMultiMesh"
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
