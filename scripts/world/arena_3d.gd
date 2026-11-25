class_name Arena3D
extends Node3D
## Procedurally builds 4 complex, multi-tiered 3D Japanese battlegrounds with high-resolution
## heightfield terrain, walkable arched bridges & multi-level decks, solid tactical cover pillars,
## atmospheric water/lava/cloud layers, and animated stage-specific mechanics.

@export var world_environment: WorldEnvironment
@export var center_light: OmniLight3D

var current_stage_id: String = "sakura_shrine"

# Walkable elevated circular decks: {pos: Vector3 (XZ center, y=top), radius: float}
var platforms: Array[Dictionary] = []
# Walkable arched rectangular bridges/walkways: {start: Vector3, end: Vector3, width: float, arch: float}
var bridges: Array[Dictionary] = []
# Solid tactical cover obstacles (pillars, boulders, pagoda columns): {pos: Vector2, radius: float, top_y: float}
var obstacles: Array[Dictionary] = []

# Stage-specific mechanic zones queried by BattleManager
var sakura_zone_pos: Vector3 = Vector3.ZERO
var sakura_zone_radius: float = 4.8
var wind_zones: Array[Dictionary] = []       # {pos: Vector3, radius: float, node: Node3D}
var jump_pads: Array[Dictionary] = []        # {pos: Vector3, radius: float, node: Node3D}

