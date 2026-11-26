class_name ArpgNatureProps
extends RefCounted

## High-craft procedural Japanese botanical, lake, and coastal sandy beach props
## for Godot 4.3 (GL Compatibility / WebGL2).
## All foliage meshes encode root-to-tip height cleanly in UV.y (0.0 = ground root,
## 1.0 = top tip) and per-vertex COLOR gradients for `foliage_wind_interactive.gdshader`
## and `wafuu_prop.gdshader`, with shadows disabled and ultra-low draw calls.


# ==============================================================================
#  INTERNAL SURFACE TOOL HELPERS (OUTWARD CW WINDING + UV + VERTEX COLOR)
# ==============================================================================

static func _emit_tri_uv(
	st: SurfaceTool,
	v0: Vector3, v1: Vector3, v2: Vector3,
	n0: Vector3, n1: Vector3, n2: Vector3,
	uv0: Vector2, uv1: Vector2, uv2: Vector2,
	c0: Color, c1: Color, c2: Color
) -> void:
	st.set_normal(n0); st.set_uv(uv0); st.set_color(c0); st.add_vertex(v0)
	st.set_normal(n1); st.set_uv(uv1); st.set_color(c1); st.add_vertex(v1)
	st.set_normal(n2); st.set_uv(uv2); st.set_color(c2); st.add_vertex(v2)


static func _append_tri_colored(
	st: SurfaceTool,
	v0: Vector3, v1: Vector3, v2: Vector3,
	c0: Color, c1: Color, c2: Color,
	outward_hint: Vector3,
	uv0: Vector2 = Vector2.ZERO,
	uv1: Vector2 = Vector2.ZERO,
	uv2: Vector2 = Vector2.ZERO
) -> void:
	# Godot 4 CW front face: outward normal is (v2 - v0).cross(v1 - v0).
	var n: Vector3 = (v2 - v0).cross(v1 - v0)
	if n.length_squared() < 0.0000001:
		return
	if n.dot(outward_hint) < 0.0:
		var tv: Vector3 = v1; v1 = v2; v2 = tv
		var tc: Color = c1; c1 = c2; c2 = tc
		var tuv: Vector2 = uv1; uv1 = uv2; uv2 = tuv
		n = -n
	n = n.normalized()
	st.set_normal(n); st.set_uv(uv0); st.set_color(c0); st.add_vertex(v0)
	st.set_normal(n); st.set_uv(uv1); st.set_color(c1); st.add_vertex(v1)
	st.set_normal(n); st.set_uv(uv2); st.set_color(c2); st.add_vertex(v2)


static func _append_quad_colored(
	st: SurfaceTool,
	v0: Vector3, v1: Vector3, v2: Vector3, v3: Vector3,
	c0: Color, c1: Color, c2: Color, c3: Color,
	outward_hint: Vector3,
	uv0: Vector2 = Vector2.ZERO,
	uv1: Vector2 = Vector2.ZERO,
	uv2: Vector2 = Vector2.ZERO,
	uv3: Vector2 = Vector2.ZERO
) -> void:
	_append_tri_colored(st, v0, v1, v2, c0, c1, c2, outward_hint, uv0, uv1, uv2)
	_append_tri_colored(st, v0, v2, v3, c0, c2, c3, outward_hint, uv0, uv2, uv3)


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
	var x_verts := PackedVector3Array(); x_verts.resize(vcount)
	var x_norms := PackedVector3Array(); x_norms.resize(vcount)
	var x_cols := PackedColorArray(); x_cols.resize(vcount)

	for i: int in range(vcount):
		var lv: Vector3 = raw_verts[i]
		var ln: Vector3 = raw_norms[i] if i < raw_norms.size() else Vector3.UP
		if has_noise:
			var np: Vector3 = lv * 2.2 + Vector3(noise_seed, noise_seed * 1.41, noise_seed * 0.83)
			var disp: float = (
				sin(np.x * 2.4 + np.y * 1.8) * cos(np.z * 2.2 - np.x * 1.3) * 0.65
				+ sin(np.y * 3.7 + np.z * 2.8 + noise_seed) * 0.35
			)
			var d_dir: Vector3 = ln.normalized() if ln.length_squared() > 0.0001 else lv.normalized()
			lv += d_dir * (disp * noise_amp)
		var wv: Vector3 = xform * lv
		var wn: Vector3 = (nrm_basis * ln).normalized()
		if wn.length_squared() < 0.0001:
			wn = Vector3.UP
		x_verts[i] = wv
		x_norms[i] = wn
		if use_grad:
			var t: float = clampf((wv.y - y_min) * inv_span, 0.0, 1.0)
			x_cols[i] = base_col.lerp(top_col, t)
		else:
			x_cols[i] = base_col

	if not indices.is_empty():
		var idx: int = 0
		var icount: int = indices.size()
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
				var fn: Vector3 = (p2 - p0).cross(p1 - p0)
				if fn.length_squared() > 0.000001:
					fn = fn.normalized()
					n0 = n0.lerp(fn, 0.5).normalized()
					n1 = n1.lerp(fn, 0.5).normalized()
					n2 = n2.lerp(fn, 0.5).normalized()
			st.set_normal(n0); st.set_uv(Vector2.ZERO); st.set_color(x_cols[i0]); st.add_vertex(p0)
			st.set_normal(n1); st.set_uv(Vector2.ZERO); st.set_color(x_cols[i1]); st.add_vertex(p1)
			st.set_normal(n2); st.set_uv(Vector2.ZERO); st.set_color(x_cols[i2]); st.add_vertex(p2)
			idx += 3
	else:
		var idx: int = 0
		while idx + 2 < vcount:
			st.set_normal(x_norms[idx]); st.set_uv(Vector2.ZERO); st.set_color(x_cols[idx]); st.add_vertex(x_verts[idx])
			st.set_normal(x_norms[idx + 1]); st.set_uv(Vector2.ZERO); st.set_color(x_cols[idx + 1]); st.add_vertex(x_verts[idx + 1])
			st.set_normal(x_norms[idx + 2]); st.set_uv(Vector2.ZERO); st.set_color(x_cols[idx + 2]); st.add_vertex(x_verts[idx + 2])
			idx += 3


static func _append_tapered_tube(
	st: SurfaceTool,
	points: Array[Vector3],
	radii: Array[float],
	segs: int,
	bot_col: Color,
	top_col: Color,
	cap_ends: bool = true,
	uv_y_min: float = 0.0,
	uv_y_max: float = 1.0
) -> void:
	var n_pts: int = points.size()
	if n_pts < 2 or radii.size() < n_pts:
		return
	var rings: Array = []
	var ring_cols: Array[Color] = []
	var ring_uvy: Array[float] = []
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
			ring_v[s] = points[i] + (right * cos(ang) + fwd * sin(ang)) * r
		rings.append(ring_v)
		var t: float = float(i) / float(n_pts - 1)
		ring_cols.append(bot_col.lerp(top_col, t))
		ring_uvy.append(lerpf(uv_y_min, uv_y_max, t))

	for i: int in range(n_pts - 1):
		var r0: PackedVector3Array = rings[i]
		var r1: PackedVector3Array = rings[i + 1]
		var c0: Color = ring_cols[i]
		var c1: Color = ring_cols[i + 1]
		var uvy0: float = ring_uvy[i]
		var uvy1: float = ring_uvy[i + 1]
		var center_mid: Vector3 = (points[i] + points[i + 1]) * 0.5
		for s: int in range(segs):
			var sn: int = (s + 1) % segs
			var v00: Vector3 = r0[s]
			var v01: Vector3 = r0[sn]
			var v11: Vector3 = r1[sn]
			var v10: Vector3 = r1[s]
			var quad_mid: Vector3 = (v00 + v01 + v11 + v10) * 0.25
			var out_h: Vector3 = quad_mid - center_mid
			var u0: float = float(s) / float(segs)
			var u1: float = float(s + 1) / float(segs)
			_append_quad_colored(
				st, v00, v01, v11, v10, c0, c0, c1, c1, out_h,
				Vector2(u0, uvy0), Vector2(u1, uvy0), Vector2(u1, uvy1), Vector2(u0, uvy1)
			)

	if cap_ends:
		var top_r: PackedVector3Array = rings[n_pts - 1]
		var top_c: Vector3 = points[n_pts - 1]
		var top_dir: Vector3 = (points[n_pts - 1] - points[n_pts - 2]).normalized()
		var tc: Color = ring_cols[n_pts - 1]
		var tuv := Vector2(0.5, ring_uvy[n_pts - 1])
		for s: int in range(segs):
			var sn: int = (s + 1) % segs
			_append_tri_colored(st, top_c, top_r[s], top_r[sn], tc, tc, tc, top_dir, tuv, tuv, tuv)
		var bot_r: PackedVector3Array = rings[0]
		var bot_c: Vector3 = points[0]
		var bot_dir: Vector3 = (points[0] - points[1]).normalized()
		var bc: Color = ring_cols[0]
		var buv := Vector2(0.5, ring_uvy[0])
		for s: int in range(segs):
			var sn: int = (s + 1) % segs
			_append_tri_colored(st, bot_c, bot_r[sn], bot_r[s], bc, bc, bc, bot_dir, buv, buv, buv)


