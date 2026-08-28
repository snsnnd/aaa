class_name SaveManager
extends RefCounted

## 持久化：进行中的 Run（自动存档）+ 局外进度（解锁/难度/统计/教学）。
## Run 存 user://save_run.json；局外存 user://save_meta.json；设置存 user://settings.json（Settings 自管）。

const RUN_PATH := "user://save_run.json"
const META_PATH := "user://save_meta.json"

## 局外进度：
##   difficulty_unlocked: 已解锁的最高难度
##   wins / runs_total: 通关数 / 总局数
##   tutorial_done: 教学已完成
##   best_act_row: 单局最远行数
static func load_run() -> Dictionary:
	return _load_json(RUN_PATH)


static func save_run(run: RunState) -> void:
	_save_json(RUN_PATH, run.to_dict())


static func clear_run() -> void:
	if FileAccess.file_exists(RUN_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(RUN_PATH))


static func has_run() -> bool:
	var data := _load_json(RUN_PATH)
	return not data.is_empty() and int(data.get("version", 0)) == 1


static func load_meta() -> Dictionary:
	return _load_json(META_PATH)


static func save_meta(meta: Dictionary) -> void:
	_save_json(META_PATH, meta)


static func default_meta() -> Dictionary:
	return {
		"version": 1,
		"difficulty_unlocked": 0,
		"wins": 0,
		"runs_total": 0,
		"tutorial_done": false,
		"best_act_row": 0,
	}


static func _load_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	return parsed if parsed is Dictionary else {}


static func _save_json(path: String, data: Dictionary) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		push_warning("无法写入存档：%s" % path)
		return
	f.store_string(JSON.stringify(data, "  "))
	f.close()
