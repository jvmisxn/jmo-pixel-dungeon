extends RefCounted
## Huntress Liquid Nature (upstream Talent.onPotionUsed): drinking or
## throwing a potion roots adjacent enemies for 1/2 turns (factor * points)
## and sprouts grass in the 3x3 around the drink/splash cell — every
## EMPTY/EMBERS cell becomes short GRASS, then 2 + 2*points (4/6) random
## cells without a plant grow into HIGH_GRASS. Port adaptation: no
## EMPTY_DECO terrain, so only EMPTY/EMBERS seed short grass.

func run(t: Object) -> void:
	_test_registry(t)
	_test_no_talent_no_grass(t)
	_test_grass_sprouts(t)
	_test_walls_untouched(t)
	_test_roots_enemies(t)
	_test_ally_not_rooted(t)
	_test_thrown_cell_used(t)

func _make_level() -> Level:
	var level := Level.new()
	level.map.resize(ConstantsData.LENGTH)
	level.map.fill(ConstantsData.Terrain.EMPTY)
	level.build_flag_maps()
	return level

func _make_huntress(points: int, level: Level, cell: int) -> Hero:
	var hero := Hero.new()
	hero.init_class(ConstantsData.HeroClass.HUNTRESS)
	if points > 0:
		hero.talent_levels["huntress_liquid_nature"] = points
	hero.level = level
	hero.pos = cell
	return hero

func _make_mob(level: Level, mob_pos: int) -> Mob:
	var mob := Mob.new()
	mob.is_alive = true
	mob.hp_max = 10
	mob.hp = 10
	mob.pos = mob_pos
	mob.level = level
	level.add_mob(mob)
	return mob

func _area_counts(level: Level, cell: int) -> Dictionary:
	var counts: Dictionary = {"grass": 0, "high": 0, "empty": 0}
	var cells: Array[int] = [cell]
	for offset: int in ConstantsData.DIRS_8:
		cells.append(cell + offset)
	for c: int in cells:
		match level.get_terrain(c):
			ConstantsData.Terrain.GRASS:
				counts["grass"] += 1
			ConstantsData.Terrain.HIGH_GRASS:
				counts["high"] += 1
			ConstantsData.Terrain.EMPTY:
				counts["empty"] += 1
	return counts

func _test_registry(t: Object) -> void:
	var info: TalentData.TalentInfo = TalentData.get_talent(
		ConstantsData.HeroClass.HUNTRESS, "huntress_liquid_nature")
	t.check(info != null, "huntress_liquid_nature is registered")
	if info != null:
		t.check(info.tier == 2 and info.max_points == 2 and info.implemented,
			"Liquid Nature is an implemented 2-point T2 talent")

func _test_no_talent_no_grass(t: Object) -> void:
	var cell: int = ConstantsData.xy_to_pos(10, 10)
	var level := _make_level()
	var hero := _make_huntress(0, level, cell)
	hero.on_potion_used()
	var counts: Dictionary = _area_counts(level, cell)
	t.check(counts["grass"] == 0 and counts["high"] == 0,
		"no talent: potion use sprouts no grass")
	hero.free()

func _test_grass_sprouts(t: Object) -> void:
	for points: int in [1, 2]:
		var cell: int = ConstantsData.xy_to_pos(10, 10)
		var level := _make_level()
		var hero := _make_huntress(points, level, cell)
		hero.on_potion_used()
		var counts: Dictionary = _area_counts(level, cell)
		var expected_high: int = 2 + 2 * points
		t.check(counts["high"] == expected_high,
			"%d point(s): exactly %d cells become tall grass" % [points, expected_high])
		t.check(counts["grass"] == 9 - expected_high,
			"%d point(s): remaining 3x3 cells become short grass" % points)
		t.check(counts["empty"] == 0,
			"%d point(s): no 3x3 cell stays empty" % points)
		hero.free()

func _test_walls_untouched(t: Object) -> void:
	var cell: int = ConstantsData.xy_to_pos(10, 10)
	var level := _make_level()
	var wall_cell: int = cell + ConstantsData.DIR_N
	level.map[wall_cell] = ConstantsData.Terrain.WALL
	level.build_flag_maps()
	var hero := _make_huntress(2, level, cell)
	hero.on_potion_used()
	t.check(level.get_terrain(wall_cell) == ConstantsData.Terrain.WALL,
		"wall cells in the 3x3 stay walls")
	hero.free()

func _test_roots_enemies(t: Object) -> void:
	for points: int in [1, 2]:
		var cell: int = ConstantsData.xy_to_pos(10, 10)
		var level := _make_level()
		var hero := _make_huntress(points, level, cell)
		var mob := _make_mob(level, cell + ConstantsData.DIR_E)
		hero.on_potion_used()
		t.check(mob.has_buff("Rooted"),
			"%d point(s): adjacent enemy is rooted" % points)
		var rooted: Variant = mob.get_buff("Rooted")
		t.check(rooted != null and is_equal_approx(rooted.get_duration(), float(points)),
			"%d point(s): root duration is %d turn(s)" % [points, points])
		var far_mob := _make_mob(level, cell + 5)
		hero.on_potion_used()
		t.check(not far_mob.has_buff("Rooted"),
			"%d point(s): distant enemy is not rooted" % points)
		hero.free()

func _test_ally_not_rooted(t: Object) -> void:
	var cell: int = ConstantsData.xy_to_pos(10, 10)
	var level := _make_level()
	var hero := _make_huntress(2, level, cell)
	var mob := _make_mob(level, cell + ConstantsData.DIR_W)
	mob.is_ally = true
	hero.on_potion_used()
	t.check(not mob.has_buff("Rooted"), "allied mobs are not rooted")
	hero.free()

func _test_thrown_cell_used(t: Object) -> void:
	var hero_cell: int = ConstantsData.xy_to_pos(5, 5)
	var splash_cell: int = ConstantsData.xy_to_pos(15, 15)
	var level := _make_level()
	var hero := _make_huntress(2, level, hero_cell)
	hero.on_potion_used(splash_cell)
	var splash_counts: Dictionary = _area_counts(level, splash_cell)
	var hero_counts: Dictionary = _area_counts(level, hero_cell)
	t.check(splash_counts["high"] == 6 and splash_counts["empty"] == 0,
		"thrown: grass sprouts around the splash cell")
	t.check(hero_counts["grass"] == 0 and hero_counts["high"] == 0,
		"thrown: no grass sprouts around the hero")
	hero.free()
