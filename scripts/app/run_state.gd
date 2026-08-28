class_name RunState
extends RefCounted

## 可序列化的一局 Run 状态：存档、继续游戏、Seed 与难度都落在这里。
## RunFlow 持有本对象；战斗读它的 deck/hp/max_hp/mods/flags，战后写回。

const ContentCatalog := preload("res://scripts/battle/content_catalog.gd")

var seed_value := 0
var difficulty := 0
var hp := 72
var max_hp := 72
var gold := 0
var deck: Array[String] = []            # 槽位："id" 或 "id+"（升级）
var relics: Array[String] = []
var flags: Dictionary = {}              # 剧情旗标（改变敌人规则/奖励）
var map: Dictionary = {}                # MapGenerator 产物
var node_row := 0
var node_col := 0
var current_node: Dictionary = {}       # {type, enemy, id, event_id?}
var node_state := "done"                # 节点状态：in_progress（战斗中/事件未选）| done
var draft_history: Array[String] = []   # 遥测：三选一记录
var battle_count := 0
var shop_visited := false


func _init(start_seed: int = 0, diff: int = 0) -> void:
	seed_value = start_seed
	difficulty = clampi(diff, 0, ContentCatalog.DIFFICULTIES.size() - 1)


func setup_new_run() -> void:
	var rng := RandomNumberGenerator.new()
	if seed_value > 0:
		rng.seed = seed_value
	else:
		rng.randomize()
		seed_value = rng.seed
	hp = 72
	max_hp = 72
	gold = 0
	deck = ["attack", "attack", "shatter", "guard", "shift"]
	relics = []
	flags = {}
	node_row = 0
	node_col = 0
	node_state = "done"
	draft_history = []
	battle_count = 0
	shop_visited = false
	var MapGen := load("res://scripts/app/map_generator.gd")
	map = MapGen.new().generate(seed_value, difficulty)
	current_node = {}


func rng() -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = hash([seed_value, node_row, node_col, deck.size(), relics.size()])
	return r


func mods() -> Dictionary:
	## 遗物 + 难度 → BattleSimulation.run_mods。
	var mods := {}
	for rid in relics:
		var relic: Dictionary = ContentCatalog.RELICS.get(rid, {})
		for key in relic.get("mods", {}):
			if mods.has(key) and typeof(mods[key]) in [TYPE_INT, TYPE_FLOAT] and typeof(relic.mods[key]) in [TYPE_INT, TYPE_FLOAT]:
				mods[key] = mods[key] + relic.mods[key]
			else:
				mods[key] = relic.mods[key]
	var diff: Dictionary = ContentCatalog.DIFFICULTIES[difficulty]
	mods["enemy_hp_mul"] = diff.enemy_hp_mul
	mods["enemy_dmg_mul"] = diff.enemy_dmg_mul
	mods["gold_mul"] = diff.gold_mul
	if difficulty >= 2:
		mods["start_hp_penalty"] = 10
	return mods


func has_relic(id: String) -> bool:
	return relics.has(id)


func add_card(card_id: String, upgraded := false) -> void:
	deck.append(card_id + ("+" if upgraded else ""))


func remove_card(slot: String) -> bool:
	var idx := deck.find(slot)
	if idx < 0:
		return false
	deck.remove_at(idx)
	return true


func upgradable_cards() -> Array[String]:
	var out: Array[String] = []
	for slot in deck:
		if not slot.ends_with("+"):
			out.append(slot)
	return out


func upgrade_card(slot: String) -> bool:
	if slot.ends_with("+") or not deck.has(slot):
		return false
	deck[deck.find(slot)] = slot + "+"
	return true


func has_card_class(card_class: String) -> bool:
	for slot in deck:
		if String(ContentCatalog.CARD_DATA.get(String(slot.trim_suffix("+")), {}).get("class", "")) == card_class:
			return true
	return false


func random_card_of_class(rng_gen: RandomNumberGenerator, card_class := "") -> String:
	var pool: Array[String] = []
	for id in ContentCatalog.CARD_DATA:
		if card_class == "" or String(ContentCatalog.CARD_DATA[id]["class"]) == card_class:
			pool.append(String(id))
	if pool.is_empty():
		return "attack"
	return pool[rng_gen.randi_range(0, pool.size() - 1)]


func heal(amount: int) -> void:
	hp = mini(max_hp, hp + amount)


func to_dict() -> Dictionary:
	return {
		"version": 1,
		"seed": seed_value, "difficulty": difficulty,
		"hp": hp, "max_hp": max_hp, "gold": gold,
		"deck": deck, "relics": relics, "flags": flags,
		"map": map, "node_row": node_row, "node_col": node_col,
		"current_node": current_node,
		"node_state": node_state,
		"draft_history": draft_history, "battle_count": battle_count,
		"shop_visited": shop_visited,
	}


func from_dict(data: Dictionary) -> void:
	seed_value = int(data.get("seed", 0))
	difficulty = int(data.get("difficulty", 0))
	hp = int(data.get("hp", 72))
	max_hp = int(data.get("max_hp", 72))
	gold = int(data.get("gold", 0))
	deck.clear()
	for slot in data.get("deck", []):
		deck.append(String(slot))
	relics.assign(data.get("relics", []))
	flags = data.get("flags", {})
	map = data.get("map", {})
	node_row = int(data.get("node_row", 0))
	node_col = int(data.get("node_col", 0))
	current_node = data.get("current_node", {})
	node_state = String(data.get("node_state", "done"))
	draft_history.assign(data.get("draft_history", []))
	battle_count = int(data.get("battle_count", 0))
	shop_visited = bool(data.get("shop_visited", false))