static func _append_curved_blade(
	st: SurfaceTool,
	base_pos: Vector3,
	out_dir: Vector3,
	height: float,
	base_width: float,
	arch_out: float,
	col_root: Color,
	col_mid: Color,
	col_tip: Color,
	segs: int = 3,
	uv_y_start: float = 0.0,
	uv_y_end: float = 1.0
) -> void:
	## Builds a gracefully arching, tapered foliage blade with UV.y strictly mapping
	## from root (uv_y_start) to tip (uv_y_end). Designed for double-sided foliage shaders.
	var fwd: Vector3 = Vector3(out_dir.x, 0.0, out_dir.z).normalized()
	if fwd.length_squared() < 0.001:
		fwd = Vector3.FORWARD
	var side: Vector3 = Vector3(-fwd.z, 0.0, fwd.x)
	var n_base: Vector3 = Vector3(fwd.x * 0.32, 0.92, fwd.z * 0.32).normalized()

	var prev_l := Vector3.ZERO
	var prev_r := Vector3.ZERO
	var prev_c := col_root
	var prev_uvy: float = uv_y_start

	for i: int in range(segs + 1):
		var t: float = float(i) / float(segs)
		# Smooth vertical rise + graceful quadratic outward arch & tip droop
		var y_t: float = height * (t - 0.12 * t * t * t)
		var r_t: float = arch_out * (t * t)
		var center: Vector3 = base_pos + fwd * r_t + Vector3(0.0, y_t, 0.0)
		var w_t: float = base_width * (1.0 - t * 0.92)
		var c_t: Color = col_root.lerp(col_mid, t * 2.0) if t < 0.5 else col_mid.lerp(col_tip, (t - 0.5) * 2.0)
		var uvy: float = lerpf(uv_y_start, uv_y_end, t)

		if i == 0:
			prev_l = center - side * (w_t * 0.5)
			prev_r = center + side * (w_t * 0.5)
			prev_c = c_t
			prev_uvy = uvy
		elif i < segs:
			var cur_l: Vector3 = center - side * (w_t * 0.5)
			var cur_r: Vector3 = center + side * (w_t * 0.5)
			var n_up: Vector3 = (n_base + Vector3(0.0, 0.25 * t, 0.0)).normalized()
			_emit_tri_uv(
				st, prev_l, prev_r, cur_r,
				n_up, n_up, n_up,
				Vector2(0.0, prev_uvy), Vector2(1.0, prev_uvy), Vector2(1.0, uvy),
				prev_c, prev_c, c_t
			)
			_emit_tri_uv(
				st, prev_l, cur_r, cur_l,
				n_up, n_up, n_up,
				Vector2(0.0, prev_uvy), Vector2(1.0, uvy), Vector2(0.0, uvy),
				prev_c, c_t, c_t
			)
			prev_l = cur_l
			prev_r = cur_r
			prev_c = c_t
			prev_uvy = uvy
		else:
			# Tapered pointed blade tip triangle
			var tip_n: Vector3 = Vector3(fwd.x * 0.22, 0.97, fwd.z * 0.22).normalized()
			_emit_tri_uv(
				st, prev_l, prev_r, center,
				tip_n, tip_n, tip_n,
				Vector2(0.0, prev_uvy), Vector2(1.0, prev_uvy), Vector2(0.5, uvy),
				prev_c, prev_c, c_t
			)


