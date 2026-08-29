extends RefCounted

## 玩家动作控制器：消费 action_started 的完整时间轴
## （startup / impact_time / recovery / movement / transition），
## 生成与时间轴同步的动作示意——前摇蓄、命中冲、收招回。
## 全部运动经 MotionChannel 播放：新动作接管旧 Tween，连招加速不抖动。

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


## 动作被取消（受击/防反）：立即接管运动通道并落到对应姿态。
## reason: "hit" → 受击踉跄；"parry" → 转戒备；"card_cancel"（新卡衔接）→ 不处理，由新动作接管。
func on_action_canceled(reason: String) -> void:
	if view == null:
		return
	view.motion.stop("player_pivot")
	var pivot: Node2D = view.player_anim.player_pivot
	var origin: Vector2 = pivot.position
	match reason:
		"hit":
			# 受击踉跄：后坠下沉再回位
			view.motion.play("player_pivot", func(host: Node) -> Tween:
				var tw := host.create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
				tw.tween_property(pivot, "position", origin + Vector2(26, 14), 0.09)
				tw.tween_property(pivot, "position", origin, 0.30).set_ease(Tween.EASE_IN_OUT)
				return tw)
		"parry":
			# 转戒备：小步回到防御位
			view.motion.play("player_pivot", func(host: Node) -> Tween:
				var tw := host.create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
				tw.tween_property(pivot, "position", origin + Vector2(-6, 0), 0.10)
				tw.tween_property(pivot, "position", origin, 0.20)
				return tw)
		_:
			pass  # card_cancel：新动作已通过 MotionChannel 接管


## 按动作时间轴分段驱动：前摇向后蓄 → 命中冲到位移点（与 impact_time 同步）→ 收招缓回。
func _timeline_swing(thrust: Vector2, startup: float, impact_time: float, recovery: float) -> void:
	var pivot: Node2D = view.player_anim.player_pivot
	var origin: Vector2 = pivot.position
	var windup := Vector2(thrust.x * 0.35 + 14.0, thrust.y * 0.35)
	view.motion.play("player_pivot", func(host: Node) -> Tween:
		var tw := host.create_tween()
		tw.tween_property(pivot, "position", origin + windup, maxf(0.01, startup))
		tw.tween_property(pivot, "position", origin + thrust, maxf(0.01, impact_time - startup)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		# 收招段长 = recovery - impact_time：三段总时长与模拟层 recovery 严格一致
		tw.tween_property(pivot, "position", origin, maxf(0.01, recovery - impact_time)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		return tw)


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
	view.motion.play("player_flash", func(host: Node) -> Tween:
		sprite.modulate = flash
		var tw := host.create_tween()
		tw.tween_property(sprite, "modulate", Color.WHITE, 0.28)
		return tw)
	if tier >= 2:
		view.pulse_glow(0.25 + 0.2 * tier)


## 大幅换位（heavy_swap）：沉重感——身体下沉。
func _heavy_sag() -> void:
	var pivot: Node2D = view.player_anim.player_pivot
	var origin: Vector2 = pivot.position
	view.motion.play("player_pivot", func(host: Node) -> Tween:
		var tw := host.create_tween()
		tw.tween_property(pivot, "position", origin + Vector2(0, 10), 0.08)
		tw.tween_property(pivot, "position", origin, 0.24)
		return tw)
