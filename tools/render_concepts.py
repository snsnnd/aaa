#!/usr/bin/env python3
"""Render three comparable art-direction boards for project aaa."""

from __future__ import annotations

import math
import random
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageEnhance, ImageFilter, ImageFont


ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "art_concepts"
FONT_DIR = Path.home() / ".local/share/fonts"
FONT_REGULAR = FONT_DIR / "NotoSansSC.otf"
FONT_BOLD = FONT_DIR / "NotoSansSC-Bold.otf"
SIZE = (1600, 1000)
RNG = random.Random(720260827)
RESAMPLING = getattr(Image, "Resampling", Image)


def font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(str(FONT_BOLD if bold else FONT_REGULAR), size)


def alpha_layer(size: tuple[int, int]) -> tuple[Image.Image, ImageDraw.ImageDraw]:
    layer = Image.new("RGBA", size, (0, 0, 0, 0))
    return layer, ImageDraw.Draw(layer)


def add_grain(image: Image.Image, amount: int = 12, opacity: int = 24) -> Image.Image:
    noise = Image.effect_noise(image.size, amount).convert("L")
    grain = Image.merge("RGBA", (noise, noise, noise, Image.new("L", image.size, opacity)))
    return Image.alpha_composite(image.convert("RGBA"), grain)


def vignette(image: Image.Image, strength: int = 105) -> Image.Image:
    w, h = image.size
    mask = Image.new("L", (w, h), 0)
    px = mask.load()
    for y in range(h):
        ny = (y - h / 2) / (h / 2)
        for x in range(w):
            nx = (x - w / 2) / (w / 2)
            edge = min(1.0, max(0.0, math.sqrt(nx * nx + ny * ny) - 0.22) / 0.78)
            px[x, y] = int(edge * strength)
    shade = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    shade.putalpha(mask)
    return Image.alpha_composite(image.convert("RGBA"), shade)


def centered(draw: ImageDraw.ImageDraw, xy: tuple[int, int], text: str, fnt, fill, **kwargs) -> None:
    box = draw.textbbox((0, 0), text, font=fnt, **kwargs)
    draw.text((xy[0] - (box[2] - box[0]) / 2, xy[1] - (box[3] - box[1]) / 2), text, font=fnt, fill=fill, **kwargs)


def paper_cut_border(draw: ImageDraw.ImageDraw, box: tuple[int, int, int, int], gold: str, red: str) -> None:
    x0, y0, x1, y1 = box
    draw.rounded_rectangle(box, radius=24, outline=gold, width=5)
    draw.rounded_rectangle((x0 + 14, y0 + 14, x1 - 14, y1 - 14), radius=18, outline=red, width=2)
    for x in range(x0 + 38, x1 - 18, 44):
        draw.polygon([(x, y0 + 3), (x + 12, y0 + 15), (x + 24, y0 + 3), (x + 12, y0 - 9)], fill=red)
        draw.polygon([(x, y1 - 3), (x + 12, y1 - 15), (x + 24, y1 - 3), (x + 12, y1 + 9)], fill=red)


