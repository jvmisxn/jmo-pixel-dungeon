extends RefCounted

func run(t: Object) -> void:
	_test_halls_uses_late_game_trap_table(t)
	_test_halls_does_not_fall_back_to_early_traps(t)
	_test_halls_caps_hero_view_distance(t)

func _test_halls_uses_late_game_trap_table(t: Object) -> void:
	var level := HallsLevel.new()
	var expectations: Array[Array] = [
		[0.00, "frost trap"],
		[4.0 / 37.0, "storm trap"],
		[8.0 / 37.0, "corrosion trap"],
		[12.0 / 37.0, "blazing trap"],
		[16.0 / 37.0, "disintegration trap"],
		[20.0 / 37.0, "rockfall trap"],
		[22.0 / 37.0, "flashing trap"],
		[24.0 / 37.0, "guardian trap"],
		[26.0 / 37.0, "weakening trap"],
		[28.0 / 37.0, "disarming trap"],
		[29.0 / 37.0, "summoning trap"],
		[30.0 / 37.0, "warping trap"],
		[31.0 / 37.0, "cursing trap"],
		[32.0 / 37.0, "grim trap"],
		[33.0 / 37.0, "pitfall trap"],
		[34.0 / 37.0, "distortion trap"],
		[35.0 / 37.0, "gateway trap"],
		[36.0 / 37.0, "geyser trap"],
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
	for i: int in range(37):
		var trap: Trap = level._trap_for_weighted_roll((float(i) + 0.5) / 37.0)
		t.check(not early_traps.has(trap.trap_name),
			"Halls weighted slot %d does not use early fallback trap %s" % [i, trap.trap_name])

func _test_halls_caps_hero_view_distance(t: Object) -> void:
	var halls21 := HallsLevel.new()
	halls21.depth = 21
	var huntress := Hero.new()
	huntress.hero_class = ConstantsData.HeroClass.HUNTRESS
	huntress.level = halls21
	t.check(
		huntress.get_view_distance() == 5,
		"Halls depth 21 caps Huntress sight to upstream 26-depth"
	)

	var halls24 := HallsLevel.new()
	halls24.depth = 24
	var warrior := Hero.new()
	warrior.hero_class = ConstantsData.HeroClass.WARRIOR
	warrior.level = halls24
	t.check(
		warrior.get_view_distance() == 2,
		"Halls depth 24 tightens normal sight to upstream 26-depth"
	)

	var normal := RegularLevel.new()
	normal.depth = 21
	var normal_huntress := Hero.new()
	normal_huntress.hero_class = ConstantsData.HeroClass.HUNTRESS
	normal_huntress.level = normal
	t.check(
		normal_huntress.get_view_distance() == ConstantsData.VIEW_DISTANCE + 2,
		"Non-Halls levels keep the Huntress sight bonus uncapped"
	)

	huntress.free()
	warrior.free()
	normal_huntress.free()
