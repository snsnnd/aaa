extends Node2D

## 表现层：世界搭建、输入映射、动画、音频与 UI。
## 所有规则判断都在 BattleSimulation 中；本脚本只读状态、消费事件。

const BattleSimulationScript := preload("res://scripts/battle/battle_simulation.gd")
const VIEW_SIZE := Vector2(1280.0, 720.0)
const ASSET_FOLDER := "demo"

var sim: BattleSimulationScript

var camera: Camera2D
var background: Sprite2D
var player_sprite: Sprite2D
var enemy_sprite: Sprite2D
var weapon_pivot: Node2D
var weapon_sprite: Sprite2D
var ghost_hand: Node2D
var attack_trail: Line2D
var ui: CanvasLayer
var player_status: Label
var enemy_status: Label
var resource_status: Label
var style_status: Label
var intent_label: Label
var timing_label: Label
var message_label: Label
var instruction_label: Label
var defense_button: Button
var flash: ColorRect
var card_buttons: Dictionary = {}
var card_icons: Dictionary = {}
var parry_audio: AudioStreamPlayer
var hurt_audio: AudioStreamPlayer
var card_audio: AudioStreamPlayer
var warning_audio: AudioStreamPlayer
var lantern_glow: Sprite2D
var enemy_aura: Sprite2D
var fog_back: Line2D
var fog_front: Line2D
var rain_drops: Array[Line2D] = []
var noise := FastNoiseLite.new()
var trauma := 0.0
var shake_time := 0.0
var animation_time := 0.0
var message_serial := 0
var hitstop_running := false
var player_pivot: Node2D
var pose_x := 0.0
var pose_rot := 0.0
var impulse_x := 0.0
var impulse_rot := 0.0
var glow_boost := 0.0
var enemy_push := 0.0
var talismans: Array[Node2D] = []


func _ready() -> void:
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.seed = 4271
	sim = BattleSimulationScript.new()
	_build_world()
	_build_ui()
	_load_style()
	_apply_attack_presentation()
	_refresh_ui()
	if "--smoke-test" in OS.get_cmdline_user_args():
		call_deferred("_run_smoke_test")


func _exit_tree() -> void:
	Engine.time_scale = 1.0


func _process(delta: float) -> void:
	_update_ambient_animation(delta)
	_update_camera_shake(delta)
	_refresh_defense_button()
	for event: Dictionary in sim.step(delta):
		_handle_event(event)


func _input(event: InputEvent) -> void:
	if not event is InputEventKey:
		return
	if not event.pressed or event.echo:
		return
	if _handle_shortcut(event.keycode):
		get_viewport().set_input_as_handled()


func _handle_shortcut(keycode: Key) -> bool:
	match keycode:
		KEY_1:
			_submit({"type": "play_card", "id": "attack"})
		KEY_2:
			_submit({"type": "play_card", "id": "shatter"})
		KEY_3:
			_submit({"type": "play_card", "id": "guard"})
		KEY_4:
			_submit({"type": "play_card", "id": "shift"})
		KEY_SPACE:
			_submit({"type": "defend"})
		KEY_R:
			_restart_battle()
		_:
			return false
	return true


func _submit(command: Dictionary) -> void:
	for event: Dictionary in sim.submit(command):
		_handle_event(event)


func _handle_event(event: Dictionary) -> void:
	match String(event.get("type", "")):
		"attack_started":
			_apply_attack_presentation()
			enemy_push = 0.0
			warning_audio.play()
			_refresh_ui()
		"commit_cue":
			_commit_flash(_intent_color())
		"fake_release":
			_fake_release()
		"defense_queued":
			if int(event.grade) == BattleSimulationScript.DefenseGrade.PERFECT:
				_show_message("刀光将落——正是此刻", Color("f2d487"), 0.5)
			glow_boost = maxf(glow_boost, 0.18)
			_refresh_defense_button()
		"defense_miss":
			impulse_x = -20.0
			impulse_rot = -0.07
			_show_message("架势散乱……", Color("c15454"), 0.6)
		"impact":
			_present_impact(event)
		"enemy_staggered":
			enemy_sprite.modulate = Color("ffe9b0")
			create_tween().tween_property(enemy_sprite, "modulate", Color.WHITE, 0.5)
			trauma = minf(1.0, trauma + 0.2)
			_show_message("鬼身僵直", Color("f2d487"), 0.7)
		"stagger":
			_show_message("鬼招凝滞", Color("7fc5cd"), 0.6)
		"card_played":
			_present_card(event)
		"card_rejected":
			if String(event.get("reason", "")) == "ended":
				_show_message("胜负已分  [R]", Color("9e8b81"), 0.8)
			else:
				_show_message("愿力不足", Color("c15454"), 0.6)
		"action_finished":
			attack_trail.visible = false
			ghost_hand.visible = false
		"victory":
			attack_trail.visible = false
			ghost_hand.visible = false
			defense_button.disabled = true
			_show_message("怨已归还，天将明  [R]", Color("f1d185"), 5.0)
		"defeat":
			attack_trail.visible = false
			ghost_hand.visible = false
			defense_button.disabled = true
			_show_message("灯灭了……  [R]", Color("cf5555"), 5.0)