static func _make_inst(mesh: Mesh, mat: Material, pos: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	inst.material_override = mat
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	inst.position = pos
	return inst


# ==============================================================================
#  1. INTERACTIVE MEADOW GRASS TUFT MESH
# ==============================================================================

static func make_grass_tuft_mesh(is_mob: bool) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var blade_count: int = 5 if is_mob else 8
	var segs: int = 2 if is_mob else 3
	var c_root := Color.html("#143d1a")
	var c_mid := Color.html("#2f7a2c")
	var c_tip := Color.html("#6ab845")

	for i: int in range(blade_count):
		var frac: float = float(i) / float(blade_count)
		var ang: float = frac * TAU + float(i % 3) * 0.34
		var rad: float = 0.045 + float((i * 5) % 4) * 0.032
		var dir := Vector3(cos(ang), 0.0, sin(ang))
		var b_pos := dir * rad
		# Varied organic heights 0.42m..0.88m and graceful outward arch
		var h_var: float = 0.42 + fmod(float(i) * 0.37 + 0.13, 1.0) * 0.46
		var w_var: float = lerpf(0.085, 0.135, 1.0 - (h_var - 0.42) / 0.46)
		var arch: float = h_var * (0.28 + float(i % 3) * 0.10)
		var tint_shift: float = (float(i % 3) - 1.0) * 0.055
		var cr: Color = c_root.lightened(maxf(0.0, tint_shift))
		var cm: Color = c_mid.lightened(maxf(0.0, tint_shift)) if tint_shift >= 0.0 else c_mid.darkened(-tint_shift)
		var ct: Color = c_tip.lightened(maxf(0.0, tint_shift)) if tint_shift >= 0.0 else c_tip.darkened(-tint_shift)
		_append_curved_blade(st, b_pos, dir, h_var, w_var, arch, cr, cm, ct, segs, 0.0, 1.0)

	return st.commit()


# ==============================================================================
#  2. LAKESIDE PAMPAS GRASS & CATTAIL REED CLUSTER MESH
# ==============================================================================

static func make_reed_cluster_mesh(is_mob: bool) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var blade_count: int = 6 if is_mob else 9
	var segs: int = 3
	var c_root := Color.html("#173a1d")
	var c_mid := Color.html("#3d7b38")
	var c_tip := Color.html("#9eb956")

	# Slender arching wetland reed blades (1.40m .. 2.05m)
	for i: int in range(blade_count):
		var ang: float = (float(i) / float(blade_count)) * TAU + float(i % 2) * 0.28
		var dir := Vector3(cos(ang), 0.0, sin(ang))
		var base_p := dir * (0.06 + float(i % 3) * 0.045)
		var h: float = 1.40 + fmod(float(i) * 0.41 + 0.19, 1.0) * 0.65
		var arch: float = h * (0.34 + float(i % 3) * 0.08)
		_append_curved_blade(st, base_p, dir, h, 0.10, arch, c_root, c_mid, c_tip, segs, 0.0, 1.0)

	# 2 tall cattail spikes / feathery Japanese silver susuki plumes (1.75m .. 2.30m)
	var stalk_count: int = 2 if is_mob else 3
	var c_stalk_bot := Color.html("#1e4620")
	var c_stalk_top := Color.html("#527a34")
	var c_cattail_dark := Color.html("#5c3317")
	var c_cattail_lit := Color.html("#8c5228")
	var c_plume_base := Color.html("#d4ccb4")
	var c_plume_tip := Color.html("#faf6e8")

	for si: int in range(stalk_count):
		var s_ang: float = float(si) * 2.15 + 0.45
		var s_dir := Vector3(cos(s_ang), 0.0, sin(s_ang))
		var s_base := s_dir * 0.07
		var s_h: float = 1.82 + float(si) * 0.22
		var lean: float = 0.16 + float(si) * 0.05
		var p0 := s_base
		var p1 := s_base + s_dir * (lean * 0.42) + Vector3(0.0, s_h * 0.48, 0.0)
		var p2 := s_base + s_dir * lean + Vector3(0.0, s_h * 0.80, 0.0)
		var p3 := s_base + s_dir * (lean * 1.15) + Vector3(0.0, s_h, 0.0)

		if si % 2 == 0:
			# Velvet golden-brown Cattail (蒲の穂)
			var pts: Array[Vector3] = [p0, p1, p2]
			var rads: Array[float] = [0.028, 0.022, 0.018]
			_append_tapered_tube(st, pts, rads, 5, c_stalk_bot, c_stalk_top, false, 0.0, 0.78)
			var cat_pts: Array[Vector3] = [
				p2 - Vector3(0.0, 0.02, 0.0),
				p2.lerp(p3, 0.25),
				p2.lerp(p3, 0.78),
				p3,
			]
			var cat_rads: Array[float] = [0.022, 0.058, 0.056, 0.012]
			_append_tapered_tube(st, cat_pts, cat_rads, 5, c_cattail_dark, c_cattail_lit, true, 0.76, 0.98)
		else:
			# Feathery silver-cream Susuki Pampas Plume (薄・ススキ)
			var pts: Array[Vector3] = [p0, p1, p2]
			var rads: Array[float] = [0.024, 0.019, 0.014]
			_append_tapered_tube(st, pts, rads, 4, c_stalk_bot, c_stalk_top, false, 0.0, 0.74)
			var fronds: int = 4 if is_mob else 6
			for fi: int in range(fronds):
				var f_ang: float = s_ang + (float(fi) / float(fronds) - 0.5) * 2.2
				var f_dir := Vector3(cos(f_ang), 0.0, sin(f_ang))
				_append_curved_blade(
					st, p2, f_dir, 0.44 + float(fi % 2) * 0.12,
					0.075, 0.24, c_plume_base, c_plume_tip, c_plume_tip,
					2, 0.74, 1.0
				)

	return st.commit()


# ==============================================================================
#  3. JAPANESE WILDFLOWER CLUSTER MESHES (COSMOS, NANOHANA, HIGANBANA)
# ==============================================================================

static func make_flower_cluster_mesh(kind: int, is_mob: bool) -> ArrayMesh:
	## kind = 0: Cosmos 秋櫻 (sakura pink & blush white)
	## kind = 1: Nanohana 油菜花 (vibrant golden yellow)
	## kind = 2: Higanbana 彼岸花 (dramatic crimson red spider lily)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var stem_count: int = 4 if is_mob else 6
	var c_leaf_root := Color.html("#184520")
	var c_leaf_mid := Color.html("#2f7a32")
	var c_leaf_tip := Color.html("#52a346")
	var c_stem_bot := Color.html("#1c4d24")
	var c_stem_top := Color.html("#3d8439")

	# Basal lush green leaves radiating near the root (UV.y: 0.0 -> 0.52)
	var leaf_count: int = 4 if is_mob else 6
	for li: int in range(leaf_count):
		var lang: float = (float(li) / float(leaf_count)) * TAU + 0.31
		var ldir := Vector3(cos(lang), 0.0, sin(lang))
		_append_curved_blade(
			st, ldir * 0.04, ldir, 0.28 + float(li % 2) * 0.10,
			0.095, 0.20, c_leaf_root, c_leaf_mid, c_leaf_tip,
			2, 0.0, 0.52
		)

	# Sculpted flower stems + multi-petal star blossom cups + golden stamen domes
	for si: int in range(stem_count):
		var sang: float = (float(si) / float(stem_count)) * TAU + float(si % 2) * 0.25
		var sdir := Vector3(cos(sang), 0.0, sin(sang))
		var base_r: float = 0.05 + float(si % 3) * 0.055
		var stem_h: float = 0.44 + fmod(float(si) * 0.43 + 0.17, 1.0) * 0.36
		var spread: float = 0.12 + float(si % 3) * 0.07

		var p0: Vector3 = sdir * base_r
		var p1: Vector3 = sdir * (base_r + spread * 0.45) + Vector3(0.0, stem_h * 0.52, 0.0)
		var p2: Vector3 = sdir * (base_r + spread) + Vector3(0.0, stem_h, 0.0)

		# Slender 3-sided stem (UV.y: 0.0 -> 0.85)
		var pts: Array[Vector3] = [p0, p1, p2]
		var rads: Array[float] = [0.018, 0.014, 0.011]
		_append_tapered_tube(st, pts, rads, 3, c_stem_bot, c_stem_top, false, 0.0, 0.85)

		# Blossom palette per species
		var petal_inner: Color
		var petal_outer: Color
		var stamen_col: Color
		var petals: int = 5
		var petal_len: float = 0.165
		var petal_w: float = 0.088
		var cup_lift: float = 0.052

		if kind == 0:
			# Cosmos 秋櫻: alternating sakura pink, rose pink, and crisp blush white
			var variant: int = si % 3
			if variant == 0:
				petal_inner = Color.html("#ec4899")
				petal_outer = Color.html("#f9a8d4")
			elif variant == 1:
				petal_inner = Color.html("#f472b6")
				petal_outer = Color.html("#fdf2f8")
			else:
				petal_inner = Color.html("#fbcfe8")
				petal_outer = Color.html("#ffffff")
			stamen_col = Color.html("#facc15")
			petals = 5
			petal_len = 0.175
			petal_w = 0.092
			cup_lift = 0.055
		elif kind == 1:
			# Nanohana 油菜花: sunny golden canary yellow clusters
			petal_inner = Color.html("#eab308")
			petal_outer = Color.html("#fef08a") if si % 2 == 0 else Color.html("#fde047")
			stamen_col = Color.html("#d97706")
			petals = 5
			petal_len = 0.15
			petal_w = 0.085
			cup_lift = 0.048
		else:
			# Higanbana 彼岸花: dramatic crimson-red recurved spider-lily petals
			petal_inner = Color.html("#991b1b")
			petal_outer = Color.html("#ef4444") if si % 2 == 0 else Color.html("#dc2626")
			stamen_col = Color.html("#fca5a5")
			petals = 6
			petal_len = 0.21
			petal_w = 0.055
			cup_lift = 0.085

		# Orient blossom gently outward along stem tangent
		var up_axis: Vector3 = (Vector3.UP + sdir * 0.24).normalized()
		var right_axis: Vector3 = Vector3(-sdir.z, 0.0, sdir.x).normalized()
		var fwd_axis: Vector3 = right_axis.cross(up_axis).normalized()

		# Emit sculpted star blossom petals (UV.y = 0.85 -> 0.98)
		for pi: int in range(petals):
			var pang: float = (float(pi) / float(petals)) * TAU + float(si) * 0.4
			var p_dir: Vector3 = (right_axis * cos(pang) + fwd_axis * sin(pang)).normalized()
			var p_side: Vector3 = up_axis.cross(p_dir).normalized()

			var v_base: Vector3 = p2 + p_dir * 0.015
			var v_mid_l: Vector3 = p2 + p_dir * (petal_len * 0.56) - p_side * (petal_w * 0.5) + up_axis * (cup_lift * 0.65)
			var v_mid_r: Vector3 = p2 + p_dir * (petal_len * 0.56) + p_side * (petal_w * 0.5) + up_axis * (cup_lift * 0.65)
			var tip_lift: float = cup_lift * (0.55 if kind == 2 else 1.05) # Higanbana curls slightly back!
			var v_tip: Vector3 = p2 + p_dir * petal_len + up_axis * tip_lift
			var p_nrm: Vector3 = (up_axis + p_dir * 0.22).normalized()

			_emit_tri_uv(
				st, v_base, v_mid_r, v_mid_l,
				p_nrm, p_nrm, p_nrm,
				Vector2(0.5, 0.85), Vector2(1.0, 0.92), Vector2(0.0, 0.92),
				petal_inner, petal_outer, petal_outer
			)
			_emit_tri_uv(
				st, v_mid_l, v_mid_r, v_tip,
				p_nrm, p_nrm, p_nrm,
				Vector2(0.0, 0.92), Vector2(1.0, 0.92), Vector2(0.5, 0.98),
				petal_outer, petal_outer, petal_outer.lightened(0.08)
			)

		# Sculpted bright stamen crown dome (UV.y = 0.90 -> 1.0)
		var st_r: float = 0.042 if kind != 2 else 0.036
		var st_h: float = 0.046 if kind != 2 else 0.095
		var apex: Vector3 = p2 + up_axis * st_h
		var dome_segs: int = 5
		for di: int in range(dome_segs):
			var a0: float = (float(di) / float(dome_segs)) * TAU
			var a1: float = (float(di + 1) / float(dome_segs)) * TAU
			var b0: Vector3 = p2 + (right_axis * cos(a0) + fwd_axis * sin(a0)) * st_r + up_axis * 0.012
			var b1: Vector3 = p2 + (right_axis * cos(a1) + fwd_axis * sin(a1)) * st_r + up_axis * 0.012
			_emit_tri_uv(
				st, b0, b1, apex,
				up_axis, up_axis, up_axis,
				Vector2(0.0, 0.90), Vector2(1.0, 0.90), Vector2(0.5, 1.0),
				stamen_col, stamen_col, stamen_col.lightened(0.18)
			)

	return st.commit()


# ==============================================================================
#  4. FLOATING EMERALD LOTUS PAD + SCULPTED PINK-WHITE LOTUS FLOWER MESH
# ==============================================================================

static func make_lotus_pad_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Notched circular lily pad (radius ~ 0.65m, V-shaped cutout notch)
	var pad_r: float = 0.65
	var segs: int = 14
	var notch_half: float = 0.24 # radians on each side of +Z notch
	var c_center := Color.html("#14532d")
	var c_mid := Color.html("#228b3b")
	var c_rim := Color.html("#4ade80")
	var center_v := Vector3(0.0, 0.015, 0.0)

	for i: int in range(segs):
		var t0: float = float(i) / float(segs)
		var t1: float = float(i + 1) / float(segs)
		var a0: float = lerpf(notch_half, TAU - notch_half, t0)
		var a1: float = lerpf(notch_half, TAU - notch_half, t1)
		var r0: float = pad_r * (0.96 + 0.05 * sin(a0 * 5.0))
		var r1: float = pad_r * (0.96 + 0.05 * sin(a1 * 5.0))

		var m0 := Vector3(sin(a0) * r0 * 0.58, 0.022, cos(a0) * r0 * 0.58)
		var m1 := Vector3(sin(a1) * r1 * 0.58, 0.022, cos(a1) * r1 * 0.58)
		var e0 := Vector3(sin(a0) * r0, 0.055, cos(a0) * r0) # upturned saucer rim
		var e1 := Vector3(sin(a1) * r1, 0.055, cos(a1) * r1)

		_append_tri_colored(
			st, center_v, m0, m1,
			c_center, c_mid, c_mid, Vector3.UP,
			Vector2(0.5, 0.15), Vector2(0.5, 0.15), Vector2(0.5, 0.15)
		)
		_append_quad_colored(
			st, m0, e0, e1, m1,
			c_mid, c_rim, c_rim, c_mid, Vector3.UP,
			Vector2(0.5, 0.15), Vector2(0.5, 0.15), Vector2(0.5, 0.15), Vector2(0.5, 0.15)
		)

	# Sculpted multi-petal pink-white lotus blossom resting on top of the lily pad
	var fl_pos := Vector3(-0.08, 0.035, -0.06)
	var c_pink_bot := Color.html("#db2777")
	var c_pink_tip := Color.html("#f9a8d4")
	var c_inner_bot := Color.html("#fbcfe8")
	var c_inner_tip := Color.html("#ffffff")
	var c_gold := Color.html("#facc15")

	# Outer 6 cupped rose-pink lotus petals
	for i: int in range(6):
		var a: float = (float(i) / 6.0) * TAU
		var d := Vector3(cos(a), 0.0, sin(a))
		var s := Vector3(-d.z, 0.0, d.x)
		var vb := fl_pos + d * 0.03
		var vml := fl_pos + d * 0.15 - s * 0.065 + Vector3(0.0, 0.055, 0.0)
		var vmr := fl_pos + d * 0.15 + s * 0.065 + Vector3(0.0, 0.055, 0.0)
		var vt := fl_pos + d * 0.24 + Vector3(0.0, 0.115, 0.0)
		var hint := (Vector3.UP + d * 0.35).normalized()
		_append_tri_colored(st, vb, vmr, vml, c_pink_bot, c_pink_tip, c_pink_tip, hint, Vector2(0.5, 0.3), Vector2(0.5, 0.35), Vector2(0.5, 0.35))
		_append_tri_colored(st, vml, vmr, vt, c_pink_tip, c_pink_tip, c_inner_tip, hint, Vector2(0.5, 0.35), Vector2(0.5, 0.35), Vector2(0.5, 0.42))

	# Inner 5 upright blush-white lotus petals
	for i: int in range(5):
		var a: float = (float(i) / 5.0) * TAU + 0.32
		var d := Vector3(cos(a), 0.0, sin(a))
		var s := Vector3(-d.z, 0.0, d.x)
		var vb := fl_pos + d * 0.02 + Vector3(0.0, 0.015, 0.0)
		var vml := fl_pos + d * 0.095 - s * 0.045 + Vector3(0.0, 0.095, 0.0)
		var vmr := fl_pos + d * 0.095 + s * 0.045 + Vector3(0.0, 0.095, 0.0)
		var vt := fl_pos + d * 0.13 + Vector3(0.0, 0.175, 0.0)
		var hint := (Vector3.UP + d * 0.25).normalized()
		_append_tri_colored(st, vb, vmr, vml, c_inner_bot, c_inner_tip, c_inner_tip, hint, Vector2(0.5, 0.35), Vector2(0.5, 0.4), Vector2(0.5, 0.4))
		_append_tri_colored(st, vml, vmr, vt, c_inner_tip, c_inner_tip, c_inner_tip, hint, Vector2(0.5, 0.4), Vector2(0.5, 0.4), Vector2(0.5, 0.45))

	# Golden lotus seed-pod heart
	var pod := CylinderMesh.new()
	pod.bottom_radius = 0.035; pod.top_radius = 0.055; pod.height = 0.07; pod.radial_segments = 6; pod.rings = 1
	_append_mesh_colored(st, pod, Transform3D(Basis.IDENTITY, fl_pos + Vector3(0.0, 0.05, 0.0)), c_gold.darkened(0.12), c_gold.lightened(0.14), fl_pos.y, fl_pos.y + 0.09)

	return st.commit()


# ==============================================================================
#  5. SCULPTED JAPANESE COASTAL RED PINE TREE (赤松・Akamatsu, 2 DRAW CALLS!)
# ==============================================================================

static func _append_pine_needle_pad(
	st: SurfaceTool,
	center: Vector3,
	rx: float,
	ry: float,
	rz: float,
	yaw: float,
	bot_col: Color,
	mid_col: Color,
	top_col: Color,
	seed_val: float,
	is_mob: bool
) -> void:
	## Flat-bottomed, layered windswept Japanese pine canopy pad with organic needle tufts.
	var sp := SphereMesh.new()
	sp.radius = 1.0
	sp.height = 2.0
	sp.radial_segments = 8 if is_mob else 11
	sp.rings = 4 if is_mob else 6
	var arrays: Array = sp.surface_get_arrays(0)
	if arrays.is_empty():
		return
	var raw_verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var raw_norms: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]

	var rot_b := Basis(Vector3.UP, yaw)
	var vcount: int = raw_verts.size()
	var x_verts := PackedVector3Array(); x_verts.resize(vcount)
	var x_norms := PackedVector3Array(); x_norms.resize(vcount)
	var x_cols := PackedColorArray(); x_cols.resize(vcount)

	for i: int in range(vcount):
		var v: Vector3 = raw_verts[i]
		# Sculpt iconic flat-bottomed Japanese coastal pine cloud pad
		var sy: float = v.y
		if sy < 0.0:
			sy *= 0.34
		else:
			sy = pow(sy, 0.85)
		var ang: float = atan2(v.z, v.x)
		var lobe: float = 1.0 + 0.16 * sin(ang * 4.0 + seed_val) + 0.09 * cos(ang * 7.0 - seed_val * 1.4)
		var sv := Vector3(v.x * rx * lobe, sy * ry, v.z * rz * lobe)
		var wv: Vector3 = center + rot_b * sv
		x_verts[i] = wv

		var ln: Vector3 = raw_norms[i] if i < raw_norms.size() else Vector3.UP
		var wn: Vector3 = (rot_b * Vector3(ln.x / maxf(0.1, rx), ln.y / maxf(0.1, ry), ln.z / maxf(0.1, rz))).normalized()
		x_norms[i] = wn

		var t: float = clampf((v.y + 1.0) * 0.5, 0.0, 1.0)
		x_cols[i] = bot_col.lerp(mid_col, t * 2.0) if t < 0.5 else mid_col.lerp(top_col, (t - 0.5) * 2.0)

	var idx: int = 0
	var icount: int = indices.size()
	while idx + 2 < icount:
		var i0: int = indices[idx]
		var i1: int = indices[idx + 1]
		var i2: int = indices[idx + 2]
		st.set_normal(x_norms[i0]); st.set_color(x_cols[i0]); st.add_vertex(x_verts[i0])
		st.set_normal(x_norms[i1]); st.set_color(x_cols[i1]); st.add_vertex(x_verts[i1])
		st.set_normal(x_norms[i2]); st.set_color(x_cols[i2]); st.add_vertex(x_verts[i2])
		idx += 3


