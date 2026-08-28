# 美术资产全景规格与生产分工指南 (Art Assets Specification & Production Matrix)

> 版本：v1.0 | 适用项目：`aaa` (中式怪谈卡牌肉鸽 × 弹反窗口)
> 上层依据：`art_direction.md` (C方案手绘厚涂)、`GDD_core.md`、`CONTENT_DESIGN.md`

---

## 一、美术总纲与核心视觉法则

### 1.1 核心调色与明度法则
- **近黑夜景（60% ~ 70%）**：背景与暗部保持近黑，为战斗核心信息让出最大视觉对比度；
- **冷青鬼气（磷光/残月）**：所有厉鬼敌人、怨气刀光、阴暗环境反射采用冷青（`#2d8a94`）与灰绿色调；
- **暖橙命火（灯笼/余烬）**：执灯人、还愿点、命火、治疗采用高饱和暖橙金（`#f2a03c` / `#ffd460`）；
- **朱砂赤红（警示/慢刀/重击）**：赤·嗔重击、受击流血、道教朱砂符咒采用暗红与亮白芯（`#bd3d45`）。

### 1.2 视觉信息优先级（防光污染）
1. **第一优先级（永远最清晰）**：角色与敌人本体剪影（硬边）、武器刃口与鬼手接触点；
2. **第二优先级**：敌招预警（白芯闪烁、意图变色、假释放提示）；
3. **第三优先级**：卡牌 UI、还愿点槽位与生命数值；
4. **第四优先级（允许模糊失边）**：环境瓦片、远景建筑、背景雨雾细节。

---

## 二、场景环境全景规划 (Scenes & Environments)

游戏共分三幕，每幕均采用 **5 层独立视差（Parallax）深度结构**：

```
Layer 0 (远景天空/天体) ➔ Layer 1 (远景地标剪影) ➔ Layer 2 (中景主体建筑) ➔ Layer 3 (地面与反光) ➔ Layer 4 (近景雨雾遮罩)
```

| 场景幕次 | 场景名称 | 核心视觉元素 | 光色氛围 | 视差层级拆解 | 生产方式建议 |
|---|---|---|---|---|---|
| **第一幕** | **雨夜老街** (Old Street) | 破败明清老铺、残月云遮、青石积水反光、巡更灯笼、歪斜招牌 | 极暗夜景 + 暖橙窗烛 + 湿冷反光 | • L0: 阴云残月天<br>• L1: 远景城楼屋脊<br>• L2: 老街破败铺面<br>• L3: 湿石路面反光<br>• L4: 前景斜雨与地气 | **程序化/手工分层切片**（已在 `assets/game/environments/old_street/` 完成） |
| **第二幕** | **石桥乱葬岗** (Stone Bridge & Graves) | 断裂拱桥、枯柳水草、浮水河灯、倾斜墓碑群、水面磷火 | 幽冥冷绿 + 幽暗河水 + 游离磷光 | • L0: 墨绿夜空<br>• L1: 远景荒山与枯树<br>• L2: 乱葬岗残碑石桥<br>• L3: 忘川浅滩水波<br>• L4: 水汽与漂浮河灯 | **AI生图概念 ➔ 人工分层拆解** |
| **第三幕** | **望乡台忘川** (Nostalgia Platform) | 断裂巨型轮回之秤、逆流忘川、漫山彼岸花海、血色残月、虚幻业镜 | 浓烈深红 + 业火暗金 + 虚空近黑 | • L0: 漩涡血月<br>• L1: 悬空断秤残骸<br>• L2: 望乡台与业镜<br>• L3: 逆流河床与花海<br>• L4: 飞舞彼岸花瓣 | **AI生图大底 ➔ 人工修光分层** |

---

## 三、角色与敌人全谱系拆件与动效 DNA

为确保未来扩充数十个敌人时**零代码重复**，所有角色均接入 `ModularCharacterView` 与 `CharacterStateMachine`，并基于 `CharacterAnimProfile.tres` 数据表驱动。

### 3.1 角色全览与动效特征

