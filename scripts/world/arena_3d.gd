class_name Arena3D
extends Node3D
## Procedurally builds the 3D Japanese Dojo / Temple / Lava / Sky arena
## with Torii gate, stone lanterns, glowing rings, and falling particles.

@export var world_environment: WorldEnvironment
@export var center_light: OmniLight3D

var _arena_content: Node3D
var _particles: CPUParticles3D


func _ready() -> void:
	_arena_content = Node3D.new()
	_arena_content.name = "ArenaContent"
	add_child(_arena_content)


func build_stage(stage_id: String) -> void:
	var st: Dictionary = GameData.get_stage(stage_id)

	for child in _arena_content.get_children():
		child.queue_free()

	var sky_col := Color.html(st["sky_color"])
	var fog_col := Color.html(st["fog_color"])
	var floor_col := Color.html(st["floor_color"])
	var ring_col := Color.html(st["ring_color"])
	var ambient_col := Color.html(st["ambient_color"])
	var particle_col := Color.html(st["particle_color"])

	# Update WorldEnvironment sky, ambient light, and fog
	if world_environment != null:
		var env := world_environment.environment
		if env == null:
			env = Environment.new()
			world_environment.environment = env
		env.background_mode = Environment.BG_COLOR
		env.background_color = sky_col
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = ambient_col
		env.ambient_light_energy = 0.78
		env.fog_enabled = true
		env.fog_mode = Environment.FOG_MODE_EXPONENTIAL
		env.fog_light_color = fog_col
		env.fog_density = 0.018

	if center_light != null:
		center_light.light_color = ring_col
		center_light.light_energy = 1.6
		center_light.omni_range = 45.0

	var radius: float = GameData.ARENA_RADIUS

	# 1. Main Circular Dojo Platform
	var floor_mesh := CylinderMesh.new()
	floor_mesh.top_radius = radius
	floor_mesh.bottom_radius = radius + 1.2
	floor_mesh.height = 1.2
	floor_mesh.radial_segments = 48
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = floor_col
	floor_mat.roughness = 0.72
	floor_mat.metallic = 0.15
	var floor_inst := MeshInstance3D.new()
	floor_inst.mesh = floor_mesh
	floor_inst.material_override = floor_mat
	floor_inst.position = Vector3(0.0, -0.6, 0.0)
	_arena_content.add_child(floor_inst)

	# 2. Glowing Outer Ring Border & Center Emblem Ring
	var ring_mat := StandardMaterial3D.new()
	ring_mat.albedo_color = ring_col
	ring_mat.emission_enabled = true
	ring_mat.emission = ring_col
	ring_mat.emission_energy_multiplier = 1.1
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	_arena_content.add_child(_make_flat_ring(radius - 0.55, radius, ring_mat, 0.03))
	_arena_content.add_child(_make_flat_ring(3.2, 3.55, ring_mat, 0.03))

	# 3. Torii Gate at North Edge (-Z)
	var torii := Node3D.new()
	torii.position = Vector3(0.0, 0.0, -radius + 0.8)

	var pillar_mat := StandardMaterial3D.new()
	pillar_mat.albedo_color = Color.html("#dc2626")
	pillar_mat.roughness = 0.4

	var cap_mat := StandardMaterial3D.new()
	cap_mat.albedo_color = Color.html("#1e293b")
	cap_mat.roughness = 0.5

	var pillar_mesh := CylinderMesh.new()
	pillar_mesh.top_radius = 0.35
	pillar_mesh.bottom_radius = 0.40
	pillar_mesh.height = 7.2
	pillar_mesh.radial_segments = 16

	for px in [-3.2, 3.2]:
		var p := MeshInstance3D.new()
		p.mesh = pillar_mesh
		p.material_override = pillar_mat
		p.position = Vector3(px, 3.6, 0.0)
		torii.add_child(p)

	var kasagi := MeshInstance3D.new()
	var kasagi_mesh := BoxMesh.new()
	kasagi_mesh.size = Vector3(8.8, 0.55, 0.8)
	kasagi.mesh = kasagi_mesh
	kasagi.material_override = cap_mat
	kasagi.position = Vector3(0.0, 7.3, 0.0)
	torii.add_child(kasagi)

	var nuki := MeshInstance3D.new()
	var nuki_mesh := BoxMesh.new()
	nuki_mesh.size = Vector3(7.6, 0.4, 0.5)
	nuki.mesh = nuki_mesh
	nuki.material_override = pillar_mat
	nuki.position = Vector3(0.0, 5.7, 0.0)
	torii.add_child(nuki)

	_arena_content.add_child(torii)

	# 4. 4 Stone Lanterns around the Arena
	var stone_mat := StandardMaterial3D.new()
	stone_mat.albedo_color = Color.html("#64748b")
	stone_mat.roughness = 0.8

	var roof_mat := StandardMaterial3D.new()
	roof_mat.albedo_color = Color.html("#475569")
	roof_mat.roughness = 0.7

	var glow_mat := StandardMaterial3D.new()
	glow_mat.albedo_color = Color.html("#fde047")
	glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	var base_mesh := BoxMesh.new()
	base_mesh.size = Vector3(1.1, 2.2, 1.1)
	var glow_mesh := BoxMesh.new()
	glow_mesh.size = Vector3(0.75, 0.75, 0.75)
	var roof_mesh := CylinderMesh.new()
	roof_mesh.top_radius = 0.0
	roof_mesh.bottom_radius = 1.15
	roof_mesh.height = 0.9
	roof_mesh.radial_segments = 4

	var angles: Array[float] = [PI * 0.25, PI * 0.75, -PI * 0.25, -PI * 0.75]
	for ang in angles:
		var lg := Node3D.new()
		lg.position = Vector3(cos(ang) * (radius - 1.4), 0.0, sin(ang) * (radius - 1.4))

		var b := MeshInstance3D.new()
		b.mesh = base_mesh
		b.material_override = stone_mat
		b.position = Vector3(0.0, 1.1, 0.0)
		lg.add_child(b)

		var g := MeshInstance3D.new()
		g.mesh = glow_mesh
		g.material_override = glow_mat
		g.position = Vector3(0.0, 2.55, 0.0)
		lg.add_child(g)

		var r := MeshInstance3D.new()
		r.mesh = roof_mesh
		r.material_override = roof_mat
		r.position = Vector3(0.0, 3.35, 0.0)
		r.rotation.y = PI * 0.25
		lg.add_child(r)

		_arena_content.add_child(lg)

	# 5. Ambient Falling Petals / Embers (CPUParticles3D for universal Web/GL Compatibility)
	_particles = CPUParticles3D.new()
	_particles.amount = 90
	_particles.lifetime = 8.0
	_particles.preprocess = 4.0
	_particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_particles.emission_box_extents = Vector3(20.0, 1.0, 20.0)
	_particles.position = Vector3(0.0, 14.0, 0.0)
	_particles.direction = Vector3(0.15, -1.0, 0.1)
	_particles.spread = 20.0
	_particles.gravity = Vector3(0.0, -0.15, 0.0)
	_particles.initial_velocity_min = 1.2
	_particles.initial_velocity_max = 2.0

	var p_mesh := QuadMesh.new()
	p_mesh.size = Vector2(0.26, 0.26)
	var p_mat := StandardMaterial3D.new()
	p_mat.albedo_color = particle_col
	p_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	p_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	p_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	p_mat.albedo_color.a = 0.85
	p_mesh.material = p_mat
	_particles.mesh = p_mesh
	_arena_content.add_child(_particles)


func _make_flat_ring(inner_r: float, outer_r: float, mat: Material, y_pos: float) -> MeshInstance3D:
	var torus := TorusMesh.new()
	torus.inner_radius = inner_r
	torus.outer_radius = outer_r
	torus.rings = 48
	torus.ring_segments = 8
	var inst := MeshInstance3D.new()
	inst.mesh = torus
	inst.material_override = mat
	inst.position = Vector3(0.0, y_pos, 0.0)
	inst.scale = Vector3(1.0, 0.06, 1.0)
	return inst
