extends RefCounted
## Rogue search should cover the SPD class radius of 2 tiles, while other
## classes keep the default 1-tile intentional search radius.

func _make_level() -> Level:
	var level := Level.new()
	level.map.resize(ConstantsData.LENGTH)
	level.map.fill(ConstantsData.Terrain.EMPTY)
	level.entrance = ConstantsData.xy_to_pos(1, 1)
	level.exit_pos = ConstantsData.xy_to_pos(2, 2)
	level.build_flag_maps()
	return level

func _make_hero(hero_class: int, pos: int, level: Level) -> Hero:
	var hero := Hero.new()
	hero.init_class(hero_class)
	hero.pos = pos
	hero.level = level
	return hero

func run(t: Object) -> void:
	_check_warrior_search_stays_adjacent(t)
	_check_rogue_search_reaches_two_tiles(t)

func _check_warrior_search_stays_adjacent(t: Object) -> void:
	var level: Level = _make_level()
	var hero_pos: int = ConstantsData.xy_to_pos(10, 10)
	var near_secret: int = ConstantsData.xy_to_pos(11, 10)
	var far_secret: int = ConstantsData.xy_to_pos(12, 10)
	level.set_terrain(near_secret, ConstantsData.Terrain.SECRET_DOOR)
	level.set_terrain(far_secret, ConstantsData.Terrain.SECRET_DOOR)
	var hero: Hero = _make_hero(ConstantsData.HeroClass.WARRIOR, hero_pos, level)

	hero._do_search()

	t.check(
		level.terrain_at(near_secret) == ConstantsData.Terrain.DOOR,
		"Warrior search reveals adjacent secret doors"
	)
	t.check(
		level.terrain_at(far_secret) == ConstantsData.Terrain.SECRET_DOOR,
		"Warrior search does not reveal two-tile secret doors"
	)
	hero.free()

func _check_rogue_search_reaches_two_tiles(t: Object) -> void:
	var level: Level = _make_level()
	var hero_pos: int = ConstantsData.xy_to_pos(10, 10)
	var far_secret: int = ConstantsData.xy_to_pos(12, 10)
	var far_trap: int = ConstantsData.xy_to_pos(10, 12)
	level.set_terrain(far_secret, ConstantsData.Terrain.SECRET_DOOR)
	level.set_terrain(far_trap, ConstantsData.Terrain.SECRET_TRAP)
	var hero: Hero = _make_hero(ConstantsData.HeroClass.ROGUE, hero_pos, level)

	hero._do_search()

	t.check(
		level.terrain_at(far_secret) == ConstantsData.Terrain.DOOR,
		"Rogue search reveals secret doors two tiles away"
	)
	t.check(
		level.terrain_at(far_trap) == ConstantsData.Terrain.TRAP,
		"Rogue search reveals hidden traps two tiles away"
	)
	hero.free()
