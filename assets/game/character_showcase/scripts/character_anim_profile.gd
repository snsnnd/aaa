@tool
class_name CharacterAnimProfile
extends Resource

## 角色动效数据驱动配置表 (Resource)
## 后续新增任意角色无需编写任何脚本代码，只需新建此 Resource 配置参数即可！

enum MotionType {
	HUMAN_GROUND,       # 执灯人/人型：沉稳呼吸、重心起伏、挂件惯性摆动
	FLOAT_SPIRIT,       # 浮空小鬼/幽灵：正弦波漂浮、高频微抖、动态透视阴影
	RIGID_MECHANICAL,   # 僵尸/木偶：步态顿挫、机械节奏、卡点定格
	PAPER_FLUTTER,      # 纸扎/轻量：无骨骼风吹形变、纸片折痕颤动
	MAJESTIC_BOSS,      # Boss/领主：低频庄严悬浮、领域光环呼吸脉冲
	SLITHER_CREEP,      # 爬行/水生（如井中姐弟）：波浪形蠕动
	NERVOUS_JITTER,     # 神经质（如赌鬼）：高频摇摆、剧烈抽搐
}

@export_group("基础标识")
@export var character_id: String = "new_character"
@export var display_name: String = "新角色"
@export_multiline var motion_notes: String = "动效特征说明"

@export_group("核心动效模式")
@export var motion_type: MotionType = MotionType.HUMAN_GROUND

@export_group("呼吸与起伏 (Breathing / Float)")
@export var breath_speed: float = 2.2           # 呼吸/浮空频率
@export var breath_height: float = 3.0          # Y轴上下位移幅度 (px)
@export var squash_stretch: float = 0.015       # 呼吸挤压拉伸形变量
@export var idle_tilt_angle: float = 0.01       # 待机身体轻微倾角 (rad)

@export_group("浮空与神经质抖动 (Float & Jitter)")
@export var jitter_speed: float = 0.0           # 抖动频率 (0 为无抖动)
@export var jitter_amount_x: float = 0.0        # X轴细微抽搐抖动幅度 (px)

@export_group("挂载物物理 (Lantern / Weapon Pendulum)")
@export var prop_sway_freq: float = 2.2         # 挂载物（如灯笼/吊坠）摆动频率
@export var prop_sway_angle: float = 0.06       # 摆动最大角度 (rad)
@export var prop_lag_phase: float = 0.4         # 物理惯性滞后相位 (s)

@export_group("机械顿挫 (Cadence Steps)")
@export var cadence_beats: int = 4              # 步态节拍数 (如4拍巡更)
@export var step_lift_height: float = 6.0       # 提步抬升高度 (px)

@export_group("战斗动作冲量 (Combat Dynamics)")
@export var attack_windup_px: float = 35.0      # 蓄力后撤距离
@export var attack_lunge_px: float = 60.0       # 突刺前冲距离
@export var hit_recoil_px: float = 30.0         # 受击后仰冲量
@export var hit_tilt_rad: float = 0.08          # 受击后仰倾角

@export_group("光环与阴影 (Aura & Shadow)")
@export var shadow_sync: bool = true            # 阴影是否随高度动态缩放/淡出
@export var aura_pulse_speed: float = 2.5       # 光环呼吸速率
@export var aura_scale_range: Vector2 = Vector2(1.0, 1.25)
