extends RefCounted
## Contract tests for GameManager's save-facing run-state chokepoint.

func run(t: Object) -> void:
	var script: Variant = load("res://src/autoloads/game_manager.gd")
	t.check(script != null and script is GDScript, "game_manager.gd compiles")
	if script == null:
		return

	var manager: Object = script.new()
	manager.depth = 7
	manager.gold = 123
	manager.run_seed = 456
	manager.quest_flags["sample_flag"] = "kept"
	manager.stats["items_collected"] = 3

	var saved: Dictionary = manager.serialize_run_state()
	t.check(saved.get("depth", 0) == 7, "run-state serialize includes depth")
	t.check(
		saved.get("quest_flags", {}).get("sample_flag", "") == "kept",
		"run-state serialize includes quest flags"
	)

	manager.depth = 1
	manager.gold = 0
	manager.quest_flags.clear()
	manager.apply_run_state(saved)
	t.check(manager.depth == 7, "run-state apply restores depth")
	t.check(manager.gold == 123, "run-state apply restores gold")
	t.check(
		manager.quest_flags.get("sample_flag", "") == "kept",
		"run-state apply restores quest flags"
	)

	manager.free()
