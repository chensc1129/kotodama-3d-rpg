class_name Arena3D
extends Node3D
## Procedurally builds 4 distinct enlarged 3D Japanese arenas with smooth heightfield terrain,
## walkable elevated platforms/terraces, thematic landmarks, and animated stage-specific mechanics:
## 1. sakura_shrine  : 3-tier Shrine Terraces + rotating Sakura Spirit Sanctuary (heal/SP/ATK buff)
## 2. maple_temple   : Rolling Bamboo Hills + 3 swirling Wind Draft Pillars (speed/sprint/jump buff)
## 3. onigashima_lava: Obsidian Plateaus & Glowing Lava Trenches + Periodic Volcanic Geysers
## 4. sky_tenshu     : Floating Golden Sky Platforms + 4 Cloud Jump Pads + Full-Moon Thunder Strikes

@export var world_environment: WorldEnvironment
@export var center_light: OmniLight3D

var current_stage_id: String = "sakura_shrine"

# Walkable elevated platforms (e.g. Sky Tenshu floating decks)
# Each dict: {pos: Vector3 (center XZ, y=top), radius: float}
var platforms: Array[Dictionary] = []

# Stage-specific mechanic zones queried by BattleManager
var sakura_zone_pos: Vector3 = Vector3.ZERO
var sakura_zone_radius: float = 4.8
var wind_zones: Array[Dictionary] = []       # {pos: Vector3, radius: float, node: Node3D}
var jump_pads: Array[Dictionary] = []        # {pos: Vector3, radius: float, node: Node3D}

var _arena_content: Node3D
var _particles: CPUParticles3D
var _sakura_zone_node: Node3D
var _lava_plane_mat: StandardMaterial3D
var _elapsed: float = 0.0
var _sakura_spots: Array[Vector2] = [
	Vector2(0.0, -17.5),
	Vector2(17.5, 2.0),
	Vector2(-17.5, 2.0),
	Vector2(0.0, 2.0),
]
var _sakura_spot_idx: int = 0


func _ready() -> void:
	_arena_content = Node3D.new()
	_arena_content.name = "ArenaContent"
	add_child(_arena_content)