func _present_impact(event: Dictionary) -> void:
	var grade: int = int(event.grade)
	var contact := _contact_point()
	match grade:
		BattleSimulationScript.DefenseGrade.SUCCESS:
			_parry_feedback(contact, false)
			impulse_x = -18.0
			glow_boost = maxf(glow_boost, 0.45)
			enemy_push = 26.0
			_snap_ghost_hand_back()
			_show_message("化解｜还愿 +1", _intent_color().lightened(0.30), 0.6)
		BattleSimulationScript.DefenseGrade.PERFECT:
			_parry_feedback(contact, true)
			_hit_stop(0.11, 0.06)
			impulse_x = -10.0
			glow_boost = 1.0
			player_sprite.modulate = Color("fff2c4")
			create_tween().tween_property(player_sprite, "modulate", Color.WHITE, 0.24).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
			enemy_push = 55.0
			_snap_ghost_hand_back()
			_show_message("完美接刀｜还愿 +2", Color("f2d487"), 0.8)
		_:
			_take_hit(int(event.damage))
	_refresh_ui()


func _contact_point() -> Vector2:
	return player_pivot.position + Vector2(122.0, -14.0)


func _snap_ghost_hand_back() -> void:
	if not ghost_hand.visible:
		return
	var back := enemy_sprite.position + Vector2(-6, -8)
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(ghost_hand, "position", back, 0.16)
	tw.tween_property(ghost_hand, "scale", Vector2(0.3, 0.6), 0.16)
	tw.chain().tween_callback(func(): ghost_hand.visible = false)


func _present_card(event: Dictionary) -> void:
	card_audio.play()
	var id := String(event.id)
	_spawn_talisman(id)
	var data: Dictionary = BattleSimulationScript.CARD_DATA[id]
	if id == "shift":
		if int(event.healed) > 0:
			_show_message("续灯｜灯油 +%d" % int(event.healed), data.color, 0.7)
		else:
			_show_message("灯火已盈", data.color, 0.5)
	elif id == "shatter" and bool(event.get("charged", false)):
		_small_enemy_hit(0.32)
		_show_message("还刃·乘势｜怨气 -%d" % int(event.damage), data.color, 0.8)
	else:
		_small_enemy_hit(0.16)
		var verb := "散去" if id == "attack" else "斩去"
		_show_message("%s｜%s %d 点怨气" % [data.title, verb, int(event.damage)], data.color, 0.6)
	_refresh_ui()


