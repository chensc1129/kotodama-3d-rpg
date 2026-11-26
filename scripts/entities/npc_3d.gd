class_name Npc3D
extends Node3D
## Interactive 3D NPC entity for Chapter 1 Japanese ARPG Adventure Mode.
## Renders anime cel-shaded .glb characters (and Elder Byakko floating fox spirit),
## unshaded ground halo ring, billboard CJK nameplate, and animated quest marker.

const NPC_MODELS: Dictionary = {
	"sakura": "res://assets/models/hero_sakura.glb",
	"swordsman": "res://assets/models/hero_swordsman.glb",
	"kickboxer": "res://assets/models/hero_kickboxer.glb",
	"yukionna": "res://assets/models/hero_yukionna.glb",
	"kitsune": "res://assets/models/sh_kitsune.glb",
}

const FONT_PATH: String = "res://assets/fonts/noto_cjk_game.otf"
const NAMEPLATE_Y: float = 2.65
const MARKER_BASE_Y: float = 3.25

static var _cached_font: Font = null
static var _font_checked: bool = false

var npc_id: String = ""
var npc_name: String = ""
var npc_data: Dictionary = {}
var interaction_radius: float = 5.4

var _visual_root: Node3D
var _model_holder: Node3D
var _body_pivot: Node3D
var _tail_pivot: Node3D
var _orbit_node: Node3D
var _halo_mesh: MeshInstance3D
var _halo_mat: StandardMaterial3D
var _name_label: Label3D
var _quest_label: Label3D

var _accent_color: Color = Color.html("#e8c474")
var _base_facing: float = 0.0
var _base_model_y: float = 0.0
var _is_kitsune: bool = false
var _is_nearby: bool = false
var _elapsed: float = 0.0
var _marker_state: String = "none"


static func _get_cjk_font() -> Font:
	if not _font_checked:
		_font_checked = true
		if ResourceLoader.exists("res://resources/ui_theme.tres"):
			var th := load("res://resources/ui_theme.tres") as Theme
			if th != null and th.default_font != null:
				_cached_font = th.default_font
		if _cached_font == null and ResourceLoader.exists(FONT_PATH):
			_cached_font = load(FONT_PATH) as Font
	return _cached_font


func setup(data: Dictionary, ground_y: float) -> void:
	for child in get_children():
		child.queue_free()

	_visual_root = null
	_model_holder = null
	_body_pivot = null
	_tail_pivot = null
	_orbit_node = null
	_halo_mesh = null
	_halo_mat = null
	_name_label = null
	_quest_label = null

	npc_data = data
	npc_id = String(data.get("id", ""))
	npc_name = String(data.get("name", "NPC"))
	_base_facing = float(data.get("facing", 0.0))
	_elapsed = randf() * TAU
	_is_nearby = false

	var raw_pos: Variant = data.get("pos", Vector3.ZERO)
	if raw_pos is Vector3:
		var p3: Vector3 = raw_pos
		position = Vector3(p3.x, ground_y, p3.z)
	elif raw_pos is Vector2:
		var p2: Vector2 = raw_pos
		position = Vector3(p2.x, ground_y, p2.y)
	else:
		position = Vector3(0.0, ground_y, 0.0)

	var accent_hex: String = String(data.get("accent", data.get("color", "#e8c474")))
	_accent_color = Color.html(accent_hex)
	var model_key: String = String(data.get("model", "sakura"))
	_is_kitsune = (model_key == "kitsune")

	# Visual root handles facing rotation cleanly without spinning labels
	_visual_root = Node3D.new()
	_visual_root.name = "VisualRoot"
	_visual_root.rotation.y = _base_facing
	add_child(_visual_root)

	_model_holder = Node3D.new()
	_model_holder.name = "ModelHolder"
	_visual_root.add_child(_model_holder)

	var model_path: String = String(NPC_MODELS.get(model_key, NPC_MODELS["sakura"]))
	var packed: PackedScene = load(model_path) as PackedScene
	if packed != null:
		var inst: Node = packed.instantiate()
		_model_holder.add_child(inst)
		var outline_w: float = 0.0 if UiStyle.is_mobile_device() else 0.012
		ToonMaterialHelper.apply_anime_toon(inst, outline_w, _accent_color.lerp(Color.WHITE, 0.5), 0.45)

		_body_pivot = inst.find_child("BodyPivot", true, false) as Node3D
		_tail_pivot = inst.find_child("TailPivot", true, false) as Node3D
		_orbit_node = inst.find_child("OrbitNode", true, false) as Node3D
		if _orbit_node == null:
			_orbit_node = inst.find_child("OrbitGroup", true, false) as Node3D

	if _is_kitsune:
		_model_holder.scale = Vector3(1.55, 1.55, 1.55)
		_base_model_y = 0.45
		_model_holder.position.y = _base_model_y
	else:
		_base_model_y = 0.0
		_model_holder.position.y = 0.0

	# Soft unshaded ground halo ring (20x6 TorusMesh, shadows off)
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 1.02
	ring_mesh.outer_radius = 1.24
	ring_mesh.rings = 20
	ring_mesh.ring_segments = 6

	_halo_mat = StandardMaterial3D.new()
	_halo_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_halo_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_halo_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_halo_mat.albedo_color = Color(_accent_color.r, _accent_color.g, _accent_color.b, 0.50)

	_halo_mesh = MeshInstance3D.new()
	_halo_mesh.name = "GroundHalo"
	_halo_mesh.mesh = ring_mesh
	_halo_mesh.material_override = _halo_mat
	_halo_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_halo_mesh.position = Vector3(0.0, 0.08, 0.0)
	_halo_mesh.scale = Vector3(1.0, 0.14, 1.0)
	add_child(_halo_mesh)

	var cjk_font: Font = _get_cjk_font()

	# Floating 3D Nameplate (uses crisp vector glyphs so 3D Label3D never renders tofu boxes)
	_name_label = Label3D.new()
	_name_label.name = "Nameplate"
	_name_label.text = npc_name
	_name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_name_label.no_depth_test = true
	_name_label.position = Vector3(0.0, NAMEPLATE_Y, 0.0)
	_name_label.pixel_size = 0.0085
	_name_label.font_size = 34
	_name_label.outline_size = 10
	_name_label.modulate = Color.html("#fef3c7")
	_name_label.outline_modulate = Color.html("#0a0f1e")
	if cjk_font != null:
		_name_label.font = cjk_font
	add_child(_name_label)

	# Floating 3D Quest Marker above nameplate
	_quest_label = Label3D.new()
	_quest_label.name = "QuestMarker"
	_quest_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_quest_label.no_depth_test = true
	_quest_label.position = Vector3(0.0, MARKER_BASE_Y, 0.0)
	_quest_label.pixel_size = 0.0092
	_quest_label.font_size = 36
	_quest_label.outline_size = 12
	_quest_label.outline_modulate = Color.html("#0a0f1e")
	_quest_label.visible = false
	if cjk_font != null:
		_quest_label.font = cjk_font
	add_child(_quest_label)

	var initial_marker: String = String(data.get("marker", "none"))
	set_quest_marker(initial_marker)


