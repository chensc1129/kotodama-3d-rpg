class_name EnemyProjectile3D
extends MeshInstance3D
## Enemy ranged fireball projectile using shared low-poly mesh & unshaded material.

static var _shared_mesh: SphereMesh
static var _shared_mat: StandardMaterial3D

var direction: Vector3 = Vector3.FORWARD
var dmg: int = 10
var life: float = 3.6


func setup(origin: Vector3, dir: Vector3, damage: int) -> void:
	direction = dir.normalized() if dir.length_squared() > 0.0001 else Vector3.FORWARD
	dmg = damage
	life = 3.6
	position = Vector3(origin.x, origin.y + 1.2, origin.z)
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	if _shared_mesh == null:
		_shared_mesh = SphereMesh.new()
		_shared_mesh.radius = 0.32
		_shared_mesh.height = 0.64
		_shared_mesh.radial_segments = 10
		_shared_mesh.rings = 6
	if _shared_mat == null:
		_shared_mat = StandardMaterial3D.new()
		_shared_mat.albedo_color = Color.html("#f43f5e")
		_shared_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	mesh = _shared_mesh
	material_override = _shared_mat
