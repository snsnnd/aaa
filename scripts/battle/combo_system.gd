class_name ComboSystem
extends RefCounted

## 动作语法系统：根据"上一动作收势 + 下一动作起手 + 连势"计算衔接质量。
## 不写 A+B=C 死组合——50/100 张卡也不会组合爆炸。
## 输出 ComboResult：transition_type / combo_delta / recovery_mul / vfx_tier / finisher_available。
##
## 连招奖励不是伤害倍率（设计第 7 点）：
##   SEAMLESS → 连势+1、敌人受击层级随连势升级、表现层转场加速
##   连招等级≥3 且卡带 finisher 标签 → 开放终结动作（FINISHER 受击层级）
##   recovery_mul 只影响表现层转场速度，不改战斗数值。

const SEAMLESS := "seamless"    # 顺势衔接：连势+1
const GLUED := "glued"          # 生硬衔接：可连，但不涨连势
const HEAVY_SWAP := "heavy_swap"  # 大幅换位：收势拖长
const ComboWindow := 2.6
const FINISHER_LEVEL := 3   # 终结动作开放的连招等级

## 顺势表：收势姿态 → 可无缝接的起手姿态。
## same=同姿态、swing=左右对摆、parry=弹反起手可接任意攻击、spell=符术续接。
const SEAMLESS_MAP := {
	"parry_exit": ["high", "low", "left", "right", "thrust", "guard", "spell"],
	"high": ["high", "low", "right"],
	"low": ["low", "high", "left", "thrust"],
	"left": ["left", "right", "spell"],
	"right": ["right", "left", "spell", "thrust"],
	"thrust": ["thrust", "left", "high"],
	"spell": ["spell", "neutral"],
	"guard": ["guard", "neutral", "spell"],
	"neutral": ["neutral", "spell"],
}

const SWING_PAIRS := [["left", "right"], ["right", "left"], ["low", "high"], ["high", "low"]]


func resolve(state: ActionState, next_action: Dictionary, chain_open: bool, finisher_combo_level: int) -> Dictionary:
	var result := {
		"transition": GLUED,
		"combo_delta": 0,
		"recovery_mul": 1.0,
		"vfx_tier": 0,
		"finisher_available": false,
		"combo_level": state.combo_level,
		"opener": false,
	}
	var entry: String = String(next_action.get("entry_pose", "neutral"))
	var tags: Array = next_action.get("combo_tags", [])

	if not chain_open:
		# 新起手：连招等级重置为 1。
		# 起手不只有防反：突进/截招/拖拍等带 opener 标签的动作本身就是好起手（连势+1）；
		# 防反仍是最强起手（免费、等级+1/+2），但不是唯一入口。
		result["combo_level"] = 1
		result["transition"] = "open"
		result["opener"] = tags.has("opener")
		result["vfx_tier"] = _tier(state.momentum, 1)
		result["finisher_available"] = false
		return result

	# 衔接解析
	var seamless_pool: Array = SEAMLESS_MAP.get(state.current_pose, [])
	if seamless_pool.has(entry):
		result["transition"] = SEAMLESS
		result["combo_delta"] = 1
		result["recovery_mul"] = 0.85
		result["vfx_tier"] = _tier(state.momentum, state.combo_level + 1)
	elif _is_swing(state.current_pose, entry):
		result["transition"] = SEAMLESS
		result["combo_delta"] = 1
		result["recovery_mul"] = 0.9
		result["vfx_tier"] = _tier(state.momentum, state.combo_level + 1)
	elif state.current_pose == "parry_exit":
		# 弹反起手兜底：任何动作都能接，但只有攻击类是顺势
		result["transition"] = GLUED
		result["recovery_mul"] = 0.95
		result["vfx_tier"] = _tier(state.momentum, state.combo_level + 1)
	else:
		result["transition"] = HEAVY_SWAP
		result["combo_delta"] = 0
		result["recovery_mul"] = 1.3
		result["vfx_tier"] = _tier(state.momentum, state.combo_level)

	result["combo_level"] = mini(5, state.combo_level + result["combo_delta"])
	result["finisher_available"] = result["combo_level"] >= FINISHER_LEVEL and tags.has("finisher")
	return result


## 连招等级对敌人受击层级的升级（设计第 7/10 点：敌人受击强度随连势提升）。
func pick_impact_level(base_level: String, combo_level: int, momentum: int, is_finisher_tag: bool) -> String:
	if is_finisher_tag and combo_level >= FINISHER_LEVEL:
		return "FINISHER"
	var ladder: Array = ["LIGHT", "MEDIUM", "HEAVY", "BREAK"]
	var idx: int = ladder.find(base_level)
	if idx < 0:
		return base_level  # STAGGER/INTERRUPT 等特殊层级不参与升级
	var up := 0
	if combo_level >= 3:
		up += 1
	if momentum >= 2:
		up += 1
	if momentum >= 4:
		up += 1
	return String(ladder[mini(ladder.size() - 1, idx + up)])


func _is_swing(from_pose: String, to_pose: String) -> bool:
	for pair in SWING_PAIRS:
		if String(pair[0]) == from_pose and String(pair[1]) == to_pose:
			return true
	return false


func _tier(momentum: int, combo_level: int) -> int:
	return clampi(momentum + (combo_level / 2), 0, 3)