func _spawn_talisman(id: String) -> void:
	var color: Color = BattleSimulationScript.CARD_DATA[id].color
	var tal := Node2D.new()
	tal.position = player_pivot.position + Vector2(74, 4)
	tal.z_index = 15
	var paper := Polygon2D.new()
	paper.polygon = PackedVector2Array([Vector2(-7, -11), Vector2(7, -11), Vector2(7, 11), Vector2(-7, 11)])
	paper.color = Color("efe3bd")
	tal.add_child(paper)
	var stripe := Line2D.new()
	stripe.points = PackedVector2Array([Vector2(0, -8), Vector2(0, 8)])
	stripe.width = 3.5
	stripe.default_color = color
	tal.add_child(stripe)
	var trail := Line2D.new()
	trail.width = 5.0
	trail.default_color = Color(color, 0.5)
	trail.begin_cap_mode = Line2D.LINE_CAP_ROUND
	trail.end_cap_mode = Line2D.LINE_CAP_ROUND
	add_child(trail)
	add_child(tal)
	tal.set_meta("trail", trail)
	talismans.append(tal)
	if id == "shift":
		var tw := create_tween()
		tw.tween_property(tal, "position", tal.position + Vector2(34, -130), 0.14).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.tween_property(tal, "position", lantern_glow.position, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_callback(func():
			glow_boost = 0.85
			_finish_talisman(tal)
		)
	else:
		var target := Vector2(randf_range(830.0, 890.0), randf_range(270.0, 330.0))
		var tw := create_tween()
		tw.tween_property(tal, "position", target, 0.26).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(tal, "rotation", randf_range(-1.2, 1.2), 0.26)
		tw.tween_callback(func(): _finish_talisman(tal))


func _finish_talisman(tal: Node2D) -> void:
	talismans.erase(tal)
	if not is_instance_valid(tal):
		return
	var trail: Line2D = tal.get_meta("trail")
	var fade := create_tween().set_parallel(true)
	fade.tween_property(trail, "modulate:a", 0.0, 0.22)
	fade.tween_property(tal, "modulate:a", 0.0, 0.12)
	fade.chain().tween_callback(func():
		trail.queue_free()
		tal.queue_free()
	)


func _intent_color() -> Color:
	return sim.current_intent.color


func _build_world() -> void:
	camera = Camera2D.new()
	camera.position = VIEW_SIZE * 0.5
	camera.enabled = true
	add_child(camera)

	background = Sprite2D.new()
	background.position = VIEW_SIZE * 0.5
	background.scale = Vector2(2.0 / 3.0, 2.0 / 3.0)
	background.z_index = -10
	add_child(background)

	var ground_tint := Polygon2D.new()
	ground_tint.polygon = PackedVector2Array([Vector2(0, 430), Vector2(1280, 430), Vector2(1280, 555), Vector2(0, 555)])
	ground_tint.color = Color(0.03, 0.04, 0.055, 0.18)
	ground_tint.z_index = -2
	add_child(ground_tint)

	fog_back = Line2D.new()
	fog_back.points = PackedVector2Array([Vector2(-220, 315), Vector2(420, 298), Vector2(980, 330), Vector2(1510, 306)])
	fog_back.width = 72.0
	fog_back.default_color = Color(0.38, 0.55, 0.56, 0.045)
	fog_back.antialiased = true
	fog_back.z_index = -4
	add_child(fog_back)
	fog_front = Line2D.new()
	fog_front.points = PackedVector2Array([Vector2(-260, 465), Vector2(350, 442), Vector2(940, 478), Vector2(1540, 449)])
	fog_front.width = 54.0
	fog_front.default_color = Color(0.55, 0.58, 0.55, 0.032)
	fog_front.antialiased = true
	fog_front.z_index = 2
	add_child(fog_front)

	player_pivot = Node2D.new()
	player_pivot.position = Vector2(264, 355)
	player_pivot.z_index = 1
	add_child(player_pivot)
	player_sprite = Sprite2D.new()
	player_sprite.position = Vector2.ZERO
	player_sprite.scale = Vector2(0.49, 0.49)
	player_pivot.add_child(player_sprite)

	enemy_sprite = Sprite2D.new()
	enemy_sprite.position = Vector2(1006, 350)
	enemy_sprite.scale = Vector2(0.49, 0.49)
	enemy_sprite.z_index = 1
	add_child(enemy_sprite)

	weapon_pivot = Node2D.new()
	weapon_pivot.position = enemy_sprite.position + Vector2(38, -28)
	weapon_pivot.rotation = -0.45
	weapon_pivot.z_index = 3
	add_child(weapon_pivot)
	weapon_sprite = Sprite2D.new()
	weapon_sprite.position = Vector2(0, 98)
	weapon_sprite.scale = Vector2(0.49, 0.49)
	weapon_pivot.add_child(weapon_sprite)

	ghost_hand = _create_ghost_hand()
	ghost_hand.position = enemy_sprite.position + Vector2(-6, -8)
	ghost_hand.visible = false
	ghost_hand.z_index = 3
	add_child(ghost_hand)

	lantern_glow = Sprite2D.new()
	lantern_glow.texture = _make_glow_texture(Color(1.0, 0.42, 0.08, 0.48))
	lantern_glow.position = player_sprite.position + Vector2(118, 112)
	lantern_glow.scale = Vector2(2.35, 2.35)
	var lantern_material := CanvasItemMaterial.new()
	lantern_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	lantern_glow.material = lantern_material
	lantern_glow.z_index = 0
	add_child(lantern_glow)
	enemy_aura = Sprite2D.new()
	enemy_aura.texture = _make_glow_texture(Color(0.15, 0.62, 0.66, 0.25))
	enemy_aura.position = enemy_sprite.position + Vector2(-12, -30)
	enemy_aura.scale = Vector2(2.8, 3.4)
	var aura_material := CanvasItemMaterial.new()
	aura_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	enemy_aura.material = aura_material
	enemy_aura.z_index = 0
	add_child(enemy_aura)

	attack_trail = Line2D.new()
	attack_trail.position = Vector2(1008, 310)
	attack_trail.points = PackedVector2Array([Vector2.ZERO, Vector2(-205, 0)])
	attack_trail.width = 18.0
	attack_trail.default_color = Color("bd3d45")
	attack_trail.begin_cap_mode = Line2D.LINE_CAP_ROUND
	attack_trail.end_cap_mode = Line2D.LINE_CAP_ROUND
	attack_trail.visible = false
	attack_trail.z_index = 3
	add_child(attack_trail)
	_create_rain()

	parry_audio = _audio_player("res://assets/demo/audio/parry.wav")
	hurt_audio = _audio_player("res://assets/demo/audio/hurt.wav")
	card_audio = _audio_player("res://assets/demo/audio/card.wav")
	warning_audio = _audio_player("res://assets/demo/audio/warning.wav")


func _build_ui() -> void:
	ui = CanvasLayer.new()
	add_child(ui)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(root)

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

	var intent_panel := Panel.new()
	intent_panel.position = Vector2(803, 106)
	intent_panel.size = Vector2(435, 58)
	intent_panel.add_theme_stylebox_override("panel", _style_box(Color(0.025, 0.03, 0.04, 0.90), Color("755335"), 16, 2))
	root.add_child(intent_panel)
	intent_label = _label(Vector2(20, 10), Vector2(395, 30), 21, Color("efe1bf"), true)
	intent_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	intent_panel.add_child(intent_label)

	var timing_panel := Panel.new()
	timing_panel.position = Vector2(377, 112)
	timing_panel.size = Vector2(402, 72)
	timing_panel.add_theme_stylebox_override("panel", _style_box(Color(0.02, 0.025, 0.035, 0.90), Color("6f5a3f"), 16, 2))
	root.add_child(timing_panel)
	timing_label = _label(Vector2(14, 8), Vector2(374, 55), 22, Color("e6d8b7"), true)
	timing_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	timing_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	timing_panel.add_child(timing_label)

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
	instruction_label.text = "Space 架势防范\n1-4 消耗还愿出牌\n按空则气息散乱\nR 重新开始"
	bottom.add_child(instruction_label)

	var ids := ["attack", "shatter", "guard", "shift"]
	for i in ids.size():
		_create_card_button(bottom, ids[i], Vector2(285 + i * 160, 12))

	defense_button = Button.new()
	defense_button.position = Vector2(975, 38)
	defense_button.size = Vector2(264, 92)
	defense_button.focus_mode = Control.FOCUS_NONE
	defense_button.add_theme_font_size_override("font_size", 20)
	defense_button.add_theme_stylebox_override("normal", _style_box(Color("2c211d"), Color("bd8b45"), 15, 3))
	defense_button.add_theme_stylebox_override("hover", _style_box(Color("493126"), Color("e0ad58"), 15, 4))
	defense_button.add_theme_stylebox_override("disabled", _style_box(Color("17171d"), Color("47434a"), 15, 2))
	defense_button.pressed.connect(func(): _submit({"type": "defend"}))
	bottom.add_child(defense_button)

	flash = ColorRect.new()
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash.color = Color(1.0, 0.86, 0.57, 0.0)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(flash)


func _create_card_button(parent: Control, id: String, pos: Vector2) -> void:
	var data: Dictionary = BattleSimulationScript.CARD_DATA[id]
	var hints := {
		"attack": "1点｜散怨",
		"shatter": "3点｜重斩",
		"guard": "2点｜凝滞",
		"shift": "2点｜续灯",
	}
	var tooltips := {
		"attack": "散去 4 点怨气",
		"shatter": "斩去 12 点怨气；完美接刀后追加 6",
		"guard": "斩去 6 点怨气，鬼招短暂凝滞",
		"shift": "回复 7 点灯油",
	}
	var button := Button.new()
	button.position = pos
	button.size = Vector2(142, 156)
	button.focus_mode = Control.FOCUS_NONE
	button.tooltip_text = tooltips[id]
	button.add_theme_stylebox_override("normal", _style_box(Color("151821"), data.color.darkened(0.2), 12, 3))
	button.add_theme_stylebox_override("hover", _style_box(Color("222631"), data.color, 12, 4))
	button.add_theme_stylebox_override("pressed", _style_box(Color("0d0f15"), Color("ead8a4"), 12, 5))
	button.pressed.connect(func(): _submit({"type": "play_card", "id": id}))
	parent.add_child(button)

	var icon := TextureRect.new()
	icon.position = Vector2(31, 8)
	icon.size = Vector2(80, 80)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(icon)
	card_icons[id] = icon

	var title := _label(Vector2(8, 87), Vector2(126, 28), 20, Color("eee2c1"), true)
	title.text = "%s  [%s]" % [data.title, data.key]
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(title)
	var hint := _label(Vector2(8, 117), Vector2(126, 30), 13, Color("a9a49b"), false)
	hint.text = hints[id]
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(hint)
	card_buttons[id] = button


func _load_style() -> void:
	var folder := ASSET_FOLDER
	background.texture = load("res://assets/%s/background_old_street.png" % folder)
	player_sprite.texture = load("res://assets/%s/player_keeper.png" % folder)
	enemy_sprite.texture = load("res://assets/%s/enemy_watchman.png" % folder)
	weapon_sprite.texture = load("res://assets/%s/enemy_blade.png" % folder)
	background.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	player_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	enemy_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	weapon_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	for id in card_icons:
		var icon: TextureRect = card_icons[id]
		icon.texture = load("res://assets/%s/card_%s.png" % [folder, id])
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	style_status.text = "第一夜·雨巷老街"


func _apply_attack_presentation() -> void:
	attack_trail.visible = false
	attack_trail.points = PackedVector2Array([Vector2.ZERO, Vector2(-205, 0)])
	attack_trail.modulate = Color.WHITE
	attack_trail.default_color = _intent_color()
	weapon_sprite.modulate = Color.WHITE
	ghost_hand.visible = false
	_reset_enemy_pose()
	intent_label.text = "敌意图：%s" % sim.current_intent.title
	timing_label.modulate = _intent_color().lightened(0.35)
	match String(sim.current_intent.id):
		"red":
			timing_label.text = "怨气凝刃，蓄而未发"
		"blue":
			timing_label.text = "残影连闪，刀势不停"
		"green":
			timing_label.text = "刀光是虚，鬼手是真"


func _update_enemy_attack_visuals() -> void:
	var duration: float = sim.current_intent.duration
	var ratio := clampf(sim.attack_elapsed / duration, 0.0, 1.0)
	match String(sim.current_intent.id):
		"red":
			_update_red_slow_blade(ratio)
		"blue":
			_update_blue_combo(ratio)
		"green":
			_update_green_grab(ratio)


func _update_red_slow_blade(ratio: float) -> void:
	if ratio < 0.36:
		var raise := smoothstep(0.0, 0.36, ratio)
		weapon_pivot.rotation = lerpf(-0.45, -2.22, raise)
		enemy_sprite.position.x = lerpf(1006.0, 1016.0, raise)
		enemy_sprite.rotation = lerpf(0.0, 0.045, raise)
	elif ratio < 0.68:
		var hold := (ratio - 0.36) / 0.32
		weapon_pivot.rotation = -2.22 + sin(hold * PI * 7.0) * 0.018
		enemy_sprite.position.x = 1016.0 + sin(hold * PI * 5.0) * 1.5
		enemy_sprite.rotation = 0.045 + sin(hold * PI * 5.0) * 0.004
	else:
		var commit := smoothstep(0.68, 1.0, ratio)
		weapon_pivot.rotation = lerpf(-2.22, 1.45, commit)
		enemy_sprite.position.x = lerpf(1016.0, 530.0, commit)
		enemy_sprite.rotation = lerpf(0.045, -0.18, commit)
	attack_trail.visible = ratio > 0.74
	attack_trail.points = PackedVector2Array([Vector2.ZERO, Vector2(-300, 0)])
	attack_trail.position = enemy_sprite.position + Vector2(8, -30)
	attack_trail.rotation = weapon_pivot.rotation + PI * 0.5
	attack_trail.width = 8.0 + 20.0 * maxf(0.0, (ratio - 0.74) / 0.26)
	attack_trail.default_color = Color("ead79c")
	attack_trail.modulate.a = clampf((ratio - 0.74) / 0.12, 0.0, 0.8)
	weapon_pivot.position = enemy_sprite.position + Vector2(38, -28)


func _update_blue_combo(ratio: float) -> void:
	var strike_time := 0.82 if sim.strike_index == 0 else 1.56
	var start_time := 0.0 if sim.strike_index == 0 else 0.82
	var reach := 380.0 if sim.strike_index == 0 else 420.0
	var phase := clampf((sim.attack_elapsed - start_time) / (strike_time - start_time), 0.0, 1.0)
	var commit := clampf((phase - 0.56) / 0.44, 0.0, 1.0)
	if phase < 0.56:
		weapon_pivot.rotation = lerpf(0.35 if sim.strike_index > 0 else -0.45, -1.62, smoothstep(0.0, 0.56, phase))
	else:
		weapon_pivot.rotation = lerpf(-1.62, 1.15, smoothstep(0.0, 1.0, commit))
	enemy_sprite.position.x = 1006.0 - sin(commit * PI) * reach
	enemy_sprite.rotation = -sin(commit * PI) * 0.085
	var time_to_hit := strike_time - sim.attack_elapsed
	attack_trail.visible = time_to_hit <= 0.13 and time_to_hit >= -0.05
	attack_trail.points = PackedVector2Array([Vector2.ZERO, Vector2(-290, 0)])
	attack_trail.position = enemy_sprite.position + Vector2(18, -26)
	attack_trail.rotation = weapon_pivot.rotation + PI * 0.5
	attack_trail.width = 12.0
	attack_trail.default_color = _intent_color().lightened(0.35)
	attack_trail.modulate.a = 0.68
	weapon_pivot.position = enemy_sprite.position + Vector2(38, -28)


func _update_green_grab(ratio: float) -> void:
	attack_trail.visible = false
	if ratio < 0.42:
		var fake_raise := smoothstep(0.0, 0.42, ratio)
		weapon_pivot.rotation = lerpf(-0.45, -2.02, fake_raise)
		enemy_sprite.rotation = fake_raise * 0.04
		ghost_hand.visible = false
	elif ratio < 0.60:
		var cancel := smoothstep(0.42, 0.60, ratio)
		weapon_pivot.rotation = lerpf(-2.02, -0.20, cancel)
		enemy_sprite.rotation = lerpf(0.04, -0.02, cancel)
		ghost_hand.visible = cancel > 0.62
		ghost_hand.position = enemy_sprite.position + Vector2(-6, -8)
		ghost_hand.scale = Vector2(0.55, 0.8)
	else:
		var reach := smoothstep(0.60, 1.0, ratio)
		weapon_pivot.rotation = -0.20
		enemy_sprite.position.x = lerpf(1006.0, 940.0, reach)
		enemy_sprite.rotation = lerpf(-0.02, -0.09, reach)
		ghost_hand.visible = true
		ghost_hand.position = enemy_sprite.position.lerp(enemy_sprite.position + Vector2(-505, -18), reach)
		ghost_hand.scale = Vector2(lerpf(0.55, 1.3, reach), lerpf(0.8, 1.0, reach))
	weapon_pivot.position = enemy_sprite.position + Vector2(38, -28)


func _commit_flash(color: Color) -> void:
	warning_audio.play()
	weapon_sprite.modulate = Color("fff1bd")
	var tween := create_tween().set_ignore_time_scale(true).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.tween_property(weapon_sprite, "modulate", Color.WHITE, 0.16)
	if sim.current_intent.id == "green" and ghost_hand.visible:
		ghost_hand.modulate = color.lightened(0.35)
		create_tween().set_ignore_time_scale(true).tween_property(ghost_hand, "modulate", Color.WHITE, 0.18)


func _fake_release() -> void:
	trauma = minf(1.0, trauma + 0.035)
	warning_audio.play()
	weapon_sprite.modulate = Color("cf4b4f")
	create_tween().set_ignore_time_scale(true).tween_property(weapon_sprite, "modulate", Color.WHITE, 0.20).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)


