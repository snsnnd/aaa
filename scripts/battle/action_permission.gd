class_name ActionPermission
extends RefCounted

## 动作权限统一判定层：出牌 / 防反 / 召符 / Buffer / 受击中断 的规则都从这里走，
## 避免权限判断散落在模拟器各函数里。所有返回 {ok: bool, reason: String}。

## 注意：不 preload battle_simulation（循环依赖）；常量与枚举经传入的 sim 实例访问。

# —— 受击中断策略（设计：明确霸体规则） ——
const HIT_NORMAL := "NORMAL"                    # 被击中即中断，未命中的动作不再结算
const HIT_ARMOR := "ARMOR"                      # 霸体：动作继续，伤害照吃
const HIT_UNINTERRUPTIBLE := "UNINTERRUPTIBLE"  # 完全不可中断（预留）
# —— 防反取消策略（设计：明确防反能否打断自己动作） ——
const PARRY_NONE := "NONE"   # 大承诺动作：出招期间防反不打断自己
const PARRY_LATE := "LATE"   # 只能按正常取消窗口衔接
const PARRY_ANY := "ANY"     # 随时可弃招转防反


## 是否可以打出这张卡（不含费用判断——费用在起手时扣）。
static func can_play_card(sim, id: String) -> Dictionary:
	if sim.state == sim.BattleState.VICTORY or sim.state == sim.BattleState.DEFEAT:
		return {"ok": false, "reason": "ended"}
	if not sim.scry_options.is_empty():
		return {"ok": false, "reason": "scrying"}
	if not sim.hand.has(id):
		return {"ok": false, "reason": "not_in_hand"}
	return {"ok": true, "reason": ""}


## 卡牌如何进入动作流：立即起手 / 取消衔接 / 预输入缓冲。
static func entry_route(sim) -> String:
	if sim.p_phase == sim.PlayerActionPhase.IDLE:
		return "start"
	if sim._in_cancel_window():
		return "cancel"
	return "buffer"


## 是否可以防范（不含时机窗口判断——那是成功/完美分级的事）。
static func can_defend(sim) -> Dictionary:
	if sim.state != sim.BattleState.WINDUP:
		return {"ok": false, "reason": "not_windup"}
	if sim.queued_defense != sim.DefenseGrade.NONE:
		return {"ok": false, "reason": "already_queued"}
	if sim.defense_cooldown > 0.0:
		return {"ok": false, "reason": "cooldown"}
	return {"ok": true, "reason": ""}


## 是否可以召符。
## 并发规则：召符是即时资源动作，仅允许在 IDLE 或取消窗口内执行
## （前摇/收招中召符会抽走缓冲牌已锁定的费用，禁止）。
static func can_summon(sim) -> Dictionary:
	if sim.state == sim.BattleState.VICTORY or sim.state == sim.BattleState.DEFEAT:
		return {"ok": false, "reason": "ended"}
	if sim.hand.size() >= sim.HAND_SIZE:
		return {"ok": false, "reason": "hand_full"}
	if not sim.scry_options.is_empty():
		return {"ok": false, "reason": "scrying"}
	if sim.p_phase != sim.PlayerActionPhase.IDLE and not cancel_window_open(sim):
		return {"ok": false, "reason": "busy"}
	var scost: int = sim.SUMMON_COST - (1 if sim.perfect_charge else 0)
	if sim.points < scost:
		return {"ok": false, "reason": "points"}
	if sim.draw_pile.is_empty() and sim.discard_pile.is_empty():
		return {"ok": false, "reason": "empty"}
	return {"ok": true, "reason": ""}


## 当前动作的受击中断策略。
static func hit_policy(action_def: Dictionary) -> String:
	var explicit := String(action_def.get("on_hit", ""))
	if explicit != "":
		return explicit
	return HIT_NORMAL


## 当前动作的防反取消策略。
static func parry_cancel_policy(action_def: Dictionary) -> String:
	var explicit := String(action_def.get("parry_cancel", ""))
	if explicit != "":
		return explicit
	var tags: Array = action_def.get("combo_tags", [])
	if tags.has("finisher"):
		return PARRY_NONE  # 大承诺动作不可弃招
	if String(action_def.get("type", "")) == "RULE":
		return PARRY_ANY    # 规则/符术随时可弃
	return PARRY_LATE


## 是否真的存在可取消的窗口（cancel_window == 0 的动作永远没有取消窗口）。
static func cancel_window_open(sim) -> bool:
	if sim.p_phase != sim.PlayerActionPhase.CANCEL:
		return false
	if float(sim.p_action.get("cancel_window", 0.0)) <= 0.0:
		return false
	return sim._in_cancel_window()
