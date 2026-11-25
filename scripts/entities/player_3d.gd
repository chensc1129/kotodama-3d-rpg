class_name Player3D
extends Node3D
## Loads sculpted anime-stylized .glb hero models with custom cel-shading + ink outlines,
## dynamic weapon blade/aura sync, 3D crescent slash arc, and articulated animations.

const HERO_MODELS: Dictionary = {
	"sakura": "res://assets/models/hero_sakura.glb",
	"kickboxer": "res://assets/models/hero_kickboxer.glb",
	"swordsman": "res://assets/models/hero_swordsman.glb",
	"raijin": "res://assets/models/hero_raijin.glb",
	"yukionna": "res://assets/models/hero_yukionna.glb",
}

const GRAVITY: float = 28.5
const JUMP_FORCE: float = 11.6

var facing: float = PI
var slash_anim_timer: float = 0.0
var kick_anim_timer: float = 0.0
var vertical_velocity: float = 0.0
var is_grounded: bool = true

var _current_ground_y: float = 0.0
var _slash_step: int = 1
var _walk_phase: float = 0.0
var _elapsed: float = 0.0
var _punch_scale: Vector3 = Vector3.ONE

var _visual_root: Node3D
var _body_pivot: Node3D
var _head_pivot: Node3D
var _left_arm: Node3D
var _right_arm: Node3D
var _weapon_pivot: Node3D
var _left_leg: Node3D
var _right_leg: Node3D
var _scarf_node: Node3D
var _orbit_group: Node3D
var _aura_mesh: MeshInstance3D
var _slash_arc_mesh: MeshInstance3D
var _slash_arc_mat: StandardMaterial3D
var _slash_core_mesh: MeshInstance3D
var _slash_core_mat: StandardMaterial3D
var _slash_base_color: Color = Color.WHITE
var _name_label: Label3D


func _ready() -> void:
	_visual_root = Node3D.new()
	_visual_root.name = "VisualRoot"
	add_child(_visual_root)

	_name_label = Label3D.new()
	_name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_name_label.no_depth_test = false
	_name_label.font_size = 36
	_name_label.outline_size = 10
	_name_label.modulate = Color.html("#fde68a")
	_name_label.outline_modulate = Color.html("#0f172a")
	_name_label.position = Vector3(0.0, 3.15, 0.0)
	_name_label.pixel_size = 0.0085
	if ResourceLoader.exists("res://assets/fonts/noto_cjk_game.otf"):
		_name_label.font = load("res://assets/fonts/noto_cjk_game.otf")
	add_child(_name_label)


func trigger_jump(force_mult: float = 1.0) -> bool:
	if not is_grounded:
		return false
	is_grounded = false
	vertical_velocity = JUMP_FORCE * force_mult
	_punch_scale = Vector3(0.88, 1.18, 0.88)
	if _body_pivot != null:
		_body_pivot.scale = _punch_scale
	return true


func launch_upward(vy: float) -> void:
	is_grounded = false
	vertical_velocity = maxf(vertical_velocity, vy)
	_punch_scale = Vector3(0.84, 1.26, 0.84)
	if _body_pivot != null:
		_body_pivot.scale = _punch_scale


func reset_vertical_state(ground_y: float = 0.0) -> void:
	_current_ground_y = ground_y
	position.y = ground_y
	vertical_velocity = 0.0
	is_grounded = true


func update_vertical_physics(delta: float, ground_y: float = 0.0) -> bool:
	_current_ground_y = ground_y
	if is_grounded:
		# Step off a steep drop-off into free-fall
		if ground_y < position.y - 0.55:
			is_grounded = false
			vertical_velocity = -0.5
		else:
			position.y = lerpf(position.y, ground_y, clampf(delta * 20.0, 0.0, 1.0))
			vertical_velocity = 0.0
			return false

	vertical_velocity -= GRAVITY * delta
	position.y += vertical_velocity * delta
	if position.y <= ground_y and vertical_velocity <= 0.0:
		position.y = ground_y
		vertical_velocity = 0.0
		is_grounded = true
		_punch_scale = Vector3(1.16, 0.84, 1.16)
		if _body_pivot != null:
			_body_pivot.scale = _punch_scale
		return true
	return false


