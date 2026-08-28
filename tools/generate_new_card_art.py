#!/usr/bin/env python3
"""为新增 4 张御/佑卡生成主题图标（中式怪谈手绘风格，与既有卡图同规格 320x320）。"""
from __future__ import annotations

import math
import random
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
CARDS_DIR = ROOT / "assets/game/cards"
RNG = random.Random(20260829)


def canvas(size=(320, 320), bg=(14, 17, 22, 255)):
    img = Image.new("RGBA", size, bg)
    return img, ImageDraw.Draw(img)


def glow(img, center, radius, color, alpha=110):
    w, h = img.size
    layer = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    for step in range(6, 0, -1):
        r = radius * step / 6
        a = int(alpha / step)
        d.ellipse([center[0] - r, center[1] - r, center[0] + r, center[1] + r], fill=color + (a,))
    img.alpha_composite(layer.filter(ImageFilter.GaussianBlur(6)))


def paper_grain(img, n=240):
    d = ImageDraw.Draw(img)
    for _ in range(n):
        x, y = RNG.randint(0, 319), RNG.randint(0, 319)
        a = RNG.randint(8, 26)
        d.point((x, y), fill=(214, 198, 164, a))


def vignette(img):
    w, h = img.size
    layer = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(layer)
    d.ellipse([-w // 3, -h // 3, w + w // 3, h + h // 3], fill=255)
    layer = layer.filter(ImageFilter.GaussianBlur(60))
    dark = Image.new("RGBA", (w, h), (0, 0, 0, 130))
    img.alpha_composite(Image.composite(Image.new("RGBA", (w, h), (0, 0, 0, 0)), dark, layer))


def draw_yandeng():
    """延灯：一盏被符纸拉长的灯笼，光焰拖出长长的尾迹。"""
    img, d = canvas()
    glow(img, (160, 150), 90, (138, 192, 184), 90)
    for i in range(7):
        t = i / 6
        r = int(60 - 40 * t)
        a = int(200 - 170 * t)
        cy = int(150 + 110 * t)
        d.ellipse([160 - r, cy - r, 160 + r, cy + r], fill=(120, 200, 190, a))
    d.ellipse([128, 108, 192, 150], outline=(232, 210, 150, 255), width=5)
    d.rectangle([146, 92, 174, 110], fill=(90, 60, 40, 255))
    d.line([160, 92, 160, 60], fill=(150, 130, 100, 255), width=3)
    for x in (140, 180):
        d.line([x, 112, x, 146], fill=(90, 70, 50, 220), width=2)
    paper_grain(img)
    vignette(img)
    return img


def draw_jiezou():
    """劫奏：一段被拦腰斩断的更鼓/音波。"""
    img, d = canvas()
    glow(img, (160, 160), 100, (106, 168, 200), 80)
    cx, cy = 160, 160
    for i in range(4):
        r = 50 + i * 30
        box = [cx - r, cy - r * 0.6, cx + r, cy + r * 0.6]
        if i < 2:
            d.arc(box, start=-60, end=70, fill=(110, 190, 220, 230 - i * 40), width=6)
        else:
            d.arc(box, start=100, end=200, fill=(110, 190, 220, 200 - i * 30), width=5)
    d.line([160, 40, 160, 280], fill=(238, 226, 180, 255), width=7)
    d.line([148, 52, 172, 52], fill=(238, 226, 180, 255), width=5)
    d.line([148, 268, 172, 268], fill=(238, 226, 180, 255), width=5)
    paper_grain(img)
    vignette(img)
    return img


def draw_huangdeng():
    """晃灯：来回摇摆的灯，光晕两侧荡开，窗口放宽的意象。"""
    img, d = canvas()
    glow(img, (120, 150), 80, (200, 192, 138), 90)
    glow(img, (200, 150), 80, (200, 192, 138), 70)
    d.line([160, 40, 128, 130], fill=(160, 140, 105, 255), width=4)
    d.line([160, 40, 192, 130], fill=(160, 140, 105, 255), width=4)
    for ox in (-36, 36):
        cx, cy = 160 + ox, 160
        d.ellipse([cx - 34, cy - 46, cx + 34, cy + 46], outline=(235, 215, 155, 240), width=5)
        d.rectangle([cx - 12, cy - 62, cx + 12, cy - 46], fill=(90, 60, 40, 255))
        d.line([cx - 20, cy - 38, cx - 20, cy + 38], fill=(120, 95, 65, 200), width=2)
        d.line([cx + 20, cy - 38, cx + 20, cy + 38], fill=(120, 95, 65, 200), width=2)
        d.ellipse([cx - 12, cy - 14, cx + 12, cy + 14], fill=(255, 226, 140, 235))
    paper_grain(img)
    vignette(img)
    return img


def draw_chageng():
    """查更：一只手执更梆，探照的灯焰照亮前路。"""
    img, d = canvas()
    glow(img, (170, 150), 110, (158, 192, 168), 80)
    d.line([70, 250, 130, 190], fill=(190, 170, 140, 255), width=10)
    d.line([130, 190, 150, 170], fill=(190, 170, 140, 255), width=10)
    d.ellipse([140, 120, 200, 200], outline=(232, 210, 150, 255), width=6)
    d.ellipse([152, 138, 188, 182], fill=(255, 232, 150, 220))
    for i in range(3):
        r = 70 + i * 34
        d.arc([170 - r, 160 - r, 170 + r, 160 + r], start=-45, end=45,
              fill=(160, 210, 180, 220 - i * 55), width=5)
    d.rectangle([120, 226, 210, 252], outline=(140, 110, 80, 255), width=5)
    d.line([138, 226, 138, 252], fill=(140, 110, 80, 255), width=4)
    paper_grain(img)
    vignette(img)
    return img


def main():
    jobs = {
        "card_yandeng.png": draw_yandeng,
        "card_jiezou.png": draw_jiezou,
        "card_huangdeng.png": draw_huangdeng,
        "card_chageng.png": draw_chageng,
    }
    for name, fn in jobs.items():
        img = fn()
        img.save(CARDS_DIR / name)
        print("generated", name)


if __name__ == "__main__":
    main()
