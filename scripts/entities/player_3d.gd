class_name Player3D
extends Node3D
## Procedural 3D player character with equipment visuals, animations, and 3D overhead nameplate.

var facing: float = PI
var slash_anim_timer: float = 0.0
var kick_anim_timer: float = 0.0
var _walk_phase: float = 0.0
var _elapsed: float = 0.0

var _visual_root: Node3D
var _weapon_pivot: Node3D
var _aura_mesh: MeshInstance3D
var _left_leg: MeshInstance3D
var _right_leg: MeshInstance3D
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
	_name_label.position = Vector3(0.0, 3.25, 0.0)
	_name_label.pixel_size = 0.0085
	if ResourceLoader.exists("res://assets/fonts/noto_cjk_game.otf"):
		_name_label.font = load("res://assets/fonts/noto_cjk_game.otf")
	add_child(_name_label)


func rebuild_mesh() -> void:
	for child in _visual_root.get_children():
		child.queue_free()

	var char_cfg: Dictionary = GameData.get_character(GameState.player["char_id"])
	var eq_w: Dictionary = GameData.get_equipment(GameState.player["equipped"].get("weapon", "w1"))
	var eq_a: Dictionary = GameData.get_equipment(GameState.player["equipped"].get("armor", "a1"))
	if eq_w.is_empty():
		eq_w = GameData.EQUIPMENT_LIST[0]
	if eq_a.is_empty():
		eq_a = GameData.EQUIPMENT_LIST[5]

	var body_mat := StandardMaterial3D.new()
	body_mat.albedo_color = Color.html(char_cfg["color_primary"])
	body_mat.roughness = 0.45

	# Torso / Kimono / Gi
	var torso_mesh := CylinderMesh.new()
	torso_mesh.top_radius = 0.42
	torso_mesh.bottom_radius = 0.58
	torso_mesh.height = 1.35
	torso_mesh.radial_segments = 16
	var torso := MeshInstance3D.new()
	torso.mesh = torso_mesh
	torso.material_override = body_mat
	torso.position = Vector3(0.0, 1.15, 0.0)
	_visual_root.add_child(torso)

	# Obi Belt
	var belt_mat := StandardMaterial3D.new()
	belt_mat.albedo_color = Color.html(char_cfg["color_secondary"])
	var belt_mesh := CylinderMesh.new()
	belt_mesh.top_radius = 0.49
	belt_mesh.bottom_radius = 0.51
	belt_mesh.height = 0.24
	belt_mesh.radial_segments = 16
	var belt := MeshInstance3D.new()
	belt.mesh = belt_mesh
	belt.material_override = belt_mat
	belt.position = Vector3(0.0, 1.1, 0.0)
	_visual_root.add_child(belt)

	# Head
	var skin_mat := StandardMaterial3D.new()
	skin_mat.albedo_color = Color.html("#fde6d8")
	skin_mat.roughness = 0.5
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.42
	head_mesh.height = 0.84
	var head := MeshInstance3D.new()
	head.mesh = head_mesh
	head.material_override = skin_mat
	head.position = Vector3(0.0, 2.15, 0.0)
	_visual_root.add_child(head)

	# Hair Cap & Ponytail
	var hair_mat := StandardMaterial3D.new()
	hair_mat.albedo_color = Color.html(char_cfg["color_hair"])
	hair_mat.roughness = 0.6
	var hair_mesh := SphereMesh.new()
	hair_mesh.radius = 0.45
	hair_mesh.height = 0.56
	hair_mesh.is_hemisphere = true
	var hair := MeshInstance3D.new()
	hair.mesh = hair_mesh
	hair.material_override = hair_mat
	hair.position = Vector3(0.0, 2.12, 0.0)
	_visual_root.add_child(hair)

	var pony_mesh := CylinderMesh.new()
	pony_mesh.top_radius = 0.0
	pony_mesh.bottom_radius = 0.22
	pony_mesh.height = 0.85
	pony_mesh.radial_segments = 12
	var ponytail := MeshInstance3D.new()
	ponytail.mesh = pony_mesh
	ponytail.material_override = hair_mat
	ponytail.position = Vector3(0.0, 2.05, -0.46)
	ponytail.rotation.x = -0.45
	_visual_root.add_child(ponytail)

	# Character Signature Headgear
	var cid: String = char_cfg["id"]
	if cid == "sakura":
		var flower_mat := StandardMaterial3D.new()
		flower_mat.albedo_color = Color.html("#f472b6")
		flower_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		var flower := MeshInstance3D.new()
		var fmesh := SphereMesh.new()
		fmesh.radius = 0.16
		fmesh.height = 0.32
		fmesh.radial_segments = 6
		fmesh.rings = 3
		flower.mesh = fmesh
		flower.material_override = flower_mat
		flower.position = Vector3(0.36, 2.42, 0.15)
		_visual_root.add_child(flower)
	elif cid == "kickboxer":
		var band_mat := StandardMaterial3D.new()
		band_mat.albedo_color = Color.html("#ef4444")
		band_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		var band := MeshInstance3D.new()
		var bmesh := TorusMesh.new()
		bmesh.inner_radius = 0.38
		bmesh.outer_radius = 0.46
		band.mesh = bmesh
		band.material_override = band_mat
		band.position = Vector3(0.0, 2.28, 0.0)
		_visual_root.add_child(band)
	elif cid == "raijin":
		var horn_mat := StandardMaterial3D.new()
		horn_mat.albedo_color = Color.html("#facc15")
		horn_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		var horn := MeshInstance3D.new()
		var hmesh := CylinderMesh.new()
		hmesh.top_radius = 0.0
		hmesh.bottom_radius = 0.12
		hmesh.height = 0.45
		hmesh.radial_segments = 8
		horn.mesh = hmesh
		horn.material_override = horn_mat
		horn.position = Vector3(0.0, 2.62, 0.12)
		_visual_root.add_child(horn)
	elif cid == "yukionna":
		var crown_mat := StandardMaterial3D.new()
		crown_mat.albedo_color = Color.html("#38bdf8")
		crown_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		var crown := MeshInstance3D.new()
		var cmesh := SphereMesh.new()
		cmesh.radius = 0.22
		cmesh.height = 0.44
		cmesh.radial_segments = 6
		cmesh.rings = 3
		crown.mesh = cmesh
		crown.material_override = crown_mat
		crown.position = Vector3(0.0, 2.65, 0.0)
		_visual_root.add_child(crown)

	# Legs
	var leg_mat := StandardMaterial3D.new()
	leg_mat.albedo_color = Color.html("#1e293b")
	var leg_mesh := CylinderMesh.new()
	leg_mesh.top_radius = 0.14
	leg_mesh.bottom_radius = 0.12
	leg_mesh.height = 0.65
	leg_mesh.radial_segments = 10

	_left_leg = MeshInstance3D.new()
	_left_leg.mesh = leg_mesh
	_left_leg.material_override = leg_mat
	_left_leg.position = Vector3(-0.2, 0.35, 0.0)
	_visual_root.add_child(_left_leg)

	_right_leg = MeshInstance3D.new()
	_right_leg.mesh = leg_mesh
	_right_leg.material_override = leg_mat
	_right_leg.position = Vector3(0.2, 0.35, 0.0)
	_visual_root.add_child(_right_leg)

	# Right Hand Katana Weapon
	_weapon_pivot = Node3D.new()
	_weapon_pivot.position = Vector3(0.55, 1.35, 0.25)
	_weapon_pivot.rotation.x = 0.75

	var hilt_mat := StandardMaterial3D.new()
	hilt_mat.albedo_color = Color.html("#1e293b")
	var hilt_mesh := CylinderMesh.new()
	hilt_mesh.top_radius = 0.05
	hilt_mesh.bottom_radius = 0.05
	hilt_mesh.height = 0.45
	var hilt := MeshInstance3D.new()
	hilt.mesh = hilt_mesh
	hilt.material_override = hilt_mat
	_weapon_pivot.add_child(hilt)

	var blade_col := Color.html(eq_w.get("blade_color", "#d6d3d1"))
	var blade_mat := StandardMaterial3D.new()
	blade_mat.albedo_color = blade_col
	blade_mat.emission_enabled = true
	blade_mat.emission = blade_col
	blade_mat.emission_energy_multiplier = 0.45
	blade_mat.metallic = 0.8
	blade_mat.roughness = 0.2
	var blade_mesh := BoxMesh.new()
	blade_mesh.size = Vector3(0.06, 1.55, 0.14)
	var blade := MeshInstance3D.new()
	blade.mesh = blade_mesh
	blade.material_override = blade_mat
	blade.position = Vector3(0.0, 0.95, 0.0)
	_weapon_pivot.add_child(blade)
	_visual_root.add_child(_weapon_pivot)

	# Ground Armor Aura Ring
	var aura_col := Color.html(eq_a.get("aura_color", "#94a3b8"))
	var aura_mat := StandardMaterial3D.new()
	aura_mat.albedo_color = Color(aura_col.r, aura_col.g, aura_col.b, 0.65)
	aura_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	aura_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var aura_torus := TorusMesh.new()
	aura_torus.inner_radius = 0.75
	aura_torus.outer_radius = 0.95
	aura_torus.rings = 32
	aura_torus.ring_segments = 8
	_aura_mesh = MeshInstance3D.new()
	_aura_mesh.mesh = aura_torus
	_aura_mesh.material_override = aura_mat
	_aura_mesh.position = Vector3(0.0, 0.05, 0.0)
	_aura_mesh.scale = Vector3(1.0, 0.08, 1.0)
	_visual_root.add_child(_aura_mesh)

	update_name_badge()


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
	_visual_root.position.y = sin((kick_anim_timer / 0.5) * PI) * 1.4 if kick_anim_timer > 0.0 else 0.0

	if _weapon_pivot != null:
		_weapon_pivot.rotation.x = 2.4 if slash_anim_timer > 0.0 else 0.75

	if _aura_mesh != null:
		_aura_mesh.rotation.y = _elapsed * 2.0

	if _left_leg != null and _right_leg != null:
		if is_moving:
			_walk_phase += delta * 14.0
			_left_leg.rotation.x = sin(_walk_phase) * 0.5
			_right_leg.rotation.x = -sin(_walk_phase) * 0.5
		else:
			_left_leg.rotation.x = lerpf(_left_leg.rotation.x, 0.0, clampf(delta * 12.0, 0.0, 1.0))
			_right_leg.rotation.x = lerpf(_right_leg.rotation.x, 0.0, clampf(delta * 12.0, 0.0, 1.0))


func clamp_to_arena() -> void:
	var limit: float = GameData.ARENA_RADIUS - 1.1
	var flat := Vector2(position.x, position.z)
	if flat.length() > limit:
		flat = flat.normalized() * limit
		position.x = flat.x
		position.z = flat.y
