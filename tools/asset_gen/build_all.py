"""Builds all 17 sculpted, UV-mapped, textured glTF 2.0 (.glb) 3D models for Kotodama 3D RPG."""

import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from gltf_builder import (
    GlbSceneBuilder,
    make_anime_head,
    make_box,
    make_crystal,
    make_curved_katana_blade,
    make_lathe,
    make_sphere,
    make_torus,
    make_tube_along_curve,
    merge_meshes,
)
import textures as tex
from build_enemies import build_refined_enemy_glb

OUT_DIR = "/home/antigravity/kotodama_3d_rpg/assets/models"


# ==============================================================================
#  1. FIVE SCULPTED ANIME PLAYABLE HEROES
# ==============================================================================
def _add_curved_hair_dome_and_bangs(b, head_node, hair_mat, style):
    """Build sculpted hair crown, 7 Bezier-curved tapered bangs, and flowing side locks."""
    # Fitted anime hair dome (slightly larger than head, open on face)
    dome = make_lathe(
        [
            (0.01, 0.44), (0.28, 0.41), (0.39, 0.31), (0.425, 0.16),
            (0.425, 0.02), (0.40, -0.14), (0.34, -0.26), (0.24, -0.32),
        ],
        segs=28, sx=1.02, sz=1.06, cap_bottom=True, cap_top=True,
    ).translate(0.0, 0.39, -0.04)

    hair_parts = [dome]

    # 7 Bezier-swept anime bangs framing forehead
    bang_specs = [
        (-0.29, 0.17, -0.34, 0.31, 0.075),
        (-0.20, 0.27, -0.22, 0.37, 0.080),
        (-0.10, 0.33, -0.10, 0.40, 0.078),
        (0.00, 0.35, 0.00, 0.41, 0.082),
        (0.10, 0.33, 0.10, 0.40, 0.078),
        (0.20, 0.27, 0.22, 0.37, 0.080),
        (0.29, 0.17, 0.34, 0.31, 0.075),
    ]
    for bx, bz, tip_x, tip_z, rw in bang_specs:
        tip_y = 0.43 if abs(bx) < 0.15 else 0.36
        if style == "kickboxer" or style == "raijin":
            tip_y += 0.05
        ctrl = [
            [bx * 0.55, 0.78, bz * 0.45],
            [bx * 0.92, 0.67, bz * 0.95],
            [tip_x, tip_y, tip_z],
        ]
        hair_parts.append(
            make_tube_along_curve(ctrl, [rw * 0.85, rw, 0.012], [0.04, 0.045, 0.008], steps=10, segs=8)
        )

    # Flowing side face-framing locks
    lock_len = 0.68 if style in ("sakura", "yukionna") else 0.34
    for side in (-1.0, 1.0):
        ctrl = [
            [0.24 * side, 0.72, 0.06],
            [0.40 * side, 0.46, 0.13],
            [0.37 * side, 0.42 - lock_len * 0.55, 0.16],
            [0.32 * side, 0.42 - lock_len, 0.12],
        ]
        hair_parts.append(
            make_tube_along_curve(ctrl, [0.085, 0.09, 0.065, 0.014], [0.05, 0.055, 0.045, 0.01], steps=12, segs=8)
        )

    # Style-specific sculpted back hairstyles
    if style == "sakura":
        # Silky high curved multi-strand ponytail!
        for ox, oz, scale_l in [(0.0, 0.0, 1.0), (-0.11, -0.02, 0.86), (0.11, -0.02, 0.86)]:
            ctrl = [
                [ox * 0.3, 0.58, -0.36],
                [ox * 0.9, 0.52, -0.58 + oz],
                [ox * 1.1, 0.15, -0.66 + oz],
                [ox * 0.85, -0.32 * scale_l, -0.56 + oz],
            ]
            hair_parts.append(
                make_tube_along_curve(ctrl, [0.10, 0.14, 0.11, 0.018], [0.08, 0.11, 0.08, 0.014], steps=14, segs=10)
            )
    elif style in ("kickboxer", "raijin"):
        # Dynamic layered anime spiky hair tufts
        spikes = [
            ([0.0, 0.72, -0.02], [0.0, 0.96, 0.02], [0.0, 1.12, -0.08]),
            ([-0.18, 0.68, -0.04], [-0.34, 0.88, -0.06], [-0.46, 0.98, -0.14]),
            ([0.18, 0.68, -0.04], [0.34, 0.88, -0.06], [0.46, 0.98, -0.14]),
            ([0.0, 0.62, -0.24], [0.0, 0.76, -0.48], [0.0, 0.68, -0.66]),
            ([-0.22, 0.56, -0.22], [-0.38, 0.64, -0.42], [-0.48, 0.54, -0.56]),
            ([0.22, 0.56, -0.22], [0.38, 0.64, -0.42], [0.48, 0.54, -0.56]),
            ([-0.15, 0.38, -0.30], [-0.26, 0.32, -0.50], [-0.32, 0.18, -0.60]),
            ([0.15, 0.38, -0.30], [0.26, 0.32, -0.50], [0.32, 0.18, -0.60]),
        ]
        for p0, p1, p2 in spikes:
            hair_parts.append(make_tube_along_curve([p0, p1, p2], [0.11, 0.075, 0.012], [0.09, 0.06, 0.01], steps=8, segs=8))
    elif style == "swordsman":
        # Samurai swept back hair + tied chonmage/high ponytail
        bun = make_sphere(0.15, segs=16, rings_n=10).translate(0.0, 0.78, -0.18)
        hair_parts.append(bun)
        for ox in (-0.07, 0.0, 0.07):
            ctrl = [
                [ox * 0.4, 0.76, -0.24],
                [ox, 0.70, -0.48],
                [ox * 1.1, 0.38, -0.62],
                [ox * 0.9, 0.06, -0.56],
            ]
            hair_parts.append(make_tube_along_curve(ctrl, [0.07, 0.095, 0.075, 0.015], [0.06, 0.07, 0.055, 0.01], steps=12, segs=8))
    elif style == "yukionna":
        # Sweeping waist-length cascading silver-ice hair curtains (5 wide silky wavy ribbons)
        for i in range(5):
            ang = (i - 2) * 0.36
            sx = math.sin(ang) * 0.36
            sz = -math.cos(ang) * 0.36
            ctrl = [
                [sx * 0.7, 0.55, sz * 0.75],
                [sx * 1.08, 0.18, sz * 1.05 - 0.08],
                [sx * 1.25, -0.36, sz * 1.12 - 0.16],
                [sx * 1.15, -0.82, sz * 1.05 - 0.10],
            ]
            hair_parts.append(make_tube_along_curve(ctrl, [0.12, 0.145, 0.135, 0.025], [0.055, 0.06, 0.05, 0.012], steps=14, segs=8))

    hair_mesh = b.add_mesh("Hair", [(merge_meshes(hair_parts), hair_mat)])
    b.add_node("HairMesh", parent=head_node, mesh_idx=hair_mesh)


