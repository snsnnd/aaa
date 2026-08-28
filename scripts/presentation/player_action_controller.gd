extends RefCounted

## 玩家动作控制器（潦草版）：消费 action_started 的完整时间轴
## （startup / impact_time / recovery / movement / transition），
## 生成与时间轴同步的动作示意——前摇蓄、命中冲、收招回。
## 正式姿态过渡动画后续单独优化，这里保证"动了、跟时间轴对齐、有连势感"。

const BattleViewScript := preload("res://scripts/presentation/battle_view.gd")

var view: BattleViewScript


func setup(v: BattleViewScript) -> void:
	view = v


func on_action_started(transition: String, movement: String, vfx_tier: int, startup: float, impact_time: float, recovery: float) -> void:
	if view == null:
		return
	var thrust := _movement_offset(movement)
	_timeline_swing(thrust, startup, impact_time, recovery)
	if transition == "seamless":
		_chain_flash(vfx_tier)
	elif transition == "heavy_swap":
		_heavy_sag()


func on_action_canceled() -> void:
	# 取消衔接：动作被打断接续，给一个轻量的"接上了"脉冲
	_chain_flash(1)


## 按动作时间轴分段驱动：前摇后撤 → 命中前冲（到位时刻=impact_time）→ 收招回位。
func _timeline_swing(thrust: Vector2, startup: float, impact_time: float, recovery: float) -> void:
	var pivot: Node2D = view.player_anim.player_pivot
	var origin: Vector2 = pivot.position
	var windup := Vector2(thrust.x * 0.35 + 14.0, thrust.y * 0.35)
	var tw := view.player_anim.create_tween()
	# 前摇：向后蓄
	tw.tween_property(pivot, "position", origin + windup, maxf(0.01, startup))
	# 命中：冲到位移点（与 impact_time 同步）
	tw.tween_property(pivot, "position", origin + thrust, maxf(0.01, impact_time - startup)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	# 收招：缓回
	tw.tween_property(pivot, "position", origin, maxf(0.01, recovery - (impact_time - startup))).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _movement_offset(movement: String) -> Vector2:
	match movement:
		"dash":
			return Vector2(-64, 0)
		"lunge":
			return Vector2(-40, 0)
		"step":
			return Vector2(-20, 0)
		"retreat":
			return Vector2(28, 0)
		"leap":
			return Vector2(-30, -26)
	return Vector2(-8, 0)


## 连势闪光：转场越顺，身位越亮（VFX 层级随连势抬升）。
func _chain_flash(tier: int) -> void:
	var sprite: Sprite2D = view.player_anim.player_sprite
	var flash := Color(1.0, 0.92, 0.72).lerp(Color(1.0, 0.75, 0.35), clampf(tier / 3.0, 0.0, 1.0))
	sprite.modulate = flash
	view.player_anim.create_tween().tween_property(sprite, "modulate", Color.WHITE, 0.28)
	if tier >= 2:
		view.pulse_glow(0.25 + 0.2 * tier)


## 大幅换位（heavy_swap）：沉重感——身体下沉。
func _heavy_sag() -> void:
	var pivot: Node2D = view.player_anim.player_pivot
	var origin: Vector2 = pivot.position
	var tw := view.player_anim.create_tween()
	tw.tween_property(pivot, "position", origin + Vector2(0, 10), 0.08)
	tw.tween_property(pivot, "position", origin, 0.24)
