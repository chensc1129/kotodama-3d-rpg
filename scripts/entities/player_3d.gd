class_name Player3D
extends Node3D
## Stylized anime-heroic 3D player character builder with layered Japanese attire,
## expressive anime face, sculpted hair, articulated limbs, signature accessories,
## equipment-synced weapons, and dynamic idle/run/3-hit slash/kick animations.

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
var _slash_arc_mesh: MeshInstance3D
var _slash_arc_mat: StandardMaterial3D
var _left_leg: Node3D
var _right_leg: Node3D
var _aura_mesh: MeshInstance3D
var _orbit_group: Node3D
var _scarf_node: Node3D
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

	_orbit_group = null
	_scarf_node = null

	var char_cfg: Dictionary = GameData.get_character(GameState.player["char_id"])
	var eq_w: Dictionary = GameData.get_equipment(GameState.player["equipped"].get("weapon", "w1"))
	var eq_a: Dictionary = GameData.get_equipment(GameState.player["equipped"].get("armor", "a1"))
	if eq_w.is_empty():
		eq_w = GameData.EQUIPMENT_LIST[0]
	if eq_a.is_empty():
		eq_a = GameData.EQUIPMENT_LIST[5]

	var cid: String = char_cfg["id"]
	var col_primary := Color.html(char_cfg["color_primary"])
	var col_secondary := Color.html(char_cfg["color_secondary"])
	var col_hair := Color.html(char_cfg["color_hair"])
	var blade_col := Color.html(eq_w.get("blade_color", "#d6d3d1"))
	var aura_col := Color.html(eq_a.get("aura_color", "#94a3b8"))

	var skin_mat := _mat(Color.html("#ffe2cf"), 0.55, 0.0)
	var hair_mat := _mat(col_hair, 0.42, 0.08)
	var gold_mat := _mat(Color.html("#fbbf24"), 0.25, 0.85, Color.html("#f59e0b"), 0.25)
	var dark_mat := _mat(Color.html("#1e293b"), 0.65, 0.15)
	var white_mat := _mat(Color.html("#f8fafc"), 0.50, 0.05)

	# Ground Armor Aura Ring (outer + inner rune ring)
	_aura_mesh = _build_aura_ring(aura_col)
	_visual_root.add_child(_aura_mesh)

	# Main articulated body root (for breathing/jump/lean)
	_body_pivot = Node3D.new()
	_visual_root.add_child(_body_pivot)

	# ==================== LEGS (HIP PIVOTS) ====================
	_left_leg = Node3D.new()
	_left_leg.position = Vector3(-0.18, 0.72, 0.0)
	_body_pivot.add_child(_left_leg)

	_right_leg = Node3D.new()
	_right_leg.position = Vector3(0.18, 0.72, 0.0)
	_body_pivot.add_child(_right_leg)

	_build_legs(cid, col_primary, col_secondary, skin_mat, dark_mat, white_mat, gold_mat)

	# ==================== TORSO & LAYERED JAPANESE OUTFIT ====================
	_build_torso_and_outfit(cid, col_primary, col_secondary, skin_mat, dark_mat, white_mat, gold_mat)

	# ==================== ARMS (SHOULDER PIVOTS) ====================
	_left_arm = Node3D.new()
	_left_arm.position = Vector3(-0.44, 1.44, 0.0)
	_body_pivot.add_child(_left_arm)

	_right_arm = Node3D.new()
	_right_arm.position = Vector3(0.44, 1.44, 0.0)
	_body_pivot.add_child(_right_arm)

	_build_arms(cid, col_primary, col_secondary, skin_mat, dark_mat, white_mat, gold_mat, blade_col)

	# ==================== WEAPON & 3D SLASH ARC ====================
	_weapon_pivot = Node3D.new()
	_weapon_pivot.position = Vector3(0.0, -0.52, 0.14)
	_right_arm.add_child(_weapon_pivot)
	_build_weapon(cid, blade_col, gold_mat, dark_mat)

	_build_slash_arc(blade_col)

	# ==================== HEAD, EXPRESSIVE ANIME FACE & LAYERED HAIR ====================
	_head_pivot = Node3D.new()
	_head_pivot.position = Vector3(0.0, 1.62, 0.0)
	_body_pivot.add_child(_head_pivot)

	_build_head_and_hair(cid, col_primary, col_secondary, skin_mat, hair_mat, white_mat, gold_mat, dark_mat)

	# ==================== CHARACTER-UNIQUE FLOATING ACCESSORIES ====================
	_build_back_and_orbit_accessories(cid, col_primary, col_secondary, gold_mat)

	update_name_badge()


func _build_aura_ring(aura_col: Color) -> MeshInstance3D:
	var torus := TorusMesh.new()
	torus.inner_radius = 0.74
	torus.outer_radius = 0.90
	torus.rings = 36
	torus.ring_segments = 8
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(aura_col.r, aura_col.g, aura_col.b, 0.65)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var inst := MeshInstance3D.new()
	inst.mesh = torus
	inst.material_override = mat
	inst.position = Vector3(0.0, 0.04, 0.0)
	inst.scale = Vector3(1.0, 0.08, 1.0)
	return inst