| 角色 ID | 名称/身份 | 攻击与机制特点 | 动效模式 (`MotionType`) | 专属动效 DNA (Animation DNA) | 图层拆件要求 (Layer Slicing) |
|---|---|---|---|---|---|
| `keeper` | **执灯人 (玩家)** | 基础防范、斩纸、出牌施法 | `HUMAN_GROUND` (人型呼吸) | 沉稳深呼吸（周期2.2s）、手提灯笼受物理重力滞后摆动、足底贴地软阴影 | • 身体主干 (`keeper_body_clean`)<br>• 独立提灯与铁链 (`keeper_lantern_prop`)<br>• 斗笠阴影 |
| `lantern_imp` | **灯笼小鬼** | 火苗突刺（快刀）、灯油泼溅 | `FLOAT_SPIRIT` (浮空灵体) | 高频上下正弦漂游、神经质横向微颤、悬挂灯笼剧烈晃动、悬浮阴影动态缩放 | • 灵体躯干 (`imp_body`)<br>• 悬吊小灯笼 (`imp_lantern`)<br>• 头部磷火微粒 |
| `patrol_corpse` | **更练尸** | 梆子二拍（稳节奏）、冲撞 | `RIGID_MECHANICAL` (机械顿挫) | 4拍机械僵硬巡更步态、步态卡点停顿、手持铜锣与短棒保持机械僵持 | • 僵尸躯干 (`corpse_body`)<br>• 巡更短棒 (`corpse_mallet`)<br>• 铜锣道具 (`corpse_gong`) |
| `paper_apprentice` | **纸扎学徒** | 纸刀单劈、纸人抱投技 | `PAPER_FLUTTER` (折纸微颤) | 轻盈失重感、折纸边缘随风微颤、纸刀轻飘摇曳、无骨骼韧性扭曲 | • 折纸身体 (`paper_body`)<br>• 薄纸双刀 (`paper_blades`) |
| `barber_ghost` | **剃头匠** | 双剃快连、按头刀（不可防） | `FLOAT_SPIRIT` + 快速剪切 | 贴地滑行飘游、悬空双剃刀高频咔嗒开合、阴郁下垂身段 | • 阴魂上半身 (`barber_body`)<br>• 浮空剃刀左右件 (`barber_razors`) |
| `well_sisters` | **井中姐弟** | 湿发鞭挞、双生抓、拖井 | `SLITHER_CREEP` (水生蠕动) | 湿发波浪形下垂摆动、交替探出双臂、湿漉滴水下沉感 | • 姐弟交缠躯干 (`sisters_body`)<br>• 伸出鬼手 (`sisters_hands`) |
| `gambler_ghost` | **赌鬼** | 骰子三连（带虚招）、翻桌 | `NERVOUS_JITTER` (神经抽搐) | 极高频横向抽搐、骨牌骰蛊剧烈震颤、狂热不稳的失衡体态 | • 骨架躯干 (`gambler_body`)<br>• 骰蛊与骨牌 (`gambler_props`) |
| `mortuary_warden` | **义庄看守** (精英) | 铁链横扫、棺板压顶、呼尸 | `HUMAN_GROUND` + 重型惯性 | 沉重笨重拖步、生锈铁链地面拖行拖尾、重型踏地顿挫 | • 魁梧躯干 (`warden_body`)<br>• 生锈锁链 (`warden_chains`)<br>• 棺木板残件 |
| `lantern_keeper` | **守灯人** (第一幕Boss) | 三段连斩、灯焰领域（禁防） | `MAJESTIC_BOSS` (庄严领主) | 宏大低频缓慢悬浮、背后神圣命火领域光环呼吸脉冲、庄严衣袍舒展 | • 领主尊者躯干 (`boss_body`)<br>• 环形命火法阵光环 (`boss_aura`)<br>• 大典长明灯 |

---

## 四、AI 生图 vs. 程序化优化生产分工矩阵 (Production Matrix)

为保证项目高效推进且不发生“资产失控、风格漂移、动效无法切片”的风险，特制定以下生产分工红线：

```
┌──────────────────────────────────────────────────────────────────────────────────┐
│                             美术资产生产分类与决策矩阵                           │
├──────────────────────────┬──────────────────────────┬────────────────────────────┤
│ 生产路径                 │ 适用资产类型             │ 核心原因 / 验收标准        │
├──────────────────────────┼──────────────────────────┼────────────────────────────┤
│ 路径 A: 纯 AI 生图       │ • 30~120 张静态卡面插画  │ • 纯静态、无切片需求       │
│ (AI Image Generation)    │ • 随机事件剧情大插画     │ • 生产效率提升 90% 以上    │
│                          │ • 局外遗物/道具静态概念图│ • 统一 LoRA 与 Prompt 即可 │
├──────────────────────────┼──────────────────────────┼────────────────────────────┤
│ 路径 B: 混合工作流       │ • 场景各视差层概念大图   │ • AI 生成 2K 概念氛围图    │
│ (AI 概念 ➔ 人工切片)    │ • 战斗角色高精度厚涂立绘 │ • 人工/工具拆分为透明部件  │
│                          │ • Boss 阶段变形立绘      │ • 导入 Godot 节点插槽驱动  │
├──────────────────────────┼──────────────────────────┼────────────────────────────┤
│ 路径 C: 纯程序/手工制作  │ • 战斗特效粒子贴图与光环 │ • 需精准数学渐变与Alpha通道│
│ (Engine/Code/Shaders)    │ • 屏幕折射/消散 Shaders  │ • 保证 60fps 跨平台性能    │
│                          │ • 卡框/UI 交互控件       │ • 保证视规同步与快慢刀对齐│
│                          │ • 状态机与物理摆动曲线   │                            │
└──────────────────────────┴──────────────────────────┴────────────────────────────┘
```

### 4.1 路径 A：卡面与事件插画 AI 生图 Prompt 标准模板

在生成静态卡面时，使用统一的 Prompt 结构锁定风格（禁止随意放飞）：

```text
Prompt Template:
[Subject], Dark Chinese Folk Horror Painterly style, thick oil brushstrokes and wet ink edges, high contrast, muted dark charcoal background (#0b0d10), sharp rim lighting with [Cold Cyan / Warm Amber / Cinnabar Red], expressive silhouette, atmospheric mist and rain, highly detailed focal point, no text, clean composition, masterpiece, 8k.

Negative Prompt:
anime, cute, bright colorful cartoon, 3d render, modern clothes, western medieval, golden frames, text, watermark, signature, blurry.
```

---

## 五、资产落地与目录索引

当前所有已优化的资产已全部归档至标准目录：

```text
assets/game/
├── environments/
│   └── old_street/                  # 5层视差老街场景贴图与 env_old_street_parallax.tscn
├── characters_sliced/               # 角色解耦独立部件 (body_clean, lantern_prop)
├── character_showcase/              # 角色动效状态机展厅 (showcase.tscn + 8个.tres配置)
├── vfx/                             # 10套独立特效预制体、11张粒子贴图、4套Shaders
└── ui/                              # 3类中式卡框 (card_frame_zhan/yu/you)
```
