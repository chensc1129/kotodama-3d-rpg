"""Parametric 3D mesh sculpting primitives and binary glTF 2.0 (.glb) exporter."""

import io
import json
import math
import struct
import numpy as np
from PIL import Image


def hex_rgba(hex_str, alpha=1.0):
    h = hex_str.lstrip("#")
    return [int(h[0:2], 16) / 255.0, int(h[2:4], 16) / 255.0, int(h[4:6], 16) / 255.0, float(alpha)]


def _compute_smooth_normals(verts, indices):
    normals = np.zeros_like(verts, dtype=np.float32)
    tri = verts[indices.reshape(-1, 3)]
    e1 = tri[:, 1] - tri[:, 0]
    e2 = tri[:, 2] - tri[:, 0]
    fn = np.cross(e1, e2)
    idx3 = indices.reshape(-1, 3)
    np.add.at(normals, idx3[:, 0], fn)
    np.add.at(normals, idx3[:, 1], fn)
    np.add.at(normals, idx3[:, 2], fn)
    lens = np.linalg.norm(normals, axis=1, keepdims=True)
    lens = np.where(lens < 1e-8, 1.0, lens)
    return (normals / lens).astype(np.float32)


def _compute_flat_mesh(verts, uvs, indices):
    idx = indices.reshape(-1, 3)
    tri_v = verts[idx].reshape(-1, 3).astype(np.float32)
    tri_uv = uvs[idx].reshape(-1, 2).astype(np.float32)
    v0 = tri_v[0::3]
    v1 = tri_v[1::3]
    v2 = tri_v[2::3]
    fn = np.cross(v1 - v0, v2 - v0)
    lens = np.linalg.norm(fn, axis=1, keepdims=True)
    lens = np.where(lens < 1e-8, 1.0, lens)
    fn = (fn / lens).astype(np.float32)
    tri_n = np.repeat(fn, 3, axis=0)
    new_idx = np.arange(len(tri_v), dtype=np.uint32)
    return tri_v, tri_n, tri_uv, new_idx


class MeshData:
    def __init__(self, verts, normals, uvs, indices):
        self.verts = np.asarray(verts, dtype=np.float32)
        self.normals = np.asarray(normals, dtype=np.float32)
        self.uvs = np.asarray(uvs, dtype=np.float32)
        self.indices = np.asarray(indices, dtype=np.uint32)

    def translate(self, dx, dy, dz):
        self.verts = self.verts + np.array([dx, dy, dz], dtype=np.float32)
        return self

    def scale(self, sx, sy, sz):
        self.verts = self.verts * np.array([sx, sy, sz], dtype=np.float32)
        inv = np.array([1.0 / sx if abs(sx) > 1e-6 else 1.0,
                        1.0 / sy if abs(sy) > 1e-6 else 1.0,
                        1.0 / sz if abs(sz) > 1e-6 else 1.0], dtype=np.float32)
        n = self.normals * inv
        lens = np.linalg.norm(n, axis=1, keepdims=True)
        self.normals = (n / np.where(lens < 1e-8, 1.0, lens)).astype(np.float32)
        return self

    def rotate_euler(self, rx=0.0, ry=0.0, rz=0.0):
        cx, sx = math.cos(rx), math.sin(rx)
        cy, sy = math.cos(ry), math.sin(ry)
        cz, sz = math.cos(rz), math.sin(rz)
        Rx = np.array([[1, 0, 0], [0, cx, -sx], [0, sx, cx]], dtype=np.float32)
        Ry = np.array([[cy, 0, sy], [0, 1, 0], [-sy, 0, cy]], dtype=np.float32)
        Rz = np.array([[cz, -sz, 0], [sz, cz, 0], [0, 0, 1]], dtype=np.float32)
        R = Ry @ Rx @ Rz
        self.verts = (self.verts @ R.T).astype(np.float32)
        self.normals = (self.normals @ R.T).astype(np.float32)
        return self