static func add_japanese_pine_tree(
	content_root: Node3D,
	base_pos: Vector3,
	sc: float = 1.0,
	yaw: float = 0.0,
	is_mob: bool = false
) -> Node3D:
	var root := Node3D.new()
	root.name = "JapaneseCoastalPine"
	root.position = base_pos
	root.rotation.y = yaw
	root.scale = Vector3.ONE * sc

	# 1. Gnarled leaning reddish-brown Akamatsu bark trunk + sweeping limbs (Draw call 1)
	var st_bark := SurfaceTool.new()
	st_bark.begin(Mesh.PRIMITIVE_TRIANGLES)

	var c_root := Color.html("#3b1e16")
	var c_bark_mid := Color.html("#6e3524")
	var c_bark_top := Color.html("#914830")
	var trunk_segs: int = 6 if is_mob else 8

	# S-curved coastal leaning main trunk
	var trunk_pts: Array[Vector3] = [
		Vector3(0.0, -0.25, 0.0),
		Vector3(0.18, 0.85, 0.10),
		Vector3(0.62, 2.05, 0.24),
		Vector3(0.95, 3.30, 0.14),
		Vector3(0.65, 4.50, -0.15),
		Vector3(0.28, 5.45, -0.35),
	]
	var trunk_rads: Array[float] = [0.54, 0.36, 0.28, 0.22, 0.15, 0.08]
	_append_tapered_tube(st_bark, trunk_pts, trunk_rads, trunk_segs, c_root, c_bark_top, true)

	# 3 flared coastal root buttresses gripping the sand/soil
	for ri: int in range(3):
		var ra: float = float(ri) * (TAU / 3.0) + 0.55
		var rd := Vector3(cos(ra), 0.0, sin(ra))
		var r_pts: Array[Vector3] = [
			Vector3(0.0, 0.55, 0.0) + rd * 0.15,
			rd * 0.55 + Vector3(0.0, 0.12, 0.0),
			rd * 0.98 + Vector3(0.0, -0.22, 0.0),
		]
		_append_tapered_tube(st_bark, r_pts, [0.22, 0.14, 0.06], 5, c_root, c_bark_mid, true)

	# 4 sweeping asymmetrical limbs reaching over the beach/water
	var limb_specs: Array = [
		[Vector3(0.62, 2.25, 0.22), Vector3(1.65, 2.55, 0.72), Vector3(2.55, 2.72, 0.98), 0.15, 0.05],
		[Vector3(0.88, 3.15, 0.15), Vector3(-0.35, 3.45, 0.85), Vector3(-1.55, 3.62, 1.15), 0.14, 0.05],
		[Vector3(0.76, 3.95, -0.05), Vector3(1.62, 4.22, -0.88), Vector3(2.25, 4.38, -1.35), 0.12, 0.04],
		[Vector3(0.42, 4.85, -0.25), Vector3(-0.68, 5.15, -0.95), Vector3(-1.35, 5.28, -1.25), 0.10, 0.04],
	]
	for limb in limb_specs:
		var l_pts: Array[Vector3] = [limb[0], limb[1], limb[2]]
		var l_rads: Array[float] = [float(limb[3]), (float(limb[3]) + float(limb[4])) * 0.5, float(limb[4])]
		_append_tapered_tube(st_bark, l_pts, l_rads, 5, c_bark_mid, c_bark_top, true)

	var bark_mat := WafuuModels3D.make_wafuu_mat(0, is_mob, 0.86, 0.02, 0.12)
	root.add_child(_make_inst(st_bark.commit(), bark_mat))

	# 2. Wide flat layered deep-emerald pine needle pads (Draw call 2)
	var st_needles := SurfaceTool.new()
	st_needles.begin(Mesh.PRIMITIVE_TRIANGLES)

	var c_pine_bot := Color.html("#14532d")
	var c_pine_mid := Color.html("#227a3e")
	var c_pine_top := Color.html("#3e9c4f")

	var pad_specs: Array = [
		[Vector3(2.55, 2.90, 0.98), 1.65, 0.56, 1.32, 0.25],
		[Vector3(-1.55, 3.82, 1.15), 1.55, 0.52, 1.25, 1.35],
		[Vector3(2.22, 4.56, -1.35), 1.48, 0.52, 1.28, 2.40],
		[Vector3(-1.35, 5.42, -1.25), 1.35, 0.48, 1.18, 3.55],
		[Vector3(0.32, 5.75, -0.32), 1.92, 0.68, 1.62, 0.85],
	]
	if not is_mob:
		pad_specs.append([Vector3(1.15, 3.45, 0.45), 1.18, 0.44, 1.05, 4.15])
		pad_specs.append([Vector3(-0.35, 4.65, 0.35), 1.25, 0.46, 1.10, 5.20])

	for pi: int in range(pad_specs.size()):
		var ps: Array = pad_specs[pi]
		_append_pine_needle_pad(
			st_needles, ps[0], float(ps[1]), float(ps[2]), float(ps[3]),
			float(ps[4]), c_pine_bot, c_pine_mid, c_pine_top, float(pi) * 1.7 + 0.6, is_mob
		)

	var pine_mat := WafuuModels3D.make_wafuu_mat(1, is_mob, 0.66, 0.02, 0.0)
	root.add_child(_make_inst(st_needles.commit(), pine_mat))

	content_root.add_child(root)
	return root


