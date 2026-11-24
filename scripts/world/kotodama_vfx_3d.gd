class_name KotodamaVfx3D
extends Node3D
## WebGL2 (GL Compatibility) safe 3D Kotodama spell VFX engine supporting 8 distinct
## Japanese vocabulary visual archetypes + floating 3D Kanji calligraphy callout.

var _life: float = 0.0
var _max_life: float = 1.65
var _vfx_type: String = "sacred_halo"
var _accent: Color = Color.html("#fbbf24")
var _scale_mult: float = 1.0

var _kanji_label: Label3D
var _kana_label: Label3D
var _animated_parts: Array[Dictionary] = [] # {node, mat, kind, ...}


func setup(world_pos: Vector3, word: Dictionary, is_perfect: bool = false) -> void:
	position = world_pos
	_vfx_type = String(word.get("vfx", "sacred_halo"))
	_accent = Color.html(String(word.get("color", "#fbbf24")))
	_scale_mult = 1.25 if is_perfect else 1.0
	_max_life = 1.85 if is_perfect else 1.55

	_build_kanji_stamp(String(word.get("kanji", "")), String(word.get("kana", "")), is_perfect)

	match _vfx_type:
		"meteor":
			_build_meteor_shower()
		"lightning":
			_build_lightning_storm()
		"blizzard":
			_build_blizzard_spires()
		"sakura_storm":
			_build_sakura_vortex()
		"dragon_vortex":
			_build_dragon_vortex()
		"sword_rain":
			_build_sword_rain()
		"earth_shatter":
			_build_earth_shatter()
		_:
			_build_sacred_halo()


func _make_unshaded_mat(col: Color, alpha: float = 0.92) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(col.r, col.g, col.b, alpha)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	return mat


func _build_kanji_stamp(kanji: String, kana: String, is_perfect: bool) -> void:
	if kanji.is_empty():
		return
	var font_res: Font = null
	if ResourceLoader.exists("res://assets/fonts/noto_cjk_game.otf"):
		font_res = load("res://assets/fonts/noto_cjk_game.otf")

	_kanji_label = Label3D.new()
	_kanji_label.text = "「%s」" % kanji
	_kanji_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_kanji_label.no_depth_test = true
	_kanji_label.font_size = 96 if is_perfect else 76
	_kanji_label.outline_size = 18
	_kanji_label.modulate = _accent.lerp(Color.WHITE, 0.45)
	_kanji_label.outline_modulate = Color.html("#090d1a")
	_kanji_label.position = Vector3(0.0, 3.8, 0.0)
	_kanji_label.pixel_size = 0.0115
	if font_res != null:
		_kanji_label.font = font_res
	add_child(_kanji_label)

	if not kana.is_empty():
		_kana_label = Label3D.new()
		_kana_label.text = kana
		_kana_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_kana_label.no_depth_test = true
		_kana_label.font_size = 44 if is_perfect else 38
		_kana_label.outline_size = 10
		_kana_label.modulate = Color.html("#fef3c7")
		_kana_label.outline_modulate = Color.html("#090d1a")
		_kana_label.position = Vector3(0.0, 2.95, 0.0)
		_kana_label.pixel_size = 0.0105
		if font_res != null:
			_kana_label.font = font_res
		add_child(_kana_label)


func _spawn_particles(amount: int, col: Color, shape_size: Vector3, dir: Vector3, spread: float, vmin: float, vmax: float, grav: Vector3, life: float, emission_rad: float = 1.2) -> void:
	var p := CPUParticles3D.new()
	p.emitting = false
	p.one_shot = true
	p.explosiveness = 0.85
	p.amount = amount
	p.lifetime = life
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = emission_rad
	p.direction = dir
	p.spread = spread
	p.initial_velocity_min = vmin
	p.initial_velocity_max = vmax
	p.gravity = grav
	p.damping_min = 1.5
	p.damping_max = 3.5
	p.scale_amount_min = 0.65
	p.scale_amount_max = 1.45

	var bm := BoxMesh.new()
	bm.size = shape_size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bm.material = mat
	p.mesh = bm
	p.particle_flag_align_y = true
	add_child(p)
	p.emitting = true


