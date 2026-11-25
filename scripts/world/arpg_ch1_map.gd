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

	# 5. Two Flush-Anchored Walkable Bridges over Koi River (Zone 2)
	# Main Grand Vermilion Taiko Bridge (x = 0.0, z: 18.5 -> 5.5)
	_add_walkable_bridge(
		arena, content_root, prop_shader,
		_bridge_pt(0.0, 18.5), _bridge_pt(0.0, 5.5),
		5.2, 0.95, "#991b1b", "#450a0a", "#ef4444", 0
	)
	# East Rustic Cedar Footbridge (x = 24.0, z: 18.5 -> 5.5)
	_add_walkable_bridge(
		arena, content_root, prop_shader,
		_bridge_pt(24.0, 18.5), _bridge_pt(24.0, 5.5),
		3.8, 0.72, "#7c4722", "#43220d", "#d97706", 0
	)

	# 6. Zone 1: Sakura Village Plaza Architecture
	_build_zone1_village(arena, content_root)

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
#  ZONE 1: SAKURA VILLAGE PLAZA
# ==============================================================================
static func _build_zone1_village(arena: Arena3D, content_root: Node3D) -> void:
	# Welcoming South Village Torii Gate at (0, y, 48.0)
	_add_torii_gate(content_root, Vector3(0.0, get_base_terrain_height(0.0, 48.0), 48.0), "#dc2626", 1.15)

	# Cozy Teahouse Pavilion (茶屋) at (-18.5, y, 29.0) + red wagasa umbrella prop
	var tea_pos := Vector3(-18.5, get_base_terrain_height(-18.5, 29.0), 29.0)
	_add_shrine_pavilion(arena, content_root, tea_pos, "#991b1b", "#2a1b2e", 1.05)
	_add_wagasa_umbrella(content_root, Vector3(-12.5, get_base_terrain_height(-12.5, 32.5), 32.5))

	# Blacksmith Forge Pavilion (鍛冶屋) at (19.5, y, 28.0) + glowing ember forge hearth
	var forge_pos := Vector3(19.5, get_base_terrain_height(19.5, 28.0), 28.0)
	_add_shrine_pavilion(arena, content_root, forge_pos, "#7c2d12", "#1e293b", 1.05)
	_add_forge_hearth(arena, content_root, Vector3(20.5, get_base_terrain_height(20.5, 28.2), 28.2))

	# Village Stone Lanterns lining plaza and road approaches
	var village_lanterns: Array[Vector2] = [
		Vector2(-6.2, 46.5), Vector2(6.2, 46.5),
		Vector2(-7.0, 36.0), Vector2(7.0, 36.0),
		Vector2(-5.8, 21.5), Vector2(5.8, 21.5),
		Vector2(20.5, 21.0), Vector2(27.5, 21.0),
		Vector2(-15.5, 23.5), Vector2(16.5, 23.0),
	]
	for lp: Vector2 in village_lanterns:
		_add_stone_lantern(content_root, Vector3(lp.x, get_base_terrain_height(lp.x, lp.y), lp.y), "#fde047")

	# Village Sakura Trees (merged foliage per tree, clear of spawn & NPC spots)
	var village_trees: Array[Vector2] = [
		Vector2(-29.0, 44.0), Vector2(29.0, 44.0),
		Vector2(-35.0, 30.0), Vector2(35.0, 30.0),
		Vector2(-26.0, 21.5), Vector2(34.0, 21.5),
		Vector2(-11.5, 49.0), Vector2(11.5, 49.0),
		Vector2(-42.0, 42.0), Vector2(42.0, 42.0),
	]
	for idx: int in range(village_trees.size()):
		var tp: Vector2 = village_trees[idx]
		var sc: float = 1.25 + float(idx % 3) * 0.16
		var leaf_hex: String = "#f472b6" if idx % 2 == 0 else "#fbcfe8"
		_add_stylized_tree(content_root, Vector3(tp.x, get_base_terrain_height(tp.x, tp.y), tp.y), "#3b231e", leaf_hex, sc)


