extends RefCounted

## 敌人受击分级控制器：只消费事件（enemy_reaction / action_impact），
## 把 LIGHT/MEDIUM/HEAVY/STAGGER/BREAK/INTERRUPT/FINISHER 映射到既有表现。
## 卡牌只声明 impact_level，不控制敌人具体动画（架构原则三）。

const BattleViewScript := preload("res://scripts/presentation/battle_view.gd")

var view: BattleViewScript


func setup(v: BattleViewScript) -> void:
	view = v


func react(level: String, vfx_tier: int) -> void:
	if view == null:
		return
	match level:
		"LIGHT":
			view.small_enemy_hit(0.06 + 0.03 * vfx_tier)
		"MEDIUM":
			view.small_enemy_hit(0.14 + 0.04 * vfx_tier)
			view.add_trauma(0.08 + 0.04 * vfx_tier)
		"HEAVY":
			view.small_enemy_hit(0.30)
			view.add_trauma(0.22 + 0.06 * vfx_tier)
			view.set_glow(0.4 + 0.2 * vfx_tier)
		"BREAK":
			view.enemy_staggered_fx()
			view.add_trauma(0.42)
			view.rage_flare(view.enemy_sprite.position)
		"FINISHER":
			view.enemy_staggered_fx()
			view.add_trauma(0.62)
			view.rage_flare(view.enemy_sprite.position)
			view.set_glow(1.0)
		"STAGGER":
			view.enemy_staggered_fx()
			view.add_trauma(0.10)
		"INTERRUPT":
			view.snap_ghost_hand_back()
			view.add_trauma(0.24)
		_:
			view.small_enemy_hit(0.10)
