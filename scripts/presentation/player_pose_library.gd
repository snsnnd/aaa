class_name PlayerPoseLibrary
extends RefCounted

## 玩家姿态语言：命名姿态 + 动作关键帧轨道。
## 通道（channels）：rx/ry = 根位移偏移（+x 朝向敌人）、rr = 根倾角、
##                   br = 身体倾角、sx/sy = 身体挤压拉伸、ln = 灯笼摆角（弧度）
## 设计原则（动作优先，特效后置）：
##   蓄力段 EASE_IN（慢蓄）→ 命中段 EASE_OUT_EXPO（骤然释放）→ 收招段 EASE_OUT（缓回）。

const POSES := {
	"idle":         {"rx": 0.0, "ry": 0.0, "rr": 0.0, "br": 0.0, "sx": 1.0, "sy": 1.0, "ln": 0.0},
	"guard":        {"rx": 14.0, "ry": 2.0, "rr": 0.03, "br": -0.03, "sx": 0.98, "sy": 1.02, "ln": 0.05},
	"parry_high":   {"rx": 6.0, "ry": -6.0, "rr": -0.02, "br": -0.08, "sx": 1.04, "sy": 0.96, "ln": -0.26},
	# —— 蓄力（anticipation：下沉/后引/压扁） ——
	"crouch":       {"rx": 10.0, "ry": 9.0, "rr": 0.02, "br": 0.07, "sx": 1.07, "sy": 0.90, "ln": 0.18},
	"raise_high":   {"rx": -8.0, "ry": -15.0, "rr": -0.05, "br": -0.11, "sx": 0.95, "sy": 1.06, "ln": -0.32},
	"pull_left":    {"rx": -12.0, "ry": -4.0, "rr": -0.03, "br": -0.09, "sx": 0.97, "sy": 1.02, "ln": -0.22},
	"pull_right":   {"rx": 12.0, "ry": -4.0, "rr": 0.03, "br": 0.07, "sx": 0.97, "sy": 1.02, "ln": 0.22},
	"cast_up":      {"rx": 6.0, "ry": -14.0, "rr": -0.02, "br": -0.05, "sx": 0.98, "sy": 1.03, "ln": -0.42},
	"leap_wind":    {"rx": -14.0, "ry": -8.0, "rr": -0.03, "br": -0.04, "sx": 0.94, "sy": 1.08, "ln": -0.18},
	# —— 命中（impact：伸展/拉伸/灯笼甩出） ——
	"lunge_ext":    {"rx": 46.0, "ry": -4.0, "rr": 0.04, "br": 0.02, "sx": 1.12, "sy": 0.92, "ln": 0.12},
	"overhead_end": {"rx": 28.0, "ry": 10.0, "rr": 0.06, "br": 0.13, "sx": 1.09, "sy": 0.92, "ln": 0.32},
	"high_end":     {"rx": 22.0, "ry": -10.0, "rr": -0.03, "br": -0.09, "sx": 1.06, "sy": 0.95, "ln": -0.28},
	"left_end":     {"rx": 20.0, "ry": -6.0, "rr": -0.03, "br": -0.11, "sx": 1.05, "sy": 0.95, "ln": -0.24},
	"right_end":    {"rx": 28.0, "ry": 2.0, "rr": 0.04, "br": 0.09, "sx": 1.06, "sy": 0.95, "ln": 0.24},
	"thrust_ext":   {"rx": 54.0, "ry": -2.0, "rr": 0.02, "br": 0.0, "sx": 1.15, "sy": 0.90, "ln": -0.06},
	"cast_fwd":     {"rx": 18.0, "ry": -8.0, "rr": 0.0, "br": -0.02, "sx": 1.0, "sy": 1.0, "ln": -0.38},
	"slam_fwd":     {"rx": 34.0, "ry": 6.0, "rr": 0.05, "br": 0.10, "sx": 1.10, "sy": 0.93, "ln": 0.28},
	"retreat_pose": {"rx": -26.0, "ry": 4.0, "rr": -0.03, "br": 0.05, "sx": 0.97, "sy": 1.0, "ln": 0.26},
	"leap_pose":    {"rx": -12.0, "ry": -28.0, "rr": -0.02, "br": -0.07, "sx": 0.96, "sy": 1.07, "ln": -0.22},
	# —— 收招/受击 ——
	"recover":      {"rx": 4.0, "ry": 2.0, "rr": 0.01, "br": 0.02, "sx": 1.0, "sy": 1.0, "ln": 0.08},
	"hurt":         {"rx": -20.0, "ry": 10.0, "rr": -0.07, "br": 0.11, "sx": 1.06, "sy": 0.88, "ln": 0.38},
}

## 收势语义 → 命中姿态
const STRIKE_BY_EXIT := {
	"right": "right_end", "left": "left_end", "thrust": "thrust_ext",
	"low": "overhead_end", "high": "high_end", "neutral": "slam_fwd", "spell": "cast_fwd", "guard": "slam_fwd",
}
## 起手语义 → 蓄力姿态（与命中反向：左斩右引、下劈上举）
const WINDUP_BY_ENTRY := {
	"high": "crouch", "low": "raise_high", "left": "pull_right", "right": "pull_left",
	"thrust": "crouch", "spell": "cast_up", "guard": "guard", "neutral": "guard",
}
## 位移语义 → 蓄力/命中覆盖
const MOVEMENT_WINDUP := {"dash": "crouch", "lunge": "crouch", "leap": "leap_wind", "retreat": "guard", "step": "", "none": ""}
const MOVEMENT_STRIKE := {"dash": "lunge_ext", "lunge": "lunge_ext", "leap": "overhead_end", "retreat": "retreat_pose", "step": "", "none": ""}

