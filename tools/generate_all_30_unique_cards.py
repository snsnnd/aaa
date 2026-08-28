#!/usr/bin/env python3
"""Generate 30 completely unique, dedicated, handcrafted card artwork illustrations.
Every single card has its own custom motif, composition, and visual storytelling.
"""

from __future__ import annotations

import math
import random
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
CARDS_DIR = ROOT / "assets/game/cards"
DEMO_DIR = ROOT / "assets/demo"
CARDS_DIR.mkdir(parents=True, exist_ok=True)


def create_canvas(size: tuple[int, int] = (320, 320), bg=(12, 15, 20, 255)) -> tuple[Image.Image, ImageDraw.ImageDraw]:
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


# =========================================================================
# 14 斩 (Slash / Attack / Vengeance) Cards - Unique Draw Functions
# =========================================================================

def draw_attack(img: Image.Image, d: ImageDraw.ImageDraw): # 斩纸 (1费)
    img = radial_glow(img, (160, 160), 110, (215, 160, 75), 140)
    d = ImageDraw.Draw(img)
    # Floating cut paper sheets
    d.polygon([(50, 90), (120, 60), (100, 230), (30, 260)], fill=(215, 200, 165, 240))
    d.polygon([(200, 60), (270, 90), (250, 260), (180, 230)], fill=(195, 180, 145, 220))
    # Razor ink blade cut
    d.line([(25, 265), (295, 55)], fill=(255, 245, 220, 255), width=12)
    d.line([(20, 270), (300, 50)], fill=(185, 45, 35, 220), width=5)
    # Ink drops
    for px, py in [(80, 120), (110, 180), (210, 130), (240, 190)]:
        d.ellipse((px-5, py-5, px+5, py+5), fill=(20, 24, 28, 255))
    return img


def draw_shatter(img: Image.Image, d: ImageDraw.ImageDraw): # 还刃 (2费)
    img = radial_glow(img, (160, 160), 130, (220, 65, 50), 160)
    d = ImageDraw.Draw(img)
    # Crossed dual shattered blades
    d.line([(45, 55), (275, 265)], fill=(215, 45, 40, 255), width=16)
    d.line([(275, 55), (45, 265)], fill=(215, 45, 40, 255), width=16)
    # Golden kintsugi lightning fracture veins
    d.line([(55, 65), (265, 255)], fill=(255, 235, 150, 255), width=6)
    d.line([(265, 65), (55, 255)], fill=(255, 235, 150, 255), width=6)
    # Burning center impact
    d.ellipse((135, 135, 185, 185), fill=(255, 255, 255, 255))
    return img


def draw_duannian(img: Image.Image, d: ImageDraw.ImageDraw): # 断念 (2费)
    img = radial_glow(img, (160, 160), 110, (190, 80, 60), 140)
    d = ImageDraw.Draw(img)
    # Severed red cord of fate
    d.line([(40, 95), (140, 145)], fill=(200, 45, 40, 255), width=9)
    d.line([(180, 175), (280, 225)], fill=(200, 45, 40, 255), width=9)
    # Scissors / Blade snip glint
    d.line([(100, 200), (220, 120)], fill=(230, 235, 240, 255), width=8)
    d.line([(100, 120), (220, 200)], fill=(230, 235, 240, 255), width=8)
    d.ellipse((145, 145, 175, 175), fill=(255, 245, 180, 255))
    return img


def draw_zhuangzhong(img: Image.Image, d: ImageDraw.ImageDraw): # 撞钟 (2费)
    img = radial_glow(img, (160, 150), 120, (220, 170, 75), 140)
    d = ImageDraw.Draw(img)
    # Ancient bronze temple bell
    d.polygon([(110, 110), (210, 110), (235, 220), (85, 220)], fill=(140, 105, 50, 255))
    d.arc([(85, 205), (235, 235)], 0, 180, fill=(240, 195, 95, 255), width=8)
    d.line([(160, 50), (160, 110)], fill=(80, 60, 35, 255), width=8)
    # Vibrating acoustic shockwaves
    for r in [135, 155]:
        d.arc([(160 - r, 160 - r), (160 + r, 160 + r)], 30, 150, fill=(255, 220, 120, 180), width=4)
        d.arc([(160 - r, 160 - r), (160 + r, 160 + r)], 210, 330, fill=(255, 220, 120, 180), width=4)
    return img


