# 杀戮尖塔 2 代码架构研究

> 研究日期：2026-08-27 | 游戏版本：Steam Early Access（0.107.x 时代证据为主）
> 目的：为项目 aaa 的战斗架构、内容管线与未来 PvP 预留提供参照。
> 性质：本项目 aaa 未使用杀戮尖塔 2 的任何代码或资产；本文只做架构学习。

---

## 0. 关于"网上有开源代码"的澄清

杀戮尖塔 2 **官方未开源**。网上能找到的资源分三类，可信度与合法性完全不同：

| 类型 | 代表 | 性质 | 本文如何使用 |
|------|------|------|--------------|
| 官方公开仓库 | `megacrit/sts2-mod-uploader` | 模组上传工具，唯一官方仓库 | 直接采信 |
| 社区框架与模组源码 | BaseLib、RitsuLib、ModTemplate、STS2MCP | 引用随游戏分发的 `sts2.dll` 编写，源码公开 | 证明游戏的公共可观察接口 |
| 反编译镜像 | `adoubt/sts2_source_code`、Spire Codex 数据管线 | 用 ILSpy 反编译 `sts2.dll` 得到约 3300 个 C# 文件 | 只用于理解结构，不复制代码/资产 |

结论：可以**学习**它的架构模式，不可以**搬运**它的实现。反编译产物属于 Mega Crit 版权资产。

---

## 1. 技术栈（官方确认，高可信）

| 项 | 事实 | 来源 |
|----|------|------|
| 引擎 | Godot（Mega Crit 自建 fork，社区称 **MegaDot**） | 官方 FAQ 明确 "We are using Godot"；fork 出自开发者 AMA 转述（中高可信） |
| 游戏逻辑语言 | **C# / .NET**，全部在 `sts2.dll` 中，**不是 GDScript** | Spire Codex 文档直接证实；所有模组源码 import 均为 C# |
| 场景/表现 | Godot `.tscn` + `N` 前缀节点类（如 `NPlayerHand`、`NMapScreen`） | 模组源码可观察 |
| 模组 SDK | `Godot.NET.Sdk/4.5.1` + `.NET 9`（模板工程） | ModTemplate csproj |
| 多人 | 最多 4 人合作，仅 Steam 好友邀请，无匹配系统 | 官方 FAQ |
| 平台 | Windows / macOS / Linux，Steam Deck 兼容 | 官方 FAQ |

选 Godot 的公开理由（开发者文章与 AMA）：轻量、跨三大桌面系统、构建导出快、开源可自行调试和打补丁、静态类型语言、场景格式对版本控制友好。代价是上游修复等待、贴图集工具链较弱。

---

## 2. 核心分层：Model 与 Node 严格分离（社区代码可观察，高可信）

这是全架构最重要的一条规则：**游戏逻辑住在纯 C# Model 里，Godot 节点只做表现**。

```text
MegaCrit.Sts2.Core.*（sts2.dll 内，由模组源码 import 证实）
├── Models          CardModel / RelicModel / PowerModel / CharacterModel / MonsterModel
│                   内容即代码：每张卡是一个 sealed 子类，带 base(费用, CardType, CardRarity, TargetType)
├── Entities        CardPlay / CardType / CardRarity / TargetType / Creature / Player / Potion
├── Commands        PlayerCmd.EndTurn(player, canBackOut) / PotionCmd.Discard(potion) / PowerCmd.Apply<T>
├── GameActions     PlayCardAction(card, target) 等；经 ActionQueueSynchronizer 排队执行
├── Runs            RunState / RunManager（全局单例）/ SerializableRun / RunState.FromSerializable
├── Combat          CombatManager.Instance.IsInProgress / ICombatState / CombatState
├── Nodes.*         NPlayerHand / NMapScreen / NRewardsScreen 等 Godot 节点（仅 UI/表现/输入）
├── Multiplayer.*   Game / Lobby / Serialization / Transport（INetGameService、PacketWriter/Reader）
├── Localization    本地化表 + DynamicVars（卡面数值动态变量）
├── ValueProps      伤害/格挡计算属性
├── Helpers / Logging / Modding   （ModInitializer 特性在此命名空间）
```

**证据实例**（STS2MCP，一个通过真实接口操作游戏的模组）：

```csharp
// 出牌走与游戏 UI 完全相同的动作队列
RunManager.Instance.ActionQueueSynchronizer.RequestEnqueue(new PlayCardAction(card, target));
// 结束回合走命令层
PlayerCmd.EndTurn(player, canBackOut: false);
// 查询手牌是纯数据
var card = player.PlayerCombatState.Hand.Cards[cardIndex];
card.CanPlay(out var reason, out _);
```

关键含义：
- 想改游戏状态，唯一正规路径是**往同步动作队列里塞动作**，而不是直接改字段。
- Model 层不含 Godot 类型依赖逻辑时，可在无头环境跑（这正是内容迁移工具和测试能自动化的原因）。
- `N` 前缀节点被明确当作表现层；模组绕过节点直接改私有 UI 状态被视为脆弱做法。

