#!/usr/bin/env python3
"""Generate enhanced and decoupled 2D game assets without requiring AI models:
1. Multi-layered Parallax Background for Act-1 Old Street (雨夜老街分层视差场景)
2. Decoupled character body & prop slices for modular rigging (角色与独立道具拆件)
3. Worn black-lacquer & Daoist talisman card frame UI templates (黑漆木与符纸卡牌框)
"""

from __future__ import annotations

import math
import random
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
ENV_DIR = ROOT / "assets/game/environments/old_street"
CHAR_DIR = ROOT / "assets/game/characters_sliced"
UI_DIR = ROOT / "assets/game/ui"

ENV_DIR.mkdir(parents=True, exist_ok=True)
CHAR_DIR.mkdir(parents=True, exist_ok=True)
UI_DIR.mkdir(parents=True, exist_ok=True)

RNG = random.Random(20260828)


def create_canvas(size: tuple[int, int], bg=(0, 0, 0, 0)) -> tuple[Image.Image, ImageDraw.ImageDraw]:
    img = Image.new("RGBA", size, bg)
    return img, ImageDraw.Draw(img)


def add_fine_noise(img: Image.Image, strength: int = 14, alpha: int = 16) -> Image.Image:
    orig_a = img.getchannel("A")
    noise = Image.effect_noise(img.size, strength).convert("L")
    noise_rgba = Image.merge("RGBA", (noise, noise, noise, Image.new("L", img.size, alpha)))
    res = Image.alpha_composite(img.convert("RGBA"), noise_rgba)
    res.putalpha(orig_a)
    return res


# -------------------------------------------------------------------------
# 1. Multi-layer Parallax Old Street Scene (雨夜老街视差分层场景)
# -------------------------------------------------------------------------

