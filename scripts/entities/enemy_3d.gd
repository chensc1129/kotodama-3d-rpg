class_name Enemy3D
extends Node3D
## Distinct procedural 3D Japanese Yokai & Boss models with animated body parts
## and multi-material status tinting (petrify, freeze, stun, shock, burn).

var enemy_name: String = ""
var template_id: String = ""
var is_boss: bool = false
var hp: int = 100
var max_hp: int = 100
var move_speed: float = 3.5
var atk: int = 10
var ranged: bool = false
var atk_timer: float = 1.5

var petrify_timer: float = 0.0
var freeze_timer: float = 0.0
var stun_timer: float = 0.0
var shock_timer: float = 0.0
var burn_timer: float = 0.0
var frost_tick_timer: float = 0.0
var dead: bool = false

var _visual_root: Node3D
var _anim_nodes: Array[Node3D] = []
var _tint_mats: Array[StandardMaterial3D] = []
var _orig_colors: Array[Color] = []
var _status_ring: MeshInstance3D
var _status_mat: StandardMaterial3D
var _elapsed: float = 0.0


func setup(tpl: Dictionary, p_is_boss: bool, wave_num: int, is_hard: bool) -> void:
	enemy_name = tpl["name"]
	template_id = tpl["id"]
	is_boss = p_is_boss
	_elapsed = randf() * TAU

	var scale_factor: float = 1.0 + float(wave_num - 1) * 0.24 + (0.45 if is_hard else 0.0)
	max_hp = int(round(75.0 * float(tpl["hp_mult"]) * scale_factor))
	hp = max_hp
	move_speed = float(tpl["spd"]) * (1.15 if is_hard else 1.0)
	atk = int(round(float(tpl["atk"]) * (1.0 + float(wave_num - 1) * 0.14) * (1.3 if is_hard else 1.0)))
	ranged = bool(tpl["ranged"]) or is_hard
	atk_timer = 1.2 + randf() * 1.5

	var ang := randf() * TAU
	var dist := 10.0 + randf() * 6.0
	position = Vector3(cos(ang) * dist, 0.0, sin(ang) * dist)

	_build_mesh(tpl)