def _add_sculpted_leg(b, parent_node, style, mats):
    """Build smooth sculpted anime leg + Japanese footwear (geta/greaves/wraps)."""
    if style in ("sakura", "yukionna"):
        # Smooth tabi sock leg + wooden double-toothed geta sandal
        leg = make_lathe(
            [(0.095, 0.0), (0.092, -0.20), (0.085, -0.38), (0.078, -0.54), (0.072, -0.62)],
            segs=16,
        )
        sole = make_box(0.17, 0.055, 0.30).translate(0.0, -0.64, 0.04)
        tooth1 = make_box(0.16, 0.06, 0.04).translate(0.0, -0.69, -0.04)
        tooth2 = make_box(0.16, 0.06, 0.04).translate(0.0, -0.69, 0.11)
        strap = make_tube_along_curve(
            [[-0.07, -0.62, 0.03], [0.0, -0.57, 0.15], [0.07, -0.62, 0.03]],
            [0.022, 0.024, 0.022], steps=8, segs=6,
        )
        m = b.add_mesh("Leg", [
            (leg, mats["white"]),
            (merge_meshes([sole, tooth1, tooth2]), mats["wood"]),
            (strap, mats["primary"]),
        ])
        b.add_node("LegMesh", parent=parent_node, mesh_idx=m)
    elif style == "kickboxer":
        # Sculpted athletic leg + Muay Thai wrapped shin & ankle wind ring
        thigh = make_lathe([(0.115, 0.0), (0.105, -0.22), (0.092, -0.34)], segs=16)
        shin = make_lathe([(0.094, -0.33), (0.098, -0.46), (0.080, -0.62)], segs=16)
        foot = make_sphere(0.10, segs=14, rings_n=8, sx=0.85, sy=0.55, sz=1.45).translate(0.0, -0.66, 0.06)
        ring = make_torus(0.125, 0.024, segs=22).translate(0.0, -0.50, 0.0)
        m = b.add_mesh("Leg", [
            (thigh, mats["skin"]),
            (merge_meshes([shin, foot]), mats["accent"]),
            (ring, mats["glow"]),
        ])
        b.add_node("LegMesh", parent=parent_node, mesh_idx=m)
    else:
        # Armored samurai greaves / sleek shinobi boots
        thigh = make_lathe([(0.115, 0.0), (0.102, -0.28), (0.090, -0.36)], segs=16)
        greave = make_lathe([(0.096, -0.34), (0.104, -0.48), (0.088, -0.64)], segs=16)
        knee = make_sphere(0.10, segs=12, rings_n=8, sx=1.0, sy=0.9, sz=0.65).translate(0.0, -0.35, 0.07)
        boot = make_sphere(0.105, segs=14, rings_n=8, sx=0.85, sy=0.55, sz=1.48).translate(0.0, -0.66, 0.06)
        m = b.add_mesh("Leg", [
            (thigh, mats["dark"]),
            (merge_meshes([greave, boot]), mats["armor"]),
            (knee, mats["gold"]),
        ])
        b.add_node("LegMesh", parent=parent_node, mesh_idx=m)


def _add_sculpted_arm(b, parent_node, side, style, mats):
    """Build smooth articulated anime arm + curved furisode sleeve / layered sode armor / wraps."""
    prims = []
    if style in ("sakura", "yukionna"):
        # Smooth shoulder + gracefully flared wide Japanese Furisode sleeve + trim + sculpted hand
        sleeve = make_lathe(
            [
                (0.11, 0.04), (0.12, -0.06), (0.145, -0.22),
                (0.19, -0.40), (0.21, -0.50),
            ],
            segs=18, sx=0.92, sz=1.28,
        ).translate(0.03 * side, 0.0, -0.02)
        cuff = make_torus(0.185, 0.032, segs=22).scale(0.92, 1.0, 1.28).translate(0.03 * side, -0.49, -0.02)
        hand = make_sphere(0.078, segs=14, rings_n=8, sx=0.9, sy=1.1, sz=0.9).translate(0.0, -0.54, 0.03)
        prims.extend([(sleeve, mats["sleeve"]), (cuff, mats["primary"]), (hand, mats["skin"])])
    elif style == "kickboxer":
        upper = make_lathe([(0.11, 0.04), (0.10, -0.14), (0.088, -0.28)], segs=16)
        wrap = make_lathe([(0.092, -0.27), (0.098, -0.40), (0.086, -0.52)], segs=16)
        fist = make_sphere(0.095, segs=14, rings_n=8).translate(0.0, -0.54, 0.03)
        knuckle = make_box(0.12, 0.08, 0.12).translate(0.0, -0.54, 0.07)
        prims.extend([(upper, mats["skin"]), (merge_meshes([wrap, fist]), mats["accent"]), (knuckle, mats["gold"])])
    elif style == "swordsman":
        # Layered 3-tier curved Samurai Sode Pauldron + Armored Gauntlet
        sodes = []
        for tier in range(3):
            plate = make_box(0.24 + tier * 0.02, 0.085, 0.28).rotate_euler(0.0, 0.0, -0.28 * side)
            plate.translate((0.06 + tier * 0.025) * side, 0.02 - tier * 0.09, 0.0)
            sodes.append(plate)
        arm = make_lathe([(0.095, 0.0), (0.088, -0.28)], segs=14)
        gauntlet = make_lathe([(0.098, -0.26), (0.102, -0.42), (0.086, -0.52)], segs=14)
        hand = make_sphere(0.08, segs=12, rings_n=8).translate(0.0, -0.54, 0.02)
        prims.extend([(merge_meshes(sodes), mats["armor"]), (arm, mats["dark"]), (gauntlet, mats["armor"]), (hand, mats["dark"])])
    else:  # raijin
        pauldron = make_sphere(0.135, segs=14, rings_n=10, sx=1.1, sy=0.85, sz=1.15).translate(0.03 * side, 0.0, 0.0)
        arm = make_lathe([(0.09, 0.0), (0.082, -0.32)], segs=14)
        bracer = make_lathe([(0.094, -0.30), (0.098, -0.46), (0.084, -0.52)], segs=14)
        hand = make_sphere(0.078, segs=12, rings_n=8).translate(0.0, -0.54, 0.02)
        prims.extend([
            (pauldron, mats["gold"] if side > 0 else mats["dark"]),
            (arm, mats["suit"]),
            (bracer, mats["gold"]),
            (hand, mats["dark"]),
        ])
        if side < 0:
            kunai = make_crystal(0.045, 0.56, sides=4).rotate_euler(math.pi * 0.5, 0.0, 0.0).translate(0.0, -0.54, 0.26)
            prims.append((kunai, mats["glow"]))

    m = b.add_mesh("Arm", prims)
    b.add_node("ArmMesh", parent=parent_node, mesh_idx=m)


