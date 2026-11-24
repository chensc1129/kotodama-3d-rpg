"""Supersampled procedural Japanese anime & yokai texture painter using Pillow."""

import math
from PIL import Image, ImageDraw, ImageFilter


def _hex(h):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), 255)


def _lerp_col(c1, c2, t):
    t = max(0.0, min(1.0, t))
    return tuple(int(c1[i] + (c2[i] - c1[i]) * t) for i in range(4))


def paint_anime_face(
    skin_hex="#ffe2cf",
    iris_top="#be123c",
    iris_bot="#fda4af",
    brow_hex="#3b1d2a",
    blush_hex="#fb7185",
    fierce=False,
    bandaid=False,
    ninja_mask_hex=None,
    smile="gentle",
):
    """Paint a crisp 512x512 anime head wrap texture where u=0.5 faces straight ahead (+Z)."""
    W, H = 1024, 1024  # 2x supersampled -> downsampled to 512x512
    skin = _hex(skin_hex)
    img = Image.new("RGBA", (W, H), skin)
    draw = ImageDraw.Draw(img, "RGBA")

    # Subtle warm face shading around forehead & jawline (fully opaque RGB blend)
    shade = _lerp_col(skin, (205, 135, 120, 255), 0.16)
    for y in range(H):
        if y < int(H * 0.34):
            t = 0.45 * (1.0 - y / (H * 0.34))
            draw.line([(0, y), (W, y)], fill=_lerp_col(skin, shade, t))
        elif y > int(H * 0.78):
            t = 0.35 * ((y - H * 0.78) / (H * 0.22))
            draw.line([(0, y), (W, y)], fill=_lerp_col(skin, shade, t))

    # Face center is at x = 512 (u=0.5), eye height at y = 515 (v~0.50)
    cx, cy = 512, 518
    eye_dx = 84
    eye_w = 50
    eye_h = 56 if not fierce else 44

    # Soft airbrushed cheek blush
    blush_layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    bd = ImageDraw.Draw(blush_layer, "RGBA")
    bc = _hex(blush_hex)
    for side in (-1, 1):
        bx = cx + side * 108
        by = cy + 68
        bd.ellipse([bx - 42, by - 20, bx + 42, by + 20], fill=(bc[0], bc[1], bc[2], 95 if not fierce else 45))
    blush_layer = blush_layer.filter(ImageFilter.GaussianBlur(radius=14))
    img = Image.alpha_composite(img, blush_layer)
    draw = ImageDraw.Draw(img, "RGBA")

    c_top = _hex(iris_top)
    c_bot = _hex(iris_bot)
    c_brow = _hex(brow_hex)
    ink = (22, 16, 32, 255)

    for side in (-1, 1):
        ex = cx + side * eye_dx
        ey = cy

        # Sclera white
        draw.ellipse([ex - eye_w, ey - eye_h, ex + eye_w, ey + eye_h], fill=(255, 253, 255, 255))
        # Subtle upper sclera shadow
        draw.pieslice([ex - eye_w, ey - eye_h, ex + eye_w, ey + eye_h], 195, 345, fill=(216, 212, 232, 175))

        # Gradient anime iris
        ir_w = int(eye_w * 0.72)
        ir_h = int(eye_h * 0.84)
        iris_img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        idraw = ImageDraw.Draw(iris_img, "RGBA")
        for dy in range(-ir_h, ir_h + 1):
            t = (dy + ir_h) / float(2 * ir_h)
            col = _lerp_col(c_top, c_bot, t ** 1.15)
            dx_span = int(ir_w * math.sqrt(max(0.0, 1.0 - (dy / float(ir_h)) ** 2)))
            idraw.line([(ex - dx_span, ey + dy), (ex + dx_span, ey + dy)], fill=col)
        # Outer iris rim & deep pupil
        idraw.ellipse([ex - ir_w, ey - ir_h, ex + ir_w, ey + ir_h], outline=ink, width=4)
        idraw.ellipse([ex - int(ir_w * 0.45), ey - int(ir_h * 0.44), ex + int(ir_w * 0.45), ey + int(ir_h * 0.44)], fill=(25, 18, 36, 235))
        # Lower luminous crescent glow inside iris
        idraw.arc([ex - int(ir_w * 0.68), ey - int(ir_h * 0.62), ex + int(ir_w * 0.68), ey + int(ir_h * 0.72)], 25, 155, fill=(255, 255, 255, 210), width=7)
        img = Image.alpha_composite(img, iris_img)
        draw = ImageDraw.Draw(img, "RGBA")

        # Dual anime eye sparkles (big top-left + small bottom-right)
        sx = ex - side * 12
        draw.ellipse([sx - 15, ey - 28, sx + 15, ey - 2], fill=(255, 255, 255, 255))
        draw.ellipse([ex + side * 14 - 7, ey + 14 - 7, ex + side * 14 + 7, ey + 14 + 7], fill=(255, 255, 255, 240))

        # Thick sculpted upper anime eyelashes + wing tip
        draw.arc([ex - eye_w - 6, ey - eye_h - 6, ex + eye_w + 6, ey + eye_h], 185, 355, fill=ink, width=15)
        wing_x = ex + side * (eye_w + 14)
        draw.polygon([(ex + side * (eye_w - 4), ey - 16), (wing_x, ey - 26), (ex + side * (eye_w - 2), ey - 2)], fill=ink)
        # Delicate lower lash line
        draw.arc([ex - eye_w + 6, ey - eye_h + 10, ex + eye_w - 6, ey + eye_h + 4], 25, 155, fill=(55, 40, 62, 180), width=4)
        # Double-eyelid crease
        draw.arc([ex - eye_w + 4, ey - eye_h - 24, ex + eye_w - 4, ey + eye_h - 20], 205, 335, fill=(165, 105, 95, 165), width=4)

        # Expressive anime eyebrow
        if fierce:
            p1 = (ex - side * 48, ey - eye_h - 24)
            p2 = (ex + side * 44, ey - eye_h - 46)
            draw.line([p1, p2], fill=c_brow, width=12)
        else:
            draw.arc([ex - 52, ey - eye_h - 54, ex + 52, ey - eye_h + 10], 200, 340, fill=c_brow, width=9)

    # Subtle nose shadow dot
    draw.polygon([(cx - 4, cy + 54), (cx + 6, cy + 68), (cx - 5, cy + 72)], fill=(190, 128, 112, 185))

    # Sporty nose band-aid for Kickboxer
    if bandaid:
        draw.rounded_rectangle([cx - 44, cy + 16, cx + 44, cy + 44], radius=10, fill=(248, 232, 206, 255), outline=(185, 145, 110, 255), width=3)
        draw.rectangle([cx - 18, cy + 20, cx + 18, cy + 40], fill=(238, 214, 182, 255))

    # Anime Mouth
    if ninja_mask_hex is None:
        if smile == "grin":
            draw.chord([cx - 32, cy + 88, cx + 32, cy + 128], 10, 170, fill=(255, 255, 255, 255), outline=ink, width=5)
        elif smile == "stoic":
            draw.line([(cx - 24, cy + 108), (cx + 24, cy + 104)], fill=(135, 72, 72, 235), width=6)
        else:
            draw.arc([cx - 26, cy + 88, cx + 26, cy + 120], 18, 162, fill=(175, 78, 92, 240), width=6)
    else:
        # High-collar sculpted shinobi face mask covering lower face cleanly below eyes!
        mc = _hex(ninja_mask_hex)
        mc_hi = _lerp_col(mc, (255, 255, 255, 255), 0.18)
        gold = _hex("#facc15")
        draw.polygon([(0, cy + 56), (cx, cy + 40), (W, cy + 56), (W, H), (0, H)], fill=mc)
        # Golden ninja trim border along top edge of mask
        draw.line([(0, cy + 56), (cx, cy + 40), (W, cy + 56)], fill=gold, width=10)
        # Subtle mask stitching
        for ox in range(-180, 220, 44):
            draw.line([(cx + ox, cy + 64), (cx + ox, cy + 190)], fill=mc_hi, width=3)

    return img.resize((512, 512), Image.LANCZOS)