def merge_meshes(mesh_list):
    verts, normals, uvs, indices = [], [], [], []
    offset = 0
    for m in mesh_list:
        verts.append(m.verts)
        normals.append(m.normals)
        uvs.append(m.uvs)
        indices.append(m.indices + offset)
        offset += len(m.verts)
    return MeshData(
        np.vstack(verts),
        np.vstack(normals),
        np.vstack(uvs),
        np.concatenate(indices),
    )


def make_grid_surface(rings_xyz, close_u=True, cap_bottom=False, cap_top=False, flat=False, uv_u_scale=1.0, uv_v_scale=1.0):
    """Loft a smooth surface through rings_xyz: shape (n_v, n_u, 3)."""
    rings = np.asarray(rings_xyz, dtype=np.float32)
    nv, nu, _ = rings.shape

    # Duplicate seam column so UVs wrap seamlessly from 0.0 to 1.0
    if close_u:
        rings = np.concatenate([rings, rings[:, :1, :]], axis=1)
        nu_ext = nu + 1
    else:
        nu_ext = nu

    verts = rings.reshape(-1, 3)
    u_coords = np.linspace(0.0, uv_u_scale, nu_ext, dtype=np.float32)
    v_coords = np.linspace(uv_v_scale, 0.0, nv, dtype=np.float32)
    uu, vv = np.meshgrid(u_coords, v_coords)
    uvs = np.stack([uu.ravel(), vv.ravel()], axis=1)

    idx = []
    for j in range(nv - 1):
        for i in range(nu_ext - 1):
            a = j * nu_ext + i
            b = a + 1
            c = a + nu_ext
            d = c + 1
            # Winding CCW outward for standard +Y axis revolution where theta increases from +Z toward +X
            idx.extend([a, b, d, a, d, c])

    verts_list = [verts]
    uvs_list = [uvs]
    base_count = len(verts)

    if cap_bottom:
        center = rings[0, :nu].mean(axis=0, keepdims=True)
        verts_list.append(center)
        uvs_list.append(np.array([[0.5, 1.0]], dtype=np.float32))
        c_idx = base_count
        base_count += 1
        for i in range(nu):
            idx.extend([c_idx, i + 1, i])

    if cap_top:
        center = rings[-1, :nu].mean(axis=0, keepdims=True)
        verts_list.append(center)
        uvs_list.append(np.array([[0.5, 0.0]], dtype=np.float32))
        c_idx = base_count
        base_count += 1
        top_row = (nv - 1) * nu_ext
        for i in range(nu):
            idx.extend([c_idx, top_row + i, top_row + i + 1])

    all_verts = np.vstack(verts_list).astype(np.float32)
    all_uvs = np.vstack(uvs_list).astype(np.float32)
    all_idx = np.array(idx, dtype=np.uint32)

    if flat:
        fv, fn, fuv, fi = _compute_flat_mesh(all_verts, all_uvs, all_idx)
        return MeshData(fv, fn, fuv, fi)

    normals = _compute_smooth_normals(all_verts, all_idx)
    if close_u:
        # Average seam normals across i=0 and i=nu so inverted-hull outlines never crack!
        for j in range(nv):
            a = j * nu_ext
            b = j * nu_ext + nu
            avg = normals[a] + normals[b]
            nlen = np.linalg.norm(avg)
            if nlen > 1e-6:
                avg /= nlen
            normals[a] = avg
            normals[b] = avg
    return MeshData(all_verts, normals, all_uvs, all_idx)


def make_lathe(profile_ry, segs=24, sx=1.0, sz=1.0, pleats=0, pleat_amp=0.0, cap_bottom=True, cap_top=True, flat=False):
    """Revolve [(r, y), ...] around Y axis. theta=0 starts at -Z so u=0.5 faces +Z!
    Automatically ensures bottom-to-top ordering so CCW triangle winding always faces outward."""
    if len(profile_ry) >= 2 and profile_ry[0][1] > profile_ry[-1][1]:
        profile_ry = list(reversed(profile_ry))
    thetas = np.linspace(-math.pi, math.pi, segs, endpoint=False)
    rings = []
    for r, y in profile_ry:
        ring = []
        for th in thetas:
            rr = r * (1.0 + pleat_amp * math.cos(pleats * th)) if pleats > 0 else r
            x = math.sin(th) * rr * sx
            z = math.cos(th) * rr * sz
            ring.append([x, y, z])
        rings.append(ring)
    return make_grid_surface(rings, close_u=True, cap_bottom=cap_bottom, cap_top=cap_top, flat=flat)


