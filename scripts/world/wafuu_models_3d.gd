class_name WafuuModels3D
extends RefCounted

## High-craft procedural 3D Japanese architectural and botanical modeling library
## for Godot 4.3 (GL Compatibility / WebGL2).
## All procedural meshes emit per-vertex COLOR gradients and valid outward normals
## for use with `wafuu_prop.gdshader`, with shadows disabled and minimal draw calls.

const WAFUU_PROP_SHADER: Shader = preload("res://assets/shaders/wafuu_prop.gdshader")
const LEAF_SHADER_PATH: String = "res://assets/shaders/tree_leaves_alpha.gdshader"
const LEAF_TEX_PATHS: Dictionary = {
	"sakura": "res://assets/textures/foliage/leaf_sakura_branch.png",
	"maple": "res://assets/textures/foliage/leaf_maple_branch.png",
	"pine": "res://assets/textures/foliage/leaf_pine_branch.png",
	"broadleaf": "res://assets/textures/foliage/leaf_broadleaf_branch.png",
}


# ==============================================================================
# 1. MATERIAL FACTORY HELPERS
# ==============================================================================

static func make_wafuu_mat(
	surface_mode: int,
	is_mob: bool,
	roughness: float = 0.72,
	metallic: float = 0.04,
	moss: float = 0.0
) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = WAFUU_PROP_SHADER
	mat.set_shader_parameter("surface_mode", surface_mode)
	mat.set_shader_parameter("base_tint", Color.WHITE)
	mat.set_shader_parameter("roughness_base", roughness)
	mat.set_shader_parameter("metallic_base", metallic)
	mat.set_shader_parameter("moss_amount", moss)
	mat.set_shader_parameter("mobile_mode", is_mob)
	return mat


static func detect_tree_species(leaf_hex: String) -> String:
	## Auto-detects botanical tree species from a legacy leaf hex color so all
	## existing callers seamlessly render authentic species-specific leaf cards.
	var c: Color = Color.html(leaf_hex)
	if c.r > 0.65 and c.b > 0.42 and c.r >= c.g:
		return "sakura"
	if c.r > 0.52 and c.r > c.g * 1.10 and c.r > c.b * 1.45:
		return "maple"
	if c.g >= c.r and c.v < 0.48 and (c.b > c.r * 1.15 or c.v < 0.40):
		return "pine"
	if c.g >= c.r * 0.90:
		return "broadleaf"
	return "sakura"


static func make_leaf_card_mat(
	species: String,
	is_mob: bool,
	tint: Color = Color.WHITE
) -> Material:
	## Creates an alpha-cutout 3D real-leaf branch card material bound to
	## `tree_leaves_alpha.gdshader` and the matching 512x512 botanical texture.
	var sp_key: String = species if LEAF_TEX_PATHS.has(species) else "sakura"
	if ResourceLoader.exists(LEAF_SHADER_PATH):
		var sh: Shader = load(LEAF_SHADER_PATH) as Shader
		if sh != null:
			var mat := ShaderMaterial.new()
			mat.shader = sh
			var tex_path: String = str(LEAF_TEX_PATHS[sp_key])
			if ResourceLoader.exists(tex_path):
				var tex: Texture2D = load(tex_path) as Texture2D
				if tex != null:
					mat.set_shader_parameter("leaf_tex", tex)
			mat.set_shader_parameter("alpha_cutoff", 0.42)
			var wind_f: float = 1.15 if sp_key == "sakura" else (1.05 if sp_key == "maple" else (0.72 if sp_key == "pine" else 0.95))
			mat.set_shader_parameter("wind_strength", wind_f)
			mat.set_shader_parameter("wind_dir", Vector2(0.85, 0.52))
			mat.set_shader_parameter("wind_gust", 0.0)
			mat.set_shader_parameter("gust_time", 99.0)
			mat.set_shader_parameter("gust_strength", 1.0)
			mat.set_shader_parameter("tint_color", tint)
			mat.set_shader_parameter("translucency", 0.20 if sp_key == "sakura" else 0.14)
			mat.set_shader_parameter("mobile_mode", is_mob)
			return mat
	return make_wafuu_mat(1, is_mob, 0.56, 0.02, 0.0)


