class_name Shikigami3D
extends Node3D
## Floating Shikigami spirit companion mesh that smoothly follows the player.

var _visual: Node3D
var _elapsed: float = 0.0


func _ready() -> void:
	_visual = Node3D.new()
	add_child(_visual)


func rebuild_mesh(player_pos: Vector3) -> void:
	for child in _visual.get_children():
		child.queue_free()

	var sh_id: String = GameState.player.get("active_shikigami", "none")
	if sh_id == "none":
		visible = false
		return

	visible = true
	var cfg: Dictionary = GameData.get_shikigami(sh_id)
	var col := Color.html(cfg.get("color", "#f97316"))

	var body_mat := StandardMaterial3D.new()
	body_mat.albedo_color = col
	body_mat.emission_enabled = true
	body_mat.emission = col
	body_mat.emission_energy_multiplier = 0.45

	var body_mesh := SphereMesh.new()
	body_mesh.radius = 0.35
	body_mesh.height = 0.70
	var body := MeshInstance3D.new()
	body.mesh = body_mesh
	body.material_override = body_mat
	_visual.add_child(body)

	var ear_mat := StandardMaterial3D.new()
	ear_mat.albedo_color = Color.WHITE
	ear_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var ear_mesh := CylinderMesh.new()
	ear_mesh.top_radius = 0.0
	ear_mesh.bottom_radius = 0.12
	ear_mesh.height = 0.30
	ear_mesh.radial_segments = 8

	for ex in [-0.18, 0.18]:
		var ear := MeshInstance3D.new()
		ear.mesh = ear_mesh
		ear.material_override = ear_mat
		ear.position = Vector3(ex, 0.36, 0.0)
		_visual.add_child(ear)

	position = Vector3(player_pos.x - 1.3, 1.5, player_pos.z + 0.8)


func update_follow(delta: float, player_pos: Vector3, player_facing: float) -> void:
	if not visible:
		return
	_elapsed += delta
	var target := Vector3(
		player_pos.x - sin(player_facing) * 1.2 - 0.7,
		1.55 + sin(_elapsed * 5.0) * 0.2,
		player_pos.z - cos(player_facing) * 1.2 + 0.7
	)
	position = position.lerp(target, clampf(delta * 6.0, 0.0, 1.0))
	rotation.y += delta * 2.5
