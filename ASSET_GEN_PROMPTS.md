# 战斗资产生成提示词（执灯人·从定妆图到可动资产）

> 用途：把定妆图（斗笠发光眼/破袍红绦/左手刀/右手灯笼）转化为战斗可用的分层资产与姿态关键帧。
> 使用顺序：① 战斗朝向基准帧 → ② 拆层（5 层）→ ③ 姿态关键帧（先核心 8 姿态）→ ④ 回收进游戏。
> 铁律：**所有提示词都必须携带"同一角色、同一光源、同一画风"的锁定描述**，否则每一帧都是新角色。

## 〇、角色锁定描述（每条提示词开头都要带）

```
[LOCK] a night-watch lantern keeper, wide straw hat brim shadowing his face,
two glowing orange eyes in the dark, tattered layered dark blue-grey hanfu,
crimson sash and tassels, gauntlets and straw sandals, holding a straight
sword low in his left hand and a glowing paper lantern in his right,
hand-painted thick-oil style, muted blue-grey palette, warm brown cloth,
orange-gold lantern glow as the only saturated color, clean silhouette
```

技术后缀（每条结尾都带）：

```
full body, side view facing right, transparent background, no ground shadow,
no background elements, character sheet asset, crisp edges
```

> 说明：战斗是横版侧视（玩家居左朝右）。当前定妆图接近正 3/4 面——
> **第一步先把朝向统一到侧面**，后面所有拆层/姿态才不会视角漂移。

## 一、战斗朝向基准帧

```
[LOCK], turned to a strict side profile view facing right, standing on guard:
knees slightly bent, sword held low behind, lantern raised at chest height,
weight on the back foot, coat and sash hanging naturally
[后缀]
```

> 产出 1 张"侧面戒备帧"。这张是拆层的底图——后续所有层都从它裁出，
> 保证拼回时逐像素重合。多生成几张挑剪影最清晰的一张，**固定 seed**。

## 二、拆层（5 层，供姿态通道驱动）

方法：以侧面基准帧为垫图（img2img / 局部重绘），每次只"拿走"一个部件，
不重绘其余部分。每层提示词：

**L1 · 身体层**（含头/斗笠/躯干/双腿/衣摆，双臂保留至空手自然下垂）
```
[LOCK], side view facing right, standing guard pose, the lantern and its
right forearm removed, the sword and its left forearm removed, empty sleeves
hang naturally, same pose and lighting as reference, isolated cut-out,
transparent background, keep original colors and brushwork, no redraw
[后缀]
```

**L2 · 灯笼臂**（右前臂+手，肘部断口整齐）
```
[LOCK], only the right forearm and hand gripping a lantern handle, cut at
the elbow, natural dark sleeve and gauntlet, holding pose, same lighting as
reference, isolated cut-out on transparent background, no body, no lantern
[后缀]
```

**L3 · 灯笼**（含提梁/挂绳/红穗，不含手）
```
[LOCK], only the glowing paper lantern with its hanging rope, red tassel,
warm orange glow from inside, same lighting as reference, isolated cut-out,
transparent background, no hand, no arm
```

**L4 · 刀臂**（左前臂+手，握刀姿势）
```
[LOCK], only the left forearm and hand in a sword-gripping pose, cut at the
elbow, dark sleeve and gauntlet, same lighting as reference, isolated
cut-out, transparent background, no sword, no body
```

**L5 · 长刀**（含刀柄/刀穗）
```
[LOCK], only the straight chinese jian sword with its hilt and red tassel,
same lighting and edge glow as reference, isolated cut-out, transparent
background, no hand
```

> 拆层要点：**宁可用"移除其余"的否定式描述，也不要正向重画**——重画必漂移。
> 每层生成后叠回基准帧检查对齐，不齐就重摇（同 seed 换 denoise 强度）。

## 三、姿态关键帧（核心 8 姿态先行）

模板（把 `{POSE}` 换成下面的姿态描述；**始终垫侧面基准帧 + 固定 seed**）：

```
[LOCK], side view facing right, {POSE}, full body, transparent background,
no ground shadow [后缀]
```

| # | 姿态 | {POSE} 描述 |
|---|---|---|
| 1 | guard 戒备 | knees bent, sword low behind, lantern at chest, weight back, shoulders tense |
| 2 | crouch 蹲蓄 | deep crouch, body compressed downward, shoulders pulled back-right, lantern swinging low behind, coiled like a spring |
| 3 | raise_high 高举 | arm fully raised overhead holding the lantern high, body stretched tall and leaning back, looking up |
| 4 | lunge_ext 突进 | deep forward lunge, body stretched long toward the right, back leg straight, lantern trailing behind, sleeves flying backward |
| 5 | overhead_end 劈落 | full overhead downward slam follow-through, body bent forward, shoulders dropped, lantern swung down-right, coat flaring |
| 6 | thrust_ext 刺击 | arm fully extended in a straight thrust toward the right, body at maximum horizontal stretch, back foot dragging |
| 7 | cast_fwd 掷符 | one arm casting forward, a paper talisman leaving the hand, lantern pulled forward, eyes glowing brighter |
| 8 | hurt 受击 | knocked backward, body folded and recoiling, lantern flung behind, sash whipping, coat blown back |

> 其余 12 姿态从 `ACTION_POSE_SPEC.md` 词汇表按同模板补齐。
> 每个姿态生成 2-4 张挑最好的一张；**先做核心 8 个**接进游戏看节奏，再补全。

## 四、回收进游戏的规格

- 尺寸：单层高 2048px，导出 PNG-32 透明；游戏内 `player_sprite.scale = 0.49` 已按此基准。
- 文件命名（放入 `assets/game/characters_sliced/`，与现有 keeper 系列并列）：
  `keeper2_body.png / keeper2_arm_lantern.png / keeper2_lantern.png / keeper2_arm_sword.png / keeper2_sword.png`
- 枢轴点（记录坐标，接入 rig）：
  - 身体根：胯部中心（现有 pivot 264,355）
  - 灯笼臂：肘部断口 → 灯笼提梁
  - 刀臂：肘部断口 → 刀柄握点
- 灯焰**不要画死在图里**：留空或单独一层——引擎里 `lantern_glow`（additive 呼吸光）已存在，焰随连势变亮是手感的一部分。
- 代码侧后续：姿态通道增加 `sword_arm` 通道（肩部旋转），`PlayerPoseLibrary` 的姿态字典扩字段即可，上层不动。

## 五、一致性检查清单（每张生成后过一遍）

- [ ] 斗笠宽度/帽穗方向与基准帧一致
- [ ] 眼睛发光位置在帽檐阴影内
- [ ] 红绦数量与系法一致
- [ ] 光源方向一致（右下灯笼暖光 + 环境冷光）
- [ ] 笔触密度一致（厚涂斑驳，不是厚涂+赛璐璐混搭）
- [ ] 透明背景无白边/黑边（去底光晕检查）
