"""High-detail organic 3D sculpting for all 6 Yokai Monsters and 3 Bosses."""

import math
import os
from gltf_builder import (
    GlbSceneBuilder,
    make_anime_head,
    make_box,
    make_crystal,
    make_lathe,
    make_sphere,
    make_torus,
    make_tube_along_curve,
    merge_meshes,
)
import textures as tex


def _build_organic_oni(b, root, skin_mat, face_mat, mane_mat, tiger_mat, rope_mat, gold_mat, dark_mat, iron_mat, is_general=False):
    """Sculpted muscular Oni Demon Warrior / Hellfire Shogun with anatomy, wild demon mane,
    painted fierce Oni face, sacred shimenawa rope belt, layered armor, and 24-spike iron kanabo!"""
    # Sculpted muscular torso: pinched waist, broad heroic chest & hunched demon traps
    torso = make_lathe(
        [(0.38, 0.78), (0.42, 0.96), (0.56, 1.24), (0.62, 1.46), (0.54, 1.62), (0.30, 1.72)],
        segs=28, sx=1.14, sz=0.86,
    )
    # Sculpted chest pectorals & abs contour
    pecs = []
    for side in (-1.0, 1.0):
        p = make_sphere(0.24, segs=16, rings_n=10, sx=1.18, sy=0.85, sz=0.72).translate(0.22 * side, 1.42, 0.34)
        pecs.append(p)
        ab = make_sphere(0.14, segs=12, rings_n=8, sx=1.0, sy=0.75, sz=0.55).translate(0.12 * side, 1.12, 0.36)
        pecs.append(ab)

    # Flared pleated tiger-pelt fundoshi skirt + knotted sacred shimenawa waist rope
    loin = make_lathe([(0.58, 0.38), (0.52, 0.62), (0.44, 0.84)], segs=28, pleats=10, pleat_amp=0.055)
    shimenawa = make_torus(0.48, 0.085, segs=32, tube_segs=10).translate(0.0, 0.84, 0.0)
    rope_tails = []
    for side in (-1.0, 1.0):
        rope_tails.append(make_tube_along_curve(
            [[0.12 * side, 0.84, 0.46], [0.22 * side, 0.56, 0.50], [0.18 * side, 0.32, 0.44]],
            [0.055, 0.048, 0.022], steps=10, segs=8,
        ))

    # Sculpted bent muscular demon legs + shin wraps + sandals
    legs_skin, legs_wrap = [], []
    for side in (-1.0, 1.0):
        thigh = make_tube_along_curve(
            [[0.25 * side, 0.72, 0.0], [0.30 * side, 0.44, 0.10], [0.26 * side, 0.24, 0.04]],
            [0.19, 0.16, 0.13], steps=10, segs=12,
        )
        shin = make_tube_along_curve(
            [[0.26 * side, 0.28, 0.04], [0.26 * side, 0.06, -0.02]],
            [0.135, 0.115], steps=8, segs=12,
        )
        foot = make_sphere(0.14, segs=12, rings_n=8, sx=0.95, sy=0.55, sz=1.55).translate(0.26 * side, 0.05, 0.10)
        legs_skin.append(thigh)
        legs_wrap.extend([shin, foot])

    # Sculpted Oni head with painted furious demon face + curved tusks + ridged horns
    head = make_anime_head(rx=0.41, ry=0.42, rz=0.39, segs=28, rings_n=18).translate(0.0, 2.02, 0.06)
    ears = [make_tube_along_curve([[0.36 * s, 2.00, 0.04], [0.50 * s, 2.12, -0.02]], [0.07, 0.015], [0.04, 0.01], steps=6, segs=6) for s in (-1.0, 1.0)]

    # Wild sweeping lion-like Oni Demon Mane hair!
    mane_locks = []
    for i in range(11):
        ang = -math.pi * 0.85 + (i / 10.0) * math.pi * 1.7
        sx, cz = math.sin(ang), -math.cos(ang)
        ctrl = [
            [sx * 0.26, 2.34, 0.02 + cz * 0.22],
            [sx * 0.56, 2.26 + (0.14 if is_general else 0.04), 0.0 + cz * 0.42],
            [sx * 0.68, 1.82, -0.06 + cz * 0.54],
            [sx * 0.52, 1.44, -0.08 + cz * 0.44],
        ]
        mane_locks.append(make_tube_along_curve(ctrl, [0.11, 0.13, 0.09, 0.016], [0.08, 0.09, 0.06, 0.012], steps=12, segs=8))

    # Ridged sweeping bull-like demon horns & curved ivory tusks
    horns, tusks = [], []
    for side in (-1.0, 1.0):
        hl = 0.92 if is_general else 0.58
        horns.append(make_tube_along_curve(
            [[0.22 * side, 2.28, 0.10], [0.42 * side, 2.28 + hl * 0.50, 0.18], [0.34 * side, 2.28 + hl, 0.02]],
            [0.115 if is_general else 0.085, 0.072, 0.012], steps=12, segs=10,
        ))
        tusks.append(make_tube_along_curve(
            [[0.15 * side, 1.80, 0.36], [0.17 * side, 1.88, 0.48], [0.14 * side, 1.98, 0.46]],
            [0.042, 0.032, 0.008], steps=8, segs=6,
        ))

    bm = b.add_mesh("OniBody", [
        (merge_meshes([torso] + pecs + legs_skin + ears), skin_mat),
        (head, face_mat),
        (merge_meshes(mane_locks), mane_mat),
        (loin, tiger_mat),
        (merge_meshes([shimenawa] + rope_tails), rope_mat),
        (merge_meshes(legs_wrap), dark_mat),
        (merge_meshes(horns), gold_mat),
        (merge_meshes(tusks), rope_mat),
    ])
    b.add_node("OniBodyMesh", parent=root, mesh_idx=bm)

    # Articulated muscular arms + layered demon pauldrons + 24-spike Kanabo greatclub
    for idx, side in enumerate((-1.0, 1.0)):
        arm_n = b.add_node(f"AnimPart_{idx}", parent=root, translation=(0.66 * side, 1.54, 0.02))
        arm_m = make_tube_along_curve(
            [[0.0, 0.0, 0.0], [0.14 * side, -0.34, 0.08], [0.08 * side, -0.68, 0.22]],
            [0.17, 0.16, 0.14], steps=10, segs=12,
        )
        fist = make_sphere(0.15, segs=12, rings_n=8).translate(0.08 * side, -0.70, 0.24)
        # Layered horned demon shoulder armor
        pauldrons = []
        for t_i in range(2):
            pl = make_lathe([(0.26, -0.05), (0.28, 0.05)], segs=12, sx=1.1, sz=0.9)
            pl.rotate_euler(0.0, 0.0, -0.45 * side).translate((0.06 + t_i * 0.05) * side, 0.08 - t_i * 0.12, 0.0)
            pauldrons.append(pl)
        prims = [
            (merge_meshes([arm_m, fist]), skin_mat),
            (merge_meshes(pauldrons), gold_mat if is_general else iron_mat),
        ]
        if side > 0:
            cl = 1.75 if is_general else 1.32
            club = make_lathe(
                [(0.06, 0.0), (0.075, cl * 0.30), (0.19 if is_general else 0.15, cl * 0.85), (0.14, cl * 0.96), (0.04, cl)],
                segs=8, flat=True,
            ).rotate_euler(1.22, 0.0, 0.0).translate(0.08, -0.68, 0.24)
            # Studded metal spikes spiraling around the kanabo head!
            spikes = []
            for row_t in (0.42, 0.56, 0.70, 0.84):
                rad = (0.17 if is_general else 0.135) * (0.75 + row_t * 0.32)
                cy_c = -0.68 + math.cos(1.22) * cl * row_t
                cz_c = 0.24 + math.sin(1.22) * cl * row_t
                for k in range(6):
                    a = k * math.tau / 6.0 + row_t * 3.0
                    sx_k = math.cos(a) * rad
                    sy_k = math.sin(a) * rad * math.sin(1.22)
                    sz_k = -math.sin(a) * rad * math.cos(1.22)
                    sp = make_crystal(0.036, 0.13, sides=4).translate(0.08 + sx_k, cy_c + sy_k, cz_c + sz_k)
                    spikes.append(sp)
            prims.append((club, iron_mat))
            prims.append((merge_meshes(spikes), gold_mat))
        am = b.add_mesh(f"OniArm_{idx}", prims)
        b.add_node(f"OniArmMesh_{idx}", parent=arm_n, mesh_idx=am)


