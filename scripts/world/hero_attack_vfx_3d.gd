class_name HeroAttackVfx3D
extends Node3D
## Dedicated WebGL2 (GL Compatibility) safe 3D basic-attack VFX engine giving all 5 heroes
## unmistakably unique 3-hit combo attack visuals aligned with player facing direction.

var _life: float = 0.0
var _max_life: float = 0.42
var _parts: Array[Dictionary] = []


func setup(char_id: String, world_pos: Vector3, facing: float, step: int, reach: float = 4.5) -> void:
	position = world_pos
	rotation.y = facing
	_max_life = 0.56 if step == 3 else 0.36

	match char_id:
		"sakura":
			_build_sakura_attack(step, reach)
		"kickboxer":
			_build_kickboxer_attack(step, reach)
		"swordsman":
			_build_swordsman_attack(step, reach)
		"raijin":
			_build_raijin_attack(step, reach)
		"yukionna":
			_build_yukionna_attack(step, reach)
		_:
			_build_sakura_attack(step, reach)


func _make_mat(col: Color, alpha: float = 0.92) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(col.r, col.g, col.b, alpha)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


func _add_particles(amount: int, col: Color, box_sz: Vector3, origin: Vector3, dir: Vector3, spread: float, vmin: float, vmax: float, grav: Vector3, life: float) -> void:
	var is_mob := UiStyle.is_mobile_device()
	var p := CPUParticles3D.new()
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.position = origin
	p.emitting = false
	p.one_shot = true
	p.explosiveness = 0.92
	p.amount = maxi(4, int(round(float(amount) * (0.45 if is_mob else 1.0))))
	p.lifetime = life
	p.direction = dir
	p.spread = spread
	p.initial_velocity_min = vmin
	p.initial_velocity_max = vmax
	p.gravity = grav
	p.damping_min = 2.5
	p.damping_max = 5.0
	p.scale_amount_min = 0.65
	p.scale_amount_max = 1.35

	var bm := BoxMesh.new()
	bm.size = box_sz
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bm.material = mat
	p.mesh = bm
	p.particle_flag_align_y = true
	add_child(p)
	p.emitting = true


func _new_mesh_inst(mesh: Mesh, mat: Material) -> MeshInstance3D:
	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	inst.material_override = mat
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return inst


# 1. SAKURA: Swirling pink-gold cherry blossom petal fan & blooming petal tornado
func _build_sakura_attack(step: int, reach: float) -> void:
	var pink := Color.html("#f472b6")
	var gold := Color.html("#fef3c7")
	var petal_count := (9 if UiStyle.is_mobile_device() else 14) if step == 3 else 7
	var petal_m := BoxMesh.new()
	petal_m.size = Vector3(0.46, 0.05, 0.24) if step == 3 else Vector3(0.38, 0.05, 0.20)
	for i in range(petal_count):
		var frac := float(i) / float(maxi(1, petal_count - 1))
		var ang := (frac * TAU) if step == 3 else lerpf(-1.05, 1.05, frac)
		var mat := _make_mat(pink.lerp(gold, float(i % 2) * 0.45), 0.94)
		var inst := _new_mesh_inst(petal_m, mat)
		var start_r := 1.2
		inst.position = Vector3(sin(ang) * start_r, 1.25 + randf_range(-0.35, 0.45), cos(ang) * start_r)
		add_child(inst)
		_parts.append({
			"kind": "orbit_out",
			"node": inst,
			"mat": mat,
			"angle": ang,
			"r0": start_r,
			"r1": reach * (0.95 if step == 3 else 0.85),
			"spin": 9.0 if step != 2 else -9.0,
			"y0": inst.position.y,
			"y_rise": 1.35 if step == 3 else 0.35,
		})

	if step == 3:
		var ring_m := TorusMesh.new()
		ring_m.inner_radius = 0.65
		ring_m.outer_radius = 1.0
		ring_m.rings = 20
		ring_m.ring_segments = 6
		var rmat := _make_mat(pink.lerp(gold, 0.3), 0.88)
		var rinst := _new_mesh_inst(ring_m, rmat)
		rinst.position = Vector3(0.0, 1.15, 0.0)
		rinst.scale = Vector3(1.0, 0.14, 1.0)
		add_child(rinst)
		_parts.append({"kind": "expand_ring", "node": rinst, "mat": rmat, "max_s": reach * 0.95, "spin": 7.0})

	_add_particles(22 if step == 3 else 11, pink.lerp(Color.WHITE, 0.35), Vector3(0.18, 0.05, 0.12), Vector3(0.0, 1.2, 1.1), Vector3(0.0, 0.35, 1.0), 75.0 if step != 3 else 160.0, 4.5, 10.0, Vector3(0.0, -2.5, 0.0), 0.48)


