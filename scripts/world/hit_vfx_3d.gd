class_name HitVfx3D
extends Node3D
## GL-Compatibility (WebGL2) safe 3D impact sparks, anime slash-cross flashes,
## critical starbursts, and yokai death shatter bursts.

var _life: float = 0.0
var _max_life: float = 0.35
var _flash_nodes: Array[MeshInstance3D] = []
var _flash_mats: Array[StandardMaterial3D] = []
var _flash_base_scales: Array[Vector3] = []
var _flash_duration: float = 0.16


func setup_hit_spark(world_pos: Vector3, color: Color, is_crit: bool = false, intensity: float = 1.0) -> void:
	position = world_pos
	_max_life = 0.45 if is_crit else 0.34
	_flash_duration = 0.20 if is_crit else 0.14

	# 1. Crossed anime impact slash-flash blades (white-hot core + colored cross)
	var slash_angle := randf() * PI
	var main_len := (2.6 if is_crit else 1.75) * intensity
	var main_thick := (0.20 if is_crit else 0.14) * intensity
	_add_flash_blade(Vector3(main_len, main_thick, main_thick), Vector3(0.0, randf() * TAU, slash_angle), Color.WHITE)
	_add_flash_blade(Vector3(main_len * 0.72, main_thick * 0.85, main_thick * 0.85), Vector3(0.0, randf() * TAU, slash_angle + PI * 0.5), color.lerp(Color.WHITE, 0.35))

	if is_crit:
		# Extra golden diagonal starburst + bright impact core flash
		_add_flash_blade(Vector3(main_len * 0.92, main_thick * 0.9, main_thick * 0.9), Vector3(0.4, randf() * TAU, slash_angle + PI * 0.25), Color.html("#fde047"))
		_add_flash_sphere(0.55 * intensity, Color.html("#fef9c3"))
	else:
		_add_flash_sphere(0.32 * intensity, color.lerp(Color.WHITE, 0.6))

	# 2. Directional radial impact spark particles (CPUParticles3D for WebGL2 safety)
	var is_mob := UiStyle.is_mobile_device()
	var particles := CPUParticles3D.new()
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	particles.emitting = false
	particles.one_shot = true
	particles.explosiveness = 0.95
	var base_amt := 22 if is_crit else 12
	particles.amount = maxi(4, int(round(float(base_amt) * (0.45 if is_mob else 1.0))))
	particles.lifetime = 0.34 if is_crit else 0.24
	particles.direction = Vector3(0.0, 0.4, 0.0)
	particles.spread = 180.0
	particles.initial_velocity_min = (5.5 if is_crit else 3.8) * intensity
	particles.initial_velocity_max = (10.5 if is_crit else 7.2) * intensity
	particles.gravity = Vector3(0.0, -14.0, 0.0)
	particles.damping_min = 3.0
	particles.damping_max = 5.0
	particles.scale_amount_min = 0.6
	particles.scale_amount_max = 1.35 if is_crit else 1.0

	var spark_mesh := BoxMesh.new()
	spark_mesh.size = Vector3(0.11, 0.11, 0.32) if is_crit else Vector3(0.09, 0.09, 0.24)
	var pmat := StandardMaterial3D.new()
	pmat.albedo_color = Color.html("#fde047") if is_crit else color.lerp(Color.WHITE, 0.45)
	pmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	spark_mesh.material = pmat
	particles.mesh = spark_mesh
	particles.particle_flag_align_y = true
	add_child(particles)
	particles.emitting = true


func setup_death_burst(world_pos: Vector3, color: Color, is_boss: bool = false) -> void:
	position = world_pos
	_max_life = 0.85 if is_boss else 0.55
	_flash_duration = 0.32 if is_boss else 0.20

	var sc := 1.85 if is_boss else 1.0
	_add_flash_sphere(0.95 * sc, color.lerp(Color.WHITE, 0.55))
	_add_flash_blade(Vector3(3.4 * sc, 0.24 * sc, 0.24 * sc), Vector3(0.0, 0.0, 0.35), Color.WHITE)
	_add_flash_blade(Vector3(3.0 * sc, 0.22 * sc, 0.22 * sc), Vector3(0.0, PI * 0.5, -0.35), color.lerp(Color.html("#fde047"), 0.5))

	var is_mob := UiStyle.is_mobile_device()
	var particles := CPUParticles3D.new()
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	particles.emitting = false
	particles.one_shot = true
	particles.explosiveness = 0.94
	var base_amt := 42 if is_boss else 24
	particles.amount = maxi(8, int(round(float(base_amt) * (0.45 if is_mob else 1.0))))
	particles.lifetime = 0.72 if is_boss else 0.46
	particles.direction = Vector3(0.0, 1.0, 0.0)
	particles.spread = 155.0
	particles.initial_velocity_min = 4.5 * sc
	particles.initial_velocity_max = 11.0 * sc
	particles.gravity = Vector3(0.0, -11.0, 0.0)
	particles.damping_min = 2.0
	particles.damping_max = 4.0
	particles.scale_amount_min = 0.7
	particles.scale_amount_max = 1.6

	var shard := BoxMesh.new()
	shard.size = Vector3(0.22, 0.22, 0.22) * (1.25 if is_boss else 0.95)
	var smat := StandardMaterial3D.new()
	smat.albedo_color = color.lerp(Color.WHITE, 0.35)
	smat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shard.material = smat
	particles.mesh = shard
	add_child(particles)
	particles.emitting = true


func _add_flash_blade(size_vec: Vector3, rot_vec: Vector3, col: Color) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size_vec
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(col.r, col.g, col.b, 0.96)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	inst.material_override = mat
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	inst.rotation = rot_vec
	inst.scale = Vector3(0.35, 1.0, 1.0)
	add_child(inst)

	_flash_nodes.append(inst)
	_flash_mats.append(mat)
	_flash_base_scales.append(Vector3.ONE)


func _add_flash_sphere(radius: float, col: Color) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 10
	mesh.rings = 6
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(col.r, col.g, col.b, 0.88)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	inst.material_override = mat
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(inst)

	_flash_nodes.append(inst)
	_flash_mats.append(mat)
	_flash_base_scales.append(Vector3(1.4, 1.4, 1.4))


func _process(delta: float) -> void:
	_life += delta
	if _life >= _max_life:
		queue_free()
		return

	var fp := clampf(_life / _flash_duration, 0.0, 1.0)
	for i in range(_flash_nodes.size()):
		var n := _flash_nodes[i]
		var m := _flash_mats[i]
		if fp >= 1.0:
			n.visible = false
		else:
			var expand := 0.55 + fp * 1.15
			var shrink_y := maxf(0.05, 1.0 - fp * 0.85)
			if _flash_base_scales[i].x > 1.2:
				var s := 0.4 + fp * 1.25
				n.scale = Vector3(s, s, s)
			else:
				n.scale = Vector3(expand, shrink_y, shrink_y)
			m.albedo_color.a = (1.0 - fp) * 0.92
