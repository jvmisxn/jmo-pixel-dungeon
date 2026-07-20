extends RefCounted
## Frost Bomb should mirror SPD's FrostBomb: a radius-2 normal bomb blast that
## seeds Freezing at 10 volume across the reachable footprint and directly
## applies a short Frost/Frozen effect to chars there.

func _make_level() -> Level:
	var level := Level.new()
	level.map.resize(ConstantsData.LENGTH)
	level.map.fill(ConstantsData.Terrain.EMPTY)
	level.build_flag_maps()
	return level

func _make_hero(pos: int, level: Level) -> Hero:
	var hero := Hero.new()
	hero.init_class(ConstantsData.HeroClass.WARRIOR)
	hero.pos = pos
	hero.level = level
	hero.hp = 999
	hero.hp_max = 999
	hero.ht = 999
	return hero

func run(t: Object) -> void:
	seed(0xF2057)

	var original_hero: Node = GameManager.hero
	var original_heroes: Array[Node] = GameManager.heroes.duplicate()
	var original_level: Level = GameManager.current_level

	_test_factory_builds_spd_profile(t)
	_test_detonation_seeds_freezing_and_applies_frozen(t)

	GameManager.heroes = original_heroes
	GameManager.hero = original_hero
	GameManager.current_level = original_level

func _test_factory_builds_spd_profile(t: Object) -> void:
	var bomb: Bomb = Bomb.create("frost_bomb")
	t.check(bomb.bomb_type == Bomb.BombType.FROST, "frost bomb has BombType.FROST")
	t.check(bomb.radius == 2, "frost bomb uses SPD radius-2 explosion range")
	t.check(bomb.damage_min == 10 and bomb.damage_max == 30,
			"frost bomb keeps the normal bomb blast damage")
	t.check(bomb.value() == 50, "frost bomb uses SPD base+ingredient value")

func _test_detonation_seeds_freezing_and_applies_frozen(t: Object) -> void:
	var level: Level = _make_level()
	var center: int = ConstantsData.xy_to_pos(16, 16)
	var hero: Hero = _make_hero(center, level)
	GameManager.hero = null
	GameManager.heroes.clear()
	GameManager.current_level = level
	GameManager.add_hero(hero)

	var water_cell: int = center + 1
	level.set_terrain(water_cell, ConstantsData.Terrain.WATER)

	var bomb: Bomb = Bomb.create("frost_bomb")
	bomb.detonate(center, level)

	var freezing: FreezingBlob = _find_freezing(level)
	t.check(freezing != null, "frost bomb seeds a Freezing blob")
	if freezing != null:
		t.check(freezing.active_cells.size() == 25,
				"frost bomb covers the full 25-cell radius-2 footprint (got %d)" % freezing.active_cells.size())
		t.check(is_equal_approx(freezing.get_density(center), Bomb.FROST_SEED_VOLUME),
				"center cell seeded at 10 freezing volume")
		t.check(is_equal_approx(freezing.get_density(water_cell), Bomb.FROST_SEED_VOLUME),
				"adjacent cells are seeded at 10 freezing volume")

	t.check(hero.has_buff("Frozen"), "frost bomb directly applies Frozen")
	t.check(not hero.has_buff("Paralysis"), "frost bomb no longer applies generic Paralysis")
	var frozen: Variant = hero.get_buff("Frozen")
	t.check(frozen != null and is_equal_approx(float(frozen.get("time_left")), Bomb.FROST_DIRECT_DURATION),
			"direct Frozen duration is the short SPD frost duration")

	level.tick_blobs()
	t.check(level.terrain_at(water_cell) == ConstantsData.Terrain.EMPTY,
			"frost bomb's Freezing blob hardens water on the blob tick")

	hero.free()

func _find_freezing(level: Level) -> FreezingBlob:
	for entry: Dictionary in level.blobs:
		var blob: Variant = entry.get("blob")
		if blob is FreezingBlob:
			return blob as FreezingBlob
	return null