# 2. KICKBOXER: High-impact azure sonic-boom cone & compressed air shock rings
func _build_kickboxer_attack(step: int, reach: float) -> void:
	var cyan := Color.html("#38bdf8")
	var white := Color.html("#e0f2fe")

	if step < 3:
		# Forward-blasting hollow air shock-cone + 2 concentric sonic boom rings
		var cone_m := CylinderMesh.new()
		cone_m.top_radius = 0.25
		cone_m.bottom_radius = 1.55
		cone_m.height = 2.4
		cone_m.radial_segments = 14
		cone_m.rings = 1
		var cmat := _make_mat(cyan, 0.62)
		var cone := _new_mesh_inst(cone_m, cmat)
		cone.position = Vector3(0.0, 1.15, 1.4)
		cone.rotation = Vector3(-PI * 0.5, 0.0, 0.0)
		add_child(cone)
		_parts.append({"kind": "surge_forward", "node": cone, "mat": cmat, "z0": 1.1, "z1": reach * 0.82, "s0": 0.65, "s1": 1.45, "max_a": 0.62})

		var tm := TorusMesh.new()
		tm.inner_radius = 0.55
		tm.outer_radius = 0.80
		tm.rings = 18
		tm.ring_segments = 6
		for r_i in range(2):
			var tmat := _make_mat(white if r_i == 0 else cyan, 0.92)
			var ti := _new_mesh_inst(tm, tmat)
			ti.position = Vector3(0.0, 1.15, 1.2 + float(r_i) * 0.7)
			ti.rotation = Vector3(PI * 0.5, 0.0, 0.0)
			add_child(ti)
			_parts.append({"kind": "surge_forward", "node": ti, "mat": tmat, "z0": 1.0 + float(r_i) * 0.6, "z1": reach * (0.88 + float(r_i) * 0.14), "s0": 0.85, "s1": 2.35, "max_a": 0.92})
	else:
		# 360-degree spinning hurricane kick double sonic shockwaves!
		var tm := TorusMesh.new()
		tm.inner_radius = 0.65
		tm.outer_radius = 1.05
		tm.rings = 20
		tm.ring_segments = 6
		for r_i in range(2):
			var tmat := _make_mat(cyan if r_i == 0 else white, 0.94)
			var ti := _new_mesh_inst(tm, tmat)
			ti.position = Vector3(0.0, 0.85 + float(r_i) * 0.75, 0.0)
			ti.rotation = Vector3(0.18 if r_i == 0 else -0.18, 0.0, 0.12)
			ti.scale = Vector3(1.0, 0.16, 1.0)
			add_child(ti)
			_parts.append({"kind": "expand_ring", "node": ti, "mat": tmat, "max_s": reach * (1.02 + float(r_i) * 0.15), "spin": 11.0 if r_i == 0 else -9.0})

	_add_particles(24 if step == 3 else 14, white, Vector3(0.14, 0.14, 0.52), Vector3(0.0, 1.1, 1.0), Vector3(0.0, 0.2, 1.0), 40.0 if step < 3 else 170.0, 8.0, 15.0, Vector3(0.0, -4.0, 0.0), 0.34)


# 3. SWORDSMAN: Blazing crimson katana crescent wave & Cross-X Hellfire Slash
func _build_swordsman_attack(step: int, reach: float) -> void:
	var red := Color.html("#ef4444")
	var gold := Color.html("#fde047")

	if step < 3:
		var tilt := 0.42 if step == 1 else -0.42
		var wave_m := BoxMesh.new()
		wave_m.size = Vector3(3.4, 0.18, 0.75)
		var wmat := _make_mat(red.lerp(gold, 0.30), 0.94)
		var wave := _new_mesh_inst(wave_m, wmat)
		wave.position = Vector3(0.0, 1.25, 1.4)
		wave.rotation = Vector3(0.0, 0.0, tilt)
		add_child(wave)
		_parts.append({"kind": "surge_forward", "node": wave, "mat": wmat, "z0": 1.1, "z1": reach * 0.92, "s0": 0.75, "s1": 1.48, "max_a": 0.94})

		var core_m := BoxMesh.new()
		core_m.size = Vector3(3.2, 0.09, 0.30)
		var cmat := _make_mat(gold, 0.98)
		var core := _new_mesh_inst(core_m, cmat)
		core.position = Vector3(0.0, 1.25, 1.55)
		core.rotation = Vector3(0.0, 0.0, tilt)
		add_child(core)
		_parts.append({"kind": "surge_forward", "node": core, "mat": cmat, "z0": 1.25, "z1": reach * 0.96, "s0": 0.75, "s1": 1.48, "max_a": 0.98})
	else:
		# Giant Cross-X Crimson Flame Slash surging forward!
		var slash_m := BoxMesh.new()
		slash_m.size = Vector3(4.6, 0.24, 0.95)
		for s_i in range(2):
			var smat := _make_mat(red.lerp(gold, 0.35 if s_i == 0 else 0.15), 0.96)
			var sl := _new_mesh_inst(slash_m, smat)
			sl.position = Vector3(0.0, 1.45, 1.4)
			sl.rotation = Vector3(0.0, 0.0, 0.68 if s_i == 0 else -0.68)
			add_child(sl)
			_parts.append({"kind": "surge_forward", "node": sl, "mat": smat, "z0": 1.2, "z1": reach * 0.96, "s0": 0.72, "s1": 1.55, "max_a": 0.96})

	_add_particles(28 if step == 3 else 14, red.lerp(gold, 0.5), Vector3(0.14, 0.14, 0.42), Vector3(0.0, 1.2, 1.4), Vector3(0.0, 0.35, 1.0), 55.0, 6.0, 13.5, Vector3(0.0, -6.0, 0.0), 0.44)


