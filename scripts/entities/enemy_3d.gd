class_name Enemy3D
extends Node3D
## Loads sculpted, textured .glb Japanese Yokai & Boss models with anime cel-shading,
## ink outlines, articulated animations, and shader-based status tinting (petrify/freeze/stun).

const ENEMY_MODELS: Dictionary = {
	"chochin": "res://assets/models/enemy_chochin.glb",
	"kasa": "res://assets/models/enemy_kasa.glb",
	"aooni": "res://assets/models/enemy_aooni.glb",
	"kyubi": "res://assets/models/enemy_kyubi.glb",
	"jorogumo": "res://assets/models/enemy_jorogumo.glb",
	"dogu": "res://assets/models/enemy_dogu.glb",
	"akaoni_boss": "res://assets/models/enemy_akaoni_boss.glb",
	"tengu_boss": "res://assets/models/enemy_tengu_boss.glb",
	"orochi_boss": "res://assets/models/enemy_orochi_boss.glb",
}

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
var primary_color: Color = Color.WHITE

var _visual_root: Node3D
var _anim_nodes: Array[Node3D] = []
var _toon_mats: Array[ShaderMaterial] = []
var _status_ring: MeshInstance3D
var _status_mat: StandardMaterial3D
var _elapsed: float = 0.0

var _hit_flash_timer: float = 0.0
var _hit_flash_max: float = 0.12
var _stagger_timer: float = 0.0
var _recoil_scale: Vector3 = Vector3.ONE
var _recoil_tilt: Vector3 = Vector3.ZERO


func setup(tpl: Dictionary, p_is_boss: bool, wave_num: int, is_hard: bool) -> void:
	enemy_name = tpl["name"]
	template_id = tpl["id"]
	is_boss = p_is_boss
	primary_color = Color.html(tpl["color"])
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
	var model_path: String = ENEMY_MODELS.get(template_id, ENEMY_MODELS["aooni"])
	var packed: PackedScene = load(model_path) as PackedScene
	var rim_col := primary_color.lerp(Color.WHITE, 0.4)

	if packed != null:
		var inst := packed.instantiate()
		add_child(inst)
		var outline_w := 0.018 if is_boss else 0.014
		_toon_mats = ToonMaterialHelper.apply_anime_toon(inst, outline_w, rim_col, 0.42)
		_visual_root = inst.find_child("VisualRoot", true, false) as Node3D
		if _visual_root == null:
			_visual_root = inst as Node3D

		for idx in range(8):
			var part := inst.find_child("AnimPart_%d" % idx, true, false) as Node3D
			if part != null:
				_anim_nodes.append(part)

	# Status indicator ring (Petrify / Freeze / Stun)
	_status_mat = StandardMaterial3D.new()
	_status_mat.albedo_color = Color.html("#94a3b8")
	_status_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.85
	ring_mesh.outer_radius = 1.02
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


func trigger_hit_react(knock_dir: Vector3, heavy: bool = false) -> void:
	_hit_flash_max = 0.14 if heavy else 0.10
	_hit_flash_timer = _hit_flash_max
	var stagger_dur := (0.14 if is_boss else 0.25) if heavy else (0.06 if is_boss else 0.14)
	_stagger_timer = maxf(_stagger_timer, stagger_dur)
	_recoil_scale = Vector3(1.34, 0.68, 1.34) if heavy else Vector3(1.20, 0.82, 1.20)

	if knock_dir.length_squared() > 0.001:
		var local_dir := knock_dir.normalized().rotated(Vector3.UP, -rotation.y)
		var tilt_amp := (0.28 if is_boss else 0.44) if heavy else (0.16 if is_boss else 0.26)
		_recoil_tilt = Vector3(local_dir.z * tilt_amp, 0.0, -local_dir.x * tilt_amp)
	else:
		_recoil_tilt = Vector3(-0.30 if heavy else -0.18, 0.0, 0.0)

	_set_hit_flash(1.0)
	if _visual_root != null:
		_visual_root.scale = _recoil_scale
		_visual_root.rotation = _recoil_tilt


func is_staggered() -> bool:
	return _stagger_timer > 0.0