def draw_zhuying(img: Image.Image, d: ImageDraw.ImageDraw): # 逐影 (1费)
    img = radial_glow(img, (160, 160), 120, (180, 140, 85), 130)
    d = ImageDraw.Draw(img)
    # Multiple phantom speed trailing silhouettes
    for offset_x in [-60, -30, 0]:
        alpha = 90 + (offset_x + 60) * 2
        d.polygon([(130 + offset_x, 80), (180 + offset_x, 140), (160 + offset_x, 260), (110 + offset_x, 240)], fill=(210, 160, 70, alpha))
    # Leading white motion slash
    d.line([(70, 220), (260, 100)], fill=(255, 250, 230, 255), width=8)
    d.ellipse((250, 95, 275, 115), fill=(255, 235, 160, 255))
    return img


def draw_liebo(img: Image.Image, d: ImageDraw.ImageDraw): # 裂帛 (1费)
    img = radial_glow(img, (160, 160), 110, (210, 85, 75), 140)
    d = ImageDraw.Draw(img)
    # Tattered waving white silk cloth
    d.polygon([(80, 60), (140, 90), (110, 250), (50, 220)], fill=(230, 225, 220, 220))
    d.polygon([(180, 90), (240, 60), (270, 220), (210, 250)], fill=(230, 225, 220, 220))
    # Dual rip slashes in the middle
    d.line([(100, 130), (220, 190)], fill=(225, 50, 45, 255), width=8)
    d.line([(100, 190), (220, 130)], fill=(225, 50, 45, 255), width=8)
    return img


def draw_xuezhang(img: Image.Image, d: ImageDraw.ImageDraw): # 血账 (2费)
    img = radial_glow(img, (160, 160), 120, (200, 50, 45), 150)
    d = ImageDraw.Draw(img)
    # Open antique ledger book
    d.polygon([(60, 90), (155, 110), (155, 250), (60, 230)], fill=(200, 185, 150, 255)) # Left page
    d.polygon([(165, 110), (260, 90), (260, 230), (165, 250)], fill=(215, 200, 165, 255)) # Right page
    d.line([(160, 100), (160, 260)], fill=(80, 50, 30, 255), width=6) # Spine
    # Red blood handprint & seal stamps
    d.ellipse((180, 130, 220, 170), fill=(185, 35, 30, 220)) # Seal
    d.line([(90, 140), (130, 180)], fill=(185, 35, 30, 200), width=6)
    d.line([(90, 180), (130, 140)], fill=(185, 35, 30, 200), width=6)
    return img


def draw_baiguyin(img: Image.Image, d: ImageDraw.ImageDraw): # 白骨引 (2费)
    img = radial_glow(img, (160, 160), 120, (190, 215, 225), 140)
    d = ImageDraw.Draw(img)
    # Skeletal hand claw reaching from underworld
    d.polygon([(135, 190), (185, 190), (175, 260), (145, 260)], fill=(225, 225, 215, 255)) # Wrist
    for i, fx in enumerate([105, 135, 165, 195, 220]): # 5 Bone fingers
        fy = 95 + abs(i - 2) * 15
        d.line([(160 + (i - 2) * 12, 190), (fx, fy + 35), (fx - 5, fy)], fill=(235, 235, 225, 255), width=7)
    # Cyan spirit flame
    d.ellipse((145, 75, 175, 105), fill=(95, 215, 230, 200))
    return img