def _add_sculpted_weapon(b, weapon_node, style, mats):
    """Build authentic curved Japanese katana, crystalline ice naginata, or blazing wind-tonfa.
    Separates 'WeaponBlade' node so Godot dynamically syncs equipped weapon blade color & glow!"""
    if style == "yukionna":
        staff = make_lathe([(0.028, -0.35), (0.032, 0.92)], segs=12)
        guard = make_crystal(0.13, 0.20, sides=6).translate(0.0, 0.96, 0.0)
        hilt_m = b.add_mesh("WeaponHilt", [(staff, mats["white"]), (guard, mats["gold"])])
        b.add_node("WeaponHilt", parent=weapon_node, mesh_idx=hilt_m)

        blade = make_crystal(0.095, 1.05, sides=6).scale(0.45, 1.0, 1.25).translate(0.0, 1.48, 0.0)
        blade_m = b.add_mesh("WeaponBlade", [(blade, mats["blade"])])
        b.add_node("WeaponBlade", parent=weapon_node, mesh_idx=blade_m)
    elif style == "kickboxer":
        grip = make_lathe([(0.038, -0.18), (0.040, 0.20)], segs=12)
        guard = make_torus(0.09, 0.028, segs=18).translate(0.0, 0.20, 0.0)
        hilt_m = b.add_mesh("WeaponHilt", [(grip, mats["hilt"]), (guard, mats["gold"])])
        b.add_node("WeaponHilt", parent=weapon_node, mesh_idx=hilt_m)

        blade = make_curved_katana_blade(length=1.08, curve=0.06, width=0.13, thick=0.042).translate(0.0, 0.22, 0.0)
        blade_m = b.add_mesh("WeaponBlade", [(blade, mats["blade"])])
        b.add_node("WeaponBlade", parent=weapon_node, mesh_idx=blade_m)
    else:
        hilt = make_lathe([(0.042, -0.24), (0.038, 0.20)], segs=14, sx=0.82, sz=1.18)
        pommel = make_sphere(0.046, segs=12, rings_n=8).translate(0.0, -0.25, 0.0)
        tsuba = make_lathe([(0.125, 0.19), (0.132, 0.21), (0.125, 0.23)], segs=20)
        habaki = make_box(0.055, 0.08, 0.105).translate(0.0, 0.26, 0.01)
        hilt_m = b.add_mesh("WeaponHilt", [
            (hilt, mats["hilt"]),
            (merge_meshes([pommel, tsuba, habaki]), mats["gold"]),
        ])
        b.add_node("WeaponHilt", parent=weapon_node, mesh_idx=hilt_m)

        blade = make_curved_katana_blade(length=1.45, curve=0.12, width=0.095, thick=0.028).translate(0.0, 0.26, 0.0)
        blade_m = b.add_mesh("WeaponBlade", [(blade, mats["blade"])])
        b.add_node("WeaponBlade", parent=weapon_node, mesh_idx=blade_m)