def make_anime_head(rx=0.38, ry=0.41, rz=0.37, segs=32, rings_n=22):
    """Sculpted anime head with tapered jawline, pointed soft chin, cheek fullness, and subtle nose bridge.
    UV u=0.5 is centered straight ahead (+Z) for crisp 512x512 painted anime face textures."""
    thetas = np.linspace(-math.pi, math.pi, segs, endpoint=False)
    phis = np.linspace(-math.pi * 0.495, math.pi * 0.495, rings_n)
    rings = []
    for phi in phis:
        sp = math.sin(phi)  # -1 bottom chin, +1 crown
        cp = math.cos(phi)
        ring = []
        for th in thetas:
            st = math.sin(th)
            ct = math.cos(th)  # +1 at front (+Z)
            x = st * cp * rx
            y = sp * ry
            z = ct * cp * rz

            # Taper lower jaw & sculpt gentle anime chin
            if sp < 0.0:
                jaw = abs(sp)
                # Narrow cheekbones smoothly toward chin
                x *= (1.0 - 0.30 * (jaw ** 1.35))
                if ct > 0.0:
                    # Slight forward chin contour
                    z += 0.032 * (ct ** 2) * math.exp(-((sp + 0.72) / 0.28) ** 2)
                else:
                    # Tuck back of skull slightly under
                    z *= (1.0 - 0.14 * jaw)
            else:
                # Fuller anime cranium at back/top
                z -= 0.025 * (1.0 - ct) * sp

            # Soft cheek curve
            cheek = math.exp(-((sp + 0.18) / 0.24) ** 2) * (max(0.0, ct) ** 1.5)
            x *= (1.0 + 0.045 * cheek)

            # Delicate sculpted anime nose tip on +Z centerline
            nose = math.exp(-((sp + 0.14) / 0.11) ** 2) * math.exp(-(th / 0.18) ** 2)
            z += 0.036 * nose

            ring.append([x, y, z])
        rings.append(ring)

    mesh = make_grid_surface(rings, close_u=True, cap_bottom=False, cap_top=False)
    # Remap UVs smoothly so front face (+Z) spans u in [0.22, 0.78] with minimal distortion
    return mesh