# ==============================================================================
#  EXACT ANALYTICAL TERRAIN HEIGHT + ELEVATED PLATFORM QUERIES
# ==============================================================================
func get_base_terrain_height(x: float, z: float) -> float:
	var r := sqrt(x * x + z * z)
	var radius := GameData.ARENA_RADIUS

	match current_stage_id:
		"sakura_shrine":
			# 3-Tiered Shrine Courtyard:
			# - North Elevated Torii Altar (+2.45m) with wide stepped ramp
			var north_t := clampf((-z - 7.5) / 8.0, 0.0, 1.0)
			north_t = north_t * north_t * (3.0 - 2.0 * north_t)
			var x_mask := clampf(1.0 - maxf(0.0, absf(x) - 10.0) / 6.5, 0.0, 1.0)
			var north_altar := 2.45 * north_t * x_mask

			# - Twin East/West Crescent Shrine Balconies (+1.45m)
			var wing_x := clampf((absf(x) - 11.5) / 5.5, 0.0, 1.0)
			wing_x = wing_x * wing_x * (3.0 - 2.0 * wing_x)
			var wing_z := clampf(1.0 - maxf(0.0, absf(z - 3.5) - 7.5) / 5.5, 0.0, 1.0)
			var wing_balcony := 1.45 * wing_x * wing_z

			# - Subtle South Entrance Step (+0.65m)
			var south_t := clampf((z - 15.0) / 6.0, 0.0, 1.0)
			var south_step := 0.70 * south_t * south_t * (3.0 - 2.0 * south_t)
			return maxf(maxf(north_altar, wing_balcony), south_step)

		"maple_temple":
			# Rolling Autumn Bamboo Hills & Central Pagoda Mound:
			var center_mound := 1.65 * exp(-((r * r) / 58.0))
			var valley_dip := -0.55 * exp(-(((r - 12.0) * (r - 12.0)) / 18.0))
			var ang := atan2(z, x)
			var outer_t := clampf((r - 13.5) / 10.0, 0.0, 1.0)
			outer_t = outer_t * outer_t * (3.0 - 2.0 * outer_t)
			var hills := (1.55 + 0.95 * sin(ang * 3.0 + 0.4) + 0.45 * cos(ang * 5.0 - 0.8)) * outer_t
			return center_mound + valley_dip + hills

		"onigashima_lava":
			# Volcanic Caldera: Sunken Magma Trenches (-0.85m) + Central Mound (+0.85m) + 4 Obsidian Plateaus (+2.25m)
			var h := -0.85
			# Central volcanic battle hub
			var center_t := clampf(1.0 - maxf(0.0, r - 4.8) / 4.2, 0.0, 1.0)
			center_t = center_t * center_t * (3.0 - 2.0 * center_t)
			h = maxf(h, lerpf(-0.85, 0.85, center_t))

			# 4 Raised Obsidian Basalt Plateaus in NE, NW, SE, SW quadrants
			var islands := [
				Vector2(13.5, -13.0),
				Vector2(-13.5, -13.0),
				Vector2(13.5, 13.0),
				Vector2(-13.5, 13.0),
			]
			for isl: Vector2 in islands:
				var d := Vector2(x, z).distance_to(isl)
				var it := clampf(1.0 - maxf(0.0, d - 4.8) / 4.6, 0.0, 1.0)
				it = it * it * (3.0 - 2.0 * it)
				h = maxf(h, lerpf(-0.85, 2.25, it))

			# 4 Diagonal Volcanic Stone Causeways connecting center to plateaus (safe from lava!)
			var diag_d1 := absf(x - z) * 0.7071
			var diag_d2 := absf(x + z) * 0.7071
			var bridge_d := minf(diag_d1, diag_d2)
			if r > 3.5 and r < 22.0:
				var bt := clampf(1.0 - maxf(0.0, bridge_d - 1.7) / 1.8, 0.0, 1.0)
				bt = bt * bt * (3.0 - 2.0 * bt)
				h = maxf(h, lerpf(-0.85, 0.72, bt))

			# Outer volcanic rim ridge
			var rim_t := clampf((r - (radius - 4.2)) / 3.8, 0.0, 1.0)
			h = maxf(h, lerpf(-0.85, 1.2, rim_t * rim_t))
			return h

		"sky_tenshu":
			# Golden Sky-Castle Courtyard (+0.0m center, stepped golden outer rim +0.75m,
			# plus sloped spirit-ramps climbing North/South up toward floating sky decks!)
			var rim_t := clampf((r - 19.0) / 5.5, 0.0, 1.0)
			var h := 0.75 * rim_t * rim_t * (3.0 - 2.0 * rim_t)
			# Gentle north/south ceremonial spirit-ramps climbing to +2.4m platforms
			if absf(x) < 3.6 and absf(z) > 6.5 and absf(z) < 16.5:
				var ramp_t := clampf((absf(z) - 6.5) / 8.0, 0.0, 1.0)
				var x_fade := clampf(1.0 - maxf(0.0, absf(x) - 2.2) / 1.4, 0.0, 1.0)
				h = maxf(h, 2.45 * ramp_t * x_fade)
			return h

	return 0.0