# 1. METEOR: Blazing fireballs/star-shards plunging diagonally from sky + shockwave craters
func _build_meteor_shower() -> void:
	var count := 6
	for i in range(count):
		var ang := (float(i) / float(count)) * TAU + randf_range(-0.25, 0.25)
		var dist := randf_range(2.2, 8.8) * _scale_mult
		var target := Vector3(cos(ang) * dist, 0.35, sin(ang) * dist)
		var start := target + Vector3(cos(ang + 1.2) * 8.5, 19.0 + randf_range(0.0, 4.0), sin(ang + 1.2) * 8.5)

		var root := Node3D.new()
		root.position = start
		add_child(root)

		var core_m := SphereMesh.new()
		core_m.radius = 0.62 * _scale_mult
		core_m.height = 1.24 * _scale_mult
		var core_mat := _make_unshaded_mat(_accent.lerp(Color.html("#fef08a"), 0.55), 0.96)
		var core := MeshInstance3D.new()
		core.mesh = core_m
		core.material_override = core_mat
		root.add_child(core)

		var tail_m := CylinderMesh.new()
		tail_m.top_radius = 0.08
		tail_m.bottom_radius = 0.52 * _scale_mult
		tail_m.height = 4.2 * _scale_mult
		var tail_mat := _make_unshaded_mat(_accent, 0.78)
		var tail := MeshInstance3D.new()
		tail.mesh = tail_m
		tail.material_override = tail_mat
		tail.position = Vector3(0.0, 2.2 * _scale_mult, 0.0)
		root.add_child(tail)

		var fall_dir := (start - target).normalized()
		if fall_dir.length() > 0.01:
			root.basis = Basis(Vector3.UP.cross(fall_dir).normalized() if absf(fall_dir.y) < 0.98 else Vector3.RIGHT, acos(clampf(Vector3.UP.dot(fall_dir), -1.0, 1.0)))

		# Ground impact ring (expands when meteor lands)
		var ring_m := TorusMesh.new()
		ring_m.inner_radius = 0.5
		ring_m.outer_radius = 0.95
		var ring_mat := _make_unshaded_mat(_accent.lerp(Color.html("#fde047"), 0.35), 0.0)
		var ring := MeshInstance3D.new()
		ring.mesh = ring_m
		ring.material_override = ring_mat
		ring.position = Vector3(target.x, 0.16, target.z)
		ring.scale = Vector3(0.5, 0.08, 0.5)
		add_child(ring)

		_animated_parts.append({
			"kind": "meteor",
			"node": root,
			"mat": core_mat,
			"tail_mat": tail_mat,
			"ring": ring,
			"ring_mat": ring_mat,
			"start": start,
			"target": target,
			"delay": float(i) * 0.075,
			"fall_dur": 0.36,
		})

	_spawn_particles(42, _accent.lerp(Color.html("#fde047"), 0.45), Vector3(0.18, 0.42, 0.18), Vector3(0.0, 1.0, 0.0), 140.0, 5.5, 13.5, Vector3(0.0, -10.0, 0.0), 1.1, 4.0)


