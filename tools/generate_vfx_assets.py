#!/usr/bin/env python3
"""Generate high-quality visual effect (VFX) texture assets for the game.
Theme: Eastern Folk Horror / Painterly Hand-drawn (手绘厚涂中式怪谈)
Textures include:
- Sharp parry diamond sparks (弹反白金星芒)
- Calligraphy brush crescent slash (水墨刀光月弧)
- Daoist yellow talisman paper shards (朱砂黄纸符片)
- Chinese ink splatter and dispersion (浓淡水墨飞溅)
- Radial shockwave rings (径向冲击波光环)
- Daoist Bagua suppression seal array (八卦镇煞法阵)
- Bronze bell acoustic resonance ripple (铜钟音波纹)
- Eerie wispy ghost flame (冷青幽冥鬼火)
- High-energy ember particles (命火余烬碎屑)
- Dual cross impact flash (十字重斩光芒)
- Seamless noise for burn/dissolve shaders (符纸燃烧消散噪波)
"""

from __future__ import annotations

import math
import random
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
VFX_DIR = ROOT / "assets/game/vfx"
TEXTURES_DIR = VFX_DIR / "textures"
TEXTURES_DIR.mkdir(parents=True, exist_ok=True)

RNG = random.Random(20260828)


def create_canvas(size: tuple[int, int] = (512, 512), bg=(0, 0, 0, 0)) -> tuple[Image.Image, ImageDraw.ImageDraw]:
    img = Image.new("RGBA", size, bg)
    return img, ImageDraw.Draw(img)


