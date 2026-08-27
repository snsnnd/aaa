# 正式版路线图

> 起点日期：2026-08-28 | 基线：demo 战斗垂直切片（54 项验证）
> Demo 保留于 `scenes/main.tscn` + `scripts/main.gd` + `scripts/battle/` + `scripts/presentation/`，作为玩法更新验证场，不删除。

## 模块划分（当前已完成）

```text
scripts/
  battle/
    battle_simulation.gd   纯规则：状态、命令、事件、牌库、判定
  presentation/
    battle_view.gd         世界：场景、敌招动画、玩家姿态、特效、音频
    battle_hud.gd          UI：状态栏、手牌、牌堆视图、菜单、结算
  main.gd                  组合根：装配三层、路由输入与事件（约 300 行）
```

验证入口：`tools/validate_demo.sh`（烟雾 + 视觉双通道），对三层重构不敏感——这正是分层的目的。

## 正式版增量顺序（每步都可玩、可验证）

| 里程碑 | 内容 | 验收 |
|--------|------|------|
| M1 敌招阶段机 | 把三套硬编码动画改为数据驱动阶段时间线（telegraph/windup/commit/recover + 可防性 + 打断规则），视图读阶段而非公式 | demo 三敌招表现与现在一致 + 新增一个敌人只写数据 |
| M2 卡牌资源化 | `CONTENT_DESIGN.md` 首发卡池入库（.tres 或目录化 JSON + 类别/费用/效果 op），效果执行器替换 main 里的 match | 卡池数据哈希稳定，召符/奖励按池抽取 |
| M3 跑局骨架 | 三幕节点图（战斗/奖励/篝火/商店/Boss）、怨契三选一、场景切换 | 完整一局可通，死亡回主菜单 |
| M4 存档 | RunState 快照（模拟层已无场景依赖，成本低）、设置持久化 | 关游戏续玩，版本号+内容哈希校验 |
| M5 敌人扩充 | 按 CONTENT_DESIGN 敌人表实现第一幕 5+2 | 每个敌人独立节奏签名 |
| M6 数值平衡 | 基于 M1-M5 的真实通关数据调整 | 完美覆盖率 ~55%±10%（GDD §3） |

## 状态机决策

- **战斗阶段机**：维持 enum+match（WINDUP/RESOLVING/VICTORY/DEFEAT），M3 引入跑局流程时把场景级状态（地图/奖励/商店）另立 RunFlow 状态机，不与战斗混用。
- **敌招阶段机**：M1 必做。每招 = 阶段数组 `[{name, duration, defense: none/success/perfect, interrupt: [card_ids], pose_curve}]`，模拟层按阶段推进并发出 `phase_changed` 事件；视图按当前阶段+阶段进度演姿势。新敌人零代码。

## 不做（防止范围蔓延）

- 多人/回放（接口已预留：命令/事件/种子/快照边界就位）
- 每张卡独立脚本；效果一律走操作码执行器
- 手写动画帧；继续程序化姿态直到美术管线升级