func get_ground_height(x: float, z: float, entity_y: float = 99.0) -> float:
	var h := get_base_terrain_height(x, z)
	for plat in platforms:
		var p: Vector3 = plat["pos"]
		var rad: float = float(plat["radius"])
		var dx := x - p.x
		var dz := z - p.z
		if (dx * dx + dz * dz) <= rad * rad:
			if p.y <= entity_y + 0.70:
				h = maxf(h, p.y)
	return h


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
	wind_zones.clear()
	jump_pads.clear()
	_sakura_zone_node = null
	_lava_plane_mat = null
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
		env.ambient_light_energy = 0.82
		env.fog_enabled = true
		env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
		env.fog_light_color = fog_col
		env.fog_density = 0.011

	if center_light != null:
		center_light.light_color = ring_col
		center_light.light_energy = 1.8
		center_light.omni_range = 68.0

	# 1. Sculpted Heightfield Terrain Mesh with Elevation Vertex Colors!
	_build_heightfield_terrain(floor_col, ring_col)

	# 2. Glowing Outer Boundary Ring conforming to edge terrain
	_build_boundary_ring(ring_col)

	# 3. Stage-Specific Architecture, Platforms, Landmarks & Mechanic Zones!
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
	match current_stage_id:
		"sakura_shrine":
			if h > 1.8:
				return Color.html("#4a3958") # Warm moonlight altar stone
			elif h > 0.7:
				return Color.html("#3c2e4a") # Elevated balcony granite
			var r := sqrt(x * x + z * z)
			if r < 6.0:
				return Color.html("#372845")
			return base_col
		"maple_temple":
			if h < -0.15:
				return Color.html("#21382a") # Lush mossy bamboo valley
			elif h > 1.35:
				return Color.html("#6e3b24") # Autumn maple hilltop soil
			return base_col.lerp(Color.html("#3f4c2f"), clampf((h + 0.2) * 0.35, 0.0, 0.6))
		"onigashima_lava":
			if h < -0.42:
				return Color.html("#ea580c") # Glowing molten magma trench!
			elif h < 0.15:
				return Color.html("#451a14") # Charred volcanic slope
			elif h > 1.55:
				return Color.html("#2b2528") # High obsidian basalt crown
			return Color.html("#221d1f")
		"sky_tenshu":
			if h > 1.0:
				return Color.html("#4b5563").lerp(Color.html("#fef08a"), 0.22) # Golden spirit bridge
			elif h > 0.35:
				return Color.html("#2d3e5e") # Outer castle stone rim
			return Color.html("#1b2b48")
	return base_col


func _build_heightfield_terrain(floor_col: Color, _ring_col: Color) -> void:
	var radius := GameData.ARENA_RADIUS
	var rings := 26
	var segs := 56

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
			var eps := 0.35
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

			# Tri 1 (CCW upward normal: v00 -> v10 -> v11)
			st.set_color(v00[2]); st.set_normal(v00[1]); st.add_vertex(v00[0])
			st.set_color(v11[2]); st.set_normal(v11[1]); st.add_vertex(v11[0])
			st.set_color(v10[2]); st.set_normal(v10[1]); st.add_vertex(v10[0])

			# Tri 2 (v00 -> v01 -> v11)
			st.set_color(v00[2]); st.set_normal(v00[1]); st.add_vertex(v00[0])
			st.set_color(v01[2]); st.set_normal(v01[1]); st.add_vertex(v01[0])
			st.set_color(v11[2]); st.set_normal(v11[1]); st.add_vertex(v11[0])

	# Outer rocky/stone cliff skirt so arena feels solid from all angles
	var skirt_col := floor_col.darkened(0.45)
	for si in range(segs):
		var sn := (si + 1) % segs
		var top0: Vector3 = grid[rings][si][0]
		var top1: Vector3 = grid[rings][sn][0]
		var bot0 := Vector3(top0.x * 1.04, top0.y - 4.2, top0.z * 1.04)
		var bot1 := Vector3(top1.x * 1.04, top1.y - 4.2, top1.z * 1.04)
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
	mat.roughness = 0.78
	mat.metallic = 0.12

	var terrain_inst := MeshInstance3D.new()
	terrain_inst.name = "TerrainMesh"
	terrain_inst.mesh = mesh
	terrain_inst.material_override = mat
	_arena_content.add_child(terrain_inst)


