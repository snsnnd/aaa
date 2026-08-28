extends CanvasLayer

## 战后奖励：怨契三选一（保证御/斩/随机）+ 纸钱结算 + 删牌入口在鬼市。

signal card_picked(index: int)
signal skipped

const PresentationCatalog := preload("res://scripts/presentation/presentation_catalog.gd")

var options: Array[String] = []
var card_buttons: Array[Button] = []
var gold_label: Label


func _ready() -> void:
	layer = 6
	visible = false
	add_child(UIKit.dim(Color(0.05, 0.03, 0.03, 0.86)))
	add_child(UIKit.title("怨契三选一"))
	gold_label = UIKit.label(Vector2(240, 186), Vector2(800, 30), 18, Color("c8aa64"))
	gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(gold_label)
	for i in 3:
		var btn := UIKit.button(Vector2(240 + i * 280, 240), Vector2(240, 210), "", 24)
		btn.pressed.connect(func(): card_picked.emit(i))
		add_child(btn)
		card_buttons.append(btn)
	var skip := UIKit.button(Vector2(500, 500), Vector2(280, 52), "跳过（继续上路）")
	skip.pressed.connect(func(): skipped.emit())
	add_child(skip)


func show_reward(draft: Array, gold_gain: int, gold_total: int) -> void:
	options.assign(draft)
	gold_label.text = "纸钱 +%d（共 %d）" % [gold_gain, gold_total]
	for i in 3:
		var btn := card_buttons[i]
		var id := options[i]
		var pres: Dictionary = PresentationCatalog.CARD_PRESENTATION.get(id, {"title": id, "color": Color.WHITE})
		var def: Dictionary = CardSystem.effective_def(id)
		btn.text = "%s\n%s·%d点\n%s" % [pres["title"], def.get("class", "?"), def.get("cost", 0), CardSystem.describe(id)]
		btn.disabled = false
		var color: Color = pres.get("color", Color.WHITE)
		btn.add_theme_stylebox_override("normal", UIKit.style_box(Color("151821"), color.darkened(0.2), 12, 3))
		btn.add_theme_stylebox_override("hover", UIKit.style_box(Color("222631"), color, 12, 4))
	visible = true
