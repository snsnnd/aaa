#!/usr/bin/env python3
"""Generate the minimal painterly asset pack used by the combat demo."""

from __future__ import annotations

import math
import random
import struct
import wave
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter


ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets/demo"
AUDIO = OUT / "audio"
RNG = random.Random(20260827)


def rgba(size: tuple[int, int], color=(0, 0, 0, 0)) -> tuple[Image.Image, ImageDraw.ImageDraw]:
    image = Image.new("RGBA", size, color)
    return image, ImageDraw.Draw(image)


def add_noise(image: Image.Image, amount: int = 18, alpha: int = 18) -> Image.Image:
    original_alpha = image.getchannel("A")
    noise = Image.effect_noise(image.size, amount).convert("L")
    texture = Image.merge("RGBA", (noise, noise, noise, Image.new("L", image.size, alpha)))
    result = Image.alpha_composite(image.convert("RGBA"), texture)
    result.putalpha(original_alpha)
    return result


def glow(size: tuple[int, int], center: tuple[int, int], radius: int, color: tuple[int, int, int], alpha: int) -> Image.Image:
    layer, draw = rgba(size)
    x, y = center
    for scale, opacity in [(1.0, alpha // 5), (0.68, alpha // 3), (0.36, alpha)]:
        r = int(radius * scale)
        draw.ellipse((x - r, y - r, x + r, y + r), fill=(*color, opacity))
    return layer.filter(ImageFilter.GaussianBlur(max(8, radius // 5)))


def make_background() -> None:
    size = (1920, 1080)
    image, draw = rgba(size, "#0a0d12")
    # Cold night fields.
    image = Image.alpha_composite(image, glow(size, (1450, 210), 570, (38, 93, 104), 52))
    image = Image.alpha_composite(image, glow(size, (365, 690), 420, (202, 105, 40), 44))
    draw = ImageDraw.Draw(image)
    # Distant moon behind rain cloud.
    draw.ellipse((1285, 58, 1655, 428), fill=(187, 195, 176, 45))
    # Old street silhouettes.
    buildings = [
        (-80, 292, 440, 790, "#111319"),
        (335, 365, 835, 803, "#15171c"),
        (760, 250, 1260, 798, "#101419"),
        (1190, 340, 1760, 804, "#14161a"),
        (1680, 220, 2020, 805, "#0d1116"),
    ]
    for x0, y0, x1, y1, color in buildings:
        draw.rectangle((x0, y0, x1, y1), fill=color)
        draw.polygon([(x0 - 65, y0 + 18), ((x0 + x1) // 2, y0 - 76), (x1 + 68, y0 + 20)], fill="#090b0f")
        draw.line((x0 - 70, y0 + 23, x1 + 73, y0 + 23), fill="#252329", width=10)
        for wx in range(x0 + 72, x1 - 40, 145):
            draw.rectangle((wx, y0 + 96, wx + 52, y0 + 154), fill=(100, 70, 39, 80), outline="#272127", width=4)
    # Signboards and hanging cloth on the far left only
    draw.rectangle((222, 350, 299, 559), fill="#21161a", outline="#6f3a2c", width=6)
    draw.line((260, 322, 260, 350), fill="#685039", width=8)
    # Wet road.
    draw.polygon([(0, 728), (1920, 728), (1920, 1080), (0, 1080)], fill="#101318")
    for _ in range(95):
        y = RNG.randint(755, 1060)
        x = RNG.randint(-70, 1900)
        length = RNG.randint(30, 210)
        color = RNG.choice([(210, 133, 60, 22), (63, 125, 134, 20), (190, 193, 180, 15)])
        draw.line((x, y, x + length, y + RNG.randint(-3, 3)), fill=color, width=RNG.randint(2, 7))
    # Painterly fog bands.
    fog, fd = rgba(size)
    for _ in range(26):
        y = RNG.randint(260, 860)
        fd.line((RNG.randint(-300, 100), y, RNG.randint(1200, 2200), y + RNG.randint(-70, 70)), fill=(101, 128, 128, RNG.randint(8, 24)), width=RNG.randint(14, 46))
    image = Image.alpha_composite(image, fog.filter(ImageFilter.GaussianBlur(15)))
    # Rain with perspective and a few roof drips.
    rain, rd = rgba(size)
    for _ in range(410):
        x = RNG.randint(-80, 1960)
        y = RNG.randint(-80, 1080)
        length = RNG.randint(12, 58)
        rd.line((x, y, x - 8, y + length), fill=(157, 190, 195, RNG.randint(15, 62)), width=RNG.choice([1, 1, 2]))
    image = Image.alpha_composite(image, rain.filter(ImageFilter.GaussianBlur(0.5)))
    image = add_noise(image, 20, 20)
    image.convert("RGB").save(OUT / "background_old_street.png", optimize=True)


def make_keeper() -> None:
    size = (640, 800)
    image, draw = rgba(size)
    image = Image.alpha_composite(image, glow(size, (454, 605), 160, (242, 139, 42), 120))
    draw = ImageDraw.Draw(image)
    ink = "#090b0d"
    # Cloak and readable red lining.
    draw.polygon([(245, 260), (105, 744), (503, 744), (391, 273)], fill=ink)
    draw.polygon([(218, 347), (133, 708), (207, 653), (271, 365)], fill="#6e2225")
    draw.line((389, 294, 494, 731), fill=(189, 124, 61, 140), width=12)
    for x in [260, 295, 332, 370]:
        draw.line((x, 390, x - 35, 696), fill=(81, 54, 47, 170), width=7)
    # Head and broad hat.
    draw.ellipse((222, 155, 374, 302), fill=ink)
    draw.polygon([(137, 221), (450, 221), (385, 145), (231, 132)], fill=ink)
    draw.line((145, 222, 446, 222), fill="#8f6737", width=7)
    draw.ellipse((282, 209, 306, 233), fill="#e5b952")
    # Lantern arm.
    draw.line((378, 330, 505, 499), fill=ink, width=34)
    draw.line((492, 479, 532, 529), fill="#c58c3f", width=9)
    draw.rounded_rectangle((481, 522, 591, 674), radius=16, fill="#d98729", outline="#120d0b", width=10)
    draw.line((536, 524, 536, 674), fill="#3a2119", width=6)
    draw.line((483, 596, 589, 596), fill="#3a2119", width=6)
    draw.arc((500, 488, 571, 546), 180, 360, fill="#241813", width=9)
    # Warm hard rim on the silhouette.
    draw.line((391, 281, 456, 509), fill=(235, 161, 74, 190), width=6)
    image = add_noise(image, 13, 14)
    image.save(OUT / "player_keeper.png", optimize=True)


def make_watchman() -> None:
    size = (640, 800)
    image, draw = rgba(size)
    image = Image.alpha_composite(image, glow(size, (310, 335), 240, (53, 136, 139), 92))
    draw = ImageDraw.Draw(image)
    ink = "#0b0d10"
    # Trailing ghost body and broken stance.
    draw.polygon([(249, 248), (127, 724), (473, 724), (405, 268)], fill=ink)
    draw.polygon([(168, 390), (114, 679), (197, 615), (258, 358)], fill="#24252a")
    draw.line((239, 342, 198, 665), fill=(51, 116, 118, 145), width=9)
    draw.line((282, 349, 269, 678), fill=(57, 125, 125, 110), width=6)
    # Bent head, straw hat, face mask.
    draw.ellipse((226, 134, 384, 289), fill="#101317")
    draw.polygon([(143, 202), (457, 202), (390, 127), (238, 117)], fill="#0a0d10")
    draw.line((154, 203, 449, 203), fill="#486b68", width=7)
    draw.ellipse((278, 189, 301, 216), fill="#b03a35")
    draw.ellipse((333, 187, 355, 214), fill="#b03a35")
    # Red resentment gathers at the shoulder. The weapon is a separate animated asset.
    resentment, rd = rgba(size)
    rd.ellipse((314, 245, 455, 383), fill=(158, 36, 42, 70))
    image = Image.alpha_composite(image, resentment.filter(ImageFilter.GaussianBlur(28)))
    image = add_noise(image, 14, 16)
    image.save(OUT / "enemy_watchman.png", optimize=True)


def make_enemy_blade() -> None:
    size = (180, 460)
    image, draw = rgba(size)
    # Long dark shaft with a narrow warm rim and a heavy funeral cleaver.
    draw.line((88, 20, 91, 312), fill="#111216", width=22)
    draw.line((82, 20, 84, 306), fill="#5c4c39", width=4)
    draw.line((54, 296, 126, 296), fill="#17171a", width=18)
    draw.polygon([(74, 310), (126, 278), (165, 333), (109, 443), (58, 415)], fill="#aaa48f", outline="#121418")
    draw.line((82, 318, 126, 292), fill="#eee1af", width=5)
    draw.line((126, 292, 154, 334), fill="#d7c786", width=4)
    draw.line((65, 408, 108, 432), fill="#6a6360", width=5)
    image = Image.alpha_composite(image, glow(size, (112, 345), 110, (174, 42, 47), 58))
    image = add_noise(image, 12, 12)
    image.save(OUT / "enemy_blade.png", optimize=True)


def make_card_icon(name: str, color: str, kind: str) -> None:
    size = (320, 320)
    image, draw = rgba(size, "#11141b")
    image = Image.alpha_composite(image, glow(size, (160, 146), 135, tuple(int(color[i:i + 2], 16) for i in (1, 3, 5)), 65))
    draw = ImageDraw.Draw(image)
    draw.rounded_rectangle((10, 10, 310, 310), radius=30, outline=color, width=8)
    if kind == "attack":
        draw.polygon([(88, 239), (126, 202), (207, 79), (233, 65), (222, 102), (143, 222)], fill="#ddd1a4")
        draw.line((79, 250, 241, 88), fill=color, width=18)
        draw.line((86, 227, 126, 269), fill="#b88b45", width=20)
    elif kind == "shatter":
        draw.polygon([(135, 255), (152, 173), (128, 151), (176, 62), (205, 47), (180, 142), (208, 164), (171, 183), (190, 256)], fill="#ddd1a4")
        for angle in [-55, -20, 15, 48]:
            x = 165 + int(math.cos(math.radians(angle)) * 112)
            y = 161 + int(math.sin(math.radians(angle)) * 112)
            draw.line((165, 161, x, y), fill=color, width=8)
    elif kind == "guard":
        for offset in [0, 24, 48]:
            draw.arc((78 + offset, 82, 201 + offset, 253), 248, 108, fill=color, width=17)
        draw.ellipse((139, 134, 185, 181), outline="#e2d7b4", width=8)
    else:
        draw.polygon([(110, 73), (195, 73), (229, 145), (198, 247), (149, 280), (94, 240), (71, 155)], fill=(91, 136, 91, 95), outline=color)
        draw.line((118, 228, 207, 103), fill="#ddd1a4", width=18)
        draw.line((117, 105, 217, 229), fill="#ddd1a4", width=18)
    image = add_noise(image, 10, 10)
    image.save(OUT / name, optimize=True)


def write_wav(name: str, duration: float, sample_fn, volume: float = 0.55) -> None:
    rate = 44100
    count = int(rate * duration)
    samples = []
    for i in range(count):
        t = i / rate
        value = max(-1.0, min(1.0, sample_fn(t, duration))) * volume
        samples.append(struct.pack("<h", int(value * 32767)))
    with wave.open(str(AUDIO / name), "wb") as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(rate)
        wav.writeframes(b"".join(samples))


def make_audio() -> None:
    write_wav(
        "parry.wav",
        0.34,
        lambda t, d: (math.sin(2 * math.pi * (2100 - 1200 * t / d) * t) * math.exp(-13 * t)
                      + 0.5 * math.sin(2 * math.pi * 116 * t) * math.exp(-8 * t)
                      + RNG.uniform(-0.16, 0.16) * math.exp(-18 * t)),
        0.72,
    )
    write_wav(
        "hurt.wav",
        0.42,
        lambda t, d: (math.sin(2 * math.pi * (92 - 35 * t / d) * t) * math.exp(-7 * t)
                      + RNG.uniform(-0.28, 0.28) * math.exp(-12 * t)),
        0.58,
    )
    write_wav(
        "card.wav",
        0.18,
        lambda t, d: math.sin(2 * math.pi * (520 + 960 * t / d) * t) * math.exp(-15 * t),
        0.42,
    )
    write_wav(
        "warning.wav",
        0.28,
        lambda t, d: math.sin(2 * math.pi * (150 + 210 * t / d) * t) * (0.35 + 0.65 * t / d),
        0.34,
    )


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    AUDIO.mkdir(parents=True, exist_ok=True)
    make_background()
    make_keeper()
    make_watchman()
    make_enemy_blade()
    make_card_icon("card_attack.png", "#c9a151", "attack")
    make_card_icon("card_shatter.png", "#b93b40", "shatter")
    make_card_icon("card_guard.png", "#3f9fa7", "guard")
    make_card_icon("card_shift.png", "#668e5c", "shift")
    make_audio()
    print(f"Generated demo assets in {OUT}")


if __name__ == "__main__":
    main()