# ==============================================================================
#  ZONE 3: MISTY BAMBOO FOREST
# ==============================================================================
static func _build_zone3_bamboo_forest(
	arena: Arena3D,
	content_root: Node3D,
	prop_shader: Shader,
	is_mob: bool
) -> void:
	# 1. Dense emerald bamboo groves batched into ONE single MultiMeshInstance3D!
	var bamboo_mesh := _make_bamboo_stalk_mesh()
	var bamboo_mat := StandardMaterial3D.new()
	bamboo_mat.albedo_color = Color.html("#15803d")
	bamboo_mat.roughness = 0.60
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
		# - NPC Kenta & Mossy Jizo Shrine clearing at (-24, -10)
		if Vector2(bx + 24.0, bz + 10.0).length() < 7.2:
			continue
		# - Ambush #2 clearing around (2, -16)
		if Vector2(bx - 2.0, bz + 16.0).length() < 8.0:
			continue
		# - Eastern Wooden Lookout Deck & its flush west approach ramp at (14..32, -18..-6)
		if Vector2(bx - 26.0, bz + 12.0).length() < 8.4:
			continue
		if bx > 13.0 and bx < 24.0 and absf(bz + 12.0) < 3.5:
			continue
		# - East Rustic Cedar Footbridge landing corridor (x ~ 24, z ~ 0..4)
		if absf(bx - 24.0) < 4.0 and bz > -3.5:
			continue
		# - Keep clear around the 4 tactical mossy boulders
		if (
			Vector2(bx + 9.2, bz + 7.5).length() < 3.0
			or Vector2(bx - 9.5, bz + 6.0).length() < 3.0
			or Vector2(bx + 8.8, bz + 18.5).length() < 3.0
			or Vector2(bx - 10.2, bz + 19.0).length() < 3.0
		):
			continue

		var by: float = get_base_terrain_height(bx, bz)
		var h_scale: float = rng.randf_range(0.85, 1.42)
		var r_scale: float = rng.randf_range(0.85, 1.18)
		var yaw: float = rng.randf_range(0.0, TAU)
		var tilt_x: float = rng.randf_range(-0.06, 0.06)
		var tilt_z: float = rng.randf_range(-0.06, 0.06)
		var basis: Basis = Basis.from_euler(Vector3(tilt_x, yaw, tilt_z)).scaled(Vector3(r_scale, h_scale, r_scale))
		bamboo_xforms.append(Transform3D(basis, Vector3(bx, by - 0.15, bz)))

	_add_batched_multimesh(content_root, bamboo_mesh, bamboo_xforms, "BambooGroveMultiMesh")

	# 2. Mossy Jizo Shrine Stone + Stone Lantern at (-26, y, -12)
	var jizo_pos := Vector3(-26.0, get_base_terrain_height(-26.0, -12.0), -12.0)
	_add_jizo_shrine(arena, content_root, jizo_pos)
	_add_stone_lantern(content_root, Vector3(-22.5, get_base_terrain_height(-22.5, -13.5), -13.5), "#fef08a")

	# 3. Elevated Wooden Lookout Deck at (26.0, y + 1.2, -12.0) + Flush Wooden Ramp!
	var terrace_y: float = get_base_terrain_height(26.0, -12.0)
	var deck_top_y: float = terrace_y + 1.2
	_add_walkable_deck(
		arena, content_root, prop_shader,
		Vector3(26.0, deck_top_y, -12.0), 4.8,
		"#713819", "#421d0b", "#f59e0b", 1, true
	)
	# Flush wooden ramp climbing from hillside (15.2, h, -12.0) onto west rim (21.35, deck_top_y, -12.0)
	_add_walkable_bridge(
		arena, content_root, prop_shader,
		_bridge_pt(15.2, -12.0), Vector3(21.35, deck_top_y, -12.0),
		3.2, 0.06, "#7c4722", "#43220d", "#f59e0b", 0
	)
	_add_stone_lantern(content_root, Vector3(28.5, deck_top_y, -14.2), "#fde047")

	# 4. Four Tactical Mossy Boulders (arena.obstacles) in the bamboo clearing
	var boulders: Array[Vector2] = [
		Vector2(-9.2, -7.5),
		Vector2(9.5, -6.0),
		Vector2(-8.8, -18.5),
		Vector2(10.2, -19.0),
	]
	for bp: Vector2 in boulders:
		_add_mossy_boulder(arena, content_root, Vector3(bp.x, get_base_terrain_height(bp.x, bp.y), bp.y), 1.55)

	# Road-side stone lanterns guiding the pilgrimage north through the misty bamboo
	for lp: Vector2 in [Vector2(-5.5, 1.5), Vector2(5.5, 1.5), Vector2(-5.5, -12.0), Vector2(5.5, -12.0)]:
		_add_stone_lantern(content_root, Vector3(lp.x, get_base_terrain_height(lp.x, lp.y), lp.y), "#fde68a")


