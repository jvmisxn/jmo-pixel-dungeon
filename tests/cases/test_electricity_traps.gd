extends RefCounted
## ShockingTrap and StormTrap should seed SPD-style Electricity blobs instead
## of applying invented immediate chain/storm damage or Blindness.

func _make_level() -> Level:
	var level := Level.new()
	level.depth = 10
	level.map.resize(ConstantsData.LENGTH)
	level.map.fill(ConstantsData.Terrain.EMPTY)
	level.entrance = ConstantsData.xy_to_pos(1, 1)
	level.exit_pos = ConstantsData.xy_to_pos(2, 2)
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

func _find_electricity(level: Level) -> Electricity:
	for entry: Dictionary in level.blobs:
		var blob: Variant = entry.get("blob")
		if blob is Electricity:
			return blob as Electricity
	return null

func _restore_game_manager(original_hero: Node, original_heroes: Array[Node], original_level: Level) -> void:
	GameManager.heroes = original_heroes
	GameManager.hero = original_hero
	GameManager.current_level = original_level

func run(t: Object) -> void:
	seed(0xE1EC)

	var original_hero: Node = GameManager.hero
	var original_heroes: Array[Node] = GameManager.heroes.duplicate()
	var original_level: Level = GameManager.current_level

	var level: Level = _make_level()
	var hero_pos: int = ConstantsData.xy_to_pos(10, 10)
	var hero: Hero = _make_hero(hero_pos, level)
	GameManager.hero = null
	GameManager.heroes.clear()
	GameManager.current_level = level
	GameManager.add_hero(hero)

	var shocking := ShockingTrap.new()
	shocking.set_pos(hero_pos)
	shocking.activate(hero, level)
	var shocking_blob: Electricity = _find_electricity(level)
	t.check(shocking_blob != null, "shocking trap seeds an Electricity blob")
	t.check(is_equal_approx(shocking_blob.get_density(hero_pos), ShockingTrap.ELECTRICITY_AMOUNT),
			"shocking trap seeds 10 charge at the trigger cell")
	t.check(hero.hp == 999, "shocking trap deals no immediate direct damage")
	t.check(not hero.has_buff("Paralysis"), "shocking trap waits for the blob tick before paralyzing")

	level.tick_blobs()
	var paralysis: Paralysis = hero.get_buff("Paralysis") as Paralysis
	t.check(paralysis != null, "Electricity paralyzes the triggerer on tick")
	t.check(is_equal_approx(shocking_blob.get_density(hero_pos), 9.0),
			"Electricity loses one charge after shocking")

	var storm_level: Level = _make_level()
	var storm_pos: int = ConstantsData.xy_to_pos(20, 10)
	var water_cell: int = storm_pos + 3
	storm_level.set_terrain(storm_pos + 2, ConstantsData.Terrain.WATER)
	storm_level.set_terrain(water_cell, ConstantsData.Terrain.WATER)
	var storm_hero: Hero = _make_hero(storm_pos, storm_level)
	GameManager.hero = null
	GameManager.heroes.clear()
	GameManager.current_level = storm_level
	GameManager.add_hero(storm_hero)

	var storm := StormTrap.new()
	storm.set_pos(storm_pos)
	storm.activate(storm_hero, storm_level)
	var storm_blob: Electricity = _find_electricity(storm_level)
	t.check(storm_blob != null, "storm trap seeds an Electricity blob")
	t.check(is_equal_approx(storm_blob.get_density(storm_pos), StormTrap.ELECTRICITY_AMOUNT),
			"storm trap seeds 20 charge at the trigger cell")
	t.check(is_equal_approx(storm_blob.get_density(storm_pos + 2), StormTrap.ELECTRICITY_AMOUNT),
			"storm trap seeds the passable radius-2 footprint")
	t.check(is_equal_approx(storm_blob.get_density(water_cell), 0.0),
			"storm trap does not seed beyond radius 2 before the blob tick")
	t.check(storm_hero.hp == 999, "storm trap deals no immediate direct damage")
	t.check(not storm_hero.has_buff("Blindness"), "storm trap does not apply invented Blindness")

	storm_level.tick_blobs()
	t.check(is_equal_approx(storm_blob.get_density(water_cell), 19.0),
			"Electricity conducts through connected water on tick")

	_restore_game_manager(original_hero, original_heroes, original_level)
	hero.free()
	storm_hero.free()