# ==============================================================================
#  6. WALKABLE WEATHERED CEDAR LAKESIDE BOAT PIER (REGISTERED IN arena.bridges)
# ==============================================================================

static func add_lakeside_pier(
	arena: Arena3D,
	content_root: Node3D,
	prop_shader: Shader,
	start_p: Vector3,
	end_p: Vector3,
	width: float = 3.2
) -> Node3D:
	var is_mob: bool = UiStyle.is_mobile_device()
	# Register cleanly in arena.bridges with arch = 0.0 so players walk straight over water!
	arena.bridges.append({
		"start": start_p,
		"end": end_p,
		"width": width,
		"arch": 0.0,
	})

	var dir3: Vector3 = end_p - start_p
	var total_len: float = Vector2(dir3.x, dir3.z).length()
	var dy_total: float = end_p.y - start_p.y
	var yaw: float = atan2(dir3.x, dir3.z)

	var root := Node3D.new()
	root.name = "MoonlitLakesidePier"
	root.position = start_p
	root.rotation.y = yaw

	var st_deck := SurfaceTool.new()
	st_deck.begin(Mesh.PRIMITIVE_TRIANGLES)
	var st_posts := SurfaceTool.new()
	st_posts.begin(Mesh.PRIMITIVE_TRIANGLES)
	var st_glow := SurfaceTool.new()
	st_glow.begin(Mesh.PRIMITIVE_TRIANGLES)

	var c_cedar_dark := Color.html("#4a3121")
	var c_cedar_mid := Color.html("#704c33")
	var c_cedar_lit := Color.html("#946949")
	var c_piling_wet := Color.html("#261c15")
	var c_piling_top := Color.html("#61432d")
	var c_rope_bot := Color.html("#9c8256")
	var c_rope_top := Color.html("#d6bf8f")
	var c_iron := Color.html("#1e293b")
	var c_lantern := Color.html("#fef08a")

	# 1. Transverse weathered cedar planks along the pier deck
	var plank_count: int = maxi(10, int(round(total_len / 0.44)))
	var plank_step: float = total_len / float(plank_count)
	var plank_box := BoxMesh.new()
	plank_box.size = Vector3(width, 0.14, plank_step * 0.86)
	var pitch: float = -atan2(dy_total, maxf(0.01, total_len))
	var tilt_b := Basis(Vector3.RIGHT, pitch)

	for i: int in range(plank_count):
		var t: float = (float(i) + 0.5) / float(plank_count)
		var pz: float = t * total_len
		var py: float = dy_total * t - 0.07
		var plank_col: Color = c_cedar_mid.lerp(c_cedar_lit, float(i % 3) * 0.28)
		_append_mesh_colored(st_deck, plank_box, Transform3D(tilt_b, Vector3(0.0, py, pz)), plank_col.darkened(0.14), plank_col, py - 0.08, py + 0.08)

	# Twin longitudinal bearer beams + edge curb timbers
	var beam_box := BoxMesh.new()
	beam_box.size = Vector3(0.22, 0.24, total_len + 0.2)
	var curb_box := BoxMesh.new()
	curb_box.size = Vector3(0.18, 0.14, total_len)
	for side: float in [-1.0, 1.0]:
		_append_mesh_colored(
			st_posts, beam_box,
			Transform3D(tilt_b, Vector3(side * (width * 0.36), dy_total * 0.5 - 0.24, total_len * 0.5)),
			c_cedar_dark, c_cedar_mid
		)
		_append_mesh_colored(
			st_posts, curb_box,
			Transform3D(tilt_b, Vector3(side * (width * 0.47), dy_total * 0.5 + 0.05, total_len * 0.5)),
			c_cedar_dark, c_cedar_lit
		)

	# 2. Cylindrical wooden pilings anchored deep into the lakebed + mooring bollards with rope wraps
	var piling_pairs: int = 4
	var piling_cyl := CylinderMesh.new()
	piling_cyl.bottom_radius = 0.17; piling_cyl.top_radius = 0.145; piling_cyl.height = 2.95
	piling_cyl.radial_segments = 7 if is_mob else 9; piling_cyl.rings = 1

	var rope_torus := TorusMesh.new()
	rope_torus.inner_radius = 0.125; rope_torus.outer_radius = 0.195
	rope_torus.rings = 10 if is_mob else 14; rope_torus.ring_segments = 5

	for pi: int in range(piling_pairs):
		var t: float = float(pi) / float(piling_pairs - 1)
		var pz: float = lerpf(0.55, total_len - 0.35, t)
		var deck_y: float = dy_total * (pz / maxf(0.01, total_len))
		var is_bollard: bool = (pi == 1 or pi == piling_pairs - 1)
		var top_ext: float = 0.68 if is_bollard else 0.18

		for side: float in [-1.0, 1.0]:
			var px: float = side * (width * 0.45)
			var p_top_y: float = deck_y + top_ext
			var p_center_y: float = p_top_y - piling_cyl.height * 0.5
			_append_mesh_colored(
				st_posts, piling_cyl,
				Transform3D(Basis.IDENTITY, Vector3(px, p_center_y, pz)),
				c_piling_wet, c_piling_top, p_center_y - 1.2, p_top_y
			)
			# Coiled hemp rope wraps around mooring bollards
			if is_bollard:
				for ri: int in range(2):
					_append_mesh_colored(
						st_posts, rope_torus,
						Transform3D(Basis.IDENTITY, Vector3(px, deck_y + 0.28 + float(ri) * 0.13, pz)),
						c_rope_bot, c_rope_top
					)

	# 3. Traditional curved hanging pier lantern post at the lake-facing tip!
	var lx: float = -width * 0.42
	var lz: float = total_len - 0.32
	var ly: float = dy_total
	var post_pts: Array[Vector3] = [
		Vector3(lx, ly - 0.15, lz),
		Vector3(lx, ly + 1.45, lz),
		Vector3(lx, ly + 2.38, lz),
		Vector3(lx + 0.52, ly + 2.48, lz + 0.10),
	]
	_append_tapered_tube(st_posts, post_pts, [0.11, 0.095, 0.08, 0.055], 6, c_cedar_dark, c_cedar_lit, true)

	# Lantern iron cap, base frame, and glowing paper core
	var lan_pos := Vector3(lx + 0.52, ly + 2.02, lz + 0.10)
	var cap_cyl := CylinderMesh.new()
	cap_cyl.bottom_radius = 0.26; cap_cyl.top_radius = 0.05; cap_cyl.height = 0.18; cap_cyl.radial_segments = 6; cap_cyl.rings = 1
	_append_mesh_colored(st_posts, cap_cyl, Transform3D(Basis.IDENTITY, lan_pos + Vector3(0.0, 0.24, 0.0)), c_iron, c_iron.lightened(0.2))
	var chain_cyl := CylinderMesh.new()
	chain_cyl.bottom_radius = 0.018; chain_cyl.top_radius = 0.018; chain_cyl.height = 0.28; chain_cyl.radial_segments = 4; chain_cyl.rings = 1
	_append_mesh_colored(st_posts, chain_cyl, Transform3D(Basis.IDENTITY, lan_pos + Vector3(0.0, 0.34, 0.0)), c_iron, c_iron)
	var bot_cyl := CylinderMesh.new()
	bot_cyl.bottom_radius = 0.14; bot_cyl.top_radius = 0.16; bot_cyl.height = 0.07; bot_cyl.radial_segments = 6; bot_cyl.rings = 1
	_append_mesh_colored(st_posts, bot_cyl, Transform3D(Basis.IDENTITY, lan_pos + Vector3(0.0, -0.20, 0.0)), c_iron, c_iron)

	var glow_cyl := CylinderMesh.new()
	glow_cyl.bottom_radius = 0.14; glow_cyl.top_radius = 0.17; glow_cyl.height = 0.36; glow_cyl.radial_segments = 8; glow_cyl.rings = 1
	_append_mesh_colored(st_glow, glow_cyl, Transform3D(Basis.IDENTITY, lan_pos), Color.html("#fbbf24"), c_lantern, lan_pos.y - 0.18, lan_pos.y + 0.18)

	var deck_mat: Material
	if prop_shader != null:
		var sm := ShaderMaterial.new()
		sm.shader = prop_shader
		sm.set_shader_parameter("surface_type", 0)
		sm.set_shader_parameter("albedo_a", c_cedar_lit)
		sm.set_shader_parameter("albedo_b", c_cedar_dark)
		sm.set_shader_parameter("accent_color", c_rope_top)
		sm.set_shader_parameter("roughness_val", 0.70)
		sm.set_shader_parameter("metallic_val", 0.04)
		sm.set_shader_parameter("emission_strength", 0.0)
		sm.set_shader_parameter("tile_scale", 2.2)
		deck_mat = sm
	else:
		deck_mat = WafuuModels3D.make_wafuu_mat(0, is_mob, 0.74, 0.03, 0.08)

	var post_mat := WafuuModels3D.make_wafuu_mat(0, is_mob, 0.80, 0.04, 0.15)
	var glow_mat := WafuuModels3D.make_glow_mat("#fef08a", 0.96)
	glow_mat.vertex_color_use_as_albedo = true
	glow_mat.albedo_color = Color.WHITE

	root.add_child(_make_inst(st_deck.commit(), deck_mat))
	root.add_child(_make_inst(st_posts.commit(), post_mat))
	root.add_child(_make_inst(st_glow.commit(), glow_mat))

	content_root.add_child(root)
	return root