func _build_boundary_ring(ring_col: Color) -> void:
	var radius := GameData.ARENA_RADIUS - 0.35
	var segs := 64
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
		var p0i := Vector3(x0_i, y0, z0_i)
		var p0o := Vector3(x0_o, y0, z0_o)
		var p1i := Vector3(x1_i, y1, z1_i)
		var p1o := Vector3(x1_o, y1, z1_o)
		st.set_normal(Vector3.UP); st.add_vertex(p0i)
		st.set_normal(Vector3.UP); st.add_vertex(p1o)
		st.set_normal(Vector3.UP); st.add_vertex(p0o)
		st.set_normal(Vector3.UP); st.add_vertex(p0i)
		st.set_normal(Vector3.UP); st.add_vertex(p1i)
		st.set_normal(Vector3.UP); st.add_vertex(p1o)

	var mat := StandardMaterial3D.new()
	mat.albedo_color = ring_col
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var inst := MeshInstance3D.new()
	inst.mesh = st.commit()
	inst.material_override = mat
	_arena_content.add_child(inst)


# ==============================================================================
#  STAGE 1: SAKURA SHRINE (Terraced Torii Altar + Sakura Spirit Blessing Circle)
# ==============================================================================
func _build_sakura_shrine_props(_ring_col: Color) -> void:
	# Grand Vermilion Torii perched atop North Altar Terrace
	_add_torii_gate(Vector3(0.0, get_base_terrain_height(0.0, -23.0), -23.0), "#dc2626", 1.25)

	# Decorative stone stairs accent on North ramp
	var step_mat := StandardMaterial3D.new()
	step_mat.albedo_color = Color.html("#6b5b7b")
	step_mat.roughness = 0.82
	for i in range(6):
		var z := -8.8 - float(i) * 1.15
		var y := get_base_terrain_height(0.0, z)
		var step := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(7.4, 0.28, 1.1)
		step.mesh = bm
		step.material_override = step_mat
		step.position = Vector3(0.0, y - 0.08, z)
		_arena_content.add_child(step)

	# 4 Lush Night Sakura Trees framing East/West terraces
	for tp: Vector2 in [Vector2(-19.5, -12.0), Vector2(19.5, -12.0), Vector2(-20.0, 12.5), Vector2(20.0, 12.5)]:
		_add_stylized_tree(Vector3(tp.x, get_base_terrain_height(tp.x, tp.y), tp.y), "#3b231e", "#f472b6", 1.35)

	# 6 Stone Lanterns at exact terrain elevation
	for ang in [0.4, 1.25, 2.0, 2.75, -0.5, -2.65]:
		var lx := cos(ang) * (GameData.ARENA_RADIUS - 2.4)
		var lz := sin(ang) * (GameData.ARENA_RADIUS - 2.4)
		_add_stone_lantern(Vector3(lx, get_base_terrain_height(lx, lz), lz), "#fde047")

	# Stage Mechanic Visual: Luminous Sakura Spirit Blessing Circle!
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

	var vortex := CPUParticles3D.new()
	vortex.amount = 28
	vortex.lifetime = 2.0
	vortex.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	vortex.emission_ring_radius = sakura_zone_radius * 0.85
	vortex.emission_ring_inner_radius = 1.0
	vortex.emission_ring_height = 0.2
	vortex.direction = Vector3(0.0, 1.0, 0.0)
	vortex.spread = 15.0
	vortex.gravity = Vector3.ZERO
	vortex.initial_velocity_min = 1.4
	vortex.initial_velocity_max = 2.6
	var pm := QuadMesh.new()
	pm.size = Vector2(0.28, 0.28)
	var pmat := StandardMaterial3D.new()
	pmat.albedo_color = Color.html("#fbcfe8")
	pmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pmat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	pm.material = pmat
	vortex.mesh = pm
	_sakura_zone_node.add_child(vortex)
	_arena_content.add_child(_sakura_zone_node)