var _arena_content: Node3D
var _particles: CPUParticles3D
var _sakura_zone_node: Node3D
var _lava_plane_mat: StandardMaterial3D
var _water_plane_mat: StandardMaterial3D
var _elapsed: float = 0.0
var _sakura_spots: Array[Vector2] = [
	Vector2(0.0, -17.5),
	Vector2(17.5, 2.0),
	Vector2(-17.5, 2.0),
	Vector2(0.0, 1.5),
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
	var r := sqrt(x * x + z * z)
	var radius := GameData.ARENA_RADIUS

	match current_stage_id:
		"sakura_shrine":
			# Multi-tier Shrine Complex: Central Plaza (+0.35m) -> Sunken Moonlit Koi Moat (-0.75m)
			# -> North Grand Torii Altar (+2.75m) + Twin East/West Pavilions (+1.85m) + South Steps (+0.85m)
			var h := 0.0
			# Central stone courtyard mound
			var inner_t := clampf(1.0 - maxf(0.0, r - 5.2) / 2.2, 0.0, 1.0)
			inner_t = inner_t * inner_t * (3.0 - 2.0 * inner_t)
			h = lerpf(0.0, 0.38, inner_t)

			# Sunken circular Koi Pond Moat ring around r = 8.8m (spanning r=6.8..11.2m)
			var moat_d := absf(r - 8.9)
			var moat_t := clampf(1.0 - moat_d / 2.4, 0.0, 1.0)
			moat_t = moat_t * moat_t * (3.0 - 2.0 * moat_t)
			h -= 0.78 * moat_t

			# North Elevated Torii Altar (+2.75m) with stepped stone approach
			var north_t := clampf((-z - 10.5) / 6.2, 0.0, 1.0)
			north_t = north_t * north_t * (3.0 - 2.0 * north_t)
			var x_mask := clampf(1.0 - maxf(0.0, absf(x) - 10.5) / 6.2, 0.0, 1.0)
			var north_altar := 2.75 * north_t * x_mask

			# Twin East/West Moon-Viewing Pavilion Terraces (+1.85m)
			var wing_x := clampf((absf(x) - 12.2) / 4.8, 0.0, 1.0)
			wing_x = wing_x * wing_x * (3.0 - 2.0 * wing_x)
			var wing_z := clampf(1.0 - maxf(0.0, absf(z - 2.0) - 7.8) / 5.2, 0.0, 1.0)
			var wing_balcony := 1.85 * wing_x * wing_z

			# South Stepped Approach (+0.95m)
			var south_t := clampf((z - 13.5) / 5.8, 0.0, 1.0)
			var south_step := 0.95 * south_t * south_t * (3.0 - 2.0 * south_t)
			return maxf(h, maxf(maxf(north_altar, wing_balcony), south_step))

		"maple_temple":
			# Winding Mountain Gorge (-1.15m) + Central Pagoda Sanctuary (+2.15m) + Steep Terraced Hills (+2.95m)
			var center_mound := 2.15 * exp(-((r * r) / 42.0))
			# Winding S-shaped river gorge carving around center
			var gorge_curve := sin(x * 0.16) * 4.2
			var gorge_ring := absf(r - 11.8 - sin(atan2(z, x) * 2.0) * 1.8)
			var valley_dip := -1.18 * exp(-((gorge_ring * gorge_ring) / 9.5))
			var stream_cut := -0.45 * exp(-(((z - gorge_curve) * (z - gorge_curve)) / 8.0)) * clampf((r - 6.0) / 5.0, 0.0, 1.0)

			var ang := atan2(z, x)
			var outer_t := clampf((r - 14.2) / 8.5, 0.0, 1.0)
			outer_t = outer_t * outer_t * (3.0 - 2.0 * outer_t)
			var raw_hills := (1.95 + 1.05 * sin(ang * 3.0 + 0.5) + 0.55 * cos(ang * 5.0 - 0.7)) * outer_t
			# Quantize slightly for subtle terraced temple hillside steps
			var stepped_hills := lerpf(raw_hills, floor(raw_hills * 1.8) / 1.8, 0.30)
			return center_mound + valley_dip + stream_cut + stepped_hills

		"onigashima_lava":
			# Cracked Volcanic Caldera: Deep Magma Chasms (-1.05m) + Central Hub (+1.05m)
			# + 4 Basalt Fortresses (+2.45m) + 4 Safe Diagonal Stone Causeways (+0.78m) + Volcanic Rim
			var h := -1.05
			# Central volcanic hub with rimmed crater step
			var center_t := clampf(1.0 - maxf(0.0, r - 4.6) / 3.8, 0.0, 1.0)
			center_t = center_t * center_t * (3.0 - 2.0 * center_t)
			h = maxf(h, lerpf(-1.05, 1.05, center_t))

			# 4 Raised Obsidian Basalt Bastions in NE, NW, SE, SW quadrants
			var islands := [
				Vector2(13.5, -13.0),
				Vector2(-13.5, -13.0),
				Vector2(13.5, 13.0),
				Vector2(-13.5, 13.0),
			]
			for isl: Vector2 in islands:
				var d := Vector2(x, z).distance_to(isl)
				var it := clampf(1.0 - maxf(0.0, d - 5.0) / 4.2, 0.0, 1.0)
				it = it * it * (3.0 - 2.0 * it)
				h = maxf(h, lerpf(-1.05, 2.45, it))

			# 4 Diagonal Obsidian Stone Causeways (safe above lava)
			var diag_d1 := absf(x - z) * 0.7071
			var diag_d2 := absf(x + z) * 0.7071
			var bridge_d := minf(diag_d1, diag_d2)
			if r > 3.2 and r < 22.5:
				var bt := clampf(1.0 - maxf(0.0, bridge_d - 1.75) / 1.65, 0.0, 1.0)
				bt = bt * bt * (3.0 - 2.0 * bt)
				h = maxf(h, lerpf(-1.05, 0.78, bt))

			# Outer jagged volcanic caldera ridge
			var ang := atan2(z, x)
			var rim_t := clampf((r - (radius - 4.4)) / 3.8, 0.0, 1.0)
			var rim_h := 1.45 + 0.55 * sin(ang * 8.0)
			h = maxf(h, lerpf(-1.05, rim_h, rim_t * rim_t))
			return h

		"sky_tenshu":
			# Tiered Golden Sky-Castle Courtyard + 4 Ceremonial Spirit-Ramps (N/S/E/W) climbing to +2.55m!
			var h := 0.0
			# Subtle octagonal sunken inner courtyard + raised golden terrace rim
			var inner_rim := clampf((r - 11.5) / 4.5, 0.0, 1.0)
			h = 0.55 * inner_rim * inner_rim * (3.0 - 2.0 * inner_rim)
			var outer_rim := clampf((r - 20.5) / 4.5, 0.0, 1.0)
			h += 0.85 * outer_rim * outer_rim * (3.0 - 2.0 * outer_rim)

			# North/South sloped ceremonial spirit-ramps climbing up to +2.55m floating decks
			if absf(x) < 3.4 and absf(z) > 6.2 and absf(z) < 16.5:
				var ramp_t := clampf((absf(z) - 6.2) / 8.0, 0.0, 1.0)
				var x_fade := clampf(1.0 - maxf(0.0, absf(x) - 2.1) / 1.3, 0.0, 1.0)
				h = maxf(h, 2.55 * ramp_t * x_fade)
			# East/West sloped ceremonial spirit-ramps climbing up to +2.65m floating decks
			if absf(z) < 3.4 and absf(x) > 6.2 and absf(x) < 16.5:
				var ramp_tx := clampf((absf(x) - 6.2) / 8.0, 0.0, 1.0)
				var z_fade := clampf(1.0 - maxf(0.0, absf(z) - 2.1) / 1.3, 0.0, 1.0)
				h = maxf(h, 2.65 * ramp_tx * z_fade)
			return h

	return 0.0


func get_ground_height(x: float, z: float, entity_y: float = 99.0) -> float:
	var h := get_base_terrain_height(x, z)

	# Check walkable circular elevated decks
	for plat in platforms:
		var p: Vector3 = plat["pos"]
		var rad: float = float(plat["radius"])
		var dx := x - p.x
		var dz := z - p.z
		if (dx * dx + dz * dz) <= rad * rad:
			if p.y <= entity_y + 0.85:
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
			if deck_y <= entity_y + 0.90:
				h = maxf(h, deck_y)

	return h


func resolve_obstacle_collision(pos: Vector3, entity_radius: float = 0.65) -> Vector3:
	var out := pos
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
	return out


func is_in_lava(x: float, z: float, entity_y: float) -> bool:
	if current_stage_id != "onigashima_lava":
		return false
	return entity_y < -0.35 and get_base_terrain_height(x, z) < -0.45


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

	for child in _arena_content.get_children():
		child.queue_free()

	platforms.clear()
	bridges.clear()
	obstacles.clear()
	wind_zones.clear()
	jump_pads.clear()
	_sakura_zone_node = null
	_lava_plane_mat = null
	_water_plane_mat = null
	_sakura_spot_idx = 0

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
		env.background_mode = Environment.BG_COLOR
		env.background_color = sky_col
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = ambient_col
		env.ambient_light_energy = 0.85
		env.fog_enabled = true
		env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
		env.fog_light_color = fog_col
		env.fog_density = 0.010

	if center_light != null:
		center_light.light_color = ring_col
		center_light.light_energy = 1.9
		center_light.omni_range = 72.0

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

	# 4. Ambient Falling Petals / Leaves / Embers / Starlight
	_build_ambient_particles(particle_col)


func _terrain_vertex_color(x: float, z: float, h: float, base_col: Color) -> Color:
	var r := sqrt(x * x + z * z)
	match current_stage_id:
		"sakura_shrine":
			if h < -0.22:
				return Color.html("#13283d") # Sunken moonlit koi pond floor
			elif h > 2.0:
				return Color.html("#523f63") # Elevated grand shrine granite
			elif h > 1.1:
				return Color.html("#423352") # Pavilion terrace slate
			elif r < 5.6:
				return Color.html("#3d2f4d") # Central tiled sanctuary
			return base_col
		"maple_temple":
			if h < -0.45:
				return Color.html("#16353a") # Deep misty stream gorge bed
			elif h < 0.15:
				return Color.html("#213d2b") # Mossy bamboo valley bank
			elif h > 1.9:
				return Color.html("#7c3f23") # Crimson maple terrace ridge
			return base_col.lerp(Color.html("#4d522c"), clampf((h + 0.3) * 0.35, 0.0, 0.65))
		"onigashima_lava":
			if h < -0.45:
				return Color.html("#ea580c") # Molten magma chasm
			elif h < 0.20:
				return Color.html("#4c1812") # Scorched volcanic slope
			elif h > 1.75:
				return Color.html("#31292e") # Obsidian fortress crown
			return Color.html("#241e21")
		"sky_tenshu":
			if h > 1.3:
				return Color.html("#5b6478").lerp(Color.html("#fde047"), 0.28) # Golden spirit ramps
			elif h > 0.45:
				return Color.html("#2c3f63") # Outer castle stone rim
			elif r < 6.0:
				return Color.html("#223454")
			return Color.html("#182742")
	return base_col


func _build_heightfield_terrain(floor_col: Color, _ring_col: Color) -> void:
	var radius := GameData.ARENA_RADIUS
	var rings := 34
	var segs := 72

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
			var eps := 0.30
			var hx1 := get_base_terrain_height(x + eps, z)
			var hx0 := get_base_terrain_height(x - eps, z)
			var hz1 := get_base_terrain_height(x, z + eps)
			var hz0 := get_base_terrain_height(x, z - eps)
			var nrm := Vector3(hx0 - hx1, 2.0 * eps, hz0 - hz1).normalized()
			var col := _terrain_vertex_color(x, z, y, floor_col)
			row.append([Vector3(x, y, z), nrm, col])
		grid.append(row)

	for ri in range(rings):
		for si in range(segs):
			var sn := (si + 1) % segs
			var v00: Array = grid[ri][si]
			var v10: Array = grid[ri + 1][si]
			var v11: Array = grid[ri + 1][sn]
			var v01: Array = grid[ri][sn]

			st.set_color(v00[2]); st.set_normal(v00[1]); st.add_vertex(v00[0])
			st.set_color(v11[2]); st.set_normal(v11[1]); st.add_vertex(v11[0])
			st.set_color(v10[2]); st.set_normal(v10[1]); st.add_vertex(v10[0])

			st.set_color(v00[2]); st.set_normal(v00[1]); st.add_vertex(v00[0])
			st.set_color(v01[2]); st.set_normal(v01[1]); st.add_vertex(v01[0])
			st.set_color(v11[2]); st.set_normal(v11[1]); st.add_vertex(v11[0])

	# Outer rocky cliff skirt
	var skirt_col := floor_col.darkened(0.45)
	for si in range(segs):
		var sn := (si + 1) % segs
		var top0: Vector3 = grid[rings][si][0]
		var top1: Vector3 = grid[rings][sn][0]
		var bot0 := Vector3(top0.x * 1.05, top0.y - 5.0, top0.z * 1.05)
		var bot1 := Vector3(top1.x * 1.05, top1.y - 5.0, top1.z * 1.05)
		var out_n := Vector3(top0.x + top1.x, 0.0, top0.z + top1.z).normalized()

		st.set_color(skirt_col); st.set_normal(out_n); st.add_vertex(top0)
		st.set_color(skirt_col); st.set_normal(out_n); st.add_vertex(top1)
		st.set_color(skirt_col); st.set_normal(out_n); st.add_vertex(bot1)

		st.set_color(skirt_col); st.set_normal(out_n); st.add_vertex(top0)
		st.set_color(skirt_col); st.set_normal(out_n); st.add_vertex(bot1)
		st.set_color(skirt_col); st.set_normal(out_n); st.add_vertex(bot0)

	var mesh := st.commit()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.76
	mat.metallic = 0.14

	var terrain_inst := MeshInstance3D.new()
	terrain_inst.name = "TerrainMesh"
	terrain_inst.mesh = mesh
	terrain_inst.material_override = mat
	_arena_content.add_child(terrain_inst)


func _build_boundary_ring(ring_col: Color) -> void:
	var radius := GameData.ARENA_RADIUS - 0.35
	var segs := 72
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
		st.set_normal(Vector3.UP); st.add_vertex(p0i); st.set_normal(Vector3.UP); st.add_vertex(p1o); st.set_normal(Vector3.UP); st.add_vertex(p0o)
		st.set_normal(Vector3.UP); st.add_vertex(p0i); st.set_normal(Vector3.UP); st.add_vertex(p1i); st.set_normal(Vector3.UP); st.add_vertex(p1o)

	var mat := StandardMaterial3D.new()
	mat.albedo_color = ring_col
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var inst := MeshInstance3D.new()
	inst.mesh = st.commit()
	inst.material_override = mat
	_arena_content.add_child(inst)


# ==============================================================================
#  STAGE 1: SAKURA SHRINE (Koi Moat + 3 Arched Vermilion Bridges + Pavilions)
# ==============================================================================
func _build_sakura_shrine_props(_ring_col: Color) -> void:
	# Shimmering Moonlit Koi Pond Water Ring peeking in the sunken moat (y = -0.34)
	_add_water_plane(-0.34, 13.0, "#1d4ed8", 0.56)

	# Double Ceremonial Vermilion Torii Gates (Inner & Grand North Altar)
	_add_torii_gate(Vector3(0.0, get_base_terrain_height(0.0, -23.5), -23.5), "#dc2626", 1.32)
	_add_torii_gate(Vector3(0.0, get_base_terrain_height(0.0, 21.5), 21.5), "#b91c1c", 1.05)

	# 4 Walkable Arched Vermilion Taiko Bridges spanning the sunken Koi Moat!
	_add_walkable_bridge(Vector3(0.0, 0.35, -5.2), Vector3(0.0, 1.35, -13.0), 4.6, 0.85, "#7f1d1d", "#ef4444")
	_add_walkable_bridge(Vector3(5.2, 0.32, 1.0), Vector3(13.6, 1.35, 1.5), 4.2, 0.72, "#7f1d1d", "#ef4444")
	_add_walkable_bridge(Vector3(-5.2, 0.32, 1.0), Vector3(-13.6, 1.35, 1.5), 4.2, 0.72, "#7f1d1d", "#ef4444")
	_add_walkable_bridge(Vector3(0.0, 0.32, 5.4), Vector3(0.0, 0.55, 13.2), 4.4, 0.65, "#7f1d1d", "#ef4444")

	# 2 Elevated Walkable Moon-Viewing Stone Decks flanking the North Altar!
	_add_walkable_deck(Vector3(-11.8, 2.25, -14.8), 3.9, "#3b2c4a", "#f472b6")
	_add_walkable_deck(Vector3(11.8, 2.25, -14.8), 3.9, "#3b2c4a", "#f472b6")

	# Twin East/West Open Shrine Pavilion Roofs (ornate corners, walkable under!)
	_add_shrine_pavilion(Vector3(19.5, get_base_terrain_height(19.5, 2.0), 2.0), "#991b1b", "#1e1b2e", 1.0)
	_add_shrine_pavilion(Vector3(-19.5, get_base_terrain_height(-19.5, 2.0), 2.0), "#991b1b", "#1e1b2e", 1.0)

	# 4 Solid Tactical Shrine Stone Columns around outer moat corners
	for cp: Vector2 in [Vector2(-7.8, -7.8), Vector2(7.8, -7.8), Vector2(-7.8, 9.5), Vector2(7.8, 9.5)]:
		var cy := get_base_terrain_height(cp.x, cp.y)
		_add_tactical_pillar(Vector3(cp.x, cy, cp.y), 0.78, 4.4, "#4c3b5e", "#f472b6")

	# 8 Lush Night Sakura Trees framing the terraced shrine
	for tp: Vector2 in [
		Vector2(-20.5, -13.0), Vector2(20.5, -13.0), Vector2(-21.0, 13.0), Vector2(21.0, 13.0),
		Vector2(-12.5, -21.5), Vector2(12.5, -21.5), Vector2(-13.5, 19.5), Vector2(13.5, 19.5)
	]:
		_add_stylized_tree(Vector3(tp.x, get_base_terrain_height(tp.x, tp.y), tp.y), "#3b231e", "#f472b6", 1.28)

	# 8 Glowing Stone Lanterns along terraces
	for ang in [0.35, 1.15, 1.95, 2.75, -0.45, -1.15, -2.0, -2.7]:
		var lx := cos(ang) * (GameData.ARENA_RADIUS - 2.2)
		var lz := sin(ang) * (GameData.ARENA_RADIUS - 2.2)
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
	_sakura_zone_node.add_child(_make_flat_ring(1.8, 2.15, ring_m, 0.06))
	_arena_content.add_child(_sakura_zone_node)


# ==============================================================================
#  STAGE 2: MAPLE TEMPLE (Mountain Gorge + 4 Timber Bridges + 3 Canopy Decks + Pagoda)
# ==============================================================================
func _build_maple_temple_props(_ring_col: Color) -> void:
	# Shimmering Mountain Gorge Stream in the deep ravine (y = -0.62)
	_add_water_plane(-0.62, 23.0, "#0e7490", 0.52)

	_add_torii_gate(Vector3(0.0, get_base_terrain_height(0.0, -23.5), -23.5), "#ea580c", 1.2)

	# 4 Walkable Wooden Suspension Bridges spanning the sunken autumn ravine!
	_add_walkable_bridge(Vector3(0.0, 1.45, -5.2), Vector3(0.0, 1.65, -16.8), 4.0, 0.75, "#5c3317", "#f59e0b")
	_add_walkable_bridge(Vector3(0.0, 1.45, 5.2), Vector3(0.0, 1.55, 16.8), 4.0, 0.75, "#5c3317", "#f59e0b")
	_add_walkable_bridge(Vector3(5.2, 1.45, 0.0), Vector3(16.8, 1.60, 0.0), 4.0, 0.75, "#5c3317", "#f59e0b")
	_add_walkable_bridge(Vector3(-5.2, 1.45, 0.0), Vector3(-16.8, 1.60, 0.0), 4.0, 0.75, "#5c3317", "#f59e0b")

	# 3 Walkable Elevated Wooden Tea-House Canopy Decks perched on outer autumn hills!
	_add_walkable_deck(Vector3(-15.5, 2.65, -12.5), 4.3, "#5c2d16", "#fb923c")
	_add_walkable_deck(Vector3(15.5, 2.65, -12.5), 4.3, "#5c2d16", "#fb923c")
	_add_walkable_deck(Vector3(0.0, 2.75, 18.2), 4.6, "#5c2d16", "#fb923c")

	# Central Pagoda Sanctuary Spire (tall landmark perched at dead center, solid core!)
	_add_temple_pagoda(Vector3(0.0, get_base_terrain_height(0.0, 0.0), 0.0))

	# 4 Tactical Mossy Temple Boulders providing flank cover in the ravine & ridges
	for bp: Vector2 in [Vector2(-9.5, -9.2), Vector2(9.5, -9.2), Vector2(-9.5, 9.2), Vector2(9.5, 9.2)]:
		_add_mossy_boulder(Vector3(bp.x, get_base_terrain_height(bp.x, bp.y), bp.y), 1.35)

	# Perimeter Tall Bamboo Groves
	var bamboo_mat := StandardMaterial3D.new()
	bamboo_mat.albedo_color = Color.html("#15803d")
	bamboo_mat.roughness = 0.45
	var stalk_mesh := CylinderMesh.new()
	stalk_mesh.top_radius = 0.16; stalk_mesh.bottom_radius = 0.22; stalk_mesh.height = 10.5; stalk_mesh.radial_segments = 10
	for i in range(20):
		var ang := (float(i) / 20.0) * TAU + 0.12
		if absf(ang - (-PI * 0.5)) < 0.35 or absf(ang - (PI * 1.5)) < 0.35:
			continue
		var dist := GameData.ARENA_RADIUS - 2.1 - (0.9 if i % 2 == 0 else 0.0)
		var bx := cos(ang) * dist; var bz := sin(ang) * dist
		var by := get_base_terrain_height(bx, bz)
		for offset: Vector2 in [Vector2(0.0, 0.0), Vector2(0.7, 0.5), Vector2(-0.6, 0.7)]:
			var stalk := MeshInstance3D.new()
			stalk.mesh = stalk_mesh; stalk.material_override = bamboo_mat
			stalk.position = Vector3(bx + offset.x, by + 5.0, bz + offset.y)
			stalk.rotation.z = sin(float(i) + offset.x) * 0.06
			_arena_content.add_child(stalk)

	# 7 Crimson & Golden Maple Trees atop outer hills
	for mp: Vector2 in [
		Vector2(-19.5, -8.5), Vector2(19.5, -8.5), Vector2(-18.5, 14.5), Vector2(18.5, 14.5),
		Vector2(-11.0, -21.0), Vector2(11.0, -21.0), Vector2(12.5, 20.0)
	]:
		_add_stylized_tree(Vector3(mp.x, get_base_terrain_height(mp.x, mp.y), mp.y), "#451a03", "#ea580c", 1.32)

	# Stage Mechanic: 3 Swirling Emerald-Gold Wind Draft Pillars (疾風氣流)
	var wind_coords := [Vector2(-12.5, 4.0), Vector2(12.5, 4.0), Vector2(0.0, -12.5)]
	var wind_mat := StandardMaterial3D.new()
	wind_mat.albedo_color = Color(0.28, 0.94, 0.72, 0.78)
	wind_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	wind_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for wc: Vector2 in wind_coords:
		var wy := get_ground_height(wc.x, wc.y)
		var wn := Node3D.new()
		wn.position = Vector3(wc.x, wy, wc.y)
		for ri in range(3):
			wn.add_child(_make_flat_ring(1.6 + float(ri) * 0.65, 1.9 + float(ri) * 0.65, wind_mat, 0.35 + float(ri) * 1.15))
		_arena_content.add_child(wn)
		wind_zones.append({"pos": Vector3(wc.x, wy, wc.y), "radius": 3.8, "node": wn})


# ==============================================================================
#  STAGE 3: ONIGASHIMA LAVA (Magma Chasms + High Chain-Bridges + Basalt Fortresses)
# ==============================================================================
func _build_onigashima_lava_props(_ring_col: Color) -> void:
	_add_torii_gate(Vector3(0.0, get_base_terrain_height(0.0, -24.0), -24.0), "#991b1b", 1.35)

	# Glowing Molten Lava Surface Plane peeking through all sunken chasms (y = -0.58)
	var lava_mesh := CylinderMesh.new()
	lava_mesh.top_radius = GameData.ARENA_RADIUS - 0.4
	lava_mesh.bottom_radius = GameData.ARENA_RADIUS - 0.4
	lava_mesh.height = 0.1
	lava_mesh.radial_segments = 56
	_lava_plane_mat = StandardMaterial3D.new()
	_lava_plane_mat.albedo_color = Color.html("#f97316")
	_lava_plane_mat.emission_enabled = true
	_lava_plane_mat.emission = Color.html("#ea580c")
	_lava_plane_mat.emission_energy_multiplier = 1.65
	_lava_plane_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var lava_inst := MeshInstance3D.new()
	lava_inst.mesh = lava_mesh; lava_inst.material_override = _lava_plane_mat
	lava_inst.position = Vector3(0.0, -0.58, 0.0)
	_arena_content.add_child(lava_inst)

	# 2 High-Altitude Walkable Chain-Plank Fortress Bridges spanning between Obsidian Plateaus!
	_add_walkable_bridge(Vector3(-12.5, 2.45, -13.0), Vector3(12.5, 2.45, -13.0), 3.8, 0.65, "#292524", "#f97316")
	_add_walkable_bridge(Vector3(-12.5, 2.45, 13.0), Vector3(12.5, 2.45, 13.0), 3.8, 0.65, "#292524", "#f97316")

	# 2 Ultra-High Demon Watch-Decks (+3.35m) perched above East & West rim!
	_add_walkable_deck(Vector3(19.5, 3.25, 0.0), 4.0, "#1c1917", "#ef4444")
	_add_walkable_deck(Vector3(-19.5, 3.25, 0.0), 4.0, "#1c1917", "#ef4444")
	# Walkable ramps connecting NE/NW plateaus to the East/West Demon Watch-Decks
	_add_walkable_bridge(Vector3(14.5, 2.45, -11.5), Vector3(19.2, 3.25, -2.5), 3.2, 0.25, "#292524", "#dc2626")
	_add_walkable_bridge(Vector3(-14.5, 2.45, -11.5), Vector3(-19.2, 3.25, -2.5), 3.2, 0.25, "#292524", "#dc2626")

	# 4 Tactical Obsidian Monolith Pillars around the central battle hub
	for op: Vector2 in [Vector2(0.0, -5.8), Vector2(0.0, 5.8), Vector2(5.8, 0.0), Vector2(-5.8, 0.0)]:
		_add_tactical_pillar(Vector3(op.x, get_base_terrain_height(op.x, op.y), op.y), 0.72, 3.6, "#1c1917", "#f97316")

	# Jagged Obsidian Crystal Spires crowning the outer volcanic rim
	var obs_mat := StandardMaterial3D.new()
	obs_mat.albedo_color = Color.html("#1c1917"); obs_mat.roughness = 0.32; obs_mat.metallic = 0.50
	var spire_mesh := CylinderMesh.new()
	spire_mesh.top_radius = 0.06; spire_mesh.bottom_radius = 1.25; spire_mesh.height = 6.8; spire_mesh.radial_segments = 5
	for sp: Vector2 in [
		Vector2(20.0, -18.0), Vector2(-20.0, -18.0), Vector2(20.0, 18.0), Vector2(-20.0, 18.0),
		Vector2(24.5, -6.0), Vector2(-24.5, -6.0), Vector2(24.5, 6.0), Vector2(-24.5, 6.0)
	]:
		var sy := get_base_terrain_height(sp.x, sp.y)
		var spire := MeshInstance3D.new()
		spire.mesh = spire_mesh; spire.material_override = obs_mat
		spire.position = Vector3(sp.x, sy + 3.0, sp.y)
		spire.rotation.z = -signf(sp.x) * 0.20
		_arena_content.add_child(spire)

	# 4 Flaming Oni Braziers on the 4 Obsidian Plateaus
	for bp: Vector2 in [Vector2(13.5, -13.0), Vector2(-13.5, -13.0), Vector2(13.5, 13.0), Vector2(-13.5, 13.0)]:
		_add_stone_lantern(Vector3(bp.x, get_base_terrain_height(bp.x, bp.y), bp.y), "#f97316")


# ==============================================================================
#  STAGE 4: SKY TENSHU (6 Multi-Tier Floating Decks + 4 Golden Sky-Bridges + 6 Jump Pads)
# ==============================================================================
func _build_sky_tenshu_props(_ring_col: Color) -> void:
	_add_torii_gate(Vector3(0.0, get_base_terrain_height(0.0, -24.5), -24.5), "#f59e0b", 1.35)

	# 4 Mid-Tier Walkable Floating Jade-Gold Sky Platforms (+2.55m ~ +2.65m)
	_add_walkable_deck(Vector3(0.0, 2.55, -16.2), 5.6, "#1e3a5f", "#facc15")
	_add_walkable_deck(Vector3(0.0, 2.55, 16.2), 5.4, "#1e3a5f", "#facc15")
	_add_walkable_deck(Vector3(16.2, 2.65, 0.0), 5.4, "#1e3a5f", "#facc15")
	_add_walkable_deck(Vector3(-16.2, 2.65, 0.0), 5.4, "#1e3a5f", "#facc15")

	# 2 Sovereign Upper-Tier Moon-Decks (+4.25m high!)
	_add_walkable_deck(Vector3(-13.8, 4.25, -13.8), 4.4, "#172554", "#fef08a")
	_add_walkable_deck(Vector3(13.8, 4.25, -13.8), 4.4, "#172554", "#fef08a")

	# 4 Walkable Glowing Golden Sky-Bridges linking the floating decks into an aerial ring!
	_add_walkable_bridge(Vector3(4.5, 2.55, -14.8), Vector3(14.8, 2.65, -4.5), 3.4, 0.55, "#1e3a5f", "#facc15")
	_add_walkable_bridge(Vector3(-4.5, 2.55, -14.8), Vector3(-14.8, 2.65, -4.5), 3.4, 0.55, "#1e3a5f", "#facc15")
	_add_walkable_bridge(Vector3(4.5, 2.55, 14.8), Vector3(14.8, 2.65, 4.5), 3.4, 0.55, "#1e3a5f", "#facc15")
	_add_walkable_bridge(Vector3(-4.5, 2.55, 14.8), Vector3(-14.8, 2.65, 4.5), 3.4, 0.55, "#1e3a5f", "#facc15")

	# 4 Ornate Golden Castle Columns guarding the central Tenshu courtyard
	for cp: Vector2 in [Vector2(-6.5, -6.5), Vector2(6.5, -6.5), Vector2(-6.5, 6.5), Vector2(6.5, 6.5)]:
		_add_tactical_pillar(Vector3(cp.x, get_base_terrain_height(cp.x, cp.y), cp.y), 0.72, 4.8, "#1e293b", "#facc15")

	# 6 Glowing Cloud Jump Pads (4 Courtyard + 2 Mid-Tier launching up to Sovereign +4.25m Moon-Decks!)
	var pad_mat := StandardMaterial3D.new()
	pad_mat.albedo_color = Color(0.38, 0.90, 1.0, 0.92)
	pad_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pad_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var gold_rim_mat := StandardMaterial3D.new()
	gold_rim_mat.albedo_color = Color.html("#facc15")
	gold_rim_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	var pad_coords := [
		Vector3(9.2, 0.0, -9.2), Vector3(-9.2, 0.0, -9.2),
		Vector3(9.2, 0.0, 9.2), Vector3(-9.2, 0.0, 9.2),
		Vector3(16.2, 2.65, -3.0), Vector3(-16.2, 2.65, -3.0),
	]
	for jp: Vector3 in pad_coords:
		var jy: float = jp.y if jp.y > 0.5 else get_base_terrain_height(jp.x, jp.z)
		var jn := Node3D.new()
		jn.position = Vector3(jp.x, jy, jp.z)
		jn.add_child(_make_flat_ring(1.3, 2.25, pad_mat, 0.14))
		jn.add_child(_make_flat_ring(0.5, 0.95, gold_rim_mat, 0.24))
		_arena_content.add_child(jn)
		jump_pads.append({"pos": Vector3(jp.x, jy, jp.z), "radius": 2.6, "node": jn})

	# Soft Floating Cloud Banks beneath the castle horizon
	var cloud_mat := StandardMaterial3D.new()
	cloud_mat.albedo_color = Color(0.75, 0.88, 1.0, 0.28)
	cloud_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cloud_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for ci in range(8):
		var a := (float(ci) / 8.0) * TAU
		var cm := SphereMesh.new()
		cm.radius = 5.5; cm.height = 2.6; cm.radial_segments = 14; cm.rings = 6
		var c_inst := MeshInstance3D.new()
		c_inst.mesh = cm; c_inst.material_override = cloud_mat
		c_inst.position = Vector3(cos(a) * 34.0, -1.5 + sin(float(ci)) * 1.5, sin(a) * 34.0)
		_arena_content.add_child(c_inst)

	# Giant Luminous Full Moon perched high beyond the North Torii
	var moon := MeshInstance3D.new()
	var ms := SphereMesh.new(); ms.radius = 7.2; ms.height = 14.4
	var mm := StandardMaterial3D.new()
	mm.albedo_color = Color.html("#fef9c3"); mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	moon.mesh = ms; moon.material_override = mm
	moon.position = Vector3(0.0, 20.5, -45.0)
	_arena_content.add_child(moon)


# ==============================================================================
#  SHARED ARCHITECTURAL PROP, BRIDGE, DECK & OBSTACLE HELPERS
# ==============================================================================
func _add_water_plane(y_level: float, rad: float, color_hex: String, alpha: float) -> void:
	var wm := CylinderMesh.new()
	wm.top_radius = rad; wm.bottom_radius = rad; wm.height = 0.08; wm.radial_segments = 48
	_water_plane_mat = StandardMaterial3D.new()
	var wc := Color.html(color_hex)
	_water_plane_mat.albedo_color = Color(wc.r, wc.g, wc.b, alpha)
	_water_plane_mat.roughness = 0.15
	_water_plane_mat.metallic = 0.45
	_water_plane_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var wi := MeshInstance3D.new()
	wi.mesh = wm; wi.material_override = _water_plane_mat
	wi.position = Vector3(0.0, y_level, 0.0)
	_arena_content.add_child(wi)


func _add_walkable_deck(top_pos: Vector3, rad: float, deck_hex: String, rim_hex: String) -> void:
	platforms.append({"pos": top_pos, "radius": rad})

	var deck_mat := StandardMaterial3D.new()
	deck_mat.albedo_color = Color.html(deck_hex); deck_mat.roughness = 0.48; deck_mat.metallic = 0.25
	var rim_mat := StandardMaterial3D.new()
	rim_mat.albedo_color = Color.html(rim_hex); rim_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	var cyl := CylinderMesh.new()
	cyl.top_radius = rad; cyl.bottom_radius = rad * 0.76; cyl.height = 0.92; cyl.radial_segments = 24
	var deck := MeshInstance3D.new()
	deck.mesh = cyl; deck.material_override = deck_mat
	deck.position = Vector3(top_pos.x, top_pos.y - 0.46, top_pos.z)
	_arena_content.add_child(deck)

	var rim := _make_flat_ring(rad - 0.32, rad + 0.06, rim_mat, top_pos.y + 0.04)
	rim.position.x = top_pos.x; rim.position.z = top_pos.z
	_arena_content.add_child(rim)


func _add_walkable_bridge(start_p: Vector3, end_p: Vector3, width: float, arch: float, deck_hex: String, rail_hex: String) -> void:
	bridges.append({"start": start_p, "end": end_p, "width": width, "arch": arch})

	var deck_mat := StandardMaterial3D.new()
	deck_mat.albedo_color = Color.html(deck_hex); deck_mat.roughness = 0.65
	var rail_mat := StandardMaterial3D.new()
	rail_mat.albedo_color = Color.html(rail_hex); rail_mat.roughness = 0.42

	var dir3 := end_p - start_p
	var flat_dir := Vector2(dir3.x, dir3.z)
	var total_len := flat_dir.length()
	var yaw := atan2(dir3.x, dir3.z)
	var right_v := Vector3(cos(yaw), 0.0, -sin(yaw))

	var segs := 8
	var seg_len := (total_len / float(segs)) * 1.08
	for i in range(segs):
		var t0 := float(i) / float(segs)
		var t1 := float(i + 1) / float(segs)
		var tm := (t0 + t1) * 0.5
		var p0 := start_p.lerp(end_p, t0) + Vector3(0.0, sin(t0 * PI) * arch, 0.0)
		var p1 := start_p.lerp(end_p, t1) + Vector3(0.0, sin(t1 * PI) * arch, 0.0)
		var pm := (p0 + p1) * 0.5
		var pitch := -atan2(p1.y - p0.y, Vector2(p1.x - p0.x, p1.z - p0.z).length())

		var plank := MeshInstance3D.new()
		var bm := BoxMesh.new(); bm.size = Vector3(width, 0.24, seg_len)
		plank.mesh = bm; plank.material_override = deck_mat
		plank.position = pm - Vector3(0.0, 0.12, 0.0)
		plank.rotation = Vector3(pitch, yaw, 0.0)
		_arena_content.add_child(plank)

		# Side railings + posts every 2 segments
		for side in [-1.0, 1.0]:
			var rail := MeshInstance3D.new()
			var rm := BoxMesh.new(); rm.size = Vector3(0.16, 0.18, seg_len)
			rail.mesh = rm; rail.material_override = rail_mat
			rail.position = pm + right_v * (side * (width * 0.48)) + Vector3(0.0, 0.72, 0.0)
			rail.rotation = Vector3(pitch, yaw, 0.0)
			_arena_content.add_child(rail)
			if i % 2 == 0:
				var post := MeshInstance3D.new()
				var pmsh := BoxMesh.new(); pmsh.size = Vector3(0.22, 0.92, 0.22)
				post.mesh = pmsh; post.material_override = rail_mat
				post.position = pm + right_v * (side * (width * 0.48)) + Vector3(0.0, 0.42, 0.0)
				_arena_content.add_child(post)


func _add_tactical_pillar(base_pos: Vector3, rad: float, height: float, stone_hex: String, trim_hex: String) -> void:
	obstacles.append({"pos": Vector2(base_pos.x, base_pos.z), "radius": rad + 0.15, "top_y": base_pos.y + height})

	var smat := StandardMaterial3D.new()
	smat.albedo_color = Color.html(stone_hex); smat.roughness = 0.65; smat.metallic = 0.22
	var tmat := StandardMaterial3D.new()
	tmat.albedo_color = Color.html(trim_hex); tmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	var col := MeshInstance3D.new()
	var cm := CylinderMesh.new(); cm.top_radius = rad * 0.85; cm.bottom_radius = rad; cm.height = height; cm.radial_segments = 8
	col.mesh = cm; col.material_override = smat
	col.position = base_pos + Vector3(0.0, height * 0.5, 0.0)
	_arena_content.add_child(col)

	var ring := _make_flat_ring(rad * 0.82, rad * 1.12, tmat, base_pos.y + height - 0.35)
	ring.position.x = base_pos.x; ring.position.z = base_pos.z
	_arena_content.add_child(ring)


func _add_mossy_boulder(base_pos: Vector3, rad: float) -> void:
	obstacles.append({"pos": Vector2(base_pos.x, base_pos.z), "radius": rad, "top_y": base_pos.y + rad * 1.25})
	var rmat := StandardMaterial3D.new()
	rmat.albedo_color = Color.html("#4b5548"); rmat.roughness = 0.88
	var b := MeshInstance3D.new()
	var sm := SphereMesh.new(); sm.radius = rad; sm.height = rad * 1.65; sm.radial_segments = 10; sm.rings = 6
	b.mesh = sm; b.material_override = rmat
	b.position = base_pos + Vector3(0.0, rad * 0.55, 0.0)
	_arena_content.add_child(b)


func _add_shrine_pavilion(base_pos: Vector3, pillar_hex: String, roof_hex: String, sc: float = 1.0) -> void:
	var pav := Node3D.new()
	pav.position = base_pos
	pav.scale = Vector3(sc, sc, sc)
	var pmat := StandardMaterial3D.new(); pmat.albedo_color = Color.html(pillar_hex); pmat.roughness = 0.45
	var rmat := StandardMaterial3D.new(); rmat.albedo_color = Color.html(roof_hex); rmat.roughness = 0.55

	var pm := CylinderMesh.new(); pm.top_radius = 0.22; pm.bottom_radius = 0.25; pm.height = 4.6
	for ox in [-2.6, 2.6]:
		for oz in [-2.6, 2.6]:
			var p := MeshInstance3D.new()
			p.mesh = pm; p.material_override = pmat
			p.position = Vector3(ox, 2.3, oz)
			pav.add_child(p)
			obstacles.append({"pos": Vector2(base_pos.x + ox * sc, base_pos.z + oz * sc), "radius": 0.40 * sc, "top_y": base_pos.y + 4.6 * sc})

	var roof := MeshInstance3D.new()
	var rm := CylinderMesh.new(); rm.top_radius = 0.2; rm.bottom_radius = 4.9; rm.height = 2.1; rm.radial_segments = 4
	roof.mesh = rm; roof.material_override = rmat
	roof.position = Vector3(0.0, 5.4, 0.0); roof.rotation.y = PI * 0.25
	pav.add_child(roof)
	_arena_content.add_child(pav)


func _add_temple_pagoda(base_pos: Vector3) -> void:
	obstacles.append({"pos": Vector2(base_pos.x, base_pos.z), "radius": 1.65, "top_y": base_pos.y + 8.5})
	var pag := Node3D.new()
	pag.position = base_pos
	var body_m := StandardMaterial3D.new(); body_m.albedo_color = Color.html("#7c2d12"); body_m.roughness = 0.55
	var roof_m := StandardMaterial3D.new(); roof_m.albedo_color = Color.html("#1e293b"); roof_m.roughness = 0.48
	var gold_m := StandardMaterial3D.new(); gold_m.albedo_color = Color.html("#fbbf24"); gold_m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	for tier in range(3):
		var sc := 1.0 - float(tier) * 0.22
		var ty := float(tier) * 2.4
		var b := MeshInstance3D.new()
		var bm := BoxMesh.new(); bm.size = Vector3(2.4 * sc, 2.0, 2.4 * sc)
		b.mesh = bm; b.material_override = body_m; b.position = Vector3(0.0, ty + 1.0, 0.0)
		pag.add_child(b)

		var r := MeshInstance3D.new()
		var rm := CylinderMesh.new(); rm.top_radius = 0.4 * sc; rm.bottom_radius = 3.2 * sc; rm.height = 1.1; rm.radial_segments = 4
		r.mesh = rm; r.material_override = roof_m; r.position = Vector3(0.0, ty + 2.25, 0.0); r.rotation.y = PI * 0.25
		pag.add_child(r)

	var spire := MeshInstance3D.new()
	var sm := CylinderMesh.new(); sm.top_radius = 0.05; sm.bottom_radius = 0.16; sm.height = 2.6
	spire.mesh = sm; spire.material_override = gold_m; spire.position = Vector3(0.0, 8.3, 0.0)
	pag.add_child(spire)
	_arena_content.add_child(pag)


func _add_torii_gate(base_pos: Vector3, pillar_hex: String, sc: float = 1.0) -> void:
	var torii := Node3D.new()
	torii.position = base_pos
	torii.scale = Vector3(sc, sc, sc)

	var pillar_mat := StandardMaterial3D.new()
	pillar_mat.albedo_color = Color.html(pillar_hex); pillar_mat.roughness = 0.40
	var cap_mat := StandardMaterial3D.new()
	cap_mat.albedo_color = Color.html("#0f172a"); cap_mat.roughness = 0.50

	var pillar_mesh := CylinderMesh.new()
	pillar_mesh.top_radius = 0.35; pillar_mesh.bottom_radius = 0.42; pillar_mesh.height = 7.2; pillar_mesh.radial_segments = 16
	for px in [-3.2, 3.2]:
		var p := MeshInstance3D.new()
		p.mesh = pillar_mesh; p.material_override = pillar_mat; p.position = Vector3(px, 3.6, 0.0)
		torii.add_child(p)

	var kasagi := MeshInstance3D.new()
	var km := BoxMesh.new(); km.size = Vector3(8.8, 0.55, 0.8)
	kasagi.mesh = km; kasagi.material_override = cap_mat; kasagi.position = Vector3(0.0, 7.3, 0.0)
	torii.add_child(kasagi)

	var nuki := MeshInstance3D.new()
	var nm := BoxMesh.new(); nm.size = Vector3(7.6, 0.40, 0.50)
	nuki.mesh = nm; nuki.material_override = pillar_mat; nuki.position = Vector3(0.0, 5.7, 0.0)
	torii.add_child(nuki)
	_arena_content.add_child(torii)


func _add_stone_lantern(base_pos: Vector3, glow_hex: String) -> void:
	var lg := Node3D.new()
	lg.position = base_pos

	var stone_mat := StandardMaterial3D.new(); stone_mat.albedo_color = Color.html("#64748b"); stone_mat.roughness = 0.8
	var roof_mat := StandardMaterial3D.new(); roof_mat.albedo_color = Color.html("#475569"); roof_mat.roughness = 0.7
	var glow_mat := StandardMaterial3D.new(); glow_mat.albedo_color = Color.html(glow_hex); glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	var b := MeshInstance3D.new()
	var bm := BoxMesh.new(); bm.size = Vector3(1.1, 2.2, 1.1)
	b.mesh = bm; b.material_override = stone_mat; b.position = Vector3(0.0, 1.1, 0.0)
	lg.add_child(b)

	var g := MeshInstance3D.new()
	var gm := BoxMesh.new(); gm.size = Vector3(0.75, 0.75, 0.75)
	g.mesh = gm; g.material_override = glow_mat; g.position = Vector3(0.0, 2.55, 0.0)
	lg.add_child(g)

	var r := MeshInstance3D.new()
	var rm := CylinderMesh.new(); rm.top_radius = 0.0; rm.bottom_radius = 1.15; rm.height = 0.9; rm.radial_segments = 4
	r.mesh = rm; r.material_override = roof_mat; r.position = Vector3(0.0, 3.35, 0.0); r.rotation.y = PI * 0.25
	lg.add_child(r)
	_arena_content.add_child(lg)


func _add_stylized_tree(base_pos: Vector3, trunk_hex: String, leaf_hex: String, sc: float = 1.0) -> void:
	var tree := Node3D.new()
	tree.position = base_pos
	tree.scale = Vector3(sc, sc, sc)

	var trunk_m := StandardMaterial3D.new(); trunk_m.albedo_color = Color.html(trunk_hex); trunk_m.roughness = 0.85
	var leaf_m := StandardMaterial3D.new(); leaf_m.albedo_color = Color.html(leaf_hex); leaf_m.roughness = 0.55

	var trunk := MeshInstance3D.new()
	var tc := CylinderMesh.new(); tc.top_radius = 0.24; tc.bottom_radius = 0.42; tc.height = 4.2; tc.radial_segments = 10
	trunk.mesh = tc; trunk.material_override = trunk_m; trunk.position = Vector3(0.0, 2.0, 0.0)
	tree.add_child(trunk)

	for cp: Array in [[Vector3(0.0, 4.6, 0.0), 2.1], [Vector3(1.2, 4.1, 0.7), 1.45], [Vector3(-1.1, 4.2, -0.6), 1.55]]:
		var fol := MeshInstance3D.new()
		var sp := SphereMesh.new()
		var r: float = float(cp[1])
		sp.radius = r; sp.height = r * 1.45; sp.radial_segments = 14; sp.rings = 8
		fol.mesh = sp; fol.material_override = leaf_m; fol.position = cp[0]
		tree.add_child(fol)

	_arena_content.add_child(tree)


func _build_ambient_particles(particle_col: Color) -> void:
	_particles = CPUParticles3D.new()
	_particles.amount = 140
	_particles.lifetime = 8.0
	_particles.preprocess = 4.0
	_particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_particles.emission_box_extents = Vector3(30.0, 1.0, 30.0)
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
	torus.inner_radius = inner_r; torus.outer_radius = outer_r; torus.rings = 40; torus.ring_segments = 8
	var inst := MeshInstance3D.new()
	inst.mesh = torus; inst.material_override = mat
	inst.position = Vector3(0.0, y_pos, 0.0)
	inst.scale = Vector3(1.0, 0.08, 1.0)
	return inst


func _process(delta: float) -> void:
	_elapsed += delta
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
	if _lava_plane_mat != null:
		_lava_plane_mat.emission_energy_multiplier = 1.45 + sin(_elapsed * 3.2) * 0.30