---

## 3. 内容即代码（官方确认，高可信）

- 初代 Unity 版把内容放 ScriptableObject；因 Feed 这类条件卡难以维护和调试，团队写了自动迁移工具把内容转成 **C# 类**，覆盖卡牌、遗物、怪物"pretty much all other content"（开发者 AMA 原话）。
- 好处：逻辑与表现分离后，"a huge amount" 的 C# 代码在从 Unity 换到 Godot 时**原样可用**；条件逻辑可以写测试、可以重构。
- 内容注册与查询：`ModelDb.Card<T>()` / `ModelDb.Relic<T>()`；模组经特性或内容包批量注册。
- 内容条目有**稳定公开 ID**（如 `MY_MOD_CARD_MY_STRIKE`），被存档、模型 ID、本地化 key、资源默认路径、解锁规则、跨模组引用共用；发布后视为不可变 API。

---

## 4. 多人与同步（官方事实 + 架构推断）

官方事实（补丁说明与 AMA）：
- 4 人合作、Steam 好友邀请、无匹配、无中途进出；存档由**房主持有**。
- 游戏有**状态分歧检测**（"state divergence"）并上报。
- 事件 RNG 种子必须在各端一致；`SavedProperty` 标识符跨端排序；`SerializableSave.NumReloads` 保持一致。
- 多人兼容性哈希用 `ModelIdSerializationCache`，内容**按 ModelId 排序**而非 C# 类型名；非玩法 Model 可排除在哈希外；要求双方启用完全相同的玩法模组。

架构推断（中可信）：种子化多流 RNG + 序列化哈希 + 分歧检测，指向**各端跑同一确定性模拟、同步动作序列**的模型，而不是"服务器算结果、客户端只看动画"。但官方未公开传输层、权威模型、是否 lockstep，这些保持"未知"。

对模组开放的多人安全路径：
- `ActionQueueSynchronizer.RequestEnqueue(...)`——所有玩法变更进同一条有全序的队列。
- `ICustomMessage` / `PacketWriter` / `PacketReader`，默认可靠传输；官方只在跑局开始阶段启用缓冲，玩法消息应设 `ShouldBuffer = true`；不可靠传输仅限悬停提示这类纯视觉信息。
- Run-saved data：模组数据**内嵌进跑局快照**，随存档读写和多人重连一起流转（`RunSavedData<T>` / 按玩家的 `PlayerRunSavedData<T>` / `SyncLobbyOnChange`）。

---

## 5. RNG 与种子（官方确认，高可信）

- 每局有 12 位字母数字 run seed。
- 一局使用**多条 PRNG 流**，分别影响抽牌、战斗奖励、事件等系统；各流种子由主 seed 派生。
- 0.107.1 起换用 `xoshiro256**`；同 seed 同序列。

---

## 6. 存档体系（官方确认，高可信）

- 文件级概念：`current_run.save`、`settings.save`、跑局历史；多人存档独立；模组化与无模组存档目录分离（首次启用模组时拷贝一份无模组存档作基线，之后有意分叉）。
- 存档写入做了容错：被杀毒/云同步占用时重试，防崩溃、断电与损坏。
- 未公开：`.save` 的具体序列化格式。
- 模组数据分层：Global（账号设置）/ Profile（解锁进度）/ Run（跑局内嵌）/ InMemory（进程内），发布后 key 与文件名保持稳定，破坏性变更前先写迁移。

---

## 7. 模组体系（官方工具 + 社区框架，高可信）

```text
MyMod/
├── mod_manifest.json   id / version / min_game_version / has_pck / has_dll / dependencies / affects_gameplay
├── MyMod.dll           C# 程序集；入口类打 [ModInitializer(nameof(Initialize))]
└── MyMod.pck           Godot 资源包（场景/贴图/音频/本地化 JSON），按 res://MyMod/... 打包
```

- 官方上传器：`ModUploader.exe upload -w <workspace>`，走 Steam Workshop；可声明依赖、玩法影响、分支兼容。
- 模组可直接引用 `sts2.dll` 的公开类型；官方 API 不足时用 Harmony 补丁（BaseLib 甚至用 Publicizer 暴露私有成员——这是最脆弱的依赖层级）。
- 兼容层级（社区总结）：公开 Model 覆写 < 命名公开方法的 Harmony 补丁 < 私有字段/异步状态机/IL 转译。
- 官方明确：初代模组不能直接移植（"very different engine and mildly different architecture"），但新模组更容易写。

---

## 8. 官方未公开 / 未知（不要臆测）

- 网络传输协议与权威模型细节（只有 Steam 集成痕迹）。
- `.save` 序列化格式。
- 确定性回放/录像系统（Run History 只记结果与选择，未见动作流重建；"Replay" 同时是一张卡的名字，勿混淆）。
- MegaDot fork 的具体改动内容。
- 是否存在专用服务器。

---

## 9. 证据分级与来源