def build_hero_glb(style):
    b = GlbSceneBuilder()

    # Materials & supersampled custom textures per hero
    face_cfgs = {
        "sakura": dict(skin_hex="#ffe4d4", iris_top="#be123c", iris_bot="#fda4af", brow_hex="#3b1d2a", blush_hex="#fb7185", smile="gentle"),
        "kickboxer": dict(skin_hex="#f7d2b5", iris_top="#b45309", iris_bot="#fde047", brow_hex="#1e293b", blush_hex="#f97316", fierce=True, bandaid=True, smile="grin"),
        "swordsman": dict(skin_hex="#fbe0cc", iris_top="#991b1b", iris_bot="#fb923c", brow_hex="#0f172a", blush_hex="#f87171", fierce=True, smile="stoic"),
        "raijin": dict(skin_hex="#fde2ce", iris_top="#ca8a04", iris_bot="#fef08a", brow_hex="#a16207", blush_hex="#facc15", fierce=True, ninja_mask_hex="#1e1b4b"),
        "yukionna": dict(skin_hex="#fff0ee", iris_top="#0284c7", iris_bot="#a5f3fc", brow_hex="#64748b", blush_hex="#7dd3fc", smile="gentle"),
    }
    hair_cfgs = {
        "sakura": ("#4c1d32", "#f472b6", "#230b17"),
        "kickboxer": ("#1e293b", "#64748b", "#090d16"),
        "swordsman": ("#18181b", "#52525b", "#09090b"),
        "raijin": ("#facc15", "#fef9c3", "#b45309"),
        "yukionna": ("#bae6fd", "#ffffff", "#38bdf8"),
    }
    primary_hex = {
        "sakura": "#e11d48",
        "kickboxer": "#2563eb",
        "swordsman": "#dc2626",
        "raijin": "#eab308",
        "yukionna": "#06b6d4",
    }[style]

    mats = {
        "face": b.add_material("Face", "#ffffff", roughness=0.55, texture_img=tex.paint_anime_face(**face_cfgs[style])),
        "skin": b.add_material("Skin", face_cfgs[style]["skin_hex"], roughness=0.55),
        "hair": b.add_material("Hair", "#ffffff", roughness=0.35, texture_img=tex.paint_hair_tex(*hair_cfgs[style])),
        "primary": b.add_material("Primary", primary_hex, roughness=0.42),
        "white": b.add_material("White", "#f8fafc", roughness=0.48),
        "dark": b.add_material("Dark", "#1e293b", roughness=0.58, metallic=0.15),
        "gold": b.add_material("Gold", "#fbbf24", roughness=0.22, metallic=0.85, emission="#f59e0b", emission_strength=0.22),
        "wood": b.add_material("Wood", "#7c2d12", roughness=0.72),
        "hilt": b.add_material("Hilt", "#ffffff", roughness=0.55, texture_img=tex.paint_katana_hilt()),
        "blade": b.add_material("Blade", "#e2e8f0", roughness=0.16, metallic=0.88, emission="#94a3b8", emission_strength=0.4),
        "accent": b.add_material("Accent", "#ef4444", roughness=0.45, emission="#dc2626", emission_strength=0.2),
        "glow": b.add_material("Glow", "#38bdf8" if style != "raijin" else "#facc15", roughness=0.18, emission="#38bdf8" if style != "raijin" else "#facc15", emission_strength=1.35),
        "armor": b.add_material("Armor", "#ffffff", roughness=0.32, metallic=0.55, texture_img=tex.paint_samurai_armor()),
        "suit": b.add_material("Suit", "#ffffff", roughness=0.45, texture_img=tex.paint_raijin_suit()),
        "sleeve": b.add_material("Sleeve", "#ffffff", roughness=0.42, texture_img=tex.paint_yukionna_kimono() if style == "yukionna" else None),
    }

    body_pivot = b.add_node("BodyPivot")

    # ==================== SCULPTED ANIME TORSO & OUTFIT ====================
    neck = make_lathe([(0.105, 1.48), (0.092, 1.56), (0.100, 1.65)], segs=16)
    torso_prims = [(neck, mats["skin"])]

    if style == "sakura":
        hakama_mat = b.add_material("SakuraHakama", "#ffffff", roughness=0.44, texture_img=tex.paint_sakura_hakama())
        # Sculpted feminine anime upper kimono
        chest = make_lathe(
            [(0.23, 0.94), (0.21, 1.08), (0.26, 1.24), (0.27, 1.38), (0.22, 1.48), (0.12, 1.52)],
            segs=24, sx=1.08, sz=0.86,
        )
        # Fluted pleated Japanese Hakama skirt with 14 cloth folds!
        skirt = make_lathe(
            [(0.58, 0.28), (0.52, 0.44), (0.43, 0.64), (0.33, 0.84), (0.26, 0.96)],
            segs=42, pleats=14, pleat_amp=0.045,
        )
        obi = make_lathe([(0.295, 0.87), (0.285, 0.98), (0.295, 1.08)], segs=24, sx=1.06, sz=0.92)
        cord = make_torus(0.295, 0.022, segs=28).scale(1.06, 1.0, 0.92).translate(0.0, 0.98, 0.0)
        # Sculpted V-collar lapels + big curved back Obi bow
        lapels = []
        for side in (-1.0, 1.0):
            lapels.append(make_tube_along_curve(
                [[0.12 * side, 1.50, 0.06], [0.11 * side, 1.36, 0.22], [0.02 * side, 1.18, 0.23]],
                [0.042, 0.045, 0.036], [0.02, 0.025, 0.02], steps=8, segs=8,
            ))
            # Back ribbon loop + flowing tail
            lapels.append(make_tube_along_curve(
                [[0.0, 0.98, -0.28], [0.24 * side, 1.06, -0.38], [0.28 * side, 0.92, -0.36], [0.04 * side, 0.95, -0.29]],
                [0.05, 0.095, 0.085, 0.045], [0.03, 0.035, 0.035, 0.03], steps=12, segs=8,
            ))
            lapels.append(make_tube_along_curve(
                [[0.06 * side, 0.94, -0.31], [0.15 * side, 0.72, -0.40], [0.18 * side, 0.48, -0.36]],
                [0.06, 0.075, 0.055], [0.02, 0.02, 0.015], steps=10, segs=8,
            ))
        torso_prims.extend([
            (chest, mats["white"]),
            (skirt, hakama_mat),
            (obi, mats["primary"]),
            (cord, mats["gold"]),
            (merge_meshes(lapels), mats["primary"]),
        ])

    elif style == "kickboxer":
        gi_mat = b.add_material("KickboxerGi", "#ffffff", roughness=0.48, texture_img=tex.paint_kickboxer_gi())
        chest = make_lathe(
            [(0.24, 0.94), (0.26, 1.10), (0.31, 1.28), (0.33, 1.42), (0.24, 1.50), (0.12, 1.53)],
            segs=24, sx=1.10, sz=0.84,
        )
        shorts = make_lathe([(0.36, 0.56), (0.33, 0.72), (0.28, 0.92)], segs=24, sx=1.08, sz=0.90)
        belt = make_lathe([(0.295, 0.88), (0.29, 0.95), (0.295, 1.02)], segs=24, sx=1.08, sz=0.88)
        buckle = make_box(0.18, 0.13, 0.07).translate(0.0, 0.95, 0.27)
        # White open gi collar + hanging belt tails
        collars = []
        tails = []
        for side in (-1.0, 1.0):
            collars.append(make_tube_along_curve(
                [[0.12 * side, 1.51, 0.06], [0.13 * side, 1.34, 0.24], [0.05 * side, 1.02, 0.25]],
                [0.045, 0.050, 0.042], [0.025, 0.028, 0.024], steps=10, segs=8,
            ))
            tails.append(make_tube_along_curve(
                [[0.06 * side, 0.92, 0.27], [0.14 * side, 0.72, 0.30], [0.18 * side, 0.54, 0.28]],
                [0.042, 0.048, 0.036], [0.018, 0.018, 0.014], steps=8, segs=6,
            ))
        chest_skin = make_sphere(0.17, segs=14, rings_n=10, sx=0.82, sy=1.25, sz=0.65).translate(0.0, 1.32, 0.21)
        torso_prims.extend([
            (merge_meshes([chest, shorts]), gi_mat),
            (chest_skin, mats["skin"]),
            (merge_meshes(collars), mats["white"]),
            (merge_meshes([belt] + tails), mats["accent"]),
            (buckle, mats["gold"]),
        ])

    elif style == "swordsman":
        under = make_lathe([(0.44, 0.44), (0.35, 0.72), (0.27, 0.98), (0.29, 1.34), (0.14, 1.51)], segs=24, sx=1.06, sz=0.88)
        cuirass = make_lathe([(0.30, 0.96), (0.31, 1.18), (0.33, 1.38), (0.26, 1.48)], segs=24, sx=1.10, sz=0.88)
        # 6 Sculpted Kusazuri armored hip tassets
        tassets = []
        for i in range(6):
            ang = (i / 6.0) * math.tau
            p = make_box(0.24, 0.40, 0.055).rotate_euler(-0.22, ang, 0.0)
            p.translate(math.sin(ang) * 0.36, 0.74, math.cos(ang) * 0.34)
            tassets.append(p)
        belt = make_torus(0.31, 0.045, segs=24).scale(1.08, 1.0, 0.88).translate(0.0, 0.96, 0.0)
        crest = make_torus(0.085, 0.022, segs=20).rotate_euler(math.pi * 0.5, 0.0, 0.0).translate(0.0, 1.30, 0.29)
        # Curved Scabbard (Saya) slung at left hip
        saya = make_tube_along_curve(
            [[-0.32, 0.94, 0.28], [-0.36, 0.86, -0.22], [-0.38, 0.74, -0.78]],
            [0.036, 0.034, 0.030], [0.052, 0.048, 0.042], steps=10, segs=10,
        )
        torso_prims.extend([
            (merge_meshes([under, saya]), mats["dark"]),
            (merge_meshes([cuirass] + tassets), mats["armor"]),
            (merge_meshes([belt, crest]), mats["gold"]),
        ])

    elif style == "raijin":
        chest = make_lathe(
            [(0.23, 0.92), (0.24, 1.12), (0.29, 1.32), (0.30, 1.44), (0.21, 1.50), (0.12, 1.53)],
            segs=24, sx=1.08, sz=0.85,
        )
        # Split curved shinobi coat tails
        coat_parts = []
        for side in (-1.0, 1.0):
            coat_parts.append(make_tube_along_curve(
                [[0.15 * side, 0.94, -0.18], [0.22 * side, 0.66, -0.28], [0.24 * side, 0.38, -0.34]],
                [0.14, 0.16, 0.11], [0.035, 0.032, 0.022], steps=10, segs=8,
            ))
        # Golden X-harness straps + belt
        straps = []
        for side in (-1.0, 1.0):
            straps.append(make_tube_along_curve(
                [[0.22 * side, 1.46, 0.05], [0.0, 1.24, 0.25], [-0.22 * side, 0.98, 0.14]],
                [0.038, 0.042, 0.038], [0.018, 0.020, 0.018], steps=10, segs=6,
            ))
        belt = make_torus(0.26, 0.042, segs=24).scale(1.06, 1.0, 0.88).translate(0.0, 0.94, 0.0)
        torso_prims.extend([
            (merge_meshes([chest] + coat_parts), mats["suit"]),
            (merge_meshes(straps + [belt]), mats["gold"]),
        ])

    elif style == "yukionna":
        kimono_mat = mats["sleeve"]
        ice_glow = b.add_material("IceCrystal", "#a5f3fc", roughness=0.10, metallic=0.25, emission="#22d3ee", emission_strength=0.75)
        chest = make_lathe(
            [(0.22, 0.94), (0.21, 1.12), (0.26, 1.28), (0.26, 1.42), (0.20, 1.49), (0.12, 1.52)],
            segs=24, sx=1.06, sz=0.85,
        )
        # Sweeping multi-pleat frost kimono gown
        gown = make_lathe(
            [(0.62, 0.20), (0.54, 0.42), (0.42, 0.68), (0.31, 0.88), (0.25, 0.98)],
            segs=42, pleats=12, pleat_amp=0.038,
        )
        obi = make_lathe([(0.285, 0.88), (0.278, 0.98), (0.285, 1.08)], segs=24, sx=1.05, sz=0.90)
        # Crystalline back ribbon crystals
        bow_crystals = [
            make_crystal(0.11, 0.34, sides=6).rotate_euler(0.0, 0.0, 0.95).translate(0.16, 0.98, -0.32),
            make_crystal(0.11, 0.34, sides=6).rotate_euler(0.0, 0.0, -0.95).translate(-0.16, 0.98, -0.32),
            make_crystal(0.09, 0.28, sides=6).translate(0.0, 0.98, -0.34),
        ]
        torso_prims.extend([
            (merge_meshes([chest, gown]), kimono_mat),
            (obi, mats["primary"]),
            (merge_meshes(bow_crystals), ice_glow),
        ])

    body_mesh = b.add_mesh("TorsoOutfit", torso_prims)
    b.add_node("TorsoMesh", parent=body_pivot, mesh_idx=body_mesh)

    # ==================== HEAD PIVOT (SCULPTED ANIME HEAD + EARS + HAIR + HEADGEAR) ====================
    head_pivot = b.add_node("HeadPivot", parent=body_pivot, translation=(0.0, 1.62, 0.0))

    head_geo = make_anime_head(rx=0.37, ry=0.40, rz=0.36).translate(0.0, 0.36, 0.0)
    ears = [
        make_sphere(0.075, segs=12, rings_n=8, sx=0.45, sy=1.1, sz=0.8).translate(-0.36, 0.34, 0.0),
        make_sphere(0.075, segs=12, rings_n=8, sx=0.45, sy=1.1, sz=0.8).translate(0.36, 0.34, 0.0),
    ]
    head_mesh = b.add_mesh("Head", [(head_geo, mats["face"]), (merge_meshes(ears), mats["skin"])])
    b.add_node("HeadMesh", parent=head_pivot, mesh_idx=head_mesh)

    _add_curved_hair_dome_and_bangs(b, head_pivot, mats["hair"], style)

    # Character-unique sculpted Headgear
    if style == "sakura":
        # Sculpted 5-petal curved 3D Sakura hairpin + White Mizuhiki hair tie!
        petal_mat = b.add_material("SakuraPetal", "#f9a8d4", roughness=0.3, emission="#f472b6", emission_strength=0.35)
        petals = []
        for i in range(5):
            ang = i * math.tau / 5.0
            p = make_sphere(0.075, segs=12, rings_n=8, sx=1.15, sy=0.85, sz=0.32).rotate_euler(0.0, 0.0, ang)
            p.translate(math.cos(ang) * 0.09, math.sin(ang) * 0.09, 0.0)
            petals.append(p)
        flower = merge_meshes(petals).rotate_euler(0.2, 0.4, -0.35).translate(0.33, 0.64, 0.16)
        stamen = make_sphere(0.045, segs=10, rings_n=8).translate(0.33, 0.64, 0.18)
        tie = make_torus(0.11, 0.032, segs=20).rotate_euler(0.85, 0.0, 0.0).translate(0.0, 0.56, -0.37)
        hg = b.add_mesh("Headgear", [(flower, petal_mat), (stamen, mats["gold"]), (tie, mats["white"])])
        b.add_node("Headgear", parent=head_pivot, mesh_idx=hg)
    elif style == "kickboxer":
        band = make_torus(0.39, 0.042, segs=28).translate(0.0, 0.56, 0.0)
        hg = b.add_mesh("Headgear", [(band, mats["accent"])])
        b.add_node("Headgear", parent=head_pivot, mesh_idx=hg)
        # Flowing curved headband tails attached to ScarfNode
        scarf_node = b.add_node("ScarfNode", parent=head_pivot, translation=(0.0, 0.54, -0.41))
        ribbons = []
        for side in (-1.0, 1.0):
            ribbons.append(make_tube_along_curve(
                [[0.04 * side, 0.0, 0.0], [0.14 * side, -0.14, -0.18], [0.22 * side, -0.36, -0.28], [0.18 * side, -0.56, -0.20]],
                [0.045, 0.055, 0.048, 0.018], [0.015, 0.015, 0.012, 0.008], steps=12, segs=6,
            ))
        sm = b.add_mesh("HeadbandTails", [(merge_meshes(ribbons), mats["accent"])])
        b.add_node("HeadbandTailsMesh", parent=scarf_node, mesh_idx=sm)
    elif style == "swordsman":
        # Sweeping curved Golden Samurai Kuwagata Crescent Horns + Crimson Center Gem
        horns = []
        for side in (-1.0, 1.0):
            horns.append(make_tube_along_curve(
                [[0.04 * side, 0.62, 0.34], [0.22 * side, 0.72, 0.32], [0.34 * side, 0.94, 0.24], [0.26 * side, 1.08, 0.18]],
                [0.045, 0.042, 0.032, 0.008], [0.02, 0.02, 0.015, 0.006], steps=12, segs=8,
            ))
        band = make_torus(0.39, 0.035, segs=28).translate(0.0, 0.58, 0.0)
        gem = make_crystal(0.065, 0.14, sides=6).rotate_euler(math.pi * 0.5, 0.0, 0.0).translate(0.0, 0.63, 0.38)
        hg = b.add_mesh("Headgear", [(merge_meshes(horns + [band]), mats["gold"]), (gem, mats["accent"])])
        b.add_node("Headgear", parent=head_pivot, mesh_idx=hg)
    elif style == "raijin":
        plate = make_box(0.28, 0.11, 0.04).translate(0.0, 0.58, 0.38)
        band = make_torus(0.39, 0.038, segs=28).translate(0.0, 0.58, 0.0)
        bolt = make_tube_along_curve(
            [[0.0, 0.62, 0.39], [-0.06, 0.76, 0.38], [0.06, 0.86, 0.35], [0.0, 1.04, 0.30]],
            [0.035, 0.038, 0.030, 0.008], [0.018, 0.018, 0.015, 0.006], steps=10, segs=6,
        )
        hg = b.add_mesh("Headgear", [(band, mats["dark"]), (plate, mats["gold"]), (bolt, mats["glow"])])
        b.add_node("Headgear", parent=head_pivot, mesh_idx=hg)
    elif style == "yukionna":
        ice_mat = b.add_material("TiaraIce", "#a5f3fc", roughness=0.08, metallic=0.25, emission="#38bdf8", emission_strength=0.85)
        band = make_torus(0.34, 0.028, segs=28).translate(0.0, 0.68, 0.0)
        shards = [
            make_crystal(0.055, 0.34, sides=6).translate(0.0, 0.88, 0.27),
            make_crystal(0.045, 0.26, sides=6).rotate_euler(0.0, 0.0, 0.32).translate(-0.17, 0.81, 0.23),
            make_crystal(0.045, 0.26, sides=6).rotate_euler(0.0, 0.0, -0.32).translate(0.17, 0.81, 0.23),
            make_crystal(0.035, 0.20, sides=6).rotate_euler(0.0, 0.0, 0.60).translate(-0.30, 0.74, 0.14),
            make_crystal(0.035, 0.20, sides=6).rotate_euler(0.0, 0.0, -0.60).translate(0.30, 0.74, 0.14),
        ]
        hg = b.add_mesh("Headgear", [(merge_meshes([band] + shards), ice_mat)])
        b.add_node("Headgear", parent=head_pivot, mesh_idx=hg)

    # ==================== ARTICULATED ARMS, LEGS & WEAPON ====================
    left_arm = b.add_node("LeftArm", parent=body_pivot, translation=(-0.42, 1.44, 0.0))
    right_arm = b.add_node("RightArm", parent=body_pivot, translation=(0.42, 1.44, 0.0))
    _add_sculpted_arm(b, left_arm, -1.0, style, mats)
    _add_sculpted_arm(b, right_arm, 1.0, style, mats)

    weapon_pivot = b.add_node("WeaponPivot", parent=right_arm, translation=(0.0, -0.52, 0.14))
    _add_sculpted_weapon(b, weapon_pivot, style, mats)

    left_leg = b.add_node("LeftLeg", parent=body_pivot, translation=(-0.17, 0.72, 0.0))
    right_leg = b.add_node("RightLeg", parent=body_pivot, translation=(0.17, 0.72, 0.0))
    _add_sculpted_leg(b, left_leg, style, mats)
    _add_sculpted_leg(b, right_leg, style, mats)

    # ==================== FLOWING SCARF & ORBITING SIGNATURE ACCESSORIES ====================
    if style in ("swordsman", "raijin"):
        sc_mat = mats["accent"] if style == "swordsman" else mats["gold"]
        collar = make_torus(0.24, 0.055, segs=24).translate(0.0, 1.53, 0.0)
        cm = b.add_mesh("ScarfCollar", [(collar, sc_mat)])
        b.add_node("ScarfCollar", parent=body_pivot, mesh_idx=cm)

        scarf_node = b.add_node("ScarfNode", parent=body_pivot, translation=(0.0, 1.52, -0.24))
        streamer = make_tube_along_curve(
            [[0.0, 0.0, 0.0], [0.06, -0.20, -0.28], [-0.04, -0.52, -0.48], [0.05, -0.84, -0.36]],
            [0.12, 0.15, 0.13, 0.04], [0.025, 0.024, 0.020, 0.010], steps=14, segs=8,
        )
        sm = b.add_mesh("ScarfStreamer", [(streamer, sc_mat)])
        b.add_node("ScarfStreamerMesh", parent=scarf_node, mesh_idx=sm)

    if style == "raijin":
        # Authentic Raijin Floating Thunder-Drum Ring with painted Mitsudomoe drumheads!
        drum_mat = b.add_material("MitsudomoeDrum", "#ffffff", roughness=0.38, texture_img=tex.paint_mitsudomoe_drum())
        orbit = b.add_node("OrbitGroup", parent=body_pivot, translation=(0.0, 1.56, -0.46))
        ring = make_torus(0.64, 0.028, segs=32).rotate_euler(math.pi * 0.5, 0.0, 0.0)
        drums_body = []
        drums_rim = []
        for i in range(5):
            ang = i * math.tau / 5.0
            dx, dy = math.cos(ang) * 0.64, math.sin(ang) * 0.64
            face = make_lathe([(0.125, -0.045), (0.125, 0.045)], segs=18).rotate_euler(math.pi * 0.5, 0.0, 0.0).translate(dx, dy, 0.0)
            rim = make_torus(0.128, 0.022, segs=18).rotate_euler(math.pi * 0.5, 0.0, 0.0).translate(dx, dy, 0.0)
            drums_body.append(face)
            drums_rim.append(rim)
        om = b.add_mesh("RaijinDrums", [
            (ring, mats["glow"]),
            (merge_meshes(drums_body), drum_mat),
            (merge_meshes(drums_rim), mats["gold"]),
        ])
        b.add_node("RaijinDrumsMesh", parent=orbit, mesh_idx=om)
    elif style == "yukionna":
        orbit = b.add_node("OrbitGroup", parent=body_pivot, translation=(0.0, 1.38, 0.0))
        ice_m = b.add_material("OrbitIce", "#a5f3fc", roughness=0.08, metallic=0.25, emission="#22d3ee", emission_strength=0.95)
        shards = []
        for i in range(4):
            ang = i * math.tau / 4.0
            s = make_crystal(0.075, 0.36, sides=6).translate(math.cos(ang) * 0.90, math.sin(i * 1.6) * 0.18, math.sin(ang) * 0.90)
            shards.append(s)
        om = b.add_mesh("IceOrbit", [(merge_meshes(shards), ice_m)])
        b.add_node("IceOrbitMesh", parent=orbit, mesh_idx=om)
    elif style == "sakura":
        orbit = b.add_node("OrbitGroup", parent=body_pivot, translation=(0.0, 1.42, 0.0))
        p_mat = b.add_material("SakuraOrb", "#fbcfe8", roughness=0.25, emission="#f472b6", emission_strength=0.95)
        petals = []
        for i in range(3):
            ang = i * math.tau / 3.0
            s = make_sphere(0.085, segs=12, rings_n=8, sx=1.2, sy=0.8, sz=0.35).rotate_euler(0.4, ang, 0.3)
            s.translate(math.cos(ang) * 0.88, math.sin(ang) * 0.14, math.sin(ang) * 0.88)
            petals.append(s)
        om = b.add_mesh("SakuraOrbit", [(merge_meshes(petals), p_mat)])
        b.add_node("SakuraOrbitMesh", parent=orbit, mesh_idx=om)

    out_path = os.path.join(OUT_DIR, f"hero_{style}.glb")
    b.save_glb(out_path)
    return out_path