func _build_mesh(tpl: Dictionary) -> void:
	_visual_root = Node3D.new()
	add_child(_visual_root)

	var main_col := Color.html(tpl["color"])
	var main_mat := _tint_mat(main_col, 0.45, 0.1)
	var dark_mat := _tint_mat(Color.html("#1e293b"), 0.55, 0.2)
	var gold_mat := _tint_mat(Color.html("#fbbf24"), 0.25, 0.75)
	var white_mat := _mat_unshaded(Color.WHITE)
	var eye_glow := _mat_unshaded(Color.html("#fef08a"))
	var pupil_mat := _mat_unshaded(Color.html("#0f172a"))
	var red_mat := _tint_mat(Color.html("#dc2626"), 0.4, 0.1)

	match template_id:
		"chochin":
			# Classic Japanese Lantern Yokai (Chochin-obake): ribbed glowing lantern + huge 1 eye + red tongue
			var lantern_mat := _tint_mat(Color.html("#f97316"), 0.35, 0.05, Color.html("#ea580c"), 0.45)
			var body := _sphere(0.68, lantern_mat)
			body.position = Vector3(0.0, 1.18, 0.0)
			body.scale = Vector3(0.95, 1.25, 0.95)
			_visual_root.add_child(body)

			# Lantern ribs
			for ry in [0.78, 1.05, 1.32, 1.58]:
				var rib := _torus(0.54, 0.62, dark_mat)
				rib.position = Vector3(0.0, ry, 0.0)
				_visual_root.add_child(rib)

			# Top & bottom wooden caps
			var cap_t := _cyl(0.38, 0.46, 0.18, dark_mat)
			cap_t.position = Vector3(0.0, 2.02, 0.0)
			_visual_root.add_child(cap_t)
			var cap_b := _cyl(0.44, 0.36, 0.16, dark_mat)
			cap_b.position = Vector3(0.0, 0.38, 0.0)
			_visual_root.add_child(cap_b)

			# Single huge glaring eye
			var eye_bg := _sphere(0.24, white_mat)
			eye_bg.position = Vector3(0.0, 1.48, 0.56)
			eye_bg.scale = Vector3(1.2, 0.9, 0.5)
			_visual_root.add_child(eye_bg)
			var pupil := _sphere(0.11, pupil_mat)
			pupil.position = Vector3(0.0, 1.48, 0.66)
			_visual_root.add_child(pupil)

			# Wide mouth & dangling red tongue
			var mouth := _box(Vector3(0.70, 0.16, 0.18), dark_mat)
			mouth.position = Vector3(0.0, 1.05, 0.58)
			_visual_root.add_child(mouth)
			var tongue := _box(Vector3(0.24, 0.48, 0.08), red_mat)
			tongue.position = Vector3(0.0, 0.80, 0.66)
			tongue.rotation.x = -0.25
			_visual_root.add_child(tongue)
			_anim_nodes.append(tongue)

		"kasa":
			# Classic Umbrella Yokai (Kasa-obake): purple canopy + single eye + 1 hopping leg with geta sandal
			var canopy := _cyl(0.08, 0.95, 0.85, main_mat, 10)
			canopy.position = Vector3(0.0, 1.65, 0.0)
			_visual_root.add_child(canopy)

			var rim := _torus(0.86, 0.96, gold_mat)
			rim.position = Vector3(0.0, 1.24, 0.0)
			_visual_root.add_child(rim)

			var stem := _cyl(0.09, 0.09, 1.15, _tint_mat(Color.html("#a16207"), 0.6, 0.05))
			stem.position = Vector3(0.0, 0.72, 0.0)
			_visual_root.add_child(stem)

			var geta := _box(Vector3(0.32, 0.16, 0.54), _tint_mat(Color.html("#78350f"), 0.7, 0.05))
			geta.position = Vector3(0.0, 0.10, 0.08)
			_visual_root.add_child(geta)

			var eye := _sphere(0.22, white_mat)
			eye.position = Vector3(0.0, 1.58, 0.56)
			eye.scale = Vector3(1.15, 1.0, 0.55)
			_visual_root.add_child(eye)
			var pupil := _sphere(0.10, pupil_mat)
			pupil.position = Vector3(0.0, 1.58, 0.66)
			_visual_root.add_child(pupil)

		"aooni":
			# Muscular Horned Blue Oni Warrior with tiger loincloth, shoulder plates & iron kanabo club!
			_build_oni_warrior(main_mat, gold_mat, dark_mat, eye_glow, false)

		"kyubi":
			# Golden Nine-Tails Demon Fox with fox mask face & dramatic fan of glowing tails!
			var fox_mat := _tint_mat(Color.html("#facc15"), 0.35, 0.15, Color.html("#eab308"), 0.22)
			var robe := _cyl(0.30, 0.54, 1.25, _tint_mat(Color.html("#fef3c7"), 0.45, 0.05))
			robe.position = Vector3(0.0, 0.72, 0.0)
			_visual_root.add_child(robe)

			var sash := _cyl(0.36, 0.38, 0.22, red_mat)
			sash.position = Vector3(0.0, 0.92, 0.0)
			_visual_root.add_child(sash)

			var head := _sphere(0.36, fox_mat)
			head.position = Vector3(0.0, 1.62, 0.04)
			_visual_root.add_child(head)

			var snout := _cyl(0.04, 0.14, 0.30, white_mat)
			snout.position = Vector3(0.0, 1.56, 0.36)
			snout.rotation.x = PI * 0.5
			_visual_root.add_child(snout)

			for side in [-1.0, 1.0]:
				var ear := _cyl(0.0, 0.11, 0.38, fox_mat)
				ear.position = Vector3(0.20 * side, 2.02, 0.04)
				ear.rotation.z = -0.24 * side
				_visual_root.add_child(ear)
				var eye := _sphere(0.065, _mat_unshaded(Color.html("#dc2626")))
				eye.position = Vector3(0.14 * side, 1.66, 0.34)
				_visual_root.add_child(eye)

			# Fan of 5 Glowing Golden Fox Tails
			var tail_fan := Node3D.new()
			tail_fan.position = Vector3(0.0, 0.92, -0.35)
			for i in range(5):
				var spread := (float(i) - 2.0) * 0.42
				var t_mesh := _sphere(0.24, fox_mat)
				t_mesh.position = Vector3(sin(spread) * 0.72, 0.25 + cos(spread) * 0.38, -0.38)
				t_mesh.scale = Vector3(0.55, 0.75, 1.6)
				t_mesh.rotation.y = -spread
				tail_fan.add_child(t_mesh)
			_visual_root.add_child(tail_fan)
			_anim_nodes.append(tail_fan)

		"jorogumo":
			# Venom Spider Yokai: segmented emerald abdomen + 6 articulated spider legs + glowing toxic eyes
			var abd := _sphere(0.58, main_mat)
			abd.position = Vector3(0.0, 0.92, -0.42)
			abd.scale = Vector3(0.95, 0.85, 1.25)
			_visual_root.add_child(abd)

			var thorax := _sphere(0.40, dark_mat)
			thorax.position = Vector3(0.0, 1.02, 0.24)
			_visual_root.add_child(thorax)

			for side in [-1.0, 1.0]:
				for row in [0, 1, 2]:
					var leg_p := Node3D.new()
					leg_p.position = Vector3(0.32 * side, 0.96, 0.22 - float(row) * 0.32)
					var seg1 := _cyl(0.055, 0.045, 0.72, dark_mat)
					seg1.position = Vector3(0.30 * side, 0.08, 0.0)
					seg1.rotation.z = -1.1 * side
					leg_p.add_child(seg1)
					var seg2 := _cyl(0.045, 0.02, 0.92, main_mat)
					seg2.position = Vector3(0.62 * side, -0.35, 0.0)
					seg2.rotation.z = 0.22 * side
					leg_p.add_child(seg2)
					_visual_root.add_child(leg_p)
					_anim_nodes.append(leg_p)

				var eye := _sphere(0.085, _mat_unshaded(Color.html("#4ade80")))
				eye.position = Vector3(0.14 * side, 1.12, 0.58)
				_visual_root.add_child(eye)

		"dogu":
			# Ancient Jomon Clay Golem (Dogu): wide goggle eyes, carved stone torso, floating rune arms!
			var stone_mat := _tint_mat(Color.html("#78716c"), 0.85, 0.1)
			var rune_mat := _mat_unshaded(Color.html("#38bdf8"))

			var torso := _cyl(0.58, 0.42, 1.18, stone_mat, 10)
			torso.position = Vector3(0.0, 0.95, 0.0)
			_visual_root.add_child(torso)

			var core := _sphere(0.18, rune_mat)
			core.position = Vector3(0.0, 1.12, 0.45)
			_visual_root.add_child(core)

			var head := _sphere(0.46, stone_mat)
			head.position = Vector3(0.0, 1.82, 0.0)
			head.scale = Vector3(1.15, 0.88, 0.92)
			_visual_root.add_child(head)

			var crown := _cyl(0.28, 0.38, 0.24, stone_mat, 8)
			crown.position = Vector3(0.0, 2.26, 0.0)
			_visual_root.add_child(crown)

			for side in [-1.0, 1.0]:
				# Iconic Dogu wide goggle eyes
				var goggle := _torus(0.10, 0.17, gold_mat)
				goggle.position = Vector3(0.20 * side, 1.84, 0.38)
				goggle.rotation.x = PI * 0.5
				_visual_root.add_child(goggle)
				var slit := _box(Vector3(0.18, 0.04, 0.04), rune_mat)
				slit.position = Vector3(0.20 * side, 1.84, 0.43)
				_visual_root.add_child(slit)

				# Floating stone arms
				var arm := _cyl(0.18, 0.12, 0.85, stone_mat, 8)
				arm.position = Vector3(0.82 * side, 1.18, 0.10)
				arm.rotation.z = -0.25 * side
				_visual_root.add_child(arm)
				_anim_nodes.append(arm)

		"akaoni_boss":
			# BOSS: Crimson Demon General with giant curved horns, lava pauldrons & colossal kanabo!
			_build_oni_warrior(_tint_mat(Color.html("#dc2626"), 0.35, 0.2, Color.html("#991b1b"), 0.25), gold_mat, dark_mat, eye_glow, true)

		"tengu_boss":
			# BOSS: Great Tengu Warlord with red tengu mask + long nose + huge feathered wings + war fan!
			var indigo_mat := _tint_mat(Color.html("#4338ca"), 0.4, 0.15)
			var wing_mat := _tint_mat(Color.html("#0f172a"), 0.6, 0.1)

			var body := _cyl(0.42, 0.60, 1.38, indigo_mat)
			body.position = Vector3(0.0, 0.92, 0.0)
			_visual_root.add_child(body)

			var sash := _cyl(0.46, 0.48, 0.22, gold_mat)
			sash.position = Vector3(0.0, 1.05, 0.0)
			_visual_root.add_child(sash)

			var head := _sphere(0.42, red_mat)
			head.position = Vector3(0.0, 1.88, 0.0)
			_visual_root.add_child(head)

			# Iconic Long Tengu Nose
			var nose := _cyl(0.055, 0.08, 0.52, red_mat)
			nose.position = Vector3(0.0, 1.84, 0.56)
			nose.rotation.x = PI * 0.5
			_visual_root.add_child(nose)

			# Pillbox Tokin Cap
			var tokin := _cyl(0.16, 0.18, 0.24, dark_mat)
			tokin.position = Vector3(0.0, 2.34, 0.08)
			_visual_root.add_child(tokin)

			for side in [-1.0, 1.0]:
				var eye := _sphere(0.08, eye_glow)
				eye.position = Vector3(0.16 * side, 1.94, 0.36)
				_visual_root.add_child(eye)

				# Huge Spread Feathered Wings!
				var wing_p := Node3D.new()
				wing_p.position = Vector3(0.32 * side, 1.48, -0.28)
				var wing_main := _box(Vector3(1.55, 0.85, 0.10), wing_mat)
				wing_main.position = Vector3(0.75 * side, 0.25, -0.15)
				wing_main.rotation.z = 0.28 * side
				wing_main.rotation.y = -0.35 * side
				wing_p.add_child(wing_main)
				var wing_tip := _box(Vector3(1.10, 0.45, 0.08), indigo_mat)
				wing_tip.position = Vector3(1.35 * side, 0.55, -0.25)
				wing_tip.rotation.z = 0.45 * side
				wing_p.add_child(wing_tip)
				_visual_root.add_child(wing_p)
				_anim_nodes.append(wing_p)

		"orochi_boss":
			# BOSS: Yamata-no-Orochi Phantom with coiled emerald dragon body & 3 horned serpent heads!
			var serpent_mat := _tint_mat(Color.html("#059669"), 0.30, 0.25, Color.html("#10b981"), 0.25)
			var coil1 := _torus(0.65, 0.98, serpent_mat)
			coil1.position = Vector3(0.0, 0.36, 0.0)
			_visual_root.add_child(coil1)
			var coil2 := _torus(0.45, 0.72, serpent_mat)
			coil2.position = Vector3(0.0, 0.86, 0.0)
			_visual_root.add_child(coil2)

			for idx in [-1, 0, 1]:
				var neck_p := Node3D.new()
				neck_p.position = Vector3(float(idx) * 0.42, 1.05, 0.12)
				var neck := _cyl(0.20, 0.26, 1.05 if idx == 0 else 0.88, serpent_mat)
				neck.position = Vector3(float(idx) * 0.18, 0.48, 0.18)
				neck.rotation.z = -float(idx) * 0.28
				neck.rotation.x = 0.22
				neck_p.add_child(neck)

				var h_pos := Vector3(float(idx) * 0.34, 1.02 if idx == 0 else 0.88, 0.34)
				var s_head := _box(Vector3(0.42, 0.34, 0.62), serpent_mat)
				s_head.position = h_pos
				neck_p.add_child(s_head)

				for side in [-1.0, 1.0]:
					var eye := _sphere(0.07, eye_glow)
					eye.position = h_pos + Vector3(0.16 * side, 0.08, 0.26)
					neck_p.add_child(eye)
					var horn := _cyl(0.0, 0.06, 0.42, gold_mat)
					horn.position = h_pos + Vector3(0.14 * side, 0.28, -0.10)
					horn.rotation.x = -0.35
					neck_p.add_child(horn)
				_visual_root.add_child(neck_p)
				_anim_nodes.append(neck_p)

		_:
			# Fallback Oni mesh
			_build_oni_warrior(main_mat, gold_mat, dark_mat, eye_glow, is_boss)

	# Status indicator ring (Petrify / Freeze / Stun)
	_status_mat = StandardMaterial3D.new()
	_status_mat.albedo_color = Color.html("#94a3b8")
	_status_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.82
	ring_mesh.outer_radius = 0.98
	ring_mesh.rings = 24
	ring_mesh.ring_segments = 8
	_status_ring = MeshInstance3D.new()
	_status_ring.mesh = ring_mesh
	_status_ring.material_override = _status_mat
	_status_ring.position = Vector3(0.0, 0.18, 0.0)
	_status_ring.scale = Vector3(1.0, 0.15, 1.0)
	_status_ring.visible = false
	add_child(_status_ring)

	var s: float = float(tpl["scale"])
	scale = Vector3(s, s, s)


