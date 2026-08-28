extends RefCounted

## 敌人受击分级控制器：消费 enemy_reaction 事件，
## 七级反应各有真实动作差异（轻顿/后退/大仰/破势/失衡/终结/截停），
## 不再是"连打四张牌敌人只闪四下"。卡牌只声明 impact_level。

const BattleViewScript := preload("res://scripts/presentation/battle_view.gd")

var view: BattleViewScript


func setup(v: BattleViewScript) -> void:
	view = v


func react(level: String, vfx_tier: int) -> void:
	if view == null:
		return
	match level:
		"LIGHT":
			# 轻顿：白色闪一下，身体微颤
			_flash(Color("fff3d0"), 0.12)
			_nudge(Vector2(-8, 0), 0.08)
		"MEDIUM":
			# 后退：明显后仰位移
			_flash(Color("ffe0a0"), 0.16)
			_nudge(Vector2(-26, 0), 0.12)
			view.add_trauma(0.08 + 0.03 * vfx_tier)
		"HEAVY":
			# 大仰：大幅后退 + 武器下沉
			_flash(Color("ffc880"), 0.20)
			_nudge(Vector2(-52, 6), 0.16)
			_weapon_drop(0.35)
			view.add_trauma(0.20 + 0.05 * vfx_tier)
		"BREAK":
			# 破势：僵直 + 大位移 + 红光
			view.enemy_staggered_fx()
			_nudge(Vector2(-84, 10), 0.20)
			_weapon_drop(0.6)
			view.add_trauma(0.40)
			view.rage_flare(view.enemy_sprite.position)
		"FINISHER":
			# 失衡/终结：僵直 + 消散色 + 大震
			view.enemy_staggered_fx()
			view.enemy_sprite.modulate = Color("cfeef0")
			view.player_anim.create_tween().tween_property(view.enemy_sprite, "modulate", Color.WHITE, 0.6)
			_nudge(Vector2(-110, 14), 0.24)
			view.add_trauma(0.62)
			view.rage_flare(view.enemy_sprite.position)
			view.set_glow(1.0)
		"STAGGER":
			# 凝滞：时间冻结感——只有闪光与 aura，无位移
			view.enemy_staggered_fx()
			view.add_trauma(0.08)
		"INTERRUPT":
			# 截停：鬼手缩回 + 硬直
			view.snap_ghost_hand_back()
			_flash(Color("cfeef0"), 0.18)
			view.add_trauma(0.22)
		_:
			view.small_enemy_hit(0.10)


## 位移示意：向后退 then 回位（与 enemy_anim.tick 的 settle 有轻微竞争，潦草版可接受）。
func _nudge(offset: Vector2, duration: float) -> void:
	var sprite: Sprite2D = view.enemy_sprite
	var origin_x := sprite.position.x
	var tw := view.player_anim.create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(sprite, "position:x", origin_x + offset.x, duration)
	tw.tween_property(sprite, "position:x", origin_x, duration * 1.6).set_ease(Tween.EASE_IN_OUT)
	if offset.y != 0.0:
		var origin_y := sprite.position.y
		var tw2 := view.player_anim.create_tween()
		tw2.tween_property(sprite, "position:y", origin_y + offset.y, duration)
		tw2.tween_property(sprite, "position:y", origin_y, duration * 1.6)


func _flash(color: Color, duration: float) -> void:
	var sprite: Sprite2D = view.enemy_sprite
	sprite.modulate = color
	view.player_anim.create_tween().tween_property(sprite, "modulate", Color.WHITE, duration + 0.1)


## 武器下沉：重击/破势时武器臂无力下垂再抬起。
func _weapon_drop(amount: float) -> void:
	var weapon: Node2D = view.weapon_pivot
	if weapon == null or not weapon.visible:
		return
	var origin_rot: float = weapon.rotation
	var tw := view.player_anim.create_tween()
	tw.tween_property(weapon, "rotation", origin_rot + amount, 0.12)
	tw.tween_property(weapon, "rotation", origin_rot, 0.30)
