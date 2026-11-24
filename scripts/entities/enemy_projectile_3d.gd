class_name EnemyProjectile3D
extends MeshInstance3D
## Enemy ranged fireball projectile.

var direction: Vector3 = Vector3.FORWARD
var dmg: int = 10
var life: float = 2.6


func setup(origin: Vector3, dir: Vector3, damage: int) -> void:
	direction = Vector3(dir.x, 0.0, dir.z).normalized()
	dmg = damage
	life = 2.6
	position = Vector3(origin.x, 1.2, origin.z)

	var sphere := SphereMesh.new()
	sphere.radius = 0.32
	sphere.height = 0.64
	mesh = sphere

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color.html("#f43f5e")
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material_override = mat
