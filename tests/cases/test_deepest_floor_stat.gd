extends RefCounted
## The deepest_floor run stat must actually be recorded (upstream
## Dungeon.newLevel: Statistics.deepestFloor only ever increases), so
## WndHeroInfo's "Deepest Floor" row stops showing 0. Also covers the
## save backfill for older saves that predate the stat.

func run(t: Object) -> void:
	var saved_depth: int = GameManager.depth
	var saved_stats: Dictionary = GameManager.stats.duplicate(true)
	var saved_gold: int = GameManager.gold
	var saved_seed: int = GameManager.run_seed
	var saved_classes: Array = GameManager.get_party_classes()
	var saved_run_active: bool = GameManager.run_active

	_test_reset_initializes_stat(t)
	_test_depth_change_records_max(t)
	_test_apply_run_state_backfills_old_saves(t)
	_test_apply_run_state_keeps_saved_max(t)

	GameManager.depth = saved_depth
	GameManager.stats = saved_stats
	GameManager.gold = saved_gold
	GameManager.run_seed = saved_seed
	GameManager.set_party_classes(saved_classes)
	GameManager.run_active = saved_run_active

func _test_reset_initializes_stat(t: Object) -> void:
	GameManager._reset_stats()
	t.check(GameManager.stats.get("deepest_floor", -1) == 0,
		"_reset_stats initializes deepest_floor to 0")

func _test_depth_change_records_max(t: Object) -> void:
	GameManager._reset_stats()
	GameManager.depth = 3
	GameManager._on_depth_changed()
	t.check(GameManager.stats.get("deepest_floor", 0) == 3,
		"depth change records deepest_floor")
	GameManager.depth = 2
	GameManager._on_depth_changed()
	t.check(GameManager.stats.get("deepest_floor", 0) == 3,
		"ascending does not lower deepest_floor")
	GameManager.depth = 5
	GameManager._on_depth_changed()
	t.check(GameManager.stats.get("deepest_floor", 0) == 5,
		"deeper descent raises deepest_floor")

func _test_apply_run_state_backfills_old_saves(t: Object) -> void:
	GameManager.apply_run_state({
		"depth": 4,
		"stats": {"enemies_slain": 7},
	})
	t.check(GameManager.stats.get("deepest_floor", 0) == 4,
		"old save without deepest_floor backfills from current depth")
	t.check(GameManager.stats.get("enemies_slain", 0) == 7,
		"backfill preserves other loaded stats")

func _test_apply_run_state_keeps_saved_max(t: Object) -> void:
	GameManager.apply_run_state({
		"depth": 4,
		"stats": {"deepest_floor": 9},
	})
	t.check(GameManager.stats.get("deepest_floor", 0) == 9,
		"saved deepest_floor greater than current depth is kept")
