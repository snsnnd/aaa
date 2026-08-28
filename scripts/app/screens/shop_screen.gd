extends CanvasLayer

## 鬼市：纸钱消费——买牌、买遗物、删牌、买灯油。
## 补齐肉鸽经济闭环：战斗赚纸钱，这里花掉；删牌是构筑收敛的关键操作。

signal bought(item: String, payload: String)
signal left_shop

const ContentCatalog := preload("res://scripts/battle/content_catalog.gd")
const PresentationCatalog := preload("res://scripts/presentation/presentation_catalog.gd")

var gold_label: Label
var stock_cards: Array[String] = []
var stock_relic := ""
var prices := {"card": 65, "relic": 100, "remove": 40, "heal": 30}
var card_buttons: Array[Button] = []
var relic_btn: Button
var remove_btn: Button
var heal_btn: Button


func _ready() -> void:
	layer = 6
	visible = false
	add_child(UIKit.dim(Color(0.03, 0.02, 0.04, 0.9)))
	add_child(UIKit.title("鬼 市", 90))
	gold_label = UIKit.label(Vector2(240, 146), Vector2(800, 30), 18, Color("c8aa64"))
	gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(gold_label)
	for i in 2:
		var btn := UIKit.button(Vector2(260 + i * 280, 210), Vector2(240, 190), "", 18)
		var idx := i
		btn.pressed.connect(func(): bought.emit("card", stock_cards[idx]))
		add_child(btn)
		card_buttons.append(btn)
	relic_btn = UIKit.button(Vector2(260, 420), Vector2(240, 80), "", 16)
	relic_btn.pressed.connect(func(): bought.emit("relic", stock_relic))
	add_child(relic_btn)
	remove_btn = UIKit.button(Vector2(520, 420), Vector2(240, 80), "焚符（删一张牌）", 18)
	remove_btn.pressed.connect(func(): bought.emit("remove", ""))
	add_child(remove_btn)
	heal_btn = UIKit.button(Vector2(780, 420), Vector2(240, 80), "热汤（灯油 +20）", 18)
	heal_btn.pressed.connect(func(): bought.emit("heal", ""))
	add_child(heal_btn)
	var leave := UIKit.button(Vector2(500, 560), Vector2(280, 50), "离开鬼市")
	leave.pressed.connect(func(): left_shop.emit())
	add_child(leave)


func show_shop(gold: int, cards: Array[String], relic: String, owned_relics: Array) -> void:
	stock_cards = cards
	stock_relic = relic
	gold_label.text = "纸钱 %d" % gold
	for i in 2:
		var id := stock_cards[i]
		var pres: Dictionary = PresentationCatalog.CARD_PRESENTATION.get(id, {"title": id, "color": Color.WHITE})
		var def: Dictionary = CardSystem.effective_def(id)
		card_buttons[i].text = "%s\n%s·%d点\n%s\n——— %d 纸钱" % [pres["title"], def.get("class", "?"), def.get("cost", 0), CardSystem.describe(id), prices["card"]]
		card_buttons[i].disabled = gold < prices["card"]
	if stock_relic == "":
		relic_btn.text = "遗物已售罄"
		relic_btn.disabled = true
	else:
		var relic_data: Dictionary = ContentCatalog.RELICS[stock_relic]
		relic_btn.text = "%s\n%s\n——— %d 纸钱" % [relic_data["name"], relic_data["desc"], prices["relic"]]
		relic_btn.disabled = gold < prices["relic"] or owned_relics.has(stock_relic)
	remove_btn.disabled = gold < prices["remove"]
	heal_btn.disabled = gold < prices["heal"]
	visible = true
