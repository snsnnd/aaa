extends RefCounted

## 敌人受击分级控制器：消费 enemy_reaction 事件，
## 七级反应各有真实动作差异（轻顿/后退/大仰/破势/失衡/终结/截停），
## 全部运动经 MotionChannel 播放，连招加速时新反应接管旧 Tween 不抖动。
## 反馈强度表（hitstop/震屏/SFX）统一在 feedback_tiers.gd，按重要性分层。

const BattleViewScript := preload("res://scripts/presentation/battle_view.gd")
const FeedbackTiers := preload("res://scripts/presentation/feedback_tiers.gd")

var view: BattleViewScript


func setup(v: BattleViewScript) -> void:
	view = v


func react(level: String, vfx_tier: int) -> void:
	if view == null:
		return
	var tier: Dictionary = FeedbackTiers.tier(level)
	# 分层 hitstop：只给 HEAVY 以上（game-feel: 最重要的时刻才停时间）
	var hs: float = float(tier["hitstop"])
	if hs > 0.0:
		GameTime.hitstop(hs, float(tier["hitstop_scale"]))
	# 分层 SFX（音量随层级，音调微移在 play_sfx 内）
	view.play_sfx(String(tier["sfx"]), float(tier["sfx_db"]))
	view.add_trauma(float(tier["trauma"]))
	match level:
		"LIGHT":
			_flash(Color("fff3d0"), 0.12)
			_nudge(Vector2(-8, 0), 0.08)
		"MEDIUM":
			_flash(Color("ffe0a0"), 0.16)
			_nudge(Vector2(-26, 0), 0.12)
		"HEAVY":
			_flash(Color("ffc880"), 0.20)
			_nudge(Vector2(-52, 6), 0.16)
			_weapon_drop(0.35)
			view.set_glow(0.4 + 0.2 * vfx_tier)
		"BREAK":
			view.enemy_staggered_fx()
			_nudge(Vector2(-84, 10), 0.20)
			_weapon_drop(0.6)
			view.rage_flare(view.enemy_sprite.position)
		"FINISHER":
			_dissolve_tint()
			_nudge(Vector2(-110, 14), 0.24)
			view.rage_flare(view.enemy_sprite.position)
			view.set_glow(1.0)
		"STAGGER":
			view.enemy_staggered_fx()
		"INTERRUPT":
			view.snap_ghost_hand_back()
			_flash(Color("cfeef0"), 0.18)
		_:
			_flash(Color("fff3d0"), 0.12)


## 位移示意：向后退 then 回位（经 MotionChannel，新反应接管旧位移）。
func _nudge(offset: Vector2, duration: float) -> void:
	var sprite: Sprite2D = view.enemy_sprite
	var origin := sprite.position
	var target := origin + offset
	view.motion.play("enemy_pos", func(host: Node) -> Tween:
		var tw := host.create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(sprite, "position", target, duration)
		tw.tween_property(sprite, "position", origin, duration * 1.6).set_ease(Tween.EASE_IN_OUT)
		return tw)


func _flash(color: Color, duration: float) -> void:
	var sprite: Sprite2D = view.enemy_sprite
	view.motion.play("enemy_flash", func(host: Node) -> Tween:
		sprite.modulate = color
		var tw := host.create_tween()
		tw.tween_property(sprite, "modulate", Color.WHITE, duration + 0.1)
		return tw)


## 终结失衡：消散色渐回。
func _dissolve_tint() -> void:
	var sprite: Sprite2D = view.enemy_sprite
	view.motion.play("enemy_flash", func(host: Node) -> Tween:
		sprite.modulate = Color("cfeef0")
		var tw := host.create_tween()
		tw.tween_property(sprite, "modulate", Color.WHITE, 0.6)
		return tw)


## 武器下沉：重击/破势时武器臂无力下垂再抬起。
func _weapon_drop(amount: float) -> void:
	var weapon: Node2D = view.weapon_pivot
	if weapon == null or not weapon.visible:
		return
	var origin_rot: float = weapon.rotation
	view.motion.play("enemy_weapon", func(host: Node) -> Tween:
		var tw := host.create_tween()
		tw.tween_property(weapon, "rotation", origin_rot + amount, 0.12)
		tw.tween_property(weapon, "rotation", origin_rot, 0.30)
		return tw)
