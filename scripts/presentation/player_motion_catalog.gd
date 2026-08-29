class_name PlayerMotionCatalog
extends RefCounted

## 动作表现后端分类（混合管线）：
##   TRACK    程序姿态轨道（当前兜底；资产未就绪时的默认）
##   SKELETAL 骨骼/切片剪辑（Idle/Parry/Quick Slash/Heavy Slash/Dash/Hurt —— 资产到位后启用）
##   FRAMES   替换帧/逐帧序列（Perfect Contact/Finisher/处决/卡牌高潮）
## 无论哪种后端：根位移(rx/ry)与时间轴永远由 PlayerActionController 程序驱动。

const TRACK := "track"
const SKELETAL := "skeletal"
const FRAMES := "frames"

## 按动作声明的表现后端。未列出的动作默认 TRACK。
## 骨骼资产就绪后：把常规动作逐个改为 SKELETAL。
## 逐帧资产就绪后：把特殊动作逐个改为 FRAMES 并在 PlayerFrameLibrary 登记。
const KINDS := {
	# —— 特殊动作：替换帧/逐帧（资产就绪即启用） ——
	"act_tianping": FRAMES,       # 极·天平倒悬（终结）
	"act_shatter": FRAMES,        # 还刃·重斩（乘势高潮）
	"act_shoulian": FRAMES,       # 收殓（终结向）
	"act_yuangui": FRAMES,        # 怨归（终结向）
	# —— 常规动作：骨骼/切片（骨骼资产就绪即启用；此前继续用 TRACK 兜底） ——
	"attack": SKELETAL, "zhuying": SKELETAL, "liebo": SKELETAL, "zhuangzhong": SKELETAL,
	"duannian": SKELETAL, "xuezhang": SKELETAL,
	"guard": SKELETAL, "difan": SKELETAL, "jiedao": SKELETAL, "jieshi": SKELETAL,
	"shift": SKELETAL, "dengxin": SKELETAL, "anhun": SKELETAL,
}


static func kind_for(action_id: String) -> String:
	return String(KINDS.get(action_id, TRACK))