def lantern(layer: Image.Image, center: tuple[int, int], scale: float, style: str) -> None:
    x, y = center
    glow, gd = alpha_layer(layer.size)
    if style == "painterly":
        for radius, alpha in [(145, 12), (105, 20), (72, 38), (45, 72)]:
            gd.ellipse((x - radius, y - radius, x + radius, y + radius), fill=(255, 154, 54, alpha))
        glow = glow.filter(ImageFilter.GaussianBlur(24))
        layer.alpha_composite(glow)
    d = ImageDraw.Draw(layer)
    w, h = int(64 * scale), int(82 * scale)
    outline = "#110c0d" if style != "pixel" else "#070914"
    fill = "#f2a23a" if style == "painterly" else "#e7bc55"
    d.rounded_rectangle((x - w // 2, y - h // 2, x + w // 2, y + h // 2), radius=max(4, w // 6), fill=fill, outline=outline, width=max(3, int(5 * scale)))
    d.line((x, y - h // 2, x, y + h // 2), fill=outline, width=max(2, int(3 * scale)))
    d.line((x - w // 2, y, x + w // 2, y), fill=outline, width=max(2, int(3 * scale)))
    d.arc((x - w // 3, y - h // 2 - int(18 * scale), x + w // 3, y - h // 5), 180, 360, fill=outline, width=max(2, int(3 * scale)))


def draw_papercut_hero(base: Image.Image, box: tuple[int, int, int, int]) -> None:
    x0, y0, x1, y1 = box
    layer, d = alpha_layer(base.size)
    ink, paper, red, gold, blue = "#120b0d", "#e9d79a", "#ae2631", "#d6a84f", "#2b8b91"
    d.rounded_rectangle(box, radius=28, fill="#2a1116", outline=gold, width=4)
    # Layered paper moon, rooftops and cloud cuts.
    d.ellipse((x0 + 102, y0 + 58, x0 + 518, y0 + 474), fill=paper, outline=gold, width=5)
    for i in range(5):
        yy = y1 - 80 - i * 37
        color = ["#4a1720", "#631d24", "#7f252a", "#96312f", "#b34736"][i]
        d.polygon([(x0, yy + 48), (x0 + 120, yy - 4), (x0 + 240, yy + 32), (x0 + 390, yy - 20), (x0 + 540, yy + 42), (x1, yy), (x1, y1), (x0, y1)], fill=color)
    for cx, cy, r in [(x0 + 76, y0 + 154, 42), (x0 + 119, y0 + 163, 58), (x0 + 174, y0 + 151, 38)]:
        d.arc((cx - r, cy - r // 2, cx + r, cy + r // 2), 180, 360, fill=gold, width=5)
    # Ghost silhouette behind the keeper.
    d.ellipse((x0 + 392, y0 + 190, x0 + 565, y0 + 363), fill="#d8eee1", outline=ink, width=5)
    d.polygon([(x0 + 405, y0 + 297), (x0 + 369, y0 + 488), (x0 + 438, y0 + 448), (x0 + 474, y0 + 515), (x0 + 508, y0 + 440), (x0 + 572, y0 + 487), (x0 + 550, y0 + 294)], fill="#b9d6c9", outline=ink)
    d.ellipse((x0 + 432, y0 + 246, x0 + 452, y0 + 274), fill=ink)
    d.ellipse((x0 + 500, y0 + 246, x0 + 520, y0 + 274), fill=ink)
    d.arc((x0 + 455, y0 + 263, x0 + 500, y0 + 307), 15, 165, fill=red, width=5)
    # The keeper: large readable triangular cloak, round hat, lantern arm.
    d.polygon([(x0 + 217, y0 + 293), (x0 + 131, y0 + 681), (x0 + 452, y0 + 681), (x0 + 354, y0 + 307)], fill=ink, outline=gold)
    d.polygon([(x0 + 182, y0 + 348), (x0 + 136, y0 + 600), (x0 + 210, y0 + 560)], fill=red)
    d.ellipse((x0 + 204, y0 + 198, x0 + 344, y0 + 337), fill=ink, outline=gold, width=4)
    d.polygon([(x0 + 150, y0 + 242), (x0 + 398, y0 + 242), (x0 + 350, y0 + 193), (x0 + 225, y0 + 182)], fill=ink, outline=gold)
    d.ellipse((x0 + 249, y0 + 242, x0 + 282, y0 + 272), fill=paper)
    d.line((x0 + 332, y0 + 365, x0 + 482, y0 + 504), fill=ink, width=25)
    d.line((x0 + 465, y0 + 473, x0 + 520, y0 + 526), fill=gold, width=7)
    lantern(layer, (x0 + 520, y0 + 555), 1.1, "papercut")
    # Decorative joints and paper piercings.
    for px, py in [(x0 + 274, y0 + 290), (x0 + 339, y0 + 373), (x0 + 211, y0 + 500)]:
        d.ellipse((px - 7, py - 7, px + 7, py + 7), fill=gold, outline=red, width=2)
    d.rectangle((x0 + 62, y1 - 62, x1 - 62, y1 - 45), fill=ink)
    base.alpha_composite(layer)


def draw_pixel_hero(base: Image.Image, box: tuple[int, int, int, int]) -> None:
    x0, y0, x1, y1 = box
    w, h = 160, 176
    px = Image.new("RGBA", (w, h), "#101525")
    d = ImageDraw.Draw(px)
    # Moon and blocky clouds.
    d.ellipse((18, 12, 116, 110), fill="#d7d28e")
    d.rectangle((0, 121, w, h), fill="#17192a")
    d.polygon([(0, 134), (32, 111), (61, 128), (101, 101), (159, 130), (159, 175), (0, 175)], fill="#342035")
    d.polygon([(0, 146), (41, 126), (80, 144), (116, 119), (159, 151), (159, 175), (0, 175)], fill="#602638")
    # Ghost.
    d.ellipse((99, 40, 129, 69), fill="#89c8bb", outline="#0a0c16", width=2)
    d.polygon([(101, 60), (95, 99), (105, 92), (113, 103), (120, 91), (131, 99), (127, 60)], fill="#55968d", outline="#0a0c16")
    d.rectangle((106, 50, 109, 54), fill="#0a0c16")
    d.rectangle((120, 50, 123, 54), fill="#0a0c16")
    # Keeper sprite.
    d.polygon([(55, 57), (38, 142), (101, 142), (82, 58)], fill="#090b13")
    d.polygon([(52, 77), (39, 133), (55, 124)], fill="#b53545")
    d.ellipse((55, 38, 80, 62), fill="#090b13")
    d.polygon([(44, 45), (91, 45), (81, 35), (59, 34)], fill="#090b13")
    d.rectangle((63, 46, 67, 50), fill="#f1d06c")
    d.line((80, 73, 117, 109), fill="#090b13", width=7)
    d.line((115, 103, 132, 121), fill="#e7b84c", width=2)
    # Pixel lantern with glow rings.
    d.rectangle((121, 117, 145, 146), fill="#f2a53c", outline="#090b13", width=3)
    d.line((133, 117, 133, 146), fill="#7c3b2c", width=2)
    d.line((121, 131, 145, 131), fill="#7c3b2c", width=2)
    d.rectangle((114, 150, 150, 153), fill="#090b13")
    # Frame pixels.
    d.rectangle((1, 1, w - 2, h - 2), outline="#6377a8", width=2)
    d.rectangle((5, 5, w - 6, h - 6), outline="#252d4b", width=1)
    scaled = px.resize((x1 - x0, y1 - y0), RESAMPLING.NEAREST)
    base.alpha_composite(scaled, (x0, y0))


def brush_stroke(layer: Image.Image, points: list[tuple[int, int]], color: tuple[int, int, int, int], width: int) -> None:
    d = ImageDraw.Draw(layer)
    for i in range(5):
        jitter = [(x + RNG.randint(-4, 4), y + RNG.randint(-4, 4)) for x, y in points]
        d.line(jitter, fill=(color[0], color[1], color[2], max(12, color[3] // (i + 1))), width=max(2, width - i * 3), joint="curve")


def draw_painterly_hero(base: Image.Image, box: tuple[int, int, int, int]) -> None:
    x0, y0, x1, y1 = box
    w, h = x1 - x0, y1 - y0
    panel = Image.new("RGBA", (w, h), "#10141c")
    # Smoky color fields.
    fog, fd = alpha_layer((w, h))
    for cx, cy, rx, ry, color in [
        (180, 210, 220, 270, (171, 49, 41, 72)),
        (470, 170, 170, 220, (43, 117, 124, 58)),
        (395, 530, 260, 170, (196, 116, 47, 38)),
    ]:
        fd.ellipse((cx - rx, cy - ry, cx + rx, cy + ry), fill=color)
    panel = Image.alpha_composite(panel, fog.filter(ImageFilter.GaussianBlur(62)))
    strokes, _ = alpha_layer((w, h))
    for _ in range(38):
        sy = RNG.randint(40, h - 70)
        brush_stroke(strokes, [(RNG.randint(-50, 80), sy), (RNG.randint(200, 440), sy + RNG.randint(-45, 45)), (w + 20, sy + RNG.randint(-35, 35))], (90, 108, 110, RNG.randint(20, 50)), RNG.randint(8, 25))
    panel = Image.alpha_composite(panel, strokes.filter(ImageFilter.GaussianBlur(2)))
    d = ImageDraw.Draw(panel)
    # Moon, ghost and wet ground reflections.
    d.ellipse((70, 46, 442, 418), fill=(224, 208, 158, 185))
    d.ellipse((90, 65, 432, 407), outline=(249, 197, 111, 92), width=7)
    ghost, gd = alpha_layer((w, h))
    gd.ellipse((420, 170, 575, 335), fill=(142, 209, 193, 118))
    gd.polygon([(431, 290), (398, 500), (463, 455), (500, 528), (529, 446), (589, 500), (566, 284)], fill=(99, 168, 156, 108))
    ghost = ghost.filter(ImageFilter.GaussianBlur(7))
    panel = Image.alpha_composite(panel, ghost)
    d = ImageDraw.Draw(panel)
    gd = d
    gd.ellipse((461, 231, 480, 256), fill="#091012")
    gd.ellipse((519, 231, 538, 256), fill="#091012")
    # Keeper silhouette with rim-lit cloth folds.
    d.polygon([(210, 276), (102, 674), (459, 674), (354, 285)], fill="#080a0d")
    d.ellipse((202, 159, 342, 302), fill="#090b0d")
    d.polygon([(143, 208), (404, 208), (351, 155), (220, 142)], fill="#080a0d")
    d.line((209, 279, 109, 667), fill=(177, 49, 48, 225), width=17)
    d.line((350, 290, 455, 671), fill=(225, 161, 70, 122), width=9)
    for offset in [0, 23, 51, 88]:
        d.line((240 + offset, 335, 199 + offset // 2, 641), fill=(85, 52, 43, 175), width=5)
    d.ellipse((250, 213, 279, 243), fill="#f0cf7a")
    d.line((337, 346, 505, 486), fill="#090b0d", width=28)
    d.line((492, 470, 543, 517), fill="#e3b05a", width=7)
    lantern(panel, (555, 552), 1.25, "painterly")
    # Foreground loose brush silhouettes.
    front, _ = alpha_layer((w, h))
    brush_stroke(front, [(0, 661), (180, 646), (400, 675), (w, 640)], (10, 10, 13, 255), 42)
    panel = Image.alpha_composite(panel, front)
    panel = add_grain(panel, 18, 20)
    pd = ImageDraw.Draw(panel)
    pd.rounded_rectangle((2, 2, w - 3, h - 3), radius=25, outline="#a87c43", width=4)
    base.alpha_composite(panel, (x0, y0))


def attack_icons(draw: ImageDraw.ImageDraw, origin: tuple[int, int], palette: dict[str, str], style: str) -> None:
    x0, y0 = origin
    data = [
        ("赤·嗔", "重击 / 慢刀", palette["red"], "slash"),
        ("碧·痴", "连击 / 变拍", palette["blue"], "chain"),
        ("青·疑", "投技 / 佯攻", palette["green"], "hand"),
    ]
    for i, (title, sub, color, icon) in enumerate(data):
        y = y0 + i * 126
        if style == "pixel":
            draw.rectangle((x0, y, x0 + 285, y + 102), fill=palette["panel"], outline=color, width=5)
        else:
            draw.rounded_rectangle((x0, y, x0 + 285, y + 102), radius=16, fill=palette["panel"], outline=color, width=4)
        cx, cy = x0 + 48, y + 51
        if icon == "slash":
            draw.polygon([(cx - 24, cy + 22), (cx + 20, cy - 26), (cx + 28, cy - 8), (cx - 12, cy + 28)], fill=color)
            draw.line((cx - 23, cy - 17, cx + 26, cy + 23), fill=palette["ink"], width=7)
        elif icon == "chain":
            for j in range(3):
                draw.arc((cx - 29 + j * 10, cy - 29 + j * 2, cx + 12 + j * 10, cy + 24 + j * 2), 255, 105, fill=color, width=7)
        else:
            draw.ellipse((cx - 18, cy - 13, cx + 20, cy + 24), fill=color)
            for j in range(4):
                draw.line((cx - 17 + j * 11, cy - 8, cx - 24 + j * 13, cy - 34), fill=color, width=7)
        draw.text((x0 + 87, y + 18), title, font=font(28, True), fill=palette["text"])
        draw.text((x0 + 87, y + 59), sub, font=font(20), fill=palette["muted"])


def draw_broken_blade(draw: ImageDraw.ImageDraw, box: tuple[int, int, int, int], palette: dict[str, str], style: str) -> None:
    x0, y0, x1, y1 = box
    cx, cy = (x0 + x1) // 2, (y0 + y1) // 2
    if style == "painterly":
        for _ in range(18):
            a = RNG.uniform(0, math.tau)
            r = RNG.randint(50, 145)
            ex, ey = int(cx + math.cos(a) * r), int(cy + math.sin(a) * r)
            draw.line((cx, cy, ex, ey), fill=(*ImageColor_getrgb(palette["gold"]), RNG.randint(40, 110)), width=RNG.randint(2, 7))
    blade = [(cx - 34, y1 - 28), (cx - 7, cy + 19), (cx - 27, cy - 8), (cx + 16, y0 + 32), (cx + 44, y0 + 16), (cx + 18, cy - 17), (cx + 39, cy + 11), (cx + 9, cy + 30), (cx + 38, y1 - 28)]
    draw.polygon(blade, fill=palette["paper"], outline=palette["ink"])
    draw.line((cx - 65, cy + 57, cx + 65, cy + 57), fill=palette["red"], width=15)
    draw.line((cx - 20, cy + 57, cx - 20, cy + 98), fill=palette["gold"], width=13)
    for angle in [-55, -20, 18, 49]:
        ex = cx + int(math.cos(math.radians(angle)) * 104)
        ey = cy + int(math.sin(math.radians(angle)) * 104)
        draw.line((cx, cy, ex, ey), fill=palette["gold"], width=5)


def ImageColor_getrgb(color: str) -> tuple[int, int, int]:
    return tuple(int(color[i : i + 2], 16) for i in (1, 3, 5))


def draw_card(base: Image.Image, box: tuple[int, int, int, int], palette: dict[str, str], style: str) -> None:
    x0, y0, x1, y1 = box
    d = ImageDraw.Draw(base)
    radius = 0 if style == "pixel" else 25
    d.rounded_rectangle(box, radius=radius, fill=palette["card"], outline=palette["gold"], width=7)
    inner = (x0 + 15, y0 + 15, x1 - 15, y1 - 15)
    d.rounded_rectangle(inner, radius=max(0, radius - 8), outline=palette["ink"], width=3)
    d.ellipse((x0 + 18, y0 + 16, x0 + 82, y0 + 80), fill=palette["red"], outline=palette["gold"], width=4)
    centered(d, (x0 + 50, y0 + 48), "1", font(32, True), palette["text"])
    centered(d, ((x0 + x1) // 2, y0 + 52), "崩 解", font(34, True), palette["text"])
    art = (x0 + 28, y0 + 94, x1 - 28, y0 + 374)
    d.rounded_rectangle(art, radius=max(0, radius - 12), fill=palette["art"], outline=palette["red"], width=4)
    draw_broken_blade(d, (art[0] + 12, art[1] + 12, art[2] - 12, art[3] - 12), palette, style)
    d.line((x0 + 45, y0 + 407, x1 - 45, y0 + 407), fill=palette["gold"], width=2)
    centered(d, ((x0 + x1) // 2, y0 + 444), "赤·嗔  /  反制", font(21, True), palette["red"])
    centered(d, ((x0 + x1) // 2, y0 + 490), "在真实出手瞬间打出：", font(19), palette["muted"])
    centered(d, ((x0 + x1) // 2, y0 + 525), "免伤，并将重击原样归还。", font(20, True), palette["text"])
    centered(d, ((x0 + x1) // 2, y1 - 36), "灯照本相 · 怨还其身", font(17), palette["gold"])


def draw_header(base: Image.Image, title: str, subtitle: str, palette: dict[str, str], style: str, version: str) -> None:
    d = ImageDraw.Draw(base)
    if style == "pixel":
        d.rectangle((0, 0, 1600, 116), fill=palette["header"])
        d.rectangle((0, 108, 1600, 116), fill=palette["gold"])
    else:
        d.rectangle((0, 0, 1600, 116), fill=palette["header"])
        d.line((60, 108, 1540, 108), fill=palette["gold"], width=4)
    d.text((66, 21), title, font=font(52, True), fill=palette["text"])
    d.text((68, 78), subtitle, font=font(20), fill=palette["muted"])
    d.text((1450, 37), version, font=font(25, True), fill=palette["gold"])


def draw_palette(draw: ImageDraw.ImageDraw, origin: tuple[int, int], palette: dict[str, str], style: str) -> None:
    x, y = origin
    draw.text((x, y), "语义色板", font=font(25, True), fill=palette["text"])
    chips = [("命火", palette["gold"]), ("嗔", palette["red"]), ("痴", palette["blue"]), ("疑", palette["green"]), ("阴影", palette["ink"])]
    for i, (label, color) in enumerate(chips):
        cx = x + i * 57
        if style == "pixel":
            draw.rectangle((cx, y + 43, cx + 44, y + 87), fill=color, outline=palette["text"], width=2)
        else:
            draw.rounded_rectangle((cx, y + 43, cx + 44, y + 87), radius=8, fill=color, outline=palette["text"], width=2)
        centered(draw, (cx + 22, y + 109), label, font(15), palette["muted"])


def make_board(style: str) -> Image.Image:
    configs = {
        "papercut": {
            "title": "版本 A｜皮影剪纸",
            "subtitle": "硬轮廓 · 三层色纸 · 民俗纹样 · 高缩略图辨识度",
            "bg": "#160c10", "header": "#10080b", "panel": "#32151a", "card": "#e1c982",
            "art": "#4b1620", "ink": "#130b0d", "paper": "#eadb9d", "text": "#f2e5b9",
            "muted": "#c2ad80", "gold": "#d3a44b", "red": "#b42d37", "blue": "#278b91", "green": "#588d57",
        },
        "pixel": {
            "title": "版本 B｜高对比像素",
            "subtitle": "16色约束 · 硬像素簇 · 强状态反馈 · 最低资产成本",
            "bg": "#0c0f1b", "header": "#080a13", "panel": "#182037", "card": "#202a43",
            "art": "#111626", "ink": "#080a12", "paper": "#d8d19c", "text": "#f2e6c8",
            "muted": "#8d99b5", "gold": "#e6b94e", "red": "#d63f53", "blue": "#42b9c5", "green": "#65bd72",
        },
        "painterly": {
            "title": "版本 C｜手绘厚涂",
            "subtitle": "软硬边混合 · 冷暖体积光 · 局部高细节 · 氛围上限最高",
            "bg": "#11131a", "header": "#0b0d13", "panel": "#25242b", "card": "#29241f",
            "art": "#16191f", "ink": "#0a0b0e", "paper": "#d8d0b4", "text": "#eee6d1",
            "muted": "#aaa59c", "gold": "#d59a45", "red": "#b63838", "blue": "#3c939c", "green": "#668f58",
        },
    }
    p = configs[style]
    base = Image.new("RGBA", SIZE, p["bg"])
    if style == "painterly":
        base = vignette(add_grain(base, 16, 18), 125)
    draw_header(base, p["title"], p["subtitle"], p, style, "STYLE 01" if style == "papercut" else "STYLE 02" if style == "pixel" else "STYLE 03")
    hero_box = (60, 148, 750, 888)
    if style == "papercut":
        draw_papercut_hero(base, hero_box)
    elif style == "pixel":
        draw_pixel_hero(base, hero_box)
    else:
        draw_painterly_hero(base, hero_box)
    d = ImageDraw.Draw(base)
    centered(d, ((hero_box[0] + hero_box[2]) // 2, 925), "执灯人｜主角正面视觉靶", font(22, True), p["text"])
    draw_card(base, (805, 154, 1185, 790), p, style)
    d.text((1240, 156), "战斗语言", font=font(29, True), fill=p["text"])
    attack_icons(d, (1240, 208), p, style)
    draw_palette(d, (1240, 610), p, style)
    # Production readout.
    d.rounded_rectangle((1218, 778, 1540, 912), radius=0 if style == "pixel" else 18, fill=p["panel"], outline=p["gold"], width=3)
    risk = {"papercut": "产能：高｜风险：低", "pixel": "产能：最高｜风险：最低", "painterly": "产能：低｜风险：高"}[style]
    d.text((1243, 797), risk, font=font(21, True), fill=p["gold"])
    notes = {
        "papercut": "适合纸扎/符箓/皮影动作\n角色动画可用骨骼切片",
        "pixel": "适合快速扩充卡池与敌人\n但中式民俗独特性较弱",
        "painterly": "卡面与宣传图表现最强\n角色动画一致性成本最高",
    }[style]
    d.multiline_text((1243, 841), notes, font=font(17), fill=p["muted"], spacing=8)
    d.line((805, 839, 1185, 839), fill=p["gold"], width=2)
    centered(d, (995, 880), "同一内容 · 只改变视觉系统", font(19), p["muted"])
    if style == "papercut":
        paper_cut_border(d, (29, 128, 1571, 965), p["gold"], p["red"])
    elif style == "pixel":
        d.rectangle((28, 128, 1572, 966), outline=p["gold"], width=8)
        d.rectangle((40, 140, 1560, 954), outline=p["panel"], width=4)
    else:
        base = vignette(base, 82)
    return base.convert("RGB")


def build_comparison(images: list[tuple[str, Image.Image]]) -> Image.Image:
    canvas = Image.new("RGB", (1800, 720), "#0d0d12")
    d = ImageDraw.Draw(canvas)
    d.text((65, 31), "《执灯人》美术概念横向对比", font=font(46, True), fill="#eee6cf")
    d.text((67, 88), "同一角色 / 同一卡牌 / 同一语义色板｜请选择最想继续深化的一版", font=font(21), fill="#a8a39b")
    for i, (label, image) in enumerate(images):
        thumb = image.resize((530, 331), RESAMPLING.LANCZOS)
        x, y = 65 + i * 570, 147
        canvas.paste(thumb, (x, y))
        d.rectangle((x - 3, y - 3, x + 533, y + 334), outline="#c99b4b", width=3)
        centered(d, (x + 265, 516), label, font(30, True), "#eee6cf")
        verdict = [
            "世界观咬合最强｜推荐深化",
            "产能最高｜适合极小团队",
            "氛围上限最高｜成本最高",
        ][i]
        centered(d, (x + 265, 560), verdict, font(19), "#aaa59c")
    d.rounded_rectangle((65, 615, 1735, 680), radius=14, fill="#191820", outline="#4f4540", width=2)
    centered(d, (900, 648), "推荐：A 作为游戏内主视觉，C 作为宣传海报/关键剧情插画；B 保留为最低成本备选。", font(22, True), "#d5a24d")
    return canvas


def main() -> None:
    OUTPUT.mkdir(parents=True, exist_ok=True)
    results = []
    for key, label, filename in [
        ("papercut", "A｜皮影剪纸", "concept_A_papercut.png"),
        ("pixel", "B｜高对比像素", "concept_B_pixel.png"),
        ("painterly", "C｜手绘厚涂", "concept_C_painterly.png"),
    ]:
        board = make_board(key)
        board.save(OUTPUT / filename, optimize=True)
        results.append((label, board))
    build_comparison(results).save(OUTPUT / "concept_comparison.png", optimize=True)
    print(f"Rendered {len(results) + 1} files to {OUTPUT}")


if __name__ == "__main__":
    main()