func trigger_slash(step: int) -> void:
	_slash_step = clampi(step, 1, 3)
	var cid: String = String(GameState.player.get("char_id", "sakura"))
	if cid == "raijin":
		slash_anim_timer = 0.21 if _slash_step == 3 else 0.155
	elif cid == "kickboxer":
		slash_anim_timer = 0.34 if _slash_step == 3 else 0.26
	elif cid == "swordsman":
		slash_anim_timer = 0.34 if _slash_step == 3 else 0.27
	elif cid == "yukionna":
		slash_anim_timer = 0.34 if _slash_step == 3 else 0.26
	else:
		slash_anim_timer = 0.30 if _slash_step == 3 else 0.23


func trigger_hit_punch(heavy: bool = false) -> void:
	_punch_scale = Vector3(1.16, 0.88, 1.16) if heavy else Vector3(1.09, 0.93, 1.09)
	if _body_pivot != null:
		_body_pivot.scale = _punch_scale


func rebuild_mesh() -> void:
	for child in _visual_root.get_children():
		child.queue_free()

	_body_pivot = null
	_head_pivot = null
	_left_arm = null
	_right_arm = null
	_weapon_pivot = null
	_left_leg = null
	_right_leg = null
	_scarf_node = null
	_orbit_group = null
	_slash_arc_mesh = null
	_slash_core_mesh = null

	var char_cfg: Dictionary = GameData.get_character(GameState.player["char_id"])
	var eq_w: Dictionary = GameData.get_equipment(GameState.player["equipped"].get("weapon", "w1"))
	var eq_a: Dictionary = GameData.get_equipment(GameState.player["equipped"].get("armor", "a1"))
	if eq_w.is_empty():
		eq_w = GameData.EQUIPMENT_LIST[0]
	if eq_a.is_empty():
		eq_a = GameData.EQUIPMENT_LIST[5]

	var cid: String = char_cfg["id"]
	var blade_col := Color.html(eq_w.get("blade_color", "#d6d3d1"))
	var aura_col := Color.html(eq_a.get("aura_color", "#94a3b8"))
	var rim_col := Color.html(char_cfg["color_primary"]).lerp(Color.WHITE, 0.55)
	_slash_base_color = Color.html(char_cfg["color_primary"]).lerp(blade_col, 0.5)

	# 1. Ground Armor Aura Ring
	_aura_mesh = _build_aura_ring(aura_col)
	_visual_root.add_child(_aura_mesh)

	# 2. Instantiate Sculpted Anime .glb Hero Model
	var model_path: String = HERO_MODELS.get(cid, HERO_MODELS["sakura"])
	var packed: PackedScene = load(model_path) as PackedScene
	if packed != null:
		var inst := packed.instantiate()
		_visual_root.add_child(inst)

		# Apply custom Anime Cel-Shading + Crisp Dark Ink Outlines
		ToonMaterialHelper.apply_anime_toon(inst, 0.013, rim_col, 0.48)

		# Bind named animation pivots from glTF hierarchy
		_body_pivot = inst.find_child("BodyPivot", true, false) as Node3D
		_head_pivot = inst.find_child("HeadPivot", true, false) as Node3D
		_left_arm = inst.find_child("LeftArm", true, false) as Node3D
		_right_arm = inst.find_child("RightArm", true, false) as Node3D
		_weapon_pivot = inst.find_child("WeaponPivot", true, false) as Node3D
		_left_leg = inst.find_child("LeftLeg", true, false) as Node3D
		_right_leg = inst.find_child("RightLeg", true, false) as Node3D
		_scarf_node = inst.find_child("ScarfNode", true, false) as Node3D
		_orbit_group = inst.find_child("OrbitGroup", true, false) as Node3D

		if _weapon_pivot != null:
			_weapon_pivot.rotation.x = 0.85

		# Sync equipped weapon blade color & glowing energy!
		var blade_node := inst.find_child("WeaponBlade", true, false) as MeshInstance3D
		if blade_node != null and blade_node.mesh != null and blade_node.mesh.get_surface_count() > 0:
			var bm := blade_node.get_surface_override_material(0) as ShaderMaterial
			if bm != null:
				bm.set_shader_parameter("albedo_color", blade_col)
				bm.set_shader_parameter("emission_color", blade_col)
				bm.set_shader_parameter("emission_energy", 0.65)
				bm.set_shader_parameter("metallic_val", 0.85)
				bm.set_shader_parameter("roughness_val", 0.16)

	# 3. 3D Dual-Layer Glowing Crescent Slash Arc VFX
	_build_slash_arc(_slash_base_color)

	update_name_badge()


