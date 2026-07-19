extends RefCounted
## Paralytic traps should seed real paralytic gas instead of doing nothing.

func _make_level() -> Level:
	var level := Level.new()
	level.depth = 7
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
	return hero

func run(t: Object) -> void:
	_check_trap_seeds_paralytic_gas(t)
	_check_prison_pool_can_roll_paralytic_trap(t)

func _check_trap_seeds_paralytic_gas(t: Object) -> void:
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

	var trap := ParalyticTrap.new()
	trap.set_pos(hero_pos)
	trap.activate(hero, level)

	t.check(_has_blob(level, "paralytic_gas"), "paralytic trap seeds paralytic gas")
	t.check(not hero.has_buff("Paralysis"), "paralytic trap waits for gas tick before paralysis")
	level.tick_blobs()
	t.check(hero.has_buff("Paralysis"), "paralytic trap gas paralyzes the triggerer")
	t.check(not trap.active, "paralytic trap remains one-shot after activation")

	GameManager.heroes = original_heroes
	GameManager.hero = original_hero
	GameManager.current_level = original_level
	hero.free()

func _check_prison_pool_can_roll_paralytic_trap(t: Object) -> void:
	var prison := PrisonLevel.new()
	var found: bool = false
	for _i: int in range(200):
		if prison._create_random_trap() is ParalyticTrap:
			found = true
			break
	t.check(found, "Prison trap pool can roll ParalyticTrap")

func _has_blob(level: Level, blob_id: String) -> bool:
	for entry: Dictionary in level.blobs:
		var blob: Variant = entry.get("blob")
		if blob != null and str(blob.get("blob_id")) == blob_id:
			return true
	return false