func set_quest_marker(state: String) -> void:
	_marker_state = state
	if _quest_label == null:
		return
	match state:
		"story":
			_quest_label.text = "★ 主線"
			_quest_label.modulate = Color.html("#fde047")
			_quest_label.visible = true
		"quiz":
			_quest_label.text = "◆ 日文試煉"
			_quest_label.modulate = Color.html("#38bdf8")
			_quest_label.visible = true
		"done":
			_quest_label.text = "✓ 已完成"
			_quest_label.modulate = Color.html("#4ade80")
			_quest_label.visible = true
		_:
			_quest_label.text = ""
			_quest_label.visible = false


func set_player_nearby(nearby: bool, player_pos: Vector3, delta: float) -> void:
	_is_nearby = nearby
	var dt: float = minf(0.05, maxf(0.0, delta))

	if _visual_root != null:
		var target_yaw: float = _base_facing
		if nearby:
			var my_pos: Vector3 = global_position if is_inside_tree() else position
			var dx: float = player_pos.x - my_pos.x
			var dz: float = player_pos.z - my_pos.z
			if dx * dx + dz * dz > 0.0004:
				target_yaw = atan2(dx, dz)
		var turn_t: float = 1.0 - exp(-7.5 * dt)
		_visual_root.rotation.y = lerp_angle(_visual_root.rotation.y, target_yaw, turn_t)

	if _halo_mat != null and _halo_mesh != null:
		var pulse_t: float = 1.0 - exp(-8.0 * dt)
		if nearby:
			var pulse: float = 0.5 + 0.5 * sin(_elapsed * 5.8)
			var bright_col: Color = _accent_color.lerp(Color.WHITE, 0.35 + pulse * 0.25)
			bright_col.a = 0.72 + pulse * 0.24
			_halo_mat.albedo_color = _halo_mat.albedo_color.lerp(bright_col, pulse_t)
			var target_s: float = 1.12 + pulse * 0.07
			_halo_mesh.scale = _halo_mesh.scale.lerp(Vector3(target_s, 0.16, target_s), pulse_t)
		else:
			var idle_pulse: float = 0.5 + 0.5 * sin(_elapsed * 2.2)
			var idle_col := Color(_accent_color.r, _accent_color.g, _accent_color.b, 0.40 + idle_pulse * 0.14)
			_halo_mat.albedo_color = _halo_mat.albedo_color.lerp(idle_col, pulse_t)
			_halo_mesh.scale = _halo_mesh.scale.lerp(Vector3(1.0, 0.14, 1.0), pulse_t)


func _process(delta: float) -> void:
	var dt: float = minf(0.05, delta)
	_elapsed += dt

	# Gentle bobbing for quest marker above nameplate
	if _quest_label != null and _quest_label.visible:
		var bob_speed: float = 4.2 if _marker_state == "story" else 3.2
		_quest_label.position.y = MARKER_BASE_Y + sin(_elapsed * bob_speed) * 0.13
		var pulse_s: float = 1.0 + sin(_elapsed * bob_speed) * 0.05
		_quest_label.scale = Vector3(pulse_s, pulse_s, pulse_s)

	# Mystical hover for kitsune spirit / subtle idle breathing for humanoids
	if _model_holder != null:
		if _is_kitsune:
			_model_holder.position.y = _base_model_y + sin(_elapsed * 2.8) * 0.18
		elif _body_pivot != null:
			var breath: float = 1.0 + sin(_elapsed * 2.4) * 0.014
			_body_pivot.scale = Vector3(1.0, breath, 1.0)

	if _tail_pivot != null:
		_tail_pivot.rotation.y = sin(_elapsed * 5.2) * 0.30
		_tail_pivot.rotation.x = sin(_elapsed * 3.8) * 0.16
	if _orbit_node != null:
		_orbit_node.rotation.y = _elapsed * 1.9

	if _halo_mesh != null:
		_halo_mesh.rotation.y += dt * (1.8 if _is_nearby else 0.75)