func _build_aura_ring(aura_col: Color) -> MeshInstance3D:
	var torus := TorusMesh.new()
	torus.inner_radius = 0.74
	torus.outer_radius = 0.90
	torus.rings = 36
	torus.ring_segments = 8
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(aura_col.r, aura_col.g, aura_col.b, 0.68)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var inst := MeshInstance3D.new()
	inst.mesh = torus
	inst.material_override = mat
	inst.position = Vector3(0.0, 0.04, 0.0)
	inst.scale = Vector3(1.0, 0.08, 1.0)
	return inst


func _build_slash_arc(blade_col: Color) -> void:
	var parent_n: Node3D = _body_pivot if _body_pivot != null else _visual_root

	# Outer wide energy crescent
	var torus := TorusMesh.new()
	torus.inner_radius = 1.05
	torus.outer_radius = 1.92
	torus.rings = 32
	torus.ring_segments = 6
	_slash_arc_mat = StandardMaterial3D.new()
	_slash_arc_mat.albedo_color = Color(blade_col.r, blade_col.g, blade_col.b, 0.0)
	_slash_arc_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_slash_arc_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_slash_arc_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_slash_arc_mesh = MeshInstance3D.new()
	_slash_arc_mesh.mesh = torus
	_slash_arc_mesh.material_override = _slash_arc_mat
	_slash_arc_mesh.position = Vector3(0.0, 1.25, 0.55)
	_slash_arc_mesh.scale = Vector3(1.0, 0.07, 1.0)
	_slash_arc_mesh.visible = false
	parent_n.add_child(_slash_arc_mesh)

	# Razor-bright white-hot inner edge flash
	var core_torus := TorusMesh.new()
	core_torus.inner_radius = 1.48
	core_torus.outer_radius = 1.88
	core_torus.rings = 32
	core_torus.ring_segments = 6
	_slash_core_mat = StandardMaterial3D.new()
	_slash_core_mat.albedo_color = Color(1.0, 0.98, 0.90, 0.0)
	_slash_core_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_slash_core_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_slash_core_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_slash_core_mesh = MeshInstance3D.new()
	_slash_core_mesh.mesh = core_torus
	_slash_core_mesh.material_override = _slash_core_mat
	_slash_core_mesh.position = Vector3(0.0, 1.25, 0.55)
	_slash_core_mesh.scale = Vector3(1.0, 0.05, 1.0)
	_slash_core_mesh.visible = false
	parent_n.add_child(_slash_core_mesh)


func update_name_badge() -> void:
	if _name_label == null:
		return
	var char_cfg: Dictionary = GameData.get_character(GameState.player["char_id"])
	_name_label.text = "%s\nLv.%d・%s" % [GameState.player["name"], int(GameState.player["level"]), char_cfg["name"]]