def apply_radial_glow(img: Image.Image, center: tuple[int, int], radius: int, color: tuple[int, int, int], alpha: int = 255) -> Image.Image:
    w, h = img.size
    cx, cy = center
    glow_img, draw = create_canvas((w, h))
    for step in range(5, 0, -1):
        r = int(radius * (step / 5.0))
        cur_alpha = int((alpha / 5.0) * (6 - step) * 0.7)
        draw.ellipse((cx - r, cy - r, cx + r, cy + r), fill=(*color, cur_alpha))
    filtered = glow_img.filter(ImageFilter.GaussianBlur(max(4, radius // 6)))
    return Image.alpha_composite(img, filtered)


def add_fine_noise(img: Image.Image, strength: int = 12) -> Image.Image:
    alpha = img.getchannel("A")
    noise = Image.effect_noise(img.size, strength).convert("L")
    noise_rgba = Image.merge("RGBA", (noise, noise, noise, Image.new("L", img.size, strength)))
    result = Image.alpha_composite(img, noise_rgba)
    result.putalpha(alpha)
    return result


def generate_spark_sharp():
    """Generates sharp 4-pointed diamond parry spark with intense white core and golden corona."""
    size = (512, 512)
    img, draw = create_canvas(size)
    cx, cy = 256, 256

    # Soft golden background glow
    img = apply_radial_glow(img, (cx, cy), 180, (255, 200, 80), 90)
    img = apply_radial_glow(img, (cx, cy), 80, (255, 240, 180), 160)

    # Sharp horizontal and vertical needles (White/Gold)
    needle_layer, ndraw = create_canvas(size)
    # Horizontal spike
    ndraw.polygon([(30, cy), (cx, cy - 8), (482, cy), (cx, cy + 8)], fill=(255, 245, 200, 240))
    # Vertical spike
    ndraw.polygon([(cx, 30), (cx + 8, cy), (cx, 482), (cx - 8, cy)], fill=(255, 245, 200, 240))
    # Diagonal smaller spikes
    ndraw.polygon([(cx - 100, cy - 100), (cx + 5, cy - 5), (cx + 100, cy + 100), (cx - 5, cy + 5)], fill=(255, 215, 110, 180))
    ndraw.polygon([(cx + 100, cy - 100), (cx + 5, cy + 5), (cx - 100, cy + 100), (cx - 5, cy - 5)], fill=(255, 215, 110, 180))

    # Center intense diamond
    ndraw.polygon([(cx - 40, cy), (cx, cy - 40), (cx + 40, cy), (cx, cy + 40)], fill=(255, 255, 255, 255))
    ndraw.ellipse((cx - 16, cy - 16, cx + 16, cy + 16), fill=(255, 255, 255, 255))

    needle_blurred = needle_layer.filter(ImageFilter.GaussianBlur(1.5))
    img = Image.alpha_composite(img, needle_blurred)
    img = Image.alpha_composite(img, needle_layer)

    img.save(TEXTURES_DIR / "tex_spark_sharp.png", optimize=True)


def generate_slash_arc():
    """Generates a calligraphy brush crescent slash with dynamic thickness and ink fade."""
    size = (512, 512)
    img, draw = create_canvas(size)
    cx, cy = 256, 256

    # Draw curving crescent blade sweep
    points_outer = []
    points_inner = []
    
    start_angle = -math.pi * 0.75
    end_angle = math.pi * 0.55
    steps = 60

    for i in range(steps + 1):
        t = i / float(steps)
        angle = start_angle + t * (end_angle - start_angle)
        
        # radius changes to create a tapered crescent
        outer_r = 210.0 + math.sin(t * math.pi) * 20.0
        # thickness peaks at t=0.6
        thickness = math.sin(t * math.pi) ** 1.5 * 38.0
        inner_r = max(10.0, outer_r - thickness)
        
        ox = cx + math.cos(angle) * outer_r
        oy = cy + math.sin(angle) * outer_r
        ix = cx + math.cos(angle) * inner_r
        iy = cy + math.sin(angle) * inner_r
        
        points_outer.append((ox, oy))
        points_inner.insert(0, (ix, iy))

    poly = points_outer + points_inner
    
    # Glow layer
    glow_layer, gdraw = create_canvas(size)
    gdraw.polygon(poly, fill=(255, 220, 130, 140))
    glow_blurred = glow_layer.filter(ImageFilter.GaussianBlur(12.0))
    img = Image.alpha_composite(img, glow_blurred)

    # Core stroke (Golden white with ink brush texture)
    core_layer, cdraw = create_canvas(size)
    cdraw.polygon(poly, fill=(255, 250, 220, 240))
    
    # Inner sharp white spine
    spine_outer = []
    spine_inner = []
    for i in range(10, steps - 5):
        t = i / float(steps)
        angle = start_angle + t * (end_angle - start_angle)
        outer_r = 208.0 + math.sin(t * math.pi) * 18.0
        thickness = math.sin(t * math.pi) ** 2.0 * 14.0
        inner_r = max(10.0, outer_r - thickness)
        ox = cx + math.cos(angle) * outer_r
        oy = cy + math.sin(angle) * outer_r
        ix = cx + math.cos(angle) * inner_r
        iy = cy + math.sin(angle) * inner_r
        spine_outer.append((ox, oy))
        spine_inner.insert(0, (ix, iy))
    
    cdraw.polygon(spine_outer + spine_inner, fill=(255, 255, 255, 255))
    
    img = Image.alpha_composite(img, core_layer)
    img = add_fine_noise(img, 14)
    img.save(TEXTURES_DIR / "tex_slash_arc.png", optimize=True)


def generate_talisman_shard():
    """Generates Daoist talisman parchment paper fragments with cinnabar talisman ink and burnt edges."""
    size = (512, 512)
    img, draw = create_canvas(size)
    
    # Yellow paper base
    paper_layer, pdraw = create_canvas(size)
    # Irregular torn rectangular paper
    poly = [
        (120, 80), (370, 70), (410, 120), (390, 410), (350, 440), (140, 430), (95, 380), (105, 140)
    ]
    pdraw.polygon(poly, fill=(225, 202, 145, 255))
    
    # Paper border & burnt edges
    b_layer, bdraw = create_canvas(size)
    bdraw.polygon(poly, outline=(65, 42, 28, 240), width=6)
    # Burn marks (dark brown/black scorched spots)
    for bx, by, br in [(120, 80, 26), (370, 70, 22), (390, 410, 32), (140, 430, 28), (250, 435, 18)]:
        bdraw.ellipse((bx - br, by - br, bx + br, by + br), fill=(40, 24, 16, 200))
    
    paper_composite = Image.alpha_composite(paper_layer, b_layer)
    
    # Cinnabar Red Daoist Runes (朱砂符箓)
    rune_layer, rdraw = create_canvas(size)
    c_red = (185, 35, 30, 240)
    # Top talisman header 罡/敕
    rdraw.line([(210, 120), (300, 120)], fill=c_red, width=9)
    rdraw.line([(256, 120), (256, 170)], fill=c_red, width=8)
    rdraw.arc([(220, 140), (290, 190)], start=0, end=180, fill=c_red, width=7)
    
    # Mysterious talisman cursive curves (符胆)
    rdraw.line([(256, 180), (256, 320)], fill=c_red, width=10)
    rdraw.line([(200, 220), (310, 220)], fill=c_red, width=8)
    rdraw.line([(215, 260), (295, 260)], fill=c_red, width=7)
    rdraw.line([(205, 295), (305, 295)], fill=c_red, width=8)
    
    # Lightning hook bottom
    rdraw.line([(256, 320), (290, 350), (230, 380), (275, 410)], fill=c_red, width=8)
    
    # Composite all layers
    img = Image.alpha_composite(paper_composite, rune_layer)
    img = add_fine_noise(img, 18)
    img.save(TEXTURES_DIR / "tex_talisman_shard.png", optimize=True)


def generate_ink_splatter():
    """Generates realistic Chinese ink wash splatter with fine dispersal droplets."""
    size = (512, 512)
    img, draw = create_canvas(size)
    cx, cy = 256, 256

    ink_layer, idraw = create_canvas(size)
    # Central ink blob with organic edge
    for i in range(16):
        angle = i * (2 * math.pi / 16) + RNG.uniform(-0.15, 0.15)
        dist = RNG.uniform(30, 75)
        rad = RNG.uniform(25, 55)
        bx = cx + math.cos(angle) * dist
        by = cy + math.sin(angle) * dist
        idraw.ellipse((bx - rad, by - rad, bx + rad, by + rad), fill=(18, 20, 24, 230))

    # Core deep black
    idraw.ellipse((cx - 45, cy - 45, cx + 45, cy + 45), fill=(8, 10, 12, 255))

    # Flying ink tendrils & droplets
    for _ in range(32):
        angle = RNG.uniform(0, 2 * math.pi)
        length = RNG.uniform(80, 220)
        thick = RNG.uniform(4, 14)
        
        # Streak
        ex = cx + math.cos(angle) * length
        ey = cy + math.sin(angle) * length
        idraw.line([(cx + math.cos(angle) * 30, cy + math.sin(angle) * 30), (ex, ey)], fill=(15, 17, 20, 210), width=int(thick))
        
        # Flying droplet at tail
        drop_dist = length + RNG.uniform(10, 45)
        drop_rad = RNG.uniform(3, 10)
        dx = cx + math.cos(angle) * drop_dist
        dy = cy + math.sin(angle) * drop_dist
        idraw.ellipse((dx - drop_rad, dy - drop_rad, dx + drop_rad, dy + drop_rad), fill=(12, 14, 16, 230))

    # Fine spray
    for _ in range(90):
        angle = RNG.uniform(0, 2 * math.pi)
        dist = RNG.uniform(50, 240)
        rad = RNG.uniform(1.2, 3.5)
        px = cx + math.cos(angle) * dist
        py = cy + math.sin(angle) * dist
        idraw.ellipse((px - rad, py - rad, px + rad, py + rad), fill=(20, 22, 26, 180))

    img = Image.alpha_composite(img, ink_layer)
    img.save(TEXTURES_DIR / "tex_ink_splatter.png", optimize=True)


def generate_shockwave_ring():
    """Generates a smooth concentric high-frequency shockwave ring."""
    size = (512, 512)
    img, draw = create_canvas(size)
    cx, cy = 256, 256

    # Multiple concentric fading rings
    ring_layer, rdraw = create_canvas(size)
    
    # Outer glow ring
    for i in range(20):
        r = 180 + i * 2
        alpha = int(math.sin(i / 20.0 * math.pi) * 120)
        rdraw.ellipse((cx - r, cy - r, cx + r, cy + r), outline=(255, 230, 160, alpha), width=2)

    # Sharp bright core ring
    rdraw.ellipse((cx - 200, cy - 200, cx + 200, cy + 200), outline=(255, 255, 255, 240), width=6)
    rdraw.ellipse((cx - 194, cy - 194, cx + 194, cy + 194), outline=(255, 215, 120, 190), width=4)
    rdraw.ellipse((cx - 206, cy - 206, cx + 206, cy + 206), outline=(255, 215, 120, 190), width=4)

    # Inner faint echo ring
    rdraw.ellipse((cx - 140, cy - 140, cx + 140, cy + 140), outline=(255, 240, 190, 90), width=3)

    img = apply_radial_glow(img, (cx, cy), 220, (255, 210, 110), 60)
    img = Image.alpha_composite(img, ring_layer)
    img.save(TEXTURES_DIR / "tex_shockwave_ring.png", optimize=True)


def generate_seal_bagua():
    """Generates ancient Daoist Bagua suppression seal array (镇煞封印法阵)."""
    size = (512, 512)
    img, draw = create_canvas(size)
    cx, cy = 256, 256

    seal_layer, sdraw = create_canvas(size)
    cyan_bright = (120, 235, 245, 240)
    cyan_glow = (60, 180, 200, 160)

    # Outer double talisman boundary circles
    sdraw.ellipse((cx - 240, cy - 240, cx + 240, cy + 240), outline=cyan_bright, width=5)
    sdraw.ellipse((cx - 224, cy - 224, cx + 224, cy + 224), outline=cyan_glow, width=3)
    sdraw.ellipse((cx - 165, cy - 165, cx + 165, cy + 165), outline=cyan_glow, width=3)

    # Eight Trigrams (Bagua) segments
    for i in range(8):
        angle = i * (2 * math.pi / 8)
        # Radial division marks
        x1 = cx + math.cos(angle) * 168
        y1 = cy + math.sin(angle) * 168
        x2 = cx + math.cos(angle) * 222
        y2 = cy + math.sin(angle) * 222
        sdraw.line([(x1, y1), (x2, y2)], fill=cyan_bright, width=3)

        # Trigram lines (Yin/Yang bars)
        mid_angle = angle + (math.pi / 8)
        bar_r = 195
        bx = cx + math.cos(mid_angle) * bar_r
        by = cy + math.sin(mid_angle) * bar_r
        
        # Draw small 3 horizontal bars oriented perpendicularly
        perp = mid_angle + math.pi / 2
        for layer_idx in [-8, 0, 8]:
            lr = bar_r + layer_idx
            p1x = cx + math.cos(mid_angle) * lr + math.cos(perp) * 14
            p1y = cy + math.sin(mid_angle) * lr + math.sin(perp) * 14
            p2x = cx + math.cos(mid_angle) * lr - math.cos(perp) * 14
            p2y = cy + math.sin(mid_angle) * lr - math.sin(perp) * 14
            sdraw.line([(p1x, p1y), (p2x, p2y)], fill=cyan_bright, width=3)

    # Inner Taiji / Yin-Yang circle
    sdraw.ellipse((cx - 85, cy - 85, cx + 85, cy + 85), outline=cyan_bright, width=4)
    # S curve
    sdraw.arc((cx - 42, cy - 85, cx + 42, cy + 1), start=270, end=90, fill=cyan_bright, width=3)
    sdraw.arc((cx - 42, cy - 1, cx + 42, cy + 85), start=90, end=270, fill=cyan_bright, width=3)
    # Yin-yang dots
    sdraw.ellipse((cx - 6, cy - 48, cx + 6, cy - 36), fill=cyan_bright)
    sdraw.ellipse((cx - 6, cy + 36, cx + 6, cy + 48), fill=cyan_bright)

    # Glow underlay
    glow_img = apply_radial_glow(img, (cx, cy), 230, (67, 185, 200), 100)
    img = Image.alpha_composite(glow_img, seal_layer)
    img.save(TEXTURES_DIR / "tex_seal_bagua.png", optimize=True)


def generate_bell_ripple():
    """Generates bronze bell acoustic resonance wave ripple with radial flutes (撞钟音波)."""
    size = (512, 512)
    img, draw = create_canvas(size)
    cx, cy = 256, 256

    wave_layer, wdraw = create_canvas(size)
    gold_bright = (255, 230, 140, 230)
    gold_mid = (210, 160, 70, 170)

    # Concentric wave crests
    for r in [60, 115, 170, 220]:
        wdraw.ellipse((cx - r, cy - r, cx + r, cy + r), outline=gold_bright, width=4)
        wdraw.ellipse((cx - r - 4, cy - r - 4, cx + r + 4, cy + r + 4), outline=gold_mid, width=2)

    # 12 directional resonance pulse rays
    for i in range(12):
        a = i * (2 * math.pi / 12)
        x1 = cx + math.cos(a) * 50
        y1 = cy + math.sin(a) * 50
        x2 = cx + math.cos(a) * 235
        y2 = cy + math.sin(a) * 235
        wdraw.line([(x1, y1), (x2, y2)], fill=(255, 215, 100, 110), width=2)

    img = apply_radial_glow(img, (cx, cy), 240, (230, 180, 80), 80)
    img = Image.alpha_composite(img, wave_layer)
    img.save(TEXTURES_DIR / "tex_bell_ripple.png", optimize=True)


def generate_ghost_flame():
    """Generates eerie wispy ghost flame (幽冥鬼火/怨气之焰)."""
    size = (512, 512)
    img, draw = create_canvas(size)
    cx, cy = 256, 300

    flame_layer, fdraw = create_canvas(size)
    
    # Outer cyan flame teardrop
    poly_outer = [
        (cx, 60), (cx + 70, 140), (cx + 120, 240), (cx + 110, 340), 
        (cx + 60, 420), (cx, 440), (cx - 60, 420), (cx - 110, 340), 
        (cx - 120, 240), (cx - 70, 140)
    ]
    fdraw.polygon(poly_outer, fill=(45, 175, 185, 160))

    # Inner bright green/cyan flame
    poly_inner = [
        (cx, 120), (cx + 45, 190), (cx + 70, 270), (cx + 40, 360), 
        (cx, 380), (cx - 40, 360), (cx - 70, 270), (cx - 45, 190)
    ]
    fdraw.polygon(poly_inner, fill=(110, 235, 210, 220))

    # White hot spirit core
    fdraw.ellipse((cx - 28, 250, cx + 28, 360), fill=(240, 255, 250, 255))

    # Wispy tendrils curling at the top
    tendrils, tdraw = create_canvas(size)
    tdraw.line([(cx, 80), (cx + 35, 40), (cx + 15, 15)], fill=(120, 240, 220, 200), width=8)
    tdraw.line([(cx - 20, 110), (cx - 50, 50), (cx - 25, 20)], fill=(70, 200, 190, 180), width=6)

    comp = Image.alpha_composite(flame_layer, tendrils)
    blurred = comp.filter(ImageFilter.GaussianBlur(6))
    
    img = apply_radial_glow(img, (cx, cy), 180, (40, 190, 190), 120)
    img = Image.alpha_composite(img, blurred)
    img = Image.alpha_composite(img, comp)
    img = add_fine_noise(img, 12)
    img.save(TEXTURES_DIR / "tex_ghost_flame.png", optimize=True)


def generate_ember_particle():
    """Generates glowing polygonal ember / spark particle (命火余烬)."""
    size = (256, 256)
    img, draw = create_canvas(size)
    cx, cy = 128, 128

    img = apply_radial_glow(img, (cx, cy), 80, (255, 130, 40), 150)
    
    ember_layer, edraw = create_canvas(size)
    # Diamond ember shape
    edraw.polygon([(cx, 40), (cx + 25, cy), (cx, 216), (cx - 25, cy)], fill=(255, 180, 70, 240))
    edraw.polygon([(cx - 70, cy), (cx, cy - 12), (cx + 70, cy), (cx, cy + 12)], fill=(255, 180, 70, 240))
    edraw.ellipse((cx - 14, cy - 14, cx + 14, cy + 14), fill=(255, 255, 255, 255))

    img = Image.alpha_composite(img, ember_layer)
    img.save(TEXTURES_DIR / "tex_ember_particle.png", optimize=True)


def generate_slash_cross():
    """Generates dual heavy cross slash impact (十字还刃重斩光)."""
    size = (512, 512)
    img, draw = create_canvas(size)
    cx, cy = 256, 256

    img = apply_radial_glow(img, (cx, cy), 190, (255, 90, 60), 120)
    img = apply_radial_glow(img, (cx, cy), 90, (255, 220, 140), 180)

    cross_layer, cdraw = create_canvas(size)
    # Slash 1: Top-Left to Bottom-Right (-35 deg)
    p1 = [(40, 70), (cx, cy - 12), (472, 442), (cx, cy + 12)]
    cdraw.polygon(p1, fill=(255, 245, 210, 240))
    # Slash 2: Top-Right to Bottom-Left (+35 deg)
    p2 = [(472, 70), (cx, cy - 12), (40, 442), (cx, cy + 12)]
    cdraw.polygon(p2, fill=(255, 245, 210, 240))

    # Bright intersection center
    cdraw.ellipse((cx - 32, cy - 32, cx + 32, cy + 32), fill=(255, 255, 255, 255))

    cross_blurred = cross_layer.filter(ImageFilter.GaussianBlur(3.0))
    img = Image.alpha_composite(img, cross_blurred)
    img = Image.alpha_composite(img, cross_layer)
    img.save(TEXTURES_DIR / "tex_slash_cross.png", optimize=True)


def generate_noise_dissolve():
    """Generates seamless cloud noise texture for burn/dissolve shaders."""
    size = (512, 512)
    noise_base = Image.effect_noise(size, 45).convert("L")
    blurred = noise_base.filter(ImageFilter.GaussianBlur(16.0))
    # Enhance contrast
    lut = [int(min(255, max(0, (i - 80) * 1.8))) for i in range(256)]
    contrast_noise = blurred.point(lut)
    
    # Save as RGB/RGBA texture
    rgba_noise = Image.merge("RGBA", (contrast_noise, contrast_noise, contrast_noise, Image.new("L", size, 255)))
    rgba_noise.save(TEXTURES_DIR / "tex_noise_dissolve.png", optimize=True)


def main():
    print("Generating official VFX texture asset library...")
    generate_spark_sharp()
    print(" - Generated tex_spark_sharp.png")
    generate_slash_arc()
    print(" - Generated tex_slash_arc.png")
    generate_talisman_shard()
    print(" - Generated tex_talisman_shard.png")
    generate_ink_splatter()
    print(" - Generated tex_ink_splatter.png")
    generate_shockwave_ring()
    print(" - Generated tex_shockwave_ring.png")
    generate_seal_bagua()
    print(" - Generated tex_seal_bagua.png")
    generate_bell_ripple()
    print(" - Generated tex_bell_ripple.png")
    generate_ghost_flame()
    print(" - Generated tex_ghost_flame.png")
    generate_ember_particle()
    print(" - Generated tex_ember_particle.png")
    generate_slash_cross()
    print(" - Generated tex_slash_cross.png")
    generate_noise_dissolve()
    print(" - Generated tex_noise_dissolve.png")
    print("All VFX texture assets successfully created in:", TEXTURES_DIR)


if __name__ == "__main__":
    main()