func _build_legs(
	cid: String,
	col_primary: Color,
	_col_secondary: Color,
	skin_mat: StandardMaterial3D,
	dark_mat: StandardMaterial3D,
	white_mat: StandardMaterial3D,
	gold_mat: StandardMaterial3D
) -> void:
	var pant_mat := dark_mat
	var boot_mat := dark_mat
	var strap_mat := _mat(col_primary, 0.45, 0.1)

	if cid == "sakura" or cid == "yukionna":
		pant_mat = white_mat
		boot_mat = _mat(Color.html("#7c2d12"), 0.7, 0.05) # Wooden geta
	elif cid == "kickboxer":
		pant_mat = skin_mat
		boot_mat = _mat(Color.html("#ef4444"), 0.4, 0.1, Color.html("#f97316"), 0.25) # Flame ankle wraps
	elif cid == "swordsman":
		pant_mat = dark_mat
		boot_mat = _mat(Color.html("#991b1b"), 0.35, 0.55) # Armored greaves
	elif cid == "raijin":
		pant_mat = _mat(Color.html("#1e1b4b"), 0.5, 0.2)
		boot_mat = _mat(Color.html("#eab308"), 0.3, 0.6, Color.html("#facc15"), 0.25)

	for leg_pivot in [_left_leg, _right_leg]:
		# Upper leg
		var upper := _cyl(0.115, 0.10, 0.38, pant_mat)
		upper.position = Vector3(0.0, -0.18, 0.0)
		leg_pivot.add_child(upper)

		# Lower leg / shin guard
		var lower := _cyl(0.10, 0.09, 0.34, boot_mat if cid != "sakura" and cid != "yukionna" else white_mat)
		lower.position = Vector3(0.0, -0.50, 0.0)
		leg_pivot.add_child(lower)

		# Foot / sandal / boot
		var foot := _box(Vector3(0.18, 0.11, 0.30), boot_mat)
		foot.position = Vector3(0.0, -0.66, 0.05)
		leg_pivot.add_child(foot)

		if cid == "sakura" or cid == "yukionna":
			var strap := _box(Vector3(0.16, 0.05, 0.08), strap_mat)
			strap.position = Vector3(0.0, -0.59, 0.08)
			leg_pivot.add_child(strap)
		elif cid == "kickboxer":
			# Glowing wind-ring around each ankle
			var ring := _torus(0.13, 0.17, _mat_unshaded(Color.html("#38bdf8"), 0.85))
			ring.position = Vector3(0.0, -0.52, 0.0)
			leg_pivot.add_child(ring)
		elif cid == "swordsman" or cid == "raijin":
			var knee := _sphere(0.11, gold_mat)
			knee.position = Vector3(0.0, -0.35, 0.07)
			knee.scale = Vector3(1.0, 0.9, 0.65)
			leg_pivot.add_child(knee)