# ==============================================================================
#  STAGE 2: MAPLE TEMPLE (Rolling Bamboo Hills + 3 Swirling Wind Draft Pillars)
# ==============================================================================
func _build_maple_temple_props(_ring_col: Color) -> void:
	_add_torii_gate(Vector3(0.0, get_base_terrain_height(0.0, -23.5), -23.5), "#ea580c", 1.15)

	# Perimeter Tall Bamboo Groves
	var bamboo_mat := StandardMaterial3D.new()
	bamboo_mat.albedo_color = Color.html("#15803d")
	bamboo_mat.roughness = 0.45
	var stalk_mesh := CylinderMesh.new()
	stalk_mesh.top_radius = 0.16
	stalk_mesh.bottom_radius = 0.22
	stalk_mesh.height = 9.5
	stalk_mesh.radial_segments = 10

	for i in range(18):
		var ang := (float(i) / 18.0) * TAU + 0.12
		if absf(ang - (-PI * 0.5)) < 0.35 or absf(ang - (PI * 1.5)) < 0.35:
			continue
		var dist := GameData.ARENA_RADIUS - 2.2 - (0.8 if i % 2 == 0 else 0.0)
		var bx := cos(ang) * dist
		var bz := sin(ang) * dist
		var by := get_base_terrain_height(bx, bz)
		for offset: Vector2 in [Vector2(0.0, 0.0), Vector2(0.7, 0.5), Vector2(-0.6, 0.7)]:
			var stalk := MeshInstance3D.new()
			stalk.mesh = stalk_mesh
			stalk.material_override = bamboo_mat
			stalk.position = Vector3(bx + offset.x, by + 4.5, bz + offset.y)
			stalk.rotation.z = sin(float(i) + offset.x) * 0.06
			_arena_content.add_child(stalk)

	# Crimson Maple Trees atop the outer rolling hills
	for mp: Vector2 in [Vector2(-18.0, -11.0), Vector2(18.5, -10.0), Vector2(-17.0, 15.0), Vector2(18.0, 14.0)]:
		_add_stylized_tree(Vector3(mp.x, get_base_terrain_height(mp.x, mp.y), mp.y), "#451a03", "#ea580c", 1.25)

	# Stage Mechanic Visual: 3 Swirling Emerald-Gold Wind Draft Pillars (疾風氣流)
	var wind_coords := [Vector2(-12.5, 4.0), Vector2(12.5, 4.0), Vector2(0.0, -12.5)]
	var wind_mat := StandardMaterial3D.new()
	wind_mat.albedo_color = Color(0.28, 0.94, 0.72, 0.75)
	wind_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	wind_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for wc: Vector2 in wind_coords:
		var wy := get_base_terrain_height(wc.x, wc.y)
		var wn := Node3D.new()
		wn.position = Vector3(wc.x, wy, wc.y)
		for ri in range(3):
			var wr := _make_flat_ring(1.6 + float(ri) * 0.65, 1.9 + float(ri) * 0.65, wind_mat, 0.35 + float(ri) * 1.15)
			wn.add_child(wr)
		_arena_content.add_child(wn)
		wind_zones.append({"pos": Vector3(wc.x, wy, wc.y), "radius": 3.8, "node": wn})


