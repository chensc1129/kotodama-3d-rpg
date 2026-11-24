class_name Shikigami3D
extends Node3D
## Stylized 3D Shikigami companions: Kitsune spirit fox, Maneki-neko lucky cat, and Raiju electric wolf.

var _visual: Node3D
var _tail_pivot: Node3D
var _orbit_node: Node3D
var _elapsed: float = 0.0


func _ready() -> void:
	_visual = Node3D.new()
	add_child(_visual)


func rebuild_mesh(player_pos: Vector3) -> void:
	for child in _visual.get_children():
		child.queue_free()

	_tail_pivot = null
	_orbit_node = null

	var sh_id: String = GameState.player.get("active_shikigami", "none")
	if sh_id == "none":
		visible = false
		return

	visible = true
	var cfg: Dictionary = GameData.get_shikigami(sh_id)
	var main_col := Color.html(cfg.get("color", "#f97316"))
	var main_mat := _mat(main_col, 0.38, 0.1, main_col, 0.25)
	var white_mat := _mat(Color.html("#fffbeb"), 0.45, 0.05)
	var dark_mat := _mat_unshaded(Color.html("#0f172a"))
	var pink_mat := _mat(Color.html("#fda4af"), 0.5, 0.0)
	var gold_mat := _mat(Color.html("#fbbf24"), 0.2, 0.8, Color.html("#f59e0b"), 0.35)

	if sh_id == "kitsune":
		# Cute 3D Spirit Fox (body, head, snout, big pointed fox ears, fluffy tail with white tip, foxfire wisps)
		var body := _sphere(0.28, main_mat)
		body.scale = Vector3(0.95, 0.85, 1.2)
		_visual.add_child(body)

		var chest := _sphere(0.20, white_mat)
		chest.position = Vector3(0.0, -0.02, 0.18)
		_visual.add_child(chest)

		var head := _sphere(0.26, main_mat)
		head.position = Vector3(0.0, 0.26, 0.22)
		_visual.add_child(head)

		var snout := _cyl(0.03, 0.10, 0.22, white_mat)
		snout.position = Vector3(0.0, 0.22, 0.44)
		snout.rotation.x = PI * 0.5
		_visual.add_child(snout)

		var nose := _sphere(0.035, dark_mat)
		nose.position = Vector3(0.0, 0.23, 0.55)
		_visual.add_child(nose)

		for side in [-1.0, 1.0]:
			var ear := _cyl(0.0, 0.09, 0.28, main_mat)
			ear.position = Vector3(0.15 * side, 0.50, 0.20)
			ear.rotation.z = -0.22 * side
			_visual.add_child(ear)

			var inner := _cyl(0.0, 0.05, 0.18, pink_mat)
			inner.position = Vector3(0.15 * side, 0.48, 0.25)
			inner.rotation.z = -0.22 * side
			_visual.add_child(inner)

			var eye := _sphere(0.042, dark_mat)
			eye.position = Vector3(0.11 * side, 0.30, 0.43)
			_visual.add_child(eye)

		_tail_pivot = Node3D.new()
		_tail_pivot.position = Vector3(0.0, 0.05, -0.28)
		var tail := _sphere(0.22, main_mat)
		tail.position = Vector3(0.0, 0.14, -0.22)
		tail.scale = Vector3(0.75, 0.85, 1.6)
		_tail_pivot.add_child(tail)
		var tip := _sphere(0.14, white_mat)
		tip.position = Vector3(0.0, 0.24, -0.46)
		_tail_pivot.add_child(tip)
		_visual.add_child(_tail_pivot)

		# Orbiting foxfire wisps
		_orbit_node = Node3D.new()
		var fire_mat := _mat_unshaded(Color.html("#fb923c"))
		for i in range(2):
			var a := float(i) * PI
			var wisp := _sphere(0.07, fire_mat)
			wisp.position = Vector3(cos(a) * 0.58, 0.2, sin(a) * 0.58)
			_orbit_node.add_child(wisp)
		_visual.add_child(_orbit_node)

	elif sh_id == "neko":
		# Adorable Maneki-neko Lucky Cat with red collar, golden bell, beckoning paw, and floating koban coin!
		var body := _cyl(0.24, 0.30, 0.44, white_mat)
		body.position = Vector3(0.0, -0.04, 0.0)
		_visual.add_child(body)

		var collar := _torus(0.22, 0.28, _mat(Color.html("#dc2626"), 0.4, 0.1))
		collar.position = Vector3(0.0, 0.18, 0.0)
		_visual.add_child(collar)

		var bell := _sphere(0.075, gold_mat)
		bell.position = Vector3(0.0, 0.14, 0.27)
		_visual.add_child(bell)

		var head := _sphere(0.29, white_mat)
		head.position = Vector3(0.0, 0.38, 0.02)
		head.scale = Vector3(1.08, 0.96, 0.95)
		_visual.add_child(head)

		for side in [-1.0, 1.0]:
			var ear := _cyl(0.0, 0.095, 0.22, white_mat)
			ear.position = Vector3(0.18 * side, 0.64, 0.02)
			ear.rotation.z = -0.30 * side
			_visual.add_child(ear)

			var ear_in := _cyl(0.0, 0.055, 0.14, pink_mat)
			ear_in.position = Vector3(0.18 * side, 0.62, 0.07)
			ear_in.rotation.z = -0.30 * side
			_visual.add_child(ear_in)

			var eye := _sphere(0.045, dark_mat)
			eye.position = Vector3(0.11 * side, 0.40, 0.27)
			_visual.add_child(eye)

			var cheek := _sphere(0.045, pink_mat)
			cheek.position = Vector3(0.17 * side, 0.33, 0.25)
			cheek.scale = Vector3(1.2, 0.6, 0.4)
			_visual.add_child(cheek)

		# Raised beckoning right paw
		_tail_pivot = Node3D.new()
		_tail_pivot.position = Vector3(0.26, 0.16, 0.14)
		var paw := _cyl(0.075, 0.08, 0.28, white_mat)
		paw.position = Vector3(0.0, 0.14, 0.04)
		paw.rotation.x = 0.25
		_tail_pivot.add_child(paw)
		_visual.add_child(_tail_pivot)

		# Floating Golden Koban Coin!
		_orbit_node = Node3D.new()
		var coin := _cyl(0.16, 0.16, 0.04, gold_mat)
		coin.position = Vector3(0.0, 0.85, 0.0)
		coin.rotation.x = PI * 0.5
		coin.scale = Vector3(0.75, 1.0, 1.25)
		_orbit_node.add_child(coin)
		_visual.add_child(_orbit_node)

	else:
		# Raiju: Sleek Electric Spirit Wolf with spiky cyan lightning mane & bolt tail!
		var dark_blue := _mat(Color.html("#0f172a"), 0.4, 0.3)
		var bolt_mat := _mat_unshaded(Color.html("#38bdf8"))

		var body := _sphere(0.28, main_mat)
		body.scale = Vector3(0.9, 0.85, 1.3)
		_visual.add_child(body)

		var head := _sphere(0.26, main_mat)
		head.position = Vector3(0.0, 0.25, 0.24)
		_visual.add_child(head)

		var snout := _box(Vector3(0.16, 0.13, 0.22), dark_blue)
		snout.position = Vector3(0.0, 0.21, 0.44)
		_visual.add_child(snout)

		for side in [-1.0, 1.0]:
			var ear := _cyl(0.0, 0.085, 0.30, dark_blue)
			ear.position = Vector3(0.15 * side, 0.48, 0.20)
			ear.rotation.z = -0.25 * side
			_visual.add_child(ear)

			var eye := _sphere(0.048, _mat_unshaded(Color.html("#fef08a")))
			eye.position = Vector3(0.11 * side, 0.29, 0.44)
			_visual.add_child(eye)

			var spike := _cyl(0.0, 0.07, 0.26, bolt_mat)
			spike.position = Vector3(0.24 * side, 0.18, 0.08)
			spike.rotation.z = -0.9 * side
			_visual.add_child(spike)

		_tail_pivot = Node3D.new()
		_tail_pivot.position = Vector3(0.0, 0.08, -0.32)
		var bolt_tail := _cyl(0.0, 0.10, 0.56, bolt_mat)
		bolt_tail.position = Vector3(0.0, 0.18, -0.20)
		bolt_tail.rotation.x = -0.75
		_tail_pivot.add_child(bolt_tail)
		_visual.add_child(_tail_pivot)

		_orbit_node = Node3D.new()
		var ring := _torus(0.48, 0.52, bolt_mat)
		ring.position = Vector3(0.0, 0.12, 0.0)
		_orbit_node.add_child(ring)
		_visual.add_child(_orbit_node)

	position = Vector3(player_pos.x - 1.35, 1.55, player_pos.z + 0.85)