func _build_torso_and_outfit(
	cid: String,
	col_primary: Color,
	col_secondary: Color,
	skin_mat: StandardMaterial3D,
	dark_mat: StandardMaterial3D,
	white_mat: StandardMaterial3D,
	gold_mat: StandardMaterial3D
) -> void:
	var pri_mat := _mat(col_primary, 0.42, 0.12)
	var sec_mat := _mat(col_secondary, 0.45, 0.10)

	# Neck
	var neck := _cyl(0.11, 0.12, 0.20, skin_mat)
	neck.position = Vector3(0.0, 1.56, 0.0)
	_body_pivot.add_child(neck)

	if cid == "sakura":
		# White Miko Chihaya upper kimono
		var chest := _cyl(0.28, 0.25, 0.62, white_mat)
		chest.position = Vector3(0.0, 1.24, 0.0)
		_body_pivot.add_child(chest)

		# Crimson V-collar lapels
		for side in [-1.0, 1.0]:
			var lapel := _box(Vector3(0.07, 0.34, 0.10), pri_mat)
			lapel.position = Vector3(0.10 * side, 1.38, 0.20)
			lapel.rotation.z = -0.35 * side
			_body_pivot.add_child(lapel)

		# Flowing Crimson Hakama Skirt (layered flared skirt)
		var skirt := _cyl(0.27, 0.56, 0.68, pri_mat)
		skirt.position = Vector3(0.0, 0.64, 0.0)
		_body_pivot.add_child(skirt)

		# Sakura pink hem trim
		var hem := _torus(0.51, 0.57, _mat(Color.html("#fda4af"), 0.4, 0.1, Color.html("#f472b6"), 0.2))
		hem.position = Vector3(0.0, 0.33, 0.0)
		hem.scale = Vector3(1.0, 0.45, 1.0)
		_body_pivot.add_child(hem)

		# Obi Waist Sash & Big Back Ribbon Bow
		var obi := _cyl(0.30, 0.31, 0.22, _mat(Color.html("#be123c"), 0.4, 0.15))
		obi.position = Vector3(0.0, 0.96, 0.0)
		_body_pivot.add_child(obi)

		var obijime := _torus(0.29, 0.33, gold_mat)
		obijime.position = Vector3(0.0, 0.96, 0.0)
		_body_pivot.add_child(obijime)

		# Back ribbon wings
		for side in [-1.0, 1.0]:
			var bow := _box(Vector3(0.28, 0.18, 0.09), pri_mat)
			bow.position = Vector3(0.18 * side, 0.96, -0.32)
			bow.rotation.z = 0.28 * side
			bow.rotation.y = -0.25 * side
			_body_pivot.add_child(bow)
			var tail := _box(Vector3(0.11, 0.34, 0.05), _mat(Color.html("#fda4af"), 0.4, 0.05))
			tail.position = Vector3(0.11 * side, 0.74, -0.33)
			tail.rotation.z = 0.15 * side
			_body_pivot.add_child(tail)

	elif cid == "kickboxer":
		# Athletic Martial Arts Gi Vest (open V-chest)
		var chest := _cyl(0.31, 0.26, 0.64, pri_mat)
		chest.position = Vector3(0.0, 1.24, 0.0)
		_body_pivot.add_child(chest)

		# Open chest triangle showing athletic wrap
		var inner_chest := _box(Vector3(0.16, 0.32, 0.12), skin_mat)
		inner_chest.position = Vector3(0.0, 1.36, 0.23)
		_body_pivot.add_child(inner_chest)

		# White gi lapel trim
		for side in [-1.0, 1.0]:
			var lapel := _box(Vector3(0.07, 0.42, 0.09), white_mat)
			lapel.position = Vector3(0.11 * side, 1.32, 0.23)
			lapel.rotation.z = -0.26 * side
			_body_pivot.add_child(lapel)

		# Championship Red/Gold Belt + Hanging Belt Tails
		var belt := _cyl(0.29, 0.30, 0.16, _mat(Color.html("#dc2626"), 0.4, 0.2))
		belt.position = Vector3(0.0, 0.94, 0.0)
		_body_pivot.add_child(belt)

		var buckle := _box(Vector3(0.18, 0.14, 0.08), gold_mat)
		buckle.position = Vector3(0.0, 0.94, 0.29)
		_body_pivot.add_child(buckle)

		# Martial Arts Fight Shorts
		var shorts := _cyl(0.29, 0.37, 0.36, _mat(Color.html("#1d4ed8"), 0.45, 0.1))
		shorts.position = Vector3(0.0, 0.72, 0.0)
		_body_pivot.add_child(shorts)

		var short_trim := _torus(0.34, 0.38, white_mat)
		short_trim.position = Vector3(0.0, 0.56, 0.0)
		_body_pivot.add_child(short_trim)

	elif cid == "swordsman":
		# Samurai Armored Cuirass (Do) + Dark Haori
		var under := _cyl(0.29, 0.27, 0.64, dark_mat)
		under.position = Vector3(0.0, 1.24, 0.0)
		_body_pivot.add_child(under)

		# Crimson Samurai Chest Plate
		var armor := _box(Vector3(0.50, 0.48, 0.38), _mat(Color.html("#b91c1c"), 0.3, 0.6))
		armor.position = Vector3(0.0, 1.26, 0.02)
		_body_pivot.add_child(armor)

		# Gold Mon Crest on Chest
		var crest := _torus(0.06, 0.11, gold_mat)
		crest.position = Vector3(0.0, 1.32, 0.22)
		crest.rotation.x = PI * 0.5
		_body_pivot.add_child(crest)

		# Flared Armored Tassets (Kusazuri) + Haori Skirt
		var skirt := _cyl(0.30, 0.48, 0.54, dark_mat)
		skirt.position = Vector3(0.0, 0.70, 0.0)
		_body_pivot.add_child(skirt)

		for ang in [0.0, PI * 0.5, PI, -PI * 0.5]:
			var plate := _box(Vector3(0.28, 0.36, 0.06), _mat(Color.html("#dc2626"), 0.32, 0.55))
			plate.position = Vector3(sin(ang) * 0.35, 0.74, cos(ang) * 0.35)
			plate.rotation.y = ang
			plate.rotation.x = -0.18
			_body_pivot.add_child(plate)

		# Gold Braided Belt + Left-Hip Scabbard (Saya)
		var belt := _cyl(0.31, 0.32, 0.14, gold_mat)
		belt.position = Vector3(0.0, 0.96, 0.0)
		_body_pivot.add_child(belt)

		var saya := _cyl(0.045, 0.04, 1.15, dark_mat)
		saya.position = Vector3(-0.34, 0.88, -0.05)
		saya.rotation.x = 1.25
		saya.rotation.z = 0.25
		_body_pivot.add_child(saya)

	elif cid == "raijin":
		# Sleek Shinobi Bodysuit
		var suit_mat := _mat(Color.html("#1e1b4b"), 0.42, 0.25)
		var chest := _cyl(0.27, 0.23, 0.62, suit_mat)
		chest.position = Vector3(0.0, 1.24, 0.0)
		_body_pivot.add_child(chest)

		# Golden Lightning X-Harness
		for side in [-1.0, 1.0]:
			var strap := _box(Vector3(0.07, 0.56, 0.36), _mat(Color.html("#eab308"), 0.25, 0.7, Color.html("#facc15"), 0.3))
			strap.position = Vector3(0.0, 1.25, 0.02)
			strap.rotation.z = 0.48 * side
			_body_pivot.add_child(strap)

		# Shinobi Belt & Split Coat Tails
		var belt := _cyl(0.27, 0.28, 0.14, gold_mat)
		belt.position = Vector3(0.0, 0.94, 0.0)
		_body_pivot.add_child(belt)

		for side in [-1.0, 1.0]:
			var tail := _box(Vector3(0.24, 0.44, 0.06), suit_mat)
			tail.position = Vector3(0.16 * side, 0.68, -0.22)
			tail.rotation.x = 0.22
			_body_pivot.add_child(tail)

	elif cid == "yukionna":
		# Ethereal Layered Snow-Kimono
		var ice_mat := _mat(Color.html("#e0f2fe"), 0.28, 0.15, Color.html("#38bdf8"), 0.18)
		var cyan_mat := _mat(Color.html("#06b6d4"), 0.25, 0.25, Color.html("#22d3ee"), 0.30)

		var chest := _cyl(0.26, 0.24, 0.62, ice_mat)
		chest.position = Vector3(0.0, 1.24, 0.0)
		_body_pivot.add_child(chest)

		for side in [-1.0, 1.0]:
			var lapel := _box(Vector3(0.07, 0.36, 0.10), cyan_mat)
			lapel.position = Vector3(0.09 * side, 1.38, 0.19)
			lapel.rotation.z = -0.32 * side
			_body_pivot.add_child(lapel)

		# Long Sweeping Frost Gown
		var gown := _cyl(0.26, 0.58, 0.78, ice_mat)
		gown.position = Vector3(0.0, 0.58, 0.0)
		_body_pivot.add_child(gown)

		var frost_hem := _torus(0.52, 0.60, cyan_mat)
		frost_hem.position = Vector3(0.0, 0.24, 0.0)
		frost_hem.scale = Vector3(1.0, 0.4, 1.0)
		_body_pivot.add_child(frost_hem)

		# Ice-Crystal Obi & Back Bow
		var obi := _cyl(0.29, 0.30, 0.22, cyan_mat)
		obi.position = Vector3(0.0, 0.96, 0.0)
		_body_pivot.add_child(obi)

		var crystal_bow := _sphere(0.20, _mat_unshaded(Color.html("#67e8f9"), 0.9))
		crystal_bow.position = Vector3(0.0, 0.96, -0.32)
		crystal_bow.scale = Vector3(1.4, 0.85, 0.45)
		_body_pivot.add_child(crystal_bow)


