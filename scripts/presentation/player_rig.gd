class_name PlayerRig
extends RefCounted

## 玩家姿态通道 → 节点变换 的适配层。
## 姿态语言（PlayerPoseLibrary 的语义通道）与本类解耦：
##   - 当前实现：3 节点切片（pivot / body sprite / lantern_pivot）
##   - 未来实现：5 层切片（+ sword_pivot / lantern_arm_pivot）或 Skeleton2D 骨骼
## 换资产形态时只需替换本类（或新增 PlayerRigSkeleton），控制器与姿态库不动。
##
## 通道：rx/ry 根位移，rr 根倾角，br 身体倾角，sx/sy 身体挤压拉伸，
##       ln 灯笼摆角，sa 刀臂摆角（预留，5 层资产接入后生效）。

const BASE_SCALE := 0.49
const ANCHOR := Vector2(264.0, 355.0)  # 根锚点（世界坐标）

var player_pivot: Node2D
var player_sprite: Sprite2D
var lantern_pivot: Node2D
var sword_pivot: Node2D = null  # 预留


func bind(pivot: Node2D, sprite: Sprite2D, lantern: Node2D, sword: Node2D = null) -> void:
	player_pivot = pivot
	player_sprite = sprite
	lantern_pivot = lantern
	sword_pivot = sword


## 应用动作姿态通道。ctx 由调用方（player_anim）传入本帧的战斗姿态基值：
##   pose_x / pose_rot（戒备姿态）、impulse_x / impulse_rot（受击冲量）、breath_y（呼吸）。
func apply(channels: Dictionary, weight: float, ctx: Dictionary) -> void:
	if player_pivot == null:
		return
	var w := clampf(weight, 0.0, 1.0)
	var rx := float(channels.get("rx", 0.0)) * w
	var ry := float(channels.get("ry", 0.0)) * w
	var rr := float(channels.get("rr", 0.0)) * w
	var br := float(channels.get("br", 0.0)) * w
	var sx := lerpf(1.0, float(channels.get("sx", 1.0)), w)
	var sy := lerpf(1.0, float(channels.get("sy", 1.0)), w)
	var breath_y := float(ctx.get("breath_y", 0.0))
	var pose_x := float(ctx.get("pose_x", 0.0))
	var pose_rot := float(ctx.get("pose_rot", 0.0))
	var impulse_x := float(ctx.get("impulse_x", 0.0))
	var impulse_rot := float(ctx.get("impulse_rot", 0.0))
	player_pivot.position = ANCHOR + Vector2(pose_x + impulse_x + rx, breath_y + ry)
	player_pivot.rotation = pose_rot + impulse_rot + rr
	if player_sprite:
		player_sprite.scale = Vector2(BASE_SCALE, BASE_SCALE) * Vector2(sx, sy)
	# 刀臂通道：5 层切片资产接入后生效（当前 rig 无刀臂节点时静默跳过）
	if sword_pivot:
		sword_pivot.rotation += float(channels.get("sa", 0.0)) * w
