extends CanvasLayer

## 城隍歇脚：回血 / 升级一张牌。比旧版"只能 +20 灯油"多一个战略选择。

signal rest_choice(kind: String, payload: String)

const PresentationCatalog := preload("res://scripts/presentation/presentation_catalog.gd")

var hp_label: Label
var upgrade_list: VBoxContainer
var show_upgrades := false


func _ready() -> void:
	layer = 6
	visible = false
	add_child(UIKit.dim(Color(0.02, 0.03, 0.02, 0.88)))
	var panel := UIKit.panel(Vector2(420, 180), Vector2(440, 320), Color("6d9663"))
	add_child(panel)
	var title := UIKit.label(Vector2(20, 34), Vector2(400, 48), 30, Color("aad18f"), true)
	title.text = "城隍歇脚"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(title)
	hp_label = UIKit.label(Vector2(20, 100), Vector2(400, 30), 18, Color("c8bb9d"))
	hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(hp_label)
	var heal_btn := UIKit.button(Vector2(70, 146), Vector2(300, 48), "添灯油（回复 30%）")
	heal_btn.pressed.connect(func(): rest_choice.emit("heal", ""))
	panel.add_child(heal_btn)
	var upg_btn := UIKit.button(Vector2(70, 206), Vector2(300, 48), "补完一张符牌（升级）")
	upg_btn.pressed.connect(func():
		show_upgrades = not show_upgrades
		_toggle_upgrades())
	panel.add_child(upg_btn)
	upgrade_list = VBoxContainer.new()
	upgrade_list.name = "upgrade_list"
	upgrade_list.position = Vector2(70, 206)
	upgrade_list.size = Vector2(300, 100)
	upgrade_list.visible = false
	panel.add_child(upgrade_list)


func show_rest(hp: int, max_hp: int) -> void:
	hp_label.text = "灯油 %d / %d" % [hp, max_hp]
	visible = true


func populate_upgrades(slots: Array) -> void:
	for child in upgrade_list.get_children():
		child.queue_free()
	if slots.is_empty():
		var none := UIKit.label(Vector2.ZERO, Vector2(300, 30), 15, Color("9e8b81"))
		none.text = "没有可升级的符牌"
		upgrade_list.add_child(none)
		return
	for slot in slots.slice(0, 3):
		var id := CardSystem.display_id(String(slot))
		var btn := UIKit.button(Vector2.ZERO, Vector2(300, 34),
			"%s+%d → %s" % [PresentationCatalog.CARD_PRESENTATION[id]["title"], 0, _upgraded_desc(slot)], 13)
		btn.pressed.connect(func(): rest_choice.emit("upgrade", String(slot)))
		upgrade_list.add_child(btn)


func _toggle_upgrades() -> void:
	upgrade_list.visible = show_upgrades
	upgrade_list.position.y = 262.0 if show_upgrades else 206.0


func _upgraded_desc(slot: String) -> String:
	var def: Dictionary = CardSystem.effective_def(slot + "+")
	var parts: Array[String] = []
	for eff: Dictionary in CardSystem.effects_of(slot + "+"):
		if String(eff.get("type", "")) in ["damage", "heal", "stagger", "max_hp"]:
			parts.append("%s %s" % [String(eff.get("type", "")), str(eff.get("amount", ""))])
	return def.get("title", "?") + ("（" + "·".join(parts) + "）" if not parts.is_empty() else "")
