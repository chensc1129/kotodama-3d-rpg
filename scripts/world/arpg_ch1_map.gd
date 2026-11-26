class_name ArpgCh1Map
extends RefCounted
## Procedurally builds the sprawling Japanese-themed 3D ARPG Adventure Map for Chapter 1:
## 「第一章：櫻花之里・失落的言靈碑」 (104m × 132m pilgrimage map, X: [-52, 52], Z: [-76, 56]).

const MIN_X: float = -52.0
const MAX_X: float = 52.0
const MIN_Z: float = -76.0
const MAX_Z: float = 56.0
const MAP_CENTER_Z: float = -10.0

const SPRING_POS_2D: Vector2 = Vector2(-14.0, -34.0)
const SPRING_RADIUS: float = 5.2


static func _smooth01(t: float) -> float:
	var c: float = clampf(t, 0.0, 1.0)
	return c * c * (3.0 - 2.0 * c)


# ==============================================================================
#  1. EXACT ANALYTICAL TERRAIN HEIGHT (Smooth walkable slopes everywhere)
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

		# Eastern lookout terrace at (26, -12) -> y ≈ 1.40m
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

	# Zone 2 (z: +4 .. +20): Sunken Koi River Valley cutting East-West along z = 12.0 + sin(x * 0.08) * 2.2
	# Dips smoothly down to y = -1.20m (width ~7m; bridge ends at z=18.5 & z=5.5 sit on dry banks)
	var river_z: float = 12.0 + sin(x * 0.08) * 2.2
	var river_d: float = absf(z - river_z)
	if river_d < 4.4:
		var river_t: float = 1.0 - _smooth01((river_d - 1.4) / 3.0)
		h -= 1.20 * river_t

	return h