# 2. LIGHTNING: Jagged multi-segment sky-to-ground thunderbolts + crackling aura cylinder
func _build_lightning_storm() -> void:
	var bolt_count := 6
	for i in range(bolt_count):
		var ang := (float(i) / float(bolt_count)) * TAU
		var dist := (0.0 if i == 0 else randf_range(3.6, 9.2)) * _scale_mult
		var base_x := cos(ang) * dist
		var base_z := sin(ang) * dist

		var bolt_root := Node3D.new()
		bolt_root.position = Vector3(base_x, 0.0, base_z)
		add_child(bolt_root)

		var bolt_mat := _make_unshaded_mat(_accent.lerp(Color.WHITE, 0.45), 0.96)
		var prev := Vector3(0.0, 0.0, 0.0)
		var segs := 6
		for s in range(1, segs + 1):
			var ny := float(s) * 3.4
			var nx := randf_range(-1.1, 1.1) if s < segs else 0.0
			var nz := randf_range(-1.1, 1.1) if s < segs else 0.0
			var nxt := Vector3(nx, ny, nz)
			var mid := (prev + nxt) * 0.5
			var seg_vec := nxt - prev
			var seg_len := seg_vec.length()

			var cyl := CylinderMesh.new()
			cyl.top_radius = 0.16 * _scale_mult
			cyl.bottom_radius = 0.24 * _scale_mult
			cyl.height = seg_len
			var seg_inst := MeshInstance3D.new()
			seg_inst.mesh = cyl
			seg_inst.material_override = bolt_mat
			seg_inst.position = mid
			var up_dir := seg_vec.normalized()
			if absf(up_dir.y) < 0.99:
				seg_inst.basis = Basis(Vector3.UP.cross(up_dir).normalized(), acos(clampf(Vector3.UP.dot(up_dir), -1.0, 1.0)))
			bolt_root.add_child(seg_inst)
			prev = nxt

		# Ground flash disc
		var disc_m := CylinderMesh.new()
		disc_m.top_radius = 1.6 * _scale_mult
		disc_m.bottom_radius = 1.8 * _scale_mult
		disc_m.height = 0.12
		var disc_mat := _make_unshaded_mat(_accent, 0.85)
		var disc := MeshInstance3D.new()
		disc.mesh = disc_m
		disc.material_override = disc_mat
		disc.position = Vector3(0.0, 0.10, 0.0)
		bolt_root.add_child(disc)

		_animated_parts.append({
			"kind": "lightning",
			"node": bolt_root,
			"mat": bolt_mat,
			"disc_mat": disc_mat,
			"delay": float(i) * 0.06,
		})

	_spawn_particles(44, _accent.lerp(Color.WHITE, 0.4), Vector3(0.11, 0.55, 0.11), Vector3(0.0, 1.0, 0.0), 160.0, 6.0, 14.0, Vector3(0.0, -8.0, 0.0), 0.95, 4.5)


# 3. BLIZZARD: Erupting hexagonal 3D ice crystal spires + rotating frost halo + snowstorm
func _build_blizzard_spires() -> void:
	var count := 10
	for i in range(count):
		var ang := (float(i) / float(count)) * TAU
		var dist := (4.8 + float(i % 2) * 3.8) * _scale_mult
		var spire_h := randf_range(3.6, 5.8) * _scale_mult

		var cone := CylinderMesh.new()
		cone.top_radius = 0.05
		cone.bottom_radius = 0.68 * _scale_mult
		cone.height = spire_h
		cone.radial_segments = 6
		var mat := _make_unshaded_mat(_accent.lerp(Color.WHITE, 0.35), 0.88)
		var inst := MeshInstance3D.new()
		inst.mesh = cone
		inst.material_override = mat
		inst.position = Vector3(cos(ang) * dist, -spire_h * 0.5, sin(ang) * dist)
		inst.rotation = Vector3(sin(ang) * 0.22, ang, -cos(ang) * 0.22)
		add_child(inst)

		_animated_parts.append({
			"kind": "spire",
			"node": inst,
			"mat": mat,
			"target_y": spire_h * 0.42,
			"start_y": -spire_h * 0.6,
			"delay": float(i % 5) * 0.045,
		})

	# Rotating frost ring halo
	var halo_m := TorusMesh.new()
	halo_m.inner_radius = 5.4 * _scale_mult
	halo_m.outer_radius = 6.1 * _scale_mult
	halo_m.rings = 32
	var halo_mat := _make_unshaded_mat(_accent.lerp(Color.WHITE, 0.5), 0.80)
	var halo := MeshInstance3D.new()
	halo.mesh = halo_m
	halo.material_override = halo_mat
	halo.position = Vector3(0.0, 1.8, 0.0)
	halo.scale = Vector3(1.0, 0.16, 1.0)
	add_child(halo)
	_animated_parts.append({"kind": "spin_ring", "node": halo, "mat": halo_mat, "spin": 3.4, "rise": 1.6})

	_spawn_particles(54, _accent.lerp(Color.WHITE, 0.6), Vector3(0.20, 0.20, 0.20), Vector3(0.0, 0.8, 0.0), 180.0, 3.5, 9.0, Vector3(0.0, -2.5, 0.0), 1.35, 6.0)