# ==============================================================================
#  ZONE 4: SENBON TORII HILLSIDE (千本鳥居)
# ==============================================================================
static func _build_zone4_senbon_torii(
	arena: Arena3D,
	content_root: Node3D,
	sky_anim_nodes: Array[Dictionary],
	is_mob: bool
) -> void:
	# 1. Eight sequential Vermilion Torii Gates climbing from z = -24 to z = -45 (step = 3.0m)
	# Batched into 2 draw calls total (vermilion structure + dark slate kasagi caps)!
	var st_red := SurfaceTool.new()
	st_red.begin(Mesh.PRIMITIVE_TRIANGLES)
	var st_cap := SurfaceTool.new()
	st_cap.begin(Mesh.PRIMITIVE_TRIANGLES)

	var pillar_mesh := CylinderMesh.new()
	pillar_mesh.top_radius = 0.28; pillar_mesh.bottom_radius = 0.34; pillar_mesh.height = 6.2
	pillar_mesh.radial_segments = 8; pillar_mesh.rings = 1
	var nuki_mesh := BoxMesh.new()
	nuki_mesh.size = Vector3(7.4, 0.36, 0.44)
	var kasagi_mesh := BoxMesh.new()
	kasagi_mesh.size = Vector3(8.5, 0.48, 0.74)

	for i: int in range(8):
		var tz: float = -24.0 - float(i) * 3.0
		var ty: float = get_base_terrain_height(0.0, tz)
		for side: float in [-3.1, 3.1]:
			st_red.append_from(pillar_mesh, 0, Transform3D(Basis.IDENTITY, Vector3(side, ty + 3.05, tz)))
		st_red.append_from(nuki_mesh, 0, Transform3D(Basis.IDENTITY, Vector3(0.0, ty + 4.95, tz)))
		st_cap.append_from(kasagi_mesh, 0, Transform3D(Basis.IDENTITY, Vector3(0.0, ty + 6.25, tz)))

	var red_mat := StandardMaterial3D.new()
	red_mat.albedo_color = Color.html("#dc2626")
	red_mat.roughness = 0.40
	var cap_mat := StandardMaterial3D.new()
	cap_mat.albedo_color = Color.html("#0f172a")
	cap_mat.roughness = 0.50

	var red_inst := MeshInstance3D.new()
	red_inst.name = "SenbonToriiRed"
	red_inst.mesh = st_red.commit()
	red_inst.material_override = red_mat
	red_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	content_root.add_child(red_inst)

	var cap_inst := MeshInstance3D.new()
	cap_inst.name = "SenbonToriiCaps"
	cap_inst.mesh = st_cap.commit()
	cap_inst.material_override = cap_mat
	cap_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	content_root.add_child(cap_inst)

	# 2. Glowing Sakura Healing Spring circle at (-14.0, y, -34.0)
	var spring_y: float = get_base_terrain_height(SPRING_POS_2D.x, SPRING_POS_2D.y)
	var spring_world := Vector3(SPRING_POS_2D.x, spring_y, SPRING_POS_2D.y)
	arena.sakura_zone_pos = spring_world
	arena.sakura_zone_radius = SPRING_RADIUS

	# Shimmering healing spring water basin disc
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

	# Double rotating pink-cyan spirit ring added to sky_anim_nodes with kind = "spin"
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

	_add_stone_lantern(content_root, Vector3(-19.5, get_base_terrain_height(-19.5, -34.0), -34.0), "#f472b6")
	_add_stylized_tree(content_root, Vector3(-20.0, get_base_terrain_height(-20.0, -39.0), -39.0), "#3b231e", "#fbcfe8", 1.45)

	# 3. Stone Shrine Alcove for Elder Byakko at (16.5, y, -34.0)
	var byakko_y: float = get_base_terrain_height(16.5, -34.0)
	_add_byakko_alcove(arena, content_root, Vector3(16.5, byakko_y, -34.0))

	# Hillside sakura trees framing the Senbon Torii ascent
	for tp: Vector2 in [
		Vector2(-11.5, -26.5), Vector2(11.5, -26.5),
		Vector2(-26.0, -32.0), Vector2(28.0, -32.0),
		Vector2(-13.5, -42.5), Vector2(13.5, -42.5),
	]:
		_add_stylized_tree(content_root, Vector3(tp.x, get_base_terrain_height(tp.x, tp.y), tp.y), "#3b231e", "#f472b6", 1.32)


# ==============================================================================
#  ZONE 5: NIGHT-SAKURA GRAND ALTAR
# ==============================================================================
static func _build_zone5_grand_altar(
	arena: Arena3D,
	content_root: Node3D,
	sky_anim_nodes: Array[Dictionary],
	is_mob: bool
) -> void:
	# 1. Grand North Torii Gate at (0.0, 2.8, -47.0), scale 1.45
	_add_torii_gate(content_root, Vector3(0.0, 2.8, -47.0), "#dc2626", 1.45)

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
	_add_kotodama_monolith(arena, content_root, Vector3(0.0, 2.8, -69.0), sky_anim_nodes, is_mob)

	# 4. Giant Weeping Sakura Tree behind the Monolith at (0.0, 2.8, -73.0)
	_add_giant_weeping_sakura(content_root, Vector3(0.0, 2.8, -73.0))

	# 5. Perimeter Night-Sakura Trees & Stone Lanterns framing the Grand Altar
	var altar_trees: Array[Vector2] = [
		Vector2(-26.0, -52.0), Vector2(26.0, -52.0),
		Vector2(-29.0, -64.0), Vector2(29.0, -64.0),
		Vector2(-18.0, -71.5), Vector2(18.0, -71.5),
		Vector2(-38.0, -58.0), Vector2(38.0, -58.0),
	]
	for idx: int in range(altar_trees.size()):
		var tp: Vector2 = altar_trees[idx]
		var leaf_hex: String = "#f472b6" if idx % 2 == 0 else "#f9a8d4"
		_add_stylized_tree(content_root, Vector3(tp.x, get_base_terrain_height(tp.x, tp.y), tp.y), "#3b231e", leaf_hex, 1.55)

	var altar_lanterns: Array[Vector2] = [
		Vector2(-7.5, -48.0), Vector2(7.5, -48.0),
		Vector2(-20.0, -58.0), Vector2(20.0, -58.0),
		Vector2(-7.0, -68.5), Vector2(7.0, -68.5),
	]
	for lp: Vector2 in altar_lanterns:
		_add_stone_lantern(content_root, Vector3(lp.x, get_base_terrain_height(lp.x, lp.y), lp.y), "#f472b6")


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
#  SHARED ARCHITECTURAL PROP, BRIDGE, DECK & OBSTACLE HELPERS
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


static func _make_bamboo_stalk_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Tall tapered emerald bamboo culm (5-sided for ultra-low poly count across 190 instances)
	var culm := CylinderMesh.new()
	culm.top_radius = 0.11; culm.bottom_radius = 0.18; culm.height = 9.2
	culm.radial_segments = 5; culm.rings = 1
	st.append_from(culm, 0, Transform3D(Basis.IDENTITY, Vector3(0.0, 4.6, 0.0)))

	# 3 Stylized angled bamboo foliage fronds near upper canopy
	var leaf := BoxMesh.new()
	leaf.size = Vector3(1.55, 0.08, 0.55)
	for fi: int in range(3):
		var a: float = float(fi) * (TAU / 3.0) + 0.3
		var y_h: float = 6.2 + float(fi) * 1.05
		var xf := Transform3D(
			Basis.from_euler(Vector3(0.28, a, -0.22)),
			Vector3(cos(a) * 0.62, y_h, sin(a) * 0.62)
		)
		st.append_from(leaf, 0, xf)

	return st.commit()


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


