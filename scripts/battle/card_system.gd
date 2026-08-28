class_name CardSystem
extends RefCounted

## 卡牌系统：卡牌定义 → 效果列表 → 模拟器执行。
## _play_card 的大型 match 由此取代：新增卡牌只需在 content_catalog 里声明 effects，
## 无需改动模拟器分支。升级卡（"id+"）在此合成有效定义。

const ContentCatalog := preload("res://scripts/battle/content_catalog.gd")

const CARD_DATA := ContentCatalog.CARD_DATA


## 解析牌组槽位（"id" 或 "id+"）为卡牌 id 与升级标记。
static func parse_slot(slot: String) -> Array:
	if slot.ends_with("+"):
		return [slot.trim_suffix("+"), true]
	return [slot, false]


## 合成有效定义：基础定义 + 升级补丁；标量字段（damage/heal 等）从效果列表回填。
static func effective_def(slot: String) -> Dictionary:
	var parsed: Array = parse_slot(slot)
	var base: Dictionary = CARD_DATA.get(parsed[0], {})
	if base.is_empty():
		return {}
	var def := base.duplicate(true)
	def["id"] = parsed[0]
	def["upgraded"] = parsed[1]
	if parsed[1] and base.has("upgrade"):
		for key in base["upgrade"]:
			def[key] = base["upgrade"][key]
	# 从效果列表回填标量，保证 upgrade 后 damage/heal 与效果一致
	for eff: Dictionary in def.get("effects", []):
		if String(eff.get("type", "")) == "damage":
			def["damage"] = int(eff.get("amount", 0))
		elif String(eff.get("type", "")) == "heal":
			def["heal"] = int(eff.get("amount", 0))
	return def


static func display_id(slot: String) -> String:
	return String(parse_slot(slot)[0])


static func cost_of(slot: String) -> int:
	return int(effective_def(slot).get("cost", 0))


static func title_of(slot: String) -> String:
	return String(effective_def(slot).get("title", "?"))


static func class_of(slot: String) -> String:
	return String(effective_def(slot).get("class", "斩"))


static func effects_of(slot: String) -> Array:
	return effective_def(slot).get("effects", [])


## 描述文本（卡面短说明），依据效果列表自动合成。
static func describe(slot: String) -> String:
	var parts: Array[String] = []
	for eff: Dictionary in effects_of(slot):
		var t := String(eff.get("type", ""))
		var n := int(eff.get("amount", 0))
		match t:
			"damage":
				var text := "怨气 -%d" % n
				if eff.has("bonus_cond"):
					var cond_text := "灯油不满" if String(eff.bonus_cond) == "player_wounded" else "敌怨气低"
					text += "（%s 再 -%d）" % [cond_text, int(eff.get("bonus", 0))]
				parts.append(text)
			"charged_bonus":
				parts.append("乘势追加 -%d" % n)
			"heal":
				parts.append("灯油 +%d" % n)
			"max_hp":
				parts.append("灯油上限 +%d" % n)
			"stagger":
				parts.append("凝滞 %.2fs" % float(eff.get("amount", 0.0)))
			"interrupt":
				parts.append("打断鬼招（头目免疫）")
			"grab_cancel":
				parts.append("可斩断鬼手")
			"force_perfect":
				parts.append("下一刀视为完美")
			"mirror":
				parts.append("化解时反伤 3")
			"fear":
				parts.append("鬼伤 ×%.2f（一次）" % float(eff.get("mul", 1.0)))
			"golden":
				parts.append("承伤固定 5，×%d" % n)
			"cleanse":
				parts.append("鬼手化为可防范")
			"suppress_fake":
				parts.append("佯攻失效")
			"delay_impact":
				parts.append("鬼招延后 %.2fs" % float(eff.get("amount", 0.0)))
			"widen_window":
				parts.append("本招窗口 +%.0f%%" % (float(eff.get("amount", 0.0)) * 100.0))
			"widen_window_next":
				parts.append("下一招窗口 +%.0f%%" % (float(eff.get("amount", 0.0)) * 100.0))
			"skip_next_strike":
				parts.append("抹去鬼招下一段命中")
			"draw":
				parts.append("抽 %d 张" % n)
			"scry":
				parts.append("问路：看牌堆顶 %d 张选一张" % n)
			"summon_draw":
				parts.append("召回 %d 张符牌" % n)
			"discard_random":
				parts.append("随机弃一张手牌" + ("（可拒绝）" if bool(eff.get("optional", false)) else ""))
			"points":
				parts.append("还愿 +%d" % n)
			"damage_self":
				parts.append("灯油 -%d" % n)
			"reveal_next":
				parts.append("窥见下一招")
	return "·".join(parts) if not parts.is_empty() else "符牌"