| 级别 | 内容 | 来源 |
|------|------|------|
| A 官方 | 用 Godot、C# 内容层结论、4 人 Steam 好友合作、Steam Workshop、多流种子 RNG、状态分歧检测、ModelId 哈希、存档文件概念 | https://www.megacrit.com/faq/ ；https://godotengine.org/showcase/slay-the-spire-2/ ；Steam 补丁说明 https://store.steampowered.com/news/app/2868840/ ；官方上传器 https://github.com/megacrit/sts2-mod-uploader |
| B 官方转述 | MegaDot fork、ScriptableObject→C# 迁移、"a huge amount 代码跨引擎复用" | 2026-02 Mega Crit Reddit AMA（经转述，未能直接抓取原帖，标注中高可信）；Casey Yano《On Evaluating Godot》 https://caseyyano.com/on-evaluating-godot-b35ea86e8cf4 （站点反爬，经 FAQ 链接佐证） |
| C 社区源码可观察 | 命名空间地图、ActionQueueSynchronizer、PlayerCmd/ModelDb/N 节点、模组清单与初始化、PacketWriter 消息层、存档 scope API | https://github.com/Gennadiyev/STS2MCP ；https://github.com/Alchyr/BaseLib-StS2 ；https://github.com/Alchyr/ModTemplate-StS2 ；https://github.com/BAKAOLC/STS2-RitsuLib （docs/pages/guide/*） |
| D 反编译可观察 | `sts2.dll` 约 3300 个 C# 文件、卡牌构造签名、怪物 `GenerateMoveStateMachine()`、`PowerCmd.Apply<T>`、SmartFormat 本地化模板、Spine 骨骼动画 | https://github.com/ptrlrd/spire-codex （README 公开其管线）；https://github.com/adoubt/sts2_source_code （镜像本体） |

注意：`MegaCrit.Sts2.*` 命名空间来自随游戏分发的程序集，不是官方发布的 API 文档；Early Access 期间接口频繁变动（社区已观察到卡牌 `OnPlay(PlayerChoiceContext, CardPlay)` → `Use(ICombatContext, ...)` 的签名漂移）。

---

## 10. 对项目 aaa 的启示

### 直接印证我们已有的设计（可放心推进）

| 杀戮尖塔 2 做法 | aaa 对应 |
|-----------------|----------|
| 逻辑在纯 C# Model，Godot 节点只做表现 | 我们的 `BattleSimulation`（无 Node/Tween/输入）+ `BattlePresenter` 计划 |
| 所有玩法变更经 `ActionQueueSynchronizer` 全序队列 | 我们的 `CommandRequest → AcceptedCommand → step(accepted_commands)` |
| 稳定 Model ID + ModelIdSerializationCache 兼容哈希、内容按 ID 排序 | 我们的 `content_hash`、稳定 `card_definition_id` |
| 多条种子化 PRNG 流（xoshiro256**） | 我们的 `DeterministicRng` 命名流（DECK_SHUFFLE / AI / EFFECT / REWARD） |
| 状态分歧检测 + 要求同版本内容 | 我们的 `simulation_version` + `content_hash` 协商 |
| 存档分 Global/Profile/Run 层 | 我们的 save_service 分层 |
| 模组清单含 `affects_gameplay`、`min_game_version` | 若将来做模组/内容包，直接照抄此清单字段 |

### 值得新学的三课

1. **动作队列是多人唯一的正确入口**。STS2MCP 证明连外部 AI 操作游戏都走 `RequestEnqueue(new PlayCardAction(...))`，而不是改状态。aaa 的输入层、PvE 敌人 AI、未来远程对手都必须产出同一种命令对象。
2. **内容即代码胜过资源文件**（对 conditional 逻辑而言）。aaa 的 GDD 原计划 `CardResource (.tres)`；STS2 的教训是效果逻辑一复杂，资源文件就难调试，他们宁可自动迁移到代码类。aaa 可以折中：数值/文本用资源，效果逻辑用代码类编译进目录（catalog）。
3. **兼容性哈希只含玩法字段**。非玩法 Model 可排除、内容按 ModelId 排序而非类型名——这些细节直接决定未来联机时"双方内容是否真的相同"能被机器判定。

### 不可照搬

- C#/.NET 9 + 自建引擎 fork 的工具链成本（3 人团队多年投入）。
- Steam 好友邀请、无服务器的合作向联机：STS2 是 PvE 合作，各端跑同一模拟即可；aaa 若做**竞技 PvP**，仍需权威服务器，反作弊要求更高。
- 任何反编译代码与提取资产。

### 修订 aaa 记录

- GDD §2.3 的"效果系统用指令模式"与 STS2 的动作队列模型一致，维持；"每张卡 = CardResource (.tres)"建议改为"数值资源 + 效果代码类"。
- 我们的 PvP 分层计划（Simulation / Session / Transport）与 STS2 的 Models / Actions / Multiplayer.Transport 分界同构，方向得到验证。