static func _add_walkable_bridge(
	arena: Arena3D,
	content_root: Node3D,
	prop_shader: Shader,
	start_p: Vector3,
	end_p: Vector3,
	width: float,
	arch: float,
	deck_hex: String,
	deck_dark_hex: String,
	rail_hex: String,
	surface_type: int = 0
) -> void:
	arena.bridges.append({"start": start_p, "end": end_p, "width": width, "arch": arch})

	var deck_mat := ShaderMaterial.new()
	deck_mat.shader = prop_shader
	deck_mat.set_shader_parameter("surface_type", surface_type)
	deck_mat.set_shader_parameter("albedo_a", Color.html(deck_hex))
	deck_mat.set_shader_parameter("albedo_b", Color.html(deck_dark_hex))
	deck_mat.set_shader_parameter("accent_color", Color.html(rail_hex))
	deck_mat.set_shader_parameter("roughness_val", 0.62 if surface_type == 0 else 0.34)
	deck_mat.set_shader_parameter("metallic_val", 0.08 if surface_type == 0 else 0.38)
	deck_mat.set_shader_parameter("emission_strength", 0.25 if surface_type == 2 else 0.0)
	deck_mat.set_shader_parameter("tile_scale", width * 0.55)

	var rail_mat := StandardMaterial3D.new()
	rail_mat.albedo_color = Color.html(rail_hex)
	rail_mat.roughness = 0.40
	rail_mat.metallic = 0.20

	var dir3: Vector3 = end_p - start_p
	var total_len: float = Vector2(dir3.x, dir3.z).length()
	var dy_total: float = end_p.y - start_p.y
	var yaw: float = atan2(dir3.x, dir3.z)

	# Merge all planks into 1 ArrayMesh and rails+posts into 1 ArrayMesh (2 draw calls total per bridge!)
	var segs: int = 8
	var seg_len: float = (total_len / float(segs)) * 1.08
	var plank_box := BoxMesh.new(); plank_box.size = Vector3(width, 0.24, seg_len)
	var rail_box := BoxMesh.new(); rail_box.size = Vector3(0.16, 0.18, seg_len)
	var post_box := BoxMesh.new(); post_box.size = Vector3(0.22, 0.92, 0.22)

	var st_planks := SurfaceTool.new()
	st_planks.begin(Mesh.PRIMITIVE_TRIANGLES)
	var st_rails := SurfaceTool.new()
	st_rails.begin(Mesh.PRIMITIVE_TRIANGLES)

	for i: int in range(segs):
		var t0: float = float(i) / float(segs)
		var t1: float = float(i + 1) / float(segs)
		var z0: float = t0 * total_len
		var z1: float = t1 * total_len
		var y0: float = dy_total * t0 + sin(t0 * PI) * arch
		var y1: float = dy_total * t1 + sin(t1 * PI) * arch
		var zm: float = (z0 + z1) * 0.5
		var ym: float = (y0 + y1) * 0.5
		var pitch: float = -atan2(y1 - y0, maxf(0.001, z1 - z0))
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

	content_root.add_child(bridge_root)


static func _add_shrine_pavilion(
	arena: Arena3D,
	content_root: Node3D,
	base_pos: Vector3,
	pillar_hex: String,
	roof_hex: String,
	sc: float = 1.0
) -> void:
	var pav := Node3D.new()
	pav.position = base_pos
	pav.scale = Vector3(sc, sc, sc)

	var pmat := StandardMaterial3D.new()
	pmat.albedo_color = Color.html(pillar_hex); pmat.roughness = 0.45
	var rmat := StandardMaterial3D.new()
	rmat.albedo_color = Color.html(roof_hex); rmat.roughness = 0.55

	var st_pillars := SurfaceTool.new()
	st_pillars.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pm := CylinderMesh.new()
	pm.top_radius = 0.22; pm.bottom_radius = 0.25; pm.height = 4.6; pm.radial_segments = 8; pm.rings = 1
	for ox: float in [-2.6, 2.6]:
		for oz: float in [-2.6, 2.6]:
			st_pillars.append_from(pm, 0, Transform3D(Basis.IDENTITY, Vector3(ox, 2.3, oz)))
			arena.obstacles.append({
				"pos": Vector2(base_pos.x + ox * sc, base_pos.z + oz * sc),
				"radius": 0.40 * sc,
				"top_y": base_pos.y + 4.6 * sc,
			})

	var pillars_inst := MeshInstance3D.new()
	pillars_inst.mesh = st_pillars.commit()
	pillars_inst.material_override = pmat
	pillars_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pav.add_child(pillars_inst)

	var roof := MeshInstance3D.new()
	var rm := CylinderMesh.new()
	rm.top_radius = 0.2; rm.bottom_radius = 4.9; rm.height = 2.1; rm.radial_segments = 4; rm.rings = 1
	roof.mesh = rm
	roof.material_override = rmat
	roof.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	roof.position = Vector3(0.0, 5.4, 0.0)
	roof.rotation.y = PI * 0.25
	pav.add_child(roof)
	content_root.add_child(pav)