def draw_shoulian(img: Image.Image, d: ImageDraw.ImageDraw): # 收殓 (3费)
    img = radial_glow(img, (160, 160), 110, (180, 150, 100), 130)
    d = ImageDraw.Draw(img)
    # White funeral coffin shroud binding
    d.polygon([(90, 70), (230, 70), (210, 250), (110, 250)], fill=(210, 205, 190, 240))
    # Red tying rope
    d.line([(80, 120), (240, 120)], fill=(185, 45, 35, 255), width=6)
    d.line([(90, 180), (230, 180)], fill=(185, 45, 35, 255), width=6)
    # Copper burial coins on eyes
    d.ellipse((120, 85, 145, 110), fill=(180, 140, 60, 255), outline=(50, 35, 20, 255), width=2)
    d.ellipse((175, 85, 200, 110), fill=(180, 140, 60, 255), outline=(50, 35, 20, 255), width=2)
    return img


def draw_shuangdeng(img: Image.Image, d: ImageDraw.ImageDraw): # 双灯照 (3费)
    img = radial_glow(img, (110, 160), 90, (235, 140, 45), 140)
    img = radial_glow(img, (210, 160), 90, (65, 185, 165), 140)
    d = ImageDraw.Draw(img)
    # Left warm amber lantern
    d.rounded_rectangle([(75, 110), (145, 210)], radius=12, fill=(240, 140, 40, 220), outline=(50, 30, 15, 255), width=5)
    d.line([(110, 70), (110, 110)], fill=(80, 50, 30, 255), width=5)
    # Right cold jade lantern
    d.rounded_rectangle([(175, 110), (245, 210)], radius=12, fill=(65, 195, 175, 220), outline=(15, 40, 35, 255), width=5)
    d.line([(210, 70), (210, 110)], fill=(40, 60, 55, 255), width=5)
    return img


def draw_yuangui(img: Image.Image, d: ImageDraw.ImageDraw): # 怨归 (3费)
    img = radial_glow(img, (160, 160), 120, (195, 45, 40), 150)
    d = ImageDraw.Draw(img)
    # Vengeful spirit mask silhouette
    d.polygon([(110, 100), (210, 100), (230, 180), (160, 250), (90, 180)], fill=(25, 20, 25, 255), outline=(195, 45, 40, 255), width=6)
    # Glowing sharp wrath eyes
    d.line([(120, 140), (145, 150)], fill=(255, 60, 50, 255), width=6)
    d.line([(200, 140), (175, 150)], fill=(255, 60, 50, 255), width=6)
    # Fangs & crying red blood tears
    d.line([(135, 155), (135, 210)], fill=(185, 35, 30, 200), width=4)
    d.line([(185, 155), (185, 210)], fill=(185, 35, 30, 200), width=4)
    return img


def draw_tianping(img: Image.Image, d: ImageDraw.ImageDraw): # 极·天平倒悬 (5费)
    img = radial_glow(img, (160, 160), 130, (235, 60, 50), 170)
    d = ImageDraw.Draw(img)
    # Tilted broken beam
    d.line([(60, 230), (260, 90)], fill=(210, 175, 95, 255), width=12)
    d.line([(160, 60), (160, 160)], fill=(160, 125, 65, 255), width=10)
    # Scale pans (Left low, right high)
    d.arc([(35, 230), (105, 280)], 0, 180, fill=(180, 45, 35, 255), width=6)
    d.line([(70, 205), (45, 245)], fill=(120, 90, 50, 255), width=3)
    d.line([(70, 205), (95, 245)], fill=(120, 90, 50, 255), width=3)
    d.arc([(215, 90), (285, 140)], 0, 180, fill=(230, 190, 100, 255), width=6)
    d.line([(250, 65), (225, 105)], fill=(120, 90, 50, 255), width=3)
    d.line([(250, 65), (275, 105)], fill=(120, 90, 50, 255), width=3)
    d.ellipse((145, 145, 175, 175), fill=(255, 255, 255, 255))
    return img


# =========================================================================
# 8 御 (Ward / Defense / Interruption) Cards - Unique Draw Functions
# =========================================================================

