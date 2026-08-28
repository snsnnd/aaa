extends CanvasLayer

## 夜巡地图：路线选择层。展示整张地图、当前位置与下一行可达节点，
## 玩家点选节点上路——随机地图 + 路线收益风险的载体。

signal node_picked(row: int, col: int)

const NODE_COLORS := {
	"battle": Color("bd6a5a"), "elite": Color("d85151"), "event": Color("c9a15a"),
	"rest": Color("8fb07a"), "shop": Color("c8b46a"), "treasure": Color("a08ac8"),
	"boss": Color("f2d487"),
}
const NODE_NAMES := {
	"battle": "夜战", "elite": "精英", "event": "遭遇",
	"rest": "歇脚", "shop": "鬼市", "treasure": "遗物", "boss": "守灯人",
}

var buttons: Array = []


func _ready() -> void:
	layer = 4
	visible = false
	add_child(UIKit.dim(Color(0.015, 0.015, 0.025, 0.97)))
	var title := UIKit.label(Vector2(240, 24), Vector2(800, 44), 28, Color("f2d487"), true)
	title.text = "更  路"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)
	var hint := UIKit.label(Vector2(240, 66), Vector2(800, 26), 15, Color("9caaa9"))
	hint.text = "点一盏灯，选你的路。精英更险，遗物更贪。"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(hint)


func show_map(map_data: Dictionary, row: int, col: int, options: Array, hp: int, max_hp: int, gold: int) -> void:
	for child in get_children():
		if child.name.begins_with("map_"):
			child.queue_free()
	for b in buttons:
		if is_instance_valid(b):
			b.queue_free()
	buttons.clear()
	var rows: Array = map_data.get("rows", [])
	var row_h := 46.0
	var origin_y := 110.0
	var center_x := 640.0
	# 节点
	for r in rows.size():
		var nodes: Array = rows[r]
		var spread := 150.0
		for c in nodes.size():
			var node: Dictionary = nodes[c]
			var x := center_x + (float(c) - float(nodes.size() - 1) * 0.5) * spread
			var y := origin_y + float(r) * row_h
			var is_current := r == row and c == col
			var is_option := false
			for opt in options:
				if int(opt["row"]) == r and int(opt["col"]) == c:
					is_option = true
			var visited := r < row
			_draw_node(x, y, node, is_current, is_option, visited, r, c)
	# 连线
	for r in rows.size() - 1:
		var nodes: Array = rows[r]
		var next_nodes: Array = rows[r + 1]
		for c in nodes.size():
			for c2 in next_nodes.size():
				var connected := false
				for e in next_nodes[c2].get("from", []):
					if int(e[0]) == r and int(e[1]) == c:
						connected = true
				if connected:
					_draw_edge(float(c), nodes.size(), float(r), float(c2), next_nodes.size(), float(r + 1))
	# 末行 → Boss 连线
	var last_normal: Array = rows[rows.size() - 2] if rows.size() >= 2 else []
	for c in last_normal.size():
		_draw_edge(float(c), last_normal.size(), float(rows.size() - 2), 0.0, 1.0, float(rows.size() - 1))
	var status := UIKit.label(Vector2(240, 668), Vector2(800, 30), 18, Color("c8bb9d"))
	status.name = "map_status"
	status.text = "灯油 %d/%d ｜ 纸钱 %d" % [hp, max_hp, gold]
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.name = "map_status"
	add_child(status)
	visible = true


func _edge_pos(c: float, count: float, r: float) -> Vector2:
	var spread := 150.0
	var x := 640.0 + (c - (count - 1) * 0.5) * spread
	var y := 110.0 + r * 46.0 + 16.0
	return Vector2(x, y)


func _draw_edge(c1: float, n1: int, r1: int, c2: float, n2: int, r2: int) -> void:
	var line := Line2D.new()
	line.name = "map_edge"
	line.width = 2.0
	line.default_color = Color(0.35, 0.3, 0.22, 0.8)
	line.add_point(_edge_pos(c1, n1, r1))
	line.add_point(_edge_pos(c2, n2, r2))
	add_child(line)


func _draw_node(x: float, y: float, node: Dictionary, is_current: bool, is_option: bool, visited: bool, r: int, c: int) -> void:
	var type := String(node.get("type", "battle"))
	var color: Color = NODE_COLORS.get(type, Color.GRAY)
	if visited:
		color = color.darkened(0.5)
	var size := Vector2(74, 34)
	var pos := Vector2(x - size.x * 0.5, y)
	var btn := UIKit.button(pos, size, NODE_NAMES.get(type, type), 14)
	btn.name = "map_node"
	btn.add_theme_stylebox_override("normal", UIKit.style_box(color.darkened(0.55), color if (is_option or is_current) else Color(0.3, 0.28, 0.24), 8, 2 if not is_current else 4))
	btn.disabled = not is_option
	if is_current:
		btn.text = "▶ " + btn.text
	if is_option:
		btn.add_theme_stylebox_override("hover", UIKit.style_box(color.darkened(0.3), color.lightened(0.3), 8, 3))
	var enemy := String(node.get("enemy", ""))
	if enemy != "":
		btn.tooltip_text = enemy
	btn.pressed.connect(func(): node_picked.emit(r, c))
	add_child(btn)
	buttons.append(btn)