# ==============================================================================
#  STAGE 3: ONIGASHIMA LAVA (Obsidian Plateaus + Glowing Lava Sea + Spires)
# ==============================================================================
func _build_onigashima_lava_props(_ring_col: Color) -> void:
	_add_torii_gate(Vector3(0.0, get_base_terrain_height(0.0, -24.0), -24.0), "#991b1b", 1.3)

	# Glowing Molten Lava Surface Plane peeking through all sunken trenches (y = -0.58)
	var lava_mesh := CylinderMesh.new()
	lava_mesh.top_radius = GameData.ARENA_RADIUS - 0.5
	lava_mesh.bottom_radius = GameData.ARENA_RADIUS - 0.5
	lava_mesh.height = 0.1
	lava_mesh.radial_segments = 48
	_lava_plane_mat = StandardMaterial3D.new()
	_lava_plane_mat.albedo_color = Color.html("#f97316")
	_lava_plane_mat.emission_enabled = true
	_lava_plane_mat.emission = Color.html("#ea580c")
	_lava_plane_mat.emission_energy_multiplier = 1.65
	_lava_plane_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var lava_inst := MeshInstance3D.new()
	lava_inst.mesh = lava_mesh
	lava_inst.material_override = _lava_plane_mat
	lava_inst.position = Vector3(0.0, -0.58, 0.0)
	_arena_content.add_child(lava_inst)

	# Jagged Obsidian Crystal Spires crowning the 4 outer volcanic plateaus
	var obs_mat := StandardMaterial3D.new()
	obs_mat.albedo_color = Color.html("#1c1917")
	obs_mat.roughness = 0.35
	obs_mat.metallic = 0.45
	var spire_mesh := CylinderMesh.new()
	spire_mesh.top_radius = 0.08
	spire_mesh.bottom_radius = 1.15
	spire_mesh.height = 5.5
	spire_mesh.radial_segments = 5

	for sp: Vector2 in [Vector2(19.5, -18.5), Vector2(-19.5, -18.5), Vector2(19.5, 18.5), Vector2(-19.5, 18.5)]:
		var sy := get_base_terrain_height(sp.x, sp.y)
		var spire := MeshInstance3D.new()
		spire.mesh = spire_mesh
		spire.material_override = obs_mat
		spire.position = Vector3(sp.x, sy + 2.4, sp.y)
		spire.rotation.z = -signf(sp.x) * 0.16
		_arena_content.add_child(spire)

	# 4 Hellfire Braziers on the 4 Obsidian Plateaus
	for bp: Vector2 in [Vector2(13.5, -13.0), Vector2(-13.5, -13.0), Vector2(13.5, 13.0), Vector2(-13.5, 13.0)]:
		_add_stone_lantern(Vector3(bp.x, get_base_terrain_height(bp.x, bp.y), bp.y), "#f97316")


# ==============================================================================
#  STAGE 4: SKY TENSHU (Floating Golden Sky Platforms + 4 Cloud Jump Pads)
# ==============================================================================
func _build_sky_tenshu_props(_ring_col: Color) -> void:
	_add_torii_gate(Vector3(0.0, get_base_terrain_height(0.0, -24.5), -24.5), "#f59e0b", 1.3)

	# 4 Walkable Floating Jade-Gold Sky Platforms!
	var plat_specs := [
		[Vector3(0.0, 2.45, -16.2), 5.6],
		[Vector3(0.0, 2.45, 16.2), 5.4],
		[Vector3(16.2, 2.65, 0.0), 5.4],
		[Vector3(-16.2, 2.65, 0.0), 5.4],
	]
	var deck_mat := StandardMaterial3D.new()
	deck_mat.albedo_color = Color.html("#1e3a5f")
	deck_mat.roughness = 0.42
	deck_mat.metallic = 0.30
	var gold_rim_mat := StandardMaterial3D.new()
	gold_rim_mat.albedo_color = Color.html("#facc15")
	gold_rim_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	for spec in plat_specs:
		var p: Vector3 = spec[0]
		var rad: float = float(spec[1])
		platforms.append({"pos": p, "radius": rad})

		var cyl := CylinderMesh.new()
		cyl.top_radius = rad
		cyl.bottom_radius = rad * 0.72
		cyl.height = 0.9
		cyl.radial_segments = 24
		var deck := MeshInstance3D.new()
		deck.mesh = cyl
		deck.material_override = deck_mat
		deck.position = Vector3(p.x, p.y - 0.45, p.z)
		_arena_content.add_child(deck)

		var rim := _make_flat_ring(rad - 0.35, rad + 0.05, gold_rim_mat, p.y + 0.04)
		rim.position.x = p.x
		rim.position.z = p.z
		_arena_content.add_child(rim)

	# 4 Glowing Cloud Jump Pads (騰雲陣) launching hero up onto floating sky platforms!
	var pad_mat := StandardMaterial3D.new()
	pad_mat.albedo_color = Color(0.38, 0.90, 1.0, 0.90)
	pad_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pad_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for jp: Vector2 in [Vector2(8.8, -8.8), Vector2(-8.8, -8.8), Vector2(8.8, 8.8), Vector2(-8.8, 8.8)]:
		var jy := get_base_terrain_height(jp.x, jp.y)
		var jn := Node3D.new()
		jn.position = Vector3(jp.x, jy, jp.y)
		jn.add_child(_make_flat_ring(1.3, 2.25, pad_mat, 0.14))
		jn.add_child(_make_flat_ring(0.5, 0.95, gold_rim_mat, 0.24))
		_arena_content.add_child(jn)
		jump_pads.append({"pos": Vector3(jp.x, jy, jp.y), "radius": 2.6, "node": jn})

	# Giant Luminous Full Moon perched high beyond the North Torii!
	var moon := MeshInstance3D.new()
	var ms := SphereMesh.new()
	ms.radius = 6.5
	ms.height = 13.0
	var mm := StandardMaterial3D.new()
	mm.albedo_color = Color.html("#fef9c3")
	mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	moon.mesh = ms
	moon.material_override = mm
	moon.position = Vector3(0.0, 19.0, -44.0)
	_arena_content.add_child(moon)