func _process(delta: float) -> void:
	if dead:
		return

	# Always update hit-flash, stagger & elastic squash-recoil springs
	if _stagger_timer > 0.0:
		_stagger_timer = maxf(0.0, _stagger_timer - delta)

	if _hit_flash_timer > 0.0:
		_hit_flash_timer = maxf(0.0, _hit_flash_timer - delta)
		var ratio := _hit_flash_timer / maxf(0.001, _hit_flash_max)
		# Hold full white for first ~45% of flash for snappy anime impact readability
		var flash_val := 1.0 if ratio > 0.55 else (ratio / 0.55)
		_set_hit_flash(flash_val)

	if _visual_root != null:
		var spring := clampf(delta * 15.0, 0.0, 1.0)
		_recoil_scale = _recoil_scale.lerp(Vector3.ONE, spring)
		_recoil_tilt = _recoil_tilt.lerp(Vector3.ZERO, spring)
		_visual_root.scale = _recoil_scale
		_visual_root.rotation = _recoil_tilt

	if is_controlled():
		return

	_elapsed += delta
	if _visual_root != null:
		if template_id == "kasa" or template_id == "chochin":
			_visual_root.position.y = absf(sin(_elapsed * 5.2)) * 0.35
		elif template_id == "dogu" or template_id == "kyubi":
			_visual_root.position.y = sin(_elapsed * 3.4) * 0.14
		else:
			_visual_root.position.y = sin(_elapsed * 4.0) * 0.06

	for idx in range(_anim_nodes.size()):
		var n := _anim_nodes[idx]
		if not is_instance_valid(n):
			continue
		var phase := _elapsed * 5.0 + float(idx) * 1.3
		if template_id == "tengu_boss":
			var sign_dir := -1.0 if idx == 0 else 1.0
			n.rotation.y = sign_dir * (0.22 + sin(_elapsed * 6.5) * 0.36)
		elif template_id == "jorogumo":
			n.rotation.z = sin(phase * 1.9) * 0.24
			n.rotation.y = cos(phase * 1.9) * 0.10
		elif template_id == "chochin":
			n.rotation.z = sin(_elapsed * 7.0) * 0.28
			n.rotation.x = sin(_elapsed * 4.2) * 0.18
		elif template_id == "kasa":
			var s_dir := -1.0 if idx == 0 else 1.0
			n.rotation.z = s_dir * (0.18 + sin(_elapsed * 7.5 + float(idx) * PI) * 0.32)
		elif template_id == "kyubi":
			n.rotation.y = sin(_elapsed * 3.2) * 0.16
			n.rotation.x = sin(_elapsed * 2.4) * 0.08
		elif template_id == "orochi_boss":
			n.rotation.y = sin(_elapsed * 3.5 + float(idx) * 2.1) * 0.24
			n.rotation.x = cos(_elapsed * 4.4 + float(idx) * 1.4) * 0.16
		else:
			n.rotation.x = sin(phase) * 0.22


func is_controlled() -> bool:
	return petrify_timer > 0.0 or freeze_timer > 0.0 or stun_timer > 0.0


func update_status_visuals(delta: float) -> void:
	if _status_ring == null:
		return
	if petrify_timer > 0.0:
		_set_status_shader(Color.html("#94a3b8"), 0.72)
		_status_ring.visible = true
		_status_mat.albedo_color = Color.html("#f472b6")
		_status_ring.rotation.y += delta * 3.0
	elif freeze_timer > 0.0:
		_set_status_shader(Color.html("#67e8f9"), 0.65)
		_status_ring.visible = true
		_status_mat.albedo_color = Color.html("#06b6d4")
	elif stun_timer > 0.0:
		_set_status_shader(Color.html("#fde047"), 0.55)
		_status_ring.visible = true
		_status_mat.albedo_color = Color.html("#facc15")
	else:
		_set_status_shader(Color.WHITE, 0.0)
		_status_ring.visible = false


func _set_status_shader(col: Color, mix_val: float) -> void:
	for sm in _toon_mats:
		sm.set_shader_parameter("status_tint", col)
		sm.set_shader_parameter("status_mix", mix_val)


func _set_hit_flash(val: float) -> void:
	for sm in _toon_mats:
		sm.set_shader_parameter("hit_flash", val)


func clamp_to_arena() -> void:
	var limit: float = GameData.ARENA_RADIUS - 0.8
	var flat := Vector2(position.x, position.z)
	if flat.length() > limit:
		flat = flat.normalized() * limit
		position.x = flat.x
		position.z = flat.y