static func make_glow_mat(hex: String, alpha: float = 1.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	var c: Color = Color.html(hex)
	c.a = alpha
	mat.albedo_color = c
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if alpha < 0.999:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return mat


static func _make_vcol_glow_mat(alpha: float = 1.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 1.0, 1.0, alpha)
	mat.vertex_color_use_as_albedo = true
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if alpha < 0.999:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return mat


static func _get_scene_cache(root: Node, meta_key: String) -> Dictionary:
	if root == null:
		return {}
	if root.has_meta(meta_key):
		return root.get_meta(meta_key) as Dictionary
	var d: Dictionary = {}
	root.set_meta(meta_key, d)
	return d


static func _make_mesh_inst(mesh: Mesh, mat: Material, pos: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	inst.material_override = mat
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	inst.position = pos
	return inst


# ==============================================================================
# CORE SURFACE TOOL GEOMETRY HELPERS (STRICT CW OUTWARD WINDING + VERTEX COLOR)
# ==============================================================================

static func _append_mesh_colored(
	st: SurfaceTool,
	mesh: Mesh,
	xform: Transform3D,
	base_col: Color,
	top_col: Color = Color(-1.0, 0.0, 0.0),
	y_min: float = 0.0,
	y_max: float = 1.0,
	noise_amp: float = 0.0,
	noise_seed: float = 0.0
) -> void:
	var arrays: Array = mesh.surface_get_arrays(0)
	if arrays.is_empty():
		return
	var raw_verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var raw_norms: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	if raw_verts.is_empty():
		return

	var use_grad: bool = top_col.r >= 0.0
	var inv_span: float = 1.0 / maxf(0.0001, y_max - y_min)
	var nrm_basis: Basis = xform.basis.inverse().transposed()
	var has_noise: bool = noise_amp > 0.0001

	var vcount: int = raw_verts.size()
	var x_verts := PackedVector3Array()
	x_verts.resize(vcount)
	var x_norms := PackedVector3Array()
	x_norms.resize(vcount)
	var x_cols := PackedColorArray()
	x_cols.resize(vcount)

	for i: int in range(vcount):
		var lv: Vector3 = raw_verts[i]
		var ln: Vector3 = raw_norms[i] if i < raw_norms.size() else Vector3.UP
		if has_noise:
			var np: Vector3 = lv * 2.15 + Vector3(noise_seed, noise_seed * 1.37, noise_seed * 0.79)
			var disp: float = (
				sin(np.x * 2.3 + np.y * 1.7) * cos(np.z * 2.1 - np.x * 1.3) * 0.65
				+ sin(np.y * 3.8 + np.z * 2.9 + noise_seed) * 0.35
			)
			var d_dir: Vector3 = ln.normalized() if ln.length_squared() > 0.0001 else lv.normalized()
			lv += d_dir * (disp * noise_amp)

		var wp: Vector3 = xform * lv
		var wn: Vector3 = (nrm_basis * ln).normalized()
		if wn.length_squared() < 0.0001:
			wn = Vector3.UP
		x_verts[i] = wp
		x_norms[i] = wn
		if use_grad:
			var t: float = clampf((wp.y - y_min) * inv_span, 0.0, 1.0)
			x_cols[i] = base_col.lerp(top_col, t)
		else:
			x_cols[i] = base_col

	if not indices.is_empty():
		var icount: int = indices.size()
		var idx: int = 0
		while idx + 2 < icount:
			var i0: int = indices[idx]
			var i1: int = indices[idx + 1]
			var i2: int = indices[idx + 2]
			var p0: Vector3 = x_verts[i0]
			var p1: Vector3 = x_verts[i1]
			var p2: Vector3 = x_verts[i2]
			var n0: Vector3 = x_norms[i0]
			var n1: Vector3 = x_norms[i1]
			var n2: Vector3 = x_norms[i2]
			if has_noise:
				var face_n: Vector3 = (p2 - p0).cross(p1 - p0)
				if face_n.length_squared() > 0.000001:
					face_n = face_n.normalized()
					n0 = n0.lerp(face_n, 0.55).normalized()
					n1 = n1.lerp(face_n, 0.55).normalized()
					n2 = n2.lerp(face_n, 0.55).normalized()
			st.set_normal(n0)
			st.set_color(x_cols[i0])
			st.add_vertex(p0)
			st.set_normal(n1)
			st.set_color(x_cols[i1])
			st.add_vertex(p1)
			st.set_normal(n2)
			st.set_color(x_cols[i2])
			st.add_vertex(p2)
			idx += 3
	else:
		var idx: int = 0
		while idx + 2 < vcount:
			var p0: Vector3 = x_verts[idx]
			var p1: Vector3 = x_verts[idx + 1]
			var p2: Vector3 = x_verts[idx + 2]
			var n0: Vector3 = x_norms[idx]
			var n1: Vector3 = x_norms[idx + 1]
			var n2: Vector3 = x_norms[idx + 2]
			if has_noise:
				var face_n: Vector3 = (p2 - p0).cross(p1 - p0)
				if face_n.length_squared() > 0.000001:
					face_n = face_n.normalized()
					n0 = n0.lerp(face_n, 0.55).normalized()
					n1 = n1.lerp(face_n, 0.55).normalized()
					n2 = n2.lerp(face_n, 0.55).normalized()
			st.set_normal(n0)
			st.set_color(x_cols[idx])
			st.add_vertex(p0)
			st.set_normal(n1)
			st.set_color(x_cols[idx + 1])
			st.add_vertex(p1)
			st.set_normal(n2)
			st.set_color(x_cols[idx + 2])
			st.add_vertex(p2)
			idx += 3


static func _append_box(
	st: SurfaceTool,
	size: Vector3,
	pos: Vector3,
	rot_euler: Vector3,
	bot_col: Color,
	top_col: Color = Color(-1.0, 0.0, 0.0)
) -> void:
	var bm := BoxMesh.new()
	bm.size = size
	var xf := Transform3D(Basis.from_euler(rot_euler), pos)
	var half_h: float = size.y * 0.5
	_append_mesh_colored(st, bm, xf, bot_col, top_col, pos.y - half_h, pos.y + half_h)


static func _append_cyl(
	st: SurfaceTool,
	r_bot: float,
	r_top: float,
	height: float,
	segs: int,
	pos: Vector3,
	rot_euler: Vector3,
	bot_col: Color,
	top_col: Color = Color(-1.0, 0.0, 0.0)
) -> void:
	var cm := CylinderMesh.new()
	cm.bottom_radius = r_bot
	cm.top_radius = r_top
	cm.height = height
	cm.radial_segments = segs
	cm.rings = 1
	var xf := Transform3D(Basis.from_euler(rot_euler), pos)
	var half_h: float = height * 0.5
	_append_mesh_colored(st, cm, xf, bot_col, top_col, pos.y - half_h, pos.y + half_h)


static func _basis_align_y(dir: Vector3) -> Basis:
	var y_axis: Vector3 = dir.normalized()
	if y_axis.length_squared() < 0.0001:
		return Basis.IDENTITY
	var ref_v: Vector3 = Vector3.FORWARD if absf(y_axis.y) > 0.92 else Vector3.UP
	var x_axis: Vector3 = ref_v.cross(y_axis).normalized()
	var z_axis: Vector3 = x_axis.cross(y_axis).normalized()
	return Basis(x_axis, y_axis, z_axis)


static func _append_cyl_between(
	st: SurfaceTool,
	p0: Vector3,
	p1: Vector3,
	r_bot: float,
	r_top: float,
	segs: int,
	bot_col: Color,
	top_col: Color
) -> void:
	var d: Vector3 = p1 - p0
	var length: float = d.length()
	if length < 0.001:
		return
	var cm := CylinderMesh.new()
	cm.bottom_radius = r_bot
	cm.top_radius = r_top
	cm.height = length
	cm.radial_segments = segs
	cm.rings = 1
	var mid: Vector3 = (p0 + p1) * 0.5
	var xf := Transform3D(_basis_align_y(d), mid)
	_append_mesh_colored(st, cm, xf, bot_col, top_col, minf(p0.y, p1.y), maxf(p0.y, p1.y) + 0.001)


static func _append_tri_colored(
	st: SurfaceTool,
	v0: Vector3,
	v1: Vector3,
	v2: Vector3,
	c0: Color,
	c1: Color,
	c2: Color,
	outward_hint: Vector3
) -> void:
	# Godot 3D CW front face: outward normal is (v2 - v0).cross(v1 - v0).
	var n: Vector3 = (v2 - v0).cross(v1 - v0)
	if n.length_squared() < 0.0000001:
		return
	if n.dot(outward_hint) < 0.0:
		var tmp_v: Vector3 = v1
		v1 = v2
		v2 = tmp_v
		var tmp_c: Color = c1
		c1 = c2
		c2 = tmp_c
		n = -n
	n = n.normalized()
	st.set_normal(n)
	st.set_color(c0)
	st.add_vertex(v0)
	st.set_normal(n)
	st.set_color(c1)
	st.add_vertex(v1)
	st.set_normal(n)
	st.set_color(c2)
	st.add_vertex(v2)


static func _append_quad_colored(
	st: SurfaceTool,
	v0: Vector3,
	v1: Vector3,
	v2: Vector3,
	v3: Vector3,
	c0: Color,
	c1: Color,
	c2: Color,
	c3: Color,
	outward_hint: Vector3
) -> void:
	_append_tri_colored(st, v0, v1, v2, c0, c1, c2, outward_hint)
	_append_tri_colored(st, v0, v2, v3, c0, c2, c3, outward_hint)


static func _append_tapered_tube(
	st: SurfaceTool,
	points: Array[Vector3],
	radii: Array[float],
	segs: int,
	bot_col: Color,
	top_col: Color,
	cap_ends: bool = true
) -> void:
	var n_pts: int = points.size()
	if n_pts < 2 or radii.size() < n_pts:
		return
	var rings: Array = []
	var ring_cols: Array[Color] = []
	var prev_right := Vector3.RIGHT
	for i: int in range(n_pts):
		var tangent: Vector3
		if i == 0:
			tangent = (points[1] - points[0]).normalized()
		elif i == n_pts - 1:
			tangent = (points[n_pts - 1] - points[n_pts - 2]).normalized()
		else:
			tangent = (points[i + 1] - points[i - 1]).normalized()
		if tangent.length_squared() < 0.0001:
			tangent = Vector3.UP
		var right: Vector3 = prev_right - tangent * prev_right.dot(tangent)
		if right.length_squared() < 0.001:
			var alt: Vector3 = Vector3.FORWARD if absf(tangent.y) > 0.9 else Vector3.UP
			right = alt.cross(tangent)
		right = right.normalized()
		var fwd: Vector3 = tangent.cross(right).normalized()
		prev_right = right

		var r: float = radii[i]
		var ring_v := PackedVector3Array()
		ring_v.resize(segs)
		for s: int in range(segs):
			var ang: float = (float(s) / float(segs)) * TAU
			var dir_r: Vector3 = right * cos(ang) + fwd * sin(ang)
			ring_v[s] = points[i] + dir_r * r
		rings.append(ring_v)
		var t: float = float(i) / float(n_pts - 1)
		ring_cols.append(bot_col.lerp(top_col, t))

	for i: int in range(n_pts - 1):
		var r0: PackedVector3Array = rings[i]
		var r1: PackedVector3Array = rings[i + 1]
		var c0: Color = ring_cols[i]
		var c1: Color = ring_cols[i + 1]
		var center_mid: Vector3 = (points[i] + points[i + 1]) * 0.5
		for s: int in range(segs):
			var sn: int = (s + 1) % segs
			var v00: Vector3 = r0[s]
			var v01: Vector3 = r0[sn]
			var v11: Vector3 = r1[sn]
			var v10: Vector3 = r1[s]
			var quad_mid: Vector3 = (v00 + v01 + v11 + v10) * 0.25
			var out_h: Vector3 = quad_mid - center_mid
			_append_quad_colored(st, v00, v01, v11, v10, c0, c0, c1, c1, out_h)

	if cap_ends:
		var top_r: PackedVector3Array = rings[n_pts - 1]
		var top_c: Vector3 = points[n_pts - 1]
		var top_dir: Vector3 = (points[n_pts - 1] - points[n_pts - 2]).normalized()
		var tc: Color = ring_cols[n_pts - 1]
		for s: int in range(segs):
			var sn: int = (s + 1) % segs
			_append_tri_colored(st, top_c, top_r[s], top_r[sn], tc, tc, tc, top_dir)
		var bot_r: PackedVector3Array = rings[0]
		var bot_c: Vector3 = points[0]
		var bot_dir: Vector3 = (points[0] - points[1]).normalized()
		var bc: Color = ring_cols[0]
		for s: int in range(segs):
			var sn: int = (s + 1) % segs
			_append_tri_colored(st, bot_c, bot_r[sn], bot_r[s], bc, bc, bc, bot_dir)


static func _calibrate_leaf_card_color(src_col: Color, target_v: float, sat_scale: float) -> Color:
	## Preserves botanical hue variety across tree variants while preventing
	## multiplicative over-darkening when modulated against rich RGBA leaf textures.
	return Color.from_hsv(src_col.h, clampf(src_col.s * sat_scale, 0.0, 0.62), target_v)


static func _emit_leaf_vert(
	st: SurfaceTool,
	wp: Vector3,
	uv: Vector2,
	crown_center: Vector3,
	crown_radius: float,
	top_col: Color,
	mid_col: Color,
	bot_col: Color,
	shade_bias: float
) -> void:
	# Spherical crown-outward normals (AAA/anime foliage lighting trick):
	# smoothly wraps sunlight across intersecting leaf cards with zero flat creases.
	var rel: Vector3 = wp - crown_center
	var out_n: Vector3 = rel.normalized() if rel.length_squared() > 0.0001 else Vector3.UP
	var nrm: Vector3 = (out_n * 0.78 + Vector3.UP * 0.22).normalized()

	# 3-stop crown AO & sunlit outer tip gradient
	var inv_r: float = 1.0 / maxf(0.45, crown_radius)
	var h_f: float = clampf((rel.y + crown_radius * 0.62) * inv_r * 0.68, 0.0, 1.0)
	var r_f: float = clampf(rel.length() * inv_r * 0.88, 0.0, 1.0)
	var tip_f: float = clampf(1.0 - uv.y, 0.0, 1.0)
	var shade_t: float = clampf(h_f * 0.48 + r_f * 0.30 + tip_f * 0.22 + shade_bias, 0.0, 1.0)

	var col: Color
	if shade_t < 0.48:
		col = bot_col.lerp(mid_col, shade_t / 0.48)
	else:
		col = mid_col.lerp(top_col, (shade_t - 0.48) / 0.52)

	st.set_normal(nrm)
	st.set_uv(uv)
	st.set_color(col)
	st.add_vertex(wp)


static func _append_curved_leaf_card(
	st: SurfaceTool,
	origin: Vector3,
	growth_dir: Vector3,
	up_hint: Vector3,
	card_w: float,
	card_len: float,
	arch_h: float,
	tip_droop: float,
	crown_center: Vector3,
	crown_radius: float,
	top_col: Color,
	mid_col: Color,
	bot_col: Color,
	uv_flip: bool,
	shade_bias: float,
	cup_depth: float = -1.0
) -> void:
	## Emits a 3D curved & cupped V-arch leaf-branch sprig (6 logical vertices / 5 triangles).
	## UV.y = 1.0 strictly pins the woody twig stem pivot at `origin`; UV.y = 0.0 reaches
	## the outer fluttering leaf tips; UV.x spans 0.0..1.0 across width for torsional flutter.
	## Trimmed bottom corners (v=0.78) eliminate empty alpha overdraw while keeping 100% of
	## opaque foliage pixels intact across all four botanical textures.
	var g_dir: Vector3 = growth_dir.normalized()
	if g_dir.length_squared() < 0.0001:
		g_dir = Vector3.FORWARD
	var right: Vector3 = g_dir.cross(up_hint)
	if right.length_squared() < 0.0001:
		var fallback_up: Vector3 = Vector3.RIGHT if absf(g_dir.y) > 0.92 else Vector3.UP
		right = g_dir.cross(fallback_up)
	right = right.normalized()
	# Right-handed frame where right.cross(g_dir) == up_n (CW front face points +up_n)
	var up_n: Vector3 = right.cross(g_dir).normalized()

	var hw_low: float = card_w * 0.49
	var hw_tip: float = card_w * 0.51
	var cup_h: float = cup_depth if cup_depth >= 0.0 else (card_w * 0.14)

	# Woody stem attachment pivot tucked directly into the branch tip
	var p_stem: Vector3 = origin - g_dir * (card_len * 0.12)
	var low_center: Vector3 = p_stem + g_dir * (card_len * 0.24) + up_n * (arch_h * 0.42 + cup_h * 0.72)
	var p_low_l: Vector3 = low_center - right * hw_low
	var p_low_r: Vector3 = low_center + right * hw_low
	# Central arched midrib slightly recessed below cupped side margins for organic 3D V-cup
	var p_mid_c: Vector3 = p_stem + g_dir * (card_len * 0.54) + up_n * (arch_h - cup_h * 0.35)
	var tip_center: Vector3 = p_stem + g_dir * card_len - up_n * (tip_droop - cup_h * 0.85)
	var p_tip_l: Vector3 = tip_center - right * hw_tip
	var p_tip_r: Vector3 = tip_center + right * hw_tip

	var u_l: float = 1.0 if uv_flip else 0.0
	var u_r: float = 0.0 if uv_flip else 1.0
	var uv_stem := Vector2(0.5, 1.0)
	var uv_low_l := Vector2(u_l, 0.78)
	var uv_low_r := Vector2(u_r, 0.78)
	var uv_mid_c := Vector2(0.5, 0.46)
	var uv_tip_l := Vector2(u_l, 0.0)
	var uv_tip_r := Vector2(u_r, 0.0)

	# 1-2. Stem-pinned V-cup fan (woody twig base -> cupped shoulders & arched midrib)
	_emit_leaf_vert(st, p_stem, uv_stem, crown_center, crown_radius, top_col, mid_col, bot_col, shade_bias - 0.03)
	_emit_leaf_vert(st, p_low_l, uv_low_l, crown_center, crown_radius, top_col, mid_col, bot_col, shade_bias)
	_emit_leaf_vert(st, p_mid_c, uv_mid_c, crown_center, crown_radius, top_col, mid_col, bot_col, shade_bias + 0.02)

	_emit_leaf_vert(st, p_stem, uv_stem, crown_center, crown_radius, top_col, mid_col, bot_col, shade_bias - 0.03)
	_emit_leaf_vert(st, p_mid_c, uv_mid_c, crown_center, crown_radius, top_col, mid_col, bot_col, shade_bias + 0.02)
	_emit_leaf_vert(st, p_low_r, uv_low_r, crown_center, crown_radius, top_col, mid_col, bot_col, shade_bias)

	# 3-5. Cupped outer blade & fluttering leaf tips
	_emit_leaf_vert(st, p_low_l, uv_low_l, crown_center, crown_radius, top_col, mid_col, bot_col, shade_bias)
	_emit_leaf_vert(st, p_tip_l, uv_tip_l, crown_center, crown_radius, top_col, mid_col, bot_col, shade_bias + 0.04)
	_emit_leaf_vert(st, p_mid_c, uv_mid_c, crown_center, crown_radius, top_col, mid_col, bot_col, shade_bias + 0.02)

	_emit_leaf_vert(st, p_mid_c, uv_mid_c, crown_center, crown_radius, top_col, mid_col, bot_col, shade_bias + 0.02)
	_emit_leaf_vert(st, p_tip_l, uv_tip_l, crown_center, crown_radius, top_col, mid_col, bot_col, shade_bias + 0.04)
	_emit_leaf_vert(st, p_tip_r, uv_tip_r, crown_center, crown_radius, top_col, mid_col, bot_col, shade_bias + 0.04)

	_emit_leaf_vert(st, p_mid_c, uv_mid_c, crown_center, crown_radius, top_col, mid_col, bot_col, shade_bias + 0.02)
	_emit_leaf_vert(st, p_tip_r, uv_tip_r, crown_center, crown_radius, top_col, mid_col, bot_col, shade_bias + 0.04)
	_emit_leaf_vert(st, p_low_r, uv_low_r, crown_center, crown_radius, top_col, mid_col, bot_col, shade_bias)


static func _append_inner_core_leaf_card(
	st: SurfaceTool,
	origin: Vector3,
	growth_dir: Vector3,
	up_hint: Vector3,
	card_w: float,
	card_len: float,
	cup_h: float,
	crown_center: Vector3,
	crown_radius: float,
	top_col: Color,
	mid_col: Color,
	bot_col: Color,
	uv_flip: bool,
	shade_bias: float
) -> void:
	## Ultra-lean 2-triangle V-folded inner core depth sprig (4 logical vertices) tucked
	## inside dense branch forks for volumetric canopy depth without bloating WebGL2 counts.
	var g_dir: Vector3 = growth_dir.normalized()
	if g_dir.length_squared() < 0.0001:
		g_dir = Vector3.UP
	var right: Vector3 = g_dir.cross(up_hint)
	if right.length_squared() < 0.0001:
		var fallback_up: Vector3 = Vector3.RIGHT if absf(g_dir.y) > 0.92 else Vector3.UP
		right = g_dir.cross(fallback_up)
	right = right.normalized()
	var up_n: Vector3 = right.cross(g_dir).normalized()

	var hw: float = card_w * 0.52
	var p_stem: Vector3 = origin - g_dir * (card_len * 0.10)
	var mid_c: Vector3 = p_stem + g_dir * (card_len * 0.50) + up_n * cup_h
	var p_l: Vector3 = mid_c - right * hw
	var p_r: Vector3 = mid_c + right * hw
	var p_tip: Vector3 = p_stem + g_dir * card_len - up_n * (cup_h * 0.35)

	var u_l: float = 1.0 if uv_flip else 0.0
	var u_r: float = 0.0 if uv_flip else 1.0
	var uv_stem := Vector2(0.5, 1.0)
	var uv_l := Vector2(u_l, 0.42)
	var uv_r := Vector2(u_r, 0.42)
	var uv_tip := Vector2(0.5, 0.0)

	_emit_leaf_vert(st, p_stem, uv_stem, crown_center, crown_radius, top_col, mid_col, bot_col, shade_bias - 0.04)
	_emit_leaf_vert(st, p_l, uv_l, crown_center, crown_radius, top_col, mid_col, bot_col, shade_bias)
	_emit_leaf_vert(st, p_tip, uv_tip, crown_center, crown_radius, top_col, mid_col, bot_col, shade_bias + 0.02)

	_emit_leaf_vert(st, p_stem, uv_stem, crown_center, crown_radius, top_col, mid_col, bot_col, shade_bias - 0.04)
	_emit_leaf_vert(st, p_tip, uv_tip, crown_center, crown_radius, top_col, mid_col, bot_col, shade_bias + 0.02)
	_emit_leaf_vert(st, p_r, uv_r, crown_center, crown_radius, top_col, mid_col, bot_col, shade_bias)


static func _append_leaf_card_cluster(
	st: SurfaceTool,
	center: Vector3,
	card_size: float,
	count: int,
	crown_center: Vector3,
	top_col: Color,
	mid_col: Color,
	bot_col: Color,
	seed_val: float,
	crown_radius: float = 3.0,
	pitch_bias: float = 0.24,
	flatness: float = 1.0,
	droop_factor: float = 0.16,
	aspect_len: float = 1.0
) -> void:
	## Emits a layered multi-angle 3D real-leaf branch-sprig cluster:
	## - Outer airy cupped silhouette sprigs fanning organically around the branch tip
	## - Steeply pitched inner core depth sprigs providing lush volume from all camera angles
	if count <= 0:
		return
	var out_from_crown: Vector3 = center - crown_center
	var out_xz := Vector3(out_from_crown.x, 0.0, out_from_crown.z)
	var base_yaw: float = atan2(out_xz.z, out_xz.x) if out_xz.length_squared() > 0.01 else fmod(seed_val * 2.1, TAU)
	var outer_count: int = (count - 1) if count >= 3 else count

	for ci: int in range(count):
		var h1: float = sin(seed_val * 3.17 + float(ci) * 2.41)
		var h2: float = cos(seed_val * 2.31 + float(ci) * 3.73)
		var h3: float = sin(seed_val * 4.53 + float(ci) * 1.67)
		var is_core_sprig: bool = (count >= 3 and ci == count - 1)

		var yaw: float
		var pitch_var: float
		var roll: float
		var radial_off: float
		var size_var: float
		var local_shade: float
		var cup_scale: float

		if is_core_sprig:
			# Inner core depth sprig: tucked close to the branch fork, pitched steeply
			# with subtle ambient core darkening so the crown reads full from underneath & oblique angles.
			yaw = base_yaw + PI * 0.72 + h1 * 0.65
			pitch_var = (0.54 + 0.24 * absf(h2)) * maxf(0.68, flatness)
			roll = h3 * 0.56
			radial_off = card_size * 0.05
			size_var = card_size * (0.84 + 0.14 * (0.5 + 0.5 * h1))
			local_shade = -0.07 + h3 * 0.04
			cup_scale = 0.18
		else:
			# Outer airy silhouette sprigs: evenly fanned around the perimeter with organic jitter
			yaw = base_yaw + (float(ci) / float(maxi(1, outer_count))) * TAU + h1 * 0.34
			if ci % 2 == 0:
				pitch_var = (pitch_bias + 0.18 * h2) * flatness
			else:
				pitch_var = (pitch_bias - 0.15 + 0.24 * h2) * flatness
			roll = h3 * (0.48 if flatness > 0.7 else 0.32)
			radial_off = card_size * 0.17
			size_var = card_size * (0.93 + 0.24 * (0.5 + 0.5 * h1))
			local_shade = 0.03 + h3 * 0.06
			cup_scale = 0.14 + 0.04 * absf(h2)

		var pitch: float = clampf(pitch_var, -0.22, 0.96)
		var cos_p: float = cos(pitch)
		var growth_dir := Vector3(cos(yaw) * cos_p, sin(pitch), sin(yaw) * cos_p).normalized()
		var side_ref := Vector3(-sin(yaw), 0.0, cos(yaw))
		var up_hint: Vector3 = (Vector3.UP * cos(roll) + side_ref * sin(roll)).normalized()

		var stem_off := Vector3(
			cos(yaw) * radial_off,
			(h2 * 0.11 - (0.06 if is_core_sprig else 0.0)) * card_size * flatness,
			sin(yaw) * radial_off
		)
		var c_w: float = size_var * (0.96 + 0.12 * absf(h3))
		var c_len: float = size_var * aspect_len
		var arch_h: float = c_len * (0.15 + 0.06 * absf(h2))
		var tip_droop: float = c_len * (droop_factor + 0.05 * maxf(0.0, h1))
		var cup_h: float = c_w * cup_scale

		_append_curved_leaf_card(
			st,
			center + stem_off,
			growth_dir,
			up_hint,
			c_w,
			c_len,
			arch_h,
			tip_droop,
			crown_center,
			crown_radius,
			top_col,
			mid_col,
			bot_col,
			(ci % 2) == 1,
			local_shade,
			cup_h
		)

	# Desktop dense clusters (count >= 4): add 1 lean 2-triangle V-folded inner heart sprig
	# oriented across the branch fork for lush core fullness while keeping vertex budget lean.
	if count >= 4:
		var hc1: float = sin(seed_val * 5.71 + 1.13)
		var hc2: float = cos(seed_val * 3.89 + 2.27)
		var core_yaw: float = base_yaw - PI * 0.58 + hc1 * 0.52
		var core_pitch: float = clampf((0.46 + 0.22 * absf(hc2)) * maxf(0.65, flatness), 0.18, 0.92)
		var c_cos: float = cos(core_pitch)
		var core_dir := Vector3(cos(core_yaw) * c_cos, sin(core_pitch), sin(core_yaw) * c_cos).normalized()
		var core_side := Vector3(-sin(core_yaw), 0.0, cos(core_yaw))
		var core_up: Vector3 = (Vector3.UP * cos(hc2 * 0.5) + core_side * sin(hc2 * 0.5)).normalized()
		var core_sz: float = card_size * 0.80
		_append_inner_core_leaf_card(
			st,
			center + Vector3(0.0, -card_size * 0.05 * flatness, 0.0),
			core_dir,
			core_up,
			core_sz * 1.04,
			core_sz * aspect_len * 0.96,
			core_sz * 0.17,
			crown_center,
			crown_radius,
			top_col,
			mid_col,
			bot_col,
			hc1 > 0.0,
			-0.10
		)


static func _append_weeping_leaf_curtain(
	st: SurfaceTool,
	hang_top: Vector3,
	out_dir_xz: Vector3,
	drape_len: float,
	card_w: float,
	crown_center: Vector3,
	crown_radius: float,
	top_col: Color,
	mid_col: Color,
	bot_col: Color,
	seed_val: float
) -> void:
	## Emits 2 crossed, gracefully curving vertical weeping-sakura branch curtains.
	## Stem (UV.y = 1.0) anchors at `hang_top`; petal tips (UV.y = 0.0) cascade downward!
	var out_n: Vector3 = Vector3(out_dir_xz.x, 0.0, out_dir_xz.z).normalized()
	if out_n.length_squared() < 0.001:
		out_n = Vector3.FORWARD
	var side_n := Vector3(-out_n.z, 0.0, out_n.x)
	var hang_dir: Vector3 = (Vector3(0.0, -1.0, 0.0) + out_n * 0.12).normalized()

	for ci: int in range(2):
		var cross_ang: float = seed_val * 1.3 + float(ci) * (PI * 0.48)
		var up_hint: Vector3 = (out_n * cos(cross_ang) + side_n * sin(cross_ang)).normalized()
		var off: Vector3 = up_hint * (card_w * 0.08 * (1.0 if ci == 0 else -1.0))
		var len_i: float = drape_len * (1.0 if ci == 0 else 0.88)
		var w_i: float = card_w * (1.0 if ci == 0 else 0.92)
		_append_curved_leaf_card(
			st,
			hang_top + off,
			hang_dir,
			up_hint,
			w_i,
			len_i,
			len_i * 0.09,
			len_i * 0.05,
			crown_center,
			crown_radius,
			top_col,
			mid_col,
			bot_col,
			ci == 1,
			0.04 if ci == 0 else -0.05
		)



static func _append_shide_zigzag(
	st: SurfaceTool,
	top_pos: Vector3,
	yaw: float,
	scale_f: float,
	col_top: Color,
	col_bot: Color
) -> void:
	## Iconic folded white paper lightning-zigzag (shide) hanging from shimenawa rope.
	var rot_b := Basis(Vector3.UP, yaw)
	var step_h: float = 0.24 * scale_f
	var step_w: float = 0.16 * scale_f
	var thick: float = 0.032 * scale_f
	var bm := BoxMesh.new()
	for si: int in range(3):
		var side_sign: float = 1.0 if si % 2 == 0 else -1.0
		bm.size = Vector3(step_w, step_h, thick)
		var local_p := Vector3(side_sign * step_w * 0.28, -step_h * (float(si) + 0.55), 0.0)
		var tilt := Basis(Vector3.FORWARD, side_sign * 0.38)
		var xf := Transform3D(rot_b * tilt, top_pos + rot_b * local_p)
		var t: float = float(si) / 2.0
		_append_mesh_colored(st, bm, xf, col_top.lerp(col_bot, t))


static func _register_rotated_obstacle(
	arena: Arena3D,
	base_pos: Vector3,
	yaw: float,
	sc: float,
	local_xz: Vector2,
	radius: float,
	height: float
) -> void:
	var c_y: float = cos(yaw)
	var s_y: float = sin(yaw)
	# Godot Node3D rotation.y rotates (x, z) -> (x*cos + z*sin, -x*sin + z*cos)
	var wx: float = base_pos.x + (local_xz.x * c_y + local_xz.y * s_y) * sc
	var wz: float = base_pos.z + (-local_xz.x * s_y + local_xz.y * c_y) * sc
	arena.obstacles.append({
		"pos": Vector2(wx, wz),
		"radius": radius * sc,
		"top_y": base_pos.y + height * sc,
	})


# ==============================================================================
# 2. REAL-LEAF 3D TREES (SAKURA / MAPLE / PINE / BROADLEAF) & GIANT WEEPING SAKURA
# ==============================================================================

static func build_tree_meshes(
	variant_idx: int,
	trunk_hex: String,
	leaf_top_hex: String,
	leaf_mid_hex: String,
	leaf_bot_hex: String,
	is_mob: bool,
	species: String = "sakura"
) -> Dictionary:
	var sp_key: String = species if LEAF_TEX_PATHS.has(species) else "sakura"
	var seed_f: float = float(variant_idx) * 2.137 + 0.618
	var trunk_base: Color = Color.html(trunk_hex)
	var bark_dark: Color = trunk_base.darkened(0.38)
	var bark_mid: Color = trunk_base
	var bark_light: Color = trunk_base.lightened(0.14)

	var col_top: Color = _calibrate_leaf_card_color(Color.html(leaf_top_hex), 1.0, 0.34)
	var col_mid: Color = _calibrate_leaf_card_color(Color.html(leaf_mid_hex), 0.89, 0.48)
	var col_bot: Color = _calibrate_leaf_card_color(Color.html(leaf_bot_hex), 0.54, 0.54)

	var st_trunk := SurfaceTool.new()
	st_trunk.begin(Mesh.PRIMITIVE_TRIANGLES)

	var st_fol := SurfaceTool.new()
	st_fol.begin(Mesh.PRIMITIVE_TRIANGLES)

	var seg_trunk: int = 6 if is_mob else 8
	var seg_branch: int = 5 if is_mob else 6
	var root_base_yaw: float = fmod(seed_f * 1.3, TAU)

	# 1. Four flared gnarled buttress roots gripping the earth
	for ri: int in range(4):
		var a: float = root_base_yaw + float(ri) * (PI * 0.5) + sin(seed_f + float(ri) * 1.9) * 0.24
		var r_reach: float = (0.98 if sp_key == "pine" else 0.88) + 0.24 * (0.5 + 0.5 * sin(seed_f * 1.7 + float(ri) * 2.3))
		var r_pts: Array[Vector3] = [
			Vector3(cos(a) * r_reach, -0.25, sin(a) * r_reach),
			Vector3(cos(a) * (r_reach * 0.52), 0.18, sin(a) * (r_reach * 0.52)),
			Vector3(cos(a) * 0.18, 0.78, sin(a) * 0.18),
		]
		var r_rads: Array[float] = [0.10, 0.18, 0.24]
		_append_tapered_tube(st_trunk, r_pts, r_rads, 5, bark_dark, bark_mid, true)

	# 2. Species-tailored organic curved wooden trunk
	var lean_x: float = sin(seed_f * 1.1) * 0.34
	var lean_z: float = cos(seed_f * 0.9) * 0.30
	var p_t2: Vector3
	var p_t3: Vector3
	var crown_center: Vector3
	var crown_radius: float = 3.2

	if sp_key == "pine":
		# Iconic S-curved coastal Japanese Red Pine (Akamatsu) leaning trunk
		var s_dir: float = 1.0 if variant_idx % 2 == 0 else -1.0
		var z_dir: float = 1.0 if variant_idx != 2 else -1.0
		var pine_pts: Array[Vector3] = [
			Vector3(0.0, -0.25, 0.0),
			Vector3(0.20 * s_dir, 0.90, 0.10 * z_dir),
			Vector3(0.64 * s_dir, 2.10, 0.24 * z_dir),
			Vector3(0.92 * s_dir, 3.28, 0.14 * z_dir),
			Vector3(0.62 * s_dir, 4.42, -0.14 * z_dir),
			Vector3(0.28 * s_dir, 5.28, -0.30 * z_dir),
		]
		var pine_rads: Array[float] = [0.52, 0.36, 0.28, 0.22, 0.15, 0.08]
		_append_tapered_tube(st_trunk, pine_pts, pine_rads, seg_trunk, bark_dark, bark_light, true)
		p_t2 = pine_pts[2]
		p_t3 = pine_pts[5]
		crown_center = Vector3(0.42 * s_dir, 4.35, -0.08 * z_dir)
		crown_radius = 3.15
	else:
		var trunk_h: float = 4.35 if sp_key == "broadleaf" else (3.85 if sp_key == "maple" else 3.65)
		var r_base: float = 0.50 if sp_key == "broadleaf" else (0.41 if sp_key == "maple" else 0.48)
		var r_top: float = 0.24 if sp_key == "broadleaf" else (0.17 if sp_key == "maple" else 0.21)
		var p_t0 := Vector3(0.0, -0.15, 0.0)
		var p_t1 := Vector3(lean_x * 0.40, trunk_h * 0.34, lean_z * 0.40)
		p_t2 = Vector3(lean_x * 0.94, trunk_h * 0.70, lean_z * 0.84)
		p_t3 = Vector3(lean_x * 0.72, trunk_h, lean_z * 0.68)
		var trunk_pts: Array[Vector3] = [p_t0, p_t1, p_t2, p_t3]
		var trunk_rads: Array[float] = [r_base, lerpf(r_base, r_top, 0.35), lerpf(r_base, r_top, 0.68), r_top]
		_append_tapered_tube(st_trunk, trunk_pts, trunk_rads, seg_trunk, bark_dark, bark_mid, true)
		var crown_y: float = 5.65 if sp_key == "broadleaf" else (4.75 if sp_key == "maple" else 4.90)
		crown_center = Vector3(lean_x * 0.55, crown_y, lean_z * 0.50)
		crown_radius = 3.35 if sp_key == "broadleaf" else (3.05 if sp_key == "maple" else 3.25)

	# 3. Primary limbs + forked dark wooden twigs + curved 3D real-leaf branch-sprig cards
	# Desktop target: 53-56 cards | Mobile target: 31-36 cards (ZERO spherical blobs!)
	var branch_count: int = 6 if sp_key == "broadleaf" else 5
	var pitch_bias: float = 0.06 if sp_key == "pine" else (0.14 if sp_key == "maple" else (0.34 if sp_key == "broadleaf" else 0.22))
	var flatness: float = 0.52 if sp_key == "pine" else (0.72 if sp_key == "maple" else (1.04 if sp_key == "broadleaf" else 0.88))
	var droop_f: float = 0.08 if sp_key == "pine" else (0.14 if sp_key == "maple" else (0.15 if sp_key == "broadleaf" else 0.20))
	var base_card_sz: float = 1.56 if sp_key == "pine" else (1.50 if sp_key == "maple" else (1.60 if sp_key == "broadleaf" else 1.66))

	for bi: int in range(branch_count):
		var az: float = root_base_yaw + 0.42 + float(bi) * (TAU / float(branch_count)) + sin(seed_f + float(bi) * 2.1) * 0.24
		var is_upper: bool = bi >= (branch_count - 2)
		var b_frac: float = float(bi) / float(max(1, branch_count - 1))
		var start_p: Vector3 = p_t2.lerp(p_t3, 0.16 + 0.74 * b_frac)

		var horiz_len: float
		var rise_h: float
		if sp_key == "pine":
			# Asymmetric horizontal windswept cloud-boughs
			horiz_len = (1.95 if is_upper else 2.55) + 0.36 * sin(seed_f * 1.6 + float(bi) * 2.1)
			rise_h = (0.45 if is_upper else 0.58) + 0.18 * cos(seed_f + float(bi) * 1.9)
		elif sp_key == "maple":
			# Graceful tiered horizontal-arching Momiji limbs
			horiz_len = (1.85 if is_upper else 2.48) + 0.28 * sin(seed_f * 1.4 + float(bi) * 1.7)
			rise_h = (1.28 if is_upper else 0.88) + 0.22 * cos(seed_f + float(bi) * 2.3)
		elif sp_key == "broadleaf":
			# Tall ascending Keyaki vase-shaped boughs
			horiz_len = (1.72 if is_upper else 2.28) + 0.26 * sin(seed_f * 1.5 + float(bi) * 1.9)
			rise_h = (2.05 if is_upper else 1.68) + 0.28 * cos(seed_f + float(bi) * 2.1)
		else:
			# Wide spreading Sakura umbrella boughs
			horiz_len = (1.85 if is_upper else 2.58) + 0.34 * sin(seed_f * 1.4 + float(bi) * 1.7)
			rise_h = (1.55 if is_upper else 1.18) + 0.24 * cos(seed_f + float(bi) * 2.3)

		var dir_xz := Vector3(cos(az), 0.0, sin(az))
		var mid_p: Vector3 = start_p + dir_xz * (horiz_len * 0.54) + Vector3(0.0, rise_h * 0.52, 0.0)
		var tip_p: Vector3 = start_p + dir_xz * horiz_len + Vector3(0.0, rise_h, 0.0)
		var r0_b: float = 0.16 if is_upper else 0.20
		var b_pts: Array[Vector3] = [start_p, mid_p, tip_p]
		var b_rads: Array[float] = [r0_b, r0_b * 0.66, 0.055]
		_append_tapered_tube(st_trunk, b_pts, b_rads, seg_branch, bark_mid, bark_light, true)

		# Two slender forked secondary wooden twigs per limb (10-12 visible twigs!)
		var side_sign: float = 1.0 if bi % 2 == 0 else -1.0
		var twig_a_az: float = az + side_sign * 0.58
		var twig_a_tip: Vector3 = mid_p + Vector3(cos(twig_a_az), 0.0, sin(twig_a_az)) * (horiz_len * 0.56) + Vector3(0.0, rise_h * 0.46 + 0.18, 0.0)
		_append_cyl_between(st_trunk, mid_p, twig_a_tip, 0.095, 0.036, 4, bark_mid, bark_light)

		var twig_b_az: float = az - side_sign * 0.52
		var twig_b_start: Vector3 = mid_p.lerp(tip_p, 0.42)
		var twig_b_tip: Vector3 = twig_b_start + Vector3(cos(twig_b_az), 0.0, sin(twig_b_az)) * (horiz_len * 0.44) + Vector3(0.0, rise_h * 0.36 + 0.24, 0.0)
		_append_cyl_between(st_trunk, twig_b_start, twig_b_tip, 0.075, 0.030, 4, bark_mid, bark_light)

		# Crossed 3D real-leaf branch-sprig card clusters at main tip + both twigs
		var b_seed: float = seed_f * 3.1 + float(bi) * 2.47
		var tip_cards: int = 3 if is_mob else 4
		var twig_a_cards: int = 2 if is_mob else (2 if sp_key == "broadleaf" else 3)
		var twig_b_cards: int = 0 if is_mob else 2

		_append_leaf_card_cluster(
			st_fol, tip_p + Vector3(0.0, 0.08, 0.0), base_card_sz, tip_cards,
			crown_center, col_top, col_mid, col_bot, b_seed,
			crown_radius, pitch_bias, flatness, droop_f, 1.04
		)
		_append_leaf_card_cluster(
			st_fol, twig_a_tip + Vector3(0.0, 0.06, 0.0), base_card_sz * 0.90, twig_a_cards,
			crown_center, col_top, col_mid, col_bot, b_seed + 1.73,
			crown_radius, pitch_bias + 0.05, flatness, droop_f, 1.0
		)
		if twig_b_cards > 0:
			_append_leaf_card_cluster(
				st_fol, twig_b_tip + Vector3(0.0, 0.06, 0.0), base_card_sz * 0.84, twig_b_cards,
				crown_center, col_top, col_mid, col_bot, b_seed + 3.41,
				crown_radius, pitch_bias + 0.08, flatness, droop_f, 0.98
			)

	# 4. Upper crown wooden summit twigs + sunlit top real-leaf clusters
	for ci: int in range(2):
		var ca: float = root_base_yaw + float(ci) * PI + 0.85
		var c_reach: float = 0.72 if sp_key == "pine" else 0.85
		var c_rise: float = 0.65 if sp_key == "pine" else (1.55 if sp_key == "broadleaf" else 1.18)
		var c_tip: Vector3 = p_t3 + Vector3(cos(ca) * c_reach, c_rise, sin(ca) * c_reach)
		_append_cyl_between(st_trunk, p_t3, c_tip, 0.11, 0.04, 4, bark_mid, bark_light)

		var crown_cards: int = 3 if is_mob else 4
		_append_leaf_card_cluster(
			st_fol, c_tip + Vector3(0.0, 0.12, 0.0), base_card_sz * 1.06, crown_cards,
			crown_center, col_top, col_mid, col_bot, seed_f * 5.3 + float(ci) * 2.91,
			crown_radius, pitch_bias + 0.10, flatness, droop_f * 0.85, 1.02
		)

	return {
		"trunk": st_trunk.commit(),
		"foliage": st_fol.commit(),
		"trunk_mat": make_wafuu_mat(0, is_mob, 0.86, 0.02, 0.12 if sp_key == "pine" else 0.18),
		"foliage_mat": make_leaf_card_mat(sp_key, is_mob, Color.WHITE),
	}


static func add_realistic_tree(
	content_root: Node3D,
	base_pos: Vector3,
	trunk_hex: String,
	leaf_hex: String,
	sc: float = 1.0,
	variant_idx: int = 0,
	species: String = ""
) -> Node3D:
	var is_mob: bool = UiStyle.is_mobile_device()
	var resolved_species: String = species if species != "" else detect_tree_species(leaf_hex)
	var mid_c: Color = Color.html(leaf_hex)
	var top_c: Color = mid_c.lightened(0.24).lerp(Color(1.0, 0.97, 0.95), 0.16)
	var bot_c: Color = mid_c.darkened(0.36).lerp(Color(0.22, 0.13, 0.28), 0.18)

	var tree_cache: Dictionary = _get_scene_cache(content_root, "_wafuu_tree_cache")
	var cache_key: String = "%d_%s_%s_%s_%d" % [variant_idx, resolved_species, trunk_hex, leaf_hex, 1 if is_mob else 0]
	var meshes: Dictionary
	if tree_cache.has(cache_key):
		meshes = tree_cache[cache_key] as Dictionary
	else:
		meshes = build_tree_meshes(
			variant_idx,
			trunk_hex,
			top_c.to_html(false),
			mid_c.to_html(false),
			bot_c.to_html(false),
			is_mob,
			resolved_species
		)
		tree_cache[cache_key] = meshes

	var tree := Node3D.new()
	tree.position = base_pos
	tree.scale = Vector3(sc, sc, sc)

	var trunk_mat: Material = meshes.get("trunk_mat", make_wafuu_mat(0, is_mob, 0.86, 0.02, 0.18)) as Material
	var fol_mat: Material = meshes.get("foliage_mat", make_leaf_card_mat(resolved_species, is_mob, Color.WHITE)) as Material
	tree.add_child(_make_mesh_inst(meshes["trunk"] as ArrayMesh, trunk_mat))
	tree.add_child(_make_mesh_inst(meshes["foliage"] as ArrayMesh, fol_mat))

	content_root.add_child(tree)
	return tree


static func add_giant_weeping_sakura(
	content_root: Node3D,
	base_pos: Vector3,
	is_mob: bool = false
) -> Node3D:
	var tree := Node3D.new()
	tree.name = "GiantWeepingSakura"
	tree.position = base_pos

	var bark_dark := Color.html("#241412")
	var bark_mid := Color.html("#3d2520")
	var bark_light := Color.html("#573730")

	var col_top: Color = _calibrate_leaf_card_color(Color.html("#fce7f3"), 1.0, 0.30)
	var col_mid: Color = _calibrate_leaf_card_color(Color.html("#f472b6"), 0.90, 0.46)
	var col_bot: Color = _calibrate_leaf_card_color(Color.html("#9d174d"), 0.56, 0.52)

	var st_trunk := SurfaceTool.new()
	st_trunk.begin(Mesh.PRIMITIVE_TRIANGLES)

	# 1. Six massive flared buttress roots gripping the sanctuary earth
	for ri: int in range(6):
		var ra: float = float(ri) * (TAU / 6.0) + 0.18
		var r_out: float = 2.65 + 0.35 * sin(float(ri) * 2.1)
		var r_pts: Array[Vector3] = [
			Vector3(cos(ra) * r_out, -0.45, sin(ra) * r_out),
			Vector3(cos(ra) * (r_out * 0.62), 0.38, sin(ra) * (r_out * 0.62)),
			Vector3(cos(ra) * 0.72, 1.75, sin(ra) * 0.72),
		]
		var r_rads: Array[float] = [0.28, 0.48, 0.62]
		_append_tapered_tube(st_trunk, r_pts, r_rads, 6, bark_dark, bark_mid, true)

	# 2. Monumental gnarled 4-segment sacred trunk
	var t_pts: Array[Vector3] = [
		Vector3(0.0, -0.35, 0.0),
		Vector3(0.24, 2.35, -0.15),
		Vector3(-0.18, 5.15, 0.22),
		Vector3(0.10, 7.65, 0.05),
	]
	var t_rads: Array[float] = [1.58, 1.24, 1.05, 0.84]
	_append_tapered_tube(st_trunk, t_pts, t_rads, 8 if is_mob else 10, bark_dark, bark_mid, true)

	# 3. Six monumental sweeping boughs + wooden twigs + lush real-leaf sakura crown & weeping curtains
	var st_fol := SurfaceTool.new()
	st_fol.begin(Mesh.PRIMITIVE_TRIANGLES)

	var crown_center := Vector3(0.0, 9.6, 0.0)
	var crown_radius: float = 7.4
	var bough_segs: int = 6 if is_mob else 7

	for bi: int in range(6):
		var az: float = float(bi) * (TAU / 6.0) + 0.25
		var dir_xz := Vector3(cos(az), 0.0, sin(az))
		var b_start: Vector3 = t_pts[2].lerp(t_pts[3], 0.35 + 0.55 * float(bi % 3) / 2.0)
		var reach: float = 5.4 + 0.75 * sin(float(bi) * 1.9)
		var peak_y: float = 9.4 + 0.7 * cos(float(bi) * 1.3)
		var b_mid: Vector3 = b_start + dir_xz * (reach * 0.52) + Vector3(0.0, (peak_y - b_start.y) * 0.78, 0.0)
		var b_tip: Vector3 = b_start + dir_xz * reach + Vector3(0.0, peak_y - b_start.y - 0.55, 0.0)
		var b_pts: Array[Vector3] = [b_start, b_mid, b_tip]
		var b_rads: Array[float] = [0.62, 0.42, 0.18]
		_append_tapered_tube(st_trunk, b_pts, b_rads, bough_segs, bark_mid, bark_light, true)

		# Secondary & tertiary wooden twigs visible beneath the real-leaf sakura canopy
		var fork_a: float = az + 0.42
		var fork_tip: Vector3 = b_mid + Vector3(cos(fork_a), 0.0, sin(fork_a)) * (reach * 0.56) + Vector3(0.0, 1.35, 0.0)
		_append_cyl_between(st_trunk, b_mid, fork_tip, 0.30, 0.11, 5, bark_mid, bark_light)

		var fork_b: float = az - 0.44
		var fork_b_tip: Vector3 = b_mid + Vector3(cos(fork_b), 0.0, sin(fork_b)) * (reach * 0.46) + Vector3(0.0, 1.05, 0.0)
		_append_cyl_between(st_trunk, b_mid, fork_b_tip, 0.22, 0.08, 4, bark_mid, bark_light)

		# Lush spreading upper real-leaf sakura branch-card clusters on each monumental bough
		var tip_cnt: int = 4 if is_mob else 5
		var fork_cnt: int = 3 if is_mob else 4
		_append_leaf_card_cluster(
			st_fol, b_tip + Vector3(0.0, 0.35, 0.0), 3.15, tip_cnt,
			crown_center, col_top, col_mid, col_bot, float(bi) * 3.1 + 0.7,
			crown_radius, 0.16, 0.85, 0.24, 1.08
		)
		_append_leaf_card_cluster(
			st_fol, fork_tip + Vector3(0.0, 0.25, 0.0), 2.75, fork_cnt,
			crown_center, col_top, col_mid, col_bot, float(bi) * 4.7 + 1.9,
			crown_radius, 0.22, 0.88, 0.20, 1.05
		)
		if not is_mob:
			_append_leaf_card_cluster(
				st_fol, fork_b_tip + Vector3(0.0, 0.30, 0.0), 2.55, 3,
				crown_center, col_top, col_mid, col_bot, float(bi) * 2.3 + 5.1,
				crown_radius, 0.25, 0.90, 0.18, 1.02
			)

		# Cascading long vertical drooping curtains of real-leaf sakura branch cards!
		var drapes_per_bough: int = 3 if is_mob else 5
		for di: int in range(drapes_per_bough):
			var da: float = az + (float(di) - float(drapes_per_bough - 1) * 0.5) * 0.28
			var dr: float = reach * (0.84 + 0.18 * float(di % 2))
			var hang_top := Vector3(cos(da) * dr, peak_y - 0.10 + 0.25 * float(di % 2), sin(da) * dr)
			var drape_len: float = 3.4 + 1.55 * (0.5 + 0.5 * sin(float(bi * 7 + di) * 1.73))
			var card_w: float = 1.55 + 0.32 * cos(float(bi * 3 + di) * 2.1)
			_append_weeping_leaf_curtain(
				st_fol,
				hang_top,
				Vector3(cos(da), 0.0, sin(da)),
				drape_len,
				card_w,
				crown_center,
				crown_radius,
				col_top,
				col_mid,
				col_bot,
				float(bi * 11 + di) * 1.37
			)

	# Grand luminous upper summit branches & sunlit sakura leaf-card canopy dome
	var summit_specs: Array = [
		[Vector3(0.0, 10.7, 0.0), 3.45, 4 if is_mob else 6, 17.3],
		[Vector3(-1.8, 10.1, 1.3), 2.85, 3 if is_mob else 4, 23.1],
		[Vector3(1.9, 10.2, -1.2), 2.85, 3 if is_mob else 4, 29.4],
		[Vector3(0.4, 10.0, 2.0), 2.65, 2 if is_mob else 4, 35.7],
	]
	for si_c: int in range(summit_specs.size()):
		var ss: Array = summit_specs[si_c]
		var sp_pos: Vector3 = ss[0] as Vector3
		_append_cyl_between(st_trunk, t_pts[3], sp_pos - Vector3(0.0, 0.35, 0.0), 0.32, 0.11, 5, bark_mid, bark_light)
		_append_leaf_card_cluster(
			st_fol, sp_pos, float(ss[1]), int(ss[2]),
			crown_center, col_top, col_mid, col_bot, float(ss[3]),
			crown_radius, 0.28, 0.82, 0.18, 1.06
		)

	# 4. Sacred braided shimenawa rope + 5 crisp white shide paper zigzags around trunk
	var st_sacred := SurfaceTool.new()
	st_sacred.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rope_y: float = 2.55
	var rope_segs: int = 16 if is_mob else 24
	var rope_pts: Array[Vector3] = []
	var rope_rads: Array[float] = []
	var straw_dark := Color.html("#a16207")
	var straw_gold := Color.html("#eab308")
	for si: int in range(rope_segs + 1):
		var a: float = (float(si) / float(rope_segs)) * TAU
		var front_bulge: float = 0.5 + 0.5 * maxf(0.0, sin(a)) # thick belly on +Z front
		var r_ring: float = 1.38 + front_bulge * 0.12
		var sag_y: float = rope_y - front_bulge * 0.14 + sin(a * 6.0) * 0.03
		rope_pts.append(Vector3(cos(a) * r_ring, sag_y, sin(a) * r_ring))
		rope_rads.append(0.14 + front_bulge * 0.12 + 0.025 * sin(a * 12.0))
	_append_tapered_tube(st_sacred, rope_pts, rope_rads, 6, straw_dark, straw_gold, false)

	var paper_top := Color.html("#ffffff")
	var paper_bot := Color.html("#e2e8f0")
	for zi: int in range(5):
		var za: float = PI * 0.5 + (float(zi) - 2.0) * 0.42
		var z_pos := Vector3(cos(za) * 1.54, rope_y - 0.16, sin(za) * 1.54)
		_append_shide_zigzag(st_sacred, z_pos, -za + PI * 0.5, 1.35, paper_top, paper_bot)

	tree.add_child(_make_mesh_inst(st_trunk.commit(), make_wafuu_mat(0, is_mob, 0.88, 0.02, 0.24)))
	tree.add_child(_make_mesh_inst(st_sacred.commit(), make_wafuu_mat(4, is_mob, 0.76, 0.04, 0.0)))
	tree.add_child(_make_mesh_inst(st_fol.commit(), make_leaf_card_mat("sakura", is_mob, Color.WHITE)))
	content_root.add_child(tree)
	return tree


# ==============================================================================
# 3. TRADITIONAL JAPANESE ARCHITECTURE & CONCAVE CURVED ROOFS
# ==============================================================================

static func _append_curved_japanese_roof(
	st_roof: SurfaceTool,
	st_body: SurfaceTool,
	style: String,
	half_w: float,
	half_d: float,
	y_eave: float,
	y_top: float,
	roof_col: Color,
	wood_col: Color,
	plaster_col: Color,
	gold_col: Color,
	is_mob: bool
) -> void:
	## Authentic sweeping concave-eave Japanese roof:
	## - "irimoya": hip-and-gable roof with 4 concave slope rings, upturned sori corners,
	##              plaster gable triangles, exposed dark cedar truss & rafters, and gold onigawara.
	## - "kirizuma": sweeping concave gabled roof with bargeboards, timber truss, rafters & onigawara.
	## - "hogyo": 4-sided sweeping concave pyramidal shrine/pagoda roof with upturned corners & finial.
	var col_eave: Color = roof_col.darkened(0.24)
	var col_mid: Color = roof_col
	var col_ridge: Color = roof_col.lightened(0.16)
	var col_under: Color = wood_col.darkened(0.28)
	var gold_dark: Color = gold_col.darkened(0.24)
	var slope_h: float = maxf(0.4, y_top - y_eave)
	var rings: int = 4
	var corner_lift: float = clampf(slope_h * 0.22, 0.14, 0.62)

	if style == "hogyo":
		# 4-sided concave pyramidal roof with graceful upturned corners
		var top_r: float = maxf(0.14, minf(half_w, half_d) * 0.08)
		var ring_pts: Array = []
		var ring_cols: Array[Color] = []
		for ri: int in range(rings + 1):
			var t: float = float(ri) / float(rings)
			var rw: float = lerpf(top_r, half_w, t)
			var rd: float = lerpf(top_r, half_d, t)
			# Sweeping concave curve: steeper at top, flattens and kicks slightly up at corners
			var base_y: float = y_top - slope_h * (1.0 - pow(1.0 - t, 1.85))
			var lift_c: float = corner_lift * pow(t, 2.2)
			var sub_n: int = 2 if is_mob else 3
			var pts := PackedVector3Array()
			# Walk perimeter CW when viewed from +Y: (-w,-d) -> (+w,-d) -> (+w,+d) -> (-w,+d)
			var corners: Array[Vector2] = [
				Vector2(-rw, -rd),
				Vector2(rw, -rd),
				Vector2(rw, rd),
				Vector2(-rw, rd),
			]
			for side_i: int in range(4):
				var ca: Vector2 = corners[side_i]
				var cb: Vector2 = corners[(side_i + 1) % 4]
				for si: int in range(sub_n):
					var u: float = float(si) / float(sub_n)
					var p2: Vector2 = ca.lerp(cb, u)
					var corner_w: float = absf(u * 2.0 - 1.0)
					var py: float = base_y + lift_c * pow(corner_w, 1.9)
					pts.append(Vector3(p2.x, py, p2.y))
			ring_pts.append(pts)
			ring_cols.append(col_ridge.lerp(col_eave, t))

		for ri: int in range(rings):
			var r0: PackedVector3Array = ring_pts[ri]
			var r1: PackedVector3Array = ring_pts[ri + 1]
			var c0: Color = ring_cols[ri]
			var c1: Color = ring_cols[ri + 1]
			var pcount: int = r0.size()
			for pi: int in range(pcount):
				var pn: int = (pi + 1) % pcount
				var v00: Vector3 = r0[pi]
				var v01: Vector3 = r0[pn]
				var v11: Vector3 = r1[pn]
				var v10: Vector3 = r1[pi]
				var mid_p: Vector3 = (v00 + v01 + v11 + v10) * 0.25
				var out_h := Vector3(mid_p.x, slope_h * 0.85, mid_p.z)
				_append_quad_colored(st_roof, v00, v01, v11, v10, c0, c0, c1, c1, out_h)

		# Eave thickness skirt + underside soffit + exposed rafters
		var outer_r: PackedVector3Array = ring_pts[rings]
		var eave_t: float = clampf(slope_h * 0.11, 0.10, 0.22)
		var pcount_o: int = outer_r.size()
		for pi: int in range(pcount_o):
			var pn: int = (pi + 1) % pcount_o
			var a0: Vector3 = outer_r[pi]
			var a1: Vector3 = outer_r[pn]
			var b0: Vector3 = a0 - Vector3(0.0, eave_t, 0.0)
			var b1: Vector3 = a1 - Vector3(0.0, eave_t, 0.0)
			var out_s := Vector3((a0.x + a1.x) * 0.5, 0.0, (a0.z + a1.z) * 0.5)
			_append_quad_colored(st_roof, a0, a1, b1, b0, col_eave, col_eave, col_eave.darkened(0.25), col_eave.darkened(0.25), out_s)
			_append_tri_colored(st_body, Vector3(0.0, y_eave - eave_t * 0.6, 0.0), b1, b0, col_under, col_under, col_under, Vector3.DOWN)

		# Diagonal hip ridge ribs (kudari-mune) running to the 4 upturned corners
		for sx: float in [-1.0, 1.0]:
			for sz: float in [-1.0, 1.0]:
				var rib_pts: Array[Vector3] = []
				var rib_rads: Array[float] = []
				for ri: int in range(rings + 1):
					var t: float = float(ri) / float(rings)
					var py: float = y_top - slope_h * (1.0 - pow(1.0 - t, 1.85)) + corner_lift * pow(t, 2.2) + 0.07
					rib_pts.append(Vector3(sx * lerpf(top_r, half_w * 1.03, t), py, sz * lerpf(top_r, half_d * 1.03, t)))
					rib_rads.append(lerpf(0.11, 0.08, t))
				_append_tapered_tube(st_roof, rib_pts, rib_rads, 4, col_ridge, gold_col, true)

		# Exposed underside cedar rafters radiating to all 4 edges
		var raft_n: int = 4 if is_mob else 6
		for si: int in range(4):
			for ri: int in range(raft_n):
				var u: float = (float(ri) + 0.5) / float(raft_n) * 2.0 - 1.0
				var p_in: Vector3
				var p_out: Vector3
				if si == 0:
					p_in = Vector3(u * half_w * 0.45, y_eave + slope_h * 0.14, -half_d * 0.45)
					p_out = Vector3(u * half_w * 0.96, y_eave - eave_t * 0.75, -half_d * 0.96)
				elif si == 1:
					p_in = Vector3(u * half_w * 0.45, y_eave + slope_h * 0.14, half_d * 0.45)
					p_out = Vector3(u * half_w * 0.96, y_eave - eave_t * 0.75, half_d * 0.96)
				elif si == 2:
					p_in = Vector3(-half_w * 0.45, y_eave + slope_h * 0.14, u * half_d * 0.45)
					p_out = Vector3(-half_w * 0.96, y_eave - eave_t * 0.75, u * half_d * 0.96)
				else:
					p_in = Vector3(half_w * 0.45, y_eave + slope_h * 0.14, u * half_d * 0.45)
					p_out = Vector3(half_w * 0.96, y_eave - eave_t * 0.75, u * half_d * 0.96)
				_append_cyl_between(st_body, p_in, p_out, 0.045, 0.04, 4, col_under, wood_col)

		# Golden square lotus base (roban) + jewel finial (hoju)
		_append_box(st_roof, Vector3(0.46, 0.22, 0.46), Vector3(0.0, y_top + 0.08, 0.0), Vector3.ZERO, gold_dark, gold_col)
		_append_cyl(st_roof, 0.22, 0.04, 0.56, 6, Vector3(0.0, y_top + 0.44, 0.0), Vector3.ZERO, gold_dark, gold_col.lightened(0.22))
		return

	if style == "kirizuma":
		# Sweeping concave gabled roof along X axis (front +Z and back -Z slopes)
		var eave_t: float = clampf(slope_h * 0.10, 0.10, 0.20)
		var sub_x: int = 3 if is_mob else 4
		for side_z: float in [-1.0, 1.0]:
			for ri: int in range(rings):
				var t0: float = float(ri) / float(rings)
				var t1: float = float(ri + 1) / float(rings)
				var z0: float = side_z * half_d * t0
				var z1: float = side_z * half_d * t1
				var y0_b: float = y_top - slope_h * (1.0 - pow(1.0 - t0, 1.85))
				var y1_b: float = y_top - slope_h * (1.0 - pow(1.0 - t1, 1.85))
				var c0: Color = col_ridge.lerp(col_eave, t0)
				var c1: Color = col_ridge.lerp(col_eave, t1)
				for xi: int in range(sub_x):
					var ux0: float = (float(xi) / float(sub_x)) * 2.0 - 1.0
					var ux1: float = (float(xi + 1) / float(sub_x)) * 2.0 - 1.0
					var x0: float = ux0 * half_w
					var x1: float = ux1 * half_w
					var lift00: float = corner_lift * 0.45 * pow(t0, 2.2) * pow(absf(ux0), 2.0)
					var lift01: float = corner_lift * 0.45 * pow(t0, 2.2) * pow(absf(ux1), 2.0)
					var lift10: float = corner_lift * 0.45 * pow(t1, 2.2) * pow(absf(ux0), 2.0)
					var lift11: float = corner_lift * 0.45 * pow(t1, 2.2) * pow(absf(ux1), 2.0)
					var p00 := Vector3(x0, y0_b + lift00, z0)
					var p01 := Vector3(x1, y0_b + lift01, z0)
					var p11 := Vector3(x1, y1_b + lift11, z1)
					var p10 := Vector3(x0, y1_b + lift10, z1)
					var out_h := Vector3(0.0, 1.0, side_z * 0.85)
					_append_quad_colored(st_roof, p00, p01, p11, p10, c0, c0, c1, c1, out_h)
					# Underside roof soffit
					var u_off := Vector3(0.0, -eave_t, 0.0)
					_append_quad_colored(st_body, p00 + u_off, p10 + u_off, p11 + u_off, p01 + u_off, col_under, col_under, col_under, col_under, Vector3(0.0, -1.0, -side_z * 0.4))
			# Front/back eave fascia edge
			var eave_z: float = side_z * half_d
			var el_end: float = corner_lift * 0.45
			for xi: int in range(sub_x):
				var ux0: float = (float(xi) / float(sub_x)) * 2.0 - 1.0
				var ux1: float = (float(xi + 1) / float(sub_x)) * 2.0 - 1.0
				var p0 := Vector3(ux0 * half_w, y_eave + el_end * pow(absf(ux0), 2.0), eave_z)
				var p1 := Vector3(ux1 * half_w, y_eave + el_end * pow(absf(ux1), 2.0), eave_z)
				_append_quad_colored(st_roof, p0, p1, p1 - Vector3(0.0, eave_t, 0.0), p0 - Vector3(0.0, eave_t, 0.0), col_eave, col_eave, col_eave.darkened(0.25), col_eave.darkened(0.25), Vector3(0.0, 0.0, side_z))

		# White plaster gable triangles + dark cedar bargeboards (hafu) + exposed king-post truss
		var gable_inset: float = half_w * 0.84
		for sx: float in [-1.0, 1.0]:
			var gx: float = sx * gable_inset
			var g_top := Vector3(gx, y_top - 0.10, 0.0)
			var g_fl := Vector3(gx, y_eave - 0.04, half_d * 0.86)
			var g_bk := Vector3(gx, y_eave - 0.04, -half_d * 0.86)
			_append_tri_colored(st_body, g_top, g_fl, g_bk, plaster_col, plaster_col.darkened(0.10), plaster_col.darkened(0.10), Vector3(sx, 0.0, 0.0))
			# Dark wood king-post & horizontal collar beam on gable face
			_append_box(st_body, Vector3(0.12, slope_h * 0.88, 0.14), Vector3(gx + sx * 0.04, y_eave + slope_h * 0.46, 0.0), Vector3.ZERO, wood_col.darkened(0.2), wood_col)
			_append_box(st_body, Vector3(0.12, 0.14, half_d * 1.12), Vector3(gx + sx * 0.04, y_eave + slope_h * 0.32, 0.0), Vector3.ZERO, wood_col.darkened(0.18), wood_col)
			# Sweeping dark bargeboards at outer gable edges
			for side_z: float in [-1.0, 1.0]:
				var barge_pts: Array[Vector3] = []
				var barge_rads: Array[float] = []
				for ri: int in range(rings + 1):
					var t: float = float(ri) / float(rings)
					var py: float = y_top - slope_h * (1.0 - pow(1.0 - t, 1.85)) + corner_lift * 0.45 * pow(t, 2.2) - eave_t * 0.35
					barge_pts.append(Vector3(sx * half_w, py, side_z * half_d * t))
					barge_rads.append(0.10)
				_append_tapered_tube(st_body, barge_pts, barge_rads, 4, wood_col.darkened(0.25), wood_col, true)

		# Exposed cedar rafters under front & back eaves
		var raft_cnt: int = 5 if is_mob else 8
		for side_z: float in [-1.0, 1.0]:
			for xi: int in range(raft_cnt):
				var ux: float = (float(xi) + 0.5) / float(raft_cnt) * 2.0 - 1.0
				var rx: float = ux * half_w * 0.94
				var p_in := Vector3(rx, y_eave + slope_h * 0.20, side_z * half_d * 0.52)
				var p_out := Vector3(rx, y_eave - eave_t * 0.72, side_z * half_d * 0.97)
				_append_cyl_between(st_body, p_in, p_out, 0.048, 0.044, 4, col_under, wood_col)

		# Prominent central ridge beam (mune) + upturned golden onigawara end ornaments
		_append_box(st_roof, Vector3(half_w * 2.08, 0.28, 0.30), Vector3(0.0, y_top + 0.11, 0.0), Vector3.ZERO, col_mid, col_ridge)
		for sx: float in [-1.0, 1.0]:
			_append_box(st_roof, Vector3(0.28, 0.42, 0.36), Vector3(sx * (half_w * 1.04), y_top + 0.22, 0.0), Vector3(0.0, 0.0, -sx * 0.22), gold_dark, gold_col)
		return

	# Default: "irimoya" — authentic hip-and-gable Japanese roof!
	# Lower sweeping concave hip skirt from mid-break down to overhanging eaves,
	# crowned by a pitched concave gable section with white plaster gables & gold onigawara!
	var break_y: float = y_eave + slope_h * 0.48
	var ridge_hw: float = half_w * 0.54
	var upper_hw: float = half_w * 0.58
	var upper_hd: float = half_d * 0.54
	var eave_t: float = clampf(slope_h * 0.10, 0.10, 0.20)

	# A) Lower 4-sided concave hip skirt (3 rings from break rect out to outer eaves)
	var skirt_rings: int = 3
	var skirt_pts: Array = []
	var skirt_cols: Array[Color] = []
	var sub_n: int = 2 if is_mob else 3
	for ri: int in range(skirt_rings + 1):
		var t: float = float(ri) / float(skirt_rings)
		var rw: float = lerpf(upper_hw, half_w, t)
		var rd: float = lerpf(upper_hd, half_d, t)
		var base_y: float = break_y - (break_y - y_eave) * (1.0 - pow(1.0 - t, 1.75))
		var lift_c: float = corner_lift * pow(t, 2.0)
		var pts := PackedVector3Array()
		var corners: Array[Vector2] = [
			Vector2(-rw, -rd),
			Vector2(rw, -rd),
			Vector2(rw, rd),
			Vector2(-rw, rd),
		]
		for side_i: int in range(4):
			var ca: Vector2 = corners[side_i]
			var cb: Vector2 = corners[(side_i + 1) % 4]
			for si: int in range(sub_n):
				var u: float = float(si) / float(sub_n)
				var p2: Vector2 = ca.lerp(cb, u)
				var cw: float = absf(u * 2.0 - 1.0)
				pts.append(Vector3(p2.x, base_y + lift_c * pow(cw, 1.85), p2.y))
		skirt_pts.append(pts)
		skirt_cols.append(col_mid.lerp(col_eave, t))

	for ri: int in range(skirt_rings):
		var r0: PackedVector3Array = skirt_pts[ri]
		var r1: PackedVector3Array = skirt_pts[ri + 1]
		var c0: Color = skirt_cols[ri]
		var c1: Color = skirt_cols[ri + 1]
		var pcount: int = r0.size()
		for pi: int in range(pcount):
			var pn: int = (pi + 1) % pcount
			var v00: Vector3 = r0[pi]
			var v01: Vector3 = r0[pn]
			var v11: Vector3 = r1[pn]
			var v10: Vector3 = r1[pi]
			var mid_p: Vector3 = (v00 + v01 + v11 + v10) * 0.25
			_append_quad_colored(st_roof, v00, v01, v11, v10, c0, c0, c1, c1, Vector3(mid_p.x, slope_h * 0.9, mid_p.z))

	# Outer eave fascia thickness + dark soffit underside
	var outer_sk: PackedVector3Array = skirt_pts[skirt_rings]
	var pcount_sk: int = outer_sk.size()
	for pi: int in range(pcount_sk):
		var pn: int = (pi + 1) % pcount_sk
		var a0: Vector3 = outer_sk[pi]
		var a1: Vector3 = outer_sk[pn]
		var b0: Vector3 = a0 - Vector3(0.0, eave_t, 0.0)
		var b1: Vector3 = a1 - Vector3(0.0, eave_t, 0.0)
		_append_quad_colored(st_roof, a0, a1, b1, b0, col_eave, col_eave, col_eave.darkened(0.25), col_eave.darkened(0.25), Vector3((a0.x + a1.x) * 0.5, 0.0, (a0.z + a1.z) * 0.5))
		_append_tri_colored(st_body, Vector3(0.0, y_eave - eave_t * 0.5, 0.0), b1, b0, col_under, col_under, col_under, Vector3.DOWN)

	# B) Upper concave gabled crown (2 slope rings from ridge down to break_y)
	var upper_h: float = y_top - break_y
	for side_z: float in [-1.0, 1.0]:
		for ri: int in range(2):
			var t0: float = float(ri) * 0.5
			var t1: float = float(ri + 1) * 0.5
			var z0: float = side_z * upper_hd * t0
			var z1: float = side_z * upper_hd * t1
			var y0: float = y_top - upper_h * (1.0 - pow(1.0 - t0, 1.55))
			var y1: float = y_top - upper_h * (1.0 - pow(1.0 - t1, 1.55))
			var w0: float = lerpf(ridge_hw, upper_hw * 1.04, t0)
			var w1: float = lerpf(ridge_hw, upper_hw * 1.04, t1)
			var c0: Color = col_ridge.lerp(col_mid, t0)
			var c1: Color = col_ridge.lerp(col_mid, t1)
			var p00 := Vector3(-w0, y0, z0)
			var p01 := Vector3(w0, y0, z0)
			var p11 := Vector3(w1, y1, z1)
			var p10 := Vector3(-w1, y1, z1)
			_append_quad_colored(st_roof, p00, p01, p11, p10, c0, c0, c1, c1, Vector3(0.0, 1.0, side_z * 0.85))

	# C) White plaster gable triangles (tsuma) + dark wood truss & bargeboards
	for sx: float in [-1.0, 1.0]:
		var gx: float = sx * (ridge_hw * 0.94)
		var g_top := Vector3(gx, y_top - 0.06, 0.0)
		var g_f := Vector3(gx, break_y - 0.02, upper_hd * 0.96)
		var g_b := Vector3(gx, break_y - 0.02, -upper_hd * 0.96)
		_append_tri_colored(st_body, g_top, g_f, g_b, plaster_col, plaster_col.darkened(0.08), plaster_col.darkened(0.08), Vector3(sx, 0.0, 0.0))
		_append_box(st_body, Vector3(0.10, upper_h * 0.85, 0.12), Vector3(gx + sx * 0.04, break_y + upper_h * 0.44, 0.0), Vector3.ZERO, wood_col.darkened(0.22), wood_col)
		_append_box(st_body, Vector3(0.10, 0.12, upper_hd * 1.25), Vector3(gx + sx * 0.04, break_y + upper_h * 0.28, 0.0), Vector3.ZERO, wood_col.darkened(0.18), wood_col)
		for side_z: float in [-1.0, 1.0]:
			_append_cyl_between(st_body, Vector3(sx * ridge_hw, y_top - 0.04, 0.0), Vector3(sx * upper_hw * 1.04, break_y - 0.02, side_z * upper_hd), 0.08, 0.08, 4, wood_col.darkened(0.2), wood_col)

	# D) Diagonal hip ribs (kudari-mune) down to all 4 upturned eaves corners
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var h_pts: Array[Vector3] = []
			var h_rads: Array[float] = []
			for ri: int in range(skirt_rings + 1):
				var t: float = float(ri) / float(skirt_rings)
				var py: float = break_y - (break_y - y_eave) * (1.0 - pow(1.0 - t, 1.75)) + corner_lift * pow(t, 2.0) + 0.07
				h_pts.append(Vector3(sx * lerpf(upper_hw, half_w * 1.03, t), py, sz * lerpf(upper_hd, half_d * 1.03, t)))
				h_rads.append(lerpf(0.10, 0.075, t))
			_append_tapered_tube(st_roof, h_pts, h_rads, 4, col_ridge, gold_col, true)

	# E) Exposed dark cedar rafters lining the eaves on all 4 sides
	var raft_x: int = 5 if is_mob else 8
	for side_z: float in [-1.0, 1.0]:
		for xi: int in range(raft_x):
			var ux: float = (float(xi) + 0.5) / float(raft_x) * 2.0 - 1.0
			var rx: float = ux * half_w * 0.90
			_append_cyl_between(st_body, Vector3(rx, y_eave + 0.24, side_z * half_d * 0.55), Vector3(rx, y_eave - eave_t * 0.72, side_z * half_d * 0.96), 0.045, 0.040, 4, col_under, wood_col)
	var raft_z: int = 3 if is_mob else 5
	for side_x: float in [-1.0, 1.0]:
		for zi: int in range(raft_z):
			var uz: float = (float(zi) + 0.5) / float(raft_z) * 2.0 - 1.0
			var rz: float = uz * half_d * 0.84
			_append_cyl_between(st_body, Vector3(side_x * half_w * 0.55, y_eave + 0.24, rz), Vector3(side_x * half_w * 0.96, y_eave - eave_t * 0.72, rz), 0.045, 0.040, 4, col_under, wood_col)

	# F) Prominent central ridge beam (mune) + upturned golden onigawara ornaments
	_append_box(st_roof, Vector3(ridge_hw * 2.14, 0.28, 0.30), Vector3(0.0, y_top + 0.11, 0.0), Vector3.ZERO, col_mid, col_ridge)
	for sx: float in [-1.0, 1.0]:
		_append_box(st_roof, Vector3(0.28, 0.44, 0.38), Vector3(sx * (ridge_hw * 1.08), y_top + 0.24, 0.0), Vector3(0.0, 0.0, -sx * 0.24), gold_dark, gold_col)


static func add_japanese_teahouse(
	arena: Arena3D,
	content_root: Node3D,
	base_pos: Vector3,
	sc: float = 1.0,
	yaw: float = 0.0
) -> Node3D:
	var is_mob: bool = UiStyle.is_mobile_device()
	var root := Node3D.new()
	root.name = "JapaneseTeahouse"
	root.position = base_pos
	root.rotation.y = yaw
	root.scale = Vector3(sc, sc, sc)

	# Register clean footprint obstacles (leaves front NPC standing zone z > +2.3 open)
	_register_rotated_obstacle(arena, base_pos, yaw, sc, Vector2(-1.25, -0.25), 2.05, 4.4)
	_register_rotated_obstacle(arena, base_pos, yaw, sc, Vector2(1.25, -0.25), 2.05, 4.4)

	var st_body := SurfaceTool.new()
	st_body.begin(Mesh.PRIMITIVE_TRIANGLES)
	var st_roof := SurfaceTool.new()
	st_roof.begin(Mesh.PRIMITIVE_TRIANGLES)
	var st_glow := SurfaceTool.new()
	st_glow.begin(Mesh.PRIMITIVE_TRIANGLES)

	var stone_dark := Color.html("#334155")
	var stone_light := Color.html("#64748b")
	var wood_dark := Color.html("#3b2316")
	var wood_cedar := Color.html("#5c3a21")
	var wood_hinoki := Color.html("#9c6f44")
	var plaster_bot := Color.html("#d8cfc2")
	var plaster_top := Color.html("#f6f0e6")
	var crimson_bot := Color.html("#7f1d1d")
	var crimson_top := Color.html("#dc2626")
	var roof_indigo := Color.html("#1e293b")
	var gold_col := Color.html("#f59e0b")

	# 1. Raised stone foundation plinth + cypress engawa verandah + front steps
	_append_box(st_body, Vector3(6.2, 0.78, 4.8), Vector3(0.0, 0.04, -0.15), Vector3.ZERO, stone_dark, stone_light)
	_append_box(st_body, Vector3(6.4, 0.22, 1.35), Vector3(0.0, 0.46, 2.55), Vector3.ZERO, wood_cedar, wood_hinoki)
	# Verandah support piers
	for px: float in [-2.85, -1.0, 1.0, 2.85]:
		_append_box(st_body, Vector3(0.22, 0.72, 0.22), Vector3(px, 0.08, 3.05), Vector3.ZERO, stone_dark, stone_light)
	# Front 2-step wooden stairs
	_append_box(st_body, Vector3(2.15, 0.20, 0.48), Vector3(0.0, 0.24, 3.42), Vector3.ZERO, wood_cedar, wood_hinoki)
	_append_box(st_body, Vector3(2.25, 0.18, 0.46), Vector3(0.0, 0.05, 3.84), Vector3.ZERO, stone_dark, stone_light)

	# 2. Cream shikkui plaster walls + dark aged cedar wainscoting & timber post frame
	_append_box(st_body, Vector3(5.6, 2.95, 4.2), Vector3(0.0, 1.92, -0.2), Vector3.ZERO, plaster_bot, plaster_top)
	# Lower dark charred-cedar skirting band
	_append_box(st_body, Vector3(5.72, 0.72, 4.32), Vector3(0.0, 0.82, -0.2), Vector3.ZERO, wood_dark, wood_cedar)
	# Vertical corner & wall timber posts
	for px: float in [-2.82, -1.15, 1.15, 2.82]:
		for pz: float in [-2.32, 1.92]:
			_append_box(st_body, Vector3(0.22, 3.15, 0.22), Vector3(px, 2.02, pz), Vector3.ZERO, wood_dark, wood_cedar)
	# Engawa front veranda posts supporting eaves
	for px: float in [-2.88, 2.88]:
		_append_box(st_body, Vector3(0.20, 2.95, 0.20), Vector3(px, 2.02, 3.05), Vector3.ZERO, wood_dark, wood_cedar)
	# Horizontal tie beams (nageshi) & top eave plate
	_append_box(st_body, Vector3(5.92, 0.20, 4.52), Vector3(0.0, 3.45, -0.2), Vector3.ZERO, wood_dark, wood_cedar)
	_append_box(st_body, Vector3(5.96, 0.16, 0.20), Vector3(0.0, 3.35, 3.05), Vector3.ZERO, wood_dark, wood_cedar)

	# 3. Warm glowing shoji sliding doors (front & side) with dark wooden grid mullions
	var shoji_bot := Color.html("#f59e0b")
	var shoji_top := Color.html("#fef3c7")
	# Front entrance shoji panels
	_append_box(st_glow, Vector3(2.10, 2.18, 0.08), Vector3(0.0, 1.66, 1.94), Vector3.ZERO, shoji_bot, shoji_top)
	# Side shoji windows (left & right)
	for sx: float in [-1.0, 1.0]:
		_append_box(st_glow, Vector3(0.08, 1.48, 2.05), Vector3(sx * 2.82, 2.02, -0.2), Vector3.ZERO, shoji_bot, shoji_top)
		# Vertical koshi lattice slats over side windows
		var slats: int = 5 if is_mob else 7
		for si: int in range(slats):
			var sz: float = -1.05 + (float(si) / float(slats - 1)) * 1.70
			_append_box(st_body, Vector3(0.10, 1.56, 0.055), Vector3(sx * 2.86, 2.02, sz), Vector3.ZERO, wood_dark, wood_cedar)
	# Front shoji grid mullions (vertical & horizontal)
	for mx: float in [-1.02, -0.34, 0.34, 1.02]:
		_append_box(st_body, Vector3(0.06, 2.24, 0.12), Vector3(mx, 1.66, 1.96), Vector3.ZERO, wood_dark, wood_cedar)
	for my: float in [0.95, 1.48, 2.02, 2.55]:
		_append_box(st_body, Vector3(2.16, 0.055, 0.12), Vector3(0.0, my, 1.96), Vector3.ZERO, wood_dark, wood_cedar)

	# 4. Crimson 3-panel noren entrance curtains hanging under front lintel
	for ni: int in range(3):
		var nx: float = (float(ni) - 1.0) * 0.72
		_append_box(st_body, Vector3(0.64, 0.78, 0.06), Vector3(nx, 2.58, 2.24), Vector3(0.06, 0.0, 0.0), crimson_bot, crimson_top)
	_append_cyl_between(st_body, Vector3(-1.18, 2.98, 2.22), Vector3(1.18, 2.98, 2.22), 0.035, 0.035, 5, wood_hinoki, wood_hinoki)

	# 5. Two hanging glowing red paper chochin lanterns under front eaves
	var chochin_bot := Color.html("#dc2626")
	var chochin_top := Color.html("#fb923c")
	var lan_sp := SphereMesh.new()
	lan_sp.radius = 0.24
	lan_sp.height = 0.62
	lan_sp.radial_segments = 8
	lan_sp.rings = 5
	for sx: float in [-1.0, 1.0]:
		var lp := Vector3(sx * 2.05, 2.72, 3.05)
		_append_cyl_between(st_body, lp + Vector3(0.0, 0.30, 0.0), lp + Vector3(0.0, 0.62, 0.0), 0.02, 0.02, 4, wood_dark, wood_dark)
		_append_cyl(st_body, 0.14, 0.14, 0.06, 8, lp + Vector3(0.0, 0.30, 0.0), Vector3.ZERO, wood_dark, wood_dark)
		_append_cyl(st_body, 0.14, 0.14, 0.06, 8, lp - Vector3(0.0, 0.30, 0.0), Vector3.ZERO, wood_dark, wood_dark)
		_append_mesh_colored(st_glow, lan_sp, Transform3D(Basis.IDENTITY, lp), chochin_bot, chochin_top, lp.y - 0.30, lp.y + 0.30)

	# 6. Outdoor wooden tea counter & bench on right veranda wing
	_append_box(st_body, Vector3(1.65, 0.10, 0.72), Vector3(2.02, 1.24, 2.38), Vector3.ZERO, wood_cedar, wood_hinoki)
	_append_box(st_body, Vector3(1.55, 0.70, 0.56), Vector3(2.02, 0.86, 2.35), Vector3.ZERO, wood_dark, wood_cedar)
	# Resting bench with crimson cloth seat on left wing
	_append_box(st_body, Vector3(1.55, 0.12, 0.62), Vector3(-2.02, 0.94, 2.65), Vector3.ZERO, crimson_bot, crimson_top)
	for lx: float in [-2.62, -1.42]:
		_append_box(st_body, Vector3(0.10, 0.44, 0.52), Vector3(lx, 0.70, 2.65), Vector3.ZERO, wood_dark, wood_cedar)

	# 7. Sweeping curved dark-indigo Kawara irimoya roof
	_append_curved_japanese_roof(
		st_roof, st_body, "irimoya",
		4.35, 3.65, 3.52, 6.25,
		roof_indigo, wood_dark, plaster_top, gold_col, is_mob
	)

	root.add_child(_make_mesh_inst(st_body.commit(), make_wafuu_mat(4, is_mob, 0.70, 0.04, 0.0)))
	root.add_child(_make_mesh_inst(st_roof.commit(), make_wafuu_mat(2, is_mob, 0.54, 0.12, 0.0)))
	root.add_child(_make_mesh_inst(st_glow.commit(), _make_vcol_glow_mat()))
	content_root.add_child(root)
	return root


static func add_japanese_forge(
	arena: Arena3D,
	content_root: Node3D,
	base_pos: Vector3,
	sc: float = 1.0,
	yaw: float = 0.0
) -> Node3D:
	var is_mob: bool = UiStyle.is_mobile_device()
	var root := Node3D.new()
	root.name = "JapaneseForge"
	root.position = base_pos
	root.rotation.y = yaw
	root.scale = Vector3(sc, sc, sc)

	# Register clean obstacles for forge body & hearth while leaving front blacksmith spot clear
	_register_rotated_obstacle(arena, base_pos, yaw, sc, Vector2(-1.15, -0.75), 1.80, 4.4)
	_register_rotated_obstacle(arena, base_pos, yaw, sc, Vector2(1.15, -0.75), 1.80, 4.4)
	_register_rotated_obstacle(arena, base_pos, yaw, sc, Vector2(0.0, 0.35), 1.15, 1.9)

	var st_body := SurfaceTool.new()
	st_body.begin(Mesh.PRIMITIVE_TRIANGLES)
	var st_roof := SurfaceTool.new()
	st_roof.begin(Mesh.PRIMITIVE_TRIANGLES)
	var st_glow := SurfaceTool.new()
	st_glow.begin(Mesh.PRIMITIVE_TRIANGLES)

	var stone_dark := Color.html("#27303d")
	var stone_mid := Color.html("#475569")
	var stone_light := Color.html("#64748b")
	var timber_dark := Color.html("#2c1b12")
	var timber_mid := Color.html("#4a2e1d")
	var iron_dark := Color.html("#1e293b")
	var iron_shine := Color.html("#94a3b8")
	var roof_charcoal := Color.html("#1c2431")
	var bronze_col := Color.html("#d97706")

	# 1. Heavy stone foundation pad + back & side stone smithy walls (open front bay!)
	_append_box(st_body, Vector3(6.2, 0.65, 5.2), Vector3(0.0, 0.02, -0.1), Vector3.ZERO, stone_dark, stone_mid)
	# Rear stone wall
	_append_box(st_body, Vector3(5.6, 3.25, 0.55), Vector3(0.0, 1.95, -2.25), Vector3.ZERO, stone_dark, stone_light)
	# Left & right partial stone walls
	for sx: float in [-1.0, 1.0]:
		_append_box(st_body, Vector3(0.48, 2.85, 3.2), Vector3(sx * 2.62, 1.75, -0.85), Vector3.ZERO, stone_dark, stone_mid)
	# Heavy charred timber pillars framing open front forge bay
	for px: float in [-2.68, 2.68]:
		for pz: float in [-2.25, 2.05]:
			_append_box(st_body, Vector3(0.28, 3.45, 0.28), Vector3(px, 2.05, pz), Vector3.ZERO, timber_dark, timber_mid)
	# Heavy lintel beams supporting roof
	_append_box(st_body, Vector3(5.85, 0.28, 0.28), Vector3(0.0, 3.62, 2.05), Vector3.ZERO, timber_dark, timber_mid)
	_append_box(st_body, Vector3(5.85, 0.28, 0.28), Vector3(0.0, 3.62, -2.25), Vector3.ZERO, timber_dark, timber_mid)
	for sx: float in [-1.0, 1.0]:
		_append_box(st_body, Vector3(0.28, 0.28, 4.65), Vector3(sx * 2.68, 3.62, -0.10), Vector3.ZERO, timber_dark, timber_mid)

	# 2. Tall tapered stone chimney flue rising above the roof + stone forge hearth & smoke hood
	_append_cyl(st_body, 0.85, 0.52, 7.6, 4, Vector3(0.0, 3.95, -1.55), Vector3(0.0, PI * 0.25, 0.0), stone_dark, stone_light)
	# Chimney crown cap
	_append_box(st_body, Vector3(1.12, 0.24, 1.12), Vector3(0.0, 7.75, -1.55), Vector3.ZERO, stone_dark, stone_mid)
	# Stone forge hearth counter
	_append_box(st_body, Vector3(2.25, 1.08, 1.65), Vector3(0.0, 0.86, -0.25), Vector3.ZERO, stone_dark, stone_mid)
	# Low raised stone hearth lip around firebed
	_append_box(st_body, Vector3(2.35, 0.24, 0.22), Vector3(0.0, 1.48, 0.50), Vector3.ZERO, stone_mid, stone_light)
	for sx: float in [-1.0, 1.0]:
		_append_box(st_body, Vector3(0.24, 0.28, 1.68), Vector3(sx * 1.05, 1.50, -0.25), Vector3.ZERO, stone_mid, stone_light)
	# Sloped iron/stone chimney hood overhanging hearth
	_append_cyl(st_body, 1.45, 0.62, 1.65, 4, Vector3(0.0, 3.05, -0.58), Vector3(0.0, PI * 0.25, 0.0), iron_dark, stone_mid)

	# 3. Fiery amber glowing forge coals + white-hot steel bar + hanging forge lantern
	var coal_bot := Color.html("#ea580c")
	var coal_top := Color.html("#fef08a")
	var coal_sp := SphereMesh.new()
	coal_sp.radius = 0.62
	coal_sp.height = 0.42
	coal_sp.radial_segments = 8
	coal_sp.rings = 4
	_append_mesh_colored(st_glow, coal_sp, Transform3D(Basis.IDENTITY.scaled(Vector3(1.45, 0.72, 1.05)), Vector3(0.0, 1.42, -0.22)), coal_bot, coal_top, 1.25, 1.62, 0.06, 2.4)
	# Glowing red-hot blade blank resting in coals
	_append_box(st_glow, Vector3(0.88, 0.07, 0.14), Vector3(0.25, 1.54, 0.12), Vector3(0.0, 0.28, 0.08), Color.html("#fb923c"), Color.html("#fef9c3"))
	# Warm hanging smithy lantern on right front post
	_append_box(st_glow, Vector3(0.28, 0.42, 0.28), Vector3(2.32, 2.85, 2.05), Vector3.ZERO, Color.html("#f59e0b"), Color.html("#fef3c7"))
	_append_box(st_body, Vector3(0.36, 0.08, 0.36), Vector3(2.32, 3.08, 2.05), Vector3.ZERO, iron_dark, iron_dark)

	# 4. Sculpted horned iron anvil on heavy wooden chopping stump (left front bay)
	var anvil_p := Vector3(-1.68, 0.35, 1.25)
	_append_cyl(st_body, 0.42, 0.36, 0.72, 8, anvil_p + Vector3(0.0, 0.36, 0.0), Vector3.ZERO, timber_dark, timber_mid)
	# Anvil base & waist
	_append_box(st_body, Vector3(0.62, 0.16, 0.38), anvil_p + Vector3(0.0, 0.78, 0.0), Vector3.ZERO, iron_dark, stone_mid)
	_append_box(st_body, Vector3(0.42, 0.24, 0.26), anvil_p + Vector3(0.0, 0.96, 0.0), Vector3.ZERO, iron_dark, stone_mid)
	# Anvil face + pointed conical bick/horn
	_append_box(st_body, Vector3(0.76, 0.18, 0.32), anvil_p + Vector3(0.04, 1.14, 0.0), Vector3.ZERO, stone_mid, iron_shine)
	_append_cyl_between(st_body, anvil_p + Vector3(-0.32, 1.15, 0.0), anvil_p + Vector3(-0.74, 1.18, 0.0), 0.12, 0.02, 6, iron_dark, iron_shine)

	# 5. Water-quenching wooden barrel with iron hoops (right front bay)
	var bar_p := Vector3(1.65, 0.35, 1.20)
	_append_cyl(st_body, 0.42, 0.46, 0.88, 10, bar_p + Vector3(0.0, 0.44, 0.0), Vector3.ZERO, timber_dark, timber_mid)
	for hy: float in [0.22, 0.68]:
		_append_cyl(st_body, 0.465, 0.465, 0.08, 10, bar_p + Vector3(0.0, hy, 0.0), Vector3.ZERO, iron_dark, iron_shine)
	# Still water surface disk inside barrel
	_append_cyl(st_body, 0.38, 0.38, 0.04, 10, bar_p + Vector3(0.0, 0.84, 0.0), Vector3.ZERO, Color.html("#1e3a5f"), Color.html("#38bdf8"))

	# 6. Katana display rack with 2 forged katanas along right wall
	var rack_p := Vector3(2.15, 0.35, -0.55)
	for rz: float in [-0.55, 0.55]:
		_append_box(st_body, Vector3(0.10, 1.25, 0.12), rack_p + Vector3(0.0, 0.62, rz), Vector3.ZERO, timber_dark, timber_mid)
	_append_box(st_body, Vector3(0.12, 0.10, 1.28), rack_p + Vector3(0.0, 0.22, 0.0), Vector3.ZERO, timber_dark, timber_mid)
	for ky: float in [0.78, 1.12]:
		_append_box(st_body, Vector3(0.04, 0.07, 1.48), rack_p + Vector3(-0.04, ky, 0.0), Vector3.ZERO, iron_shine, Color.html("#e2e8f0"))
		_append_box(st_body, Vector3(0.08, 0.14, 0.06), rack_p + Vector3(-0.04, ky, 0.42), Vector3.ZERO, bronze_col, bronze_col)

	# 7. Sweeping curved charcoal-tiled kirizuma gable roof
	_append_curved_japanese_roof(
		st_roof, st_body, "kirizuma",
		4.15, 3.45, 3.62, 6.05,
		roof_charcoal, timber_dark, stone_light, bronze_col, is_mob
	)

	root.add_child(_make_mesh_inst(st_body.commit(), make_wafuu_mat(3, is_mob, 0.78, 0.08, 0.10)))
	root.add_child(_make_mesh_inst(st_roof.commit(), make_wafuu_mat(2, is_mob, 0.56, 0.12, 0.0)))
	root.add_child(_make_mesh_inst(st_glow.commit(), _make_vcol_glow_mat()))
	content_root.add_child(root)
	return root


static func add_japanese_house(
	arena: Arena3D,
	content_root: Node3D,
	base_pos: Vector3,
	sc: float = 1.0,
	yaw: float = 0.0,
	roof_hex: String = "#1e293b"
) -> Node3D:
	var is_mob: bool = UiStyle.is_mobile_device()
	var root := Node3D.new()
	root.name = "JapaneseHouse"
	root.position = base_pos
	root.rotation.y = yaw
	root.scale = Vector3(sc, sc, sc)

	_register_rotated_obstacle(arena, base_pos, yaw, sc, Vector2(-1.10, 0.0), 1.95, 4.5)
	_register_rotated_obstacle(arena, base_pos, yaw, sc, Vector2(1.10, 0.0), 1.95, 4.5)

	var st_body := SurfaceTool.new()
	st_body.begin(Mesh.PRIMITIVE_TRIANGLES)
	var st_roof := SurfaceTool.new()
	st_roof.begin(Mesh.PRIMITIVE_TRIANGLES)
	var st_glow := SurfaceTool.new()
	st_glow.begin(Mesh.PRIMITIVE_TRIANGLES)

	var stone_dark := Color.html("#334155")
	var stone_light := Color.html("#64748b")
	var wood_dark := Color.html("#2f1d13")
	var wood_cedar := Color.html("#523420")
	var plaster_bot := Color.html("#dcd4c7")
	var plaster_top := Color.html("#f8f4ec")
	var roof_col := Color.html(roof_hex)
	var gold_col := Color.html("#d97706")

	# 1. Stone plinth + white shikkui machiya walls + dark cedar yakisugi wainscoting
	_append_box(st_body, Vector3(5.6, 0.72, 4.4), Vector3(0.0, 0.02, 0.0), Vector3.ZERO, stone_dark, stone_light)
	_append_box(st_body, Vector3(5.2, 3.65, 4.0), Vector3(0.0, 2.20, 0.0), Vector3.ZERO, plaster_bot, plaster_top)
	_append_box(st_body, Vector3(5.32, 1.05, 4.12), Vector3(0.0, 0.92, 0.0), Vector3.ZERO, wood_dark, wood_cedar)

	# 2. Dark cedar timber frame posts & horizontal beams
	for px: float in [-2.62, -0.88, 0.88, 2.62]:
		for pz: float in [-2.02, 2.02]:
			_append_box(st_body, Vector3(0.20, 3.72, 0.20), Vector3(px, 2.24, pz), Vector3.ZERO, wood_dark, wood_cedar)
	_append_box(st_body, Vector3(5.48, 0.18, 4.28), Vector3(0.0, 2.58, 0.0), Vector3.ZERO, wood_dark, wood_cedar)
	_append_box(st_body, Vector3(5.48, 0.20, 4.28), Vector3(0.0, 4.02, 0.0), Vector3.ZERO, wood_dark, wood_cedar)

	# 3. Decorative lower wooden entrance eaves (hisashi) over front facade (+Z)
	_append_box(st_roof, Vector3(5.75, 0.14, 1.15), Vector3(0.0, 2.68, 2.48), Vector3(0.28, 0.0, 0.0), roof_col.darkened(0.22), roof_col)
	for sx: float in [-2.35, 2.35]:
		_append_cyl_between(st_body, Vector3(sx, 2.05, 2.04), Vector3(sx, 2.52, 2.92), 0.06, 0.06, 4, wood_dark, wood_cedar)

	# 4. Warm glowing shoji windows & vertical koshi wooden latticework
	var shoji_bot := Color.html("#f59e0b")
	var shoji_top := Color.html("#fef3c7")
	# Front entrance shoji + left bay window + upper mezzanine windows
	_append_box(st_glow, Vector3(1.52, 1.92, 0.08), Vector3(0.0, 1.48, 2.03), Vector3.ZERO, shoji_bot, shoji_top)
	_append_box(st_glow, Vector3(1.38, 1.12, 0.08), Vector3(-1.74, 1.76, 2.03), Vector3.ZERO, shoji_bot, shoji_top)
	_append_box(st_glow, Vector3(1.38, 1.12, 0.08), Vector3(1.74, 1.76, 2.03), Vector3.ZERO, shoji_bot, shoji_top)
	# Upper floor warm lattice windows
	for ux: float in [-1.55, 0.0, 1.55]:
		_append_box(st_glow, Vector3(1.02, 0.72, 0.08), Vector3(ux, 3.24, 2.03), Vector3.ZERO, shoji_bot, shoji_top)
		_append_box(st_body, Vector3(1.12, 0.07, 0.12), Vector3(ux, 3.60, 2.05), Vector3.ZERO, wood_dark, wood_cedar)
		_append_box(st_body, Vector3(1.12, 0.07, 0.12), Vector3(ux, 2.88, 2.05), Vector3.ZERO, wood_dark, wood_cedar)

	# Vertical koshi slats across front windows
	var k_slats: int = 4 if is_mob else 6
	for wx: float in [-1.74, 1.74]:
		for si: int in range(k_slats):
			var sx_off: float = wx - 0.62 + (float(si) / float(k_slats - 1)) * 1.24
			_append_box(st_body, Vector3(0.055, 1.18, 0.10), Vector3(sx_off, 1.76, 2.06), Vector3.ZERO, wood_dark, wood_cedar)
	# Entrance door mullions
	for mx: float in [-0.74, -0.25, 0.25, 0.74]:
		_append_box(st_body, Vector3(0.055, 1.98, 0.10), Vector3(mx, 1.48, 2.06), Vector3.ZERO, wood_dark, wood_cedar)

	# 5. Sweeping concave Kawara irimoya roof
	_append_curved_japanese_roof(
		st_roof, st_body, "irimoya",
		3.85, 3.15, 4.02, 6.45,
		roof_col, wood_dark, plaster_top, gold_col, is_mob
	)

	root.add_child(_make_mesh_inst(st_body.commit(), make_wafuu_mat(4, is_mob, 0.72, 0.04, 0.0)))
	root.add_child(_make_mesh_inst(st_roof.commit(), make_wafuu_mat(2, is_mob, 0.56, 0.12, 0.0)))
	root.add_child(_make_mesh_inst(st_glow.commit(), _make_vcol_glow_mat()))
	content_root.add_child(root)
	return root


static func add_wagasa_umbrella(content_root: Node3D, base_pos: Vector3) -> Node3D:
	var is_mob: bool = UiStyle.is_mobile_device()
	var root := Node3D.new()
	root.name = "WagasaUmbrella"
	root.position = base_pos

	var st_wood := SurfaceTool.new()
	st_wood.begin(Mesh.PRIMITIVE_TRIANGLES)
	var st_cloth := SurfaceTool.new()
	st_cloth.begin(Mesh.PRIMITIVE_TRIANGLES)

	var bam_dark := Color.html("#4d321c")
	var bam_mid := Color.html("#7c5329")
	var bam_gold := Color.html("#b68d4c")
	var stone_c := Color.html("#475569")
	var red_dark := Color.html("#7f1d1d")
	var red_mid := Color.html("#dc2626")
	var red_bright := Color.html("#ef4444")
	var cup_jade := Color.html("#6ee7b7")

	# 1. Stone umbrella stand + slender bamboo pole with nodal rings
	_append_cyl(st_wood, 0.34, 0.26, 0.32, 8, Vector3(0.0, 0.16, 0.0), Vector3.ZERO, stone_c.darkened(0.25), stone_c)
	_append_cyl(st_wood, 0.068, 0.052, 3.45, 8, Vector3(0.0, 1.72, 0.0), Vector3.ZERO, bam_dark, bam_gold)
	for ny: float in [0.75, 1.45, 2.15, 2.80]:
		_append_cyl(st_wood, 0.080, 0.080, 0.045, 8, Vector3(0.0, ny, 0.0), Vector3.ZERO, bam_gold, bam_gold)

	# 2. Curved ribbed crimson oil-paper canopy (12-16 facets with gentle dome curve) + bamboo ribs
	var spokes: int = 12 if is_mob else 16
	var apex := Vector3(0.0, 3.48, 0.0)
	var r_mid: float = 1.18
	var y_mid: float = 3.24
	var r_out: float = 2.22
	var y_out: float = 2.86

	for si: int in range(spokes):
		var a0: float = (float(si) / float(spokes)) * TAU
		var a1: float = (float(si + 1) / float(spokes)) * TAU
		var am: float = (a0 + a1) * 0.5
		var p_m0 := Vector3(cos(a0) * r_mid, y_mid, sin(a0) * r_mid)
		var p_m1 := Vector3(cos(a1) * r_mid, y_mid, sin(a1) * r_mid)
		var p_o0 := Vector3(cos(a0) * r_out, y_out, sin(a0) * r_out)
		var p_o1 := Vector3(cos(a1) * r_out, y_out, sin(a1) * r_out)

		# Subtle rib shading contrast on alternating facets
		var c_edge: Color = red_mid if si % 2 == 0 else red_mid.darkened(0.10)
		var c_top: Color = red_bright if si % 2 == 0 else red_mid
		_append_tri_colored(st_cloth, apex, p_m1, p_m0, red_dark, c_top, c_top, Vector3(cos(am), 1.8, sin(am)))
		_append_quad_colored(st_cloth, p_m0, p_m1, p_o1, p_o0, c_top, c_top, c_edge, c_edge, Vector3(cos(am), 1.5, sin(am)))
		# Underside canopy face (darker warm crimson glow)
		var c_under: Color = red_dark.lerp(red_mid, 0.35)
		_append_tri_colored(st_cloth, apex - Vector3(0.0, 0.03, 0.0), p_m0 - Vector3(0.0, 0.03, 0.0), p_m1 - Vector3(0.0, 0.03, 0.0), red_dark, c_under, c_under, Vector3.DOWN)
		_append_quad_colored(st_cloth, p_m0 - Vector3(0.0, 0.03, 0.0), p_o0 - Vector3(0.0, 0.03, 0.0), p_o1 - Vector3(0.0, 0.03, 0.0), p_m1 - Vector3(0.0, 0.03, 0.0), c_under, c_under, c_under, c_under, Vector3.DOWN)

		# Bamboo underside spoke (hone) + spreader strut
		_append_cyl_between(st_wood, Vector3(0.0, 3.38, 0.0), p_o0 - Vector3(0.0, 0.04, 0.0), 0.018, 0.014, 4, bam_gold, bam_mid)
		if si % 2 == 0:
			_append_cyl_between(st_wood, Vector3(0.0, 2.82, 0.0), p_m0 - Vector3(0.0, 0.04, 0.0), 0.016, 0.014, 4, bam_mid, bam_gold)

	# Dark lacquer center cap (rokuro) & gold finial tip
	_append_cyl(st_cloth, 0.22, 0.14, 0.12, 8, Vector3(0.0, 3.50, 0.0), Vector3.ZERO, Color.html("#1e1b2e"), Color.html("#334155"))
	_append_cyl(st_cloth, 0.07, 0.03, 0.14, 6, Vector3(0.0, 3.60, 0.0), Vector3.ZERO, Color.html("#ca8a04"), Color.html("#fde047"))

	# 3. Wooden tea bench with draped red cloth runner & lacquered tray + tiny teacups
	var bench_z: float = 0.98
	_append_box(st_wood, Vector3(2.28, 0.10, 0.84), Vector3(0.0, 0.50, bench_z), Vector3.ZERO, bam_dark, bam_mid)
	for lx: float in [-0.94, 0.94]:
		for lz: float in [-0.30, 0.30]:
			_append_box(st_wood, Vector3(0.10, 0.50, 0.10), Vector3(lx, 0.25, bench_z + lz), Vector3.ZERO, bam_dark, bam_mid)
	# Draped red mosen felt cloth runner
	_append_box(st_cloth, Vector3(2.34, 0.04, 0.90), Vector3(0.0, 0.56, bench_z), Vector3.ZERO, red_dark, red_mid)
	for side_z: float in [-1.0, 1.0]:
		_append_box(st_cloth, Vector3(2.34, 0.22, 0.04), Vector3(0.0, 0.45, bench_z + side_z * 0.44), Vector3.ZERO, red_dark, red_mid)
	# Tiny lacquered wooden tray + 2 celadon matcha teacups
	_append_box(st_wood, Vector3(0.46, 0.04, 0.32), Vector3(0.48, 0.60, bench_z), Vector3(0.0, 0.14, 0.0), Color.html("#1f130d"), Color.html("#451a03"))
	_append_cyl(st_cloth, 0.055, 0.070, 0.10, 8, Vector3(0.40, 0.67, bench_z - 0.02), Vector3.ZERO, cup_jade.darkened(0.25), cup_jade)
	_append_cyl(st_cloth, 0.055, 0.070, 0.10, 8, Vector3(0.56, 0.67, bench_z + 0.04), Vector3.ZERO, cup_jade.darkened(0.25), cup_jade)

	root.add_child(_make_mesh_inst(st_wood.commit(), make_wafuu_mat(0, is_mob, 0.68, 0.04, 0.0)))
	root.add_child(_make_mesh_inst(st_cloth.commit(), make_wafuu_mat(4, is_mob, 0.52, 0.04, 0.0)))
	content_root.add_child(root)
	return root


static func add_shrine_pavilion(
	arena: Arena3D,
	content_root: Node3D,
	base_pos: Vector3,
	pillar_hex: String,
	roof_hex: String,
	sc: float = 1.0
) -> Node3D:
	var is_mob: bool = UiStyle.is_mobile_device()
	var pav := Node3D.new()
	pav.name = "ShrinePavilion"
	pav.position = base_pos
	pav.scale = Vector3(sc, sc, sc)

	var st_body := SurfaceTool.new()
	st_body.begin(Mesh.PRIMITIVE_TRIANGLES)
	var st_roof := SurfaceTool.new()
	st_roof.begin(Mesh.PRIMITIVE_TRIANGLES)
	var st_glow := SurfaceTool.new()
	st_glow.begin(Mesh.PRIMITIVE_TRIANGLES)

	var pillar_col := Color.html(pillar_hex)
	var pillar_dark := pillar_col.darkened(0.28)
	var pillar_light := pillar_col.lightened(0.10)
	var roof_col := Color.html(roof_hex)
	var stone_dark := Color.html("#334155")
	var stone_light := Color.html("#64748b")
	var gold_dark := Color.html("#b45309")
	var gold_bright := Color.html("#facc15")
	var wood_dark := Color.html("#3b1f14")
	var plaster_col := Color.html("#f1ece4")

	# 1. Open 4 corner pillars (walkable underneath — only corner pillars registered as obstacles!)
	for ox: float in [-2.6, 2.6]:
		for oz: float in [-2.6, 2.6]:
			# Carved octagonal granite pillar base (soseki)
			_append_cyl(st_body, 0.44, 0.34, 0.42, 8, Vector3(ox, 0.16, oz), Vector3.ZERO, stone_dark, stone_light)
			# Tapered vermilion/timber corner pillar
			_append_cyl(st_body, 0.25, 0.21, 4.45, 8 if is_mob else 10, Vector3(ox, 2.48, oz), Vector3.ZERO, pillar_dark, pillar_light)
			# Stepped decorative bracket capital (tokyo)
			_append_box(st_body, Vector3(0.68, 0.18, 0.68), Vector3(ox, 4.62, oz), Vector3.ZERO, pillar_dark, pillar_col)
			_append_box(st_body, Vector3(0.96, 0.16, 0.96), Vector3(ox, 4.80, oz), Vector3.ZERO, wood_dark, gold_dark)

			arena.obstacles.append({
				"pos": Vector2(base_pos.x + ox * sc, base_pos.z + oz * sc),
				"radius": 0.42 * sc,
				"top_y": base_pos.y + 4.8 * sc,
			})

	# 2. Carved upper tie-beams (kashiranuki) with protruding decorative ends (kibana)
	for oz: float in [-2.6, 2.6]:
		_append_box(st_body, Vector3(6.45, 0.28, 0.26), Vector3(0.0, 4.35, oz), Vector3.ZERO, pillar_dark, pillar_col)
		_append_box(st_body, Vector3(5.85, 0.20, 0.20), Vector3(0.0, 3.85, oz), Vector3.ZERO, pillar_dark, gold_dark)
	for ox: float in [-2.6, 2.6]:
		_append_box(st_body, Vector3(0.26, 0.28, 6.45), Vector3(ox, 4.35, 0.0), Vector3.ZERO, pillar_dark, pillar_col)
		_append_box(st_body, Vector3(0.20, 0.20, 5.85), Vector3(ox, 3.85, 0.0), Vector3.ZERO, pillar_dark, gold_dark)

	# 3. Suspended central golden bronze shrine bell (suzu) + 4 hanging warm corner lanterns
	_append_cyl_between(st_body, Vector3(0.0, 4.85, 0.0), Vector3(0.0, 3.92, 0.0), 0.04, 0.04, 5, gold_dark, gold_bright)
	var bell_sp := SphereMesh.new()
	bell_sp.radius = 0.34
	bell_sp.height = 0.62
	bell_sp.radial_segments = 8
	bell_sp.rings = 5
	_append_mesh_colored(st_body, bell_sp, Transform3D(Basis.IDENTITY, Vector3(0.0, 3.66, 0.0)), gold_dark, gold_bright, 3.35, 3.98)

	var glow_bot := Color.html("#f59e0b")
	var glow_top := Color.html("#fef3c7")
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var lp := Vector3(sx * 3.15, 4.05, sz * 3.15)
			_append_cyl_between(st_body, lp + Vector3(0.0, 0.28, 0.0), lp + Vector3(0.0, 0.72, 0.0), 0.025, 0.025, 4, wood_dark, wood_dark)
			_append_cyl(st_body, 0.22, 0.14, 0.14, 6, lp + Vector3(0.0, 0.28, 0.0), Vector3.ZERO, wood_dark, gold_dark)
			_append_cyl(st_glow, 0.15, 0.15, 0.36, 6, lp, Vector3.ZERO, glow_bot, glow_top)
			_append_cyl(st_body, 0.18, 0.18, 0.06, 6, lp - Vector3(0.0, 0.21, 0.0), Vector3.ZERO, wood_dark, wood_dark)

	# 4. Grand sweeping concave hogyo tiled roof with upturned corners & golden finial
	_append_curved_japanese_roof(
		st_roof, st_body, "hogyo",
		4.35, 4.35, 4.88, 7.25,
		roof_col, wood_dark, plaster_col, gold_bright, is_mob
	)

	pav.add_child(_make_mesh_inst(st_body.commit(), make_wafuu_mat(4, is_mob, 0.48, 0.10, 0.0)))
	pav.add_child(_make_mesh_inst(st_roof.commit(), make_wafuu_mat(2, is_mob, 0.50, 0.14, 0.0)))
	pav.add_child(_make_mesh_inst(st_glow.commit(), _make_vcol_glow_mat()))
	content_root.add_child(pav)
	return pav


static func add_temple_pagoda(arena: Arena3D, content_root: Node3D, base_pos: Vector3) -> Node3D:
	var is_mob: bool = UiStyle.is_mobile_device()
	arena.obstacles.append({"pos": Vector2(base_pos.x, base_pos.z), "radius": 1.85, "top_y": base_pos.y + 9.2})

	var pag := Node3D.new()
	pag.name = "TemplePagoda"
	pag.position = base_pos

	var st_body := SurfaceTool.new()
	st_body.begin(Mesh.PRIMITIVE_TRIANGLES)
	var st_roof := SurfaceTool.new()
	st_roof.begin(Mesh.PRIMITIVE_TRIANGLES)
	var st_glow := SurfaceTool.new()
	st_glow.begin(Mesh.PRIMITIVE_TRIANGLES)

	var stone_dark := Color.html("#334155")
	var stone_light := Color.html("#64748b")
	var verm_dark := Color.html("#7f1d1d")
	var verm_mid := Color.html("#b91c1c")
	var plaster_bot := Color.html("#ddd5c8")
	var plaster_top := Color.html("#f8f5ef")
	var roof_slate := Color.html("#1e293b")
	var gold_dark := Color.html("#ca8a04")
	var gold_bright := Color.html("#fde047")

	# 1. Stepped stone foundation podium (kidan)
	_append_box(st_body, Vector3(4.35, 0.55, 4.35), Vector3(0.0, 0.15, 0.0), Vector3.ZERO, stone_dark, stone_light)
	_append_box(st_body, Vector3(3.65, 0.35, 3.65), Vector3(0.0, 0.55, 0.0), Vector3.ZERO, stone_dark, stone_light)

	# 2. Three tapering pagoda tiers with vermilion pillars, balconies, plaster walls & sweeping roofs
	var cur_y: float = 0.72
	for tier: int in range(3):
		var ts: float = 1.0 - float(tier) * 0.21
		var core_w: float = 2.55 * ts
		var wall_h: float = 2.15 * (1.0 - float(tier) * 0.08)
		var roof_hw: float = 3.25 * ts
		var roof_h: float = 1.38 * (1.0 - float(tier) * 0.07)

		# White shikkui plaster inner walls
		_append_box(st_body, Vector3(core_w, wall_h, core_w), Vector3(0.0, cur_y + wall_h * 0.5, 0.0), Vector3.ZERO, plaster_bot, plaster_top)

		# Vermilion corner pillars & wrap-around balcony rail (koran)
		var p_off: float = core_w * 0.52
		for ox: float in [-p_off, p_off]:
			for oz: float in [-p_off, p_off]:
				_append_box(st_body, Vector3(0.22 * ts, wall_h + 0.12, 0.22 * ts), Vector3(ox, cur_y + wall_h * 0.5, oz), Vector3.ZERO, verm_dark, verm_mid)
		var bal_w: float = core_w + 0.52 * ts
		_append_box(st_body, Vector3(bal_w, 0.12, bal_w), Vector3(0.0, cur_y + 0.10, 0.0), Vector3.ZERO, verm_dark, verm_mid)
		for side: float in [-1.0, 1.0]:
			_append_box(st_body, Vector3(bal_w, 0.10, 0.08), Vector3(0.0, cur_y + 0.42, side * (bal_w * 0.48)), Vector3.ZERO, verm_dark, verm_mid)
			_append_box(st_body, Vector3(0.08, 0.10, bal_w), Vector3(side * (bal_w * 0.48), cur_y + 0.42, 0.0), Vector3.ZERO, verm_dark, verm_mid)

		# Warm glowing shoji lattice windows centered on all 4 faces
		var win_w: float = core_w * 0.42
		var win_h: float = wall_h * 0.46
		var win_y: float = cur_y + wall_h * 0.54
		for side: float in [-1.0, 1.0]:
			_append_box(st_glow, Vector3(win_w, win_h, 0.08), Vector3(0.0, win_y, side * (core_w * 0.50 + 0.02)), Vector3.ZERO, Color.html("#f59e0b"), Color.html("#fef3c7"))
			_append_box(st_glow, Vector3(0.08, win_h, win_w), Vector3(side * (core_w * 0.50 + 0.02), win_y, 0.0), Vector3.ZERO, Color.html("#f59e0b"), Color.html("#fef3c7"))

		# Sweeping concave upturned tiled hogyo roof for this tier
		var eave_y: float = cur_y + wall_h + 0.06
		_append_curved_japanese_roof(
			st_roof, st_body, "hogyo",
			roof_hw, roof_hw, eave_y, eave_y + roof_h,
			roof_slate, verm_dark, plaster_top, gold_bright, is_mob
		)
		cur_y = eave_y + roof_h * 0.62

	# 3. Ornate golden sorin ringed spire crowning the pagoda summit
	var spire_base_y: float = cur_y + 0.58
	_append_cyl(st_body, 0.14, 0.045, 2.75, 8, Vector3(0.0, spire_base_y + 1.35, 0.0), Vector3.ZERO, gold_dark, gold_bright)
	var ring_cnt: int = 5 if is_mob else 7
	for ri: int in range(ring_cnt):
		var ry: float = spire_base_y + 0.45 + float(ri) * (1.45 / float(ring_cnt))
		var rr: float = lerpf(0.28, 0.16, float(ri) / float(ring_cnt))
		_append_cyl(st_body, rr, rr, 0.075, 8, Vector3(0.0, ry, 0.0), Vector3.ZERO, gold_dark, gold_bright)
	# Sacred flame-jewel apex (hoju)
	_append_cyl(st_body, 0.18, 0.02, 0.44, 6, Vector3(0.0, spire_base_y + 2.82, 0.0), Vector3.ZERO, gold_dark, Color.html("#fef9c3"))

	pag.add_child(_make_mesh_inst(st_body.commit(), make_wafuu_mat(4, is_mob, 0.54, 0.10, 0.0)))
	pag.add_child(_make_mesh_inst(st_roof.commit(), make_wafuu_mat(2, is_mob, 0.50, 0.14, 0.0)))
	pag.add_child(_make_mesh_inst(st_glow.commit(), make_glow_mat("#fde68a")))
	content_root.add_child(pag)
	return pag


# ==============================================================================
# 4. AUTHENTIC MYOJIN TORII GATES & BATCHED SENBON TORII
# ==============================================================================

static func _append_curved_kasagi_beam(
	st: SurfaceTool,
	xform: Transform3D,
	half_span: float,
	base_y: float,
	beam_h: float,
	beam_d: float,
	curve_lift: float,
	segs: int,
	bot_col: Color,
	top_col: Color
) -> void:
	## Swept multi-segment concave upturned torii lintel (kasagi / shimaki).
	var hw_top: float = beam_d * 0.58
	var hw_bot: float = beam_d * 0.46
	var hh: float = beam_h * 0.5

	var profiles: Array = []
	for si: int in range(segs + 1):
		var u: float = (float(si) / float(segs)) * 2.0 - 1.0 # -1 .. +1
		var au: float = absf(u)
		var px: float = u * half_span
		var py: float = base_y + curve_lift * pow(au, 2.25)
		var end_flare: float = 1.0 + 0.18 * pow(au, 2.0)
		var p_tl: Vector3 = xform * Vector3(px, py + hh * end_flare, -hw_top)
		var p_tr: Vector3 = xform * Vector3(px, py + hh * end_flare, hw_top)
		var p_br: Vector3 = xform * Vector3(px, py - hh, hw_bot)
		var p_bl: Vector3 = xform * Vector3(px, py - hh, -hw_bot)
		profiles.append([p_tl, p_tr, p_br, p_bl])

	var up_h: Vector3 = (xform.basis * Vector3.UP).normalized()
	var dn_h: Vector3 = -up_h
	var f_h: Vector3 = (xform.basis * Vector3.BACK).normalized()
	var b_h: Vector3 = -f_h

	for si: int in range(segs):
		var a: Array = profiles[si]
		var b: Array = profiles[si + 1]
		# Top, Bottom, Front (+Z), Back (-Z)
		_append_quad_colored(st, a[0], b[0], b[1], a[1], top_col, top_col, top_col, top_col, up_h)
		_append_quad_colored(st, a[3], a[2], b[2], b[3], bot_col, bot_col, bot_col, bot_col, dn_h)
		_append_quad_colored(st, a[1], b[1], b[2], a[2], top_col, top_col, bot_col, bot_col, f_h)
		_append_quad_colored(st, a[0], a[3], b[3], b[0], top_col, bot_col, bot_col, top_col, b_h)

	# End caps (left -X, right +X)
	var left_p: Array = profiles[0]
	var right_p: Array = profiles[segs]
	var l_h: Vector3 = (xform.basis * Vector3.LEFT).normalized()
	var r_h: Vector3 = -l_h
	_append_quad_colored(st, left_p[0], left_p[1], left_p[2], left_p[3], top_col, top_col, bot_col, bot_col, l_h)
	_append_quad_colored(st, right_p[1], right_p[0], right_p[3], right_p[2], top_col, top_col, bot_col, bot_col, r_h)


static func _append_torii_geometry(
	st_red: SurfaceTool,
	st_dark: SurfaceTool,
	xform: Transform3D,
	pillar_col: Color,
	with_shimenawa: bool,
	is_mob: bool
) -> void:
	var red_dark: Color = pillar_col.darkened(0.24)
	var red_mid: Color = pillar_col
	var red_bright: Color = pillar_col.lightened(0.10)
	var stone_dark := Color.html("#0f172a")
	var stone_mid := Color.html("#1e293b")
	var slate_top := Color.html("#334155")
	var gold_col := Color.html("#f59e0b")

	var p_segs: int = 8 if is_mob else 10
	var k_segs: int = 8 if is_mob else 10

	# 1. Black granite nemaki base plinths + slightly inward-sloping tapered vermilion pillars
	for sx: float in [-1.0, 1.0]:
		var bot_p: Vector3 = xform * Vector3(sx * 3.24, -0.20, 0.0)
		var base_top: Vector3 = xform * Vector3(sx * 3.20, 1.05, 0.0)
		var top_p: Vector3 = xform * Vector3(sx * 2.94, 7.12, 0.0)
		_append_cyl_between(st_dark, bot_p, base_top, 0.56, 0.45, p_segs, stone_dark, stone_mid)
		_append_cyl_between(st_red, xform * Vector3(sx * 3.21, 0.85, 0.0), top_p, 0.42, 0.34, p_segs, red_dark, red_bright)
		# Decorative dark collar ring (daiwa) at pillar crown
		_append_cyl_between(st_dark, xform * Vector3(sx * 2.95, 6.72, 0.0), xform * Vector3(sx * 2.94, 6.96, 0.0), 0.41, 0.41, p_segs, stone_dark, slate_top)

	# 2. Lower nuki tie-beam + dark wedges (kusabi) + central gakuzuka strut
	var nuki_bm := BoxMesh.new()
	nuki_bm.size = Vector3(8.15, 0.42, 0.46)
	_append_mesh_colored(st_red, nuki_bm, xform * Transform3D(Basis.IDENTITY, Vector3(0.0, 5.65, 0.0)), red_dark, red_mid, -1.0, 1.0)
	var wedge_bm := BoxMesh.new()
	wedge_bm.size = Vector3(0.92, 0.54, 0.56)
	for sx: float in [-1.0, 1.0]:
		_append_mesh_colored(st_dark, wedge_bm, xform * Transform3D(Basis.IDENTITY, Vector3(sx * 3.00, 5.65, 0.0)), stone_dark, stone_mid)
	var strut_bm := BoxMesh.new()
	strut_bm.size = Vector3(0.46, 1.25, 0.38)
	_append_mesh_colored(st_red, strut_bm, xform * Transform3D(Basis.IDENTITY, Vector3(0.0, 6.32, 0.0)), red_dark, red_bright)

	# 3. Gold-framed black hengaku plaque centered on the gakuzuka strut
	var frame_bm := BoxMesh.new()
	frame_bm.size = Vector3(0.84, 1.08, 0.46)
	_append_mesh_colored(st_dark, frame_bm, xform * Transform3D(Basis.IDENTITY, Vector3(0.0, 6.32, 0.0)), gold_col.darkened(0.25), gold_col)
	var tablet_bm := BoxMesh.new()
	tablet_bm.size = Vector3(0.68, 0.90, 0.50)
	_append_mesh_colored(st_dark, tablet_bm, xform * Transform3D(Basis.IDENTITY, Vector3(0.0, 6.32, 0.0)), stone_dark, stone_mid)

	# 4. Authentic curved concave upturned shimaki (vermilion) + dark slate kasagi top lintel!
	_append_curved_kasagi_beam(st_red, xform, 4.48, 7.02, 0.32, 0.64, 0.52, k_segs, red_dark, red_bright)
	_append_curved_kasagi_beam(st_dark, xform, 4.88, 7.36, 0.40, 0.86, 0.64, k_segs, stone_dark, slate_top)

	# 5. Optional braided shimenawa rope + 3 crisp white zigzag shide streamers
	if with_shimenawa:
		var rope_pts: Array[Vector3] = []
		var rope_rads: Array[float] = []
		var r_segs: int = 8 if is_mob else 12
		for si: int in range(r_segs + 1):
			var u: float = (float(si) / float(r_segs)) * 2.0 - 1.0
			var sag: float = (1.0 - u * u) * 0.44
			var local_p := Vector3(u * 2.86, 5.44 - sag, 0.28)
			rope_pts.append(xform * local_p)
			rope_rads.append(0.11 + (1.0 - absf(u)) * 0.14)
		_append_tapered_tube(st_red, rope_pts, rope_rads, 5, Color.html("#a16207"), Color.html("#eab308"), true)
		var rot_y: float = xform.basis.get_euler().y
		for sx: float in [-1.15, 0.0, 1.15]:
			var u_s: float = sx / 2.86
			var sag_s: float = (1.0 - u_s * u_s) * 0.44
			var sp_world: Vector3 = xform * Vector3(sx, 5.34 - sag_s, 0.36)
			_append_shide_zigzag(st_red, sp_world, rot_y, 1.15, Color.html("#ffffff"), Color.html("#e2e8f0"))


static func add_torii_gate(
	content_root: Node3D,
	base_pos: Vector3,
	pillar_hex: String,
	sc: float = 1.0,
	with_shimenawa: bool = true
) -> Node3D:
	var is_mob: bool = UiStyle.is_mobile_device()
	var torii := Node3D.new()
	torii.name = "MyojinTorii"
	torii.position = base_pos
	torii.scale = Vector3(sc, sc, sc)

	var st_red := SurfaceTool.new()
	st_red.begin(Mesh.PRIMITIVE_TRIANGLES)
	var st_dark := SurfaceTool.new()
	st_dark.begin(Mesh.PRIMITIVE_TRIANGLES)

	_append_torii_geometry(st_red, st_dark, Transform3D.IDENTITY, Color.html(pillar_hex), with_shimenawa, is_mob)

	torii.add_child(_make_mesh_inst(st_red.commit(), make_wafuu_mat(4, is_mob, 0.38, 0.08, 0.0)))
	torii.add_child(_make_mesh_inst(st_dark.commit(), make_wafuu_mat(3, is_mob, 0.56, 0.10, 0.0)))
	content_root.add_child(torii)
	return torii


static func build_senbon_torii(
	content_root: Node3D,
	gate_positions: Array[Vector3],
	pillar_hex: String = "#dc2626"
) -> void:
	if gate_positions.is_empty():
		return
	var is_mob: bool = UiStyle.is_mobile_device()
	var pillar_col := Color.html(pillar_hex)

	var st_red := SurfaceTool.new()
	st_red.begin(Mesh.PRIMITIVE_TRIANGLES)
	var st_dark := SurfaceTool.new()
	st_dark.begin(Mesh.PRIMITIVE_TRIANGLES)

	var count: int = gate_positions.size()
	var gate_sc: float = 0.62
	for i: int in range(count):
		var pos: Vector3 = gate_positions[i]
		var yaw: float = 0.0
		if count >= 2:
			var p_prev: Vector3 = gate_positions[maxi(0, i - 1)]
			var p_next: Vector3 = gate_positions[mini(count - 1, i + 1)]
			var tangent := Vector2(p_next.x - p_prev.x, p_next.z - p_prev.z)
			if tangent.length_squared() > 0.0001:
				yaw = atan2(tangent.x, tangent.y)
		var b := Basis(Vector3.UP, yaw).scaled(Vector3(gate_sc, gate_sc, gate_sc))
		_append_torii_geometry(st_red, st_dark, Transform3D(b, pos), pillar_col, false, is_mob)

	var batch_root := Node3D.new()
	batch_root.name = "SenbonToriiBatch"
	batch_root.add_child(_make_mesh_inst(st_red.commit(), make_wafuu_mat(4, is_mob, 0.40, 0.08, 0.0)))
	batch_root.add_child(_make_mesh_inst(st_dark.commit(), make_wafuu_mat(3, is_mob, 0.58, 0.10, 0.0)))
	content_root.add_child(batch_root)


# ==============================================================================
# 5. CARVED GRANITE KASUGA-DORO STONE LANTERNS
# ==============================================================================

static func make_stone_lantern_meshes(is_mob: bool) -> Dictionary:
	var st_stone := SurfaceTool.new()
	st_stone.begin(Mesh.PRIMITIVE_TRIANGLES)
	var st_glow := SurfaceTool.new()
	st_glow.begin(Mesh.PRIMITIVE_TRIANGLES)

	var gran_dark := Color.html("#475569")
	var gran_mid := Color.html("#64748b")
	var gran_light := Color.html("#94a3b8")

	# 1. Hexagonal stepped stone base (kiso)
	_append_cyl(st_stone, 0.80, 0.72, 0.34, 6, Vector3(0.0, 0.08, 0.0), Vector3.ZERO, gran_dark, gran_mid)
	_append_cyl(st_stone, 0.58, 0.42, 0.24, 6, Vector3(0.0, 0.36, 0.0), Vector3.ZERO, gran_dark, gran_light)

	# 2. Slender tapered octagonal/hexagonal shaft (sao) with carved mid-collar (fushi)
	var shaft_segs: int = 6 if is_mob else 8
	_append_cyl(st_stone, 0.24, 0.20, 1.56, shaft_segs, Vector3(0.0, 1.24, 0.0), Vector3.ZERO, gran_dark, gran_mid)
	_append_cyl(st_stone, 0.27, 0.27, 0.14, shaft_segs, Vector3(0.0, 1.22, 0.0), Vector3.ZERO, gran_mid, gran_light)

	# 3. Flared hexagonal lotus pedestal (chudai)
	_append_cyl(st_stone, 0.22, 0.58, 0.30, 6, Vector3(0.0, 2.16, 0.0), Vector3.ZERO, gran_dark, gran_light)
	_append_cyl(st_stone, 0.62, 0.60, 0.12, 6, Vector3(0.0, 2.36, 0.0), Vector3.ZERO, gran_mid, gran_light)

	# 4. Open 4-corner-mullion stone firebox (hibukuro) framing glowing lantern core
	for sx: float in [-0.33, 0.33]:
		for sz: float in [-0.33, 0.33]:
			_append_box(st_stone, Vector3(0.11, 0.68, 0.11), Vector3(sx, 2.74, sz), Vector3.ZERO, gran_dark, gran_light)
	_append_cyl(st_stone, 0.54, 0.54, 0.10, 6, Vector3(0.0, 3.10, 0.0), Vector3.ZERO, gran_dark, gran_mid)

	# 5. Sweeping flared hexagonal concave stone roof (kasa) with upturned tips (warabite)
	var r_rings: Array[Vector2] = [
		Vector2(0.18, 3.74),
		Vector2(0.48, 3.44),
		Vector2(0.84, 3.22),
		Vector2(1.12, 3.16), # slight upward eave kick!
	]
	for ri: int in range(r_rings.size() - 1):
		var r0: float = r_rings[ri].x
		var y0: float = r_rings[ri].y
		var r1: float = r_rings[ri + 1].x
		var y1: float = r_rings[ri + 1].y
		var c0: Color = gran_light.lerp(gran_dark, float(ri) / 3.0)
		var c1: Color = gran_light.lerp(gran_dark, float(ri + 1) / 3.0)
		for si: int in range(6):
			var a0: float = float(si) * (TAU / 6.0)
			var a1: float = float(si + 1) * (TAU / 6.0)
			var am: float = (a0 + a1) * 0.5
			var v00 := Vector3(cos(a0) * r0, y0, sin(a0) * r0)
			var v01 := Vector3(cos(a1) * r0, y0, sin(a1) * r0)
			var v11 := Vector3(cos(a1) * r1, y1, sin(a1) * r1)
			var v10 := Vector3(cos(a0) * r1, y1, sin(a0) * r1)
			_append_quad_colored(st_stone, v00, v01, v11, v10, c0, c0, c1, c1, Vector3(cos(am), 1.4, sin(am)))
			if ri == r_rings.size() - 2:
				# Thick stone eave rim + underside
				var b0: Vector3 = v10 - Vector3(0.0, 0.14, 0.0)
				var b1: Vector3 = v11 - Vector3(0.0, 0.14, 0.0)
				_append_quad_colored(st_stone, v10, v11, b1, b0, gran_dark, gran_dark, gran_dark.darkened(0.2), gran_dark.darkened(0.2), Vector3(cos(am), 0.0, sin(am)))
				_append_tri_colored(st_stone, Vector3(0.0, 3.06, 0.0), b1, b0, gran_dark, gran_dark, gran_dark, Vector3.DOWN)
				# Upturned corner warabite scroll nubs
				_append_cyl(st_stone, 0.065, 0.05, 0.11, 5, v10 + Vector3(0.0, 0.04, 0.0), Vector3.ZERO, gran_mid, gran_light)

	# 6. Pointed lotus-bud finial (hoju)
	_append_cyl(st_stone, 0.24, 0.16, 0.14, 6, Vector3(0.0, 3.80, 0.0), Vector3.ZERO, gran_mid, gran_light)
	_append_cyl(st_stone, 0.18, 0.02, 0.34, 6, Vector3(0.0, 4.04, 0.0), Vector3.ZERO, gran_mid, gran_light.lightened(0.14))

	# 7. Glowing inner core inside the 4 stone mullions
	_append_cyl(st_glow, 0.27, 0.27, 0.60, 6, Vector3(0.0, 2.74, 0.0), Vector3.ZERO, Color.WHITE, Color.WHITE)

	return {
		"stone": st_stone.commit(),
		"glow": st_glow.commit(),
	}


static func add_stone_lantern(
	content_root: Node3D,
	base_pos: Vector3,
	glow_hex: String
) -> Node3D:
	var is_mob: bool = UiStyle.is_mobile_device()
	var l_cache: Dictionary = _get_scene_cache(content_root, "_wafuu_lantern_cache")
	var cache_key: int = 1 if is_mob else 0
	var meshes: Dictionary
	if l_cache.has(cache_key):
		meshes = l_cache[cache_key] as Dictionary
	else:
		meshes = make_stone_lantern_meshes(is_mob)
		l_cache[cache_key] = meshes
	var lg := Node3D.new()
	lg.name = "KasugaStoneLantern"
	lg.position = base_pos

	lg.add_child(_make_mesh_inst(meshes["stone"] as ArrayMesh, make_wafuu_mat(3, is_mob, 0.80, 0.04, 0.34)))
	lg.add_child(_make_mesh_inst(meshes["glow"] as ArrayMesh, make_glow_mat(glow_hex)))
	content_root.add_child(lg)
	return lg


static func add_batched_stone_lanterns(
	content_root: Node3D,
	positions: Array[Vector3],
	glow_hex: String,
	is_mob: bool
) -> void:
	if positions.is_empty():
		return
	var meshes: Dictionary = make_stone_lantern_meshes(is_mob)
	var count: int = positions.size()

	var mm_stone := MultiMesh.new()
	mm_stone.transform_format = MultiMesh.TRANSFORM_3D
	mm_stone.mesh = meshes["stone"] as ArrayMesh
	mm_stone.instance_count = count

	var mm_glow := MultiMesh.new()
	mm_glow.transform_format = MultiMesh.TRANSFORM_3D
	mm_glow.mesh = meshes["glow"] as ArrayMesh
	mm_glow.instance_count = count

	for i: int in range(count):
		var yaw: float = fmod(float(i) * 1.13, TAU)
		var xf := Transform3D(Basis(Vector3.UP, yaw), positions[i])
		mm_stone.set_instance_transform(i, xf)
		mm_glow.set_instance_transform(i, xf)

	var mmi_stone := MultiMeshInstance3D.new()
	mmi_stone.name = "StoneLanternsBatch"
	mmi_stone.multimesh = mm_stone
	mmi_stone.material_override = make_wafuu_mat(3, is_mob, 0.80, 0.04, 0.34)
	mmi_stone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	content_root.add_child(mmi_stone)

	var mmi_glow := MultiMeshInstance3D.new()
	mmi_glow.name = "StoneLanternGlowsBatch"
	mmi_glow.multimesh = mm_glow
	mmi_glow.material_override = make_glow_mat(glow_hex)
	mmi_glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	content_root.add_child(mmi_glow)


# ==============================================================================
# 6. REALISTIC SEGMENTED BAMBOO STALK MESH (1-DRAW-CALL MULTIMESH READY)
# ==============================================================================

static func _append_lanceolate_leaf(
	st: SurfaceTool,
	stem_pos: Vector3,
	dir: Vector3,
	leaf_len: float,
	leaf_w: float,
	col_base: Color,
	col_tip: Color
) -> void:
	## Delicate pointed double-sided lanceolate bamboo leaf blade arching softly downward.
	var fwd: Vector3 = dir.normalized()
	if fwd.length_squared() < 0.0001:
		fwd = Vector3.RIGHT
	var side: Vector3 = fwd.cross(Vector3.UP)
	if side.length_squared() < 0.0001:
		side = Vector3.FORWARD
	side = side.normalized()
	var up_n: Vector3 = side.cross(fwd).normalized()

	var p_base: Vector3 = stem_pos
	var p_mid_l: Vector3 = stem_pos + fwd * (leaf_len * 0.42) - side * (leaf_w * 0.5) + up_n * (leaf_len * 0.04)
	var p_mid_r: Vector3 = stem_pos + fwd * (leaf_len * 0.42) + side * (leaf_w * 0.5) + up_n * (leaf_len * 0.04)
	var p_tip: Vector3 = stem_pos + fwd * leaf_len - Vector3(0.0, leaf_len * 0.22, 0.0)
	var col_mid: Color = col_base.lerp(col_tip, 0.52)

	# Front (+up_n) and Back (-up_n) faces so leaves are crisp from above & below under cull_back
	_append_tri_colored(st, p_base, p_mid_l, p_mid_r, col_base, col_mid, col_mid, up_n)
	_append_tri_colored(st, p_tip, p_mid_r, p_mid_l, col_tip, col_mid, col_mid, up_n)
	var col_under: Color = col_mid.darkened(0.18)
	_append_tri_colored(st, p_base, p_mid_r, p_mid_l, col_base.darkened(0.18), col_under, col_under, -up_n)
	_append_tri_colored(st, p_tip, p_mid_l, p_mid_r, col_tip.darkened(0.15), col_under, col_under, -up_n)


static func make_realistic_bamboo_mesh(is_mob: bool) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var col_root := Color.html("#2d5a27")
	var col_mid := Color.html("#4d8c3f")
	var col_top := Color.html("#7ab84d")
	var node_cream := Color.html("#dce6be")
	var leaf_base := Color.html("#3a7a2f")
	var leaf_tip := Color.html("#8cd14e")

	var segs: int = 5 if is_mob else 6
	var culm_radial: int = 5 if is_mob else 6
	var total_h: float = 7.45

	var pts: Array[Vector3] = []
	var rads: Array[float] = []
	for i: int in range(segs + 1):
		var t: float = float(i) / float(segs)
		var py: float = lerpf(-0.22, total_h, t)
		var curve_x: float = pow(t, 1.85) * 0.44
		var curve_z: float = sin(t * PI) * 0.14
		pts.append(Vector3(curve_x, py, curve_z))
		rads.append(lerpf(0.118, 0.048, t))

	# 1. Segmented culm + raised pale-cream nodal rings (fushi) at every joint
	for i: int in range(segs):
		var t0: float = float(i) / float(segs)
		var t1: float = float(i + 1) / float(segs)
		var c0: Color = col_root.lerp(col_mid, minf(1.0, t0 * 1.4)) if t0 < 0.5 else col_mid.lerp(col_top, (t0 - 0.5) * 2.0)
		var c1: Color = col_root.lerp(col_mid, minf(1.0, t1 * 1.4)) if t1 < 0.5 else col_mid.lerp(col_top, (t1 - 0.5) * 2.0)
		_append_cyl_between(st, pts[i], pts[i + 1], rads[i], rads[i + 1], culm_radial, c0, c1)

		if i > 0:
			var np: Vector3 = pts[i]
			var tangent: Vector3 = (pts[i + 1] - pts[i - 1]).normalized()
			var nr: float = rads[i] * 1.24
			_append_cyl_between(st, np - tangent * 0.045, np + tangent * 0.045, nr, nr * 0.96, culm_radial, node_cream.darkened(0.14), node_cream)

	# 2. 4-5 graceful slender arching upper twigs bearing delicate pointed lanceolate leaf fans
	var twig_count: int = 4 if is_mob else 5
	var leaves_per_twig: int = 4 if is_mob else 6
	for ti: int in range(twig_count):
		var frac: float = lerpf(0.50, 0.97, float(ti) / float(twig_count - 1))
		var seg_f: float = frac * float(segs)
		var s_idx: int = mini(segs - 1, int(seg_f))
		var anchor: Vector3 = pts[s_idx].lerp(pts[s_idx + 1], seg_f - float(s_idx))

		var az: float = float(ti) * 2.15 + 0.35
		var twig_len: float = lerpf(1.22, 0.88, float(ti) / float(twig_count - 1))
		var dir_xz := Vector3(cos(az), 0.0, sin(az))
		var mid_t: Vector3 = anchor + dir_xz * (twig_len * 0.52) + Vector3(0.0, 0.36, 0.0)
		var tip_t: Vector3 = anchor + dir_xz * twig_len + Vector3(0.0, 0.42, 0.0)
		_append_cyl_between(st, anchor, mid_t, 0.022, 0.015, 4, col_mid, col_top)
		_append_cyl_between(st, mid_t, tip_t, 0.015, 0.008, 4, col_mid, col_top)

		# Fan cluster of slender lanceolate leaves radiating gracefully off the twig
		for li: int in range(leaves_per_twig):
			var u: float = float(li) / float(leaves_per_twig - 1)
			var l_base: Vector3 = mid_t.lerp(tip_t, 0.15 + u * 0.85)
			var spread: float = (u - 0.5) * 1.45 + (0.28 if li % 2 == 0 else -0.28)
			var la: float = az + spread
			var l_dir := Vector3(cos(la), 0.12 - 0.24 * absf(u - 0.5), sin(la)).normalized()
			var l_len: float = 0.54 + 0.18 * sin(float(ti * 7 + li) * 1.6)
			var l_w: float = 0.13 + 0.03 * cos(float(li) * 2.1)
			_append_lanceolate_leaf(st, l_base, l_dir, l_len, l_w, leaf_base, leaf_tip)

	return st.commit()


# ==============================================================================
# 7. SUPPORTING PROPS (MOSSY BOULDER, JIZO SHRINE, ORNATE BRIDGE, BYAKKO, MONOLITH)
# ==============================================================================

static func add_mossy_boulder(
	arena: Arena3D,
	content_root: Node3D,
	base_pos: Vector3,
	rad: float
) -> Node3D:
	var is_mob: bool = UiStyle.is_mobile_device()
	arena.obstacles.append({"pos": Vector2(base_pos.x, base_pos.z), "radius": rad, "top_y": base_pos.y + rad * 1.25})

	var root := Node3D.new()
	root.name = "MossyBoulder"
	root.position = base_pos

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var rock_bot := Color.html("#374139")
	var rock_top := Color.html("#8b9487")
	var seed_f: float = base_pos.x * 0.37 + base_pos.z * 0.71

	var sp := SphereMesh.new()
	sp.radius = 1.0
	sp.height = 2.0
	sp.radial_segments = 7 if is_mob else 9
	sp.rings = 4 if is_mob else 5

	# Primary craggy boulder (slightly flattened base, organic faceted silhouette)
	var main_b := Basis(Vector3.UP, fmod(seed_f, TAU)).scaled(Vector3(rad * 1.04, rad * 0.78, rad * 0.94))
	_append_mesh_colored(st, sp, Transform3D(main_b, Vector3(0.0, rad * 0.50, 0.0)), rock_bot, rock_top, 0.0, rad * 1.35, 0.22, seed_f)

	# 2-3 nested companion accent rocks inside obstacle footprint
	var sub_cnt: int = 2 if is_mob else 3
	for si: int in range(sub_cnt):
		var a: float = seed_f + float(si) * (TAU / float(sub_cnt)) + 0.6
		var s_rad: float = rad * (0.48 - float(si) * 0.07)
		var off := Vector3(cos(a) * rad * 0.56, s_rad * 0.42, sin(a) * rad * 0.56)
		var sb := Basis(Vector3.UP, a * 1.4).scaled(Vector3(s_rad * 1.15, s_rad * 0.72, s_rad * 0.92))
		_append_mesh_colored(st, sp, Transform3D(sb, off), rock_bot.darkened(0.12), rock_top.darkened(0.08), 0.0, rad * 0.95, 0.24, seed_f + float(si) * 3.1)

	root.add_child(_make_mesh_inst(st.commit(), make_wafuu_mat(3, is_mob, 0.86, 0.02, 0.85)))
	content_root.add_child(root)
	return root


static func add_jizo_shrine(
	arena: Arena3D,
	content_root: Node3D,
	base_pos: Vector3
) -> Node3D:
	var is_mob: bool = UiStyle.is_mobile_device()
	arena.obstacles.append({"pos": Vector2(base_pos.x, base_pos.z), "radius": 1.05, "top_y": base_pos.y + 2.85})

	var root := Node3D.new()
	root.name = "JizoShrine"
	root.position = base_pos

	var st_stone := SurfaceTool.new()
	st_stone.begin(Mesh.PRIMITIVE_TRIANGLES)
	var st_wood := SurfaceTool.new()
	st_wood.begin(Mesh.PRIMITIVE_TRIANGLES)
	var st_roof := SurfaceTool.new()
	st_roof.begin(Mesh.PRIMITIVE_TRIANGLES)

	var gran_dark := Color.html("#4b5563")
	var gran_mid := Color.html("#6b7280")
	var gran_light := Color.html("#9ca3af")
	var wood_dark := Color.html("#3a2214")
	var wood_mid := Color.html("#633d24")
	var red_dark := Color.html("#991b1b")
	var red_bright := Color.html("#ef4444")
	var roof_col := Color.html("#273449")
	var gold_col := Color.html("#d97706")

	# 1. Stepped stone podium + carved lotus base + sculpted Jizo statue
	_append_box(st_stone, Vector3(1.88, 0.42, 1.56), Vector3(0.0, 0.16, 0.0), Vector3.ZERO, gran_dark, gran_mid)
	_append_cyl(st_stone, 0.56, 0.44, 0.24, 8, Vector3(0.0, 0.48, 0.0), Vector3.ZERO, gran_dark, gran_light)
	# Robed Jizo torso & shoulders
	_append_cyl(st_stone, 0.40, 0.28, 1.05, 8, Vector3(0.0, 1.10, 0.0), Vector3.ZERO, gran_dark, gran_light)
	# Folded prayer hands (gassho)
	_append_box(st_stone, Vector3(0.24, 0.26, 0.20), Vector3(0.0, 1.24, 0.26), Vector3(0.18, 0.0, 0.0), gran_mid, gran_light)
	# Serene rounded head + carved stone mandorla halo behind head
	var head_sp := SphereMesh.new()
	head_sp.radius = 0.28
	head_sp.height = 0.58
	head_sp.radial_segments = 8
	head_sp.rings = 5
	_append_mesh_colored(st_stone, head_sp, Transform3D(Basis.IDENTITY, Vector3(0.0, 1.82, 0.02)), gran_mid, gran_light, 1.54, 2.12)
	_append_cyl(st_stone, 0.42, 0.42, 0.08, 10, Vector3(0.0, 1.80, -0.18), Vector3(PI * 0.5, 0.0, 0.0), gran_dark, gran_light)
	# Small smooth offering pebbles at the foot of Jizo
	var peb_sp := SphereMesh.new()
	peb_sp.radius = 0.10
	peb_sp.height = 0.12
	peb_sp.radial_segments = 6
	peb_sp.rings = 4
	_append_mesh_colored(st_stone, peb_sp, Transform3D(Basis.IDENTITY, Vector3(-0.46, 0.42, 0.48)), gran_mid, gran_light)
	_append_mesh_colored(st_stone, peb_sp, Transform3D(Basis.IDENTITY.scaled(Vector3(0.8, 0.8, 0.8)), Vector3(0.48, 0.40, 0.44)), gran_dark, gran_mid)

	# 2. Iconic red cloth bib (yodarekake) + small knitted red cap (zukin)
	_append_tri_colored(
		st_wood,
		Vector3(-0.32, 1.54, 0.22),
		Vector3(0.32, 1.54, 0.22),
		Vector3(0.0, 1.06, 0.40),
		red_bright, red_bright, red_dark,
		Vector3(0.0, 0.2, 1.0)
	)
	_append_box(st_wood, Vector3(0.46, 0.22, 0.22), Vector3(0.0, 1.48, 0.22), Vector3(0.18, 0.0, 0.0), red_dark, red_bright)
	var cap_sp := SphereMesh.new()
	cap_sp.radius = 0.295
	cap_sp.height = 0.34
	cap_sp.radial_segments = 8
	cap_sp.rings = 4
	_append_mesh_colored(st_wood, cap_sp, Transform3D(Basis.IDENTITY, Vector3(0.0, 1.98, 0.01)), red_dark, red_bright, 1.84, 2.16)

	# 3. Miniature 4-post wooden hokora shelter frame
	for ox: float in [-0.78, 0.78]:
		for oz: float in [-0.62, 0.62]:
			_append_box(st_wood, Vector3(0.12, 2.12, 0.12), Vector3(ox, 1.40, oz), Vector3.ZERO, wood_dark, wood_mid)
	# Back wooden screen & side lower rails
	_append_box(st_wood, Vector3(1.52, 1.68, 0.08), Vector3(0.0, 1.24, -0.62), Vector3.ZERO, wood_dark, wood_mid)
	for ox: float in [-0.78, 0.78]:
		_append_box(st_wood, Vector3(0.08, 0.10, 1.24), Vector3(ox, 0.88, 0.0), Vector3.ZERO, wood_dark, wood_mid)
		_append_box(st_wood, Vector3(0.12, 0.12, 1.38), Vector3(ox, 2.40, 0.0), Vector3.ZERO, wood_dark, wood_mid)
	for oz: float in [-0.62, 0.62]:
		_append_box(st_wood, Vector3(1.72, 0.12, 0.12), Vector3(0.0, 2.40, oz), Vector3.ZERO, wood_dark, wood_mid)

	# 4. Miniature sweeping curved Kawara tiled kirizuma roof
	_append_curved_japanese_roof(
		st_roof, st_wood, "kirizuma",
		1.28, 1.06, 2.46, 3.22,
		roof_col, wood_dark, Color.html("#e5dfd4"), gold_col, is_mob
	)

	root.add_child(_make_mesh_inst(st_stone.commit(), make_wafuu_mat(3, is_mob, 0.84, 0.02, 0.42)))
	root.add_child(_make_mesh_inst(st_wood.commit(), make_wafuu_mat(4, is_mob, 0.62, 0.04, 0.0)))
	root.add_child(_make_mesh_inst(st_roof.commit(), make_wafuu_mat(2, is_mob, 0.56, 0.10, 0.0)))
	content_root.add_child(root)
	return root


static func add_ornate_bridge(
	arena: Arena3D,
	content_root: Node3D,
	prop_shader: Shader,
	start_p: Vector3,
	end_p: Vector3,
	width: float,
	arch: float,
	deck_hex: String,
	deck_dark_hex: String,
	rail_hex: String,
	surface_type: int = 0
) -> Node3D:
	var is_mob: bool = UiStyle.is_mobile_device()
	arena.bridges.append({"start": start_p, "end": end_p, "width": width, "arch": arch})

	var deck_mat: Material
	if prop_shader != null:
		var sm := ShaderMaterial.new()
		sm.shader = prop_shader
		sm.set_shader_parameter("surface_type", surface_type)
		sm.set_shader_parameter("albedo_a", Color.html(deck_hex))
		sm.set_shader_parameter("albedo_b", Color.html(deck_dark_hex))
		sm.set_shader_parameter("accent_color", Color.html(rail_hex))
		sm.set_shader_parameter("roughness_val", 0.62 if surface_type == 0 else 0.34)
		sm.set_shader_parameter("metallic_val", 0.08 if surface_type == 0 else 0.38)
		sm.set_shader_parameter("emission_strength", 0.25 if surface_type == 2 else 0.0)
		sm.set_shader_parameter("tile_scale", width * 0.55)
		deck_mat = sm
	else:
		deck_mat = make_wafuu_mat(0, is_mob, 0.66, 0.04, 0.0)

	var rail_col := Color.html(rail_hex)
	var rail_dark := rail_col.darkened(0.24)
	var rail_bright := rail_col.lightened(0.10)
	var gold_dark := Color.html("#b45309")
	var gold_bright := Color.html("#fde047")
	var stone_dark := Color.html("#334155")
	var stone_light := Color.html("#64748b")
	var deck_col := Color.html(deck_hex)

	var dir3: Vector3 = end_p - start_p
	var total_len: float = Vector2(dir3.x, dir3.z).length()
	var dy_total: float = end_p.y - start_p.y
	var yaw: float = atan2(dir3.x, dir3.z)

	var segs: int = 8 if is_mob else 10
	var seg_len: float = (total_len / float(segs)) * 1.07
	var plank_box := BoxMesh.new()
	plank_box.size = Vector3(width, 0.26, seg_len)
	var curb_box := BoxMesh.new()
	curb_box.size = Vector3(0.24, 0.34, seg_len)
	var top_rail_box := BoxMesh.new()
	top_rail_box.size = Vector3(0.18, 0.14, seg_len)
	var low_rail_box := BoxMesh.new()
	low_rail_box.size = Vector3(0.12, 0.10, seg_len)

	var st_deck := SurfaceTool.new()
	st_deck.begin(Mesh.PRIMITIVE_TRIANGLES)
	var st_rails := SurfaceTool.new()
	st_rails.begin(Mesh.PRIMITIVE_TRIANGLES)
	var st_stone := SurfaceTool.new()
	st_stone.begin(Mesh.PRIMITIVE_TRIANGLES)

	var onion_sp := SphereMesh.new()
	onion_sp.radius = 0.17
	onion_sp.height = 0.30
	onion_sp.radial_segments = 8
	onion_sp.rings = 4

	for i: int in range(segs):
		var t0: float = float(i) / float(segs)
		var t1: float = float(i + 1) / float(segs)
		var z0: float = t0 * total_len
		var z1: float = t1 * total_len
		var y0: float = dy_total * t0 + sin(t0 * PI) * arch
		var y1: float = dy_total * t1 + sin(t1 * PI) * arch
		var zm: float = (z0 + z1) * 0.5
		var ym: float = (y0 + y1) * 0.5
		var pitch: float = -atan2(y1 - y0, maxf(0.001, z1 - z0))
		var tilt_b := Basis(Vector3.RIGHT, pitch)

		_append_mesh_colored(st_deck, plank_box, Transform3D(tilt_b, Vector3(0.0, ym - 0.13, zm)), deck_col)
		for side: float in [-1.0, 1.0]:
			var sx: float = side * (width * 0.48)
			# Side stringer beam + double horizontal taiko-bashi rails
			_append_mesh_colored(st_rails, curb_box, Transform3D(tilt_b, Vector3(sx, ym - 0.04, zm)), rail_dark, rail_col)
			_append_mesh_colored(st_rails, top_rail_box, Transform3D(tilt_b, Vector3(sx, ym + 0.86, zm)), rail_dark, rail_bright)
			_append_mesh_colored(st_rails, low_rail_box, Transform3D(tilt_b, Vector3(sx, ym + 0.46, zm)), rail_dark, rail_col)

	# Balustrade posts + golden bronze giboshi onion finials at regular intervals & both ends
	var post_step: int = 2
	for i: int in range(0, segs + 1, post_step):
		var t: float = float(i) / float(segs)
		var pz: float = t * total_len
		var py: float = dy_total * t + sin(t * PI) * arch
		var is_end: bool = i == 0 or i == segs
		var pw: float = 0.28 if is_end else 0.21
		var ph: float = 1.12 if is_end else 0.98
		for side: float in [-1.0, 1.0]:
			var sx: float = side * (width * 0.48)
			_append_box(st_rails, Vector3(pw, ph, pw), Vector3(sx, py + ph * 0.5 - 0.06, pz), Vector3.ZERO, rail_dark, rail_bright)
			# Golden bronze giboshi finial: neck collar + bulbous onion dome + pointed bud tip
			var gy: float = py + ph - 0.04
			var gs: float = 1.18 if is_end else 0.92
			_append_cyl(st_rails, 0.13 * gs, 0.15 * gs, 0.10 * gs, 8, Vector3(sx, gy + 0.04 * gs, pz), Vector3.ZERO, gold_dark, gold_bright)
			_append_mesh_colored(st_rails, onion_sp, Transform3D(Basis.IDENTITY.scaled(Vector3(gs, gs, gs)), Vector3(sx, gy + 0.18 * gs, pz)), gold_dark, gold_bright, gy, gy + 0.34 * gs)
			_append_cyl(st_rails, 0.09 * gs, 0.015 * gs, 0.16 * gs, 6, Vector3(sx, gy + 0.36 * gs, pz), Vector3.ZERO, gold_dark, Color.html("#fef9c3"))

	# Carved granite abutment piers & bank wing-walls at both bridge ends
	for end_i: int in range(2):
		var ez: float = 0.0 if end_i == 0 else total_len
		var ey: float = 0.0 if end_i == 0 else dy_total
		var dir_out: float = -1.0 if end_i == 0 else 1.0
		_append_box(st_stone, Vector3(width + 0.95, 1.65, 1.35), Vector3(0.0, ey - 0.92, ez + dir_out * 0.35), Vector3.ZERO, stone_dark, stone_light)
		for side: float in [-1.0, 1.0]:
			var wx: float = side * (width * 0.52 + 0.25)
			_append_box(st_stone, Vector3(0.55, 1.25, 1.15), Vector3(wx, ey - 0.32, ez + dir_out * 0.30), Vector3.ZERO, stone_dark, stone_light)

	var bridge_root := Node3D.new()
	bridge_root.name = "OrnateJapaneseBridge"
	bridge_root.position = start_p
	bridge_root.rotation.y = yaw

	bridge_root.add_child(_make_mesh_inst(st_deck.commit(), deck_mat))
	bridge_root.add_child(_make_mesh_inst(st_rails.commit(), make_wafuu_mat(4, is_mob, 0.40, 0.18, 0.0)))
	bridge_root.add_child(_make_mesh_inst(st_stone.commit(), make_wafuu_mat(3, is_mob, 0.82, 0.04, 0.30)))
	content_root.add_child(bridge_root)
	return bridge_root


static func add_byakko_alcove(
	arena: Arena3D,
	content_root: Node3D,
	npc_pos: Vector3,
	get_height_cb: Callable
) -> Node3D:
	var is_mob: bool = UiStyle.is_mobile_device()
	var stele_z: float = npc_pos.z - 2.6
	var stele_y: float = float(get_height_cb.call(npc_pos.x, stele_z))
	var stele_pos := Vector3(npc_pos.x, stele_y, stele_z)
	arena.obstacles.append({"pos": Vector2(stele_pos.x, stele_pos.z), "radius": 1.35, "top_y": stele_pos.y + 3.8})

	var root := Node3D.new()
	root.name = "ByakkoAlcove"
	root.position = stele_pos

	var st_stone := SurfaceTool.new()
	st_stone.begin(Mesh.PRIMITIVE_TRIANGLES)
	var st_roof := SurfaceTool.new()
	st_roof.begin(Mesh.PRIMITIVE_TRIANGLES)
	var st_glow := SurfaceTool.new()
	st_glow.begin(Mesh.PRIMITIVE_TRIANGLES)

	var slate_dark := Color.html("#1e293b")
	var slate_mid := Color.html("#334155")
	var slate_light := Color.html("#64748b")
	var roof_col := Color.html("#0f172a")
	var ice_gold := Color.html("#bae6fd")

	# 1. Stepped carved shrine dais + imposing Byakko stone stele + flanking wing walls
	_append_box(st_stone, Vector3(4.15, 0.48, 1.85), Vector3(0.0, 0.18, 0.0), Vector3.ZERO, slate_dark, slate_mid)
	_append_box(st_stone, Vector3(3.35, 0.30, 1.35), Vector3(0.0, 0.54, 0.0), Vector3.ZERO, slate_mid, slate_light)
	_append_box(st_stone, Vector3(2.45, 3.05, 0.62), Vector3(0.0, 2.15, 0.0), Vector3.ZERO, slate_dark, slate_light)
	# Carved side stone pillars & low wing walls
	for sx: float in [-1.0, 1.0]:
		_append_box(st_stone, Vector3(0.36, 3.25, 0.78), Vector3(sx * 1.38, 2.20, 0.05), Vector3.ZERO, slate_dark, slate_mid)
		_append_box(st_stone, Vector3(1.10, 1.15, 0.44), Vector3(sx * 2.02, 0.96, 0.25), Vector3(0.0, -sx * 0.22, 0.0), slate_dark, slate_light)

	# 2. Sweeping curved dark-slate shrine canopy roof crowning the stele
	_append_curved_japanese_roof(
		st_roof, st_stone, "kirizuma",
		2.38, 1.32, 3.68, 4.68,
		roof_col, slate_dark, slate_light, ice_gold, is_mob
	)

	# 3. Luminous celestial White-Tiger (Byakko) spirit seal & flanking rune bars
	_append_box(st_glow, Vector3(0.84, 1.28, 0.08), Vector3(0.0, 2.18, 0.34), Vector3.ZERO, Color.html("#7dd3fc"), Color.html("#f0f9ff"))
	_append_box(st_glow, Vector3(0.46, 0.46, 0.10), Vector3(0.0, 2.18, 0.36), Vector3(0.0, 0.0, PI * 0.25), Color.html("#e0f2fe"), Color.html("#ffffff"))
	for sx: float in [-0.74, 0.74]:
		_append_box(st_glow, Vector3(0.12, 1.75, 0.08), Vector3(sx, 2.15, 0.34), Vector3.ZERO, Color.html("#38bdf8"), Color.html("#e0f2fe"))

	root.add_child(_make_mesh_inst(st_stone.commit(), make_wafuu_mat(3, is_mob, 0.74, 0.08, 0.32)))
	root.add_child(_make_mesh_inst(st_roof.commit(), make_wafuu_mat(2, is_mob, 0.52, 0.14, 0.0)))
	root.add_child(_make_mesh_inst(st_glow.commit(), _make_vcol_glow_mat()))
	content_root.add_child(root)

	# 4. Pair of carved Kasuga-doro stone lanterns flanking the alcove
	for sx: float in [-2.6, 2.6]:
		var lx: float = npc_pos.x + sx
		var lz: float = npc_pos.z - 1.6
		var ly: float = float(get_height_cb.call(lx, lz))
		add_stone_lantern(content_root, Vector3(lx, ly, lz), "#bae6fd")

	return root


static func add_kotodama_monolith(
	arena: Arena3D,
	content_root: Node3D,
	base_pos: Vector3,
	sky_anim_nodes: Array[Dictionary],
	is_mob: bool
) -> Node3D:
	arena.obstacles.append({"pos": Vector2(base_pos.x, base_pos.z), "radius": 1.75, "top_y": base_pos.y + 7.8})

	var root := Node3D.new()
	root.name = "KotodamaMonolith"
	root.position = base_pos

	var st_body := SurfaceTool.new()
	st_body.begin(Mesh.PRIMITIVE_TRIANGLES)
	var st_runes := SurfaceTool.new()
	st_runes.begin(Mesh.PRIMITIVE_TRIANGLES)

	var obs_dark := Color.html("#131022")
	var obs_mid := Color.html("#251f3d")
	var obs_light := Color.html("#43386b")
	var rune_bot := Color.html("#db2777")
	var rune_top := Color.html("#fbcfe8")

	# 1. Three-tier stepped hexagonal obsidian shrine dais + 6 outer ward stones
	_append_cyl(st_body, 3.05, 2.75, 0.56, 6, Vector3(0.0, 0.24, 0.0), Vector3.ZERO, obs_dark, obs_mid)
	_append_cyl(st_body, 2.28, 2.02, 0.52, 6, Vector3(0.0, 0.76, 0.0), Vector3.ZERO, obs_dark, obs_light)
	_append_cyl(st_body, 1.56, 1.38, 0.36, 6, Vector3(0.0, 1.18, 0.0), Vector3.ZERO, obs_mid, obs_light)
	for wi: int in range(6):
		var wa: float = float(wi) * (TAU / 6.0) + PI / 6.0
		_append_cyl(st_body, 0.22, 0.10, 0.92, 6, Vector3(cos(wa) * 2.52, 0.72, sin(wa) * 2.52), Vector3(0.0, wa, 0.0), obs_dark, obs_light)

	# 2. Sculpted tapered hexagonal Kotodama obelisk + floating capstone crystal
	_append_cyl(st_body, 1.18, 0.44, 5.55, 6, Vector3(0.0, 4.02, 0.0), Vector3.ZERO, obs_dark, obs_light)
	_append_cyl(st_body, 0.44, 0.08, 0.88, 6, Vector3(0.0, 7.22, 0.0), Vector3.ZERO, obs_mid, obs_light.lightened(0.18))
	# Floating carved capstone shard above obelisk
	_append_cyl(st_body, 0.28, 0.02, 0.62, 6, Vector3(0.0, 8.15, 0.0), Vector3.ZERO, obs_mid, obs_light.lightened(0.22))
	_append_cyl(st_body, 0.02, 0.28, 0.36, 6, Vector3(0.0, 7.66, 0.0), Vector3.ZERO, obs_dark, obs_mid)

	# 3. Glowing Kotodama spirit rune inlays along obelisk faces + luminous apex gem
	var strip_cnt: int = 3 if is_mob else 6
	for ri: int in range(strip_cnt):
		var a: float = float(ri) * (TAU / float(strip_cnt))
		var r_off: float = 0.84
		_append_box(st_runes, Vector3(0.18, 4.35, 0.10), Vector3(sin(a) * r_off, 4.05, cos(a) * r_off), Vector3(0.0, a, 0.0), rune_bot, rune_top)
		_append_box(st_runes, Vector3(0.32, 0.24, 0.12), Vector3(sin(a) * 0.92, 2.35, cos(a) * 0.92), Vector3(0.0, a, 0.0), rune_bot, rune_top)
	var gem_sp := SphereMesh.new()
	gem_sp.radius = 0.24
	gem_sp.height = 0.54
	gem_sp.radial_segments = 6
	gem_sp.rings = 4
	_append_mesh_colored(st_runes, gem_sp, Transform3D(Basis.IDENTITY, Vector3(0.0, 7.82, 0.0)), rune_bot, Color.html("#ffffff"), 7.55, 8.10)

	root.add_child(_make_mesh_inst(st_body.commit(), make_wafuu_mat(3, is_mob, 0.46, 0.24, 0.14)))
	root.add_child(_make_mesh_inst(st_runes.commit(), _make_vcol_glow_mat()))

	# 4. Rotating sacred Kotodama halo rings registered in sky_anim_nodes
	var aura_mat: StandardMaterial3D = make_glow_mat("#e05cf5", 0.84)
	var halo_outer := _make_halo_ring(1.85, 2.22, aura_mat, 5.45, is_mob)
	root.add_child(halo_outer)
	sky_anim_nodes.append({"node": halo_outer, "kind": "spin", "speed": 1.35})

	var inner_mat: StandardMaterial3D = make_glow_mat("#fbcfe8", 0.78)
	var halo_inner := _make_halo_ring(1.22, 1.42, inner_mat, 6.45, is_mob)
	halo_inner.rotation.z = 0.32
	root.add_child(halo_inner)
	sky_anim_nodes.append({"node": halo_inner, "kind": "spin", "speed": -0.95})

	content_root.add_child(root)
	return root


static func _make_halo_ring(
	inner_r: float,
	outer_r: float,
	mat: Material,
	y_pos: float,
	is_mob: bool
) -> MeshInstance3D:
	var torus := TorusMesh.new()
	torus.inner_radius = inner_r
	torus.outer_radius = outer_r
	torus.rings = 24 if is_mob else 36
	torus.ring_segments = 6
	var inst := MeshInstance3D.new()
	inst.mesh = torus
	inst.material_override = mat
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	inst.position = Vector3(0.0, y_pos, 0.0)
	inst.scale = Vector3(1.0, 0.08, 1.0)
	return inst