static func _add_wagasa_umbrella(content_root: Node3D, base_pos: Vector3) -> void:
	var root := Node3D.new()
	root.position = base_pos

	var pole_mat := StandardMaterial3D.new()
	pole_mat.albedo_color = Color.html("#5c3a21"); pole_mat.roughness = 0.72
	var canopy_mat := StandardMaterial3D.new()
	canopy_mat.albedo_color = Color.html("#dc2626"); canopy_mat.roughness = 0.48
	var bench_mat := StandardMaterial3D.new()
	bench_mat.albedo_color = Color.html("#991b1b"); bench_mat.roughness = 0.58

	var pole := MeshInstance3D.new()
	var pm := CylinderMesh.new(); pm.top_radius = 0.07; pm.bottom_radius = 0.09; pm.height = 3.2; pm.radial_segments = 6; pm.rings = 1
	pole.mesh = pm; pole.material_override = pole_mat
	pole.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pole.position = Vector3(0.0, 1.6, 0.0)
	root.add_child(pole)

	var canopy := MeshInstance3D.new()
	var cm := CylinderMesh.new(); cm.top_radius = 0.12; cm.bottom_radius = 2.15; cm.height = 0.65; cm.radial_segments = 12; cm.rings = 1
	canopy.mesh = cm; canopy.material_override = canopy_mat
	canopy.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	canopy.position = Vector3(0.0, 3.1, 0.0)
	root.add_child(canopy)

	# Red-cloth tea bench beside the umbrella
	var bench := MeshInstance3D.new()
	var bm := BoxMesh.new(); bm.size = Vector3(2.2, 0.55, 0.85)
	bench.mesh = bm; bench.material_override = bench_mat
	bench.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	bench.position = Vector3(0.0, 0.28, 0.95)
	root.add_child(bench)

	content_root.add_child(root)


static func _add_forge_hearth(arena: Arena3D, content_root: Node3D, base_pos: Vector3) -> void:
	arena.obstacles.append({"pos": Vector2(base_pos.x, base_pos.z), "radius": 1.15, "top_y": base_pos.y + 1.5})

	var root := Node3D.new()
	root.position = base_pos

	var stone_mat := StandardMaterial3D.new()
	stone_mat.albedo_color = Color.html("#334155"); stone_mat.roughness = 0.82
	var ember_mat := StandardMaterial3D.new()
	ember_mat.albedo_color = Color.html("#fb923c")
	ember_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var iron_mat := StandardMaterial3D.new()
	iron_mat.albedo_color = Color.html("#1e293b"); iron_mat.roughness = 0.35; iron_mat.metallic = 0.72

	var hearth := MeshInstance3D.new()
	var hm := BoxMesh.new(); hm.size = Vector3(1.9, 1.1, 1.5)
	hearth.mesh = hm; hearth.material_override = stone_mat
	hearth.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	hearth.position = Vector3(0.0, 0.55, 0.0)
	root.add_child(hearth)

	var coals := MeshInstance3D.new()
	var cm := BoxMesh.new(); cm.size = Vector3(1.25, 0.25, 0.95)
	coals.mesh = cm; coals.material_override = ember_mat
	coals.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	coals.position = Vector3(0.0, 1.12, 0.0)
	root.add_child(coals)

	var anvil := MeshInstance3D.new()
	var am := BoxMesh.new(); am.size = Vector3(0.95, 0.72, 0.52)
	anvil.mesh = am; anvil.material_override = iron_mat
	anvil.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	anvil.position = Vector3(-1.55, 0.36, 0.65)
	root.add_child(anvil)

	content_root.add_child(root)


static func _add_jizo_shrine(arena: Arena3D, content_root: Node3D, base_pos: Vector3) -> void:
	arena.obstacles.append({"pos": Vector2(base_pos.x, base_pos.z), "radius": 1.05, "top_y": base_pos.y + 2.8})

	var root := Node3D.new()
	root.position = base_pos

	var stone_mat := StandardMaterial3D.new()
	stone_mat.albedo_color = Color.html("#6b7280"); stone_mat.roughness = 0.88
	var bib_mat := StandardMaterial3D.new()
	bib_mat.albedo_color = Color.html("#dc2626"); bib_mat.roughness = 0.55
	var wood_mat := StandardMaterial3D.new()
	wood_mat.albedo_color = Color.html("#451a03"); wood_mat.roughness = 0.75

	# Stone plinth + statue body & head merged into 1 draw call
	var st_stone := SurfaceTool.new()
	st_stone.begin(Mesh.PRIMITIVE_TRIANGLES)
	var plinth := BoxMesh.new(); plinth.size = Vector3(1.75, 0.55, 1.45)
	var body := CylinderMesh.new(); body.top_radius = 0.34; body.bottom_radius = 0.44; body.height = 1.15; body.radial_segments = 8; body.rings = 1
	var head := SphereMesh.new(); head.radius = 0.30; head.height = 0.60; head.radial_segments = 8; head.rings = 5
	st_stone.append_from(plinth, 0, Transform3D(Basis.IDENTITY, Vector3(0.0, 0.28, 0.0)))
	st_stone.append_from(body, 0, Transform3D(Basis.IDENTITY, Vector3(0.0, 1.12, 0.0)))
	st_stone.append_from(head, 0, Transform3D(Basis.IDENTITY, Vector3(0.0, 1.88, 0.0)))

	var stone_inst := MeshInstance3D.new()
	stone_inst.mesh = st_stone.commit()
	stone_inst.material_override = stone_mat
	stone_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(stone_inst)

	# Iconic red Jizo cloth bib
	var bib := MeshInstance3D.new()
	var bm := BoxMesh.new(); bm.size = Vector3(0.56, 0.44, 0.26)
	bib.mesh = bm; bib.material_override = bib_mat
	bib.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	bib.position = Vector3(0.0, 1.42, 0.26)
	root.add_child(bib)

	# Small pitched wooden shrine shelter roof
	var roof := MeshInstance3D.new()
	var rm := CylinderMesh.new(); rm.top_radius = 0.12; rm.bottom_radius = 1.55; rm.height = 0.85; rm.radial_segments = 4; rm.rings = 1
	roof.mesh = rm; roof.material_override = wood_mat
	roof.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	roof.position = Vector3(0.0, 2.75, 0.0)
	roof.rotation.y = PI * 0.25
	root.add_child(roof)

	content_root.add_child(root)