func _build_arms(
	cid: String,
	col_primary: Color,
	col_secondary: Color,
	skin_mat: StandardMaterial3D,
	dark_mat: StandardMaterial3D,
	white_mat: StandardMaterial3D,
	gold_mat: StandardMaterial3D,
	blade_col: Color
) -> void:
	var pri_mat := _mat(col_primary, 0.40, 0.15)
	var sec_mat := _mat(col_secondary, 0.42, 0.10)

	for pair in [[_left_arm, -1.0], [_right_arm, 1.0]]:
		var arm_pivot: Node3D = pair[0]
		var side: float = pair[1]

		if cid == "sakura" or cid == "yukionna":
			# Billowing Japanese Furisode Kimono Sleeves
			var sleeve_mat := white_mat if cid == "sakura" else _mat(Color.html("#e0f2fe"), 0.3, 0.15, Color.html("#38bdf8"), 0.15)
			var trim_mat := pri_mat if cid == "sakura" else _mat(Color.html("#06b6d4"), 0.25, 0.25, Color.html("#22d3ee"), 0.3)

			var shoulder := _sphere(0.14, sleeve_mat)
			arm_pivot.add_child(shoulder)

			var upper := _cyl(0.11, 0.16, 0.44, sleeve_mat)
			upper.position = Vector3(0.03 * side, -0.22, 0.0)
			arm_pivot.add_child(upper)

			# Hanging wide sleeve drape
			var drape := _box(Vector3(0.16, 0.38, 0.28), sleeve_mat)
			drape.position = Vector3(0.06 * side, -0.34, -0.06)
			arm_pivot.add_child(drape)

			var cuff := _box(Vector3(0.18, 0.07, 0.30), trim_mat)
			cuff.position = Vector3(0.06 * side, -0.52, -0.06)
			arm_pivot.add_child(cuff)

		elif cid == "kickboxer":
			# Muscular bare arms + fiery crimson Muay Thai forearm wraps
			var shoulder := _sphere(0.14, skin_mat)
			arm_pivot.add_child(shoulder)

			var upper := _cyl(0.105, 0.095, 0.28, skin_mat)
			upper.position = Vector3(0.0, -0.14, 0.0)
			arm_pivot.add_child(upper)

			var wrap := _cyl(0.105, 0.11, 0.26, _mat(Color.html("#ef4444"), 0.45, 0.1, Color.html("#f97316"), 0.25))
			wrap.position = Vector3(0.0, -0.38, 0.02)
			arm_pivot.add_child(wrap)

			# Glowing fist guard synced with equipped weapon color
			var knuckle := _box(Vector3(0.14, 0.12, 0.16), _mat(blade_col, 0.25, 0.7, blade_col, 0.45))
			knuckle.position = Vector3(0.0, -0.52, 0.05)
			arm_pivot.add_child(knuckle)

		elif cid == "swordsman":
			# Layered Samurai Pauldron (Sode) + Armored Gauntlets
			var pauldron := _box(Vector3(0.22, 0.26, 0.28), _mat(Color.html("#dc2626"), 0.3, 0.6))
			pauldron.position = Vector3(0.06 * side, -0.04, 0.0)
			pauldron.rotation.z = -0.25 * side
			arm_pivot.add_child(pauldron)

			var p_trim := _box(Vector3(0.24, 0.05, 0.30), gold_mat)
			p_trim.position = Vector3(0.08 * side, -0.15, 0.0)
			p_trim.rotation.z = -0.25 * side
			arm_pivot.add_child(p_trim)

			var arm := _cyl(0.095, 0.09, 0.48, dark_mat)
			arm.position = Vector3(0.0, -0.26, 0.0)
			arm_pivot.add_child(arm)

			var gauntlet := _cyl(0.105, 0.095, 0.22, _mat(Color.html("#991b1b"), 0.3, 0.6))
			gauntlet.position = Vector3(0.0, -0.40, 0.0)
			arm_pivot.add_child(gauntlet)

		elif cid == "raijin":
			# Sleek Shinobi Sleeve + Golden Lightning Bracer
			var shoulder := _sphere(0.13, gold_mat if side > 0 else sec_mat)
			arm_pivot.add_child(shoulder)

			var arm := _cyl(0.09, 0.085, 0.48, sec_mat)
			arm.position = Vector3(0.0, -0.25, 0.0)
			arm_pivot.add_child(arm)

			var bracer := _cyl(0.105, 0.095, 0.20, _mat(Color.html("#facc15"), 0.2, 0.75, Color.html("#fde047"), 0.45))
			bracer.position = Vector3(0.0, -0.40, 0.0)
			arm_pivot.add_child(bracer)

			# Left-hand backup lightning kunai
			if side < 0:
				var kunai := _cyl(0.0, 0.055, 0.55, _mat(blade_col, 0.2, 0.85, blade_col, 0.5))
				kunai.position = Vector3(0.0, -0.52, 0.22)
				kunai.rotation.x = PI * 0.5
				arm_pivot.add_child(kunai)

		# Hand sphere
		var hand := _sphere(0.09, skin_mat if cid != "raijin" else dark_mat)
		hand.position = Vector3(0.0, -0.52, 0.02)
		arm_pivot.add_child(hand)