func _build_oni_warrior(
	skin_mat: StandardMaterial3D,
	gold_mat: StandardMaterial3D,
	dark_mat: StandardMaterial3D,
	eye_glow: StandardMaterial3D,
	is_general: bool
) -> void:
	# Muscular Oni Torso + Tiger Loincloth + Legs + Arms + Horns + Kanabo Club
	var torso := _cyl(0.58, 0.44, 1.02, skin_mat, 14)
	torso.position = Vector3(0.0, 1.15, 0.0)
	_visual_root.add_child(torso)

	var loin := _cyl(0.48, 0.54, 0.42, gold_mat)
	loin.position = Vector3(0.0, 0.62, 0.0)
	_visual_root.add_child(loin)

	var belt := _torus(0.46, 0.53, dark_mat)
	belt.position = Vector3(0.0, 0.82, 0.0)
	_visual_root.add_child(belt)

	for side in [-1.0, 1.0]:
		var leg := _cyl(0.17, 0.14, 0.56, skin_mat)
		leg.position = Vector3(0.24 * side, 0.28, 0.0)
		_visual_root.add_child(leg)

		var arm_p := Node3D.new()
		arm_p.position = Vector3(0.62 * side, 1.48, 0.0)
		var pauldron := _sphere(0.24, dark_mat if not is_general else gold_mat)
		arm_p.add_child(pauldron)
		var arm := _cyl(0.15, 0.13, 0.72, skin_mat)
		arm.position = Vector3(0.05 * side, -0.34, 0.08)
		arm_p.add_child(arm)

		# Right-hand spiked iron Kanabo war club!
		if side > 0:
			var club := _cyl(0.18 if is_general else 0.13, 0.07, 1.45 if is_general else 1.15, dark_mat)
			club.position = Vector3(0.08, -0.58, 0.48)
			club.rotation.x = 1.25
			arm_p.add_child(club)
			var spike_ring := _torus(0.14, 0.22, gold_mat)
			spike_ring.position = Vector3(0.08, -0.45, 0.88)
			spike_ring.rotation.x = 1.25
			arm_p.add_child(spike_ring)

		_visual_root.add_child(arm_p)
		_anim_nodes.append(arm_p)

	var head := _sphere(0.44, skin_mat)
	head.position = Vector3(0.0, 1.92, 0.04)
	_visual_root.add_child(head)

	# Fierce eyes, brows & horns
	for side in [-1.0, 1.0]:
		var eye := _sphere(0.085, eye_glow)
		eye.position = Vector3(0.16 * side, 1.96, 0.40)
		_visual_root.add_child(eye)

		var brow := _box(Vector3(0.18, 0.05, 0.08), dark_mat)
		brow.position = Vector3(0.16 * side, 2.06, 0.41)
		brow.rotation.z = -0.32 * side
		_visual_root.add_child(brow)

		var horn := _cyl(0.0, 0.12 if is_general else 0.09, 0.78 if is_general else 0.52, gold_mat)
		horn.position = Vector3(0.26 * side, 2.42, 0.08)
		horn.rotation.z = -0.32 * side
		horn.rotation.x = 0.15
		_visual_root.add_child(horn)

		var fang := _cyl(0.0, 0.045, 0.14, _mat_unshaded(Color.WHITE))
		fang.position = Vector3(0.12 * side, 1.72, 0.42)
		_visual_root.add_child(fang)


