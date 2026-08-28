extends Control

## 手牌区：四个符牌槽、召符/防范按钮、牌堆视图与操作提示。

const BattleSimulationScript := preload("res://scripts/battle/battle_simulation.gd")
const PresentationCatalog := preload("res://scripts/presentation/presentation_catalog.gd")

var sim: BattleSimulationScript
var command: Callable
var card_buttons: Dictionary = {}
var slot_titles: Dictionary = {}
var slot_hints: Dictionary = {}
var slot_classes: Dictionary = {}
var slot_frames: Dictionary = {}
var pile_draw_box: Control
var pile_discard_box: Control
var instruction_label: Label
var defense_button: Button
var summon_button: Button
var _card_textures: Dictionary = {}


func setup(s: BattleSimulationScript, command_cb: Callable) -> void:
	sim = s
	command = command_cb
	_load_card_textures()
	_build()
	rebuild_hand()
	rebuild_pile_view()
	refresh_slots()


func _load_card_textures() -> void:
	for id in BattleSimulationScript.CARD_DATA:
		if PresentationCatalog.CARD_PRESENTATION.has(id):
			_card_textures[id] = load(PresentationCatalog.CARD_PRESENTATION[id].icon)
		else:
			var default_icon := "res://assets/game/cards/card_%s.png" % id
			if ResourceLoader.exists(default_icon):
				_card_textures[id] = load(default_icon)


func _build() -> void:
	instruction_label = _label(Vector2(24, 18), Vector2(246, 142), 16, Color("a9a49b"), false)
	instruction_label.text = "Space 架势防范\n1-4 消耗还愿出牌\n5 召符（2 点）\n按空则气息散乱\nR 重新开始\nEsc 菜单"
	instruction_label.visible = false
	add_child(instruction_label)

	var pile_draw_title := _label(Vector2(24, 14), Vector2(160, 22), 14, Color("8f8578"), false)
	pile_draw_title.text = "牌堆"
	add_child(pile_draw_title)
	pile_draw_box = Control.new()
	pile_draw_box.position = Vector2(24, 40)
	pile_draw_box.size = Vector2(240, 54)
	pile_draw_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(pile_draw_box)
	var pile_discard_title := _label(Vector2(24, 100), Vector2(160, 22), 14, Color("8f8578"), false)
	pile_discard_title.text = "弃牌堆"
	add_child(pile_discard_title)
	pile_discard_box = Control.new()
	pile_discard_box.position = Vector2(24, 126)
	pile_discard_box.size = Vector2(240, 54)
	pile_discard_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(pile_discard_box)

	for i in 4:
		_create_slot_button(Vector2(285 + i * 160, 12), i)
	rebuild_hand()

	defense_button = Button.new()
	defense_button.position = Vector2(975, 38)
	defense_button.size = Vector2(264, 92)
	defense_button.focus_mode = Control.FOCUS_NONE
	defense_button.add_theme_font_size_override("font_size", 20)
	defense_button.add_theme_stylebox_override("normal", _style_box(Color("2c211d"), Color("bd8b45"), 15, 3))
	defense_button.add_theme_stylebox_override("hover", _style_box(Color("493126"), Color("e0ad58"), 15, 4))
	defense_button.add_theme_stylebox_override("disabled", _style_box(Color("17171d"), Color("47434a"), 15, 2))
	defense_button.pressed.connect(func(): command.call({"type": "defend"}))
	add_child(defense_button)

	summon_button = Button.new()
	summon_button.position = Vector2(905, 12)
	summon_button.size = Vector2(58, 156)
	summon_button.focus_mode = Control.FOCUS_NONE
	summon_button.add_theme_font_size_override("font_size", 18)
	summon_button.text = "召\n符\n[5]"
	summon_button.add_theme_stylebox_override("normal", _style_box(Color("241d14"), Color("9a7a3a"), 12, 2))
	summon_button.add_theme_stylebox_override("hover", _style_box(Color("3a2f1d"), Color("d3a44b"), 12, 3))
	summon_button.add_theme_stylebox_override("disabled", _style_box(Color("17171d"), Color("47434a"), 12, 2))
	summon_button.pressed.connect(func(): command.call({"type": "summon"}))
	add_child(summon_button)


