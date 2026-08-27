extends CanvasLayer

## 战斗 HUD：状态栏、手牌槽、牌堆视图、消息、歇脚菜单与结算面板。
## 只读模拟层状态；玩家指令通过 command 回调提交。

const ASSET_FOLDER := "demo"
const CLASS_COLORS := {"斩": Color("e08a7a"), "御": Color("7fd4dc"), "佑": Color("aad18f")}
const BattleSimulationScript := preload("res://scripts/battle/battle_simulation.gd")

var sim: BattleSimulationScript
var command: Callable
var restart_cb: Callable

var root: Control
var player_status: Label
var enemy_status: Label
var resource_status: Label
var style_status: Label
var message_label: Label
var instruction_label: Label
var defense_button: Button
var summon_button: Button
var flash_rect: ColorRect
var card_buttons: Dictionary = {}
var slot_titles: Dictionary = {}
var slot_hints: Dictionary = {}
var slot_classes: Dictionary = {}
var pile_draw_box: Control
var pile_discard_box: Control
var settle_root: Control
var settle_title: Label
var settle_sub: Label
var _card_textures: Dictionary = {}
var menu_layer: CanvasLayer
var menu_root: Control
var menu_open := false
var message_serial := 0


func setup(s: BattleSimulationScript, command_cb: Callable, restart_callback: Callable) -> void:
	sim = s
	command = command_cb
	restart_cb = restart_callback
	_build_ui()
	_build_menu()
	_load_card_textures()
	rebuild_hand()
	rebuild_pile_view()
	refresh()


func _load_card_textures() -> void:
	for id in BattleSimulationScript.CARD_DATA:
		_card_textures[id] = load("res://assets/%s/card_%s.png" % [ASSET_FOLDER, id])


func _build_ui() -> void:
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var top_shade := ColorRect.new()
	top_shade.position = Vector2.ZERO
	top_shade.size = Vector2(1280, 96)
	top_shade.color = Color(0.025, 0.025, 0.035, 0.82)
	top_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(top_shade)

	player_status = _label(Vector2(34, 18), Vector2(300, 34), 24, Color("e8d7a1"), true)
	root.add_child(player_status)
	enemy_status = _label(Vector2(936, 18), Vector2(310, 34), 24, Color("e8d7a1"), true)
	enemy_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	root.add_child(enemy_status)
	resource_status = _label(Vector2(34, 54), Vector2(390, 28), 18, Color("c8aa64"), false)
	root.add_child(resource_status)
	style_status = _label(Vector2(470, 25), Vector2(340, 42), 19, Color("9caaa9"), true)
	style_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(style_status)
	style_status.text = "第一夜·雨巷老街"

	message_label = _label(Vector2(220, 456), Vector2(840, 65), 30, Color("f3deb1"), true)
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	message_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	message_label.add_theme_constant_override("shadow_offset_x", 3)
	message_label.add_theme_constant_override("shadow_offset_y", 3)
	root.add_child(message_label)

	var bottom := Panel.new()
	bottom.position = Vector2(0, 540)
	bottom.size = Vector2(1280, 180)
	bottom.add_theme_stylebox_override("panel", _style_box(Color(0.025, 0.026, 0.035, 0.96), Color("4e3f34"), 0, 2))
	root.add_child(bottom)

	instruction_label = _label(Vector2(24, 18), Vector2(246, 142), 16, Color("a9a49b"), false)
	instruction_label.text = "Space 架势防范\n1-4 消耗还愿出牌\n5 召符（2 点）\n按空则气息散乱\nR 重新开始\nEsc 菜单"
	instruction_label.visible = false
	bottom.add_child(instruction_label)

	var pile_draw_title := _label(Vector2(24, 14), Vector2(160, 22), 14, Color("8f8578"), false)
	pile_draw_title.text = "牌堆"
	bottom.add_child(pile_draw_title)
	pile_draw_box = Control.new()
	pile_draw_box.position = Vector2(24, 40)
	pile_draw_box.size = Vector2(240, 54)
	pile_draw_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_child(pile_draw_box)
	var pile_discard_title := _label(Vector2(24, 100), Vector2(160, 22), 14, Color("8f8578"), false)
	pile_discard_title.text = "弃牌堆"
	bottom.add_child(pile_discard_title)
	pile_discard_box = Control.new()
	pile_discard_box.position = Vector2(24, 126)
	pile_discard_box.size = Vector2(240, 54)
	pile_discard_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.add_child(pile_discard_box)

	for i in 4:
		_create_slot_button(bottom, i, Vector2(285 + i * 160, 12))
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
	bottom.add_child(defense_button)

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
	bottom.add_child(summon_button)

	flash_rect = ColorRect.new()
	flash_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash_rect.color = Color(1.0, 0.86, 0.57, 0.0)
	flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(flash_rect)


