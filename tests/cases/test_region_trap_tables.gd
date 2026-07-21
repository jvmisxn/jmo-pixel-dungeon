extends RefCounted

func run(t: Object) -> void:
	_test_caves_uses_source_weighted_trap_table(t)
	_test_city_uses_source_weighted_trap_table(t)
	_test_city_no_longer_uses_halls_only_grim_trap(t)

func _test_caves_uses_source_weighted_trap_table(t: Object) -> void:
	var level := CavesLevel.new()
	var expectations: Array[Array] = [
		[0.00, "fire trap"],
		[4.0 / 32.0, "poison dart trap"],
		[8.0 / 32.0, "frost trap"],
		[12.0 / 32.0, "storm trap"],
		[16.0 / 32.0, "corrosion trap"],
		[20.0 / 32.0, "gripping trap"],
		[22.0 / 32.0, "rockfall trap"],
		[24.0 / 32.0, "guardian trap"],
		[26.0 / 32.0, "confusion gas trap"],
		[27.0 / 32.0, "summoning trap"],
		[28.0 / 32.0, "warping trap"],
		[29.0 / 32.0, "pitfall trap"],
		[30.0 / 32.0, "gateway trap"],
		[31.0 / 32.0, "geyser trap"],
	]
	for expectation: Array in expectations:
		var trap: Trap = level._trap_for_weighted_roll(float(expectation[0]))
		t.check(trap.trap_name == String(expectation[1]),
			"Caves trap roll %.3f creates %s" % [float(expectation[0]), String(expectation[1])])

func _test_city_uses_source_weighted_trap_table(t: Object) -> void:
	var level := CityLevel.new()
	var expectations: Array[Array] = [
		[0.00, "frost trap"],
		[4.0 / 35.0, "storm trap"],
		[8.0 / 35.0, "corrosion trap"],
		[12.0 / 35.0, "blazing trap"],
		[16.0 / 35.0, "disintegration trap"],
		[20.0 / 35.0, "rockfall trap"],
		[22.0 / 35.0, "flashing trap"],
		[24.0 / 35.0, "guardian trap"],
		[26.0 / 35.0, "weakening trap"],
		[28.0 / 35.0, "disarming trap"],
		[29.0 / 35.0, "summoning trap"],
		[30.0 / 35.0, "warping trap"],
		[31.0 / 35.0, "cursing trap"],
		[32.0 / 35.0, "pitfall trap"],
		[33.0 / 35.0, "gateway trap"],
		[34.0 / 35.0, "geyser trap"],
	]
	for expectation: Array in expectations:
		var trap: Trap = level._trap_for_weighted_roll(float(expectation[0]))
		t.check(trap.trap_name == String(expectation[1]),
			"City trap roll %.3f creates %s" % [float(expectation[0]), String(expectation[1])])

func _test_city_no_longer_uses_halls_only_grim_trap(t: Object) -> void:
	var level := CityLevel.new()
	for i: int in range(35):
		var trap: Trap = level._trap_for_weighted_roll((float(i) + 0.5) / 35.0)
		t.check(trap.trap_name != "grim trap",
			"City weighted slot %d does not use Halls-only grim trap" % i)
