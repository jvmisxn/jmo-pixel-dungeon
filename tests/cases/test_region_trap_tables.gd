extends RefCounted

func run(t: Object) -> void:
	_test_caves_uses_source_weighted_trap_table(t)
	_test_city_uses_source_weighted_trap_table(t)
	_test_city_no_longer_uses_halls_only_grim_trap(t)

func _test_caves_uses_source_weighted_trap_table(t: Object) -> void:
	var level := CavesLevel.new()
	var expectations: Array[Array] = [
		[0.00, "fire trap"],
		[4.0 / 29.0, "poison dart trap"],
		[8.0 / 29.0, "frost trap"],
		[12.0 / 29.0, "storm trap"],
		[16.0 / 29.0, "corrosion trap"],
		[20.0 / 29.0, "gripping trap"],
		[22.0 / 29.0, "rockfall trap"],
		[24.0 / 29.0, "guardian trap"],
		[26.0 / 29.0, "summoning trap"],
		[27.0 / 29.0, "warping trap"],
		[28.0 / 29.0, "pitfall trap"],
	]
	for expectation: Array in expectations:
		var trap: Trap = level._trap_for_weighted_roll(float(expectation[0]))
		t.check(trap.trap_name == String(expectation[1]),
			"Caves trap roll %.3f creates %s" % [float(expectation[0]), String(expectation[1])])

func _test_city_uses_source_weighted_trap_table(t: Object) -> void:
	var level := CityLevel.new()
	var expectations: Array[Array] = [
		[0.00, "frost trap"],
		[4.0 / 27.0, "storm trap"],
		[8.0 / 27.0, "corrosion trap"],
		[12.0 / 27.0, "blazing trap"],
		[16.0 / 27.0, "rockfall trap"],
		[18.0 / 27.0, "flashing trap"],
		[20.0 / 27.0, "guardian trap"],
		[22.0 / 27.0, "disarming trap"],
		[23.0 / 27.0, "summoning trap"],
		[24.0 / 27.0, "warping trap"],
		[25.0 / 27.0, "cursing trap"],
		[26.0 / 27.0, "pitfall trap"],
	]
	for expectation: Array in expectations:
		var trap: Trap = level._trap_for_weighted_roll(float(expectation[0]))
		t.check(trap.trap_name == String(expectation[1]),
			"City trap roll %.3f creates %s" % [float(expectation[0]), String(expectation[1])])

func _test_city_no_longer_uses_halls_only_grim_trap(t: Object) -> void:
	var level := CityLevel.new()
	for i: int in range(27):
		var trap: Trap = level._trap_for_weighted_roll((float(i) + 0.5) / 27.0)
		t.check(trap.trap_name != "grim trap",
			"City weighted slot %d does not use Halls-only grim trap" % i)