# ==============================================================================
#  7. TRADITIONAL JAPANESE WASEN ROWBOAT (和舟, 2 DRAW CALLS + WAVE BOBBING)
# ==============================================================================

static func add_moored_rowboat(
	content_root: Node3D,
	water_pos: Vector3,
	yaw: float,
	sky_anim_nodes: Array[Dictionary]
) -> Node3D:
	var is_mob: bool = UiStyle.is_mobile_device()
	var boat := Node3D.new()
	boat.name = "MooredWasenRowboat"
	boat.position = water_pos
	boat.rotation.y = yaw

	var st_wood := SurfaceTool.new()
	st_wood.begin(Mesh.PRIMITIVE_TRIANGLES)
	var st_glow := SurfaceTool.new()
	st_glow.begin(Mesh.PRIMITIVE_TRIANGLES)

	var c_hull_bot := Color.html("#3d2517")
	var c_hull_mid := Color.html("#7c5033")
	var c_hull_top := Color.html("#ad7b52")
	var c_seat := Color.html("#9c6b43")
	var c_oar := Color.html("#c49a6c")

	# Longitudinal hull stations from stern (-1.80) to upturned pointed bow (+2.05)
	# Each station: [z, half_beam_bot, half_beam_top, y_bot, y_top]
	var stations: Array = [
		[-1.80, 0.30, 0.44, 0.02, 0.48],
		[-1.15, 0.46, 0.66, -0.10, 0.42],
		[0.00,  0.52, 0.72, -0.13, 0.40],
		[1.05,  0.34, 0.52, -0.06, 0.46],
		[1.72,  0.10, 0.22, 0.12, 0.62],
		[2.08,  0.02, 0.04, 0.42, 0.78], # Iconic upturned wasen bow prow!
	]

	for i: int in range(stations.size() - 1):
		var s0: Array = stations[i]
		var s1: Array = stations[i + 1]
		var z0: float = float(s0[0]); var z1: float = float(s1[0])
		var bb0: float = float(s0[1]); var bb1: float = float(s1[1])
		var bt0: float = float(s0[2]); var bt1: float = float(s1[2])
		var yb0: float = float(s0[3]); var yb1: float = float(s1[3])
		var yt0: float = float(s0[4]); var yt1: float = float(s1[4])

		# Flat bottom floor (outer underside + visible interior deck planks)
		var fl0 := Vector3(-bb0, yb0, z0); var fr0 := Vector3(bb0, yb0, z0)
		var fl1 := Vector3(-bb1, yb1, z1); var fr1 := Vector3(bb1, yb1, z1)
		_append_quad_colored(st_wood, fl0, fr0, fr1, fl1, c_hull_bot, c_hull_bot, c_hull_bot, c_hull_bot, Vector3.DOWN)
		var ifl0 := fl0 + Vector3(0.0, 0.04, 0.0); var ifr0 := fr0 + Vector3(0.0, 0.04, 0.0)
		var ifl1 := fl1 + Vector3(0.0, 0.04, 0.0); var ifr1 := fr1 + Vector3(0.0, 0.04, 0.0)
		_append_quad_colored(st_wood, ifl0, ifl1, ifr1, ifr0, c_hull_mid, c_hull_mid, c_hull_mid, c_hull_mid, Vector3.UP)

		# Port (-X) and Starboard (+X) curved plank hull walls (outer + inner + gunwale cap)
		for side: float in [-1.0, 1.0]:
			var b0 := Vector3(side * bb0, yb0, z0)
			var b1 := Vector3(side * bb1, yb1, z1)
			var t0 := Vector3(side * bt0, yt0, z0)
			var t1 := Vector3(side * bt1, yt1, z1)
			var out_h := Vector3(side, 0.15, 0.0)
			_append_quad_colored(st_wood, b0, b1, t1, t0, c_hull_bot, c_hull_bot, c_hull_top, c_hull_top, out_h)

			# Inner hull wall (offset inward by 0.06m so hull has solid timber thickness)
			var inset: float = -side * 0.06
			var ib0 := b0 + Vector3(inset, 0.04, 0.0)
			var ib1 := b1 + Vector3(inset, 0.04, 0.0)
			var it0 := t0 + Vector3(inset, 0.0, 0.0)
			var it1 := t1 + Vector3(inset, 0.0, 0.0)
			_append_quad_colored(st_wood, ib0, it0, it1, ib1, c_hull_bot, c_hull_mid, c_hull_mid, c_hull_bot, -out_h)
			# Gunwale top rim strip
			_append_quad_colored(st_wood, t0, t1, it1, it0, c_hull_top, c_hull_top, c_hull_top, c_hull_top, Vector3.UP)

	# Stern transom bulkhead
	var st_s: Array = stations[0]
	var sb_l := Vector3(-float(st_s[1]), float(st_s[3]), float(st_s[0]))
	var sb_r := Vector3(float(st_s[1]), float(st_s[3]), float(st_s[0]))
	var st_l := Vector3(-float(st_s[2]), float(st_s[4]), float(st_s[0]))
	var st_r := Vector3(float(st_s[2]), float(st_s[4]), float(st_s[0]))
	_append_quad_colored(st_wood, sb_l, st_l, st_r, sb_r, c_hull_bot, c_hull_top, c_hull_top, c_hull_bot, Vector3.FORWARD)
	_append_quad_colored(st_wood, sb_l + Vector3(0.0, 0.0, 0.07), sb_r + Vector3(0.0, 0.0, 0.07), st_r + Vector3(0.0, 0.0, 0.07), st_l + Vector3(0.0, 0.0, 0.07), c_hull_bot, c_hull_bot, c_hull_mid, c_hull_mid, Vector3.BACK)

	# 3 Cross-thwart wooden bench seats
	var seats: Array = [
		[-1.08, 1.18, 0.30, 0.28],
		[0.00,  1.30, 0.34, 0.27],
		[0.98,  0.96, 0.28, 0.30],
	]
	for seat in seats:
		var bm := BoxMesh.new()
		bm.size = Vector3(float(seat[1]), 0.07, float(seat[2]))
		_append_mesh_colored(st_wood, bm, Transform3D(Basis.IDENTITY, Vector3(0.0, float(seat[3]), float(seat[0]))), c_hull_mid, c_seat)

	# Resting traditional wooden oar (櫓) angled across the thwarts
	var oar_shaft := CylinderMesh.new()
	oar_shaft.bottom_radius = 0.026; oar_shaft.top_radius = 0.024; oar_shaft.height = 2.45; oar_shaft.radial_segments = 6; oar_shaft.rings = 1
	var oar_b := Basis.from_euler(Vector3(PI * 0.5 - 0.06, 0.26, 0.0))
	_append_mesh_colored(st_wood, oar_shaft, Transform3D(oar_b, Vector3(0.14, 0.38, -0.15)), c_hull_mid, c_oar)
	var oar_blade := BoxMesh.new()
	oar_blade.size = Vector3(0.18, 0.03, 0.68)
	_append_mesh_colored(st_wood, oar_blade, Transform3D(Basis.from_euler(Vector3(0.06, 0.26, 0.12)), Vector3(-0.15, 0.44, -1.25)), c_hull_mid, c_oar)

	# Small curved wooden bow lantern bracket + warm glowing bow lantern
	var br_pts: Array[Vector3] = [
		Vector3(0.0, 0.58, 1.88),
		Vector3(0.0, 0.96, 2.02),
		Vector3(0.0, 1.05, 2.24),
	]
	_append_tapered_tube(st_wood, br_pts, [0.04, 0.03, 0.022], 5, c_hull_bot, c_hull_top, true)

	var lan_sp := CylinderMesh.new()
	lan_sp.bottom_radius = 0.10; lan_sp.top_radius = 0.12; lan_sp.height = 0.24; lan_sp.radial_segments = 7; lan_sp.rings = 1
	_append_mesh_colored(st_glow, lan_sp, Transform3D(Basis.IDENTITY, Vector3(0.0, 0.86, 2.24)), Color.html("#fbbf24"), Color.html("#fef08a"), 0.72, 1.00)

	var wood_mat := WafuuModels3D.make_wafuu_mat(0, is_mob, 0.70, 0.04, 0.05)
	var glow_mat := WafuuModels3D.make_glow_mat("#fef08a", 0.96)
	glow_mat.vertex_color_use_as_albedo = true
	glow_mat.albedo_color = Color.WHITE

	boat.add_child(_make_inst(st_wood.commit(), wood_mat))
	boat.add_child(_make_inst(st_glow.commit(), glow_mat))

	content_root.add_child(boat)
	sky_anim_nodes.append({
		"node": boat,
		"kind": "float_boat",
		"base_pos": water_pos,
		"base_yaw": yaw,
		"phase": 0.4,
	})
	return boat


# ==============================================================================
#  8. SWIMMING JAPANESE KOI SCHOOL (KOHAKU VERMILION-WHITE & GOLDEN YAMABUKI)
# ==============================================================================

