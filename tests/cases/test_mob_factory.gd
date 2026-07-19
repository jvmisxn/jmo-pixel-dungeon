extends RefCounted

class FakeDropLevel:
	extends RefCounted

	var drops: Array[Dictionary] = []

	func drop_item(cell: int, item: Variant, heap_type: String = "heap") -> void:
		drops.append({"cell": cell, "item": item, "heap_type": heap_type})

func run(t: Object) -> void:
	_test_halls_mob_rotation_matches_spd_depth_ramp(t)
	_test_halls_regular_rotation_excludes_rippers(t)
	_test_create_boss_unknown_depth_returns_null(t)
	_test_boss_drops_skeleton_key(t)

func _test_halls_mob_rotation_matches_spd_depth_ramp(t: Object) -> void:
	var expected_by_depth: Dictionary = {
		21: {"succubus": 2.0, "eye": 1.0},
		22: {"succubus": 1.0, "eye": 1.0},
		23: {"succubus": 1.0, "eye": 2.0, "scorpio": 1.0},
		24: {"succubus": 1.0, "eye": 2.0, "scorpio": 3.0},
	}
	for depth: int in expected_by_depth.keys():
		t.check(
			_table_weights(MobFactory.get_mob_table(depth)) == expected_by_depth[depth],
			"Halls depth %d uses the SPD standard mob rotation weights" % depth
		)

func _test_halls_regular_rotation_excludes_rippers(t: Object) -> void:
	for depth: int in range(21, 25):
		t.check(
			not _table_weights(MobFactory.get_mob_table(depth)).has("ripper"),
			"Halls depth %d does not spawn Rippers as ordinary room mobs" % depth
		)

func _test_create_boss_unknown_depth_returns_null(t: Object) -> void:
	t.check(
		MobFactory.create_boss(1) == null,
		"unknown boss depth follows create_mob's null-on-unknown contract"
	)

func _test_boss_drops_skeleton_key(t: Object) -> void:
	var old_depth: int = GameManager.depth
	GameManager.depth = 5
	var boss := Mob.new()
	var level := FakeDropLevel.new()
	boss.mob_id = "goo"
	boss.pos = 123
	boss.level = level

	boss._drop_skeleton_key()

	t.check(level.drops.size() == 1, "boss death helper drops one skeleton key")
	if level.drops.size() == 1:
		var dropped_item: Variant = level.drops[0].get("item")
		t.check(
			ConstantsData.get_prop(dropped_item, "item_id", "") == "skeleton_key",
			"boss death helper drops the canonical skeleton key item"
		)
		t.check(
			int(ConstantsData.get_prop(dropped_item, "depth", -1)) == 5,
			"boss skeleton key is tied to the boss depth"
		)
	boss.free()
	GameManager.depth = old_depth

func _table_weights(table: Array[Dictionary]) -> Dictionary:
	var weights: Dictionary = {}
	for entry: Dictionary in table:
		weights[String(entry.get("mob_id", ""))] = float(entry.get("weight", 0.0))
	return weights