# 4. SAKURA_STORM: Rising helical whirlwind of glowing petal/butterfly blades + twin rose rings
func _build_sakura_vortex() -> void:
	var count := 24
	for i in range(count):
		var ang := (float(i) / float(count)) * TAU * 2.0
		var rad := (2.6 + float(i % 4) * 1.8) * _scale_mult
		var petal_m := BoxMesh.new()
		petal_m.size = Vector3(0.62 * _scale_mult, 0.08, 0.34 * _scale_mult)
		var col := _accent.lerp(Color.html("#fef3c7"), float(i % 3) * 0.22)
		var mat := _make_unshaded_mat(col, 0.92)
		var inst := MeshInstance3D.new()
		inst.mesh = petal_m
		inst.material_override = mat
		inst.position = Vector3(cos(ang) * rad, 0.4 + float(i) * 0.18, sin(ang) * rad)
		add_child(inst)

		_animated_parts.append({
			"kind": "helix",
			"node": inst,
			"mat": mat,
			"angle": ang,
			"radius": rad,
			"base_y": 0.35 + float(i) * 0.16,
			"speed": 5.2 + float(i % 3) * 1.1,
			"rise": 4.2,
		})

	for r_i in range(2):
		var ring_m := TorusMesh.new()
		ring_m.inner_radius = (3.0 + float(r_i) * 3.0) * _scale_mult
		ring_m.outer_radius = (3.4 + float(r_i) * 3.0) * _scale_mult
		var rmat := _make_unshaded_mat(_accent, 0.85)
		var rinst := MeshInstance3D.new()
		rinst.mesh = ring_m
		rinst.material_override = rmat
		rinst.position = Vector3(0.0, 0.4 + float(r_i) * 1.2, 0.0)
		rinst.scale = Vector3(1.0, 0.12, 1.0)
		add_child(rinst)
		_animated_parts.append({"kind": "spin_ring", "node": rinst, "mat": rmat, "spin": (4.0 if r_i == 0 else -3.0), "rise": 3.2})

	_spawn_particles(56, _accent.lerp(Color.WHITE, 0.35), Vector3(0.24, 0.06, 0.16), Vector3(0.0, 1.0, 0.0), 130.0, 4.0, 9.5, Vector3(0.0, -1.6, 0.0), 1.45, 5.2)


# 5. DRAGON_VORTEX: Towering spiraling wind/dragon tornado of stacked tilted rings + rising gale
func _build_dragon_vortex() -> void:
	var tiers := 9
	for i in range(tiers):
		var t := float(i) / float(tiers - 1)
		var rad := lerpf(1.8, 6.8, t) * _scale_mult
		var ring_m := TorusMesh.new()
		ring_m.inner_radius = rad * 0.84
		ring_m.outer_radius = rad
		ring_m.rings = 28
		var col := _accent.lerp(Color.WHITE, t * 0.45)
		var mat := _make_unshaded_mat(col, 0.86)
		var inst := MeshInstance3D.new()
		inst.mesh = ring_m
		inst.material_override = mat
		inst.position = Vector3(0.0, 0.6 + t * 8.2, 0.0)
		inst.rotation = Vector3(sin(float(i) * 0.8) * 0.25, float(i) * 0.7, cos(float(i) * 0.8) * 0.25)
		inst.scale = Vector3(1.0, 0.22, 1.0)
		add_child(inst)

		_animated_parts.append({
			"kind": "vortex_tier",
			"node": inst,
			"mat": mat,
			"spin": (7.5 - t * 2.5) * (1.0 if i % 2 == 0 else -1.0),
			"base_y": inst.position.y,
			"rise": 3.5,
		})

	# Central roaring vortex core
	var core_m := CylinderMesh.new()
	core_m.top_radius = 2.4 * _scale_mult
	core_m.bottom_radius = 0.8 * _scale_mult
	core_m.height = 11.0
	var core_mat := _make_unshaded_mat(_accent, 0.42)
	var core := MeshInstance3D.new()
	core.mesh = core_m
	core.material_override = core_mat
	core.position = Vector3(0.0, 5.5, 0.0)
	add_child(core)
	_animated_parts.append({"kind": "pillar", "node": core, "mat": core_mat, "max_alpha": 0.42})

	_spawn_particles(48, _accent.lerp(Color.WHITE, 0.5), Vector3(0.16, 0.55, 0.16), Vector3(0.0, 1.0, 0.0), 85.0, 7.0, 14.0, Vector3(0.0, 1.2, 0.0), 1.25, 3.6)