static func _add_byakko_alcove(arena: Arena3D, content_root: Node3D, npc_pos: Vector3) -> void:
	# Back shrine stone stele positioned behind Elder Byakko at z - 2.6 so NPC stands cleanly at (16.5, y, -34.0)
	var stele_pos := Vector3(npc_pos.x, get_base_terrain_height(npc_pos.x, npc_pos.z - 2.6), npc_pos.z - 2.6)
	arena.obstacles.append({"pos": Vector2(stele_pos.x, stele_pos.z), "radius": 1.35, "top_y": stele_pos.y + 3.6})

	var stone_mat := StandardMaterial3D.new()
	stone_mat.albedo_color = Color.html("#334155"); stone_mat.roughness = 0.72
	var accent_mat := StandardMaterial3D.new()
	accent_mat.albedo_color = Color.html("#e0f2fe"); accent_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var base := BoxMesh.new(); base.size = Vector3(3.4, 0.55, 1.4)
	var wall := BoxMesh.new(); wall.size = Vector3(2.5, 3.1, 0.55)
	var cap := BoxMesh.new(); cap.size = Vector3(3.2, 0.35, 1.0)
	st.append_from(base, 0, Transform3D(Basis.IDENTITY, Vector3(0.0, 0.28, 0.0)))
	st.append_from(wall, 0, Transform3D(Basis.IDENTITY, Vector3(0.0, 1.95, 0.0)))
	st.append_from(cap, 0, Transform3D(Basis.IDENTITY, Vector3(0.0, 3.62, 0.0)))

	var stele := MeshInstance3D.new()
	stele.mesh = st.commit()
	stele.material_override = stone_mat
	stele.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	stele.position = stele_pos
	content_root.add_child(stele)

	# Glowing white-tiger spirit seal inlay on stele front
	var seal := MeshInstance3D.new()
	var sm := BoxMesh.new(); sm.size = Vector3(0.85, 1.35, 0.08)
	seal.mesh = sm; seal.material_override = accent_mat
	seal.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	seal.position = stele_pos + Vector3(0.0, 2.0, 0.30)
	content_root.add_child(seal)

	_add_stone_lantern(content_root, Vector3(npc_pos.x - 2.6, get_base_terrain_height(npc_pos.x - 2.6, npc_pos.z - 1.6), npc_pos.z - 1.6), "#bae6fd")
	_add_stone_lantern(content_root, Vector3(npc_pos.x + 2.6, get_base_terrain_height(npc_pos.x + 2.6, npc_pos.z - 1.6), npc_pos.z - 1.6), "#bae6fd")


static func _add_kotodama_monolith(
	arena: Arena3D,
	content_root: Node3D,
	base_pos: Vector3,
	sky_anim_nodes: Array[Dictionary],
	is_mob: bool
) -> void:
	arena.obstacles.append({"pos": Vector2(base_pos.x, base_pos.z), "radius": 1.75, "top_y": base_pos.y + 7.6})

	var root := Node3D.new()
	root.name = "KotodamaMonolith"
	root.position = base_pos

	var stone_mat := StandardMaterial3D.new()
	stone_mat.albedo_color = Color.html("#1e1b2e"); stone_mat.roughness = 0.42; stone_mat.metallic = 0.28
	var rune_mat := StandardMaterial3D.new()
	rune_mat.albedo_color = Color.html("#f472b6")
	rune_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var aura_mat := StandardMaterial3D.new()
	aura_mat.albedo_color = Color(0.88, 0.36, 0.96, 0.82)
	aura_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	aura_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	# Stepped plinth + tapered obelisk merged into 1 mesh
	var st_body := SurfaceTool.new()
	st_body.begin(Mesh.PRIMITIVE_TRIANGLES)
	var step1 := CylinderMesh.new(); step1.top_radius = 2.6; step1.bottom_radius = 2.9; step1.height = 0.55; step1.radial_segments = 6; step1.rings = 1
	var step2 := CylinderMesh.new(); step2.top_radius = 1.9; step2.bottom_radius = 2.15; step2.height = 0.55; step2.radial_segments = 6; step2.rings = 1
	var obelisk := CylinderMesh.new(); obelisk.top_radius = 0.35; obelisk.bottom_radius = 1.15; obelisk.height = 6.4; obelisk.radial_segments = 6; obelisk.rings = 1
	st_body.append_from(step1, 0, Transform3D(Basis.IDENTITY, Vector3(0.0, 0.27, 0.0)))
	st_body.append_from(step2, 0, Transform3D(Basis.IDENTITY, Vector3(0.0, 0.80, 0.0)))
	st_body.append_from(obelisk, 0, Transform3D(Basis.IDENTITY, Vector3(0.0, 4.15, 0.0)))

	var body_inst := MeshInstance3D.new()
	body_inst.mesh = st_body.commit()
	body_inst.material_override = stone_mat
	body_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(body_inst)

	# Glowing Kotodama spirit rune strips along monolith faces
	var st_runes := SurfaceTool.new()
	st_runes.begin(Mesh.PRIMITIVE_TRIANGLES)
	var strip := BoxMesh.new(); strip.size = Vector3(0.24, 4.2, 0.12)
	for ri: int in range(3):
		var a: float = float(ri) * (TAU / 3.0)
		st_runes.append_from(strip, 0, Transform3D(Basis.from_euler(Vector3(0.0, a, 0.0)), Vector3(sin(a) * 0.80, 3.85, cos(a) * 0.80)))
	var rune_inst := MeshInstance3D.new()
	rune_inst.mesh = st_runes.commit()
	rune_inst.material_override = rune_mat
	rune_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(rune_inst)

	# Rotating sacred halo ring around monolith crown
	var halo := _make_flat_ring(1.85, 2.20, aura_mat, 5.4, is_mob)
	root.add_child(halo)
	sky_anim_nodes.append({"node": halo, "kind": "spin", "speed": 1.35})

	content_root.add_child(root)