func update_follow(delta: float, player_pos: Vector3, player_facing: float) -> void:
	if not visible:
		return
	_elapsed += delta
	var target := Vector3(
		player_pos.x - sin(player_facing) * 1.35 - 0.85,
		1.50 + sin(_elapsed * 4.5) * 0.22,
		player_pos.z - cos(player_facing) * 1.35 + 0.85
	)
	position = position.lerp(target, clampf(delta * 6.0, 0.0, 1.0))
	rotation.y = lerp_angle(rotation.y, player_facing, clampf(delta * 6.0, 0.0, 1.0))

	if _tail_pivot != null:
		_tail_pivot.rotation.y = sin(_elapsed * 8.0) * 0.35
		_tail_pivot.rotation.x = sin(_elapsed * 6.0) * 0.22
	if _orbit_node != null:
		_orbit_node.rotation.y = _elapsed * 3.0


func _mat(col: Color, rough: float = 0.5, metal: float = 0.0, emis: Color = Color.BLACK, emis_e: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = rough
	m.metallic = metal
	if emis_e > 0.0:
		m.emission_enabled = true
		m.emission = emis
		m.emission_energy_multiplier = emis_e
	return m


func _mat_unshaded(col: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m


func _cyl(top_r: float, bot_r: float, h: float, mat: Material) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top_r
	mesh.bottom_radius = bot_r
	mesh.height = h
	mesh.radial_segments = 12
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
	mesh.rings = 24
	mesh.ring_segments = 8
	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	inst.material_override = mat
	return inst