# ==============================================================================
#  SHARED ARCHITECTURAL PROP HELPERS
# ==============================================================================
func _add_torii_gate(base_pos: Vector3, pillar_hex: String, sc: float = 1.0) -> void:
	var torii := Node3D.new()
	torii.position = base_pos
	torii.scale = Vector3(sc, sc, sc)

	var pillar_mat := StandardMaterial3D.new()
	pillar_mat.albedo_color = Color.html(pillar_hex)
	pillar_mat.roughness = 0.40
	var cap_mat := StandardMaterial3D.new()
	cap_mat.albedo_color = Color.html("#0f172a")
	cap_mat.roughness = 0.50

	var pillar_mesh := CylinderMesh.new()
	pillar_mesh.top_radius = 0.35
	pillar_mesh.bottom_radius = 0.42
	pillar_mesh.height = 7.2
	pillar_mesh.radial_segments = 16
	for px in [-3.2, 3.2]:
		var p := MeshInstance3D.new()
		p.mesh = pillar_mesh
		p.material_override = pillar_mat
		p.position = Vector3(px, 3.6, 0.0)
		torii.add_child(p)

	var kasagi := MeshInstance3D.new()
	var km := BoxMesh.new()
	km.size = Vector3(8.8, 0.55, 0.8)
	kasagi.mesh = km
	kasagi.material_override = cap_mat
	kasagi.position = Vector3(0.0, 7.3, 0.0)
	torii.add_child(kasagi)

	var nuki := MeshInstance3D.new()
	var nm := BoxMesh.new()
	nm.size = Vector3(7.6, 0.40, 0.50)
	nuki.mesh = nm
	nuki.material_override = pillar_mat
	nuki.position = Vector3(0.0, 5.7, 0.0)
	torii.add_child(nuki)
	_arena_content.add_child(torii)


func _add_stone_lantern(base_pos: Vector3, glow_hex: String) -> void:
	var lg := Node3D.new()
	lg.position = base_pos

	var stone_mat := StandardMaterial3D.new()
	stone_mat.albedo_color = Color.html("#64748b")
	stone_mat.roughness = 0.8
	var roof_mat := StandardMaterial3D.new()
	roof_mat.albedo_color = Color.html("#475569")
	roof_mat.roughness = 0.7
	var glow_mat := StandardMaterial3D.new()
	glow_mat.albedo_color = Color.html(glow_hex)
	glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

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

	var trunk_m := StandardMaterial3D.new()
	trunk_m.albedo_color = Color.html(trunk_hex)
	trunk_m.roughness = 0.85
	var leaf_m := StandardMaterial3D.new()
	leaf_m.albedo_color = Color.html(leaf_hex)
	leaf_m.roughness = 0.55

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
	_particles.amount = 130
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

	var p_mesh := QuadMesh.new()
	p_mesh.size = Vector2(0.28, 0.28)
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
	torus.inner_radius = inner_r
	torus.outer_radius = outer_r
	torus.rings = 40
	torus.ring_segments = 8
	var inst := MeshInstance3D.new()
	inst.mesh = torus
	inst.material_override = mat
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
