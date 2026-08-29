#!/usr/bin/env python3
"""
generate_refined_keeper_assets.py
---------------------------------
重构中式怪谈卡牌肉鸽《执灯人》主角资产：
基于正视图概念图，重构为高精度侧身迎敌（侧视朝右）厚涂美术资产。
生成文件：
  1. assets/demo/player_keeper.png (完整侧视战斗立绘)
  2. assets/game/characters_sliced/keeper_body_clean.png (解耦纯净身体部件，带刀与红绳腰封，对齐物理锚点)
  3. assets/game/characters_sliced/keeper_lantern_prop.png (解耦高精八角古木长明灯，带顶环挂链、琥珀透光芯与朱红流苏)
"""

import math
import random
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path("/mnt/d/Godot/aaa")
DEMO_DIR = ROOT / "assets" / "demo"
CHAR_DIR = ROOT / "assets" / "game" / "characters_sliced"

DEMO_DIR.mkdir(parents=True, exist_ok=True)
CHAR_DIR.mkdir(parents=True, exist_ok=True)


def create_canvas(size: tuple[int, int]) -> tuple[Image.Image, ImageDraw.ImageDraw]:
    img = Image.new("RGBA", size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    return img, draw


def add_subtle_grain(img: Image.Image, intensity: int = 8) -> Image.Image:
    """添加中式国风手绘纸张与厚涂颗粒微纹理"""
    arr = np.array(img, dtype=np.int16)
    alpha = arr[:, :, 3]
    mask = alpha > 10
    noise = np.random.normal(0, intensity, (arr.shape[0], arr.shape[1]))
    for c in range(3):
        arr[:, :, c] = np.clip(arr[:, :, c] + noise * (mask.astype(float)), 0, 255)
    return Image.fromarray(arr.astype(np.uint8), "RGBA")


def draw_ragged_strip(draw: ImageDraw.ImageDraw, p_top1, p_top2, p_bot, color):
    """绘制破损衣袍的不规则条状撕裂片"""
    draw.polygon([p_top1, p_top2, p_bot], fill=color)


def draw_woven_hat(img: Image.Image, center_x: int, center_y: int, width: int, height: int, is_side_view: bool = True):
    """绘制高精度编织竹纹斗笠，带破损边缘毛刺与深邃阴影"""
    hat_layer, d = create_canvas(img.size)
    
    # 斗笠轮廓顶点 (侧视轻微向右倾斜)
    if is_side_view:
        apex = (center_x - 15, center_y - height // 2)
        left_rim = (center_x - width // 2 + 10, center_y + height // 2 - 10)
        right_rim = (center_x + width // 2 + 25, center_y + height // 2 + 5)
        rim_curve_mid = (center_x + 5, center_y + height // 2 + 15)
    else:
        apex = (center_x, center_y - height // 2)
        left_rim = (center_x - width // 2, center_y + height // 2)
        right_rim = (center_x + width // 2, center_y + height // 2)
        rim_curve_mid = (center_x, center_y + height // 2 + 8)

    # 1. 基础竹笠实体底色 (风化深竹棕色)
    poly = [apex, right_rim, rim_curve_mid, left_rim]
    d.polygon(poly, fill=(52, 40, 28, 255))

    # 2. 编织竹条纹理（密集的同心弧线与经纬放射线）
    # 放射竹骨
    for i in range(26):
        t = i / 25.0
        # 沿帽檐插值
        if t < 0.5:
            u = t * 2.0
            rx = left_rim[0] + (rim_curve_mid[0] - left_rim[0]) * u
            ry = left_rim[1] + (rim_curve_mid[1] - left_rim[1]) * u
        else:
            u = (t - 0.5) * 2.0
            rx = rim_curve_mid[0] + (right_rim[0] - rim_curve_mid[0]) * u
            ry = rim_curve_mid[1] + (right_rim[1] - rim_curve_mid[1]) * u
        
        # 经线深浅交替
        bone_col = (78, 60, 42, 220) if i % 2 == 0 else (36, 26, 18, 200)
        d.line([apex, (int(rx), int(ry))], fill=bone_col, width=2)

    # 纬向环线
    for ring in range(1, 9):
        factor = ring / 9.0
        r_apex_l = (apex[0] + (left_rim[0] - apex[0]) * factor, apex[1] + (left_rim[1] - apex[1]) * factor)
        r_apex_m = (apex[0] + (rim_curve_mid[0] - apex[0]) * factor, apex[1] + (rim_curve_mid[1] - apex[1]) * factor)
        r_apex_r = (apex[0] + (right_rim[0] - apex[0]) * factor, apex[1] + (right_rim[1] - apex[1]) * factor)
        
        arc_points = []
        for step in range(21):
            st = step / 20.0
            if st < 0.5:
                su = st * 2.0
                px = r_apex_l[0] + (r_apex_m[0] - r_apex_l[0]) * su
                py = r_apex_l[1] + (r_apex_m[1] - r_apex_l[1]) * su
            else:
                su = (st - 0.5) * 2.0
                px = r_apex_m[0] + (r_apex_r[0] - r_apex_m[0]) * su
                py = r_apex_m[1] + (r_apex_r[1] - r_apex_m[1]) * su
            arc_points.append((int(px), int(py)))
            
        d.line(arc_points, fill=(90, 72, 50, 180) if ring % 2 == 0 else (40, 30, 20, 210), width=2)

    # 3. 笠顶竹节压顶与破损毛边
    d.polygon([(apex[0]-8, apex[1]+4), (apex[0], apex[1]-6), (apex[0]+8, apex[1]+4), (apex[0], apex[1]+10)], fill=(32, 24, 16, 255))
    
    # 边缘破损毛竹刺
    random.seed(42)
    for step in range(40):
        st = step / 39.0
        if st < 0.5:
            su = st * 2.0
            bx = left_rim[0] + (rim_curve_mid[0] - left_rim[0]) * su
            by = left_rim[1] + (rim_curve_mid[1] - left_rim[1]) * su
        else:
            su = (st - 0.5) * 2.0
            bx = rim_curve_mid[0] + (right_rim[0] - rim_curve_mid[0]) * su
            by = rim_curve_mid[1] + (right_rim[1] - rim_curve_mid[1]) * su
        
        length = random.randint(4, 16)
        angle = random.uniform(0.3, 1.2)
        ex = bx + math.cos(angle) * (1 if st > 0.4 else -0.5) * length
        ey = by + math.sin(angle) * length
        straw_color = (random.randint(90, 140), random.randint(70, 110), random.randint(45, 75), 240)
        d.line([(bx, by), (ex, ey)], fill=straw_color, width=random.randint(1, 3))

    # 4. 帽檐暖光高光（迎向灯笼侧）
    if is_side_view:
        d.line([rim_curve_mid, right_rim], fill=(185, 135, 70, 220), width=3)
        d.line([(rim_curve_mid[0], rim_curve_mid[1]-2), (right_rim[0]-4, right_rim[1]-2)], fill=(235, 175, 90, 160), width=2)
    
    img.alpha_composite(hat_layer)


def draw_glowing_eyes(img: Image.Image, eye_left: tuple[int, int], eye_right: tuple[int, int]):
    """绘制斗笠阴影下散发炽热橙金光芒的锐利双眸"""
    eye_layer, d = create_canvas(img.size)
    glow_layer, gd = create_canvas(img.size)

    # 眼睛基础光芒外晕
    for (ex, ey) in [eye_left, eye_right]:
        for r, a in [(16, 25), (10, 60), (6, 120), (3, 220)]:
            gd.ellipse((ex - r, ey - r // 2, ex + r, ey + r // 2), fill=(255, 140, 25, a))
        # 极亮白色金芯
        gd.ellipse((ex - 2, ey - 1, ex + 2, ey + 1), fill=(255, 245, 200, 255))

    glow_blur = glow_layer.filter(ImageFilter.GaussianBlur(3))
    img.alpha_composite(glow_blur)
    img.alpha_composite(eye_layer)


def draw_lantern_prop_image() -> Image.Image:
    """生成解耦的八角古木长明灯 (256x384)，锚点在 (128, 20)"""
    size = (256, 384)
    img, draw = create_canvas(size)
    cx, cy = 128, 195

    # 1. 顶部铁环与挂链 (锚点 (128, 20))
    # 顶部挂环
    draw.ellipse((cx - 14, 10, cx + 14, 38), outline=(95, 80, 65, 255), width=4)
    draw.ellipse((cx - 10, 14, cx + 10, 34), outline=(145, 125, 100, 200), width=2)
    # 铁链环节
    for y_link in range(36, 100, 14):
        draw.rounded_rectangle((cx - 5, y_link, cx + 5, y_link + 16), radius=3, outline=(80, 68, 55, 255), width=3)
        draw.line([(cx, y_link + 2), (cx, y_link + 14)], fill=(130, 110, 90, 220), width=1)

    # 2. 八角仿古木质顶盖 (Roof)
    roof_top = 100
    roof_bot = 138
    # 飞檐上翘
    roof_poly = [
        (cx - 18, roof_top - 4), (cx + 18, roof_top - 4),
        (cx + 64, roof_bot - 10), (cx + 78, roof_bot - 2), (cx + 66, roof_bot + 4),
        (cx - 66, roof_bot + 4), (cx - 78, roof_bot - 2), (cx - 64, roof_bot - 10)
    ]
    draw.polygon(roof_poly, fill=(42, 28, 18, 255))
    # 瓦当与木纹细节
    draw.line([(cx - 60, roof_bot), (cx + 60, roof_bot)], fill=(65, 45, 30, 255), width=4)
    draw.polygon([(cx - 24, roof_top), (cx + 24, roof_top), (cx + 18, roof_bot - 8), (cx - 18, roof_bot - 8)], fill=(58, 40, 26, 255))
    draw.line([(cx - 78, roof_bot - 2), (cx - 18, roof_top - 4)], fill=(95, 70, 48, 220), width=2)
    draw.line([(cx + 78, roof_bot - 2), (cx + 18, roof_top - 4)], fill=(125, 95, 65, 240), width=2)

    # 3. 内部发光纸芯 (Luminous Rice Paper Core)
    paper_top = roof_bot + 2
    paper_bot = 258
    core_w = 48
    
    # 渐变发光纸芯层
    core_layer, cd = create_canvas(size)
    for rx in range(core_w, 0, -2):
        factor = rx / float(core_w)
        # 从内白金到外琥珀红橙渐变
        r = int(255)
        g = int(140 + 105 * (1.0 - factor))
        b = int(20 + 190 * (1.0 - factor)**2)
        alpha = int(240 - 40 * factor)
        cd.rounded_rectangle((cx - rx, paper_top, cx + rx, paper_bot), radius=8, fill=(r, g, b, alpha))

    # 纸芯中央道符隐纹 (符文暗影)
    cd.line([(cx, paper_top + 18), (cx, paper_bot - 18)], fill=(160, 60, 20, 160), width=3)
    cd.line([(cx - 16, paper_top + 40), (cx + 16, paper_top + 40)], fill=(160, 60, 20, 140), width=2)
    cd.line([(cx - 12, paper_top + 75), (cx + 12, paper_top + 75)], fill=(160, 60, 20, 140), width=2)
    cd.ellipse((cx - 8, paper_top + 50, cx + 8, paper_top + 66), outline=(170, 70, 25, 150), width=2)

    img.alpha_composite(core_layer)

    # 4. 八角木质立柱与窗棂框架 (Struts & Lattice)
    # 外框立柱
    draw.rounded_rectangle((cx - 52, paper_top, cx - 44, paper_bot), radius=2, fill=(35, 22, 14, 255))
    draw.rounded_rectangle((cx + 44, paper_top, cx + 52, paper_bot), radius=2, fill=(45, 30, 20, 255))
    # 中间立柱 (带受光侧高光)
    draw.rounded_rectangle((cx - 20, paper_top, cx - 14, paper_bot), radius=2, fill=(38, 25, 16, 255))
    draw.rounded_rectangle((cx + 14, paper_top, cx + 20, paper_bot), radius=2, fill=(55, 38, 25, 255))
    draw.line([(cx + 16, paper_top), (cx + 16, paper_bot)], fill=(110, 80, 50, 200), width=1)
    # 横向木棂
    for y_strut in [paper_top + 32, (paper_top + paper_bot) // 2, paper_bot - 32]:
        draw.line([(cx - 48, y_strut), (cx + 48, y_strut)], fill=(40, 26, 16, 230), width=3)

    # 5. 灯底木座与底托 (Base)
    base_poly = [
        (cx - 58, paper_bot - 2), (cx + 58, paper_bot - 2),
        (cx + 48, paper_bot + 18), (cx + 18, paper_bot + 24),
        (cx - 18, paper_bot + 24), (cx - 48, paper_bot + 18)
    ]
    draw.polygon(base_poly, fill=(36, 24, 15, 255))
    draw.line([(cx - 54, paper_bot), (cx + 54, paper_bot)], fill=(60, 42, 28, 255), width=3)
    draw.line([(cx - 44, paper_bot + 16), (cx + 44, paper_bot + 16)], fill=(75, 52, 35, 255), width=2)
    # 底座金环
    draw.ellipse((cx - 8, paper_bot + 20, cx + 8, paper_bot + 36), outline=(160, 120, 60, 255), width=3)

    # 6. 下垂朱红真丝流苏 (Crimson Silk Tassel)
    tassel_top = paper_bot + 32
    tassel_bot = tassel_top + 80
    
    # 流苏扎头 (金色丝线束)
    draw.ellipse((cx - 6, tassel_top - 2, cx + 6, tassel_top + 10), fill=(180, 130, 45, 255))
    draw.rectangle((cx - 5, tassel_top + 4, cx + 5, tassel_top + 14), fill=(195, 145, 50, 255))
    
    # 丝绦流苏条 (朱砂红与暗红交织)
    random.seed(99)
    for i in range(28):
        offset = (i - 14) * 0.75
        length = random.randint(65, 80)
        col_r = random.randint(170, 220)
        col_g = random.randint(25, 55)
        col_b = random.randint(25, 50)
        draw.line([(cx + offset * 0.4, tassel_top + 12), (cx + offset * 1.3, tassel_top + length)], fill=(col_r, col_g, col_b, 240), width=2)

    # 7. 全局柔和厚涂颗粒
    img = add_subtle_grain(img, 10)
    return img


def draw_keeper_body_side(include_lantern: bool = False) -> Image.Image:
    """
    绘制侧身迎敌（侧视朝右）的高精手绘厚涂执灯人立绘。
    尺寸：640 x 800
    对齐游戏骨骼系统：
      - 角色中心 pivot 位于 (320, 400)
      - 左手提灯挂点 anchor 位于 (384, 440) (即 pivot + (64, 40))
      - 右手执刀向前延伸至 (560, 520)
    """
    size = (640, 800)
    base_img, draw = create_canvas(size)

    cx, cy = 320, 400

    # =========================================================================
    # 图层 1: 背面残破衣袍与背风飞扬的披风下摆 (Dark Charcoal Robe Back Layers)
    # =========================================================================
    back_layer, bd = create_canvas(size)
    
    # 飘向左后方的深黑破袍轮廓
    back_robe_poly = [
        (cx - 30, cy - 80),   # 颈后
        (cx - 85, cy - 30),   # 左肩后背
        (cx - 150, cy + 120), # 后扬宽袖
        (cx - 180, cy + 240), # 飞扬衣角
        (cx - 195, cy + 330), # 极左撕裂下摆
        (cx - 90, cy + 345),  # 下摆中间
        (cx + 40, cy + 345),  # 袍底前沿
        (cx + 10, cy + 80),   # 腰腹后
        (cx - 10, cy - 60)
    ]
    bd.polygon(back_robe_poly, fill=(16, 18, 24, 255))
    
    # 破损边缘条状撕裂片 (Ragged edges)
    ragged_spikes = [
        ((cx - 195, cy + 330), (cx - 170, cy + 280), (cx - 210, cy + 355)),
        ((cx - 165, cy + 335), (cx - 140, cy + 300), (cx - 175, cy + 360)),
        ((cx - 135, cy + 340), (cx - 110, cy + 310), (cx - 145, cy + 365)),
        ((cx - 105, cy + 342), (cx - 80, cy + 315), (cx - 110, cy + 368)),
        ((cx - 75, cy + 345), (cx - 50, cy + 320), (cx - 80, cy + 365)),
        ((cx - 40, cy + 345), (cx - 20, cy + 325), (cx - 45, cy + 360)),
    ]
    for p1, p2, p3 in ragged_spikes:
        bd.polygon([p1, p2, p3], fill=(12, 14, 18, 255))

    # 冷青色微弱背光环境光 (Moonlight rim on back)
    for offset in range(3):
        bd.line([(cx - 85 - offset, cy - 30), (cx - 180 - offset, cy + 240), (cx - 195 - offset, cy + 330)], fill=(45, 75, 85, 140 - offset * 40), width=2)

    base_img.alpha_composite(back_layer)

    # =========================================================================
    # 图层 2: 下身双腿、草鞋与绑腿 (Legs, Shin Wraps & Straw Boots)
    # =========================================================================
    leg_layer, ld = create_canvas(size)
    
    # 侧身弓箭战步：左腿偏后稳立，右腿微屈在前
    # 1. 后腿（左腿）
    ld.polygon([(cx - 70, cy + 180), (cx - 35, cy + 180), (cx - 45, cy + 340), (cx - 85, cy + 340)], fill=(20, 22, 28, 255))
    # 后脚草鞋
    ld.polygon([(cx - 95, cy + 340), (cx - 40, cy + 340), (cx - 35, cy + 358), (cx - 105, cy + 358)], fill=(32, 26, 20, 255))
    # 绑腿绳索
    for y_wrap in range(cy + 240, cy + 335, 16):
        ld.line([(cx - 75, y_wrap), (cx - 45, y_wrap + 8)], fill=(65, 52, 38, 220), width=3)
        ld.line([(cx - 45, y_wrap), (cx - 75, y_wrap + 8)], fill=(45, 36, 26, 200), width=2)

    # 2. 前腿（右腿）- 迎向前方
    ld.polygon([(cx - 20, cy + 170), (cx + 35, cy + 170), (cx + 25, cy + 342), (cx - 25, cy + 342)], fill=(24, 28, 36, 255))
    # 前脚草鞋 (分趾扎实踩地)
    ld.polygon([(cx - 35, cy + 342), (cx + 48, cy + 342), (cx + 56, cy + 358), (cx - 42, cy + 358)], fill=(42, 34, 24, 255))
    ld.line([(cx - 40, cy + 356), (cx + 54, cy + 356)], fill=(75, 58, 40, 255), width=3) # 草编鞋底
    # 前腿绑腿与受光高光
    for y_wrap in range(cy + 220, cy + 335, 15):
        ld.line([(cx - 22, y_wrap), (cx + 28, y_wrap + 7)], fill=(85, 68, 48, 230), width=3)
        ld.line([(cx + 28, y_wrap), (cx - 22, y_wrap + 7)], fill=(55, 42, 30, 210), width=2)

    base_img.alpha_composite(leg_layer)

    # =========================================================================
    # 图层 3: 主干道袍与交领长衫 (Main Robe Body & Folds)
    # =========================================================================
    body_layer, bd2 = create_canvas(size)
    
    # 躯干主干多边形 (侧身挺拔且沉稳)
    torso_poly = [
        (cx - 50, cy - 90),  # 后颈
        (cx + 25, cy - 80),  # 前锁骨
        (cx + 65, cy - 10),  # 右胸/右肩前
        (cx + 75, cy + 60),  # 前腰
        (cx + 85, cy + 200), # 前袍下垂
        (cx + 95, cy + 335), # 前袍底角
        (cx - 30, cy + 348), # 袍底后沿
        (cx - 75, cy + 220), # 后臀
        (cx - 65, cy + 50),  # 后腰
        (cx - 70, cy - 40)   # 后背
    ]
    bd2.polygon(torso_poly, fill=(28, 32, 42, 255))
    
    # 道袍交领深色折叠结构
    bd2.polygon([(cx - 35, cy - 85), (cx + 20, cy - 75), (cx + 35, cy - 20), (cx - 20, cy - 15)], fill=(20, 24, 32, 255))
    # 领口受光侧包边
    bd2.line([(cx + 20, cy - 75), (cx + 38, cy - 15)], fill=(55, 64, 82, 230), width=4)
    bd2.line([(cx - 25, cy - 85), (cx + 10, cy - 10)], fill=(40, 48, 62, 220), width=3)

    # 衣袍厚涂布料褶皱 (Brushstroke folds)
    fold_lines = [
        ([(cx + 60, cy + 50), (cx + 40, cy + 180), (cx + 55, cy + 330)], (42, 48, 64, 220), 6),
        ([(cx + 30, cy + 60), (cx + 10, cy + 200), (cx + 15, cy + 335)], (38, 44, 58, 200), 5),
        ([(cx - 10, cy + 65), (cx - 25, cy + 210), (cx - 10, cy + 340)], (22, 26, 35, 230), 6),
        ([(cx - 45, cy + 70), (cx - 55, cy + 220), (cx - 50, cy + 335)], (18, 20, 28, 240), 7),
    ]
    for pts, col, w in fold_lines:
        bd2.line(pts, fill=col, width=w)

    # 前摆撕裂尖齿
    front_ragged = [
        ((cx + 95, cy + 335), (cx + 80, cy + 290), (cx + 105, cy + 358)),
        ((cx + 75, cy + 340), (cx + 60, cy + 295), (cx + 85, cy + 362)),
        ((cx + 50, cy + 344), (cx + 35, cy + 300), (cx + 60, cy + 365)),
        ((cx + 25, cy + 346), (cx + 10, cy + 305), (cx + 30, cy + 366)),
        ((cx - 5, cy + 348), (cx - 20, cy + 310), (cx - 2, cy + 365)),
    ]
    for p1, p2, p3 in front_ragged:
        bd2.polygon([p1, p2, p3], fill=(22, 25, 33, 255))

    base_img.alpha_composite(body_layer)

    # =========================================================================
    # 图层 4: 朱砂赤红粗绳腰封、结饰与悬垂木牌 (Crimson Rope Sash & Talisman Tag)
    # =========================================================================
    sash_layer, sd = create_canvas(size)
    
    sash_y = cy + 25
    # 宽腰封底布 (暗赤红)
    sd.polygon([(cx - 68, sash_y - 12), (cx + 72, sash_y - 8), (cx + 75, sash_y + 36), (cx - 66, sash_y + 32)], fill=(120, 24, 22, 255))
    
    # 粗绳编织缠绕层 (4 道粗朱红麻绳)
    for i in range(4):
        sy = sash_y - 6 + i * 11
        # 主绳
        sd.line([(cx - 66, sy), (cx + 73, sy + 2)], fill=(185, 42, 34, 255), width=7)
        # 绳索高光（立体捻线效果）
        sd.line([(cx - 64, sy - 2), (cx + 71, sy)], fill=(228, 72, 60, 220), width=2)
        # 绳索暗缝
        sd.line([(cx - 64, sy + 2), (cx + 71, sy + 4)], fill=(85, 16, 15, 200), width=2)

    # 中心腰封大绳结 (Intricate central knot on right/front side)
    knot_cx, knot_cy = cx + 42, sash_y + 14
    sd.ellipse((knot_cx - 16, knot_cy - 16, knot_cx + 16, knot_cy + 16), fill=(160, 32, 26, 255), outline=(75, 14, 12, 255), width=3)
    sd.ellipse((knot_cx - 11, knot_cy - 11, knot_cx + 11, knot_cy + 11), fill=(215, 60, 48, 255))
    sd.ellipse((knot_cx - 6, knot_cy - 6, knot_cx + 6, knot_cy + 6), fill=(130, 22, 18, 255))

    # 腰带垂下的两道赤红飘带 (Dangling ribbons)
    ribbon1 = [(knot_cx - 4, knot_cy + 8), (cx + 25, cy + 110), (cx + 10, cy + 190), (cx - 5, cy + 260)]
    sd.line(ribbon1, fill=(195, 45, 36, 255), width=9)
    sd.line([(p[0]+1, p[1]) for p in ribbon1], fill=(235, 85, 72, 200), width=3)

    ribbon2 = [(knot_cx + 4, knot_cy + 10), (cx + 55, cy + 100), (cx + 50, cy + 175), (cx + 42, cy + 240)]
    sd.line(ribbon2, fill=(165, 32, 25, 255), width=7)
    sd.line([(p[0]+1, p[1]) for p in ribbon2], fill=(215, 65, 52, 180), width=2)

    # 悬挂的古木法器牌 / 降魔木牌 (Wooden Talisman Tag)
    tag_x, tag_y = knot_cx + 12, knot_cy + 22
    sd.line([(knot_cx + 6, knot_cy + 8), (tag_x + 6, tag_y)], fill=(80, 60, 40, 255), width=2)
    sd.polygon([(tag_x, tag_y), (tag_x + 14, tag_y), (tag_x + 14, tag_y + 44), (tag_x + 7, tag_y + 50), (tag_x, tag_y + 44)], fill=(92, 68, 44, 255), outline=(42, 28, 16, 255), width=2)
    sd.line([(tag_x + 7, tag_y + 8), (tag_x + 7, tag_y + 38)], fill=(185, 50, 35, 230), width=2) # 朱砂符印

    base_img.alpha_composite(sash_layer)

    # =========================================================================
    # 图层 5: 右手持刀（迎敌长刀·单刃唐横刀/斩纸刀）
    # =========================================================================
    sword_layer, swd = create_canvas(size)
    
    # 右肩与大臂
    swd.polygon([(cx + 30, cy - 80), (cx + 78, cy - 30), (cx + 60, cy + 40), (cx + 15, cy + 10)], fill=(24, 28, 38, 255))
    # 右前臂 (伸向前下方持刀)
    swd.polygon([(cx + 65, cy + 20), (cx + 115, cy + 55), (cx + 105, cy + 78), (cx + 55, cy + 45)], fill=(18, 20, 28, 255))
    # 右手腕黑布缠带 (Forearm wraps)
    for yw in range(cy + 40, cy + 75, 8):
        swd.line([(cx + 80 + (yw - cy - 40), yw), (cx + 65 + (yw - cy - 40), yw + 6)], fill=(50, 56, 70, 240), width=2)

    # 右手握拳手掌 (Grip)
    hand_x, hand_y = cx + 112, cy + 62
    swd.ellipse((hand_x - 10, hand_y - 9, hand_x + 12, hand_y + 11), fill=(32, 28, 26, 255))
    swd.ellipse((hand_x - 7, hand_y - 6, hand_x + 9, hand_y + 8), fill=(60, 48, 42, 255))

    # 刀柄 (Hilt / Tsuka) - 倾斜向左上方
    hilt_top = (hand_x - 38, hand_y - 32)
    hilt_bot = (hand_x + 16, hand_y + 14)
    swd.line([hilt_top, hilt_bot], fill=(22, 20, 24, 255), width=10)
    # 刀柄红绳缠绕 (Tsukamaki)
    for step in range(5):
        t = step / 4.0
        hx = hilt_top[0] + (hilt_bot[0] - hilt_top[0]) * t
        hy = hilt_top[1] + (hilt_bot[1] - hilt_top[1]) * t
        swd.line([(hx - 4, hy + 3), (hx + 4, hy - 3)], fill=(175, 40, 32, 255), width=3)
    # 刀首金属环 (Pommel)
    swd.ellipse((hilt_top[0] - 6, hilt_top[1] - 6, hilt_top[0] + 6, hilt_top[1] + 6), fill=(135, 105, 55, 255))

    # 圆形古铜刀镡 (Circular Tsuba Handguard)
    tsuba_pt = (hand_x + 16, hand_y + 14)
    swd.ellipse((tsuba_pt[0] - 7, tsuba_pt[1] - 14, tsuba_pt[0] + 7, tsuba_pt[1] + 14), fill=(145, 110, 50, 255), outline=(50, 35, 15, 255), width=2)

    # 锋利刀刃 (Sharp Katana/Dao Blade) - 延伸向右前下方
    blade_start = (tsuba_pt[0] + 4, tsuba_pt[1] + 4)
    blade_tip = (cx + 285, cy + 225) # 极长且具压迫感的锋利刀身
    
    # 刀背 (厚重黑钢)
    swd.line([blade_start, blade_tip], fill=(38, 44, 54, 255), width=7)
    # 刀身刃面 (冷钢渐变)
    swd.line([(blade_start[0] - 2, blade_start[1] + 2), (blade_tip[0] - 2, blade_tip[1] + 2)], fill=(120, 138, 156, 255), width=5)
    # 刀刃极亮斩线 (Razor edge highlight)
    swd.line([(blade_start[0] - 4, blade_start[1] + 4), (blade_tip[0] - 3, blade_tip[1] + 3)], fill=(225, 238, 250, 255), width=2)
    # 刀尖反光
    swd.polygon([blade_tip, (blade_tip[0] - 16, blade_tip[1] - 5), (blade_tip[0] - 6, blade_tip[1] + 8)], fill=(240, 248, 255, 255))

    base_img.alpha_composite(sword_layer)

    # =========================================================================
    # 图层 6: 左臂与提灯手 (Left Arm Holding Lantern Anchor)
    # =========================================================================
    arm_layer, ad = create_canvas(size)
    
    # 左手大袖宽袍 (Draped sleeve extending to lantern anchor)
    # 目标锚点位于 (cx + 64, cy + 40) = (384, 440)
    anchor_x, anchor_y = cx + 64, cy + 40
    
    sleeve_poly = [
        (cx - 20, cy - 70),  # 左肩
        (cx + 35, cy - 40),  # 大臂上沿
        (anchor_x + 10, anchor_y - 15), # 手腕上
        (anchor_x + 5, anchor_y + 15),  # 手腕下
        (cx + 25, cy + 95),  # 下垂宽袖底
        (cx - 35, cy + 60),  # 袖褶
        (cx - 50, cy - 30)   # 腋下
    ]
    ad.polygon(sleeve_poly, fill=(24, 28, 36, 255))
    
    # 袖口破烂毛边
    ad.polygon([(cx + 25, cy + 95), (cx + 10, cy + 60), (cx + 32, cy + 115)], fill=(15, 18, 24, 255))
    ad.polygon([(cx + 5, cy + 85), (cx - 8, cy + 55), (cx + 10, cy + 110)], fill=(15, 18, 24, 255))
    
    # 左手握拳持环手型 (Hand holding lantern ring at anchor (384, 440))
    ad.ellipse((anchor_x - 8, anchor_y - 12, anchor_x + 14, anchor_y + 10), fill=(28, 24, 22, 255))
    ad.ellipse((anchor_x - 4, anchor_y - 9, anchor_x + 10, anchor_y + 6), fill=(58, 48, 40, 255))
    # 手指受光
    for f_idx in range(3):
        ad.line([(anchor_x - 2 + f_idx * 4, anchor_y - 6), (anchor_x + 2 + f_idx * 4, anchor_y + 4)], fill=(145, 105, 65, 220), width=2)

    base_img.alpha_composite(arm_layer)

    # =========================================================================
    # 图层 7: 围颈黑巾与飘拂朱红巾带 (Neck Scarf & Flowing Red Scarf)
    # =========================================================================
    neck_layer, nd = create_canvas(size)
    
    # 飘向左后方的长红巾 (Flowing crimson scarf banner)
    scarf_curve = [
        (cx + 15, cy - 110),
        (cx - 30, cy - 120),
        (cx - 95, cy - 105),
        (cx - 165, cy - 75),
        (cx - 230, cy - 35),
        (cx - 210, cy - 10),
        (cx - 150, cy - 50),
        (cx - 85, cy - 80),
        (cx - 20, cy - 90)
    ]
    nd.polygon(scarf_curve, fill=(185, 38, 30, 255))
    nd.line([(p[0], p[1]-2) for p in scarf_curve[:5]], fill=(235, 80, 68, 220), width=3)
    # 巾尾分叉撕裂
    nd.polygon([(cx - 230, cy - 35), (cx - 210, cy - 10), (cx - 260, cy - 25)], fill=(150, 28, 22, 255))

    # 围脖黑布层 (Dark Cowl Collar)
    nd.polygon([(cx - 45, cy - 130), (cx + 35, cy - 120), (cx + 45, cy - 70), (cx - 35, cy - 65)], fill=(16, 18, 24, 255), outline=(32, 38, 50, 255), width=2)
    # 脖颈折叠布褶
    nd.line([(cx - 30, cy - 100), (cx + 30, cy - 92)], fill=(45, 52, 68, 200), width=4)
    nd.line([(cx - 25, cy - 82), (cx + 35, cy - 75)], fill=(45, 52, 68, 200), width=4)

    base_img.alpha_composite(neck_layer)

    # =========================================================================
    # 图层 8: 头部阴影、编织斗笠与炽热金眸 (Head, Bamboo Hat & Glowing Eyes)
    # =========================================================================
    head_layer, hd = create_canvas(size)
    
    # 斗笠下的纯黑面容剪影
    hd.ellipse((cx - 30, cy - 165, cx + 45, cy - 95), fill=(8, 10, 14, 255))
    
    # 炽热双眸 (侧视朝向右前方，右眼在前稍大，左眼在后稍敛)
    eye_r = (cx + 26, cy - 122) # 前方右眼
    eye_l = (cx + 8, cy - 123)  # 后方左眼
    
    base_img.alpha_composite(head_layer)
    draw_glowing_eyes(base_img, eye_l, eye_r)

    # 绘制高精编织竹斗笠 (侧视宽大斗笠)
    draw_woven_hat(base_img, center_x=cx + 10, center_y=cy - 160, width=320, height=130, is_side_view=True)

    # =========================================================================
    # 图层 9: 侧面暖橙色提灯漫射环境光 (Volumetric Lantern Rim Lighting)
    # =========================================================================
    rim_layer, rd = create_canvas(size)
    
    # 身体右前侧（迎光面）的暖橙金边光
    rim_strokes = [
        # 头部斗笠右檐
        ([(cx + 80, cy - 145), (cx + 165, cy - 125)], (255, 175, 75, 180), 3),
        # 围脖右沿
        ([(cx + 35, cy - 120), (cx + 45, cy - 75)], (245, 145, 50, 200), 3),
        # 右肩与持刀大臂外缘
        ([(cx + 55, cy - 40), (cx + 82, cy - 15), (cx + 72, cy + 35)], (255, 160, 60, 190), 4),
        # 右前臂与手腕
        ([(cx + 75, cy + 28), (cx + 115, cy + 55)], (255, 170, 70, 220), 3),
        # 腰封右侧与绳结外缘
        ([(cx + 68, cy + 18), (cx + 75, cy + 45)], (255, 185, 80, 230), 4),
        # 前袍垂褶迎光面
        ([(cx + 72, cy + 65), (cx + 85, cy + 200), (cx + 98, cy + 340)], (235, 135, 45, 160), 4),
        # 前腿小腿迎光面
        ([(cx + 20, cy + 230), (cx + 35, cy + 340)], (220, 120, 40, 150), 3),
    ]
    for pts, col, w in rim_strokes:
        rd.line(pts, fill=col, width=w)

    rim_blur = rim_layer.filter(ImageFilter.GaussianBlur(2))
    base_img.alpha_composite(rim_blur)

    # =========================================================================
    # 图层 10: 如果需要合成提灯 (用于 demo/player_keeper.png 完整全貌)
    # =========================================================================
    if include_lantern:
        lantern_img = draw_lantern_prop_image()
        # 提灯挂在 anchor (cx + 64, cy + 40) = (384, 440)
        # 提灯素材尺寸 256x384, 锚点在 (128, 20)
        # 因此粘贴位置为 (384 - 128, 440 - 20) = (256, 420)
        
        # 先绘制提灯发光外晕
        glow_layer, gd = create_canvas(size)
        lamp_center = (384, 440 + 175)
        for r, a in [(180, 15), (130, 28), (80, 55), (45, 95)]:
            gd.ellipse((lamp_center[0] - r, lamp_center[1] - r, lamp_center[0] + r, lamp_center[1] + r), fill=(255, 140, 20, a))
        glow_blur = glow_layer.filter(ImageFilter.GaussianBlur(18))
        base_img.alpha_composite(glow_blur)
        
        base_img.alpha_composite(lantern_img, (anchor_x - 128, anchor_y - 20))

    # 全局国风手绘微噪点处理
    base_img = add_subtle_grain(base_img, 8)
    return base_img


def main():
    print("🎨 开始重构中式怪谈卡牌《执灯人》高精度主角资产...")

    # 1. 生成解耦提灯道具 keeper_lantern_prop.png (256 x 384)
    lantern_img = draw_lantern_prop_image()
    lantern_path = CHAR_DIR / "keeper_lantern_prop.png"
    lantern_img.save(lantern_path, optimize=True)
    print(f"✅ 已生成解耦提灯道具: {lantern_path} ({lantern_img.size})")

    # 2. 生成解耦纯净身体部件 keeper_body_clean.png (640 x 800)
    body_clean_img = draw_keeper_body_side(include_lantern=False)
    body_path = CHAR_DIR / "keeper_body_clean.png"
    body_clean_img.save(body_path, optimize=True)
    print(f"✅ 已生成解耦纯净身体部件: {body_path} ({body_clean_img.size})")

    # 3. 生成完整侧视立绘 demo/player_keeper.png (640 x 800)
    full_player_img = draw_keeper_body_side(include_lantern=True)
    full_path = DEMO_DIR / "player_keeper.png"
    full_player_img.save(full_path, optimize=True)
    print(f"✅ 已生成完整侧视立绘: {full_path} ({full_player_img.size})")

    print("\n🎉 主角资产重构渲染全部完成！")


if __name__ == "__main__":
    main()
