extends RefCounted
## Regrowth Bomb should route through the shared Regrowth blob layer instead of
## painting grass immediately. Source check: SPD RegrowthBomb seeds Regrowth at
## 10 volume over a radius-3 footprint and heals allied characters like a healing
## potion; the blob then grows grass/high grass and roots chars standing in it.

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
	hero.hp_max = 40
	hero.ht = 40
	hero.hp = 10
	return hero

func run(t: Object) -> void:
	var original_hero: Node = GameManager.hero
	var original_heroes: Array[Node] = GameManager.heroes.duplicate()
	var original_level: Level = GameManager.current_level

	_test_factory_builds_radius_3_regrowth_bomb(t)
	_test_detonation_seeds_regrowth_and_heals_hero(t)
	_test_regrowth_blob_grows_grass_and_roots(t)
	_test_regrowth_blob_serializes(t)

	GameManager.heroes = original_heroes
	GameManager.hero = original_hero
	GameManager.current_level = original_level

func _test_factory_builds_radius_3_regrowth_bomb(t: Object) -> void:
	var bomb: Bomb = Bomb.create("regrowth_bomb")
	t.check(bomb.bomb_type == Bomb.BombType.REGROWTH, "regrowth bomb has BombType.REGROWTH")
	t.check(bomb.radius == 3, "regrowth bomb uses SPD radius-3 footprint")

func _test_detonation_seeds_regrowth_and_heals_hero(t: Object) -> void:
	var level: Level = _make_level()
	var center: int = ConstantsData.xy_to_pos(16, 16)
	var hero: Hero = _make_hero(center, level)
	GameManager.hero = null
	GameManager.heroes.clear()
	GameManager.current_level = level
	GameManager.add_hero(hero)

	var poison := Poison.create(5.0)
	hero.add_buff(poison)
	hero.add_buff(Weakness.new())

	var bomb: Bomb = Bomb.create("regrowth_bomb")
	bomb.detonate(center, level)

	var regrowth: Regrowth = _find_regrowth(level)
	t.check(regrowth != null, "detonation seeds a regrowth blob")
	if regrowth != null:
		t.check(regrowth.active_cells.size() == 49,
				"regrowth covers the full 49-cell radius-3 footprint (got %d)" % regrowth.active_cells.size())
		t.check(is_equal_approx(regrowth.get_density(center), Bomb.REGROWTH_SEED_VOLUME),
				"center cell seeded at 10 volume")
	t.check(hero.hp == hero.hp_max, "regrowth bomb heals heroes like a healing potion")
	t.check(not hero.has_buff("Poison"), "regrowth bomb cures poison on healed heroes")
	t.check(not hero.has_buff("Weakness"), "regrowth bomb cures the broader healing-potion debuff set")

	hero.free()

func _test_regrowth_blob_grows_grass_and_roots(t: Object) -> void:
	var level: Level = _make_level()
	var center: int = ConstantsData.xy_to_pos(14, 14)
	var hero: Hero = _make_hero(center, level)
	GameManager.hero = null
	GameManager.heroes.clear()
	GameManager.current_level = level
	GameManager.add_hero(hero)

	var grass_cell: int = center + 1
	level.set_terrain(grass_cell, ConstantsData.Terrain.GRASS)
	var occupied_cell: int = center
	var regrowth := Regrowth.new()
	level.add_blob(regrowth, occupied_cell, 10.0)
	level.add_blob(Regrowth.new(), grass_cell, 10.0)

	regrowth.tick()

	t.check(hero.has_buff("Rooted"), "regrowth blob roots a character standing in dense growth")
	t.check(level.terrain_at(grass_cell) == ConstantsData.Terrain.HIGH_GRASS,
			"regrowth promotes unoccupied grass to high grass")
	t.check(level.terrain_at(occupied_cell) == ConstantsData.Terrain.GRASS,
			"regrowth grows grass under an occupied empty cell but does not make it high grass")

	hero.free()

func _test_regrowth_blob_serializes(t: Object) -> void:
	var level: Level = _make_level()
	var center: int = ConstantsData.xy_to_pos(18, 18)
	level.add_blob(Regrowth.new(), center, 10.0)

	var restored_level := Level.new()
	restored_level.deserialize(level.serialize())
	var regrowth: Regrowth = _find_regrowth(restored_level)
	t.check(regrowth != null, "regrowth blob round-trips through Level serialization")
	if regrowth != null:
		t.check(is_equal_approx(regrowth.get_density(center), 10.0),
				"restored regrowth keeps per-cell density")

func _find_regrowth(level: Level) -> Regrowth:
	for entry: Dictionary in level.blobs:
		var blob: Variant = entry.get("blob")
		if blob is Regrowth:
			return blob as Regrowth
	return null