func _build_weapon(cid: String, blade_col: Color, gold_mat: StandardMaterial3D, dark_mat: StandardMaterial3D) -> void:
	var blade_mat := _mat(blade_col, 0.18, 0.85, blade_col, 0.55)
	var edge_mat := _mat_unshaded(blade_col.lightened(0.35), 0.95)

	if cid == "yukionna":
		# Crystalline Frost Naginata / Ice Katana
		var staff := _cyl(0.032, 0.032, 1.35, _mat(Color.html("#bae6fd"), 0.25, 0.5))
		staff.position = Vector3(0.0, 0.42, 0.0)
		_weapon_pivot.add_child(staff)

		var crystal_guard := _sphere(0.13, edge_mat)
		crystal_guard.position = Vector3(0.0, 0.95, 0.0)
		crystal_guard.scale = Vector3(1.1, 0.55, 1.1)
		_weapon_pivot.add_child(crystal_guard)

		var ice_blade := _cyl(0.0, 0.11, 0.95, blade_mat)
		ice_blade.position = Vector3(0.0, 1.48, 0.0)
		ice_blade.scale = Vector3(0.45, 1.0, 1.2)
		_weapon_pivot.add_child(ice_blade)
	elif cid == "kickboxer":
		# Compact Blazing Wind-Tonfa Blade
		var grip := _cyl(0.04, 0.04, 0.40, dark_mat)
		_weapon_pivot.add_child(grip)
		var guard := _box(Vector3(0.18, 0.12, 0.22), gold_mat)
		guard.position = Vector3(0.0, 0.18, 0.0)
		_weapon_pivot.add_child(guard)
		var energy_blade := _box(Vector3(0.07, 1.10, 0.20), blade_mat)
		energy_blade.position = Vector3(0.0, 0.78, 0.02)
		_weapon_pivot.add_child(energy_blade)
	else:
		# Detailed Forged Japanese Katana (Tsuka hilt + ornate Tsuba + curved glowing Blade + Kissaki tip)
		var hilt := _cyl(0.042, 0.045, 0.44, dark_mat)
		hilt.position = Vector3(0.0, -0.02, 0.0)
		_weapon_pivot.add_child(hilt)

		var pommel := _cyl(0.052, 0.052, 0.06, gold_mat)
		pommel.position = Vector3(0.0, -0.25, 0.0)
		_weapon_pivot.add_child(pommel)

		var tsuba := _cyl(0.13, 0.13, 0.035, gold_mat)
		tsuba.position = Vector3(0.0, 0.21, 0.0)
		_weapon_pivot.add_child(tsuba)

		var blade_main := _box(Vector3(0.045, 1.38, 0.12), blade_mat)
		blade_main.position = Vector3(0.0, 0.92, 0.0)
		_weapon_pivot.add_child(blade_main)

		# Glowing razor edge highlight
		var blade_edge := _box(Vector3(0.02, 1.36, 0.03), edge_mat)
		blade_edge.position = Vector3(0.0, 0.92, 0.065)
		_weapon_pivot.add_child(blade_edge)

		# Sharp Kissaki sword tip
		var tip := _cyl(0.0, 0.065, 0.26, blade_mat)
		tip.position = Vector3(0.0, 1.74, 0.0)
		tip.scale = Vector3(0.42, 1.0, 1.0)
		_weapon_pivot.add_child(tip)

	_weapon_pivot.rotation.x = 0.85