# 6. SWORD_RAIN: 10 luminous 3D katana light-blades summoned in an overhead halo & plunging down
func _build_sword_rain() -> void:
	var count := 10
	for i in range(count):
		var ang := (float(i) / float(count)) * TAU
		var dist := (3.6 + float(i % 2) * 3.8) * _scale_mult
		var tx := cos(ang) * dist
		var tz := sin(ang) * dist

		var sword_root := Node3D.new()
		sword_root.position = Vector3(tx, 12.5, tz)
		add_child(sword_root)

		var blade_m := BoxMesh.new()
		blade_m.size = Vector3(0.16 * _scale_mult, 3.6 * _scale_mult, 0.34 * _scale_mult)
		var blade_mat := _make_unshaded_mat(_accent.lerp(Color.WHITE, 0.55), 0.95)
		var blade := MeshInstance3D.new()
		blade.mesh = blade_m
		blade.material_override = blade_mat
		blade.position = Vector3(0.0, 1.8 * _scale_mult, 0.0)
		sword_root.add_child(blade)

		var guard_m := BoxMesh.new()
		guard_m.size = Vector3(0.95 * _scale_mult, 0.16, 0.28 * _scale_mult)
		var guard_mat := _make_unshaded_mat(Color.html("#fde047"), 0.95)
		var guard := MeshInstance3D.new()
		guard.mesh = guard_m
		guard.material_override = guard_mat
		guard.position = Vector3(0.0, 3.55 * _scale_mult, 0.0)
		sword_root.add_child(guard)

		var ring_m := TorusMesh.new()
		ring_m.inner_radius = 0.35
		ring_m.outer_radius = 0.65
		var ring_mat := _make_unshaded_mat(_accent, 0.0)
		var ring := MeshInstance3D.new()
		ring.mesh = ring_m
		ring.material_override = ring_mat
		ring.position = Vector3(tx, 0.14, tz)
		ring.scale = Vector3(0.6, 0.08, 0.6)
		add_child(ring)

		_animated_parts.append({
			"kind": "sword",
			"node": sword_root,
			"mat": blade_mat,
			"guard_mat": guard_mat,
			"ring": ring,
			"ring_mat": ring_mat,
			"delay": float(i) * 0.045,
			"hover_dur": 0.22,
			"drop_dur": 0.16,
		})

	_spawn_particles(40, _accent.lerp(Color.WHITE, 0.55), Vector3(0.10, 0.65, 0.10), Vector3(0.0, 1.0, 0.0), 150.0, 5.0, 12.0, Vector3(0.0, -12.0, 0.0), 1.0, 5.2)


# 7. EARTH_SHATTER: 10 jagged angled monolith rock spikes erupting in a radial blast
func _build_earth_shatter() -> void:
	var count := 10
	for i in range(count):
		var ang := (float(i) / float(count)) * TAU
		var dist := (4.2 + float(i % 2) * 3.4) * _scale_mult
		var h := randf_range(3.2, 5.4) * _scale_mult

		var rock_m := PrismMesh.new()
		rock_m.size = Vector3(1.45 * _scale_mult, h, 1.45 * _scale_mult)
		var mat := _make_unshaded_mat(_accent.lerp(Color.html("#fef08a"), 0.22 if i % 2 == 0 else 0.0), 0.94)
		var inst := MeshInstance3D.new()
		inst.mesh = rock_m
		inst.material_override = mat
		inst.position = Vector3(cos(ang) * dist, -h * 0.6, sin(ang) * dist)
		inst.rotation = Vector3(-sin(ang) * 0.34, ang, cos(ang) * 0.34)
		add_child(inst)

		_animated_parts.append({
			"kind": "spire",
			"node": inst,
			"mat": mat,
			"target_y": h * 0.42,
			"start_y": -h * 0.65,
			"delay": float(i % 5) * 0.04,
		})

	_spawn_particles(46, _accent.lerp(Color.html("#fed7aa"), 0.35), Vector3(0.32, 0.32, 0.32), Vector3(0.0, 1.0, 0.0), 135.0, 5.5, 12.0, Vector3(0.0, -16.0, 0.0), 1.15, 4.8)