static func _add_giant_weeping_sakura(content_root: Node3D, base_pos: Vector3) -> void:
	var tree := Node3D.new()
	tree.name = "GiantWeepingSakura"
	tree.position = base_pos

	var trunk_m := StandardMaterial3D.new()
	trunk_m.albedo_color = Color.html("#2e1a18"); trunk_m.roughness = 0.88
	var leaf_m := StandardMaterial3D.new()
	leaf_m.albedo_color = Color.html("#f472b6"); leaf_m.roughness = 0.50

	# Massive gnarled trunk + main boughs merged into 1 mesh
	var st_trunk := SurfaceTool.new()
	st_trunk.begin(Mesh.PRIMITIVE_TRIANGLES)
	var main_t := CylinderMesh.new(); main_t.top_radius = 0.85; main_t.bottom_radius = 1.45; main_t.height = 9.2; main_t.radial_segments = 8; main_t.rings = 1
	var bough := CylinderMesh.new(); bough.top_radius = 0.35; bough.bottom_radius = 0.65; bough.height = 6.0; bough.radial_segments = 6; bough.rings = 1
	st_trunk.append_from(main_t, 0, Transform3D(Basis.IDENTITY, Vector3(0.0, 4.5, 0.0)))
	st_trunk.append_from(bough, 0, Transform3D(Basis.from_euler(Vector3(0.2, 0.0, 0.65)), Vector3(-2.6, 8.2, 0.4)))
	st_trunk.append_from(bough, 0, Transform3D(Basis.from_euler(Vector3(-0.2, 0.0, -0.65)), Vector3(2.6, 8.2, -0.4)))
	var trunk_inst := MeshInstance3D.new()
	trunk_inst.mesh = st_trunk.commit()
	trunk_inst.material_override = trunk_m
	trunk_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	tree.add_child(trunk_inst)

	# Sprawling weeping blossom canopy merged into 1 single draw call
	var st_leaves := SurfaceTool.new()
	st_leaves.begin(Mesh.PRIMITIVE_TRIANGLES)
	var clusters: Array = [
		[Vector3(0.0, 11.2, 0.0), 5.2, 0.95],
		[Vector3(-4.8, 9.6, 1.2), 4.0, 1.15],
		[Vector3(4.8, 9.8, 0.8), 4.1, 1.15],
		[Vector3(-2.5, 10.4, -3.2), 3.6, 1.05],
		[Vector3(2.8, 10.2, -3.0), 3.5, 1.05],
		[Vector3(0.0, 9.2, 3.6), 3.8, 1.25],
	]
	for cp: Array in clusters:
		var sp := SphereMesh.new()
		var r: float = float(cp[1])
		var h_mult: float = float(cp[2])
		sp.radius = r; sp.height = r * 1.45 * h_mult; sp.radial_segments = 10; sp.rings = 6
		st_leaves.append_from(sp, 0, Transform3D(Basis.IDENTITY, cp[0]))

	var fol := MeshInstance3D.new()
	fol.mesh = st_leaves.commit()
	fol.material_override = leaf_m
	fol.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	tree.add_child(fol)
	content_root.add_child(tree)


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


static func _add_mossy_boulder(arena: Arena3D, content_root: Node3D, base_pos: Vector3, rad: float) -> void:
	arena.obstacles.append({"pos": Vector2(base_pos.x, base_pos.z), "radius": rad, "top_y": base_pos.y + rad * 1.25})
	var rmat := StandardMaterial3D.new()
	rmat.albedo_color = Color.html("#4b5548"); rmat.roughness = 0.88
	var b := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = rad; sm.height = rad * 1.65; sm.radial_segments = 8; sm.rings = 5
	b.mesh = sm; b.material_override = rmat
	b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	b.position = base_pos + Vector3(0.0, rad * 0.55, 0.0)
	content_root.add_child(b)


