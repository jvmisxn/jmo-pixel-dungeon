extends RefCounted

func run(t: Object) -> void:
	_test_charm_and_terror_deserialize_source_id(t)
	_test_char_buff_round_trip_preserves_source_id(t)

func _test_charm_and_terror_deserialize_source_id(t: Object) -> void:
	var charm: Charm = Charm.new()
	charm.deserialize({
		"buff_id": "Charm",
		"duration": 7.0,
		"time_left": 3.0,
		"source_id": 42,
	})

	var terror: Terror = Terror.new()
	terror.deserialize({
		"buff_id": "Terror",
		"duration": 6.0,
		"time_left": 2.0,
		"source_id": 77,
	})

	t.check(charm.source_id == 42, "Charm restores its source actor id")
	t.check(charm.time_left == 3.0, "Charm still restores base buff timing")
	t.check(terror.source_id == 77, "Terror restores its source actor id")
	t.check(terror.time_left == 2.0, "Terror still restores base buff timing")

func _test_char_buff_round_trip_preserves_source_id(t: Object) -> void:
	var original: Char = Char.new()
	original.add_buff(Charm.create(12, 4.0))
	original.add_buff(Terror.create(34, 5.0))
	var data: Array[Dictionary] = original._serialize_buffs()

	var restored: Char = Char.new()
	restored._deserialize_buffs(data)

	var charm: Charm = restored.get_buff("Charm") as Charm
	var terror: Terror = restored.get_buff("Terror") as Terror
	t.check(charm != null and charm.source_id == 12, "serialized Charm keeps its source through Char reload")
	t.check(terror != null and terror.source_id == 34, "serialized Terror keeps its source through Char reload")

	original.free()
	restored.free()