def build_refined_enemy_glb(tpl_id, out_dir):
    b = GlbSceneBuilder()
    root = b.add_node("VisualRoot")

    dark_mat = b.add_material("Dark", "#1e293b", roughness=0.55, metallic=0.2)
    iron_mat = b.add_material("Iron", "#334155", roughness=0.35, metallic=0.75)
    gold_mat = b.add_material("Gold", "#fbbf24", roughness=0.22, metallic=0.85, emission="#f59e0b", emission_strength=0.25)
    rope_mat = b.add_material("Shimenawa", "#fef3c7", roughness=0.72)
    eye_mat = b.add_material("EyeGlow", "#fef08a", roughness=0.1, emission="#fef08a", emission_strength=1.45)

    if tpl_id == "chochin":
        # Haunted Festival Paper Lantern Demon: organic S-slouched pleated lantern + sculpted brow/teeth + tassels + hitodama wisp!
        lan_mat = b.add_material("Lantern", "#ffffff", roughness=0.36, emission="#ea580c", emission_strength=0.38, texture_img=tex.paint_chochin_lantern())
        tongue_mat = b.add_material("Tongue", "#ef4444", roughness=0.22)
        tassel_mat = b.add_material("Tassel", "#dc2626", roughness=0.45)
        wisp_mat = b.add_material("Hitodama", "#38bdf8", roughness=0.1, emission="#38bdf8", emission_strength=1.5)

        prof = []
        for i in range(29):
            t = i / 28.0
            y = 0.44 + t * 1.60
            r = 0.40 + 0.34 * math.sin(t * math.pi) + 0.048 * math.sin(t * 8.0 * math.tau)
            prof.append((r, y))
        lantern = make_lathe(prof, segs=36)
        cap_t = make_lathe([(0.44, 2.02), (0.48, 2.12), (0.42, 2.20), (0.30, 2.24)], segs=24)
        cap_b = make_lathe([(0.32, 0.28), (0.46, 0.36), (0.44, 0.46)], segs=24)
        bail = make_tube_along_curve([[-0.36, 2.18, 0.0], [-0.26, 2.54, 0.0], [0.0, 2.66, 0.0], [0.26, 2.54, 0.0], [0.36, 2.18, 0.0]], [0.028] * 5, steps=14, segs=8)
        # Hanging crimson festival tassel underneath
        tassel = make_tube_along_curve([[0.0, 0.28, 0.0], [0.04, 0.08, -0.04], [-0.02, -0.14, 0.02]], [0.055, 0.085, 0.03], steps=8, segs=10)
        # Sculpted angry brow ridge over front eye
        brow = make_tube_along_curve([[-0.32, 1.62, 0.64], [0.0, 1.56, 0.72], [0.32, 1.62, 0.64]], [0.055, 0.065, 0.055], steps=8, segs=8)
        # Orbiting ghostly blue hitodama flame
        wisp = make_tube_along_curve([[0.68, 2.05, 0.15], [0.72, 2.28, 0.12], [0.66, 2.50, 0.08]], [0.10, 0.075, 0.012], steps=8, segs=10)

        bm = b.add_mesh("Chochin", [
            (lantern, lan_mat),
            (merge_meshes([cap_t, cap_b, bail, brow]), dark_mat),
            (tassel, tassel_mat),
            (wisp, wisp_mat),
        ])
        b.add_node("ChochinMesh", parent=root, mesh_idx=bm)

        # Animated wagging wet curved red tongue
        tn = b.add_node("AnimPart_0", parent=root, translation=(0.0, 0.96, 0.66))
        tongue = make_tube_along_curve(
            [[0.0, 0.0, 0.0], [0.0, -0.18, 0.24], [0.04, -0.46, 0.16], [-0.02, -0.64, 0.28]],
            [0.14, 0.16, 0.12, 0.035], [0.045, 0.042, 0.035, 0.014], steps=14, segs=10,
        )
        tm = b.add_mesh("Tongue", [(tongue, tongue_mat)])
        b.add_node("TongueMesh", parent=tn, mesh_idx=tm)

    elif tpl_id == "kasa":
        # Cursed Karakasa Umbrella Spirit: scalloped 20-rib umbrella + mischievous arms + bent hopping leg + geta!
        umb_mat = b.add_material("Wagasa", "#ffffff", roughness=0.38, texture_img=tex.paint_kasa_umbrella())
        wood_mat = b.add_material("Bamboo", "#a16207", roughness=0.62)
        geta_mat = b.add_material("Geta", "#78350f", roughness=0.68)
        red_mat = b.add_material("KasaRed", "#dc2626", roughness=0.45)

        canopy = make_lathe(
            [(1.02, 1.24), (0.86, 1.48), (0.62, 1.74), (0.30, 1.98), (0.06, 2.12)],
            segs=40, pleats=20, pleat_amp=0.048,
        )
        finial = make_lathe([(0.10, 2.08), (0.06, 2.24), (0.02, 2.34)], segs=12)
        # Bent lively hopping wooden/spirit leg + sock + double-tooth geta
        leg = make_tube_along_curve(
            [[0.0, 1.42, 0.0], [0.0, 0.88, 0.16], [0.0, 0.20, 0.02]],
            [0.095, 0.09, 0.08], steps=12, segs=12,
        )
        geta = merge_meshes([
            make_box(0.34, 0.08, 0.58).translate(0.0, 0.15, 0.08),
            make_box(0.32, 0.11, 0.06).translate(0.0, 0.05, -0.08),
            make_box(0.32, 0.11, 0.06).translate(0.0, 0.05, 0.20),
        ])
        strap = make_tube_along_curve([[-0.14, 0.18, 0.08], [0.0, 0.26, 0.26], [0.14, 0.18, 0.08]], [0.032, 0.036, 0.032], steps=8, segs=6)
        bm = b.add_mesh("Kasa", [(canopy, umb_mat), (merge_meshes([leg, finial]), wood_mat), (geta, geta_mat), (strap, red_mat)])
        b.add_node("KasaMesh", parent=root, mesh_idx=bm)

        # Two mischievous animated stick-arms waving from sides!
        for idx, side in enumerate((-1.0, 1.0)):
            an = b.add_node(f"AnimPart_{idx}", parent=root, translation=(0.12 * side, 1.18, 0.04))
            arm = make_tube_along_curve(
                [[0.0, 0.0, 0.0], [0.42 * side, -0.06, 0.18], [0.64 * side, 0.18, 0.34]],
                [0.055, 0.045, 0.065], steps=10, segs=8,
            )
            am = b.add_mesh(f"KasaArm_{idx}", [(arm, wood_mat)])
            b.add_node(f"KasaArmMesh_{idx}", parent=an, mesh_idx=am)

    elif tpl_id == "aooni":
        skin_mat = b.add_material("AoOniSkin", "#ffffff", roughness=0.40, texture_img=tex.paint_lava_oni("#2563eb", "#7dd3fc"))
        face_mat = b.add_material("AoOniFace", "#ffffff", roughness=0.42, texture_img=tex.paint_oni_face("#2563eb", "#fef08a", "#1e1b4b"))
        mane_mat = b.add_material("AoOniMane", "#ffffff", roughness=0.38, texture_img=tex.paint_hair_tex("#0f172a", "#38bdf8", "#020617"))
        tiger_mat = b.add_material("TigerPelt", "#ffffff", roughness=0.58, texture_img=tex.paint_tiger_stripes())
        _build_organic_oni(b, root, skin_mat, face_mat, mane_mat, tiger_mat, rope_mat, gold_mat, dark_mat, iron_mat, is_general=False)

    elif tpl_id == "akaoni_boss":
        skin_mat = b.add_material("AkaOniSkin", "#ffffff", roughness=0.34, emission="#991b1b", emission_strength=0.28, texture_img=tex.paint_lava_oni("#dc2626", "#facc15"))
        face_mat = b.add_material("AkaOniFace", "#ffffff", roughness=0.38, emission="#7f1d1d", emission_strength=0.18, texture_img=tex.paint_oni_face("#dc2626", "#fde047", "#450a0a"))
        mane_mat = b.add_material("AkaOniMane", "#ffffff", roughness=0.32, emission="#ea580c", emission_strength=0.35, texture_img=tex.paint_hair_tex("#f97316", "#fef08a", "#9a3412"))
        tiger_mat = b.add_material("TigerPelt", "#ffffff", roughness=0.55, texture_img=tex.paint_tiger_stripes())
        _build_organic_oni(b, root, skin_mat, face_mat, mane_mat, tiger_mat, rope_mat, gold_mat, dark_mat, iron_mat, is_general=True)

    elif tpl_id == "kyubi":
        # Graceful Nine-Tails Fox Enchantress: anime kimono silhouette, tilted Kitsune mask, flowing hair, 9 dual-tier sweeping tails!
        fur_mat = b.add_material("KyubiGold", "#facc15", roughness=0.34, emission="#eab308", emission_strength=0.28)
        tip_mat = b.add_material("KyubiTip", "#fffbeb", roughness=0.35, emission="#fef08a", emission_strength=0.45)
        kimono_mat = b.add_material("KyubiKimono", "#ffffff", roughness=0.42, texture_img=tex.paint_kyubi_kimono())
        face_mat = b.add_material("KyubiFace", "#ffffff", roughness=0.45, texture_img=tex.paint_anime_face("#fff3e6", "#d97706", "#fde047", "#b45309", "#fb7185", smile="gentle"))
        mask_mat = b.add_material("SideMask", "#ffffff", roughness=0.35, texture_img=tex.paint_kitsune_mask())
        hair_mat = b.add_material("KyubiHair", "#ffffff", roughness=0.34, texture_img=tex.paint_hair_tex("#fde68a", "#ffffff", "#d97706"))
        red_mat = b.add_material("KyubiRed", "#dc2626", roughness=0.42)

        chest = make_lathe([(0.22, 0.96), (0.21, 1.14), (0.26, 1.32), (0.24, 1.48), (0.12, 1.56)], segs=24, sx=1.05, sz=0.85)
        skirt = make_lathe([(0.64, 0.14), (0.52, 0.48), (0.38, 0.78), (0.26, 0.98)], segs=36, pleats=14, pleat_amp=0.04)
        obi = make_lathe([(0.30, 0.88), (0.29, 1.04)], segs=24)
        sleeves = []
        for side in (-1.0, 1.0):
            s = make_tube_along_curve([[0.28 * side, 1.44, 0.0], [0.46 * side, 1.16, 0.10], [0.50 * side, 0.86, 0.14]], [0.12, 0.18, 0.22], [0.12, 0.20, 0.24], steps=10, segs=12)
            sleeves.append(s)

        head = make_anime_head(rx=0.34, ry=0.37, rz=0.34, segs=26, rings_n=16).translate(0.0, 1.92, 0.02)
        # Flowing golden anime hair + tilted side Kitsune mask + tall fluffy fox ears
        hair_parts = [make_sphere(0.38, segs=20, rings_n=12).translate(0.0, 1.98, -0.04)]
        for i in range(5):
            a = (i - 2) * 0.42
            hair_parts.append(make_tube_along_curve(
                [[math.sin(a) * 0.24, 2.08, -math.cos(a) * 0.28], [math.sin(a) * 0.40, 1.65, -math.cos(a) * 0.36 - 0.10], [math.sin(a) * 0.36, 1.18, -math.cos(a) * 0.32 - 0.06]],
                [0.11, 0.12, 0.02], [0.05, 0.05, 0.012], steps=10, segs=8,
            ))
        ears = [make_tube_along_curve([[0.15 * s, 2.22, 0.02], [0.28 * s, 2.54, 0.06], [0.30 * s, 2.74, 0.0]], [0.10, 0.065, 0.012], [0.06, 0.04, 0.01], steps=8, segs=8) for s in (-1.0, 1.0)]
        side_mask = make_sphere(0.22, segs=18, rings_n=10, sx=0.95, sy=1.08, sz=0.42).rotate_euler(-0.2, 0.65, -0.25).translate(0.30, 2.22, 0.14)

        bm = b.add_mesh("KyubiBody", [
            (merge_meshes([chest, skirt] + sleeves), kimono_mat),
            (obi, red_mat),
            (head, face_mat),
            (merge_meshes(hair_parts), hair_mat),
            (merge_meshes(ears), fur_mat),
            (side_mask, mask_mat),
        ])
        b.add_node("KyubiMesh", parent=root, mesh_idx=bm)

        # Dual-tier sweeping 9-tail golden fan!
        fan_n = b.add_node("AnimPart_0", parent=root, translation=(0.0, 0.96, -0.30))
        tails_body, tails_tips = [], []
        for i in range(9):
            ang = (i - 4) * 0.28
            tier_y = 0.26 if i % 2 == 0 else 0.02
            sx, cz = math.sin(ang), math.cos(ang)
            ctrl = [
                [0.0, 0.0, 0.0],
                [sx * 0.68, 0.25 + tier_y + cz * 0.25, -0.46],
                [sx * 1.24, 0.78 + tier_y + cz * 0.44, -0.72],
                [sx * 1.44, 1.18 + tier_y + cz * 0.38, -0.44],
            ]
            tails_body.append(make_tube_along_curve(ctrl, [0.075, 0.18, 0.15, 0.024], [0.075, 0.16, 0.13, 0.02], steps=12, segs=10))
            tails_tips.append(make_sphere(0.11, segs=10, rings_n=8).translate(ctrl[-1][0], ctrl[-1][1], ctrl[-1][2]))
        fm = b.add_mesh("KyubiTails", [(merge_meshes(tails_body), fur_mat), (merge_meshes(tails_tips), tip_mat)])
        b.add_node("KyubiTailsMesh", parent=fan_n, mesh_idx=fm)

    elif tpl_id == "jorogumo":
        # True Japanese Jorogumo Spider-Maiden Empress: pale kimono demon maiden upper body + barbed spider abdomen + 6 curved legs!
        abd_mat = b.add_material("SpiderVenom", "#ffffff", roughness=0.26, emission="#059669", emission_strength=0.30, texture_img=tex.paint_spider_venom())
        kim_mat = b.add_material("JoroKimono", "#4c1d95", roughness=0.40)
        face_mat = b.add_material("JoroFace", "#ffffff", roughness=0.45, texture_img=tex.paint_jorogumo_face())
        hair_mat = b.add_material("JoroHair", "#ffffff", roughness=0.32, texture_img=tex.paint_hair_tex("#1e1b4b", "#a855f7", "#09071a"))
        venom_glow = b.add_material("VenomGlow", "#4ade80", roughness=0.1, emission="#22c55e", emission_strength=1.45)

        # Glossy segmented arachnid abdomen + spiny dorsal carapace
        abd = make_lathe(
            [(0.18, -0.64), (0.56, -0.36), (0.64, 0.0), (0.54, 0.36), (0.28, 0.56)],
            segs=24, sx=0.95, sz=1.05,
        ).rotate_euler(math.pi * 0.44, 0.0, 0.0).translate(0.0, 0.96, -0.52)
        thorax = make_sphere(0.36, segs=18, rings_n=12).translate(0.0, 0.98, 0.16)
        spines = [make_crystal(0.075, 0.28, sides=5).rotate_euler(-0.3, 0.0, s * 0.35).translate(0.24 * s, 1.44, -0.42 - r * 0.28) for r in (0, 1) for s in (-1.0, 1.0)]

        # Demon Maiden Upper Torso emerging from spider thorax!
        upper = make_lathe([(0.24, 1.14), (0.20, 1.34), (0.25, 1.56), (0.14, 1.72)], segs=22, sx=1.04, sz=0.86).translate(0.0, 0.0, 0.22)
        obi = make_torus(0.24, 0.05, segs=22).translate(0.0, 1.24, 0.22)
        head = make_anime_head(rx=0.32, ry=0.35, rz=0.32, segs=24, rings_n=14).translate(0.0, 2.02, 0.24)
        hair = merge_meshes([
            make_sphere(0.36, segs=18, rings_n=10).translate(0.0, 2.08, 0.18),
            make_tube_along_curve([[0.0, 2.18, 0.02], [0.0, 1.78, -0.18], [0.0, 1.35, -0.10]], [0.22, 0.18, 0.04], [0.08, 0.07, 0.02], steps=10, segs=8),
        ])
        maiden_arms = [make_tube_along_curve([[0.28 * s, 1.58, 0.22], [0.46 * s, 1.42, 0.42], [0.36 * s, 1.32, 0.62]], [0.08, 0.07, 0.03], steps=8, segs=8) for s in (-1.0, 1.0)]

        bm = b.add_mesh("JorogumoBody", [
            (abd, abd_mat),
            (merge_meshes([thorax, upper] + maiden_arms), kim_mat),
            (head, face_mat),
            (hair, hair_mat),
            (merge_meshes([obi] + spines), venom_glow),
        ])
        b.add_node("JorogumoMesh", parent=root, mesh_idx=bm)

        # 6 Articulated Curved Barbed Spider Legs!
        idx = 0
        for side in (-1.0, 1.0):
            for row in (0, 1, 2):
                ln = b.add_node(f"AnimPart_{idx}", parent=root, translation=(0.30 * side, 0.94, 0.20 - row * 0.34))
                leg = make_tube_along_curve(
                    [[0.0, 0.0, 0.0], [0.48 * side, 0.44, 0.08 - row * 0.10], [0.94 * side, -0.18, 0.12 - row * 0.18], [1.10 * side, -0.94, 0.14 - row * 0.22]],
                    [0.085, 0.072, 0.048, 0.012], steps=12, segs=8,
                )
                joint = make_sphere(0.085, segs=10, rings_n=6).translate(0.48 * side, 0.44, 0.08 - row * 0.10)
                lm = b.add_mesh(f"SpiderLeg_{idx}", [(leg, dark_mat), (joint, venom_glow)])
                b.add_node(f"SpiderLegMesh_{idx}", parent=ln, mesh_idx=lm)
                idx += 1

    elif tpl_id == "dogu":
        # Authentic Floating Ancient Jomon Shakoki-Dogu Stone Golem with carved relief ornaments & rune core!
        clay_mat = b.add_material("DoguClay", "#ffffff", roughness=0.76, texture_img=tex.paint_dogu_clay())
        rune_mat = b.add_material("DoguRune", "#38bdf8", roughness=0.10, emission="#38bdf8", emission_strength=1.5)

        body = make_lathe(
            [(0.32, 0.22), (0.60, 0.48), (0.48, 0.78), (0.36, 0.96), (0.64, 1.28), (0.58, 1.54), (0.28, 1.66)],
            segs=28, sx=1.18, sz=0.78, pleats=8, pleat_amp=0.03,
        )
        head = make_lathe(
            [(0.28, 1.64), (0.52, 1.84), (0.50, 2.08), (0.28, 2.22), (0.44, 2.38), (0.26, 2.52), (0.10, 2.58)],
            segs=28, sx=1.18, sz=0.84, pleats=6, pleat_amp=0.04,
        )
        core_ring = make_torus(0.24, 0.055, segs=24).rotate_euler(math.pi * 0.5, 0.0, 0.0).translate(0.0, 1.24, 0.46)
        core_gem = make_crystal(0.18, 0.36, sides=6).translate(0.0, 1.24, 0.46)
        goggles, slits = [], []
        for side in (-1.0, 1.0):
            goggles.append(make_torus(0.16, 0.048, segs=22).rotate_euler(math.pi * 0.5, 0.0, 0.0).translate(0.22 * side, 1.94, 0.40))
            slits.append(make_box(0.22, 0.042, 0.05).translate(0.22 * side, 1.94, 0.45))

        bm = b.add_mesh("DoguBody", [
            (merge_meshes([body, head]), clay_mat),
            (merge_meshes([core_ring] + goggles), gold_mat),
            (merge_meshes([core_gem] + slits), rune_mat),
        ])
        b.add_node("DoguMesh", parent=root, mesh_idx=bm)

        for idx, side in enumerate((-1.0, 1.0)):
            an = b.add_node(f"AnimPart_{idx}", parent=root, translation=(0.94 * side, 1.24, 0.10))
            arm = make_lathe([(0.14, -0.46), (0.26, -0.14), (0.28, 0.22), (0.14, 0.44)], segs=16, pleats=6, pleat_amp=0.05)
            ring = make_torus(0.24, 0.032, segs=18).translate(0.0, 0.0, 0.0)
            am = b.add_mesh(f"DoguArm_{idx}", [(arm, clay_mat), (ring, rune_mat)])
            b.add_node(f"DoguArmMesh_{idx}", parent=an, mesh_idx=am)

    elif tpl_id == "tengu_boss":
        # Majestic Great Tengu Warlord: sculpted Yamabushi robe, white bonten pom-poms, fierce red mask + long nose,
        # flowing white hair & beard, double-tier sculpted feathered wings, and red-white feathered Hauchiwa war fan!
        robe_mat = b.add_material("TenguRobe", "#3730a3", roughness=0.44)
        face_mat = b.add_material("TenguFace", "#ffffff", roughness=0.38, texture_img=tex.paint_tengu_face())
        red_mat = b.add_material("TenguRed", "#dc2626", roughness=0.38)
        white_mat = b.add_material("TenguWhite", "#f8fafc", roughness=0.45)
        wing_mat = b.add_material("TenguWing", "#0f172a", roughness=0.46, metallic=0.18)

        chest = make_lathe([(0.34, 0.96), (0.38, 1.24), (0.44, 1.48), (0.22, 1.66)], segs=26, sx=1.10, sz=0.88)
        hakama = make_lathe([(0.68, 0.24), (0.56, 0.62), (0.42, 0.98)], segs=36, pleats=14, pleat_amp=0.045)
        sash = make_torus(0.42, 0.068, segs=26).translate(0.0, 1.00, 0.0)
        # Iconic Yamabushi Yuigesa white pom-poms (bonten) across chest!
        pompoms = []
        for row_y, ox in [(1.42, 0.24), (1.24, 0.20), (1.08, 0.16)]:
            for side in (-1.0, 1.0):
                pompoms.append(make_sphere(0.085, segs=12, rings_n=8).translate(ox * side, row_y, 0.36))
        # Tall single-tooth Tengu geta sandals
        getas = [merge_meshes([
            make_box(0.24, 0.06, 0.38).translate(0.22 * s, 0.22, 0.06),
            make_box(0.22, 0.22, 0.06).translate(0.22 * s, 0.11, 0.06),
        ]) for s in (-1.0, 1.0)]

        head = make_anime_head(rx=0.40, ry=0.42, rz=0.40, segs=28, rings_n=16).translate(0.0, 2.02, 0.02)
        nose = make_tube_along_curve([[0.0, 1.98, 0.34], [0.0, 1.98, 0.62], [0.0, 1.95, 0.88]], [0.095, 0.072, 0.042], steps=10, segs=12)
        tokin = make_lathe([(0.14, 2.38), (0.17, 2.62), (0.12, 2.66)], segs=8, flat=True)
        # Wild sculpted white tengu hair + long flowing beard
        white_locks = [make_tube_along_curve([[0.0, 1.72, 0.28], [0.0, 1.38, 0.38], [0.0, 1.02, 0.32]], [0.16, 0.12, 0.022], [0.06, 0.05, 0.014], steps=10, segs=8)]
        for i in range(7):
            a = -math.pi * 0.72 + (i / 6.0) * math.pi * 1.44
            white_locks.append(make_tube_along_curve(
                [[math.sin(a) * 0.28, 2.28, -math.cos(a) * 0.24], [math.sin(a) * 0.54, 1.98, -math.cos(a) * 0.44], [math.sin(a) * 0.48, 1.54, -math.cos(a) * 0.40]],
                [0.10, 0.11, 0.018], [0.06, 0.06, 0.012], steps=10, segs=8,
            ))

        # Sculpted Red-and-White Feathered Hauchiwa War Fan held in right hand!
        fan_leaves = []
        for k in range(7):
            fa = (k - 3) * 0.24
            leaf = make_tube_along_curve(
                [[0.64, 1.24, 0.34], [0.64 + math.sin(fa) * 0.36, 1.24 + math.cos(fa) * 0.36, 0.42], [0.64 + math.sin(fa) * 0.68, 1.24 + math.cos(fa) * 0.68, 0.46]],
                [0.04, 0.085, 0.02], [0.02, 0.025, 0.01], steps=8, segs=6,
            )
            fan_leaves.append(leaf)

        bm = b.add_mesh("TenguBody", [
            (merge_meshes([chest, hakama]), robe_mat),
            (sash, gold_mat),
            (head, face_mat),
            (merge_meshes([nose] + fan_leaves + getas), red_mat),
            (tokin, dark_mat),
            (merge_meshes(pompoms + white_locks), white_mat),
        ])
        b.add_node("TenguMesh", parent=root, mesh_idx=bm)

        # Double-layered sculpted curved Raven Wings (8 primary + 6 secondary feathers per wing!)
        for idx, side in enumerate((-1.0, 1.0)):
            wn = b.add_node(f"AnimPart_{idx}", parent=root, translation=(0.30 * side, 1.56, -0.32))
            feathers = []
            # Wing arch arm bone
            feathers.append(make_tube_along_curve(
                [[0.0, 0.0, 0.0], [0.75 * side, 0.46, -0.18], [1.45 * side, 0.64, -0.36]],
                [0.10, 0.08, 0.04], steps=10, segs=8,
            ))
            for f_i in range(8):
                ang = 0.56 - f_i * 0.20
                flen = 1.95 - f_i * 0.14
                ctrl = [
                    [0.22 * side, 0.12 - f_i * 0.04, -0.06],
                    [side * flen * 0.55, math.sin(ang) * flen * 0.55 + 0.24, -0.22],
                    [side * flen, math.sin(ang) * flen + 0.04, -0.38],
                ]
                feathers.append(make_tube_along_curve(ctrl, [0.09, 0.145, 0.02], [0.03, 0.028, 0.01], steps=10, segs=6))
            wm = b.add_mesh(f"TenguWing_{idx}", [(merge_meshes(feathers), wing_mat)])
            b.add_node(f"TenguWingMesh_{idx}", parent=wn, mesh_idx=wm)

    elif tpl_id == "orochi_boss":
        # Mythic Yamata-no-Orochi Dragon-Serpent: continuous helical coiled scaled dragon body + dorsal spine ridge +
        # 3 sculpted open-jaw horned Japanese Ryu dragon heads with glowing whiskers & jade orb!
        scale_mat = b.add_material("DragonScales", "#ffffff", roughness=0.26, metallic=0.28, emission="#047857", emission_strength=0.28, texture_img=tex.paint_dragon_scales())
        belly_mat = b.add_material("DragonBelly", "#fde68a", roughness=0.40)
        jade_mat = b.add_material("JadeOrb", "#34d399", roughness=0.08, emission="#10b981", emission_strength=1.55)
        jaw_mat = b.add_material("DragonMouth", "#991b1b", roughness=0.35)

        # Continuous organic helical coiled dragon body + tapered whip tail!
        coil_pts = []
        coil_r = []
        for i in range(28):
            t = i / 27.0
            ang = t * math.tau * 1.75
            rad = 1.15 - t * 0.58
            y = 0.22 + t * 0.92
            coil_pts.append([math.cos(ang) * rad, y, math.sin(ang) * rad])
            coil_r.append(0.10 + 0.28 * math.sin(min(1.0, t * 1.35) * math.pi * 0.85))
        coil_body = make_tube_along_curve(coil_pts, coil_r, coil_r, steps=40, segs=14)

        # Dorsal spiky dragon spine fins along the coils
        fins = []
        for i in range(4, 24, 2):
            p = coil_pts[i]
            fins.append(make_crystal(0.08, 0.30, sides=4).translate(p[0], p[1] + 0.24, p[2]))
        orb = make_sphere(0.24, segs=18, rings_n=12).translate(0.0, 2.72, 0.16)

        bm = b.add_mesh("OrochiBody", [
            (coil_body, scale_mat),
            (merge_meshes(fins), gold_mat),
            (orb, jade_mat),
        ])
        b.add_node("OrochiBodyMesh", parent=root, mesh_idx=bm)

        # 3 Fierce Sculpted Horned Japanese Ryu Dragon Heads with open fanged jaws & flowing whiskers!
        for idx, side in enumerate((-1.0, 0.0, 1.0)):
            hn = b.add_node(f"AnimPart_{idx}", parent=root, translation=(side * 0.46, 0.98, 0.06))
            h_top = 1.56 if side == 0.0 else 1.28
            neck = make_tube_along_curve(
                [[0.0, 0.0, 0.0], [side * 0.26, h_top * 0.45, -0.18], [side * 0.38, h_top * 0.82, 0.16], [side * 0.42, h_top, 0.44]],
                [0.24, 0.21, 0.19, 0.18], [0.24, 0.21, 0.19, 0.18], steps=16, segs=12,
            )
            hx, hy, hz = side * 0.42, h_top, 0.48
            # Sculpted upper dragon snout + brow ridge + open lower jaw!
            upper_jaw = make_tube_along_curve(
                [[hx, hy + 0.08, hz - 0.10], [hx, hy + 0.10, hz + 0.28], [hx, hy + 0.06, hz + 0.62]],
                [0.22, 0.18, 0.11], [0.14, 0.12, 0.08], steps=10, segs=10,
            )
            lower_jaw = make_tube_along_curve(
                [[hx, hy - 0.06, hz - 0.04], [hx, hy - 0.16, hz + 0.26], [hx, hy - 0.14, hz + 0.54]],
                [0.16, 0.13, 0.08], [0.08, 0.07, 0.05], steps=8, segs=8,
            )
            fangs = [make_crystal(0.032, 0.14, sides=4).translate(hx + 0.10 * s, hy - 0.03, hz + 0.42) for s in (-1.0, 1.0)]
            horns, whiskers, eyes = [], [], []
            for es in (-1.0, 1.0):
                # Sweeping antler-like golden dragon horns
                horns.append(make_tube_along_curve(
                    [[hx + 0.14 * es, hy + 0.18, hz - 0.06], [hx + 0.28 * es, hy + 0.48, hz - 0.28], [hx + 0.22 * es, hy + 0.72, hz - 0.44]],
                    [0.068, 0.048, 0.012], steps=10, segs=8,
                ))
                # Iconic flowing Japanese Ryu dragon whiskers (hige)!
                whiskers.append(make_tube_along_curve(
                    [[hx + 0.12 * es, hy + 0.04, hz + 0.46], [hx + 0.42 * es, hy - 0.06, hz + 0.52], [hx + 0.64 * es, hy - 0.26, hz + 0.34]],
                    [0.032, 0.022, 0.008], steps=10, segs=6,
                ))
                eyes.append(make_sphere(0.078, segs=10, rings_n=8).translate(hx + 0.17 * es, hy + 0.15, hz + 0.22))

            hm = b.add_mesh(f"OrochiHead_{idx}", [
                (merge_meshes([neck, upper_jaw]), scale_mat),
                (lower_jaw, jaw_mat),
                (merge_meshes(horns), gold_mat),
                (merge_meshes(whiskers), jade_mat),
                (merge_meshes(eyes + fangs), eye_mat),
            ])
            b.add_node(f"OrochiHeadMesh_{idx}", parent=hn, mesh_idx=hm)

    out_path = os.path.join(out_dir, f"enemy_{tpl_id}.glb")
    b.save_glb(out_path)
    return out_path