static func _make_koi_mesh(is_golden: bool) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var c_head: Color = Color.html("#facc15") if is_golden else Color.html("#f97316")
	var c_mid: Color = Color.html("#fef08a") if is_golden else Color.html("#f8fafc")
	var c_patch: Color = Color.html("#eab308") if is_golden else Color.html("#ef4444")
	var c_tail: Color = Color.html("#fde047") if is_golden else Color.html("#fb923c")

	# Streamlined fusiform Koi body oriented nose at +Z (+0.48) -> tail at -Z (-0.52)
	var pts: Array[Vector3] = [
		Vector3(0.0, 0.0, 0.48),
		Vector3(0.0, 0.02, 0.30),
		Vector3(0.0, 0.03, 0.06),
		Vector3(0.0, 0.01, -0.22),
		Vector3(0.0, 0.0, -0.44),
	]
	var rads: Array[float] = [0.025, 0.115, 0.125, 0.072, 0.024]
	var cols: Array[Color] = [c_head, c_patch, c_mid, c_patch, c_mid]

	# Build smooth elliptical-cross-section rings
	var segs: int = 6
	var rings: Array = []
	for i: int in range(pts.size()):
		var ring := PackedVector3Array()
		ring.resize(segs)
		var r: float = rads[i]
		for s: int in range(segs):
			var a: float = (float(s) / float(segs)) * TAU
			ring[s] = pts[i] + Vector3(cos(a) * r * 0.85, sin(a) * r * 0.72, 0.0)
		rings.append(ring)

	for i: int in range(pts.size() - 1):
		var r0: PackedVector3Array = rings[i]
		var r1: PackedVector3Array = rings[i + 1]
		var c0: Color = cols[i]
		var c1: Color = cols[i + 1]
		var mid_c: Vector3 = (pts[i] + pts[i + 1]) * 0.5
		for s: int in range(segs):
			var sn: int = (s + 1) % segs
			var v00: Vector3 = r0[s]; var v01: Vector3 = r0[sn]
			var v11: Vector3 = r1[sn]; var v10: Vector3 = r1[s]
			var out_h: Vector3 = (v00 + v01 + v11 + v10) * 0.25 - mid_c
			_append_quad_colored(st, v00, v01, v11, v10, c0, c0, c1, c1, out_h)

	# Nose & tail caps
	for s: int in range(segs):
		var sn: int = (s + 1) % segs
		_append_tri_colored(st, pts[0] + Vector3(0.0, 0.0, 0.03), rings[0][s], rings[0][sn], c_head, c_head, c_head, Vector3.BACK)

	# Flowing paired pectoral fins (graceful silhouette seen from above!)
	for side: float in [-1.0, 1.0]:
		var f0 := Vector3(side * 0.08, -0.02, 0.22)
		var f1 := Vector3(side * 0.07, -0.02, 0.04)
		var f2 := Vector3(side * 0.28, -0.04, -0.02)
		var f3 := Vector3(side * 0.24, -0.03, 0.14)
		_append_quad_colored(st, f0, f3, f2, f1, c_mid, c_tail, c_tail, c_mid, Vector3.UP)
		_append_quad_colored(st, f0, f1, f2, f3, c_mid, c_mid, c_tail, c_tail, Vector3.DOWN)

	# Forked flowing caudal tail fin (horizontal + slight V-fan so visible from top camera!)
	var tb := Vector3(0.0, 0.0, -0.42)
	var tl := Vector3(-0.14, 0.02, -0.72)
	var tc := Vector3(0.0, 0.0, -0.58)
	var tr := Vector3(0.14, 0.02, -0.72)
	_append_tri_colored(st, tb, tl, tc, c_patch, c_tail, c_tail, Vector3.UP)
	_append_tri_colored(st, tb, tc, tr, c_patch, c_tail, c_tail, Vector3.UP)
	_append_tri_colored(st, tb, tc, tl, c_patch, c_tail, c_tail, Vector3.DOWN)
	_append_tri_colored(st, tb, tr, tc, c_patch, c_tail, c_tail, Vector3.DOWN)

	# Dorsal crest fin
	var d0 := Vector3(0.0, 0.08, 0.16)
	var d1 := Vector3(0.0, 0.15, -0.04)
	var d2 := Vector3(0.0, 0.05, -0.20)
	_append_tri_colored(st, d0, d1, d2, c_patch, c_tail, c_mid, Vector3.RIGHT)
	_append_tri_colored(st, d0, d2, d1, c_patch, c_mid, c_tail, Vector3.LEFT)

	return st.commit()


static func add_swimming_koi_school(
	content_root: Node3D,
	lake_center: Vector3,
	water_y: float,
	sky_anim_nodes: Array[Dictionary],
	is_mob: bool
) -> void:
	var kohaku_mesh := _make_koi_mesh(false)
	var yamabuki_mesh := _make_koi_mesh(true)

	# Use wafuu_prop surface_mode = 1 with wind_strength = 0.0 so Koi glow luminously
	# beneath the translucent water surface while keeping smooth shading.
	var koi_mat := WafuuModels3D.make_wafuu_mat(1, is_mob, 0.26, 0.10, 0.0)
	koi_mat.set_shader_parameter("wind_strength", 0.0)

	var count: int = 5 if is_mob else 8
	var swim_y: float = water_y - 0.24
	var center_at_depth := Vector3(lake_center.x, swim_y, lake_center.z)

	var orbits: Array = [
		[4.2, 3.0, 0.34, 0.00, 1.05],
		[6.4, 4.4, 0.26, 1.15, 0.94],
		[8.5, 5.6, -0.22, 2.30, 1.12],
		[5.2, 4.0, 0.31, 3.50, 0.88],
		[7.6, 5.2, -0.27, 4.75, 1.00],
		[9.6, 6.2, 0.21, 5.40, 1.16],
		[3.6, 2.6, -0.36, 0.72, 0.85],
		[6.9, 3.8, 0.29, 2.95, 0.96],
	]

	for i: int in range(count):
		var orb: Array = orbits[i]
		var koi := MeshInstance3D.new()
		koi.name = "SwimmingKoi_%d" % i
		koi.mesh = yamabuki_mesh if (i % 3 == 1) else kohaku_mesh
		koi.material_override = koi_mat
		koi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		koi.scale = Vector3.ONE * float(orb[4])
		var rx: float = float(orb[0])
		var rz: float = float(orb[1])
		var ph: float = float(orb[3])
		koi.position = Vector3(lake_center.x + cos(ph) * rx, swim_y, lake_center.z + sin(ph) * rz)
		content_root.add_child(koi)
		sky_anim_nodes.append({
			"node": koi,
			"kind": "koi_swim",
			"center": center_at_depth,
			"rx": rx,
			"rz": rz,
			"speed": float(orb[2]),
			"phase": ph,
		})


# ==============================================================================
#  9. SANDY BEACH PROPS: DRIFTWOOD, TIDE-POOL STONES, PEBBLES & LAKESIDE BENCH
# ==============================================================================