func update_animations(delta: float, is_moving: bool, is_sprinting: bool = false) -> void:
	_elapsed += delta
	if slash_anim_timer > 0.0:
		slash_anim_timer = maxf(0.0, slash_anim_timer - delta)
	if kick_anim_timer > 0.0:
		kick_anim_timer = maxf(0.0, kick_anim_timer - delta)

	_visual_root.rotation.y = facing

	if _aura_mesh != null:
		_aura_mesh.rotation.y = _elapsed * (3.2 if is_sprinting else 1.8)
		# Keep aura ring hugging the exact terrain surface below the hero!
		_aura_mesh.position.y = 0.04 + (_current_ground_y - position.y)

	if _orbit_group != null:
		var cid: String = GameState.player["char_id"]
		if cid == "raijin":
			_orbit_group.rotation.z = _elapsed * 2.2
		else:
			_orbit_group.rotation.y = _elapsed * 1.9

	if _scarf_node != null:
		var scarf_base := 0.62 if is_sprinting else (0.35 if is_moving else 0.08)
		_scarf_node.rotation.x = scarf_base + sin(_elapsed * (12.0 if is_sprinting else 7.5)) * 0.14

	if _body_pivot == null:
		return

	# Impact hit-punch / jump-land squash recovery
	_punch_scale = _punch_scale.lerp(Vector3.ONE, clampf(delta * 15.0, 0.0, 1.0))
	_body_pivot.scale = _punch_scale

	# Subtle head life motion
	if _head_pivot != null:
		_head_pivot.rotation.z = sin(_elapsed * 2.4) * 0.035

	# Vertical body bounce / kick jump / sprint forward lean
	if kick_anim_timer > 0.0:
		var kt := kick_anim_timer / 0.5
		_body_pivot.position.y = sin(kt * PI) * 1.45
		_body_pivot.rotation.x = -0.35
	elif not is_grounded:
		_body_pivot.position.y = lerpf(_body_pivot.position.y, 0.0, clampf(delta * 12.0, 0.0, 1.0))
		var air_lean := 0.22 if vertical_velocity > 0.0 else 0.10
		_body_pivot.rotation.x = lerpf(_body_pivot.rotation.x, air_lean, clampf(delta * 10.0, 0.0, 1.0))
	else:
		var bounce_freq := 15.5 if is_sprinting else (10.0 if is_moving else 3.2)
		var bounce_amp := 0.09 if is_sprinting else (0.06 if is_moving else 0.03)
		_body_pivot.position.y = sin(_elapsed * bounce_freq) * bounce_amp
		var target_lean := 0.26 if (slash_anim_timer > 0.0 or is_sprinting) else (0.14 if is_moving else 0.0)
		_body_pivot.rotation.x = lerpf(_body_pivot.rotation.x, target_lean, clampf(delta * 12.0, 0.0, 1.0))

	# Leg & Arm Locomotion
	if not is_grounded and kick_anim_timer <= 0.0:
		# Crisp mid-air jump tuck pose
		var smooth_air := clampf(delta * 12.0, 0.0, 1.0)
		if _left_leg != null and _right_leg != null:
			_left_leg.rotation.x = lerpf(_left_leg.rotation.x, -0.52, smooth_air)
			_right_leg.rotation.x = lerpf(_right_leg.rotation.x, 0.38, smooth_air)
		if _left_arm != null:
			_left_arm.rotation.x = lerpf(_left_arm.rotation.x, -0.55, smooth_air)
		if _right_arm != null and slash_anim_timer <= 0.0:
			_right_arm.rotation.x = lerpf(_right_arm.rotation.x, -0.45, smooth_air)
			_right_arm.rotation.z = lerpf(_right_arm.rotation.z, 0.25, smooth_air)
	elif is_moving and kick_anim_timer <= 0.0:
		_walk_phase += delta * (21.0 if is_sprinting else 14.0)
		var swing := sin(_walk_phase)
		var amp := 0.92 if is_sprinting else 0.65
		if _left_leg != null and _right_leg != null:
			_left_leg.rotation.x = swing * amp
			_right_leg.rotation.x = -swing * amp
		if _left_arm != null:
			_left_arm.rotation.x = -swing * (0.78 if is_sprinting else 0.55)
		if _right_arm != null and slash_anim_timer <= 0.0:
			_right_arm.rotation.x = swing * (0.58 if is_sprinting else 0.40) - 0.25
			_right_arm.rotation.z = 0.08
	elif kick_anim_timer > 0.0:
		if _right_leg != null and _left_leg != null:
			_right_leg.rotation.x = -1.35
			_left_leg.rotation.x = 0.55
	else:
		var smooth := clampf(delta * 12.0, 0.0, 1.0)
		if _left_leg != null and _right_leg != null:
			_left_leg.rotation.x = lerpf(_left_leg.rotation.x, 0.0, smooth)
			_right_leg.rotation.x = lerpf(_right_leg.rotation.x, 0.0, smooth)
		if _left_arm != null:
			_left_arm.rotation.x = lerpf(_left_arm.rotation.x, sin(_elapsed * 3.0) * 0.06, smooth)
		if _right_arm != null and slash_anim_timer <= 0.0:
			_right_arm.rotation.x = lerpf(_right_arm.rotation.x, -0.25, smooth)
			_right_arm.rotation.z = lerpf(_right_arm.rotation.z, 0.12, smooth)

	# Character-Exclusive 3-Hit Combo Animation + Tailored Crescent Slash Arc
	if slash_anim_timer > 0.0:
		var cid: String = String(GameState.player.get("char_id", "sakura"))
		var max_t := 0.30 if _slash_step == 3 else 0.23
		if cid == "raijin":
			max_t = 0.21 if _slash_step == 3 else 0.155
		elif cid == "kickboxer" or cid == "swordsman" or cid == "yukionna":
			max_t = 0.34 if _slash_step == 3 else 0.27
		var p := clampf(1.0 - (slash_anim_timer / max_t), 0.0, 1.0)
		var ease_p := 1.0 - pow(1.0 - p, 2.5)
		var show_blade_arc := true
		var arc_scale_mult := 1.0

		if cid == "kickboxer":
			# Authentic Martial-Arts Kicks: Left High Whip Kick -> Right Roundhouse -> 360° Leaping Hurricane Kick!
			show_blade_arc = false
			if _slash_step == 1:
				if _left_leg != null:
					_left_leg.rotation.x = lerpf(0.45, -1.65, ease_p)
				if _right_leg != null:
					_right_leg.rotation.x = 0.28
				_body_pivot.rotation.y = lerpf(0.35, -0.55, ease_p)
				_body_pivot.rotation.x = -0.22 * sin(p * PI)
			elif _slash_step == 2:
				if _right_leg != null:
					_right_leg.rotation.x = lerpf(0.50, -1.75, ease_p)
				if _left_leg != null:
					_left_leg.rotation.x = 0.30
				_body_pivot.rotation.y = lerpf(-0.55, 0.72, ease_p)
				_body_pivot.rotation.x = -0.26 * sin(p * PI)
			else:
				_body_pivot.position.y = sin(p * PI) * 1.15
				_body_pivot.rotation.y = ease_p * TAU
				_body_pivot.rotation.x = -0.34
				if _right_leg != null:
					_right_leg.rotation.x = -1.55
				if _left_leg != null:
					_left_leg.rotation.x = 0.65
			if _left_arm != null:
				_left_arm.rotation.x = -0.95
			if _right_arm != null:
				_right_arm.rotation.x = -0.95

		elif cid == "yukionna":
			# Graceful Arcane Sleeve-Cast: Left Sleeve Sweep -> Right Sleeve Flourish -> Floating Frost Lotus Bloom!
			show_blade_arc = false
			if _slash_step == 1:
				if _left_arm != null:
					_left_arm.rotation.x = lerpf(0.35, -1.55, ease_p)
					_left_arm.rotation.z = lerpf(0.1, -0.75, ease_p)
				_body_pivot.rotation.y = lerpf(-0.28, 0.25, ease_p)
			elif _slash_step == 2:
				if _right_arm != null:
					_right_arm.rotation.x = lerpf(0.35, -1.65, ease_p)
					_right_arm.rotation.z = lerpf(-0.1, 0.75, ease_p)
				_body_pivot.rotation.y = lerpf(0.28, -0.25, ease_p)
			else:
				_body_pivot.position.y = sin(p * PI) * 0.58
				_body_pivot.rotation.x = -0.14 * sin(p * PI)
				if _left_arm != null:
					_left_arm.rotation.x = lerpf(-0.4, -1.75, ease_p)
					_left_arm.rotation.z = lerpf(0.1, -0.95, ease_p)
				if _right_arm != null:
					_right_arm.rotation.x = lerpf(-0.4, -1.75, ease_p)
					_right_arm.rotation.z = lerpf(-0.1, 0.95, ease_p)

		elif cid == "raijin":
			# Hyper-Fast Low-Crouch Ninja Dual-Blade Flurry!
			arc_scale_mult = 0.88
			_body_pivot.rotation.x = 0.36
			if _slash_step == 1:
				if _left_arm != null:
					_left_arm.rotation.x = lerpf(-1.6, 1.15, ease_p)
				if _right_arm != null:
					_right_arm.rotation.x = -0.85
				_body_pivot.rotation.y = lerpf(0.55, -0.55, ease_p)
			elif _slash_step == 2:
				if _right_arm != null:
					_right_arm.rotation.x = lerpf(-1.75, 1.25, ease_p)
				if _left_arm != null:
					_left_arm.rotation.x = -0.85
				_body_pivot.rotation.y = lerpf(-0.55, 0.55, ease_p)
			else:
				if _right_arm != null:
					_right_arm.rotation.x = lerpf(-2.1, 1.35, ease_p)
				if _left_arm != null:
					_left_arm.rotation.x = lerpf(-2.1, 1.35, ease_p)
				_body_pivot.rotation.y = ease_p * TAU * 1.25

		elif cid == "swordsman":
			# Heavy Two-Handed Iaido Flame Katana
			arc_scale_mult = 1.28
			if _right_arm != null:
				if _slash_step == 1:
					_right_arm.rotation.x = lerpf(-2.05, 1.25, ease_p)
					_right_arm.rotation.z = lerpf(0.85, -0.68, ease_p)
					_body_pivot.rotation.y = lerpf(-0.58, 0.58, ease_p)
				elif _slash_step == 2:
					_right_arm.rotation.x = lerpf(1.05, -1.95, ease_p)
					_right_arm.rotation.z = lerpf(-0.78, 0.88, ease_p)
					_body_pivot.rotation.y = lerpf(0.58, -0.58, ease_p)
				else:
					_right_arm.rotation.x = lerpf(-2.55, 1.55, ease_p)
					_right_arm.rotation.z = 0.0
					_body_pivot.rotation.y = ease_p * TAU
			if _left_arm != null:
				_left_arm.rotation.x = -1.05

		else:
			# Sakura: Graceful Kagura Petal-Dance Blade + Light Finishing Hop
			arc_scale_mult = 1.08
			if _right_arm != null:
				if _slash_step == 1:
					_right_arm.rotation.x = lerpf(-1.75, 1.05, ease_p)
					_right_arm.rotation.z = lerpf(0.75, -0.55, ease_p)
					_body_pivot.rotation.y = lerpf(-0.45, 0.45, ease_p)
				elif _slash_step == 2:
					_right_arm.rotation.x = lerpf(0.85, -1.65, ease_p)
					_right_arm.rotation.z = lerpf(-0.68, 0.78, ease_p)
					_body_pivot.rotation.y = lerpf(0.45, -0.45, ease_p)
				else:
					_body_pivot.position.y = sin(p * PI) * 0.48
					_right_arm.rotation.x = lerpf(-2.35, 1.35, ease_p)
					_right_arm.rotation.z = 0.0
					_body_pivot.rotation.y = ease_p * TAU

		if _weapon_pivot != null:
			_weapon_pivot.rotation.x = 1.75 if show_blade_arc else 0.85
		if _slash_arc_mesh != null and _slash_arc_mat != null:
			if show_blade_arc:
				var arc_col := Color.html("#fbbf24") if _slash_step == 3 else _slash_base_color
				var tilt_z := 0.38 if _slash_step == 1 else (-0.38 if _slash_step == 2 else 0.08)
				var sc := (1.55 if _slash_step == 3 else 1.12) * arc_scale_mult * (0.78 + ease_p * 0.62)
				var alpha_val := clampf((1.0 - p) * 1.15, 0.0, 0.94)
				_slash_arc_mesh.visible = true
				_slash_arc_mesh.rotation.z = tilt_z
				_slash_arc_mesh.rotation.y = ease_p * 3.4
				_slash_arc_mesh.scale = Vector3(sc, 0.085, sc)
				_slash_arc_mat.albedo_color = Color(arc_col.r, arc_col.g, arc_col.b, alpha_val)
				if _slash_core_mesh != null and _slash_core_mat != null:
					_slash_core_mesh.visible = true
					_slash_core_mesh.rotation.z = tilt_z
					_slash_core_mesh.rotation.y = ease_p * 3.4
					_slash_core_mesh.scale = Vector3(sc * 1.03, 0.055, sc * 1.03)
					_slash_core_mat.albedo_color = Color(1.0, 0.98, 0.92, clampf((1.0 - p * 1.25) * 0.98, 0.0, 0.98))
			else:
				_slash_arc_mesh.visible = false
				if _slash_core_mesh != null:
					_slash_core_mesh.visible = false
	else:
		_body_pivot.rotation.y = lerpf(_body_pivot.rotation.y, 0.0, clampf(delta * 14.0, 0.0, 1.0))
		if _weapon_pivot != null:
			_weapon_pivot.rotation.x = lerpf(_weapon_pivot.rotation.x, 0.85, clampf(delta * 12.0, 0.0, 1.0))
		if _slash_arc_mesh != null:
			_slash_arc_mesh.visible = false
		if _slash_core_mesh != null:
			_slash_core_mesh.visible = false


func clamp_to_arena() -> void:
	var limit: float = GameData.ARENA_RADIUS - 1.1
	var flat := Vector2(position.x, position.z)
	if flat.length() > limit:
		flat = flat.normalized() * limit
		position.x = flat.x
		position.z = flat.y