def draw_guard(img: Image.Image, d: ImageDraw.ImageDraw): # 镇煞 (2费)
    img = radial_glow(img, (160, 160), 120, (65, 175, 185), 150)
    d = ImageDraw.Draw(img)
    # Bagua circle & Yin Yang
    d.ellipse((60, 60, 260, 260), outline=(100, 225, 235, 240), width=6)
    d.ellipse((85, 85, 235, 235), outline=(65, 160, 175, 180), width=4)
    for i in range(8):
        a = i * (math.pi / 4)
        x1, y1 = 160 + math.cos(a) * 90, 160 + math.sin(a) * 90
        x2, y2 = 160 + math.cos(a) * 125, 160 + math.sin(a) * 125
        d.line([(x1, y1), (x2, y2)], fill=(120, 240, 250, 220), width=4)
    d.ellipse((135, 135, 185, 185), fill=(220, 250, 255, 240))
    d.ellipse((150, 150, 170, 170), fill=(20, 30, 40, 255))
    return img


def draw_difan(img: Image.Image, d: ImageDraw.ImageDraw): # 低幡 (1费)
    img = radial_glow(img, (160, 160), 110, (75, 145, 165), 130)
    d = ImageDraw.Draw(img)
    # Mourning Spirit Streamer Banner (招魂幡)
    d.line([(160, 40), (160, 270)], fill=(90, 70, 50, 255), width=7) # Pole
    d.polygon([(160, 60), (90, 110), (160, 160), (100, 210), (160, 250)], fill=(220, 230, 235, 220))
    d.polygon([(160, 60), (230, 110), (160, 160), (220, 210), (160, 250)], fill=(190, 205, 215, 200))
    return img


def draw_jieshi(img: Image.Image, d: ImageDraw.ImageDraw): # 借势 (1费)
    img = radial_glow(img, (160, 160), 120, (230, 195, 80), 150)
    d = ImageDraw.Draw(img)
    # Soaring golden whirlwind / dragon crest
    pts = []
    for i in range(24):
        a = i * 0.35
        r = 30 + i * 4.5
        pts.append((160 + math.cos(a) * r, 160 + math.sin(a) * r))
    d.line(pts, fill=(255, 225, 110, 255), width=8, joint="curve")
    d.polygon([(240, 110), (270, 150), (220, 165)], fill=(255, 240, 160, 255)) # Arrow head
    return img


def draw_tongjing(img: Image.Image, d: ImageDraw.ImageDraw): # 铜镜 (1费)
    img = radial_glow(img, (160, 160), 120, (140, 195, 210), 150)
    d = ImageDraw.Draw(img)
    # Ancient round bronze mirror
    d.ellipse((65, 65, 255, 255), fill=(40, 55, 65, 255), outline=(180, 145, 85, 255), width=12)
    d.ellipse((85, 85, 235, 235), outline=(210, 180, 110, 200), width=4)
    # Reflection ray
    d.line([(90, 210), (210, 90)], fill=(200, 245, 255, 230), width=10)
    d.line([(130, 230), (230, 130)], fill=(160, 220, 240, 170), width=6)
    return img


def draw_fuhunsuo(img: Image.Image, d: ImageDraw.ImageDraw): # 缚魂索 (2费)
    img = radial_glow(img, (160, 160), 120, (65, 165, 180), 140)
    d = ImageDraw.Draw(img)
    # Coiling spectral chain links
    for i in range(5):
        cx = 85 + i * 36
        cy = 160 + math.sin(i * 1.2) * 45
        d.ellipse((cx - 24, cy - 16, cx + 24, cy + 16), outline=(90, 210, 225, 255), width=6)
        d.ellipse((cx - 14, cy - 8, cx + 14, cy + 8), fill=(25, 40, 50, 255))
    return img


def draw_jiedao(img: Image.Image, d: ImageDraw.ImageDraw): # 借刀 (2费)
    img = radial_glow(img, (160, 160), 110, (80, 185, 190), 140)
    d = ImageDraw.Draw(img)
    # Floating downward pointing spectral dagger
    d.polygon([(160, 260), (140, 120), (180, 120)], fill=(110, 225, 235, 240))
    d.line([(160, 260), (160, 120)], fill=(240, 255, 255, 255), width=4)
    d.rectangle([(120, 110), (200, 124)], fill=(60, 80, 90, 255)) # Crossguard
    d.line([(160, 60), (160, 110)], fill=(45, 60, 70, 255), width=8) # Hilt
    return img


