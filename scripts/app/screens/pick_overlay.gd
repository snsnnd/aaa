extends CanvasLayer

## 通用牌组挑选浮层：删牌（鬼市焚符 / 事件超度）等需要"从牌组选一张"的场合复用。

signal picked(slot: String)
signal cancelled

const PresentationCatalog := preload("res://scripts/presentation/presentation_catalog.gd")

var list: VBoxContainer
var title_label: Label


func _ready() -> void:
	layer = 15
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	add_child(UIKit.dim(Color(0, 0, 0, 0.82)))
	var panel := UIKit.panel(Vector2(340, 100), Vector2(600, 520))
	add_child(panel)
	title_label = UIKit.label(Vector2(20, 20), Vector2(560, 40), 24, Color("f1d185"), true)
	title_label.text = "选一张符牌"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(title_label)
	list = VBoxContainer.new()
	list.position = Vector2(30, 72)
	list.size = Vector2(540, 380)
	panel.add_child(list)
	var cancel := UIKit.button(Vector2(200, 462), Vector2(200, 40), "取消", 16)
	cancel.pressed.connect(func(): cancelled.emit(); visible = false)
	panel.add_child(cancel)


func open(deck: Array, title_text := "选一张符牌") -> void:
	title_label.text = title_text
	for child in list.get_children():
		child.queue_free()
	var scroll := ScrollContainer.new()
	scroll.size = Vector2(540, 380)
	list.add_child(scroll)
	var inner := VBoxContainer.new()
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(inner)
	for slot in deck:
		var id := CardSystem.display_id(String(slot))
		var pres: Dictionary = PresentationCatalog.CARD_PRESENTATION.get(id, {"title": id, "color": Color.WHITE})
		var def: Dictionary = CardSystem.effective_def(String(slot))
		var btn := UIKit.button(Vector2.ZERO, Vector2(520, 44),
			"%s%s｜%s·%d点  %s" % [pres["title"], "+" if String(slot).ends_with("+") else "", def.get("class", "?"), def.get("cost", 0), CardSystem.describe(String(slot))], 14)
		btn.pressed.connect(func():
			picked.emit(String(slot))
			visible = false)
		inner.add_child(btn)
	visible = true
