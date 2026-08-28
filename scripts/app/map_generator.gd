class_name MapGenerator
extends RefCounted

## 夜巡地图生成：行式分支地图（类杀戮尖塔）。
## 每行 2-3 个节点，相邻行按"同列或邻列"连边；玩家在结算后从当前行的
## 可达节点中选一条路。风险收益：精英掉遗物、商店可删牌、事件有剧情收益。

const ContentCatalog := preload("res://scripts/battle/content_catalog.gd")

const ROWS := 10

const NORMAL_POOL := ["lantern_imp", "paper_apprentice", "barber_ghost", "patrol_corpse"]
const ELITE_POOL := ["gambler_ghost", "well_sisters", "mortuary_warden"]
const BOSS := "lantern_keeper"

var rng := RandomNumberGenerator.new()


func generate(seed_value: int, difficulty: int) -> Dictionary:
	rng.seed = seed_value if seed_value > 0 else randi()
	var rows: Array = []
	for r in ROWS:
		rows.append(_gen_row(r))
	_connect(rows, ROWS)
	rows.append([{"type": "boss", "enemy": BOSS}])
	return {"rows": rows, "difficulty": difficulty}


func _gen_row(r: int) -> Array:
	var nodes: Array = []
	var count := 2 if rng.randf() < 0.45 else 3
	for c in count:
		nodes.append({"type": _pick_type(r), "enemy": "", "id": "%d_%d" % [r, c]})
	for node in nodes:
		if node["type"] in ["battle", "elite"]:
			node["enemy"] = _pick_enemy(node["type"], r)
	return nodes


func _pick_type(r: int) -> String:
	var roll := rng.randf()
	if r == ROWS - 1:
		# 决战前一排必有歇脚
		return "rest" if roll < 0.6 else "shop"
	if r == 0:
		return "battle"
	if roll < 0.42:
		return "battle"
	if roll < 0.62:
		return "event"
	if roll < 0.72:
		return "elite" if r >= 3 else "battle"
	if roll < 0.82:
		return "rest"
	if roll < 0.92:
		return "shop"
	return "treasure"


func _pick_enemy(kind: String, r: int) -> String:
	if kind == "elite":
		return ELITE_POOL[rng.randi_range(0, ELITE_POOL.size() - 1)]
	# 深度越深，用越硬的普通敌人
	var pool := NORMAL_POOL.duplicate()
	if r >= 4:
		pool.append("well_sisters")
	if r >= 6:
		pool.append("gambler_ghost")
	return pool[rng.randi_range(0, pool.size() - 1)]


func _connect(rows: Array, row_count: int) -> void:
	for node in rows[0]:
		node["entry"] = true
	for r in row_count - 1:
		var cur: Array = rows[r]
		var next: Array = rows[r + 1]
		# 保证下一行每个节点都有入边
		for c in next.size():
			var from_c := clampi(c, 0, cur.size() - 1)
			next[c]["from"] = next[c].get("from", [])
			next[c]["from"].append([r, from_c])
		# 保证当前行每个节点都有出边
		for c in cur.size():
			var to_c := clampi(c, 0, next.size() - 1)
			next[to_c]["from"] = next[to_c].get("from", [])
			if not _has_edge(next[to_c]["from"], r, c):
				next[to_c]["from"].append([r, c])


func _has_edge(edges: Array, r: int, c: int) -> bool:
	for e in edges:
		if int(e[0]) == r and int(e[1]) == c:
			return true
	return false


## 玩家当前站在 (row, col)，返回下一行可达节点列表 [{row, col, node}]。
func next_options(map_data: Dictionary, row: int, col: int) -> Array:
	var rows: Array = map_data.get("rows", [])
	var last_normal := rows.size() - 2
	if row >= last_normal:
		# 末行 → Boss
		return [{"row": rows.size() - 1, "col": 0, "node": rows[rows.size() - 1][0]}]
	var out: Array = []
	for c in rows[row + 1].size():
		var node: Dictionary = rows[row + 1][c]
		for e in node.get("from", []):
			if int(e[0]) == row and int(e[1]) == col:
				out.append({"row": row + 1, "col": c, "node": node})
				break
	return out