static func add_beach_props(
	arena: Arena3D,
	content_root: Node3D,
	get_height_cb: Callable,
	is_mob: bool
) -> void:
	var st_wood := SurfaceTool.new()
	st_wood.begin(Mesh.PRIMITIVE_TRIANGLES)
	var st_stone := SurfaceTool.new()
	st_stone.begin(Mesh.PRIMITIVE_TRIANGLES)

	# 1. Sun-bleached driftwood logs resting organically on the golden-white sandy beach
	var c_drift_dark := Color.html("#786b5b")
	var c_drift_lit := Color.html("#cec4b0")
	var drift_specs: Array = [
		[Vector2(38.6, 21.0), 0.42, 2.8, 0.20],
		[Vector2(47.2, 13.8), -1.15, 2.4, 0.17],
		[Vector2(37.4, 1.4),  0.68, 2.6, 0.18],
	]
	for ds in drift_specs:
		var p2: Vector2 = ds[0]
		var yaw: float = float(ds[1])
		var dlen: float = float(ds[2])
		var drad: float = float(ds[3])
		var y0: float = float(get_height_cb.call(p2.x, p2.y))
		var fwd := Vector3(cos(yaw), 0.0, sin(yaw))
		var side := Vector3(-fwd.z, 0.0, fwd.x)
		var base := Vector3(p2.x, y0 + drad * 0.35, p2.y)
		var pts: Array[Vector3] = [
			base - fwd * (dlen * 0.5) - Vector3(0.0, 0.06, 0.0),
			base - fwd * (dlen * 0.15) + side * 0.12 + Vector3(0.0, 0.05, 0.0),
			base + fwd * (dlen * 0.22) - side * 0.08 + Vector3(0.0, 0.03, 0.0),
			base + fwd * (dlen * 0.52) + side * 0.16 + Vector3(0.0, 0.14, 0.0),
		]
		_append_tapered_tube(st_wood, pts, [drad, drad * 0.88, drad * 0.72, drad * 0.42], 6, c_drift_dark, c_drift_lit, true)
		# Small weathered branch stub
		var stub_pts: Array[Vector3] = [
			pts[2],
			pts[2] + side * 0.48 + Vector3(0.0, 0.24, 0.0),
		]
		_append_tapered_tube(st_wood, stub_pts, [drad * 0.48, drad * 0.20], 5, c_drift_dark, c_drift_lit, true)

	# 2. Smooth lakeside tide-pool stones & coastal pebble clusters along the beach cove
	var c_stone_wet := Color.html("#475569")
	var c_stone_dry := Color.html("#94a3b8")
	var stone_sp := SphereMesh.new()
	stone_sp.radius = 1.0; stone_sp.height = 2.0
	stone_sp.radial_segments = 7 if is_mob else 9; stone_sp.rings = 4 if is_mob else 5

	var stone_spots: Array = [
		[Vector2(26.4, 20.6), Vector3(0.85, 0.38, 0.68), 0.4],
		[Vector2(27.5, 20.0), Vector3(0.48, 0.24, 0.42), 1.1],
		[Vector2(35.8, 21.8), Vector3(0.76, 0.32, 0.62), 2.1],
		[Vector2(45.5, 17.8), Vector3(0.95, 0.46, 0.78), 0.7],
		[Vector2(46.8, 16.9), Vector3(0.54, 0.26, 0.46), 1.9],
		[Vector2(46.2, 6.2),  Vector3(0.88, 0.42, 0.72), 2.6],
		[Vector2(41.5, 2.2),  Vector3(0.72, 0.32, 0.58), 0.9],
		[Vector2(26.2, 3.0),  Vector3(0.82, 0.36, 0.66), 1.5],
	]
	if not is_mob:
		stone_spots.append([Vector2(44.2, 19.2), Vector3(0.36, 0.16, 0.32), 0.2])
		stone_spots.append([Vector2(34.2, 22.4), Vector3(0.32, 0.15, 0.28), 1.4])
		stone_spots.append([Vector2(47.4, 10.6), Vector3(0.44, 0.20, 0.38), 2.3])
		stone_spots.append([Vector2(39.4, 1.8),  Vector3(0.38, 0.18, 0.34), 0.8])

	for idx: int in range(stone_spots.size()):
		var ss: Array = stone_spots[idx]
		var sp2: Vector2 = ss[0]
		var ssc: Vector3 = ss[1]
		var syaw: float = float(ss[2])
		var sy: float = float(get_height_cb.call(sp2.x, sp2.y))
		var xf := Transform3D(Basis(Vector3.UP, syaw).scaled(ssc), Vector3(sp2.x, sy + ssc.y * 0.25, sp2.y))
		_append_mesh_colored(st_stone, stone_sp, xf, c_stone_wet, c_stone_dry, sy - 0.1, sy + ssc.y, 0.12, float(idx) * 2.3)

	content_root.add_child(_make_inst(st_wood.commit(), WafuuModels3D.make_wafuu_mat(0, is_mob, 0.84, 0.02, 0.06)))
	content_root.add_child(_make_inst(st_stone.commit(), WafuuModels3D.make_wafuu_mat(3, is_mob, 0.62, 0.06, 0.18)))

	# 3. Cozy Thatched-Roof Lakeside Resting Bench + Lantern overlooking Moonlit Lake!
	var bench_2d := Vector2(43.2, 22.0)
	var bench_y: float = float(get_height_cb.call(bench_2d.x, bench_2d.y))
	var bench_root := Node3D.new()
	bench_root.name = "LakesideRestingBench"
	bench_root.position = Vector3(bench_2d.x, bench_y, bench_2d.y)
	# Face NW toward Moonlit Lake center (33.5, 11.5)
	bench_root.rotation.y = atan2(33.5 - bench_2d.x, 11.5 - bench_2d.y)

	# Light obstacle collider for the shelter footprint so player doesn't clip through roof posts
	arena.obstacles.append({"pos": bench_2d, "radius": 1.35, "top_y": bench_y + 2.8})

	var st_bwood := SurfaceTool.new()
	st_bwood.begin(Mesh.PRIMITIVE_TRIANGLES)
	var st_thatch := SurfaceTool.new()
	st_thatch.begin(Mesh.PRIMITIVE_TRIANGLES)
	var st_blan := SurfaceTool.new()
	st_blan.begin(Mesh.PRIMITIVE_TRIANGLES)

	var c_cedar_d := Color.html("#4a2d1b")
	var c_cedar_l := Color.html("#7c5033")
	var c_cloth_d := Color.html("#991b1b")
	var c_cloth_l := Color.html("#dc2626")
	var c_thatch_d := Color.html("#52402b")
	var c_thatch_l := Color.html("#9c835c")

	# 4 corner cedar shelter posts
	var post_cyl := CylinderMesh.new()
	post_cyl.bottom_radius = 0.095; post_cyl.top_radius = 0.085; post_cyl.height = 2.45; post_cyl.radial_segments = 6; post_cyl.rings = 1
	for sx: float in [-1.18, 1.18]:
		for sz: float in [-0.62, 0.62]:
			_append_mesh_colored(st_bwood, post_cyl, Transform3D(Basis.IDENTITY, Vector3(sx, 1.15, sz)), c_cedar_d, c_cedar_l, 0.0, 2.4)

	# Top eaves tie-beams
	var eave_x := BoxMesh.new(); eave_x.size = Vector3(2.65, 0.14, 0.14)
	for sz: float in [-0.62, 0.62]:
		_append_mesh_colored(st_bwood, eave_x, Transform3D(Basis.IDENTITY, Vector3(0.0, 2.34, sz)), c_cedar_d, c_cedar_l)
	var eave_z := BoxMesh.new(); eave_z.size = Vector3(0.14, 0.14, 1.48)
	for sx: float in [-1.18, 1.18]:
		_append_mesh_colored(st_bwood, eave_z, Transform3D(Basis.IDENTITY, Vector3(sx, 2.34, 0.0)), c_cedar_d, c_cedar_l)

	# Traditional Japanese resting bench (縁台) with crimson cloth runner
	var seat_bm := BoxMesh.new(); seat_bm.size = Vector3(2.15, 0.10, 0.84)
	_append_mesh_colored(st_bwood, seat_bm, Transform3D(Basis.IDENTITY, Vector3(0.0, 0.54, 0.0)), c_cedar_d, c_cedar_l)
	var cloth_bm := BoxMesh.new(); cloth_bm.size = Vector3(1.75, 0.04, 0.88)
	_append_mesh_colored(st_bwood, cloth_bm, Transform3D(Basis.IDENTITY, Vector3(0.0, 0.60, 0.0)), c_cloth_d, c_cloth_l)
	var leg_bm := BoxMesh.new(); leg_bm.size = Vector3(0.10, 0.56, 0.72)
	for sx: float in [-0.88, 0.88]:
		_append_mesh_colored(st_bwood, leg_bm, Transform3D(Basis.IDENTITY, Vector3(sx, 0.24, 0.0)), c_cedar_d, c_cedar_l)

	# Gently pitched Japanese thatched roof (茅葺き屋根)
	var roof_w: float = 1.68
	var roof_d: float = 1.15
	var r_eave_y: float = 2.26
	var r_peak_y: float = 3.08
	var ridge_l := Vector3(-roof_w * 0.72, r_peak_y, 0.0)
	var ridge_r := Vector3(roof_w * 0.72, r_peak_y, 0.0)
	var fl := Vector3(-roof_w, r_eave_y, roof_d)
	var fr := Vector3(roof_w, r_eave_y, roof_d)
	var bl := Vector3(-roof_w, r_eave_y, -roof_d)
	var br := Vector3(roof_w, r_eave_y, -roof_d)
	# Front & back slopes + hipped side gables
	_append_quad_colored(st_thatch, fl, fr, ridge_r, ridge_l, c_thatch_d, c_thatch_d, c_thatch_l, c_thatch_l, Vector3(0.0, 0.8, 0.6))
	_append_quad_colored(st_thatch, br, bl, ridge_l, ridge_r, c_thatch_d, c_thatch_d, c_thatch_l, c_thatch_l, Vector3(0.0, 0.8, -0.6))
	_append_tri_colored(st_thatch, bl, fl, ridge_l, c_thatch_d, c_thatch_d, c_thatch_l, Vector3(-0.8, 0.6, 0.0))
	_append_tri_colored(st_thatch, fr, br, ridge_r, c_thatch_d, c_thatch_d, c_thatch_l, Vector3(0.8, 0.6, 0.0))
	# Underside roof cap
	_append_quad_colored(st_thatch, fl, bl, br, fr, c_thatch_d.darkened(0.25), c_thatch_d.darkened(0.25), c_thatch_d.darkened(0.25), c_thatch_d.darkened(0.25), Vector3.DOWN)
	# Ridge pole timber
	var ridge_bm := BoxMesh.new(); ridge_bm.size = Vector3(roof_w * 1.54, 0.14, 0.16)
	_append_mesh_colored(st_bwood, ridge_bm, Transform3D(Basis.IDENTITY, Vector3(0.0, r_peak_y + 0.04, 0.0)), c_cedar_d, c_cedar_l)

	# Warm hanging paper lantern under the front-right eave
	var lan_c := CylinderMesh.new()
	lan_c.bottom_radius = 0.11; lan_c.top_radius = 0.13; lan_c.height = 0.28; lan_c.radial_segments = 7; lan_c.rings = 1
	_append_mesh_colored(st_blan, lan_c, Transform3D(Basis.IDENTITY, Vector3(1.18, 2.02, 0.72)), Color.html("#fbbf24"), Color.html("#fef08a"), 1.88, 2.16)

	var blan_mat := WafuuModels3D.make_glow_mat("#fef08a", 0.96)
	blan_mat.vertex_color_use_as_albedo = true
	blan_mat.albedo_color = Color.WHITE

	bench_root.add_child(_make_inst(st_bwood.commit(), WafuuModels3D.make_wafuu_mat(0, is_mob, 0.74, 0.03, 0.04)))
	bench_root.add_child(_make_inst(st_thatch.commit(), WafuuModels3D.make_wafuu_mat(0, is_mob, 0.90, 0.01, 0.10)))
	bench_root.add_child(_make_inst(st_blan.commit(), blan_mat))
	content_root.add_child(bench_root)
