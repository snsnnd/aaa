# 项目 aaa — 设计索引

> 卡牌 × 肉鸽 × 持续攻防 | 单人开发 | Godot 4.7 Mono | 目标：小型精策（30-60分钟一局）

## 文档结构
| 文件 | 内容 | 状态 |
|------|------|------|
| [decisions_log.md](decisions_log.md) | 全部已拍板决策 + 讨论理由 | 持续更新 |
| [GDD_core.md](GDD_core.md) | 核心玩法机制规格 | v0.1 已定稿 |
| [market_notes.md](market_notes.md) | 市场分析快照（2026-08） | 已定稿 |
| [art_direction.md](art_direction.md) | C 手绘厚涂正式规范与概念图 | v0.2 已定稿 |
| [story_bible.md](story_bible.md) | 世界观：轮回之秤/执灯人/三色怨气（嗔痴疑） | v0.1 已定稿 |
| [DEMO.md](DEMO.md) | 基础战斗 Demo 操作与验证范围 | 可运行 |
| [CARD_ACQUISITION.md](CARD_ACQUISITION.md) | 战斗内抽牌循环与战后怨契三选一 | v0.1 已定稿 |
| [GAME_FEEL_RESEARCH.md](GAME_FEEL_RESEARCH.md) | 对标游戏手感调研（只狼/九日/匹诺曹/Eden 等）与补强路线 | 调研完成 2026-08-29 |
| [ACTION_FEEL_RESEARCH.md](ACTION_FEEL_RESEARCH.md) | 格斗/动作手感调研（帧学/取消系统/Roman Cancel/连招表达） | 调研完成 2026-08-29 |
| [ACTION_POSE_SPEC.md](ACTION_POSE_SPEC.md) | 玩家动作姿态规范：20 姿态词汇 + 全动作三段轨道（生图对照用） | v1 已定稿 |
| [ASSET_GEN_PROMPTS.md](ASSET_GEN_PROMPTS.md) | 定妆图→战斗资产生成提示词（朝向基准/拆层5件/核心8姿态/回收规格） | v1 已定稿 |
| [STS2_CODE_RESEARCH.md](STS2_CODE_RESEARCH.md) | 杀戮尖塔 2 代码架构研究与本项目启示 | 研究快照 2026-08-27 |

## 一句话概念
> **大殓之夜，怨鬼讨债。你是最后一个打更人——灯照本相，怨还其身：接住它的刀，替它了断。**
> 只狼式弹反 × 杀戮尖塔式构筑 × 快慢刀节奏读招，持续攻防卡牌肉鸽。
> 战斗骨架见 [GDD_core.md](GDD_core.md)，世界观见 [story_bible.md](story_bible.md)。

## 开发约定
- 引擎：Godot 4.7.2 (Mono/C#)，Windows 平台优先
- 规模定位：小型精策——几十个房间短循环，敌人种类少而精
- 资产管线：AI 辅助生成 + 统一风格校验（见 opencode skills: create-game-assets）
- 技能包就位：game-feel / physics-tuning / godot-tween-animation / godot-camera-system

## 当前可运行内容

- `project.godot`：主场景为正式版标题界面（scenes/game.tscn）；demo 战斗保留于 scenes/main.tscn
- **肉鸽战略层**：随机分支地图与路线选择、纸钱经济与鬼市（买牌/遗物/删牌/回血）、遗物 10 件、歇脚升级牌、难度阶梯（通关解锁）、Seed、继续游戏与存档管理
- **敌人机制**：每名敌人一条专属规则（纸胎甲/加速/骰运/拖拽偷牌/重尸/记仇/惊灯）；守灯人三阶段（撕灯/收灯），多段招独立分段伤害
- **卡牌系统**：效果列表驱动（CardSystem），34 张符牌含升级（"id+"）；问路=牌堆顶看三选一；长明=真实灯油上限提升
- **剧情耦合**：事件旗标进入战斗规则（破纸胎甲、骰运做局、窗口放宽、Boss 慢半拍）
- **基础设施**：TimeController 统一时间流速；InputMap 动作 + 键位重映射 + 手柄；无障碍（震屏/闪光/文字/色觉/反应窗口辅助）；渐进式教学；RunState 可序列化 + 自动存档
- **数据闭环**：Telemetry 收集逐招误判率、首死位置、卡牌选择率、召符资源占比、构筑胜率、退出节点（user://telemetry/summary.json）
- `Space` 是牌组外的统一防范：成功获得 1 还愿点，完美获得 1 点并进入乘势（僵直中还刃追加、召符半价），失误触发短冷却
- `tools/validate_demo.sh`：冒烟+画面验证；`tools/validate_roguelike.gd`：肉鸽系统 24 项验证；`tools/validate_three_builds.gd`：三构筑分化验证