func _take_hit(damage: int) -> void:
	hurt_audio.play()
	trauma = minf(1.0, trauma + 0.58)
	impulse_x = -34.0
	impulse_rot = -0.13
	glow_boost = -0.7
	flash.color = Color(0.75, 0.08, 0.08, 0.30)
	var flash_tween := create_tween().set_ignore_time_scale(true)
	flash_tween.tween_property(flash, "color:a", 0.0, 0.22)
	player_sprite.modulate = Color(1.0, 0.35, 0.35)
	create_tween().tween_property(player_sprite, "modulate", Color.WHITE, 0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_show_message("灯油 -%d" % damage, Color("d85151"), 0.75)


func _small_enemy_hit(strength: float) -> void:
	trauma = minf(1.0, trauma + strength)
	enemy_sprite.modulate = Color("ffd59a")
	create_tween().tween_property(enemy_sprite, "modulate", Color.WHITE, 0.18).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)


func _parry_feedback(pos: Vector2, major: bool) -> void:
	parry_audio.play()
	trauma = minf(1.0, trauma + (0.82 if major else 0.48))
	flash.color = Color(1.0, 0.88, 0.56, 0.68 if major else 0.34)
	var flash_tween := create_tween().set_ignore_time_scale(true)
	flash_tween.tween_property(flash, "color:a", 0.0, 0.18 if major else 0.10)
	_spawn_parry_burst(pos, _intent_color(), 22 if major else 11)
	var original_scale := enemy_sprite.scale
	enemy_sprite.scale = original_scale * Vector2(1.08, 0.92)
	create_tween().tween_property(enemy_sprite, "scale", original_scale, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _spawn_parry_burst(pos: Vector2, color: Color, count: int) -> void:
	var burst := Node2D.new()
	burst.position = pos
	burst.z_index = 20
	add_child(burst)
	for i in count:
		var shard := Line2D.new()
		var angle := TAU * float(i) / float(count) + randf_range(-0.10, 0.10)
		var length := randf_range(44.0, 132.0)
		shard.points = PackedVector2Array([Vector2.ZERO, Vector2.RIGHT.rotated(angle) * length])
		shard.width = randf_range(2.0, 7.0)
		shard.default_color = color.lightened(randf_range(0.15, 0.65))
		burst.add_child(shard)
	var ring := Line2D.new()
	var ring_points := PackedVector2Array()
	for i in 33:
		var angle := TAU * float(i) / 32.0
		ring_points.append(Vector2.RIGHT.rotated(angle) * 72.0)
	ring.points = ring_points
	ring.width = 5.0
	ring.default_color = Color("ffe7a3")
	burst.add_child(ring)
	for angle in [-0.55, 0.55]:
		var slash := Line2D.new()
		slash.points = PackedVector2Array([Vector2.RIGHT.rotated(angle) * -108.0, Vector2.RIGHT.rotated(angle) * 108.0])
		slash.width = 7.0
		slash.default_color = Color("fff4ca")
		burst.add_child(slash)
	burst.scale = Vector2(0.26, 0.26)
	var tween := create_tween().set_parallel(true).set_ignore_time_scale(true)
	tween.tween_property(burst, "scale", Vector2(1.45, 1.45), 0.30).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tween.tween_property(burst, "modulate:a", 0.0, 0.28).set_delay(0.12)
	tween.chain().tween_callback(burst.queue_free)


func _hit_stop(duration: float, time_scale: float) -> void:
	if hitstop_running:
		return
	hitstop_running = true
	Engine.time_scale = time_scale
	await get_tree().create_timer(duration, true, false, true).timeout
	Engine.time_scale = 1.0
	hitstop_running = false


func _make_glow_texture(color: Color) -> ImageTexture:
	var image := Image.create(128, 128, false, Image.FORMAT_RGBA8)
	for y in 128:
		for x in 128:
			var distance := Vector2(x - 63.5, y - 63.5).length() / 63.5
			var alpha := pow(maxf(0.0, 1.0 - distance), 2.4) * color.a
			image.set_pixel(x, y, Color(color.r, color.g, color.b, alpha))
	return ImageTexture.create_from_image(image)


func _create_rain() -> void:
	for i in 74:
		var drop := Line2D.new()
		drop.points = PackedVector2Array([Vector2.ZERO, Vector2(-5, randf_range(18.0, 34.0))])
		drop.width = randf_range(1.0, 2.2)
		drop.default_color = Color(0.48, 0.64, 0.68, randf_range(0.12, 0.32))
		drop.position = Vector2(randf_range(-40.0, 1320.0), randf_range(-720.0, 720.0))
		drop.set_meta("speed", randf_range(0.72, 1.28))
		drop.z_index = 4
		add_child(drop)
		rain_drops.append(drop)


func _create_ghost_hand() -> Node2D:
	var hand := Node2D.new()
	var palm := Polygon2D.new()
	palm.polygon = PackedVector2Array([Vector2(-72, -34), Vector2(-118, -24), Vector2(-140, 2), Vector2(-112, 30), Vector2(-68, 28), Vector2(-48, 0)])
	palm.color = Color(0.30, 0.55, 0.36, 0.72)
	hand.add_child(palm)
	for i in 4:
		var finger := Line2D.new()
		var y := -25.0 + i * 16.0
		finger.points = PackedVector2Array([Vector2(-105, y), Vector2(-166 - i * 8, y - 18 + i * 9)])
		finger.width = 10.0 - i * 0.8
		finger.default_color = Color(0.42, 0.68, 0.44, 0.78)
		finger.begin_cap_mode = Line2D.LINE_CAP_ROUND
		finger.end_cap_mode = Line2D.LINE_CAP_ROUND
		hand.add_child(finger)
	return hand


func _update_ambient_animation(delta: float) -> void:
	animation_time += delta
	player_sprite.position = Vector2(0.0, sin(animation_time * 1.65) * 3.0)
	player_sprite.rotation = sin(animation_time * 1.25) * 0.006
	if sim.state == BattleSimulationScript.BattleState.WINDUP:
		_update_enemy_attack_visuals()
		if sim.stagger_remaining > 0.0:
			weapon_pivot.rotation = lerpf(weapon_pivot.rotation, 0.62, minf(1.0, delta * 6.0))
			enemy_sprite.rotation = lerpf(enemy_sprite.rotation, 0.06, minf(1.0, delta * 6.0))
	else:
		var settle := minf(1.0, delta * 8.0)
		enemy_sprite.position.x = lerpf(enemy_sprite.position.x, 1006.0 + enemy_push, settle)
		enemy_sprite.rotation = lerpf(enemy_sprite.rotation, 0.0, settle)
		weapon_pivot.position = weapon_pivot.position.lerp(enemy_sprite.position + Vector2(38, -28), settle)
		weapon_pivot.rotation = lerpf(weapon_pivot.rotation, -0.45, settle)
		if sim.state != BattleSimulationScript.BattleState.RESOLVING:
			enemy_sprite.position.y = 350.0 + sin(animation_time * 1.22 + 1.7) * 5.0
			weapon_pivot.rotation += sin(animation_time * 0.88 + 0.7) * -0.006
	_update_player_combat_pose(delta)
	glow_boost = lerpf(glow_boost, 0.0, minf(1.0, delta * 3.0))
	var flicker := sin(animation_time * 9.7) * 0.08 + sin(animation_time * 15.1) * 0.04
	background.position.x = 640.0 + sin(animation_time * 0.10) * 2.5
	lantern_glow.position = player_pivot.position + Vector2(118, 112)
	lantern_glow.scale = Vector2.ONE * (2.35 * (1.0 + 0.38 * glow_boost))
	lantern_glow.modulate.a = clampf((0.76 + flicker) * (1.0 + 0.5 * glow_boost), 0.18, 1.0)
	enemy_aura.position = enemy_sprite.position + Vector2(-12, -30)
	enemy_aura.modulate.a = 0.50 + sin(animation_time * 1.8) * 0.12
	fog_back.position.x = fmod(animation_time * 7.0, 420.0) - 210.0
	fog_front.position.x = 210.0 - fmod(animation_time * 10.0, 420.0)
	for drop in rain_drops:
		var speed: float = drop.get_meta("speed")
		drop.position += Vector2(-72.0, 520.0) * speed * delta
		if drop.position.y > 760.0:
			drop.position = Vector2(randf_range(0.0, 1340.0), randf_range(-180.0, -20.0))
	_update_talisman_trails()


func _update_player_combat_pose(delta: float) -> void:
	var guard := sim.queued_defense != BattleSimulationScript.DefenseGrade.NONE
	var brace := false
	if sim.state == BattleSimulationScript.BattleState.WINDUP and not guard:
		var ratio := clampf(sim.attack_elapsed / float(sim.current_intent.duration), 0.0, 1.0)
		match String(sim.current_intent.id):
			"red", "green":
				brace = ratio > 0.60
			"blue":
				brace = sim.attack_elapsed > 0.45
	var target_x := 26.0 if guard else (12.0 if brace else 0.0)
	var target_rot := 0.05 if guard else (0.022 if brace else 0.0)
	pose_x = lerpf(pose_x, target_x, minf(1.0, delta * 12.0))
	pose_rot = lerpf(pose_rot, target_rot, minf(1.0, delta * 12.0))
	impulse_x = lerpf(impulse_x, 0.0, minf(1.0, delta * 6.5))
	impulse_rot = lerpf(impulse_rot, 0.0, minf(1.0, delta * 8.0))
	player_pivot.position = Vector2(264.0 + pose_x + impulse_x, 355.0)
	player_pivot.rotation = pose_rot + impulse_rot


func _update_talisman_trails() -> void:
	for tal in talismans.duplicate():
		if not is_instance_valid(tal):
			talismans.erase(tal)
			continue
		var trail: Line2D = tal.get_meta("trail")
		trail.add_point(tal.position)
		if trail.get_point_count() > 14:
			trail.remove_point(0)


func _update_camera_shake(delta: float) -> void:
	if trauma <= 0.0:
		camera.offset = Vector2.ZERO
		camera.rotation = 0.0
		return
	trauma = maxf(0.0, trauma - delta * 1.55)
	shake_time += delta * 46.0
	var amount := trauma * trauma
	camera.offset = Vector2(
		noise.get_noise_2d(shake_time, 0.0) * 17.0 * amount,
		noise.get_noise_2d(0.0, shake_time) * 11.0 * amount
	)
	camera.rotation = noise.get_noise_2d(shake_time, shake_time) * 0.018 * amount


func _restart_battle() -> void:
	Engine.time_scale = 1.0
	trauma = 0.0
	pose_x = 0.0
	pose_rot = 0.0
	impulse_x = 0.0
	impulse_rot = 0.0
	glow_boost = 0.0
	enemy_push = 0.0
	player_sprite.modulate = Color.WHITE
	enemy_sprite.modulate = Color.WHITE
	sim.restart()
	_apply_attack_presentation()
	warning_audio.play()
	_refresh_ui()
	_show_message("夜还长，刀再来", Color("e2cf9c"), 1.0)


func _reset_enemy_pose() -> void:
	enemy_sprite.position = Vector2(1006, 350)
	enemy_sprite.rotation = 0.0
	weapon_pivot.position = enemy_sprite.position + Vector2(38, -28)
	weapon_pivot.rotation = -0.45
	weapon_sprite.modulate = Color.WHITE
	ghost_hand.position = enemy_sprite.position + Vector2(-6, -8)
	ghost_hand.scale = Vector2.ONE
	ghost_hand.modulate = Color.WHITE
	ghost_hand.visible = false


func _refresh_ui() -> void:
	player_status.text = "执灯人｜灯油 %d / %d" % [sim.player_hp, BattleSimulationScript.PLAYER_MAX_HP]
	enemy_status.text = "前任更夫｜怨气 %d / 46" % maxi(0, sim.enemy_hp)
	resource_status.text = "还愿 %d / %d    第 %d 招" % [sim.points, BattleSimulationScript.MAX_POINTS, sim.attack_index + 1]
	for id in card_buttons:
		var button: Button = card_buttons[id]
		button.disabled = sim.points < int(BattleSimulationScript.CARD_DATA[id].cost) or sim.state == BattleSimulationScript.BattleState.VICTORY or sim.state == BattleSimulationScript.BattleState.DEFEAT


func _refresh_defense_button() -> void:
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


func _show_message(text: String, color: Color, duration: float) -> void:
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


func _audio_player(path: String) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.stream = load(path)
	add_child(player)
	return player


func _run_smoke_test() -> void:
	var s := BattleSimulationScript.new()
	assert(background.texture != null and player_sprite.texture != null and enemy_sprite.texture != null and weapon_sprite.texture != null)
	assert(s.state == BattleSimulationScript.BattleState.WINDUP)
	assert(s.points == 0)
	var events: Array = s.submit({"type": "defend"})
	assert(s.defense_cooldown > 0.0 and s.queued_defense == BattleSimulationScript.DefenseGrade.NONE)
	s.defense_cooldown = 0.0
	s.attack_elapsed = float(s.current_intent.duration) - 0.20
	events = s.submit({"type": "defend"})
	assert(s.queued_defense == BattleSimulationScript.DefenseGrade.SUCCESS)
	events = s.step(1.0)
	assert(s.points == 1 and s.player_hp == BattleSimulationScript.PLAYER_MAX_HP)
	_assert_has(events, "impact")
	events = s.submit({"type": "play_card", "id": "attack"})
	assert(s.points == 0 and s.enemy_hp == 42)
	s.restart()
	s.attack_index = 1
	s._begin_attack()
	s.attack_elapsed = 0.82 - 0.04
	s.submit({"type": "defend"})
	assert(s.queued_defense == BattleSimulationScript.DefenseGrade.PERFECT)
	s.step(0.4)
	assert(s.points == 2 and s.strike_index == 1)
	s.attack_elapsed = 1.56 - 0.14
	s.submit({"type": "defend"})
	assert(s.queued_defense == BattleSimulationScript.DefenseGrade.SUCCESS)
	s.step(0.4)
	assert(s.points == 2 and s.stagger_remaining > 0.0)
	s.step(0.4)
	assert(s.points == 2)
	s.step(0.4)
	assert(s.points == 3)
	s.submit({"type": "play_card", "id": "shatter"})
	assert(s.points == 0 and s.enemy_hp == 34)
	s.restart()
	s.attack_index = 2
	s._begin_attack()
	s.attack_elapsed = float(s.current_intent.duration) + 0.02
	s.submit({"type": "defend"})
	assert(s.queued_defense == BattleSimulationScript.DefenseGrade.SUCCESS)
	s.step(0.4)
	assert(s.points == 1 and s.player_hp == BattleSimulationScript.PLAYER_MAX_HP)
	s.restart()
	s.attack_index = 2
	s._begin_attack()
	s.attack_elapsed = float(s.current_intent.duration) - 0.04
	s.submit({"type": "defend"})
	assert(s.queued_defense == BattleSimulationScript.DefenseGrade.PERFECT)
	s.step(0.4)
	assert(s.points == 2)
	print("SMOKE_TEST_OK: simulation commands, grace window, cooldown, points, and cards")
	s.battle_generation += 1
	await get_tree().create_timer(0.4, true, false, true).timeout
	for tween in get_tree().get_processed_tweens():
		tween.kill()
	for audio in [parry_audio, hurt_audio, card_audio, warning_audio]:
		audio.stop()
		audio.stream = null
		audio.free()
	Engine.time_scale = 1.0
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().quit(0)


func _assert_has(events: Array, type: String) -> void:
	for event: Dictionary in events:
		if String(event.get("type", "")) == type:
			return
	assert(false)