# ==============================================================================
#  2. MULTI-MATERIAL FLOOR WEIGHTS (arena_floor.gdshader stage_id = 0)
# ==============================================================================
static func get_terrain_material_weights(x: float, z: float, h: float) -> Color:
	# A (r): Carved Granite Flagstones — central pilgrimage road & village plaza center
	# B (g): Zen Gravel / Soil — bamboo woodland & outer hills
	# C (b): Polished Dark Slate — Grand Shrine Altar plateau & pavilion pads
	# D (a): Wet River Cobblestones — sunken Koi riverbed (h < -0.15)
	var w_d: float = _smooth01((-0.05 - h) / 0.30)

	# Dark slate zones: Grand Altar plateau (z < -46) + Teahouse/Forge/Alcove pads
	var altar_slate: float = _smooth01((-z - 45.5) / 3.0)
	var tea_d: float = Vector2(x + 18.5, z - 29.0).length()
	var tea_pad: float = 1.0 - _smooth01((tea_d - 3.8) / 1.8)
	var forge_d: float = Vector2(x - 19.5, z - 28.0).length()
	var forge_pad: float = 1.0 - _smooth01((forge_d - 3.8) / 1.8)
	var byakko_d: float = Vector2(x - 16.5, z + 34.0).length()
	var byakko_pad: float = 1.0 - _smooth01((byakko_d - 2.6) / 1.6)
	var w_c: float = maxf(altar_slate, maxf(tea_pad, maxf(forge_pad, byakko_pad))) * (1.0 - w_d)

	# Granite flagstones: central pilgrimage road (|x| < 4.5, z: -50..+48) & village plaza center
	var road_x: float = 1.0 - _smooth01((absf(x) - 3.8) / 1.5)
	var road_z: float = (1.0 - _smooth01((z - 48.0) / 3.0)) * (1.0 - _smooth01((-z - 50.0) / 3.0))
	var road_w: float = road_x * road_z

	var plaza_x: float = 1.0 - _smooth01((absf(x) - 11.5) / 4.5)
	var plaza_z: float = _smooth01((z - 20.0) / 3.5) * (1.0 - _smooth01((z - 46.0) / 4.0))
	var plaza_w: float = plaza_x * plaza_z * 0.92

	# Subtle stone path leading toward the East Cedar Footbridge at x = 24
	var east_x: float = 1.0 - _smooth01((absf(x - 24.0) - 2.0) / 1.4)
	var east_z: float = _smooth01((z - 2.0) / 3.0) * (1.0 - _smooth01((z - 24.0) / 3.0))
	var east_w: float = east_x * east_z * 0.78

	var w_a: float = clampf(maxf(road_w, maxf(plaza_w, east_w)), 0.0, 1.0) * (1.0 - w_d) * (1.0 - w_c * 0.78)
	var w_b: float = maxf(0.0, 1.0 - (w_a + w_c + w_d))

	var s: float = maxf(w_a + w_b + w_c + w_d, 0.0001)
	return Color(w_a / s, w_b / s, w_c / s, w_d / s)


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

	# 2. Rectangular Heightfield TerrainMesh + 4-Edge Cliff Skirts
	_build_heightfield_terrain(content_root, floor_shader, is_mob)

	# 3. Glowing Perimeter Shrine Boundary Border
	_build_perimeter_border(content_root, Color.html("#e11d48"), is_mob)

	# 4. Shimmering Koi River Water Plane (Zone 2)
	_build_koi_river(content_root, water_shader)

	# 5. Two Flush-Anchored Ornate Walkable Bridges over Koi River (Zone 2)
	# Main Grand Vermilion Taiko Bridge (x = 0.0, z: 18.5 -> 5.5)
	WafuuModels3D.add_ornate_bridge(
		arena, content_root, prop_shader,
		_bridge_pt(0.0, 18.5), _bridge_pt(0.0, 5.5),
		5.2, 0.95, "#991b1b", "#450a0a", "#ef4444", 0
	)
	# East Rustic Cedar Footbridge (x = 24.0, z: 18.5 -> 5.5)
	WafuuModels3D.add_ornate_bridge(
		arena, content_root, prop_shader,
		_bridge_pt(24.0, 18.5), _bridge_pt(24.0, 5.5),
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

	# 10. Sky Landmarks (16 Drifting Sky Lanterns + Moonlit Cloud Ring + Full Moon)
	_build_sky_landmarks(content_root, sky_anim_nodes)

	# 11. Ambient Falling Sakura Petals across the entire 104m x 132m map
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

	# Cliff skirts along all 4 outer rectangular edges (dark slate stone channel C)
	var skirt_w := Color(0.0, 0.0, 1.0, 0.0)
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
	mat.set_shader_parameter("stage_id", 0)
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


static func _build_koi_river(content_root: Node3D, water_shader: Shader) -> void:
	var pm := PlaneMesh.new()
	pm.size = Vector2(MAX_X - MIN_X, 14.0) # X: -52..52, Z: 5..19
	pm.subdivide_width = 1
	pm.subdivide_depth = 1

	var wmat := ShaderMaterial.new()
	wmat.shader = water_shader
	var dc := Color.html("#1d4ed8")
	var sc := Color.html("#38bdf8")
	wmat.set_shader_parameter("deep_color", Color(dc.r, dc.g, dc.b, 0.76))
	wmat.set_shader_parameter("shallow_color", Color(sc.r, sc.g, sc.b, 0.62))
	wmat.set_shader_parameter("glint_color", Color.html("#e0f2fe"))
	wmat.set_shader_parameter("wave_speed", 1.15)

	var wi := MeshInstance3D.new()
	wi.name = "KoiRiverWater"
	wi.mesh = pm
	wi.material_override = wmat
	wi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	wi.position = Vector3(0.0, -0.52, 12.0)
	content_root.add_child(wi)


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

	# Batched Carved Granite Kasuga-doro Stone Lanterns lining plaza & road approaches (2 draw calls total!)
	var village_lanterns_2d: Array[Vector2] = [
		Vector2(-6.2, 46.5), Vector2(6.2, 46.5),
		Vector2(-7.0, 36.0), Vector2(7.0, 36.0),
		Vector2(-5.8, 21.5), Vector2(5.8, 21.5),
		Vector2(20.5, 21.0), Vector2(27.5, 21.0),
		Vector2(-15.5, 23.0), Vector2(16.5, 22.8),
	]
	var village_lantern_pts: Array[Vector3] = []
	for lp: Vector2 in village_lanterns_2d:
		village_lantern_pts.append(Vector3(lp.x, get_base_terrain_height(lp.x, lp.y), lp.y))
	WafuuModels3D.add_batched_stone_lanterns(content_root, village_lantern_pts, "#fde047", is_mob)

	# Lush Multi-Branching Sakura Trees framing Sakura Village (clear of houses, spawn & NPC spots)
	var village_trees: Array[Vector2] = [
		Vector2(-19.5, 46.5), Vector2(19.5, 46.5),
		Vector2(-37.5, 31.0), Vector2(37.5, 31.0),
		Vector2(-29.5, 21.5), Vector2(35.0, 21.5),
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
	var max_attempts: int = target_count * 6

	while bamboo_xforms.size() < target_count and attempts < max_attempts:
		attempts += 1
		var side: float = -1.0 if (attempts % 2 == 0) else 1.0
		var bx: float = side * rng.randf_range(7.2, 46.0)
		var bz: float = rng.randf_range(-24.0, 2.5)

		# Keep clearings open:
		if Vector2(bx + 24.0, bz + 10.0).length() < 7.2:
			continue
		if Vector2(bx - 2.0, bz + 16.0).length() < 8.0:
			continue
		if Vector2(bx - 26.0, bz + 12.0).length() < 8.4:
			continue
		if bx > 13.0 and bx < 24.0 and absf(bz + 12.0) < 3.5:
			continue
		if absf(bx - 24.0) < 4.0 and bz > -3.5:
			continue
		if (
			Vector2(bx + 9.2, bz + 7.5).length() < 3.0
			or Vector2(bx - 9.5, bz + 6.0).length() < 3.0
			or Vector2(bx + 8.8, bz + 18.5).length() < 3.0
			or Vector2(bx - 10.2, bz + 19.0).length() < 3.0
		):
			continue

		var by: float = get_base_terrain_height(bx, bz)
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