func _build_slash_arc(blade_col: Color) -> void:
	# Glowing 3D crescent slash VFX attached to body during combo swings
	var torus := TorusMesh.new()
	torus.inner_radius = 1.15
	torus.outer_radius = 1.65
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
	_body_pivot.add_child(_slash_arc_mesh)


func _build_head_and_hair(
	cid: String,
	col_primary: Color,
	_col_secondary: Color,
	skin_mat: StandardMaterial3D,
	hair_mat: StandardMaterial3D,
	white_mat: StandardMaterial3D,
	gold_mat: StandardMaterial3D,
	dark_mat: StandardMaterial3D
) -> void:
	# Sculpted Anime Head
	var head := _sphere(0.39, skin_mat)
	head.position = Vector3(0.0, 0.36, 0.0)
	head.scale = Vector3(0.98, 1.03, 0.95)
	_head_pivot.add_child(head)

	# ==================== EXPRESSIVE ANIME FACE (+Z) ====================
	var iris_color := col_primary
	if cid == "kickboxer":
		iris_color = Color.html("#f59e0b")
	elif cid == "swordsman":
		iris_color = Color.html("#ef4444")
	elif cid == "raijin":
		iris_color = Color.html("#facc15")
	elif cid == "yukionna":
		iris_color = Color.html("#38bdf8")

	var sclera_mat := _mat_unshaded(Color.WHITE, 1.0)
	var iris_mat := _mat_unshaded(iris_color, 1.0)
	var pupil_mat := _mat_unshaded(Color.html("#0f172a"), 1.0)
	var blush_mat := _mat_unshaded(Color(1.0, 0.55, 0.65, 0.55), 0.55)

	for side in [-1.0, 1.0]:
		# White sclera oval
		var eye_bg := _sphere(0.082, sclera_mat)
		eye_bg.position = Vector3(0.145 * side, 0.35, 0.32)
		eye_bg.scale = Vector3(0.92, 1.12, 0.45)
		_head_pivot.add_child(eye_bg)

		# Colored anime iris
		var iris := _sphere(0.062, iris_mat)
		iris.position = Vector3(0.142 * side, 0.34, 0.345)
		iris.scale = Vector3(0.88, 1.08, 0.42)
		_head_pivot.add_child(iris)

		# Dark pupil center
		var pupil := _sphere(0.036, pupil_mat)
		pupil.position = Vector3(0.142 * side, 0.345, 0.36)
		pupil.scale = Vector3(0.85, 1.0, 0.4)
		_head_pivot.add_child(pupil)

		# Anime eye highlight glint!
		var glint := _sphere(0.020, sclera_mat)
		glint.position = Vector3(0.165 * side, 0.38, 0.372)
		_head_pivot.add_child(glint)

		# Upper eyelash / eyebrow
		var lash := _box(Vector3(0.15, 0.028, 0.04), dark_mat)
		lash.position = Vector3(0.145 * side, 0.43, 0.345)
		lash.rotation.z = (-0.16 if (cid == "kickboxer" or cid == "raijin" or cid == "swordsman") else 0.06) * side
		_head_pivot.add_child(lash)

		# Soft rosy cheek blush (for Sakura & Yukionna)
		if cid == "sakura" or cid == "yukionna":
			var blush := _sphere(0.045, blush_mat)
			blush.position = Vector3(0.21 * side, 0.25, 0.305)
			blush.scale = Vector3(1.25, 0.55, 0.35)
			_head_pivot.add_child(blush)

	# Raijin Ninja Lower-Face Mask
	if cid == "raijin":
		var mask := _cyl(0.36, 0.33, 0.24, _mat(Color.html("#1e1b4b"), 0.5, 0.2))
		mask.position = Vector3(0.0, 0.18, 0.04)
		_head_pivot.add_child(mask)

	# ==================== LAYERED ANIME HAIR ====================
	# Full Hair Crown Volume
	var crown := _sphere(0.425, hair_mat)
	crown.position = Vector3(0.0, 0.41, -0.03)
	crown.scale = Vector3(1.03, 1.02, 1.05)
	_head_pivot.add_child(crown)

	# Sculpted Front Bangs (5 overlapping tapered locks)
	var bang_offsets := [
		[-0.24, 0.54, 0.28, 0.28, -0.25],
		[-0.12, 0.58, 0.34, 0.14, -0.10],
		[0.0, 0.59, 0.36, 0.0, 0.0],
		[0.12, 0.58, 0.34, -0.14, 0.10],
		[0.24, 0.54, 0.28, -0.28, 0.25],
	]
	for b in bang_offsets:
		var bang := _cyl(0.085, 0.015, 0.30, hair_mat)
		bang.position = Vector3(b[0], b[1], b[2])
		bang.rotation.z = b[3]
		bang.rotation.x = 0.22
		_head_pivot.add_child(bang)

	# Side Face-Framing Hair Locks
	for side in [-1.0, 1.0]:
		var lock_len := 0.62 if (cid == "sakura" or cid == "yukionna") else 0.34
		var side_lock := _cyl(0.085, 0.025, lock_len, hair_mat)
		side_lock.position = Vector3(0.36 * side, 0.44 - lock_len * 0.42, 0.12)
		side_lock.rotation.z = -0.10 * side
		_head_pivot.add_child(side_lock)

	# ==================== DISTINCT BACK HAIRSTYLE & HEADGEAR ====================
	if cid == "sakura":
		# High Flowing Ponytail + White/Red Mizuhiki Tie + 5-Petal Sakura Hairpin!
		var tie := _torus(0.08, 0.14, white_mat)
		tie.position = Vector3(0.0, 0.52, -0.40)
		tie.rotation.x = 0.9
		_head_pivot.add_child(tie)

		var pony := _cyl(0.17, 0.04, 0.95, hair_mat)
		pony.position = Vector3(0.0, 0.12, -0.52)
		pony.rotation.x = 0.25
		_head_pivot.add_child(pony)

		# 5-Petal 3D Sakura Blossom Hairpin
		var flower_root := Node3D.new()
		flower_root.position = Vector3(0.33, 0.62, 0.16)
		flower_root.rotation = Vector3(0.2, 0.4, -0.4)
		var petal_mat := _mat_unshaded(Color.html("#f472b6"), 1.0)
		for i in range(5):
			var ang := float(i) * TAU / 5.0
			var petal := _sphere(0.075, petal_mat)
			petal.position = Vector3(cos(ang) * 0.085, sin(ang) * 0.085, 0.0)
			petal.scale = Vector3(1.1, 0.85, 0.45)
			flower_root.add_child(petal)
		var center_bud := _sphere(0.05, gold_mat)
		flower_root.add_child(center_bud)
		_head_pivot.add_child(flower_root)

	elif cid == "kickboxer":
		# Spiky Anime Fighter Hair + Crimson Hachimaki Headband with Fluttering Tails
		for s_cfg in [
			[0.0, 0.84, 0.05, 0.1, 0.0],
			[-0.22, 0.78, -0.05, -0.2, 0.45],
			[0.22, 0.78, -0.05, -0.2, -0.45],
			[0.0, 0.72, -0.32, -0.7, 0.0],
			[-0.26, 0.64, -0.26, -0.5, 0.6],
			[0.26, 0.64, -0.26, -0.5, -0.6],
		]:
			var spike := _cyl(0.0, 0.12, 0.36, hair_mat)
			spike.position = Vector3(s_cfg[0], s_cfg[1], s_cfg[2])
			spike.rotation.x = s_cfg[3]
			spike.rotation.z = s_cfg[4]
			_head_pivot.add_child(spike)

		var band_mat := _mat(Color.html("#ef4444"), 0.4, 0.1, Color.html("#dc2626"), 0.2)
		var band := _torus(0.37, 0.44, band_mat)
		band.position = Vector3(0.0, 0.54, 0.0)
		_head_pivot.add_child(band)

		_scarf_node = Node3D.new()
		_scarf_node.position = Vector3(0.0, 0.52, -0.43)
		for side in [-1.0, 1.0]:
			var ribbon := _box(Vector3(0.09, 0.52, 0.03), band_mat)
			ribbon.position = Vector3(0.09 * side, -0.22, -0.10)
			ribbon.rotation.x = 0.42
			ribbon.rotation.z = 0.22 * side
			_scarf_node.add_child(ribbon)
		_head_pivot.add_child(_scarf_node)

	elif cid == "swordsman":
		# Samurai Tied Topknot + Golden Crescent Kuwagata Crest
		var bun := _sphere(0.14, hair_mat)
		bun.position = Vector3(0.0, 0.78, -0.18)
		_head_pivot.add_child(bun)

		var pony := _cyl(0.11, 0.03, 0.62, hair_mat)
		pony.position = Vector3(0.0, 0.52, -0.46)
		pony.rotation.x = 0.65
		_head_pivot.add_child(pony)

		# Golden Samurai Crescent Forehead Crest
		for side in [-1.0, 1.0]:
			var horn := _cyl(0.0, 0.055, 0.44, gold_mat)
			horn.position = Vector3(0.15 * side, 0.76, 0.28)
			horn.rotation.z = -0.58 * side
			horn.rotation.x = 0.18
			_head_pivot.add_child(horn)

		var gem := _sphere(0.07, _mat_unshaded(Color.html("#ef4444"), 1.0))
		gem.position = Vector3(0.0, 0.64, 0.38)
		_head_pivot.add_child(gem)

	elif cid == "raijin":
		# Electric Spiky Gold Hair + Twin Thunder Horns
		for s_cfg in [
			[0.0, 0.88, -0.02, -0.15, 0.0],
			[-0.25, 0.80, -0.10, -0.25, 0.55],
			[0.25, 0.80, -0.10, -0.25, -0.55],
			[-0.18, 0.72, -0.34, -0.65, 0.35],
			[0.18, 0.72, -0.34, -0.65, -0.35],
		]:
			var sp := _cyl(0.0, 0.11, 0.40, hair_mat)
			sp.position = Vector3(s_cfg[0], s_cfg[1], s_cfg[2])
			sp.rotation.x = s_cfg[3]
			sp.rotation.z = s_cfg[4]
			_head_pivot.add_child(sp)

		var visor := _torus(0.37, 0.43, _mat(Color.html("#1e1b4b"), 0.3, 0.5))
		visor.position = Vector3(0.0, 0.55, 0.0)
		_head_pivot.add_child(visor)

		var bolt := _cyl(0.0, 0.08, 0.38, _mat_unshaded(Color.html("#facc15"), 1.0))
		bolt.position = Vector3(0.0, 0.76, 0.32)
		bolt.rotation.x = 0.32
		_head_pivot.add_child(bolt)

	elif cid == "yukionna":
		# Long Flowing Silver-Blue Princess Hair + Multi-Pronged Ice Crystal Tiara
		var back_hair := _cyl(0.36, 0.44, 1.15, hair_mat)
		back_hair.position = Vector3(0.0, -0.10, -0.20)
		back_hair.scale = Vector3(1.0, 1.0, 0.55)
		_head_pivot.add_child(back_hair)

		var crystal_mat := _mat(Color.html("#67e8f9"), 0.12, 0.4, Color.html("#38bdf8"), 0.75)
		var tiara_band := _torus(0.32, 0.37, crystal_mat)
		tiara_band.position = Vector3(0.0, 0.66, 0.0)
		_head_pivot.add_child(tiara_band)

		for prong in [[0.0, 0.88, 0.24, 0.30, 0.0], [-0.18, 0.80, 0.20, 0.22, 0.32], [0.18, 0.80, 0.20, 0.22, -0.32]]:
			var shard := _cyl(0.0, 0.065, prong[3], crystal_mat)
			shard.position = Vector3(prong[0], prong[1], prong[2])
			shard.rotation.z = prong[4]
			_head_pivot.add_child(shard)