# 4. RAIJIN: Ultra-fast jagged gold-white lightning slash bolts & mini sky thunder strike
func _build_raijin_attack(step: int, reach: float) -> void:
	var elec := Color.html("#facc15")
	var white := Color.html("#fef9c3")
	var bolts := 3 if step == 3 else 2

	for b_i in range(bolts):
		var bolt_root := Node3D.new()
		add_child(bolt_root)
		var bmat := _make_mat(white if b_i == 0 else elec, 0.98)

		var start_p := Vector3((-1.6 if step == 1 else 1.6) + randf_range(-0.4, 0.4), 1.45 + randf_range(-0.3, 0.3), 0.8)
		var end_p := Vector3((1.6 if step == 1 else -1.6) + randf_range(-0.4, 0.4), 1.15 + randf_range(-0.3, 0.3), reach * 0.82)
		if step == 3 and b_i == 2:
			# Mini vertical sky lightning strike right in front of Raijin!
			start_p = Vector3(0.0, 10.5, reach * 0.58)
			end_p = Vector3(0.0, 0.15, reach * 0.58)

		var prev := start_p
		var segs := 5
		for s in range(1, segs + 1):
			var frac := float(s) / float(segs)
			var nxt := start_p.lerp(end_p, frac)
			if s < segs:
				nxt += Vector3(randf_range(-0.55, 0.55), randf_range(-0.35, 0.35), randf_range(-0.35, 0.35))
			var seg_v := nxt - prev
			var cyl := CylinderMesh.new()
			cyl.top_radius = 0.08 if step < 3 else 0.12
			cyl.bottom_radius = 0.10 if step < 3 else 0.14
			cyl.height = maxf(0.1, seg_v.length())
			cyl.radial_segments = 6
			cyl.rings = 1
			var seg := _new_mesh_inst(cyl, bmat)
			seg.position = (prev + nxt) * 0.5
			var udir := seg_v.normalized()
			if absf(udir.y) < 0.99:
				seg.basis = Basis(Vector3.UP.cross(udir).normalized(), acos(clampf(Vector3.UP.dot(udir), -1.0, 1.0)))
			bolt_root.add_child(seg)
			prev = nxt

		_parts.append({"kind": "flicker", "node": bolt_root, "mat": bmat})

	_add_particles(22 if step == 3 else 12, elec.lerp(Color.WHITE, 0.4), Vector3(0.09, 0.38, 0.09), Vector3(0.0, 1.3, 2.0), Vector3(0.0, 0.5, 1.0), 95.0, 7.5, 16.0, Vector3(0.0, -8.0, 0.0), 0.30)