func _process(delta: float) -> void:
	if dead or is_controlled():
		return
	_elapsed += delta
	if _visual_root != null:
		if template_id == "kasa" or template_id == "chochin":
			_visual_root.position.y = absf(sin(_elapsed * 5.2)) * 0.35
		else:
			_visual_root.position.y = sin(_elapsed * 4.0) * 0.06
	for idx in range(_anim_nodes.size()):
		var n := _anim_nodes[idx]
		if not is_instance_valid(n):
			continue
		var phase := _elapsed * 5.0 + float(idx) * 1.3
		if template_id == "tengu_boss":
			var sign_dir := -1.0 if idx == 0 else 1.0
			n.rotation.y = sign_dir * (0.25 + sin(_elapsed * 6.5) * 0.35)
		elif template_id == "jorogumo":
			n.rotation.z = sin(phase * 1.8) * 0.22
		else:
			n.rotation.x = sin(phase) * 0.18


func is_controlled() -> bool:
	return petrify_timer > 0.0 or freeze_timer > 0.0 or stun_timer > 0.0


func update_status_visuals(delta: float) -> void:
	if _status_ring == null:
		return
	if petrify_timer > 0.0:
		_set_all_tint(Color.html("#94a3b8"))
		_status_ring.visible = true
		_status_mat.albedo_color = Color.html("#f472b6")
		_status_ring.rotation.y += delta * 3.0
	elif freeze_timer > 0.0:
		_set_all_tint(Color.html("#67e8f9"))
		_status_ring.visible = true
		_status_mat.albedo_color = Color.html("#06b6d4")
	elif stun_timer > 0.0:
		_set_all_tint(Color.html("#fde047"))
		_status_ring.visible = true
		_status_mat.albedo_color = Color.html("#facc15")
	else:
		_restore_all_tint()
		_status_ring.visible = false


