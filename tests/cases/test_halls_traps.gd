extends RefCounted

func run(t: Object) -> void:
	_test_halls_uses_late_game_trap_table(t)
	_test_halls_does_not_fall_back_to_early_traps(t)

func _test_halls_uses_late_game_trap_table(t: Object) -> void:
	var level := HallsLevel.new()
	var expectations: Array[Array] = [
		[0.00, "frost trap"],
		[4.0 / 28.0, "storm trap"],
		[8.0 / 28.0, "corrosion trap"],
		[12.0 / 28.0, "blazing trap"],
		[16.0 / 28.0, "rockfall trap"],
		[18.0 / 28.0, "flashing trap"],
		[20.0 / 28.0, "guardian trap"],
		[22.0 / 28.0, "disarming trap"],
		[23.0 / 28.0, "summoning trap"],
		[24.0 / 28.0, "warping trap"],
		[25.0 / 28.0, "cursing trap"],
		[26.0 / 28.0, "grim trap"],
		[27.0 / 28.0, "pitfall trap"],
	]
	for expectation: Array in expectations:
		var trap: Trap = level._trap_for_weighted_roll(float(expectation[0]))
		t.check(trap.trap_name == String(expectation[1]),
			"Halls trap roll %.3f creates %s" % [float(expectation[0]), String(expectation[1])])

func _test_halls_does_not_fall_back_to_early_traps(t: Object) -> void:
	var level := HallsLevel.new()
	var early_traps: Array[String] = [
		"worn dart trap",
		"poison dart trap",
		"fire trap",
		"alarm trap",
		"teleportation trap",
	]
	for i: int in range(28):
		var trap: Trap = level._trap_for_weighted_roll((float(i) + 0.5) / 28.0)
		t.check(not early_traps.has(trap.trap_name),
			"Halls weighted slot %d does not use early fallback trap %s" % [i, trap.trap_name])