# 5. YUKIONNA: Ranged flying hexagonal ice-crystal darts & blooming 3D Frost Lotus spires
func _build_yukionna_attack(step: int, reach: float) -> void:
	var ice := Color.html("#22d3ee")
	var frost := Color.html("#e0f2fe")

	if step < 3:
		# Shoot 3 luminous hexagonal ice crystal darts forward up to 7.8m!
		var spreads := [-0.26, 0.0, 0.26] if step == 2 else [-0.15, 0.15]
		var dart_m := CylinderMesh.new()
		dart_m.top_radius = 0.02
		dart_m.bottom_radius = 0.22
		dart_m.height = 1.65
		dart_m.radial_segments = 6
		dart_m.rings = 1
		for ang in spreads:
			var dmat := _make_mat(ice.lerp(frost, 0.35), 0.94)
			var dart := _new_mesh_inst(dart_m, dmat)
			var dir_x := sin(ang)
			var dir_z := cos(ang)
			dart.position = Vector3(dir_x * 1.0, 1.45, dir_z * 1.0)
			dart.rotation = Vector3(PI * 0.5, ang, 0.0)
			add_child(dart)
			_parts.append({
				"kind": "dart",
				"node": dart,
				"mat": dmat,
				"start": dart.position,
				"end": Vector3(dir_x * reach * 0.94, 1.25, dir_z * reach * 0.94),
			})
	else:
		# Blooming 3D Frost Lotus ring + 5 erupting ice crystal spires at forward target!
		var center_z := reach * 0.62
		var ring_m := TorusMesh.new()
		ring_m.inner_radius = 0.55
		ring_m.outer_radius = 0.92
		ring_m.rings = 20
		ring_m.ring_segments = 6
		var rmat := _make_mat(frost, 0.92)
		var rinst := _new_mesh_inst(ring_m, rmat)
		rinst.position = Vector3(0.0, 0.25, center_z)
		rinst.scale = Vector3(1.0, 0.12, 1.0)
		add_child(rinst)
		_parts.append({"kind": "expand_ring", "node": rinst, "mat": rmat, "max_s": 4.2, "spin": 6.5})

		for i in range(5):
			var a := (float(i) / 5.0) * TAU
			var rad := 0.0 if i == 0 else 1.85
			var h := 3.4 if i == 0 else 2.5
			var sp_m := CylinderMesh.new()
			sp_m.top_radius = 0.04
			sp_m.bottom_radius = 0.42
			sp_m.height = h
			sp_m.radial_segments = 6
			sp_m.rings = 1
			var smat := _make_mat(ice.lerp(frost, 0.45 if i == 0 else 0.2), 0.92)
			var sp := _new_mesh_inst(sp_m, smat)
			sp.position = Vector3(cos(a) * rad, -h * 0.5, center_z + sin(a) * rad)
			sp.rotation = Vector3(sin(a) * 0.22, a, -cos(a) * 0.22)
			add_child(sp)
			_parts.append({"kind": "ice_pop", "node": sp, "mat": smat, "y0": -h * 0.5, "y1": h * 0.45})

	_add_particles(26 if step == 3 else 14, frost, Vector3(0.16, 0.16, 0.16), Vector3(0.0, 1.35, 1.5 if step < 3 else reach * 0.62), Vector3(0.0, 0.5, 1.0), 35.0 if step < 3 else 160.0, 5.5, 12.0, Vector3(0.0, -3.5, 0.0), 0.48)


func _process(delta: float) -> void:
	_life += delta
	if _life >= _max_life:
		queue_free()
		return

	var t := clampf(_life / _max_life, 0.0, 1.0)
	var ease_out := 1.0 - pow(1.0 - t, 2.5)
	var fade := clampf(1.0 - maxf(0.0, (t - 0.45) / 0.55), 0.0, 1.0)

	for p in _parts:
		var kind: String = p["kind"]
		var node: Node3D = p["node"]
		var mat: StandardMaterial3D = p["mat"]
		if kind == "orbit_out":
			var ang: float = float(p["angle"]) + _life * float(p["spin"]) * 0.35
			var r := lerpf(float(p["r0"]), float(p["r1"]), ease_out)
			node.position = Vector3(sin(ang) * r, float(p["y0"]) + ease_out * float(p["y_rise"]), cos(ang) * r)
			node.rotation = Vector3(_life * 8.0, ang, _life * 6.0)
			mat.albedo_color.a = 0.94 * fade
		elif kind == "expand_ring":
			var s := lerpf(0.8, float(p["max_s"]), ease_out)
			node.scale = Vector3(s, node.scale.y, s)
			node.rotation.y += delta * float(p["spin"])
			mat.albedo_color.a = 0.92 * (1.0 - t)
		elif kind == "surge_forward":
			node.position.z = lerpf(float(p["z0"]), float(p["z1"]), ease_out)
			var s := lerpf(float(p["s0"]), float(p["s1"]), ease_out)
			node.scale = Vector3(s, s, s)
			mat.albedo_color.a = float(p["max_a"]) * (1.0 - t)
		elif kind == "flicker":
			var fl := 0.5 + 0.5 * absf(sin(_life * 62.0))
			mat.albedo_color.a = (1.0 - t) * fl
		elif kind == "dart":
			node.position = (p["start"] as Vector3).lerp(p["end"] as Vector3, ease_out)
			mat.albedo_color.a = 0.95 * fade
		elif kind == "ice_pop":
			var pop_t := clampf(t / 0.32, 0.0, 1.0)
			pop_t = 1.0 - pow(1.0 - pop_t, 3.0)
			node.position.y = lerpf(float(p["y0"]), float(p["y1"]), pop_t)
			mat.albedo_color.a = 0.92 * fade