## 签名动作覆盖（大承诺动作的蓄力更长更夸张，交给数据说话）
const OVERRIDES := {
	"act_shatter": {"windup": "raise_high", "strike": "overhead_end", "settle": "recover"},
	"act_tianping": {"windup": "leap_wind", "strike": "overhead_end", "settle": "recover"},
	"act_zhuangzhong": {"windup": "raise_high", "strike": "slam_fwd", "settle": "recover"},
	"act_guard": {"windup": "guard", "strike": "slam_fwd", "settle": "recover"},
	"act_anhun": {"windup": "cast_up", "strike": "guard", "settle": "recover"},
	"act_jiedao": {"windup": "pull_left", "strike": "thrust_ext", "settle": "recover"},
	"act_yandeng": {"windup": "cast_up", "strike": "retreat_pose", "settle": "recover"},
	"act_wenlu": {"windup": "cast_up", "strike": "cast_fwd", "settle": "recover"},
	"act_shift": {"windup": "crouch", "strike": "cast_fwd", "settle": "recover"},
}

## 生成动作轨道：[{t, pose, ease_in}]，t 为绝对时间（与模拟时间轴同源）。
## ease_in 表示"到达该关键帧"这一段使用的缓入曲线名。
static func track_for(action_id: String, action_def: Dictionary) -> Dictionary:
	var startup: float = maxf(0.02, float(action_def.get("startup", 0.1)))
	var impact: float = maxf(startup + 0.02, float(action_def.get("impact_time", 0.2)))
	var recovery: float = maxf(impact + 0.06, float(action_def.get("recovery", 0.3)))
	var movement := String(action_def.get("movement", "none"))
	var windup_name := ""
	var strike_name := ""
	var settle_name := "recover"
	if OVERRIDES.has(action_id):
		var ov: Dictionary = OVERRIDES[action_id]
		windup_name = String(ov["windup"])
		strike_name = String(ov["strike"])
		settle_name = String(ov["settle"])
	else:
		var entry := String(action_def.get("entry_pose", "neutral"))
		var exit_pose := String(action_def.get("exit_pose", "neutral"))
		windup_name = String(MOVEMENT_WINDUP.get(movement, ""))
		if windup_name == "":
			windup_name = String(WINDUP_BY_ENTRY.get(entry, "guard"))
		strike_name = String(MOVEMENT_STRIKE.get(movement, ""))
		if strike_name == "":
			strike_name = String(STRIKE_BY_EXIT.get(exit_pose, "slam_fwd"))
	# 佑/RULE 类动作整体放柔：命中帧不强甩灯笼
	if String(action_def.get("type", "")) == "RULE" and not OVERRIDES.has(action_id):
		windup_name = "crouch" if movement in ["none", "step"] else windup_name
		strike_name = "cast_fwd"
	var keys := [
		{"t": 0.0, "pose": String(POSES.keys()[0]), "ease": "OUT"},
		{"t": startup, "pose": windup_name, "ease": "IN"},          # 蓄力段：慢入
		{"t": impact, "pose": strike_name, "ease": "SNAP"},          # 命中段：骤放
		{"t": recovery, "pose": settle_name, "ease": "OUT"},         # 收招段：缓出
	]
	for k in keys:
		k["pose_data"] = POSES.get(String(k["pose"]), POSES["idle"])
	return {"keys": keys, "total": recovery}


## 特殊轨道：防反起手（命中后余韵）
static func parry_track(perfect: bool) -> Dictionary:
	var hold: float = 0.42 if perfect else 0.30
	var keys := [
		{"t": 0.0, "pose": "parry_high", "ease": "SNAP", "pose_data": POSES["parry_high"]},
		{"t": hold, "pose": "recover", "ease": "OUT", "pose_data": POSES["recover"]},
	]
	return {"keys": keys, "total": hold}


## 特殊轨道：受击踉跄
static func hurt_track() -> Dictionary:
	var keys := [
		{"t": 0.0, "pose": "hurt", "ease": "SNAP", "pose_data": POSES["hurt"]},
		{"t": 0.30, "pose": "recover", "ease": "OUT", "pose_data": POSES["recover"]},
	]
	return {"keys": keys, "total": 0.30}


## 关键帧插值：返回当前通道字典。ease 到达段 = 上一关键帧 → 本帧。
static func evaluate(track: Dictionary, t: float) -> Dictionary:
	var keys: Array = track["keys"]
	var prev: Dictionary = keys[0]
	var pose: Dictionary = prev["pose_data"]
	var u := 0.0
	for i in range(1, keys.size()):
		var k: Dictionary = keys[i]
		if t <= float(k["t"]) or i == keys.size() - 1:
			var span: float = maxf(0.001, float(k["t"]) - float(prev["t"]))
			u = clampf((t - float(prev["t"])) / span, 0.0, 1.0)
			pose = k["pose_data"]
			var ease := String(k.get("ease", "OUT"))
			match ease:
				"IN":
					u = u * u
				"SNAP":
					u = 1.0 - pow(1.0 - u, 3.0)  # ease-out expo：骤然释放
				_:
					u = 1.0 - pow(1.0 - u, 2.0)  # ease-out quad：缓出
			break
		prev = k
	var a: Dictionary = prev["pose_data"]
	var out := {}
	for ch in pose:
		out[ch] = lerpf(float(a.get(ch, 0.0)), float(pose.get(ch, 0.0)), u)
	return out
