extends CanvasLayer

## 结算：天明 / 灯灭，展示本局数据并回落到标题（或难度解锁提示）。

signal back_to_menu

var title_label: Label
var sub_label: Label
var stats_label: Label


func _ready() -> void:
	layer = 7
	visible = false
	add_child(UIKit.dim(Color(0.01, 0.01, 0.02, 0.92)))
	title_label = UIKit.label(Vector2(240, 190), Vector2(800, 80), 52, Color("f1d185"), true)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title_label)
	sub_label = UIKit.label(Vector2(240, 300), Vector2(800, 40), 20, Color("c8bb9d"))
	sub_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(sub_label)
	stats_label = UIKit.label(Vector2(240, 356), Vector2(800, 70), 16, Color("9caaa9"))
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(stats_label)
	var menu_btn := UIKit.button(Vector2(490, 470), Vector2(300, 60), "回到长夜")
	menu_btn.pressed.connect(func(): back_to_menu.emit())
	add_child(menu_btn)


func show_over(victory: bool, node_text: String, battles: int, deck_size: int, unlocked_next: bool) -> void:
	if victory:
		title_label.text = "夜 尽 天 明"
		title_label.add_theme_color_override("font_color", Color("f1d185"))
		sub_label.text = "秤砣归位，众怨过河。你走完了整条更路。"
	else:
		title_label.text = "灯 灭 了"
		title_label.add_theme_color_override("font_color", Color("cf5555"))
		sub_label.text = "第 %s 场，执灯人倒在了更路上。" % node_text
	var unlock_text := ""
	if unlocked_next:
		unlock_text = "\n※ 解锁新难度：下一更已开启 ※"
	stats_label.text = "历经 %d 场战斗 · 牌组 %d 张%s" % [battles, deck_size, unlock_text]
	visible = true