def generate_scene_layers():
    size = (1920, 1080)

    # Layer 0: Sky & Diseased Pale Moon (远景天空与残月)
    l0, d0 = create_canvas(size, (10, 13, 18, 255))
    # Cold moonlight sky glow
    glow_l, gd0 = create_canvas(size)
    for r in range(400, 50, -40):
        gd0.ellipse((1450 - r, 200 - r, 1450 + r, 200 + r), fill=(35, 95, 105, int(math.sin(r/400.0 * math.pi) * 35)))
    l0 = Image.alpha_composite(l0, glow_l.filter(ImageFilter.GaussianBlur(30)))
    d0 = ImageDraw.Draw(l0)
    # The pale diseased moon
    d0.ellipse((1350, 100, 1550, 300), fill=(195, 205, 185, 110))
    d0.ellipse((1370, 120, 1530, 280), fill=(215, 225, 205, 160))
    # Dark cloud bands drifting over moon
    cloud_l, cd = create_canvas(size)
    for cy in [120, 180, 240, 310]:
        cd.ellipse((1200, cy, 1750, cy + 60), fill=(14, 18, 24, 180))
    l0 = Image.alpha_composite(l0, cloud_l.filter(ImageFilter.GaussianBlur(25)))
    l0 = add_fine_noise(l0, 12, 14)
    l0.save(ENV_DIR / "bg_layer0_sky_moon.png", optimize=True)

    # Layer 1: Distant Eaves & Pagoda Silhouettes (远景屋脊剪影)
    l1, d1 = create_canvas(size)
    # Distant dark blue rooftops
    roofs_far = [
        (0, 480, 350, 750), (300, 420, 750, 750), (700, 490, 1100, 750),
        (1050, 430, 1550, 750), (1500, 470, 1920, 750)
    ]
    for x0, y0, x1, y1 in roofs_far:
        d1.rectangle((x0, y0, x1, y1), fill=(15, 20, 26, 210))
        d1.polygon([(x0 - 40, y0 + 15), ((x0 + x1) // 2, y0 - 55), (x1 + 40, y0 + 15)], fill=(12, 16, 22, 230))
    # Distant pagoda spire
    d1.polygon([(920, 440), (940, 280), (960, 440)], fill=(10, 14, 18, 240))
    d1.line([(940, 280), (940, 220)], fill=(8, 11, 14, 255), width=4)
    # Distant haze blur
    l1 = l1.filter(ImageFilter.GaussianBlur(3.5))
    l1 = add_fine_noise(l1, 10, 12)
    l1.save(ENV_DIR / "bg_layer1_distant_eaves.png", optimize=True)

    # Layer 2: Mid-ground Buildings, Eaves & Signboards (中景街道与老街瓦房)
    l2, d2 = create_canvas(size)
    mid_buildings = [
        (-40, 320, 420, 800, (18, 21, 27, 255)),
        (380, 380, 840, 810, (22, 24, 30, 255)),
        (800, 290, 1280, 805, (17, 21, 26, 255)),
        (1240, 350, 1720, 810, (21, 23, 29, 255)),
        (1680, 260, 1960, 810, (16, 20, 25, 255)),
    ]
    for x0, y0, x1, y1, col in mid_buildings:
        d2.rectangle((x0, y0, x1, y1), fill=col)
        # Curved Ming/Qing eaves
        mid_x = (x0 + x1) // 2
        d2.polygon([(x0 - 70, y0 + 20), (mid_x, y0 - 80), (x1 + 70, y0 + 20)], fill=(10, 12, 16, 255))
        d2.line([(x0 - 75, y0 + 25), (x1 + 75, y0 + 25)], fill=(40, 38, 44, 255), width=8)
        # Windows with dim yellow candle light
        for wx in range(x0 + 60, x1 - 50, 130):
            d2.rectangle((wx, y0 + 90, wx + 48, y0 + 145), fill=(120, 75, 35, 90), outline=(32, 26, 24, 255), width=4)
            d2.line([(wx + 24, y0 + 90), (wx + 24, y0 + 145)], fill=(32, 26, 24, 255), width=3)
    
    # Wooden signboards hanging on the far left side only
    d2.rectangle((210, 360, 280, 560), fill=(28, 18, 16, 255), outline=(100, 48, 36, 255), width=5)
    d2.line([(245, 330), (245, 360)], fill=(80, 60, 40, 255), width=6)
    
    l2 = add_fine_noise(l2, 14, 16)
    l2.save(ENV_DIR / "bg_layer2_mid_buildings.png", optimize=True)

    # Layer 3: Wet Cobblestone Ground with Light Reflections (前景湿石路面与光影反光)
    l3, d3 = create_canvas(size)
    d3.polygon([(0, 730), (1920, 730), (1920, 1080), (0, 1080)], fill=(15, 18, 24, 255))
    
    # Wet stone highlights and water puddles
    for _ in range(120):
        y = RNG.randint(750, 1070)
        x = RNG.randint(-50, 1920)
        length = RNG.randint(40, 240)
        # Gold lantern reflections and cold cyan moon reflections
        col = RNG.choice([
            (225, 145, 55, RNG.randint(25, 60)),
            (60, 140, 150, RNG.randint(20, 45)),
            (180, 185, 175, RNG.randint(15, 35))
        ])
        d3.line([(x, y), (x + length, y + RNG.randint(-2, 2))], fill=col, width=RNG.randint(2, 6))
    
    # Cobblestone tile cracks
    for _ in range(80):
        cx = RNG.randint(0, 1920)
        cy = RNG.randint(760, 1060)
        d3.line([(cx, cy), (cx + RNG.randint(30, 90), cy)], fill=(8, 10, 14, 180), width=3)
    
    l3 = add_fine_noise(l3, 16, 18)
    l3.save(ENV_DIR / "bg_layer3_ground_puddles.png", optimize=True)

    # Layer 4: Foreground Rolling Mist & Rain Streaks (近景雨雾与水气)
    l4, d4 = create_canvas(size)
    fog_l, fd4 = create_canvas(size)
    for _ in range(18):
        fy = RNG.randint(450, 950)
        fd4.line([(RNG.randint(-200, 100), fy), (RNG.randint(1200, 2100), fy + RNG.randint(-40, 40))], fill=(90, 130, 135, RNG.randint(12, 30)), width=RNG.randint(25, 65))
    l4 = Image.alpha_composite(l4, fog_l.filter(ImageFilter.GaussianBlur(18)))
    
    # Slanted rain drops
    rain_l, rd4 = create_canvas(size)
    for _ in range(350):
        rx = RNG.randint(-50, 1950)
        ry = RNG.randint(-50, 1080)
        rlen = RNG.randint(15, 45)
        rd4.line([(rx, ry), (rx - 6, ry + rlen)], fill=(160, 195, 205, RNG.randint(20, 80)), width=RNG.choice([1, 1, 2]))
    l4 = Image.alpha_composite(l4, rain_l)
    l4.save(ENV_DIR / "bg_layer4_foreground_fog.png", optimize=True)


# -------------------------------------------------------------------------
# 2. Decoupled Character Slices for Dynamic Rigging (角色解耦拆件)
# -------------------------------------------------------------------------

def generate_sliced_characters():
    # --- 执灯人 (Player Keeper) ---
    # Body clean (No lantern baked in hand)
    size = (640, 800)
    img_body, d_body = create_canvas(size)
    cx, cy = 320, 400
    
    # Shadow under robe
    d_body.polygon([(220, 360), (140, 750), (500, 750), (420, 360)], fill=(12, 14, 18, 255))
    # Layered Daoist robe & straw cape
    d_body.polygon([(250, 320), (180, 680), (460, 680), (390, 320)], fill=(18, 20, 26, 255))
    d_body.polygon([(270, 320), (220, 620), (420, 620), (370, 320)], fill=(28, 30, 38, 255))
    # Head & Conical bamboo hat
    d_body.polygon([(140, 260), (320, 150), (500, 260)], fill=(10, 12, 16, 255))
    d_body.line([(130, 262), (510, 262)], fill=(140, 95, 45, 255), width=7)
    # Eyes glow inside hat shadow
    d_body.ellipse((300, 275, 312, 285), fill=(255, 175, 65, 240))
    d_body.ellipse((328, 275, 340, 285), fill=(255, 175, 65, 240))
    # Left & right arms
    d_body.line([(240, 360), (180, 510)], fill=(14, 16, 20, 255), width=24) # Left holding talisman
    d_body.line([(400, 360), (450, 480)], fill=(14, 16, 20, 255), width=24) # Right arm reaching out to hold lantern chain
    
    img_body = add_fine_noise(img_body, 14)
    img_body.save(CHAR_DIR / "keeper_body_clean.png", optimize=True)

    # Independent Lantern Prop (独立提灯部件，以挂钩为旋转原点)
    l_size = (256, 384)
    l_img, l_draw = create_canvas(l_size)
    lx, ly = 128, 160
    
    # Top chain & hook (Pivot anchor at top (128, 20))
    l_draw.line([(128, 20), (128, 100)], fill=(90, 75, 55, 255), width=5)
    # Wooden frame top & bottom
    l_draw.polygon([(80, 100), (128, 80), (176, 100)], fill=(55, 38, 25, 255))
    l_draw.polygon([(80, 240), (128, 260), (176, 240)], fill=(55, 38, 25, 255))
    # Glowing lantern paper core
    l_draw.rounded_rectangle([(80, 100), (176, 240)], radius=16, fill=(240, 140, 40, 230), outline=(35, 20, 12, 255), width=6)
    l_draw.line([(128, 100), (128, 240)], fill=(65, 35, 18, 200), width=4)
    # Bottom red tassel
    l_draw.line([(128, 260), (128, 340)], fill=(190, 40, 30, 240), width=6)
    
    l_img = add_fine_noise(l_img, 12)
    l_img.save(CHAR_DIR / "keeper_lantern_prop.png", optimize=True)


# -------------------------------------------------------------------------
# 3. Card Frame UI Templates (中式黑漆木与朱砂符纸卡框)
# -------------------------------------------------------------------------

def generate_card_frames():
    size = (400, 560)
    
    frame_configs = [
        ("card_frame_zhan.png", (185, 45, 35), "斩", "刀光符线"),
        ("card_frame_yu.png", (65, 170, 185), "御", "八卦护身"),
        ("card_frame_you.png", (110, 160, 95), "佑", "长明灵结"),
    ]

    for fname, color_rgb, class_name, motif in frame_configs:
        img, draw = create_canvas(size)
        
        # Outer black lacquered wood border (黑漆木基底)
        draw.rounded_rectangle([(10, 10), (390, 550)], radius=18, fill=(18, 20, 24, 255), outline=(45, 48, 55, 255), width=6)
        
        # Inner worn parchment cutout (内嵌旧符纸区域)
        draw.rounded_rectangle([(24, 24), (376, 536)], radius=12, fill=(215, 200, 165, 255), outline=(60, 48, 38, 255), width=4)
        
        # Transparent cutout for card illustration window (透明插画透视窗口)
        # We clear the alpha inside the illustration window (38, 48) to (362, 330)
        draw.rectangle([(38, 48), (362, 330)], fill=(0, 0, 0, 0), outline=(*color_rgb, 220), width=5)
        
        # Cinnabar/Spectral decorative corner runes (四角符文锁边)
        for cx, cy in [(44, 54), (356, 54), (44, 324), (356, 324)]:
            draw.line([(cx - 12, cy), (cx + 12, cy)], fill=(*color_rgb, 240), width=3)
            draw.line([(cx, cy - 12), (cx, cy + 12)], fill=(*color_rgb, 240), width=3)
            
        # Cost badge circle at top-left (左上角还愿点消耗槽)
        draw.ellipse((20, 20, 80, 80), fill=(24, 18, 16, 255), outline=(*color_rgb, 255), width=4)
        
        # Bottom text plaque area (底部技能说明符板)
        draw.rounded_rectangle([(38, 345), (362, 520)], radius=8, fill=(35, 30, 26, 230), outline=(80, 70, 58, 255), width=3)
        
        # Class seal icon backing at top-right (右上角类别印章)
        draw.rectangle([(330, 26), (372, 72)], fill=(*color_rgb, 220), outline=(20, 22, 26, 255), width=3)

        img = add_fine_noise(img, 14, 16)
        img.save(UI_DIR / fname, optimize=True)


def main():
    print("Generating enhanced non-AI art assets...")
    generate_scene_layers()
    print(" - Generated 5-layer Parallax Scene in assets/game/environments/old_street/")
    generate_sliced_characters()
    print(" - Generated Decoupled Character Slices in assets/game/characters_sliced/")
    generate_card_frames()
    print(" - Generated 3-class Card Frames in assets/game/ui/")
    print("All enhanced non-AI art assets successfully created!")


if __name__ == "__main__":
    main()