func _build_back_and_orbit_accessories(
	cid: String,
	col_primary: Color,
	_col_secondary: Color,
	gold_mat: StandardMaterial3D
) -> void:
	if cid == "swordsman" or cid == "raijin":
		# Heroic Flowing Scarf around Neck!
		var scarf_col := Color.html("#dc2626") if cid == "swordsman" else Color.html("#facc15")
		var scarf_mat := _mat(scarf_col, 0.45, 0.1, scarf_col, 0.25 if cid == "raijin" else 0.08)
		var collar := _torus(0.22, 0.31, scarf_mat)
		collar.position = Vector3(0.0, 1.54, 0.0)
		_body_pivot.add_child(collar)

		_scarf_node = Node3D.new()
		_scarf_node.position = Vector3(0.0, 1.52, -0.26)
		var streamer := _box(Vector3(0.22, 0.85, 0.05), scarf_mat)
		streamer.position = Vector3(0.0, -0.36, -0.20)
		streamer.rotation.x = 0.48
		_scarf_node.add_child(streamer)
		_body_pivot.add_child(_scarf_node)

	if cid == "raijin":
		# Iconic Raijin Floating Thunder-Drum Ring behind Back!
		_orbit_group = Node3D.new()
		_orbit_group.position = Vector3(0.0, 1.55, -0.45)
		var ring := _torus(0.60, 0.65, _mat_unshaded(Color.html("#facc15"), 0.75))
		ring.rotation.x = PI * 0.5
		_orbit_group.add_child(ring)

		for i in range(5):
			var ang := float(i) * TAU / 5.0
			var drum := _cyl(0.11, 0.11, 0.08, gold_mat)
			drum.position = Vector3(cos(ang) * 0.62, sin(ang) * 0.62, 0.0)
			drum.rotation.x = PI * 0.5
			_orbit_group.add_child(drum)
		_body_pivot.add_child(_orbit_group)

	elif cid == "yukionna":
		# Orbiting Floating Translucent Ice Crystals!
		_orbit_group = Node3D.new()
		_orbit_group.position = Vector3(0.0, 1.35, 0.0)
		var ice_mat := _mat(Color.html("#a5f3fc"), 0.1, 0.3, Color.html("#22d3ee"), 0.85)
		for i in range(4):
			var ang := float(i) * TAU / 4.0
			var shard := _cyl(0.0, 0.09, 0.36, ice_mat)
			shard.position = Vector3(cos(ang) * 0.88, sin(float(i) * 1.5) * 0.2, sin(ang) * 0.88)
			_orbit_group.add_child(shard)
		_body_pivot.add_child(_orbit_group)

	elif cid == "sakura":
		# Floating Sacred Sakura Spirit Orbs!
		_orbit_group = Node3D.new()
		_orbit_group.position = Vector3(0.0, 1.40, 0.0)
		var orb_mat := _mat_unshaded(col_primary.lightened(0.25), 0.9)
		for i in range(3):
			var ang := float(i) * TAU / 3.0
			var orb := _sphere(0.085, orb_mat)
			orb.position = Vector3(cos(ang) * 0.85, 0.12 * sin(ang), sin(ang) * 0.85)
			_orbit_group.add_child(orb)
		_body_pivot.add_child(_orbit_group)


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

	# Vertical position: flying kick arc or gentle idle breathing bob
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
			_right_leg.rotation.x = -1.35 # Extended flying kick!
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

	# 3-Hit Combo Slash Animation + Glowing Crescent Slash Arc!
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
				_body_pivot.rotation.y = p * TAU # 360-degree heavy finisher spin!
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


# ==================== MESH / MATERIAL HELPERS ====================
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


func _mat_unshaded(col: Color, alpha: float = 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(col.r, col.g, col.b, alpha)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m


func _cyl(top_r: float, bot_r: float, h: float, mat: Material, segs: int = 14) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top_r
	mesh.bottom_radius = bot_r
	mesh.height = h
	mesh.radial_segments = segs
	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	inst.material_override = mat
	return inst


func _sphere(r: float, mat: Material, segs: int = 16) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = r
	mesh.height = r * 2.0
	mesh.radial_segments = segs
	mesh.rings = 10
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
