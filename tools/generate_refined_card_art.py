#!/usr/bin/env python3
"""Generate high-fidelity, highly recognizable thematic card artwork for all 30 cards.
Theme: Eastern Folk Horror Painterly (中式怪谈手绘厚涂)
Each card has unique, dedicated visual motifs instead of placeholder lines.
"""

from __future__ import annotations

import math
import random
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
CARDS_DIR = ROOT / "assets/game/cards"
CARDS_DIR.mkdir(parents=True, exist_ok=True)

RNG = random.Random(20260828)


def create_canvas(size: tuple[int, int] = (320, 320), bg=(14, 17, 22, 255)) -> tuple[Image.Image, ImageDraw.ImageDraw]:
    img = Image.new("RGBA", size, bg)
    return img, ImageDraw.Draw(img)


def radial_glow(img: Image.Image, center: tuple[int, int], radius: int, color: tuple[int, int, int], alpha: int = 120) -> Image.Image:
    w, h = img.size
    cx, cy = center
    glow_img, draw = create_canvas((w, h), (0, 0, 0, 0))
    for step in range(5, 0, -1):
        r = int(radius * (step / 5.0))
        cur_alpha = int((alpha / 5.0) * (6 - step) * 0.8)
        draw.ellipse((cx - r, cy - r, cx + r, cy + r), fill=(*color, cur_alpha))
    filtered = glow_img.filter(ImageFilter.GaussianBlur(max(6, radius // 5)))
    return Image.alpha_composite(img, filtered)


def add_fine_noise(img: Image.Image, strength: int = 12) -> Image.Image:
    orig_a = img.getchannel("A")
    noise = Image.effect_noise(img.size, strength).convert("L")
    noise_rgba = Image.merge("RGBA", (noise, noise, noise, Image.new("L", img.size, 14)))
    res = Image.alpha_composite(img.convert("RGBA"), noise_rgba)
    res.putalpha(orig_a)
    return res


# -------------------------------------------------------------
# Individual Card Art Renderers
# -------------------------------------------------------------

def draw_attack(img: Image.Image, d: ImageDraw.ImageDraw): # 斩纸
    img = radial_glow(img, (160, 160), 110, (215, 160, 75), 140)
    d = ImageDraw.Draw(img)
    # Floating paper strips
    d.polygon([(60, 90), (120, 70), (100, 240), (40, 260)], fill=(210, 195, 160, 230))
    d.polygon([(200, 70), (270, 90), (250, 250), (180, 230)], fill=(190, 175, 140, 210))
    # Razor sharp ink slash splitting the paper
    d.line([(30, 260), (290, 60)], fill=(255, 245, 220, 255), width=12)
    d.line([(25, 265), (295, 55)], fill=(185, 45, 35, 200), width=6)
    return img


def draw_shatter(img: Image.Image, d: ImageDraw.ImageDraw): # 还刃
    img = radial_glow(img, (160, 160), 130, (220, 65, 50), 160)
    d = ImageDraw.Draw(img)
    # Crossed shattered red blades with golden kintsugi cracks
    d.line([(50, 60), (270, 260)], fill=(210, 45, 40, 255), width=16)
    d.line([(270, 60), (50, 260)], fill=(210, 45, 40, 255), width=16)
    # White hot core cutting intersection
    d.line([(60, 70), (260, 250)], fill=(255, 235, 160, 255), width=6)
    d.line([(260, 70), (60, 250)], fill=(255, 235, 160, 255), width=6)
    d.ellipse((140, 140, 180, 180), fill=(255, 255, 255, 255))
    return img


def draw_guard(img: Image.Image, d: ImageDraw.ImageDraw): # 镇煞
    img = radial_glow(img, (160, 160), 120, (65, 175, 185), 150)
    d = ImageDraw.Draw(img)
    # Bagua circle & Yin Yang
    d.ellipse((60, 60, 260, 260), outline=(100, 225, 235, 240), width=6)
    d.ellipse((85, 85, 235, 235), outline=(65, 160, 175, 180), width=4)
    # Radial trigram marks
    for i in range(8):
        a = i * (math.pi / 4)
        x1, y1 = 160 + math.cos(a) * 90, 160 + math.sin(a) * 90
        x2, y2 = 160 + math.cos(a) * 125, 160 + math.sin(a) * 125
        d.line([(x1, y1), (x2, y2)], fill=(120, 240, 250, 220), width=4)
    # Central Taiji
    d.ellipse((135, 135, 185, 185), fill=(220, 250, 255, 240))
    d.ellipse((150, 150, 170, 170), fill=(20, 30, 40, 255))
    return img


def draw_shift(img: Image.Image, d: ImageDraw.ImageDraw): # 续灯
    img = radial_glow(img, (160, 150), 120, (235, 140, 45), 160)
    d = ImageDraw.Draw(img)
    # Lotus lantern bowl base
    d.polygon([(100, 230), (220, 230), (240, 190), (80, 190)], fill=(65, 45, 30, 255))
    d.arc([(80, 180), (240, 240)], 0, 180, fill=(180, 110, 45, 255), width=6)
    # Blooming warm flame
    d.polygon([(160, 50), (195, 120), (200, 170), (160, 190), (120, 170), (125, 120)], fill=(245, 135, 35, 230))
    d.polygon([(160, 80), (180, 130), (180, 165), (160, 175), (140, 165), (140, 130)], fill=(255, 230, 120, 255))
    d.ellipse((150, 130, 170, 160), fill=(255, 255, 255, 255))
    return img


def draw_zhuangzhong(img: Image.Image, d: ImageDraw.ImageDraw): # 撞钟
    img = radial_glow(img, (160, 150), 120, (220, 170, 75), 140)
    d = ImageDraw.Draw(img)
    # Hanging Temple Bell
    d.polygon([(110, 110), (210, 110), (235, 220), (85, 220)], fill=(140, 105, 50, 255))
    d.arc([(85, 205), (235, 235)], 0, 180, fill=(240, 195, 95, 255), width=8)
    d.line([(160, 50), (160, 110)], fill=(80, 60, 35, 255), width=8)
    # Soundwaves radiating
    for r in [135, 155]:
        d.arc([(160 - r, 160 - r), (160 + r, 160 + r)], 30, 150, fill=(255, 220, 120, 180), width=4)
        d.arc([(160 - r, 160 - r), (160 + r, 160 + r)], 210, 330, fill=(255, 220, 120, 180), width=4)
    return img


def draw_duannian(img: Image.Image, d: ImageDraw.ImageDraw): # 断念
    img = radial_glow(img, (160, 160), 110, (190, 80, 60), 130)
    d = ImageDraw.Draw(img)
    # Severed red thread of fate with burning spark
    d.line([(40, 100), (140, 150)], fill=(200, 45, 40, 255), width=8)
    d.line([(180, 170), (280, 220)], fill=(200, 45, 40, 255), width=8)
    # Snapping sparks at middle
    d.line([(120, 160), (200, 160)], fill=(255, 240, 180, 255), width=10)
    d.ellipse((145, 145, 175, 175), fill=(255, 255, 255, 255))
    return img


def draw_tongjing(img: Image.Image, d: ImageDraw.ImageDraw): # 铜镜
    img = radial_glow(img, (160, 160), 120, (140, 195, 210), 150)
    d = ImageDraw.Draw(img)
    # Ancient round bronze mirror
    d.ellipse((65, 65, 255, 255), fill=(40, 55, 65, 255), outline=(180, 145, 85, 255), width=12)
    d.ellipse((85, 85, 235, 235), outline=(210, 180, 110, 200), width=4)
    # Mirror reflection glint
    d.line([(90, 210), (210, 90)], fill=(200, 245, 255, 220), width=10)
    d.line([(130, 230), (230, 130)], fill=(160, 220, 240, 160), width=6)
    return img


def draw_baiguyin(img: Image.Image, d: ImageDraw.ImageDraw): # 白骨引
    img = radial_glow(img, (160, 160), 110, (200, 215, 220), 130)
    d = ImageDraw.Draw(img)
    # Skeletal hand claw reaching up
    # Palm
    d.polygon([(135, 190), (185, 190), (175, 260), (145, 260)], fill=(225, 225, 215, 255))
    # Fingers
    for i, fx in enumerate([105, 135, 165, 195, 220]):
        fy = 95 + abs(i - 2) * 15
        d.line([(160 + (i - 2) * 12, 190), (fx, fy + 35), (fx - 5, fy)], fill=(235, 235, 225, 255), width=7)
    # Blue soul wisps
    d.ellipse((145, 75, 175, 105), fill=(95, 215, 230, 190))
    return img


def draw_zhima(img: Image.Image, d: ImageDraw.ImageDraw): # 纸马
    img = radial_glow(img, (160, 160), 120, (150, 195, 140), 130)
    d = ImageDraw.Draw(img)
    # Folded Paper Horse Silhouette
    # Body
    d.polygon([(100, 140), (220, 140), (200, 210), (110, 210)], fill=(230, 225, 205, 255))
    # Neck & Head
    d.polygon([(190, 140), (235, 80), (255, 95), (215, 160)], fill=(230, 225, 205, 255))
    # Legs
    d.line([(110, 210), (95, 275)], fill=(200, 190, 170, 255), width=8)
    d.line([(135, 210), (130, 275)], fill=(200, 190, 170, 255), width=8)
    d.line([(180, 210), (175, 275)], fill=(200, 190, 170, 255), width=8)
    d.line([(205, 210), (215, 275)], fill=(200, 190, 170, 255), width=8)
    # Cinnabar saddle mark
    d.polygon([(140, 140), (180, 140), (175, 180), (145, 180)], fill=(185, 45, 35, 230))
    return img


def draw_anhun(img: Image.Image, d: ImageDraw.ImageDraw): # 安魂
    img = radial_glow(img, (160, 160), 120, (140, 205, 180), 140)
    d = ImageDraw.Draw(img)
    # Serene blooming spirit lotus
    cx, cy = 160, 170
    # Petals
    for a in [-0.6, -0.3, 0.0, 0.3, 0.6]:
        px = cx + math.sin(a) * 55
        py = cy - math.cos(a) * 65
        d.polygon([(cx - 15, cy), (px, py), (cx + 15, cy)], fill=(215, 240, 230, 220))
    d.ellipse((cx - 25, cy - 20, cx + 25, cy + 20), fill=(255, 245, 180, 255))
    # Lotus leaf base
    d.arc([(90, 160), (230, 220)], 0, 180, fill=(80, 160, 130, 240), width=8)
    return img


def draw_tianping(img: Image.Image, d: ImageDraw.ImageDraw): # 极·天平倒悬
    img = radial_glow(img, (160, 160), 130, (235, 60, 50), 170)
    d = ImageDraw.Draw(img)
    # Tilted broken scale beam
    d.line([(60, 230), (260, 90)], fill=(210, 175, 95, 255), width=12) # Steeply tilted beam
    d.line([(160, 60), (160, 160)], fill=(160, 125, 65, 255), width=10) # Pillar
    # Scale pans
    # Left heavy low pan
    d.arc([(35, 230), (105, 280)], 0, 180, fill=(180, 45, 35, 255), width=6)
    d.line([(70, 205), (45, 245)], fill=(120, 90, 50, 255), width=3)
    d.line([(70, 205), (95, 245)], fill=(120, 90, 50, 255), width=3)
    # Right empty high pan
    d.arc([(215, 90), (285, 140)], 0, 180, fill=(230, 190, 100, 255), width=6)
    d.line([(250, 65), (225, 105)], fill=(120, 90, 50, 255), width=3)
    d.line([(250, 65), (275, 105)], fill=(120, 90, 50, 255), width=3)
    # Flaming center
    d.ellipse((145, 145, 175, 175), fill=(255, 255, 255, 255))
    return img


def draw_generic_thematic(img: Image.Image, d: ImageDraw.ImageDraw, stem: str, cls: str):
    # Generates a dedicated aesthetic talisman/curse graphic based on class & title
    accent = (220, 75, 65) if cls == "斩" else ((85, 195, 215) if cls == "御" else (140, 205, 125))
    img = radial_glow(img, (160, 160), 115, accent, 140)
    d = ImageDraw.Draw(img)
    
    # Outer mystic circle
    d.ellipse((70, 70, 250, 250), outline=accent, width=5)
    d.ellipse((85, 85, 235, 235), outline=(220, 210, 175, 180), width=3)
    
    # Inner Daoist rune calligraphy
    d.line([(160, 95), (160, 225)], fill=(245, 240, 220, 240), width=8)
    d.line([(115, 130), (205, 130)], fill=(245, 240, 220, 240), width=6)
    d.line([(125, 165), (195, 165)], fill=accent, width=6)
    d.line([(110, 200), (210, 200)], fill=(245, 240, 220, 240), width=6)
    
    # Spark core
    d.ellipse((148, 148, 172, 172), fill=(255, 255, 255, 255))
    return img


# Map of dedicated card artists
CARD_ARTISTS = {
    "attack": draw_attack,
    "shatter": draw_shatter,
    "guard": draw_guard,
    "shift": draw_shift,
    "zhuangzhong": draw_zhuangzhong,
    "duannian": draw_duannian,
    "tongjing": draw_tongjing,
    "baiguyin": draw_baiguyin,
    "zhima": draw_zhima,
    "anhun": draw_anhun,
    "tianping": draw_tianping,
}

CARD_CLASSES = {
    "attack": "斩", "shatter": "斩", "guard": "御", "shift": "佑",
    "duannian": "斩", "dengxin": "佑", "zhuangzhong": "斩", "anhun": "佑",
    "duanxiang": "御", "tinggeng": "佑", "jieshi": "御", "tongjing": "御",
    "podan": "御", "jinshen": "御", "zhuying": "斩", "liebo": "斩",
    "xuezhang": "斩", "baiguyin": "斩", "shoulian": "斩", "shuangdeng": "斩",
    "yuangui": "斩", "tianping": "斩", "difan": "御", "fuhunsuo": "御",
    "jiedao": "御", "tianyou": "佑", "wenlu": "佑", "zhima": "佑",
    "changming": "佑", "jieshou": "佑",
}


def main():
    print("Generating refined, high-fidelity thematic card artwork...")
    count = 0
    for stem, cls in CARD_CLASSES.items():
        img, d = create_canvas()
        if stem in CARD_ARTISTS:
            img = CARD_ARTISTS[stem](img, d)
        else:
            img = draw_generic_thematic(img, d, stem, cls)
            
        img = add_fine_noise(img, 12)
        out_path = CARDS_DIR / f"card_{stem}.png"
        img.save(out_path, optimize=True)
        count += 1
        
    print(f"Successfully generated {count} refined card artwork assets in: {CARDS_DIR}")


if __name__ == "__main__":
    main()