# 8. SACRED_HALO: Towering golden heavenly light beam + 2 counter-rotating sacred halos
func _build_sacred_halo() -> void:
	var beam_m := CylinderMesh.new()
	beam_m.top_radius = 2.8 * _scale_mult
	beam_m.bottom_radius = 4.2 * _scale_mult
	beam_m.height = 20.0
	var beam_mat := _make_unshaded_mat(_accent.lerp(Color.WHITE, 0.35), 0.56)
	var beam := MeshInstance3D.new()
	beam.mesh = beam_m
	beam.material_override = beam_mat
	beam.position = Vector3(0.0, 10.0, 0.0)
	add_child(beam)
	_animated_parts.append({"kind": "pillar", "node": beam, "mat": beam_mat, "max_alpha": 0.56})

	for i in range(2):
		var halo_m := TorusMesh.new()
		halo_m.inner_radius = (3.6 + float(i) * 2.2) * _scale_mult
		halo_m.outer_radius = (4.1 + float(i) * 2.2) * _scale_mult
		halo_m.rings = 36
		var hmat := _make_unshaded_mat(_accent.lerp(Color.WHITE, 0.5), 0.92)
		var hinst := MeshInstance3D.new()
		hinst.mesh = halo_m
		hinst.material_override = hmat
		hinst.position = Vector3(0.0, 2.2 + float(i) * 1.4, 0.0)
		hinst.rotation = Vector3(0.38 if i == 0 else -0.38, 0.0, 0.25 if i == 0 else -0.25)
		hinst.scale = Vector3(1.0, 0.25, 1.0)
		add_child(hinst)
		_animated_parts.append({"kind": "spin_ring", "node": hinst, "mat": hmat, "spin": (3.2 if i == 0 else -2.6), "rise": 2.4})

	_spawn_particles(48, _accent.lerp(Color.WHITE, 0.55), Vector3(0.22, 0.22, 0.22), Vector3(0.0, 1.0, 0.0), 45.0, 3.5, 9.5, Vector3(0.0, 2.2, 0.0), 1.45, 4.4)