def draw_jinshen(img: Image.Image, d: ImageDraw.ImageDraw): # 金身 (2费)
    img = radial_glow(img, (160, 160), 130, (230, 190, 110), 160)
    d = ImageDraw.Draw(img)
    # Golden Vajra shield hexagon
    poly = []
    for i in range(6):
        a = i * (math.pi / 3) + math.pi / 6
        poly.append((160 + math.cos(a) * 95, 160 + math.sin(a) * 95))
    d.polygon(poly, fill=(180, 140, 60, 140), outline=(255, 230, 140, 255), width=7)
    # Inner Buddhist/Daoist cross
    d.line([(160, 95), (160, 225)], fill=(255, 245, 190, 255), width=8)
    d.line([(95, 160), (225, 160)], fill=(255, 245, 190, 255), width=8)
    return img


def draw_podan(img: Image.Image, d: ImageDraw.ImageDraw): # 破胆 (2费)
    img = radial_glow(img, (160, 160), 120, (155, 90, 185), 140)
    d = ImageDraw.Draw(img)
    # Terrified ghostly skull splitting
    d.ellipse((95, 80, 225, 200), fill=(160, 120, 185, 200), outline=(220, 180, 245, 255), width=5)
    # Hollow screaming eyes and mouth
    d.ellipse((120, 120, 145, 155), fill=(20, 14, 28, 255))
    d.ellipse((175, 120, 200, 155), fill=(20, 14, 28, 255))
    d.ellipse((145, 170, 175, 215), fill=(20, 14, 28, 255))
    # Shattering purple crack
    d.line([(160, 65), (150, 130), (170, 180), (160, 235)], fill=(255, 230, 255, 255), width=6)
    return img


def draw_duanxiang(img: Image.Image, d: ImageDraw.ImageDraw): # 断香 (1费)
    img = radial_glow(img, (160, 160), 110, (110, 170, 160), 130)
    d = ImageDraw.Draw(img)
    # Three incense sticks snapped in half
    for i, offset_x in enumerate([-35, 0, 35]):
        # Lower stick in censer
        d.line([(160 + offset_x, 160), (160 + offset_x, 260)], fill=(120, 80, 50, 255), width=5)
        # Snapped upper burning tip falling
        d.line([(160 + offset_x + 15, 145), (160 + offset_x + 35, 75)], fill=(140, 90, 60, 255), width=5)
        # Glowing red ash tip
        d.ellipse((160 + offset_x + 32, 70, 160 + offset_x + 38, 76), fill=(255, 60, 40, 255))
    return img


# =========================================================================
# 8 佑 (Bless / Lantern / Life) Cards - Unique Draw Functions
# =========================================================================

def draw_shift(img: Image.Image, d: ImageDraw.ImageDraw): # 续灯 (2费)
    img = radial_glow(img, (160, 150), 120, (235, 140, 45), 160)
    d = ImageDraw.Draw(img)
    # Lotus lantern bowl base
    d.polygon([(100, 230), (220, 230), (240, 190), (80, 190)], fill=(65, 45, 30, 255))
    d.arc([(80, 180), (240, 240)], 0, 180, fill=(180, 110, 45, 255), width=6)
    # Warm flame core
    d.polygon([(160, 50), (195, 120), (200, 170), (160, 190), (120, 170), (125, 120)], fill=(245, 135, 35, 230))
    d.polygon([(160, 80), (180, 130), (180, 165), (160, 175), (140, 165), (140, 130)], fill=(255, 230, 120, 255))
    d.ellipse((150, 130, 170, 160), fill=(255, 255, 255, 255))
    return img


def draw_dengxin(img: Image.Image, d: ImageDraw.ImageDraw): # 灯芯 (1费)
    img = radial_glow(img, (160, 160), 115, (245, 165, 60), 150)
    d = ImageDraw.Draw(img)
    # Braided golden wick rope
    d.line([(160, 150), (160, 260)], fill=(180, 130, 50, 255), width=8)
    # Pure white hot flame spark
    d.polygon([(160, 60), (185, 120), (160, 150), (135, 120)], fill=(255, 240, 160, 255))
    d.ellipse((152, 105, 168, 135), fill=(255, 255, 255, 255))
    return img


