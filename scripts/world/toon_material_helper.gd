class_name ToonMaterialHelper
extends RefCounted
## Converts imported .glb StandardMaterial3D surfaces into Anime Cel-Shaded ShaderMaterials
## with optional crisp dark ink outlines, returning material references for runtime tinting.

const TOON_SHADER: Shader = preload("res://assets/shaders/anime_toon.gdshader")
const OUTLINE_SHADER: Shader = preload("res://assets/shaders/ink_outline.gdshader")


static func apply_anime_toon(
	root: Node,
	outline_width: float = 0.014,
	rim_color: Color = Color.html("#fff1e6"),
	rim_strength: float = 0.40
) -> Array[ShaderMaterial]:
	var mats: Array[ShaderMaterial] = []
	var outline_mat := ShaderMaterial.new()
	outline_mat.shader = OUTLINE_SHADER
	outline_mat.set_shader_parameter("outline_width", outline_width)
	outline_mat.set_shader_parameter("outline_color", Color(0.07, 0.05, 0.13, 1.0))

	_walk_meshes(root, outline_mat, outline_width > 0.0, rim_color, rim_strength, mats)
	return mats


static func _walk_meshes(
	node: Node,
	outline_mat: ShaderMaterial,
	use_outline: bool,
	rim_color: Color,
	rim_strength: float,
	out_mats: Array[ShaderMaterial]
) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if mi.mesh != null:
			var surf_count := mi.mesh.get_surface_count()
			for i in range(surf_count):
				var src_mat: Material = mi.get_active_material(i)
				if src_mat == null:
					src_mat = mi.mesh.surface_get_material(i)
				var sm := ShaderMaterial.new()
				sm.shader = TOON_SHADER
				sm.set_shader_parameter("rim_color", rim_color)
				sm.set_shader_parameter("rim_strength", rim_strength)

				var is_emissive_only := false
				if src_mat is StandardMaterial3D:
					var std := src_mat as StandardMaterial3D
					sm.set_shader_parameter("albedo_color", std.albedo_color)
					if std.albedo_texture != null:
						sm.set_shader_parameter("albedo_texture", std.albedo_texture)
						sm.set_shader_parameter("use_texture", true)
					sm.set_shader_parameter("roughness_val", std.roughness)
					sm.set_shader_parameter("metallic_val", std.metallic)
					if std.emission_enabled:
						sm.set_shader_parameter("emission_color", std.emission)
						sm.set_shader_parameter("emission_energy", std.emission_energy_multiplier)
						if std.emission_energy_multiplier >= 1.2:
							is_emissive_only = true

				if use_outline and not is_emissive_only and not mi.name.begins_with("NoOutline"):
					sm.next_pass = outline_mat

				mi.set_surface_override_material(i, sm)
				out_mats.append(sm)

	for child in node.get_children():
		_walk_meshes(child, outline_mat, use_outline, rim_color, rim_strength, out_mats)
