extends SceneTree

func _init() -> void:
	print("--- Validating VFX Scenes & Assets ---")
	var scenes := [
		"res://assets/game/vfx/scenes/vfx_perfect_parry.tscn",
		"res://assets/game/vfx/scenes/vfx_guard_arc.tscn",
		"res://assets/game/vfx/scenes/vfx_paper_burst.tscn",
		"res://assets/game/vfx/scenes/vfx_counter_slash.tscn",
		"res://assets/game/vfx/scenes/vfx_seal_ring.tscn",
		"res://assets/game/vfx/scenes/vfx_bell_wave.tscn",
		"res://assets/game/vfx/scenes/vfx_soul_embers.tscn",
		"res://assets/game/vfx/scenes/vfx_ghost_flame_burst.tscn",
		"res://assets/game/vfx/scenes/vfx_hit_sparks.tscn",
		"res://assets/game/vfx/scenes/vfx_death_dissolve.tscn",
	]
	
	var passed := 0
	for path in scenes:
		if not ResourceLoader.exists(path):
			printerr("FAIL: Scene missing -> ", path)
			continue
		var packed: PackedScene = load(path)
		if packed == null:
			printerr("FAIL: Failed to load scene -> ", path)
			continue
		var instance = packed.instantiate()
		if instance == null:
			printerr("FAIL: Failed to instantiate scene -> ", path)
			continue
		if instance.has_method("play"):
			instance.play()
		print("OK: [Scene Validated] ", path, " -> ", instance.name)
		instance.free()
		passed += 1
		
	print("--- VFX Validation Finished: ", passed, "/", scenes.size(), " Passed ---")
	quit(0 if passed == scenes.size() else 1)
