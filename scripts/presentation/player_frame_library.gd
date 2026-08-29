class_name PlayerFrameLibrary
extends RefCounted

## 替换帧/逐帧序列库（特殊动作：Perfect Contact / Finisher / 处决 / 卡牌高潮）。
## schema：action_id → {frames: [{t: 相对命中帧的偏移秒, tex: 路径}], base: 命中帧序号}
## 约定：
##   - 帧序列只替换"身体贴图"（player_sprite.texture），根位移/灯笼仍由控制器程序驱动；
##   - t 以命中帧（impact_time）为 0：负值在命中前，正值在命中后；
##   - 序列不必覆盖全时间轴：未覆盖区间自动回落到程序姿态轨道的对应身体通道。

## 逐帧资产就绪后在此登记。当前为空：FRAMES 类动作自动回落 TRACK 兜底。
const SEQUENCES := {
	# 示例（登记时照此格式）：
	# "act_shatter": {
	#     "frames": [
	#         {"t": -0.10, "tex": "res://assets/game/frames/shatter_windup.png"},
	#         {"t": 0.00,  "tex": "res://assets/game/frames/shatter_impact.png"},
	#         {"t": 0.08,  "tex": "res://assets/game/frames/shatter_follow.png"},
	#     ],
	# },
}


static func sequence_for(action_id: String) -> Dictionary:
	return SEQUENCES.get(action_id, {})


## 求值：给定动作时间轴上的局部时间与命中时刻，返回当前应显示的贴图路径（"" 表示回落）。
static func texture_at(seq: Dictionary, local_t: float, impact_time: float) -> String:
	var frames: Array = seq.get("frames", [])
	if frames.is_empty():
		return ""
	var best := ""
	var best_dist := INF
	for f: Dictionary in frames:
		var frame_t := impact_time + float(f.get("t", 0.0))
		var dist: float = absf(local_t - frame_t)
		if dist < best_dist:
			best_dist = dist
			best = String(f.get("tex", ""))
	return best
