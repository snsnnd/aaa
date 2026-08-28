extends RefCounted

## 玩家动作控制器（潦草版）：消费 action_started 事件，把位移类型转成
## 轻量动作表现。防反后不回 Idle——下一张牌直接从 parry_exit 姿态接出去。
## 正式的姿态过渡/动画状态机后续单独优化，这里只保证"动了、方向对、有连势感"。

const BattleViewScript := preload("res://scripts/presentation/battle_view.gd")

var view: BattleViewScript


func setup(v: BattleViewScript) -> void:
	view = v


func on_action_started(transition: String, movement: String, vfx_tier: int) -> void:
	if view == null:
		return
	var offset := Vector2.ZERO
	match movement:
		"dash":
			offset = Vector2(-64, 0)
		"lunge":
			offset = Vector2(-40, 0)
		"step":
			offset = Vector2(-20, 0)
		"retreat":
			offset = Vector2(28, 0)
		"leap":
			offset = Vector2(-30, -26)
		"none":
			if transition == "seamless":
				offset = Vector2(-8, 0)
	if offset != Vector2.ZERO:
		_pose_nudge(offset)
	if transition == "seamless":
		_chain_flash(vfx_tier)


## 姿态示意：向位移方向荡一下再回位（挂 player_pivot，不与 tick 的呼吸摆动冲突）。
func _pose_nudge(offset: Vector2) -> void:
	var pivot: Node2D = view.player_anim.player_pivot
	var origin: Vector2 = pivot.position
	var tw := view.player_anim.create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(pivot, "position", origin + offset, 0.09)
	tw.tween_property(pivot, "position", origin, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)


## 连势闪光：转场越顺，灯笼/身位越亮（VFX 层级随连势抬升）。
func _chain_flash(tier: int) -> void:
	var sprite: Sprite2D = view.player_anim.player_sprite
	var flash := Color(1.0, 0.92, 0.72).lerp(Color(1.0, 0.75, 0.35), clampf(tier / 3.0, 0.0, 1.0))
	sprite.modulate = flash
	view.player_anim.create_tween().tween_property(sprite, "modulate", Color.WHITE, 0.28)
	if tier >= 2:
		view.pulse_glow(0.25 + 0.2 * tier)