func _set_all_tint(col: Color) -> void:
	for m in _tint_mats:
		m.albedo_color = col


func _restore_all_tint() -> void:
	for i in range(_tint_mats.size()):
		_tint_mats[i].albedo_color = _orig_colors[i]


func clamp_to_arena() -> void:
	var limit: float = GameData.ARENA_RADIUS - 0.8
	var flat := Vector2(position.x, position.z)
	if flat.length() > limit:
		flat = flat.normalized() * limit
		position.x = flat.x
		position.z = flat.y


# ==================== HELPERS ====================
func _tint_mat(col: Color, rough: float = 0.5, metal: float = 0.0, emis: Color = Color.BLACK, emis_e: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = rough
	m.metallic = metal
	if emis_e > 0.0:
		m.emission_enabled = true
		m.emission = emis
		m.emission_energy_multiplier = emis_e
	_tint_mats.append(m)
	_orig_colors.append(col)
	return m


func _mat_unshaded(col: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m


func _cyl(top_r: float, bot_r: float, h: float, mat: Material, segs: int = 12) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top_r
	mesh.bottom_radius = bot_r
	mesh.height = h
	mesh.radial_segments = segs
	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	inst.material_override = mat
	return inst


func _sphere(r: float, mat: Material) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = r
	mesh.height = r * 2.0
	mesh.radial_segments = 14
	mesh.rings = 8
	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	inst.material_override = mat
	return inst


func _box(sz: Vector3, mat: Material) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = sz
	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	inst.material_override = mat
	return inst


func _torus(in_r: float, out_r: float, mat: Material) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = in_r
	mesh.outer_radius = out_r
	mesh.rings = 20
	mesh.ring_segments = 8
	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	inst.material_override = mat
	return inst