func _create_slot_button(parent: Control, slot: int, pos: Vector2) -> void:
	var button := Button.new()
	button.position = pos
	button.size = Vector2(142, 156)
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_stylebox_override("normal", _style_box(Color("151821"), Color("4a4438"), 12, 3))
	button.add_theme_stylebox_override("hover", _style_box(Color("222631"), Color("6a6250"), 12, 4))
	button.add_theme_stylebox_override("pressed", _style_box(Color("0d0f15"), Color("ead8a4"), 12, 5))
	button.pressed.connect(_on_slot_pressed.bind(slot))
	parent.add_child(button)

	var icon := TextureRect.new()
	icon.position = Vector2(31, 8)
	icon.size = Vector2(80, 80)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	button.add_child(icon)

	var title := _label(Vector2(8, 87), Vector2(126, 28), 20, Color("eee2c1"), true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(title)
	var hint := _label(Vector2(8, 117), Vector2(126, 30), 13, Color("a9a49b"), false)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(hint)
	var class_tag := _label(Vector2(10, 6), Vector2(34, 24), 15, Color.WHITE, true)
	class_tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(class_tag)
	card_buttons[slot] = button
	slot_titles[slot] = title
	slot_hints[slot] = hint
	slot_classes[slot] = class_tag


func _on_slot_pressed(slot: int) -> void:
	if slot >= 0 and slot < sim.hand.size():
		command.call({"type": "play_card", "id": sim.hand[slot]})


func rebuild_hand() -> void:
	for i in 4:
		var button: Button = card_buttons[i]
		var icon: TextureRect = button.get_child(0)
		var title: Label = slot_titles[i]
		var hint: Label = slot_hints[i]
		var class_tag: Label = slot_classes[i]
		if i < sim.hand.size():
			var id: String = sim.hand[i]
			var data: Dictionary = BattleSimulationScript.CARD_DATA[id]
			icon.texture = _card_textures.get(id)
			title.text = "%s  [%d]" % [data.title, i + 1]
			hint.text = "%s·%d点｜%s" % [data["class"], data.cost, _card_short(id)]
			class_tag.text = String(data["class"])
			class_tag.add_theme_color_override("font_color", CLASS_COLORS[data["class"]])
			button.tooltip_text = _card_tip(id)
			var col: Color = data.color
			button.add_theme_stylebox_override("normal", _style_box(Color("151821"), col.darkened(0.2), 12, 3))
			button.add_theme_stylebox_override("hover", _style_box(Color("222631"), col, 12, 4))
		else:
			icon.texture = null
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


func _card_short(id: String) -> String:
	var shorts := {"attack": "散怨", "shatter": "重斩", "guard": "凝滞", "shift": "续灯"}
	return shorts[id]


func _card_tip(id: String) -> String:
	var tips := {
		"attack": "散去 4 点怨气",
		"shatter": "斩去 12 点怨气；完美接刀后追加 6",
		"guard": "斩去 6 点怨气，鬼招短暂凝滞",
		"shift": "回复 7 点灯油",
	}
	return tips[id]


func refresh() -> void:
	player_status.text = "执灯人｜灯油 %d / %d" % [sim.player_hp, BattleSimulationScript.PLAYER_MAX_HP]
	enemy_status.text = "前任更夫｜怨气 %d / 46" % maxi(0, sim.enemy_hp)
	resource_status.text = "还愿 %d / %d    第 %d 招" % [sim.points, BattleSimulationScript.MAX_POINTS, sim.attack_index + 1]
	var ended := sim.state == BattleSimulationScript.BattleState.VICTORY or sim.state == BattleSimulationScript.BattleState.DEFEAT
	for i in 4:
		var button: Button = card_buttons[i]
		if i < sim.hand.size():
			var cost := int(BattleSimulationScript.CARD_DATA[sim.hand[i]].cost)
			button.disabled = sim.points < cost or ended
		else:
			button.disabled = true
	summon_button.disabled = sim.points < BattleSimulationScript.SUMMON_COST or sim.hand.size() >= BattleSimulationScript.HAND_SIZE or ended
	refresh_defense_button()


func refresh_defense_button() -> void:
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


func show_message(text: String, color: Color, duration: float) -> void:
	message_serial += 1
	var serial := message_serial
	message_label.text = text
	message_label.modulate = color
	message_label.modulate.a = 1.0
	message_label.scale = Vector2(1.08, 0.92)
	message_label.pivot_offset = message_label.size * 0.5
	var tween := create_tween().set_ignore_time_scale(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(message_label, "scale", Vector2.ONE, 0.14)
	tween.tween_interval(duration)
	tween.tween_property(message_label, "modulate:a", 0.0, 0.22)
	tween.tween_callback(func():
		if serial == message_serial:
			message_label.text = ""
	)


func flash(color: Color, alpha: float, duration: float) -> void:
	flash_rect.color = color
	flash_rect.color.a = alpha
	var tween := create_tween().set_ignore_time_scale(true)
	tween.tween_property(flash_rect, "color:a", 0.0, duration)


func _build_menu() -> void:
	menu_layer = CanvasLayer.new()
	menu_layer.layer = 10
	menu_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(menu_layer)
	menu_root = Control.new()
	menu_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu_root.visible = false
	menu_layer.add_child(menu_root)

	var dim := ColorRect.new()
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.0, 0.0, 0.0, 0.74)
	menu_root.add_child(dim)

	var panel := Panel.new()
	panel.position = Vector2(440, 150)
	panel.size = Vector2(400, 420)
	panel.add_theme_stylebox_override("panel", _style_box(Color(0.03, 0.03, 0.045, 0.97), Color("8a6a3a"), 16, 2))
	menu_root.add_child(panel)

	var title := _label(Vector2(20, 24), Vector2(360, 40), 26, Color("f1d185"), true)
	title.text = "歇  脚"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(title)

	var resume := Button.new()
	resume.position = Vector2(60, 92)
	resume.size = Vector2(280, 52)
	resume.focus_mode = Control.FOCUS_NONE
	resume.text = "继续  [Esc]"
	resume.add_theme_font_size_override("font_size", 20)
	resume.add_theme_stylebox_override("normal", _style_box(Color("2c211d"), Color("bd8b45"), 12, 2))
	resume.add_theme_stylebox_override("hover", _style_box(Color("493126"), Color("e0ad58"), 12, 3))
	resume.pressed.connect(toggle_menu)
	panel.add_child(resume)

	var restart := Button.new()
	restart.position = Vector2(60, 154)
	restart.size = Vector2(280, 52)
	restart.focus_mode = Control.FOCUS_NONE
	restart.text = "重新开始  [R]"
	restart.add_theme_font_size_override("font_size", 20)
	restart.add_theme_stylebox_override("normal", _style_box(Color("2c211d"), Color("bd8b45"), 12, 2))
	restart.add_theme_stylebox_override("hover", _style_box(Color("493126"), Color("e0ad58"), 12, 3))
	restart.pressed.connect(func():
		close_menu()
		restart_cb.call()
	)
	panel.add_child(restart)

	var vol_label := _label(Vector2(60, 228), Vector2(280, 26), 16, Color("a9a49b"), false)
	vol_label.text = "音效音量"
	panel.add_child(vol_label)
	var volume := HSlider.new()
	volume.position = Vector2(60, 258)
	volume.size = Vector2(280, 24)
	volume.min_value = 0.0
	volume.max_value = 1.0
	volume.step = 0.05
	volume.value = 0.8
	volume.focus_mode = Control.FOCUS_NONE
	volume.value_changed.connect(func(v: float): AudioServer.set_bus_volume_db(0, linear_to_db(maxf(v, 0.0001))))
	panel.add_child(volume)

	var shake_toggle := CheckButton.new()
	shake_toggle.position = Vector2(60, 296)
	shake_toggle.size = Vector2(280, 34)
	shake_toggle.text = "画面震动"
	shake_toggle.button_pressed = true
	shake_toggle.focus_mode = Control.FOCUS_NONE
	shake_toggle.toggled.connect(func(on: bool):
		var view := _find_view()
		if view:
			view.shake_enabled = on
	)
	panel.add_child(shake_toggle)

	var hint_toggle := CheckButton.new()
	hint_toggle.position = Vector2(60, 340)
	hint_toggle.size = Vector2(280, 34)
	hint_toggle.text = "操作提示"
	hint_toggle.button_pressed = false
	hint_toggle.focus_mode = Control.FOCUS_NONE
	hint_toggle.toggled.connect(func(on: bool): instruction_label.visible = on)
	panel.add_child(hint_toggle)

	settle_root = Control.new()
	settle_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	settle_root.visible = false
	settle_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_layer.add_child(settle_root)
	var settle_dim := ColorRect.new()
	settle_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	settle_dim.color = Color(0.0, 0.0, 0.0, 0.6)
	settle_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	settle_root.add_child(settle_dim)
	var settle_panel := Panel.new()
	settle_panel.position = Vector2(440, 200)
	settle_panel.size = Vector2(400, 300)
	settle_panel.add_theme_stylebox_override("panel", _style_box(Color(0.03, 0.03, 0.045, 0.97), Color("8a6a3a"), 16, 2))
	settle_root.add_child(settle_panel)
	settle_title = _label(Vector2(20, 44), Vector2(360, 48), 34, Color("f1d185"), true)
	settle_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	settle_panel.add_child(settle_title)
	settle_sub = _label(Vector2(20, 116), Vector2(360, 60), 17, Color("c8bb9d"), false)
	settle_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	settle_panel.add_child(settle_sub)
	var again := Button.new()
	again.position = Vector2(60, 206)
	again.size = Vector2(280, 52)
	again.focus_mode = Control.FOCUS_NONE
	again.text = "再入夜  [R]"
	again.add_theme_font_size_override("font_size", 20)
	again.add_theme_stylebox_override("normal", _style_box(Color("2c211d"), Color("bd8b45"), 12, 2))
	again.add_theme_stylebox_override("hover", _style_box(Color("493126"), Color("e0ad58"), 12, 3))
	again.pressed.connect(func():
		close_menu()
		restart_cb.call()
	)
	settle_panel.add_child(again)


func _find_view() -> Node:
	var parent := get_parent()
	if parent == null:
		return null
	for child in parent.get_children():
		if child.has_method("tick") and child.has_method("parry_feedback"):
			return child
	return null


func toggle_menu() -> void:
	menu_open = not menu_open
	menu_root.visible = menu_open
	get_tree().paused = menu_open


func close_menu() -> void:
	menu_open = false
	if menu_root:
		menu_root.visible = false
	get_tree().paused = false


func hide_settlement() -> void:
	if settle_root:
		settle_root.visible = false


func show_settlement(victory: bool) -> void:
	if victory:
		settle_title.text = "怨 已 归 还"
		settle_title.add_theme_color_override("font_color", Color("f1d185"))
		settle_sub.text = "灯油余 %d/%d · 历经 %d 招 · 完美接刀 x %d" % [sim.player_hp, BattleSimulationScript.PLAYER_MAX_HP, sim.attack_index + 1, sim.perfects]
	else:
		settle_title.text = "灯 灭 了"
		settle_title.add_theme_color_override("font_color", Color("cf5555"))
		settle_sub.text = "夜止于第 %d 招 · 完美接刀 x %d" % [sim.attack_index + 1, sim.perfects]
	settle_root.visible = true


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