def draw_tianyou(img: Image.Image, d: ImageDraw.ImageDraw): # 添油 (2费)
    img = radial_glow(img, (160, 160), 120, (230, 160, 50), 150)
    d = ImageDraw.Draw(img)
    # Ceramic oil flask tilting
    d.polygon([(90, 90), (150, 60), (180, 120), (120, 150)], fill=(120, 85, 55, 255), outline=(190, 140, 85, 255), width=4)
    # Golden oil pouring stream
    d.line([(165, 110), (185, 180), (195, 250)], fill=(255, 210, 80, 255), width=8)
    d.ellipse((180, 235, 210, 265), fill=(255, 235, 140, 255))
    return img


def draw_wenlu(img: Image.Image, d: ImageDraw.ImageDraw): # 问路 (1费)
    img = radial_glow(img, (160, 160), 120, (135, 195, 145), 140)
    d = ImageDraw.Draw(img)
    # Daoist Geomantic Compass (风水罗盘)
    d.ellipse((60, 60, 260, 260), fill=(45, 60, 45, 255), outline=(190, 160, 90, 255), width=10)
    d.ellipse((95, 95, 225, 225), outline=(140, 180, 130, 200), width=3)
    # Red & White South-pointing Needle
    d.polygon([(160, 85), (172, 160), (148, 160)], fill=(225, 45, 35, 255)) # North red needle
    d.polygon([(160, 235), (172, 160), (148, 160)], fill=(240, 245, 240, 255)) # South white needle
    d.ellipse((152, 152, 168, 168), fill=(210, 180, 100, 255))
    return img


def draw_zhima(img: Image.Image, d: ImageDraw.ImageDraw): # 纸马 (2费)
    img = radial_glow(img, (160, 160), 120, (150, 195, 140), 140)
    d = ImageDraw.Draw(img)
    # Paper funeral horse
    d.polygon([(100, 140), (220, 140), (200, 210), (110, 210)], fill=(230, 225, 205, 255)) # Body
    d.polygon([(190, 140), (235, 80), (255, 95), (215, 160)], fill=(230, 225, 205, 255)) # Head
    d.line([(110, 210), (95, 275)], fill=(200, 190, 170, 255), width=8)
    d.line([(135, 210), (130, 275)], fill=(200, 190, 170, 255), width=8)
    d.line([(180, 210), (175, 275)], fill=(200, 190, 170, 255), width=8)
    d.line([(205, 210), (215, 275)], fill=(200, 190, 170, 255), width=8)
    d.polygon([(140, 140), (180, 140), (175, 180), (145, 180)], fill=(185, 45, 35, 230)) # Saddle
    return img


def draw_changming(img: Image.Image, d: ImageDraw.ImageDraw): # 长明 (2费)
    img = radial_glow(img, (160, 160), 125, (240, 180, 70), 150)
    d = ImageDraw.Draw(img)
    # Everlasting stone pagoda lamp
    d.polygon([(120, 190), (200, 190), (220, 260), (100, 260)], fill=(70, 75, 80, 255)) # Base
    d.polygon([(90, 140), (230, 140), (160, 90)], fill=(90, 95, 100, 255)) # Roof
    # Bright everlasting flame core inside
    d.ellipse((140, 145, 180, 185), fill=(255, 235, 120, 255))
    d.ellipse((150, 155, 170, 175), fill=(255, 255, 255, 255))
    return img


def draw_jieshou(img: Image.Image, d: ImageDraw.ImageDraw): # 借寿 (1费)
    img = radial_glow(img, (160, 160), 120, (225, 75, 65), 150)
    d = ImageDraw.Draw(img)
    # Antique hourglass with glowing red life sand flowing upward
    d.polygon([(100, 60), (220, 60), (170, 150), (150, 150)], fill=(180, 140, 70, 255)) # Upper glass
    d.polygon([(100, 260), (220, 260), (170, 170), (150, 170)], fill=(180, 140, 70, 255)) # Lower glass
    # Glowing upward sand stream
    d.line([(160, 230), (160, 90)], fill=(255, 75, 60, 255), width=6)
    d.ellipse((140, 80, 180, 110), fill=(255, 120, 100, 240)) # Upper life pool
    return img


