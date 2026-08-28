extends CanvasLayer

## 事件遭遇：剧情选择，产出真实后果（灯油/纸钱/符牌/遗物/删牌/升级/旗标）。
## 剧情旗标会写进 RunState.flags，改变后续敌人规则——故事与玩法互相咬合。

signal choice_made(event_id: String, choice: int)

const ContentCatalog := preload("res://scripts/battle/content_catalog.gd")

var event_id := ""
var choice_buttons: Array[Button] = []


func _ready() -> void:
	layer = 6
	visible = false
	add_child(UIKit.dim(Color(0.03, 0.02, 0.03, 0.88)))
	var panel := UIKit.panel(Vector2(390, 150), Vector2(500, 400))
	add_child(panel)
	var title := UIKit.label(Vector2(20, 30), Vector2(460, 44), 28, Color("f1d185"), true)
	title.name = "event_title"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(title)
	var body := UIKit.label(Vector2(36, 92), Vector2(428, 130), 17, Color("c8bb9d"))
	body.name = "event_body"
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(body)
	for i in 3:
		var btn := UIKit.button(Vector2(40, 234 + i * 54), Vector2(420, 46), "", 18)
		btn.name = "event_choice_%d" % i
		var idx := i
		btn.pressed.connect(func(): choice_made.emit(event_id, idx))
		panel.add_child(btn)
		choice_buttons.append(btn)


func show_event(id: String, data: Dictionary) -> void:
	event_id = id
	panel().get_node("event_title").text = String(data.get("title", ""))
	panel().get_node("event_body").text = String(data.get("body", ""))
	var choices: Array = data.get("choices", [])
	for i in 3:
		var btn := choice_buttons[i]
		if i < choices.size():
			btn.text = String(choices[i].get("text", ""))
			btn.visible = true
		else:
			btn.visible = false
	visible = true


func panel() -> Panel:
	for child in get_children():
		if child is Panel:
			return child
	return null
