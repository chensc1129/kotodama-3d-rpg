class_name Shikigami3D
extends Node3D
## Loads sculpted textured .glb Shikigami companions with anime cel-shading + ink outlines.

const SHIKIGAMI_MODELS: Dictionary = {
	"kitsune": "res://assets/models/sh_kitsune.glb",
	"neko": "res://assets/models/sh_neko.glb",
	"raiju": "res://assets/models/sh_raiju.glb",
}

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
	if sh_id == "none" or not SHIKIGAMI_MODELS.has(sh_id):
		visible = false
		return

	visible = true
	var cfg: Dictionary = GameData.get_shikigami(sh_id)
	var rim_col := Color.html(cfg.get("color", "#f97316")).lerp(Color.WHITE, 0.45)

	var packed: PackedScene = load(SHIKIGAMI_MODELS[sh_id]) as PackedScene
	if packed != null:
		var inst := packed.instantiate()
		_visual.add_child(inst)
		ToonMaterialHelper.apply_anime_toon(inst, 0.011, rim_col, 0.50)
		_tail_pivot = inst.find_child("TailPivot", true, false) as Node3D
		_orbit_node = inst.find_child("OrbitNode", true, false) as Node3D

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
