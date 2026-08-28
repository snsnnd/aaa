extends Node

## Settings（autoload "GameSettings"）：设置、键位重映射、无障碍选项。
## 之前输入硬编码在 main.gd（KEY_1/KEY_SPACE...），现在统一走 InputMap 动作；
## 键盘部分可在这里重映射（手柄默认映射在 project.godot [input]）。

const PATH := "user://settings.json"

const ACTIONS := {
	"defend": KEY_SPACE,
	"card_1": KEY_1,
	"card_2": KEY_2,
	"card_3": KEY_3,
	"card_4": KEY_4,
	"summon": KEY_5,
	"pause": KEY_ESCAPE,
	"restart": KEY_R,
}

const ACTION_LABELS := {
	"defend": "架势防范", "card_1": "符牌一", "card_2": "符牌二", "card_3": "符牌三",
	"card_4": "符牌四", "summon": "召符", "pause": "暂停菜单", "restart": "重开本战",
}

# 无障碍：震屏强度 / 闪光减弱 / 文字缩放 / 色觉模式 / 反应窗口辅助
var shake_scale := 1.0
var flash_reduction := false
var text_scale := 1.0
var colorblind_mode := 0    # 0 关 1 红色盲 2 绿色盲 3 蓝色盲
var reaction_assist := 1.0  # 1.0 / 1.25 / 1.5，放大防范判定窗口
var keybindings: Dictionary = {}


func _ready() -> void:
	load_settings()
	apply_keybindings()


func load_settings() -> void:
	if not FileAccess.file_exists(PATH):
		return
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if parsed is Dictionary:
		shake_scale = float(parsed.get("shake_scale", 1.0))
		flash_reduction = bool(parsed.get("flash_reduction", false))
		text_scale = float(parsed.get("text_scale", 1.0))
		colorblind_mode = int(parsed.get("colorblind_mode", 0))
		reaction_assist = float(parsed.get("reaction_assist", 1.0))
		keybindings = parsed.get("keybindings", {})


func save_settings() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({
		"shake_scale": shake_scale, "flash_reduction": flash_reduction,
		"text_scale": text_scale, "colorblind_mode": colorblind_mode,
		"reaction_assist": reaction_assist, "keybindings": keybindings,
	}, "  "))
	f.close()


## 文字缩放：所有 UI 字号统一经此换算。
func font(size: int) -> int:
	return int(round(size * text_scale))


## 色觉辅助：对招式/提示颜色做线性变换。
func adjust_color(c: Color) -> Color:
	match colorblind_mode:
		1:  # 红色盲
			return Color(0.567 * c.r + 0.433 * c.g, 0.558 * c.r + 0.442 * c.g, 0.242 * c.g + 0.758 * c.b, c.a)
		2:  # 绿色盲
			return Color(0.625 * c.r + 0.375 * c.g, 0.7 * c.r + 0.3 * c.g, 0.3 * c.g + 0.7 * c.b, c.a)
		3:  # 蓝色盲
			return Color(0.95 * c.r + 0.05 * c.g, 0.0 * c.r + 0.433 * c.g + 0.567 * c.b, 0.433 * c.g + 0.567 * c.b, c.a)
	return c


func apply_keybindings() -> void:
	for action in ACTIONS:
		if not InputMap.has_action(action):
			continue
		# 只替换键盘事件，保留 project.godot 里的手柄映射
		for ev in InputMap.action_get_events(action):
			if ev is InputEventKey:
				InputMap.action_erase_event(action, ev)
		var key: Key = int(keybindings.get(action, ACTIONS[action]))
		var ev := InputEventKey.new()
		ev.physical_keycode = key
		InputMap.action_add_event(action, ev)


func set_binding(action: String, key: Key) -> void:
	keybindings[action] = key
	apply_keybindings()
	save_settings()


func binding_label(action: String) -> String:
	var key: Key = int(keybindings.get(action, ACTIONS[action]))
	return OS.get_keycode_string(key)