def draw_anhun(img: Image.Image, d: ImageDraw.ImageDraw): # 安魂 (1费)
    img = radial_glow(img, (160, 160), 120, (140, 205, 180), 140)
    d = ImageDraw.Draw(img)
    # Serene blooming spirit lotus
    cx, cy = 160, 170
    for a in [-0.6, -0.3, 0.0, 0.3, 0.6]:
        px = cx + math.sin(a) * 55
        py = cy - math.cos(a) * 65
        d.polygon([(cx - 15, cy), (px, py), (cx + 15, cy)], fill=(215, 240, 230, 220))
    d.ellipse((cx - 25, cy - 20, cx + 25, cy + 20), fill=(255, 245, 180, 255))
    d.arc([(90, 160), (230, 220)], 0, 180, fill=(80, 160, 130, 240), width=8)
    return img


def draw_tinggeng(img: Image.Image, d: ImageDraw.ImageDraw): # 听更 (1费)
    img = radial_glow(img, (160, 160), 120, (160, 205, 160), 140)
    d = ImageDraw.Draw(img)
    # Bamboo watchman clapper (梆子) and mallet
    d.rounded_rectangle([(80, 120), (200, 190)], radius=12, fill=(130, 95, 55, 255), outline=(210, 175, 110, 255), width=5)
    d.line([(110, 155), (170, 155)], fill=(45, 30, 18, 255), width=6) # Sound slit
    d.line([(180, 70), (240, 210)], fill=(160, 120, 70, 255), width=10) # Striker mallet
    # Sound ripples
    d.arc([(180, 70), (280, 170)], 270, 60, fill=(230, 245, 190, 200), width=4)
    return img


# =========================================================================
# Master Dispatcher Table
# =========================================================================

CARD_DISPATCHER = {
    # 斩类 (12)
    "attack": draw_attack,
    "shatter": draw_shatter,
    "duannian": draw_duannian,
    "zhuangzhong": draw_zhuangzhong,
    "zhuying": draw_zhuying,
    "liebo": draw_liebo,
    "xuezhang": draw_xuezhang,
    "baiguyin": draw_baiguyin,
    "shoulian": draw_shoulian,
    "shuangdeng": draw_shuangdeng,
    "yuangui": draw_yuangui,
    "tianping": draw_tianping,
    # 御类 (9)
    "guard": draw_guard,
    "difan": draw_difan,
    "jieshi": draw_jieshi,
    "tongjing": draw_tongjing,
    "fuhunsuo": draw_fuhunsuo,
    "jiedao": draw_jiedao,
    "jinshen": draw_jinshen,
    "podan": draw_podan,
    "duanxiang": draw_duanxiang,
    # 佑类 (9)
    "shift": draw_shift,
    "dengxin": draw_dengxin,
    "tianyou": draw_tianyou,
    "wenlu": draw_wenlu,
    "zhima": draw_zhima,
    "changming": draw_changming,
    "jieshou": draw_jieshou,
    "anhun": draw_anhun,
    "tinggeng": draw_tinggeng,
}


def main():
    print("Generating 30 completely unique, dedicated, handcrafted card artwork illustrations...")
    for stem, draw_fn in CARD_DISPATCHER.items():
        img, d = create_canvas()
        img = draw_fn(img, d)
        img = add_fine_noise(img, 12)
        
        # Save to game cards folder
        out_path = CARDS_DIR / f"card_{stem}.png"
        img.save(out_path, optimize=True)
        print(f" [OK] card_{stem}.png generated.")
        
        # Also sync demo cards
        if stem in ["attack", "guard", "shatter", "shift"]:
            img.save(DEMO_DIR / f"card_{stem}.png", optimize=True)

    print(f"\nAll 30 unique card artwork illustrations successfully generated in: {CARDS_DIR}")


if __name__ == "__main__":
    main()
