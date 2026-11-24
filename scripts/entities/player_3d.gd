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

var facing: float = PI
var slash_anim_timer: float = 0.0
var kick_anim_timer: float = 0.0

var _slash_step: int = 1
var _walk_phase: float = 0.0
var _elapsed: float = 0.0

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


func trigger_slash(step: int) -> void:
	_slash_step = clampi(step, 1, 3)
	slash_anim_timer = 0.28


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

	# 3. 3D Glowing Crescent Slash Arc VFX
	_build_slash_arc(blade_col)

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
	var torus := TorusMesh.new()
	torus.inner_radius = 1.15
	torus.outer_radius = 1.68
	torus.rings = 28
	torus.ring_segments = 6
	_slash_arc_mat = StandardMaterial3D.new()
	_slash_arc_mat.albedo_color = Color(blade_col.r, blade_col.g, blade_col.b, 0.0)
	_slash_arc_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_slash_arc_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_slash_arc_mesh = MeshInstance3D.new()
	_slash_arc_mesh.mesh = torus
	_slash_arc_mesh.material_override = _slash_arc_mat
	_slash_arc_mesh.position = Vector3(0.0, 1.25, 0.45)
	_slash_arc_mesh.scale = Vector3(1.0, 0.08, 1.0)
	_slash_arc_mesh.visible = false
	var parent_n: Node3D = _body_pivot if _body_pivot != null else _visual_root
	parent_n.add_child(_slash_arc_mesh)


func update_name_badge() -> void:
	if _name_label == null:
		return
	var char_cfg: Dictionary = GameData.get_character(GameState.player["char_id"])
	_name_label.text = "%s\nLv.%d・%s" % [GameState.player["name"], int(GameState.player["level"]), char_cfg["name"]]


func update_animations(delta: float, is_moving: bool) -> void:
	_elapsed += delta
	if slash_anim_timer > 0.0:
		slash_anim_timer = maxf(0.0, slash_anim_timer - delta)
	if kick_anim_timer > 0.0:
		kick_anim_timer = maxf(0.0, kick_anim_timer - delta)

	_visual_root.rotation.y = facing

	if _aura_mesh != null:
		_aura_mesh.rotation.y = _elapsed * 1.8

	if _orbit_group != null:
		var cid: String = GameState.player["char_id"]
		if cid == "raijin":
			_orbit_group.rotation.z = _elapsed * 2.2
		else:
			_orbit_group.rotation.y = _elapsed * 1.9

	if _scarf_node != null:
		_scarf_node.rotation.x = (0.35 if is_moving else 0.08) + sin(_elapsed * 7.5) * 0.12

	if _body_pivot == null:
		return

	# Subtle head life motion
	if _head_pivot != null:
		_head_pivot.rotation.z = sin(_elapsed * 2.4) * 0.035

	# Vertical body bounce / kick jump / forward run lean
	if kick_anim_timer > 0.0:
		var kt := kick_anim_timer / 0.5
		_body_pivot.position.y = sin(kt * PI) * 1.45
		_body_pivot.rotation.x = -0.35
	else:
		_body_pivot.position.y = sin(_elapsed * (10.0 if is_moving else 3.2)) * (0.06 if is_moving else 0.03)
		_body_pivot.rotation.x = lerpf(_body_pivot.rotation.x, 0.14 if is_moving else 0.0, clampf(delta * 10.0, 0.0, 1.0))

	# Leg & Arm Locomotion
	if is_moving and kick_anim_timer <= 0.0:
		_walk_phase += delta * 14.0
		var swing := sin(_walk_phase)
		if _left_leg != null and _right_leg != null:
			_left_leg.rotation.x = swing * 0.65
			_right_leg.rotation.x = -swing * 0.65
		if _left_arm != null:
			_left_arm.rotation.x = -swing * 0.55
		if _right_arm != null and slash_anim_timer <= 0.0:
			_right_arm.rotation.x = swing * 0.40 - 0.25
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

	# 3-Hit Combo Slash Animation + Glowing Crescent Slash Arc
	if slash_anim_timer > 0.0:
		var p := 1.0 - (slash_anim_timer / 0.28)
		if _right_arm != null:
			if _slash_step == 1:
				_right_arm.rotation.x = lerpf(-1.6, 0.9, p)
				_right_arm.rotation.z = lerpf(0.6, -0.5, p)
				_body_pivot.rotation.y = lerpf(-0.35, 0.35, p)
			elif _slash_step == 2:
				_right_arm.rotation.x = lerpf(0.7, -1.5, p)
				_right_arm.rotation.z = lerpf(-0.6, 0.7, p)
				_body_pivot.rotation.y = lerpf(0.35, -0.35, p)
			else:
				_right_arm.rotation.x = lerpf(-2.2, 1.25, p)
				_right_arm.rotation.z = 0.0
				_body_pivot.rotation.y = p * TAU
		if _weapon_pivot != null:
			_weapon_pivot.rotation.x = 1.65
		if _slash_arc_mesh != null and _slash_arc_mat != null:
			_slash_arc_mesh.visible = true
			_slash_arc_mesh.rotation.z = 0.35 if _slash_step == 1 else (-0.35 if _slash_step == 2 else 0.0)
			_slash_arc_mesh.rotation.y = p * 2.8
			var sc := (1.35 if _slash_step == 3 else 1.0) * (0.85 + p * 0.55)
			_slash_arc_mesh.scale = Vector3(sc, 0.08, sc)
			_slash_arc_mat.albedo_color.a = (1.0 - p) * 0.85
	else:
		_body_pivot.rotation.y = lerpf(_body_pivot.rotation.y, 0.0, clampf(delta * 14.0, 0.0, 1.0))
		if _weapon_pivot != null:
			_weapon_pivot.rotation.x = lerpf(_weapon_pivot.rotation.x, 0.85, clampf(delta * 12.0, 0.0, 1.0))
		if _slash_arc_mesh != null:
			_slash_arc_mesh.visible = false


func clamp_to_arena() -> void:
	var limit: float = GameData.ARENA_RADIUS - 1.1
	var flat := Vector2(position.x, position.z)
	if flat.length() > limit:
		flat = flat.normalized() * limit
		position.x = flat.x
		position.z = flat.y
