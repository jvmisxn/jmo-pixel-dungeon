extends RefCounted
## Rogue Wide Search (upstream Hero.search): having the talent adds +1 search
## radius on top of the Rogue's innate 2. At exactly +1 the expanded area has
## rounded corners (ShadowCaster rounding table); at +2 the full square is
## searched.

func run(t: Object) -> void:
	_test_registry(t)
	_test_baseline_radius_unchanged(t)
	_test_plus_one_rounded_radius_three(t)
	_test_plus_two_full_square(t)
	_test_non_rogue_circular_radius_two(t)

func _make_level() -> Level:
	var level := Level.new()
	level.map.resize(ConstantsData.LENGTH)
	level.map.fill(ConstantsData.Terrain.EMPTY)
	level.entrance = ConstantsData.xy_to_pos(1, 1)
	level.exit_pos = ConstantsData.xy_to_pos(2, 2)
	level.build_flag_maps()
	return level

func _make_hero(hero_class: int, pos: int, level: Level, points: int) -> Hero:
	var hero := Hero.new()
	hero.init_class(hero_class)
	hero.pos = pos
	hero.level = level
	if points > 0:
		hero.talent_levels["rogue_wide_search"] = points
	return hero

func _test_registry(t: Object) -> void:
	var info: TalentData.TalentInfo = TalentData.get_talent(
		ConstantsData.HeroClass.ROGUE, "rogue_wide_search")
	t.check(info != null, "rogue_wide_search is registered for the Rogue")
	t.check(info != null and info.implemented,
		"rogue_wide_search is marked implemented")
	t.check(info != null and info.tier == 2, "rogue_wide_search is tier 2")

func _test_baseline_radius_unchanged(t: Object) -> void:
	var level: Level = _make_level()
	var hero_pos: int = ConstantsData.xy_to_pos(10, 10)
	var two_away: int = ConstantsData.xy_to_pos(12, 12)
	var three_away: int = ConstantsData.xy_to_pos(13, 10)
	level.set_terrain(two_away, ConstantsData.Terrain.SECRET_DOOR)
	level.set_terrain(three_away, ConstantsData.Terrain.SECRET_DOOR)
	var hero: Hero = _make_hero(ConstantsData.HeroClass.ROGUE, hero_pos, level, 0)

	hero._do_search()

	t.check(level.terrain_at(two_away) == ConstantsData.Terrain.DOOR,
		"0 points: Rogue innate radius 2 still reveals (2,2)")
	t.check(level.terrain_at(three_away) == ConstantsData.Terrain.SECRET_DOOR,
		"0 points: cells 3 tiles away stay hidden")
	hero.free()

func _test_plus_one_rounded_radius_three(t: Object) -> void:
	var level: Level = _make_level()
	var hero_pos: int = ConstantsData.xy_to_pos(10, 10)
	var edge: int = ConstantsData.xy_to_pos(13, 10)
	var near_corner: int = ConstantsData.xy_to_pos(13, 12)
	var corner: int = ConstantsData.xy_to_pos(13, 13)
	level.set_terrain(edge, ConstantsData.Terrain.SECRET_DOOR)
	level.set_terrain(near_corner, ConstantsData.Terrain.SECRET_DOOR)
	level.set_terrain(corner, ConstantsData.Terrain.SECRET_DOOR)
	var hero: Hero = _make_hero(ConstantsData.HeroClass.ROGUE, hero_pos, level, 1)

	hero._do_search()

	t.check(level.terrain_at(edge) == ConstantsData.Terrain.DOOR,
		"+1: radius grows to 3, edge cell (3,0) revealed")
	t.check(level.terrain_at(near_corner) == ConstantsData.Terrain.DOOR,
		"+1: rounded area still includes (3,2)")
	t.check(level.terrain_at(corner) == ConstantsData.Terrain.SECRET_DOOR,
		"+1: rounded corner (3,3) stays hidden")
	hero.free()

func _test_plus_two_full_square(t: Object) -> void:
	var level: Level = _make_level()
	var hero_pos: int = ConstantsData.xy_to_pos(10, 10)
	var corner: int = ConstantsData.xy_to_pos(13, 13)
	var trap_corner: int = ConstantsData.xy_to_pos(7, 13)
	level.set_terrain(corner, ConstantsData.Terrain.SECRET_DOOR)
	level.set_terrain(trap_corner, ConstantsData.Terrain.SECRET_TRAP)
	var hero: Hero = _make_hero(ConstantsData.HeroClass.ROGUE, hero_pos, level, 2)

	hero._do_search()

	t.check(level.terrain_at(corner) == ConstantsData.Terrain.DOOR,
		"+2: full square, corner (3,3) revealed")
	t.check(level.terrain_at(trap_corner) == ConstantsData.Terrain.TRAP,
		"+2: hidden trap at square corner revealed too")
	hero.free()

func _test_non_rogue_circular_radius_two(t: Object) -> void:
	# Talent points on a non-Rogue still act through the same shared search
	# path (upstream hasTalent check is class-agnostic): base 1 -> 2, rounded.
	var level: Level = _make_level()
	var hero_pos: int = ConstantsData.xy_to_pos(10, 10)
	var edge: int = ConstantsData.xy_to_pos(12, 10)
	var corner: int = ConstantsData.xy_to_pos(12, 12)
	level.set_terrain(edge, ConstantsData.Terrain.SECRET_DOOR)
	level.set_terrain(corner, ConstantsData.Terrain.SECRET_DOOR)
	var hero: Hero = _make_hero(ConstantsData.HeroClass.WARRIOR, hero_pos, level, 1)

	hero._do_search()

	t.check(level.terrain_at(edge) == ConstantsData.Terrain.DOOR,
		"+1 non-Rogue: radius 2 edge (2,0) revealed")
	t.check(level.terrain_at(corner) == ConstantsData.Terrain.SECRET_DOOR,
		"+1 non-Rogue: rounded corner (2,2) stays hidden")
	hero.free()