static func _add_torii_gate(content_root: Node3D, base_pos: Vector3, pillar_hex: String, sc: float = 1.0) -> void:
	var torii := Node3D.new()
	torii.position = base_pos
	torii.scale = Vector3(sc, sc, sc)

	var pillar_mat := StandardMaterial3D.new()
	pillar_mat.albedo_color = Color.html(pillar_hex); pillar_mat.roughness = 0.40
	var cap_mat := StandardMaterial3D.new()
	cap_mat.albedo_color = Color.html("#0f172a"); cap_mat.roughness = 0.50

	var st_red := SurfaceTool.new()
	st_red.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pillar_mesh := CylinderMesh.new()
	pillar_mesh.top_radius = 0.35; pillar_mesh.bottom_radius = 0.42; pillar_mesh.height = 7.2
	pillar_mesh.radial_segments = 10; pillar_mesh.rings = 1
	for px: float in [-3.2, 3.2]:
		st_red.append_from(pillar_mesh, 0, Transform3D(Basis.IDENTITY, Vector3(px, 3.6, 0.0)))
	var nuki_mesh := BoxMesh.new(); nuki_mesh.size = Vector3(7.6, 0.40, 0.50)
	st_red.append_from(nuki_mesh, 0, Transform3D(Basis.IDENTITY, Vector3(0.0, 5.7, 0.0)))

	var red_inst := MeshInstance3D.new()
	red_inst.mesh = st_red.commit()
	red_inst.material_override = pillar_mat
	red_inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	torii.add_child(red_inst)

	var kasagi := MeshInstance3D.new()
	var km := BoxMesh.new(); km.size = Vector3(8.8, 0.55, 0.80)
	kasagi.mesh = km; kasagi.material_override = cap_mat
	kasagi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	kasagi.position = Vector3(0.0, 7.3, 0.0)
	torii.add_child(kasagi)

	content_root.add_child(torii)


static func _add_stone_lantern(content_root: Node3D, base_pos: Vector3, glow_hex: String) -> void:
	var lg := Node3D.new()
	lg.position = base_pos

	var stone_mat := StandardMaterial3D.new(); stone_mat.albedo_color = Color.html("#64748b"); stone_mat.roughness = 0.80
	var roof_mat := StandardMaterial3D.new(); roof_mat.albedo_color = Color.html("#475569"); roof_mat.roughness = 0.70
	var glow_mat := StandardMaterial3D.new(); glow_mat.albedo_color = Color.html(glow_hex); glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	var b := MeshInstance3D.new()
	var bm := BoxMesh.new(); bm.size = Vector3(1.1, 2.2, 1.1)
	b.mesh = bm; b.material_override = stone_mat
	b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	b.position = Vector3(0.0, 1.1, 0.0)
	lg.add_child(b)

	var g := MeshInstance3D.new()
	var gm := BoxMesh.new(); gm.size = Vector3(0.75, 0.75, 0.75)
	g.mesh = gm; g.material_override = glow_mat
	g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	g.position = Vector3(0.0, 2.55, 0.0)
	lg.add_child(g)

	var r := MeshInstance3D.new()
	var rm := CylinderMesh.new(); rm.top_radius = 0.0; rm.bottom_radius = 1.15; rm.height = 0.9; rm.radial_segments = 4; rm.rings = 1
	r.mesh = rm; r.material_override = roof_mat
	r.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	r.position = Vector3(0.0, 3.35, 0.0)
	r.rotation.y = PI * 0.25
	lg.add_child(r)

	content_root.add_child(lg)


static func _add_stylized_tree(
	content_root: Node3D,
	base_pos: Vector3,
	trunk_hex: String,
	leaf_hex: String,
	sc: float = 1.0
) -> void:
	var tree := Node3D.new()
	tree.position = base_pos
	tree.scale = Vector3(sc, sc, sc)

	var trunk_m := StandardMaterial3D.new(); trunk_m.albedo_color = Color.html(trunk_hex); trunk_m.roughness = 0.85
	var leaf_m := StandardMaterial3D.new(); leaf_m.albedo_color = Color.html(leaf_hex); leaf_m.roughness = 0.55

	var trunk := MeshInstance3D.new()
	var tc := CylinderMesh.new(); tc.top_radius = 0.24; tc.bottom_radius = 0.42; tc.height = 4.2; tc.radial_segments = 7; tc.rings = 1
	trunk.mesh = tc; trunk.material_override = trunk_m
	trunk.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	trunk.position = Vector3(0.0, 2.0, 0.0)
	tree.add_child(trunk)

	var st_leaves := SurfaceTool.new()
	st_leaves.begin(Mesh.PRIMITIVE_TRIANGLES)
	for cp: Array in [
		[Vector3(0.0, 4.6, 0.0), 2.1],
		[Vector3(1.2, 4.1, 0.7), 1.45],
		[Vector3(-1.1, 4.2, -0.6), 1.55],
	]:
		var sp := SphereMesh.new()
		var r: float = float(cp[1])
		sp.radius = r; sp.height = r * 1.45; sp.radial_segments = 10; sp.rings = 6
		st_leaves.append_from(sp, 0, Transform3D(Basis.IDENTITY, cp[0]))

	var fol := MeshInstance3D.new()
	fol.mesh = st_leaves.commit()
	fol.material_override = leaf_m
	fol.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	tree.add_child(fol)

	content_root.add_child(tree)


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