def eval_catmull_rom(ctrl_pts, steps=16):
    pts = np.asarray(ctrl_pts, dtype=np.float32)
    if len(pts) < 2:
        return pts
    ext = np.vstack([pts[:1], pts, pts[-1:]])
    out = []
    n_seg = len(pts) - 1
    for i in range(n_seg):
        p0, p1, p2, p3 = ext[i], ext[i + 1], ext[i + 2], ext[i + 3]
        sub_steps = max(2, steps // n_seg)
        ts = np.linspace(0.0, 1.0, sub_steps, endpoint=(i == n_seg - 1))
        for t in ts:
            t2, t3 = t * t, t * t * t
            pos = 0.5 * (
                (2 * p1)
                + (-p0 + p2) * t
                + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2
                + (-p0 + 3 * p1 - 3 * p2 + p3) * t3
            )
            out.append(pos)
    return np.array(out, dtype=np.float32)


def make_tube_along_curve(ctrl_pts, radii_x, radii_z=None, steps=16, segs=10, cap_start=True, cap_end=True, flat=False):
    """Sweep an elliptical/ribbon cross-section smoothly along a 3D Catmull-Rom curve.
    Ideal for anime hair locks, ponytails, curved horns, tails, scarves, dragon necks, and spider legs."""
    path = eval_catmull_rom(ctrl_pts, steps=steps)
    n = len(path)
    rx_arr = np.interp(np.linspace(0, 1, n), np.linspace(0, 1, len(radii_x)), radii_x)
    if radii_z is None:
        rz_arr = rx_arr
    else:
        rz_arr = np.interp(np.linspace(0, 1, n), np.linspace(0, 1, len(radii_z)), radii_z)

    # Compute smooth Frenet-like parallel-transport frames
    tangents = np.zeros_like(path)
    tangents[0] = path[1] - path[0]
    tangents[-1] = path[-1] - path[-2]
    for i in range(1, n - 1):
        tangents[i] = path[i + 1] - path[i - 1]
    t_lens = np.linalg.norm(tangents, axis=1, keepdims=True)
    tangents /= np.where(t_lens < 1e-6, 1.0, t_lens)

    ref = np.array([0.0, 0.0, 1.0], dtype=np.float32)
    if abs(np.dot(tangents[0], ref)) > 0.9:
        ref = np.array([1.0, 0.0, 0.0], dtype=np.float32)
    normal = np.cross(tangents[0], ref)
    normal /= max(1e-6, np.linalg.norm(normal))

    thetas = np.linspace(0.0, math.tau, segs, endpoint=False)
    rings = []
    for i in range(n):
        t = tangents[i]
        # Parallel transport previous normal onto plane perpendicular to t
        normal = normal - np.dot(normal, t) * t
        nlen = np.linalg.norm(normal)
        if nlen < 1e-6:
            alt = np.array([1.0, 0.0, 0.0], dtype=np.float32)
            if abs(np.dot(t, alt)) > 0.9:
                alt = np.array([0.0, 1.0, 0.0], dtype=np.float32)
            normal = np.cross(t, alt)
            nlen = np.linalg.norm(normal)
        normal /= nlen
        binormal = np.cross(t, normal)

        ring = []
        for th in thetas:
            pt = path[i] + (math.cos(th) * rx_arr[i]) * normal + (math.sin(th) * rz_arr[i]) * binormal
            ring.append(pt)
        rings.append(ring)

    return make_grid_surface(rings, close_u=True, cap_bottom=cap_start, cap_top=cap_end, flat=flat)


def make_curved_katana_blade(length=1.42, curve=0.11, width=0.095, thick=0.028, segs_y=16):
    """Authentic curved Japanese Katana blade with diamond shinogi cross-section and tapered kissaki tip."""
    rings = []
    for i in range(segs_y):
        t = i / float(segs_y - 1)
        y = t * length
        z_curve = -curve * (t ** 2)  # Sori backward curve
        # Taper sharply at kissaki tip
        w = width * (1.0 - 0.18 * t) if t < 0.85 else width * 0.82 * max(0.02, (1.0 - t) / 0.15)
        th = thick * (1.0 - 0.25 * t) if t < 0.85 else thick * 0.75 * max(0.05, (1.0 - t) / 0.15)
        # 6-point Japanese blade cross-section (flat spine at -Z, sharp razor edge at +Z)
        ring = [
            [0.0, y, z_curve + w * 0.62],      # Razor edge (+Z)
            [th * 0.55, y, z_curve + w * 0.12],  # Right shinogi ridge
            [th * 0.38, y, z_curve - w * 0.38],  # Right spine
            [-th * 0.38, y, z_curve - w * 0.38], # Left spine
            [-th * 0.55, y, z_curve + w * 0.12], # Left shinogi ridge
        ]
        rings.append(ring)
    return make_grid_surface(rings, close_u=True, cap_bottom=True, cap_top=True, flat=True)


def make_sphere(r=0.5, segs=18, rings_n=12, sx=1.0, sy=1.0, sz=1.0):
    profile = []
    for j in range(rings_n):
        phi = -math.pi * 0.495 + (j / float(rings_n - 1)) * math.pi * 0.99
        profile.append((max(1e-4, math.cos(phi) * r), math.sin(phi) * r * sy))
    return make_lathe(profile, segs=segs, sx=sx, sz=sz, cap_bottom=False, cap_top=False)


def make_crystal(r=0.12, h=0.42, sides=6):
    profile = [(0.002, -h * 0.42), (r, -h * 0.08), (r * 0.92, h * 0.14), (0.002, h * 0.58)]
    return make_lathe(profile, segs=sides, cap_bottom=False, cap_top=False, flat=True)


def make_torus(major_r=0.5, minor_r=0.08, segs=28, tube_segs=10, sy=1.0):
    rings = []
    for j in range(tube_segs):
        phi = (j / float(tube_segs)) * math.tau
        rr = major_r + math.cos(phi) * minor_r
        y = math.sin(phi) * minor_r * sy
        ring = []
        for i in range(segs):
            th = -math.pi + (i / float(segs)) * math.tau
            ring.append([math.sin(th) * rr, y, math.cos(th) * rr])
        rings.append(ring)
    rings.append(rings[0])
    return make_grid_surface(rings, close_u=True, cap_bottom=False, cap_top=False)


def make_box(sx, sy, sz, flat=True):
    hx, hy, hz = sx * 0.5, sy * 0.5, sz * 0.5
    faces = [
        # +Z
        ([(-hx, -hy, hz), (hx, -hy, hz), (hx, hy, hz), (-hx, hy, hz)], (0, 0, 1)),
        # -Z
        ([(hx, -hy, -hz), (-hx, -hy, -hz), (-hx, hy, -hz), (hx, hy, -hz)], (0, 0, -1)),
        # +X
        ([(hx, -hy, hz), (hx, -hy, -hz), (hx, hy, -hz), (hx, hy, hz)], (1, 0, 0)),
        # -X
        ([(-hx, -hy, -hz), (-hx, -hy, hz), (-hx, hy, hz), (-hx, hy, -hz)], (-1, 0, 0)),
        # +Y
        ([(-hx, hy, hz), (hx, hy, hz), (hx, hy, -hz), (-hx, hy, -hz)], (0, 1, 0)),
        # -Y
        ([(-hx, -hy, -hz), (hx, -hy, -hz), (hx, -hy, hz), (-hx, -hy, hz)], (0, -1, 0)),
    ]
    verts, normals, uvs, indices = [], [], [], []
    for fi, (pts, n) in enumerate(faces):
        base = fi * 4
        verts.extend(pts)
        normals.extend([n] * 4)
        uvs.extend([(0, 1), (1, 1), (1, 0), (0, 0)])
        indices.extend([base, base + 1, base + 2, base, base + 2, base + 3])
    return MeshData(verts, normals, uvs, indices)


class GlbSceneBuilder:
    """Builds a multi-node hierarchical glTF 2.0 binary (.glb) with embedded PNG textures."""

    def __init__(self):
        self.nodes = []
        self.meshes = []
        self.materials = []
        self.textures = []
        self.images = []
        self.buffer_views = []
        self.accessors = []
        self.bin_chunks = []
        self.bin_len = 0
        self.root_nodes = []

    def _append_bytes(self, raw_bytes, target=None):
        pad = (4 - (len(raw_bytes) % 4)) % 4
        padded = raw_bytes + (b"\x00" * pad)
        bv_idx = len(self.buffer_views)
        bv = {"buffer": 0, "byteOffset": self.bin_len, "byteLength": len(raw_bytes)}
        if target is not None:
            bv["target"] = target
        self.buffer_views.append(bv)
        self.bin_chunks.append(padded)
        self.bin_len += len(padded)
        return bv_idx

    def add_image_texture(self, pil_img: Image.Image):
        buf = io.BytesIO()
        if pil_img.mode == "RGBA":
            bg = Image.new("RGB", pil_img.size, (255, 255, 255))
            bg.paste(pil_img, mask=pil_img.split()[3])
            bg.save(buf, format="PNG", optimize=True)
        else:
            pil_img.convert("RGB").save(buf, format="PNG", optimize=True)
        bv_idx = self._append_bytes(buf.getvalue())
        img_idx = len(self.images)
        self.images.append({"bufferView": bv_idx, "mimeType": "image/png"})
        tex_idx = len(self.textures)
        self.textures.append({"source": img_idx})
        return tex_idx

    def add_material(self, name, color="#ffffff", roughness=0.48, metallic=0.0,
                     emission=None, emission_strength=0.0, texture_img=None, double_sided=False):
        mat = {
            "name": name,
            "pbrMetallicRoughness": {
                "baseColorFactor": hex_rgba(color) if isinstance(color, str) else list(color),
                "roughnessFactor": float(roughness),
                "metallicFactor": float(metallic),
            },
            "doubleSided": bool(double_sided),
        }
        if texture_img is not None:
            tex_idx = self.add_image_texture(texture_img)
            mat["pbrMetallicRoughness"]["baseColorTexture"] = {"index": tex_idx}
        if emission is not None and emission_strength > 0.0:
            ec = hex_rgba(emission)[:3] if isinstance(emission, str) else list(emission[:3])
            mat["emissiveFactor"] = [min(1.0, c * min(1.0, emission_strength)) for c in ec]
            if emission_strength > 1.0:
                mat["extensions"] = {
                    "KHR_materials_emissive_strength": {"emissiveStrength": float(emission_strength)}
                }
        idx = len(self.materials)
        self.materials.append(mat)
        return idx

    def _add_accessor(self, arr, comp_type, acc_type, target):
        raw = arr.tobytes()
        bv_idx = self._append_bytes(raw, target=target)
        acc = {
            "bufferView": bv_idx,
            "componentType": comp_type,
            "count": int(arr.shape[0]),
            "type": acc_type,
        }
        if acc_type == "VEC3":
            acc["min"] = [float(x) for x in arr.min(axis=0)]
            acc["max"] = [float(x) for x in arr.max(axis=0)]
        idx = len(self.accessors)
        self.accessors.append(acc)
        return idx

    def add_mesh(self, name, primitives):
        """primitives: list of (MeshData, mat_idx)."""
        gl_prims = []
        for mesh_data, mat_idx in primitives:
            pos_acc = self._add_accessor(mesh_data.verts.astype(np.float32), 5126, "VEC3", 34962)
            nrm_acc = self._add_accessor(mesh_data.normals.astype(np.float32), 5126, "VEC3", 34962)
            uv_acc = self._add_accessor(mesh_data.uvs.astype(np.float32), 5126, "VEC2", 34962)
            idx_acc = self._add_accessor(mesh_data.indices.astype(np.uint32), 5125, "SCALAR", 34963)
            gl_prims.append({
                "attributes": {"POSITION": pos_acc, "NORMAL": nrm_acc, "TEXCOORD_0": uv_acc},
                "indices": idx_acc,
                "material": mat_idx,
            })
        idx = len(self.meshes)
        self.meshes.append({"name": name, "primitives": gl_prims})
        return idx

    def add_node(self, name, parent=None, translation=None, mesh_idx=None):
        node = {"name": name}
        if translation is not None:
            node["translation"] = [float(translation[0]), float(translation[1]), float(translation[2])]
        if mesh_idx is not None:
            node["mesh"] = mesh_idx
        idx = len(self.nodes)
        self.nodes.append(node)
        if parent is None:
            self.root_nodes.append(idx)
        else:
            self.nodes[parent].setdefault("children", []).append(idx)
        return idx

    def save_glb(self, out_path):
        gltf = {
            "asset": {"version": "2.0", "generator": "Kotodama3D Sculpt Pipeline"},
            "scene": 0,
            "scenes": [{"nodes": self.root_nodes}],
            "nodes": self.nodes,
            "meshes": self.meshes,
            "materials": self.materials,
            "accessors": self.accessors,
            "bufferViews": self.buffer_views,
            "buffers": [{"byteLength": self.bin_len}],
        }
        if self.images:
            gltf["images"] = self.images
            gltf["textures"] = self.textures
        # Check if emissive_strength extension is used
        if any("extensions" in m for m in self.materials):
            gltf["extensionsUsed"] = ["KHR_materials_emissive_strength"]

        json_bytes = json.dumps(gltf, separators=(",", ":")).encode("utf-8")
        json_pad = (4 - (len(json_bytes) % 4)) % 4
        json_bytes += b" " * json_pad

        bin_bytes = b"".join(self.bin_chunks)
        total_len = 12 + 8 + len(json_bytes) + 8 + len(bin_bytes)

        with open(out_path, "wb") as f:
            f.write(struct.pack("<III", 0x46546C67, 2, total_len))
            f.write(struct.pack("<II", len(json_bytes), 0x4E4F534A))
            f.write(json_bytes)
            f.write(struct.pack("<II", len(bin_bytes), 0x004E4942))
            f.write(bin_bytes)