func _create_slot_button(pos: Vector2, slot: int) -> void:
	var button := Button.new()
	button.position = pos
	button.size = Vector2(142, 156)
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_stylebox_override("normal", _style_box(Color("151821"), Color("4a4438"), 12, 3))
	button.add_theme_stylebox_override("hover", _style_box(Color("222631"), Color("6a6250"), 12, 4))
	button.add_theme_stylebox_override("pressed", _style_box(Color("0d0f15"), Color("ead8a4"), 12, 5))
	button.pressed.connect(_on_slot_pressed.bind(slot))
	add_child(button)

	var icon := TextureRect.new()
	icon.position = Vector2(31, 8)
	icon.size = Vector2(80, 80)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	button.add_child(icon)

	var frame := TextureRect.new()
	frame.position = Vector2(2, 2)
	frame.size = Vector2(138, 152)
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.stretch_mode = TextureRect.STRETCH_SCALE
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.z_index = 1
	button.add_child(frame)

	var title := _label(Vector2(8, 87), Vector2(126, 28), 20, Color("eee2c1"), true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.z_index = 2
	button.add_child(title)
	var hint := _label(Vector2(8, 117), Vector2(126, 30), 13, Color("a9a49b"), false)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint.z_index = 2
	button.add_child(hint)
	var class_tag := _label(Vector2(10, 6), Vector2(34, 24), 15, Color.WHITE, true)
	class_tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	class_tag.z_index = 2
	button.add_child(class_tag)
	card_buttons[slot] = button
	slot_titles[slot] = title
	slot_hints[slot] = hint
	slot_classes[slot] = class_tag
	slot_frames[slot] = frame


func _on_slot_pressed(slot: int) -> void:
	if slot >= 0 and slot < sim.hand.size():
		command.call({"type": "play_card", "id": sim.hand[slot]})


func rebuild_hand() -> void:
	var class_colors := {"斩": Color("e08a7a"), "御": Color("7fd4dc"), "佑": Color("aad18f")}
	for i in 4:
		var button: Button = card_buttons[i]
		var icon: TextureRect = button.get_child(0)
		var frame: TextureRect = slot_frames[i]
		var title: Label = slot_titles[i]
		var hint: Label = slot_hints[i]
		var class_tag: Label = slot_classes[i]
		if i < sim.hand.size():
			var id: String = sim.hand[i]
			var data: Dictionary = BattleSimulationScript.CARD_DATA[id]
			var pres: Dictionary = PresentationCatalog.CARD_PRESENTATION[id]
			icon.texture = _card_textures.get(id)
			title.text = "%s  [%d]" % [pres.title, i + 1]
			hint.text = "%s·%d点｜%s" % [data["class"], data.cost, _card_short(id)]
			class_tag.text = String(data["class"])
			class_tag.add_theme_color_override("font_color", class_colors[data["class"]])
			button.tooltip_text = _card_tip(id)
			var frame_path: String = PresentationCatalog.CARD_FRAMES.get(data["class"], "")
			if frame_path != "" and ResourceLoader.exists(frame_path):
				frame.texture = load(frame_path)
			else:
				frame.texture = null
			var col: Color = pres.color
			button.add_theme_stylebox_override("normal", _style_box(Color("151821"), col.darkened(0.2), 12, 3))
			button.add_theme_stylebox_override("hover", _style_box(Color("222631"), col, 12, 4))
		else:
			icon.texture = null
			frame.texture = null
			title.text = ""
			hint.text = ""
			class_tag.text = ""
			button.tooltip_text = ""


func rebuild_pile_view() -> void:
	_fill_pile_box(pile_draw_box, sim.draw_pile)
	_fill_pile_box(pile_discard_box, sim.discard_pile)


func _fill_pile_box(box: Control, pile: Array[String]) -> void:
	for child in box.get_children():
		box.remove_child(child)
		child.queue_free()
	for i in pile.size():
		var icon := TextureRect.new()
		icon.position = Vector2(float(i) * 26.0, 0.0)
		icon.size = Vector2(40, 54)
		icon.texture = _card_textures.get(pile[i])
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.modulate.a = 0.8
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(icon)


func refresh_slots() -> void:
	var ended := sim.state == BattleSimulationScript.BattleState.VICTORY or sim.state == BattleSimulationScript.BattleState.DEFEAT
	for i in 4:
		var button: Button = card_buttons[i]
		if i < sim.hand.size():
			var cost := int(BattleSimulationScript.CARD_DATA[sim.hand[i]].cost)
			button.disabled = sim.points < cost or ended
		else:
			button.disabled = true
	summon_button.disabled = sim.points < BattleSimulationScript.SUMMON_COST or sim.hand.size() >= BattleSimulationScript.HAND_SIZE or ended
	refresh_defense()


func refresh_defense() -> void:
	match sim.state:
		BattleSimulationScript.BattleState.VICTORY, BattleSimulationScript.BattleState.DEFEAT:
			defense_button.disabled = true
			defense_button.text = "R 重新开始"
		BattleSimulationScript.BattleState.RESOLVING:
			defense_button.disabled = true
			defense_button.text = "……"
		_:
			if sim.queued_defense != BattleSimulationScript.DefenseGrade.NONE:
				defense_button.disabled = true
				defense_button.text = "已就位"
			elif sim.defense_cooldown > 0.0:
				defense_button.disabled = true
				defense_button.text = "气息散乱 %.1f" % sim.defense_cooldown
			else:
				defense_button.disabled = false
				defense_button.text = "架势防范  [Space]"


func _card_short(id: String) -> String:
	var shorts := {"attack": "散怨", "shatter": "重斩", "guard": "凝滞", "shift": "续灯", "duannian": "断念", "dengxin": "挑芯", "zhuangzhong": "鸣钟", "anhun": "安魂"}
	return shorts.get(id, "符牌")


func _card_tip(id: String) -> String:
	var tips := {
		"attack": "散去 5 点怨气",
		"shatter": "斩去 12 点怨气；完美接刀后追加 6",
		"guard": "斩去 6 点怨气，鬼招短暂凝滞",
		"shift": "回复 7 点灯油",
		"duannian": "斩去 8 点怨气，弃一张手牌",
		"dengxin": "回复 4 点灯油",
		"zhuangzhong": "斩去 5 点怨气，凝滞 0.2 秒",
		"anhun": "净化：下一记鬼手改为可防范",
	}
	return tips.get(id, "符牌")


func _label(pos: Vector2, size: Vector2, font_size: int, color: Color, bold: bool) -> Label:
	var label := Label.new()
	label.position = pos
	label.size = size
	label.add_theme_font_size_override("font_size", font_size + (1 if bold else 0))
	label.add_theme_color_override("font_color", color)
	return label


func _style_box(bg: Color, border: Color, radius: int, width: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_color = border
	box.set_border_width_all(width)
	box.set_corner_radius_all(radius)
	return box