func _process(delta: float) -> void:
	_life += delta
	if _life >= _max_life:
		queue_free()
		return

	var global_t := clampf(_life / _max_life, 0.0, 1.0)
	var fade_out := clampf(1.0 - maxf(0.0, (global_t - 0.58) / 0.42), 0.0, 1.0)

	# Animate 3D Kanji calligraphy callout (dramatic pop-in, gentle ascent, smooth fade)
	if _kanji_label != null:
		var pop := 1.0 + sin(minf(1.0, _life / 0.22) * PI) * 0.28
		_kanji_label.scale = Vector3(pop, pop, pop)
		_kanji_label.position.y = 3.8 + _life * 1.15
		_kanji_label.modulate.a = fade_out
		_kanji_label.outline_modulate.a = fade_out
	if _kana_label != null:
		_kana_label.position.y = 2.95 + _life * 1.15
		_kana_label.modulate.a = fade_out
		_kana_label.outline_modulate.a = fade_out

	for p in _animated_parts:
		var kind: String = p["kind"]
		if kind == "meteor":
			var lt := _life - float(p["delay"])
			var node: Node3D = p["node"]
			var ring: MeshInstance3D = p["ring"]
			var rmat: StandardMaterial3D = p["ring_mat"]
			if lt < 0.0:
				node.visible = false
				ring.visible = false
			else:
				var fdur: float = float(p["fall_dur"])
				var ft := clampf(lt / fdur, 0.0, 1.0)
				if ft < 1.0:
					node.visible = true
					node.position = (p["start"] as Vector3).lerp(p["target"] as Vector3, ft * ft)
					ring.visible = false
				else:
					node.visible = false
					var rt := clampf((lt - fdur) / 0.55, 0.0, 1.0)
					ring.visible = rt < 1.0
					var rs := 0.8 + rt * 4.8 * _scale_mult
					ring.scale = Vector3(rs, 0.08, rs)
					rmat.albedo_color.a = (1.0 - rt) * 0.88
		elif kind == "lightning":
			var lt := _life - float(p["delay"])
			var node: Node3D = p["node"]
			var bmat: StandardMaterial3D = p["mat"]
			var dmat: StandardMaterial3D = p["disc_mat"]
			if lt < 0.0:
				node.visible = false
			else:
				node.visible = true
				var flick := 0.55 + 0.45 * absf(sin(lt * 46.0))
				var lfade := clampf(1.0 - lt / 0.75, 0.0, 1.0)
				bmat.albedo_color.a = lfade * flick
				dmat.albedo_color.a = lfade * 0.85
				var sc := 0.75 + (1.0 - lfade) * 0.6
				node.scale = Vector3(sc, 1.0, sc)
		elif kind == "spire":
			var lt := _life - float(p["delay"])
			var node: MeshInstance3D = p["node"]
			var mat: StandardMaterial3D = p["mat"]
			if lt < 0.0:
				node.visible = false
			else:
				node.visible = true
				var up_t := clampf(lt / 0.22, 0.0, 1.0)
				up_t = 1.0 - pow(1.0 - up_t, 3.0)
				node.position.y = lerpf(float(p["start_y"]), float(p["target_y"]), up_t)
				mat.albedo_color.a = 0.88 * fade_out
		elif kind == "helix":
			var node: MeshInstance3D = p["node"]
			var mat: StandardMaterial3D = p["mat"]
			var ang: float = float(p["angle"]) + _life * float(p["speed"])
			var rad: float = float(p["radius"]) * (0.95 + global_t * 0.45)
			node.position = Vector3(cos(ang) * rad, float(p["base_y"]) + global_t * float(p["rise"]), sin(ang) * rad)
			node.rotation = Vector3(_life * 5.0, -ang, _life * 3.5)
			mat.albedo_color.a = 0.92 * fade_out
		elif kind == "vortex_tier":
			var node: MeshInstance3D = p["node"]
			var mat: StandardMaterial3D = p["mat"]
			node.rotation.y += delta * float(p["spin"])
			node.position.y = float(p["base_y"]) + global_t * float(p["rise"])
			var expand := 0.85 + global_t * 0.45
			node.scale = Vector3(expand, 0.22, expand)
			mat.albedo_color.a = 0.85 * fade_out
		elif kind == "sword":
			var lt := _life - float(p["delay"])
			var node: Node3D = p["node"]
			var mat: StandardMaterial3D = p["mat"]
			var gmat: StandardMaterial3D = p["guard_mat"]
			var ring: MeshInstance3D = p["ring"]
			var rmat: StandardMaterial3D = p["ring_mat"]
			if lt < 0.0:
				node.visible = false
				ring.visible = false
			else:
				node.visible = true
				var hdur: float = float(p["hover_dur"])
				var ddur: float = float(p["drop_dur"])
				if lt < hdur:
					node.position.y = 12.5 - sin((lt / hdur) * PI * 0.5) * 0.8
					ring.visible = false
				elif lt < hdur + ddur:
					var dt := (lt - hdur) / ddur
					node.position.y = lerpf(11.7, 0.15, dt * dt)
					ring.visible = false
				else:
					node.position.y = 0.15
					var after_t := clampf((lt - hdur - ddur) / 0.72, 0.0, 1.0)
					ring.visible = after_t < 1.0
					var rs := 0.7 + after_t * 3.2 * _scale_mult
					ring.scale = Vector3(rs, 0.08, rs)
					rmat.albedo_color.a = (1.0 - after_t) * 0.85
				mat.albedo_color.a = 0.95 * fade_out
				gmat.albedo_color.a = 0.95 * fade_out
		elif kind == "spin_ring":
			var node: MeshInstance3D = p["node"]
			var mat: StandardMaterial3D = p["mat"]
			node.rotation.y += delta * float(p["spin"])
			node.position.y += delta * float(p["rise"]) * 0.45
			var s := 0.9 + global_t * 0.55
			node.scale = Vector3(s, node.scale.y, s)
			mat.albedo_color.a = 0.88 * fade_out
		elif kind == "pillar":
			var node: MeshInstance3D = p["node"]
			var mat: StandardMaterial3D = p["mat"]
			var s := 0.55 + sin(minf(1.0, global_t * 2.2) * PI * 0.5) * 0.65
			node.scale = Vector3(s, 1.0, s)
			mat.albedo_color.a = float(p["max_alpha"]) * fade_out
