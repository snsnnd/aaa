class_name Tutorial
extends RefCounted

## 渐进式教学：不再让新手一次吞下全部规则。
## 按战斗事件逐步解锁提示，只讲当前需要的；核心步骤见过后写入局外进度。

const SaveManagerScript := preload("res://scripts/app/save_manager.gd")

const STEPS := [
	"defend_basic",    # 敌招落下前防范
	"cards",           # 用还愿出符牌
	"summon",          # 召符换牌
	"unblockable",     # 鬼手不可防范
	"perfect",         # 完美与乘势
]

var seen: Array = []
var active := false
var _battle_defended := false


func _init() -> void:
	var meta: Dictionary = SaveManagerScript.load_meta()
	if not bool(meta.get("tutorial_done", false)):
		active = true


## 返回要显示的提示文本；不需要则返回 ""。
func handle_event(event: Dictionary, sim) -> String:
	if not active:
		return ""
	var type := String(event.get("type", ""))
	match type:
		"attack_started":
			if not seen.has("defend_basic") and sim.attack_index == 0:
				_mark("defend_basic")
				return "敌招落下前按【防范】——越接近落刀，越接近完美"
		"defense_queued":
			_battle_defended = true
			if not seen.has("perfect") and int(event.get("grade", 0)) == 2:
				_mark("perfect")
				return "完美接刀！还愿+1，且进入乘势：僵直中的还刃更痛"
		"commit_cue":
			if _battle_defended and not seen.has("cards"):
				_mark("cards")
				return "有还愿了！按 1-4 出符牌削减怨气"
		"summon_rejected":
			if not seen.has("summon") and String(event.get("reason", "")) == "points":
				_mark("summon")
				return "召符花 2 点还愿，从牌堆换一张符牌上手"
		"defense_miss":
			if bool(event.get("unblockable", false)) and not seen.has("unblockable"):
				_mark("unblockable")
				return "鬼手不可防范——出【安魂】净化，或花 2 点还愿强行消解"
		"victory":
			if _all_seen():
				_finish()
	return ""


func _all_seen() -> bool:
	for step in STEPS:
		if not seen.has(step):
			return false
	return true


func _mark(step: String) -> void:
	seen.append(step)


func _finish() -> void:
	active = false
	var meta: Dictionary = SaveManagerScript.load_meta()
	meta["tutorial_done"] = true
	SaveManagerScript.save_meta(meta)