# ==============================================================================
#  2. THREE SCULPTED 3D SHIKIGAMI COMPANIONS
# ==============================================================================
def build_shikigami_glb(sh_id):
    b = GlbSceneBuilder()
    root = b.add_node("BodyRoot")

    if sh_id == "kitsune":
        fur = b.add_material("FoxFur", "#f97316", roughness=0.45, emission="#ea580c", emission_strength=0.20)
        white = b.add_material("FoxWhite", "#fffbeb", roughness=0.48)
        face_m = b.add_material("FoxFace", "#ffffff", roughness=0.42, texture_img=tex.paint_kitsune_mask())
        red = b.add_material("ShrineRed", "#dc2626", roughness=0.45)
        gold = b.add_material("Gold", "#fbbf24", roughness=0.22, metallic=0.85, emission="#f59e0b", emission_strength=0.3)
        fire = b.add_material("Foxfire", "#fb923c", roughness=0.15, emission="#f97316", emission_strength=1.45)

        body = make_lathe([(0.16, -0.22), (0.28, -0.08), (0.26, 0.10), (0.18, 0.22)], segs=20, sx=0.95, sz=1.18)
        bib = make_torus(0.20, 0.055, segs=22).translate(0.0, 0.18, 0.08)
        bell = make_sphere(0.065, segs=12, rings_n=8).translate(0.0, 0.15, 0.28)
        head = make_anime_head(rx=0.26, ry=0.25, rz=0.26, segs=22, rings_n=14).translate(0.0, 0.34, 0.16)
        snout = make_lathe([(0.12, 0.0), (0.065, 0.14), (0.032, 0.22)], segs=14).rotate_euler(math.pi * 0.5, 0.0, 0.0).translate(0.0, 0.29, 0.34)
        ears = []
        for side in (-1.0, 1.0):
            ears.append(make_tube_along_curve(
                [[0.12 * side, 0.50, 0.14], [0.22 * side, 0.68, 0.14], [0.24 * side, 0.82, 0.10]],
                [0.085, 0.055, 0.012], [0.055, 0.038, 0.010], steps=8, segs=8,
            ))
        bm = b.add_mesh("KitsuneBody", [
            (merge_meshes([body] + ears), fur),
            (head, face_m),
            (snout, white),
            (bib, red),
            (bell, gold),
        ])
        b.add_node("KitsuneMesh", parent=root, mesh_idx=bm)

        # S-curved fluffy fox tail
        tail_pivot = b.add_node("TailPivot", parent=root, translation=(0.0, 0.02, -0.26))
        tail = make_tube_along_curve(
            [[0.0, 0.0, 0.0], [0.0, 0.14, -0.26], [0.0, 0.38, -0.44], [0.0, 0.56, -0.34]],
            [0.09, 0.19, 0.16, 0.04], [0.09, 0.19, 0.16, 0.04], steps=14, segs=12,
        )
        tm = b.add_mesh("FoxTail", [(tail, fur)])
        b.add_node("FoxTailMesh", parent=tail_pivot, mesh_idx=tm)

        orbit = b.add_node("OrbitNode", parent=root)
        wisps = []
        for i in range(2):
            a = i * math.pi
            w = make_crystal(0.07, 0.20, sides=8).translate(math.cos(a) * 0.62, 0.24, math.sin(a) * 0.62)
            wisps.append(w)
        om = b.add_mesh("FoxWisps", [(merge_meshes(wisps), fire)])
        b.add_node("FoxWispsMesh", parent=orbit, mesh_idx=om)

    elif sh_id == "neko":
        white = b.add_material("NekoPorcelain", "#fffbeb", roughness=0.28)
        face_m = b.add_material("NekoFace", "#ffffff", roughness=0.30, texture_img=tex.paint_neko_face())
        red = b.add_material("CollarRed", "#dc2626", roughness=0.40)
        gold = b.add_material("Gold", "#fbbf24", roughness=0.18, metallic=0.88, emission="#f59e0b", emission_strength=0.35)

        body = make_lathe([(0.16, -0.26), (0.31, -0.16), (0.29, 0.06), (0.21, 0.22)], segs=22)
        collar = make_torus(0.23, 0.042, segs=24).translate(0.0, 0.21, 0.0)
        bell = make_sphere(0.075, segs=14, rings_n=10).translate(0.0, 0.17, 0.26)
        head = make_sphere(0.29, segs=24, rings_n=16, sx=1.08, sy=0.95, sz=0.95).translate(0.0, 0.42, 0.02)
        ears = []
        for side in (-1.0, 1.0):
            ears.append(make_tube_along_curve(
                [[0.16 * side, 0.62, 0.02], [0.24 * side, 0.78, 0.02]],
                [0.09, 0.015], [0.06, 0.012], steps=6, segs=8,
            ))
        bm = b.add_mesh("NekoBody", [
            (merge_meshes([body] + ears), white),
            (head, face_m),
            (collar, red),
            (bell, gold),
        ])
        b.add_node("NekoMesh", parent=root, mesh_idx=bm)

        tail_pivot = b.add_node("TailPivot", parent=root, translation=(0.24, 0.16, 0.14))
        paw = make_tube_along_curve([[0.0, 0.0, 0.0], [0.05, 0.16, 0.06], [0.02, 0.28, 0.09]], [0.075, 0.072, 0.062], steps=8, segs=10)
        pm = b.add_mesh("NekoPaw", [(paw, white)])
        b.add_node("NekoPawMesh", parent=tail_pivot, mesh_idx=pm)

        orbit = b.add_node("OrbitNode", parent=root)
        koban = make_lathe([(0.16, -0.025), (0.16, 0.025)], segs=22, sx=0.72, sz=1.25).rotate_euler(math.pi * 0.5, 0.0, 0.0).translate(0.0, 0.90, 0.0)
        om = b.add_mesh("KobanCoin", [(koban, gold)])
        b.add_node("KobanMesh", parent=orbit, mesh_idx=om)

    else:  # raiju
        fur = b.add_material("WolfFur", "#0284c7", roughness=0.38, emission="#38bdf8", emission_strength=0.30)
        dark = b.add_material("WolfDark", "#0f172a", roughness=0.45)
        bolt = b.add_material("Lightning", "#7dd3fc", roughness=0.12, emission="#38bdf8", emission_strength=1.45)
        eye = b.add_material("WolfEye", "#fef08a", roughness=0.1, emission="#facc15", emission_strength=1.5)

        body = make_lathe([(0.16, -0.22), (0.26, -0.06), (0.28, 0.12), (0.20, 0.24)], segs=20, sx=0.92, sz=1.32)
        head = make_sphere(0.25, segs=20, rings_n=14, sx=0.95, sy=0.95, sz=1.1).translate(0.0, 0.30, 0.22)
        snout = make_lathe([(0.13, 0.0), (0.09, 0.14), (0.06, 0.24)], segs=12, sx=1.0, sz=0.85).rotate_euler(math.pi * 0.5, 0.0, 0.0).translate(0.0, 0.26, 0.38)
        ears, spikes, eyes = [], [], []
        for side in (-1.0, 1.0):
            ears.append(make_tube_along_curve([[0.12 * side, 0.48, 0.18], [0.22 * side, 0.72, 0.14]], [0.08, 0.012], [0.05, 0.01], steps=6, segs=8))
            spikes.append(make_tube_along_curve([[0.22 * side, 0.16, 0.10], [0.42 * side, 0.28, -0.04]], [0.065, 0.010], steps=6, segs=6))
            eyes.append(make_sphere(0.048, segs=10, rings_n=8).translate(0.11 * side, 0.33, 0.43))
        bm = b.add_mesh("RaijuBody", [
            (merge_meshes([body, head]), fur),
            (merge_meshes([snout] + ears), dark),
            (merge_meshes(spikes), bolt),
            (merge_meshes(eyes), eye),
        ])
        b.add_node("RaijuMesh", parent=root, mesh_idx=bm)

        tail_pivot = b.add_node("TailPivot", parent=root, translation=(0.0, 0.08, -0.32))
        bt = make_tube_along_curve(
            [[0.0, 0.0, 0.0], [0.0, 0.18, -0.22], [0.0, 0.12, -0.36], [0.0, 0.38, -0.58]],
            [0.075, 0.065, 0.055, 0.010], steps=10, segs=6,
        )
        tm = b.add_mesh("RaijuTail", [(bt, bolt)])
        b.add_node("RaijuTailMesh", parent=tail_pivot, mesh_idx=tm)

        orbit = b.add_node("OrbitNode", parent=root)
        ring = make_torus(0.54, 0.025, segs=28).translate(0.0, 0.14, 0.0)
        om = b.add_mesh("RaijuRing", [(ring, bolt)])
        b.add_node("RaijuRingMesh", parent=orbit, mesh_idx=om)

    out_path = os.path.join(OUT_DIR, f"sh_{sh_id}.glb")
    b.save_glb(out_path)
    return out_path


# ==============================================================================
#  3. SIX REFINED ORGANIC YOKAI MONSTERS & THREE BOSSES (in build_enemies.py)
# ==============================================================================
def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    built = []
    for hero in ("sakura", "kickboxer", "swordsman", "raijin", "yukionna"):
        built.append(build_hero_glb(hero))
    for sh in ("kitsune", "neko", "raiju"):
        built.append(build_shikigami_glb(sh))
    for en in ("chochin", "kasa", "aooni", "kyubi", "jorogumo", "dogu", "akaoni_boss", "tengu_boss", "orochi_boss"):
        built.append(build_refined_enemy_glb(en, OUT_DIR))

    total_kb = sum(os.path.getsize(p) for p in built) / 1024.0
    print(f"Built {len(built)} sculpted .glb models! Total size: {total_kb:.1f} KB")
    for p in built:
        print(f"  - {os.path.basename(p)}: {os.path.getsize(p)/1024.0:.1f} KB")


if __name__ == "__main__":
    main()