def _overlay(base_img, draw_fn):
    layer = Image.new("RGBA", base_img.size, (0, 0, 0, 0))
    draw_fn(ImageDraw.Draw(layer, "RGBA"))
    return Image.alpha_composite(base_img, layer)


def paint_hair_tex(base_hex, hi_hex, sh_hex):
    """Anime hair texture with fine vertical strands and glossy angel-ring highlight."""
    W, H = 256, 256
    c_base = _hex(base_hex)
    c_hi = _hex(hi_hex)
    c_sh = _hex(sh_hex)
    img = Image.new("RGBA", (W, H), c_base)
    draw = ImageDraw.Draw(img, "RGBA")

    for y in range(H):
        v = y / float(H - 1)
        if v < 0.25:
            col = _lerp_col(c_sh, c_base, v / 0.25)
        elif v > 0.72:
            col = _lerp_col(c_base, c_sh, (v - 0.72) / 0.28)
        else:
            col = c_base
        draw.line([(0, y), (W, y)], fill=col)

    def _strands(d):
        for x in range(0, W, 6):
            tone = c_hi if (x % 18 == 0) else c_sh
            d.line([(x, 0), (x, H)], fill=(tone[0], tone[1], tone[2], 65), width=2)
        pts = [(x, 82 + (10 if (x // 16) % 2 == 0 else -8)) for x in range(0, W + 16, 16)]
        d.line(pts, fill=(c_hi[0], c_hi[1], c_hi[2], 195), width=14)

    img = _overlay(img, _strands)
    return img.filter(ImageFilter.GaussianBlur(radius=1.0)).convert("RGB")


def paint_sakura_hakama():
    """Rich crimson silk hakama with golden seigaiha hem & scattered sakura blossoms."""
    W, H = 512, 512
    c_top = _hex("#e11d48")
    c_bot = _hex("#881337")
    img = Image.new("RGBA", (W, H), c_top)
    draw = ImageDraw.Draw(img, "RGBA")

    for y in range(H):
        draw.line([(0, y), (W, y)], fill=_lerp_col(c_top, c_bot, y / float(H)))

    # Vertical subtle pleat shading stripes (composited properly with alpha!)
    pleat_layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    pd = ImageDraw.Draw(pleat_layer, "RGBA")
    for x in range(0, W, 36):
        pd.rectangle([x, 0, x + 12, H], fill=(48, 5, 18, 55))
    img = Image.alpha_composite(img, pleat_layer)
    draw = ImageDraw.Draw(img, "RGBA")

    # Gold brocade hem band
    gold = _hex("#fbbf24")
    pink = _hex("#fbcfe8")
    draw.rectangle([0, H - 56, W, H - 46], fill=gold)
    draw.rectangle([0, H - 18, W, H], fill=gold)

    # Golden waves along hem
    for x in range(-16, W + 32, 32):
        draw.arc([x, H - 46, x + 32, H - 14], 180, 360, fill=gold, width=3)

    # Scattered 5-petal sakura blossoms
    positions = [(64, 140, 18), (180, 260, 22), (310, 170, 16), (420, 320, 20), (110, 370, 19), (260, 390, 17), (455, 130, 15)]
    for cx, cy, r in positions:
        for k in range(5):
            ang = k * math.tau / 5.0
            px = cx + math.cos(ang) * r * 0.72
            py = cy + math.sin(ang) * r * 0.72
            draw.ellipse([px - r * 0.45, py - r * 0.45, px + r * 0.45, py + r * 0.45], fill=pink)
        draw.ellipse([cx - 5, cy - 5, cx + 5, cy + 5], fill=gold)
    return img


def paint_samurai_armor():
    """Layered crimson Japanese O-Yoroi laced armor plates (odoshi) with gold trim & rivets."""
    W, H = 512, 512
    img = Image.new("RGBA", (W, H), _hex("#7f1d1d"))
    draw = ImageDraw.Draw(img, "RGBA")
    crimson = _hex("#dc2626")
    dark = _hex("#1c1917")
    gold = _hex("#fbbf24")

    plate_h = 64
    for row in range(H // plate_h):
        y0 = row * plate_h
        draw.rectangle([0, y0, W, y0 + plate_h - 8], fill=crimson)
        draw.rectangle([0, y0 + plate_h - 12, W, y0 + plate_h - 6], fill=gold)
        draw.rectangle([0, y0 + plate_h - 6, W, y0 + plate_h], fill=dark)
        # Vertical odoshi lacing cords & gold rivets
        for x in range(16, W, 32):
            draw.line([(x, y0 + 4), (x, y0 + plate_h - 12)], fill=gold, width=4)
            draw.ellipse([x - 4, y0 + 10, x + 4, y0 + 18], fill=gold)
    return img


def paint_yukionna_kimono():
    """Glacial snow-white to deep cyan frost silk painted with crisp 6-point crystal snowflakes."""
    W, H = 512, 512
    c_top = _hex("#f0f9ff")
    c_mid = _hex("#bae6fd")
    c_bot = _hex("#0284c7")
    img = Image.new("RGBA", (W, H), c_top)
    draw = ImageDraw.Draw(img, "RGBA")

    for y in range(H):
        v = y / float(H - 1)
        col = _lerp_col(c_top, c_mid, v * 2.0) if v < 0.5 else _lerp_col(c_mid, c_bot, (v - 0.5) * 2.0)
        draw.line([(0, y), (W, y)], fill=col)

    # Frost filigree hem
    draw.rectangle([0, H - 36, W, H - 28], fill=(224, 242, 254, 255))

    # Crisp 6-point snowflakes
    flakes = [(80, 120, 26), (220, 240, 32), (380, 150, 24), (130, 380, 28), (330, 360, 30), (450, 290, 22)]
    for cx, cy, r in flakes:
        col = (255, 255, 255, 255)
        for k in range(6):
            ang = k * math.tau / 6.0
            x2, y2 = cx + math.cos(ang) * r, cy + math.sin(ang) * r
            draw.line([(cx, cy), (x2, y2)], fill=col, width=3)
            mx, my = cx + math.cos(ang) * r * 0.62, cy + math.sin(ang) * r * 0.62
            for da in (-0.55, 0.55):
                bx, by = mx + math.cos(ang + da) * r * 0.32, my + math.sin(ang + da) * r * 0.32
                draw.line([(mx, my), (bx, by)], fill=col, width=2)
    return img


def paint_raijin_suit():
    """Midnight-indigo ninja hex-mesh bodysuit with electric-gold lightning veins."""
    W, H = 512, 512
    img = Image.new("RGBA", (W, H), _hex("#1e1b4b"))
    draw = ImageDraw.Draw(img, "RGBA")
    mesh_c = _hex("#312e81")
    gold = _hex("#facc15")

    for i in range(-H, W + H, 28):
        draw.line([(i, 0), (i + H, H)], fill=mesh_c, width=2)
        draw.line([(i, 0), (i - H, H)], fill=mesh_c, width=2)

    for bx in (128, 384):
        pts = [(bx, 40), (bx - 24, 150), (bx + 18, 220), (bx - 20, 340), (bx + 12, 460)]
        draw.line(pts, fill=gold, width=6)
    return img


def paint_mitsudomoe_drum():
    """Traditional Japanese Raijin Taiko drumhead with swirling Mitsudomoe emblem."""
    W, H = 256, 256
    bg = _hex("#fef3c7")
    img = Image.new("RGBA", (W, H), bg)
    draw = ImageDraw.Draw(img, "RGBA")
    cx, cy = 128, 128
    draw.ellipse([10, 10, 246, 246], outline=_hex("#b45309"), width=12)
    ink = _hex("#1e1b4b")
    for k in range(3):
        base_deg = k * 120
        # Sweeping comma arc around the ring
        draw.arc([cx - 72, cy - 72, cx + 72, cy + 72], base_deg + 10, base_deg + 102, fill=ink, width=18)
        ang = math.radians(base_deg + 18)
        px = cx + math.cos(ang) * 56
        py = cy + math.sin(ang) * 56
        draw.ellipse([px - 24, py - 24, px + 24, py + 24], fill=ink)
    draw.ellipse([cx - 22, cy - 22, cx + 22, cy + 22], fill=bg)
    return img


def paint_kickboxer_gi():
    """Woven cobalt martial arts fabric with gold & crimson flame hem trim."""
    W, H = 256, 256
    img = Image.new("RGBA", (W, H), _hex("#1d4ed8"))
    draw = ImageDraw.Draw(img, "RGBA")
    weave = _hex("#2563eb")
    for y in range(0, H, 8):
        draw.line([(0, y), (W, y)], fill=weave, width=2)
    for x in range(0, W, 12):
        draw.line([(x, 0), (x, H)], fill=(15, 35, 110, 75), width=2)
    draw.rectangle([0, H - 30, W, H - 22], fill=_hex("#fbbf24"))
    draw.rectangle([0, H - 22, W, H], fill=_hex("#dc2626"))
    return img


def paint_katana_hilt():
    """Traditional diamond-wrapped Japanese Tsuka-ito cord over white rayskin."""
    W, H = 128, 256
    img = Image.new("RGBA", (W, H), _hex("#f1f5f9"))
    draw = ImageDraw.Draw(img, "RGBA")
    cord = _hex("#1e293b")
    for y in range(-64, H + 64, 32):
        draw.line([(0, y), (W, y + 64)], fill=cord, width=12)
        draw.line([(W, y), (0, y + 64)], fill=cord, width=12)
    return img


# ==================== YOKAI & SHIKIGAMI TEXTURES ====================
def paint_chochin_lantern():
    """Glowing weathered Japanese washi-paper lantern with glaring bloodshot eye, jagged grin & kanji."""
    W, H = 512, 512
    img = Image.new("RGBA", (W, H), _hex("#fb923c"))
    draw = ImageDraw.Draw(img, "RGBA")
    for y in range(H):
        v = abs(y - 256) / 256.0
        col = _lerp_col(_hex("#ffedd5"), _hex("#c2410c"), v ** 0.85)
        draw.line([(0, y), (W, y)], fill=col)

    # Subtle vertical paper grain & dark bamboo ribs
    def _ribs(d):
        for x in range(0, W, 16):
            d.line([(x, 0), (x, H)], fill=(154, 52, 18, 28), width=2)
        for y in range(36, H, 48):
            d.line([(0, y), (W, y)], fill=(90, 28, 12, 175), width=6)
    img = _overlay(img, _ribs)
    draw = ImageDraw.Draw(img, "RGBA")

    # Front (+Z, u=0.5 -> x=256): furious glaring bloodshot demon eye
    cx, cy = 256, 188
    draw.ellipse([cx - 74, cy - 52, cx + 74, cy + 52], fill=(255, 252, 240, 255), outline=(28, 12, 10, 255), width=9)
    # Bloodshot veins
    for ang_d in (-25, 0, 22, 155, 180, 205):
        a = math.radians(ang_d)
        draw.line([(cx + math.cos(a) * 34, cy + math.sin(a) * 24), (cx + math.cos(a) * 66, cy + math.sin(a) * 44)], fill=(220, 38, 38, 200), width=3)
    draw.ellipse([cx - 32, cy - 32, cx + 32, cy + 32], fill=(220, 38, 38, 255), outline=(90, 10, 10, 255), width=4)
    draw.ellipse([cx - 15, cy - 15, cx + 15, cy + 15], fill=(15, 8, 12, 255))
    draw.ellipse([cx - 18, cy - 22, cx - 4, cy - 8], fill=(255, 255, 255, 255))
    # Heavy furrowed eyelid brow
    draw.arc([cx - 82, cy - 72, cx + 82, cy + 18], 195, 345, fill=(38, 14, 12, 255), width=14)

    # Jagged tearing mouth cavity
    draw.rounded_rectangle([cx - 104, 288, cx + 104, 376], radius=28, fill=(32, 8, 12, 255), outline=(18, 8, 10, 255), width=7)
    for tx in range(cx - 84, cx + 84, 24):
        draw.polygon([(tx, 292), (tx + 12, 326), (tx + 24, 292)], fill=(255, 248, 225, 255))
        draw.polygon([(tx + 6, 372), (tx + 16, 346), (tx + 26, 372)], fill=(255, 248, 225, 255))
    return img.convert("RGB")


def paint_kasa_umbrella():
    """Purple & gold striped Wagasa umbrella canopy with expressive cyclops eye & mischievous grin."""
    W, H = 512, 512
    img = Image.new("RGBA", (W, H), _hex("#6b21a8"))
    draw = ImageDraw.Draw(img, "RGBA")
    for x in range(0, W, 64):
        draw.rectangle([x, 0, x + 32, H], fill=_hex("#9333ea"))
        draw.line([(x, 0), (x, H)], fill=_hex("#3b0764"), width=4)
        draw.line([(x + 32, 0), (x + 32, H)], fill=_hex("#3b0764"), width=4)
    draw.rectangle([0, H - 44, W, H - 36], fill=_hex("#fde047"))
    draw.rectangle([0, H - 36, W, H], fill=_hex("#f59e0b"))

    cx, cy = 256, 278
    draw.ellipse([cx - 66, cy - 54, cx + 66, cy + 54], fill=(255, 255, 255, 255), outline=(25, 10, 42, 255), width=9)
    draw.ellipse([cx - 32, cy - 32, cx + 32, cy + 32], fill=_hex("#f59e0b"), outline=(60, 20, 10, 255), width=4)
    draw.ellipse([cx - 15, cy - 15, cx + 15, cy + 15], fill=(15, 8, 20, 255))
    draw.ellipse([cx - 18, cy - 22, cx - 4, cy - 8], fill=(255, 255, 255, 255))
    draw.arc([cx - 72, cy - 68, cx + 72, cy + 10], 200, 340, fill=(25, 10, 42, 255), width=12)
    return img.convert("RGB")


def paint_tiger_stripes():
    """Classic Japanese Oni yellow-and-black tiger-pelt fundoshi loincloth."""
    W, H = 256, 256
    img = Image.new("RGBA", (W, H), _hex("#facc15"))
    draw = ImageDraw.Draw(img, "RGBA")
    ink = _hex("#1c1917")
    for y in range(18, H, 40):
        pts = [(0, y), (64, y + 14), (128, y - 6), (192, y + 16), (256, y)]
        draw.line(pts, fill=ink, width=14)
    return img.convert("RGB")


def paint_lava_oni(base_hex="#dc2626", crack_hex="#facc15"):
    """Muscular Oni skin with dramatic anatomical shading and glowing battle/lava veins."""
    W, H = 256, 256
    c1 = _hex(base_hex)
    c2 = _lerp_col(c1, (15, 10, 22, 255), 0.30)
    img = Image.new("RGBA", (W, H), c1)
    draw = ImageDraw.Draw(img, "RGBA")
    for y in range(H):
        draw.line([(0, y), (W, y)], fill=_lerp_col(c1, c2, y / float(H)))
    ck = _hex(crack_hex)
    def _veins(d):
        for x0 in (44, 128, 212):
            pts = [(x0, 14), (x0 - 18, 84), (x0 + 14, 152), (x0 - 10, 236)]
            d.line(pts, fill=(ck[0], ck[1], ck[2], 215), width=4)
    return _overlay(img, _veins).convert("RGB")


def paint_oni_face(skin_hex="#2563eb", eye_hex="#fef08a", mark_hex="#1e1b4b"):
    """Fierce sculpted Japanese Oni demon face texture with kumadori warpaint, glowing eyes & snarl."""
    W, H = 512, 512
    skin = _hex(skin_hex)
    mark = _hex(mark_hex)
    eye = _hex(eye_hex)
    ink = (18, 12, 24, 255)
    img = Image.new("RGBA", (W, H), skin)
    draw = ImageDraw.Draw(img, "RGBA")

    cx, cy = 256, 258
    # Tribal kumadori cheek warpaint stripes
    for side in (-1, 1):
        draw.line([(cx + side * 26, cy - 42), (cx + side * 72, cy - 58)], fill=mark, width=10)
        draw.line([(cx + side * 34, cy + 28), (cx + side * 86, cy + 42)], fill=mark, width=8)
        # Fierce slanted glowing demon eyes
        ex = cx + side * 46
        draw.polygon([
            (ex - side * 26, cy - 4),
            (ex + side * 26, cy - 22),
            (ex + side * 22, cy + 12),
            (ex - side * 22, cy + 16),
        ], fill=eye, outline=ink)
        draw.ellipse([ex - 9, cy - 9, ex + 9, cy + 9], fill=(185, 28, 28, 255))
        draw.ellipse([ex - 4, cy - 4, ex + 4, cy + 4], fill=ink)
        # Heavy furrowed brows
        draw.line([(ex - side * 28, cy - 14), (ex + side * 30, cy - 34)], fill=ink, width=10)

    # Scowling fanged demon mouth
    draw.rounded_rectangle([cx - 56, cy + 48, cx + 56, cy + 88], radius=14, fill=(38, 8, 14, 255), outline=ink, width=5)
    for tx in range(cx - 42, cx + 44, 16):
        draw.polygon([(tx, cy + 50), (tx + 8, cy + 68), (tx + 16, cy + 50)], fill=(255, 250, 235, 255))
    return img.convert("RGB")


def paint_tengu_face():
    """Regal crimson Japanese Great Tengu mask face with fierce golden eyes & white brows."""
    W, H = 512, 512
    img = Image.new("RGBA", (W, H), _hex("#dc2626"))
    draw = ImageDraw.Draw(img, "RGBA")
    ink = (22, 10, 14, 255)
    cx, cy = 256, 256
    for side in (-1, 1):
        ex = cx + side * 46
        draw.ellipse([ex - 26, cy - 18, ex + 26, cy + 18], fill=(255, 255, 255, 255), outline=ink, width=5)
        draw.ellipse([ex - 14, cy - 14, ex + 14, cy + 14], fill=_hex("#facc15"), outline=ink, width=3)
        draw.ellipse([ex - 6, cy - 6, ex + 6, cy + 6], fill=ink)
        # Sweeping bushy white eyebrows
        draw.line([(ex - side * 28, cy - 22), (ex + side * 34, cy - 42)], fill=(248, 250, 252, 255), width=11)
    # Stern downturned warrior mouth
    draw.arc([cx - 38, cy + 54, cx + 38, cy + 88], 195, 345, fill=ink, width=7)
    return img.convert("RGB")


def paint_jorogumo_face():
    """Pale porcelain spider-empress demon face with 6 glowing toxic-emerald eyes & dark violet lips."""
    W, H = 512, 512
    img = Image.new("RGBA", (W, H), _hex("#ede9fe"))
    draw = ImageDraw.Draw(img, "RGBA")
    ink = (24, 12, 38, 255)
    neon = _hex("#4ade80")
    emerald = _hex("#059669")
    cx, cy = 256, 260
    for side in (-1, 1):
        ex = cx + side * 44
        # Main alluring slanted spider eyes
        draw.ellipse([ex - 24, cy - 16, ex + 24, cy + 16], fill=ink)
        draw.ellipse([ex - 15, cy - 12, ex + 15, cy + 12], fill=emerald)
        draw.ellipse([ex - 8, cy - 8, ex + 8, cy + 8], fill=neon)
        draw.ellipse([ex - 3, cy - 9, ex + 3, cy + 9], fill=ink)
        # Secondary smaller spider eyes above brows!
        draw.ellipse([ex + side * 8 - 8, cy - 36 - 8, ex + side * 8 + 8, cy - 36 + 8], fill=neon, outline=ink, width=3)
        draw.ellipse([ex - side * 10 - 6, cy - 42 - 6, ex - side * 10 + 6, cy - 42 + 6], fill=neon, outline=ink, width=2)
    # Smirking dark violet lips
    draw.arc([cx - 24, cy + 44, cx + 24, cy + 68], 15, 165, fill=(109, 40, 217, 255), width=6)
    return img.convert("RGB")


def paint_kyubi_kimono():
    """Luxurious crimson-and-gold Kyubi shrine enchantress silk with swirling golden foxfire clouds."""
    W, H = 512, 512
    c1 = _hex("#fffbeb")
    c2 = _hex("#fef3c7")
    img = Image.new("RGBA", (W, H), c1)
    draw = ImageDraw.Draw(img, "RGBA")
    for y in range(H):
        draw.line([(0, y), (W, y)], fill=_lerp_col(c1, c2, y / float(H)))
    red = _hex("#dc2626")
    gold = _hex("#f59e0b")
    draw.rectangle([0, H - 72, W, H], fill=red)
    draw.rectangle([0, H - 78, W, H - 68], fill=gold)
    for x in range(32, W, 96):
        draw.ellipse([x - 22, H - 54, x + 22, H - 20], outline=gold, width=4)
        draw.ellipse([x + 14, 180, x + 46, 224], fill=gold)
    return img.convert("RGB")


def paint_dogu_clay():
    """Ancient Jomon clay figurine terracotta with carved spiral cord-markings & glowing cyan runes."""
    W, H = 256, 256
    img = Image.new("RGBA", (W, H), _hex("#78716c"))
    draw = ImageDraw.Draw(img, "RGBA")
    dark = _hex("#44403c")
    light = _hex("#a8a29e")
    rune = _hex("#38bdf8")
    for y in range(16, H, 32):
        draw.line([(0, y), (W, y)], fill=dark, width=4)
        draw.line([(0, y + 4), (W, y + 4)], fill=light, width=2)
        for x in range(16, W, 48):
            draw.ellipse([x - 10, y - 10, x + 10, y + 10], outline=dark, width=3)
    draw.line([(128, 16), (128, 240)], fill=rune, width=5)
    return img.convert("RGB")


def paint_dragon_scales(base_hex="#059669", hi_hex="#34d399"):
    """Overlapping iridescent emerald dragon scales with gold belly accents for Yamata-no-Orochi."""
    W, H = 256, 256
    img = Image.new("RGBA", (W, H), _hex(base_hex))
    draw = ImageDraw.Draw(img, "RGBA")
    hi = _hex(hi_hex)
    sh = _hex("#064e3b")
    for row in range(0, H + 32, 22):
        ox = 16 if (row // 22) % 2 else 0
        for x in range(-32 + ox, W + 32, 32):
            draw.pieslice([x, row - 16, x + 32, row + 16], 0, 180, fill=hi, outline=sh, width=3)
    return img.convert("RGB")


def paint_spider_venom():
    """Glossy obsidian spider carapace with neon-emerald venom hourglass & web filigree."""
    W, H = 256, 256
    img = Image.new("RGBA", (W, H), _hex("#0f172a"))
    draw = ImageDraw.Draw(img, "RGBA")
    venom = _hex("#10b981")
    hi = _hex("#4ade80")
    web = _hex("#1e293b")
    for a in range(0, 360, 30):
        r = math.radians(a)
        draw.line([(128, 128), (128 + math.cos(r) * 140, 128 + math.sin(r) * 140)], fill=web, width=2)
    draw.polygon([(128, 128), (88, 56), (168, 56)], fill=venom)
    draw.polygon([(128, 128), (88, 200), (168, 200)], fill=venom)
    draw.polygon([(128, 128), (104, 76), (152, 76)], fill=hi)
    draw.polygon([(128, 128), (104, 180), (152, 180)], fill=hi)
    return img.convert("RGB")


def paint_kitsune_mask():
    """Traditional white Japanese Kitsune Noh mask with crimson kumadori shrine markings."""
    W, H = 256, 256
    img = Image.new("RGBA", (W, H), _hex("#fffbeb"))
    draw = ImageDraw.Draw(img, "RGBA")
    red = _hex("#dc2626")
    ink = _hex("#1e1b4b")
    cx, cy = 128, 128
    draw.polygon([(cx, cy - 64), (cx - 18, cy - 38), (cx, cy - 24), (cx + 18, cy - 38)], fill=red)
    for side in (-1, 1):
        draw.line([(cx + side * 14, cy - 4), (cx + side * 52, cy - 18)], fill=ink, width=7)
        draw.line([(cx + side * 12, cy - 12), (cx + side * 58, cy - 26)], fill=red, width=5)
        draw.arc([cx + side * 24 - 16, cy + 16, cx + side * 24 + 16, cy + 44], 0, 260, fill=red, width=4)
    return img.convert("RGB")


def paint_neko_face():
    """Adorable white Maneki-neko porcelain cat face with crescent eyes, whiskers & calico ears."""
    W, H = 256, 256
    img = Image.new("RGBA", (W, H), _hex("#fffbeb"))
    draw = ImageDraw.Draw(img, "RGBA")
    ink = _hex("#1c1917")
    pink = _hex("#fb7185")
    gold = _hex("#f59e0b")
    cx, cy = 128, 134
    draw.ellipse([cx - 56, cy - 92, cx + 18, cy - 36], fill=gold)
    def _cheeks(d):
        for side in (-1, 1):
            d.ellipse([cx + side * 52 - 14, cy + 4, cx + side * 52 + 14, cy + 20], fill=(pink[0], pink[1], pink[2], 145))
    img = _overlay(img, _cheeks)
    draw = ImageDraw.Draw(img, "RGBA")
    for side in (-1, 1):
        draw.arc([cx + side * 34 - 18, cy - 22, cx + side * 34 + 18, cy + 8], 195, 345, fill=ink, width=6)
        for wy in (-2, 10, 22):
            draw.line([(cx + side * 46, cy + wy), (cx + side * 88, cy + wy - 4)], fill=ink, width=3)
    draw.polygon([(cx - 8, cy + 4), (cx + 8, cy + 4), (cx, cy + 14)], fill=pink)
    draw.arc([cx - 20, cy + 10, cx, cy + 28], 10, 175, fill=ink, width=4)
    draw.arc([cx, cy + 10, cx + 20, cy + 28], 5, 170, fill=ink, width=4)
    return img.convert("RGB")
