extends RefCounted

func run(t: Object) -> void:
	_test_caves_uses_source_weighted_trap_table(t)
	_test_city_uses_source_weighted_trap_table(t)
	_test_city_no_longer_uses_halls_only_grim_trap(t)
	_test_distortion_trap_summons_source_style_mix(t)
	_test_distortion_trap_rejects_wrapped_neighbours(t)

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
		[4.0 / 36.0, "storm trap"],
		[8.0 / 36.0, "corrosion trap"],
		[12.0 / 36.0, "blazing trap"],
		[16.0 / 36.0, "disintegration trap"],
		[20.0 / 36.0, "rockfall trap"],
		[22.0 / 36.0, "flashing trap"],
		[24.0 / 36.0, "guardian trap"],
		[26.0 / 36.0, "weakening trap"],
		[28.0 / 36.0, "disarming trap"],
		[29.0 / 36.0, "summoning trap"],
		[30.0 / 36.0, "warping trap"],
		[31.0 / 36.0, "cursing trap"],
		[32.0 / 36.0, "pitfall trap"],
		[33.0 / 36.0, "distortion trap"],
		[34.0 / 36.0, "gateway trap"],
		[35.0 / 36.0, "geyser trap"],
	]
	for expectation: Array in expectations:
		var trap: Trap = level._trap_for_weighted_roll(float(expectation[0]))
		t.check(trap.trap_name == String(expectation[1]),
			"City trap roll %.3f creates %s" % [float(expectation[0]), String(expectation[1])])

func _test_city_no_longer_uses_halls_only_grim_trap(t: Object) -> void:
	var level := CityLevel.new()
	for i: int in range(36):
		var trap: Trap = level._trap_for_weighted_roll((float(i) + 0.5) / 36.0)
		t.check(trap.trap_name != "grim trap",
			"City weighted slot %d does not use Halls-only grim trap" % i)

func _test_distortion_trap_summons_source_style_mix(t: Object) -> void:
	seed(12345)
	var level := Level.new()
	level.depth = 18
	for y: int in range(10, 13):
		for x: int in range(10, 13):
			level.set_terrain(y * Level.W + x, ConstantsData.Terrain.EMPTY)
	var blocker := Rat.new()
	blocker.pos = 10 * Level.W + 10
	level.add_mob(blocker)
	level.set_terrain(10 * Level.W + 11, ConstantsData.Terrain.WALL)
	var trap := DistortionTrap.new()
	trap.pos = 11 * Level.W + 11
	level.place_trap(trap.pos, trap)
	level.set_terrain(trap.pos, ConstantsData.Terrain.TRAP)
	trap.activate(null, level)

	var summoned_count: int = level.mobs.size() - 1
	t.check(summoned_count >= 3 and summoned_count <= 5,
		"DistortionTrap summons three to five mobs when enough neighbouring cells are available")
	t.check(not trap.active, "DistortionTrap is consumed as a one-shot trap")
	t.check(level.terrain_at(trap.pos) == ConstantsData.Terrain.INACTIVE_TRAP,
		"DistortionTrap leaves an inactive trap tile after activation")
	var occupied: Dictionary[int, bool] = {}
	var has_special: bool = false
	for mob: Variant in level.mobs:
		if mob == blocker:
			continue
		t.check(ConstantsData.DIRS_8.has(int(mob.pos) - trap.pos),
			"DistortionTrap places summoned mobs in neighbouring cells")
		t.check(int(mob.pos) != blocker.pos,
			"DistortionTrap does not summon onto occupied neighbours")
		t.check(level.terrain_at(int(mob.pos)) != ConstantsData.Terrain.WALL,
			"DistortionTrap does not summon onto impassable neighbours")
		t.check(not occupied.has(int(mob.pos)),
			"DistortionTrap does not stack summons on one cell")
		occupied[int(mob.pos)] = true
		t.check(mob.max_level == ConstantsData.MAX_HERO_LEVEL - 1,
			"DistortionTrap caps summoned mob XP level like upstream")
		if DistortionTrap.SPECIAL_MOB_IDS.has(mob.mob_id):
			has_special = true
	t.check(has_special, "DistortionTrap includes the upstream-style special second summon")

func _test_distortion_trap_rejects_wrapped_neighbours(t: Object) -> void:
	var level := Level.new()
	var trap := DistortionTrap.new()
	trap.pos = 2 * Level.W
	level.set_terrain(trap.pos, ConstantsData.Terrain.EMPTY)
	level.set_terrain(trap.pos - 1, ConstantsData.Terrain.EMPTY)
	level.set_terrain(trap.pos + 1, ConstantsData.Terrain.EMPTY)
	var candidates: Array[int] = trap._select_spawn_cells(level)
	t.check(not candidates.has(trap.pos - 1),
		"DistortionTrap does not treat previous row's last column as a neighbour")
	t.check(candidates.has(trap.pos + 1),
		"DistortionTrap still accepts real same-row neighbours")
