extends SceneTree

## Three-Build Archetype Validation Script (三构筑分化验证)
## 自动化模拟测试：还刃乘势流、镇煞打断流、长明续灯流 三大流派在实战中的差异化统计特征

const BattleSimulationScript := preload("res://scripts/battle/battle_simulation.gd")

const BUILDS := {
	"还刃乘势流 (Shatter Burst)": {
		"deck": ["shatter", "shatter", "attack", "jieshi", "zhuying", "tianping"],
		"strategy": "burst", # 专注完美弹反，乘势爆发输出
	},
	"镇煞打断流 (Guard Control)": {
		"deck": ["guard", "guard", "zhuangzhong", "difan", "fuhunsuo", "anhun"],
		"strategy": "control", # 专注时空凝滞、打断鬼手、控场
	},
	"长明续灯流 (Sustain Attrition)": {
		"deck": ["shift", "dengxin", "tianyou", "shuangdeng", "tongjing", "jinshen"],
		"strategy": "sustain", # 专注命火续航、铜镜反伤、高血量容错
	}
}

func _init() -> void:
	print("\n=======================================================")
	print("✦ 开始三构筑分化平衡性验证 (Three-Build Playtest) ✦")
	print("=======================================================\n")
	
	var results := {}
	
	for build_name in BUILDS:
		var cfg: Dictionary = BUILDS[build_name]
		var deck: Array[String] = []
		for c in cfg["deck"]:
			deck.append(String(c))
			
		print("-------------------------------------------------------")
		print(">>> 正在测试流派: %s" % build_name)
		print("    牌组构筑: %s" % str(deck))
		
		var sim := BattleSimulationScript.new()
		sim.deck_config = deck
		sim.restart()
		
		var turns := 0
		var elapsed_total := 0.0
		var victory := false
		
		# Run up to 40 seconds of simulated combat
		for step_i in range(2400):
			var delta := 1.0 / 60.0
			elapsed_total += delta
			var events: Array = sim.step(delta)
			
			if sim.state == BattleSimulationScript.BattleState.WINDUP:
				var move_dur: float = sim.current_intent.duration
				var time_to_hit: float = move_dur - sim.attack_elapsed
				
				# Build-specific parry input
				if bool(sim.current_intent.get("unblockable", false)):
					# Unblockable grab handling
					if cfg["strategy"] == "control" and sim.hand.has("guard") and sim.points >= 2 and sim.fake_released:
						sim.submit({"type": "play_card", "id": "guard"})
					elif sim.points >= 2 and sim.fake_released:
						sim.submit({"type": "defend"})
				else:
					# Normal / Slow strike parry
					if time_to_hit <= 0.08 and time_to_hit >= 0.0:
						sim.submit({"type": "defend"}) # Perfect parry timing
					elif time_to_hit <= 0.22 and time_to_hit > 0.08 and cfg["strategy"] != "burst":
						sim.submit({"type": "defend"}) # Success parry
						
				# Build-specific card playing
				if cfg["strategy"] == "burst":
					# 乘势流：优先在僵直窗口打出还刃
					var in_stagger := sim.state == BattleSimulationScript.BattleState.RESOLVING or sim.stagger_remaining > 0.0
					if in_stagger and sim.perfect_charge and sim.hand.has("shatter") and sim.points >= 2:
						sim.submit({"type": "play_card", "id": "shatter"})
					elif sim.points >= 2 and sim.hand.has("jieshi"):
						sim.submit({"type": "play_card", "id": "jieshi"})
					elif sim.points >= 1 and sim.hand.has("attack") and not in_stagger:
						sim.submit({"type": "play_card", "id": "attack"})
						
				elif cfg["strategy"] == "control":
					# 镇煞流：优先保持凝滞与打断
					if sim.hand.has("guard") and sim.points >= 2 and sim.stagger_remaining <= 0.1:
						sim.submit({"type": "play_card", "id": "guard"})
					elif sim.hand.has("zhuangzhong") and sim.points >= 2:
						sim.submit({"type": "play_card", "id": "zhuangzhong"})
					elif sim.hand.has("difan") and sim.points >= 1:
						sim.submit({"type": "play_card", "id": "difan"})
						
				elif cfg["strategy"] == "sustain":
					# 续灯流：保持满血和反伤
					if sim.player_hp < 60 and sim.hand.has("shift") and sim.points >= 2:
						sim.submit({"type": "play_card", "id": "shift"})
					elif sim.hand.has("tongjing") and sim.points >= 1:
						sim.submit({"type": "play_card", "id": "tongjing"})
					elif sim.hand.has("dengxin") and sim.points >= 1 and sim.player_hp < 68:
						sim.submit({"type": "play_card", "id": "dengxin"})
					elif sim.hand.has("shuangdeng") and sim.points >= 3:
						sim.submit({"type": "play_card", "id": "shuangdeng"})
						
			if sim.state == BattleSimulationScript.BattleState.VICTORY:
				victory = true
				break
			elif sim.state == BattleSimulationScript.BattleState.DEFEAT:
				victory = false
				break
				
		var st := sim.stats
		var summary := {
			"victory": victory,
			"player_hp": sim.player_hp,
			"enemy_hp": sim.enemy_hp,
			"combat_time_sec": round(elapsed_total * 10.0) / 10.0,
			"moves_faced": sim.attack_index + 1,
			"perfects": sim.perfects,
			"zhan_played": st.get("zhan_played", 0),
			"yu_played": st.get("yu_played", 0),
			"you_played": st.get("you_played", 0),
			"points_spent": st.get("points_spent", 0),
		}
		results[build_name] = summary
		print("  -> 战斗结果: %s | 历时: %.1fs | 剩余灯油: %d/72" % ["通关胜利" if victory else "战败", summary["combat_time_sec"], summary["player_hp"]])
		print("  -> 统计指纹: [斩牌: %d | 御牌: %d | 佑牌: %d | 完美弹反: %d | 消耗点数: %d]\n" % [
			summary["zhan_played"], summary["yu_played"], summary["you_played"], summary["perfects"], summary["points_spent"]
		])
		
	print("=======================================================")
	print("✦ 三构筑分化验证结论 ✦")
	var burst: Dictionary = results["还刃乘势流 (Shatter Burst)"]
	var control: Dictionary = results["镇煞打断流 (Guard Control)"]
	var sustain: Dictionary = results["长明续灯流 (Sustain Attrition)"]
	
	var is_differentiated: bool = (int(burst["zhan_played"]) > int(burst["yu_played"])) \
		and (int(control["yu_played"]) >= 2) \
		and (int(sustain["you_played"]) >= 2)
		
	if is_differentiated:
		print("✅ 验证成功：三大流派数据指纹呈现极其清晰的统计分化！")
		print("   • 乘势流：斩牌主导 (%d张)，高爆发快速击杀 (%.1fs)" % [burst["zhan_played"], burst["combat_time_sec"]])
		print("   • 镇煞流：御牌主导 (%d张)，高频凝滞打断控场" % control["yu_played"])
		print("   • 续灯流：佑牌主导 (%d张)，健康灯油终局存活 (%d/72)" % [sustain["you_played"], sustain["player_hp"]])
	else:
		printerr("❌ 警告：三大流派数据指纹未能形成明显分化！")
	print("=======================================================\n")
	
	quit(0 if is_differentiated else 1)
