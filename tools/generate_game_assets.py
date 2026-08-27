#!/usr/bin/env python3
"""Generate first-batch official assets: act-1 enemy roster and the 30-card pool icons."""

from __future__ import annotations

import math
import random
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets/game"
RNG = random.Random(20260828)

INK = "#0b0d10"


def canvas(size: tuple[int, int], base=(0, 0, 0, 0)) -> tuple[Image.Image, ImageDraw.ImageDraw]:
    image = Image.new("RGBA", size, base)
    return image, ImageDraw.Draw(image)


def glow(image: Image.Image, center: tuple[int, int], radius: int, color: tuple[int, int, int], alpha: int) -> Image.Image:
    size = image.size
    layer, draw = canvas(size)
    x, y = center
    for scale, opacity in [(1.0, alpha // 5), (0.68, alpha // 3), (0.36, alpha)]:
        r = int(radius * scale)
        draw.ellipse((x - r, y - r, x + r, y + r), fill=(*color, opacity))
    return Image.alpha_composite(image, layer.filter(ImageFilter.GaussianBlur(max(8, radius // 5))))


def grain(image: Image.Image, amount: int = 14) -> Image.Image:
    original_alpha = image.getchannel("A")
    noise = Image.effect_noise(image.size, amount).convert("L")
    texture = Image.merge("RGBA", (noise, noise, noise, Image.new("L", image.size, 14)))
    result = Image.alpha_composite(image.convert("RGBA"), texture)
    result.putalpha(original_alpha)
    return result


def robe(draw: ImageDraw.ImageDraw, cx: int, top: int, bottom: int, half: int, fill=INK, lean: int = 0) -> None:
    draw.polygon([(cx - half * 0.42, top), (cx - half + lean, bottom), (cx + half + lean, bottom), (cx + half * 0.42, top)], fill=fill)


def hat(draw: ImageDraw.ImageDraw, cx: int, y: int, half: int, brim: str = "#8f6737") -> None:
    draw.polygon([(cx - half, y), (cx, y - int(half * 0.55)), (cx + half, y)], fill=INK)
    draw.line((cx - half - 6, y + 2, cx + half + 6, y + 2), fill=brim, width=6)


def eyes(draw: ImageDraw.ImageDraw, cx: int, y: int, gap: int, color="#b03a35", r: int = 11) -> None:
    draw.ellipse((cx - gap - r, y - r, cx - gap + r, y + r), fill=color)
    draw.ellipse((cx + gap - r, y - r, cx + gap + r, y + r), fill=color)


def make_lantern_imp() -> None:
    size = (560, 640)
    image, draw = canvas(size)
    image = glow(image, (280, 470), 150, (242, 150, 42), 110)
    draw = ImageDraw.Draw(image)
    draw.ellipse((190, 240, 370, 470), fill=INK)
    draw.ellipse((225, 175, 335, 285), fill=INK)
    eyes(draw, 280, 225, 26, "#f2a03c", 9)
    draw.line((230, 330, 150, 386), fill=INK, width=22)
    draw.line((330, 330, 424, 386), fill=INK, width=22)
    draw.rounded_rectangle((96, 380, 176, 470), radius=12, fill="#d98729", outline="#120d0b", width=8)
    draw.line((136, 388, 136, 462), fill="#3a2119", width=5)
    draw.line((136, 388, 136, 372), fill="#57493a", width=6)
    draw.rounded_rectangle((392, 386, 452, 456), radius=10, fill="#b06f24", outline="#120d0b", width=7)
    draw.line((422, 394, 422, 448), fill="#3a2119", width=4)
    robe(draw, 280, 470, 600, 120, lean=0)
    image = grain(image)
    image.save(OUT / "enemies/lantern_imp.png", optimize=True)


def make_paper_apprentice() -> None:
    size = (620, 800)
    image, draw = canvas(size)
    image = glow(image, (310, 300), 190, (216, 206, 176), 80)
    draw = ImageDraw.Draw(image)
    draw.ellipse((240, 160, 380, 300), fill="#d8ceb0")
    draw.line((262, 214, 292, 214), fill="#3a3428", width=8)
    draw.line((328, 214, 358, 214), fill="#3a3428", width=8)
    draw.line((276, 262, 344, 262), fill="#8a4a3c", width=7)
    hat(draw, 310, 160, 130, "#6e6148")
    robe(draw, 310, 300, 742, 128)
    draw.polygon([(258, 356), (196, 700), (250, 660), (276, 372)], fill="#b9ad8c")
    draw.line((382, 330, 470, 470), fill=INK, width=20)
    draw.line((470, 470, 420, 560), fill="#9aa3a8", width=14)
    draw.polygon([(440, 470), (498, 438), (516, 470), (462, 502)], fill="#c9ccd1", outline="#17191d")
    draw.line((238, 330, 186, 470), fill=INK, width=20)
    draw.line((186, 470, 232, 540), fill="#9aa3a8", width=14)
    image = grain(image)
    image.save(OUT / "enemies/paper_apprentice.png", optimize=True)


def make_patrol_corpse() -> None:
    size = (620, 800)
    image, draw = canvas(size)
    image = glow(image, (300, 280), 170, (120, 140, 130), 70)
    draw = ImageDraw.Draw(image)
    draw.ellipse((240, 150, 380, 296), fill="#12151a")
    hat(draw, 310, 150, 118, "#4a5a52")
    eyes(draw, 310, 218, 24, "#7fb8a8", 9)
    robe(draw, 310, 296, 746, 140, lean=-14)
    draw.line((368, 330, 468, 500), fill=INK, width=24)
    draw.ellipse((418, 486, 520, 588), outline="#8f7a3f", width=12)
    draw.line((469, 486, 469, 588), fill="#8f7a3f", width=8)
    draw.line((252, 340, 210, 520), fill=INK, width=22)
    draw.line((206, 516, 300, 500), fill="#57493a", width=10)
    for x, y in [(258, 380), (286, 470), (318, 560)]:
        draw.ellipse((x, y, x + 14, y + 14), fill="#8f7a3f")
    draw.line((372, 306, 448, 520), fill=(127, 184, 168, 120), width=6)
    image = grain(image)
    image.save(OUT / "enemies/patrol_corpse.png", optimize=True)


def make_barber_ghost() -> None:
    size = (620, 800)
    image, draw = canvas(size)
    image = glow(image, (300, 290), 170, (150, 170, 190), 66)
    draw = ImageDraw.Draw(image)
    draw.ellipse((238, 158, 382, 300), fill="#101318")
    draw.line((262, 206, 296, 224), fill="#9fdce2", width=8)
    draw.line((358, 206, 324, 224), fill="#9fdce2", width=8)
    draw.polygon([(240, 132), (380, 132), (352, 96), (268, 96)], fill=INK)
    draw.line((248, 136, 372, 136), fill="#5a7d86", width=6)
    robe(draw, 310, 300, 740, 132, lean=10)
    for side, tip in [(0, 176), (1, 444)]:
        draw.line((310, 340, 176 if side == 0 else 444, 452), fill=INK, width=20)
    draw.line((120, 470, 232, 430), fill="#cfd6da", width=12)
    draw.polygon([(108, 452), (150, 430), (160, 448), (118, 470)], fill="#e8edf0", outline="#17191d")
    draw.line((400, 452, 512, 412), fill="#cfd6da", width=12)
    draw.polygon([(492, 392), (534, 414), (524, 432), (482, 410)], fill="#e8edf0", outline="#17191d")
    draw.line((310, 360, 310, 700), fill=(120, 160, 170, 60), width=16)
    image = grain(image)
    image.save(OUT / "enemies/barber_ghost.png", optimize=True)


def make_well_sisters() -> None:
    size = (640, 800)
    image, draw = canvas(size)
    image = glow(image, (320, 320), 200, (70, 110, 130), 84)
    draw = ImageDraw.Draw(image)
    robe(draw, 270, 280, 730, 108, lean=-18)
    robe(draw, 380, 300, 746, 104, lean=14, fill="#101318")
    draw.ellipse((222, 168, 330, 300), fill="#101318")
    draw.ellipse((338, 200, 440, 326), fill="#0d1013")
    eyes(draw, 276, 232, 22, "#7fb8a8", 9)
    eyes(draw, 388, 264, 20, "#a85a6a", 8)
    for x0, y0, x1, y1 in [(300, 240, 340, 500), (330, 260, 296, 540), (356, 280, 318, 560)]:
        draw.line((x0, y0, x1, y1), fill="#1c2a30", width=14)
    draw.line((330, 210, 306, 560), fill="#25404a", width=10)
    arm_pairs = [((240, 380), (352, 400)), ((420, 400), (306, 430))]
    for (x0, y0), (x1, y1) in arm_pairs:
        draw.line((x0, y0, x1, y1), fill=INK, width=18)
    draw.ellipse((296, 470, 344, 560), fill="#24343c", outline="#101820", width=6)
    image = grain(image)
    image.save(OUT / "enemies/well_sisters.png", optimize=True)


def make_gambler_ghost() -> None:
    size = (620, 800)
    image, draw = canvas(size)
    image = glow(image, (310, 300), 180, (170, 130, 60), 84)
    draw = ImageDraw.Draw(image)
    draw.ellipse((244, 160, 376, 298), fill="#101216")
    hat(draw, 310, 162, 96, "#6a5a2f")
    eyes(draw, 310, 224, 24, "#e0b45c", 9)
    robe(draw, 310, 298, 742, 148)
    draw.polygon([(236, 340), (150, 560), (232, 520), (268, 368)], fill="#1d1a14")
    draw.polygon([(384, 340), (470, 560), (388, 520), (352, 368)], fill="#1d1a14")
    dice = [(196, 300, 0.4), (432, 322, 0.7), (238, 236, 1.2), (398, 214, 0.9)]
    for x, y, rot in dice:
        d = Image.new("RGBA", (60, 60), (0, 0, 0, 0))
        dd = ImageDraw.Draw(d)
        dd.rounded_rectangle((6, 6, 54, 54), radius=10, fill="#e8dfc8", outline="#1c1812", width=5)
        dd.ellipse((24, 24, 36, 36), fill="#8a2f2c")
        d = d.rotate(math.degrees(rot), expand=True)
        image.alpha_composite(d, (x, y))
    draw = ImageDraw.Draw(image)
    for i in range(7):
        a = math.pi * (0.15 + 0.12 * i)
        x, y = 310 + int(math.cos(a) * 120), 430 + int(math.sin(a) * 40)
        draw.ellipse((x - 12, y - 12, x + 12, y + 12), outline="#8f7a3f", width=6)
    image = grain(image)
    image.save(OUT / "enemies/gambler_ghost.png", optimize=True)


def make_mortuary_warden() -> None:
    size = (700, 860)
    image, draw = canvas(size)
    image = glow(image, (340, 320), 210, (160, 70, 60), 90)
    draw = ImageDraw.Draw(image)
    draw.ellipse((268, 140, 432, 302), fill="#101216")
    draw.polygon([(256, 118), (444, 118), (410, 74), (290, 74)], fill=INK)
    eyes(draw, 350, 214, 28, "#d85151", 11)
    robe(draw, 350, 302, 796, 168)
    draw.line((300, 320, 300, 700), fill=(180, 80, 70, 110), width=10)
    draw.line((416, 330, 540, 500), fill=INK, width=30)
    draw.rounded_rectangle((486, 440, 668, 680), radius=26, fill="#2a2118", outline="#14100c", width=12)
    for y in [500, 560, 620]:
        draw.line((500, y, 654, y), fill="#57493a", width=8)
    draw.line((286, 340, 176, 520), fill=INK, width=26)
    chain_x, chain_y = 176, 520
    for i in range(7):
        a = 0.35 + i * 0.38
        chain_x += int(math.cos(a) * 44)
        chain_y += int(math.sin(a) * 34)
        draw.arc((chain_x - 24, chain_y - 24, chain_x + 24, chain_y + 24), 0, 360, fill="#57493a", width=9)
    draw.ellipse((chain_x - 16, chain_y - 16, chain_x + 16, chain_y + 16), fill="#2a2118", outline="#14100c", width=6)
    image = grain(image)
    image.save(OUT / "enemies/mortuary_warden.png", optimize=True)


def make_lantern_keeper() -> None:
    size = (720, 900)
    image, draw = canvas(size)
    image = glow(image, (360, 330), 240, (242, 160, 60), 100)
    draw = ImageDraw.Draw(image)
    draw.ellipse((284, 130, 456, 308), fill="#0e1014")
    draw.polygon([(268, 106), (472, 106), (436, 58), (304, 58)], fill=INK)
    draw.line((276, 110, 464, 110), fill="#c9a151", width=8)
    eyes(draw, 370, 208, 30, "#f2d487", 12)
    robe(draw, 370, 308, 826, 190)
    draw.polygon([(300, 360), (220, 760), (316, 700), (352, 386)], fill="#5a2a24")
    draw.polygon([(440, 360), (520, 760), (424, 700), (388, 386)], fill="#5a2a24")
    draw.line((498, 330, 596, 150), fill="#57493a", width=14)
    draw.line((588, 150, 588, 126), fill="#57493a", width=10)
    draw.rounded_rectangle((528, 150, 648, 320), radius=22, fill="#d98729", outline="#120d0b", width=12)
    draw.line((588, 158, 588, 312), fill="#3a2119", width=8)
    draw.line((534, 236, 642, 236), fill="#3a2119", width=8)
    flame = [(588, 176), (612, 214), (588, 246), (564, 214)]
    draw.polygon(flame, fill="#f7e3a6")
    draw.line((398, 342, 470, 540), fill=(242, 180, 90, 160), width=8)
    image = grain(image)
    image.save(OUT / "enemies/lantern_keeper.png", optimize=True)


CARD_POOL = [
    ("zhizhi", "斩纸"), ("huanchi", "还刃"), ("zhensha", "镇煞"), ("xudeng", "续灯"),
    ("zhuying", "逐影"), ("liebo", "裂帛"), ("duannian", "断念"), ("xuezhang", "血账"),
    ("zhuangzhong", "撞钟"), ("baiguyin", "白骨引"), ("shoulian", "收殓"), ("shuangdeng", "双灯照"),
    ("yuangui", "怨归"), ("tianping", "天平倒悬"), ("difan", "低幡"), ("jieshi", "借势"),
    ("tongjing", "铜镜"), ("fuhunsuo", "缚魂索"), ("jiedao", "借刀"), ("jinshen", "金身"),
    ("podan", "破胆"), ("dengxin", "灯芯"), ("tianyou", "添油"), ("wenlu", "问路"),
    ("zhima", "纸马"), ("changming", "长明"), ("jieshou", "借寿"), ("anhun", "安魂"),
]
CLASS_COLORS = {"斩": (224, 138, 122), "御": (127, 212, 220), "佑": (170, 209, 143)}
CARD_CLASS = {
    "zhizhi": "斩", "huanchi": "斩", "zhensha": "御", "xudeng": "佑",
    "zhuying": "斩", "liebo": "斩", "duannian": "斩", "xuezhang": "斩",
    "zhuangzhong": "斩", "baiguyin": "斩", "shoulian": "斩", "shuangdeng": "斩",
    "yuangui": "斩", "tianping": "斩", "difan": "御", "jieshi": "御",
    "tongjing": "御", "fuhunsuo": "御", "jiedao": "御", "jinshen": "御",
    "podan": "御", "dengxin": "佑", "tianyou": "佑", "wenlu": "佑",
    "zhima": "佑", "changming": "佑", "jieshou": "佑", "anhun": "佑",
}


def make_card_icon(stem: str, title: str) -> None:
    cls = CARD_CLASS[stem]
    accent = CLASS_COLORS[cls]
    size = (320, 320)
    image, draw = canvas(size, "#11141b")
    image = glow(image, (160, 148), 130, accent, 60)
    draw = ImageDraw.Draw(image)
    draw.rounded_rectangle((10, 10, 310, 310), radius=30, outline=tuple(list(accent) + [255]), width=8)
    cx, cy = 160, 150
    seed = sum(ord(ch) for ch in stem)
    if cls == "斩":
        for i in range(2 + seed % 2):
            a = -0.7 + i * 0.5 + (seed % 7) * 0.04
            draw.line((cx - int(88 * math.cos(a)), cy - int(88 * math.sin(a)), cx + int(88 * math.cos(a)), cy + int(88 * math.sin(a))), fill="#efe3bd", width=10 - i * 2)
        draw.line((cx - 92, cy + 92, cx + 92, cy - 92), fill=(*accent, 255), width=12)
    elif cls == "御":
        for r in [96, 72, 48][: 1 + seed % 3]:
            draw.arc((cx - r, cy - r, cx + r, cy + r), 220 + seed % 40, 140 + seed % 40, fill=(*accent, 255), width=12)
        draw.ellipse((cx - 14, cy - 14, cx + 14, cy + 14), outline="#e2d7b4", width=7)
    else:
        pts = []
        for i in range(6):
            a = math.pi * (1.15 + 0.14 * i)
            r = 40 + (i * 13 + seed) % 56
            pts.append((cx + int(math.cos(a) * r), cy + 30 - int(math.sin(a) * r)))
        draw.line(pts, fill="#ffca7a", width=9, joint="curve")
        draw.ellipse((cx - 20, cy - 96, cx + 20, cy - 56), fill=(*accent, 255))
    pips = 1 + seed % 3
    for p in range(pips):
        draw.ellipse((126 + p * 24, 272, 142 + p * 24, 288), fill=(*accent, 255))
    image = image.filter(ImageFilter.GaussianBlur(0.4))
    image = grain(image, 10)
    image.save(OUT / f"cards/card_{stem}.png", optimize=True)


def write_manifest() -> None:
    import json
    manifest = {
        "style": "C painterly, procedural",
        "enemies": {f"enemies/{p.name}": "620-720px RGBA" for p in sorted((OUT / "enemies").glob("*.png"))},
        "cards": {f"cards/{p.name}": "320x320 RGBA, class frame" for p in sorted((OUT / "cards").glob("*.png"))},
    }
    (OUT / "asset-manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8")


def main() -> None:
    (OUT / "enemies").mkdir(parents=True, exist_ok=True)
    (OUT / "cards").mkdir(parents=True, exist_ok=True)
    make_lantern_imp()
    make_paper_apprentice()
    make_patrol_corpse()
    make_barber_ghost()
    make_well_sisters()
    make_gambler_ghost()
    make_mortuary_warden()
    make_lantern_keeper()
    for stem, title in CARD_POOL:
        make_card_icon(stem, title)
    write_manifest()
    print(f"Generated official assets in {OUT}")


if __name__ == "__main__":
    main()
