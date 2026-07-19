extends RefCounted

func run(t: Object) -> void:
	_test_halls_mob_rotation_matches_spd_depth_ramp(t)
	_test_halls_regular_rotation_excludes_rippers(t)
	_test_create_boss_unknown_depth_returns_null(t)

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

func _table_weights(table: Array[Dictionary]) -> Dictionary:
	var weights: Dictionary = {}
	for entry: Dictionary in table:
		weights[String(entry.get("mob_id", ""))] = float(entry.get("weight", 0.0))
	return weights
